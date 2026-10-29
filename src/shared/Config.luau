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
-- eventos do mundo aberto (WorldEventService): primeiro chefe de mundo e intervalo entre eles (segundos)
Config.WorldBossFirst = 8 * 60
Config.WorldBossInterval = 25 * 60
Config.InvasionChance = 0.35 -- chance de invasão numa noite (depois do intervalo abaixo)
Config.InvasionGapNights = 2 -- noites sem invasão depois de uma
Config.MountSpeed = 64 -- mapa em escala realista (bem maior): o cavalo compensa
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
Config.GuildContractCount = 3 -- contratos da guilda por dia (Ulf, Salão das Guildas)

-- Salvamento (v2 usa outra chave: o progresso da v1 não é compatível)
Config.DataStoreName = "HunterRPG_v2" -- nome antigo do jogo; NÃO troque (apagaria o progresso de todos)
Config.AutosaveInterval = 60

-- Ranks do Hunter. O nível só LIBERA o exame (exam = id da missão em Quests, dada pela Capitã Lyra);
-- o rank sobe quando o exame é entregue (data.rank = índice nesta lista; PlayerService.promoteRank).
-- title = título ganho na promoção (Progression.Titles)
Config.Ranks = {
	{ name = "E", minLevel = 1, color = Color3.fromRGB(150, 150, 160) },
	{ name = "D", minLevel = 5, color = Color3.fromRGB(80, 200, 100), exam = "exame_d", title = "hunter_d" },
	{ name = "C", minLevel = 10, color = Color3.fromRGB(70, 140, 255), exam = "exame_c", title = "hunter_c" },
	{ name = "B", minLevel = 18, color = Color3.fromRGB(175, 85, 255), exam = "exame_b", title = "hunter_b" },
	{ name = "A", minLevel = 28, color = Color3.fromRGB(255, 170, 40), exam = "exame_a", title = "hunter_a" },
	{ name = "S", minLevel = 40, color = Color3.fromRGB(255, 60, 70), exam = "exame_s", title = "hunter_s" },
}

-- índice do maior rank que o nível permite (saves antigos: o rank vira esse na primeira entrada)
function Config.rankIndexForLevel(level)
	local index = 1
	for i, rank in Config.Ranks do
		if level >= rank.minLevel then
			index = i
		end
	end
	return index
end

