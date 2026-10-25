-- Masmorras de 20 andares (ver o módulo Dungeons). Grupo no portal → cópia própria longe do mapa.
-- Cada andar é montado na hora: patamar de chegada (com saída) → salão com os inimigos → escada atrás de
-- uma grade, que sobe quando o salão é limpo. Qualquer membro desce a escada e o grupo inteiro vai junto
-- para o próximo andar (o anterior é desmontado). Chefe a cada 5 andares com baú para cada membro.
-- Sempre uma corrida só, do andar 1 ao 20 (sem ponto de retorno); data.dungeons[id] guarda o recorde.
-- O grupo só entra quando TODOS dão "Pronto" no portal. Inimigos usam o EnemyService com
-- "acampamentos" de sala (piso plano em floorY, paredes em bounds, sem renascer).
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Dungeons = require(Shared.Dungeons)
local Items = require(Shared.Items)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local PlayerService = require(script.Parent.PlayerService)
local EnemyService = require(script.Parent.EnemyService)
local TravelService = require(script.Parent.TravelService)
local LootService = require(script.Parent.LootService)
local Props = require(script.Parent.WorldGen.Props)

local DungeonService = {}

DungeonService.QuestHook = function(_player, _kind, _target, _amount) end

local M = Enum.Material
local ORIGIN = Vector3.new(6000, 300, 6000) -- longe do mapa (que vai até ~770 studs)
local SLOT_SPACING = 1200
local FLOOR_SPACING = 500 -- andares pares e ímpares em lugares diferentes (monta o novo antes de apagar o velho)
local WALL_HEIGHT = 24
local OPENING_WIDTH, OPENING_HEIGHT = 16, 14
local GAP = 20 -- corredor entre duas peças (paredes de 2 + 16 de corredor)

local THEMES = {
	caverna = {
		floor = Color3.fromRGB(95, 80, 65), floorMaterial = M.Slate, floorAlt = Color3.fromRGB(85, 72, 60),
		wall = Color3.fromRGB(105, 92, 80), wallMaterial = M.Rock, ceiling = Color3.fromRGB(70, 60, 52),
		accent = Color3.fromRGB(255, 150, 60), banner = Color3.fromRGB(120, 140, 60),
	},
	cripta = {
		floor = Color3.fromRGB(88, 86, 96), floorMaterial = M.Slate, floorAlt = Color3.fromRGB(62, 60, 70),
		wall = Color3.fromRGB(92, 90, 104), wallMaterial = M.Brick, ceiling = Color3.fromRGB(55, 53, 62),
		accent = Color3.fromRGB(140, 120, 255), banner = Color3.fromRGB(90, 40, 110),
	},
	abismo = {
		floor = Color3.fromRGB(45, 40, 42), floorMaterial = M.Basalt, floorAlt = Color3.fromRGB(35, 30, 32),
		wall = Color3.fromRGB(55, 48, 48), wallMaterial = M.Basalt, ceiling = Color3.fromRGB(30, 26, 26),
		accent = Color3.fromRGB(255, 90, 30), banner = Color3.fromRGB(150, 40, 20),
	},
}

-- Mecânica do andar (andares comuns): como o salão é vencido
--   exterminio = derrote todos; ondas = 3 ondas seguidas; alavancas = puxe 3 alavancas (cada uma chama
--   uma emboscada) e derrote todos; armadilhas = grelhas de fogo que explodem com aviso no chão
local MECHANICS = { "exterminio", "ondas", "alavancas", "armadilhas" }
-- Objetivo extra (opcional, dá bônus ao limpar o andar)
--   rapido = limpar antes do tempo; intocado = ninguém do grupo morre; cacada = um Campeão aparece e foge
--   em 60 s se não for derrotado; reliquias = pegar as 3 relíquias espalhadas pelo salão
local OBJECTIVES = { "rapido", "intocado", "cacada", "reliquias" }
local BLESSINGS = {
	{ name = "Bênção da Fúria", icon = "🔥", values = { damage = 0.15 }, text = "+15% de dano por 150 s" },
	{ name = "Bênção da Pedra", icon = "🛡", values = { defense = 0.2 }, text = "+20% de defesa por 150 s" },
	{ name = "Bênção da Vida", icon = "💚", heal = true, text = "vida cheia para todo o grupo" },
}

local lobbies = {} -- [dungeonId] = { player, ... } (o primeiro é o líder)
local ready = {} -- [player] = true quando deu "Pronto"
local countdowns = {} -- [dungeonId] = hora em que a masmorra começa (todos prontos)
local COUNTDOWN = 3
local runs = {} -- execuções ativas
local runOf = {} -- [player] = run
local usedSlots = {}
local container

-- ===================== PEÇAS =====================

local function block(parent, name, size, cframe, color, material, extra)
	local props = { Name = name, Size = size, CFrame = cframe, Color = color, Material = material }
	if extra then
		for key, value in extra do
			props[key] = value
		end
	end
	return Props.part(parent, props)
end

local function prompt(parent, name, action, object, hold, onTrigger)
	local p = Instance.new("ProximityPrompt")
	p.Name = name
	p.ActionText = action
	p.ObjectText = object
	p.MaxActivationDistance = 12
	p.HoldDuration = hold
	p.RequiresLineOfSight = false
	p.Parent = parent
	p.Triggered:Connect(onTrigger)
	return p
end

-- tocha na parede: suporte de ferro, cabo de madeira e chama com luz
local function torch(parent, cf)
	block(parent, "Suporte", Vector3.new(0.4, 0.4, 1.2), cf * CFrame.new(0, 0, -0.6), Color3.fromRGB(40, 40, 45), M.Metal)
	block(parent, "Tocha", Vector3.new(0.5, 1.6, 0.5), cf * CFrame.new(0, 0.6, -1.2) * CFrame.Angles(math.rad(-15), 0, 0), Color3.fromRGB(90, 60, 35), M.Wood)
	Props.fire(parent, (cf * CFrame.new(0, 1.3, -1.4)).Position, 0.55)
end

-- parede com um vão no meio (ou inteira), sem peças sobrepostas: dois lados + verga em cima do vão
local function wallWithOpening(parent, cf, length, theme, open)
	if not open then
		block(parent, "Parede", Vector3.new(length, WALL_HEIGHT, 2), cf * CFrame.new(0, WALL_HEIGHT / 2, 0), theme.wall, theme.wallMaterial)
		return
	end
	local side = (length - OPENING_WIDTH) / 2
	local dark = theme.wall:Lerp(Color3.new(0, 0, 0), 0.25)
	for _, s in { -1, 1 } do
		block(parent, "Parede", Vector3.new(side, WALL_HEIGHT, 2), cf * CFrame.new(s * (OPENING_WIDTH / 2 + side / 2), WALL_HEIGHT / 2, 0), theme.wall, theme.wallMaterial)
		block(parent, "Batente", Vector3.new(1.2, OPENING_HEIGHT, 2.6), cf * CFrame.new(s * (OPENING_WIDTH / 2 - 0.6), OPENING_HEIGHT / 2, 0), dark, M.Slate)
	end
	local above = WALL_HEIGHT - OPENING_HEIGHT
	block(parent, "Verga", Vector3.new(OPENING_WIDTH, above, 2), cf * CFrame.new(0, OPENING_HEIGHT + above / 2, 0), theme.wall, theme.wallMaterial)
	block(parent, "VergaPedra", Vector3.new(OPENING_WIDTH + 1.2, 1.4, 2.8), cf * CFrame.new(0, OPENING_HEIGHT + 0.7, 0), dark, M.Slate)
end

