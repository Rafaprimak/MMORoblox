-- Mercado dos Caçadores: casa de leilão global (todos os servidores), à prova de duplicação.
--
-- Onde fica cada coisa:
--   * Anúncio (fonte da verdade): DataStore "Mercado_v1", chave "anuncio_<id>":
--     { id, seller, sellerName, item | material = { id, count }, price, created, expires,
--       state = "ativo" | "vendido" | "cancelado" | "expirado", buyer }
--   * Índice para buscar (rápido, some sozinho): MemoryStore SortedMap "MercadoIndice", ordenado pelo preço.
--   * Custódia no PERFIL de cada jogador (gravada antes de qualquer passo no mercado):
--       data.market.selling[id] = cópia do que foi anunciado (sai do inventário ao anunciar);
--       data.market.buying[id]  = ouro separado para uma compra em andamento.
--
-- Fluxos (cada passo pode cair no meio sem duplicar nem sumir nada):
--   VENDER:   item → custódia (grava o perfil) → cria o anúncio → índice.
--   COMPRAR:  ouro → custódia (grava o perfil) → UpdateAsync no anúncio (só passa se ainda "ativo")
--             → item para o comprador e limpa a custódia (grava). Se o anúncio já foi, devolve o ouro.
--   ACERTO:   de minuto em minuto (e ao entrar), cada jogador resolve a própria custódia pelo estado do
--             anúncio: vendido = recebe o ouro (menos a taxa); cancelado/expirado/sumido = item volta;
--             compra pendente = recebe o item se o anúncio é dele, senão o ouro volta.
-- O perfil de cada jogador só é aberto por um servidor por vez (trava do DataService), então a custódia
-- de cada um é resolvida uma única vez.
local DataStoreService = game:GetService("DataStoreService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Rarities = require(Shared.Rarities)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local PlayerService = require(script.Parent.PlayerService)

local MarketService = {}

MarketService.QuestHook = function(_player, _kind, _target, _amount) end

local DURATION = 48 * 3600
local MAX_LISTINGS = 10
local MIN_PRICE, MAX_PRICE = 10, 10000000
local TAX = 0.1 -- 10% do valor fica com o mercado (tira ouro de circulação)
local FEE = 0.01 -- 1% para anunciar (mínimo 5)
local BROWSE_CACHE = 8 -- segundos

local store, index = nil, nil
pcall(function()
	store = DataStoreService:GetDataStore("Mercado_v1")
	index = MemoryStoreService:GetSortedMap("MercadoIndice")
end)

local busy = {} -- [player] = true durante uma operação (um pedido de mercado por vez)
local cache = { time = 0, entries = {} }

local function available()
	return store ~= nil and index ~= nil
end

local function listingKey(id)
	return "anuncio_" .. id
end

local function isEquipped(data, uid)
	for _, equippedUid in data.equipped do
		if equippedUid == uid then
			return true
		end
	end
	return false
end

local function countInventory(data)
	local n = 0
	for _ in data.inventory do
		n += 1
	end
	return n
end

local function getListing(id)
	local ok, value = pcall(store.GetAsync, store, listingKey(id))
	if not ok then
		return false, nil
	end
	return true, value
end

-- resumo para o índice e para a interface
local function summary(listing)
	local entry = { id = listing.id, seller = listing.sellerName, sellerId = listing.seller, price = listing.price, expires = listing.expires }
	if listing.item then
		local item = listing.item
		local rarity = Rarities.ById[item.rarity] or Rarities.List[1]
		local base = Items.Bases[item.base] or {}
		entry.kind = "item"
		entry.base = item.base
		entry.name = Items.displayName(item)
		entry.rarity = item.rarity
		entry.order = rarity.order
		entry.level = item.level
		entry.power = Items.getPower(item)
		entry.slot = base.slot
		entry.weaponType = base.weaponType
		local perks = {}
		for _, perkId in item.perks or {} do
			table.insert(perks, perkId)
		end
		entry.perks = perks
	else
		local def = Items.Materials[listing.material.id]
		entry.kind = "material"
		entry.material = listing.material.id
		entry.name = def and def.name or listing.material.id
		entry.count = listing.material.count
		entry.order = 0
	end
	return entry
end

local function indexAdd(listing)
	pcall(function()
		index:SetAsync(listing.id, HttpService:JSONEncode(summary(listing)), DURATION + 600, listing.price)
	end)
	cache.time = 0
end

local function indexRemove(id)
	pcall(function()
		index:RemoveAsync(id)
	end)
	cache.time = 0
end

-- ===================== ACERTO DA CUSTÓDIA =====================

local function returnToSeller(data, entry)
	if entry.item then
		data.inventory[entry.item.uid] = entry.item -- (pode passar do limite: é devolução)
	elseif entry.material then
		data.materials[entry.material.id] = (data.materials[entry.material.id] or 0) + entry.material.count
	end
end

-- resolve tudo que está em custódia no perfil do jogador
function MarketService.settle(player)
	if not available() or busy[player] then
		return
	end
	local data = DataService.get(player)
	if not data then
		return
	end
	busy[player] = true
	local changed = false
	-- anúncios do jogador
	for id, entry in data.market.selling do
		local ok, listing = getListing(id)
		if ok then
			if listing and listing.state == "ativo" and os.time() > listing.expires then
				-- vence o anúncio (atômico: se alguém comprou no mesmo instante, vale a compra)
				pcall(function()
					store:UpdateAsync(listingKey(id), function(current)
						if current and current.state == "ativo" and os.time() > current.expires then
							current.state = "expirado"
							return current
						end
						return nil
					end)
				end)
				ok, listing = getListing(id)
			end
			if ok and (not listing or listing.state == "cancelado" or listing.state == "expirado") then
				returnToSeller(data, entry)
				data.market.selling[id] = nil
				changed = true
				indexRemove(id)
				Remotes.Notify:FireClient(player, { kind = "message", text = ("Seu anúncio de %s voltou para você."):format(entry.name or "item") })
			elseif ok and listing.state == "vendido" then
				local earned = math.floor(listing.price * (1 - TAX))
				data.gold += earned
				data.market.selling[id] = nil
				changed = true
				indexRemove(id)
				Remotes.Notify:FireClient(player, { kind = "banner", text = "VENDIDO NO MERCADO!", sub = ("%s por %s de ouro (você recebeu %s, já sem a taxa)"):format(entry.name or "item", listing.price, earned), color = Color3.fromRGB(255, 215, 90), duration = 5 })
				MarketService.QuestHook(player, "marketSell", nil, 1)
			end
		end
	end
	-- compras em andamento
	for id, price in data.market.buying do
		local ok, listing = getListing(id)
		if ok then
			if listing and listing.state == "vendido" and listing.buyer == player.UserId then
				if listing.item then
					local item = table.clone(listing.item)
					item.uid = HttpService:GenerateGUID(false)
					data.inventory[item.uid] = item
				elseif listing.material then
					data.materials[listing.material.id] = (data.materials[listing.material.id] or 0) + listing.material.count
				end
			else
				data.gold += price -- a compra não aconteceu: o ouro volta
			end
			data.market.buying[id] = nil
			changed = true
		end
	end
	if changed then
		PlayerService.markDirty(player)
		DataService.save(player)
	end
	busy[player] = nil
end

-- ===================== PEDIDOS =====================

local function guard(player)
	if not available() then
		return nil, "O mercado está indisponível agora (precisa do jogo publicado)."
	end
	local data = DataService.get(player)
	if not data then
		return nil, "Perfil não carregado."
	end
	if data.level < Config.TradeMinLevel then
		return nil, ("O mercado libera no nível %d."):format(Config.TradeMinLevel)
	end
	if busy[player] then
		return nil, "Espere a operação anterior terminar."
	end
	return data
end

-- anunciar: what = { uid = "..." } (equipamento) ou { material = "id", count = n }
function MarketService.sell(player, what, price)
	local data, err = guard(player)
	if not data then
		return { ok = false, msg = err }
	end
	if type(what) ~= "table" or typeof(price) ~= "number" or price ~= price then
		return { ok = false, msg = "Anúncio inválido." }
	end
	price = math.floor(price)
	if price < MIN_PRICE or price > MAX_PRICE then
		return { ok = false, msg = ("O preço vai de %d a %d de ouro."):format(MIN_PRICE, MAX_PRICE) }
	end
	local active = 0
	for _ in data.market.selling do
		active += 1
	end
	if active >= MAX_LISTINGS then
		return { ok = false, msg = ("No máximo %d anúncios ao mesmo tempo."):format(MAX_LISTINGS) }
	end
	local fee = math.max(5, math.floor(price * FEE))
	if data.gold < fee then
		return { ok = false, msg = ("A taxa para anunciar é %d de ouro."):format(fee) }
	end
	local entry = nil
	if type(what.uid) == "string" then
		local item = data.inventory[what.uid]
		if not item then
			return { ok = false, msg = "Item não encontrado." }
		end
		if isEquipped(data, what.uid) then
			return { ok = false, msg = "Desequipe o item antes de anunciar." }
		end
		entry = { item = item, name = Items.displayName(item) }
	elseif type(what.material) == "string" and typeof(what.count) == "number" then
		local def = Items.Materials[what.material]
		local count = math.floor(what.count)
		if not def or def.dungeon == "key" or count < 1 or (data.materials[what.material] or 0) < count then
			return { ok = false, msg = "Você não tem essa quantidade." }
		end
		entry = { material = { id = what.material, count = count }, name = ("%dx %s"):format(count, def.name) }
	else
		return { ok = false, msg = "Anúncio inválido." }
	end
	busy[player] = true
	local id = HttpService:GenerateGUID(false)
	-- 1) item → custódia e grava o perfil
	if entry.item then
		data.inventory[entry.item.uid] = nil
	else
		data.materials[entry.material.id] -= entry.material.count
	end
	data.gold -= fee
	entry.price = price
	data.market.selling[id] = entry
	if not DataService.save(player) then
		returnToSeller(data, entry)
		data.market.selling[id] = nil
		data.gold += fee
		busy[player] = nil
		PlayerService.markDirty(player)
		return { ok = false, msg = "Não deu para salvar agora. Tente de novo." }
	end
	-- 2) cria o anúncio
	local listing = {
		id = id,
		seller = player.UserId,
		sellerName = player.DisplayName,
		item = entry.item,
		material = entry.material,
		price = price,
		created = os.time(),
		expires = os.time() + DURATION,
		state = "ativo",
	}
	local created = pcall(function()
		store:UpdateAsync(listingKey(id), function(current)
			if current then
				return nil
			end
			return listing
		end)
	end)
	if not created then
		-- devolve na hora (o acerto também devolveria depois)
		returnToSeller(data, entry)
		data.market.selling[id] = nil
		data.gold += fee
		DataService.save(player)
		busy[player] = nil
		PlayerService.markDirty(player)
		return { ok = false, msg = "O mercado não respondeu. Seu item voltou." }
	end
	-- 3) índice (se falhar, o anúncio ainda aparece em "Meus anúncios" e pode ser cancelado)
	indexAdd(listing)
	busy[player] = nil
	PlayerService.markDirty(player)
	MarketService.QuestHook(player, "marketList", nil, 1)
	return { ok = true, msg = ("Anunciado por %d de ouro (taxa de %d paga). Fica 48 h no mercado."):format(price, fee) }
