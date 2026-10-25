-- Equipamentos, materiais, consumíveis e encantamentos.
-- Espaços: arma, armadura, elmo, botas (dão vida), amuleto e anel (dão ataque + bônus).
-- Cada item sorteia perks próprios pela raridade (ver o módulo Perks).
local HttpService = game:GetService("HttpService")

local Rarities = require(script.Parent.Rarities)
local Perks = require(script.Parent.Perks)

local Items = {}

Items.MaxUpgrade = 10

Items.Slots = {
	weapon = { name = "Arma", icon = "⚔️", order = 1, kind = "attack" },
	armor = { name = "Armadura", icon = "🛡️", order = 2, kind = "health" },
	helmet = { name = "Elmo", icon = "⛑️", order = 3, kind = "health" },
	boots = { name = "Botas", icon = "👢", order = 4, kind = "health" },
	amulet = { name = "Amuleto", icon = "📿", order = 5, kind = "attack" },
	ring = { name = "Anel", icon = "💍", order = 6, kind = "attack" },
}
Items.SlotOrder = { "weapon", "armor", "helmet", "boots", "amulet", "ring" }

Items.WeaponTypes = {
	sword = { name = "Espada", icon = "🗡️" },
	axe = { name = "Machado", icon = "🪓" },
	hammer = { name = "Martelo", icon = "🔨" },
	spear = { name = "Lança", icon = "🔱" },
	katana = { name = "Katana", icon = "⚔️" },
	dagger = { name = "Adaga", icon = "🔪" },
	bow = { name = "Arco", icon = "🏹" },
	staff = { name = "Cajado", icon = "🔮" },
}

