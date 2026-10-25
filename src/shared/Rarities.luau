-- Raridades: cor, chance de drop (weight) e chance no baú (chestWeight).
-- Os pesos somam 1.000.000 em cada coluna, então 10.000 = 1%.
local Rarities = {}

Rarities.List = {
	{ id = "Comum", name = "Comum", upper = "COMUM", order = 1, color = Color3.fromRGB(200, 200, 200), weight = 600000, chestWeight = 450000, mult = 1.0 },
	{ id = "Incomum", name = "Incomum", upper = "INCOMUM", order = 2, color = Color3.fromRGB(85, 225, 105), weight = 250000, chestWeight = 300000, mult = 1.35 },
	{ id = "Raro", name = "Raro", upper = "RARO", order = 3, color = Color3.fromRGB(65, 145, 255), weight = 100000, chestWeight = 160000, mult = 1.8 },
	{ id = "Epico", name = "Épico", upper = "ÉPICO", order = 4, color = Color3.fromRGB(185, 85, 255), weight = 40000, chestWeight = 70000, mult = 2.5 },
	{ id = "Lendario", name = "Lendário", upper = "LENDÁRIO", order = 5, color = Color3.fromRGB(255, 185, 35), weight = 9000, chestWeight = 18000, mult = 3.6 },
	{ id = "Mitico", name = "Mítico", upper = "MÍTICO", order = 6, color = Color3.fromRGB(255, 55, 75), weight = 990, chestWeight = 1900, mult = 5.2 },
	{ id = "Secreto", name = "Secreto", upper = "SECRETO", order = 7, color = Color3.fromRGB(255, 255, 255), weight = 10, chestWeight = 100, mult = 8.0, rainbow = true },
	-- Único: itens com efeito próprio que só caem de chefes específicos (chance fixa por item, ver
	-- Enemies.Defs[x].uniques). Nunca sai de baú nem de sorteio de raridade (peso 0).
	{ id = "Unico", name = "Único", upper = "ÚNICO", order = 8, color = Color3.fromRGB(60, 255, 215), weight = 0, chestWeight = 0, mult = 5.5, unique = true },
}

Rarities.ById = {}
Rarities.ByOrder = {}
for _, rarity in Rarities.List do
	Rarities.ById[rarity.id] = rarity
	Rarities.ByOrder[rarity.order] = rarity
end

local rng = Random.new()

-- Sorteia uma raridade. weightKey = "weight" (drops) ou "chestWeight" (baú).
-- minOrder garante uma raridade mínima (ex.: chefes só dropam Raro+).
function Rarities.roll(weightKey, minOrder)
	weightKey = weightKey or "weight"
	minOrder = minOrder or 1
	local total = 0
	for _, rarity in Rarities.List do
		if rarity.order >= minOrder then
			total += rarity[weightKey]
		end
	end
	local pick = rng:NextNumber() * total
	for _, rarity in Rarities.List do
		if rarity.order >= minOrder then
			pick -= rarity[weightKey]
			if pick <= 0 and rarity[weightKey] > 0 then
				return rarity
			end
		end
	end
	return Rarities.ById.Secreto
end

-- Lista com a porcentagem real de cada raridade (mostrada na UI do baú).
function Rarities.odds(weightKey, minOrder)
	weightKey = weightKey or "weight"
	minOrder = minOrder or 1
	local total = 0
	for _, rarity in Rarities.List do
		if rarity.order >= minOrder then
			total += rarity[weightKey]
		end
	end
	local result = {}
	for _, rarity in Rarities.List do
		if rarity.order >= minOrder and rarity[weightKey] > 0 then
			table.insert(result, { rarity = rarity, percent = rarity[weightKey] / total * 100 })
		end
	end
	return result
end

return Rarities
