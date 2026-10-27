-- Mapa do mundo desenhado a partir do relevo, com estradas, ruas da vila, pedras de viagem clicáveis,
-- locais e a sua posição. Roda do mouse (ou botões +/-) dá zoom; arrastar move o mapa.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local World = require(Shared.World)
local Enemies = require(Shared.Enemies)
local Points = require(Shared.Points)
local TownPlan = require(Shared.TownPlan)

local UI = require(script.Parent.UI)
local State = require(script.Parent.State)
local Window = require(script.Parent.Window)
local Sounds = require(script.Parent.Sounds)

local MapWindow = {}

local SIZE = 460
local CELLS = 64
local MIN_ZOOM, MAX_ZOOM = 1, 5
local player = Players.LocalPlayer

local win, mapFrame, canvas, markers, playerArrow, info
local zoom = 1
local offset = Vector2.zero -- canto de cima do mapa ampliado, em pixels (sempre <= 0)
local drawn = false
local stoneButtons = {}
local poiLabels = {}

-- posição no mundo -> fração do mapa (0 a 1); tudo é posicionado em escala, então acompanha o zoom
local function toMap(x, z)
	return (x + World.Half) / (World.Half * 2), (z + World.Half) / (World.Half * 2)
end

local function at(u, v)
	return UDim2.fromScale(u, v)
end

-- mantém o mapa ampliado cobrindo a janela
local function applyView()
	local size = SIZE * zoom
	offset = Vector2.new(math.clamp(offset.X, SIZE - size, 0), math.clamp(offset.Y, SIZE - size, 0))
	canvas.Size = UDim2.fromOffset(size, size)
	canvas.Position = UDim2.fromOffset(offset.X, offset.Y)
end

-- zoom em volta de um ponto da janela (em pixels)
local function setZoom(value, pivot)
	pivot = pivot or Vector2.new(SIZE / 2, SIZE / 2)
	local fraction = (pivot - offset) / (SIZE * zoom)
	zoom = math.clamp(value, MIN_ZOOM, MAX_ZOOM)
	offset = pivot - fraction * SIZE * zoom
	applyView()
end

local function centerOn(x, z)
	local u, v = toMap(x, z)
	offset = Vector2.new(SIZE / 2 - u * SIZE * zoom, SIZE / 2 - v * SIZE * zoom)
	applyView()
end

-- linha entre dois pontos do mundo (escala junto com o mapa; o mapa é quadrado)
local function line(parent, a, b, thickness, color)
	local u1, v1 = toMap(a.X, a.Y)
	local u2, v2 = toMap(b.X, b.Y)
	local du, dv = u2 - u1, v2 - v1
	return UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = at((u1 + u2) / 2, (v1 + v2) / 2),
		Size = UDim2.new(math.sqrt(du * du + dv * dv), thickness, 0, thickness),
		Rotation = math.deg(math.atan2(dv, du)),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = parent,
	})
end

local function cellColor(x, z)
	local w = World.weights(x, z)
	local h = World.heightWithWeights(x, z, w)
	if h < World.SeaLevel then
		return Color3.fromRGB(40, 100, 150):Lerp(Color3.fromRGB(20, 60, 110), math.clamp(-h / 15, 0, 1))
	end
	if w.town > 0.6 then
		return Color3.fromRGB(175, 165, 150)
	end
	if h > 115 then
		return Color3.fromRGB(235, 240, 245)
	end
	if w.mountain > 0.55 or w.crater > 0.5 then
		return Color3.fromRGB(120, 112, 105):Lerp(Color3.fromRGB(160, 150, 140), math.clamp((h - 40) / 80, 0, 1))
	end
	if w.ocean > 0.08 and h < World.SeaLevel + 6 then
		return Color3.fromRGB(225, 205, 150)
	end
	if w.forest > 0.5 then
		return Color3.fromRGB(45, 100, 50)
	end
	if w.ruins > 0.5 then
		return Color3.fromRGB(140, 140, 115)
	end
	return Color3.fromRGB(95, 160, 75):Lerp(Color3.fromRGB(120, 175, 85), math.clamp((h - 10) / 30, 0, 1))
end

local function refreshPois()
	local data = State.data
	for id, label in poiLabels do
		local poi = Points.ById[id]
		local found = data and data.poi and data.poi[id]
		local opened = data and data.poiChests and data.poiChests[id]
		-- descoberto: ícone do local (verde quando o baú já foi aberto); senão, interrogação
		UI.setIcon(label:FindFirstChild("Icone"), if found then poi.icon else "help", if opened then UI.Colors.Green elseif found then UI.Colors.Icon else Color3.new(1, 1, 1), if found then 0 else 0.2)
	end
end

