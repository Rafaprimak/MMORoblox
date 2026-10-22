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
		name = "Slime", level = 1, hp = 35, damage = 5, speed = 9, attackCooldown = 1.3, attackRange = 4,
		xp = 12, gold = { 2, 5 }, dropChance = 0.12, pool = { "espada_cobre", "adaga_cobre", "arco_curto", "cajado_aprendiz", "elmo_couro", "botas_couro", "anel_cobre" },
		drops = { { id = "gosma", chance = 0.75, min = 1, max = 2 }, essence(0.02) },
		aggro = 24, radius = 1.6, model = "slime", color = Color3.fromRGB(110, 230, 120), behavior = "melee",
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
	},
}

-- center = X,Z; spawns = { tipo = quantidade }
Enemies.Camps = {
	{ id = "treino", center = Vector2.new(0, 205), radius = 7, spawns = { boneco = 3 }, respawn = 1 },
	{ id = "slimes_a", center = Vector2.new(45, 55), radius = 30, spawns = { slime = 6 }, respawn = 5 },
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
	{ id = "cratera", center = Vector2.new(0, -455), radius = 45, spawns = { rei_goblin = 1 }, respawn = 60, boss = true },
}

Enemies.EliteChance = 0.06

-- Os centros acima estão em coordenadas de design; converte para studs reais (ver World.Scale)
local World = require(script.Parent.World)
for _, camp in Enemies.Camps do
	camp.center = camp.center * World.Scale
	if camp.id ~= "treino" then
		camp.radius = camp.radius * 1.25
	end
end

return Enemies
