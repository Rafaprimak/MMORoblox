-- Progressão de longo prazo: sequência de login diário, Passe do Hunter (trilha grátis de 50 tiers),
-- conquistas com tiers e títulos, e recompensas por marcos de nível.
-- Recompensas aceitas: gold, materials, consumables, egg (id do ovo), chest (id do baú), title, passXp.
local Progression = {}

-- ===================== LOGIN DIÁRIO (7 dias, recomeça se faltar um dia) =====================
Progression.Login = {
	{ gold = 150 },
	{ consumables = { pocao_vida = 3, pocao_mana = 2 } },
	{ gold = 400 },
	{ materials = { essencia = 3, minerio_ferro = 5 } },
	{ gold = 800, passXp = 300 },
	{ egg = "comum" },
	{ chest = "prata", gold = 1500, passXp = 600 },
}

-- ===================== PASSE DO HUNTER =====================
Progression.PassMaxTier = 50

function Progression.passXpFor(tier)
	return 300 + tier * 40
end

-- XP do passe por atividade
Progression.PassXp = {
	kill = 3,
	killElite = 20,
	killBoss = 200,
	quest = 60,
	daily = 150,
	craft = 15,
	gather = 3,
	chest = 25,
	level = 100,
	parry = 2,
	stagger = 4,
}

local PASS_TITLES = { [25] = "dedicado", [50] = "lenda_trilha" }

function Progression.passReward(tier)
	if PASS_TITLES[tier] then
		return { title = PASS_TITLES[tier], egg = if tier == 50 then "lendario" else "raro", gold = tier * 100 }
	end
	if tier % 10 == 0 then
		return { egg = if tier >= 30 then "raro" else "comum", gold = tier * 60 }
	end
	if tier % 5 == 0 then
		return { chest = if tier < 20 then "bronze" elseif tier < 40 then "prata" else "real" }
	end
	local kind = tier % 4
	if kind == 1 then
		return { gold = 150 + tier * 40 }
	elseif kind == 2 then
		return { consumables = { pocao_vida = 2 + math.floor(tier / 10), pocao_vigor = 1 } }
	elseif kind == 3 then
		return { materials = { essencia = 2 + math.floor(tier / 8), minerio_ferro = 4 } }
	end
	return { gold = 100 + tier * 30, materials = { minerio_mitril = 1 + math.floor(tier / 15) } }
end

