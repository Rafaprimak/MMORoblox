-- Inimigos e acampamentos espalhados pelo mundo.
-- behavior:
--   melee   = corre até você e ataca
--   ranged  = mantém distância e atira projéteis
--   charger = de vez em quando prepara uma investida (com aviso no chão)
--   slammer = lento; prepara pancadas em área (com aviso no chão)
--   boss    = mistura investida, pancada em área e invoca ajudantes
--   dummy   = boneco de treino (não se move; ataca devagar para treinar aparar/esquivar)
-- posture: resistência da guarda (opcional; padrão = 8 * raiz(hp)). Encheu = guarda quebrada.
local Enemies = {}

local function essence(chance)
	return { id = "essencia", chance = chance, min = 1, max = 1 }
end

Enemies.Defs = {
	boneco = {
		-- ataca devagar (com aviso) quem chega perto, para treinar aparar (F) e esquivar (Q)
		name = "Boneco de Treino", level = 1, hp = 999999, damage = 2, speed = 0, attackCooldown = 3.2, attackRange = 5, posture = 120,
		xp = 0, gold = { 0, 0 }, dropChance = 0, pool = {}, drops = {},
		aggro = 0, radius = 1.6, model = "dummy", color = Color3.fromRGB(200, 170, 110), behavior = "dummy", regen = 1,
	},
	slime = {
		name = "Slime", level = 1, hp = 35, damage = 4, speed = 9, attackCooldown = 1.6, attackRange = 4,
		xp = 12, gold = { 2, 5 }, dropChance = 0.12, pool = { "espada_cobre", "adaga_cobre", "arco_curto", "cajado_aprendiz", "elmo_couro", "botas_couro", "anel_cobre" },
		drops = { { id = "gosma", chance = 0.75, min = 1, max = 2 }, essence(0.02) },
		aggro = 18, radius = 1.6, model = "slime", color = Color3.fromRGB(110, 230, 120), behavior = "melee",
	},
	lobo = {
		name = "Lobo", level = 3, hp = 70, damage = 8, speed = 17, attackCooldown = 1.0, attackRange = 4.5,
		xp = 25, gold = { 3, 7 }, dropChance = 0.12, pool = { "lanca_cacador", "adaga_cobre", "colete_couro", "katana_errante", "botas_couro", "amuleto_cobre", "maca_peregrino" },
		drops = { { id = "couro", chance = 0.5, min = 1, max = 1 }, { id = "presa", chance = 0.45, min = 1, max = 1 }, essence(0.03) },
		aggro = 32, radius = 1.6, model = "wolf", color = Color3.fromRGB(120, 120, 130), behavior = "melee",
	},
	javali = {
		name = "Javali", level = 4, hp = 120, damage = 14, speed = 12, attackCooldown = 1.4, attackRange = 4.5,
		xp = 32, gold = { 4, 8 }, dropChance = 0.12, pool = { "machado_lenhador", "martelo_pedra", "colete_couro", "elmo_couro", "amuleto_vida" },
		drops = { { id = "couro", chance = 0.8, min = 1, max = 2 }, essence(0.03) },
		aggro = 26, radius = 2, model = "boar", color = Color3.fromRGB(110, 75, 50), behavior = "charger",
		charge = { speed = 55, time = 0.6, windup = 0.9, damage = 22, cooldown = 6 },
	},
	caranguejo = {
		name = "Caranguejo", level = 5, hp = 200, damage = 10, speed = 8, attackCooldown = 1.3, attackRange = 4.5,
		xp = 36, gold = { 5, 10 }, dropChance = 0.14, pool = { "lanca_cacador", "cota_malha", "martelo_pedra", "botas_ferro", "anel_cobre" },
		drops = { { id = "carapaca", chance = 0.6, min = 1, max = 1 }, essence(0.04) },
		aggro = 20, radius = 2, model = "crab", color = Color3.fromRGB(230, 90, 60), behavior = "melee", defense = 0.3,
	},
	goblin = {
		name = "Goblin", level = 6, hp = 170, damage = 11, speed = 14, attackCooldown = 1.1, attackRange = 4.5,
		xp = 45, gold = { 8, 15 }, dropChance = 0.15, pool = { "espada_cobre", "machado_lenhador", "lanca_cacador", "katana_errante", "manto_aprendiz", "capuz_aprendiz", "sandalias_monge", "maca_peregrino" },
		drops = { { id = "pano", chance = 0.55, min = 1, max = 2 }, essence(0.05) },
		aggro = 32, radius = 1.4, model = "goblin", color = Color3.fromRGB(100, 170, 60), behavior = "melee",
	},
	goblin_arqueiro = {
		name = "Goblin Arqueiro", level = 6, hp = 120, damage = 9, speed = 13, attackCooldown = 2.0, attackRange = 40,
		xp = 45, gold = { 8, 15 }, dropChance = 0.15, pool = { "arco_curto", "adaga_cobre", "colete_couro", "botas_vento", "amuleto_lua" },
		drops = { { id = "pano", chance = 0.5, min = 1, max = 1 }, { id = "madeira", chance = 0.4, min = 1, max = 2 }, essence(0.05) },
		aggro = 40, radius = 1.4, model = "goblinArcher", color = Color3.fromRGB(90, 150, 70), behavior = "ranged",
		projectile = { speed = 70, damage = 9, style = "enemyArrow", keepDistance = 22 },
	},
	aranha = {
		name = "Aranha Gigante", level = 8, hp = 230, damage = 14, speed = 18, attackCooldown = 1.0, attackRange = 5,
		xp = 60, gold = { 10, 18 }, dropChance = 0.15, pool = { "presas_gemeas", "katana_errante", "couraca_sombria", "capuz_sombrio", "anel_vampiro" },
		drops = { { id = "seda", chance = 0.6, min = 1, max = 2 }, essence(0.06) },
		aggro = 30, radius = 2.2, model = "spider", color = Color3.fromRGB(50, 40, 55), behavior = "melee",
	},
	esqueleto = {
		name = "Esqueleto", level = 11, hp = 420, damage = 20, speed = 14, attackCooldown = 1.0, attackRange = 4.5,
		xp = 120, gold = { 18, 30 }, dropChance = 0.16, pool = { "lamina_guardiao", "machado_berserker", "cota_malha", "katana_errante", "elmo_ferro", "botas_ferro", "anel_guardiao" },
		drops = { { id = "osso", chance = 0.6, min = 1, max = 2 }, essence(0.08) },
		aggro = 34, radius = 1.4, model = "skeleton", color = Color3.fromRGB(230, 225, 205), behavior = "melee",
	},
	esqueleto_mago = {
		name = "Esqueleto Mago", level = 12, hp = 300, damage = 18, speed = 12, attackCooldown = 2.2, attackRange = 45,
		xp = 130, gold = { 20, 32 }, dropChance = 0.18, pool = { "cajado_arcano", "manto_arcano", "cajado_aprendiz", "cetro_luz", "amuleto_sabio", "coroa_arcana" },
		drops = { { id = "osso", chance = 0.5, min = 1, max = 1 }, essence(0.15) },
		aggro = 45, radius = 1.4, model = "skeletonMage", color = Color3.fromRGB(210, 210, 230), behavior = "ranged",
		projectile = { speed = 60, damage = 18, style = "enemyMagic", keepDistance = 26, aoe = 5 },
	},
	golem = {
		name = "Golem de Pedra", level = 14, hp = 1500, damage = 30, speed = 8, attackCooldown = 2.0, attackRange = 6,
		xp = 420, gold = { 40, 70 }, dropChance = 0.35, pool = { "martelo_gigante", "armadura_placas", "machado_berserker", "elmo_ferro", "grevas_dragao", "martelo_trovao" },
		drops = { { id = "nucleo_golem", chance = 0.5, min = 1, max = 1 }, { id = "minerio_ferro", chance = 0.8, min = 2, max = 4 }, essence(0.3) },
		aggro = 28, radius = 3.2, model = "golem", color = Color3.fromRGB(120, 115, 110), behavior = "slammer", defense = 0.2,
		slam = { radius = 12, windup = 1.1, damage = 45, cooldown = 6 },
	},
	rei_goblin = {
		name = "Rei Goblin", level = 16, hp = 16000, damage = 32, speed = 12, attackCooldown = 1.3, attackRange = 9,
		xp = 3000, gold = { 300, 500 }, dropChance = 1, drops = {
			{ id = "coroa_goblin", chance = 1, min = 1, max = 1 },
			{ id = "essencia", chance = 1, min = 3, max = 6 },
			{ id = "minerio_mitril", chance = 0.6, min = 1, max = 3 },
		},
		equipDrops = 3, minRarity = 3,
		pool = { "katana_sombria", "martelo_gigante", "armadura_placas", "lanca_draconica", "arco_longo", "cajado_arcano", "presas_gemeas", "espada_runica", "machado_tempestade", "lanca_celestial", "katana_lua", "adagas_vazio", "arco_fenix", "cajado_estelar", "armadura_dragao", "elmo_dragao", "amuleto_dragao", "anel_rei", "anel_tempestade" },
		aggro = 80, radius = 4.5, model = "goblinKing", color = Color3.fromRGB(80, 140, 45), behavior = "boss", scale = 2.8,
		charge = { speed = 60, time = 0.8, windup = 1.0, damage = 40, cooldown = 9 },
		slam = { radius = 16, windup = 1.2, damage = 55, cooldown = 7 },
		summon = { enemy = "goblin", count = 3, cooldown = 25 },
		leash = 140,
		uniques = { "coroa_rei_goblin" },
	},
	-- ===== CHEFES DE CAMPO (nomeados): um por região, voltam de tempos em tempos e sempre deixam cair
	-- algo Raro ou melhor (minRarity 3), com chance das peças dos conjuntos do mundo (Items.Sets) =====
	presa_negra = {
		name = "Presa-Negra, o Lobo Alfa", level = 5, hp = 1400, damage = 13, speed = 18, attackCooldown = 1.0, attackRange = 5.5,
		xp = 450, gold = { 60, 100 }, dropChance = 1, equipDrops = 1, minRarity = 3,
		pool = { "elmo_alfa", "pele_alfa", "botas_alfa", "presa_alfa", "lanca_cacador", "katana_errante" },
		drops = { { id = "couro", chance = 1, min = 2, max = 4 }, { id = "presa", chance = 1, min = 2, max = 3 }, essence(0.5) },
		aggro = 40, radius = 2.4, model = "wolf", color = Color3.fromRGB(35, 32, 40), behavior = "boss", scale = 1.9,
		charge = { speed = 60, time = 0.5, windup = 0.8, damage = 20, cooldown = 7 },
		leash = 90, field = true,
	},
	rasga_terra = {
		name = "Rasga-Terra, o Javali Ancião", level = 6, hp = 1900, damage = 16, speed = 13, attackCooldown = 1.4, attackRange = 5.5,
		xp = 550, gold = { 70, 120 }, dropChance = 1, equipDrops = 1, minRarity = 3,
		pool = { "elmo_alfa", "pele_alfa", "botas_alfa", "presa_alfa", "machado_lenhador", "martelo_pedra" },
		drops = { { id = "couro", chance = 1, min = 3, max = 5 }, essence(0.5) },
		aggro = 34, radius = 2.8, model = "boar", color = Color3.fromRGB(80, 55, 40), behavior = "boss", scale = 2.0,
		charge = { speed = 62, time = 0.7, windup = 0.9, damage = 30, cooldown = 6 },
		slam = { radius = 10, windup = 1.1, damage = 24, cooldown = 9 },
		leash = 90, field = true,
	},
	tenaz = {
		name = "Tenaz, o Caranguejo Rei", level = 7, hp = 2600, damage = 15, speed = 9, attackCooldown = 1.3, attackRange = 6,
		xp = 650, gold = { 80, 140 }, dropChance = 1, equipDrops = 1, minRarity = 3,
		pool = { "elmo_alfa", "pele_alfa", "botas_alfa", "presa_alfa", "cota_malha", "botas_ferro", "anel_cobre" },
		drops = { { id = "carapaca", chance = 1, min = 3, max = 5 }, essence(0.5) },
		aggro = 28, radius = 3, model = "crab", color = Color3.fromRGB(170, 40, 50), behavior = "boss", scale = 2.2, defense = 0.35,
		slam = { radius = 11, windup = 1.1, damage = 26, cooldown = 8 },
		leash = 80, field = true,
	},
	olho_vermelho = {
		name = "Olho-Vermelho, Chefe de Bando", level = 9, hp = 3200, damage = 18, speed = 14, attackCooldown = 1.1, attackRange = 6,
		xp = 900, gold = { 110, 180 }, dropChance = 1, equipDrops = 1, minRarity = 3,
		pool = { "capuz_bando", "gibao_bando", "botas_bando", "anel_bando", "espada_cobre", "presas_gemeas", "arco_curto" },
		drops = { { id = "pano", chance = 1, min = 3, max = 5 }, essence(0.6) },
		aggro = 45, radius = 2, model = "goblin", color = Color3.fromRGB(150, 60, 45), behavior = "boss", scale = 1.8,
		charge = { speed = 55, time = 0.6, windup = 0.9, damage = 26, cooldown = 7 },
		summon = { enemy = "goblin_arqueiro", count = 2, cooldown = 25 },
		leash = 90, field = true,
	},
	tecela = {
		name = "Tecelã Cinzenta", level = 10, hp = 3800, damage = 19, speed = 18, attackCooldown = 1.0, attackRange = 6,
		xp = 1050, gold = { 120, 200 }, dropChance = 1, equipDrops = 1, minRarity = 3,
		pool = { "capuz_bando", "gibao_bando", "botas_bando", "anel_bando", "couraca_sombria", "capuz_sombrio", "anel_vampiro" },
		drops = { { id = "seda", chance = 1, min = 3, max = 6 }, essence(0.6) },
		aggro = 36, radius = 3, model = "spider", color = Color3.fromRGB(130, 130, 140), behavior = "boss", scale = 2.0,
		charge = { speed = 60, time = 0.5, windup = 0.8, damage = 24, cooldown = 8 },
		summon = { enemy = "aranha", count = 2, cooldown = 28 },
		leash = 90, field = true,
	},
	sir_ossario = {
		name = "Sir Ossário, o Cavaleiro Caído", level = 13, hp = 6000, damage = 26, speed = 14, attackCooldown = 1.1, attackRange = 6,
		xp = 1600, gold = { 180, 280 }, dropChance = 1, equipDrops = 1, minRarity = 3,
		pool = { "elmo_caido", "couraca_caida", "grevas_caidas", "amuleto_caido", "lamina_guardiao", "machado_berserker", "elmo_ferro" },
		drops = { { id = "osso", chance = 1, min = 3, max = 6 }, essence(0.8) },
		aggro = 40, radius = 2, model = "skeleton", color = Color3.fromRGB(150, 160, 185), behavior = "boss", scale = 1.8, defense = 0.15,
		charge = { speed = 55, time = 0.6, windup = 1.0, damage = 34, cooldown = 8 },
		slam = { radius = 11, windup = 1.2, damage = 36, cooldown = 9 },
		leash = 90, field = true,
	},
	musgo_antigo = {
		name = "Musgo-Antigo, o Golem Ancestral", level = 15, hp = 9000, damage = 34, speed = 8, attackCooldown = 2.0, attackRange = 7,
		xp = 2200, gold = { 220, 340 }, dropChance = 1, equipDrops = 2, minRarity = 3,
		pool = { "elmo_caido", "couraca_caida", "grevas_caidas", "amuleto_caido", "martelo_gigante", "armadura_placas", "grevas_dragao" },
		drops = { { id = "nucleo_golem", chance = 1, min = 1, max = 2 }, { id = "minerio_ferro", chance = 1, min = 4, max = 7 }, essence(1) },
		aggro = 30, radius = 4, model = "golem", color = Color3.fromRGB(85, 115, 70), behavior = "boss", scale = 1.6, defense = 0.25,
		slam = { radius = 14, windup = 1.2, damage = 52, cooldown = 6 },
		leash = 80, field = true,
	},
	-- ===== chefes das masmorras (só aparecem dentro delas; ver Dungeons) =====
	capitao_goblin = {
		name = "Capitão Goblin", level = 8, hp = 2600, damage = 16, speed = 13, attackCooldown = 1.3, attackRange = 6,
		xp = 700, gold = { 80, 140 }, dropChance = 1, equipDrops = 1, minRarity = 2,
		pool = { "espada_cobre", "machado_lenhador", "lanca_cacador", "katana_errante", "presas_gemeas", "colete_couro", "elmo_couro", "botas_vento", "amuleto_lua" },
		drops = { { id = "pano", chance = 1, min = 2, max = 4 }, essence(0.6) },
		aggro = 60, radius = 3, model = "goblinKing", color = Color3.fromRGB(150, 110, 60), behavior = "boss", scale = 1.8,
		charge = { speed = 50, time = 0.7, windup = 1.0, damage = 24, cooldown = 8 },
		slam = { radius = 11, windup = 1.2, damage = 28, cooldown = 8 },
		summon = { enemy = "goblin", count = 2, cooldown = 22 },
		leash = 90, dungeon = true,
		uniques = { "adagas_capitao" },
	},
	senhor_ossos = {
		name = "Senhor dos Ossos", level = 12, hp = 6000, damage = 28, speed = 12, attackCooldown = 1.3, attackRange = 7,
		xp = 2400, gold = { 220, 380 }, dropChance = 1, equipDrops = 2, minRarity = 3,
		pool = { "lamina_guardiao", "machado_berserker", "cajado_arcano", "manto_arcano", "cetro_luz", "coroa_arcana", "elmo_ferro", "anel_guardiao", "amuleto_sabio", "katana_sombria" },
		drops = { { id = "osso", chance = 1, min = 3, max = 6 }, { id = "essencia", chance = 1, min = 2, max = 4 } },
		aggro = 70, radius = 3.4, model = "skeletonMage", color = Color3.fromRGB(190, 200, 235), behavior = "boss", scale = 2.4,
		charge = { speed = 55, time = 0.7, windup = 1.0, damage = 36, cooldown = 9 },
		slam = { radius = 14, windup = 1.2, damage = 46, cooldown = 7 },
		summon = { enemy = "esqueleto", count = 2, cooldown = 24 },
		leash = 110, dungeon = true,
		uniques = { "cajado_vazio" },
	},
	rainha_aranha = {
		name = "Rainha Aranha", level = 10, hp = 5000, damage = 22, speed = 17, attackCooldown = 1.1, attackRange = 7,
		xp = 1400, gold = { 140, 240 }, dropChance = 1, equipDrops = 1, minRarity = 3,
		pool = { "presas_gemeas", "katana_sombria", "couraca_sombria", "capuz_sombrio", "anel_vampiro", "botas_vento" },
		drops = { { id = "seda", chance = 1, min = 3, max = 6 }, essence(0.8) },
		aggro = 70, radius = 4, model = "spider", color = Color3.fromRGB(70, 30, 80), behavior = "boss", scale = 2.1,
		charge = { speed = 65, time = 0.6, windup = 0.8, damage = 30, cooldown = 7 },
		slam = { radius = 13, windup = 1.0, damage = 34, cooldown = 8 },
		summon = { enemy = "aranha", count = 2, cooldown = 20 },
		leash = 110, dungeon = true,
		uniques = { "arco_viuva" },
	},
	guardiao_cripta = {
		name = "Guardião da Cripta", level = 13, hp = 7000, damage = 32, speed = 9, attackCooldown = 1.8, attackRange = 8,
		xp = 2000, gold = { 180, 320 }, dropChance = 1, equipDrops = 1, minRarity = 3,
		pool = { "martelo_gigante", "armadura_placas", "elmo_ferro", "botas_ferro", "anel_guardiao", "grevas_dragao" },
		drops = { { id = "nucleo_golem", chance = 1, min = 1, max = 2 }, { id = "essencia", chance = 1, min = 2, max = 3 } },
		aggro = 70, radius = 4.6, model = "golem", color = Color3.fromRGB(95, 90, 120), behavior = "boss", scale = 1.7, defense = 0.25,
		charge = { speed = 45, time = 0.8, windup = 1.2, damage = 40, cooldown = 10 },
		slam = { radius = 16, windup = 1.3, damage = 52, cooldown = 6 },
		summon = { enemy = "esqueleto", count = 2, cooldown = 26 },
		leash = 110, dungeon = true,
		uniques = { "couraca_guardiao" },
	},
	-- chefe de mundo (WorldEventService): feito para ~20 caçadores juntos (vida fixa enorme)
	behemoth_mana = {
		name = "Behemoth de Mana", level = 20, hp = 320000, damage = 62, speed = 11, attackCooldown = 1.7, attackRange = 13,
		xp = 9000, gold = { 900, 1400 }, dropChance = 1, equipDrops = 2, minRarity = 4,
		pool = { "espada_runica", "katana_lua", "adagas_vazio", "coroa_arcana", "amuleto_dragao", "anel_tempestade", "martelo_gigante", "armadura_placas" },
		drops = { { id = "essencia", chance = 1, min = 6, max = 12 }, { id = "minerio_mitril", chance = 1, min = 3, max = 6 } },
		aggro = 90, radius = 8, model = "behemoth", color = Color3.fromRGB(70, 60, 90), behavior = "boss", scale = 2.4, defense = 0.2,
		posture = 9000,
		charge = { speed = 55, time = 0.9, windup = 1.3, damage = 70, cooldown = 9 },
		slam = { radius = 22, windup = 1.5, damage = 80, cooldown = 7 },
		summon = { enemy = "slime", count = 4, cooldown = 25 },
		leash = 160,
	},
	rei_lich = {
		name = "Rei Lich", level = 17, hp = 14000, damage = 36, speed = 12, attackCooldown = 1.2, attackRange = 8,
		xp = 4200, gold = { 400, 650 }, dropChance = 1, equipDrops = 2, minRarity = 4,
		pool = { "cajado_estelar", "manto_estelar", "coroa_arcana", "espada_runica", "katana_lua", "adagas_vazio", "amuleto_dragao", "anel_tempestade" },
		drops = { { id = "osso", chance = 1, min = 4, max = 8 }, { id = "essencia", chance = 1, min = 3, max = 6 } },
		aggro = 80, radius = 3.8, model = "skeletonMage", color = Color3.fromRGB(150, 110, 230), behavior = "boss", scale = 3,
		charge = { speed = 60, time = 0.7, windup = 0.9, damage = 44, cooldown = 8 },
		slam = { radius = 17, windup = 1.2, damage = 58, cooldown = 6 },
		summon = { enemy = "esqueleto_mago", count = 2, cooldown = 20 },
		leash = 120, dungeon = true,
		uniques = { "lamina_eclipse", "anel_lich" },
	},
	colosso_abismo = {
		name = "Colosso do Abismo", level = 20, hp = 22000, damage = 44, speed = 9, attackCooldown = 1.7, attackRange = 10,
		xp = 7000, gold = { 700, 1100 }, dropChance = 1, equipDrops = 3, minRarity = 4,
		pool = { "martelo_trovao", "machado_tempestade", "armadura_dragao", "elmo_dragao", "grevas_dragao", "amuleto_dragao", "anel_rei", "lanca_celestial", "arco_fenix" },
		drops = { { id = "nucleo_golem", chance = 1, min = 2, max = 4 }, { id = "minerio_mitril", chance = 1, min = 2, max = 5 }, { id = "essencia", chance = 1, min = 4, max = 8 } },
		aggro = 90, radius = 6, model = "golem", color = Color3.fromRGB(110, 45, 35), behavior = "boss", scale = 2.6, defense = 0.3,
		charge = { speed = 50, time = 0.9, windup = 1.2, damage = 55, cooldown = 9 },
		slam = { radius = 20, windup = 1.4, damage = 70, cooldown = 6 },
		summon = { enemy = "golem", count = 1, cooldown = 30 },
		leash = 140, dungeon = true,
		uniques = { "martelo_colosso" },
	},
	-- chefe da raide (RaidService): fases, chuva de estrelas e servos ficam no serviço
	devorador = {
		name = "Devorador de Estrelas", level = 24, hp = 240000, damage = 52, speed = 10, attackCooldown = 1.6, attackRange = 12,
		xp = 15000, gold = { 1500, 2500 }, dropChance = 1, equipDrops = 3, minRarity = 5,
		-- só o conjunto Estelar (exclusivo da raide)
		pool = { "espada_estelar", "katana_estelar", "adagas_estelares", "machado_estelar", "martelo_estelar", "lanca_estelar", "arco_estelar", "cetro_estelar", "coroa_estelar", "armadura_estelar", "passos_estelares", "amuleto_estelar" },
		drops = { { id = "essencia", chance = 1, min = 8, max = 14 }, { id = "minerio_mitril", chance = 1, min = 4, max = 8 }, { id = "nucleo_golem", chance = 1, min = 3, max = 5 } },
		aggro = 140, radius = 8, model = "devorador", color = Color3.fromRGB(60, 35, 110), behavior = "boss", scale = 3.2, defense = 0.35,
		charge = { speed = 55, time = 1.0, windup = 1.2, damage = 70, cooldown = 10 },
		slam = { radius = 24, windup = 1.3, damage = 80, cooldown = 7 },
		summon = { enemy = "golem", count = 1, cooldown = 35 },
		leash = 220, dungeon = true,
		uniques = { "martelo_colosso", "lamina_eclipse", "anel_lich" },
	},
}

