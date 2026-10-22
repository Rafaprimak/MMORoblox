-- Classes, habilidades e árvore de talentos.
-- Cada classe tem 4 habilidades básicas (grátis ao atingir o nível) e 4 avançadas (custam 1 ponto para
-- aprender). O jogador escolhe quais 4 levar nas teclas 1 a 4 (loadout). Pontos de talento (1 por nível)
-- servem para aprender, subir rank das habilidades e comprar passivas nos 3 ramos da classe.
local Classes = {}

-- Papéis (como num MMORPG): tanque segura os inimigos, suporte cura e protege, DPS causa dano.
-- "threat" multiplica a ameaça gerada (inimigos atacam quem tem mais ameaça).
Classes.Order = { "guerreiro", "clerigo", "arqueiro", "mago", "assassino" }

Classes.Roles = {
	tank = { name = "Tanque", icon = "🛡️", color = Color3.fromRGB(110, 160, 255), text = "Segura a atenção dos inimigos e protege o grupo." },
	support = { name = "Suporte", icon = "💚", color = Color3.fromRGB(110, 230, 140), text = "Cura, protege e fortalece os aliados." },
	dps = { name = "Dano", icon = "⚔️", color = Color3.fromRGB(255, 110, 90), text = "Derruba os inimigos o mais rápido possível." },
	control = { name = "Controle", icon = "❄️", color = Color3.fromRGB(170, 140, 255), text = "Dano em área e atordoamentos que controlam a luta." },
}

Classes.List = {
	guerreiro = {
		name = "Guerreiro",
		icon = "🛡️",
		color = Color3.fromRGB(230, 80, 60),
		description = "Tanque de linha de frente. Muita vida, provoca os inimigos e protege o grupo.",
		role = "tank",
		threat = 2.0,
		health = 1.35,
		mana = 0.8,
		stamina = 1.2,
		damage = 1.0,
		crit = 0,
		weapons = { sword = true, axe = true, hammer = true },
		starter = "espada_treino",
		abilities = { "investida", "redemoinho", "grito_guerra", "impacto_sismico" },
		extra = { "provocar", "lamina_giratoria", "furia", "terremoto" },
	},
	arqueiro = {
		name = "Arqueiro",
		icon = "🏹",
		color = Color3.fromRGB(90, 200, 90),
		description = "Ataca de longe com flechas e se reposiciona rápido.",
		role = "dps",
		threat = 1.0,
		health = 1.05,
		mana = 1.0,
		stamina = 1.2,
		damage = 1.0,
		crit = 0.05,
		weapons = { bow = true, spear = true },
		starter = "arco_treino",
		abilities = { "tiro_triplo", "salto_tras", "chuva_flechas", "flecha_explosiva" },
		extra = { "flecha_perfurante", "rajada", "foco_cacador", "chuva_fogo" },
	},
	mago = {
		name = "Mago",
		icon = "🔮",
		color = Color3.fromRGB(120, 110, 255),
		description = "Dano mágico em área enorme e congelamentos, mas pouca vida. Muita mana.",
		role = "control",
		threat = 1.0,
		health = 0.9,
		mana = 1.8,
		stamina = 1.0,
		damage = 1.05,
		crit = 0,
		weapons = { staff = true },
		starter = "cajado_treino",
		abilities = { "bola_fogo", "nova_gelida", "teleporte", "meteoro" },
		extra = { "raio_arcano", "anel_fogo", "escudo_arcano", "nevasca" },
	},
	clerigo = {
		name = "Clérigo",
		icon = "😇",
		color = Color3.fromRGB(255, 215, 110),
		description = "Suporte sagrado: cura e protege os aliados por perto e castiga os inimigos com luz.",
		role = "support",
		threat = 0.7,
		health = 1.15,
		mana = 1.5,
		stamina = 1.0,
		damage = 0.85,
		crit = 0,
		weapons = { staff = true, hammer = true },
		starter = "cajado_treino",
		abilities = { "luz_curativa", "martelo_sagrado", "escudo_fe", "julgamento" },
		extra = { "bencao", "santuario", "explosao_sagrada", "milagre" },
	},
	assassino = {
		name = "Assassino",
		icon = "🗡️",
		color = Color3.fromRGB(170, 70, 220),
		description = "Rápido e letal. Críticos, ataques pelas costas e veneno.",
		role = "dps",
		threat = 0.9,
		health = 1.0,
		mana = 1.0,
		stamina = 1.4,
		damage = 1.0,
		crit = 0.1,
		weapons = { katana = true, dagger = true },
		starter = "adaga_treino",
		abilities = { "passo_sombrio", "leque_laminas", "veneno", "execucao" },
		extra = { "estrelas_sombrias", "nevoa_toxica", "frenesi", "danca_laminas" },
	},
}

