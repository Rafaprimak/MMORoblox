-- Baú do Hunter: janela com as chances reais + animação de revelação.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rarities = require(Shared.Rarities)
local Remotes = require(Shared.Remotes)

local UI = require(script.Parent.UI)
local Fx = require(script.Parent.Fx)
local Sounds = require(script.Parent.Sounds)
local Popups = require(script.Parent.Popups)

local Chest = {}
Chest.onOpen = nil

local WIDTH, HEIGHT = 380, 470
local window, windowScale, goldLabel, openButton
local overlayGui, overlay, card, cardScale, cardStroke, cardIcon, cardRarity, cardName, cardPower, resultButtons, againButton
local rays = {}
local raysConnection = nil
local state = nil
local revealing = false

local function request(action)
	local ok, result = pcall(function()
		return Remotes.Request:InvokeServer(action)
	end)
	if not ok or type(result) ~= "table" then
		Popups.message("Erro de conexão, tente de novo.")
		return nil
	end
	if not result.ok and result.msg then
		Popups.message(result.msg)
	end
	return result
end

local function fitScale()
	local camera = workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	return math.min(1, (viewport.X - 24) / WIDTH, (viewport.Y - 60) / HEIGHT)
end

local function setCardRarity(rarity)
	cardStroke.Color = rarity.color
	card.BackgroundColor3 = rarity.color:Lerp(Color3.new(0, 0, 0), 0.75)
	cardRarity.Text = rarity.upper
	cardRarity.TextColor3 = rarity.color
	for _, ray in rays do
		ray.BackgroundColor3 = rarity.color
	end
	if rarity.rainbow then
		Fx.registerRainbow(cardStroke, "Color")
		Fx.registerRainbow(cardRarity, "TextColor3")
	else
		Fx.unregisterRainbow(cardStroke)
		Fx.unregisterRainbow(cardRarity)
	end
end

local function confetti(color, count)
	for _ = 1, count do
		local piece = UI.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, -30),
			Size = UDim2.fromOffset(math.random(6, 14), math.random(6, 14)),
			BackgroundColor3 = if math.random() < 0.3 then Color3.new(1, 1, 1) else color,
			BorderSizePixel = 0,
			Rotation = math.random(0, 360),
			ZIndex = 2,
			Parent = overlay,
		})
		local angle = math.random() * math.pi * 2
		local distance = math.random(160, 420)
		local duration = 0.6 + math.random() * 0.6
		UI.tween(piece, duration, {
			Position = UDim2.new(0.5, math.cos(angle) * distance, 0.5, math.sin(angle) * distance - 30),
			Rotation = piece.Rotation + math.random(-360, 360),
			BackgroundTransparency = 1,
		})
		Debris:AddItem(piece, duration + 0.05)
	end
end

local function startRays()
	if raysConnection then
		return
	end
	raysConnection = RunService.RenderStepped:Connect(function(dt)
		rays[1].Rotation += dt * 30
		rays[2].Rotation -= dt * 20
	end)
end

local function closeOverlay()
	overlayGui.Enabled = false
	if raysConnection then
		raysConnection:Disconnect()
		raysConnection = nil
	end
	Fx.unregisterRainbow(cardStroke)
	Fx.unregisterRainbow(cardRarity)
end

local function updateTexts()
	if not state then
		return
	end
	local cost = state.chestCost or 150
	local affordable = state.gold >= cost
	goldLabel.Text = "Seu ouro: 💰 " .. UI.formatNumber(state.gold)
	openButton.Text = ("ABRIR  •  💰 %s"):format(UI.formatNumber(cost))
	openButton.BackgroundColor3 = if affordable then Color3.fromRGB(230, 155, 30) else Color3.fromRGB(110, 85, 45)
	againButton.Text = if affordable then ("ABRIR OUTRO 💰%s"):format(UI.formatNumber(cost)) else "Ouro insuficiente"
	againButton.BackgroundColor3 = if affordable then Color3.fromRGB(230, 155, 30) else Color3.fromRGB(80, 70, 60)
end

