-- Auto (só VIP; o servidor libera o atributo "AutoFarm"). Um piloto automático que joga sozinho:
--   * MISSÕES: aceita as missões que dá para fazer sozinho, vai até o objetivo (caçar, coletar, conversar,
--     explorar, achar segredos, subir de nível) e entrega no NPC. Viaja pelas pedras de viagem e monta no
--     cavalo nas distâncias longas.
--   * COMBATE: ataca no ritmo do combo, usa as habilidades 1-4, toma poção quando está mal.
--   * ROTINA: resgata o login diário e o passe, equipa itens melhores e vende o lixo quando a bolsa enche.
--   * Sem missão possível: caça em volta do ponto onde foi ligado.
-- Masmorras, raide, arena, chefes de mundo e ofícios (forja, alquimia, encantamento) ficam com você.
-- Mexer o personagem (WASD, setas, analógico, pulo) desliga.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local MarketplaceService = game:GetService("MarketplaceService")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Enemies = require(Shared.Enemies)
local Quests = require(Shared.Quests)
local NPCs = require(Shared.NPCs)
local World = require(Shared.World)
local Points = require(Shared.Points)
local Remotes = require(Shared.Remotes)

local UI = require(script.Parent.UI)
local State = require(script.Parent.State)
local Controller = require(script.Parent.Controller)
local Popups = require(script.Parent.Popups)
local WorldMarkers = require(script.Parent.WorldMarkers)

local AutoHunt = {}

local RANGE = 70 -- caça livre: até onde ele vai buscar inimigos a partir do ponto de partida
local QUEST_FIGHT_RANGE = 90 -- missão de caça: raio em volta do acampamento do alvo
local REACH = { bow = 34, staff = 30 } -- alcance de ataque por arma (o resto: corpo a corpo)
local MELEE_REACH = 6.5
local POTION_AT = 0.45 -- vida (%) para tomar poção de vida (a grande abaixo de 30%)
local TALK_RANGE = 12
local TRAVEL_MIN = 650 -- studs: acima disso tenta uma pedra de viagem

-- objetivos que o Auto sabe cumprir sozinho
local AUTO_OBJECTIVES = {
	kill = true, hit = true, gather = true, deliver = true, talk = true, explore = true, discover = true,
	poi = true, poiSecret = true, level = true, mastery = true, mount = true, dodge = true, ability = true,
	rhythm = true, finisher = true, parry = true,
}

local player = Players.LocalPlayer
local anchor = nil
local banner, statusLabel
local lastAbility, abilitySlot, lastDodge = 0, 1, 0
local abilityReadyAt = {} -- [slot] = quando a habilidade sai da recarga (conta do cliente)
local potionUsedAt = {} -- [poção] = última vez usada
local lastParryTap = 0
local guardUntil = 0 -- defendendo (aparar/esquivar): não ataca nem anda até passar
local evadeTo, evadeUntil = nil, 0 -- saindo de um círculo/linha vermelha
local lastHurt = 0 -- última vez que o personagem levou dano (reage a quem ataca de longe)
local lockedTarget = nil -- inimigo em luta: só troca quando ele morre ou fica muito longe
local LOCK_RANGE = 70
local lastChores, lastTravel, lastMount, lastTalk, lastPromptAt, lastRequest = 0, 0, 0, 0, 0, 0

local MOVE_KEYS = {
	[Enum.KeyCode.W] = true, [Enum.KeyCode.A] = true, [Enum.KeyCode.S] = true, [Enum.KeyCode.D] = true,
	[Enum.KeyCode.Up] = true, [Enum.KeyCode.Down] = true, [Enum.KeyCode.Left] = true, [Enum.KeyCode.Right] = true,
	[Enum.KeyCode.Space] = true,
}

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

function AutoHunt.isOn()
	return player:GetAttribute("AutoFarm") == true
end

function AutoHunt.toggle()
	if AutoHunt.isOn() then
		State.request("autoFarm", false)
		return
	end
	if player:GetAttribute("Dungeon") or player:GetAttribute("Raid") or player:GetAttribute("Arena") then
		Popups.message("O Auto não funciona em masmorras, raide e arena.", UI.Colors.Gold)
		return
	end
	if not player:GetAttribute("Vip") then
		if Config.VipGamePassId > 0 then
			MarketplaceService:PromptGamePassPurchase(player, Config.VipGamePassId)
		else
			Popups.message("O Auto é exclusivo para VIP (o VIP ainda não está à venda).", UI.Colors.Gold)
		end
		return
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	State.request("autoFarm", true, root and root.Position)
end

local function setStatus(text)
	if statusLabel and statusLabel.Text ~= text then
		statusLabel.Text = text
	end
end

-- ===================== ANDAR (caminho com desvio de obstáculos) =====================

local nav = { goal = nil, waypoints = nil, index = 1, computedAt = 0, computing = false, lastPos = nil, lastCheck = 0, stuck = 0, detour = nil, detourUntil = 0 }

