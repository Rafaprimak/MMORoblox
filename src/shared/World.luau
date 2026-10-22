-- Definição matemática do mundo: relevo, biomas, estradas e locais.
-- Servidor e cliente usam as mesmas funções, então o resultado é idêntico nos dois lados.
--
-- Eixos: X = leste(+)/oeste(-), Z = sul(+)/norte(-).
-- Layout: Vila no sul perto da costa, planícies no centro, bosque a leste, ruínas a oeste,
-- montanhas ao norte e nas laterais, oceano ao sul. A cratera do chefe fica nas montanhas do norte,
-- acessível por uma passagem.
--
-- ESCALA: todas as fórmulas trabalham no "espaço de design" (mapa de -512 a 512) e o resultado é
-- ampliado por World.Scale. Assim dá para aumentar o mundo inteiro mudando um número só.
-- Coordenadas expostas (TownCenter, Locations, Waystones, estradas) já estão em studs reais.
local TownPlan = require(script.Parent.TownPlan)

local World = {}

World.Scale = 1.5
local S = World.Scale

World.Half = 512 * S -- o mapa vai de -Half a +Half
World.SeaLevel = 4
World.TownCenter = Vector3.new(0, 0, 150 * S)
-- múltiplo de 4 a partir de MIN_Y (-24) do TerrainGen: o voxel fica cheio e o chão sai exatamente nessa altura
World.TownHeight = 20
World.CraterCenter = Vector3.new(0, 0, -445 * S)
World.CraterHeight = 44
World.PassGateZ = -330 * S
World.RoadWidth = 6

local SEED = 4242

local function smoothstep(a, b, x)
	local t = math.clamp((x - a) / (b - a), 0, 1)
	return t * t * (3 - 2 * t)
end
World.smoothstep = smoothstep

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function fbm(x, z, octaves, scale, seed)
	local total, amplitude, frequency, norm = 0, 1, 1 / scale, 0
	for i = 1, octaves do
		total += math.noise(x * frequency + 0.31, z * frequency + 0.17, seed + i * 13.37) * amplitude
		norm += amplitude
		amplitude *= 0.5
		frequency *= 2
	end
	return total / norm
end
-- ruído no espaço real (o mapa usa para colorir)
function World.fbm(x, z, octaves, scale, seed)
	return fbm(x / S, z / S, octaves, scale, seed)
end

local function distance(x, z, cx, cz)
	local dx, dz = x - cx, z - cz
	return math.sqrt(dx * dx + dz * dz)
end

-- Pesos de cada região (0 a 1) com bordas orgânicas (distorcidas por ruído).
-- Recebe coordenadas reais; calcula no espaço de design.
function World.weights(x, z)
	local dx, dz = x / S, z / S
	local warp = fbm(dx, dz, 2, 180, SEED + 100) * 90
	local w = {}
	w.forest = 1 - smoothstep(130, 230, distance(dx, dz, 260, -70) + warp)
	w.ruins = 1 - smoothstep(120, 220, distance(dx, dz, -260, -70) - warp)
	local north = smoothstep(290, 420, -dz + warp * 0.6)
	local sides = smoothstep(380, 480, math.abs(dx) + warp * 0.5)
	w.mountain = math.max(north, sides)
	w.crater = 1 - smoothstep(70, 105, distance(dx, dz, 0, -445))
	w.corridor = (1 - smoothstep(16, 42, math.abs(dx + fbm(dx, dz, 1, 120, SEED + 61) * 12))) * smoothstep(-205, -240, dz)
	w.ocean = smoothstep(270, 370, dz - warp * 0.3)
	w.lake = 1 - smoothstep(28, 62, distance(dx, dz, -170, 160) + warp * 0.15)
	w.town = 1 - smoothstep(TownPlan.Radius, TownPlan.Radius + 30, distance(dx, dz, 0, 150))
	return w
end

function World.heightWithWeights(x, z, w)
	local dx, dz = x / S, z / S
	local h = 18 + fbm(dx, dz, 4, 240, SEED) * 36
	h += w.forest * fbm(dx, dz, 3, 70, SEED + 7) * 14
	h += w.ruins * (12 + fbm(dx, dz, 3, 110, SEED + 11) * 18)
	local ridge = 1 - math.abs(fbm(dx, dz, 4, 160, SEED + 23)) * 2
	h += w.mountain * (1 - w.corridor) * (1 - w.crater) * (70 + ridge * 110)
	-- passagem: sobe suave da planície até a cratera
	local corridorHeight = lerp(22, World.CraterHeight, smoothstep(-235, -400, dz)) + fbm(dx, dz, 2, 40, SEED + 31) * 2
	h = lerp(h, corridorHeight, w.corridor)
	h = lerp(h, World.CraterHeight + fbm(dx, dz, 2, 30, SEED + 41) * 1.5, w.crater)
	h = lerp(h, -16, w.ocean)
	h = lerp(h, -4, w.lake)
	h = lerp(h, World.TownHeight, w.town)
	return h
end

function World.height(x, z)
	return World.heightWithWeights(x, z, World.weights(x, z))
end

-- Estradas (em coordenadas de design; convertidas para studs reais abaixo)
local DESIGN_ROADS = {
	{ { 0, 150 }, { 0, 70 }, { 0, 10 }, { 6, -110 }, { 0, -235 }, { 0, -330 } },
	{ { 0, 10 }, { 90, -15 }, { 185, -38 } },
	{ { 0, 10 }, { -90, -15 }, { -185, -38 } },
	{ { 75, 150 }, { 95, 210 }, { 112, 280 } },
	{ { -75, 150 }, { -92, 160 }, { -108, 166 } },
}
World.Roads = {}
for i, road in DESIGN_ROADS do
	local points = {}
	for j, point in road do
		points[j] = Vector2.new(point[1] * S, point[2] * S)
	end
	World.Roads[i] = points