-- power: dano (armas) ou vida extra (armaduras) de um item Comum nível 1
Items.Bases = {
	-- armas iniciais (uma por classe)
	espada_treino = { name = "Espada de Treino", slot = "weapon", weaponType = "sword", power = 5, tier = 0 },
	arco_treino = { name = "Arco de Treino", slot = "weapon", weaponType = "bow", power = 4, tier = 0 },
	cajado_treino = { name = "Cajado de Treino", slot = "weapon", weaponType = "staff", power = 4, tier = 0 },
	adaga_treino = { name = "Adaga de Treino", slot = "weapon", weaponType = "dagger", power = 3, tier = 0 },
	-- tier 1
	espada_cobre = { name = "Espada de Cobre", slot = "weapon", weaponType = "sword", power = 8, tier = 1 },
	machado_lenhador = { name = "Machado de Lenhador", slot = "weapon", weaponType = "axe", power = 10, tier = 1 },
	martelo_pedra = { name = "Martelo de Pedra", slot = "weapon", weaponType = "hammer", power = 13, tier = 1 },
	lanca_cacador = { name = "Lança do Caçador", slot = "weapon", weaponType = "spear", power = 8, tier = 1 },
	katana_errante = { name = "Katana Errante", slot = "weapon", weaponType = "katana", power = 9, tier = 1 },
	adaga_cobre = { name = "Adaga de Cobre", slot = "weapon", weaponType = "dagger", power = 6, tier = 1 },
	arco_curto = { name = "Arco Curto", slot = "weapon", weaponType = "bow", power = 7, tier = 1 },
	cajado_aprendiz = { name = "Cajado de Aprendiz", slot = "weapon", weaponType = "staff", power = 7, tier = 1 },
	-- tier 2
	lamina_guardiao = { name = "Lâmina do Guardião", slot = "weapon", weaponType = "sword", power = 13, tier = 2 },
	machado_berserker = { name = "Machado Berserker", slot = "weapon", weaponType = "axe", power = 16, tier = 2 },
	martelo_gigante = { name = "Martelo do Gigante", slot = "weapon", weaponType = "hammer", power = 20, tier = 2 },
	lanca_draconica = { name = "Lança Dracônica", slot = "weapon", weaponType = "spear", power = 14, tier = 2 },
	katana_sombria = { name = "Katana Sombria", slot = "weapon", weaponType = "katana", power = 14, tier = 2 },
	presas_gemeas = { name = "Presas Gêmeas", slot = "weapon", weaponType = "dagger", power = 10, tier = 2 },
	arco_longo = { name = "Arco Longo Élfico", slot = "weapon", weaponType = "bow", power = 12, tier = 2 },
	cajado_arcano = { name = "Cajado Arcano", slot = "weapon", weaponType = "staff", power = 12, tier = 2 },
	-- armaduras
	colete_couro = { name = "Colete de Couro", slot = "armor", power = 20, tier = 1, bonus = { stamina = 15 } },
	manto_aprendiz = { name = "Manto de Aprendiz", slot = "armor", power = 16, tier = 1, bonus = { mana = 25 } },
	cota_malha = { name = "Cota de Malha", slot = "armor", power = 34, tier = 1 },
	armadura_placas = { name = "Armadura de Placas", slot = "armor", power = 55, tier = 2 },
	manto_arcano = { name = "Manto Arcano", slot = "armor", power = 30, tier = 2, bonus = { mana = 60 } },
	couraca_sombria = { name = "Couraça Sombria", slot = "armor", power = 40, tier = 2, bonus = { stamina = 30 } },
	-- armas extras e tier 3
	maca_peregrino = { name = "Maça do Peregrino", slot = "weapon", weaponType = "hammer", power = 11, tier = 1 },
	cetro_luz = { name = "Cetro da Luz", slot = "weapon", weaponType = "staff", power = 13, tier = 2 },
	espada_runica = { name = "Espada Rúnica", slot = "weapon", weaponType = "sword", power = 19, tier = 3 },
	machado_tempestade = { name = "Machado da Tempestade", slot = "weapon", weaponType = "axe", power = 23, tier = 3 },
	martelo_trovao = { name = "Martelo do Trovão", slot = "weapon", weaponType = "hammer", power = 28, tier = 3 },
	lanca_celestial = { name = "Lança Celestial", slot = "weapon", weaponType = "spear", power = 20, tier = 3 },
	katana_lua = { name = "Katana da Lua Rubra", slot = "weapon", weaponType = "katana", power = 20, tier = 3 },
	adagas_vazio = { name = "Adagas do Vazio", slot = "weapon", weaponType = "dagger", power = 15, tier = 3 },
	arco_fenix = { name = "Arco da Fênix", slot = "weapon", weaponType = "bow", power = 18, tier = 3 },
	cajado_estelar = { name = "Cajado Estelar", slot = "weapon", weaponType = "staff", power = 18, tier = 3 },
	-- armaduras tier 3
	armadura_dragao = { name = "Armadura de Dragão", slot = "armor", power = 80, tier = 3 },
	manto_estelar = { name = "Manto Estelar", slot = "armor", power = 48, tier = 3, bonus = { mana = 100 } },
	couraca_vento = { name = "Couraça do Vento", slot = "armor", power = 60, tier = 3, bonus = { stamina = 45 } },
	-- elmos
	elmo_couro = { name = "Elmo de Couro", slot = "helmet", power = 8, tier = 1, bonus = { stamina = 5 } },
	capuz_aprendiz = { name = "Capuz de Aprendiz", slot = "helmet", power = 6, tier = 1, bonus = { mana = 15 } },
	elmo_ferro = { name = "Elmo de Ferro", slot = "helmet", power = 16, tier = 2 },
	capuz_sombrio = { name = "Capuz Sombrio", slot = "helmet", power = 13, tier = 2, bonus = { stamina = 15 } },
	elmo_dragao = { name = "Elmo de Dragão", slot = "helmet", power = 28, tier = 3 },
	coroa_arcana = { name = "Coroa Arcana", slot = "helmet", power = 22, tier = 3, bonus = { mana = 50 } },
	-- botas
	botas_couro = { name = "Botas de Couro", slot = "boots", power = 6, tier = 1, bonus = { stamina = 10 } },
	sandalias_monge = { name = "Sandálias de Monge", slot = "boots", power = 5, tier = 1, bonus = { mana = 10 } },
	botas_ferro = { name = "Botas de Ferro", slot = "boots", power = 13, tier = 2 },
	botas_vento = { name = "Botas do Vento", slot = "boots", power = 10, tier = 2, bonus = { stamina = 25 } },
	grevas_dragao = { name = "Grevas de Dragão", slot = "boots", power = 22, tier = 3 },
	botas_estelares = { name = "Botas Estelares", slot = "boots", power = 18, tier = 3, bonus = { stamina = 40 } },
	-- amuletos (stats crescem com a raridade)
	amuleto_cobre = { name = "Amuleto de Cobre", slot = "amulet", power = 2, tier = 1, stats = { damage = 0.03 } },
	amuleto_vida = { name = "Amuleto da Vida", slot = "amulet", power = 1, tier = 1, stats = { health = 0.05 } },
	amuleto_lua = { name = "Amuleto da Lua", slot = "amulet", power = 4, tier = 2, stats = { crit = 0.02 } },
	amuleto_sabio = { name = "Amuleto do Sábio", slot = "amulet", power = 3, tier = 2, stats = { manaRegen = 0.15, healPower = 0.05 } },
	amuleto_dragao = { name = "Amuleto do Dragão", slot = "amulet", power = 7, tier = 3, stats = { damage = 0.06 } },
	-- anéis
	anel_cobre = { name = "Anel de Cobre", slot = "ring", power = 2, tier = 1, stats = { crit = 0.01 } },
	anel_vampiro = { name = "Anel do Vampiro", slot = "ring", power = 3, tier = 2, stats = { lifesteal = 0.02 } },
	anel_guardiao = { name = "Anel do Guardião", slot = "ring", power = 2, tier = 2, stats = { defense = 0.03, threat = 0.1 } },
	anel_tempestade = { name = "Anel da Tempestade", slot = "ring", power = 5, tier = 3, stats = { attackSpeed = 0.05 } },
	anel_rei = { name = "Anel do Rei", slot = "ring", power = 6, tier = 3, stats = { xpGain = 0.08, goldFind = 0.08 } },

	-- ===== EXCLUSIVOS DAS MASMORRAS (dungeon = id; signature = perk de assinatura, sempre presente) =====
	-- Toca dos Goblins
	faca_saqueador = { name = "Faca do Saqueador", slot = "weapon", weaponType = "dagger", power = 12, tier = 2, dungeon = "toca", signature = "saqueador" },
	machado_tunel = { name = "Machado do Túnel", slot = "weapon", weaponType = "axe", power = 17, tier = 2, dungeon = "toca", signature = "saqueador" },
	arco_tunel = { name = "Arco de Raiz", slot = "weapon", weaponType = "bow", power = 13, tier = 2, dungeon = "toca", signature = "saqueador" },
	cajado_cristal = { name = "Cajado de Cristal da Toca", slot = "weapon", weaponType = "staff", power = 13, tier = 2, dungeon = "toca", signature = "saqueador" },
	colete_tunel = { name = "Colete de Túnel", slot = "armor", power = 42, tier = 2, bonus = { stamina = 25 }, dungeon = "toca", signature = "pele_tunel", set = "toca" },
	anel_saqueador = { name = "Anel do Saqueador", slot = "ring", power = 4, tier = 2, stats = { goldFind = 0.06, crit = 0.01 }, dungeon = "toca", signature = "pele_tunel", set = "toca" },
	-- Cripta Esquecida
	ceifa_espectral = { name = "Ceifa Espectral", slot = "weapon", weaponType = "sword", power = 21, tier = 3, dungeon = "cripta", signature = "ceifa_alma" },
	katana_espectral = { name = "Katana do Luto", slot = "weapon", weaponType = "katana", power = 22, tier = 3, dungeon = "cripta", signature = "ceifa_alma" },
	cetro_ossos = { name = "Cetro de Ossos", slot = "weapon", weaponType = "staff", power = 19, tier = 3, dungeon = "cripta", signature = "ceifa_alma" },
	arco_luto = { name = "Arco do Lamento", slot = "weapon", weaponType = "bow", power = 19, tier = 3, dungeon = "cripta", signature = "ceifa_alma" },
	mortalha_cripta = { name = "Mortalha da Cripta", slot = "armor", power = 62, tier = 3, bonus = { mana = 60 }, dungeon = "cripta", signature = "mortalha", set = "cripta" },
	amuleto_alma = { name = "Amuleto de Almas", slot = "amulet", power = 6, tier = 3, stats = { lifesteal = 0.015, damage = 0.03 }, dungeon = "cripta", signature = "mortalha", set = "cripta" },
	-- Abismo de Pedra
	martelo_magma = { name = "Martelo de Magma", slot = "weapon", weaponType = "hammer", power = 32, tier = 3, dungeon = "abismo", signature = "coracao_magma" },
	lanca_magma = { name = "Lança Abissal", slot = "weapon", weaponType = "spear", power = 25, tier = 3, dungeon = "abismo", signature = "coracao_magma" },
	adagas_brasa = { name = "Adagas de Brasa", slot = "weapon", weaponType = "dagger", power = 19, tier = 3, dungeon = "abismo", signature = "coracao_magma" },
	cajado_magma = { name = "Cajado do Vulcão", slot = "weapon", weaponType = "staff", power = 23, tier = 3, dungeon = "abismo", signature = "coracao_magma" },
	casca_abissal = { name = "Couraça Abissal", slot = "armor", power = 90, tier = 3, dungeon = "abismo", signature = "casca_abissal", set = "abismo" },
	anel_magma = { name = "Anel de Magma", slot = "ring", power = 7, tier = 3, stats = { damage = 0.04, critDamage = 0.05 }, dungeon = "abismo", signature = "casca_abissal", set = "abismo" },
	-- peças de conjunto que completam os 4 de cada masmorra
	capuz_saqueador = { name = "Capuz do Saqueador", slot = "helmet", power = 18, tier = 2, bonus = { stamina = 15 }, dungeon = "toca", signature = "pele_tunel", set = "toca" },
	botas_tunel = { name = "Botas de Túnel", slot = "boots", power = 15, tier = 2, bonus = { stamina = 20 }, dungeon = "toca", signature = "pele_tunel", set = "toca" },
	elmo_vigia = { name = "Elmo do Vigia", slot = "helmet", power = 26, tier = 3, dungeon = "cripta", signature = "mortalha", set = "cripta" },
	grevas_vigia = { name = "Grevas do Vigia", slot = "boots", power = 21, tier = 3, dungeon = "cripta", signature = "mortalha", set = "cripta" },
	elmo_magma = { name = "Elmo de Magma", slot = "helmet", power = 32, tier = 3, dungeon = "abismo", signature = "casca_abissal", set = "abismo" },
	botas_brasa = { name = "Botas de Brasa", slot = "boots", power = 26, tier = 3, bonus = { stamina = 20 }, dungeon = "abismo", signature = "casca_abissal", set = "abismo" },

	-- ===== ÚNICOS (raridade Única, efeito próprio; só caem de chefes: Enemies.Defs[x].uniques) =====
	lamina_eclipse = { name = "Lâmina do Eclipse", slot = "weapon", weaponType = "sword", power = 27, tier = 4, unique = true, signature = "eclipse" },
	adagas_capitao = { name = "Adagas do Capitão", slot = "weapon", weaponType = "dagger", power = 20, tier = 4, unique = true, signature = "sangria" },
	martelo_colosso = { name = "Punho do Colosso", slot = "weapon", weaponType = "hammer", power = 38, tier = 4, unique = true, signature = "terremoto" },
	arco_viuva = { name = "Arco da Viúva", slot = "weapon", weaponType = "bow", power = 24, tier = 4, unique = true, signature = "teia_viuva" },
	cajado_vazio = { name = "Cajado do Vazio Eterno", slot = "weapon", weaponType = "staff", power = 24, tier = 4, unique = true, signature = "abismo_arcano" },
	couraca_guardiao = { name = "Couraça do Guardião Eterno", slot = "armor", power = 105, tier = 4, unique = true, signature = "bastiao", bonus = { stamina = 30 } },
	coroa_rei_goblin = { name = "Coroa do Rei Goblin", slot = "helmet", power = 34, tier = 4, unique = true, signature = "tirania", bonus = { mana = 30 } },
	anel_lich = { name = "Anel do Lich", slot = "ring", power = 9, tier = 4, unique = true, signature = "filacterio", stats = { critDamage = 0.1, damage = 0.04 } },
}

