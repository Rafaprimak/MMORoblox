-- Animações procedurais dos personagens (golpes, magias, esquiva, guarda, montaria).
-- Gira as juntas (Motor6D.Transform) por cima das animações padrão do Roblox, sem arquivos de animação.
-- Para ficar fluido:
--   • quadros-chave com antecipação → golpe (com exagero) → acompanhamento → volta, interpolados com
--     "smootherstep" e giro esférico (CFrame:Lerp);
--   • crossfade: cada pose nova parte da última pose aplicada, e ao terminar volta suavemente ao neutro;
--   • camadas por cima: postura de combate pela arma, respiração, inclinação ao correr, tranco ao levar
--     dano e galope na montaria (cavalo com juntas animadas).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Animator = {}

local function R(x, y, z)
	return CFrame.Angles(math.rad(x or 0), math.rad(y or 0), math.rad(z or 0))
end

-- 6t^5 - 15t^4 + 10t^3: começa e termina sem tranco
local function smoother(t)
	return t * t * t * (t * (t * 6 - 15) + 10)
end

local function easeOut(t)
	return 1 - (1 - t) * (1 - t)
end

local FADE_IN = 0.07
local FADE_OUT = 0.16

-- Cada pose é uma lista de quadros { t, juntas }. Juntas: RS/RE (ombro/cotovelo dir.), LS/LE, W (cintura),
-- N (pescoço), RT (raiz/quadril), RH/LH (coxas), RK/LK (joelhos)
local POSES = {
	-- corte da direita para a esquerda
	slashA = {
		{ 0, {} },
		{ 0.24, { RS = R(110, 0, 78), RE = R(35), LS = R(25, 0, -18), W = R(0, -48, 0), RT = R(5, 10, 0), RH = R(-12), LH = R(18), LK = R(-18) } },
		{ 0.42, { RS = R(88, 0, -58), RE = R(4), LS = R(18, 0, 12), W = R(0, 52, 0), RT = R(-9, -12, 0), RH = R(24), RK = R(-24), LH = R(-14) } },
		{ 0.62, { RS = R(76, 0, -46), RE = R(14), W = R(0, 40, 0), RT = R(-6, -8, 0), RH = R(16), RK = R(-16) } },
		{ 1, {} },
	},
	-- corte de volta (esquerda para a direita)
	slashB = {
		{ 0, {} },
		{ 0.24, { RS = R(72, 0, -50), RE = R(40), LS = R(20, 0, 15), W = R(0, 42, 0), RT = R(4, -8, 0), LH = R(-12), RH = R(15), RK = R(-15) } },
		{ 0.42, { RS = R(104, 0, 80), RE = R(6), LS = R(25, 0, -20), W = R(0, -50, 0), RT = R(-8, 12, 0), LH = R(22), LK = R(-22), RH = R(-12) } },
		{ 0.62, { RS = R(94, 0, 68), RE = R(16), W = R(0, -38, 0), RT = R(-5, 8, 0), LH = R(14), LK = R(-14) } },
		{ 1, {} },
	},
	-- estocada com passo à frente
	thrust = {
		{ 0, {} },
		{ 0.28, { RS = R(50, 0, -10), RE = R(105), LS = R(30, 0, 20), W = R(0, -32, 0), RT = R(6), LH = R(-10), RH = R(10) } },
		{ 0.46, { RS = R(94, 0, 0), RE = R(-2), LS = R(-30, 0, 15), W = R(0, 16, 0), RT = R(-16), RH = R(38), RK = R(-38), LH = R(-22) } },
		{ 0.66, { RS = R(86), RE = R(8), LS = R(-20, 0, 10), W = R(0, 10, 0), RT = R(-11), RH = R(28), RK = R(-28), LH = R(-15) } },
		{ 1, {} },
	},
	stab = {
		{ 0, {} },
		{ 0.26, { RS = R(35, 0, 18), RE = R(90), W = R(0, -15, 0), RT = R(4) } },
		{ 0.44, { RS = R(92, 0, -12), RE = R(-2), W = R(0, 12, 0), RT = R(-10), RH = R(20), RK = R(-20) } },
		{ 0.62, { RS = R(84, 0, -8), RE = R(8), RT = R(-7), RH = R(14), RK = R(-14) } },
		{ 1, {} },
	},
	-- golpe de cima para baixo com as duas mãos
	overhead = {
		{ 0, {} },
		{ 0.32, { RS = R(172, 0, 12), RE = R(25), LS = R(158, 0, -12), LE = R(25), RT = R(12), N = R(16), RH = R(-6), LH = R(-6) } },
		{ 0.48, { RS = R(40), RE = R(5), LS = R(36), LE = R(5), RT = R(-22), N = R(-8), RH = R(36), LH = R(-16), RK = R(-40) } },
		{ 0.68, { RS = R(30), LS = R(28), RT = R(-16), RH = R(28), RK = R(-32), LH = R(-10) } },
		{ 1, {} },
	},
	-- salto e pancada no chão
	slam = {
		{ 0, {} },
		{ 0.38, { RS = R(176, 0, 22), LS = R(176, 0, -22), RE = R(20), LE = R(20), RT = R(14), RH = R(30), LH = R(30), RK = R(-40), LK = R(-40), N = R(15) } },
		{ 0.56, { RS = R(18), LS = R(18), RT = R(-26), RH = R(58), LH = R(58), RK = R(-72), LK = R(-72), N = R(-10) } },
		{ 0.74, { RS = R(14), LS = R(14), RT = R(-20), RH = R(46), LH = R(46), RK = R(-58), LK = R(-58) } },
		{ 1, {} },
	},
	-- puxar a corda, segurar e soltar (com recuo)
	bow = {
		{ 0, {} },
		{ 0.3, { LS = R(90, 0, -4), RS = R(92, 0, -38), RE = R(118), W = R(0, 28, 0), N = R(0, -12, 0), RT = R(0, 6, 0) } },
		{ 0.62, { LS = R(90, 0, -2), RS = R(90, 0, -40), RE = R(125), W = R(0, 30, 0), N = R(0, -14, 0) } },
		{ 0.72, { LS = R(96, 0, 0), RS = R(70, 0, -5), RE = R(40), W = R(0, 22, 0), RT = R(4) } },
		{ 1, {} },
	},
	bowUp = {
		{ 0, {} },
		{ 0.36, { LS = R(152), RS = R(142, 0, -28), RE = R(88), RT = R(12), N = R(22) } },
		{ 0.7, { LS = R(156), RS = R(128, 0, -8), RE = R(30), RT = R(10), N = R(20) } },
		{ 1, {} },
	},
	-- magia com uma mão
	cast = {
		{ 0, {} },
		{ 0.3, { RS = R(135, 0, 20), RE = R(30), W = R(0, -20, 0), RT = R(4), LS = R(15, 0, -10) } },
		{ 0.48, { RS = R(98, 0, -5), RE = R(-2), W = R(0, 14, 0), RT = R(-8), RH = R(15), RK = R(-15) } },
		{ 0.7, { RS = R(92), RE = R(5), W = R(0, 10, 0), RT = R(-6), RH = R(10), RK = R(-10) } },
		{ 1, {} },
	},
	castB = {
		{ 0, {} },
		{ 0.3, { LS = R(135, 0, -20), LE = R(30), W = R(0, 20, 0), RT = R(4) } },
		{ 0.48, { LS = R(98, 0, 5), LE = R(-2), W = R(0, -14, 0), RT = R(-8), LH = R(15), LK = R(-15) } },
		{ 0.7, { LS = R(92), LE = R(5), W = R(0, -10, 0), RT = R(-6) } },
		{ 1, {} },
	},
	-- magia grande: junta energia no alto e lança para a frente
	castBig = {
		{ 0, {} },
		{ 0.4, { RS = R(172, 0, 28), LS = R(172, 0, -28), RE = R(15), LE = R(15), RT = R(14), N = R(24), RH = R(-6), LH = R(-6) } },
		{ 0.56, { RS = R(96, 0, 12), LS = R(96, 0, -12), RT = R(-12), N = R(-4), RH = R(24), RK = R(-28), LH = R(-10) } },
		{ 0.76, { RS = R(88, 0, 8), LS = R(88, 0, -8), RT = R(-9), RH = R(18), RK = R(-22) } },
		{ 1, {} },
	},
	-- guarda (segurando F): braços à frente cruzando a arma, base firme
	block = {
		{ 0, {} },
		{ 1, { RS = R(98, 0, -42), RE = R(60), LS = R(92, 0, 42), LE = R(68), W = R(0, -14, 0), RT = R(-6), RH = R(14), RK = R(-18), LH = R(-6), N = R(-6) } },
	},
	-- carregando o golpe pesado (segurando R): arma bem para trás, peso na perna de trás
	charge = {
		{ 0, {} },
		{ 1, { RS = R(162, 0, 48), RE = R(25), LS = R(45, 0, -25), LE = R(20), W = R(0, -50, 0), RT = R(10, 8, 0), RH = R(20), RK = R(-22), LH = R(-14), N = R(0, 20, 0) } },
	},
	-- grito: peito para fora, braços abertos
	roar = {
		{ 0, {} },
		{ 0.18, { RS = R(30, 0, 20), LS = R(30, 0, -20), RT = R(-10), RH = R(20), LH = R(20), RK = R(-25), LK = R(-25), N = R(-10) } },
		{ 0.38, { RS = R(122, 0, 75), LS = R(122, 0, -75), RT = R(14), N = R(28), RH = R(-4), LH = R(-4) } },
		{ 0.75, { RS = R(118, 0, 70), LS = R(118, 0, -70), RT = R(12), N = R(24) } },
		{ 1, {} },
	},
}

