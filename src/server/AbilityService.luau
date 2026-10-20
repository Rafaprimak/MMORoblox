-- Habilidades de classe (teclas 1 a 4).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local World = require(Shared.World)
local Classes = require(Shared.Classes)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local PlayerService = require(script.Parent.PlayerService)
local EnemyService = require(script.Parent.EnemyService)
local ProjectileService = require(script.Parent.ProjectileService)
local CombatService = require(script.Parent.CombatService)

local AbilityService = {}

AbilityService.QuestHook = function(_player, _kind, _target, _amount) end

local cooldowns = {}

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

local function characterParts(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root and humanoid and humanoid.Health > 0 then
		return character, root, humanoid
	end
	return nil
end

local function flatAim(aim, root)
	local direction = if typeof(aim) == "Vector3" and aim == aim then flat(aim) else flat(root.CFrame.LookVector)
	if direction.Magnitude < 0.01 then
		direction = flat(root.CFrame.LookVector)
	end
	return direction.Unit
end

-- ponto mirado no chão, limitado ao alcance
local function groundPoint(root, aimPoint, range)
	local point = if typeof(aimPoint) == "Vector3" and aimPoint == aimPoint then aimPoint else root.Position + root.CFrame.LookVector * range * 0.6
	local offset = flat(point - root.Position)
	if offset.Magnitude > range then
		offset = offset.Unit * range
	end
	local x, z = root.Position.X + offset.X, root.Position.Z + offset.Z
	return Vector3.new(x, World.height(x, z), z)
end

local function hitRadius(player, center, radius, mult, info)
	local count = 0
	for _, rec in EnemyService.inRadius(center, radius) do
		info.fromPosition = info.fromPosition or center
		if CombatService.dealDamage(player, rec, mult, info) > 0 then
			count += 1
		end
	end
	return count
end

local function dashAndHit(player, direction, speed, duration, radius, mult, stun)
	Remotes.Fx:FireClient(player, "selfDash", direction, speed, duration)
	local _, root = characterParts(player)
	if not root then
		return
	end
	local last = root.Position
	local hit = {}
	local elapsed = 0
	while elapsed < duration + 0.1 do
		elapsed += task.wait(0.05)
		local _, r = characterParts(player)
		if not r then
			return
		end
		if mult > 0 then
			for _, rec in EnemyService.alongSegment(last, r.Position, radius) do
				if not hit[rec] then
					hit[rec] = true
					CombatService.dealDamage(player, rec, mult, { stun = stun, fromPosition = r.Position, ability = true })
				end
			end
		end
		last = r.Position
	end
end

local executors = {}

function executors.dash(player, ability, mult, aim, _point, root)
	dashAndHit(player, flatAim(aim, root), ability.dashSpeed, ability.dashTime, ability.radius, ability.dmg * mult, ability.stun)
end

function executors.whirl(player, ability, mult)
	for i = 1, ability.ticks do
		local _, r = characterParts(player)
		if not r then
			return
		end
		Remotes.Fx:FireAllClients("explosion", r.Position - Vector3.new(0, 2.5, 0), ability.radius, "slash")
		hitRadius(player, r.Position, ability.radius, ability.dmg * mult, { knockback = 4, ability = true, element = ability.style })
		if i < ability.ticks then
			task.wait(ability.interval)
		end
	end
end

function executors.buff(player, ability, mult)
	PlayerService.addBuff(player, "grito", { damage = ability.damage * mult, defense = ability.defense * mult }, ability.time)
	local _, root = characterParts(player)
	if root then
		Remotes.Fx:FireAllClients("explosion", root.Position - Vector3.new(0, 2.5, 0), 12, "roar")
	end
end

function executors.slam(player, ability, mult)
	Remotes.Fx:FireClient(player, "selfJump", 45)
	task.wait(ability.windup)
	local _, root = characterParts(player)
	if not root then
		return
	end
	local center = root.Position - Vector3.new(0, 2.5, 0)
	Remotes.Fx:FireAllClients("explosion", center, ability.radius, "earth")
	hitRadius(player, root.Position, ability.radius, ability.dmg * mult, { stun = ability.stun, knockback = 10, ability = true, element = ability.style })
end

local function shoot(player, ability, mult, direction, origin, style)
	ProjectileService.fire({
		team = "player",
		origin = origin,
		direction = direction,
		speed = ability.speed,
		range = ability.range,
		radius = ability.radius or 1.2,
		aoe = ability.aoe,
		style = style or ability.style,
		onHitEnemy = function(rec)
			CombatService.dealDamage(player, rec, ability.dmg * mult, { fromPosition = origin, ability = true, element = ability.style })
		end,
		onExplode = function(position)
			Remotes.Fx:FireAllClients("explosion", position, ability.aoe, ability.style)
			hitRadius(player, position, ability.aoe, ability.dmg * mult, { knockback = 8, ability = true, element = ability.style })
		end,
	})
end

function executors.multishot(player, ability, mult, aim, _point, root)
	local base = if typeof(aim) == "Vector3" and aim == aim and aim.Magnitude > 0.5 then aim.Unit else root.CFrame.LookVector
	local origin = root.Position + Vector3.new(0, 1.2, 0) + flat(base).Unit * 2
	local count = ability.count
	for i = 1, count do
		local angle = math.rad((i - (count + 1) / 2) * (ability.spread / math.max(count - 1, 1)))
		local direction = (CFrame.Angles(0, angle, 0) * base).Unit
		shoot(player, ability, mult, direction, origin)
	end
end

function executors.leap(player, ability, mult, aim, _point, root)
	local start = root.Position
	local direction = flatAim(aim, root)
	dashAndHit(player, direction, ability.dashSpeed, ability.dashTime, 0, 0)
	-- armadilha de espinhos onde estava
	Remotes.Fx:FireAllClients("explosion", start - Vector3.new(0, 2.5, 0), ability.radius, "spikes")
	hitRadius(player, start, ability.radius, ability.dmg * mult, { stun = 1, ability = true, element = ability.style })
end

function executors.rain(player, ability, mult, _aim, point, root)
	local center = groundPoint(root, point, ability.range)
	Remotes.Fx:FireAllClients("rain", center, ability.radius, ability.ticks * ability.interval)
	for i = 1, ability.ticks do
		hitRadius(player, center + Vector3.new(0, 2, 0), ability.radius, ability.dmg * mult, { ability = true, element = ability.style })
		if i < ability.ticks then
			task.wait(ability.interval)
		end
	end
end

function executors.projectile(player, ability, mult, aim, _point, root)
	local direction = if typeof(aim) == "Vector3" and aim == aim and aim.Magnitude > 0.5 then aim.Unit else root.CFrame.LookVector
	shoot(player, ability, mult, direction, root.Position + Vector3.new(0, 1.2, 0) + flat(direction).Unit * 2)
end

function executors.nova(player, ability, mult, _aim, _point, root)
	Remotes.Fx:FireAllClients("explosion", root.Position - Vector3.new(0, 2.5, 0), ability.radius, ability.style or "ice")
	hitRadius(player, root.Position, ability.radius, ability.dmg * mult, { stun = ability.stun, color = Color3.fromRGB(150, 220, 255), ability = true, element = ability.style })
end

function executors.blink(player, ability, _mult, aim, _point, root)
	local character = player.Character
	local direction = flatAim(aim, root)
	local from = root.Position
	local target = from + direction * ability.distance
	local ground = World.height(target.X, target.Z)
	if ground < World.SeaLevel then
		target = from + direction * ability.distance * 0.4
		ground = World.height(target.X, target.Z)
	end
	local destination = Vector3.new(target.X, math.max(ground, World.SeaLevel) + 3.2, target.Z)
	character:PivotTo(CFrame.lookAt(destination, destination + direction))
	Remotes.Fx:FireAllClients("blink", from, destination)
	PlayerService.grantIFrames(player, 0.3)
end

function executors.meteor(player, ability, mult, _aim, point, root)
	local center = groundPoint(root, point, ability.range)
	Remotes.Fx:FireAllClients("meteor", center, ability.radius, ability.delay)
	task.wait(ability.delay)
	Remotes.Fx:FireAllClients("explosion", center, ability.radius, "fire")
	hitRadius(player, center + Vector3.new(0, 2, 0), ability.radius, ability.dmg * mult, { knockback = 14, stun = 0.8, ability = true, element = ability.style })
end

function executors.shadowstep(player, ability, _mult, _aim, _point, root)
	local rec = EnemyService.nearest(root.Position, ability.range)
	if not rec then
		Remotes.Notify:FireClient(player, { kind = "message", text = "Nenhum inimigo por perto." })
		return false
	end
	local enemyLook = Vector3.new(-math.sin(rec.yaw), 0, -math.cos(rec.yaw))
	local behind = rec.pos - enemyLook * (rec.radius + 3)
	local destination = Vector3.new(behind.X, World.height(behind.X, behind.Z) + 3.2, behind.Z)
	local from = root.Position
	player.Character:PivotTo(CFrame.lookAt(destination, Vector3.new(rec.pos.X, destination.Y, rec.pos.Z)))
	Remotes.Fx:FireAllClients("blink", from, destination, "shadow")
	local s = PlayerService.getState(player)
	if s then
		s.nextCrit = true
	end
	PlayerService.grantIFrames(player, 0.4)
	return true
end

function executors.poisonbuff(player, ability, mult)
	PlayerService.addBuff(player, "veneno", { poison = ability.dps * mult }, ability.time)
end

function executors.execute(player, ability, mult, aim, _point, root)
	local targets = EnemyService.inCone(root.Position, flatAim(aim, root), ability.range, ability.arc, 1)
	local rec = targets[1]
	if not rec then
		return
	end
	local damageMult = ability.dmg * mult
	if rec.hp < rec.maxHp * 0.3 then
		damageMult *= ability.lowHpBonus
	end
	Remotes.Fx:FireAllClients("explosion", EnemyService.centerOf(rec), 4, "shadow")
	CombatService.dealDamage(player, rec, damageMult, { fromPosition = root.Position, knockback = 8, ability = true, element = ability.style })
end

function AbilityService.cast(player, slot, aim, aimPoint)
	local data = DataService.get(player)
	local class = data and Classes.List[data.class]
	if not class or typeof(slot) ~= "number" then
		return
	end
	local abilityId = class.abilities[math.floor(slot)]
	local ability = abilityId and Classes.Abilities[abilityId]
	if not ability then
		return
	end
	local _, root = characterParts(player)
	if not root then
		return
	end
	local rank = PlayerService.abilityRank(player, abilityId)
	if rank <= 0 then
		Remotes.Notify:FireClient(player, { kind = "message", text = ("%s destrava no nível %d."):format(ability.name, ability.unlock) })
		return
	end
	cooldowns[player] = cooldowns[player] or {}
	local now = os.clock()
	if now < (cooldowns[player][abilityId] or 0) - 0.1 then
		return
	end
	if not PlayerService.spendMana(player, ability.mana) then
		Remotes.Fx:FireClient(player, "noMana")
		return
	end
	CombatService.BeforeAction(player)
	local cooldown = Classes.rankCooldown(ability, rank)
	cooldowns[player][abilityId] = now + cooldown
	Remotes.Fx:FireClient(player, "cooldown", slot, cooldown)
	Remotes.Fx:FireAllClients("cast", player, abilityId, ability.pose)
	AbilityService.QuestHook(player, "ability", abilityId, 1)
	PlayerService.markCombat(player)
	local mult = Classes.rankMultiplier(rank)
	local executor = executors[ability.kind]
	if executor then
		task.spawn(function()
			local ok, result = pcall(executor, player, ability, mult, aim, aimPoint, root)
			if not ok then
				warn("[AbilityService] " .. tostring(result))
			elseif result == false then
				-- não encontrou alvo: devolve a mana e o tempo de recarga
				cooldowns[player][abilityId] = 0
				local s = PlayerService.getState(player)
				if s then
					s.mana += ability.mana
				end
				Remotes.Fx:FireClient(player, "cooldown", slot, 0)
			end
		end)
	end
end

Players.PlayerRemoving:Connect(function(player)
	cooldowns[player] = nil
end)

return AbilityService