local function computePath(from, to)
	nav.computing = true
	task.spawn(function()
		-- raio maior: o caminho passa longe de quinas, postes e cercas (menos chance de enroscar)
		local path = PathfindingService:CreatePath({ AgentRadius = 3, AgentHeight = 6, AgentCanJump = true, AgentCanClimb = true, WaypointSpacing = 6 })
		local ok = pcall(function()
			path:ComputeAsync(from, to)
		end)
		if ok and path.Status == Enum.PathStatus.Success then
			nav.waypoints = path:GetWaypoints()
			nav.index = 2
		else
			nav.waypoints = nil
		end
		nav.computedAt = os.clock()
		nav.computing = false
	end)
end

-- anda até goal; devolve a distância horizontal que falta
local function moveTo(humanoid, root, goal)
	local offset = flat(goal - root.Position)
	local distance = offset.Magnitude
	if distance < 3 then
		humanoid:MoveTo(root.Position)
		return distance
	end
	-- longe: anda por trechos de 160 studs
	local sub = goal
	if distance > 220 then
		local point = root.Position + offset.Unit * 160
		sub = Vector3.new(point.X, math.max(World.height(point.X, point.Z), World.SeaLevel) + 3, point.Z)
	end
	if not nav.goal or (nav.goal - sub).Magnitude > 15 or (os.clock() - nav.computedAt > 5 and not nav.computing) then
		nav.goal = sub
		if not nav.computing then
			computePath(root.Position, sub)
		end
	end
	-- desvio em andamento (depois de ficar preso): anda de lado por um instante
	if nav.detour and os.clock() < nav.detourUntil then
		humanoid:MoveTo(nav.detour)
		return distance
	end
	nav.detour = nil
	local waypoint = nav.waypoints and nav.waypoints[nav.index]
	if waypoint then
		if flat(waypoint.Position - root.Position).Magnitude < 4 then
			nav.index += 1
			waypoint = nav.waypoints[nav.index]
		end
	end
	if waypoint then
		if waypoint.Action == Enum.PathWaypointAction.Jump then
			humanoid.Jump = true
		end
		humanoid:MoveTo(waypoint.Position)
	else
		humanoid:MoveTo(sub)
	end
	-- preso? (a cada 1 s, só enquanto ele quer andar). Escada de saída que nunca deixa travado:
	-- 1) pula e recalcula  2) anda de lado  3) volta um pouco  4+) pede ao servidor para tirar dali
	if os.clock() - nav.lastCheck > 3 then
		nav.lastPos = nil -- ficou um tempo sem andar (lutando): começa a medir de novo
	end
	if os.clock() - nav.lastCheck > 1 then
		if nav.lastPos and (root.Position - nav.lastPos).Magnitude < 1.2 then
			nav.stuck += 1
			nav.computedAt = 0
			local side = Vector3.new(-offset.Unit.Z, 0, offset.Unit.X) * (if nav.stuck % 2 == 0 then 1 else -1)
			if nav.stuck == 1 then
				humanoid.Jump = true
			elseif nav.stuck == 2 then
				nav.detour, nav.detourUntil = root.Position + side * 8, os.clock() + 1.2
				humanoid.Jump = true
			elseif nav.stuck == 3 then
				nav.detour, nav.detourUntil = root.Position - offset.Unit * 6 + side * 4, os.clock() + 1.2
			else
				humanoid.Jump = true
				task.spawn(State.request, "autoUnstuck", goal)
				nav.stuck = 1
			end
		else
			nav.stuck = 0
		end
		nav.lastPos = root.Position
		nav.lastCheck = os.clock()
	end
	return distance
end

-- ===================== COMBATE =====================

local function enemyAt(origin, center, range, typeFilter)
	local folder = workspace:FindFirstChild("Inimigos")
	local best, bestDistance = nil, math.huge
	for _, enemyRoot in if folder then folder:GetChildren() else {} do
		local enemyType = enemyRoot:GetAttribute("Type") or ""
		local def = Enemies.Defs[enemyType]
		if enemyRoot:IsA("BasePart") and def and not enemyRoot:GetAttribute("Dead") then
			local wanted = if typeFilter then enemyType == typeFilter else def.behavior ~= "dummy"
			if wanted and (not center or (enemyRoot.Position - center).Magnitude <= range) then
				local distance = (enemyRoot.Position - origin).Magnitude
				if distance < bestDistance then
					best, bestDistance = enemyRoot, distance
				end
			end
		end
	end
	return best, bestDistance
end

-- toma uma poção se tiver e se já passou o tempo mínimo desde a última vez
local function usePotion(id, minInterval)
	local data = State.data
	if not data or (data.consumables[id] or 0) <= 0 then
		return false
	end
	if os.clock() - (potionUsedAt[id] or -1000) < minInterval then
		return false
	end
	potionUsedAt[id] = os.clock()
	State.action("potion", id)
	return true
