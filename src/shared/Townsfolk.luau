-- Vida da Vila Aurora: moradores que passeiam, conversam e animais soltos.
-- Tudo é determinístico pelo relógio do servidor (workspace:GetServerTimeNow()): cada cliente calcula
-- sozinho a mesma posição, sem tráfego de rede. Posições em coordenadas de projeto relativas ao centro
-- da praça (Townsfolk.at(x, z) ou Townsfolk.point(ângulo, raio)), convertidas por × World.Scale.
local World = require(script.Parent.World)

local Townsfolk = {}

local S = World.Scale
local CX, CZ = World.TownCenter.X, World.TownCenter.Z
local GROUND = World.TownHeight + 0.3 -- em cima do calçamento (peças de ~0,3 sobre o chão)

-- ponto em volta da praça (ângulo, raio de projeto) → Vector3 em studs reais (Y = chão da vila)
function Townsfolk.point(angle, radius)
	local a = math.rad(angle)
	return Vector3.new(CX + math.cos(a) * radius * S, GROUND, CZ + math.sin(a) * radius * S)
end

local P = Townsfolk.point

-- Falas soltas (balão em cima da cabeça quando o morador para)
Townsfolk.Lines = {
	"Dizem que o Rei Goblin voltou a rondar a passagem...",
	"O pão da padaria hoje está uma delícia!",
	"Você viu o novo Hunter? Parece forte.",
	"Cuidado com os lobos depois que escurece.",
	"Ouvi falar de um baú lendário no Bosque Sombrio.",
	"O Bruno não para de martelar desde cedo!",
	"As poções da Mira salvaram meu primo semana passada.",
	"Que dia bonito para pescar no lago.",
	"Meu galo fugiu de novo...",
	"Será que vai chover hoje?",
	"O Otto anda vendendo ovos de pet. Que fofura!",
	"À noite os monstros ficam mais bravos, sabia?",
	"Meu avô dizia que a torre do Elric é mais velha que a vila.",
	"Quero ser Hunter quando crescer!",
	"Alguém viu minha cesta de maçãs?",
	"O Mestre Kael treina os novatos no pátio.",
	"Hoje tem festa na praça!",
	"Os caranguejos tomaram a praia de novo.",
}

-- ponto (x, z) de projeto relativo ao centro da praça (x leste, z sul) → Vector3 real
function Townsfolk.at(x, z)
	return Vector3.new(CX + x * S, GROUND, CZ + z * S)
end

local A = Townsfolk.at

-- volta em octógono pela praça (entre os bancos do chafariz e as barracas dos cantos)
local function plazaLoop(radius, reverse)
	local points = {}
	for i = 0, 7 do
		local angle = 22.5 + (if reverse then -i else i) * 45
		table.insert(points, P(angle, radius))
	end
	return points
end

-- Moradores: aparência e rota (lista de pontos). Cada trecho anda em "speed" studs/s e para "pause" segundos.
-- As rotas seguem as calçadas e o meio das ruas do traçado da vila (WorldGen/Town).
Townsfolk.Villagers = {
	{ name = "Ana", skin = Color3.fromRGB(240, 200, 170), shirt = Color3.fromRGB(200, 80, 90), pants = Color3.fromRGB(70, 50, 40), hair = Color3.fromRGB(90, 50, 30), hat = "scarf", dress = true, speed = 6, pause = 6, route = { A(-5.5, -22), A(-5.5, -46), A(-5.5, -68), A(5.5, -68), A(5.5, -46), A(5.5, -22) } },
	{ name = "Beto", skin = Color3.fromRGB(200, 150, 110), shirt = Color3.fromRGB(80, 120, 170), pants = Color3.fromRGB(60, 60, 70), hair = Color3.fromRGB(40, 30, 25), hat = "cap", speed = 7, pause = 4, route = { A(0, -70), A(0, -45), A(0, -23) } },
	{ name = "Clara", skin = Color3.fromRGB(250, 215, 190), shirt = Color3.fromRGB(240, 220, 120), pants = Color3.fromRGB(150, 110, 70), hair = Color3.fromRGB(230, 190, 90), dress = true, speed = 5, pause = 8, route = { A(22, -5.5), A(48, -5.5), A(70, -5.5), A(70, 5.5), A(48, 5.5), A(22, 5.5) } },
	{ name = "Dido", skin = Color3.fromRGB(150, 100, 70), shirt = Color3.fromRGB(120, 150, 80), pants = Color3.fromRGB(80, 60, 40), hair = Color3.fromRGB(20, 20, 20), hat = "straw", basket = true, speed = 4.5, pause = 9, route = plazaLoop(16.5, false) },
	{ name = "Elza", skin = Color3.fromRGB(230, 185, 150), shirt = Color3.fromRGB(150, 90, 160), pants = Color3.fromRGB(60, 40, 70), hair = Color3.fromRGB(200, 200, 205), dress = true, old = true, speed = 3.5, pause = 12, route = { A(-5.5, 22), A(-5.5, 39), A(5.5, 39), A(5.5, 22) } },
	{ name = "Fábio", skin = Color3.fromRGB(210, 160, 120), shirt = Color3.fromRGB(170, 120, 60), pants = Color3.fromRGB(70, 70, 75), hair = Color3.fromRGB(120, 70, 30), hat = "bandana", speed = 7.5, pause = 5, route = { A(-22, 5.5), A(-46, 5.5), A(-70, 5.5), A(-70, -5.5), A(-46, -5.5), A(-22, -5.5) } },
	{ name = "Guarda Tito", skin = Color3.fromRGB(220, 170, 130), shirt = Color3.fromRGB(40, 70, 150), pants = Color3.fromRGB(50, 50, 60), hair = Color3.fromRGB(60, 40, 20), hat = "helmet", guard = true, speed = 5, pause = 6, route = { A(-2.5, -73), A(2.5, -73), A(2.5, -58), A(-2.5, -58) } },
	{ name = "Guarda Rui", skin = Color3.fromRGB(180, 130, 95), shirt = Color3.fromRGB(40, 70, 150), pants = Color3.fromRGB(50, 50, 60), hair = Color3.fromRGB(30, 25, 20), hat = "helmet", guard = true, speed = 5, pause = 6, route = { A(23, 0), A(72, 0) } },
	{ name = "Lia", skin = Color3.fromRGB(245, 205, 175), shirt = Color3.fromRGB(255, 140, 160), pants = Color3.fromRGB(100, 80, 140), hair = Color3.fromRGB(60, 35, 20), child = true, speed = 8, pause = 3, route = plazaLoop(15, false) },
	{ name = "Téo", skin = Color3.fromRGB(190, 140, 100), shirt = Color3.fromRGB(90, 180, 220), pants = Color3.fromRGB(70, 70, 120), hair = Color3.fromRGB(30, 20, 15), child = true, speed = 8.5, pause = 3, route = plazaLoop(15.5, true) },
	{ name = "Guarda Ivo", skin = Color3.fromRGB(235, 190, 150), shirt = Color3.fromRGB(40, 70, 150), pants = Color3.fromRGB(50, 50, 60), hair = Color3.fromRGB(80, 50, 25), hat = "helmet", guard = true, speed = 5, pause = 6, route = { A(-23, 0), A(-72, 0) } },
}

