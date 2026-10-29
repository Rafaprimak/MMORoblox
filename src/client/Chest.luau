-- Baús: escolha do baú, itens possíveis + chances, e a roleta horizontal que desacelera até o prêmio.
-- Abertura (o mais empolgante possível, sem enganar): as cartas da fita saem com as chances REAIS do baú
-- (nada de "quase" colocado de propósito); as cartas perto do centro crescem (lente); quando para, a luz
-- da carta premiada sobe de cor em cor até a raridade verdadeira do item (antecipa, não engana); depois
-- clarão, onda de choque, carimbo da raridade, confete e som. "Pular" mostra o resultado na hora.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared.Items)
local Rarities = require(Shared.Rarities)
local Chests = require(Shared.Chests)

local UI = require(script.Parent.UI)
local ItemIcon = require(script.Parent.ItemIcon)
local Store = require(script.Parent.Store)
local State = require(script.Parent.State)
local Window = require(script.Parent.Window)
local Fx = require(script.Parent.Fx)
local Sounds = require(script.Parent.Sounds)
local RevealScene = require(script.Parent.RevealScene)

local Chest = {}

local CARD_W, CARD_GAP = 120, 10
local REEL_LENGTH = 46
local WIN_INDEX = 40

local win, odds, possible, buyButton
local overlayGui, overlay, reel, reelHolder, resultPanel, resultName, resultInfo, againButton, rays, sceneHolder
local currentScene = nil
local selectedChest = "bronze"
local storedButton -- abre um baú guardado (bolsa de baús)
local openingStored = false -- a última roleta veio da bolsa (o "abrir outro" abre outro guardado)
local revealing = false
local possibleTitle = nil
local raysConnection = nil
local flash, stamp, shockwave, skipButton
local skipping = false

-- carimbo gigante por raridade (ordem 3+)
local STAMPS = { [3] = "RARO!", [4] = "ÉPICO!", [5] = "LENDÁRIO!!", [6] = "MÍTICO!!!", [7] = "SECRETO!!!" }

local function makeCard(parent, baseId, rarity, index)
	local base = Items.Bases[baseId]
	local card = UI.new("Frame", {
		-- âncora no meio: a lente (UIScale) cresce a carta em volta do centro, sem empurrá-la
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset((index - 1) * (CARD_W + CARD_GAP) + CARD_W / 2, 75),
		Size = UDim2.fromOffset(CARD_W, 150),
		BackgroundColor3 = rarity.color:Lerp(Color3.new(0, 0, 0), 0.7),
		Parent = parent,
	}, { UI.corner(10) })
	local stroke = UI.stroke(rarity.color, 3)
	stroke.Parent = card
	UI.new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 8), BackgroundColor3 = rarity.color, Parent = card }, { UI.corner(4) })
	ItemIcon.new(card, baseId, rarity.id, { Size = UDim2.fromScale(0.86, 0.5), Position = UDim2.fromScale(0.5, 0.05), AnchorPoint = Vector2.new(0.5, 0) })
	UI.label({ Text = if base then base.name else "?", Position = UDim2.new(0, 6, 0.56, 0), Size = UDim2.new(1, -12, 0.2, 0), TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = true, Parent = card }, { UI.textStroke(1) })
	UI.label({ Text = rarity.name, Position = UDim2.new(0, 6, 0.77, 0), Size = UDim2.new(1, -12, 0.13, 0), TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = rarity.color, Parent = card }, { UI.textStroke(1) })
	if rarity.rainbow then
		Fx.registerRainbow(stroke, "Color")
	end
	UI.new("UIScale", { Name = "Lupa", Parent = card })
	return card
end

-- onda de choque saindo do centro
local function shock(color)
	shockwave.Size = UDim2.fromOffset(40, 40)
	shockwave.BackgroundTransparency = 1
	local stroke = shockwave:FindFirstChildOfClass("UIStroke")
	stroke.Color = color
	stroke.Transparency = 0
	shockwave.Visible = true
	UI.tween(shockwave, 0.7, { Size = UDim2.fromOffset(900, 900) }, Enum.EasingStyle.Quad)
	UI.tween(stroke, 0.7, { Transparency = 1 })
