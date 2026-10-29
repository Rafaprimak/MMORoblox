-- NPCs: posição, aparência, falas e serviços.
-- services: forge (criar/aprimorar), enchant (encantar/desmontar), alchemy (poções), shop (loja),
--           classes (trocar classe), stable (montaria), board (missões diárias), chest (baús),
--           dungeon (Mercador de Masmorras: chaves, consumíveis e itens exclusivos)
local World = require(script.Parent.World)
local TownPlan = require(script.Parent.TownPlan)

local NPCs = {}

-- Posições abaixo estão em coordenadas de design (mapa de -512 a 512); make() converte para studs reais.
local TOWN_X, TOWN_Z = 0, 150

local function facingTown(x, z)
	-- yaw para olhar para o centro da praça
	return math.atan2(-(TOWN_X - x), -(TOWN_Z - z))
end

-- townRelative: x, z relativos à praça, na escala da vila (World.PropScale); senão, coordenadas de
-- design do mapa (× World.Scale)
local function make(def, townRelative)
	def.yaw = def.yaw or facingTown(def.x, def.z)
	local P = World.PropScale
	local x, z
	if townRelative then
		x, z = World.TownCenter.X + def.x * P, World.TownCenter.Z + def.z * P
	else
		x, z = def.x * World.Scale, def.z * World.Scale
	end
	-- NPC dentro da construção: a porta fica na posição original, o NPC "indoor" unidades para dentro
	if def.indoor then
		def.doorX, def.doorZ = x, z
		x += math.sin(def.yaw) * def.indoor * P
		z += math.cos(def.yaw) * def.indoor * P
	end
	def.x, def.z = x, z
	return def
end

-- Posição relativa ao centro da praça (x, z de projeto) e para onde o NPC olha, em graus:
-- 0 = norte (-Z, rumo ao portal), 180 = sul, -90 = leste (+X), 90 = oeste (-X).
-- As construções da vila (WorldGen/Town) seguem estas mesmas posições.
local function at(x, z, facing, def)
	def.x, def.z = x, z
	def.yaw = math.rad(facing)
	return make(def, true)
end

-- NPC dentro do Salão das Guildas: posição no referencial do salão (World.guildHallPoint), olhando para a
-- porta. startY: o chão é procurado logo abaixo do telhado (cai no piso do salão, não no telhado).
local function hall(id, localX, localZ, def)
	def.id = id
	def.x, def.z = World.guildHallPoint(localX, localZ)
	def.yaw = World.GuildHall.yaw
	def.startY = World.GuildHall.y + 9
	return def
end

-- NPC da vila na posição do traçado (TownPlan.Services)
local function service(id, def)
	local spot = TownPlan.Services[id]
	def.id = id
	return at(spot.x, spot.z, spot.facing, def)
end

NPCs.List = {
	service("lyra", {
		name = "Capitã Lyra",
		title = "Guarda da Vila",
		skin = Color3.fromRGB(234, 184, 146),
		shirt = Color3.fromRGB(40, 70, 150),
		pants = Color3.fromRGB(50, 50, 60),
		hat = "helmet",
		greeting = "Hunter! Você lembra de ontem, não é? Então a vila precisa de você. Os monstros estão cada vez mais ousados.",
	}),
	service("bruno", {
		name = "Bruno",
		title = "Ferreiro",
		skin = Color3.fromRGB(200, 140, 100),
		shirt = Color3.fromRGB(120, 70, 40),
		pants = Color3.fromRGB(60, 45, 35),
		hat = "bandana",
		services = { "forge", "fusion" },
		building = "forge",
		indoor = 8.5,
		greeting = "Traga minério e eu transformo em aço. Ou aprenda a forjar você mesmo!",
	}),
	service("mira", {
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
	service("elric", {
		name = "Elric",
		title = "Arquimago da Torre",
		skin = Color3.fromRGB(230, 200, 180),
		shirt = Color3.fromRGB(90, 50, 160),
		pants = Color3.fromRGB(50, 30, 90),
		hat = "wizard",
		services = { "enchant" },
		building = "tower",
		indoor = 14.5,
		greeting = "Eu, Serafina e Valdrik erguemos o Orbe para salvar este vale. Às vezes me pergunto se não o prendemos também.",
	}),
	service("otto", {
		name = "Otto",
		title = "Mercador",
		skin = Color3.fromRGB(190, 130, 90),
		shirt = Color3.fromRGB(180, 140, 40),
		pants = Color3.fromRGB(80, 60, 30),
		hat = "cap",
		services = { "shop", "chest", "pets", "market" },
		building = "emporium",
		indoor = 9,
		greeting = "Poções fresquinhas! E se estiver com sorte, um Baú do Hunter...",
	}),
	service("kael", {
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
	service("pedro", {
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
	-- dentro do Covil do Mercador (rua do sul, lado oeste)
	service("varg", {
		name = "Varg",
		title = "Mercador de Masmorras",
		skin = Color3.fromRGB(160, 110, 80),
		shirt = Color3.fromRGB(60, 40, 70),
		pants = Color3.fromRGB(40, 35, 40),
		hat = "wide",
		services = { "dungeon" },
		building = "dungeonShop",
		indoor = 10,
		greeting = "Desceu nas masmorras e voltou com saque? Eu troco por chaves, poções e armas que você não acha em lugar nenhum.",
	}),
	hall("helena", -8.5, 34, {
		name = "Helena",
		title = "Mestra das Guildas",
		skin = Color3.fromRGB(225, 180, 140),
		shirt = Color3.fromRGB(40, 75, 100),
		pants = Color3.fromRGB(40, 40, 50),
		hat = "circlet",
		services = { "guild" },
		greeting = "Bem-vindo ao Salão das Guildas! Sozinho você vai longe; com uma guilda, vai mais longe ainda. Quer fundar a sua? Custa 5.000 de ouro e o nível 10.",
	}),
	hall("ulf", 8.5, 34, {
		name = "Ulf",
		title = "Mestre dos Contratos",
		skin = Color3.fromRGB(230, 190, 160),
		shirt = Color3.fromRGB(110, 40, 35),
		pants = Color3.fromRGB(70, 55, 40),
		hat = "viking",
		guildBoard = true,
		greeting = "Contratos da guilda! Só para quem tem guilda: cada contrato entregue aqui rende ouro, XP e pontos para a sua guilda. Renovam à meia-noite.",
	}),
	service("quadro", {
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
		greeting = "Às vezes eu lembro de ontem, sabia? Deve ser a mana da minha mestra, Serafina, dormindo no lago.",
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