-- comportamento "boss" = chefe (barra no topo, música de chefe, não vira Elite, não é empurrado)
for _, def in Enemies.Defs do
	def.boss = def.behavior == "boss"
end

-- center = X,Z; spawns = { tipo = quantidade }
Enemies.Camps = {
	{ id = "treino", town = true, center = Vector2.new(0, 55), radius = 7, spawns = { boneco = 3 }, respawn = 1 },
	{ id = "slimes_a", center = Vector2.new(60, 32), radius = 30, spawns = { slime = 6 }, respawn = 5 },
	{ id = "slimes_b", center = Vector2.new(-65, 50), radius = 30, spawns = { slime = 6 }, respawn = 5 },
	{ id = "slimes_c", center = Vector2.new(75, -60), radius = 28, spawns = { slime = 5 }, respawn = 5 },
	{ id = "lobos_a", center = Vector2.new(-60, -60), radius = 40, spawns = { lobo = 4 }, respawn = 8 },
	{ id = "lobos_b", center = Vector2.new(60, -150), radius = 40, spawns = { lobo = 5 }, respawn = 8 },
	{ id = "javalis", center = Vector2.new(-110, 30), radius = 35, spawns = { javali = 4 }, respawn = 9 },
	{ id = "javalis_b", center = Vector2.new(110, 60), radius = 35, spawns = { javali = 3 }, respawn = 9 },
	{ id = "praia_a", center = Vector2.new(150, 296), radius = 26, spawns = { caranguejo = 5 }, respawn = 9 },
	{ id = "praia_b", center = Vector2.new(-60, 300), radius = 26, spawns = { caranguejo = 4 }, respawn = 9 },
	{ id = "goblins_a", center = Vector2.new(225, -55), radius = 30, spawns = { goblin = 4, goblin_arqueiro = 2 }, respawn = 10, structure = "goblinCamp" },
	{ id = "goblins_b", center = Vector2.new(290, -160), radius = 30, spawns = { goblin = 4, goblin_arqueiro = 3 }, respawn = 10, structure = "goblinCamp" },
	{ id = "aranhas", center = Vector2.new(330, 30), radius = 32, spawns = { aranha = 5 }, respawn = 11, structure = "spiderNest" },
	{ id = "esqueletos_a", center = Vector2.new(-230, -50), radius = 34, spawns = { esqueleto = 5, esqueleto_mago = 2 }, respawn = 12 },
	{ id = "esqueletos_b", center = Vector2.new(-290, -150), radius = 34, spawns = { esqueleto = 4, esqueleto_mago = 2 }, respawn = 12 },
	{ id = "golems", center = Vector2.new(-150, -150), radius = 30, spawns = { golem = 2 }, respawn = 30 },
	{ id = "cratera", center = Vector2.new(0, -455), radius = 45, spawns = { rei_goblin = 1 }, respawn = 60, boss = true, place = "No Covil, além do Portão Selado" },
	-- chefes de campo (place = onde avisar que ele voltou; centros nos acampamentos da região)
	{ id = "chefe_alfa", center = Vector2.new(60, -150), radius = 14, spawns = { presa_negra = 1 }, respawn = 420, place = "Perto da Estátua do Herói, nos campos" },
	{ id = "chefe_javali", center = Vector2.new(-110, 30), radius = 14, spawns = { rasga_terra = 1 }, respawn = 420, place = "Nos campos a oeste, perto do Círculo de Pedras" },
	{ id = "chefe_tenaz", center = Vector2.new(150, 296), radius = 14, spawns = { tenaz = 1 }, respawn = 420, place = "Na praia leste" },
	{ id = "chefe_bando", center = Vector2.new(290, -160), radius = 14, spawns = { olho_vermelho = 1 }, respawn = 480, place = "No acampamento goblin do norte do bosque" },
	{ id = "chefe_tecela", center = Vector2.new(330, 30), radius = 14, spawns = { tecela = 1 }, respawn = 480, place = "No ninho das aranhas, no bosque" },
	{ id = "chefe_ossario", center = Vector2.new(-290, -150), radius = 14, spawns = { sir_ossario = 1 }, respawn = 540, place = "Nas ruínas, a oeste do cemitério" },
	{ id = "chefe_musgo", center = Vector2.new(-150, -150), radius = 14, spawns = { musgo_antigo = 1 }, respawn = 600, place = "Entre os golems, ao sul das ruínas" },
}

Enemies.EliteChance = 0.06
-- Chance de CADA jogador que ajudou a matar o chefe ganhar um dos seus Únicos (no andar 20 das masmorras: dobro)
Enemies.UniqueChance = 0.015

-- Os centros acima estão em coordenadas de design; converte para studs reais (ver World.Scale)
local World = require(script.Parent.World)
local Points = require(script.Parent.Points)
-- Guardas de cada local de interesse (Points[...].guards): acampamento no próprio local, já em studs reais
for _, poi in Points.List do
	if poi.guards then
		table.insert(Enemies.Camps, { id = "local_" .. poi.id, poi = poi.id, center = Vector2.new(poi.x, poi.z), radius = poi.radius * 0.45, spawns = poi.guards, respawn = 20 })
	end
end

for _, camp in Enemies.Camps do
	-- town = true: centro relativo à praça, na escala da vila
	camp.center = if camp.poi then camp.center
		elseif camp.town then Vector2.new(World.TownCenter.X, World.TownCenter.Z) + camp.center * World.PropScale
		else camp.center * World.Scale
	if camp.id ~= "treino" and not camp.poi then
		camp.radius = camp.radius * 1.25
	end
end

return Enemies
