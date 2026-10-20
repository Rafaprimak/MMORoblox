-- Desenha e anima os inimigos no cliente a partir das "raízes" que o servidor move.
-- Movimento suavizado, pernas/braços balançando, preparo de ataque visível, barra de vida e queda ao morrer.
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enemies = require(Shared.Enemies)
local EnemyModels = require(Shared.EnemyModels)

local UI = require(script.Parent.UI)

local EnemyRenderer = {}

local records = {}
local visuals = Instance.new("Folder")
visuals.Name = "InimigosVisuais"
visuals.Parent = workspace

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
groundParams.FilterDescendantsInstances = { workspace.Terrain }

local WHITE = Color3.new(1, 1, 1)
local CULL_DISTANCE = 320

local function R(x, y, z)
	return CFrame.Angles(x or 0, y or 0, z or 0)
end

local function rotateAround(joint, rotation)
	return CFrame.new(joint) * rotation * CFrame.new(-joint)
end

local function createHealthGui(rec)
	local def = rec.def
	local boss = def.boss
	local anchor = Instance.new("Part")
	anchor.Name = "Topo"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Parent = rec.model
	local gui = UI.new("BillboardGui", {
		Size = if boss then UDim2.fromOffset(300, 62) else UDim2.fromOffset(150, 44),
		StudsOffset = Vector3.new(0, 1.4, 0),
		MaxDistance = if boss then 260 else 85,
		LightInfluence = 0,
		AlwaysOnTop = false,
		Adornee = anchor,
		Parent = anchor,
	})
	local nameColor = if boss then Color3.fromRGB(255, 90, 70) elseif rec.elite then UI.Colors.Gold else WHITE
	local level = rec.root:GetAttribute("Level") or def.level
	rec.nameLabel = UI.label({
		Text = ("%s%s  Nv.%d"):format(if rec.elite then "★ Elite " else "", def.name, level),
		Size = UDim2.fromScale(1, 0.44),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = nameColor,
		Font = Enum.Font.GothamBlack,
		Parent = gui,
	}, { UI.textStroke(1.5) })
	local back = UI.new("Frame", { Position = UDim2.fromScale(0.05, 0.5), Size = UDim2.fromScale(0.9, 0.28), BackgroundColor3 = Color3.fromRGB(20, 20, 25), Parent = gui }, { UI.corner(4), UI.stroke(Color3.new(0, 0, 0), 1) })
	-- barra de postura (guarda): enche com os golpes; cheia = guarda quebrada
	local postureBack = UI.new("Frame", { Position = UDim2.fromScale(0.15, 0.82), Size = UDim2.fromScale(0.7, 0.13), BackgroundColor3 = Color3.fromRGB(20, 20, 25), BackgroundTransparency = 0.2, Parent = gui }, { UI.corner(3) })
	rec.postureFill = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.fromRGB(255, 200, 50), Parent = postureBack }, { UI.corner(3) })
	rec.postureBack = postureBack
	-- aviso de golpe: ❗ amarelo = dá para aparar (F) • ‼ vermelho = só esquivar (Q)
	local warnGui = UI.new("BillboardGui", { Size = UDim2.fromOffset(60, 60), StudsOffset = Vector3.new(0, 4.2, 0), MaxDistance = 120, AlwaysOnTop = true, LightInfluence = 0, Enabled = false, Adornee = anchor, Parent = anchor })
	rec.warnLabel = UI.label({ Text = "!", Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, Font = Enum.Font.GothamBlack, TextColor3 = Color3.fromRGB(255, 220, 60), Parent = warnGui }, { UI.textStroke(3) })
	rec.warnGui = warnGui
	local trail = UI.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 230, 150), Parent = back }, { UI.corner(4) })
	local fill = UI.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(225, 55, 55), ZIndex = 2, Parent = back }, { UI.corner(4) })
	rec.anchor = anchor
	rec.hpFill = fill
	rec.hpTrail = trail
	rec.gui = gui
end

local function updatePosture(rec)
	local posture = rec.root:GetAttribute("Posture") or 0
	local maxPosture = rec.root:GetAttribute("MaxPosture") or 1
	local staggered = rec.root:GetAttribute("Staggered") == true
	local ratio = if staggered then 1 else math.clamp(posture / maxPosture, 0, 1)
	TweenService:Create(rec.postureFill, TweenInfo.new(0.15), { Size = UDim2.fromScale(ratio, 1) }):Play()
	rec.postureFill.BackgroundColor3 = if staggered then Color3.fromRGB(255, 120, 40) elseif ratio > 0.75 then Color3.fromRGB(255, 160, 40) else Color3.fromRGB(255, 200, 50)
	rec.postureBack.Visible = staggered or ratio > 0.01
	rec.staggered = staggered
