-- Inimigos: spawn nos acampamentos, IA, ataques com aviso, status (atordoar, veneno, queimadura).
-- O servidor só move uma "raiz" invisível; o cliente desenha e anima o modelo (movimento suave).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local World = require(Shared.World)
local Enemies = require(Shared.Enemies)
local EnemyModels = require(Shared.EnemyModels)
local Remotes = require(Shared.Remotes)

local PlayerService = require(script.Parent.PlayerService)

local EnemyService = {}

-- Ganchos preenchidos pelo init
EnemyService.OnKilled = nil -- function(rec, contributors)
EnemyService.OnHit = nil -- function(rec, player, amount, info)
EnemyService.FireProjectile = nil -- function(spec) (ProjectileService)
EnemyService.OnStagger = nil -- function(rec, player): guarda quebrada

local TICK = 0.1
local active = {}
local byRoot = {}
local folder = Instance.new("Folder")
folder.Name = "Inimigos"
folder.Parent = workspace

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

local function isNight()
	return workspace:GetAttribute("Night") == true
end

-- multiplicador de dano do inimigo (Elite e noite)
local function damageMult(rec)
	return rec.damageMult * (if isNight() then Config.NightEnemyDamage else 1)
end

local function yawTowards(direction)
	return math.atan2(-direction.X, -direction.Z)
end

local function lookOf(rec)
	return Vector3.new(-math.sin(rec.yaw), 0, -math.cos(rec.yaw))
end

-- altura do chão: no mundo vem do relevo; nas salas de masmorra o acampamento tem piso plano (floorY)
local function groundAt(x, z, camp)
	if camp and camp.floorY then
		return camp.floorY
	end
	return World.height(x, z)
end

-- salas de masmorra têm paredes: o inimigo não sai do retângulo (bounds = { minX, maxX, minZ, maxZ })
local function keepInside(camp, position)
	local bounds = camp and camp.bounds
	if not bounds then
		return position
	end
	return Vector3.new(math.clamp(position.X, bounds[1], bounds[2]), position.Y, math.clamp(position.Z, bounds[3], bounds[4]))
end

local function setAction(rec, action)
	rec.actionCount += 1
	rec.root:SetAttribute("Action", action .. ":" .. rec.actionCount)
end

local function place(rec)
	local cf = CFrame.new(rec.pos.X, rec.pos.Y + rec.height / 2, rec.pos.Z) * CFrame.Angles(0, rec.yaw, 0)
	if not rec.lastCf or (rec.lastCf.Position - cf.Position).Magnitude > 0.05 or math.abs(rec.lastYaw - rec.yaw) > 0.02 then
		rec.root.CFrame = cf
		rec.lastCf = cf
		rec.lastYaw = rec.yaw
	end
end

local function randomPointInCamp(camp, fraction)
	local angle = math.random() * math.pi * 2
	local distance = math.sqrt(math.random()) * camp.radius * (fraction or 0.85)
	local x = camp.center.X + math.cos(angle) * distance
	local z = camp.center.Y + math.sin(angle) * distance
	return keepInside(camp, Vector3.new(x, groundAt(x, z, camp), z))
end