function Chest.reveal(item, _paid)
	while revealing do
		task.wait(0.2)
	end
	revealing = true
	window.Visible = false
	overlayGui.Enabled = true
	resultButtons.Visible = false
	cardIcon.Text = "🎁"
	cardName.Text = "Abrindo..."
	cardPower.Text = ""
	for _, ray in rays do
		ray.BackgroundTransparency = 0.9
	end
	startRays()

	cardScale.Scale = 0.5
	UI.tween(cardScale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	for i = 1, 8 do
		card.Rotation = if i % 2 == 0 then 5 else -5
		Sounds.play("ping", 0.5, 0.12)
		task.wait(0.05)
	end
	card.Rotation = 0

	-- roleta de raridades que vai desacelerando
	local steps = 20
	for i = 1, steps do
		setCardRarity(Rarities.roll("chestWeight"))
		Sounds.play("ping", 0.7 + i * 0.02, 0.18)
		local t = i / steps
		task.wait(0.04 + t * t * 0.28)
	end

	-- revelação!
	local rarity = Rarities.ById[item.rarity] or Rarities.List[1]
	setCardRarity(rarity)
	cardIcon.Text = UI.itemIcon(item)
	cardName.Text = item.name
	cardPower.Text = ("%s Poder %d  •  Nv. %d"):format(UI.statIcon(item), item.power, item.level)
	cardScale.Scale = 1.35
	UI.tween(cardScale, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
	for _, ray in rays do
		ray.BackgroundTransparency = 0.55
	end
	Sounds.play("ping", 0.6 + rarity.order * 0.15, 0.8)
	if rarity.order >= 4 then
		Sounds.play("crit", 0.8, 0.6)
		Fx.shake(0.25 + rarity.order * 0.05, 0.2 + rarity.order * 0.12)
	end
	confetti(rarity.color, 12 + rarity.order * 8)

	task.wait(0.4)
	resultButtons.Visible = true
	revealing = false
end

local function buy()
	if revealing then
		return
	end
	local result = request("openChest")
	if result and result.ok then
		task.spawn(Chest.reveal, result.item, true)
	end
end

function Chest.init(screen)
	-- Janela de compra
	window = UI.new("Frame", {
		Name = "Bau",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(WIDTH, HEIGHT),
		BackgroundColor3 = UI.Colors.Panel,
		BackgroundTransparency = 0.05,
		Visible = false,
		ZIndex = 5,
		Parent = screen,
	}, { UI.corner(14), UI.stroke(UI.Colors.Gold, 2) })
	windowScale = UI.new("UIScale", { Parent = window })

	UI.label({ Text = "🎁 BAÚ DO HUNTER", Position = UDim2.fromOffset(16, 12), Size = UDim2.fromOffset(290, 30), TextColor3 = UI.Colors.Gold, Font = Enum.Font.GothamBlack, Parent = window }, { UI.textStroke(1) })
	UI.label({ Text = "1 arma ou armadura do seu nível", Position = UDim2.fromOffset(16, 44), Size = UDim2.fromOffset(340, 18), TextColor3 = UI.Colors.SubText, Font = Enum.Font.Gotham, Parent = window })
	local closeButton = UI.button({ Text = "X", Position = UDim2.new(1, -46, 0, 10), Size = UDim2.fromOffset(36, 34), BackgroundColor3 = UI.Colors.Red, Parent = window })
	closeButton.MouseButton1Click:Connect(function()
		Chest.close()
	end)

	UI.label({ Text = "CHANCES", Position = UDim2.fromOffset(16, 72), Size = UDim2.fromOffset(200, 18), Font = Enum.Font.GothamBlack, Parent = window })
	for i, entry in Rarities.odds("chestWeight") do
		local y = 96 + (i - 1) * 30
		local rarity = entry.rarity
		local row = UI.new("Frame", {
			Position = UDim2.fromOffset(16, y),
			Size = UDim2.new(1, -32, 0, 26),
			BackgroundColor3 = UI.Colors.PanelLight,
			BackgroundTransparency = 0.3,
			Parent = window,
		}, { UI.corner(6) })
		local dot = UI.new("Frame", { Position = UDim2.fromOffset(8, 6), Size = UDim2.fromOffset(14, 14), BackgroundColor3 = rarity.color, Parent = row }, { UI.corner(7) })
		local name = UI.label({ Text = rarity.name, Position = UDim2.fromOffset(30, 3), Size = UDim2.fromOffset(180, 20), TextColor3 = rarity.color, Parent = row }, { UI.textStroke(1) })
		UI.label({ Text = UI.formatPercent(entry.percent), Position = UDim2.new(1, -110, 0, 3), Size = UDim2.fromOffset(100, 20), TextXAlignment = Enum.TextXAlignment.Right, Parent = row })
		if rarity.rainbow then
			Fx.registerRainbow(dot, "BackgroundColor3")
			Fx.registerRainbow(name, "TextColor3")
		end
	end

	goldLabel = UI.label({ Text = "", Position = UDim2.fromOffset(16, 318), Size = UDim2.new(1, -32, 0, 22), TextColor3 = UI.Colors.Gold, TextXAlignment = Enum.TextXAlignment.Center, Parent = window })
	openButton = UI.button({ Text = "ABRIR", Position = UDim2.fromOffset(20, 350), Size = UDim2.new(1, -40, 0, 52), BackgroundColor3 = Color3.fromRGB(230, 155, 30), Parent = window })
	openButton.MouseButton1Click:Connect(buy)
	UI.label({
		Text = "Chances reais de cada raridade. Itens Míticos e Secretos são anunciados para o servidor inteiro!",
		Position = UDim2.fromOffset(16, 412),
		Size = UDim2.new(1, -32, 0, 40),
		TextWrapped = true,
		TextColor3 = UI.Colors.SubText,
		Font = Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = window,
	})

	-- Tela de revelação (fica por cima de tudo)
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	overlayGui = UI.new("ScreenGui", { Name = "RevelacaoBau", DisplayOrder = 10, IgnoreGuiInset = true, ResetOnSpawn = false, Enabled = false, Parent = playerGui })
	overlay = UI.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.3, Parent = overlayGui })

	for i = 1, 2 do
		rays[i] = UI.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, -30),
			Size = UDim2.fromOffset(560, 560),
			Rotation = (i - 1) * 45,
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.9,
			BorderSizePixel = 0,
			ZIndex = 1,
			Parent = overlay,
		})
	end

	cardStroke = UI.stroke(Color3.new(1, 1, 1), 4)
	card = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, -30),
		Size = UDim2.fromOffset(260, 330),
		BackgroundColor3 = UI.Colors.Panel,
		ZIndex = 3,
		Parent = overlay,
	}, { UI.corner(16), cardStroke })
	cardScale = UI.new("UIScale", { Parent = card })
	cardIcon = UI.label({ Text = "🎁", Position = UDim2.fromScale(0, 0.08), Size = UDim2.fromScale(1, 0.36), TextXAlignment = Enum.TextXAlignment.Center, Parent = card })
	cardRarity = UI.label({ Text = "", Position = UDim2.new(0, 10, 0.5, 0), Size = UDim2.new(1, -20, 0.12, 0), TextXAlignment = Enum.TextXAlignment.Center, Font = Enum.Font.GothamBlack, Parent = card }, { UI.textStroke(2) })
	cardName = UI.label({ Text = "", Position = UDim2.new(0, 10, 0.64, 0), Size = UDim2.new(1, -20, 0.14, 0), TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = true, Parent = card }, { UI.textStroke(1.5) })
	cardPower = UI.label({ Text = "", Position = UDim2.new(0, 10, 0.82, 0), Size = UDim2.new(1, -20, 0.08, 0), TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = UI.Colors.SubText, Parent = card })

	resultButtons = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.5, 155),
		Size = UDim2.fromOffset(360, 50),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Visible = false,
		Parent = overlay,
	})
	local okButton = UI.button({ Text = "OK", Size = UDim2.fromOffset(150, 50), BackgroundColor3 = UI.Colors.Green, Parent = resultButtons })
	okButton.MouseButton1Click:Connect(closeOverlay)
	againButton = UI.button({ Text = "ABRIR OUTRO", Position = UDim2.fromOffset(160, 0), Size = UDim2.fromOffset(200, 50), BackgroundColor3 = Color3.fromRGB(230, 155, 30), Parent = resultButtons })
	againButton.MouseButton1Click:Connect(buy)
end

function Chest.update(data)
	state = data
	updateTexts()
end

function Chest.open()
	if revealing then
		return
	end
	if Chest.onOpen then
		Chest.onOpen()
	end
	window.Visible = true
	local target = fitScale()
	windowScale.Scale = target * 0.85
	UI.tween(windowScale, 0.2, { Scale = target }, Enum.EasingStyle.Back)
	updateTexts()
end

function Chest.close()
	window.Visible = false
end

function Chest.toggle()
	if window.Visible then
		Chest.close()
	else
		Chest.open()
	end
end

return Chest