end

function MarketService.buy(player, id)
	local data, err = guard(player)
	if not data then
		return { ok = false, msg = err }
	end
	if type(id) ~= "string" or #id > 60 then
		return { ok = false, msg = "Anúncio inválido." }
	end
	local ok, listing = getListing(id)
	if not ok then
		return { ok = false, msg = "O mercado não respondeu. Tente de novo." }
	end
	if not listing or listing.state ~= "ativo" or os.time() > listing.expires then
		indexRemove(id)
		return { ok = false, msg = "Esse anúncio não está mais disponível." }
	end
	if listing.seller == player.UserId then
		return { ok = false, msg = "Esse anúncio é seu (cancele em \"Meus anúncios\")." }
	end
	if data.gold < listing.price then
		return { ok = false, msg = "Ouro insuficiente." }
	end
	if listing.item and countInventory(data) >= Config.MaxInventory then
		return { ok = false, msg = "Inventário cheio." }
	end
	busy[player] = true
	-- 1) ouro → custódia e grava
	data.gold -= listing.price
	data.market.buying[id] = listing.price
	if not DataService.save(player) then
		data.gold += listing.price
		data.market.buying[id] = nil
		busy[player] = nil
		PlayerService.markDirty(player)
		return { ok = false, msg = "Não deu para salvar agora. Tente de novo." }
	end
	-- 2) toma o anúncio (só um comprador consegue)
	local won = false
	local claimed = pcall(function()
		store:UpdateAsync(listingKey(id), function(current)
			won = false
			if current and current.state == "ativo" and os.time() <= current.expires and current.price == listing.price then
				current.state = "vendido"
				current.buyer = player.UserId
				current.soldAt = os.time()
				won = true
				return current
			end
			return nil
		end)
	end)
	busy[player] = nil
	-- 3) entrega (ou devolve) pelo acerto, que é o mesmo caminho da recuperação depois de uma queda
	if claimed then
		indexRemove(id)
		MarketService.settle(player)
	end
	if claimed and won then
		MarketService.QuestHook(player, "marketBuy", nil, 1)
		-- avisa o vendedor se ele estiver neste servidor (nos outros, o acerto de minuto em minuto avisa)
		local seller = Players:GetPlayerByUserId(listing.seller)
		if seller then
			task.spawn(MarketService.settle, seller)
		end
		return { ok = true, msg = "Compra feita! O item está no seu inventário." }
	end
	if not claimed then
		return { ok = false, msg = "O mercado não respondeu. Seu ouro volta em instantes." }
	end
	return { ok = false, msg = "Alguém comprou antes de você. Seu ouro voltou." }
