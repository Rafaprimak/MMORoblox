-- Configurações gerais do jogo. Ajuste os números aqui para balancear.
local Config = {}

-- Progressão
Config.MaxLevel = 60
Config.BaseHealth = 100
Config.HealthPerLevel = 12
Config.BaseAttack = 3
Config.AttackPerLevel = 1
Config.SkillPointsPerLevel = 1

-- Recursos
Config.BaseMana = 60
Config.ManaPerLevel = 4
Config.ManaRegen = 3 -- por segundo
Config.BaseStamina = 100
Config.StaminaRegen = 24
Config.StaminaRegenDelay = 0.8

-- Movimento
Config.WalkSpeed = 16
Config.SprintSpeed = 27
Config.SprintDrain = 14 -- estamina por segundo
Config.MountSpeed = 46
Config.MountPrice = 300
Config.DodgeCost = 22
Config.DodgeCooldown = 0.55
Config.DodgeIFrames = 0.35
Config.DodgeSpeed = 62
Config.DodgeDuration = 0.24

-- Combate
Config.CritChance = 0.08
Config.CritMultiplier = 1.8
Config.ComboWindow = 0.75 -- segundos para emendar o próximo golpe
Config.AffinityBonus = 0.15 -- dano extra com arma da sua classe
Config.MasteryDamagePerLevel = 0.02
Config.CombatTimeout = 4

-- Economia / itens
Config.StarterGold = 150
Config.MaxInventory = 60
Config.LootPickupRange = 9
Config.LootAutoCollect = 20
Config.ClassChangePrice = 500

-- Missões
Config.MaxActiveQuests = 12
Config.DailyCount = 3

-- Salvamento (v2 usa outra chave: o progresso da v1 não é compatível)
Config.DataStoreName = "HunterRPG_v2"
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

-- XP para passar do nível atual para o próximo
function Config.xpToNext(level)
	return math.floor(40 * level ^ 1.6)
end

-- XP das perícias (maestrias e profissões)
Config.SkillMaxLevel = 50
function Config.skillXpToNext(level)
	return math.floor(25 * level ^ 1.55)
end

return Config