function EnemyService.spawn(camp, enemyId, options)
	options = options or {}
	local def = Enemies.Defs[enemyId]
	if not def then
		return nil
	end
	local canBeElite = not def.boss and def.behavior ~= "dummy" and not options.summoned
	local elite = options.forceElite == true or (canBeElite and math.random() < Enemies.EliteChance * (if isNight() then Config.NightEliteMultiplier else 1))
	local height = EnemyModels.height(def, elite)
	local radius = def.radius * (if elite then 1.35 else 1)
	local hp = math.floor(def.hp * (if elite then 3 else 1) * (options.hpMult or 1))
	local level = def.level + (if elite then 2 else 0) + (options.levelBonus or 0)
	local pos = options.position or randomPointInCamp(camp)

	local root = Instance.new("Part")
	root.Name = (if elite then "Elite " else "") .. def.name
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.Transparency = 1
	root.Size = Vector3.new(radius * 2, height, radius * 2)
	root:SetAttribute("Type", enemyId)
	root:SetAttribute("Elite", elite)
	root:SetAttribute("Level", level)
	root:SetAttribute("Hp", hp)
	root:SetAttribute("MaxHp", hp)
	root:SetAttribute("Action", "idle:0")
	local maxPosture = math.floor((def.posture or 8 * math.sqrt(def.hp)) * (if elite then 1.6 else 1))
	root:SetAttribute("Posture", 0)
	root:SetAttribute("MaxPosture", maxPosture)

	local rec = {
		def = def,
		id = enemyId,
		camp = camp,
		root = root,
		pos = pos,
		home = Vector3.new(camp.center.X, 0, camp.center.Y),
		yaw = math.random() * math.pi * 2,
		lastYaw = 0,
		hp = hp,
		maxHp = hp,
		height = height,
		radius = radius,
		elite = elite,
		level = level,
		damageMult = (if elite then 1.5 else 1) * (options.damageMult or 1),
		rewardMult = options.rewardMult or 1, -- masmorras: andares mais fundos dão mais XP e ouro
		damageBy = {},
		threat = {},
		tauntBy = nil,
		tauntUntil = 0,
		state = "idle",
		stateUntil = 0,
		lastAttack = 0,
		lastHitAt = 0,
		nextCharge = os.clock() + math.random() * 3 + 2,
		nextSlam = os.clock() + math.random() * 3 + 3,
		nextSummon = os.clock() + 15,
		stunUntil = 0,
		staggerUntil = 0,
		posture = 0,
		maxPosture = maxPosture,
		lastPostureHit = 0,
		dots = {},
		actionCount = 0,
		summoned = options.summoned,
		leash = def.leash or (camp.radius * 2 + 25),
		dead = false,
	}
	place(rec)
	root.Parent = folder
	table.insert(active, rec)
	byRoot[root] = rec
	return rec
end

local function respawnLater(camp, enemyId)
	if not camp.respawn then
		return -- masmorras não renascem inimigos
	end
	task.delay(camp.respawn, function()
		local rec = EnemyService.spawn(camp, enemyId)
		if rec and rec.def.boss then
			Remotes.Notify:FireAllClients({ kind = "announce", text = ("👑 O %s voltou ao Covil!"):format(rec.def.name), sub = "Passagem do Norte, além do Portão Selado" })
		end
	end)
end

local function kill(rec, killer)
	rec.dead = true
	rec.root:SetAttribute("Hp", 0)
	rec.root:SetAttribute("Dead", true)
	local contributors = {}
	for player, damage in rec.damageBy do
		if player.Parent == Players then
			contributors[player] = damage
		end
	end
	Remotes.Fx:FireAllClients("death", rec.root.Position, rec.def.color, if rec.def.boss then 3 elseif rec.elite then 1.6 else 1)
	byRoot[rec.root] = nil
	task.delay(0.1, function()
		rec.root:Destroy()
	end)
	if rec.def.boss and rec.camp.respawn then
		Remotes.Notify:FireAllClients({ kind = "announce", text = ("👑 O %s foi derrotado!"):format(rec.def.name), sub = ("Volta em %d segundos"):format(rec.camp.respawn) })
	end
	if not rec.summoned then
		respawnLater(rec.camp, rec.id)
	end
	if EnemyService.OnKilled then
		task.spawn(EnemyService.OnKilled, rec, contributors, killer)
	end
end

-- ===================== POSTURA (guarda) =====================

local function setPosture(rec, value)
	rec.posture = math.clamp(value, 0, rec.maxPosture)
	rec.root:SetAttribute("Posture", math.floor(rec.posture))
end

