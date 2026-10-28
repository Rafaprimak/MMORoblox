-- Ataques do jogador: combos com ritmo, ataque pesado carregável, esquiva e cálculo de dano/postura.
--
-- Regras do combate dinâmico:
--   * Cada golpe custa estamina (spam esgota a estamina que você precisa para esquivar e bloquear).
--   * O combo só avança se o próximo clique vier no tempo certo; no "Ritmo" (logo após o golpe terminar)
--     ganha bônus de dano e postura. Quem clica cedo demais quebra o combo (controlado no cliente).
--   * Golpes enchem a postura do inimigo; postura cheia = guarda quebrada (atordoado, +50% de dano).
--   * Depois de aparar (F na hora certa), o próximo golpe é crítico e quebra o dobro de postura.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local WeaponStyles = require(Shared.WeaponStyles)
local Remotes = require(Shared.Remotes)

local PlayerService = require(script.Parent.PlayerService)
local SkillService = require(script.Parent.SkillService)
local EnemyService = require(script.Parent.EnemyService)
local PerkService = require(script.Parent.PerkService)
local ProjectileService = require(script.Parent.ProjectileService)

local CombatService = {}

-- Ganchos preenchidos pelo init
CombatService.QuestHook = function(_player, _kind, _target, _amount) end
CombatService.BeforeAction = function(_player) end -- desmonta do cavalo etc.

local combo = {} -- [player] = { index, endAt }
local nextDodgeAt = {}
local chargeStart = {}

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