-- Conjuntos: peças (base.set = id) e bônus por quantidade equipada (stats somados; perk liga um efeito)
Items.Sets = {
	toca = {
		name = "Saqueador da Toca",
		pieces = { "capuz_saqueador", "colete_tunel", "botas_tunel", "anel_saqueador" },
		bonuses = {
			[2] = { stats = { goldFind = 0.1, crit = 0.04 }, text = "+10% de ouro e +4% de crítico" },
			[4] = { stats = { dungeonDamage = 0.15, stamina = 0.1 }, perk = "pilhagem", text = "+15% de dano em masmorras, +10% de estamina e Pilhagem (dobro de material)" },
		},
	},
	cripta = {
		name = "Vigília da Cripta",
		pieces = { "elmo_vigia", "mortalha_cripta", "grevas_vigia", "amuleto_alma" },
		bonuses = {
			[2] = { stats = { health = 0.1, regen = 0.003 }, text = "+10% de vida e 0,3% de vida/s" },
			[4] = { stats = { dungeonDamage = 0.15, lifesteal = 0.03 }, perk = "pacto_espectral", text = "+15% de dano em masmorras, +3% de roubo de vida e Pacto Espectral (abates curam 5%)" },
		},
	},
	abismo = {
		name = "Fúria do Abismo",
		pieces = { "elmo_magma", "casca_abissal", "botas_brasa", "anel_magma" },
		bonuses = {
			[2] = { stats = { damage = 0.08, defense = 0.04 }, text = "+8% de dano e +4% de redução de dano" },
			[4] = { stats = { dungeonDamage = 0.2, heavyDamage = 0.2 }, perk = "erupcao", text = "+20% de dano em masmorras, +20% de golpe pesado e Erupção (abates explodem)" },
		},
	},
}