-- Guarda quebrada: atordoado por alguns segundos e tomando dano extra
function EnemyService.stagger(rec, player)
	if rec.dead then
		return
	end
	local now = os.clock()
	local duration = if rec.def.boss then Config.StaggerTime * 0.8 else Config.StaggerTime
	rec.staggerUntil = now + duration
	rec.stunUntil = math.max(rec.stunUntil, now + duration)
	rec.state = "stunned"
	setPosture(rec, 0)
	rec.root:SetAttribute("Staggered", true)
	setAction(rec, "stagger")
	Remotes.Fx:FireAllClients("stagger", rec.root, player)
	if EnemyService.OnStagger and player then
		task.spawn(EnemyService.OnStagger, rec, player)
	end
	task.delay(duration, function()
		if not rec.dead and os.clock() >= rec.staggerUntil - 0.05 then
			rec.root:SetAttribute("Staggered", false)
		end
	end)
end

function EnemyService.addPosture(rec, amount, player)
	if rec.dead or amount <= 0 or os.clock() < rec.staggerUntil then
		return
	end
	rec.lastPostureHit = os.clock()
	setPosture(rec, rec.posture + amount)
	if rec.posture >= rec.maxPosture then
		EnemyService.stagger(rec, player)
	end
end

-- Golpe do inimigo aparado: perde o equilíbrio (curto) e muita postura
function EnemyService.parried(rec, player)
	if rec.dead then
		return
	end
	local now = os.clock()
	if now >= rec.staggerUntil then
		rec.stunUntil = math.max(rec.stunUntil, now + (if rec.def.boss then 0.6 else 1.1))
		rec.state = "stunned"
		setAction(rec, "stun")
	end
	EnemyService.addPosture(rec, rec.maxPosture * 0.35, player)
end

function EnemyService.isStaggered(rec)
	return os.clock() < rec.staggerUntil
end

-- info: { crit, knockback, stun, fromPosition, color, dot, posture }
-- Retorna o dano causado e se foi contra-ataque
function EnemyService.damage(rec, amount, player, info)
	-- perks de assinatura das masmorras: +dano dentro delas
	if player and rec.camp and rec.camp.dungeon and amount > 0 then
		local bonus = PlayerService.getStats(player).bonus.dungeonDamage
		if bonus and bonus > 0 then
			amount = math.floor(amount * (1 + bonus) + 0.5)
		end
	end
	if rec.dead then
		return 0
	end
	info = info or {}
	local now = os.clock()
	local tag = nil
	-- contra-ataque: acertar o inimigo enquanto ele se recupera do próprio ataque
	if not info.dot and rec.state == "recover" then
		amount *= 1 + Config.CounterBonus
		info.posture = (info.posture or 0) * (1 + Config.CounterBonus)
		tag = "counter"
	end
	if now < rec.staggerUntil and not info.dot then
		amount *= 1 + Config.StaggerDamageBonus
		tag = "staggered"
	end
	amount = math.max(1, math.floor(amount * (1 - (rec.def.defense or 0))))
	rec.hp -= amount
	rec.lastHitAt = os.clock()
	if player then
		rec.lastHitBy = player
		rec.damageBy[player] = (rec.damageBy[player] or 0) + amount
		-- ameaça: o inimigo persegue quem gerou mais (tanques geram muito mais)
		rec.threat[player] = (rec.threat[player] or 0) + amount * PlayerService.threatMultiplier(player)
		rec.forcedTarget = EnemyService.topThreat(rec)
	end
	rec.root:SetAttribute("Hp", math.max(0, math.floor(rec.hp)))
	Remotes.Fx:FireAllClients("hit", rec.root, amount, info.crit == true, player, info.color, tag, info.element or (if info.dot then "dot" else nil))
	if info.posture and info.posture > 0 and rec.hp > 0 then
		EnemyService.addPosture(rec, info.posture, player)
	end

	local immovable = rec.def.boss or rec.def.behavior == "dummy"
	if info.knockback and info.fromPosition and not immovable then
		local push = flat(rec.pos - info.fromPosition)
		if push.Magnitude > 0.01 then
			local target = keepInside(rec.camp, rec.pos + push.Unit * info.knockback * 0.35)
			local y = groundAt(target.X, target.Z, rec.camp)
			if y > World.SeaLevel - 1 then
				rec.pos = Vector3.new(target.X, y, target.Z)
			end
		end
	end
	if info.stun and not rec.def.boss and now >= rec.staggerUntil then
		rec.stunUntil = math.max(rec.stunUntil, os.clock() + info.stun)
		rec.state = "stunned"
		setAction(rec, "stun")
	elseif info.stun and rec.def.boss then
		rec.stunUntil = math.max(rec.stunUntil, os.clock() + info.stun * 0.3)
	end
	if EnemyService.OnHit and player then
		EnemyService.OnHit(rec, player, amount, info, tag)
	end
	if rec.hp <= 0 then
		if rec.def.behavior == "dummy" then
			rec.hp = rec.maxHp
		else
			kill(rec, player)
		end
	end
	return amount