end

-- carimbo da raridade batendo na tela
local function stampRarity(rarity)
	local label = STAMPS[rarity.order]
	if not label then
		return
	end
	stamp.Text = label
	stamp.TextColor3 = rarity.color
	stamp.TextTransparency = 0
	stamp.Visible = true
	local scale = stamp:FindFirstChildOfClass("UIScale")
	scale.Scale = 3.2
	UI.tween(scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	if rarity.rainbow then
		Fx.registerRainbow(stamp, "TextColor3")
	else
		Fx.unregisterRainbow(stamp)
	end
	task.delay(0.3, function()
		Fx.shake(0.15 + rarity.order * 0.06, 0.25 + rarity.order * 0.05)
	end)
	task.delay(1.8, function()
		UI.tween(stamp, 0.4, { TextTransparency = 1 })
	end)
end

local function confetti(color, count)
	for _ = 1, count do
		local piece = UI.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.45),
			Size = UDim2.fromOffset(math.random(6, 14), math.random(6, 14)),
			BackgroundColor3 = if math.random() < 0.3 then Color3.new(1, 1, 1) else color,
			BorderSizePixel = 0,
			Rotation = math.random(0, 360),
			ZIndex = 8,
			Parent = overlay,
		})
		local angle = math.random() * math.pi * 2
		local distance = math.random(160, 460)
		local duration = 0.6 + math.random() * 0.7
		UI.tween(piece, duration, {
			Position = UDim2.new(0.5, math.cos(angle) * distance, 0.45, math.sin(angle) * distance),
			Rotation = piece.Rotation + math.random(-360, 360),
			BackgroundTransparency = 1,
		})
		Debris:AddItem(piece, duration + 0.05)
	end
end

-- depois de abrir um guardado, o "abrir outro" da roleta abre outro guardado do mesmo tipo
local function storedAgain(stored)
	if openingStored then
		againButton.Text = if stored > 0 then ("ABRIR OUTRO (%d)"):format(stored) else "Sem mais guardados"
		againButton.BackgroundColor3 = if stored > 0 then UI.Colors.Green else UI.Colors.Dark
	end
end

