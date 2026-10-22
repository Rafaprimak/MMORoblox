-- Mapa do mundo desenhado a partir do relevo, com pedras de viagem clicáveis, locais e a sua posição.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local World = require(Shared.World)
local Enemies = require(Shared.Enemies)
local Points = require(Shared.Points)

local UI = require(script.Parent.UI)
local State = require(script.Parent.State)
local Window = require(script.Parent.Window)
local Sounds = require(script.Parent.Sounds)

local MapWindow = {}

local SIZE = 460
local CELLS = 46
local player = Players.LocalPlayer

local win, mapFrame, markers, playerArrow, info
local drawn = false
local stoneButtons = {}
local poiLabels = {}

local function toMap(x, z)
	return (x + World.Half) / (World.Half * 2) * SIZE, (z + World.Half) / (World.Half * 2) * SIZE
end

local function cellColor(x, z)
	local w = World.weights(x, z)
	local h = World.heightWithWeights(x, z, w)
	if h < World.SeaLevel then
		return Color3.fromRGB(40, 100, 150):Lerp(Color3.fromRGB(20, 60, 110), math.clamp(-h / 15, 0, 1))
	end
	if World.roadDistance(x, z) < 6 then
		return Color3.fromRGB(170, 140, 100)
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
		label.Text = if found then poi.icon .. (if opened then "✔" else "") else "❓"
		label.TextTransparency = if found then 0 else 0.2
	end
end

local function draw()
	if drawn then
		return
	end
	drawn = true
	local cell = SIZE / CELLS
	for i = 0, CELLS - 1 do
		for j = 0, CELLS - 1 do
			local x = -World.Half + (i + 0.5) * (World.Half * 2 / CELLS)
			local z = -World.Half + (j + 0.5) * (World.Half * 2 / CELLS)
			UI.new("Frame", { Position = UDim2.fromOffset(i * cell, j * cell), Size = UDim2.fromOffset(cell + 1, cell + 1), BorderSizePixel = 0, BackgroundColor3 = cellColor(x, z), Parent = mapFrame })
		end
		if i % 8 == 0 then
			task.wait()
		end
	end
	-- nomes dos locais
	for _, loc in World.Locations do
		local mx, mz = toMap(loc.x, loc.z)
		UI.label({ Text = loc.name, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(mx, mz - 12), Size = UDim2.fromOffset(130, 14), TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = Color3.fromRGB(255, 245, 220), ZIndex = 3, Parent = markers }, { UI.textStroke(1.5) })
	end
	-- acampamentos de inimigos
	for _, camp in Enemies.Camps do
		if camp.id ~= "treino" then
			local mx, mz = toMap(camp.center.X, camp.center.Y)
			local level = 1
			for enemyId in camp.spawns do
				level = math.max(level, Enemies.Defs[enemyId].level)
			end
			UI.label({ Text = (if camp.boss then "👑" else "💀") .. level, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(mx, mz), Size = UDim2.fromOffset(34, 14), TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = if camp.boss then Color3.fromRGB(255, 90, 70) else Color3.fromRGB(255, 200, 190), ZIndex = 3, Parent = markers }, { UI.textStroke(1.5) })
		end
	end
	-- locais de interesse (❓ até descobrir; ✔ quando o baú foi aberto)
	for _, poi in Points.List do
		local mx, mz = toMap(poi.x, poi.z)
		local label = UI.new("TextButton", { Text = "❓", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(mx, mz), Size = UDim2.fromOffset(24, 24), BackgroundTransparency = 1, TextScaled = true, Font = Enum.Font.GothamBlack, TextColor3 = Color3.new(1, 1, 1), ZIndex = 4, Parent = markers }, { UI.textStroke(1.5) })
		poiLabels[poi.id] = label
		label.MouseEnter:Connect(function()
			local data = State.data
			local found = data and data.poi and data.poi[poi.id]
			local opened = data and data.poiChests and data.poiChests[poi.id]
			info.Text = if found then ("%s %s%s"):format(poi.icon, poi.name, if opened then " — baú aberto ✔" else " — o baú escondido ainda está lá!") else "❓ Local desconhecido. Vá até lá para descobrir."
		end)
	end
	refreshPois()
	-- pedras de viagem
	for _, stone in World.Waystones do
		local mx, mz = toMap(stone.x, stone.z)
		local button = UI.button({ Text = "🌀", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(mx, mz), Size = UDim2.fromOffset(28, 28), BackgroundColor3 = UI.Colors.Dark, ZIndex = 4, Parent = markers })
		stoneButtons[stone.id] = button
		button.MouseButton1Click:Connect(function()
			local data = State.data
			if not data or not data.discovered[stone.id] then
				info.Text = "🔒 " .. stone.name .. ": chegue perto dessa pedra para ativá-la."
				return
			end
			local result = State.request("travel", stone.id)
			if result and result.ok then
				Sounds.play("ping", 1.2, 0.5)
				win:close()
			end
		end)
		button.MouseEnter:Connect(function()
			info.Text = "🌀 " .. stone.name .. (if State.data and State.data.discovered[stone.id] then " — clique para viajar" else " — não ativada")
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
	win = Window.create(screen, { name = "Mapa", title = "🗺️ MAPA  •  clique numa 🌀 ativada para viajar", width = SIZE + 40, height = SIZE + 110, accent = Color3.fromRGB(140, 210, 255) })
	mapFrame = UI.new("Frame", { Size = UDim2.fromOffset(SIZE, SIZE), BackgroundColor3 = Color3.fromRGB(30, 70, 110), ClipsDescendants = true, Parent = win.content }, { UI.corner(8) })
	markers = UI.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 3, Parent = mapFrame })
	playerArrow = UI.label({ Text = "▲", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(22, 22), TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = Color3.fromRGB(255, 240, 80), ZIndex = 6, Parent = markers }, { UI.textStroke(2) })
	info = UI.label({ Text = "Você é a seta amarela. 💀 = inimigos (nível), 👑 = chefe, ❓ = local a descobrir.", Position = UDim2.fromOffset(0, SIZE + 8), Size = UDim2.new(1, 0, 0, 20), TextColor3 = UI.Colors.SubText, Parent = win.content })
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
			playerArrow.Position = UDim2.fromOffset(mx, mz)
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
