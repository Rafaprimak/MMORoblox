-- Ofícios dos NPCs: forjar, aprimorar, encantar, desmontar, alquimia e loja.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared.Items)
local Rarities = require(Shared.Rarities)
local Recipes = require(Shared.Recipes)
local NPCs = require(Shared.NPCs)

local DataService = require(script.Parent.DataService)
local PlayerService = require(script.Parent.PlayerService)
local SkillService = require(script.Parent.SkillService)

local CraftingService = {}

CraftingService.QuestHook = function(_player, _kind, _target, _amount) end

-- Precisa estar perto de um NPC que oferece o serviço
local function nearService(player, service)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	for _, npc in NPCs.List do
		if npc.services and table.find(npc.services, service) then
			local dx, dz = root.Position.X - npc.x, root.Position.Z - npc.z
			if dx * dx + dz * dz < 30 * 30 then
				return true
			end
		end
	end
	return false
end

local function fail(msg)
	return { ok = false, msg = msg }
end

function CraftingService.forge(player, index)
	local data = DataService.get(player)
	local recipe = typeof(index) == "number" and Recipes.Forge[index]
	if not data or not recipe then
		return fail("Receita inválida.")
	end
	if not nearService(player, "forge") then
		return fail("Vá até a forja do Bruno.")
	end
	local level = SkillService.getLevel(player, "ferraria")
	if level < recipe.skill then
		return fail(("Precisa de Ferraria nível %d."):format(recipe.skill))
	end
	local ok, msg = PlayerService.payCost(player, { gold = recipe.gold, materials = recipe.materials })
	if not ok then
		return fail(msg)
	end
	-- Ferraria alta: chance de rolar duas vezes e ficar com a melhor raridade
	local rarity = Rarities.roll("weight", 1)
	if math.random() < math.min(0.6, level * 0.025) then
		local second = Rarities.roll("weight", 1)
		if second.order > rarity.order then
			rarity = second
		end
	end
	local item = Items.create(recipe.result, rarity.id, data.level)
	PlayerService.addItem(player, item, { silent = true })
	SkillService.addXP(player, "ferraria", Recipes.forgeXp(recipe))
	data.stats.crafted += 1
	CraftingService.QuestHook(player, "craft", "forge", 1)
	CraftingService.QuestHook(player, "craft", recipe.result, 1)
	return { ok = true, item = Items.describe(item, false) }
end

function CraftingService.upgrade(player, uid)
	local data = DataService.get(player)
	local item = data and typeof(uid) == "string" and data.inventory[uid]
	if not item then
		return fail("Item não encontrado.")
	end
	if not nearService(player, "forge") then
		return fail("Vá até a forja do Bruno.")
	end
	if item.upgrade >= Items.MaxUpgrade then
		return fail("Este item já está no nível máximo!")
	end
	local ok, msg = PlayerService.payCost(player, Items.getUpgradeCost(item))
	if not ok then
		return fail(msg)
	end
	item.upgrade += 1
	SkillService.addXP(player, "ferraria", 10 + item.upgrade * 4)
	if PlayerService.isEquipped(player, uid) then
		PlayerService.refreshCharacter(player, { weapon = data.equipped.weapon == uid })
	end
	CraftingService.QuestHook(player, "upgrade", nil, 1)
	CraftingService.QuestHook(player, "upgradeTo", nil, item.upgrade)
	PlayerService.markDirty(player)
	return { ok = true, upgrade = item.upgrade, item = Items.describe(item, PlayerService.isEquipped(player, uid)) }
end