-- ===================== CONQUISTAS =====================
-- event = tipo do gancho de missão (QuestHook); target filtra o alvo; mode "max" usa o maior valor
-- recebido (nível, +aprimoramento) em vez de somar.
Progression.Achievements = {
	{ id = "cacador", name = "Caçador", icon = "crossed-swords", event = "kill", tiers = { 50, 500, 5000 }, title = "exterminador", text = "Derrote inimigos" },
	{ id = "regicida", name = "Regicida", icon = "crown", event = "kill", target = "rei_goblin", tiers = { 1, 10, 50 }, title = "regicida", text = "Derrote o Rei Goblin" },
	{ id = "guarda", name = "Mestre da Guarda", icon = "hand", event = "parry", tiers = { 10, 100, 1000 }, title = "muralha", text = "Apare golpes" },
	{ id = "intocavel", name = "Intocável", icon = "wind-slap", event = "perfectDodge", tiers = { 10, 100, 500 }, title = "intocavel", text = "Faça esquivas perfeitas" },
	{ id = "quebra", name = "Quebra-Guardas", icon = "explosion-rays", event = "stagger", tiers = { 10, 100, 1000 }, title = "quebra_guardas", text = "Quebre a guarda dos inimigos" },
	{ id = "ritmo", name = "No Ritmo", icon = "drum", event = "rhythm", tiers = { 50, 500, 5000 }, title = "maestro", text = "Acerte golpes no ritmo" },
	{ id = "coletor", name = "Coletor", icon = "war-pick", event = "gather", tiers = { 50, 500, 3000 }, title = "mao_de_ouro", text = "Colete recursos" },
	{ id = "artesao", name = "Artesão", icon = "anvil-impact", event = "craft", tiers = { 5, 50, 300 }, title = "mestre_artesao", text = "Fabrique itens e poções" },
	{ id = "tesouro", name = "Caçador de Tesouros", icon = "present", event = "chest", tiers = { 5, 50, 250 }, title = "sortudo", text = "Abra baús" },
	{ id = "curandeiro", name = "Curandeiro", icon = "glass-heart", event = "heal", tiers = { 2000, 50000, 500000 }, title = "anjo", text = "Cure vida (sua e dos aliados)" },
	{ id = "provocador", name = "Provocador", icon = "enrage", event = "taunt", tiers = { 20, 300, 3000 }, title = "muro_de_ferro", text = "Provoque inimigos" },
	{ id = "heroi", name = "Herói", icon = "scroll-unfurled", event = "questDone", tiers = { 10, 50, 200 }, title = "heroi", text = "Complete missões e contratos" },
	{ id = "ascensao", name = "Ascensão", icon = "star-formation", event = "level", mode = "max", tiers = { 10, 25, 50 }, title = "rank_s", text = "Alcance níveis" },
	{ id = "domador", name = "Domador", icon = "paw-print", event = "pet", tiers = { 1, 10, 30 }, title = "domador", text = "Consiga pets" },
	{ id = "explorador", name = "Explorador", icon = "compass", event = "poi", tiers = { 3, 6, 9 }, title = "desbravador", text = "Descubra locais de interesse" },
	{ id = "cacador_tesouros", name = "Caça ao Tesouro", icon = "key", event = "poiChest", tiers = { 2, 5, 9 }, title = "achador", text = "Abra baús escondidos nos locais" },
	{ id = "perfeccionista", name = "Perfeccionista", icon = "upgrade", event = "upgradeTo", mode = "max", tiers = { 5, 8, 10 }, title = "perfeccionista", text = "Aprimore um item" },
	{ id = "masmorreiro", name = "Senhor das Profundezas", icon = "castle", event = "dungeonBoss", tiers = { 1, 12, 60 }, title = "senhor_profundezas", text = "Derrote chefes de masmorra" },
	{ id = "conquistador", name = "Conquistador", icon = "trophy", event = "dungeon", tiers = { 1, 3, 10 }, title = "conquistador", text = "Chegue ao fim dos 20 andares" },
	{ id = "segredos", name = "Olho Atento", icon = "key", event = "dungeonSecret", tiers = { 1, 10, 40 }, title = "olho_atento", text = "Ache baús secretos nas masmorras" },
	{ id = "desafiante", name = "Desafiante", icon = "star-formation", event = "dungeonObjective", tiers = { 5, 30, 120 }, title = "desafiante", text = "Cumpra objetivos extras nas masmorras" },
}

Progression.AchievementById = {}
for _, achievement in Progression.Achievements do
	Progression.AchievementById[achievement.id] = achievement
end

-- recompensa de cada tier da conquista (o último também dá o título)
Progression.AchievementRewards = {
	{ gold = 250, passXp = 150 },
	{ gold = 1500, passXp = 500 },
	{ gold = 8000, passXp = 1500 },
}

-- ===================== MARCOS DE NÍVEL =====================
Progression.LevelRewards = {
	[3] = { consumables = { pocao_vida = 5 } },
	[5] = { egg = "comum" },
	[8] = { chest = "bronze", gold = 500 },
	[10] = { chest = "prata" },
	[15] = { gold = 3000, materials = { essencia = 6 } },
	[20] = { chest = "real" },
	[25] = { egg = "raro" },
	[30] = { chest = "real", gold = 6000 },
	[40] = { egg = "lendario" },
	[50] = { chest = "real", gold = 20000, title = "veterano" },
	[60] = { egg = "lendario", title = "imortal" },
}

