-- Configurações gerais do jogo. Ajuste os números aqui para balancear.
local Config = {}

-- Progressão
Config.MaxLevel = 60
Config.BaseHealth = 100
Config.HealthPerLevel = 12
-- Fora de combate (sem levar dano por um tempo) a vida volta rápido, para não precisar de poção entre lutas
Config.OutOfCombatDelay = 5 -- segundos sem levar dano
Config.OutOfCombatRegen = 0.05 -- fração da vida máxima por segundo
-- Proteção de iniciante: menos dano recebido nos primeiros níveis (diminui até sumir)
Config.NewbieProtection = { [1] = 0.35, [2] = 0.25, [3] = 0.15, [4] = 0.05 }
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

-- Combate dinâmico
Config.RhythmWindow = 0.32 -- após o fim de um golpe: clicar aqui = "Ritmo!" (bônus)
Config.RhythmBonus = 0.25 -- +25% de dano e postura no golpe no ritmo
Config.FumbleFraction = 0.55 -- clicar antes de 55% do golpe atual quebra o combo (anti-spam)
Config.ParryWindow = 0.22 -- segundos após apertar F em que um golpe é aparado
Config.BlockReduction = 0.75 -- bloquear reduz 75% do dano
Config.BlockStaminaPerDamage = 0.8 -- estamina gasta por ponto de dano bloqueado
Config.BlockWalkSpeed = 9
Config.RiposteTime = 1.6 -- depois de aparar: próximo golpe é crítico e quebra mais postura
Config.PerfectDodgeWindow = 0.2 -- golpe que chega nos primeiros 0,2s da esquiva = esquiva perfeita
Config.PerfectDodgeStamina = 15
Config.HeavyChargeTime = 1.0 -- segundos para carregar o golpe pesado ao máximo
Config.PostureBase = 12 -- postura que um golpe leve (multiplicador 1) tira
Config.StaggerTime = 2.5 -- guarda quebrada: tempo atordoado
Config.StaggerDamageBonus = 0.5 -- +50% de dano em inimigo com a guarda quebrada
Config.CounterBonus = 0.3 -- +30% de dano/postura ao acertar um inimigo se recuperando do próprio ataque

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

-- XP para passar do nível atual para o próximo (curva mais íngreme: subir de nível leva tempo)
function Config.xpToNext(level)
	return math.floor(60 * level ^ 1.75)
end

-- Inimigos bem abaixo do seu nível quase não dão XP (não compensa farmar slime no nível 20):
-- até 3 níveis abaixo = XP cheio; depois perde 15% por nível, até sobrar 10%
Config.XpLevelGapFree = 3
Config.XpLevelGapPenalty = 0.15
Config.XpLevelGapMin = 0.1
function Config.xpLevelFactor(playerLevel, enemyLevel)
	local gap = playerLevel - enemyLevel - Config.XpLevelGapFree
	if gap <= 0 then
		return 1
	end
	return math.max(Config.XpLevelGapMin, 1 - gap * Config.XpLevelGapPenalty)
end

-- ===== VIP (game pass) =====
-- Coloque aqui o ID do game pass "VIP" depois de criá-lo no Creator Hub (0 = ainda não está à venda).
-- No Studio todo mundo é VIP, para testar.
Config.VipGamePassId = 0

-- ===== Presentes por tempo no servidor =====
-- Contam só o tempo seguido no MESMO servidor (trocou de servidor, recomeça). minutes = quando libera.
Config.PlaytimeRewards = {
	{ minutes = 5, gold = 150, consumables = { pocao_vida = 2 } },
	{ minutes = 10, gold = 300, materials = { essencia = 2 } },
	{ minutes = 20, gold = 500, consumables = { pocao_vida = 3, pocao_mana = 3 } },
	{ minutes = 30, chest = "bronze", materials = { essencia = 3 } },
	{ minutes = 45, gold = 1200, consumables = { elixir_forca = 1, pocao_vigor = 2 } },
	{ minutes = 60, chest = "prata", materials = { essencia = 5 } },
	{ minutes = 90, gold = 3000, consumables = { pocao_grande = 3, tonico_pedra = 1 } },
	{ minutes = 120, chest = "real", gold = 5000 },
}

-- XP das perícias (maestrias e profissões)
Config.SkillMaxLevel = 50
function Config.skillXpToNext(level)
	return math.floor(25 * level ^ 1.55)
end

-- Ciclo de dia e noite (minutos reais). À noite os inimigos batem mais forte e as recompensas sobem.
Config.DayMinutes = 14
Config.NightMinutes = 6
Config.StartClock = 9 -- hora em que o servidor começa
Config.NightEnemyDamage = 1.2 -- dano dos inimigos à noite
Config.NightEliteMultiplier = 2.5 -- chance de Elite à noite
Config.NightRewardBonus = 0.3 -- XP e ouro extras à noite
Config.NightDropBonus = 0.25 -- chance extra de equipamento à noite

-- Configurações do jogador (valores padrão; o jogador muda na janela de Configurações)
Config.DefaultSettings = {
	volume = 0.8, -- 0 a 1
	musicVolume = 0.5, -- 0 a 1
	sensitivity = 1, -- 0.2 a 3
	damageNumbers = true,
	shake = true,
	rhythmBar = true,
	tips = true,
	quality = 2, -- 1 baixa, 2 média, 3 alta (distância de desenho do cenário)
}

return Config