-- rank pelo índice guardado em data.rank (atributo "Rank" do jogador)
function Config.rankAt(index)
	return Config.Ranks[math.clamp(math.floor(tonumber(index) or 1), 1, #Config.Ranks)]
end

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
-- Curva bem íngreme (subir é uma conquista): nível 5 ≈ 3,8 mil XP, 10 ≈ 17 mil, 20 ≈ 75 mil,
-- 40 ≈ 330 mil, 59 ≈ 760 mil (antes: 1 mil / 3,4 mil / 11 mil / 38 mil / 75 mil)
function Config.xpToNext(level)
	return math.floor(120 * level ^ 2.15)
end

-- Inimigos bem abaixo do seu nível quase não dão XP (não compensa farmar slime no nível 20):
-- até 2 níveis abaixo = XP cheio; depois perde 20% por nível, até sobrar 5%
Config.XpLevelGapFree = 2
Config.XpLevelGapPenalty = 0.2
Config.XpLevelGapMin = 0.05
function Config.xpLevelFactor(playerLevel, enemyLevel)
	local gap = playerLevel - enemyLevel - Config.XpLevelGapFree
	if gap <= 0 then
		return 1
	end
	return math.max(Config.XpLevelGapMin, 1 - gap * Config.XpLevelGapPenalty)
end

-- ===== VIP (game pass) =====
-- Coloque aqui o ID do game pass "VIP" depois de criá-lo no Creator Hub (0 = ainda não está à venda).
-- No Studio começa sem VIP: use o botão de teste "VIP liga/desliga" no menu da esquerda.
Config.VipGamePassId = 2057651679

-- ===== Administradores =====
-- O dono do jogo já é admin (e, se o jogo for de um grupo, quem tiver cargo >= AdminGroupRank).
-- Para dar acesso a mais alguém, coloque o UserId aqui. No Studio todo mundo é admin (para testar).
Config.Admins = {}
Config.AdminGroupRank = 254

-- ===== Produtos de Robux (developer products) =====
-- Crie cada produto no Creator Hub (Monetização → Produtos de desenvolvedor) e cole o ID em id. Com id = 0
-- o produto ainda não está à venda (no Studio entrega de graça para testar).
-- robux = preço mostrado só enquanto o ID é 0; com o ID preenchido, o jogo mostra o preço do Creator Hub.
-- Passo a passo completo: README, "Publicar no Roblox e vender com Robux".
Config.Products = {
	chest_celestial = { id = 3723432117, robux = 159, kind = "chest", target = "celestial" },
	egg_celestial = { id = 3723432159, robux = 159, kind = "egg", target = "celestial" },
	pass_premium = { id = 3723432246, robux = 399, kind = "pass" }, -- Passe Premium da temporada atual (não é aleatório)
}

-- ===== Fusão de equipamentos (como o cubo do Task Bar Hero) =====
-- count itens da MESMA raridade viram 1 item pelo menos uma raridade acima; jumps = chance de subir
-- 1, 2 ou 3 raridades (somando 1). Ajuste aqui se quiser outras chances.
Config.Fusion = {
	count = 9,
	jumps = {
		{ jump = 1, chance = 0.91 },
		{ jump = 2, chance = 0.08 },
		{ jump = 3, chance = 0.01 },
	},
}

-- ===== Troca entre jogadores =====
Config.TradeMinLevel = 5 -- os dois precisam ter pelo menos este nível
Config.TradeRange = 30 -- studs: distância para convidar e manter a troca aberta
Config.TradeMaxItems = 9 -- itens por lado

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

-- Dificuldade dos inimigos pelo nível deles: as armas crescem com o nível do item, a raridade e o
-- aprimoramento, então vida e dano dos inimigos também crescem (com teto). Nível 1 = valores da tabela.
-- Defs com noScale (chefe de mundo e raide, que já escalam pelo número de jogadores) ficam fora.
Config.EnemyHpPerLevel = 0.08
Config.EnemyHpScaleMax = 2.2
Config.EnemyDamagePerLevel = 0.06
Config.EnemyDamageScaleMax = 1.9
Config.EnemyAttackSpeed = 1.15 -- ataques um pouco mais seguidos (divide o attackCooldown)
function Config.enemyScale(level)
	local l = math.max(0, (level or 1) - 1)
	return math.min(Config.EnemyHpScaleMax, 1 + Config.EnemyHpPerLevel * l), math.min(Config.EnemyDamageScaleMax, 1 + Config.EnemyDamagePerLevel * l)
end
Config.NightEliteMultiplier = 2.5 -- chance de Elite à noite
Config.NightRewardBonus = 0.3 -- XP e ouro extras à noite

-- XP de abate extra no começo do jogo: +100% no nível 1, caindo até 0 no nível 20 (caçar também sobe
-- de nível, não só as missões)
Config.EarlyXpBonus = 1.0
Config.EarlyXpUntil = 20
function Config.earlyXpMult(level)
	return 1 + Config.EarlyXpBonus * math.max(0, (Config.EarlyXpUntil - level) / (Config.EarlyXpUntil - 1))
end

-- Presas do dia: um inimigo de cada faixa dá XP em dobro (mesmo sorteio em todos os servidores)
Config.PreyBands = {
	{ "slime", "lobo", "javali", "caranguejo" },
	{ "goblin", "goblin_arqueiro", "aranha" },
	{ "esqueleto", "esqueleto_mago", "golem" },
}
Config.PreyXpMult = 2
function Config.preyOfDay(time)
	local day = math.floor((time or os.time()) / 86400)
	local list = {}
	for i, band in Config.PreyBands do
		local pick = (day * 7 + i * 13) % #band + 1
		table.insert(list, band[pick])
	end
	return list
end

-- Avisos de novidade: quando o jogador chega no nível, aparece o aviso grande e quem procurar
-- (PlayerService.addXP). Os exames de rank e as habilidades novas têm aviso próprio.
Config.Unlocks = {
	{ level = 5, title = "Masmorra liberada: Toca dos Goblins", text = "O portal fica marcado no mapa (M). Vá em grupo ou entre sozinho." },
	{ level = 5, title = "Troca liberada", text = "Chegue perto de outro jogador e use o botão Trocar." },
	{ level = 8, title = "Arena liberada", text = "Lute contra outros Hunters: abra a Arena no menu da esquerda." },
	{ level = 10, title = "Masmorra liberada: Cripta Esquecida", text = "O portal fica marcado no mapa (M)." },
	{ level = 10, title = "Guildas liberadas", text = "Funde a sua guilda com a Helena, no Salão das Guildas (tecla L)." },
	{ level = 15, title = "Masmorra liberada: Abismo de Pedra", text = "O portal fica marcado no mapa (M)." },
	{ level = 18, title = "Raide liberada: Coração da Estrela", text = "Junte um grupo e enfrente o Devorador de Estrelas no portal da estrela caída." },
	{ level = 20, title = "Missões Lenda liberadas", text = "Itens exóticos: procure os NPCs com missões Lenda (depois de Novos Horizontes)." },
}
Config.NightDropBonus = 0.25 -- chance extra de equipamento à noite

-- Configurações do jogador (valores padrão; o jogador muda na janela de Configurações)
Config.DefaultSettings = {
	volume = 0.8, -- 0 a 1
	musicVolume = 0.5, -- 0 a 1
	ambienceVolume = 0.6, -- 0 a 1 (vento, ondas, grilos, pássaros)
	sensitivity = 1, -- 0.2 a 3
	damageNumbers = true,
	shake = true,
	rhythmBar = true,
	tips = true,
	quality = 2, -- 1 baixa, 2 média, 3 alta (distância de desenho do cenário)
	outlines = true, -- contorno de desenho animado nos personagens e inimigos
}

return Config
