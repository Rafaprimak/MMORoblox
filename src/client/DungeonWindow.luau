-- Masmorras no cliente: janela do portal (grupo, ponto de retorno, começar), janela do Mercador de
-- Masmorras (loja, itens exclusivos, progresso) e o painel do andar durante a masmorra.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Dungeons = require(Shared.Dungeons)
local Rarities = require(Shared.Rarities)
local Items = require(Shared.Items)
local Perks = require(Shared.Perks)

local UI = require(script.Parent.UI)
local Popups = require(script.Parent.Popups)
local State = require(script.Parent.State)
local Window = require(script.Parent.Window)
local Sounds = require(script.Parent.Sounds)
local ItemIcon = require(script.Parent.ItemIcon)
local Enemies = require(Shared.Enemies)

local DungeonWindow = {}

local portal = {} -- janela do portal
local shop = {} -- janela do mercador
local tracker = {} -- painel do andar
local currentId = nil

local function text(parent, props)
	local merged = { Size = UDim2.new(1, 0, 0, 18), TextScaled = false, TextSize = 15, TextWrapped = true, Font = Enum.Font.GothamBold }
	for key, value in props do
		merged[key] = value
	end
	return UI.label(merged)
end

local function materialName(id)
	local def = Items.Materials[id] or Items.Consumables[id]
	return if def then def.name else id
end

local function priceText(gold, materialId, amount)
	return ("%s ouro + %d %s"):format(UI.formatNumber(gold), amount, materialName(materialId))
end

local function dungeonInfo(data)
	return (data and data.dungeon) or {}
end

-- ===================== PORTAL =====================