end

function EnemyService.applyDot(rec, player, dps, duration, kind)
	if rec.dead then
		return
	end
	rec.dots[kind] = { player = player, dps = dps, untilTime = os.clock() + duration, nextTick = os.clock() + 0.5 }
	rec.root:SetAttribute("Dot", kind)
end

function EnemyService.fromRoot(root)
	return byRoot[root]
end

-- ===================== CONSULTAS =====================

function EnemyService.inCone(origin, direction, range, arcDegrees, maxTargets)
	local look = flat(direction)
	look = if look.Magnitude > 0.01 then look.Unit else Vector3.new(0, 0, -1)
	local cosLimit = math.cos(math.rad(arcDegrees / 2))
	local found = {}
	for _, rec in active do
		if not rec.dead then
			local offset = rec.pos + Vector3.new(0, rec.height / 2, 0) - origin
			local horizontal = flat(offset)
			local distance = horizontal.Magnitude - rec.radius
			if distance <= range and math.abs(offset.Y) < rec.height / 2 + 8 then
				local dot = if horizontal.Magnitude > 0.01 then look:Dot(horizontal.Unit) else 1
				if dot >= cosLimit or distance < 1.5 then
					table.insert(found, { rec = rec, distance = distance })
				end
			end
		end
	end
	table.sort(found, function(a, b)
		return a.distance < b.distance
	end)
	local result = {}
	for i = 1, math.min(maxTargets or 99, #found) do
		result[i] = found[i].rec
	end
	return result
end

function EnemyService.inRadius(center, radius, maxTargets)
	local found = {}
	for _, rec in active do
		if not rec.dead then
			local offset = rec.pos + Vector3.new(0, rec.height / 2, 0) - center
			local distance = flat(offset).Magnitude - rec.radius
			if distance <= radius and math.abs(offset.Y) < radius + rec.height then
				table.insert(found, { rec = rec, distance = distance })
			end
		end
	end
	table.sort(found, function(a, b)
		return a.distance < b.distance
	end)
	local result = {}
	for i = 1, math.min(maxTargets or 99, #found) do
		result[i] = found[i].rec
	end
	return result
end

-- Inimigos cujo corpo encosta no segmento a->b (projéteis e investidas)
function EnemyService.alongSegment(a, b, radius)
	local result = {}
	local ab = b - a
	local lengthSq = ab:Dot(ab)
	for _, rec in active do
		if not rec.dead then
			local center = rec.pos + Vector3.new(0, rec.height / 2, 0)
			local t = if lengthSq > 0 then math.clamp((center - a):Dot(ab) / lengthSq, 0, 1) else 0
			local closest = a + ab * t
			local offset = center - closest
			if flat(offset).Magnitude <= rec.radius + radius and math.abs(offset.Y) <= rec.height / 2 + radius then
				table.insert(result, rec)
			end
		end
	end
	return result
end

function EnemyService.nearest(origin, range)
	local best, bestDistance = nil, range
	for _, rec in active do
		if not rec.dead and rec.def.behavior ~= "dummy" then
			local distance = (flat(rec.pos - origin)).Magnitude - rec.radius
			if distance < bestDistance then
				best, bestDistance = rec, distance
			end
		end
	end
	return best
end

function EnemyService.centerOf(rec)
	return rec.pos + Vector3.new(0, rec.height / 2, 0)
end

-- ===================== IA =====================

local function telegraph(shape, position, size, duration, direction)
	Remotes.Fx:FireAllClients("telegraph", shape, position, size, duration, direction)
end

local function moveToward(rec, direction, speed, dt)
	if direction.Magnitude < 0.01 or speed <= 0 then
		return
	end
	local step = direction.Unit * speed * dt
	local target = keepInside(rec.camp, rec.pos + step)
	local y = groundAt(target.X, target.Z, rec.camp)
	if y < World.SeaLevel - (if rec.id == "caranguejo" then 3 else 0.3) then
		return
	end
	-- não sobe paredões
	if y - rec.pos.Y > speed * dt * 1.6 + 0.6 then
		return
	end
	rec.pos = Vector3.new(target.X, y, target.Z)
end

local function playersInfo()
	local list = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and humanoid and humanoid.Health > 0 then
			table.insert(list, { player = player, root = root, humanoid = humanoid })
		end
	end
	return list
end

-- jogador com mais ameaça (ou quem provocou, enquanto durar)
function EnemyService.topThreat(rec)
	if rec.tauntBy and os.clock() < rec.tauntUntil and rec.tauntBy.Parent then
		return rec.tauntBy
	end
	local best, bestValue = nil, 0
	for player, value in rec.threat do
		if player.Parent and value > bestValue then
			best, bestValue = player, value
		end
	end
	return best
end

-- Provocar: o inimigo ataca este jogador por "duration" segundos e ganha muita ameaça dele
function EnemyService.taunt(rec, player, duration)
	if rec.dead then
		return
	end
	rec.tauntBy = player
	rec.tauntUntil = os.clock() + duration
	local top = 0
	for _, value in rec.threat do
		top = math.max(top, value)
	end
	rec.threat[player] = top * 1.5 + 50
	rec.forcedTarget = player
	Remotes.Fx:FireAllClients("taunted", rec.root, player)
end

-- Curas geram ameaça nos inimigos que já estão lutando por perto
function EnemyService.addThreatNear(player, position, radius, amount)
	for _, rec in active do
		if not rec.dead and next(rec.threat) ~= nil and flat(rec.pos - position).Magnitude <= radius then
			rec.threat[player] = (rec.threat[player] or 0) + amount
			rec.forcedTarget = EnemyService.topThreat(rec)
		end
	end
end

local function pickTarget(rec, targets)
	local def = rec.def
	local best, bestDistance = nil, nil
	for _, candidate in targets do
		local position = candidate.root.Position
		local distance = flat(position - rec.pos).Magnitude
		local fromHome = flat(position - rec.home).Magnitude
		local aggro = def.aggro * (if rec.damageBy[candidate.player] then 2.2 else 1)
		local forced = rec.forcedTarget == candidate.player and distance < def.aggro * 3
		if (distance <= aggro or forced) and fromHome <= rec.leash and math.abs(position.Y - rec.pos.Y) < 30 then
			if forced then
				return candidate, distance
			end
			if not bestDistance or distance < bestDistance then
				best, bestDistance = candidate, distance
			end
		end
	end
	return best, bestDistance
end

-- unblockable = golpe que não dá para bloquear nem aparar (só esquivar)
local function strikePlayers(rec, center, radius, damage, unblockable)
	for _, candidate in playersInfo() do
		local offset = candidate.root.Position - center
		if flat(offset).Magnitude <= radius + 1.5 and math.abs(offset.Y) < radius + 6 then
			PlayerService.damagePlayer(candidate.player, damage, rec.pos, { source = rec, unblockable = unblockable })
		end
	end
end

local function separate(rec)
	for _, other in active do
		if other ~= rec and not other.dead and other.camp == rec.camp then
			local offset = flat(rec.pos - other.pos)
			local minDistance = rec.radius + other.radius
			local d = offset.Magnitude
			if d > 0.01 and d < minDistance then
				local push = offset.Unit * (minDistance - d) * 0.5
				local target = keepInside(rec.camp, rec.pos + push)
				rec.pos = Vector3.new(target.X, groundAt(target.X, target.Z, rec.camp), target.Z)
			end
		end
	end
end

local function updateDots(rec, now)
	for kind, dot in rec.dots do
		if now >= dot.untilTime or rec.dead then
			rec.dots[kind] = nil
			if next(rec.dots) == nil then
				rec.root:SetAttribute("Dot", nil)
			end
		elseif now >= dot.nextTick then
			dot.nextTick = now + 0.5
			local color = if kind == "poison" then Color3.fromRGB(120, 230, 80) else Color3.fromRGB(255, 140, 50)
			EnemyService.damage(rec, dot.dps * 0.5, dot.player, { dot = true, color = color })
		end
	end
end

local function updateEnemy(rec, now, targets)
	local def = rec.def
	updateDots(rec, now)
	if rec.dead then
		return
	end
	-- a postura volta ao normal se o inimigo ficar um tempo sem apanhar
	if rec.posture > 0 and now - rec.lastPostureHit > 2.5 and now >= rec.staggerUntil then
		setPosture(rec, rec.posture - rec.maxPosture * 0.15 * TICK)
	end
	if def.behavior == "dummy" then
		if now - rec.lastHitAt > 2 and rec.hp < rec.maxHp then
			rec.hp = rec.maxHp
			rec.root:SetAttribute("Hp", rec.hp)
		end
		if now < rec.stunUntil then
			return
		end
		-- boneco: golpe lento e avisado em quem estiver perto (treino de aparar/esquivar)
		if rec.state == "windup" then
			if now >= rec.stateUntil then
				rec.state = "recover"
				rec.stateUntil = now + 0.9
				setAction(rec, "attack")
				strikePlayers(rec, rec.pos + lookOf(rec) * (rec.radius + 1.5), 4, def.damage)
			end
			return
		elseif rec.state == "recover" or rec.state == "stunned" then
			if now >= rec.stateUntil then
				rec.state = "idle"
			end
			return
		end
		for _, candidate in targets do
			local toPlayer = flat(candidate.root.Position - rec.pos)
			if toPlayer.Magnitude < def.attackRange + rec.radius + 2 and now - rec.lastAttack >= def.attackCooldown then
				rec.lastAttack = now
				rec.yaw = yawTowards(toPlayer)
				rec.state = "windup"
				rec.stateUntil = now + 0.9
				setAction(rec, "windup")
				place(rec)
				break
			end
		end
		return
	end
	if now < rec.stunUntil then
		return
	end
	if rec.state == "stunned" then
		rec.state = "idle"
		setAction(rec, "idle")
	end

	local boss = def.behavior == "boss"
	local enraged = boss and rec.hp < rec.maxHp * 0.4
	local speedMult = if enraged then 1.3 else 1
	local target, distance = pickTarget(rec, targets)
	if not target then
		rec.forcedTarget = nil
		rec.threat = {}
		rec.tauntBy = nil
	end

	-- ===== estados especiais em andamento =====
	if rec.state == "windup" then
		if now >= rec.stateUntil then
			rec.state = "recover"
			rec.stateUntil = now + (if boss then 0.55 else 0.75)
			setAction(rec, "attack")
			local reach = def.attackRange + rec.radius + 2
			local center = rec.pos + lookOf(rec) * (rec.radius + 1)
			if target and distance <= reach + 1 then
				strikePlayers(rec, center, math.max(def.attackRange * 0.7, 3), def.damage * damageMult(rec))
			end
		end
		return
	elseif rec.state == "recover" then
		if now >= rec.stateUntil then
			rec.state = "chase"
		end
		return
	elseif rec.state == "chargeWindup" then
		if now >= rec.stateUntil then
			rec.state = "charging"
			rec.stateUntil = now + def.charge.time
			rec.chargeHit = {}
			setAction(rec, "charge")
		end
		return
	elseif rec.state == "charging" then
		moveToward(rec, rec.chargeDir, def.charge.speed, TICK)
		for _, candidate in targets do
			if not rec.chargeHit[candidate.player] and flat(candidate.root.Position - rec.pos).Magnitude < rec.radius + 3 then
				rec.chargeHit[candidate.player] = true
				PlayerService.damagePlayer(candidate.player, def.charge.damage * damageMult(rec), rec.pos, { source = rec, unblockable = true })
			end
		end
		if now >= rec.stateUntil then
			rec.state = "recover"
			rec.stateUntil = now + 0.6
			setAction(rec, "idle")
		end
		place(rec)
		return
	elseif rec.state == "slamWindup" then
		if now >= rec.stateUntil then
			rec.state = "recover"
			rec.stateUntil = now + 0.6
			setAction(rec, "slam")
			Remotes.Fx:FireAllClients("explosion", rec.pos, def.slam.radius, "earth")
			strikePlayers(rec, rec.pos, def.slam.radius, def.slam.damage * damageMult(rec), true)
		end
		return
	end

	if target then
		local toTarget = flat(target.root.Position - rec.pos)
		if toTarget.Magnitude > 0.05 then
			rec.yaw = yawTowards(toTarget)
		end

		-- especiais
		if def.slam and now >= rec.nextSlam and distance < def.slam.radius * 0.85 then
			rec.nextSlam = now + def.slam.cooldown * (if enraged then 0.7 else 1)
			rec.state = "slamWindup"
			rec.stateUntil = now + def.slam.windup
			setAction(rec, "slamWindup")
			telegraph("circle", rec.pos, def.slam.radius, def.slam.windup)
			place(rec)
			return
		end
		if def.charge and now >= rec.nextCharge and distance > 9 and distance < 45 then
			rec.nextCharge = now + def.charge.cooldown * (if enraged then 0.7 else 1)
			rec.state = "chargeWindup"
			rec.stateUntil = now + def.charge.windup
			rec.chargeDir = toTarget.Unit
			setAction(rec, "chargeWindup")
			telegraph("line", rec.pos, Vector3.new(rec.radius * 2 + 2, 0, def.charge.speed * def.charge.time), def.charge.windup, rec.chargeDir)
			place(rec)
			return
		end
		if def.summon and now >= rec.nextSummon and rec.hp < rec.maxHp * 0.75 then
			rec.nextSummon = now + def.summon.cooldown
			for i = 1, def.summon.count do
				local angle = i / def.summon.count * math.pi * 2
				local x = rec.pos.X + math.cos(angle) * 10
				local z = rec.pos.Z + math.sin(angle) * 10
				local spot = keepInside(rec.camp, Vector3.new(x, groundAt(x, z, rec.camp), z))
				EnemyService.spawn(rec.camp, def.summon.enemy, { summoned = true, position = spot, hpMult = rec.camp.hpMult, damageMult = rec.camp.damageMult, levelBonus = rec.camp.levelBonus })
			end
			setAction(rec, "roar")
			Remotes.Fx:FireAllClients("explosion", rec.pos, 10, "summon")
			Remotes.Notify:FireAllClients({ kind = "banner", text = ("👑 O %s chama reforços!"):format(def.name), color = Color3.fromRGB(255, 120, 60), duration = 2.5, nearby = { position = rec.pos, radius = 150 } })
		end

		if def.behavior == "ranged" then
			local keep = def.projectile.keepDistance
			if distance < keep - 6 then
				moveToward(rec, -toTarget, def.speed * 0.8, TICK)
			elseif distance > def.attackRange then
				moveToward(rec, toTarget, def.speed, TICK)
			elseif now - rec.lastAttack >= def.attackCooldown then
				rec.lastAttack = now
				rec.state = "recover"
				rec.stateUntil = now + 0.7
				setAction(rec, "shoot")
				local origin = rec.pos + Vector3.new(0, rec.height * 0.7, 0) + lookOf(rec) * (rec.radius + 0.5)
				local aimAt = target.root.Position
				task.delay(0.45, function()
					if rec.dead or not EnemyService.FireProjectile then
						return
					end
					local direction = aimAt - origin
					if direction.Magnitude < 0.1 then
						return
					end
					EnemyService.FireProjectile({
						team = "enemy",
						origin = origin,
						direction = direction.Unit,
						speed = def.projectile.speed,
						range = def.attackRange + 15,
						radius = 1.3,
						damage = def.projectile.damage * damageMult(rec),
						aoe = def.projectile.aoe,
						style = def.projectile.style,
					})
				end)
			end
		else
			local reach = def.attackRange + rec.radius
			if distance > reach then
				moveToward(rec, toTarget, def.speed * speedMult, TICK)
			elseif now - rec.lastAttack >= def.attackCooldown / speedMult then
				rec.lastAttack = now
				rec.state = "windup"
				rec.stateUntil = now + (if boss then 0.65 else 0.5)
				setAction(rec, "windup")
			end
		end
	else
		-- volta para casa se estiver longe; senão passeia
		local fromHome = flat(rec.pos - rec.home)
		if fromHome.Magnitude > rec.camp.radius + 8 then
			moveToward(rec, -fromHome, def.speed * 0.9, TICK)
			rec.yaw = yawTowards(-fromHome)
			rec.hp = math.min(rec.maxHp, rec.hp + rec.maxHp * 0.03)
			rec.root:SetAttribute("Hp", math.floor(rec.hp))
		else
			if not rec.wanderGoal or flat(rec.wanderGoal - rec.pos).Magnitude < 2 or now > rec.wanderUntil then
				rec.wanderGoal = randomPointInCamp(rec.camp)
				rec.wanderUntil = now + 6 + math.random() * 5
				rec.idleUntil = now + math.random() * 4
			end
			if now > (rec.idleUntil or 0) then
				local toGoal = flat(rec.wanderGoal - rec.pos)
				if toGoal.Magnitude > 0.5 then
					moveToward(rec, toGoal, def.speed * 0.35, TICK)
					rec.yaw = yawTowards(toGoal)
				end
			end
			if rec.hp < rec.maxHp and now - rec.lastHitAt > 4 then
				rec.hp = math.min(rec.maxHp, rec.hp + rec.maxHp * 0.02)
				rec.root:SetAttribute("Hp", math.floor(rec.hp))
				if rec.hp >= rec.maxHp then
					rec.damageBy = {}
				end
			end
		end
	end
	separate(rec)
	place(rec)
end

-- Inimigos vivos de um acampamento (inclui os invocados)
function EnemyService.aliveInCamp(camp)
	local count = 0
	for _, rec in active do
		if rec.camp == camp and not rec.dead then
			count += 1
		end
	end
	return count
end

-- Tira um inimigo do mundo sem recompensa (ex.: campeão que fugiu)
function EnemyService.despawn(rec)
	if rec and not rec.dead then
		rec.dead = true
		byRoot[rec.root] = nil
		Remotes.Fx:FireAllClients("blink", rec.root.Position)
		rec.root:Destroy()
	end
end

-- Tira os inimigos de um acampamento sem recompensa (masmorra fechada)
function EnemyService.clearCamp(camp)
	for _, rec in active do
		if rec.camp == camp and not rec.dead then
			rec.dead = true
			byRoot[rec.root] = nil
			rec.root:Destroy()
		end
	end
end

function EnemyService.start()
	for _, camp in Enemies.Camps do
		for enemyId, count in camp.spawns do
			for i = 1, count do
				local options = nil
				if Enemies.Defs[enemyId].behavior == "dummy" then
					-- bonecos lado a lado, em posições fixas
					local x = camp.center.X + (i - (count + 1) / 2) * 7 * World.Scale
					local z = camp.center.Y
					options = { position = Vector3.new(x, groundAt(x, z), z) }
				end
				EnemyService.spawn(camp, enemyId, options)
			end
		end
	end
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < TICK then
			return
		end
		accumulator = 0
		local now = os.clock()
		local targets = playersInfo()
		for i = #active, 1, -1 do
			local rec = active[i]
			if rec.dead then
				table.remove(active, i)
			else
				local ok, err = pcall(updateEnemy, rec, now, targets)
				if not ok then
					warn("[EnemyService] " .. tostring(err))
				end
			end
		end
	end)
end

return EnemyService