end

local function fight(humanoid, root, target, distance, options)
	-- trava no alvo até ele morrer (bonecos de treino nunca morrem: não trava neles)
	local targetDef = Enemies.Defs[target:GetAttribute("Type") or ""]
	if targetDef and targetDef.behavior ~= "dummy" then
		lockedTarget = target
	end
	local weaponType = player:GetAttribute("WeaponType")
	local reach = REACH[weaponType or ""] or MELEE_REACH
	local radius = target.Size.X / 2
	if distance > reach + radius then
		local direction = flat(root.Position - target.Position)
		local stop = if direction.Magnitude > 0.1 then target.Position + direction.Unit * (radius + reach * 0.6) else target.Position
		moveTo(humanoid, root, Vector3.new(stop.X, root.Position.Y, stop.Z))
		return
	end
	humanoid:MoveTo(root.Position)
	local now = os.clock()
	if now < guardUntil then
		return -- aparando ou esquivando agora
	end
	-- habilidades: usa a próxima liberada que já saiu da recarga (e só com mana sobrando)
	local abilities = State.data and State.data.abilities
	local mana, maxMana = player:GetAttribute("Mana") or 0, player:GetAttribute("MaxMana") or 1
	if abilities and not (options and options.noAbilities) and now - lastAbility > 0.7 and mana / math.max(maxMana, 1) > 0.1 then
		for _ = 1, 4 do
			local slot = abilitySlot
			abilitySlot = abilitySlot % 4 + 1
			local ability = abilities[slot]
			if ability and ability.unlocked and now >= (abilityReadyAt[slot] or 0) then
				lastAbility = now
				abilityReadyAt[slot] = now + (ability.cooldown or 5) + 0.3
				Controller.autoAimPoint = target.Position
				local aim, point = Controller.getAim()
				Controller.autoAimPoint = nil
				State.action("ability", slot, aim, point)
				break
			end
		end
	end
	-- chefe ou Elite: elixir de força e tônico de pedra (se tiver)
	if targetDef and (targetDef.behavior == "boss" or target:GetAttribute("Elite")) then
		usePotion("elixir_forca", 60)
		usePotion("tonico_pedra", 90)
	end
	-- esquiva de vez em quando (também conta para missões de esquiva)
	if options and options.dodge and now - lastDodge > 4 then
		lastDodge = now
		State.action("dodge")
	end
	if not Controller.isAttacking() then
		Controller.autoAttack(target.Position)
	end
end

-- ===================== ROTINA (resgates, equipamento, bolsa) =====================

local function chores()
	local data = State.data
	if not data then
		return
	end
	local progress = data.progress
	if progress and progress.login and progress.login.canClaim then
		State.request("claimLogin")
	end
	if progress and progress.pass then
		local pass = progress.pass
		if pass.tier > pass.claimed or (pass.premium and pass.tier > (pass.claimedPremium or 0)) then
			State.request("claimPass")
		end
	end
	-- equipa o item mais forte de cada espaço (sem trocar exóticos nem itens do mesmo nível de poder)
	local best, current = {}, {}
	for _, item in data.inventory or {} do
		if item.slot then
			if item.equipped then
				current[item.slot] = item
			end
			local candidate = best[item.slot]
			local usable = item.slot ~= "weapon" or item.weaponType == player:GetAttribute("WeaponType") or not player:GetAttribute("WeaponType")
			if usable and not item.exotic and (not candidate or item.power > candidate.power) then
				best[item.slot] = item
			end
		end
	end
	for slot, item in best do
		local equipped = current[slot]
		if not item.equipped and (not equipped or (not equipped.exotic and item.power > equipped.power * 1.05)) then
			State.request("equip", item.uid)
		end
	end
	-- bolsa cheia: vende Comuns e Incomuns
	if #(data.inventory or {}) >= Config.MaxInventory - 5 then
		State.request("sellJunk")
	end
end

-- ===================== MISSÕES =====================

local function npcPosition(npcId)
	local npc = NPCs.ById[npcId]
	if not npc or not npc.x then
		return nil
	end
	return Vector3.new(npc.x, World.height(npc.x, npc.z), npc.z)
end

local function automatable(def)
	if def.daily then
		return false
	end
	for _, objective in def.objectives do
		if not AUTO_OBJECTIVES[objective.type] then
			return false
		end
	end
	return true
end

-- ===== ordem das missões (uma por vez, em sequência lógica) =====
-- 1) história principal; 2) cadeias das regiões, da que pede menos nível para a que pede mais;
-- 3) secundárias; dentro de cada grupo, na ordem em que aparecem no jogo (Quests.List)
local QUEST_INDEX = {}
for index, def in Quests.List do
	QUEST_INDEX[def.id] = index
end

local function chainRank(def)
	if def.chain == "main" then
		return 0
	elseif def.chain and def.chain ~= "lenda" then
		return 1
	end
	return 2
end

