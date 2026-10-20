-- Definição matemática do mundo: relevo, biomas, estradas e locais.
-- Servidor e cliente usam as mesmas funções, então o resultado é idêntico nos dois lados.
--
-- Eixos: X = leste(+)/oeste(-), Z = sul(+)/norte(-).
-- Layout: Vila no sul perto da costa, planícies no centro, bosque a leste, ruínas a oeste,
-- montanhas ao norte e nas laterais, oceano ao sul. A cratera do chefe fica nas montanhas do norte,
-- acessível por uma passagem.
local World = {}

World.Half = 512 -- o mapa vai de -512 a 512
World.SeaLevel = 4
World.TownCenter = Vector3.new(0, 0, 150)
World.TownHeight = 18
World.CraterCenter = Vector3.new(0, 0, -445)
World.CraterHeight = 40
World.PassGateZ = -330

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
World.fbm = fbm

local function distance(x, z, cx, cz)
	local dx, dz = x - cx, z - cz
	return math.sqrt(dx * dx + dz * dz)
end

-- Pesos de cada região (0 a 1) com bordas orgânicas (distorcidas por ruído)
function World.weights(x, z)
	local warp = fbm(x, z, 2, 180, SEED + 100) * 90
	local w = {}
	w.forest = 1 - smoothstep(130, 230, distance(x, z, 260, -70) + warp)
	w.ruins = 1 - smoothstep(120, 220, distance(x, z, -260, -70) - warp)
	local north = smoothstep(290, 420, -z + warp * 0.6)
	local sides = smoothstep(380, 480, math.abs(x) + warp * 0.5)
	w.mountain = math.max(north, sides)
	w.crater = 1 - smoothstep(70, 105, distance(x, z, World.CraterCenter.X, World.CraterCenter.Z))
	w.corridor = (1 - smoothstep(16, 42, math.abs(x + fbm(x, z, 1, 120, SEED + 61) * 12))) * smoothstep(-205, -240, z)
	w.ocean = smoothstep(270, 370, z - warp * 0.3)
	w.lake = 1 - smoothstep(28, 62, distance(x, z, -170, 160) + warp * 0.15)
	w.town = 1 - smoothstep(78, 108, distance(x, z, World.TownCenter.X, World.TownCenter.Z))
	return w
end

function World.heightWithWeights(x, z, w)
	local h = 18 + fbm(x, z, 4, 240, SEED) * 32
	h += w.forest * fbm(x, z, 3, 70, SEED + 7) * 12
	h += w.ruins * (10 + fbm(x, z, 3, 110, SEED + 11) * 16)
	local ridge = 1 - math.abs(fbm(x, z, 4, 160, SEED + 23)) * 2
	h += w.mountain * (1 - w.corridor) * (1 - w.crater) * (55 + ridge * 85)
	-- passagem: sobe suave da planície até a cratera
	local corridorHeight = lerp(22, World.CraterHeight, smoothstep(-235, -400, z)) + fbm(x, z, 2, 40, SEED + 31) * 2
	h = lerp(h, corridorHeight, w.corridor)
	h = lerp(h, World.CraterHeight + fbm(x, z, 2, 30, SEED + 41) * 1.5, w.crater)
	h = lerp(h, -14, w.ocean)
	h = lerp(h, -3, w.lake)
	h = lerp(h, World.TownHeight, w.town)
	return h
end

function World.height(x, z)
	return World.heightWithWeights(x, z, World.weights(x, z))
end

-- Estradas (linhas entre pontos X,Z)
World.Roads = {
	{ Vector2.new(0, 150), Vector2.new(0, 70), Vector2.new(0, 10), Vector2.new(6, -110), Vector2.new(0, -235), Vector2.new(0, -330) },
	{ Vector2.new(0, 10), Vector2.new(90, -15), Vector2.new(185, -38) },
	{ Vector2.new(0, 10), Vector2.new(-90, -15), Vector2.new(-185, -38) },
	{ Vector2.new(20, 185), Vector2.new(70, 240), Vector2.new(112, 280) },
	{ Vector2.new(-25, 155), Vector2.new(-70, 165), Vector2.new(-108, 166) },
}

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

World.RoadWidth = 4.5

-- Material do terreno na superfície
function World.surfaceMaterial(x, z, h, slope, w)
	local M = Enum.Material
	local n = fbm(x, z, 2, 28, SEED + 51)
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
	if w.town > 0.6 and distance(x, z, World.TownCenter.X, World.TownCenter.Z) < 34 then
		return M.Cobblestone
	end
	if road < World.RoadWidth then
		return if w.town > 0.5 then M.Cobblestone else M.Ground
	end
	if h > 118 then
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
	elseif w.corridor > 0.5 and z < -240 then
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

-- Locais nomeados (missões de exploração, marcadores, mapa)
World.Locations = {
	vila = { name = "Vila Aurora", x = 0, z = 150, radius = 45 },
	encruzilhada = { name = "Encruzilhada", x = 0, z = 10, radius = 22 },
	bosque = { name = "Bosque Sombrio", x = 250, z = -70, radius = 60 },
	toca_aranhas = { name = "Ninho das Aranhas", x = 330, z = 30, radius = 30 },
	ruinas = { name = "Planalto das Ruínas", x = -250, z = -70, radius = 60 },
	templo_ruinas = { name = "Templo em Ruínas", x = -275, z = -115, radius = 25 },
	mina = { name = "Mina Abandonada", x = -150, z = -205, radius = 25 },
	santuario_lago = { name = "Santuário do Lago", x = -112, z = 168, radius = 18 },
	farol = { name = "Farol Abandonado", x = -205, z = 285, radius = 20 },
	praia = { name = "Costa Dourada", x = 125, z = 292, radius = 40 },
	passagem = { name = "Passagem do Norte", x = 0, z = -240, radius = 25 },
	portao_norte = { name = "Portão Selado", x = 0, z = World.PassGateZ, radius = 22 },
	cratera = { name = "Covil do Rei Goblin", x = 0, z = -445, radius = 55 },
}

-- Pedras de viagem rápida (descobertas ao chegar perto)
World.Waystones = {
	{ id = "vila", name = "Vila Aurora", x = -15, z = 150 },
	{ id = "encruzilhada", name = "Encruzilhada", x = 14, z = 18 },
	{ id = "bosque", name = "Bosque Sombrio", x = 192, z = -28 },
	{ id = "ruinas", name = "Planalto das Ruínas", x = -192, z = -28 },
	{ id = "praia", name = "Costa Dourada", x = 104, z = 276 },
	{ id = "lago", name = "Lago Espelhado", x = -98, z = 176 },
	{ id = "passagem", name = "Passagem do Norte", x = 16, z = -236 },
}
World.WaystoneById = {}
for _, stone in World.Waystones do
	World.WaystoneById[stone.id] = stone
end

function World.surfacePosition(x, z, offset)
	return Vector3.new(x, World.height(x, z) + (offset or 0), z)
end

return World
