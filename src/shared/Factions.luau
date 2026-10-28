-- Facções: reputação que sobe com o que o jogador faz (ChronicleService). Cada degrau dá recompensa
-- (ouro, baú e, nos degraus altos, um título).
local Factions = {}

Factions.List = {
	{
		id = "guarda",
		name = "Guarda da Vila",
		icon = "checked-shield",
		color = Color3.fromRGB(110, 160, 255),
		npc = "lyra",
		text = "Protege a Vila Aurora e as estradas. Sobe caçando monstros, defendendo a vila nas invasões e ajudando a Capitã Lyra.",
	},
	{
		id = "circulo",
		name = "Círculo Arcano",
		icon = "crystal-ball",
		color = Color3.fromRGB(190, 130, 255),
		npc = "elric",
		text = "Estudiosos da magia antiga. Sobe descobrindo locais e segredos, encantando itens e ajudando o mago Elric.",
	},
	{
		id = "liga",
		name = "Liga dos Caçadores",
		icon = "wolf-head",
		color = Color3.fromRGB(255, 170, 80),
		npc = "kael",
		text = "Os melhores Hunters do reino. Sobe derrotando chefes de masmorra e de mundo, limpando masmorras inteiras e vencendo na Arena.",
	},
}
Factions.ById = {}
for _, faction in Factions.List do
	Factions.ById[faction.id] = faction
end

-- degraus de reputação (rep total para alcançar) e a recompensa de cada um
Factions.Tiers = {
	{ name = "Neutro", rep = 0 },
	{ name = "Amigável", rep = 500, reward = { gold = 300, chest = "bronze" } },
	{ name = "Honrado", rep = 1500, reward = { gold = 800, chest = "prata", title = "honrado" } },
	{ name = "Reverenciado", rep = 4000, reward = { gold = 1500, chest = "prata" } },
	{ name = "Exaltado", rep = 10000, reward = { gold = 3000, chest = "real", title = "exaltado" } },
}

-- reputação por evento de missão (evento → { facção = pontos })
Factions.Events = {
	kill = { guarda = 1 },
	invasion = { guarda = 80 },
	poi = { circulo = 15 },
	poiSecret = { circulo = 40 },
	poiChest = { circulo = 10 },
	enchant = { circulo = 5 },
	dungeonSecret = { circulo = 20 },
	dungeonBoss = { liga = 25 },
	worldBoss = { liga = 70 },
	dungeon = { liga = 200 },
	raid = { liga = 300, circulo = 100 },
	arenaWin = { liga = 20 },
}

-- missões entregues dão reputação para a facção de quem deu a missão
Factions.QuestGivers = {
	lyra = "guarda", kael = "liga", nia = "liga", pedro = "guarda", bruno = "guarda", mira = "circulo",
	elric = "circulo", gus = "liga", tomas = "guarda", orin = "circulo", sol = "guarda", otto = "guarda",
}
Factions.QuestRep = 100

-- índice do degrau atual
function Factions.tier(rep)
	local index = 1
	for i, tier in Factions.Tiers do
		if rep >= tier.rep then
			index = i
		end
	end
	return index
end

-- título do degrau ("<facção>_<degrau>")
function Factions.titleId(factionId, tierTitle)
	return factionId .. "_" .. tierTitle
end

return Factions