-- a cadeia de região começa na missão com nível exigido; as seguintes herdam (ficam juntas)
local CHAIN_LEVEL = {}
for _, def in Quests.List do
	if def.chain and def.chain ~= "main" and not CHAIN_LEVEL[def.chain] then
		CHAIN_LEVEL[def.chain] = def.requires and def.requires.level or 0
	end
end

local function questOrder(a, b)
	local ra, rb = chainRank(a), chainRank(b)
	if ra ~= rb then
		return ra < rb
	end
	local la = if a.chain then CHAIN_LEVEL[a.chain] or 0 else (a.requires and a.requires.level or 0)
	local lb = if b.chain then CHAIN_LEVEL[b.chain] or 0 else (b.requires and b.requires.level or 0)
	if ra > 0 and la ~= lb then
		return la < lb
	end
	return (QUEST_INDEX[a.id] or 9999) < (QUEST_INDEX[b.id] or 9999)
end

local function activeEntries(data)
	local list = {}
	for _, entry in data.quests and data.quests.active or {} do
		local def = Quests.ById[entry.id]
		if def then
			table.insert(list, { def = def, entry = entry })
		end
	end
	table.sort(list, function(a, b)
		return questOrder(a.def, b.def)
	end)
	return list
end

-- rastreia (feixe e painel) a missão que o Auto está fazendo
local lastTrack = 0
local function focus(data, def)
	if data.quests.tracked ~= def.id and os.clock() - lastTrack > 3 then
		lastTrack = os.clock()
		task.spawn(State.request, "trackQuest", def.id)
	end
end

-- primeiro objetivo que ainda falta (e se ele é automático)
local function nextObjective(def, entry)
	for i, objective in def.objectives do
		local progress = entry.objectives[i]
		if progress and progress.progress < progress.amount then
			return objective, i
		end
	end
	return nil
end

-- próxima missão para aceitar na sequência (só as que dá para fazer sozinho)
local function questToAccept(data)
	local count = #(data.quests and data.quests.active or {})
	if count >= Config.MaxActiveQuests then
		return nil
	end
	local best = nil
	for npcId, ids in data.quests and data.quests.available or {} do
		for _, qid in ids do
			local def = Quests.ById[qid]
			if def and automatable(def) and NPCs.ById[npcId] and NPCs.ById[npcId].x then
				if not best or questOrder(def, best.def) then
					best = { def = def, npc = npcId }
				end
			end
		end
	end
	return best
end

-- acampamento bom para subir de nível (inimigo mais forte que ainda dá para enfrentar)
local function grindCamp(level, from)
	local best, bestScore = nil, -math.huge
	for _, camp in Enemies.Camps do
		if not camp.town then
			for enemyId in camp.spawns do
				local def = Enemies.Defs[enemyId]
				if def and def.behavior ~= "boss" and def.behavior ~= "dummy" and def.level <= level + 1 then
					local position = Vector3.new(camp.center.X, World.height(camp.center.X, camp.center.Y), camp.center.Y)
					local score = def.level * 100 - (position - from).Magnitude * 0.05
					if score > bestScore then
						best, bestScore = { position = position, enemy = enemyId }, score
					end
				end
			end
		end
	end
	return best
end

-- prompt perto (segredos de locais, coleta)
local function promptNear(position, radius, name)
	local best, bestDistance = nil, math.huge
	for _, part in workspace:GetPartBoundsInRadius(position, radius) do
		for _, child in part:GetChildren() do
			if child:IsA("ProximityPrompt") and child.Enabled and (name == nil or child.Name == name) then
				local distance = (part.Position - position).Magnitude
				if distance < bestDistance then
					best, bestDistance = child, distance
				end
			end
		end
	end
	return best
end

local function triggerPrompt(prompt)
	if os.clock() - lastPromptAt < (prompt.HoldDuration + 0.6) then
		return
	end
	lastPromptAt = os.clock()
	pcall(function()
		prompt:InputHoldBegin()
	end)
	task.delay(prompt.HoldDuration + 0.05, function()
		pcall(function()
			prompt:InputHoldEnd()
		end)
	end)
end

-- viagem rápida: pedra de viagem descoberta bem mais perto do destino
local function maybeTravel(root, goal)
	local data = State.data
	if not data or os.clock() - lastTravel < 25 then
		return false
	end
	local distance = flat(goal - root.Position).Magnitude
	if distance < TRAVEL_MIN then
		return false
	end
	local best, bestDistance = nil, distance - 400
	for _, stone in World.Waystones do
		if data.discovered and data.discovered[stone.id] then
			local d = flat(Vector3.new(stone.x, 0, stone.z) - goal).Magnitude
			if d < bestDistance then
				best, bestDistance = stone, d
			end
		end
	end
	if best then
		lastTravel = os.clock()
		local result = State.request("travel", best.id)
		return result ~= nil and result.ok == true
	end
	return false
end