-- Poses calculadas (giro completo, rolamento)
local FUNCTION_POSES = {
	spin = function(t)
		local e = smoother(t)
		local crouch = math.sin(t * math.pi)
		return {
			W = R(0, -360 * e, 0),
			RS = R(85, 0, 85),
			LS = R(60, 0, -60),
			RT = R(-10 * crouch),
			RH = R(20 * crouch),
			LH = R(20 * crouch),
			RK = R(-28 * crouch),
			LK = R(-28 * crouch),
		}
	end,
	dodge = function(t)
		local e = smoother(t)
		local tuck = math.sin(t * math.pi)
		return {
			RT = R(-360 * e),
			RH = R(95 * tuck),
			LH = R(95 * tuck),
			RK = R(-110 * tuck),
			LK = R(-110 * tuck),
			RS = R(70 * tuck, 0, 20 * tuck),
			LS = R(70 * tuck, 0, -20 * tuck),
			RE = R(60 * tuck),
			LE = R(60 * tuck),
			N = R(30 * tuck),
		}
	end,
}

-- Postura de combate por tipo de arma (camada leve por cima do andar padrão)
local STANCES = {
	sword = { RS = R(28, 0, -12), RE = R(38), LS = R(18, 0, 12), LE = R(20), RT = R(-3) },
	katana = { RS = R(34, 0, -24), RE = R(68), LS = R(30, 0, 18), LE = R(45), RT = R(-5), W = R(0, -8, 0) },
	dagger = { RS = R(32, 0, -18), RE = R(72), LS = R(28, 0, 16), LE = R(55), RT = R(-6) },
	axe = { RS = R(36, 0, -26), RE = R(48), LS = R(40, 0, 30), LE = R(52), RT = R(-4) },
	hammer = { RS = R(38, 0, -28), RE = R(50), LS = R(42, 0, 32), LE = R(54), RT = R(-5) },
	spear = { RS = R(42, 0, -16), RE = R(62), LS = R(52, 0, 26), LE = R(32), RT = R(-4), W = R(0, -10, 0) },
	-- cajado em pé ao lado do corpo: braço quase reto (o antebraço dobrado deitava o cajado)
	staff = { RS = R(14, 0, -12), RE = R(8), LS = R(12, 0, 10), RT = R(-2) },
	bow = { LS = R(22, 0, 4), RS = R(14, 0, -6), RT = R(-2) },
}