end

local function updateHealth(rec)
	local hp = rec.root:GetAttribute("Hp") or 0
	local maxHp = rec.root:GetAttribute("MaxHp") or 1
	local ratio = math.clamp(hp / maxHp, 0, 1)
	rec.hpFill.Size = UDim2.fromScale(ratio, 1)
	TweenService:Create(rec.hpTrail, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = UDim2.fromScale(ratio, 1) }):Play()
	rec.ratio = ratio
end

local function applyColors(rec, override, tint, amount)
	for _, entry in rec.parts do
		if override then
			entry.part.Color = override
		elseif tint then
			entry.part.Color = entry.color:Lerp(tint, amount)
		else
			entry.part.Color = entry.color
		end
	end
end

local function refreshTint(rec)
	local dot = rec.root:GetAttribute("Dot")
	if dot == "poison" then
		applyColors(rec, nil, Color3.fromRGB(110, 230, 80), 0.35)
	elseif dot == "burn" then
		applyColors(rec, nil, Color3.fromRGB(255, 120, 40), 0.35)
	else
		applyColors(rec)
	end
end

local function showWarning(rec, text, color, duration)
	rec.warnToken = (rec.warnToken or 0) + 1
	local token = rec.warnToken
	rec.warnLabel.Text = text
	rec.warnLabel.TextColor3 = color
	rec.warnGui.Enabled = true
	local scale = rec.warnLabel:FindFirstChildOfClass("UIScale") or UI.new("UIScale", { Parent = rec.warnLabel })
	scale.Scale = 1.6
	TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(duration, function()
		if rec.warnToken == token then
			rec.warnGui.Enabled = false
		end
	end)
end

local function onAction(rec)
	local value = rec.root:GetAttribute("Action") or "idle:0"
	local action = string.match(value, "^(%a+)") or "idle"
	rec.action = action
	rec.actionStart = os.clock()
	if action == "windup" then
		showWarning(rec, "!", Color3.fromRGB(255, 220, 60), if rec.def.behavior == "dummy" then 0.95 else 0.6)
	elseif action == "chargeWindup" or action == "slamWindup" then
		showWarning(rec, "‼", Color3.fromRGB(255, 60, 50), 1.3)
	elseif action == "attack" or action == "stun" or action == "stagger" or action == "idle" then
		rec.warnGui.Enabled = false
	end
end

local function track(root)
	if records[root] then
		return
	end
	local enemyId = root:GetAttribute("Type")
	local def = enemyId and Enemies.Defs[enemyId]
	if not def then
		return
	end
	local elite = root:GetAttribute("Elite") == true
	local built = EnemyModels.build(def, elite)
	local rec = {
		root = root,
		def = def,
		elite = elite,
		model = built.model,
		parts = built.parts,
		height = built.height,
		scale = built.scale,
		phase = math.random() * 10,
		speed = 0,
		action = "idle",
		actionStart = 0,
		flashUntil = 0,
		groundOffset = 0,
		nextGroundCheck = 0,
		visual = root.CFrame * CFrame.new(0, -built.height / 2, 0),
		lastPos = root.Position,
		ratio = 1,
	}
	for _, entry in rec.parts do
		entry.part.CanQuery = true -- para a mira do mouse
	end
	createHealthGui(rec)
	if elite then
		local glow = Instance.new("PointLight")
		glow.Color = UI.Colors.Gold
		glow.Range = 10
		glow.Brightness = 1.5
		glow.Parent = rec.parts[1].part
	end
	rec.bulkParts = {}
	for i, entry in rec.parts do
		rec.bulkParts[i] = entry.part
	end
	table.insert(rec.bulkParts, rec.anchor)
	rec.model.Parent = visuals
	records[root] = rec
	updateHealth(rec)
	updatePosture(rec)
	onAction(rec)
	rec.connections = {
		root:GetAttributeChangedSignal("Hp"):Connect(function()
			updateHealth(rec)
		end),
		root:GetAttributeChangedSignal("Action"):Connect(function()
			onAction(rec)
		end),
		root:GetAttributeChangedSignal("Posture"):Connect(function()
			updatePosture(rec)
		end),
		root:GetAttributeChangedSignal("Staggered"):Connect(function()
			updatePosture(rec)
		end),
		root:GetAttributeChangedSignal("Dot"):Connect(function()
			refreshTint(rec)
		end),
	}
