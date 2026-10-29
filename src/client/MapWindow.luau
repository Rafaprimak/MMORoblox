-- Mapa do mundo desenhado a partir do relevo (com sombreado das encostas), estradas, ruas da vila, pedras de
-- viagem clicáveis, locais, portais das masmorras e da raide, NPCs com missão, o objetivo da missão e a sua
-- posição. Roda do mouse (ou botões +/-) dá zoom; arrastar move o mapa.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local World = require(Shared.World)
local Enemies = require(Shared.Enemies)
local Points = require(Shared.Points)
local TownPlan = require(Shared.TownPlan)
local Dungeons = require(Shared.Dungeons)
local Raids = require(Shared.Raids)
local NPCs = require(Shared.NPCs)
local Quests = require(Shared.Quests)

local UI = require(script.Parent.UI)
local State = require(script.Parent.State)
local Window = require(script.Parent.Window)
local Sounds = require(script.Parent.Sounds)
local PartyUI = require(script.Parent.PartyUI)
local EventTracker = require(script.Parent.EventTracker)
local WorldMarkers = require(script.Parent.WorldMarkers)

local MapWindow = {}

local SIZE = 460
local CELLS = 128 -- resolução do relevo (células iguais lado a lado viram um quadro só)
local MIN_ZOOM, MAX_ZOOM = 1, 5
local player = Players.LocalPlayer

local win, mapFrame, canvas, markers, playerArrow, info
local partyDots = {} -- pontos verdes dos colegas do grupo
local eventMark -- ícone do evento do mundo (chefe/invasão)
local zoom = 1
local offset = Vector2.zero -- canto de cima do mapa ampliado, em pixels (sempre <= 0)
local drawn = false
local stoneButtons = {}
local poiLabels = {}
local npcMarks = {} -- [npcId] = "!" (missão para pegar) ou "?" (missão para entregar)
local objectiveMark -- losango dourado no objetivo da missão
local drawPortals, refreshNpcMarks -- declaradas abaixo

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

-- cor do terreno (sem sombra); t é arredondado em degraus para células vizinhas iguais virarem um quadro só
local function step(t, steps)
	return math.floor(math.clamp(t, 0, 1) * steps + 0.5) / steps
end

local function cellColor(h, w)
	if h < World.SeaLevel then
		return Color3.fromRGB(40, 100, 150):Lerp(Color3.fromRGB(20, 60, 110), step(-h / 15, 3)), true
	end
	if w.town > 0.6 then
		return Color3.fromRGB(175, 165, 150), false
	end
	if World.designHeight(h) > 115 then
		return Color3.fromRGB(235, 240, 245), false
	end
	if w.mountain > 0.55 or w.crater > 0.5 then
		return Color3.fromRGB(120, 112, 105):Lerp(Color3.fromRGB(160, 150, 140), step((h - 40) / 80, 3)), false
	end
	if w.ocean > 0.08 and h < World.SeaLevel + 6 then
		return Color3.fromRGB(225, 205, 150), false
	end
	if w.forest > 0.5 then
		return Color3.fromRGB(45, 100, 50):Lerp(Color3.fromRGB(35, 82, 42), step((w.forest - 0.5) * 2, 2)), false
	end
	if w.ruins > 0.5 then
		return Color3.fromRGB(140, 140, 115), false
	end
	return Color3.fromRGB(95, 160, 75):Lerp(Color3.fromRGB(120, 175, 85), step((h - 10) / 30, 3)), false
end