end

function MarketService.cancel(player, id)
	local data, err = guard(player)
	if not data then
		return { ok = false, msg = err }
	end
	if type(id) ~= "string" or not data.market.selling[id] then
		return { ok = false, msg = "Anúncio não encontrado." }
	end
	local ok = pcall(function()
		store:UpdateAsync(listingKey(id), function(current)
			if current and current.state == "ativo" and current.seller == player.UserId then
				current.state = "cancelado"
				return current
			end
			return nil
		end)
	end)
	if not ok then
		return { ok = false, msg = "O mercado não respondeu. Tente de novo." }
	end
	MarketService.settle(player)
	return { ok = true }
end

-- busca: filter = { text, rarity, kind ("item" | "material"), slot }
function MarketService.browse(player, filter)
	if not available() then
		return { ok = false, msg = "O mercado está indisponível agora (precisa do jogo publicado)." }
	end
	if os.clock() - cache.time > BROWSE_CACHE then
		local ok, entries = pcall(function()
			return index:GetRangeAsync(Enum.SortDirection.Ascending, 200)
		end)
		if not ok then
			return { ok = false, msg = "O mercado não respondeu. Tente de novo." }
		end
		cache.entries = {}
		for _, entry in entries do
			pcall(function()
				local value = HttpService:JSONDecode(entry.value)
				if value.expires > os.time() then
					table.insert(cache.entries, value)
				end
			end)
		end
		cache.time = os.clock()
	end
	filter = if type(filter) == "table" then filter else {}
	local text = if type(filter.text) == "string" then string.lower(filter.text) else ""
	local results = {}
	for _, entry in cache.entries do
		local match = (text == "" or string.find(string.lower(entry.name or ""), text, 1, true) ~= nil)
			and (filter.kind == nil or filter.kind == entry.kind)
			and (filter.rarity == nil or filter.rarity == entry.rarity)
			and (filter.slot == nil or filter.slot == entry.slot)
			and entry.sellerId ~= player.UserId
		if match then
			table.insert(results, entry)
			if #results >= 60 then
				break
			end
		end
	end
	return { ok = true, list = results }
end

-- anúncios do próprio jogador (lidos da custódia; o estado vem do acerto)
function MarketService.mine(player)
	local data = DataService.get(player)
	if not data then
		return { ok = false }
	end
	local list = {}
	for id, entry in data.market.selling do
		table.insert(list, { id = id, name = entry.name, price = entry.price, base = entry.item and entry.item.base, rarity = entry.item and entry.item.rarity, material = entry.material and entry.material.id })
	end
	return { ok = true, list = list, tax = TAX, fee = FEE }
end

function MarketService.onPlayerRemoving(player)
	busy[player] = nil
end

function MarketService.start()
	-- acerto de minuto em minuto (vendas feitas em outros servidores, anúncios vencidos)
	task.spawn(function()
		while true do
			task.wait(60)
			for _, player in Players:GetPlayers() do
				local data = DataService.get(player)
				if data and (next(data.market.selling) or next(data.market.buying)) then
					pcall(MarketService.settle, player)
				end
			end
		end
	end)
end

-- ao entrar: resolve o que ficou pendente
function MarketService.onProfileLoaded(player)
	task.delay(5, function()
		if player.Parent == Players then
			pcall(MarketService.settle, player)
		end
	end)
end

return MarketService
