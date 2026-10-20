-- Baú do Hunter: pago com ouro do jogo (não com Robux).
-- Se um dia o baú puder ser comprado com Robux (direta ou indiretamente), o Roblox exige
-- mostrar as chances exatas antes da compra. A UI do baú já mostra.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Items = require(Shared.Items)

local DataService = require(script.Parent.DataService)
local PlayerService = require(script.Parent.PlayerService)

local ShopService = {}

function ShopService.grantChest(player, countForQuest)
	local data = DataService.get(player)
	if not data then
		return { ok = false, msg = "Seus dados ainda estão carregando..." }
	end
	local item = Items.rollDrop(Items.ChestPool, data.level, "chestWeight", 1)
	data.stats.chests += 1
	PlayerService.addItem(player, item, { silent = true })
	if countForQuest then
		PlayerService.QuestHook(player, "chest", nil, 1)
	end
	PlayerService.markDirty(player)
	return { ok = true, item = Items.describe(item, false) }
end

function ShopService.openChest(player)
	local data = DataService.get(player)
	if not data then
		return { ok = false, msg = "Seus dados ainda estão carregando..." }
	end
	if data.gold < Config.ChestCost then
		return { ok = false, msg = ("Ouro insuficiente! O baú custa %d."):format(Config.ChestCost) }
	end
	data.gold -= Config.ChestCost
	return ShopService.grantChest(player, true)
end

return ShopService