local function maybeMount(root, goal)
	local data = State.data
	if data and data.mount and not player:GetAttribute("Mounted") and os.clock() - lastMount > 6 and flat(goal - root.Position).Magnitude > 140 then
		lastMount = os.clock()
		State.action("mount")
	end
end

-- vai até um lugar (com viagem e cavalo); true quando chegou
local function travelTo(humanoid, root, goal, near)
	local distance = flat(goal - root.Position).Magnitude
	if distance <= (near or 6) then
		humanoid:MoveTo(root.Position)
		return true
	end
	if maybeTravel(root, goal) then
		return false
	end
	maybeMount(root, goal)
	moveTo(humanoid, root, goal)
	return false
end

-- um passo do modo missões; false = não tinha nada para fazer
local function questStep(humanoid, root)
	local data = State.data
	if not data or not data.quests then
		return false
	end
	-- 1) missão pronta: entregar
	for _, item in activeEntries(data) do
		if item.entry.ready then
			local npcId = item.def.turnIn or item.def.giver
			local position = npcPosition(npcId)
			if position then
				setStatus(("Entregando: %s"):format(item.def.name))
				if travelTo(humanoid, root, position, TALK_RANGE) and os.clock() - lastRequest > 2 then
					lastRequest = os.clock()
					State.request("turnInQuest", item.def.id)
				end
				return true
			end
		end
	end
	-- 2) a história vem antes de tudo: missão principal disponível e nenhuma principal em andamento
	local hasMain = false
	for _, item in activeEntries(data) do
		if item.def.chain == "main" then
			hasMain = true
		end
	end
	if not hasMain then
		local nextQuest = questToAccept(data)
		if nextQuest and nextQuest.def.chain == "main" then
			local position = npcPosition(nextQuest.npc)
			if position then
				setStatus(("História: pegando %s"):format(nextQuest.def.name))
				if travelTo(humanoid, root, position, TALK_RANGE) and os.clock() - lastRequest > 2 then
					lastRequest = os.clock()
					State.request("acceptQuest", nextQuest.def.id)
				end
				return true
			end
		end
	end
	-- 3) objetivo da primeira missão (na ordem) que dá para fazer sozinho
	for _, item in activeEntries(data) do
		local def, entry = item.def, item.entry
		if not automatable(def) then
			continue
		end
		local objective = nextObjective(def, entry)
		if not objective then
			continue
		end
		local kind = objective.type
		focus(data, def)
		setStatus(("%s: %s"):format(def.name, objective.text or kind))
		if kind == "kill" or kind == "hit" then
			local wanted = if objective.target ~= "any" then objective.target else nil
			local target, distance = enemyAt(root.Position, nil, 0, wanted)
			if target and (target.Position - root.Position).Magnitude < QUEST_FIGHT_RANGE then
				fight(humanoid, root, target, distance, { noAbilities = kind == "hit" })
				return true
			end
			local goal = if wanted then WorldMarkers.objectiveTarget(def, entry, root.Position) else nil
			if goal then
				travelTo(humanoid, root, goal, 20)
				return true
			end
			if not wanted then
				local any, anyDistance = enemyAt(root.Position, root.Position, 120, nil)
				if any then
					fight(humanoid, root, any, anyDistance)
					return true
				end
				local camp = grindCamp(data.level or 1, root.Position)
				if camp then
					travelTo(humanoid, root, camp.position, 20)
					return true
				end
			end
		elseif kind == "level" or kind == "mastery" or kind == "dodge" or kind == "ability" or kind == "rhythm" or kind == "finisher" then
			local any, anyDistance = enemyAt(root.Position, root.Position, 120, nil)
			if any then
				fight(humanoid, root, any, anyDistance, { dodge = kind == "dodge" })
				return true
			end
			local camp = grindCamp(data.level or 1, root.Position)
			if camp then
				travelTo(humanoid, root, camp.position, 20)
				return true
			end
		elseif kind == "parry" then
			-- aparar: fica de frente para quem ataca e toca o bloqueio (F) sem parar; o golpe que cair logo
			-- depois de um toque é aparado (janela de Config.ParryWindow)
			local foe, foeDistance = enemyAt(root.Position, root.Position, 60, nil)
			if not foe then
				foe, foeDistance = enemyAt(root.Position, nil, 0, "boneco")
			end
			if foe then
				if foeDistance > 7 then
					moveTo(humanoid, root, foe.Position)
				else
					humanoid:MoveTo(root.Position)
					root.CFrame = CFrame.lookAt(root.Position, Vector3.new(foe.Position.X, root.Position.Y, foe.Position.Z))
					if os.clock() - lastParryTap > 0.32 then
						lastParryTap = os.clock()
						State.action("block", true)
						task.delay(0.18, function()
							State.action("block", false)
						end)
					end
				end
				return true
			end
			local position = npcPosition("kael")
			if position then
				travelTo(humanoid, root, position, 10)
				return true
			end
		elseif kind == "mount" then
			if not player:GetAttribute("Mounted") and os.clock() - lastMount > 4 then
				lastMount = os.clock()
				State.action("mount")
			end
			return true
		elseif kind == "talk" then
			local position = npcPosition(objective.npc)
			if position then
				if travelTo(humanoid, root, position, TALK_RANGE) and os.clock() - lastTalk > 3 then
					lastTalk = os.clock()
					State.action("talk", objective.npc)
				end
				return true
			end
		elseif kind == "gather" or kind == "deliver" then
			local goal = WorldMarkers.objectiveTarget(def, entry, root.Position)
			if goal then
				-- perto de um ponto de coleta: segura o prompt
				local prompt = promptNear(goal, 10, nil)
				if prompt and flat(goal - root.Position).Magnitude < 8 then
					humanoid:MoveTo(root.Position)
					triggerPrompt(prompt)
					return true
				end
				-- é um inimigo que deixa o material: caça perto dele
				local enemy, enemyDistance = enemyAt(root.Position, goal, 60, nil)
				if enemy and (enemy.Position - root.Position).Magnitude < 60 then
					fight(humanoid, root, enemy, enemyDistance)
					return true
				end
				travelTo(humanoid, root, goal, 5)
				return true
			end
			-- nada carregado por perto: anda até a pedra de viagem mais próxima para o mundo aparecer
			local nearest, nearestDistance = nil, math.huge
			for _, stone in World.Waystones do
				local d = flat(Vector3.new(stone.x, 0, stone.z) - root.Position).Magnitude
				if d > 40 and d < nearestDistance then
					nearest, nearestDistance = stone, d
				end
			end
			if nearest then
				travelTo(humanoid, root, Vector3.new(nearest.x, World.height(nearest.x, nearest.z), nearest.z), 10)
				return true
			end
		elseif kind == "explore" or kind == "discover" or kind == "poi" then
			local goal = WorldMarkers.objectiveTarget(def, entry, root.Position)
			if goal then
				travelTo(humanoid, root, goal, 4)
				return true
			end
		elseif kind == "poiSecret" then
			local poi = Points.ById[objective.target]
			if poi then
				local goal = Vector3.new(poi.x, World.height(poi.x, poi.z), poi.z)
				if travelTo(humanoid, root, goal, 25) or flat(goal - root.Position).Magnitude < 90 then
					local prompt = promptNear(root.Position, 90, "SegredoLocal")
					if prompt and prompt.Parent:IsA("BasePart") then
						if travelTo(humanoid, root, prompt.Parent.Position, 6) then
							triggerPrompt(prompt)
						end
					else
						moveTo(humanoid, root, goal)
					end
				end
				return true
			end
		end
	end
	-- 3) nenhuma missão em andamento dá para fazer sozinho: aceita a próxima da sequência
	local nextQuest = questToAccept(data)
	if nextQuest then
		local position = npcPosition(nextQuest.npc)
		if position then
			setStatus(("Pegando missão: %s"):format(nextQuest.def.name))
			if travelTo(humanoid, root, position, TALK_RANGE) and os.clock() - lastRequest > 2 then
				lastRequest = os.clock()
				State.request("acceptQuest", nextQuest.def.id)
			end
			return true
		end
	end
	return false
