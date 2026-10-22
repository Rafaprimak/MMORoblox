-- NPCs: posição, aparência, falas e serviços.
-- services: forge (criar/aprimorar), enchant (encantar/desmontar), alchemy (poções), shop (loja),
--           classes (trocar classe), stable (montaria), board (missões diárias), chest (baús)
local World = require(script.Parent.World)

local NPCs = {}

-- Posições abaixo estão em coordenadas de design (mapa de -512 a 512); make() converte para studs reais.
local TOWN_X, TOWN_Z = 0, 150

local function facingTown(x, z)
	-- yaw para olhar para o centro da praça
	return math.atan2(-(TOWN_X - x), -(TOWN_Z - z))
end

local function make(def)
	def.yaw = def.yaw or facingTown(def.x, def.z)
	-- NPC dentro da construção: a porta fica na posição original, o NPC "indoor" unidades para dentro
	if def.indoor then
		def.doorX = def.x * World.Scale
		def.doorZ = def.z * World.Scale
		def.x += math.sin(def.yaw) * def.indoor
		def.z += math.cos(def.yaw) * def.indoor
	end
	def.x *= World.Scale
	def.z *= World.Scale
	return def
end

-- Posição relativa ao centro da praça (x, z de projeto) e para onde o NPC olha, em graus:
-- 0 = norte (-Z, rumo ao portal), 180 = sul, -90 = leste (+X), 90 = oeste (-X).
-- As construções da vila (WorldGen/Town) seguem estas mesmas posições.
local function at(x, z, facing, def)
	def.x, def.z = TOWN_X + x, TOWN_Z + z
	def.yaw = math.rad(facing)
	return make(def)
end

NPCs.List = {
	at(-11, -17, 180, {
		id = "lyra",
		name = "Capitã Lyra",
		title = "Guarda da Vila",
		skin = Color3.fromRGB(234, 184, 146),
		shirt = Color3.fromRGB(40, 70, 150),
		pants = Color3.fromRGB(50, 50, 60),
		hat = "helmet",
		greeting = "Hunter! A vila precisa de gente como você. Os monstros estão cada vez mais ousados.",
	}),
	at(-7, -31, -90, {
		id = "bruno",
		name = "Bruno",
		title = "Ferreiro",
		skin = Color3.fromRGB(200, 140, 100),
		shirt = Color3.fromRGB(120, 70, 40),
		pants = Color3.fromRGB(60, 45, 35),
		hat = "bandana",
		services = { "forge" },
		building = "forge",
		indoor = 8.5,
		greeting = "Traga minério e eu transformo em aço. Ou aprenda a forjar você mesmo!",
	}),
	at(7, -30, 90, {
		id = "mira",
		name = "Mira",
		title = "Alquimista",
		skin = Color3.fromRGB(245, 205, 170),
		shirt = Color3.fromRGB(60, 140, 90),
		pants = Color3.fromRGB(40, 70, 50),
		hat = "witch",
		services = { "alchemy" },
		building = "alchemy",
		indoor = 9,
		greeting = "Ervas, cogumelos, flores lunares... tudo vira poção nas mãos certas.",
	}),
	at(31, 7, 0, {
		id = "elric",
		name = "Elric",
		title = "Encantador",
		skin = Color3.fromRGB(230, 200, 180),
		shirt = Color3.fromRGB(90, 50, 160),
		pants = Color3.fromRGB(50, 30, 90),
		hat = "wizard",
		services = { "enchant" },
		building = "tower",
		indoor = 14.5,
		greeting = "A essência mágica dos monstros pode despertar o poder escondido nas armas.",
	}),
	at(31, -7, 180, {
		id = "otto",
		name = "Otto",
		title = "Mercador",
		skin = Color3.fromRGB(190, 130, 90),
		shirt = Color3.fromRGB(180, 140, 40),
		pants = Color3.fromRGB(80, 60, 30),
		hat = "cap",
		services = { "shop", "chest", "pets" },
		building = "emporium",
		indoor = 9,
		greeting = "Poções fresquinhas! E se estiver com sorte, um Baú do Hunter...",
	}),
	at(0, 41, 0, {
		id = "kael",
		name = "Mestre Kael",
		title = "Mestre de Classes",
		skin = Color3.fromRGB(150, 100, 70),
		shirt = Color3.fromRGB(150, 40, 40),
		pants = Color3.fromRGB(40, 40, 40),
		hat = "headband",
		services = { "classes" },
		building = "training",
		greeting = "Todo Hunter precisa dominar sua arma. Treine nos bonecos e fique mais forte.",
	}),
	at(-32, 8, 0, {
		id = "pedro",
		name = "Pedro",
		title = "Cavalariço",
		skin = Color3.fromRGB(225, 170, 130),
		shirt = Color3.fromRGB(110, 90, 60),
		pants = Color3.fromRGB(70, 60, 40),
		hat = "straw",
		services = { "stable" },
		building = "stable",
		greeting = "Um bom cavalo vale mais que mil passos. Quer um?",
	}),
	at(11, -17, 180, {
		id = "quadro",
		name = "Quadro de Recompensas",
		title = "Missões diárias",
		board = true,
		services = { "board" },
		greeting = "Contratos do dia. Renovam à meia-noite (horário do servidor).",
	}),
	make({
		id = "nia",
		name = "Nia",
		title = "Caçadora",
		x = -14,
		z = 22,
		skin = Color3.fromRGB(170, 115, 80),
		shirt = Color3.fromRGB(70, 110, 50),
		pants = Color3.fromRGB(60, 50, 35),
		hat = "hood",
		yaw = math.rad(-30),
		greeting = "Lobos e javalis andam atacando quem passa pela encruzilhada.",
	}),
	make({
		id = "gus",
		name = "Gus",
		title = "Mineiro",
		x = -138,
		z = -190,
		skin = Color3.fromRGB(215, 165, 125),
		shirt = Color3.fromRGB(90, 90, 100),
		pants = Color3.fromRGB(50, 50, 60),
		hat = "miner",
		yaw = math.rad(150),
		greeting = "Essa mina tem ferro do bom... e golems guardando.",
	}),
	make({
		id = "orin",
		name = "Velho Orin",
		title = "Sábio do Lago",
		x = -104,
		z = 160,
		skin = Color3.fromRGB(235, 210, 190),
		shirt = Color3.fromRGB(200, 200, 210),
		pants = Color3.fromRGB(150, 150, 160),
		hat = "wizard",
		yaw = math.rad(-90),
		greeting = "Já viajei por toda esta terra. Ainda há muito a descobrir, jovem.",
	}),
	make({
		id = "tomas",
		name = "Sargento Tomás",
		title = "Guarda do Portão",
		x = 14,
		z = -318,
		skin = Color3.fromRGB(200, 150, 110),
		shirt = Color3.fromRGB(80, 80, 90),
		pants = Color3.fromRGB(50, 50, 55),
		hat = "helmet",
		yaw = math.rad(-90),
		greeting = "Além deste portão fica o covil do Rei Goblin. Só Hunters de Rank C passam.",
	}),
	make({
		id = "sol",
		name = "Marinheira Sol",
		title = "Pescadora",
		x = 52,
		z = 282,
		skin = Color3.fromRGB(160, 110, 80),
		shirt = Color3.fromRGB(230, 230, 240),
		pants = Color3.fromRGB(40, 60, 120),
		hat = "cap",
		yaw = math.rad(160),
		greeting = "Os caranguejos tomaram a praia! Não consigo nem pescar.",
	}),
}

NPCs.ById = {}
for _, npc in NPCs.List do
	NPCs.ById[npc.id] = npc
end

return NPCs
