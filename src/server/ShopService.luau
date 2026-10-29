-- Baús: pagos com ouro do jogo. A animação de roleta acontece no cliente com o resultado do servidor.
-- Baús ganhos (missões, conquistas, eventos...) vão para a bolsa de baús (data.chestBag) e o jogador abre
-- quando quiser na janela de Baús. Só o baú comprado com Robux abre na hora (reveal = true).
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
	local pool = Items.chestPool(chest.pool)
	local base = pool[math.random(1, #pool)]
	local rarity = Rarities.roll(Chests.weightKey(chest), chest.minRarity)
	local item = Items.create(base, rarity.id, data.level)
	data.stats.chests += 1
	-- baú pago com Robux nunca é vendido sozinho por inventário cheio
	PlayerService.addItem(player, item, { silent = true, force = chest.robux == true })
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
	if chest.robux then
		return { ok = false, msg = "Esse baú é comprado com Robux." }
	end
	if data.gold < chest.price then
		return { ok = false, msg = ("Ouro insuficiente! O %s custa %d."):format(chest.name, chest.price) }
	end
	data.gold -= chest.price
	local item = roll(player, chestId)
	return { ok = true, chest = chestId, item = Items.describe(item, false) }
end

-- Baú ganho: vai para a bolsa de baús. options.reveal = abre na hora com a roleta (compra com Robux)
function ShopService.grant(player, chestId, options)
	local data = DataService.get(player)
	local chest = Chests.List[chestId]
	if not chest or not data then
		return
	end
	if options and options.reveal then
		local item = roll(player, chestId)
		task.delay(1.2, function()
			Remotes.Notify:FireClient(player, { kind = "chest", chest = chestId, item = Items.describe(item, false) })
		end)
		return
	end
	data.chestBag[chestId] = (data.chestBag[chestId] or 0) + 1
	Remotes.Notify:FireClient(player, { kind = "message", text = ("%s guardado! Abra quando quiser em Baús (B)."):format(chest.name) })
	PlayerService.markDirty(player)
end

-- Abre um baú guardado na bolsa (de graça: já foi ganho)
function ShopService.openStored(player, chestId)
	local data = DataService.get(player)
	local chest = typeof(chestId) == "string" and Chests.List[chestId]
	if not data or not chest then
		return { ok = false, msg = "Baú inválido." }
	end
	if (data.chestBag[chestId] or 0) <= 0 then
		return { ok = false, msg = "Você não tem esse baú guardado." }
	end
	data.chestBag[chestId] -= 1
	if data.chestBag[chestId] <= 0 then
		data.chestBag[chestId] = nil
	end
	local item = roll(player, chestId)
	return { ok = true, chest = chestId, item = Items.describe(item, false) }
end

return ShopService