local function renderPortal()
	local data = State.data
	local dungeon = currentId and Dungeons.ById[currentId]
	if not data or not dungeon then
		return
	end
	UI.clear(portal.body)
	local info = dungeonInfo(data)
	local best = (info.best and info.best[dungeon.id]) or 0
	portal.win.title.Text = string.upper(dungeon.name)
	text(portal.body, { Text = dungeon.text, Size = UDim2.new(1, 0, 0, 40), TextColor3 = UI.Colors.SubText, LayoutOrder = 1, Parent = portal.body })
	text(portal.body, { Text = ("Nível mínimo %d  •  recomendado %d+  •  %d andares, chefe a cada %d"):format(dungeon.minLevel, dungeon.level, Dungeons.Floors, Dungeons.BossEvery), LayoutOrder = 2, Parent = portal.body })
	text(portal.body, { Text = ("Seu recorde: %s  •  material: %s (você tem %d)"):format(if best > 0 then ("andar %d de %d"):format(best, Dungeons.Floors) else "nenhum andar ainda", materialName(dungeon.material), State.materialCount(dungeon.material)), LayoutOrder = 3, TextColor3 = UI.Colors.Gold, Parent = portal.body })
	if dungeon.key then
		local has = State.materialCount(dungeon.key)
		text(portal.body, { Text = ("Precisa de: %s (você tem %d) — o líder do grupo gasta uma"):format(materialName(dungeon.key), has), LayoutOrder = 4, TextColor3 = if has > 0 then Color3.fromRGB(140, 230, 140) else Color3.fromRGB(255, 120, 110), Parent = portal.body })
	end
	-- grupo
	local lobby = info.lobby
	local inLobby = lobby ~= nil and lobby.id == dungeon.id
	local names = {}
	if inLobby then
		for i, name in lobby.members do
			table.insert(names, (if lobby.ready[i] then "[pronto] " else "… ") .. name .. (if i == 1 then " (líder)" else ""))
		end
	end
	local members = if inLobby then table.concat(names, "   ") else "você ainda não entrou no grupo"
	text(portal.body, { Text = ("Grupo (%d/%d): %s"):format(if inLobby then #lobby.members else 0, Dungeons.MaxPlayers, members), Size = UDim2.new(1, 0, 0, 36), LayoutOrder = 5, Parent = portal.body })
	text(portal.body, { Text = "Uma corrida só, do andar 1 ao 20: sair ou deixar o grupo é recomeçar. Começa quando TODOS derem Pronto (ou use o botão Entrar sozinho). A vida dos inimigos cresce com o grupo; tanque, suporte e dano fazem diferença.", Size = UDim2.new(1, 0, 0, 36), TextSize = 13, TextColor3 = UI.Colors.SubText, LayoutOrder = 6, Parent = portal.body })
	-- modificadores da semana (deixam mais difícil e mais recompensador)
	local modifiers = {}
	for _, modifier in Dungeons.weeklyModifiers() do
		table.insert(modifiers, ("%s: %s"):format(modifier.name, modifier.text))
	end
	text(portal.body, { Text = "Semana: " .. table.concat(modifiers, "  •  ") .. "  (recompensas maiores)", Size = UDim2.new(1, 0, 0, 34), TextSize = 13, TextColor3 = Color3.fromRGB(255, 150, 110), LayoutOrder = 6, Parent = portal.body })
	local row = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, LayoutOrder = 7, Parent = portal.body }, { UI.list(8, true) })
	local rankingButton = UI.button({ Text = "Ranking da semana", Size = UDim2.fromOffset(170, 38), BackgroundColor3 = UI.Colors.Dark, LayoutOrder = 9, Parent = row })
	rankingButton.MouseButton1Click:Connect(function()
		local result = State.request("dungeonRanking", dungeon.id)
		if not result or not result.ok then
			Popups.message(result and result.msg or "Ranking indisponível.", UI.Colors.SubText)
			return
		end
		local lines = {}
		for _, entry in result.list do
			table.insert(lines, ("%d. %d:%02d  —  %s"):format(entry.position, math.floor(entry.seconds / 60), entry.seconds % 60, entry.names))
		end
		Popups.banner(("MELHORES TEMPOS: %s"):format(string.upper(dungeon.name)), if #lines > 0 then table.concat(lines, "\n") else "Ninguém completou os 20 andares nesta semana. Seja o primeiro!", UI.Colors.Gold, 8)
	end)
	local joinButton = UI.button({ Text = if inLobby then "Sair do grupo" else "Entrar no grupo", Size = UDim2.fromOffset(180, 38), BackgroundColor3 = if inLobby then Color3.fromRGB(150, 60, 60) else UI.Colors.Accent, Parent = row })
	joinButton.MouseButton1Click:Connect(function()
		if inLobby then
			State.request("dungeonLeaveLobby")
		else
			State.request("dungeonJoin", dungeon.id)
		end
	end)
	if not inLobby then
		-- entra na hora, só você (sem sala nem Pronto; a chave sai de você)
		local soloButton = UI.button({ Text = "Entrar sozinho", Size = UDim2.fromOffset(180, 38), BackgroundColor3 = UI.Colors.Green, Parent = row })
		soloButton.MouseButton1Click:Connect(function()
			local result = State.request("dungeonSolo", dungeon.id)
			if result and result.ok then
				Sounds.play("ping", 1.3, 0.5)
				portal.win:close()
			end
		end)
	end
	if inLobby then
		local readyButton = UI.button({ Text = if lobby.me then "Cancelar pronto" else "PRONTO", Size = UDim2.fromOffset(180, 38), BackgroundColor3 = if lobby.me then Color3.fromRGB(150, 120, 60) else UI.Colors.Green, Parent = row })
		readyButton.MouseButton1Click:Connect(function()
			local result = State.request("dungeonReady", not lobby.me)
			if result and result.ok then
				Sounds.play("ping", 1.3, 0.5)
			end
		end)
		if lobby.startsIn then
			text(portal.body, { Text = ("Todos prontos! Entrando em %d..."):format(lobby.startsIn), LayoutOrder = 8, TextSize = 18, TextColor3 = Color3.fromRGB(140, 230, 140), Parent = portal.body })
		else
			local waiting = 0
			for _, flag in lobby.ready do
				if not flag then
					waiting += 1
				end
			end
			text(portal.body, { Text = ("Esperando %d %s dar Pronto."):format(waiting, if waiting == 1 then "jogador" else "jogadores"), LayoutOrder = 8, TextColor3 = UI.Colors.SubText, Parent = portal.body })
		end
	end
end

-- ===================== MERCADOR =====================

local function shopRow(parent, order, height)
	return UI.new("Frame", { Size = UDim2.new(1, -8, 0, height or 54), BackgroundColor3 = UI.Colors.PanelLight, BackgroundTransparency = 0.3, LayoutOrder = order, Parent = parent }, { UI.corner(10) })
end

local lastShopKey = nil

-- force: abriu a janela ou trocou de aba. Sem isso, só redesenha se o ouro ou os materiais mudaram
-- (a janela tem muitos ícones 3D)
local function renderShop(force)
	local data = State.data
	if not data then
		return
	end
	local keyParts = { tostring(shop.win.tab), tostring(data.gold) }
	for _, dungeon in Dungeons.List do
		table.insert(keyParts, State.materialCount(dungeon.material))
		table.insert(keyParts, State.materialCount(dungeon.key or ""))
	end
	for _, entry in Dungeons.Shop do
		table.insert(keyParts, data.consumables[entry.id] or 0)
	end
	local key = table.concat(keyParts, "|")
	if not force and key == lastShopKey then
		return
	end
	lastShopKey = key
	UI.clear(shop.list)
	shop.win.title.Text = ("MERCADOR DE MASMORRAS  •  %s ouro"):format(UI.formatNumber(data.gold))
	local wallet = {}
	for _, dungeon in Dungeons.List do
		table.insert(wallet, ("%s: %d"):format(Items.Materials[dungeon.material].name, State.materialCount(dungeon.material)))
	end
	text(shop.list, { Text = "Seus materiais de masmorra: " .. table.concat(wallet, "   "), LayoutOrder = 0, TextColor3 = UI.Colors.Gold, Parent = shop.list })
	if shop.win.tab == "Loja" then
		for i, entry in Dungeons.Shop do
			local def = Items.Consumables[entry.id] or Items.Materials[entry.id]
			local row = shopRow(shop.list, i)
			UI.icon(def.icon, { Position = UDim2.fromOffset(10, 8), Size = UDim2.fromOffset(38, 38), Parent = row })
			local owned = if entry.kind == "consumable" then (data.consumables[entry.id] or 0) else State.materialCount(entry.id)
			local detail = if entry.kind == "key" then ("abre a %s"):format(Dungeons.ById[def.key].name) elseif def.heal then ("cura %d%% da vida"):format(math.floor(def.heal * 100)) elseif def.defenseBuff then ("+%d%% de defesa por %d s"):format(math.floor(def.defenseBuff * 100), def.buffTime) elseif def.damageBuff then ("+%d%% de dano por %d s"):format(math.floor(def.damageBuff * 100), def.buffTime) else ""
			text(row, { Text = ("%s  (você tem %d)"):format(def.name, owned), Position = UDim2.fromOffset(56, 6), Size = UDim2.new(1, -200, 0, 20), Parent = row })
			text(row, { Text = detail .. "  •  " .. priceText(entry.gold, entry.material[1], entry.material[2]), Position = UDim2.fromOffset(56, 28), Size = UDim2.new(1, -200, 0, 18), TextSize = 13, TextColor3 = UI.Colors.SubText, Parent = row })
			local button = UI.button({ Text = "Comprar", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(120, 36), BackgroundColor3 = UI.Colors.Green, Parent = row })
			button.MouseButton1Click:Connect(function()
				local result = State.request("dungeonBuy", i)
				if result and result.ok then
					Sounds.play("coin", 1, 0.5)
				end
			end)
		end
	elseif shop.win.tab == "Exclusivos" then
		text(shop.list, { Text = "Itens que só existem nas masmorras, sempre com o perk de assinatura. Escolha a raridade: Raro, Épico ou Lendário. Nos baús dos chefes podem sair até Míticos e Secretos.", Size = UDim2.new(1, 0, 0, 36), TextSize = 13, TextColor3 = UI.Colors.SubText, LayoutOrder = 1, Parent = shop.list })
		local order = 2
		for _, dungeon in Dungeons.List do
			text(shop.list, { Text = string.upper(dungeon.name), LayoutOrder = order, TextColor3 = UI.Colors.Gold, Parent = shop.list })
			order += 1
			for _, baseId in dungeon.loot do
				local base = Items.Bases[baseId]
				local perk = Perks.List[base.signature]
				local row = shopRow(shop.list, order, 58)
				order += 1
				ItemIcon.new(row, baseId, "Epico", { Size = UDim2.fromOffset(52, 52), Position = UDim2.fromOffset(2, 3) })
				local setName = base.set and Items.Sets[base.set] and ("  •  conjunto " .. Items.Sets[base.set].name) or ""
				text(row, { Text = ("%s  •  %s%s"):format(base.name, if base.weaponType then Items.WeaponTypes[base.weaponType].name else Items.Slots[base.slot].name, setName), Position = UDim2.fromOffset(58, 5), Size = UDim2.new(1, -300, 0, 18), Parent = row })
				text(row, { Text = ("%s: %s"):format(perk.name, perk.text), Position = UDim2.fromOffset(58, 24), Size = UDim2.new(1, -300, 0, 30), TextSize = 12, TextColor3 = Color3.fromRGB(200, 180, 255), Parent = row })
				local buttons = UI.new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(234, 40), BackgroundTransparency = 1, Parent = row }, { UI.list(4, true) })
				for tierIndex, price in Dungeons.LootPrices do
					local rarity = Rarities.ById[price.rarity]
					local button = UI.button({ Text = ("%s\n%d"):format(rarity.name, price.material), Size = UDim2.fromOffset(74, 40), LayoutOrder = tierIndex, BackgroundColor3 = rarity.color:Lerp(Color3.new(0, 0, 0), 0.45), TextSize = 12, TextScaled = false, Parent = buttons })
					button.MouseButton1Click:Connect(function()
						local result = State.request("dungeonBuyLoot", baseId, tierIndex)
						if result and result.ok then
							Sounds.play("lootRare", 1, 0.6)
						end
					end)
				end
			end
		end
		local prices = {}
		for _, price in Dungeons.LootPrices do
			table.insert(prices, ("%s: %s ouro + %d"):format(Rarities.ById[price.rarity].name, UI.formatNumber(price.gold), price.material))
		end
		text(shop.list, { Text = "Preço (ouro + material da masmorra do item): " .. table.concat(prices, "  •  "), LayoutOrder = order, TextColor3 = UI.Colors.SubText, Parent = shop.list })
	else
		local best = dungeonInfo(data).best or {}
		for i, dungeon in Dungeons.List do
			local reached = best[dungeon.id] or 0
			local row = shopRow(shop.list, i, 92)
			text(row, { Text = ("%s  •  nível %d+"):format(dungeon.name, dungeon.minLevel), Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 0, 20), TextColor3 = UI.Colors.Gold, Parent = row })
			text(row, { Text = dungeon.text, Position = UDim2.fromOffset(12, 28), Size = UDim2.new(1, -24, 0, 34), TextSize = 12, TextColor3 = UI.Colors.SubText, Parent = row })
			local bosses = {}
			for floor = Dungeons.BossEvery, Dungeons.Floors, Dungeons.BossEvery do
				table.insert(bosses, floor .. (if reached >= floor then " (feito)" else ""))
			end
			text(row, { Text = ("Chefes nos andares %s   •   %s"):format(table.concat(bosses, "  "), if dungeon.key then "precisa de " .. materialName(dungeon.key) else "entrada livre"), Position = UDim2.fromOffset(12, 66), Size = UDim2.new(1, -24, 0, 18), TextSize = 13, Parent = row })
		end
		-- conjuntos
		local order = #Dungeons.List + 1
		text(shop.list, { Text = "CONJUNTOS (bônus com 2 e 4 peças equipadas)", LayoutOrder = order, TextColor3 = Color3.fromRGB(120, 255, 170), Parent = shop.list })
		for _, dungeon in Dungeons.List do
			local set = Items.Sets[dungeon.id]
			if set then
				order += 1
				local row = shopRow(shop.list, order, 92)
				for i, pieceId in set.pieces do
					ItemIcon.new(row, pieceId, "Epico", { Size = UDim2.fromOffset(40, 40), Position = UDim2.fromOffset(8 + (i - 1) * 42, 6) })
				end
				text(row, { Text = ("%s  •  %s"):format(set.name, dungeon.name), Position = UDim2.fromOffset(186, 6), Size = UDim2.new(1, -196, 0, 18), TextColor3 = Color3.fromRGB(120, 255, 170), Parent = row })
				text(row, { Text = ("2 peças: %s\n4 peças: %s"):format(set.bonuses[2].text, set.bonuses[4].text), Position = UDim2.fromOffset(12, 50), Size = UDim2.new(1, -24, 0, 38), TextSize = 12, TextColor3 = UI.Colors.SubText, Parent = row })
			end
		end
		-- únicos
		order += 1
		text(shop.list, { Text = ("ÚNICOS (%.1f%% por chefe, o dobro no andar 20)"):format(Enemies.UniqueChance * 100), LayoutOrder = order, TextColor3 = Color3.fromRGB(60, 255, 215), Parent = shop.list })
		for enemyId, def in Enemies.Defs do
			for _, baseId in def.uniques or {} do
				local base = Items.Bases[baseId]
				local perk = Perks.List[base.signature]
				order += 1
				local row = shopRow(shop.list, order, 58)
				ItemIcon.new(row, baseId, "Unico", { Size = UDim2.fromOffset(52, 52), Position = UDim2.fromOffset(2, 3) })
				text(row, { Text = ("%s  •  cai do %s"):format(base.name, def.name), Position = UDim2.fromOffset(58, 5), Size = UDim2.new(1, -66, 0, 18), TextColor3 = Color3.fromRGB(60, 255, 215), Parent = row })
				text(row, { Text = ("%s: %s"):format(perk.name, perk.text), Position = UDim2.fromOffset(58, 24), Size = UDim2.new(1, -66, 0, 30), TextSize = 12, TextColor3 = UI.Colors.SubText, Parent = row })
				local _ = enemyId
			end
		end
	end