local function shaded(color, shade)
	return Color3.new(math.min(color.R * shade, 1), math.min(color.G * shade, 1), math.min(color.B * shade, 1))
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
	-- relevo: altura de cada célula e cor com a sombra das encostas (luz vindo do noroeste)
	local cellSize = World.Half * 2 / CELLS
	local heights, colors, water = {}, {}, {}
	for i = 0, CELLS - 1 do
		heights[i], colors[i], water[i] = {}, {}, {}
		for j = 0, CELLS - 1 do
			local x = -World.Half + (i + 0.5) * cellSize
			local z = -World.Half + (j + 0.5) * cellSize
			local w = World.weights(x, z)
			local h = World.heightWithWeights(x, z, w)
			heights[i][j] = h
			colors[i][j], water[i][j] = cellColor(h, w)
		end
		if i % 4 == 0 then
			task.wait()
		end
	end
	for j = 0, CELLS - 1 do
		local runStart, runColor, runKey = 0, nil, nil
		local function flush(endIndex)
			if runColor then
				UI.new("Frame", { Position = at(runStart / CELLS, j / CELLS), Size = UDim2.new((endIndex - runStart) / CELLS, 1, 1 / CELLS, 1), BorderSizePixel = 0, BackgroundColor3 = runColor, Parent = canvas })
			end
		end
		for i = 0, CELLS - 1 do
			local color = colors[i][j]
			if not water[i][j] then
				local hNW = heights[math.max(i - 1, 0)][math.max(j - 1, 0)]
				local hSE = heights[math.min(i + 1, CELLS - 1)][math.min(j + 1, CELLS - 1)]
				local shade = 1 + math.clamp((hNW - hSE) / (cellSize * 2) * 0.9, -0.3, 0.3)
				color = shaded(color, math.floor(shade * 14 + 0.5) / 14)
			end
			local key = math.floor(color.R * 64) * 4096 + math.floor(color.G * 64) * 64 + math.floor(color.B * 64)
			if key ~= runKey then
				flush(i)
				runStart, runColor, runKey = i, color, key
			end
		end
		flush(CELLS)
		if j % 8 == 0 then
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
	local K = World.PropScale
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
			info.Text = if found then ("%s%s"):format(poi.name, if opened then " — baú já aberto" else " — o baú escondido ainda está lá!") else "? Local desconhecido. Vá até lá para descobrir."
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
	drawPortals()
	refreshNpcMarks()
end

-- marcador com nome (portais das masmorras e da raide)
local function namedMark(x, z, iconName, color, name)
	local mx, mz = toMap(x, z)
	local holder = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = at(mx, mz), Size = UDim2.fromOffset(24, 24), BackgroundTransparency = 1, ZIndex = 4, Parent = markers })
	UI.icon(iconName, { Size = UDim2.fromScale(1, 1), Color = color, ZIndex = 4, Parent = holder })
	UI.label({ Text = name, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.fromOffset(140, 13), TextXAlignment = Enum.TextXAlignment.Center, TextScaled = false, TextSize = 11, TextColor3 = color, ZIndex = 4, Parent = holder }, { UI.textStroke(1.2) })
	return holder
end

function drawPortals()
	for _, dungeon in Dungeons.List do
		if dungeon.position then
			namedMark(dungeon.position.X, dungeon.position.Z, dungeon.icon or "portal", Color3.fromRGB(200, 150, 255), dungeon.name)
		end
	end
	if Raids.PortalX then
		namedMark(Raids.PortalX, Raids.PortalZ, "falling-star", Color3.fromRGB(255, 120, 220), "Raide: " .. Raids.Name)
	end
end

