-- Baús: escolha do baú, itens possíveis + chances, e a roleta horizontal que desacelera até o prêmio.
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
local revealing = false
local raysConnection = nil

local function makeCard(parent, baseId, rarity, index)
	local base = Items.Bases[baseId]
	local card = UI.new("Frame", {
		Position = UDim2.fromOffset((index - 1) * (CARD_W + CARD_GAP), 0),
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
	return card
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

local function renderWindow()
	local chest = Chests.List[selectedChest]
	local data = State.data
	win.title.Text = ("%s %s"):format(chest.icon, chest.name)
	UI.clear(odds)
	UI.label({ Text = "CHANCES REAIS", Size = UDim2.new(1, 0, 0, 20), Font = Enum.Font.GothamBlack, LayoutOrder = 0, Parent = odds })
	for i, entry in Rarities.odds(Chests.WeightKey, chest.minRarity) do
		local row = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 26), BackgroundColor3 = UI.Colors.PanelLight, BackgroundTransparency = 0.3, LayoutOrder = i, Parent = odds }, { UI.corner(6) })
		local dot = UI.new("Frame", { Position = UDim2.fromOffset(8, 6), Size = UDim2.fromOffset(14, 14), BackgroundColor3 = entry.rarity.color, Parent = row }, { UI.corner(7) })
		local name = UI.label({ Text = entry.rarity.name, Position = UDim2.fromOffset(30, 3), Size = UDim2.fromOffset(120, 20), TextColor3 = entry.rarity.color, Parent = row }, { UI.textStroke(1) })
		UI.label({ Text = UI.formatPercent(entry.percent), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 3), Size = UDim2.fromOffset(80, 20), TextXAlignment = Enum.TextXAlignment.Right, Parent = row })
		if entry.rarity.rainbow then
			Fx.registerRainbow(dot, "BackgroundColor3")
			Fx.registerRainbow(name, "TextColor3")
		end
	end
	UI.clear(possible)
	for i, baseId in Items.ChestPool do
		local cell = UI.new("Frame", { LayoutOrder = i, BackgroundColor3 = UI.Colors.PanelLight, BackgroundTransparency = 0.2 }, { UI.corner(8) })
		ItemIcon.new(cell, baseId, "Comum", { Size = UDim2.fromScale(0.9, 0.58), Position = UDim2.fromScale(0.5, 0), AnchorPoint = Vector2.new(0.5, 0), glow = false })
		UI.label({ Text = Items.Bases[baseId].name, Position = UDim2.new(0, 3, 0.58, 0), Size = UDim2.new(1, -6, 0.36, 0), TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = true, Parent = cell })
		cell.Parent = possible
	end
	local affordable = data and data.gold >= chest.price
	buyButton.Text = ("ABRIR  •  💰 %s"):format(UI.formatNumber(chest.price))
	buyButton.BackgroundColor3 = if affordable then Color3.fromRGB(230, 155, 30) else UI.Colors.Dark
	againButton.Text = if affordable then ("ABRIR OUTRO  💰%s"):format(UI.formatNumber(chest.price)) else "Ouro insuficiente"
	againButton.BackgroundColor3 = if affordable then Color3.fromRGB(230, 155, 30) else UI.Colors.Dark
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
	for i = 1, REEL_LENGTH do
		local baseId, rarity
		if i == WIN_INDEX then
			baseId, rarity = item.base, Rarities.ById[item.rarity] or Rarities.List[1]
		else
			baseId = Items.ChestPool[math.random(1, #Items.ChestPool)]
			rarity = Rarities.roll(Chests.WeightKey, chest.minRarity)
		end
		makeCard(reel, baseId, rarity, i)
	end
	RunService.RenderStepped:Wait() -- espera a tela calcular o tamanho da fita
	local holderWidth = reelHolder.AbsoluteSize.X
	if holderWidth <= 0 then
		holderWidth = workspace.CurrentCamera.ViewportSize.X * 0.9
	end
	local centerOffset = holderWidth / 2 - CARD_W / 2
	local jitter = math.random(-CARD_W * 0.35, CARD_W * 0.35)
	local finalX = -((WIN_INDEX - 1) * (CARD_W + CARD_GAP)) + centerOffset + jitter
	reel.Position = UDim2.fromOffset(centerOffset, 0)

	-- anima com desaceleração e "tic" a cada carta que passa pelo centro
	local duration = 4.2
	local start = os.clock()
	local startX = centerOffset
	local lastIndex = 0
	while true do
		local t = math.min((os.clock() - start) / duration, 1)
		local eased = 1 - (1 - t) ^ 4
		local x = startX + (finalX - startX) * eased
		reel.Position = UDim2.fromOffset(x, 0)
		local index = math.floor((centerOffset - x) / (CARD_W + CARD_GAP)) + 1
		if index ~= lastIndex then
			lastIndex = index
			Sounds.play("ping", 0.9 + t * 0.6, 0.12)
		end
		if t >= 1 then
			break
		end
		RunService.RenderStepped:Wait()
	end

	-- revelação: a tampa abre, o feixe de luz sobe e o personagem ergue o item
	local rarity = Rarities.ById[item.rarity] or Rarities.List[1]
	if currentScene then
		currentScene:open(rarity.color, rarity.order >= 4, item.base, item.rarity)
	end
	reelHolder.Visible = false
	for _, ray in rays do
		ray.BackgroundColor3 = rarity.color
		ray.BackgroundTransparency = 0.6
	end
	raysConnection = RunService.RenderStepped:Connect(function(dt)
		rays[1].Rotation += dt * 30
		rays[2].Rotation -= dt * 20
	end)
	resultName.Text = item.name
	resultName.TextColor3 = rarity.color
	resultInfo.Text = ("%s  •  %s %d  •  Nv. %d"):format(rarity.name, UI.statIcon(item), item.power, item.level)
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
		Fx.shake(0.25 + rarity.order * 0.05, 0.2 + rarity.order * 0.12)
	end
	confetti(rarity.color, 14 + rarity.order * 9)
	renderWindow()
	revealing = false
end

local function buy()
	if revealing then
		return
	end
	local result = State.request("openChest", selectedChest)
	if result and result.ok then
		task.spawn(Chest.reveal, result.item, result.chest)
	end
end

function Chest.init(screen)
	win = Window.create(screen, { name = "Baus", title = "🎁 BAÚS", width = 720, height = 520, tabs = { "Bronze", "Prata", "Real" }, accent = UI.Colors.Gold })
	odds = UI.new("Frame", { Size = UDim2.new(0, 250, 1, -60), BackgroundTransparency = 1, Parent = win.content }, { UI.list(4) })
	UI.label({ Text = "ITENS POSSÍVEIS (de Comum a Secreto)", Position = UDim2.fromOffset(262, 0), Size = UDim2.new(1, -262, 0, 20), Font = Enum.Font.GothamBlack, Parent = win.content })
	possible = UI.new("ScrollingFrame", { Position = UDim2.fromOffset(262, 24), Size = UDim2.new(1, -262, 1, -84), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 5, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = win.content }, {
		UI.new("UIGridLayout", { CellSize = UDim2.fromOffset(78, 70), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	buyButton = UI.button({ Text = "ABRIR", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.new(0.6, 0, 0, 50), BackgroundColor3 = Color3.fromRGB(230, 155, 30), Parent = win.content })
	buyButton.MouseButton1Click:Connect(buy)
	win.onTab = function(name)
		selectedChest = if name == "Prata" then "prata" elseif name == "Real" then "real" else "bronze"
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
	UI.label({ Text = "▼", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0.82, -88), Size = UDim2.fromOffset(40, 30), TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = UI.Colors.Gold, ZIndex = 6, Parent = overlay }, { UI.textStroke(2) })

	resultPanel = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.72, 0), Size = UDim2.fromOffset(520, 150), BackgroundTransparency = 1, ZIndex = 7, Visible = false, Parent = overlay })
	UI.new("UIScale", { Parent = resultPanel })
	resultName = UI.label({ Text = "", Size = UDim2.new(1, 0, 0, 40), TextXAlignment = Enum.TextXAlignment.Center, Font = Enum.Font.GothamBlack, ZIndex = 7, Parent = resultPanel }, { UI.textStroke(2.5) })
	resultInfo = UI.label({ Text = "", Position = UDim2.fromOffset(0, 42), Size = UDim2.new(1, 0, 0, 22), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 7, Parent = resultPanel }, { UI.textStroke(1.5) })
	local okButton = UI.button({ Text = "OK", Position = UDim2.fromOffset(60, 84), Size = UDim2.fromOffset(160, 50), BackgroundColor3 = UI.Colors.Green, ZIndex = 7, Parent = resultPanel })
	okButton.MouseButton1Click:Connect(closeOverlay)
	againButton = UI.button({ Text = "ABRIR OUTRO", Position = UDim2.fromOffset(232, 84), Size = UDim2.fromOffset(230, 50), BackgroundColor3 = Color3.fromRGB(230, 155, 30), ZIndex = 7, Parent = resultPanel })
	againButton.MouseButton1Click:Connect(buy)
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
