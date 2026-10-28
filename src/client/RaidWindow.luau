-- Raide "Coração da Estrela": janela aberta pelo portal (estrela caída) e painel durante a luta.
--   * Vitrine: o Devorador girando em 3D e as recompensas exclusivas (conjunto Estelar) em ícones 3D.
--   * Sala: até 8 caçadores, Pronto, contagem; aviso se o prêmio da semana já foi pego.
--   * Na luta: fase atual, tempo restante e "Sair da raide".
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Raids = require(Shared.Raids)
local Enemies = require(Shared.Enemies)
local EnemyModels = require(Shared.EnemyModels)
local Items = require(Shared.Items)

local UI = require(script.Parent.UI)
local State = require(script.Parent.State)
local Window = require(script.Parent.Window)
local ItemIcon = require(script.Parent.ItemIcon)
local Sounds = require(script.Parent.Sounds)

local RaidWindow = {}

local win, body, viewport, bossModel
local tracker, trackerPhase, trackerTime
local lastKey = nil

local MAGENTA = Color3.fromRGB(255, 120, 230)

local function text(parent, props)
	local merged = { TextScaled = false, TextSize = 14, TextWrapped = true, Font = Enum.Font.GothamBold }
	for k, v in props do
		merged[k] = v
	end
	merged.Parent = parent
	return UI.label(merged)
end