end

local function untrack(root)
	local rec = records[root]
	if not rec then
		return
	end
	records[root] = nil
	for _, connection in rec.connections do
		connection:Disconnect()
	end
	if root:GetAttribute("Dead") or (rec.ratio or 1) <= 0.001 then
		-- desmonta o corpo: as peças caem e somem
		if rec.gui then
			rec.gui:Destroy()
		end
		for _, entry in rec.parts do
			local p = entry.part
			p.Anchored = false
			p.CanCollide = true
			p.CanQuery = false
			p.AssemblyLinearVelocity = Vector3.new(math.random(-12, 12), math.random(10, 22), math.random(-12, 12))
			p.AssemblyAngularVelocity = Vector3.new(math.random(-8, 8), math.random(-8, 8), math.random(-8, 8))
			task.delay(0.9, function()
				TweenService:Create(p, TweenInfo.new(0.6), { Transparency = 1 }):Play()
			end)
		end
		Debris:AddItem(rec.model, 1.6)
	else
		rec.model:Destroy()
	end
end

function EnemyRenderer.flash(root)
	local rec = records[root]
	if not rec then
		return
	end
	rec.flashUntil = os.clock() + 0.08
	applyColors(rec, WHITE)
	rec.hitKick = os.clock()
end

function EnemyRenderer.get(root)
	return records[root]
end

function EnemyRenderer.topPosition(root)
	local rec = records[root]
	if rec then
		return rec.visual.Position + Vector3.new(0, rec.height + 0.5, 0)
	end
	return root.Position + Vector3.new(0, root.Size.Y / 2 + 0.5, 0)
end

-- Chefe mais próximo (para a barra de chefe no topo da tela)
function EnemyRenderer.nearestBoss(position, range)
	for _, rec in records do
		if rec.def.boss and (rec.visual.Position - position).Magnitude < range then
			return rec
		end
	end
	return nil
end

-- Deslocamento de cada parte conforme o papel (pernas, braços...) e a ação atual
local function partOffset(rec, entry, moving, actionT, now)
	local role = entry.role
	local joint = entry.joint
	local swing = math.sin(rec.phase) * 0.65 * moving
	local action = rec.action
	if not joint then
		return CFrame.identity
	end
	if role == "legL" or role == "legFL" or role == "legBR" then
		return rotateAround(joint, R(swing, 0, 0))
	elseif role == "legR" or role == "legFR" or role == "legBL" then
		return rotateAround(joint, R(-swing, 0, 0))
	elseif role == "legA" then
		return rotateAround(joint, R(0, swing * 0.5, math.abs(swing) * 0.3))
	elseif role == "legB" then
		return rotateAround(joint, R(0, -swing * 0.5, -math.abs(swing) * 0.3))
	elseif role == "tail" then
		return rotateAround(joint, R(0, math.sin(now * 9) * 0.5, 0))
	elseif role == "head" then
		if action == "roar" and actionT < 1 then
			return rotateAround(joint, R(-0.5 * math.sin(actionT * math.pi), 0, 0))
		end
		return rotateAround(joint, R(math.sin(now * 2 + rec.phase) * 0.05, math.sin(now * 0.7 + rec.phase) * 0.15, 0))
	elseif role == "armR" or role == "armL" then
		local side = if role == "armR" then 1 else -1
		local base = -swing * 0.6 * side
		if (action == "windup" or action == "slamWindup") and actionT < 3 then
			return rotateAround(joint, R(-2.4 * math.min(actionT * 2.5, 1), 0, 0))
		elseif action == "attack" or action == "slam" then
			local t = math.clamp(actionT, 0, 1)
			return rotateAround(joint, R(-2.4 + 3.2 * math.min(t * 4, 1), 0, 0))
		elseif action == "shoot" and actionT < 1 then
			return rotateAround(joint, R(-1.5, 0, 0))
		elseif action == "roar" and actionT < 1.2 then
			return rotateAround(joint, R(-2.6, 0, side * 0.5))
		end
		return rotateAround(joint, R(base, 0, 0))
	end
	return CFrame.identity
end