-- Dano de um golpe/habilidade em um inimigo. mult = multiplicador do golpe.
-- info: knockback, stun, fromPosition, color, dot, ability, posture (multiplicador de postura), rhythm, riposte
function CombatService.dealDamage(player, rec, mult, info)
	info = info or {}
	local stats = PlayerService.getStats(player)
	local s = PlayerService.getState(player)
	local style = WeaponStyles.get(stats.weaponType)
	local crit = info.forceCrit or info.riposte or math.random() < stats.crit
	if s and s.nextCrit and not info.dot then
		crit = true
		s.nextCrit = false
	elseif s and (s.critCharges or 0) > 0 and not info.dot then
		crit = true -- exótico Passos do Tempo
		s.critCharges -= 1
	end
	local damage = stats.attack * stats.damageMult * mult * (0.9 + math.random() * 0.2) * (1 + PlayerService.buffValue(player, "damage"))
	if crit then
		damage *= stats.critMult
	end
	if info.rhythm then
		damage *= 1 + Config.RhythmBonus
	end
	-- adagas: bônus pelas costas
	local bonus = stats.bonus or {}
	if style.backstab and info.fromPosition and not info.ability then
		local enemyLook = Vector3.new(-math.sin(rec.yaw), 0, -math.cos(rec.yaw))
		local toAttacker = flat(info.fromPosition - rec.pos)
		if toAttacker.Magnitude > 0.1 and enemyLook:Dot(toAttacker.Unit) < -0.3 then
			damage *= 1 + style.backstab + (bonus.backstab or 0)
			info.color = Color3.fromRGB(200, 120, 255)
		end
	end
	-- postura: proporcional ao golpe e ao peso da arma (martelo quebra guarda rápido, adaga devagar)
	local posture = 0
	if not info.dot then
		posture = Config.PostureBase * mult * (info.posture or 1) * (if info.ability then 1 else style.posture or 1)
		posture *= (1 + stats.masteryLevel * 0.01) * (1 + (bonus.posture or 0))
		if info.rhythm then
			posture *= 1 + Config.RhythmBonus
		end
		if info.riposte then
			posture *= 2
		end
	end
	-- perks da arma e das peças (Fúria Crescente, Carrasco, Contragolpe...)
	local postureMult
	damage, postureMult = PerkService.modify(player, rec, damage, info, stats)
	posture *= postureMult
	local dealt = EnemyService.damage(rec, damage, player, {
		crit = crit,
		knockback = info.knockback,
		stun = info.stun,
		fromPosition = info.fromPosition,
		color = info.color,
		dot = info.dot,
		posture = posture,
		element = info.element or (if stats.burn > 0 then "fire" elseif stats.lifesteal > 0 then "blood" else nil),
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
		PerkService.afterHit(player, rec, dealt, info, stats, crit)
		if not info.ability then
			SkillService.addXP(player, stats.masteryId, if crit then 4 else 3)
		end
		PlayerService.markCombat(player)
	end
	return dealt
end

-- Resolve o efeito de um golpe (depois do tempo de preparação)
local function resolveMove(player, move, aim, extra)
	local _, root = characterParts(player)
	if not root then
		return
	end
	local origin = root.Position
	local hitAny = false
	local mult = move.dmg * (extra.damageMult or 1)
	local riposte = PlayerService.consumeRiposte(player)
	local info = {
		knockback = move.knockback,
		stun = move.stun,
		fromPosition = origin,
		posture = extra.postureMult,
		rhythm = extra.rhythm,
		riposte = riposte,
	}

	local function hitList(list)
		for _, rec in list do
			if CombatService.dealDamage(player, rec, mult, info) > 0 then
				hitAny = true
			end
		end
	end

	if move.hit == "cone" then
		hitList(EnemyService.inCone(origin, aim, move.range, move.arc, nil, player))
	elseif move.hit == "circle" then
		local center = origin + flat(aim).Unit * move.offset
		Remotes.Fx:FireAllClients("explosion", center - Vector3.new(0, 2.5, 0), move.radius, "earth")
		hitList(EnemyService.inRadius(center, move.radius, nil, player))
	elseif move.hit == "nova" then
		local ticks = move.ticks or 1
		Remotes.Fx:FireAllClients("explosion", origin - Vector3.new(0, 2.5, 0), move.radius, move.style or "slash")
		for i = 1, ticks do
			local _, r = characterParts(player)
			if not r then
				break
			end
			hitList(EnemyService.inRadius(r.Position, move.radius, nil, player))
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
			for _, rec in EnemyService.alongSegment(last, r.Position, move.radius, player) do
				if not hit[rec] then
					hit[rec] = true
					info.fromPosition = r.Position
					if CombatService.dealDamage(player, rec, mult, info) > 0 then
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
			owner = player,
			origin = spawnAt,
			direction = aim,
			speed = move.speed,
			range = move.range,
			radius = move.radius,
			pierce = move.pierce,
			aoe = move.aoe,
			style = move.style,
			onHitEnemy = function(rec)
				CombatService.dealDamage(player, rec, mult, info)
				if extra.finisher then
					CombatService.QuestHook(player, "finisher", nil, 1)
				end
			end,
			onExplode = function(position)
				Remotes.Fx:FireAllClients("explosion", position, move.aoe, move.style)
				for _, rec in EnemyService.inRadius(position, move.aoe, nil, player) do
					CombatService.dealDamage(player, rec, mult, info)
				end
			end,
		})
	end

	if hitAny and extra.finisher then
		CombatService.QuestHook(player, "finisher", nil, 1)
	end
end

local function begin(player, move, aim, extra)
	local _, root = characterParts(player)
	local stats = PlayerService.getStats(player)
	local style = WeaponStyles.get(stats.weaponType)
	aim = validAim(aim, root)
	if not style.ranged then
		local horizontal = flat(aim)
		aim = if horizontal.Magnitude > 0.01 then horizontal.Unit else flat(root.CFrame.LookVector).Unit
	end
	local duration = move.duration / stats.attackSpeed
	Remotes.Fx:FireAllClients("swing", player, move.pose, duration, extra.heavy == true)
	if extra.rhythm then
		Remotes.Fx:FireClient(player, "rhythm")
	end
	task.delay(move.windup / stats.attackSpeed, resolveMove, player, move, aim, extra)
	return duration
end

-- Interrompe o jogador por "seconds" (ninguém ataca até lá). Usado quando um golpe é aparado na arena.
function CombatService.interrupt(player, seconds)
	combo[player] = { index = 0, endAt = os.clock() + seconds }
	chargeStart[player] = nil
end

