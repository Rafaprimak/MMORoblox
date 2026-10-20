-- Spawn, IA, dano e morte dos inimigos.
-- Os inimigos são ancorados e movidos por CFrame (simples e sem bugs de física).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Enemies = require(Shared.Enemies)
local Remotes = require(Shared.Remotes)

local EnemyModels = require(script.Parent.EnemyModels)

local EnemyService = {}

-- Preenchido pelo init: function(rec, contributors) onde contributors = { [player] = dano }
EnemyService.OnKilled = nil

local active = {}
local folder = Instance.new("Folder")
folder.Name = "Inimigos"
folder.Parent = workspace

local function flat(vector)
	return Vector3.new(vector.X, 0, vector.Z)
end

local function yawTowards(direction)
	return math.atan2(-direction.X, -direction.Z)
end

local function randomPointInZone(zone)
	local angle = math.random() * math.pi * 2
	local distance = math.sqrt(math.random()) * zone.radius * 0.85
	return Vector3.new(zone.center.X + math.cos(angle) * distance, Config.GroundY, zone.center.Z + math.sin(angle) * distance)
end

local function insideZone(zone, position)
	return flat(position - zone.center).Magnitude <= zone.radius
end

local function createHealthGui(rec)
	local def = rec.def
	local gui = Instance.new("BillboardGui")
	gui.Name = "Vida"
	gui.Size = if def.boss then UDim2.fromOffset(280, 50) else UDim2.fromOffset(130, 32)
	gui.StudsOffset = Vector3.new(0, rec.height / 2 + (if def.boss then 3 else 1.4), 0)
	gui.MaxDistance = if def.boss then 300 else 90
	gui.LightInfluence = 0
	gui.Adornee = rec.root
	gui.Parent = rec.root

	local nameLabel = Instance.new("TextLabel")
	nameLabel.BackgroundTransparency = 1
	nameLabel.Size = UDim2.fromScale(1, 0.52)
	nameLabel.Font = Enum.Font.GothamBlack
	nameLabel.TextScaled = true
	nameLabel.TextColor3 = if def.boss then Color3.fromRGB(255, 200, 60) else Color3.new(1, 1, 1)
	nameLabel.Text = ("%s  Nv.%d"):format(def.name, def.level)
	nameLabel.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1.5
	stroke.Parent = nameLabel

	local back = Instance.new("Frame")
	back.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
	back.BorderSizePixel = 0
	back.Position = UDim2.fromScale(0, 0.6)
	back.Size = UDim2.fromScale(1, 0.36)
	back.Parent = gui
	local backCorner = Instance.new("UICorner")
	backCorner.CornerRadius = UDim.new(0, 4)
	backCorner.Parent = back

	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = Color3.fromRGB(230, 60, 60)
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(1, 1)
	fill.Parent = back
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 4)
	fillCorner.Parent = fill

	rec.fill = fill
end

local function updateHealthBar(rec)
	if rec.fill then
		rec.fill.Size = UDim2.fromScale(math.clamp(rec.hp / rec.maxHp, 0, 1), 1)
	end
end

local function place(rec)
	local y = rec.position.Y + rec.height / 2
	if rec.def.shape == "slime" then
		y += math.abs(math.sin(rec.bounce * 6)) * 0.8 -- pulinho do slime
	end
	rec.model:PivotTo(CFrame.new(rec.position.X, y, rec.position.Z) * CFrame.Angles(0, rec.yaw, 0))
end

local function spawnEnemy(zone, announce)
	local def = Enemies.Defs[zone.enemy]
	local model, height, parts = EnemyModels.build(def)
	local rec = {
		def = def,
		defId = zone.enemy,
		zone = zone,
		model = model,
		root = model.PrimaryPart,
		parts = parts,
		height = height,
		hp = def.hp,
		maxHp = def.hp,
		position = randomPointInZone(zone),
		yaw = math.random() * math.pi * 2,
		bounce = math.random() * 10,
		damageBy = {},
		lastAttack = 0,
		nextSlam = os.clock() + 6,
		dead = false,
	}
	createHealthGui(rec)
	place(rec)
	model.Parent = folder
	table.insert(active, rec)

	if announce and def.boss then
		Remotes.Notify:FireAllClients({ kind = "announce", text = ("👑 O %s renasceu no Covil!"):format(def.name), sub = "Entre no portal roxo para enfrentá-lo" })
	end
	return rec
