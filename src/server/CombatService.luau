-- Ataques do jogador: combos por tipo de arma, ataque pesado, esquiva e cálculo de dano.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local WeaponStyles = require(Shared.WeaponStyles)
local Remotes = require(Shared.Remotes)

local PlayerService = require(script.Parent.PlayerService)
local SkillService = require(script.Parent.SkillService)
local EnemyService = require(script.Parent.EnemyService)
local ProjectileService = require(script.Parent.ProjectileService)

local CombatService = {}

-- Ganchos preenchidos pelo init
CombatService.QuestHook = function(_player, _kind, _target, _amount) end
CombatService.BeforeAction = function(_player) end -- desmonta do cavalo etc.

local nextAttackAt = {}
local nextDodgeAt = {}

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

local function validAim(aim, root)
	if typeof(aim) == "Vector3" and aim.Magnitude > 0.5 and aim.Magnitude < 1.5 and aim == aim then
		return aim.Unit
	end
	return root.CFrame.LookVector
end

-- Dano de um golpe/habilidade em um inimigo. mult = multiplicador do golpe
function CombatService.dealDamage(player, rec, mult, info)
	info = info or {}
	local stats = PlayerService.getStats(player)
	local s = PlayerService.getState(player)
	local style = WeaponStyles.get(stats.weaponType)
	local crit = info.forceCrit or math.random() < stats.crit
	if s and s.nextCrit and not info.dot then
		crit = true
		s.nextCrit = false
	end
	local damage = stats.attack * stats.damageMult * mult * (0.9 + math.random() * 0.2) * (1 + PlayerService.buffValue(player, "damage"))
	if crit then
		damage *= stats.critMult
	end
	-- adagas: bônus pelas costas
	if style.backstab and info.fromPosition and not info.ability then
		local enemyLook = Vector3.new(-math.sin(rec.yaw), 0, -math.cos(rec.yaw))
		local toAttacker = flat(info.fromPosition - rec.pos)
		if toAttacker.Magnitude > 0.1 and enemyLook:Dot(toAttacker.Unit) < -0.3 then
			damage *= 1 + style.backstab
			info.color = Color3.fromRGB(200, 120, 255)
		end
	end
	local dealt = EnemyService.damage(rec, damage, player, {
		crit = crit,
		knockback = info.knockback,
		stun = info.stun,
		fromPosition = info.fromPosition,
		color = info.color,
	})
	if dealt > 0 then
		if stats.lifesteal > 0 then
			PlayerService.heal(player, dealt * stats.lifesteal)
		end
		if stats.burn > 0 and not info.dot then
			EnemyService.applyDot(rec, player, dealt * stats.burn / 3, 3, "burn")
		end
		local poison = PlayerService.buffValue(player, "poison")
		if poison > 0 and not info.dot then
			EnemyService.applyDot(rec, player, stats.attack * stats.damageMult * poison, 4, "poison")
		end
		if not info.ability then
			SkillService.addXP(player, stats.masteryId, if crit then 4 else 3)
		end
		PlayerService.markCombat(player)
	end
	return dealt
end