-- ===================== TÍTULOS =====================
Progression.Titles = {
	novato = { name = "Novato", color = Color3.fromRGB(200, 200, 210) },
	dedicado = { name = "Caçador Dedicado", color = Color3.fromRGB(120, 200, 255) },
	lenda_trilha = { name = "Lenda da Trilha", color = Color3.fromRGB(255, 200, 60) },
	exterminador = { name = "Exterminador", color = Color3.fromRGB(255, 80, 70) },
	regicida = { name = "Regicida", color = Color3.fromRGB(255, 210, 80) },
	senhor_profundezas = { name = "Senhor das Profundezas", color = Color3.fromRGB(180, 120, 255) },
	conquistador = { name = "Conquistador de Masmorras", color = Color3.fromRGB(255, 120, 60) },
	olho_atento = { name = "Olho Atento", color = Color3.fromRGB(150, 230, 255) },
	desafiante = { name = "Desafiante", color = Color3.fromRGB(255, 230, 120) },
	muralha = { name = "Muralha Viva", color = Color3.fromRGB(140, 180, 255) },
	intocavel = { name = "Intocável", color = Color3.fromRGB(120, 230, 255) },
	quebra_guardas = { name = "Quebra-Guardas", color = Color3.fromRGB(255, 160, 60) },
	maestro = { name = "Maestro da Lâmina", color = Color3.fromRGB(140, 255, 160) },
	mao_de_ouro = { name = "Mão de Ouro", color = Color3.fromRGB(255, 220, 90) },
	mestre_artesao = { name = "Mestre Artesão", color = Color3.fromRGB(255, 150, 60) },
	sortudo = { name = "Sortudo", color = Color3.fromRGB(120, 255, 120) },
	anjo = { name = "Anjo da Guarda", color = Color3.fromRGB(255, 240, 170) },
	muro_de_ferro = { name = "Muro de Ferro", color = Color3.fromRGB(170, 180, 200) },
	heroi = { name = "Herói da Aurora", color = Color3.fromRGB(255, 190, 120) },
	rank_s = { name = "Hunter Rank S", color = Color3.fromRGB(255, 60, 70) },
	domador = { name = "Domador de Feras", color = Color3.fromRGB(150, 255, 200) },
	perfeccionista = { name = "Perfeccionista", color = Color3.fromRGB(200, 150, 255) },
	desbravador = { name = "Desbravador", color = Color3.fromRGB(150, 220, 140) },
	achador = { name = "Achador de Tesouros", color = Color3.fromRGB(255, 200, 90) },
	veterano = { name = "Veterano", color = Color3.fromRGB(230, 200, 150) },
	imortal = { name = "Imortal", color = Color3.fromRGB(255, 255, 255), rainbow = true },
}

-- texto curto de uma recompensa (para a interface)
function Progression.rewardText(reward, items, pets, chests)
	local parts = {}
	if reward.gold then
		table.insert(parts, ("%d ouro"):format(reward.gold))
	end
	for id, count in reward.materials or {} do
		local def = items and items.Materials[id]
		table.insert(parts, ("%s x%d"):format(if def then def.icon else id, count))
	end
	for id, count in reward.consumables or {} do
		local def = items and items.Consumables[id]
		table.insert(parts, ("%s x%d"):format(if def then def.icon else id, count))
	end
	if reward.egg then
		local egg = pets and pets.Eggs[reward.egg]
		table.insert(parts, if egg then egg.name else "Ovo")
	end
	if reward.chest then
		local chest = chests and chests.List[reward.chest]
		table.insert(parts, if chest then chest.name else "Baú")
	end
	if reward.title then
		local title = Progression.Titles[reward.title]
		table.insert(parts, "price-tag" .. (if title then title.name else reward.title))
	end
	if reward.passXp then
		table.insert(parts, ("%d XP do passe"):format(reward.passXp))
	end
	return table.concat(parts, "  ")
end

return Progression