end

local function flash(rec)
	rec.flashToken = (rec.flashToken or 0) + 1
	local token = rec.flashToken
	for _, entry in rec.parts do
		entry.part.Color = Color3.new(1, 1, 1)
	end
	task.delay(0.07, function()
		if rec.flashToken ~= token or rec.dead then
			return
		end
		for _, entry in rec.parts do
			entry.part.Color = entry.color
		end
	end)
end

local function kill(rec)
	rec.dead = true
	local contributors = {}
	for player, damage in rec.damageBy do
		if player.Parent == Players then
			contributors[player] = damage
		end
	end

	local center = rec.position + Vector3.new(0, rec.height / 2, 0)
	Remotes.Fx:FireAllClients("death", center, rec.def.color, if rec.def.boss then 3 else 1)
	rec.model:Destroy()

	if rec.def.boss then
		Remotes.Notify:FireAllClients({ kind = "announce", text = ("👑 O %s foi derrotado!"):format(rec.def.name), sub = ("Volta em %d segundos"):format(rec.zone.respawn) })
	end

	local zone = rec.zone
	task.delay(zone.respawn, spawnEnemy, zone, true)

	if EnemyService.OnKilled then
		task.spawn(EnemyService.OnKilled, rec, contributors)
	end
end

function EnemyService.damage(rec, amount, player, crit, fromPosition)
	if rec.dead then
		return
	end
	rec.hp -= amount
	rec.damageBy[player] = (rec.damageBy[player] or 0) + amount
	updateHealthBar(rec)
	flash(rec)
	Remotes.Damage:FireClient(player, rec.position + Vector3.new(0, rec.height + 1, 0), amount, crit)

	-- empurrãozinho (não afeta chefes)
	if fromPosition and not rec.def.boss then
		local push = flat(rec.position - fromPosition)
		if push.Magnitude > 0.01 then
			local newPosition = rec.position + push.Unit * (if crit then 2.2 else 1.1)
			if insideZone(rec.zone, newPosition) then
				rec.position = newPosition
			end
		end
	end

	if rec.hp <= 0 then
		kill(rec)
	end
end