-- sala: piso (ladrilhos na cripta), paredes com vãos, teto, vigas e tochas
local function buildRoom(parent, theme, themeId, center, width, depth, openBack, openFront)
	local cf = CFrame.new(center)
	if themeId == "cripta" then
		local nx, nz = math.max(1, math.floor(width / 8)), math.max(1, math.floor(depth / 8))
		for i = 0, nx - 1 do
			for j = 0, nz - 1 do
				local x = -width / 2 + (i + 0.5) * (width / nx)
				local z = -depth / 2 + (j + 0.5) * (depth / nz)
				block(parent, "Ladrilho", Vector3.new(width / nx, 2, depth / nz), cf * CFrame.new(x, -1, z), if (i + j) % 2 == 0 then theme.floor else theme.floorAlt, theme.floorMaterial)
			end
		end
	else
		block(parent, "Piso", Vector3.new(width, 2, depth), cf * CFrame.new(0, -1, 0), theme.floor, theme.floorMaterial)
	end
	-- fundo/frente com vão (cobrem os cantos) e laterais entre elas
	wallWithOpening(parent, cf * CFrame.new(0, 0, -depth / 2 - 1), width + 4, theme, openBack)
	wallWithOpening(parent, cf * CFrame.new(0, 0, depth / 2 + 1), width + 4, theme, openFront)
	for _, s in { -1, 1 } do
		block(parent, "Parede", Vector3.new(2, WALL_HEIGHT, depth), cf * CFrame.new(s * (width / 2 + 1), WALL_HEIGHT / 2, 0), theme.wall, theme.wallMaterial)
		block(parent, "Rodape", Vector3.new(0.6, 1.4, depth), cf * CFrame.new(s * (width / 2 - 0.3), 0.7, 0), theme.wall:Lerp(Color3.new(0, 0, 0), 0.3), M.Slate)
		local count = math.max(1, math.floor(depth / 18))
		for i = 1, count do
			torch(parent, cf * CFrame.new(s * (width / 2 - 0.6), 8, -depth / 2 + i * depth / (count + 1)) * CFrame.Angles(0, math.rad(-s * 90), 0))
		end
	end
	block(parent, "Teto", Vector3.new(width + 4, 2, depth + 4), cf * CFrame.new(0, WALL_HEIGHT + 1, 0), theme.ceiling, theme.wallMaterial)
	for i = 1, math.floor(depth / 16) do
		block(parent, "Viga", Vector3.new(width, 1.4, 1.4), cf * CFrame.new(0, WALL_HEIGHT - 0.7, -depth / 2 + i * 16), Color3.fromRGB(70, 50, 35), M.Wood)
	end
	return cf
end

-- corredor curto entre duas peças (opcionalmente com grade de ferro no meio)
local function buildCorridor(parent, theme, startZ, x, floorY, withGate)
	local cf = CFrame.new(x, floorY, startZ + GAP / 2)
	block(parent, "PisoCorredor", Vector3.new(OPENING_WIDTH, 2, GAP), cf * CFrame.new(0, -1, 0), theme.floorAlt, theme.floorMaterial)
	local length = GAP - 4
	for _, s in { -1, 1 } do
		block(parent, "ParedeCorredor", Vector3.new(2, OPENING_HEIGHT, length), cf * CFrame.new(s * (OPENING_WIDTH / 2 + 1), OPENING_HEIGHT / 2, 0), theme.wall, theme.wallMaterial)
	end
	block(parent, "TetoCorredor", Vector3.new(OPENING_WIDTH + 4, 2, length), cf * CFrame.new(0, OPENING_HEIGHT + 1, 0), theme.ceiling, theme.wallMaterial)
	if not withGate then
		return nil
	end
	local door = Instance.new("Model")
	door.Name = "Grade"
	for i = 0, 9 do
		block(door, "Barra", Vector3.new(0.5, OPENING_HEIGHT, 0.5), cf * CFrame.new(-OPENING_WIDTH / 2 + 0.8 + i * (OPENING_WIDTH - 1.6) / 9, OPENING_HEIGHT / 2, 0), Color3.fromRGB(55, 55, 62), M.Metal)
	end
	for _, y in { 3, OPENING_HEIGHT - 2 } do
		block(door, "Travessa", Vector3.new(OPENING_WIDTH - 0.4, 0.6, 0.7), cf * CFrame.new(0, y, 0), Color3.fromRGB(45, 45, 52), M.Metal)
	end
	block(door, "Bloqueio", Vector3.new(OPENING_WIDTH, OPENING_HEIGHT, 1), cf * CFrame.new(0, OPENING_HEIGHT / 2, 0), Color3.new(0, 0, 0), M.SmoothPlastic, { Transparency = 1 })
	door.Parent = parent
	return door
end

local function openDoor(door)
	if not door or not door.Parent then
		return
	end
	for _, piece in door:GetDescendants() do
		if piece:IsA("BasePart") then
			piece.CanCollide = false
			TweenService:Create(piece, TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = piece.CFrame - Vector3.new(0, OPENING_HEIGHT + 1, 0) }):Play()
		end
	end
	task.delay(1.8, function()
		door:Destroy()
	end)
end