-- Resolve o efeito de um golpe (depois do tempo de preparação)
local function resolveMove(player, move, aim, isFinisher)
	local _, root = characterParts(player)
	if not root then
		return
	end
	local origin = root.Position
	local hitAny = false
	local info = { knockback = move.knockback, stun = move.stun, fromPosition = origin }

	local function hitList(list, mult)
		for _, rec in list do
			if CombatService.dealDamage(player, rec, mult, info) > 0 then
				hitAny = true
			end
		end
	end

	if move.hit == "cone" then
		hitList(EnemyService.inCone(origin, aim, move.range, move.arc), move.dmg)
	elseif move.hit == "circle" then
		local center = origin + flat(aim).Unit * move.offset
		Remotes.Fx:FireAllClients("explosion", center - Vector3.new(0, 2.5, 0), move.radius, "earth")
		hitList(EnemyService.inRadius(center, move.radius), move.dmg)
	elseif move.hit == "nova" then
		local ticks = move.ticks or 1
		Remotes.Fx:FireAllClients("explosion", origin - Vector3.new(0, 2.5, 0), move.radius, move.style or "slash")
		for i = 1, ticks do
			local _, r = characterParts(player)
			if not r then
				break
			end
			hitList(EnemyService.inRadius(r.Position, move.radius), move.dmg)
			if i < ticks then
				task.wait(move.interval or 0.15)
			end
		end
	elseif move.hit == "dash" then
		Remotes.Fx:FireClient(player, "selfDash", flat(aim).Unit, move.dashSpeed, move.dashTime)
		local hit = {}
		local last = origin
		local elapsed = 0
		while elapsed < move.dashTime + 0.1 do
			local dt = task.wait(0.05)
			elapsed += dt
			local _, r = characterParts(player)
			if not r then
				break
			end
			for _, rec in EnemyService.alongSegment(last, r.Position, move.radius) do
				if not hit[rec] then
					hit[rec] = true
					if CombatService.dealDamage(player, rec, move.dmg, { stun = move.stun, fromPosition = r.Position }) > 0 then
						hitAny = true
					end
				end
			end
			last = r.Position
		end
	elseif move.hit == "projectile" then
		local spawnAt = origin + Vector3.new(0, 1.2, 0) + flat(aim).Unit * 2
		ProjectileService.fire({
			team = "player",
			origin = spawnAt,
			direction = aim,
			speed = move.speed,
			range = move.range,
			radius = move.radius,
			pierce = move.pierce,
			aoe = move.aoe,
			style = move.style,
			onHitEnemy = function(rec)
				CombatService.dealDamage(player, rec, move.dmg, { fromPosition = spawnAt })
				if isFinisher then
					CombatService.QuestHook(player, "finisher", nil, 1)
				end
			end,
			onExplode = function(position)
				Remotes.Fx:FireAllClients("explosion", position, move.aoe, move.style)
				for _, rec in EnemyService.inRadius(position, move.aoe) do
					CombatService.dealDamage(player, rec, move.dmg, { fromPosition = position })
				end
			end,
		})
	end

	if hitAny and isFinisher then
		CombatService.QuestHook(player, "finisher", nil, 1)
	end
end

-- comboIndex = 0 significa ataque pesado
function CombatService.attack(player, comboIndex, aim)
	local _, root = characterParts(player)
	if not root then
		return
	end
	CombatService.BeforeAction(player)
	local stats = PlayerService.getStats(player)
	local style = WeaponStyles.get(stats.weaponType)
	local now = os.clock()
	if now < (nextAttackAt[player] or 0) - 0.1 then
		return
	end

	local move, isFinisher
	if comboIndex == 0 then
		move = style.heavy
		if (move.masteryReq or 0) > stats.masteryLevel then
			Remotes.Notify:FireClient(player, { kind = "message", text = ("Ataque pesado destrava na maestria %d."):format(move.masteryReq) })
			return
		end
		if not PlayerService.spendStamina(player, move.stamina or 0) then
			Remotes.Fx:FireClient(player, "noStamina")
			return
		end
		isFinisher = false
	else
		local index = math.clamp(math.floor(tonumber(comboIndex) or 1), 1, #style.combo)
		move = style.combo[index]
		if (move.masteryReq or 0) > stats.masteryLevel then
			move = style.combo[1]
			index = 1
		end
		isFinisher = index == #style.combo and #style.combo > 1
	end

	local speed = stats.attackSpeed
	nextAttackAt[player] = now + move.duration / speed
	aim = validAim(aim, root)
	if not style.ranged then
		local horizontal = flat(aim)
		aim = if horizontal.Magnitude > 0.01 then horizontal.Unit else flat(root.CFrame.LookVector).Unit
	end
	Remotes.Fx:FireAllClients("swing", player, move.pose, move.duration / speed, comboIndex == 0)
	task.delay(move.windup / speed, resolveMove, player, move, aim, isFinisher)
end

function CombatService.dodge(player)
	local _, root = characterParts(player)
	if not root then
		return
	end
	local now = os.clock()
	if now < (nextDodgeAt[player] or 0) then
		return
	end
	if not PlayerService.spendStamina(player, Config.DodgeCost) then
		Remotes.Fx:FireClient(player, "noStamina")
		return
	end
	CombatService.BeforeAction(player)
	nextDodgeAt[player] = now + Config.DodgeCooldown
	PlayerService.grantIFrames(player, Config.DodgeIFrames)
	Remotes.Fx:FireAllClients("dodge", player)
	CombatService.QuestHook(player, "dodge", nil, 1)
end

function CombatService.release(player)
	nextAttackAt[player] = nil
	nextDodgeAt[player] = nil
end

Players.PlayerRemoving:Connect(CombatService.release)

return CombatService
