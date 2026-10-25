-- Masmorras de 20 andares (ver o módulo Dungeons). Grupo no portal → cópia própria longe do mapa.
-- Cada andar é uma planta de várias salas montada na hora (peças em DungeonBuilder): patamar com a saída
-- → salas de combate em sequência (cada uma com a sua mecânica e uma grade que sobe quando a sala é limpa)
-- → sala da escada, mais salas laterais com altar, baús e mímicos. Qualquer membro desce a escada e o
-- grupo inteiro vai junto para o próximo andar (o anterior é desmontado). Chefe a cada 5 andares.
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
local DungeonBuilder = require(script.Parent.DungeonBuilder)

local DungeonService = {}

DungeonService.QuestHook = function(_player, _kind, _target, _amount) end

local M = Enum.Material
local ORIGIN = Vector3.new(8000, 300, 8000) -- longe do mapa (que vai até ~770 studs)
local SLOT_SPACING = 5000 -- cada grupo tem o seu espaço
local FLOOR_SPACING = 3000 -- andares pares e ímpares em lugares diferentes (monta o novo antes de apagar o velho)
local WALL_HEIGHT = DungeonBuilder.WallHeight

-- Mecânica de cada sala de combate: como a sala é vencida
--   exterminio = derrote todos; ondas = 3 ondas seguidas; alavancas = puxe 3 alavancas (cada uma chama
--   uma emboscada) e derrote todos; armadilhas = grelhas de fogo que explodem com aviso no chão
local MECHANICS = { "exterminio", "ondas", "alavancas", "armadilhas" }
-- Objetivo extra (opcional, dá bônus ao limpar o andar)
--   rapido = limpar antes do tempo; intocado = ninguém do grupo morre; cacada = um Campeão aparece e foge
--   em 60 s se não for derrotado; reliquias = pegar as 3 relíquias espalhadas pelo salão
local OBJECTIVES = { "rapido", "intocado", "cacada", "reliquias" }
-- textos para o painel do cliente
local MECHANIC_TEXT = {
	exterminio = "Derrote todos os inimigos",
	ondas = "Sobreviva às ondas",
	alavancas = "Puxe as 3 alavancas e derrote todos",
	armadilhas = "Cuidado com as grelhas de fogo!",
}
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

local block = DungeonBuilder.block

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
-- Um andar é uma planta de salas numa grade (CELL studs entre centros):
--   patamar (saída) → salas de combate em sequência (cada uma com grade na saída) → sala da escada
--   + salas laterais ligadas a salas de combate (altar, baú, mímico ou relíquias).
-- Andar de chefe: patamar → antessala → arena do chefe → escada (no andar 20 não há escada).

local CELL = 140
local DIRECTIONS = {
	{ di = 0, dj = 1, side = "south", opposite = "north", weight = 3 },
	{ di = 1, dj = 0, side = "east", opposite = "west", weight = 1.4 },
	{ di = -1, dj = 0, side = "west", opposite = "east", weight = 1.4 },
	{ di = 0, dj = -1, side = "north", opposite = "south", weight = 0 },
}

local function destroyFloor(state)
	if not state then
		return
	end
	for _, room in state.rooms or {} do
		EnemyService.clearCamp(room.camp)
	end
	if state.mimicCamp then
		EnemyService.clearCamp(state.mimicCamp)
	end
	if state.folder then
		state.folder:Destroy()
	end
end

local function spawnOptions(state, room)
	return { hpMult = room.camp.hpMult, damageMult = room.camp.damageMult, levelBonus = room.camp.levelBonus, rewardMult = state.info.rewardMult }
end

-- ponto aleatório dentro de uma sala, longe das paredes
local function roomSpot(room, rng, margin)
	return room.cf * CFrame.new(rng:NextNumber(-room.width / 2 + margin, room.width / 2 - margin), 0, rng:NextNumber(-room.depth / 2 + margin, room.depth / 2 - margin))
end

