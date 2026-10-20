-- Equipamentos, materiais, consumíveis e encantamentos.
local HttpService = game:GetService("HttpService")

local Rarities = require(script.Parent.Rarities)

local Items = {}

Items.MaxUpgrade = 10

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
}

-- Itens que podem sair dos baús
Items.ChestPool = {
	"espada_cobre", "machado_lenhador", "martelo_pedra", "lanca_cacador", "katana_errante", "adaga_cobre", "arco_curto", "cajado_aprendiz",
	"lamina_guardiao", "machado_berserker", "martelo_gigante", "lanca_draconica", "katana_sombria", "presas_gemeas", "arco_longo", "cajado_arcano",
	"colete_couro", "manto_aprendiz", "cota_malha", "armadura_placas", "manto_arcano", "couraca_sombria",
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
}

Items.Consumables = {
	pocao_vida = { name = "Poção de Vida", icon = "❤️", heal = 0.4, cooldown = 6, price = 40, key = "Z" },
	pocao_mana = { name = "Poção de Mana", icon = "💙", mana = 0.5, cooldown = 6, price = 40, key = "X" },
	pocao_vigor = { name = "Poção de Vigor", icon = "💛", stamina = 1, cooldown = 6, price = 50, key = "V" },
	elixir_forca = { name = "Elixir de Força", icon = "🔥", damageBuff = 0.2, buffTime = 60, cooldown = 30 },
}
Items.ConsumableOrder = { "pocao_vida", "pocao_mana", "pocao_vigor", "elixir_forca" }

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
	return {
		uid = HttpService:GenerateGUID(false),
		base = baseId,
		rarity = rarityId,
		level = level or 1,
		upgrade = 0,
	}
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
	if base.slot == "armor" then
		return "🛡️"
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
		disassemble = Items.getDisassembleValue(item),
		bonus = base.bonus,
		equipped = equipped == true,
	}
end

return Items