-- enfeites por tema (encostados nas paredes, para não atrapalhar a luta)
local function decorate(parent, theme, themeId, cf, width, depth, rng, isBoss)
	local function wallSpot(inset)
		local s = if rng:NextNumber() < 0.5 then -1 else 1
		return cf * CFrame.new(s * (width / 2 - inset), 0, rng:NextNumber(-depth / 2 + 4, depth / 2 - 4))
	end
	if themeId == "caverna" or themeId == "abismo" then
		for i = 1, math.floor(depth / 16) do
			for _, s in { -1, 1 } do
				block(parent, "Escora", Vector3.new(1.2, WALL_HEIGHT - 1.4, 1.2), cf * CFrame.new(s * (width / 2 - 0.6), (WALL_HEIGHT - 1.4) / 2, -depth / 2 + i * 16), if themeId == "abismo" then Color3.fromRGB(40, 35, 35) else Color3.fromRGB(95, 65, 40), if themeId == "abismo" then M.Basalt else M.Wood)
			end
		end
		for _ = 1, 6 do
			Props.rock(parent, wallSpot(rng:NextNumber(2.5, 5)), rng:NextNumber(0.8, 1.6), rng, theme.wall)
		end
		for _ = 1, 5 do
			local base = wallSpot(1.5)
			local color = if themeId == "abismo" then Color3.fromRGB(255, 110, 40) elseif rng:NextNumber() < 0.5 then Color3.fromRGB(90, 200, 255) else Color3.fromRGB(255, 140, 220)
			for k = 0, 2 do
				local crystal = block(parent, "Cristal", Vector3.new(0.9, rng:NextNumber(2, 4), 0.9), base * CFrame.new(k * 0.7 - 0.7, 1.2, k * 0.4) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 3), rng:NextNumber(-0.4, 0.4)), color, M.Neon, { CanCollide = false })
				if k == 1 then
					Props.light(crystal, color, 14, 1.2)
				end
			end
		end
		if themeId == "abismo" then
			-- poças e rachaduras de lava no chão (só visual)
			for _ = 1, 4 do
				local spot = cf * CFrame.new(rng:NextNumber(-width / 2 + 6, width / 2 - 6), 0.03, rng:NextNumber(-depth / 2 + 6, depth / 2 - 6))
				local lava = block(parent, "Lava", Vector3.new(0.06, rng:NextNumber(4, 8), rng:NextNumber(4, 8)), spot * CFrame.Angles(0, rng:NextNumber(0, 3), math.rad(90)), Color3.fromRGB(255, 100, 30), M.Neon, { Shape = Enum.PartType.Cylinder, CanCollide = false })
				Props.light(lava, Color3.fromRGB(255, 110, 40), 16, 1.5)
			end
			for _ = 1, 6 do
				block(parent, "Rachadura", Vector3.new(0.5, 0.05, rng:NextNumber(4, 10)), cf * CFrame.new(rng:NextNumber(-width / 2 + 4, width / 2 - 4), 0.03, rng:NextNumber(-depth / 2 + 4, depth / 2 - 4)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), Color3.fromRGB(255, 120, 40), M.Neon, { CanCollide = false })
			end
		else
			for _ = 1, 6 do
				local base = wallSpot(rng:NextNumber(1.5, 4))
				local height = rng:NextNumber(0.8, 1.6)
				block(parent, "Talo", Vector3.new(0.4, height, 0.4), base * CFrame.new(0, height / 2, 0), Color3.fromRGB(230, 220, 200), M.SmoothPlastic, { CanCollide = false })
				block(parent, "Chapeu", Vector3.new(1.4, 0.5, 1.4), base * CFrame.new(0, height + 0.2, 0), Color3.fromRGB(200, 70, 60), M.SmoothPlastic, { Shape = Enum.PartType.Ball, CanCollide = false })
			end
			for _, corner in { { -1, -1 }, { 1, 1 } } do
				local base = cf * CFrame.new(corner[1] * (width / 2 - 4), 0, corner[2] * (depth / 2 - 4))
				Props.crate(parent, base, 2.6)
				Props.crate(parent, base * CFrame.new(0.3, 2.6, 0.2), 1.6)
				Props.barrel(parent, base * CFrame.new(-corner[1] * 3.2, 0, 0), 0.9)
			end
		end
	else
		local rows = math.floor(depth / 20)
		for i = 1, rows do
			local z = -depth / 2 + i * depth / (rows + 1)
			for _, s in { -1, 1 } do
				local base = cf * CFrame.new(s * (width / 2 - 7), 0, z)
				block(parent, "BasePilar", Vector3.new(3.4, 1, 3.4), base * CFrame.new(0, 0.5, 0), theme.wall:Lerp(Color3.new(0, 0, 0), 0.2), M.Slate)
				Props.column(parent, base * CFrame.new(0, 1, 0), WALL_HEIGHT - 2, 2.6, theme.wall:Lerp(Color3.new(1, 1, 1), 0.1), M.Marble)
				block(parent, "Capitel", Vector3.new(3.4, 1, 3.4), base * CFrame.new(0, WALL_HEIGHT - 0.5, 0), theme.wall:Lerp(Color3.new(0, 0, 0), 0.2), M.Slate)
			end
		end
		for i = 1, 2 do
			for _, s in { -1, 1 } do
				local base = cf * CFrame.new(s * (width / 2 - 2.2), 0, -depth / 4 + (i - 1) * depth / 2)
				block(parent, "Sarcofago", Vector3.new(3, 2.2, 6.5), base * CFrame.new(0, 1.1, 0), Color3.fromRGB(120, 115, 125), M.Slate)
				block(parent, "Tampa", Vector3.new(3.3, 0.5, 6.8), base * CFrame.new(0, 2.45, 0) * CFrame.Angles(0, if rng:NextNumber() < 0.4 then 0.25 else 0, 0), Color3.fromRGB(140, 135, 145), M.Marble)
				local candle = block(parent, "Vela", Vector3.new(0.3, 0.8, 0.3), base * CFrame.new(-s * 0.9, 3.1, 2.6), Color3.fromRGB(240, 235, 210), M.SmoothPlastic, { CanCollide = false })
				local flame = block(parent, "ChamaVela", Vector3.new(0.2, 0.35, 0.2), candle.CFrame * CFrame.new(0, 0.55, 0), Color3.fromRGB(255, 200, 100), M.Neon, { CanCollide = false })
				Props.light(flame, Color3.fromRGB(255, 190, 110), 10, 1)
			end
		end
		for _ = 1, 10 do
			local base = cf * CFrame.new(rng:NextNumber(-width / 2 + 2, width / 2 - 2), 0, rng:NextNumber(-depth / 2 + 2, depth / 2 - 2))
			block(parent, "Osso", Vector3.new(0.35, 0.35, rng:NextNumber(1.2, 2)), base * CFrame.new(0, 0.18, 0) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), Color3.fromRGB(230, 225, 205), M.SmoothPlastic, { CanCollide = false })
		end
		for _, s in { -1, 1 } do
			Props.banner(parent, cf * CFrame.new(s * (width / 2 - 0.2), WALL_HEIGHT - 4, 0) * CFrame.Angles(0, math.rad(-s * 90), 0), theme.banner)
		end
		for _, corner in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
			block(parent, "Teia", Vector3.new(0.1, 5, 5), cf * CFrame.new(corner[1] * (width / 2 - 1.8), WALL_HEIGHT - 1.8, corner[2] * (depth / 2 - 1.8)) * CFrame.Angles(0, math.rad(corner[1] * corner[2] * 45), math.rad(45)), Color3.fromRGB(235, 235, 240), M.SmoothPlastic, { Transparency = 0.6, CanCollide = false })
		end
	end
	if isBoss then
		-- trono no fundo, braseiros e círculo de runas no chão
		local back = cf * CFrame.new(0, 0, depth / 2 - 6)
		block(parent, "Altar", Vector3.new(12, 1.5, 6), back * CFrame.new(0, 0.75, 0), theme.wall:Lerp(Color3.new(0, 0, 0), 0.3), M.Slate)
		block(parent, "Trono", Vector3.new(5, 9, 1.5), back * CFrame.new(0, 6, 2), theme.wall:Lerp(Color3.new(0, 0, 0), 0.4), M.Slate)
		block(parent, "Encosto", Vector3.new(6, 1.5, 2), back * CFrame.new(0, 11, 2), theme.accent, M.Neon, { CanCollide = false })
		for i = 0, 11 do
			local angle = i / 12 * math.pi * 2
			block(parent, "Runa", Vector3.new(2.2, 0.06, 0.8), cf * CFrame.new(math.cos(angle) * 18, 0.03, math.sin(angle) * 18) * CFrame.Angles(0, -angle, 0), theme.accent, M.Neon, { CanCollide = false, Transparency = 0.3 })
		end
		for _, s in { -1, 1 } do
			local brazier = back * CFrame.new(s * 9, 0, -4)
			Props.column(parent, brazier, 4, 1.4, Color3.fromRGB(50, 45, 45), M.Metal)
			Props.column(parent, brazier * CFrame.new(0, 4, 0), 1, 3, Color3.fromRGB(60, 55, 55), M.Metal)
			Props.fire(parent, (brazier * CFrame.new(0, 5, 0)).Position, 1.3)
		end
	end
end

-- ===================== GRUPO =====================

local function members(run)
	local list = {}
	for player in run.members do
		table.insert(list, player)
	end
	return list
end

local function notifyRun(run, notification)
	for player in run.members do
		Remotes.Notify:FireClient(player, notification)
	end
end

local function markRun(run)
	for player in run.members do
		PlayerService.markDirty(player)
	end
end

local function lobbyOf(player)
	for id, list in lobbies do
		if table.find(list, player) then
			return id, list
		end
	end
	return nil, nil
end

local function removeFromLobby(player)
	local id, list = lobbyOf(player)
	ready[player] = nil
	if list then
		table.remove(list, table.find(list, player))
		countdowns[id] = nil
		for _, other in list do
			PlayerService.markDirty(other)
		end
		if #list == 0 then
			lobbies[id] = nil
		end
	end
	return id
end

local function nearPortal(player, dungeon, range)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return root ~= nil and (root.Position - dungeon.position).Magnitude <= (range or Dungeons.PortalRange)
end

local function teleport(player, cframe)
	local character = player.Character
	if character and character.PrimaryPart then
		TravelService.dismount(player)
		character:PivotTo(cframe)
	end
end

-- ===================== ANDARES =====================

local function destroyFloor(floorState)
	if not floorState then
		return
	end
	EnemyService.clearCamp(floorState.camp)
	if floorState.folder then
		floorState.folder:Destroy()
	end
end

