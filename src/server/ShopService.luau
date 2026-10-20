-- Baús: pagos com ouro do jogo. A animação de roleta acontece no cliente com o resultado do servidor.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared.Items)
local Chests = require(Shared.Chests)
local Rarities = require(Shared.Rarities)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local PlayerService = require(script.Parent.PlayerService)

local ShopService = {}

ShopService.QuestHook = function(_player, _kind, _target, _amount) end

local function roll(player, chestId)
	local data = DataService.get(player)
	local chest = Chests.List[chestId]
	local base = Items.ChestPool[math.random(1, #Items.ChestPool)]
	local rarity = Rarities.roll(Chests.WeightKey, chest.minRarity)
	local item = Items.create(base, rarity.id, data.level)
	data.stats.chests += 1
	PlayerService.addItem(player, item, { silent = true })
	ShopService.QuestHook(player, "chest", chestId, 1)
	PlayerService.markDirty(player)
	return item
end

function ShopService.open(player, chestId)
	local data = DataService.get(player)
	local chest = Chests.List[chestId]
	if not data or not chest then
		return { ok = false, msg = "Baú inválido." }
	end
	if data.gold < chest.price then
		return { ok = false, msg = ("Ouro insuficiente! O %s custa %d."):format(chest.name, chest.price) }
	end
	data.gold -= chest.price
	local item = roll(player, chestId)
	return { ok = true, chest = chestId, item = Items.describe(item, false) }
end

-- Baú grátis (recompensa de missão): mostra a roleta no cliente
function ShopService.grant(player, chestId)
	if not Chests.List[chestId] or not DataService.get(player) then
		return
	end
	local item = roll(player, chestId)
	task.delay(1.2, function()
		Remotes.Notify:FireClient(player, { kind = "chest", chest = chestId, item = Items.describe(item, false) })
	end)
end

return ShopService