local function renderWindow()
	local chest = Chests.List[selectedChest]
	local data = State.data
	win.title.Text = chest.name
	UI.clear(odds)
	UI.label({ Text = "CHANCES REAIS", Size = UDim2.new(1, 0, 0, 20), Font = Enum.Font.GothamBlack, LayoutOrder = 0, Parent = odds })
	for i, entry in Rarities.odds(Chests.weightKey(chest), chest.minRarity) do
		local row = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 26), BackgroundColor3 = UI.Colors.PanelLight, BackgroundTransparency = 0.3, LayoutOrder = i, Parent = odds }, { UI.corner(6) })
		local dot = UI.new("Frame", { Position = UDim2.fromOffset(8, 6), Size = UDim2.fromOffset(14, 14), BackgroundColor3 = entry.rarity.color, Parent = row }, { UI.corner(7) })
		local name = UI.label({ Text = entry.rarity.name, Position = UDim2.fromOffset(30, 3), Size = UDim2.fromOffset(120, 20), TextColor3 = entry.rarity.color, Parent = row }, { UI.textStroke(1) })
		UI.label({ Text = UI.formatPercent(entry.percent), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 3), Size = UDim2.fromOffset(80, 20), TextXAlignment = Enum.TextXAlignment.Right, Parent = row })
		if entry.rarity.rainbow then
			Fx.registerRainbow(dot, "BackgroundColor3")
			Fx.registerRainbow(name, "TextColor3")
		end
	end
	possibleTitle.Text = if chest.robux then "ITENS POSSÍVEIS (só Lendário, Mítico e Secreto)" else "ITENS POSSÍVEIS (de Comum a Secreto)"
	UI.clear(possible)
	for i, baseId in Items.chestPool(chest.pool) do
		local cell = UI.new("Frame", { LayoutOrder = i, BackgroundColor3 = UI.Colors.PanelLight, BackgroundTransparency = 0.2 }, { UI.corner(8) })
		ItemIcon.new(cell, baseId, "Comum", { Size = UDim2.fromScale(0.9, 0.58), Position = UDim2.fromScale(0.5, 0), AnchorPoint = Vector2.new(0.5, 0), glow = false })
		UI.label({ Text = Items.Bases[baseId].name, Position = UDim2.new(0, 3, 0.58, 0), Size = UDim2.new(1, -6, 0.36, 0), TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = true, Parent = cell })
		cell.Parent = possible
	end
	-- baús guardados deste tipo: botão de abrir de graça à esquerda
	local stored = (data and data.chestBag and data.chestBag[selectedChest]) or 0
	storedButton.Visible = stored > 0
	storedButton.Text = ("ABRIR GUARDADO (%d)"):format(stored)
	buyButton.AnchorPoint = if stored > 0 then Vector2.new(1, 1) else Vector2.new(0.5, 1)
	buyButton.Position = if stored > 0 then UDim2.new(1, 0, 1, 0) else UDim2.new(0.5, 0, 1, 0)
	buyButton.Size = if stored > 0 then UDim2.new(0.48, 0, 0, 50) else UDim2.new(0.6, 0, 0, 50)
	if chest.robux then
		-- pago com Robux: as chances acima ficam sempre visíveis antes da compra
		local price = Store.priceText(chest.product)
		buyButton.Text = "COMPRAR  •  " .. price
		buyButton.BackgroundColor3 = Color3.fromRGB(40, 150, 210)
		againButton.Text = "COMPRAR OUTRO  " .. price
		againButton.BackgroundColor3 = Color3.fromRGB(40, 150, 210)
		storedAgain(stored)
		return
	end
	local affordable = data and data.gold >= chest.price
	buyButton.Text = ("ABRIR  •  %s ouro"):format(UI.formatNumber(chest.price))
	buyButton.BackgroundColor3 = if affordable then Color3.fromRGB(230, 155, 30) else UI.Colors.Dark
	againButton.Text = if affordable then ("ABRIR OUTRO  %s ouro"):format(UI.formatNumber(chest.price)) else "Ouro insuficiente"
	againButton.BackgroundColor3 = if affordable then Color3.fromRGB(230, 155, 30) else UI.Colors.Dark
	storedAgain(stored)
end

local function closeOverlay()
	overlayGui.Enabled = false
	if currentScene then
		currentScene:destroy()
		currentScene = nil
	end
	if raysConnection then
		raysConnection:Disconnect()
		raysConnection = nil
	end
end