local function draw()
	if drawn then
		return
	end
	drawn = true
	for i = 0, CELLS - 1 do
		for j = 0, CELLS - 1 do
			local x = -World.Half + (i + 0.5) * (World.Half * 2 / CELLS)
			local z = -World.Half + (j + 0.5) * (World.Half * 2 / CELLS)
			UI.new("Frame", { Position = at(i / CELLS, j / CELLS), Size = UDim2.new(1 / CELLS, 1, 1 / CELLS, 1), BorderSizePixel = 0, BackgroundColor3 = cellColor(x, z), Parent = canvas })
		end
		if i % 6 == 0 then
			task.wait()
		end
	end
	-- estradas (borda escura + terra batida por cima)
	for _, road in World.Roads do
		for i = 1, #road - 1 do
			line(canvas, road[i], road[i + 1], 5, Color3.fromRGB(110, 85, 55))
			line(canvas, road[i], road[i + 1], 3, Color3.fromRGB(205, 175, 125))
		end
	end
	-- ruas, praça e becos da vila (aparecem melhor com zoom)
	local K = World.Scale
	for _, strip in TownPlan.Paving do
		local x1, z1 = World.TownCenter.X + strip[1] * K, World.TownCenter.Z + strip[2] * K
		local x2, z2 = World.TownCenter.X + strip[3] * K, World.TownCenter.Z + strip[4] * K
		local u1, v1 = toMap(math.min(x1, x2), math.min(z1, z2))
		local u2, v2 = toMap(math.max(x1, x2), math.max(z1, z2))
		local color = if strip[5] == "beco" then Color3.fromRGB(150, 120, 90) elseif strip[5] == "praca" then Color3.fromRGB(215, 205, 185) else Color3.fromRGB(190, 180, 165)
		UI.new("Frame", { Position = at(u1, v1), Size = at(u2 - u1, v2 - v1), BorderSizePixel = 0, BackgroundColor3 = color, ZIndex = 2, Parent = canvas })
	end
	-- nomes dos locais
	for _, loc in World.Locations do
		local mx, mz = toMap(loc.x, loc.z)
		UI.label({ Text = loc.name, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(mx, 0, mz, -4), Size = UDim2.fromOffset(130, 14), TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = Color3.fromRGB(255, 245, 220), ZIndex = 3, Parent = markers }, { UI.textStroke(1.5) })
	end
	-- acampamentos de inimigos
	for _, camp in Enemies.Camps do
		if camp.id ~= "treino" then
			local mx, mz = toMap(camp.center.X, camp.center.Y)
			local level = 1
			for enemyId in camp.spawns do
				level = math.max(level, Enemies.Defs[enemyId].level)
			end
			local color = if camp.boss then Color3.fromRGB(255, 90, 70) else Color3.fromRGB(255, 200, 190)
			local holder = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = at(mx, mz), Size = UDim2.fromOffset(40, 16), BackgroundTransparency = 1, ZIndex = 3, Parent = markers })
			UI.icon(if camp.boss then "crown" else "skull-crack", { Size = UDim2.fromOffset(15, 15), Color = color, ZIndex = 3, Parent = holder })
			UI.label({ Text = tostring(level), Position = UDim2.fromOffset(16, 1), Size = UDim2.fromOffset(24, 14), TextColor3 = color, ZIndex = 3, Parent = holder }, { UI.textStroke(1.5) })
		end
	end
	-- locais de interesse ( até descobrir; ✔ quando o baú foi aberto)
	for _, poi in Points.List do
		local mx, mz = toMap(poi.x, poi.z)
		local label = UI.new("TextButton", { Text = "", AnchorPoint = Vector2.new(0.5, 0.5), Position = at(mx, mz), Size = UDim2.fromOffset(24, 24), BackgroundTransparency = 1, TextScaled = true, Font = Enum.Font.GothamBlack, TextColor3 = Color3.new(1, 1, 1), ZIndex = 4, Parent = markers }, { UI.textStroke(1.5) })
		UI.icon("help", { Size = UDim2.fromScale(1, 1), ZIndex = 4, Parent = label })
		poiLabels[poi.id] = label
		label.MouseEnter:Connect(function()
			local data = State.data
			local found = data and data.poi and data.poi[poi.id]
			local opened = data and data.poiChests and data.poiChests[poi.id]
			info.Text = if found then ("%s%s"):format(poi.name, if opened then " — baú aberto ✔" else " — o baú escondido ainda está lá!") else "? Local desconhecido. Vá até lá para descobrir."
		end)
	end
	refreshPois()
	-- pedras de viagem
	for _, stone in World.Waystones do
		local mx, mz = toMap(stone.x, stone.z)
		local button = UI.button({ Text = "", AnchorPoint = Vector2.new(0.5, 0.5), Position = at(mx, mz), Size = UDim2.fromOffset(28, 28), BackgroundColor3 = UI.Colors.Dark, ZIndex = 4, Parent = markers })
		UI.icon("vortex", { Size = UDim2.fromScale(0.8, 0.8), Position = UDim2.fromScale(0.1, 0.1), Color = Color3.fromRGB(150, 215, 255), ZIndex = 5, Parent = button })
		stoneButtons[stone.id] = button
		button.MouseButton1Click:Connect(function()
			local data = State.data
			if not data or not data.discovered[stone.id] then
				info.Text = stone.name .. ": chegue perto dessa pedra para ativá-la."
				return
			end
			local result = State.request("travel", stone.id)
			if result and result.ok then
				Sounds.play("ping", 1.2, 0.5)
				win:close()
			end
		end)
		button.MouseEnter:Connect(function()
			info.Text = stone.name .. (if State.data and State.data.discovered[stone.id] then " — clique para viajar" else " — não ativada")
		end)
	end
