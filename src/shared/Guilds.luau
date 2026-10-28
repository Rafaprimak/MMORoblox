-- Regras das guildas (dados puros, usados pelo servidor e pela interface).
local Guilds = {}

Guilds.MaxMembers = 30
Guilds.CreateLevel = 10
Guilds.CreateCost = 5000
Guilds.MaxLevel = 20
Guilds.BonusPerLevel = 0.01 -- +1% de XP e de ouro por nível da guilda

Guilds.RankNames = { lider = "Líder", oficial = "Oficial", membro = "Membro" }

-- emblemas que o líder escolhe ao fundar
-- ícones: "crossed-swords", "checked-shield", "crown", "wolf-head", "dragon-head", "lion", "eagle-emblem", "trident", "flame", "star-formation", "skull-crack", "oak"
Guilds.Emblems = { "crossed-swords", "checked-shield", "crown", "wolf-head", "dragon-head", "lion", "eagle-emblem", "trident", "flame", "star-formation", "skull-crack", "oak" }

-- XP da guilda por evento de missão de um membro
Guilds.Points = {
	kill = 1,
	gather = 1,
	craft = 3,
	upgrade = 2,
	enchant = 2,
	dungeonBoss = 30,
	dungeon = 150,
	dungeonSecret = 15,
	worldBoss = 40,
	invasion = 25,
	poi = 10,
	poiChest = 10,
	poiSecret = 20,
	marketSell = 5,
	raid = 200,
	arenaWin = 15,
}

-- metas da semana (sorteadas 3 por semana, as mesmas para todas as guildas)
Guilds.Goals = {
	{ id = "abates", text = "Derrotem 800 inimigos", icon = "crossed-swords", events = { "kill" }, target = 800, gold = 600, chest = "prata" },
	{ id = "chefes", text = "Derrotem 12 chefes de masmorra", icon = "crown", events = { "dungeonBoss" }, target = 12, gold = 900, chest = "prata" },
	{ id = "mundo", text = "Participem de 4 chefes de mundo ou invasões", icon = "dragon-head", events = { "worldBoss", "invasion" }, target = 4, gold = 800, chest = "prata" },
	{ id = "segredos", text = "Abram 12 baús ou segredos de locais", icon = "key", events = { "poiChest", "poiSecret" }, target = 12, gold = 700, chest = "bronze" },
	{ id = "coleta", text = "Coletem 400 recursos", icon = "war-pick", events = { "gather" }, target = 400, gold = 500, chest = "bronze" },
	{ id = "forja", text = "Forjem, aprimorem ou encantem 40 vezes", icon = "anvil-impact", events = { "craft", "upgrade", "enchant" }, target = 40, gold = 600, chest = "bronze" },
	{ id = "mercado", text = "Vendam 15 itens no Mercado", icon = "scales", events = { "marketSell" }, target = 15, gold = 500, chest = "bronze" },
	{ id = "masmorra", text = "Limpem 2 masmorras inteiras (andar 20)", icon = "castle", events = { "dungeon" }, target = 2, gold = 1500, chest = "real" },
}

-- evento → metas que ele faz andar
Guilds.GoalEvents = {}
for _, goal in Guilds.Goals do
	for _, event in goal.events do
		Guilds.GoalEvents[event] = Guilds.GoalEvents[event] or {}
		table.insert(Guilds.GoalEvents[event], goal.id)
	end
end

-- semana (começa segunda-feira 00:00 UTC)
function Guilds.week(time)
	return math.floor((time - 4 * 86400) / 604800)
end

function Guilds.goalsForWeek(week)
	local rng = Random.new(week * 7919 + 13)
	local pool = table.clone(Guilds.Goals)
	local picked = {}
	for _ = 1, 3 do
		table.insert(picked, table.remove(pool, rng:NextInteger(1, #pool)))
	end
	return picked
end

-- XP total para chegar ao nível
function Guilds.xpForLevel(level)
	if level <= 1 then
		return 0
	end
	return math.floor(1500 * (level - 1) ^ 1.7)
end

function Guilds.level(xp)
	local level = 1
	while level < Guilds.MaxLevel and xp >= Guilds.xpForLevel(level + 1) do
		level += 1
	end
	return level
end

return Guilds