end

-- ===================== LAÇO =====================

local function step()
	-- nunca roda dentro de masmorra, raide ou arena (o servidor também desliga)
	if player:GetAttribute("Dungeon") or player:GetAttribute("Raid") or player:GetAttribute("Arena") then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return
	end
	anchor = anchor or root.Position
	local data = State.data
	-- saindo de um ataque em área (círculo/linha vermelha): só corre para fora
	if evadeTo and os.clock() < evadeUntil then
		humanoid:MoveTo(evadeTo)
		setStatus("Saindo da área do ataque")
		return
	end
	evadeTo = nil
	-- poções: vida (a grande quando está muito mal), mana e vigor
	local health = humanoid.Health / math.max(humanoid.MaxHealth, 1)
	if health < 0.3 and not usePotion("pocao_grande", 10) then
		usePotion("pocao_vida", 6)
	elseif health < POTION_AT then
		usePotion("pocao_vida", 6)
	end
	if (player:GetAttribute("Mana") or 0) / math.max(player:GetAttribute("MaxMana") or 1, 1) < 0.25 then
		usePotion("pocao_mana", 6)
	end
	if (player:GetAttribute("Stamina") or 0) / math.max(player:GetAttribute("MaxStamina") or 1, 1) < 0.15 then
		usePotion("pocao_vigor", 6)
	end
	-- rotina a cada 15 s
	if os.clock() - lastChores > 15 then
		lastChores = os.clock()
		task.spawn(chores)
	end
	-- 1) termina a luta começada: não larga um inimigo pela metade
	if lockedTarget and (lockedTarget.Parent == nil or lockedTarget:GetAttribute("Dead") or (lockedTarget.Position - root.Position).Magnitude > LOCK_RANGE) then
		lockedTarget = nil
	end
	-- 2) quem está atacando: perto (14), arqueiros/magos (até 45) e, se levou dano há pouco, até 55
	local threatRange = if os.clock() - lastHurt < 5 then 55 else 14
	local threat, threatDistance = enemyAt(root.Position, root.Position, threatRange, nil)
	if not threat then
		local folder = workspace:FindFirstChild("Inimigos")
		local bestDistance = 45
		for _, enemyRoot in if folder then folder:GetChildren() else {} do
			local def = Enemies.Defs[enemyRoot:GetAttribute("Type") or ""]
			if def and def.behavior == "ranged" and enemyRoot:IsA("BasePart") and not enemyRoot:GetAttribute("Dead") then
				local distance = (enemyRoot.Position - root.Position).Magnitude
				if distance < bestDistance then
					threat, threatDistance, bestDistance = enemyRoot, distance, distance
				end
			end
		end
	end
	if lockedTarget and not threat then
		threat, threatDistance = lockedTarget, (lockedTarget.Position - root.Position).Magnitude
	end
	if threat then
		lockedTarget = threat
		setStatus("Lutando")
		fight(humanoid, root, threat, threatDistance)
		return
	end
	if questStep(humanoid, root) then
		return
	end
	-- caça livre em volta do ponto de partida
	setStatus("Caçando por perto")
	local target, distance = enemyAt(root.Position, anchor, RANGE, nil)
	if not target then
		if flat(root.Position - anchor).Magnitude > 8 then
			moveTo(humanoid, root, anchor)
		end
		return
	end
	lockedTarget = target
	fight(humanoid, root, target, distance)