-- Animais soltos: centro (x, z de projeto) e quanto andam em cada eixo
Townsfolk.Critters = {
	{ kind = "galinha", center = { -48, 28.5 }, roamX = 4, roamZ = 2, color = Color3.fromRGB(245, 240, 230) },
	{ kind = "galinha", center = { -46, 28 }, roamX = 4.5, roamZ = 2.5, color = Color3.fromRGB(190, 120, 60) },
	{ kind = "galinha", center = { -50, 29 }, roamX = 3, roamZ = 2, color = Color3.fromRGB(245, 240, 230) },
	{ kind = "galinha", center = { -44, 30 }, roamX = 3, roamZ = 2, color = Color3.fromRGB(150, 90, 50) },
	{ kind = "gato", center = { -25.5, -48 }, roamX = 1, roamZ = 7, color = Color3.fromRGB(240, 160, 80) },
	{ kind = "gato", center = { 25.5, -40 }, roamX = 1, roamZ = 6, color = Color3.fromRGB(60, 60, 65) },
	{ kind = "cachorro", center = { 0, -17 }, roamX = 6, roamZ = 1.5, color = Color3.fromRGB(170, 120, 75) },
}

-- duração de um trecho e do ciclo inteiro da rota
local function routeInfo(villager)
	if villager._legs then
		return villager._legs, villager._cycle
	end
	local legs = {}
	local total = 0
	local route = villager.route
	for i = 1, #route do
		local from, to = route[i], route[i % #route + 1]
		local walk = (to - from).Magnitude / villager.speed
		table.insert(legs, { from = from, to = to, start = total, walk = walk, pause = villager.pause })
		total += walk + villager.pause
	end
	villager._legs, villager._cycle = legs, total
	return legs, total
end

-- Estado do morador no tempo t: posição, direção, andando?, índice da parada (para escolher a fala)
function Townsfolk.villagerState(index, t)
	local villager = Townsfolk.Villagers[index]
	local legs, cycle = routeInfo(villager)
	local offset = (index * 17.3) % cycle
	local local_t = (t + offset) % cycle
	local stop = math.floor((t + offset) / cycle) * #legs
	for i, leg in legs do
		if local_t < leg.start + leg.walk + leg.pause then
			local direction = leg.to - leg.from
			if local_t < leg.start + leg.walk then
				local alpha = (local_t - leg.start) / leg.walk
				return leg.from:Lerp(leg.to, alpha), direction, true, stop + i
			end
			return leg.to, direction, false, stop + i
		end
	end
	local last = legs[#legs]
	return last.to, last.to - last.from, false, stop + #legs
end

-- Animal: passeio em laço suave (curva de Lissajous) com pausas para bicar/cheirar
function Townsfolk.critterState(index, t)
	local critter = Townsfolk.Critters[index]
	local center = Townsfolk.at(critter.center[1], critter.center[2])
	local speed = if critter.kind == "galinha" then 0.25 else 0.18
	local phase = index * 2.1
	local wander = t * speed + phase
	-- anda em "rajadas": metade do tempo parado
	local burst = math.sin(t * 0.6 + phase)
	local moving = burst > 0
	local smooth = wander - (if moving then 0 else burst * 0.3)
	local rx, rz = critter.roamX * S, critter.roamZ * S
	local position = center + Vector3.new(math.cos(smooth) * rx, 0, math.sin(smooth * 1.37) * rz)
	local ahead = center + Vector3.new(math.cos(smooth + 0.05) * rx, 0, math.sin((smooth + 0.05) * 1.37) * rz)
	return position, ahead - position, moving
end

return Townsfolk