function EnemyRenderer.init()
	local folder = workspace:WaitForChild("Inimigos")
	for _, root in folder:GetChildren() do
		task.spawn(track, root)
	end
	folder.ChildAdded:Connect(function(root)
		task.defer(track, root)
	end)
	folder.ChildRemoved:Connect(untrack)

	RunService.RenderStepped:Connect(function(dt)
		local camera = workspace.CurrentCamera
		local cameraPos = camera.CFrame.Position
		local now = os.clock()
		local alpha = 1 - math.exp(-12 * dt)
		local allParts, allCFrames = {}, {}
		for root, rec in records do
			if not root.Parent then
				continue
			end
			local target = root.CFrame * CFrame.new(0, -rec.height / 2, 0)
			local distance = (target.Position - cameraPos).Magnitude
			if distance > CULL_DISTANCE then
				if rec.model.Parent then
					rec.model.Parent = nil
				end
				rec.visual = target
				continue
			elseif not rec.model.Parent then
				rec.model.Parent = visuals
			end

			rec.visual = rec.visual:Lerp(target, alpha)
			local position = rec.visual.Position
			local moved = (Vector3.new(position.X, 0, position.Z) - Vector3.new(rec.lastPos.X, 0, rec.lastPos.Z)).Magnitude
			rec.lastPos = position
			rec.speed = rec.speed + ((moved / math.max(dt, 0.001)) - rec.speed) * math.min(1, dt * 10)
			local moving = math.clamp(rec.speed / 6, 0, 1)
			rec.phase += dt * (4 + rec.speed * 0.6)

			-- encaixa os pés no terreno de verdade (raycast de vez em quando)
			if now >= rec.nextGroundCheck then
				rec.nextGroundCheck = now + 0.25
				local result = workspace:Raycast(position + Vector3.new(0, 12, 0), Vector3.new(0, -40, 0), groundParams)
				if result then
					rec.targetGroundOffset = math.clamp(result.Position.Y - position.Y, -3, 3)
				end
			end
			rec.groundOffset += ((rec.targetGroundOffset or 0) - rec.groundOffset) * math.min(1, dt * 8)

			if rec.flashUntil > 0 and now > rec.flashUntil then
				rec.flashUntil = 0
				refreshTint(rec)
			end

			-- postura geral conforme a ação
			local actionT = now - rec.actionStart
			local pose = CFrame.identity
			local bob = math.abs(math.sin(rec.phase)) * 0.18 * moving * rec.scale
			local action = rec.action
			if rec.def.model == "slime" then
				bob = math.abs(math.sin(now * 6 + rec.phase)) * (0.25 + moving * 0.8) * rec.scale
			end
			if action == "windup" and actionT < 2 then
				pose = R(0.25 * math.min(actionT * 3, 1), 0, 0)
			elseif action == "attack" and actionT < 0.4 then
				local k = math.sin(actionT / 0.4 * math.pi)
				pose = CFrame.new(0, 0, -1.2 * k * rec.scale) * R(-0.35 * k, 0, 0)
			elseif action == "chargeWindup" and actionT < 3 then
				pose = CFrame.new(0, -0.3 * rec.scale, 0) * R(-0.25, 0, math.sin(now * 30) * 0.05)
			elseif action == "charge" and actionT < 2 then
				pose = R(-0.3, 0, 0)
			elseif action == "slamWindup" and actionT < 3 then
				pose = CFrame.new(0, 0.8 * math.min(actionT * 2, 1) * rec.scale, 0) * R(0.2, 0, 0)
			elseif action == "slam" and actionT < 0.5 then
				pose = R(-0.35 * math.sin(actionT / 0.5 * math.pi), 0, 0)
			elseif action == "stagger" and rec.staggered then
				-- guarda quebrada: cambaleia bastante
				pose = CFrame.new(0, -0.25 * rec.scale, 0) * R(0.25 + math.sin(now * 6) * 0.08, 0, math.sin(now * 9) * 0.18)
			elseif action == "stun" and actionT < 3 then
				pose = R(0, 0, math.sin(now * 14) * 0.12)
			end
			if rec.hitKick and now - rec.hitKick < 0.15 then
				local k = 1 - (now - rec.hitKick) / 0.15
				pose *= CFrame.new(0, 0, 0.35 * k) * R(0.12 * k, 0, 0)
			end
			local pivot = rec.visual * CFrame.new(0, rec.groundOffset + bob, 0) * pose
			for _, entry in rec.parts do
				table.insert(allParts, entry.part)
				table.insert(allCFrames, pivot * partOffset(rec, entry, moving, actionT, now) * entry.base)
			end
			table.insert(allParts, rec.anchor)
			table.insert(allCFrames, rec.visual * CFrame.new(0, rec.height + rec.groundOffset, 0))
		end
		if #allParts > 0 then
			workspace:BulkMoveTo(allParts, allCFrames, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end)
end

return EnemyRenderer