-- kind define o que o servidor executa (AbilityService)
Classes.Abilities = {
	-- Guerreiro
	investida = { name = "Investida", icon = "💨", unlock = 1, cooldown = 8, mana = 15, kind = "dash", dashSpeed = 75, dashTime = 0.3, radius = 6, dmg = 1.6, stun = 1.0, pose = "thrust", description = "Avança com o escudo, causando dano e atordoando quem estiver no caminho." },
	redemoinho = { name = "Redemoinho", icon = "🌀", unlock = 3, cooldown = 10, mana = 25, kind = "whirl", radius = 11, ticks = 4, interval = 0.3, dmg = 0.8, pose = "spin", description = "Gira com a arma, acertando todos ao redor várias vezes." },
	grito_guerra = { name = "Grito de Guerra", icon = "📯", unlock = 6, cooldown = 22, mana = 20, kind = "buff", damage = 0.3, defense = 0.25, time = 8, pose = "roar", description = "+30% de dano e +25% de defesa por 8 segundos." },
	impacto_sismico = { name = "Impacto Sísmico", icon = "💥", unlock = 10, cooldown = 18, mana = 35, kind = "slam", radius = 16, dmg = 2.6, stun = 1.5, windup = 0.45, pose = "slam", description = "Salta e esmaga o chão, atordoando tudo em uma grande área." },
	-- Arqueiro
	tiro_triplo = { name = "Tiro Triplo", icon = "🎯", unlock = 1, cooldown = 5, mana = 12, kind = "multishot", count = 3, spread = 16, dmg = 1.1, speed = 160, range = 110, radius = 1.2, style = "arrow", pose = "bow", description = "Dispara três flechas em leque." },
	salto_tras = { name = "Salto para Trás", icon = "🦘", unlock = 3, cooldown = 7, mana = 10, kind = "leap", dashSpeed = -65, dashTime = 0.28, dmg = 0.6, radius = 8, pose = "dodge", description = "Salta para trás e solta uma armadilha de espinhos onde estava." },
	chuva_flechas = { name = "Chuva de Flechas", icon = "🌧️", unlock = 6, cooldown = 14, mana = 30, kind = "rain", radius = 12, ticks = 6, interval = 0.35, dmg = 0.7, range = 70, pose = "bowUp", description = "Uma chuva de flechas cai na área mirada." },
	flecha_explosiva = { name = "Flecha Explosiva", icon = "🧨", unlock = 10, cooldown = 12, mana = 30, kind = "projectile", dmg = 2.8, aoe = 10, speed = 130, range = 110, radius = 1.6, style = "fire", pose = "bow", description = "Flecha que explode ao acertar." },
	-- Mago
	bola_fogo = { name = "Bola de Fogo", icon = "🔥", unlock = 1, cooldown = 4, mana = 18, kind = "projectile", dmg = 2.0, aoe = 7, speed = 100, range = 95, radius = 1.8, style = "fire", pose = "cast", description = "Projétil que explode em chamas." },
	nova_gelida = { name = "Nova Gélida", icon = "❄️", unlock = 3, cooldown = 12, mana = 30, kind = "nova", radius = 14, dmg = 1.2, stun = 2.0, style = "ice", pose = "castBig", description = "Congela todos ao redor por 2 segundos." },
	teleporte = { name = "Teleporte", icon = "✨", unlock = 6, cooldown = 8, mana = 20, kind = "blink", distance = 26, pose = "cast", description = "Teleporta-se para a direção mirada." },
	meteoro = { name = "Meteoro", icon = "☄️", unlock = 10, cooldown = 20, mana = 45, kind = "meteor", radius = 16, dmg = 4.0, delay = 1.2, range = 75, pose = "castBig", description = "Invoca um meteoro gigante no ponto mirado." },
	-- Assassino
	passo_sombrio = { name = "Passo Sombrio", icon = "👤", unlock = 1, cooldown = 8, mana = 15, kind = "shadowstep", range = 35, pose = "dodge", description = "Teleporta para as costas do inimigo mais próximo. O próximo golpe é crítico." },
	leque_laminas = { name = "Leque de Lâminas", icon = "🔪", unlock = 3, cooldown = 6, mana = 15, kind = "multishot", count = 5, spread = 40, dmg = 0.8, speed = 130, range = 45, radius = 1.2, style = "dagger", pose = "slashA", description = "Arremessa cinco adagas em leque." },
	veneno = { name = "Lâminas Envenenadas", icon = "🧪", unlock = 6, cooldown = 18, mana = 20, kind = "poisonbuff", time = 10, dps = 0.25, dotTime = 4, pose = "roar", description = "Por 10s, seus golpes envenenam os inimigos." },
	execucao = { name = "Execução", icon = "💀", unlock = 10, cooldown = 14, mana = 25, kind = "execute", range = 9, arc = 90, dmg = 3.0, lowHpBonus = 2.0, pose = "overhead", description = "Golpe devastador. Dano triplicado contra inimigos com menos de 30% de vida." },
	-- Clérigo (suporte): curas e escudos valem para você e para os jogadores perto
	luz_curativa = { name = "Luz Curativa", icon = "💖", unlock = 1, cooldown = 7, mana = 22, kind = "heal", radius = 26, heal = 0.16, pose = "cast", style = "holy", description = "Cura você e os aliados próximos em 16% da vida máxima." },
	martelo_sagrado = { name = "Martelo Sagrado", icon = "🔨", unlock = 3, cooldown = 5, mana = 16, kind = "projectile", dmg = 1.7, aoe = 5, speed = 110, range = 90, radius = 1.6, style = "holy", pose = "cast", description = "Arremessa um martelo de luz que explode no impacto." },
	escudo_fe = { name = "Escudo da Fé", icon = "🔰", unlock = 6, cooldown = 18, mana = 28, kind = "allybuff", buffId = "escudo_fe", radius = 28, defense = 0.4, damage = 0, time = 8, pose = "castBig", style = "holy", description = "+40% de defesa para você e os aliados próximos por 8 segundos." },
	julgamento = { name = "Julgamento", icon = "⚖️", unlock = 10, cooldown = 18, mana = 40, kind = "meteor", radius = 12, dmg = 3.0, delay = 0.8, range = 70, pose = "castBig", style = "holy", description = "Um pilar de luz cai sobre os inimigos." },
	bencao = { name = "Bênção", icon = "🌟", unlock = 4, cooldown = 22, mana = 30, kind = "allybuff", buffId = "bencao", radius = 30, damage = 0.25, defense = 0, time = 10, pose = "roar", style = "holy", advanced = true, description = "+25% de dano para você e os aliados próximos por 10 segundos." },
	santuario = { name = "Santuário", icon = "⛲", unlock = 8, cooldown = 26, mana = 40, kind = "sanctuary", radius = 14, ticks = 6, interval = 1, heal = 0.05, range = 40, pose = "castBig", style = "holy", advanced = true, description = "Cria uma área sagrada que cura 5% por segundo durante 6 segundos." },
	explosao_sagrada = { name = "Explosão Sagrada", icon = "☀", unlock = 13, cooldown = 14, mana = 30, kind = "holynova", radius = 13, dmg = 1.5, heal = 0.08, pose = "roar", style = "holy", advanced = true, description = "Fere os inimigos ao redor e cura os aliados ao mesmo tempo." },
	milagre = { name = "Milagre", icon = "🕊", unlock = 16, cooldown = 60, mana = 60, kind = "heal", radius = 40, heal = 0.6, iframes = 1.5, pose = "castBig", style = "holy", advanced = true, description = "Cura 60% da vida de todos por perto e os protege por 1,5s." },
	-- Guerreiro (tanque)
	provocar = { name = "Provocar", icon = "😤", unlock = 4, cooldown = 12, mana = 15, kind = "taunt", radius = 18, time = 6, defense = 0.3, pose = "roar", style = "roar", advanced = true, description = "Força os inimigos próximos a atacarem você por 6s e ganha +30% de defesa." },
	-- Avançadas (árvore): custam 1 ponto para aprender
	lamina_giratoria = { name = "Lâmina Giratória", icon = "🪓", unlock = 8, cooldown = 7, mana = 18, kind = "projectile", dmg = 1.5, speed = 90, range = 50, radius = 2.5, style = "slash", pose = "slashB", advanced = true, description = "Arremessa uma onda cortante que atravessa a linha." },
	furia = { name = "Fúria", icon = "😡", unlock = 13, cooldown = 30, mana = 30, kind = "buff", buffId = "furia", damage = 0.5, defense = 0, time = 6, pose = "roar", advanced = true, description = "+50% de dano por 6 segundos." },
	terremoto = { name = "Terremoto", icon = "🌋", unlock = 16, cooldown = 24, mana = 50, kind = "slam", radius = 22, dmg = 3.4, stun = 2.0, windup = 0.6, pose = "slam", style = "earth", advanced = true, description = "Esmaga o chão com força total, atingindo uma área gigante." },
	flecha_perfurante = { name = "Flecha Perfurante", icon = "➹", unlock = 4, cooldown = 8, mana = 18, kind = "projectile", dmg = 3.2, speed = 220, range = 140, radius = 1.4, style = "arrowBig", pose = "bow", advanced = true, description = "Uma flecha rapidíssima e de longo alcance." },
	rajada = { name = "Rajada", icon = "🎇", unlock = 8, cooldown = 9, mana = 24, kind = "multishot", count = 7, spread = 30, dmg = 0.75, speed = 170, range = 90, radius = 1.2, style = "arrow", pose = "bow", advanced = true, description = "Sete flechas de uma vez." },
	foco_cacador = { name = "Foco do Caçador", icon = "👁", unlock = 13, cooldown = 26, mana = 25, kind = "buff", buffId = "foco", damage = 0.4, defense = 0, time = 8, pose = "roar", advanced = true, description = "+40% de dano por 8 segundos." },
	chuva_fogo = { name = "Chuva de Fogo", icon = "🌠", unlock = 16, cooldown = 20, mana = 45, kind = "rain", radius = 14, ticks = 8, interval = 0.3, dmg = 0.8, range = 80, style = "fire", pose = "bowUp", advanced = true, description = "Flechas em chamas caem sobre a área." },
	raio_arcano = { name = "Raio Arcano", icon = "⚡", unlock = 4, cooldown = 3, mana = 14, kind = "projectile", dmg = 1.6, aoe = 4, speed = 180, range = 110, radius = 1.4, style = "arcane", pose = "cast", advanced = true, description = "Disparo arcano rápido e barato." },
	anel_fogo = { name = "Anel de Fogo", icon = "⭕", unlock = 8, cooldown = 10, mana = 28, kind = "nova", radius = 13, dmg = 1.8, stun = 0.4, style = "fire", pose = "castBig", advanced = true, description = "Explode em chamas ao seu redor." },
	escudo_arcano = { name = "Escudo Arcano", icon = "🛡", unlock = 13, cooldown = 24, mana = 30, kind = "buff", buffId = "escudo", damage = 0.1, defense = 0.5, time = 8, pose = "cast", advanced = true, description = "+50% de defesa e +10% de dano por 8 segundos." },
	nevasca = { name = "Nevasca", icon = "🌨", unlock = 16, cooldown = 22, mana = 50, kind = "rain", radius = 16, ticks = 8, interval = 0.35, dmg = 0.9, range = 75, style = "ice", pose = "castBig", advanced = true, description = "Uma tempestade de gelo na área mirada." },
	estrelas_sombrias = { name = "Estrelas Sombrias", icon = "✴", unlock = 4, cooldown = 6, mana = 14, kind = "multishot", count = 3, spread = 10, dmg = 1.3, speed = 150, range = 60, radius = 1.2, style = "shadow", pose = "slashA", advanced = true, description = "Três estrelas sombrias certeiras." },
	nevoa_toxica = { name = "Névoa Tóxica", icon = "☁", unlock = 8, cooldown = 14, mana = 22, kind = "nova", radius = 10, dmg = 1.0, stun = 1.0, style = "shadow", pose = "roar", advanced = true, description = "Solta uma névoa que atordoa quem está perto." },
	frenesi = { name = "Frenesi", icon = "💢", unlock = 13, cooldown = 24, mana = 25, kind = "buff", buffId = "frenesi", damage = 0.35, defense = 0, time = 8, pose = "roar", advanced = true, description = "+35% de dano por 8 segundos." },
	danca_laminas = { name = "Dança das Lâminas", icon = "🌪", unlock = 16, cooldown = 16, mana = 35, kind = "whirl", radius = 9, ticks = 6, interval = 0.2, dmg = 0.7, style = "shadow", pose = "spin", advanced = true, description = "Gira como um furacão de lâminas." },
}