local JOINTS = {
	RS = { "RightUpperArm", "RightShoulder" },
	RE = { "RightLowerArm", "RightElbow" },
	LS = { "LeftUpperArm", "LeftShoulder" },
	LE = { "LeftLowerArm", "LeftElbow" },
	W = { "UpperTorso", "Waist" },
	N = { "Head", "Neck" },
	RT = { "LowerTorso", "Root" },
	RH = { "RightUpperLeg", "RightHip" },
	LH = { "LeftUpperLeg", "LeftHip" },
	RK = { "RightLowerLeg", "RightKnee" },
	LK = { "LeftLowerLeg", "LeftKnee" },
}

local states = setmetatable({}, { __mode = "k" }) -- [character] = estado de animação
local motorCache = setmetatable({}, { __mode = "k" })

local function motors(character)
	local cached = motorCache[character]
	if cached and cached.RS and cached.RS.Parent then
		return cached
	end
	local result = {}
	for key, path in JOINTS do
		local part = character:FindFirstChild(path[1])
		local motor = part and part:FindFirstChild(path[2])
		if motor and motor:IsA("Motor6D") then
			result[key] = motor
		end
	end
	motorCache[character] = result
	return result
end

local function stateOf(character)
	local s = states[character]
	if not s then
		s = { job = nil, applied = {}, from = nil, fadeStart = 0, fadeDuration = 0, stance = 0, combatUntil = 0, lean = CFrame.identity, flinchStart = -10, flinchPower = 0, gallop = 0 }
		states[character] = s
	end
	return s