-- o chefe em 3D, girando devagar
local function buildViewport(parent)
	viewport = UI.new("ViewportFrame", { Size = UDim2.new(0.42, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(14, 8, 28), Ambient = Color3.fromRGB(150, 120, 200), LightColor = Color3.fromRGB(255, 220, 255), LightDirection = Vector3.new(-1, -1, -1), Parent = parent }, { UI.corner(12), UI.stroke(MAGENTA, 2, 0.3) })
	local world = Instance.new("WorldModel")
	world.Parent = viewport
	local def = Enemies.Defs[Raids.Boss]
	local built = EnemyModels.build(def, false)
	bossModel = built.model
	bossModel.Parent = world
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	local height = built.height
	camera.CFrame = CFrame.new(Vector3.new(0, height * 0.55, -height * 1.9), Vector3.new(0, height * 0.5, 0))
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	local parts = built.parts
	RunService.RenderStepped:Connect(function()
		if not win:isOpen() then
			return
		end
		local spin = CFrame.Angles(0, os.clock() * 0.4, 0)
		for _, entry in parts do
			entry.part.CFrame = spin * entry.base
		end
	end)
	text(viewport, { Text = def.name, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.new(1, -16, 0, 26), TextSize = 20, FontFace = UI.TitleFont, TextColor3 = MAGENTA, TextXAlignment = Enum.TextXAlignment.Center })
end

local function render()
	if not win or not win:isOpen() then
		return
	end
	local raid = State.data and State.data.raid or {}
	local key = tostring(State.data and State.data.level) .. ("%s|%s|%s|%s|%s|%s"):format(table.concat(raid.members or {}, ","), table.concat((function()
		local flags = {}
		for _, flag in raid.ready or {} do
			table.insert(flags, tostring(flag))
		end
		return flags
	end)(), ","), tostring(raid.inLobby), tostring(raid.startsIn), tostring(raid.busy), tostring(raid.claimed))
	if key == lastKey then
		return
	end
	lastKey = key
	UI.clear(body)
	text(body, { Text = Raids.Text, Size = UDim2.new(1, 0, 0, 72), TextColor3 = UI.Colors.SubText, LayoutOrder = 1 })
	local level = State.data and State.data.level or 1
	if level < Raids.MinLevel then
		text(body, { Text = ("Nível necessário: %d (você está no %d). Siga a história com a Capitã Lyra para chegar lá."):format(Raids.MinLevel, level), Size = UDim2.new(1, 0, 0, 34), TextColor3 = Color3.fromRGB(255, 120, 110), LayoutOrder = 1 })
	end
	-- recompensas exclusivas
	text(body, { Text = "RECOMPENSAS EXCLUSIVAS (só nesta raide)", Size = UDim2.new(1, 0, 0, 18), TextColor3 = MAGENTA, Font = Enum.Font.GothamBlack, LayoutOrder = 2 })
	local showcase = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 64), BackgroundTransparency = 1, LayoutOrder = 3 }, { UI.list(6, true) })
	showcase.Parent = body
	for _, baseId in { "espada_estelar", "cetro_estelar", "arco_estelar", "coroa_estelar", "armadura_estelar", "amuleto_estelar" } do
		local holder = UI.new("Frame", { Size = UDim2.fromOffset(58, 58), BackgroundColor3 = Color3.fromRGB(30, 18, 50), Parent = showcase }, { UI.corner(8), UI.stroke(MAGENTA, 1.5, 0.4) })
		ItemIcon.new(holder, baseId, "Lendario", { Size = UDim2.fromScale(1, 1), spin = true, glow = true })
	end
	local set = Items.Sets.estelar
	text(body, { Text = ("Conjunto \"%s\": %s. Título \"Devorador de Estrelas\" (arco-íris)."):format(set.name, set.bonuses[4].text), Size = UDim2.new(1, 0, 0, 34), TextSize = 12, TextColor3 = Color3.fromRGB(230, 200, 255), LayoutOrder = 4 })
	text(body, { Text = if raid.claimed then "Prêmio da semana já pego: você ainda ganha o loot normal do chefe." else "Prêmio da semana disponível: baú Real + item Lendário + 3.000 de ouro!", Size = UDim2.new(1, 0, 0, 18), TextColor3 = if raid.claimed then UI.Colors.SubText else UI.Colors.Gold, LayoutOrder = 5 })
	-- sala
	local names = {}
	for i, name in raid.members or {} do
		table.insert(names, (if raid.ready[i] then "[pronto] " else "… ") .. name)
	end
	text(body, { Text = ("Sala (%d/%d): %s"):format(#(raid.members or {}), Raids.MaxPlayers, if #names > 0 then table.concat(names, "   ") else "vazia"), Size = UDim2.new(1, 0, 0, 36), LayoutOrder = 6 })
	if raid.busy then
		text(body, { Text = "Um grupo está lutando agora. Espere terminar para entrar.", Size = UDim2.new(1, 0, 0, 20), TextColor3 = Color3.fromRGB(255, 150, 120), LayoutOrder = 7 })
	end
	local row = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, LayoutOrder = 8, Parent = body }, { UI.list(8, true) })
	local join = UI.button({ Text = if raid.inLobby then "Sair da sala" else "Entrar na sala", Size = UDim2.fromOffset(150, 38), BackgroundColor3 = if raid.inLobby then Color3.fromRGB(150, 60, 60) else Color3.fromRGB(120, 60, 200), Parent = row })
	join.MouseButton1Click:Connect(function()
		State.request(if raid.inLobby then "raidLeave" else "raidJoin")
	end)
	if raid.inLobby then
		local ready = UI.button({ Text = if raid.me then "Cancelar pronto" else "PRONTO", Size = UDim2.fromOffset(150, 38), BackgroundColor3 = if raid.me then Color3.fromRGB(150, 120, 60) else UI.Colors.Green, Parent = row })
		ready.MouseButton1Click:Connect(function()
			State.request("raidReady", not raid.me)
			Sounds.play("ping", 1.3, 0.5)
		end)
	end
	if raid.startsIn then
		text(body, { Text = ("Todos prontos! A fenda se abre em %d..."):format(raid.startsIn), Size = UDim2.new(1, 0, 0, 24), TextSize = 18, TextColor3 = MAGENTA, LayoutOrder = 9 })
	end
end

local function updateTracker()
	local raid = State.data and State.data.raid
	local active = raid and raid.active
	tracker.Visible = active == true
	if active then
		local phase = Raids.Phases[raid.phase or 0]
		trackerPhase.Text = if phase then ("Fase: %s"):format(phase.name) else "Fase: o Despertar"
		trackerTime.Text = ("Tempo: %s"):format(UI.formatTime(raid.endsIn or 0))
		if win:isOpen() then
			win:close()
		end
	end
end

function RaidWindow.open()
	lastKey = nil
	win:open()
	render()
end

function RaidWindow.init(screen)
	win = Window.create(screen, { icon = "falling-star", name = "Raide", title = "RAIDE: " .. string.upper(Raids.Name), width = 860, height = 560, accent = MAGENTA })
	buildViewport(win.content)
	body = UI.new("ScrollingFrame", { Position = UDim2.new(0.42, 12, 0, 0), Size = UDim2.new(0.58, -12, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = win.content }, { UI.list(8) })
	win.onOpen = render
	-- painel durante a luta
	tracker = UI.new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 230), Size = UDim2.fromOffset(240, 96), BackgroundColor3 = Color3.fromRGB(24, 14, 44), BackgroundTransparency = 0.1, Visible = false, Parent = screen }, { UI.corner(10), UI.stroke(MAGENTA, 2, 0.3) })
	UI.label({ Text = "RAIDE", Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -20, 0, 20), TextColor3 = MAGENTA, Font = Enum.Font.GothamBlack, Parent = tracker })
	trackerPhase = UI.label({ Text = "", Position = UDim2.fromOffset(10, 24), Size = UDim2.new(1, -20, 0, 18), Parent = tracker })
	trackerTime = UI.label({ Text = "", Position = UDim2.fromOffset(10, 42), Size = UDim2.new(1, -20, 0, 16), TextColor3 = UI.Colors.SubText, Parent = tracker })
	local leave = UI.button({ Text = "Sair da raide", Position = UDim2.new(0, 10, 1, -32), Size = UDim2.new(1, -20, 0, 26), BackgroundColor3 = Color3.fromRGB(150, 50, 50), Parent = tracker })
	leave.MouseButton1Click:Connect(function()
		State.request("raidExit")
	end)
	State.Changed:Connect(function()
		render()
		updateTracker()
	end)
end

return RaidWindow