-- Golpe leve. O servidor decide o índice do combo pelo tempo (o cliente só sugere).
function CombatService.attack(player, requestedIndex, aim)
	local _, root = characterParts(player)
	if not root then
		return
	end
	CombatService.BeforeAction(player)
	PlayerService.setBlocking(player, false)
	local stats = PlayerService.getStats(player)
	local style = WeaponStyles.get(stats.weaponType)
	local now = os.clock()
	local state = combo[player] or { index = 0, endAt = 0 }
	if now < state.endAt - 0.08 then
		return -- ainda no golpe anterior
	end

	-- avança o combo só se o clique veio dentro da janela e na sequência certa
	local onTime = now <= state.endAt + Config.ComboWindow
	local expected = state.index % #style.combo + 1
	local index = if onTime and tonumber(requestedIndex) == expected then expected else 1
	local move = style.combo[index]
	if (move.masteryReq or 0) > stats.masteryLevel then
		index = 1
		move = style.combo[1]
	end
	if not PlayerService.spendStamina(player, move.stamina or 0) then
		Remotes.Fx:FireClient(player, "noStamina")
		return
	end
	local rhythm = index > 1 and now <= state.endAt + Config.RhythmWindow
	local duration = begin(player, move, aim, {
		rhythm = rhythm,
		finisher = index == #style.combo and #style.combo > 1,
	})
	combo[player] = { index = index, endAt = now + duration }
	if rhythm then
		CombatService.QuestHook(player, "rhythm", nil, 1)
	end
end

-- Ataque pesado: começa a carregar ao apertar R e solta ao largar
function CombatService.heavyStart(player)
	local stats = PlayerService.getStats(player)
	local style = WeaponStyles.get(stats.weaponType)
	if (style.heavy.masteryReq or 0) > stats.masteryLevel then
		Remotes.Notify:FireClient(player, { kind = "message", text = ("Ataque pesado destrava na maestria %d da arma."):format(style.heavy.masteryReq) })
		return
	end
	PlayerService.setBlocking(player, false)
	chargeStart[player] = os.clock()
	Remotes.Fx:FireAllClients("charge", player, true)
end

function CombatService.heavyRelease(player, aim)
	local started = chargeStart[player]
	chargeStart[player] = nil
	Remotes.Fx:FireAllClients("charge", player, false)
	local _, root = characterParts(player)
	if not started or not root then
		return
	end
	local stats = PlayerService.getStats(player)
	local style = WeaponStyles.get(stats.weaponType)
	local move = style.heavy
	local now = os.clock()
	local state = combo[player] or { index = 0, endAt = 0 }
	if now < state.endAt - 0.08 then
		return
	end
	local charge = math.clamp((now - started) / Config.HeavyChargeTime, 0, 1)
	local cost = (move.stamina or 0) * (1 + charge * 0.5)
	if not PlayerService.spendStamina(player, cost) then
		Remotes.Fx:FireClient(player, "noStamina")
		return
	end
	CombatService.BeforeAction(player)
	local duration = begin(player, move, aim, {
		heavy = true,
		damageMult = (1 + charge) * (1 + (stats.bonus.heavyDamage or 0)),
		postureMult = 1.5 + charge * 2,
	})
	combo[player] = { index = 0, endAt = now + duration }
	if charge >= 0.95 then
		PerkService.onFullCharge(player, duration * 0.5)
		CombatService.QuestHook(player, "fullCharge", nil, 1)
	end
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
	chargeStart[player] = nil
	nextDodgeAt[player] = now + Config.DodgeCooldown
	PlayerService.grantIFrames(player, Config.DodgeIFrames)
	PlayerService.startDodge(player)
	-- esquivar cancela o golpe em andamento (permite reagir no meio do combo)
	combo[player] = { index = 0, endAt = 0 }
	Remotes.Fx:FireAllClients("dodge", player)
	CombatService.QuestHook(player, "dodge", nil, 1)
end

function CombatService.block(player, value)
	if value then
		CombatService.BeforeAction(player)
		chargeStart[player] = nil
	end
	PlayerService.setBlocking(player, value == true)
end

function CombatService.release(player)
	combo[player] = nil
	nextDodgeAt[player] = nil
	chargeStart[player] = nil
end

Players.PlayerRemoving:Connect(CombatService.release)

return CombatService
