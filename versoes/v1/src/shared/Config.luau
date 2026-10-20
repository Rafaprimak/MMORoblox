-- Configurações gerais do jogo. Ajuste os números aqui para balancear.
local Config = {}

-- Mundo
Config.GroundY = 0.2
Config.HubSpawn = Vector3.new(0, 4, 14)
Config.ArenaSpawn = Vector3.new(0, 4, 612)
Config.PortalLevel = 8

-- Progressão
Config.MaxLevel = 60
Config.BaseHealth = 100
Config.HealthPerLevel = 12
Config.BaseAttack = 3
Config.AttackPerLevel = 1

-- Combate
Config.AttackCooldown = 0.35
Config.AttackRange = 8
Config.CritChance = 0.12
Config.CritMultiplier = 2

-- Economia / itens
Config.StarterGold = 150
Config.ChestCost = 150
Config.MaxInventory = 60
Config.LootPickupRange = 8
Config.LootAutoCollect = 20

-- Salvamento
Config.DataStoreName = "HunterRPG_v1"
Config.AutosaveInterval = 60

Config.Ranks = {
	{ name = "E", minLevel = 1, color = Color3.fromRGB(150, 150, 160) },
	{ name = "D", minLevel = 5, color = Color3.fromRGB(80, 200, 100) },
	{ name = "C", minLevel = 10, color = Color3.fromRGB(70, 140, 255) },
	{ name = "B", minLevel = 18, color = Color3.fromRGB(175, 85, 255) },
	{ name = "A", minLevel = 28, color = Color3.fromRGB(255, 170, 40) },
	{ name = "S", minLevel = 40, color = Color3.fromRGB(255, 60, 70) },
}

function Config.getRank(level)
	local current = Config.Ranks[1]
	for _, rank in Config.Ranks do
		if level >= rank.minLevel then
			current = rank
		end
	end
	return current
end

function Config.getNextRank(level)
	for _, rank in Config.Ranks do
		if rank.minLevel > level then
			return rank
		end
	end
	return nil
end

function Config.getRankByName(name)
	for _, rank in Config.Ranks do
		if rank.name == name then
			return rank
		end
	end
	return Config.Ranks[1]
end

-- XP necessário para passar do nível atual para o próximo
function Config.xpToNext(level)
	return math.floor(40 * level ^ 1.6)
end

return Config
