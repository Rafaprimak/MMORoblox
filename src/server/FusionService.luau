-- Fusão de equipamentos (como o cubo do Task Bar Hero): 9 itens da MESMA raridade viram 1 item pelo
-- menos uma raridade acima, com chance pequena de pular mais (Config.Fusion). O item novo é de uma das
-- bases que você colocou (sorteada entre as 9) e sai no maior nível entre elas. Únicos e itens
-- equipados não entram; Secreto já é o máximo.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Rarities = require(Shared.Rarities)

local DataService = require(script.Parent.DataService)
local PlayerService = require(script.Parent.PlayerService)

local FusionService = {}

FusionService.QuestHook = function(_player, _kind, _target, _amount) end

local rng = Random.new()

local function isEquipped(data, uid)
	for _, equippedUid in data.equipped do
		if equippedUid == uid then
			return true
		end
	end
	return false
end

-- quantas raridades o resultado sobe (1, 2 ou 3), pelas chances de Config.Fusion
local function rollJump()
	local roll = rng:NextNumber()
	local acc = 0
	for _, entry in Config.Fusion.jumps do
		acc += entry.chance
		if roll <= acc then
			return entry.jump
		end
	end
	return 1
end

function FusionService.fuse(player, uids)
	local data = DataService.get(player)
	if not data or type(uids) ~= "table" then
		return { ok = false, msg = "Escolha os itens." }
	end
	local count = Config.Fusion.count
	if #uids ~= count then
		return { ok = false, msg = ("A fusão precisa de exatamente %d itens."):format(count) }
	end
	local seen, items, rarityOrder = {}, {}, nil
	for _, uid in uids do
		if type(uid) ~= "string" or seen[uid] then
			return { ok = false, msg = "Itens inválidos." }
		end
		seen[uid] = true
		local item = data.inventory[uid]
		local base = item and Items.Bases[item.base]
		local rarity = item and Rarities.ById[item.rarity]
		if not item or not base or not rarity then
			return { ok = false, msg = "Item não encontrado." }
		end
		if isEquipped(data, uid) then
			return { ok = false, msg = "Tire o item equipado antes de fundir." }
		end
		if rarity.unique then
			return { ok = false, msg = "Itens Únicos não podem ser fundidos." }
		end
		if rarityOrder and rarity.order ~= rarityOrder then
			return { ok = false, msg = "Todos os itens precisam ter a mesma raridade." }
		end
		rarityOrder = rarity.order
		table.insert(items, item)
	end
	local maxOrder = Rarities.ById.Secreto.order
	if rarityOrder >= maxOrder then
		return { ok = false, msg = "Secreto já é a raridade máxima." }
	end
	-- resultado
	local resultOrder = math.min(maxOrder, rarityOrder + rollJump())
	local pick = items[rng:NextInteger(1, #items)]
	local level = 1
	for _, item in items do
		level = math.max(level, item.level)
	end
	for _, uid in uids do
		data.inventory[uid] = nil
	end
	local result = Items.create(pick.base, Rarities.ByOrder[resultOrder].id, level)
	PlayerService.addItem(player, result, { force = true })
	FusionService.QuestHook(player, "fusion", Rarities.ByOrder[resultOrder].id, 1)
	PlayerService.markDirty(player)
	return { ok = true, item = Items.describe(result, false), jump = resultOrder - rarityOrder }
end

return FusionService