-- Texto dos stats de acessórios (para a UI)
Items.StatNames = {
	damage = "de dano", health = "de vida", crit = "de crítico", critDamage = "de dano crítico", attackSpeed = "de velocidade de ataque",
	defense = "de redução de dano", lifesteal = "de roubo de vida", manaRegen = "de mana/s", healPower = "de cura", threat = "de ameaça",
	xpGain = "de XP", goldFind = "de ouro", cooldown = "de recarga", stamina = "de estamina", mana = "de mana", regen = "de vida/s",
	dungeonDamage = "de dano em masmorras",
}

-- Itens que podem sair dos baús
Items.ChestPool = {
	"espada_cobre", "machado_lenhador", "martelo_pedra", "lanca_cacador", "katana_errante", "adaga_cobre", "arco_curto", "cajado_aprendiz",
	"lamina_guardiao", "machado_berserker", "martelo_gigante", "lanca_draconica", "katana_sombria", "presas_gemeas", "arco_longo", "cajado_arcano",
	"colete_couro", "manto_aprendiz", "cota_malha", "armadura_placas", "manto_arcano", "couraca_sombria",
	"maca_peregrino", "cetro_luz", "elmo_couro", "capuz_aprendiz", "elmo_ferro", "capuz_sombrio",
	"botas_couro", "sandalias_monge", "botas_ferro", "botas_vento",
	"amuleto_cobre", "amuleto_vida", "amuleto_lua", "amuleto_sabio", "anel_cobre", "anel_vampiro", "anel_guardiao",
	"espada_runica", "machado_tempestade", "martelo_trovao", "lanca_celestial", "katana_lua", "adagas_vazio", "arco_fenix", "cajado_estelar",
	"armadura_dragao", "manto_estelar", "couraca_vento", "elmo_dragao", "coroa_arcana", "grevas_dragao", "botas_estelares",
	"amuleto_dragao", "anel_tempestade", "anel_rei",
}