Classes.MaxAbilityRank = 5

-- bônus por rank (rank 1 = base)
function Classes.rankMultiplier(rank)
	return 1 + 0.15 * (math.max(rank, 1) - 1)
end

function Classes.rankCooldown(ability, rank)
	return ability.cooldown * (1 - 0.06 * (math.max(rank, 1) - 1))
end


-- ===================== TALENTOS (PASSIVAS) =====================
-- Cada classe tem 3 ramos. Tier 1 está liberado; os seguintes pedem pontos já gastos no ramo:
-- tier 2 = 3 pontos, tier 3 = 6, tier 4 = 10. "stats" é o bônus POR RANK.
-- Chaves de stats: health, mana, stamina, damage, crit, critDamage, attackSpeed, defense, lifesteal,
-- cooldown, abilityDamage, manaRegen, posture, parryWindow, heavyDamage, backstab, regen, xpGain,
-- goldFind, threat (ameaça), healPower (cura)
Classes.TierPoints = { 0, 3, 6, 10 }
Classes.RespecPrice = 500

local function node(id, branch, tier, max, name, icon, stats, text)
	return { id = id, branch = branch, tier = tier, max = max, name = name, icon = icon, stats = stats, text = text }
end

Classes.Branches = {
	guerreiro = {
		{ id = "muralha", name = "Muralha", icon = "🛡️", color = Color3.fromRGB(120, 170, 230), text = "Tanque: vida, defesa e ameaça" },
		{ id = "furia", name = "Fúria", icon = "🔥", color = Color3.fromRGB(240, 90, 60), text = "Dano e quebra de guarda" },
		{ id = "batalha", name = "Batalha", icon = "⚔️", color = Color3.fromRGB(240, 200, 80), text = "Estamina, recarga e grupo" },
	},
	clerigo = {
		{ id = "cura", name = "Cura", icon = "💖", color = Color3.fromRGB(120, 230, 140), text = "Curas mais fortes e mana" },
		{ id = "protecao", name = "Proteção", icon = "🔰", color = Color3.fromRGB(150, 200, 255), text = "Vida, defesa e resistência" },
		{ id = "luz", name = "Luz", icon = "☀", color = Color3.fromRGB(255, 220, 110), text = "Dano sagrado" },
	},
	arqueiro = {
		{ id = "precisao", name = "Precisão", icon = "🎯", color = Color3.fromRGB(240, 200, 80), text = "Críticos e habilidades" },
		{ id = "selvagem", name = "Selvagem", icon = "🐺", color = Color3.fromRGB(100, 200, 100), text = "Dano e velocidade" },
		{ id = "sobrevivencia", name = "Sobrevivência", icon = "🌲", color = Color3.fromRGB(150, 120, 80), text = "Vida, fôlego e exploração" },
	},
	mago = {
		{ id = "chamas", name = "Chamas", icon = "🔥", color = Color3.fromRGB(255, 120, 40), text = "Dano mágico explosivo" },
		{ id = "gelo", name = "Gelo", icon = "❄️", color = Color3.fromRGB(140, 210, 255), text = "Controle e resistência" },
		{ id = "arcano", name = "Arcano", icon = "🔮", color = Color3.fromRGB(180, 110, 255), text = "Mana e recarga" },
	},
	assassino = {
		{ id = "sombras", name = "Sombras", icon = "👤", color = Color3.fromRGB(150, 90, 220), text = "Ataques pelas costas" },
		{ id = "lamina", name = "Lâmina", icon = "🗡️", color = Color3.fromRGB(220, 220, 235), text = "Críticos e velocidade" },
		{ id = "evasao", name = "Evasão", icon = "💨", color = Color3.fromRGB(120, 230, 200), text = "Fôlego e sobrevivência" },
	},
}