end

-- ===================== PAINEL DO ANDAR =====================

local function renderTracker()
	local run = dungeonInfo(State.data).run
	tracker.frame.Visible = run ~= nil
	if not run then
		return
	end
	local dungeon = Dungeons.ById[run.id]
	tracker.title.Text = dungeon and dungeon.name or ""
	tracker.floor.Text = ("Andar %d/%d%s"):format(run.floor, run.floors, if run.boss then "  •  CHEFE" else "")
	local lines = {}
	if run.finished then
		table.insert(lines, ("Concluída! Fecha em %d s"):format(run.closesIn or 0))
	elseif run.cleared then
		table.insert(lines, if run.floor < run.floors then "Andar limpo: desçam a escada" else "Andar limpo")
	else
		table.insert(lines, ("%s  •  inimigos: %d"):format(run.mechanic or "", run.enemies))
	end
	if run.objective then
		table.insert(lines, "» " .. run.objective)
	end
	if run.canClaim then
		table.insert(lines, "Abra o baú do chefe!")
	end
	table.insert(lines, "Grupo: " .. table.concat(run.members, ", "))
	tracker.body.Text = table.concat(lines, "\n")
end

-- ===================== INIT =====================

function DungeonWindow.init(screen)
	portal.win = Window.create(screen, { icon = "castle", name = "Masmorra", title = "MASMORRA", width = 560, height = 470, accent = Color3.fromRGB(180, 120, 255) })
	portal.body = UI.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = portal.win.content }, { UI.list(8) })
	portal.win.onOpen = renderPortal

	shop.win = Window.create(screen, { icon = "castle", name = "MercadorMasmorras", title = "MERCADOR DE MASMORRAS", width = 720, height = 540, tabs = { "Loja", "Exclusivos", "Masmorras" }, accent = Color3.fromRGB(180, 120, 255) })
	shop.list = UI.new("ScrollingFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 5, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = shop.win.content }, { UI.list(8) })
	shop.win.onOpen = function()
		renderShop(true)
	end
	shop.win.onTab = function()
		renderShop(true)
	end

	-- painel do andar (lado direito da tela)
	tracker.frame = UI.new("Frame", {
		Name = "PainelMasmorra",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 150), -- no lugar do quadro de missões, que some dentro da masmorra
		Size = UDim2.fromOffset(300, 150),
		BackgroundColor3 = UI.Colors.Panel,
		BackgroundTransparency = 0.15,
		Visible = false,
		Parent = screen,
	}, { UI.corner(10) })
	UI.ornate(tracker.frame, UI.Colors.Trim, 4)
	tracker.title = UI.label({ Text = "", Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 20), FontFace = UI.TitleFont, TextColor3 = Color3.fromRGB(255, 225, 160), Parent = tracker.frame }, { UI.textStroke(1) })
	tracker.floor = UI.label({ Text = "", Position = UDim2.fromOffset(12, 30), Size = UDim2.new(1, -24, 0, 16), TextColor3 = UI.Colors.Gold, Parent = tracker.frame })
	tracker.body = text(tracker.frame, { Text = "", Position = UDim2.fromOffset(12, 50), Size = UDim2.new(1, -24, 0, 70), TextSize = 13, TextYAlignment = Enum.TextYAlignment.Top, Parent = tracker.frame })
	local exit = UI.button({ Text = "Sair da masmorra", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -10, 1, -8), Size = UDim2.fromOffset(150, 26), BackgroundColor3 = Color3.fromRGB(150, 60, 60), Parent = tracker.frame })
	exit.MouseButton1Click:Connect(function()
		State.request("dungeonExit")
	end)

	State.Changed:Connect(function()
		renderTracker()
		if portal.win:isOpen() then
			renderPortal()
		elseif shop.win:isOpen() then
			renderShop()
		end
	end)
end

-- abre a janela do portal (pelo prompt no mapa)
function DungeonWindow.openPortal(id)
	currentId = id
	Window.closeAll()
	portal.win:open()
end

function DungeonWindow.openShop()
	shop.win:open()
end

return DungeonWindow