Items.Materials = {
	minerio_cobre = { name = "Minério de Cobre", icon = "🟠", sell = 3 },
	minerio_ferro = { name = "Minério de Ferro", icon = "🔩", sell = 6 },
	minerio_mitril = { name = "Minério de Mitril", icon = "💠", sell = 15 },
	madeira = { name = "Madeira", icon = "🌲", sell = 2 },
	madeira_antiga = { name = "Madeira Antiga", icon = "🌳", sell = 8 },
	erva_verde = { name = "Erva Verde", icon = "🌿", sell = 2 },
	cogumelo_azul = { name = "Cogumelo Azul", icon = "🍄", sell = 4 },
	flor_lunar = { name = "Flor Lunar", icon = "🌸", sell = 9 },
	gosma = { name = "Gosma de Slime", icon = "🟢", sell = 1 },
	couro = { name = "Couro", icon = "🟫", sell = 3 },
	presa = { name = "Presa de Lobo", icon = "🦷", sell = 4 },
	pano = { name = "Retalho de Pano", icon = "🧵", sell = 3 },
	seda = { name = "Seda de Aranha", icon = "🕸️", sell = 6 },
	carapaca = { name = "Carapaça", icon = "🦀", sell = 5 },
	osso = { name = "Osso Antigo", icon = "🦴", sell = 5 },
	nucleo_golem = { name = "Núcleo de Golem", icon = "🔶", sell = 20 },
	essencia = { name = "Essência Mágica", icon = "✨", sell = 10 },
	coroa_goblin = { name = "Fragmento da Coroa", icon = "👑", sell = 100 },
	-- materiais das masmorras (caem de todo inimigo lá dentro; moeda do Mercador de Masmorras)
	saque_toca = { name = "Saque da Toca", icon = "💰", sell = 4, dungeon = "toca" },
	fragmento_alma = { name = "Fragmento de Alma", icon = "👻", sell = 8, dungeon = "cripta" },
	brasa_abissal = { name = "Brasa Abissal", icon = "🌋", sell = 14, dungeon = "abismo" },
	-- chaves (o líder gasta uma ao começar a masmorra)
	chave_cripta = { name = "Chave da Cripta", icon = "🗝", sell = 1, key = "cripta" },
	chave_abismo = { name = "Chave do Abismo", icon = "🗝", sell = 1, key = "abismo" },
}