end

local function samplePose(name, t)
	local fn = FUNCTION_POSES[name]
	if fn then
		return fn(t)
	end
	local frames = POSES[name]
	if not frames then
		return {}
	end
	local previous, nextFrame = frames[1], frames[#frames]
	for i = 1, #frames - 1 do
		if t >= frames[i][1] and t <= frames[i + 1][1] then
			previous, nextFrame = frames[i], frames[i + 1]
			break
		end
	end
	local span = nextFrame[1] - previous[1]
	local alpha = if span > 0 then smoother(math.clamp((t - previous[1]) / span, 0, 1)) else 1
	local result = {}
	for key, cf in previous[2] do
		result[key] = cf:Lerp(nextFrame[2][key] or CFrame.identity, alpha)
	end
	for key, cf in nextFrame[2] do
		if not result[key] then
			result[key] = CFrame.identity:Lerp(cf, alpha)
		end
	end
	return result
end

-- Liga o rastro da arma durante o golpe
local function setTrail(character, enabled)
	local weapon = character:FindFirstChild("Arma")
	local handle = weapon and weapon.PrimaryPart
	local trail = handle and handle:FindFirstChild("Rastro")
	if trail then
		trail.Enabled = enabled
	end
	local sparks = handle and handle:FindFirstChild("FaiscasGolpe", true)
	if sparks then
		sparks.Enabled = enabled
	end
end

-- começa um crossfade a partir do que está aplicado agora
local function beginFade(s, duration)
	s.from = table.clone(s.applied)
	s.fadeStart = os.clock()
	s.fadeDuration = duration
end

function Animator.play(character, poseName, duration, withTrail)
	if not character or not poseName then
		return
	end
	local s = stateOf(character)
	if s.job and s.job.trail and not withTrail then
		setTrail(character, false)
	end
	beginFade(s, FADE_IN)
	s.job = { pose = poseName, start = os.clock(), duration = math.max(duration or 0.4, 0.1), trail = withTrail }
	s.combatUntil = os.clock() + 5
	if withTrail then
		setTrail(character, true)
	end
end

-- Mantém uma pose parada (guarda, carregar golpe) até chamar Animator.stop
function Animator.hold(character, poseName, t)
	if not character or not poseName then
		return
	end
	local s = stateOf(character)
	beginFade(s, 0.12)
	s.job = { pose = poseName, start = os.clock(), duration = 1, hold = true, t = t or 1 }
	s.combatUntil = os.clock() + 5
end

function Animator.stop(character)
	local s = character and states[character]
	if s and s.job and s.job.hold then
		beginFade(s, FADE_OUT)
		s.job = nil
	end
end

-- tranco ao levar dano
function Animator.flinch(character, power)
	if not character then
		return
	end
	local s = stateOf(character)
	s.flinchStart = os.clock()
	s.flinchPower = math.clamp(power or 1, 0.3, 1.5)
	s.combatUntil = os.clock() + 5
end

-- marca "em combate" (postura de luta por alguns segundos)
function Animator.combat(character)
	if character then
		stateOf(character).combatUntil = os.clock() + 5
	end
end

function Animator.holdForPlayer(player, poseName, t)
	if player and player.Character then
		Animator.hold(player.Character, poseName, t)
	end
end

function Animator.stopForPlayer(player)
	if player and player.Character then
		Animator.stop(player.Character)
	end
end

function Animator.playForPlayer(player, poseName, duration, withTrail)
	if player and player.Character then
		Animator.play(player.Character, poseName, duration, withTrail)
	end
end

-- ===================== MONTARIA =====================

-- Cavalo: juntas Motor6D criadas pelo servidor ("JuntaPernaFL", "JuntaCabeca", "JuntaCauda"...)
local function animateHorse(character, s, dt)
	local mount = character:FindFirstChild("Montaria")
	local horse = mount and mount:FindFirstChild("Cavalo")
	local body = horse and horse:FindFirstChild("Corpo")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not body or not root then
		return 0
	end
	local velocity = root.AssemblyLinearVelocity
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local amount = math.clamp(speed / 40, 0, 1)
	s.gallop += dt * (4 + speed * 0.32)
	local phase = s.gallop
	local swing = math.sin(phase) * 38 * amount
	local swing2 = math.sin(phase + math.pi * 0.85) * 38 * amount
	for _, joint in body:GetChildren() do
		if joint:IsA("Motor6D") then
			local name = joint.Name
			if name == "JuntaPernaFL" or name == "JuntaPernaBR" then
				joint.Transform = R(swing, 0, 0)
			elseif name == "JuntaPernaFR" or name == "JuntaPernaBL" then
				joint.Transform = R(swing2, 0, 0)
			elseif name == "JuntaCabeca" then
				joint.Transform = R(math.sin(phase * 2) * 7 * amount + math.sin(os.clock() * 1.3) * 3 * (1 - amount), 0, 0)
			elseif name == "JuntaCauda" then
				joint.Transform = R(-20 * amount, math.sin(os.clock() * 3) * 15, 0)
			end
		end
	end
	return amount, phase
end

local MOUNTED = { RH = R(75, 0, 18), LH = R(75, 0, -18), RK = R(-75), LK = R(-75), RS = R(25), LS = R(25) }

-- ===================== LAÇO PRINCIPAL =====================

local function update(player, character, now, dt)
	local s = stateOf(character)
	local m = motors(character)
	local target = {}

	-- 1) golpe/magia ou pose segurada
	local job = s.job
	if job then
		if job.hold then
			for key, cf in samplePose(job.pose, job.t) do
				target[key] = cf
			end
		else
			local t = (now - job.start) / job.duration
			if t >= 1 then
				s.job = nil
				if job.trail then
					setTrail(character, false)
				end
				beginFade(s, FADE_OUT)
			else
				for key, cf in samplePose(job.pose, t) do
					target[key] = cf
				end
			end
		end
	end

	local mounted = player:GetAttribute("Mounted") == true
	local root = character:FindFirstChild("HumanoidRootPart")

	-- 2) montaria: pernas do cavaleiro + balanço do galope
	if mounted then
		local amount, phase = animateHorse(character, s, dt)
		if not s.job then
			for key, cf in MOUNTED do
				target[key] = cf
			end
			local bob = math.abs(math.sin(phase or 0)) * 0.35 * (amount or 0)
			target.RT = CFrame.new(0, bob, 0) * R(-8 * (amount or 0))
			target.N = R(6 * (amount or 0))
		end
	elseif root then
		-- 3) postura de combate (entra e sai suave) + respiração
		local inCombat = now < s.combatUntil
		s.stance += ((if inCombat then 1 else 0) - s.stance) * math.min(1, dt * 5)
		local stance = STANCES[player:GetAttribute("WeaponType") or "sword"]
		if stance and s.stance > 0.01 and not s.job then
			for key, cf in stance do
				target[key] = CFrame.identity:Lerp(cf, s.stance)
			end
		end
		local breath = math.sin(now * 2.1) * (0.8 + s.stance)
		target.W = (target.W or CFrame.identity) * R(breath)
		-- 4) inclina para a frente correndo
		local velocity = root.AssemblyLinearVelocity
		local flatVelocity = Vector3.new(velocity.X, 0, velocity.Z)
		local forward = root.CFrame.LookVector:Dot(flatVelocity)
		local side = root.CFrame.RightVector:Dot(flatVelocity)
		local goal = R(-math.clamp(forward / 27, -0.5, 1) * 9, 0, -math.clamp(side / 27, -1, 1) * 5)
		s.lean = s.lean:Lerp(goal, math.min(1, dt * 8))
		target.RT = (target.RT or CFrame.identity) * s.lean
	end

	-- 5) tranco ao levar dano (decai em 0,3s)
	local flinchT = (now - s.flinchStart) / 0.3
	if flinchT < 1 then
		local k = (1 - easeOut(flinchT)) * s.flinchPower
		target.W = (target.W or CFrame.identity) * R(14 * k, 0, 4 * k)
		target.N = (target.N or CFrame.identity) * R(12 * k)
		target.RT = (target.RT or CFrame.identity) * R(6 * k)
	end

	-- crossfade a partir da última pose aplicada
	local fadeAlpha = 1
	if s.from and s.fadeDuration > 0 then
		fadeAlpha = math.clamp((now - s.fadeStart) / s.fadeDuration, 0, 1)
		if fadeAlpha >= 1 then
			s.from = nil
		else
			fadeAlpha = smoother(fadeAlpha)
		end
	end
	local applied = {}
	for key, motor in m do
		local goal = target[key]
		local from = s.from and s.from[key]
		local offset
		if from then
			offset = from:Lerp(goal or CFrame.identity, fadeAlpha)
		else
			offset = goal
		end
		if offset then
			motor.Transform = motor.Transform * offset
			applied[key] = offset
		end
	end
	s.applied = applied
end

function Animator.init()
	RunService.Stepped:Connect(function(_, dt)
		local now = os.clock()
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 then
				update(player, character, now, dt)
			end
		end
	end)
end

return Animator
