-- Definição dos itens e fórmulas de poder, venda e aprimoramento.
local HttpService = game:GetService("HttpService")

local Rarities = require(script.Parent.Rarities)

local Items = {}

Items.MaxUpgrade = 10

-- power: dano (armas) ou vida extra (armaduras) de um item Comum nível 1
Items.Bases = {
	espada_treino = { name = "Espada de Treino", slot = "weapon", shape = "sword", power = 5 },
	espada_ferro = { name = "Espada de Ferro", slot = "weapon", shape = "sword", power = 8 },
	lanca = { name = "Lança do Caçador", slot = "weapon", shape = "spear", power = 7, range = 4 },
	machado = { name = "Machado de Guerra", slot = "weapon", shape = "axe", power = 9, cleave = 3 },
	katana = { name = "Katana Sombria", slot = "weapon", shape = "katana", power = 11, crit = 0.12 },
	martelo = { name = "Martelo do Gigante", slot = "weapon", shape = "hammer", power = 14, cleave = 5, range = 1 },
	colete = { name = "Colete de Couro", slot = "armor", power = 20 },
	cota = { name = "Cota de Malha", slot = "armor", power = 35 },
	placas = { name = "Armadura de Placas", slot = "armor", power = 55 },
}

-- Itens que podem sair do baú
Items.ChestPool = { "espada_ferro", "lanca", "machado", "katana", "martelo", "colete", "cota", "placas" }

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

function Items.getUpgradeCost(item)
	local rarity = Rarities.ById[item.rarity]
	if not rarity then
		return 0
	end
	return math.floor(40 * rarity.mult * (item.upgrade + 1) ^ 1.6 * (1 + 0.1 * (item.level - 1)))
end

function Items.displayName(item)
	local base = Items.Bases[item.base]
	local name = if base then base.name else "Item desconhecido"
	if item.upgrade > 0 then
		name ..= " +" .. item.upgrade
	end
	return name
end

-- Versão "pronta para a UI" de um item (enviada ao cliente).
function Items.describe(item, equipped)
	local base = Items.Bases[item.base] or {}
	local rarity = Rarities.ById[item.rarity] or Rarities.List[1]
	return {
		uid = item.uid,
		base = item.base,
		name = Items.displayName(item),
		rarity = rarity.id,
		order = rarity.order,
		slot = base.slot,
		shape = base.shape,
		level = item.level,
		upgrade = item.upgrade,
		maxUpgrade = Items.MaxUpgrade,
		power = Items.getPower(item),
		sell = Items.getSellValue(item),
		upgradeCost = Items.getUpgradeCost(item),
		cleave = base.cleave,
		range = base.range,
		crit = base.crit,
		equipped = equipped == true,
	}
end

return Items