-- Inimigos à frente do jogador, do mais perto ao mais longe
function EnemyService.getTargets(origin, lookVector, range, maxTargets)
	local look = flat(lookVector)
	look = if look.Magnitude > 0.01 then look.Unit else Vector3.new(0, 0, -1)
	local found = {}
	for _, rec in active do
		if rec.dead then
			continue
		end
		local offset = rec.position - origin
		local horizontal = flat(offset)
		local distance = horizontal.Magnitude - rec.def.radius
		if distance <= range and math.abs(offset.Y) < 15 then
			local dot = if horizontal.Magnitude > 0.01 then look:Dot(horizontal.Unit) else 1
			if dot > 0.2 or distance < 2 then
				table.insert(found, { rec = rec, distance = distance })
			end
		end
	end
	table.sort(found, function(a, b)
		return a.distance < b.distance
	end)
	local result = {}
	for i = 1, math.min(maxTargets, #found) do
		table.insert(result, found[i].rec)
	end
	return result
end

-- Ataque especial do chefe: círculo vermelho no chão, depois dano em área (dá para desviar!)
local function bossSlam(rec)
	local center = rec.position
	local radius = 16
	local marker = Instance.new("Part")
	marker.Shape = Enum.PartType.Cylinder
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanQuery = false
	marker.CanTouch = false
	marker.Material = Enum.Material.Neon
	marker.Color = Color3.fromRGB(255, 40, 40)
	marker.Transparency = 0.45
	marker.Size = Vector3.new(0.3, 2, 2)
	marker.CFrame = CFrame.new(center.X, Config.GroundY + 0.1, center.Z) * CFrame.Angles(0, 0, math.rad(90))
	marker.Parent = workspace
	TweenService:Create(marker, TweenInfo.new(1.2, Enum.EasingStyle.Linear), { Size = Vector3.new(0.3, radius * 2, radius * 2) }):Play()
	task.wait(1.25)
	marker:Destroy()
	if rec.dead then
		return
	end
	Remotes.Fx:FireAllClients("slam", center, radius)
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and humanoid and humanoid.Health > 0 then
			local offset = root.Position - center
			if flat(offset).Magnitude <= radius and math.abs(offset.Y) < 10 then
				local damage = math.floor(rec.def.damage * 1.8)
				humanoid:TakeDamage(damage)
				Remotes.Fx:FireClient(player, "hurt", damage)
			end
		end
	end
end

local function updateEnemy(rec, dt, now, targets)
	local def, zone = rec.def, rec.zone
	rec.bounce += dt

	-- escolhe o alvo mais próximo dentro do alcance de agressão
	local target, targetDistance = nil, nil
	for _, candidate in targets do
		local offset = candidate.root.Position - rec.position
		local distance = flat(offset).Magnitude
		local aggro = if rec.damageBy[candidate.player] then def.aggro * 2 else def.aggro
		local fromCenter = flat(candidate.root.Position - zone.center).Magnitude
		if distance <= aggro and fromCenter <= zone.radius + 25 and math.abs(offset.Y) < 20 then
			if not targetDistance or distance < targetDistance then
				target, targetDistance = candidate, distance
			end
		end
	end

	local moveDirection, speed = nil, 0
	if target then
		local toTarget = flat(target.root.Position - rec.position)
		if toTarget.Magnitude > 0.05 then
			rec.yaw = yawTowards(toTarget)
		end
		local reach = def.radius + 3.5
		if targetDistance > reach then
			moveDirection = toTarget.Unit
			speed = def.speed
		elseif now - rec.lastAttack >= def.attackCooldown then
			rec.lastAttack = now
			target.humanoid:TakeDamage(def.damage)
			Remotes.Fx:FireClient(target.player, "hurt", def.damage)
		end
		if def.boss and now >= rec.nextSlam then
			rec.nextSlam = now + 8
			task.spawn(bossSlam, rec)
		end
	else
		-- passeia pela zona e regenera vida
		if not rec.wanderGoal or flat(rec.wanderGoal - rec.position).Magnitude < 2 or now > rec.wanderUntil then
			rec.wanderGoal = randomPointInZone(zone)
			rec.wanderUntil = now + 6 + math.random() * 4
			rec.idleUntil = now + math.random() * 3
		end
		if now > (rec.idleUntil or 0) then
			local toGoal = flat(rec.wanderGoal - rec.position)
			if toGoal.Magnitude > 0.5 then
				moveDirection = toGoal.Unit
				speed = def.speed * 0.4
				rec.yaw = yawTowards(toGoal)
			end
		end
		if rec.hp < rec.maxHp then
			rec.hp = math.min(rec.maxHp, rec.hp + rec.maxHp * 0.08 * dt)
			updateHealthBar(rec)
			if rec.hp >= rec.maxHp then
				rec.damageBy = {}
			end
		end
	end

	if moveDirection then
		local newPosition = rec.position + moveDirection * speed * dt
		if insideZone(zone, newPosition) then
			rec.position = newPosition
		end
	end
	place(rec)
end

function EnemyService.start()
	for _, zone in Enemies.Zones do
		for _ = 1, zone.count do
			spawnEnemy(zone, false)
		end
	end

	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		local targets = {}
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if root and humanoid and humanoid.Health > 0 then
				table.insert(targets, { player = player, root = root, humanoid = humanoid })
			end
		end
		for i = #active, 1, -1 do
			local rec = active[i]
			if rec.dead then
				table.remove(active, i)
			else
				updateEnemy(rec, dt, now, targets)
			end
		end
	end)
end

return EnemyService