end

local function refreshStones()
	local data = State.data
	for id, button in stoneButtons do
		local discovered = data and data.discovered and data.discovered[id]
		button.BackgroundColor3 = if discovered then Color3.fromRGB(70, 150, 230) else UI.Colors.Dark
		button.TextTransparency = if discovered then 0 else 0.5
	end
end

function MapWindow.init(screen)
	win = Window.create(screen, { icon = "treasure-map", name = "Mapa", title = "MAPA  •  clique numa pedra de viagem ativada para viajar", width = SIZE + 40, height = SIZE + 110, accent = Color3.fromRGB(140, 210, 255) })
	mapFrame = UI.new("Frame", { Size = UDim2.fromOffset(SIZE, SIZE), BackgroundColor3 = Color3.fromRGB(30, 70, 110), ClipsDescendants = true, Active = true, Parent = win.content }, { UI.corner(8) })
	canvas = UI.new("Frame", { Size = UDim2.fromOffset(SIZE, SIZE), BackgroundTransparency = 1, Parent = mapFrame })
	markers = UI.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 3, Parent = canvas })
	-- zoom com a roda do mouse (em volta do cursor) e arrastar para mover
	local dragging, dragStart, dragOffset = false, Vector2.zero, Vector2.zero
	mapFrame.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			local pivot = Vector2.new(input.Position.X, input.Position.Y) - mapFrame.AbsolutePosition
			setZoom(zoom * (if input.Position.Z > 0 then 1.25 else 0.8), pivot)
		end
	end)
	mapFrame.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging, dragStart, dragOffset = true, Vector2.new(input.Position.X, input.Position.Y), offset
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			offset = dragOffset + (Vector2.new(input.Position.X, input.Position.Y) - dragStart)
			applyView()
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
	-- botões de zoom e de centralizar em você
	local function centerOnPlayer()
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root then
			zoom = math.max(zoom, 2.5)
			centerOn(root.Position.X, root.Position.Z)
		end
	end
	local zoomButtons = {
		{ "+", function()
			setZoom(zoom * 1.5)
		end },
		{ "-", function()
			setZoom(zoom / 1.5)
		end },
		{ "Eu", centerOnPlayer },
	}
	for i, spec in zoomButtons do
		local button = UI.button({ Text = spec[1], Position = UDim2.new(1, -40, 0, 8 + (i - 1) * 38), Size = UDim2.fromOffset(32, 32), BackgroundColor3 = UI.Colors.PanelLight, ZIndex = 8, Parent = mapFrame })
		button.MouseButton1Click:Connect(spec[2])
	end
	playerArrow = UI.label({ Text = "▲", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(22, 22), TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = Color3.fromRGB(255, 240, 80), ZIndex = 6, Parent = markers }, { UI.textStroke(2) })
	info = UI.label({ Text = "Seta amarela = você. Caveira = inimigos (nível), coroa = chefe, ? = local a descobrir. Roda do mouse = zoom.", Position = UDim2.fromOffset(0, SIZE + 8), Size = UDim2.new(1, 0, 0, 20), TextColor3 = UI.Colors.SubText, Parent = win.content })
	win.onOpen = function()
		task.spawn(draw)
		refreshStones()
	end
	State.Changed:Connect(function()
		refreshStones()
		refreshPois()
	end)
	RunService.RenderStepped:Connect(function()
		if not win:isOpen() then
			return
		end
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root then
			local mx, mz = toMap(root.Position.X, root.Position.Z)
			playerArrow.Position = at(mx, mz)
			local look = root.CFrame.LookVector
			playerArrow.Rotation = math.deg(math.atan2(look.X, -look.Z))
		end
	end)
end

function MapWindow.toggle()
	win:toggle()
end

function MapWindow.open()
	win:open()
end

return MapWindow
