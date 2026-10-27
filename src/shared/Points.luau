-- Locais de interesse espalhados pelo mapa (ruínas, cemitério, moinho, naufrágio...).
-- Chegar perto pela primeira vez dá recompensa ("Local descoberto") e cada um tem um baú escondido
-- que o jogador abre uma vez. Posições em coordenadas de projeto; a posição final procura (de forma
-- determinística) um chão seco e plano perto do ponto pedido, então servidor e cliente chegam no mesmo lugar.
local World = require(script.Parent.World)

local Points = {}

local S = World.Scale

-- kind = construtor em WorldGen/PointsOfInterest; radius = raio de descoberta (projeto)
local DESIGN = {
	{ id = "moinho", name = "Moinho dos Campos", icon = "wheat", kind = "windmill", x = 110, z = 85, radius = 22, xp = 120, gold = 80, chest = "bronze" },
	{ id = "circulo", name = "Círculo de Pedras", icon = "moai", kind = "stonecircle", x = -110, z = 40, radius = 20, xp = 150, gold = 90, chest = "bronze" },
	{ id = "vigia", name = "Torre de Vigia Abandonada", icon = "castle", kind = "watchtower", x = -90, z = -60, radius = 18, xp = 150, gold = 90, chest = "bronze" },
	{ id = "estatua", name = "Estátua do Herói Caído", icon = "obelisk", kind = "statue", x = 60, z = -150, radius = 18, xp = 200, gold = 120, chest = "bronze" },
	{ id = "acampamento", name = "Acampamento Abandonado", icon = "camping-tent", kind = "camp", x = 150, z = -110, radius = 18, xp = 200, gold = 120, chest = "prata" },
	{ id = "observatorio", name = "Observatório em Ruínas", icon = "telescope", kind = "observatory", x = -200, z = 20, radius = 24, xp = 300, gold = 180, chest = "prata" },
	{ id = "cemiterio", name = "Cemitério Antigo", icon = "coffin", kind = "graveyard", x = -205, z = -150, radius = 24, xp = 350, gold = 200, chest = "prata" },
	{ id = "altar", name = "Altar Esquecido", icon = "cut-diamond", kind = "altar", x = 300, z = -140, radius = 20, xp = 400, gold = 220, chest = "prata" },
	{ id = "naufragio", name = "Navio Naufragado", icon = "anchor", kind = "shipwreck", x = 225, z = 305, radius = 26, xp = 300, gold = 250, chest = "real" },
}

-- chão bom: seco, abaixo das montanhas, plano e longe das estradas
local function goodSpot(x, z)
	local h = World.height(x, z)
	if h < World.SeaLevel + 1.5 or h > 90 then
		return false
	end
	local step = 7
	local maxDiff = 0
	for _, offset in { { step, 0 }, { -step, 0 }, { 0, step }, { 0, -step }, { step, step }, { -step, -step } } do
		maxDiff = math.max(maxDiff, math.abs(World.height(x + offset[1], z + offset[2]) - h))
	end
	return maxDiff < 3.5 and World.roadDistance(x, z) > World.RoadWidth + 14
end

-- procura em espiral um ponto bom perto do pedido (mesmo resultado nos dois lados).
-- accept (opcional): regra extra, ex. ficar longe de construções (portais das masmorras)
local function resolve(x, z, accept)
	local function ok(px, pz)
		return goodSpot(px, pz) and (not accept or accept(px, pz))
	end
	if ok(x, z) then
		return x, z
	end
	for ring = 1, 10 do
		local radius = ring * 8
		local count = 6 + ring * 2
		for i = 0, count - 1 do
			local a = i / count * math.pi * 2
			local px, pz = x + math.cos(a) * radius, z + math.sin(a) * radius
			if ok(px, pz) then
				return px, pz
			end
		end
	end
	return x, z
end

-- usado também pelos portais das masmorras
Points.resolve = resolve

Points.List = {}
Points.ById = {}
for _, def in DESIGN do
	local x, z = resolve(def.x * S, def.z * S)
	local entry = table.clone(def)
	entry.x, entry.z = x, z
	entry.radius = def.radius * S
	table.insert(Points.List, entry)
	Points.ById[entry.id] = entry
end

return Points
