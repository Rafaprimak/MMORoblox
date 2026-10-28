-- Troca entre jogadores (equipamentos e ouro) com confirmação dupla:
--   convite (perto, nível mínimo) → os dois montam a oferta → "Pronto" (trava a oferta) → "Confirmar".
-- Qualquer mudança na oferta tira o "Pronto" dos dois (ninguém é enganado com troca de última hora).
-- Na confirmação o servidor confere tudo de novo, troca de uma vez, salva os dois e registra.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local PlayerService = require(script.Parent.PlayerService)

local TradeService = {}

local invites = {} -- [convidado] = { from = player, at = os.clock() }
local sessions = {} -- [player] = sessão (a mesma tabela para os dois)

local function other(session, player)
	return if session.a == player then session.b else session.a
end

local function rootOf(player)
	return player.Character and player.Character:FindFirstChild("HumanoidRootPart")
end

local function near(a, b, range)
	local ra, rb = rootOf(a), rootOf(b)
	return ra ~= nil and rb ~= nil and (ra.Position - rb.Position).Magnitude <= range
end

local function isEquipped(data, uid)
	for _, equippedUid in data.equipped do
		if equippedUid == uid then
			return true
		end
	end
	return false
end

local function mark(session)
	PlayerService.markDirty(session.a)
	PlayerService.markDirty(session.b)
end

local function close(session, message)
	sessions[session.a] = nil
	sessions[session.b] = nil
	for _, player in { session.a, session.b } do
		if player.Parent == Players then
			if message then
				Remotes.Notify:FireClient(player, { kind = "message", text = message })
			end
			PlayerService.markDirty(player)
		end
	end
end

local function resetReady(session)
	session.ready = {}
	session.confirm = {}
end

function TradeService.invite(player, targetUserId)
	local target = Players:GetPlayerByUserId(tonumber(targetUserId) or 0)
	local data = DataService.get(player)
	if not target or target == player or not data then
		return { ok = false, msg = "Jogador não encontrado." }
	end
	local targetData = DataService.get(target)
	if not targetData then
		return { ok = false, msg = "Esse jogador ainda está carregando." }
	end
	if data.level < Config.TradeMinLevel or targetData.level < Config.TradeMinLevel then
		return { ok = false, msg = ("Trocas liberam no nível %d (para os dois)."):format(Config.TradeMinLevel) }
	end
	if sessions[player] or sessions[target] then
		return { ok = false, msg = "Um de vocês já está numa troca." }
	end
	if not near(player, target, Config.TradeRange) then
		return { ok = false, msg = "Chegue mais perto para trocar." }
	end
	invites[target] = { from = player, at = os.clock() }
	Remotes.Notify:FireClient(target, { kind = "tradeInvite", from = player.DisplayName, fromId = player.UserId })
	Remotes.Notify:FireClient(player, { kind = "message", text = ("Convite de troca enviado para %s."):format(target.DisplayName) })
	return { ok = true }
end

function TradeService.respond(player, fromUserId, accept)
	local invite = invites[player]
	invites[player] = nil
	local from = invite and invite.from
	if not from or from.UserId ~= tonumber(fromUserId) or os.clock() - invite.at > 30 or from.Parent ~= Players then
		return { ok = false, msg = "O convite expirou." }
	end
	if not accept then
		Remotes.Notify:FireClient(from, { kind = "message", text = player.DisplayName .. " recusou a troca." })
		return { ok = true }
	end
	if sessions[player] or sessions[from] then
		return { ok = false, msg = "Um de vocês já está numa troca." }
	end
	if not near(player, from, Config.TradeRange) then
		return { ok = false, msg = "Chegue mais perto para trocar." }
	end
	local session = { a = from, b = player, offers = { [from] = { items = {}, gold = 0 }, [player] = { items = {}, gold = 0 } }, ready = {}, confirm = {} }
	sessions[from] = session
	sessions[player] = session
	for _, member in { from, player } do
		Remotes.Notify:FireClient(member, { kind = "tradeOpen" })
	end
	mark(session)
	return { ok = true }
end

-- oferta = { items = { uid, ... }, gold = n }
function TradeService.setOffer(player, offer)
	local session = sessions[player]
	local data = DataService.get(player)
	if not session or not data or type(offer) ~= "table" then
		return { ok = false }
	end
	local items, seen = {}, {}
	for _, uid in if type(offer.items) == "table" then offer.items else {} do
		if #items >= Config.TradeMaxItems then
			break
		end
		if type(uid) == "string" and not seen[uid] and data.inventory[uid] and not isEquipped(data, uid) and not (Items.Bases[data.inventory[uid].base] or {}).exotic then
			seen[uid] = true
			table.insert(items, uid)
		end
	end
	local gold = tonumber(offer.gold) or 0
	if gold ~= gold then
		gold = 0 -- NaN
	end
	gold = math.clamp(math.floor(gold), 0, data.gold)
	session.offers[player] = { items = items, gold = gold }
	resetReady(session)
	mark(session)
	return { ok = true }