function CraftingService.enchant(player, uid)
	local data = DataService.get(player)
	local item = data and typeof(uid) == "string" and data.inventory[uid]
	local base = item and Items.Bases[item.base]
	if not item or not base then
		return fail("Item não encontrado.")
	end
	if not nearService(player, "enchant") then
		return fail("Vá até a torre do Elric.")
	end
	local ok, msg = PlayerService.payCost(player, Items.getEnchantCost(item))
	if not ok then
		return fail(msg)
	end
	local level = SkillService.getLevel(player, "encantamento")
	local options = Items.EnchantsBySlot[base.slot]
	local maxTier = math.min(5, 2 + math.floor(level / 6))
	local tier = math.random(1, maxTier)
	-- chance extra de subir um tier
	if tier < 5 and math.random() < 0.1 then
		tier += 1
	end
	item.enchant = { id = options[math.random(1, #options)], tier = tier }
	SkillService.addXP(player, "encantamento", 30 + tier * 10)
	if PlayerService.isEquipped(player, uid) then
		PlayerService.refreshCharacter(player, {})
	end
	CraftingService.QuestHook(player, "enchant", nil, 1)
	PlayerService.markDirty(player)
	return { ok = true, item = Items.describe(item, PlayerService.isEquipped(player, uid)) }
end

function CraftingService.disassemble(player, uid)
	local data = DataService.get(player)
	local item = data and typeof(uid) == "string" and data.inventory[uid]
	if not item then
		return fail("Item não encontrado.")
	end
	if not nearService(player, "enchant") then
		return fail("Vá até a torre do Elric.")
	end
	if PlayerService.isEquipped(player, uid) then
		return fail("Desequipe antes de desmontar.")
	end
	local essence = Items.getDisassembleValue(item)
	PlayerService.removeItem(player, uid)
	PlayerService.addMaterial(player, "essencia", essence)
	SkillService.addXP(player, "encantamento", 8 + essence * 2)
	return { ok = true, essence = essence }
end

function CraftingService.alchemy(player, index)
	local data = DataService.get(player)
	local recipe = typeof(index) == "number" and Recipes.Alchemy[index]
	if not data or not recipe then
		return fail("Receita inválida.")
	end
	if not nearService(player, "alchemy") then
		return fail("Vá até o caldeirão da Mira.")
	end
	local level = SkillService.getLevel(player, "alquimia")
	if level < recipe.skill then
		return fail(("Precisa de Alquimia nível %d."):format(recipe.skill))
	end
	local ok, msg = PlayerService.payCost(player, { gold = recipe.gold, materials = recipe.materials })
	if not ok then
		return fail(msg)
	end
	local count = recipe.count
	if math.random() < math.min(0.5, level * 0.025) then
		count += 1
	end
	PlayerService.addConsumable(player, recipe.result, count)
	SkillService.addXP(player, "alquimia", Recipes.alchemyXp(recipe))
	data.stats.crafted += 1
	CraftingService.QuestHook(player, "craft", "alchemy", 1)
	CraftingService.QuestHook(player, "craft", recipe.result, 1)
	return { ok = true, count = count }
end

function CraftingService.buy(player, consumableId, amount)
	local def = Items.Consumables[consumableId]
	amount = math.clamp(math.floor(tonumber(amount) or 1), 1, 20)
	if not def or not def.price or not table.find(Recipes.Shop, consumableId) then
		return fail("Item não está à venda.")
	end
	if not nearService(player, "shop") then
		return fail("Vá até a barraca do Otto.")
	end
	local ok, msg = PlayerService.payCost(player, { gold = def.price * amount })
	if not ok then
		return fail(msg)
	end
	PlayerService.addConsumable(player, consumableId, amount, true)
	return { ok = true }
end

function CraftingService.sellMaterial(player, materialId, amount)
	local data = DataService.get(player)
	local def = Items.Materials[materialId]
	amount = math.floor(tonumber(amount) or 0)
	if not data or not def or amount <= 0 then
		return fail("Inválido.")
	end
	if not nearService(player, "shop") then
		return fail("Vá até a barraca do Otto.")
	end
	local have = data.materials[materialId] or 0
	amount = math.min(amount, have)
	if amount <= 0 then
		return fail("Você não tem esse material.")
	end
	data.materials[materialId] = have - amount
	if data.materials[materialId] <= 0 then
		data.materials[materialId] = nil
	end
	data.gold += def.sell * amount
	PlayerService.markDirty(player)
	return { ok = true, gold = def.sell * amount }
end

return CraftingService