end

-- ===================== DEFESA AUTOMÁTICA =====================
-- Aparar: os golpes normais dos inimigos têm preparo ("windup": 0,5 s; chefes 0,65; boneco 0,9). O Auto
-- segura a guarda pouco antes do golpe cair (descontando o ping), dentro da janela de aparar.
-- Esquivar: ataques em área (círculo/linha vermelha no chão) não dá para bloquear: o Auto corre para fora
-- e, se ainda estiver dentro no fim, esquiva no último instante (esquiva perfeita).
local function myRoot()
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function ping()
	local ok, value = pcall(function()
		return player:GetNetworkPing()
	end)
	return if ok and type(value) == "number" then math.clamp(value, 0, 0.3) else 0.08
end

local function onEnemyAction(enemyRoot)
	if not AutoHunt.isOn() or player:GetAttribute("Dungeon") or player:GetAttribute("Raid") or player:GetAttribute("Arena") then
		return
	end
	local action = tostring(enemyRoot:GetAttribute("Action") or "")
	if string.sub(action, 1, 7) ~= "windup:" then
		return
	end
	local root = myRoot()
	local def = Enemies.Defs[enemyRoot:GetAttribute("Type") or ""]
	if not root or not def then
		return
	end
	local reach = (def.attackRange or 6) + (def.radius or 2) + 5
	if def.behavior ~= "ranged" and (enemyRoot.Position - root.Position).Magnitude > reach then
		return -- longe demais para o golpe acertar
	end
	if def.behavior == "ranged" and (enemyRoot.Position - root.Position).Magnitude > 60 then
		return
	end
	local windup = if def.behavior == "dummy" then 0.9 elseif def.behavior == "boss" then 0.65 else 0.5
	local delay = math.max(0, windup - 0.16 - 2 * ping())
	guardUntil = os.clock() + delay + 0.6
	task.delay(delay, function()
		local r = myRoot()
		if not r or not AutoHunt.isOn() or enemyRoot.Parent == nil then
			return
		end
		-- de frente para quem ataca (a guarda só vale de frente)
		r.CFrame = CFrame.lookAt(r.Position, Vector3.new(enemyRoot.Position.X, r.Position.Y, enemyRoot.Position.Z))
		Controller.autoBlock(true)
		task.delay(0.45, function()
			Controller.autoBlock(false)
		end)
	end)
end

