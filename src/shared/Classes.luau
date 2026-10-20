-- Classes e habilidades (teclas 1 a 4).
-- As habilidades destravam por nível e sobem de rank com pontos de habilidade (1 por nível).
local Classes = {}

Classes.Order = { "guerreiro", "arqueiro", "mago", "assassino" }

Classes.List = {
	guerreiro = {
		name = "Guerreiro",
		icon = "🛡️",
		color = Color3.fromRGB(230, 80, 60),
		description = "Tanque de linha de frente. Muita vida, golpes pesados e controle de grupo.",
		health = 1.35,
		mana = 0.8,
		stamina = 1.2,
		damage = 1.0,
		crit = 0,
		weapons = { sword = true, axe = true, hammer = true },
		starter = "espada_treino",
		abilities = { "investida", "redemoinho", "grito_guerra", "impacto_sismico" },
	},
	arqueiro = {
		name = "Arqueiro",
		icon = "🏹",
		color = Color3.fromRGB(90, 200, 90),
		description = "Ataca de longe com flechas e se reposiciona rápido.",
		health = 1.05,
		mana = 1.0,
		stamina = 1.2,
		damage = 1.0,
		crit = 0.05,
		weapons = { bow = true, spear = true },
		starter = "arco_treino",
		abilities = { "tiro_triplo", "salto_tras", "chuva_flechas", "flecha_explosiva" },
	},
	mago = {
		name = "Mago",
		icon = "🔮",
		color = Color3.fromRGB(120, 110, 255),
		description = "Dano mágico em área enorme, mas pouca vida. Muita mana.",
		health = 0.9,
		mana = 1.8,
		stamina = 1.0,
		damage = 1.05,
		crit = 0,
		weapons = { staff = true },
		starter = "cajado_treino",
		abilities = { "bola_fogo", "nova_gelida", "teleporte", "meteoro" },
	},
	assassino = {
		name = "Assassino",
		icon = "🗡️",
		color = Color3.fromRGB(170, 70, 220),
		description = "Rápido e letal. Críticos, ataques pelas costas e veneno.",
		health = 1.0,
		mana = 1.0,
		stamina = 1.4,
		damage = 1.0,
		crit = 0.1,
		weapons = { katana = true, dagger = true },
		starter = "adaga_treino",
		abilities = { "passo_sombrio", "leque_laminas", "veneno", "execucao" },
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
}

Classes.MaxAbilityRank = 5

-- bônus por rank (rank 1 = base)
function Classes.rankMultiplier(rank)
	return 1 + 0.15 * (math.max(rank, 1) - 1)
end

function Classes.rankCooldown(ability, rank)
	return ability.cooldown * (1 - 0.06 * (math.max(rank, 1) - 1))
end

return Classes