end

function TradeService.setReady(player, value)
	local session = sessions[player]
	if not session then
		return { ok = false }
	end
	session.ready[player] = value == true or nil
	session.confirm = {}
	mark(session)
	return { ok = true }
end

local function countInventory(data)
	local n = 0
	for _ in data.inventory do
		n += 1
	end
	return n
end

-- confere tudo de novo e troca de uma vez (só com os dois prontos e os dois confirmando)
local function execute(session)
	local a, b = session.a, session.b
	local dataA, dataB = DataService.get(a), DataService.get(b)
	if not dataA or not dataB then
		close(session, "A troca foi cancelada.")
		return
	end
	local offerA, offerB = session.offers[a], session.offers[b]
	for _, check in { { dataA, offerA }, { dataB, offerB } } do
		local data, offer = check[1], check[2]
		if offer.gold > data.gold then
			close(session, "A troca foi cancelada (o ouro mudou).")
			return
		end
		for _, uid in offer.items do
			if not data.inventory[uid] or isEquipped(data, uid) then
				close(session, "A troca foi cancelada (um item mudou).")
				return
			end
		end
	end
	if countInventory(dataA) - #offerA.items + #offerB.items > Config.MaxInventory or countInventory(dataB) - #offerB.items + #offerA.items > Config.MaxInventory then
		close(session, "A troca foi cancelada: alguém ficaria com o inventário cheio.")
		return
	end
	local movedA, movedB = {}, {}
	for _, uid in offerA.items do
		movedA[uid] = dataA.inventory[uid]
		dataA.inventory[uid] = nil
	end
	for _, uid in offerB.items do
		movedB[uid] = dataB.inventory[uid]
		dataB.inventory[uid] = nil
	end
	for uid, item in movedA do
		dataB.inventory[uid] = item
	end
	for uid, item in movedB do
		dataA.inventory[uid] = item
	end
	dataA.gold += offerB.gold - offerA.gold
	dataB.gold += offerA.gold - offerB.gold
	-- registro (últimas 20 trocas de cada um)
	local stamp = os.time()
	for _, entry in { { dataA, b, offerA, offerB }, { dataB, a, offerB, offerA } } do
		local data = entry[1]
		data.tradeLog = data.tradeLog or {}
		table.insert(data.tradeLog, 1, { with = entry[2].UserId, name = entry[2].DisplayName, gave = #entry[3].items, gaveGold = entry[3].gold, got = #entry[4].items, gotGold = entry[4].gold, at = stamp })
		while #data.tradeLog > 20 do
			table.remove(data.tradeLog)
		end
	end
	pcall(DataService.save, a)
	pcall(DataService.save, b)
	close(session, "Troca concluída!")
end

function TradeService.confirm(player)
	local session = sessions[player]
	if not session then
		return { ok = false }
	end
	if not (session.ready[session.a] and session.ready[session.b]) then
		return { ok = false, msg = "Os dois precisam dar Pronto primeiro." }
	end
	session.confirm[player] = true
	if session.confirm[session.a] and session.confirm[session.b] then
		execute(session)
	else
		mark(session)
	end
	return { ok = true }
end

function TradeService.cancel(player)
	local session = sessions[player]
	if session then
		close(session, player.DisplayName .. " cancelou a troca.")
	end
	return { ok = true }
end

function TradeService.onPlayerRemoving(player)
	invites[player] = nil
	local session = sessions[player]
	if session then
		close(session, "A troca foi cancelada (o outro jogador saiu).")
	end
end

local function describeOffer(data, offer)
	local list = {}
	for _, uid in offer.items do
		local item = data and data.inventory[uid]
		if item then
			table.insert(list, Items.describe(item, false))
		end
	end
	return { items = list, gold = offer.gold, uids = offer.items }
end

-- para o cliente (vai no DataUpdate)
function TradeService.summary(player)
	local session = sessions[player]
	if not session then
		return nil
	end
	local partner = other(session, player)
	return {
		partner = partner.DisplayName,
		mine = describeOffer(DataService.get(player), session.offers[player]),
		theirs = describeOffer(DataService.get(partner), session.offers[partner]),
		myReady = session.ready[player] == true,
		theirReady = session.ready[partner] == true,
		myConfirm = session.confirm[player] == true,
		theirConfirm = session.confirm[partner] == true,
	}
end

-- longe demais cancela
task.spawn(function()
	while true do
		task.wait(1)
		local checked = {}
		for _, session in sessions do
			if not checked[session] then
				checked[session] = true
				if not near(session.a, session.b, Config.TradeRange * 1.5) then
					close(session, "A troca foi cancelada (vocês se afastaram).")
				end
			end
		end
	end
end)

return TradeService