-- monta um andar: patamar (saída) → corredor → salão → corredor com grade → escada para baixo
local function buildFloor(run, floor)
	local dungeon = run.dungeon
	local themeId = dungeon.theme
	local theme = THEMES[themeId] or THEMES.cripta
	local rng = Random.new(run.seed + floor * 7919)
	local info = Dungeons.floorInfo(dungeon, floor)
	local isBoss = info.boss ~= nil
	local base = run.origin + Vector3.new(0, 0, (floor % 2) * FLOOR_SPACING)
	local x, floorY = base.X, base.Y
	local folder = Instance.new("Folder")
	folder.Name = ("Andar_%02d"):format(floor)
	local state = { floor = floor, info = info, folder = folder, cleared = false }

	-- patamar de chegada com o portal de saída e a placa do andar
	local landingW, landingD = 30, 22
	local landing = buildRoom(folder, theme, themeId, Vector3.new(x, floorY, base.Z), landingW, landingD, false, true)
	local exitDisc = block(folder, "Saida", Vector3.new(0.4, 8, 8), landing * CFrame.new(-landingW / 2 + 6, 4.5, -landingD / 2 + 1.5) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(120, 220, 255), M.Neon, { Shape = Enum.PartType.Cylinder, Transparency = 0.3, CanCollide = false })
	Props.light(exitDisc, Color3.fromRGB(120, 220, 255), 18, 2)
	prompt(exitDisc, "SaidaMasmorra", "Sair da masmorra", "Voltar ao portal", 0.6, function(player)
		if runOf[player] == run then
			DungeonService.leave(player, true)
		end
	end)
	local sign = block(folder, "Placa", Vector3.new(7, 2.6, 0.4), landing * CFrame.new(4, 9, -landingD / 2 + 0.2), Color3.fromRGB(60, 45, 30), M.WoodPlanks)
	Props.billboard(sign, ("%s %s  •  ANDAR %d/%d"):format(dungeon.icon, string.upper(dungeon.name), floor, Dungeons.Floors), if isBoss then Color3.fromRGB(255, 110, 80) else theme.accent, 2.5, 80)
	state.arrival = landing * CFrame.new(0, 3, -landingD / 2 + 8)

	-- salão
	local cursor = base.Z + landingD / 2
	buildCorridor(folder, theme, cursor, x, floorY, false)
	local width = if isBoss then 92 else ({ 56, 64, 72 })[rng:NextInteger(1, 3)]
	local depth = if isBoss then 84 else ({ 52, 60, 68 })[rng:NextInteger(1, 3)]
	local center = Vector3.new(x, floorY, cursor + GAP + depth / 2)
	local hall = buildRoom(folder, theme, themeId, center, width, depth, true, true)
	decorate(folder, theme, themeId, hall, width, depth, rng, isBoss)
	state.hall = hall
	local margin = 4
	local levelBonus = math.floor((floor - 1) / 2)
	state.camp = {
		id = ("dg_%s_%d_%d"):format(dungeon.id, run.slot, floor),
		center = Vector2.new(center.X, center.Z),
		radius = math.min(width, depth) / 2 - 10,
		floorY = floorY,
		bounds = { center.X - width / 2 + margin, center.X + width / 2 - margin, center.Z - depth / 2 + margin, center.Z + depth / 2 - margin },
		hpMult = run.groupMult * (if isBoss then 1 + 0.03 * (floor - 1) else info.hpMult),
		damageMult = info.damageMult,
		levelBonus = levelBonus,
		dungeon = true,
		dungeonId = dungeon.id,
		floor = floor,
	}

	-- mecânica e objetivo extra (o andar 1 é sempre exterminação, para aprender; chefes não têm)
	if not isBoss then
		state.mechanic = if floor == 1 then "exterminio" else MECHANICS[rng:NextInteger(1, #MECHANICS)]
		state.objective = OBJECTIVES[rng:NextInteger(1, #OBJECTIVES)]
	end
	local function hallSpot(margin2)
		return hall * CFrame.new(rng:NextNumber(-width / 2 + margin2, width / 2 - margin2), 0, rng:NextNumber(-depth / 2 + margin2, depth / 2 - margin2))
	end
	if state.mechanic == "alavancas" then
		state.levers = 0
		for i, spot in { { -1, -0.25 }, { 1, 0.05 }, { -1, 0.35 } } do
			local s = spot[1]
			local wallCf = hall * CFrame.new(s * (width / 2 - 0.5), 0, spot[2] * depth) * CFrame.Angles(0, math.rad(-s * 90), 0)
			block(folder, "BaseAlavanca", Vector3.new(2, 2.4, 1), wallCf * CFrame.new(0, 3, 0), Color3.fromRGB(50, 50, 56), M.Metal)
			local handle = block(folder, "Alavanca", Vector3.new(0.35, 2.6, 0.35), wallCf * CFrame.new(0, 3.8, -0.8) * CFrame.Angles(math.rad(-35), 0, 0), Color3.fromRGB(150, 110, 60), M.Wood)
			local knob = block(folder, "Pomo", Vector3.one * 0.7, handle.CFrame * CFrame.new(0, 1.3, 0), Color3.fromRGB(255, 60, 50), M.Neon, { Shape = Enum.PartType.Ball })
			Props.light(knob, Color3.fromRGB(255, 80, 60), 10, 1.5)
			local pulled = false
			prompt(handle, "Alavanca", "Puxar alavanca", ("Alavanca %d"):format(i), 1.2, function(player)
				if pulled or runOf[player] ~= run or run.current ~= state then
					return
				end
				pulled = true
				state.levers += 1
				handle.CFrame = wallCf * CFrame.new(0, 2.2, -0.8) * CFrame.Angles(math.rad(35), 0, 0)
				knob.CFrame = handle.CFrame * CFrame.new(0, 1.3, 0)
				knob.Color = Color3.fromRGB(80, 255, 120)
				-- emboscada: dois inimigos saem perto da alavanca
				local around = wallCf * CFrame.new(0, 0, -8)
				for _ = 1, 2 do
					local position = Vector3.new(around.X + math.random(-4, 4), floorY, around.Z + math.random(-4, 4))
					EnemyService.spawn(state.camp, info.pool[math.random(1, #info.pool)], { position = position, hpMult = state.camp.hpMult, damageMult = state.camp.damageMult, levelBonus = state.camp.levelBonus, rewardMult = info.rewardMult })
				end
				notifyRun(run, { kind = "message", text = ("🔧 Alavanca %d/3 puxada... emboscada!"):format(state.levers) })
				markRun(run)
			end)
		end
	elseif state.mechanic == "armadilhas" then
		state.traps = {}
		for _ = 1, 3 + Dungeons.tier(floor) do
			local spot = hallSpot(10)
			block(folder, "Grelha", Vector3.new(8, 0.15, 8), spot * CFrame.new(0, 0.08, 0), Color3.fromRGB(40, 38, 40), M.DiamondPlate, { CanCollide = false })
			local ember = block(folder, "Brasa", Vector3.new(6.5, 0.1, 6.5), spot * CFrame.new(0, 0.05, 0), Color3.fromRGB(255, 90, 30), M.Neon, { CanCollide = false, Transparency = 0.5 })
			Props.light(ember, Color3.fromRGB(255, 100, 40), 10, 1)
			table.insert(state.traps, { position = spot.Position, nextAt = os.clock() + 3 + math.random() * 3 })
		end
	end
	if state.objective == "reliquias" then
		state.relics = 0
		for _ = 1, 3 do
			local spot = hallSpot(8)
			block(folder, "Pedestal", Vector3.new(1.6, 2.4, 1.6), spot * CFrame.new(0, 1.2, 0), theme.wall:Lerp(Color3.new(0, 0, 0), 0.2), M.Slate)
			local relic = block(folder, "Reliquia", Vector3.one * 1.3, spot * CFrame.new(0, 3.2, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)), Color3.fromRGB(255, 220, 90), M.Neon, { CanCollide = false })
			Props.light(relic, Color3.fromRGB(255, 220, 90), 12, 2)
			prompt(relic, "Reliquia", "Pegar relíquia", "Objetivo extra", 0.4, function(player)
				if runOf[player] ~= run or run.current ~= state or not relic.Parent then
					return
				end
				relic:Destroy()
				state.relics += 1
				notifyRun(run, { kind = "message", text = ("✨ %s pegou uma relíquia (%d/3)"):format(player.DisplayName, state.relics) })
				markRun(run)
			end)
		end
	end
	-- segredo: tijolo solto numa parede lateral esconde um baú
	if rng:NextNumber() < 0.45 then
		local s = if rng:NextNumber() < 0.5 then -1 else 1
		local z = rng:NextNumber(-depth / 2 + 6, depth / 2 - 6)
		local brick = block(folder, "TijoloSolto", Vector3.new(0.4, 1.4, 2.2), hall * CFrame.new(s * (width / 2 - 0.2), 3, z), theme.wall:Lerp(Color3.new(1, 1, 1), 0.12), theme.wallMaterial)
		local found = false
		local secretPrompt = prompt(brick, "TijoloSolto", "Examinar", "Tijolo solto", 1, function(player)
			if found or runOf[player] ~= run then
				return
			end
			found = true
			TweenService:Create(brick, TweenInfo.new(0.6), { CFrame = brick.CFrame * CFrame.new(s * 0.6, 0, 0), Transparency = 1 }):Play()
			notifyRun(run, { kind = "banner", text = "🗝 PASSAGEM SECRETA!", sub = player.DisplayName .. " achou um baú escondido", color = Color3.fromRGB(255, 220, 120), duration = 3 })
			DungeonService.QuestHook(player, "dungeonSecret", run.dungeon.id, 1)
			DungeonService.rewardChest(run, state, hall * CFrame.new(s * (width / 2 - 3.5), 0, z) * CFrame.Angles(0, math.rad(s * 90), 0), "secret")
		end)
		secretPrompt.MaxActivationDistance = 6
	end
	-- baú suspeito: tesouro ou mímico
	if not isBoss and rng:NextNumber() < 0.25 then
		local corner = hall * CFrame.new((if rng:NextNumber() < 0.5 then -1 else 1) * (width / 2 - 5), 0, depth / 2 - 6)
		local chest = Instance.new("Model")
		chest.Name = "BauSuspeito"
		block(chest, "Bau", Vector3.new(3.4, 2, 2.4), corner * CFrame.new(0, 1, 0), Color3.fromRGB(100, 70, 45), M.WoodPlanks)
		local lid = block(chest, "Tampa", Vector3.new(3.6, 0.8, 2.6), corner * CFrame.new(0, 2.4, 0), Color3.fromRGB(150, 110, 70), M.Wood)
		chest.Parent = folder
		local opened = false
		prompt(lid, "BauSuspeito", "Abrir baú", "Baú suspeito...", 0.8, function(player)
			if opened or runOf[player] ~= run then
				return
			end
			opened = true
			local position = corner.Position
			chest:Destroy()
			if math.random() < 0.5 then
				local gold = run.dungeon.level * 5 * floor
				PlayerService.addGold(player, gold)
				PlayerService.addMaterial(player, run.dungeon.material, 2 + math.floor(floor / 3))
				Remotes.Notify:FireClient(player, { kind = "message", text = ("🎁 Tesouro! +%d de ouro"):format(gold) })
			else
				EnemyService.spawn(state.camp, info.pool[math.random(1, #info.pool)], { position = position, forceElite = true, hpMult = state.camp.hpMult, damageMult = state.camp.damageMult, levelBonus = state.camp.levelBonus, rewardMult = info.rewardMult * 2 })
				Remotes.Fx:FireAllClients("explosion", position, 6, "summon")
				notifyRun(run, { kind = "banner", text = "🎭 ERA UM MÍMICO!", sub = "Um Elite saiu do baú!", color = Color3.fromRGB(255, 120, 80), duration = 2.5 })
			end
		end)
	end
	-- altar de bênção (uma vez por andar, para o grupo todo)
	if not isBoss and rng:NextNumber() < 0.3 then
		local altarCf = hall * CFrame.new(0, 0, -depth / 2 + 7)
		block(folder, "Altar", Vector3.new(4, 2.2, 2.4), altarCf * CFrame.new(0, 1.1, 0), theme.wall:Lerp(Color3.new(1, 1, 1), 0.15), M.Marble)
		local orb = block(folder, "Orbe", Vector3.one * 1.4, altarCf * CFrame.new(0, 3.2, 0), Color3.fromRGB(150, 230, 255), M.Neon, { Shape = Enum.PartType.Ball, CanCollide = false })
		Props.light(orb, Color3.fromRGB(150, 230, 255), 14, 2)
		local used = false
		prompt(orb, "Altar", "Rezar no altar", "Bênção para o grupo", 1, function(player)
			if used or runOf[player] ~= run then
				return
			end
			used = true
			orb.Color = Color3.fromRGB(80, 80, 90)
			local blessing = BLESSINGS[math.random(1, #BLESSINGS)]
			for member in run.members do
				if blessing.heal then
					local humanoid = member.Character and member.Character:FindFirstChildOfClass("Humanoid")
					if humanoid and humanoid.Health > 0 then
						humanoid.Health = humanoid.MaxHealth
					end
				else
					PlayerService.addBuff(member, "altar", blessing.values, 150)
				end
			end
			notifyRun(run, { kind = "banner", text = blessing.icon .. " " .. string.upper(blessing.name), sub = blessing.text, color = Color3.fromRGB(150, 230, 255), duration = 3 })
		end)
	end

	-- escada para o próximo andar, atrás de uma grade
	cursor = center.Z + depth / 2
	state.gate = buildCorridor(folder, theme, cursor, x, floorY, true)
	local alcoveD = 18
	local alcove = buildRoom(folder, theme, themeId, Vector3.new(x, floorY, cursor + GAP + alcoveD / 2), 22, alcoveD, true, false)
	if floor < Dungeons.Floors then
		for i = 0, 4 do
			block(folder, "DegrauEscada", Vector3.new(10, 0.6, 2.2), alcove * CFrame.new(0, -0.3 - i * 0.6, -2 + i * 2.2), theme.floorAlt:Lerp(Color3.new(0, 0, 0), i * 0.12), M.Slate)
		end
		local hole = block(folder, "Fundo", Vector3.new(10, 0.2, 6), alcove * CFrame.new(0, -3.4, 7), Color3.fromRGB(10, 8, 8), M.SmoothPlastic, { CanCollide = false })
		Props.light(hole, theme.accent, 16, 1.5)
		local glow = block(folder, "Brilho", Vector3.new(9, 0.1, 5), alcove * CFrame.new(0, -3.2, 7), theme.accent, M.Neon, { Transparency = 0.6, CanCollide = false })
		prompt(glow, "Descer", ("Descer para o andar %d"):format(floor + 1), "O grupo inteiro desce junto", 0.8, function(player)
			if runOf[player] == run and run.current == state and state.cleared then
				DungeonService.descend(run)
			end
		end)
	end
	folder.Parent = run.folder
	return state
end

-- coloca os inimigos do andar no salão
local function populate(run, state)
	local info = state.info
	local camp = state.camp
	local options = { hpMult = camp.hpMult, damageMult = camp.damageMult, levelBonus = camp.levelBonus, rewardMult = info.rewardMult }
	if info.boss then
		options.position = Vector3.new(camp.center.X, camp.floorY, camp.center.Y + 12)
		EnemyService.spawn(camp, info.boss, options)
		notifyRun(run, { kind = "banner", text = ("👑 ANDAR %d: CHEFE"):format(state.floor), sub = "Fiquem juntos: tanque na frente, suporte atrás!", color = Color3.fromRGB(255, 110, 80), duration = 3.5 })
	else
		local count = info.count
		if state.mechanic == "ondas" then
			state.wave, state.waves = 1, 3
			count = math.max(2, math.ceil(info.count * 0.6))
		end
		for _ = 1, count do
			EnemyService.spawn(camp, info.pool[math.random(1, #info.pool)], table.clone(options))
		end
	end
	state.startedAt = os.clock()
	state.deaths = 0
	if state.objective == "rapido" then
		state.deadline = os.clock() + 45 + info.count * 9 + (if state.mechanic == "ondas" then 40 else 0) + (if state.mechanic == "alavancas" then 30 else 0)
	elseif state.objective == "cacada" then
		local championOptions = table.clone(options)
		championOptions.forceElite = true
		championOptions.hpMult = camp.hpMult * 1.5
		championOptions.rewardMult = info.rewardMult * 3
		state.champion = EnemyService.spawn(camp, info.pool[math.random(1, #info.pool)], championOptions)
		state.championUntil = os.clock() + 60
		notifyRun(run, { kind = "banner", text = "🏹 CAÇADA!", sub = "Um Campeão apareceu: derrote em 60 s antes que ele fuja", color = Color3.fromRGB(255, 200, 90), duration = 3 })
	end
end

-- textos do andar para o painel do cliente
local MECHANIC_TEXT = {
	exterminio = "Derrote todos os inimigos",
	ondas = "Sobreviva às ondas",
	alavancas = "Puxe as 3 alavancas e derrote todos",
	armadilhas = "Cuidado com as grelhas de fogo!",
}
local function mechanicText(state)
	if state.info.boss then
		return "Derrote o chefe"
	elseif state.mechanic == "ondas" then
		return ("%s (onda %d/%d)"):format(MECHANIC_TEXT.ondas, state.wave or 1, state.waves or 3)
	elseif state.mechanic == "alavancas" then
		return ("%s (%d/3)"):format(MECHANIC_TEXT.alavancas, state.levers or 0)
	end
	return MECHANIC_TEXT[state.mechanic or "exterminio"]
end

local function objectiveText(state)
	local objective = state.objective
	if not objective then
		return nil
	end
	local mark = if state.objectiveDone == true then "✔ " elseif state.objectiveDone == false then "✖ " else ""
	if objective == "rapido" then
		local left = math.max(0, math.floor((state.deadline or 0) - os.clock()))
		return mark .. ("Extra: limpe o andar a tempo (%d s)"):format(left)
	elseif objective == "intocado" then
		return mark .. ("Extra: ninguém pode cair (quedas: %d)"):format(state.deaths or 0)
	elseif objective == "cacada" then
		local alive = state.champion and not state.champion.dead and not state.championFled
		local left = math.max(0, math.floor((state.championUntil or 0) - os.clock()))
		return mark .. (if state.championFled then "Extra: o Campeão fugiu" elseif alive then ("Extra: derrote o Campeão (%d s)"):format(left) else "Extra: Campeão derrotado")
	elseif objective == "reliquias" then
		return mark .. ("Extra: pegue as relíquias (%d/3)"):format(state.relics or 0)
	end
	return nil
end

-- Baú de recompensa (chefe ou secreto): cada membro abre o seu uma vez
function DungeonService.rewardChest(run, state, cf, kind)
	local secret = kind == "secret"
	local chest = Instance.new("Model")
	chest.Name = if secret then "BauSecreto" else "BauMasmorra"
	local scale = if secret then 0.7 else 1
	block(chest, "Bau", Vector3.new(5, 3, 3.4) * scale, cf * CFrame.new(0, 1.5 * scale, 0), Color3.fromRGB(110, 70, 40), M.WoodPlanks)
	local lid = block(chest, "Tampa", Vector3.new(5.3, 1.2, 3.7) * scale, cf * CFrame.new(0, 3.6 * scale, 0), if secret then Color3.fromRGB(150, 220, 255) else Color3.fromRGB(240, 190, 60), M.Metal)
	for _, side in { -1, 1 } do
		block(chest, "Cinta", Vector3.new(0.4, 4.4, 3.8) * scale, cf * CFrame.new(side * 1.6 * scale, 2.2 * scale, 0), Color3.fromRGB(60, 60, 66), M.Metal)
	end
	Props.light(lid, if secret then Color3.fromRGB(150, 220, 255) else Color3.fromRGB(255, 220, 120), 20, 2.5)
	block(chest, "Feixe", Vector3.new(2, WALL_HEIGHT - 4, 2) * Vector3.new(scale, 1, scale), cf * CFrame.new(0, 4 + (WALL_HEIGHT - 4) / 2, 0), if secret then Color3.fromRGB(160, 225, 255) else Color3.fromRGB(255, 225, 140), M.Neon, { Transparency = 0.7, CanCollide = false })
	local claimed = {}
	if not secret then
		state.claimed = claimed
	end
	prompt(lid, chest.Name, if secret then "Abrir baú secreto" else "Abrir recompensa", ("Andar %d"):format(state.floor), 0.6, function(player)
		DungeonService.claim(player, run, state, claimed, kind)
	end)
	chest.Parent = state.folder
end

local function startFloor(run, floor)
	local old = run.current
	local state = buildFloor(run, floor)
	run.current = state
	run.floor = floor
	run.lastAlive = nil
	run.descending = false
	for player in run.members do
		teleport(player, state.arrival)
	end
	task.delay(1, function()
		destroyFloor(old)
	end)
	populate(run, state)
	markRun(run)
end

function DungeonService.descend(run)
	if run.descending or not run.current or not run.current.cleared or run.floor >= Dungeons.Floors then
		return
	end
	run.descending = true
	notifyRun(run, { kind = "banner", text = ("⬇ DESCENDO PARA O ANDAR %d"):format(run.floor + 1), sub = "Preparem-se...", color = Color3.fromRGB(220, 200, 150), duration = 2.5 })
	task.delay(2.5, function()
		if table.find(runs, run) then
			startFloor(run, run.floor + 1)
		end
	end)
end

function DungeonService.claim(player, run, state, claimed, kind)
	if runOf[player] ~= run or claimed[player] then
		return
	end
	local data = DataService.get(player)
	if not data then
		return
	end
	claimed[player] = true
	local dungeon = run.dungeon
	local floor = state.floor
	local info = state.info
	local secret = kind == "secret"
	local gold = math.floor(dungeon.level * (if secret then 5 else 8) * floor)
	local xp = math.floor(dungeon.level * (if secret then 10 else 25) * floor)
	PlayerService.addGold(player, gold)
	PlayerService.addXP(player, xp)
	PlayerService.addMaterial(player, dungeon.material, (if secret then 3 else 4) + math.floor(floor / (if secret then 2 else 1)))
	-- item exclusivo: sempre no baú do chefe (raridade mínima sobe a cada chefe); 35% no secreto
	if not secret or math.random() < 0.35 then
		local item = Items.rollDrop(dungeon.loot, data.level, "chestWeight", info.minRarity)
		PlayerService.addItem(player, item, { silent = true })
		task.delay(0.6, function()
			Remotes.Notify:FireClient(player, { kind = "chest", chest = if info.minRarity >= 4 or secret then "real" else "prata", item = Items.describe(item, false) })
		end)
	end
	Remotes.Notify:FireClient(player, { kind = "message", text = ("%s Andar %d: %d de ouro e %d de XP!"):format(if secret then "🗝" else "🏆", floor, gold, xp) })
	PlayerService.markDirty(player)
end

-- Bônus do objetivo extra (para todo o grupo)
local function objectiveReward(run, state)
	local dungeon = run.dungeon
	for player in run.members do
		PlayerService.addGold(player, dungeon.level * 3 * state.floor)
		PlayerService.addMaterial(player, dungeon.material, 2 + math.floor(state.floor / 4))
		if math.random() < 0.12 then
			local data = DataService.get(player)
			local item = Items.rollDrop(dungeon.loot, data and data.level or 1, "weight", math.max(2, Dungeons.tier(state.floor)))
			PlayerService.addItem(player, item)
		end
		DungeonService.QuestHook(player, "dungeonObjective", dungeon.id, 1)
	end
end

-- ===================== RESUMO PARA O CLIENTE =====================

function DungeonService.summary(player)
	local result = {}
	local data = DataService.get(player)
	result.best = if data then data.dungeons else {}
	local id, list = lobbyOf(player)
	if id and list then
		local names = {}
		for _, member in list do
			table.insert(names, member.DisplayName)
		end
		local flags = {}
		for _, member in list do
			table.insert(flags, ready[member] == true)
		end
		result.lobby = { id = id, members = names, ready = flags, me = ready[player] == true, startsIn = if countdowns[id] then math.max(0, math.ceil(countdowns[id] - os.clock())) else nil }
	end
	local run = runOf[player]
	if run and run.current then
		local names = {}
		for _, member in members(run) do
			table.insert(names, member.DisplayName)
		end
		local state = run.current
		result.run = {
			id = run.dungeon.id,
			floor = run.floor,
			floors = Dungeons.Floors,
			enemies = EnemyService.aliveInCamp(state.camp),
			boss = state.info.boss ~= nil,
			cleared = state.cleared,
			canClaim = state.claimed ~= nil and not state.claimed[player],
			mechanic = mechanicText(state),
			objective = objectiveText(state),
			finished = run.finished,
			closesIn = if run.finished then math.max(0, math.floor(run.closeAt - os.clock())) else nil,
			members = names,
		}
	end
	return result
end

-- ===================== ENTRAR / SAIR =====================

local function destroyRun(run)
	destroyFloor(run.current)
	if run.folder then
		run.folder:Destroy()
	end
	usedSlots[run.slot] = nil
	local index = table.find(runs, run)
	if index then
		table.remove(runs, index)
	end
end

function DungeonService.leave(player, teleportOut)
	local run = runOf[player]
	if not run then
		return { ok = false, msg = "Você não está numa masmorra." }
	end
	runOf[player] = nil
	run.members[player] = nil
	player:SetAttribute("Dungeon", nil)
	if teleportOut and player.Parent == Players then
		local position = run.dungeon.position
		local toTown = Vector3.new(-position.X, 0, -position.Z)
		local forward = if toTown.Magnitude > 1 then toTown.Unit else Vector3.new(0, 0, -1)
		local spot = position + forward * 14 + Vector3.new(0, 7, 0)
		teleport(player, CFrame.lookAt(spot, spot + forward))
	end
	PlayerService.markDirty(player)
	markRun(run)
	if next(run.members) == nil then
		destroyRun(run)
	end
	return { ok = true }
end

function DungeonService.join(player, dungeonId)
	local dungeon = Dungeons.ById[dungeonId]
	local data = DataService.get(player)
	if not dungeon or not data then
		return { ok = false, msg = "Masmorra inválida." }
	end
	if runOf[player] then
		return { ok = false, msg = "Você já está numa masmorra." }
	end
	if not nearPortal(player, dungeon) then
		return { ok = false, msg = "Chegue perto do portal." }
	end
	if data.level < dungeon.minLevel then
		return { ok = false, msg = ("Precisa ser nível %d para entrar."):format(dungeon.minLevel) }
	end
	removeFromLobby(player)
	lobbies[dungeonId] = lobbies[dungeonId] or {}
	local list = lobbies[dungeonId]
	if #list >= Dungeons.MaxPlayers then
		return { ok = false, msg = "O grupo já está cheio (4 jogadores)." }
	end
	table.insert(list, player)
	for _, member in list do
		PlayerService.markDirty(member)
	end
	return { ok = true }
end

function DungeonService.leaveLobby(player)
	removeFromLobby(player)
	PlayerService.markDirty(player)
	return { ok = true }
end

-- Marca (ou desmarca) "Pronto". Quando todos do grupo estão prontos, a contagem começa sozinha.
function DungeonService.setReady(player, value)
	local id, list = lobbyOf(player)
	if not id or not list then
		return { ok = false, msg = "Entre no grupo do portal primeiro." }
	end
	ready[player] = value == true or nil
	if not ready[player] then
		countdowns[id] = nil
	end
	for _, member in list do
		PlayerService.markDirty(member)
	end
	return { ok = true }
end

local function lobbyReady(list)
	if #list == 0 then
		return false
	end
	for _, member in list do
		if not ready[member] then
			return false
		end
	end
	return true
end

-- Começa a corrida (sempre do andar 1) com todo o grupo. A chave sai do líder (primeiro do grupo).
local function launch(dungeonId)
	local list = lobbies[dungeonId]
	local dungeon = Dungeons.ById[dungeonId]
	if not list or not dungeon or not lobbyReady(list) then
		return
	end
	local leader = list[1]
	local leaderData = DataService.get(leader)
	local function cancel(message)
		countdowns[dungeonId] = nil
		for _, member in list do
			ready[member] = nil
			Remotes.Notify:FireClient(member, { kind = "message", text = message })
			PlayerService.markDirty(member)
		end
	end
	if not leaderData then
		cancel("O líder do grupo saiu.")
		return
	end
	if dungeon.key and (leaderData.materials[dungeon.key] or 0) < 1 then
		local key = Items.Materials[dungeon.key]
		cancel(("🗝 %s precisa de uma %s (Mercador de Masmorras, na praça)."):format(leader.DisplayName, key and key.name or "chave"))
		return
	end
	for _, member in list do
		local humanoid = member.Character and member.Character:FindFirstChildOfClass("Humanoid")
		if member.Parent ~= Players or not humanoid or humanoid.Health <= 0 or runOf[member] or not nearPortal(member, dungeon, Dungeons.PortalRange + 10) then
			cancel(("%s não está pronto perto do portal."):format(member.DisplayName))
			return
		end
	end
	local group = table.clone(list)
	if dungeon.key then
		leaderData.materials[dungeon.key] -= 1
		if leaderData.materials[dungeon.key] <= 0 then
			leaderData.materials[dungeon.key] = nil
		end
	end
	lobbies[dungeonId] = nil
	countdowns[dungeonId] = nil
	for _, member in group do
		ready[member] = nil
	end
	local slot = 1
	while usedSlots[slot] do
		slot += 1
	end
	usedSlots[slot] = true
	local folder = Instance.new("Folder")
	folder.Name = ("Masmorra_%s_%d"):format(dungeon.id, slot)
	folder.Parent = container
	local run = {
		dungeon = dungeon,
		slot = slot,
		seed = math.random(1, 1e6),
		origin = Vector3.new(ORIGIN.X + (slot - 1) * SLOT_SPACING, ORIGIN.Y, ORIGIN.Z),
		folder = folder,
		members = {},
		groupMult = 1 + Dungeons.HpPerExtraPlayer * (#group - 1),
		floor = 1,
		started = os.clock(),
		finished = false,
	}
	table.insert(runs, run)
	for _, member in group do
		run.members[member] = true
		runOf[member] = run
		member:SetAttribute("Dungeon", dungeon.id)
	end
	local ok, err = pcall(startFloor, run, 1)
	if not ok then
		warn("[Masmorra] Falha ao montar: " .. tostring(err))
		for _, member in group do
			DungeonService.leave(member, true)
		end
		return
	end
	notifyRun(run, {
		kind = "banner",
		text = dungeon.icon .. " " .. string.upper(dungeon.name),
		sub = ("Andar 1 de %d  •  %d %s  •  uma corrida só: cair fora é recomeçar"):format(Dungeons.Floors, #group, if #group == 1 then "jogador" else "jogadores"),
		color = Color3.fromRGB(220, 200, 150),
		duration = 4,
	})
end

-- quem morreu volta para o patamar do andar atual
function DungeonService.onCharacterAdded(player, character)
	local run = runOf[player]
	if not run or not run.current then
		return
	end
	run.current.deaths = (run.current.deaths or 0) + 1
	task.defer(function()
		character:WaitForChild("HumanoidRootPart", 5)
		if runOf[player] == run and run.current then
			character:PivotTo(run.current.arrival)
		end
	end)
end

function DungeonService.onPlayerRemoving(player)
	removeFromLobby(player)
	if runOf[player] then
		DungeonService.leave(player, false)
	end
end

-- Todo inimigo morto numa masmorra deixa o material dela (e às vezes um item exclusivo)
function DungeonService.onEnemyKilled(player, rec)
	local camp = rec.camp
	local dungeon = camp and camp.dungeonId and Dungeons.ById[camp.dungeonId]
	if not dungeon then
		return
	end
	local amount = if rec.def.boss then 6 + math.floor(camp.floor / 2) elseif rec.elite then 2 else (if math.random() < 0.6 then 1 else 0)
	if PlayerService.getStats(player).perks.pilhagem then
		amount *= 2 -- conjunto Saqueador da Toca
	end
	if amount > 0 then
		PlayerService.addMaterial(player, dungeon.material, amount)
	end
	if not rec.def.boss and math.random() < (if rec.elite then 0.08 else 0.02) then
		local data = DataService.get(player)
		local item = Items.rollDrop(dungeon.loot, data and data.level or rec.level, "weight", math.max(2, Dungeons.tier(camp.floor)))
		LootService.spawnDrop(player, item, rec.pos)
	end
end

-- ===================== MERCADOR DE MASMORRAS =====================

local function pay(player, gold, materialId, amount)
	return PlayerService.payCost(player, { gold = gold, materials = { [materialId] = amount } })
end

-- Compra no mercador: index = posição em Dungeons.Shop
function DungeonService.buy(player, index)
	local entry = Dungeons.Shop[tonumber(index) or 0]
	if not entry or not DataService.get(player) then
		return { ok = false, msg = "Item inválido." }
	end
	local ok, msg = pay(player, entry.gold, entry.material[1], entry.material[2])
	if not ok then
		return { ok = false, msg = msg }
	end
	if entry.kind == "consumable" then
		PlayerService.addConsumable(player, entry.id, 1)
	else
		PlayerService.addMaterial(player, entry.id, 1)
	end
	PlayerService.markDirty(player)
	return { ok = true }
end

-- Item exclusivo escolhido (raridade Rara, nível do jogador), pago com o material da masmorra dele
function DungeonService.buyLoot(player, baseId)
	local base = typeof(baseId) == "string" and Items.Bases[baseId]
	local dungeon = base and base.dungeon and Dungeons.ById[base.dungeon]
	local data = DataService.get(player)
	if not dungeon or not data then
		return { ok = false, msg = "Item inválido." }
	end
	local price = Dungeons.LootPrice
	local ok, msg = pay(player, price.gold, dungeon.material, price.material)
	if not ok then
		return { ok = false, msg = msg }
	end
	local item = Items.create(baseId, price.rarity, data.level)
	PlayerService.addItem(player, item)
	return { ok = true }
end

-- ===================== LAÇO =====================

local function update(run)
	-- quem saiu do jogo ou se teleportou para longe (pedra de viagem) deixa o grupo
	for _, player in members(run) do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if player.Parent ~= Players then
			DungeonService.leave(player, false)
		elseif root and (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(run.origin.X, 0, run.origin.Z)).Magnitude > 1500 then
			DungeonService.leave(player, false)
		end
	end
	if not table.find(runs, run) then
		return
	end
	local state = run.current
	if not state then
		return
	end
	if run.finished then
		if os.clock() >= run.closeAt then
			for _, player in members(run) do
				DungeonService.leave(player, true)
			end
		elseif math.floor(run.closeAt - os.clock()) % 10 == 0 then
			markRun(run)
		end
		return
	end
	local now = os.clock()
	-- grelhas de fogo: aviso no chão e explosão 1,2 s depois
	if state.traps and not state.cleared then
		for _, trap in state.traps do
			if now >= trap.nextAt then
				trap.nextAt = now + 4 + math.random() * 2.5
				Remotes.Fx:FireAllClients("telegraph", "circle", trap.position, 5, 1.2)
				task.delay(1.2, function()
					if run.current ~= state then
						return
					end
					Remotes.Fx:FireAllClients("explosion", trap.position, 5, "fire")
					for player in run.members do
						local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
						if root then
							local offset = root.Position - trap.position
							if Vector3.new(offset.X, 0, offset.Z).Magnitude < 5.5 and math.abs(offset.Y) < 7 then
								PlayerService.damagePlayer(player, math.floor(10 * state.info.damageMult * (1 + run.dungeon.level / 8)), trap.position, { unblockable = true })
							end
						end
					end
				end)
			end
		end
	end
	-- caçada: o Campeão foge se demorar
	if state.champion and not state.champion.dead and not state.championFled and now >= state.championUntil then
		state.championFled = true
		EnemyService.despawn(state.champion)
		notifyRun(run, { kind = "message", text = "💨 O Campeão fugiu..." })
		markRun(run)
	end
	if state.deadline and math.floor(state.deadline - now) % 5 == 0 then
		markRun(run) -- atualiza o cronômetro do painel
	end
	local alive = EnemyService.aliveInCamp(state.camp)
	if alive ~= run.lastAlive then
		run.lastAlive = alive
		markRun(run)
	end
	if alive > 0 or state.cleared then
		return
	end
	-- ondas: a próxima chega quando a atual cai
	if state.wave and state.wave < state.waves then
		state.wave += 1
		local info = state.info
		local count = math.max(2, math.ceil(info.count * (0.5 + 0.25 * state.wave)))
		for _ = 1, count do
			EnemyService.spawn(state.camp, info.pool[math.random(1, #info.pool)], { hpMult = state.camp.hpMult, damageMult = state.camp.damageMult, levelBonus = state.camp.levelBonus, rewardMult = info.rewardMult })
		end
		notifyRun(run, { kind = "banner", text = ("🌊 ONDA %d/%d"):format(state.wave, state.waves), sub = "Mais inimigos chegando!", color = Color3.fromRGB(120, 190, 255), duration = 2 })
		markRun(run)
		return
	end
	-- alavancas: só passa com as 3 puxadas
	if state.levers and state.levers < 3 then
		return
	end
	state.cleared = true
	local floor = state.floor
	-- recorde: maior andar limpo nesta masmorra
	for player in run.members do
		local data = DataService.get(player)
		if data then
			data.dungeons[run.dungeon.id] = math.max(data.dungeons[run.dungeon.id] or 0, floor)
		end
	end
	-- objetivo extra
	if state.objective then
		local done
		if state.objective == "rapido" then
			done = now <= state.deadline
		elseif state.objective == "intocado" then
			done = (state.deaths or 0) == 0
		elseif state.objective == "cacada" then
			done = state.champion ~= nil and state.champion.dead and not state.championFled
		elseif state.objective == "reliquias" then
			done = (state.relics or 0) >= 3
		end
		state.objectiveDone = done == true
		if done then
			objectiveReward(run, state)
			notifyRun(run, { kind = "message", text = "⭐ Objetivo extra concluído! Bônus de ouro e material para o grupo." })
		end
	end
	if state.info.boss then
		for player in run.members do
			DungeonService.QuestHook(player, "dungeonBoss", run.dungeon.id, 1)
		end
		DungeonService.rewardChest(run, state, state.hall * CFrame.new(0, 0, 4), "boss")
		if floor >= Dungeons.Floors then
			run.finished = true
			run.closeAt = os.clock() + Dungeons.CloseAfter
			local elapsed = os.clock() - run.started
			notifyRun(run, {
				kind = "banner",
				text = ("🏆 %s CONCLUÍDA!"):format(string.upper(run.dungeon.name)),
				sub = ("Os 20 andares em %d:%02d  •  Abram o baú e saiam pelo portal"):format(math.floor(elapsed / 60), math.floor(elapsed % 60)),
				color = Color3.fromRGB(255, 215, 90),
				duration = 6,
			})
			for player in run.members do
				DungeonService.QuestHook(player, "dungeon", run.dungeon.id, 1)
			end
		else
			notifyRun(run, {
				kind = "banner",
				text = "👑 CHEFE DERROTADO!",
				sub = "Abram o baú no salão e continuem descendo",
				color = Color3.fromRGB(255, 215, 90),
				duration = 4,
			})
		end
	else
		notifyRun(run, { kind = "banner", text = "⚔ ANDAR LIMPO!", sub = "A grade subiu: desçam a escada no fundo do salão", color = Color3.fromRGB(140, 230, 140), duration = 3 })
	end
	if floor < Dungeons.Floors then
		openDoor(state.gate)
	end
	markRun(run)
end

function DungeonService.init()
	container = Instance.new("Folder")
	container.Name = "Masmorras"
	container.Parent = workspace
	-- prompt do portal no mapa: abre a janela da masmorra no cliente
	ProximityPromptService.PromptTriggered:Connect(function(triggered, player)
		if triggered.Name == "PortalMasmorra" then
			local id = triggered:GetAttribute("DungeonId")
			if Dungeons.ById[id] then
				Remotes.Notify:FireClient(player, { kind = "dungeonPortal", id = id })
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.5)
			for i = #runs, 1, -1 do
				local run = runs[i]
				if run then
					local ok, err = pcall(update, run)
					if not ok then
						warn("[Masmorra] " .. tostring(err))
					end
				end
			end
			-- grupos: todos prontos → contagem → começa
			for id, list in lobbies do
				if lobbyReady(list) then
					if not countdowns[id] then
						countdowns[id] = os.clock() + COUNTDOWN
						for _, member in list do
							Remotes.Notify:FireClient(member, { kind = "banner", text = "⚔ TODOS PRONTOS", sub = ("Entrando em %d segundos..."):format(COUNTDOWN), color = Color3.fromRGB(140, 230, 140), duration = 2 })
							PlayerService.markDirty(member)
						end
					elseif os.clock() >= countdowns[id] then
						launch(id)
					end
				elseif countdowns[id] then
					countdowns[id] = nil
				end
			end
			-- grupos: tira quem se afastou do portal
			for id, list in lobbies do
				local dungeon = Dungeons.ById[id]
				for i = #list, 1, -1 do
					local player = list[i]
					if player.Parent ~= Players or not nearPortal(player, dungeon, Dungeons.PortalRange + 20) then
						table.remove(list, i)
						ready[player] = nil
						countdowns[id] = nil
						for _, other in list do
							PlayerService.markDirty(other)
						end
						if player.Parent == Players then
							PlayerService.markDirty(player)
						end
					end
				end
			end
		end
	end)
end

return DungeonService
