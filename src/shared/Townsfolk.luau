-- Vida da Vila Aurora: moradores que passeiam, conversam e animais soltos.
-- Tudo é determinístico pelo relógio do servidor (workspace:GetServerTimeNow()): cada cliente calcula
-- sozinho a mesma posição, sem tráfego de rede. Posições em coordenadas de projeto relativas ao centro
-- da praça (ângulo em graus, raio), convertidas por × World.Scale.
local World = require(script.Parent.World)

local Townsfolk = {}

local S = World.Scale
local CX, CZ = World.TownCenter.X, World.TownCenter.Z

-- ponto em volta da praça (ângulo, raio de projeto) → Vector3 em studs reais (Y = chão da vila)
function Townsfolk.point(angle, radius)
	local a = math.rad(angle)
	return Vector3.new(CX + math.cos(a) * radius * S, World.TownHeight, CZ + math.sin(a) * radius * S)
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

-- Moradores: aparência e rota (lista de pontos). Cada trecho anda em "speed" studs/s e para "pause" segundos.
Townsfolk.Villagers = {
	{ name = "Ana", skin = Color3.fromRGB(240, 200, 170), shirt = Color3.fromRGB(200, 80, 90), pants = Color3.fromRGB(70, 50, 40), hair = Color3.fromRGB(90, 50, 30), hat = "scarf", dress = true, speed = 6, pause = 6, route = { P(-60, 15), P(-10, 15), P(40, 21), P(100, 15), P(170, 15), P(230, 21) } },
	{ name = "Beto", skin = Color3.fromRGB(200, 150, 110), shirt = Color3.fromRGB(80, 120, 170), pants = Color3.fromRGB(60, 60, 70), hair = Color3.fromRGB(40, 30, 25), hat = "cap", speed = 7, pause = 4, route = { P(-90, 46), P(-90, 30), P(-90, 18), P(-20, 16), P(60, 16), P(-90, 18) } },
	{ name = "Clara", skin = Color3.fromRGB(250, 215, 190), shirt = Color3.fromRGB(240, 220, 120), pants = Color3.fromRGB(150, 110, 70), hair = Color3.fromRGB(230, 190, 90), dress = true, speed = 5, pause = 8, route = { P(150, 21), P(200, 16), P(260, 16), P(300, 21), P(250, 16) } },
	{ name = "Dido", skin = Color3.fromRGB(150, 100, 70), shirt = Color3.fromRGB(120, 150, 80), pants = Color3.fromRGB(80, 60, 40), hair = Color3.fromRGB(20, 20, 20), hat = "straw", basket = true, speed = 5.5, pause = 7, route = { P(10, 21), P(-40, 21), P(-75, 15), P(-140, 15), P(-40, 16) } },
	{ name = "Elza", skin = Color3.fromRGB(230, 185, 150), shirt = Color3.fromRGB(150, 90, 160), pants = Color3.fromRGB(60, 40, 70), hair = Color3.fromRGB(200, 200, 205), dress = true, old = true, speed = 3.5, pause = 12, route = { P(110, 15), P(160, 16), P(205, 15), P(160, 16) } },
	{ name = "Fábio", skin = Color3.fromRGB(210, 160, 120), shirt = Color3.fromRGB(170, 120, 60), pants = Color3.fromRGB(70, 70, 75), hair = Color3.fromRGB(120, 70, 30), hat = "bandana", speed = 7.5, pause = 5, route = { P(200, 21), P(250, 21), P(-60, 21), P(-90, 40), P(-60, 21) } },
	{ name = "Guarda Tito", skin = Color3.fromRGB(220, 170, 130), shirt = Color3.fromRGB(40, 70, 150), pants = Color3.fromRGB(50, 50, 60), hair = Color3.fromRGB(60, 40, 20), hat = "helmet", guard = true, speed = 5, pause = 5, route = { P(-90, 52), P(-75, 40), P(-90, 28), P(-105, 40) } },
	{ name = "Guarda Rui", skin = Color3.fromRGB(180, 130, 95), shirt = Color3.fromRGB(40, 70, 150), pants = Color3.fromRGB(50, 50, 60), hair = Color3.fromRGB(30, 25, 20), hat = "helmet", guard = true, speed = 5, pause = 6, route = { P(70, 21), P(110, 21), P(140, 16), P(40, 16) } },
	{ name = "Lia", skin = Color3.fromRGB(245, 205, 175), shirt = Color3.fromRGB(255, 140, 160), pants = Color3.fromRGB(100, 80, 140), hair = Color3.fromRGB(60, 35, 20), child = true, speed = 8, pause = 3, route = { P(0, 15), P(60, 15), P(120, 15), P(180, 15), P(240, 15), P(300, 15) } },
	{ name = "Téo", skin = Color3.fromRGB(190, 140, 100), shirt = Color3.fromRGB(90, 180, 220), pants = Color3.fromRGB(70, 70, 120), hair = Color3.fromRGB(30, 20, 15), child = true, speed = 8.5, pause = 3, route = { P(330, 17), P(270, 17), P(210, 17), P(150, 17), P(90, 17), P(30, 17) } },
}

-- Animais soltos: centro (ângulo, raio), raio do passeio e tipo
Townsfolk.Critters = {
	{ kind = "galinha", center = { -150, 44 }, roam = 5, color = Color3.fromRGB(245, 240, 230) },
	{ kind = "galinha", center = { -150, 44 }, roam = 6, color = Color3.fromRGB(190, 120, 60) },
	{ kind = "galinha", center = { -150, 44 }, roam = 4, color = Color3.fromRGB(245, 240, 230) },
	{ kind = "galinha", center = { 60, 46 }, roam = 4, color = Color3.fromRGB(150, 90, 50) },
	{ kind = "gato", center = { 20, 16 }, roam = 9, color = Color3.fromRGB(240, 160, 80) },
	{ kind = "gato", center = { 220, 18 }, roam = 7, color = Color3.fromRGB(60, 60, 65) },
	{ kind = "cachorro", center = { -100, 20 }, roam = 10, color = Color3.fromRGB(170, 120, 75) },
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
	local center = P(critter.center[1], critter.center[2])
	local speed = if critter.kind == "galinha" then 0.25 else 0.18
	local phase = index * 2.1
	local wander = t * speed + phase
	-- anda em "rajadas": metade do tempo parado
	local burst = math.sin(t * 0.6 + phase)
	local moving = burst > 0
	local smooth = wander - (if moving then 0 else burst * 0.3)
	local roam = critter.roam * S
	local position = center + Vector3.new(math.cos(smooth) * roam, 0, math.sin(smooth * 1.37) * roam * 0.7)
	local ahead = center + Vector3.new(math.cos(smooth + 0.05) * roam, 0, math.sin((smooth + 0.05) * 1.37) * roam * 0.7)
	return position, ahead - position, moving
end

return Townsfolk