-- "!" nos NPCs com missão para pegar e "?" nos que esperam uma entrega
function refreshNpcMarks()
	local data = State.data
	local wanted = {}
	if data and data.quests then
		for npcId, list in data.quests.available or {} do
			if #list > 0 then
				wanted[npcId] = "!"
			end
		end
		for _, entry in data.quests.active or {} do
			local def = Quests.ById[entry.id]
			if entry.ready and def then
				wanted[def.turnIn or def.giver] = "?"
			end
		end
	end
	for npcId, label in npcMarks do
		if not wanted[npcId] then
			label:Destroy()
			npcMarks[npcId] = nil
		end
	end
	for npcId, symbol in wanted do
		local npc = NPCs.ById[npcId]
		if npc then
			local label = npcMarks[npcId]
			if not label then
				local mx, mz = toMap(npc.x, npc.z)
				label = UI.label({ Text = symbol, AnchorPoint = Vector2.new(0.5, 1), Position = at(mx, mz), Size = UDim2.fromOffset(16, 20), TextXAlignment = Enum.TextXAlignment.Center, Font = Enum.Font.GothamBlack, ZIndex = 5, Parent = markers }, { UI.textStroke(1.5) })
				label.MouseEnter:Connect(function()
					info.Text = npc.name .. (if label.Text == "?" then " — missão para entregar" else " — tem missão para você")
				end)
				npcMarks[npcId] = label
			end
			label.Text = symbol
			label.TextColor3 = if symbol == "?" then Color3.fromRGB(120, 230, 140) else UI.Colors.Gold
		end
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
	playerArrow = UI.iconImage("plain-arrow", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(22, 22), Color = Color3.fromRGB(255, 240, 80), ZIndex = 6, Parent = markers })
	info = UI.label({ Text = "Seta = você • losango dourado = objetivo • ! / ? = NPC com missão • caveira = inimigos (nível) • roda do mouse = zoom", TextScaled = false, TextSize = 12, TextWrapped = true, Position = UDim2.fromOffset(0, SIZE + 6), Size = UDim2.new(1, 0, 0, 34), TextColor3 = UI.Colors.SubText, Parent = win.content })
	win.onOpen = function()
		task.spawn(draw)
		refreshStones()
	end
	State.Changed:Connect(function()
		refreshStones()
		refreshPois()
		refreshNpcMarks()
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
			playerArrow.Rotation = math.deg(math.atan2(look.X, -look.Z)) + 180 -- a seta do ícone aponta para baixo
		end
		-- colegas do grupo
		local mates = PartyUI.members()
		for i, mate in mates do
			local dot = partyDots[i]
			if not dot or not dot.Parent then
				dot = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(12, 12), BackgroundColor3 = Color3.fromRGB(110, 235, 130), ZIndex = 6, Parent = markers }, { UI.corner(6), UI.stroke(Color3.new(0, 0, 0), 1.5) })
				partyDots[i] = dot
			end
			local mateRoot = mate.player.Character and mate.player.Character:FindFirstChild("HumanoidRootPart")
			dot.Visible = mateRoot ~= nil
			if mateRoot then
				local mx, mz = toMap(mateRoot.Position.X, mateRoot.Position.Z)
				dot.Position = at(mx, mz)
			end
		end
		for i = #mates + 1, #partyDots do
			partyDots[i].Visible = false
		end
		-- objetivo da missão acompanhada (o mesmo do feixe dourado)
		local goal = WorldMarkers.currentTarget()
		if goal and goal.position then
			if not objectiveMark or not objectiveMark.Parent then
				objectiveMark = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(14, 14), Rotation = 45, BackgroundColor3 = Color3.fromRGB(255, 215, 90), ZIndex = 6, Parent = markers }, { UI.stroke(Color3.fromRGB(60, 40, 10), 2) })
			end
			local mx, mz = toMap(goal.position.X, goal.position.Z)
			objectiveMark.Position = at(mx, mz)
			local pulse = 14 + math.sin(os.clock() * 5) * 3
			objectiveMark.Size = UDim2.fromOffset(pulse, pulse)
			objectiveMark.Visible = true
		elseif objectiveMark then
			objectiveMark.Visible = false
		end
		-- evento do mundo
		local ex, ez, kind = EventTracker.position()
		if ex then
			if not eventMark or not eventMark.Parent then
				eventMark = UI.icon("crown", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(30, 30), ZIndex = 7, Parent = markers })
			end
			-- ícones: "crown", "crossed-swords"
			UI.setIcon(eventMark, if kind == "boss" then "crown" else "crossed-swords", Color3.fromRGB(255, 110, 80))
			local mx, mz = toMap(ex, ez)
			eventMark.Position = at(mx, mz)
			eventMark.Visible = true
		elseif eventMark then
			eventMark.Visible = false
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