Items.Consumables = {
	pocao_vida = { name = "Poção de Vida", icon = "❤️", heal = 0.4, cooldown = 6, price = 40, key = "Z" },
	pocao_mana = { name = "Poção de Mana", icon = "💙", mana = 0.5, cooldown = 6, price = 40, key = "X" },
	pocao_vigor = { name = "Poção de Vigor", icon = "💛", stamina = 1, cooldown = 6, price = 50, key = "V" },
	elixir_forca = { name = "Elixir de Força", icon = "🔥", damageBuff = 0.2, buffTime = 60, cooldown = 30 },
	-- vendidos pelo Mercador de Masmorras
	pocao_grande = { name = "Poção Grande de Vida", icon = "💖", heal = 0.75, cooldown = 10 },
	tonico_pedra = { name = "Tônico de Pedra", icon = "🗿", defenseBuff = 0.35, buffTime = 90, cooldown = 30 },
}
Items.ConsumableOrder = { "pocao_vida", "pocao_mana", "pocao_vigor", "elixir_forca", "pocao_grande", "tonico_pedra" }

-- Encantamentos: valor por tier (I a V)
Items.Enchants = {
	afiado = { name = "Afiado", slot = "weapon", stat = "damage", perTier = 0.05, text = "+%d%% de dano" },
	critico = { name = "Preciso", slot = "weapon", stat = "crit", perTier = 0.03, text = "+%d%% de crítico" },
	vampirico = { name = "Vampírico", slot = "weapon", stat = "lifesteal", perTier = 0.02, text = "%d%% de roubo de vida" },
	veloz = { name = "Veloz", slot = "weapon", stat = "speed", perTier = 0.04, text = "+%d%% de velocidade de ataque" },
	flamejante = { name = "Flamejante", slot = "weapon", stat = "burn", perTier = 0.06, text = "Queima: +%d%% do dano em 3s" },
	robusto = { name = "Robusto", slot = "armor", stat = "health", perTier = 0.06, text = "+%d%% de vida" },
	agil = { name = "Ágil", slot = "armor", stat = "stamina", perTier = 0.08, text = "+%d%% de estamina" },
	arcano = { name = "Arcano", slot = "armor", stat = "mana", perTier = 0.1, text = "+%d%% de mana" },
	regenerante = { name = "Regenerante", slot = "armor", stat = "regen", perTier = 0.004, text = "Regenera %0.1f%% da vida/s" },
}
Items.EnchantsBySlot = { weapon = {}, armor = {} }
for id, enchant in Items.Enchants do
	table.insert(Items.EnchantsBySlot[enchant.slot], id)