-- ponto encostado numa parede sem porta (-Z aponta para dentro)
local function wallSpot(room, rng, inset)
	local free = {}
	for _, side in { "north", "south", "east", "west" } do
		if not room.openings[side] then
			table.insert(free, side)
		end
	end
	local side = free[rng:NextInteger(1, math.max(1, #free))] or "north"
	if side == "east" or side == "west" then
		local sign = if side == "east" then 1 else -1
		return room.cf * CFrame.new(sign * (room.width / 2 - inset), 0, rng:NextNumber(-room.depth / 2 + 6, room.depth / 2 - 6)) * CFrame.Angles(0, math.rad(sign * 90), 0), side
	end
	local sign = if side == "south" then 1 else -1
	return room.cf * CFrame.new(rng:NextNumber(-room.width / 2 + 6, room.width / 2 - 6), 0, sign * (room.depth / 2 - inset)) * CFrame.Angles(0, if sign > 0 then 0 else math.pi, 0), side
end

-- monta a planta do andar (peças, salas, grades, segredos). Os inimigos entram sala por sala.
local function buildFloor(run, floor)
	local dungeon = run.dungeon
	local themeId = dungeon.theme
	local theme = DungeonBuilder.Themes[themeId] or DungeonBuilder.Themes.cripta
	local rng = Random.new(run.seed + floor * 7919)
	local info = Dungeons.floorInfo(dungeon, floor)
	local isBoss = info.boss ~= nil
	local base = run.origin + Vector3.new(0, 0, (floor % 2) * FLOOR_SPACING)
	local floorY = base.Y
	local folder = Instance.new("Folder")
	folder.Name = ("Andar_%02d"):format(floor)
	local state = { floor = floor, info = info, folder = folder, cleared = false, rooms = {}, index = 0, sideRooms = {} }

	-- ===== planta: caminho principal numa grade, sem voltar =====
	local cells = {}
	local function key(i, j)
		return i .. "," .. j
	end
	local nodes = {}
	local function addNode(i, j, role)
		local node = { i = i, j = j, role = role, openings = {} }
		cells[key(i, j)] = node
		table.insert(nodes, node)
		return node
	end
	local main = { addNode(0, 0, "landing") }
	local combatCount = if isBoss then 1 else 2 + math.floor(Dungeons.tier(floor) / 2)
	local roles = {}
	for _ = 1, combatCount do
		table.insert(roles, "combat")
	end
	if isBoss then
		table.insert(roles, "boss")
	end
	if floor < Dungeons.Floors then
		table.insert(roles, "stairs")
	end
	for _, role in roles do
		local current = main[#main]
		local options, total = {}, 0
		for _, dir in DIRECTIONS do
			if dir.weight > 0 and not cells[key(current.i + dir.di, current.j + dir.dj)] then
				table.insert(options, dir)
				total += dir.weight
			end
		end
		local chosen = DIRECTIONS[1]
		local roll = rng:NextNumber() * total
		for _, dir in options do
			roll -= dir.weight
			if roll <= 0 then
				chosen = dir
				break
			end
		end
		-- a escada e a arena seguem para a frente (fica mais claro)
		if role == "stairs" or role == "boss" then
			chosen = DIRECTIONS[1]
		end
		local node = addNode(current.i + chosen.di, current.j + chosen.dj, role)
		current.openings[chosen.side] = true
		node.openings[chosen.opposite] = true
		current.next = { node = node, dir = chosen }
		table.insert(main, node)
	end
	-- salas laterais ligadas a salas de combate
	local sideWanted = if isBoss then 0 else rng:NextInteger(1, 2)
	local combats = {}
	for _, node in main do
		if node.role == "combat" then
			table.insert(combats, node)
		end
	end
	for _ = 1, sideWanted do
		local parent = combats[rng:NextInteger(1, #combats)]
		for _, dir in DIRECTIONS do
			if not cells[key(parent.i + dir.di, parent.j + dir.dj)] and not parent.openings[dir.side] then
				local node = addNode(parent.i + dir.di, parent.j + dir.dj, "side")
				parent.openings[dir.side] = true
				node.openings[dir.opposite] = true
				parent.sides = parent.sides or {}
				table.insert(parent.sides, { node = node, dir = dir })
				break
			end
		end
	end

	-- ===== tamanhos e peças =====
	local sizes = {
		landing = { 40, 34 }, stairs = { 30, 28 }, side = { 44, 40 }, boss = { 104, 96 },
	}
	for _, node in nodes do
		local size = sizes[node.role]
		if node.role == "combat" then
			size = if isBoss then { 60, 56 } else { ({ 64, 72, 80 })[rng:NextInteger(1, 3)], ({ 60, 68, 76 })[rng:NextInteger(1, 3)] }
		end
		node.width, node.depth = size[1], size[2]
		node.center = Vector3.new(base.X + node.i * CELL, floorY, base.Z + node.j * CELL)
		local kind = if node.role == "boss" then "chefe" elseif node.role == "side" then "lateral" elseif node.role == "combat" then DungeonBuilder.randomKind(themeId, rng) else nil
		node.kind = kind
		node.cf = DungeonBuilder.room(folder, themeId, node.center, node.width, node.depth, node.openings, rng, kind)
	end
	-- corredores (com grade na saída de cada sala de combate e da arena)
	local function connect(a, link, gated)
		local dir = link.dir
		local vector = Vector3.new(dir.di, 0, dir.dj)
		local aHalf = if dir.di ~= 0 then a.width / 2 else a.depth / 2
		local b = link.node
		local bHalf = if dir.di ~= 0 then b.width / 2 else b.depth / 2
		return DungeonBuilder.corridor(folder, themeId, a.center + vector * (aHalf + 2), b.center - vector * (bHalf + 2), gated)
	end
	for _, node in main do
		if node.next then
			node.gate = connect(node, node.next, node.role == "combat" or node.role == "boss")
		end
		for _, side in node.sides or {} do
			connect(node, side, false)
		end
	end

	-- ===== patamar: portal de saída e placa do andar =====
	local landing = main[1]
	local exitCf = landing.cf * CFrame.new(-landing.width / 2 + 7, 0, -landing.depth / 2 + 1.6)
	local exitDisc = block(folder, "Saida", Vector3.new(0.4, 9, 9), exitCf * CFrame.new(0, 5, 0) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(120, 220, 255), M.Neon, { Shape = Enum.PartType.Cylinder, Transparency = 0.3, CanCollide = false })
	block(folder, "AnelSaida", Vector3.new(0.6, 10.6, 10.6), exitCf * CFrame.new(0, 5, 0.3) * CFrame.Angles(0, math.rad(90), 0), theme.trim, M.Slate, { Shape = Enum.PartType.Cylinder, CanCollide = false })
	Props.light(exitDisc, Color3.fromRGB(120, 220, 255), 20, 2)
	prompt(exitDisc, "SaidaMasmorra", "Sair da masmorra", "Voltar ao portal (a corrida acaba)", 0.8, function(player)
		if runOf[player] == run then
			DungeonService.leave(player, true)
		end
	end)
	local sign = block(folder, "Placa", Vector3.new(9, 3, 0.5), landing.cf * CFrame.new(6, 11, -landing.depth / 2 + 0.3), Color3.fromRGB(60, 45, 30), M.WoodPlanks)
	Props.billboard(sign, ("%s  •  ANDAR %d/%d"):format(string.upper(dungeon.name), floor, Dungeons.Floors), if isBoss then Color3.fromRGB(255, 110, 80) else theme.accent, 2.5, 90)
	for _, s in { -1, 1 } do
		local brazier = landing.cf * CFrame.new(s * 8, 0, landing.depth / 2 - 6)
		Props.column(folder, brazier, 3.4, 1.4, Color3.fromRGB(45, 40, 40), M.Metal)
		Props.column(folder, brazier * CFrame.new(0, 3.4, 0), 0.9, 3, Color3.fromRGB(55, 50, 50), M.Metal)
		Props.fire(folder, (brazier * CFrame.new(0, 4.2, 0)).Position, 1.1)
	end
	local arrivalPosition = (landing.cf * CFrame.new(0, 3, -landing.depth / 2 + 10)).Position
	local towards = if landing.next then landing.next.node.center else landing.center
	state.arrival = CFrame.lookAt(arrivalPosition, Vector3.new(towards.X, arrivalPosition.Y, towards.Z))

	-- ===== salas de combate (e arena): acampamento, mecânica =====
	local levelBonus = math.floor((floor - 1) / 2)
	for index, node in main do
		if node.role == "combat" or node.role == "boss" then
			local margin = 4
			local room = {
				index = index,
				role = node.role,
				cf = node.cf,
				width = node.width,
				depth = node.depth,
				openings = node.openings,
				gate = node.gate,
				kind = node.kind,
				boss = if node.role == "boss" then info.boss else nil,
				camp = {
					id = ("dg_%s_%d_%d_%d"):format(dungeon.id, run.slot, floor, index),
					center = Vector2.new(node.center.X, node.center.Z),
					radius = math.min(node.width, node.depth) / 2 - 10,
					floorY = floorY,
					bounds = { node.center.X - node.width / 2 + margin, node.center.X + node.width / 2 - margin, node.center.Z - node.depth / 2 + margin, node.center.Z + node.depth / 2 - margin },
					hpMult = run.groupMult * (if node.role == "boss" then 1 + 0.03 * (floor - 1) else info.hpMult),
					damageMult = info.damageMult,
					levelBonus = levelBonus,
					dungeon = true,
					dungeonId = dungeon.id,
					floor = floor,
				},
				count = math.clamp(2 + math.floor(floor / 3) + rng:NextInteger(0, 1), 2, 7),
			}
			if node.role == "combat" then
				room.mechanic = if floor == 1 and #state.rooms == 0 then "exterminio" else MECHANICS[rng:NextInteger(1, #MECHANICS)]
			end
			table.insert(state.rooms, room)
			-- peças da mecânica
			if room.mechanic == "alavancas" then
				room.levers = 0
				for i = 1, 3 do
					local wallCf = wallSpot(room, rng, 0.5)
					block(folder, "BaseAlavanca", Vector3.new(2.2, 2.6, 1), wallCf * CFrame.new(0, 3.2, 0), Color3.fromRGB(50, 50, 56), M.Metal)
					local handle = block(folder, "Alavanca", Vector3.new(0.4, 2.8, 0.4), wallCf * CFrame.new(0, 4, -0.85) * CFrame.Angles(math.rad(-35), 0, 0), Color3.fromRGB(150, 110, 60), M.Wood)
					local knob = block(folder, "Pomo", Vector3.one * 0.8, handle.CFrame * CFrame.new(0, 1.4, 0), Color3.fromRGB(255, 60, 50), M.Neon, { Shape = Enum.PartType.Ball })
					Props.light(knob, Color3.fromRGB(255, 80, 60), 12, 1.5)
					local pulled = false
					prompt(handle, "Alavanca", "Puxar alavanca", ("Alavanca %d"):format(i), 1.2, function(player)
						if pulled or runOf[player] ~= run or run.current ~= state or state.rooms[state.index] ~= room then
							return
						end
						pulled = true
						room.levers += 1
						handle.CFrame = wallCf * CFrame.new(0, 2.4, -0.85) * CFrame.Angles(math.rad(35), 0, 0)
						knob.CFrame = handle.CFrame * CFrame.new(0, 1.4, 0)
						knob.Color = Color3.fromRGB(80, 255, 120)
						local around = wallCf * CFrame.new(0, 0, -9)
						for _ = 1, 2 do
							local options = spawnOptions(state, room)
							options.position = Vector3.new(around.X + math.random(-4, 4), floorY, around.Z + math.random(-4, 4))
							EnemyService.spawn(room.camp, info.pool[math.random(1, #info.pool)], options)
						end
						notifyRun(run, { kind = "message", text = ("🔧 Alavanca %d/3 puxada... emboscada!"):format(room.levers) })
						markRun(run)
					end)
				end
			elseif room.mechanic == "armadilhas" then
				room.traps = {}
				for _ = 1, 3 + Dungeons.tier(floor) do
					local spot = roomSpot(room, rng, 10)
					block(folder, "Grelha", Vector3.new(8, 0.15, 8), spot * CFrame.new(0, 0.08, 0), Color3.fromRGB(40, 38, 40), M.DiamondPlate, { CanCollide = false })
					local ember = block(folder, "Brasa", Vector3.new(6.5, 0.1, 6.5), spot * CFrame.new(0, 0.05, 0), Color3.fromRGB(255, 90, 30), M.Neon, { CanCollide = false, Transparency = 0.5 })
					Props.light(ember, Color3.fromRGB(255, 100, 40), 10, 1)
					table.insert(room.traps, { position = spot.Position, nextAt = 0 })
				end
			end
		elseif node.role == "stairs" then
			state.stairsGlow = DungeonBuilder.stairs(folder, themeId, node.cf * CFrame.new(0, 0, -2))
			prompt(state.stairsGlow, "Descer", ("Descer para o andar %d"):format(floor + 1), "O grupo inteiro desce junto", 0.8, function(player)
				if runOf[player] == run and run.current == state and state.cleared then
					DungeonService.descend(run)
				end
			end)
		elseif node.role == "side" then
			table.insert(state.sideRooms, { cf = node.cf, width = node.width, depth = node.depth, openings = node.openings })
		end
	end

	-- ===== objetivo extra, relíquias, segredos, mímico, altar =====
	if not isBoss then
		state.objective = OBJECTIVES[rng:NextInteger(1, #OBJECTIVES)]
	end
	local function anyRoom()
		local all = {}
		for _, room in state.rooms do
			table.insert(all, room)
		end
		for _, room in state.sideRooms do
			table.insert(all, room)
			table.insert(all, room) -- salas laterais têm mais chance (vale explorar)
		end
		return all[rng:NextInteger(1, #all)]
	end
	if state.objective == "reliquias" then
		state.relics = 0
		for _ = 1, 3 do
			local spot = roomSpot(anyRoom(), rng, 8)
			block(folder, "Pedestal", Vector3.new(1.8, 2.6, 1.8), spot * CFrame.new(0, 1.3, 0), theme.trim, M.Slate)
			local relic = block(folder, "Reliquia", Vector3.one * 1.4, spot * CFrame.new(0, 3.5, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)), Color3.fromRGB(255, 220, 90), M.Neon, { CanCollide = false })
			Props.light(relic, Color3.fromRGB(255, 220, 90), 14, 2)
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
	-- tijolo solto numa parede esconde um baú
	if rng:NextNumber() < 0.5 then
		local room = anyRoom()
		local wallCf = wallSpot(room, rng, 0.2)
		local brick = block(folder, "TijoloSolto", Vector3.new(2.4, 1.5, 0.4), wallCf * CFrame.new(0, 3, 0), theme.wall:Lerp(Color3.new(1, 1, 1), 0.12), theme.wallMaterial)
		local found = false
		local secretPrompt = prompt(brick, "TijoloSolto", "Examinar", "Tijolo solto", 1, function(player)
			if found or runOf[player] ~= run then
				return
			end
			found = true
			TweenService:Create(brick, TweenInfo.new(0.6), { CFrame = brick.CFrame * CFrame.new(0, 0, 0.6), Transparency = 1 }):Play()
			notifyRun(run, { kind = "banner", text = "🗝 PASSAGEM SECRETA!", sub = player.DisplayName .. " achou um baú escondido", color = Color3.fromRGB(255, 220, 120), duration = 3 })
			DungeonService.QuestHook(player, "dungeonSecret", run.dungeon.id, 1)
			DungeonService.rewardChest(run, state, wallCf * CFrame.new(0, 0, -3.5), "secret")
		end)
		secretPrompt.MaxActivationDistance = 7
	end
	-- cada sala lateral ganha uma coisa: altar, baú suspeito ou baú de tesouro
	for _, side in state.sideRooms do
		local roll = rng:NextNumber()
		local spotCf = side.cf * CFrame.new(0, 0, 0)
		if roll < 0.35 then
			DungeonService.altar(run, state, spotCf, theme)
		elseif roll < 0.65 then
			DungeonService.suspiciousChest(run, state, spotCf, info)
		else
			DungeonService.rewardChest(run, state, spotCf, "secret")
		end
	end
	folder.Parent = run.folder
	return state
end

-- Altar de bênção (uma vez por andar, para o grupo todo)
function DungeonService.altar(run, state, cf, theme)
	block(state.folder, "Altar", Vector3.new(4.4, 2.4, 2.6), cf * CFrame.new(0, 1.2, 0), theme.wall:Lerp(Color3.new(1, 1, 1), 0.15), M.Marble)
	block(state.folder, "Degrau", Vector3.new(6, 0.5, 4), cf * CFrame.new(0, 0.25, 0), theme.trim, M.Slate)
	local orb = block(state.folder, "Orbe", Vector3.one * 1.5, cf * CFrame.new(0, 3.5, 0), Color3.fromRGB(150, 230, 255), M.Neon, { Shape = Enum.PartType.Ball, CanCollide = false })
	Props.light(orb, Color3.fromRGB(150, 230, 255), 18, 2)
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

-- Baú suspeito: tesouro para quem abre, ou um mímico (Elite) que entra na sala atual
function DungeonService.suspiciousChest(run, state, cf, info)
	local chest = Instance.new("Model")
	chest.Name = "BauSuspeito"
	block(chest, "Bau", Vector3.new(3.4, 2, 2.4), cf * CFrame.new(0, 1, 0), Color3.fromRGB(100, 70, 45), M.WoodPlanks)
	local lid = block(chest, "Tampa", Vector3.new(3.6, 0.8, 2.6), cf * CFrame.new(0, 2.4, 0), Color3.fromRGB(150, 110, 70), M.Wood)
	chest.Parent = state.folder
	local opened = false
	prompt(lid, "BauSuspeito", "Abrir baú", "Baú suspeito...", 0.8, function(player)
		if opened or runOf[player] ~= run then
			return
		end
		opened = true
		local position = cf.Position
		chest:Destroy()
		local room = state.rooms[math.max(1, state.index)]
		if math.random() < 0.5 or not room then
			local gold = run.dungeon.level * 5 * state.floor
			PlayerService.addGold(player, gold)
			PlayerService.addMaterial(player, run.dungeon.material, 2 + math.floor(state.floor / 3))
			Remotes.Notify:FireClient(player, { kind = "message", text = ("🎁 Tesouro! +%d de ouro"):format(gold) })
		else
			-- o mímico pertence a um acampamento só dele (não segura a grade da sala atual)
			state.mimicCamp = state.mimicCamp or { id = room.camp.id .. "_mimico", center = Vector2.new(position.X, position.Z), radius = 12, floorY = room.camp.floorY, bounds = { position.X - 16, position.X + 16, position.Z - 16, position.Z + 16 }, hpMult = room.camp.hpMult, damageMult = room.camp.damageMult, levelBonus = room.camp.levelBonus, dungeon = true, dungeonId = room.camp.dungeonId, floor = room.camp.floor }
			local options = spawnOptions(state, room)
			options.position = position
			options.forceElite = true
			options.rewardMult = info.rewardMult * 2
			EnemyService.spawn(state.mimicCamp, info.pool[math.random(1, #info.pool)], options)
			Remotes.Fx:FireAllClients("explosion", position, 6, "summon")
			notifyRun(run, { kind = "banner", text = "🎭 ERA UM MÍMICO!", sub = "Um Elite saiu do baú!", color = Color3.fromRGB(255, 120, 80), duration = 2.5 })
		end
	end)
end

-- começa uma sala: inimigos (ou o chefe) entram nela
local function startRoom(run, state, index)
	local room = state.rooms[index]
	if not room or room.started then
		return
	end
	room.started = true
	state.index = index
	run.lastAlive = nil
	local info = state.info
	local options = spawnOptions(state, room)
	if room.boss then
		options.position = Vector3.new(room.camp.center.X, room.camp.floorY, room.camp.center.Y)
		EnemyService.spawn(room.camp, room.boss, options)
		notifyRun(run, { kind = "banner", text = ("👑 ANDAR %d: CHEFE"):format(state.floor), sub = "Fiquem juntos: tanque na frente, suporte atrás!", color = Color3.fromRGB(255, 110, 80), duration = 3.5 })
	else
		local count = room.count
		if room.mechanic == "ondas" then
			room.wave, room.waves = 1, 3
			count = math.max(2, math.ceil(room.count * 0.6))
		end
		for _ = 1, count do
			EnemyService.spawn(room.camp, info.pool[math.random(1, #info.pool)], table.clone(options))
		end
		if index > 1 then
			notifyRun(run, { kind = "banner", text = ("⚔ SALA %d/%d"):format(index, #state.rooms), sub = MECHANIC_TEXT[room.mechanic or "exterminio"], color = Color3.fromRGB(220, 200, 150), duration = 2.5 })
		end
	end
	if room.traps then
		for _, trap in room.traps do
			trap.nextAt = os.clock() + 2 + math.random() * 3
		end
	end
	markRun(run)
end

-- começa o andar: primeira sala, cronômetro e caçada
local function populate(run, state)
	state.startedAt = os.clock()
	state.deaths = 0
	startRoom(run, state, 1)
	if state.objective == "rapido" then
		local total = 0
		for _, room in state.rooms do
			total += room.count * (if room.mechanic == "ondas" then 2 else 1) + (if room.mechanic == "alavancas" then 4 else 0)
		end
		state.deadline = os.clock() + 30 + total * 8 + #state.rooms * 15
	elseif state.objective == "cacada" then
		local room = state.rooms[1]
		local options = spawnOptions(state, room)
		options.forceElite = true
		options.hpMult = room.camp.hpMult * 1.5
		options.rewardMult = state.info.rewardMult * 3
		state.champion = EnemyService.spawn(room.camp, state.info.pool[math.random(1, #state.info.pool)], options)
		state.championUntil = os.clock() + 60
		notifyRun(run, { kind = "banner", text = "🏹 CAÇADA!", sub = "Um Campeão apareceu: derrote em 60 s antes que ele fuja", color = Color3.fromRGB(255, 200, 90), duration = 3 })
	end
end

local function mechanicText(state)
	local room = state.rooms[state.index]
	if not room then
		return ""
	end
	local prefix = ("Sala %d/%d: "):format(state.index, #state.rooms)
	if room.boss then
		return prefix .. "derrote o chefe"
	elseif room.mechanic == "ondas" then
		return prefix .. ("%s (onda %d/%d)"):format(MECHANIC_TEXT.ondas, room.wave or 1, room.waves or 3)
	elseif room.mechanic == "alavancas" then
		return prefix .. ("%s (%d/3)"):format(MECHANIC_TEXT.alavancas, room.levers or 0)
	end
	return prefix .. MECHANIC_TEXT[room.mechanic or "exterminio"]
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
			enemies = if state.rooms[state.index] then EnemyService.aliveInCamp(state.rooms[state.index].camp) else 0,
			boss = state.rooms[state.index] ~= nil and state.rooms[state.index].boss ~= nil,
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
		member:SetAttribute("AutoFarm", false)
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
		elseif root and (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(run.origin.X, 0, run.origin.Z)).Magnitude > 4500 then
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
	local room = state.rooms[state.index]
	if not room then
		return
	end
	-- grelhas de fogo da sala atual: aviso no chão e explosão 1,2 s depois
	if room.traps and not room.cleared then
		for _, trap in room.traps do
			if trap.nextAt > 0 and now >= trap.nextAt then
				trap.nextAt = now + 4 + math.random() * 2.5
				Remotes.Fx:FireAllClients("telegraph", "circle", trap.position, 5, 1.2)
				task.delay(1.2, function()
					if run.current ~= state or room.cleared then
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
	local alive = EnemyService.aliveInCamp(room.camp)
	if alive ~= run.lastAlive then
		run.lastAlive = alive
		markRun(run)
	end
	if alive > 0 or room.cleared then
		return
	end
	-- ondas: a próxima chega quando a atual cai
	if room.wave and room.wave < room.waves then
		room.wave += 1
		local count = math.max(2, math.ceil(room.count * (0.5 + 0.25 * room.wave)))
		for _ = 1, count do
			EnemyService.spawn(room.camp, state.info.pool[math.random(1, #state.info.pool)], spawnOptions(state, room))
		end
		notifyRun(run, { kind = "banner", text = ("🌊 ONDA %d/%d"):format(room.wave, room.waves), sub = "Mais inimigos chegando!", color = Color3.fromRGB(120, 190, 255), duration = 2 })
		markRun(run)
		return
	end
	-- alavancas: só passa com as 3 puxadas
	if room.levers and room.levers < 3 then
		return
	end
	room.cleared = true
	DungeonBuilder.openGate(room.gate)
	local floor = state.floor
	if room.boss then
		for player in run.members do
			DungeonService.QuestHook(player, "dungeonBoss", run.dungeon.id, 1)
		end
		DungeonService.rewardChest(run, state, room.cf * CFrame.new(0, 0, 6), "boss")
	end
	-- próxima sala
	if state.rooms[state.index + 1] then
		if room.boss then
			notifyRun(run, { kind = "banner", text = "👑 CHEFE DERROTADO!", sub = "Abram o baú e sigam em frente", color = Color3.fromRGB(255, 215, 90), duration = 3 })
		end
		startRoom(run, state, state.index + 1)
		return
	end
	-- andar limpo
	state.cleared = true
	for player in run.members do
		local data = DataService.get(player)
		if data then
			data.dungeons[run.dungeon.id] = math.max(data.dungeons[run.dungeon.id] or 0, floor)
		end
	end
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
	elseif room.boss then
		notifyRun(run, { kind = "banner", text = "👑 CHEFE DERROTADO!", sub = "Abram o baú; a escada para o próximo andar está aberta", color = Color3.fromRGB(255, 215, 90), duration = 4 })
	else
		notifyRun(run, { kind = "banner", text = "⚔ ANDAR LIMPO!", sub = "A última grade subiu: desçam a escada", color = Color3.fromRGB(140, 230, 140), duration = 3 })
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