function Chest.reveal(item, chestId)
	while revealing do
		task.wait(0.2)
	end
	revealing = true
	selectedChest = chestId or selectedChest
	local chest = Chests.List[selectedChest] or Chests.List.bronze
	win:close()
	overlayGui.Enabled = true
	resultPanel.Visible = false
	reelHolder.Visible = true
	stamp.Visible = false
	shockwave.Visible = false
	flash.BackgroundTransparency = 1
	if raysConnection then
		raysConnection:Disconnect()
		raysConnection = nil
	end
	-- cena no fundo: seu personagem ajoelha e mexe no baú enquanto a roleta gira
	if currentScene then
		currentScene:destroy()
	end
	currentScene = RevealScene.chest(sceneHolder, chest.color)
	for _, ray in rays do
		ray.BackgroundTransparency = 1
	end

	-- monta a fita: cartas sorteadas com as chances reais do baú; a carta 40 é o prêmio
	UI.clear(reel)
	for _, card in reel:GetChildren() do
		card:Destroy()
	end
	local cards = {}
	for i = 1, REEL_LENGTH do
		local baseId, rarity
		if i == WIN_INDEX then
			baseId, rarity = item.base, Rarities.ById[item.rarity] or Rarities.List[1]
		else
			local pool = Items.chestPool(chest.pool)
			baseId = pool[math.random(1, #pool)]
			rarity = Rarities.roll(Chests.weightKey(chest), chest.minRarity)
		end
		cards[i] = makeCard(reel, baseId, rarity, i)
	end
	-- a fita fica presa no MEIO da faixa (escala 0,5): x = deslocamento em relação à linha dourada,
	-- então a conta não depende do tamanho da tela nem de escalas da interface
	local step = CARD_W + CARD_GAP
	local jitter = math.random(-CARD_W * 0.35, CARD_W * 0.35)
	local startX = -CARD_W / 2
	local finalX = -((WIN_INDEX - 1) * step + CARD_W / 2) + jitter
	reel.Position = UDim2.new(0.5, startX, 0, 10)
	skipping = false
	skipButton.Visible = true

	-- giro com desaceleração, "tic" a cada carta (cada vez mais agudo) e lente no centro
	local duration = 5.4
	local start = os.clock()
	local lastIndex = 0
	while true do
		local t = if skipping then 1 else math.min((os.clock() - start) / duration, 1)
		local eased = 1 - (1 - t) ^ 4
		local x = startX + (finalX - startX) * eased
		reel.Position = UDim2.new(0.5, x, 0, 10)
		for i, card in cards do
			local distance = math.abs(x + (i - 1) * step + CARD_W / 2)
			local lens = card:FindFirstChild("Lupa")
			if lens then
				lens.Scale = 1 + 0.16 * math.max(0, 1 - distance / (CARD_W * 1.4))
			end
		end
		local index = math.floor((-x) / step) + 1
		if index ~= lastIndex and not skipping then
			lastIndex = index
			Sounds.play("ping", 0.85 + t * 0.75, 0.1 + t * 0.08)
		end
		if t >= 1 then
			break
		end
		RunService.RenderStepped:Wait()
	end
	skipButton.Visible = false

	-- suspense honesto: a luz da carta premiada sobe de cor em cor até a raridade REAL do item
	local rarity = Rarities.ById[item.rarity] or Rarities.List[1]
	local winCard = cards[WIN_INDEX]
	local winStroke = winCard and winCard:FindFirstChildOfClass("UIStroke")
	local winLens = winCard and winCard:FindFirstChild("Lupa")
	if winCard and not skipping then
		for order = 1, rarity.order do
			local tier = Rarities.List[order]
			if winStroke then
				winStroke.Color = tier.color
				winStroke.Thickness = 3 + order
			end
			if winLens then
				winLens.Scale = 1.16 + order * 0.035
			end
			for _, ray in rays do
				ray.BackgroundColor3 = tier.color
				ray.BackgroundTransparency = 0.88 - order * 0.03
			end
			Sounds.play("ping", 0.7 + order * 0.18, 0.3 + order * 0.04)
			if order >= 4 then
				Fx.shake(0.04 * order, 0.15)
			end
			if skipping then
				break
			end
			task.wait(if order >= 4 then 0.34 else 0.2)
		end
		-- raridades altas seguram mais um pouco (o coração acelera)
		if rarity.order >= 4 and not skipping then
			Sounds.play("charge", 1, 0.5)
			task.wait(0.55 + (rarity.order - 4) * 0.2)
		end
	end

	-- revelação: clarão, onda de choque, a tampa abre e o personagem ergue o item
	flash.BackgroundColor3 = rarity.color:Lerp(Color3.new(1, 1, 1), 0.55)
	flash.BackgroundTransparency = if rarity.order >= 4 then 0 else 0.4
	UI.tween(flash, 0.7, { BackgroundTransparency = 1 })
	shock(rarity.color)
	if currentScene then
		currentScene:open(rarity.color, rarity.order >= 4, item.base, item.rarity)
	end
	reelHolder.Visible = false
	for _, ray in rays do
		ray.BackgroundColor3 = rarity.color
		ray.BackgroundTransparency = if rarity.order >= 4 then 0.45 else 0.6
	end
	raysConnection = RunService.RenderStepped:Connect(function(dt)
		rays[1].Rotation += dt * (30 + rarity.order * 6)
		rays[2].Rotation -= dt * (20 + rarity.order * 4)
	end)
	resultName.Text = item.name
	resultName.TextColor3 = rarity.color
	resultInfo.Text = ("%s  •  %s %d  •  Nv. %d"):format(rarity.name, UI.statWord(item), item.power, item.level)
	if rarity.rainbow then
		Fx.registerRainbow(resultName, "TextColor3")
	else
		Fx.unregisterRainbow(resultName)
	end
	resultPanel.Visible = true
	local scale = resultPanel:FindFirstChildOfClass("UIScale")
	scale.Scale = 1.4
	UI.tween(scale, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
	Sounds.play("chest", 1, 0.7)
	Sounds.play(if rarity.order >= 4 then "lootRare" else "loot", 0.6 + rarity.order * 0.15, 0.8)
	if rarity.order >= 4 then
		Sounds.play("crit", 0.8, 0.6)
		Sounds.play("powerUp", 1, 0.6)
	end
	if rarity.order >= 5 then
		Sounds.play("levelup", 1, 0.6)
	end
	stampRarity(rarity)
	-- ondas de confete (mais ondas quanto mais rara)
	task.spawn(function()
		local waves = if rarity.order >= 6 then 4 elseif rarity.order >= 4 then 2 else 1
		for _ = 1, waves do
			confetti(rarity.color, 14 + rarity.order * 9)
			task.wait(0.28)
		end
	end)
	renderWindow()
	revealing = false
end

local function openStored()
	if revealing then
		return
	end
	local result = State.request("openStoredChest", selectedChest)
	if result and result.ok then
		openingStored = true
		task.spawn(Chest.reveal, result.item, result.chest)
	end
end

local function buy()
	if revealing then
		return
	end
	openingStored = false
	local chest = Chests.List[selectedChest]
	if chest and chest.robux then
		overlayGui.Enabled = false
		Store.buy(chest.product) -- o servidor entrega e a revelação começa sozinha
		return
	end
	local result = State.request("openChest", selectedChest)
	if result and result.ok then
		task.spawn(Chest.reveal, result.item, result.chest)
	end
end

function Chest.init(screen)
	win = Window.create(screen, { icon = "present", name = "Baus", title = "BAÚS", width = 720, height = 520, tabs = { "Bronze", "Prata", "Real", "Celestial" }, accent = UI.Colors.Gold })
	odds = UI.new("Frame", { Size = UDim2.new(0, 250, 1, -60), BackgroundTransparency = 1, Parent = win.content }, { UI.list(4) })
	possibleTitle = UI.label({ Text = "ITENS POSSÍVEIS (de Comum a Secreto)", Position = UDim2.fromOffset(262, 0), Size = UDim2.new(1, -262, 0, 20), Font = Enum.Font.GothamBlack, Parent = win.content })
	possible = UI.new("ScrollingFrame", { Position = UDim2.fromOffset(262, 24), Size = UDim2.new(1, -262, 1, -84), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 5, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = win.content }, {
		UI.new("UIGridLayout", { CellSize = UDim2.fromOffset(78, 70), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	buyButton = UI.button({ Text = "ABRIR", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.new(0.6, 0, 0, 50), BackgroundColor3 = Color3.fromRGB(230, 155, 30), Parent = win.content })
	buyButton.MouseButton1Click:Connect(buy)
	storedButton = UI.button({ Text = "ABRIR GUARDADO", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(0.48, 0, 0, 50), BackgroundColor3 = UI.Colors.Green, Visible = false, Parent = win.content })
	storedButton.MouseButton1Click:Connect(openStored)
	win.onTab = function(name)
		selectedChest = if name == "Prata" then "prata" elseif name == "Real" then "real" elseif name == "Celestial" then "celestial" else "bronze"
		renderWindow()
	end
	win.onOpen = renderWindow

	-- tela da roleta
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	overlayGui = UI.new("ScreenGui", { Name = "RoletaBau", DisplayOrder = 10, IgnoreGuiInset = true, ResetOnSpawn = false, Enabled = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = playerGui })
	overlay = UI.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(10, 8, 18), BackgroundTransparency = 0.15, Parent = overlayGui })
	sceneHolder = UI.new("Frame", { Size = UDim2.fromScale(1, 0.72), BackgroundTransparency = 1, ZIndex = 2, Parent = overlay })
	rays = {}
	for i = 1, 2 do
		rays[i] = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.36), Size = UDim2.fromOffset(520, 520), Rotation = (i - 1) * 45, BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 1, Parent = overlay })
	end
	reelHolder = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.82), Size = UDim2.new(0.9, 0, 0, 170), BackgroundColor3 = UI.Colors.Panel, BackgroundTransparency = 0.1, ClipsDescendants = true, ZIndex = 3, Parent = overlay }, { UI.corner(14), UI.stroke(UI.Colors.Gold, 3) })
	reel = UI.new("Frame", { Position = UDim2.fromOffset(0, 10), Size = UDim2.fromOffset(REEL_LENGTH * (CARD_W + CARD_GAP), 150), BackgroundTransparency = 1, ZIndex = 4, Parent = reelHolder })
	UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.new(0, 4, 1, 0), BackgroundColor3 = UI.Colors.Gold, ZIndex = 6, Parent = reelHolder })
	UI.iconImage("plain-arrow", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0.82, -88), Size = UDim2.fromOffset(34, 30), Color = UI.Colors.Gold, ZIndex = 6, Parent = overlay })

	-- clarão, onda de choque, carimbo e botão de pular
	flash = UI.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 9, Parent = overlay })
	shockwave = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromOffset(40, 40), BackgroundTransparency = 1, Visible = false, ZIndex = 8, Parent = overlay }, { UI.new("UICorner", { CornerRadius = UDim.new(1, 0) }), UI.new("UIStroke", { Thickness = 10, Color = Color3.new(1, 1, 1) }) })
	stamp = UI.label({ Text = "", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.22), Size = UDim2.fromOffset(700, 110), TextXAlignment = Enum.TextXAlignment.Center, FontFace = UI.TitleFont, Visible = false, ZIndex = 9, Parent = overlay }, { UI.textStroke(4), UI.new("UIScale") })
	skipButton = UI.button({ Text = "Pular", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -24, 1, -24), Size = UDim2.fromOffset(120, 40), BackgroundColor3 = UI.Colors.Dark, Visible = false, ZIndex = 9, Parent = overlay })
	skipButton.MouseButton1Click:Connect(function()
		skipping = true
	end)

	resultPanel = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.72, 0), Size = UDim2.fromOffset(520, 150), BackgroundTransparency = 1, ZIndex = 7, Visible = false, Parent = overlay })
	UI.new("UIScale", { Parent = resultPanel })
	resultName = UI.label({ Text = "", Size = UDim2.new(1, 0, 0, 40), TextXAlignment = Enum.TextXAlignment.Center, Font = Enum.Font.GothamBlack, ZIndex = 7, Parent = resultPanel }, { UI.textStroke(2.5) })
	resultInfo = UI.label({ Text = "", Position = UDim2.fromOffset(0, 42), Size = UDim2.new(1, 0, 0, 22), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 7, Parent = resultPanel }, { UI.textStroke(1.5) })
	local okButton = UI.button({ Text = "OK", Position = UDim2.fromOffset(60, 84), Size = UDim2.fromOffset(160, 50), BackgroundColor3 = UI.Colors.Green, ZIndex = 7, Parent = resultPanel })
	okButton.MouseButton1Click:Connect(closeOverlay)
	againButton = UI.button({ Text = "ABRIR OUTRO", Position = UDim2.fromOffset(232, 84), Size = UDim2.fromOffset(230, 50), BackgroundColor3 = Color3.fromRGB(230, 155, 30), ZIndex = 7, Parent = resultPanel })
	againButton.MouseButton1Click:Connect(function()
		if openingStored then
			openStored()
		else
			buy()
		end
	end)
	State.Changed:Connect(function()
		if win:isOpen() then
			renderWindow()
		end
	end)
end

function Chest.toggle()
	win:toggle()
end

function Chest.open()
	if not revealing then
		win:open()
	end
end

return Chest