end
table.sort(Items.EnchantsBySlot.weapon)
table.sort(Items.EnchantsBySlot.armor)

local ROMAN = { "I", "II", "III", "IV", "V" }
function Items.roman(n)
	return ROMAN[n] or tostring(n)
end

function Items.enchantValue(enchant)
	local def = enchant and Items.Enchants[enchant.id]
	if not def then
		return 0
	end
	return def.perTier * enchant.tier
end

function Items.enchantText(enchant)
	local def = enchant and Items.Enchants[enchant.id]
	if not def then
		return nil
	end
	local value = Items.enchantValue(enchant)
	local shown = if def.stat == "regen" then value * 100 else math.floor(value * 100 + 0.5)
	return ("%s %s: " .. def.text):format(def.name, Items.roman(enchant.tier), shown)
end

local rng = Random.new()

function Items.create(baseId, rarityId, level)
	local base = Items.Bases[baseId]
	local rarity = Rarities.ById[rarityId]
	local perks = if base and rarity then Perks.roll(base.slot, rarity.order, rng) else {}
	-- item exclusivo de masmorra: o perk de assinatura vem sempre, no lugar do primeiro sorteado
	if base and base.signature then
		if #perks > 0 then
			perks[1] = base.signature
		else
			perks = { base.signature }
		end
	end
	return {
		uid = HttpService:GenerateGUID(false),
		base = baseId,
		rarity = rarityId,
		level = level or 1,
		upgrade = 0,
		perks = perks,
	}
end

-- Stats do acessório (amuleto/anel) já escalados pela raridade e nível
function Items.getStats(item)
	local base = Items.Bases[item.base]
	local rarity = Rarities.ById[item.rarity]
	if not base or not base.stats or not rarity then
		return nil
	end
	local scale = (1 + 0.3 * (rarity.order - 1)) * (1 + 0.02 * (item.level - 1)) * (1 + 0.05 * item.upgrade)
	local result = {}
	for key, value in base.stats do
		result[key] = value * scale
	end
	return result
end

function Items.statLines(stats)
	local lines = {}
	for key, value in stats or {} do
		local shown = if key == "regen" then ("%.1f%%"):format(value * 100) else ("%d%%"):format(math.floor(value * 100 + 0.5))
		table.insert(lines, ("+%s %s"):format(shown, Items.StatNames[key] or key))
	end
	table.sort(lines)
	return lines
end