Classes.Passives = {
	guerreiro = {
		node("g_vigor", "muralha", 1, 5, "Vigor", "❤️", { health = 0.05 }, "+5% de vida por rank"),
		node("g_ameaca", "muralha", 2, 3, "Presença", "😤", { threat = 0.25, defense = 0.02 }, "+25% de ameaça e +2% de defesa"),
		node("g_aparar", "muralha", 3, 2, "Mestre da Guarda", "✋", { parryWindow = 0.04, defense = 0.03 }, "+0,04s para aparar e +3% de defesa"),
		node("g_inabalavel", "muralha", 4, 1, "Inabalável", "🗿", { health = 0.15, regen = 0.004 }, "+15% de vida e regenera 0,4%/s"),
		node("g_forca", "furia", 1, 5, "Força Bruta", "💪", { damage = 0.03 }, "+3% de dano por rank"),
		node("g_golpe_pesado", "furia", 2, 3, "Golpe Esmagador", "🔨", { heavyDamage = 0.1 }, "+10% de dano do golpe pesado"),
		node("g_quebra", "furia", 3, 3, "Quebra-Guarda", "💥", { posture = 0.15 }, "+15% de dano na postura"),
		node("g_carnificina", "furia", 4, 1, "Carnificina", "🩸", { damage = 0.08, lifesteal = 0.03 }, "+8% de dano e 3% de roubo de vida"),
		node("g_folego", "batalha", 1, 5, "Fôlego", "💨", { stamina = 0.05 }, "+5% de estamina por rank"),
		node("g_tatica", "batalha", 2, 3, "Tática", "📜", { cooldown = 0.04 }, "-4% de recarga das habilidades"),
		node("g_veterano", "batalha", 3, 3, "Veterano", "🎖️", { abilityDamage = 0.08 }, "+8% de dano das habilidades"),
		node("g_lider", "batalha", 4, 1, "Líder de Guerra", "👑", { xpGain = 0.1, goldFind = 0.1 }, "+10% de XP e ouro"),
	},
	clerigo = {
		node("c_graca", "cura", 1, 5, "Graça", "💖", { healPower = 0.06 }, "+6% de cura por rank"),
		node("c_fonte", "cura", 2, 3, "Fonte de Mana", "💧", { manaRegen = 0.12, mana = 0.04 }, "+12% de mana/s e +4% de mana"),
		node("c_prece", "cura", 3, 3, "Prece Rápida", "🙏", { cooldown = 0.05 }, "-5% de recarga"),
		node("c_santo", "cura", 4, 1, "Santo", "🕊", { healPower = 0.25, manaRegen = 0.2 }, "+25% de cura e +20% de mana/s"),
		node("c_fe", "protecao", 1, 5, "Fé Inabalável", "❤️", { health = 0.05 }, "+5% de vida por rank"),
		node("c_armadura", "protecao", 2, 3, "Armadura Abençoada", "🔰", { defense = 0.04 }, "+4% de redução de dano"),
		node("c_renovar", "protecao", 3, 2, "Renovação", "🌿", { regen = 0.003 }, "Regenera 0,3% da vida/s"),
		node("c_guardiao", "protecao", 4, 1, "Guardião", "🛡️", { defense = 0.08, health = 0.1, threat = -0.3 }, "+8% de defesa, +10% de vida e menos ameaça"),
		node("c_brilho", "luz", 1, 5, "Brilho", "✨", { abilityDamage = 0.04 }, "+4% de dano das habilidades"),
		node("c_ira", "luz", 2, 3, "Ira Sagrada", "⚡", { damage = 0.04 }, "+4% de dano"),
		node("c_punicao", "luz", 3, 3, "Punição", "⚖️", { critDamage = 0.12 }, "+12% de dano crítico"),
		node("c_aurora", "luz", 4, 1, "Aurora", "☀", { abilityDamage = 0.15, xpGain = 0.1 }, "+15% de dano das habilidades e +10% de XP"),
	},
	arqueiro = {
		node("a_mira", "precisao", 1, 5, "Mira Firme", "🎯", { crit = 0.012 }, "+1,2% de crítico por rank"),
		node("a_ponta", "precisao", 2, 3, "Ponta Afiada", "🏹", { critDamage = 0.12 }, "+12% de dano crítico"),
		node("a_disparo", "precisao", 3, 3, "Disparo Certeiro", "➹", { abilityDamage = 0.08 }, "+8% de dano das habilidades"),
		node("a_olho", "precisao", 4, 1, "Olho de Águia", "🦅", { crit = 0.05, critDamage = 0.25 }, "+5% de crítico e +25% de dano crítico"),
		node("a_instinto", "selvagem", 1, 5, "Instinto", "🐺", { damage = 0.03 }, "+3% de dano por rank"),
		node("a_ritmo", "selvagem", 2, 3, "Ritmo de Caça", "🥁", { attackSpeed = 0.04 }, "+4% de velocidade de ataque"),
		node("a_matilha", "selvagem", 3, 3, "Matilha", "🐾", { cooldown = 0.04 }, "-4% de recarga"),
		node("a_predador", "selvagem", 4, 1, "Predador", "🦁", { damage = 0.1, lifesteal = 0.02 }, "+10% de dano e 2% de roubo de vida"),
		node("a_couro", "sobrevivencia", 1, 5, "Couro Grosso", "🧥", { health = 0.05 }, "+5% de vida por rank"),
		node("a_folego", "sobrevivencia", 2, 3, "Corredor", "👟", { stamina = 0.06 }, "+6% de estamina"),
		node("a_ervas", "sobrevivencia", 3, 2, "Ervas da Mata", "🌿", { regen = 0.002 }, "Regenera 0,2% da vida/s"),
		node("a_explorador", "sobrevivencia", 4, 1, "Explorador", "🧭", { xpGain = 0.1, goldFind = 0.1 }, "+10% de XP e ouro"),
	},
	mago = {
		node("m_brasa", "chamas", 1, 5, "Brasa", "🔥", { abilityDamage = 0.04 }, "+4% de dano das habilidades"),
		node("m_combustao", "chamas", 2, 3, "Combustão", "💥", { critDamage = 0.12 }, "+12% de dano crítico"),
		node("m_inferno", "chamas", 3, 3, "Inferno", "🌋", { damage = 0.05 }, "+5% de dano"),
		node("m_fenix", "chamas", 4, 1, "Fênix", "🐦", { abilityDamage = 0.15, crit = 0.03 }, "+15% de dano das habilidades e +3% de crítico"),
		node("m_geada", "gelo", 1, 5, "Geada", "❄️", { health = 0.04 }, "+4% de vida por rank"),
		node("m_armadura_gelo", "gelo", 2, 3, "Armadura de Gelo", "🧊", { defense = 0.04 }, "+4% de redução de dano"),
		node("m_inverno", "gelo", 3, 3, "Inverno Eterno", "🌨", { cooldown = 0.04, posture = 0.1 }, "-4% de recarga e +10% de postura"),
		node("m_zero", "gelo", 4, 1, "Zero Absoluto", "💠", { defense = 0.08, health = 0.1 }, "+8% de defesa e +10% de vida"),
		node("m_mente", "arcano", 1, 5, "Mente Vasta", "🧠", { mana = 0.06 }, "+6% de mana por rank"),
		node("m_fluxo", "arcano", 2, 3, "Fluxo Arcano", "🌀", { manaRegen = 0.12 }, "+12% de regeneração de mana"),
		node("m_sabio", "arcano", 3, 3, "Sábio", "📖", { cooldown = 0.05 }, "-5% de recarga"),
		node("m_arquimago", "arcano", 4, 1, "Arquimago", "🔮", { manaRegen = 0.3, xpGain = 0.1 }, "+30% de mana/s e +10% de XP"),
	},
	assassino = {
		node("s_furtivo", "sombras", 1, 5, "Furtivo", "👤", { backstab = 0.06 }, "+6% de dano pelas costas"),
		node("s_veneno", "sombras", 2, 3, "Veneno Forte", "🧪", { abilityDamage = 0.08 }, "+8% de dano das habilidades"),
		node("s_vulto", "sombras", 3, 3, "Vulto", "🌑", { cooldown = 0.05, threat = -0.2 }, "-5% de recarga e menos ameaça"),
		node("s_ceifador", "sombras", 4, 1, "Ceifador", "💀", { backstab = 0.25, critDamage = 0.2 }, "+25% pelas costas e +20% de dano crítico"),
		node("s_fio", "lamina", 1, 5, "Fio da Navalha", "🗡️", { crit = 0.012 }, "+1,2% de crítico por rank"),
		node("s_rapidez", "lamina", 2, 3, "Rapidez", "⚡", { attackSpeed = 0.05 }, "+5% de velocidade de ataque"),
		node("s_sangria", "lamina", 3, 3, "Sangria", "🩸", { lifesteal = 0.015 }, "1,5% de roubo de vida"),
		node("s_mil_cortes", "lamina", 4, 1, "Mil Cortes", "✴", { attackSpeed = 0.1, damage = 0.08 }, "+10% de velocidade e +8% de dano"),
		node("s_reflexo", "evasao", 1, 5, "Reflexos", "💨", { stamina = 0.05 }, "+5% de estamina por rank"),
		node("s_esquiva", "evasao", 2, 3, "Pés Leves", "🦶", { parryWindow = 0.03 }, "+0,03s na janela de aparar"),
		node("s_sobrevivente", "evasao", 3, 3, "Sobrevivente", "❤️", { health = 0.06 }, "+6% de vida"),
		node("s_fantasma", "evasao", 4, 1, "Fantasma", "👻", { defense = 0.08, goldFind = 0.15 }, "+8% de defesa e +15% de ouro"),
	},
}

Classes.PassiveById = {}
for classId, list in Classes.Passives do
	for _, passive in list do
		passive.class = classId
		Classes.PassiveById[passive.id] = passive
	end
end

-- todas as habilidades da classe (básicas + avançadas)
function Classes.allAbilities(classId)
	local class = Classes.List[classId]
	if not class then
		return {}
	end
	local list = table.clone(class.abilities)
	for _, id in class.extra or {} do
		table.insert(list, id)
	end
	return list
end

-- pontos gastos em um ramo
function Classes.branchPoints(classId, talents, branchId)
	local total = 0
	for _, passive in Classes.Passives[classId] or {} do
		if passive.branch == branchId then
			total += talents and talents[passive.id] or 0
		end
	end
	return total
end

-- soma dos bônus das passivas
function Classes.talentStats(classId, talents)
	local total = {}
	for _, passive in Classes.Passives[classId] or {} do
		local rank = talents and talents[passive.id] or 0
		if rank > 0 then
			for key, value in passive.stats do
				total[key] = (total[key] or 0) + value * rank
			end
		end
	end
	return total
end

return Classes