end

local segments = {}
for _, road in World.Roads do
	for i = 1, #road - 1 do
		table.insert(segments, { road[i], road[i + 1] })
	end
end

local function segmentDistance(px, pz, a, b)
	local abx, abz = b.X - a.X, b.Y - a.Y
	local t = math.clamp(((px - a.X) * abx + (pz - a.Y) * abz) / (abx * abx + abz * abz), 0, 1)
	return distance(px, pz, a.X + abx * t, a.Y + abz * t)
end

function World.roadDistance(x, z)
	local best = math.huge
	for _, segment in segments do
		local d = segmentDistance(x, z, segment[1], segment[2])
		if d < best then
			best = d
		end
	end
	return best
end

-- Material do terreno na superfície
function World.surfaceMaterial(x, z, h, slope, w)
	local M = Enum.Material
	local n = fbm(x / S, z / S, 2, 28, SEED + 51)
	if h < World.SeaLevel + 0.5 then
		return if w.ocean > 0.05 then M.Sand else M.Mud
	end
	if w.ocean > 0.08 and h < World.SeaLevel + 6 then
		return M.Sand
	end
	if w.lake > 0.15 and h < World.SeaLevel + 3 then
		return M.Sand
	end
	local road = World.roadDistance(x, z)
	-- dentro da vila: embaixo das ruas, praça e becos, chão sem grama (a grama animada atravessaria o
	-- calçamento, que são peças finas); no resto, grama dos jardins
	if w.town > 0.5 then
		local paving = TownPlan.pavingAt((x - World.TownCenter.X) / S, (z - World.TownCenter.Z) / S, 2)
		if paving == "beco" then
			return M.Ground
		elseif paving then
			return M.Cobblestone
		end
		return if n > 0.3 then M.LeafyGrass else M.Grass
	end
	if road < World.RoadWidth then
		return if w.town > 0.5 then M.Cobblestone else M.Ground
	end
	if h > 135 then
		return M.Snow
	end
	if slope > 1.05 then
		return M.Rock
	end
	if w.crater > 0.5 then
		return if n > 0 then M.Basalt else M.Ground
	end
	if w.mountain > 0.55 then
		return if n > 0.05 then M.Rock else M.Ground
	end
	if w.ruins > 0.5 then
		if n > 0.22 then
			return M.Slate
		elseif n < -0.25 then
			return M.Ground
		end
		return M.Grass
	end
	if w.forest > 0.5 then
		return if n > 0.25 then M.Mud else M.LeafyGrass
	end
	return if n > 0.3 then M.LeafyGrass else M.Grass
end

-- Nome da região (mostrado na tela ao entrar)
function World.regionName(x, z)
	local w = World.weights(x, z)
	if w.town > 0.5 then
		return "Vila Aurora"
	elseif w.crater > 0.35 then
		return "Covil do Rei Goblin"
	elseif w.corridor > 0.5 and z < -240 * S then
		return "Passagem do Norte"
	elseif w.mountain > 0.6 then
		return "Montanhas Geladas"
	elseif w.ocean > 0.12 then
		return "Costa Dourada"
	elseif w.lake > 0.3 then
		return "Lago Espelhado"
	elseif w.forest > 0.5 then
		return "Bosque Sombrio"
	elseif w.ruins > 0.5 then
		return "Planalto das Ruínas"
	end
	return "Campos Verdejantes"
end

-- Locais nomeados (missões de exploração, marcadores, mapa). Valores de design × escala.
local DESIGN_LOCATIONS = {
	vila = { "Vila Aurora", 0, 150, 60 },
	encruzilhada = { "Encruzilhada", 0, 10, 22 },
	bosque = { "Bosque Sombrio", 250, -70, 60 },
	toca_aranhas = { "Ninho das Aranhas", 330, 30, 30 },
	ruinas = { "Planalto das Ruínas", -250, -70, 60 },
	templo_ruinas = { "Templo em Ruínas", -275, -115, 25 },
	mina = { "Mina Abandonada", -150, -205, 25 },
	santuario_lago = { "Santuário do Lago", -112, 168, 18 },
	farol = { "Farol Abandonado", -205, 285, 20 },
	praia = { "Costa Dourada", 125, 292, 40 },
	passagem = { "Passagem do Norte", 0, -240, 25 },
	portao_norte = { "Portão Selado", 0, -330, 22 },
	cratera = { "Covil do Rei Goblin", 0, -445, 55 },
}
World.Locations = {}
for id, loc in DESIGN_LOCATIONS do
	World.Locations[id] = { name = loc[1], x = loc[2] * S, z = loc[3] * S, radius = loc[4] * S }
end

-- Pedras de viagem rápida (descobertas ao chegar perto)
local DESIGN_WAYSTONES = {
	{ "vila", "Vila Aurora", -16, 134 },
	{ "encruzilhada", "Encruzilhada", 14, 18 },
	{ "bosque", "Bosque Sombrio", 192, -28 },
	{ "ruinas", "Planalto das Ruínas", -192, -28 },
	{ "praia", "Costa Dourada", 104, 276 },
	{ "lago", "Lago Espelhado", -98, 176 },
	{ "passagem", "Passagem do Norte", 16, -236 },
}
World.Waystones = {}
World.WaystoneById = {}
for i, stone in DESIGN_WAYSTONES do
	local entry = { id = stone[1], name = stone[2], x = stone[3] * S, z = stone[4] * S }
	World.Waystones[i] = entry
	World.WaystoneById[entry.id] = entry
end

function World.surfacePosition(x, z, offset)
	return Vector3.new(x, World.height(x, z) + (offset or 0), z)
end

return World