function Items.rollDrop(pool, level, weightKey, minOrder)
	local baseId = pool[rng:NextInteger(1, #pool)]
	local rarity = Rarities.roll(weightKey, minOrder)
	local itemLevel = math.max(1, level + rng:NextInteger(-1, 1))
	return Items.create(baseId, rarity.id, itemLevel)
end

function Items.getPower(item)
	local base = Items.Bases[item.base]
	local rarity = Rarities.ById[item.rarity]
	if not base or not rarity then
		return 0
	end
	return math.floor(base.power * rarity.mult * (1 + 0.1 * (item.level - 1)) * (1 + 0.12 * item.upgrade))
end

function Items.getSellValue(item)
	local rarity = Rarities.ById[item.rarity]
	if not rarity then
		return 1
	end
	return math.floor(6 * rarity.mult ^ 2 * (1 + 0.15 * (item.level - 1)) * (1 + 0.1 * item.upgrade))
end

-- Aprimorar custa ouro + minério (ferro até +5, mitril depois)
function Items.getUpgradeCost(item)
	local rarity = Rarities.ById[item.rarity]
	if not rarity then
		return { gold = 0, materials = {} }
	end
	local gold = math.floor(40 * rarity.mult * (item.upgrade + 1) ^ 1.6 * (1 + 0.1 * (item.level - 1)))
	local materials = {}
	if item.upgrade < 3 then
		materials.minerio_cobre = 2 + item.upgrade
	elseif item.upgrade < 6 then
		materials.minerio_ferro = item.upgrade
	else
		materials.minerio_mitril = item.upgrade - 4
	end
	return { gold = gold, materials = materials }
end

-- Desmontar no Encantador devolve essência
local ESSENCE_BY_ORDER = { 1, 1, 2, 4, 8, 16, 30 }
function Items.getDisassembleValue(item)
	local rarity = Rarities.ById[item.rarity]
	return ESSENCE_BY_ORDER[rarity and rarity.order or 1] + math.floor(item.upgrade / 2)
end

-- Encantamentos: arma usa os de arma; todas as outras peças usam os de armadura
function Items.enchantSlot(slot)
	return if slot == "weapon" then "weapon" else "armor"
end

-- Reforjar (sortear perks de novo) no Bruno
function Items.getReforgeCost(item)
	local rarity = Rarities.ById[item.rarity]
	local order = rarity and rarity.order or 1
	return { gold = 60 * order * order, materials = { essencia = order } }
end

function Items.getEnchantCost(item)
	local rarity = Rarities.ById[item.rarity]
	local order = rarity and rarity.order or 1
	return { gold = 30 * order, materials = { essencia = 1 + order } }
end

function Items.displayName(item)
	local base = Items.Bases[item.base]
	local name = if base then base.name else "Item desconhecido"
	if item.upgrade > 0 then
		name ..= " +" .. item.upgrade
	end
	return name
end

function Items.icon(baseId)
	local base = Items.Bases[baseId]
	if not base then
		return "❔"
	end
	if base.slot ~= "weapon" then
		local slot = Items.Slots[base.slot]
		return if slot then slot.icon else "🛡️"
	end
	local weaponType = Items.WeaponTypes[base.weaponType]
	return if weaponType then weaponType.icon else "🗡️"
end

-- Versão "pronta para a UI" de um item (enviada ao cliente)
function Items.describe(item, equipped)
	local base = Items.Bases[item.base] or {}
	local rarity = Rarities.ById[item.rarity] or Rarities.List[1]
	local upgradeCost = Items.getUpgradeCost(item)
	return {
		uid = item.uid,
		base = item.base,
		name = Items.displayName(item),
		icon = Items.icon(item.base),
		rarity = rarity.id,
		order = rarity.order,
		slot = base.slot,
		weaponType = base.weaponType,
		level = item.level,
		upgrade = item.upgrade,
		maxUpgrade = Items.MaxUpgrade,
		power = Items.getPower(item),
		sell = Items.getSellValue(item),
		upgradeGold = upgradeCost.gold,
		upgradeMaterials = upgradeCost.materials,
		enchant = item.enchant,
		enchantText = Items.enchantText(item.enchant),
		enchantCost = Items.getEnchantCost(item),
		reforgeCost = Items.getReforgeCost(item),
		disassemble = Items.getDisassembleValue(item),
		bonus = base.bonus,
		stats = Items.getStats(item),
		perks = item.perks or {},
		set = base.set,
		unique = base.unique == true,
		dungeon = base.dungeon,
		equipped = equipped == true,
	}
end

return Items