local function onTelegraph(shape, position, size, duration, direction)
	if not AutoHunt.isOn() or typeof(position) ~= "Vector3" then
		return
	end
	local root = myRoot()
	if not root then
		return
	end
	local away
	if shape == "circle" and type(size) == "number" then
		local offset = flat(root.Position - position)
		if offset.Magnitude > size + 2 then
			return -- fora do círculo
		end
		away = if offset.Magnitude > 0.1 then offset.Unit else Vector3.new(1, 0, 0)
		evadeTo = position + away * (size + 6)
	elseif shape == "line" and typeof(size) == "Vector3" then
		local dir = if typeof(direction) == "Vector3" and direction.Magnitude > 0 then flat(direction).Unit else Vector3.new(0, 0, -1)
		local offset = flat(root.Position - position)
		local along = offset:Dot(dir)
		local side = Vector3.new(-dir.Z, 0, dir.X)
		local across = offset:Dot(side)
		if along < -2 or along > size.Z + 2 or math.abs(across) > size.X / 2 + 2 then
			return -- fora da linha
		end
		away = side * (if across >= 0 then 1 else -1)
		evadeTo = root.Position + away * (size.X / 2 + 7)
	else
		return
	end
	evadeTo = Vector3.new(evadeTo.X, root.Position.Y, evadeTo.Z)
	evadeUntil = os.clock() + math.max(0.3, (tonumber(duration) or 1) - 0.1)
	-- se no fim ainda estiver dentro: esquiva perfeita no último instante
	local delay = math.max(0, (tonumber(duration) or 1) - 0.12 - 2 * ping())
	task.delay(delay, function()
		local r = myRoot()
		if not r or not AutoHunt.isOn() then
			return
		end
		local stillInside = if shape == "circle" then flat(r.Position - position).Magnitude <= size + 1 else true
		if stillInside then
			Controller.autoDodge(away)
		end
	end)
end

-- dano recebido: o Auto passa a procurar quem está atacando mais longe
local function watchCharacter(character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then
		return
	end
	local last = humanoid.Health
	humanoid.HealthChanged:Connect(function(health)
		if health < last then
			lastHurt = os.clock()
		end
		last = health
	end)
end

function AutoHunt.init(screen)
	-- defesa automática: avisos de golpe dos inimigos e áreas vermelhas
	task.spawn(function()
		local folder = workspace:WaitForChild("Inimigos", 60)
		if not folder then
			return
		end
		local function watch(enemyRoot)
			enemyRoot:GetAttributeChangedSignal("Action"):Connect(function()
				onEnemyAction(enemyRoot)
			end)
		end
		for _, child in folder:GetChildren() do
			watch(child)
		end
		folder.ChildAdded:Connect(watch)
	end)
	Remotes.Fx.OnClientEvent:Connect(function(kind, ...)
		if kind == "telegraph" then
			onTelegraph(...)
		end
	end)
	if player.Character then
		task.spawn(watchCharacter, player.Character)
	end
	player.CharacterAdded:Connect(function(character)
		lockedTarget = nil
		watchCharacter(character)
	end)
	banner = UI.new("Frame", {
		Name = "AutoCacar",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 100),
		Size = UDim2.fromOffset(420, 50),
		BackgroundColor3 = UI.Colors.Panel,
		BackgroundTransparency = 0.15,
		Visible = false,
		Parent = screen,
	}, { UI.corner(10) })
	UI.ornate(banner, UI.Colors.Trim, 3)
	UI.label({ Text = "AUTO (VIP): missões, caça e coleta sozinho  •  mova-se ou N para parar", Size = UDim2.new(1, -16, 0, 22), Position = UDim2.fromOffset(8, 3), TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = UI.Colors.Gold, Parent = banner }, { UI.textStroke(1) })
	statusLabel = UI.label({ Text = "", Size = UDim2.new(1, -16, 0, 18), Position = UDim2.fromOffset(8, 26), TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = UI.Colors.SubText, Parent = banner }, { UI.textStroke(1) })

	local function refreshAnchor()
		local on = AutoHunt.isOn()
		banner.Visible = on
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		-- o ponto de caça vem do servidor (sobrevive a morte e ao reconectar)
		local serverAnchor = player:GetAttribute("AutoAnchor")
		anchor = if not on then nil elseif typeof(serverAnchor) == "Vector3" then serverAnchor elseif root then root.Position else nil
	end
	player:GetAttributeChangedSignal("AutoAnchor"):Connect(refreshAnchor)
	player:GetAttributeChangedSignal("AutoFarm"):Connect(function()
		refreshAnchor()
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not AutoHunt.isOn() then
			nav.waypoints, nav.goal = nil, nil
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if humanoid and root then
				humanoid:MoveTo(root.Position)
			end
		end
	end)
	-- mexer o personagem desliga
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.N then
			AutoHunt.toggle()
		elseif AutoHunt.isOn() and (MOVE_KEYS[input.KeyCode] or input.KeyCode == Enum.KeyCode.Thumbstick1) then
			State.request("autoFarm", false)
		end
	end)
	refreshAnchor()
	-- 100% AFK: o Roblox desconecta depois de 20 min sem mexer no teclado/mouse. Antes disso o jogo
	-- reconecta no mesmo servidor e o Auto volta ligado no mesmo ponto.
	player.Idled:Connect(function(idleSeconds)
		if AutoHunt.isOn() and idleSeconds >= 16 * 60 then
			Popups.message("Modo AFK: reconectando para não ser desconectado...", UI.Colors.Gold)
			State.request("afkRejoin")
		end
	end)
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		if not AutoHunt.isOn() then
			return
		end
		accumulator += dt
		if accumulator < 0.15 then
			return
		end
		accumulator = 0
		local ok, err = pcall(step)
		if not ok then
			warn("[Auto]", err)
		end
	end)
end

return AutoHunt
