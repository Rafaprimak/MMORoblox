-- Animações procedurais dos personagens: TUDO é calculado aqui, sem arquivos de animação.
-- As animações padrão do Roblox ficam desligadas (o script "Animate" do jogador local é parado) e
-- este módulo escreve todas as juntas (.Transform) em RunService.Stepped. As juntas podem ser Motor6D (rig
-- antigo) ou AnimationConstraint ("Avatar Joint Upgrade", o padrão novo do Roblox): as duas têm Transform.
-- Camadas, de baixo para cima:
--   1) locomoção: parado (respiração, troca de peso, olhar), andar/correr com ciclo de passo
--      (contato → descida → passagem → subida), braços em contrabalanço, quadril girando para o lado
--      do movimento (andar de lado/de costas), pulo, queda, aterrissagem com amortecimento e nado;
--      montado: cavaleiro sentado que acompanha o galope do cavalo;
--   2) postura de combate pela arma (entra e sai suave);
--   3) golpe/magia (quadros-chave com antecipação → golpe seco → acompanhamento → volta). Andando,
--      o golpe vale só da cintura para cima e as pernas continuam o passo;
--   4) tranco ao levar dano e "congelamento" curto no impacto (hit-stop);
--   5) tornozelos: o pé fica plano no chão sozinho.
-- Referências: ciclo de passo de 4 poses, impacto com exagero + acomodação, hit-stop de 2-5 quadros,
-- passo de 4 tempos lateral e galope transverso do cavalo.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Animator = {}

local localPlayer = Players.LocalPlayer

local function R(x, y, z)
	return CFrame.Angles(math.rad(x or 0), math.rad(y or 0), math.rad(z or 0))
end

local function lerp(a, b, t)
	return a + (b - a) * t
end

-- 6t^5 - 15t^4 + 10t^3: começa e termina sem tranco
local function smoother(t)
	return t * t * t * (t * (t * 6 - 15) + 10)
end

local function easeOut(t)
	return 1 - (1 - t) * (1 - t)
end

-- curva de cada trecho entre quadros (o 3º campo do quadro diz como se chega nele)
local EASES = {
	smooth = smoother,
	snap = function(t) -- golpe: sai rápido e chega devagar (sensação de peso no impacto)
		local inv = 1 - t
		return 1 - inv * inv * inv * inv
	end,
	slowIn = function(t)
		return t * t * t
	end,
}

local FADE_IN = 0.07
local FADE_OUT = 0.18
local I = CFrame.identity

-- Cada pose é uma lista de quadros { t, juntas, curva }. Juntas: RS/RE (ombro/cotovelo dir.), LS/LE,
-- W (cintura), N (pescoço), RT (raiz/quadril), RH/LH (coxas), RK/LK (joelhos). Os golpes são somados
-- por cima da locomoção. Quadro com "snap" = o golpe em si.
local POSES = {
	-- corte da direita para a esquerda
	slashA = {
		{ 0, {} },
		{ 0.24, { RS = R(112, 0, 80), RE = R(38), LS = R(28, 0, -20), LE = R(20), W = R(0, -50, 0), N = R(0, 18, 0), RT = R(6, 12, 0), RH = R(-12), LH = R(18), LK = R(-20) } },
		{ 0.4, { RS = R(88, 0, -62), RE = R(2), LS = R(14, 0, 16), LE = R(30), W = R(0, 56, 0), N = R(0, -16, 0), RT = R(-10, -14, 0), RH = R(26), RK = R(-26), LH = R(-14) }, "snap" },
		{ 0.62, { RS = R(74, 0, -48), RE = R(14), LS = R(10, 0, 12), W = R(0, 42, 0), N = R(0, -10, 0), RT = R(-7, -9, 0), RH = R(18), RK = R(-18) } },
		{ 1, {} },
	},
	-- corte de volta (esquerda para a direita)
	slashB = {
		{ 0, {} },
		{ 0.24, { RS = R(70, 0, -54), RE = R(42), LS = R(22, 0, 16), W = R(0, 44, 0), N = R(0, -16, 0), RT = R(5, -9, 0), LH = R(-12), RH = R(15), RK = R(-15) } },
		{ 0.4, { RS = R(106, 0, 84), RE = R(4), LS = R(26, 0, -22), LE = R(25), W = R(0, -54, 0), N = R(0, 16, 0), RT = R(-9, 13, 0), LH = R(24), LK = R(-24), RH = R(-12) }, "snap" },
		{ 0.62, { RS = R(94, 0, 68), RE = R(16), W = R(0, -40, 0), N = R(0, 10, 0), RT = R(-6, 9, 0), LH = R(15), LK = R(-15) } },
		{ 1, {} },
	},
	-- estocada com passo à frente
	thrust = {
		{ 0, {} },
		{ 0.28, { RS = R(48, 0, -10), RE = R(110), LS = R(32, 0, 22), LE = R(30), W = R(0, -34, 0), N = R(0, 14, 0), RT = R(7), LH = R(-10), RH = R(10), RK = R(-12) } },
		{ 0.44, { RS = R(96, 0, 0), RE = R(-4), LS = R(-34, 0, 16), W = R(0, 18, 0), N = R(-4, -8, 0), RT = R(-18), RH = R(40), RK = R(-40), LH = R(-24) }, "snap" },
		{ 0.66, { RS = R(86), RE = R(8), LS = R(-22, 0, 10), W = R(0, 10, 0), RT = R(-12), RH = R(28), RK = R(-28), LH = R(-15) } },
		{ 1, {} },
	},
	stab = {
		{ 0, {} },
		{ 0.26, { RS = R(34, 0, 18), RE = R(95), LS = R(20, 0, -10), W = R(0, -16, 0), RT = R(5), RK = R(-8), LK = R(-8) } },
		{ 0.42, { RS = R(94, 0, -12), RE = R(-4), LS = R(-10, 0, 8), W = R(0, 14, 0), RT = R(-11), RH = R(22), RK = R(-22) }, "snap" },
		{ 0.62, { RS = R(84, 0, -8), RE = R(8), RT = R(-7), RH = R(14), RK = R(-14) } },
		{ 1, {} },
	},
	-- golpe de cima para baixo com as duas mãos (antecipação mais longa: arma pesada)
	overhead = {
		{ 0, {} },
		{ 0.34, { RS = R(174, 0, 12), RE = R(28), LS = R(160, 0, -12), LE = R(28), W = R(-6), RT = R(13), N = R(18), RH = R(-6), LH = R(-6), RK = R(-8), LK = R(-8) }, "slowIn" },
		{ 0.48, { RS = R(38), RE = R(4), LS = R(34), LE = R(4), W = R(8), RT = R(-24), N = R(-10), RH = R(38), LH = R(-16), RK = R(-42) }, "snap" },
		{ 0.7, { RS = R(30), LS = R(28), W = R(5), RT = R(-17), RH = R(28), RK = R(-32), LH = R(-10) } },
		{ 1, {} },
	},
	-- salto e pancada no chão
	slam = {
		{ 0, {} },
		{ 0.38, { RS = R(178, 0, 22), LS = R(178, 0, -22), RE = R(22), LE = R(22), RT = R(15), RH = R(32), LH = R(32), RK = R(-44), LK = R(-44), N = R(16) }, "slowIn" },
		{ 0.54, { RS = R(16), LS = R(16), W = R(10), RT = R(-28), RH = R(60), LH = R(60), RK = R(-76), LK = R(-76), N = R(-12) }, "snap" },
		{ 0.76, { RS = R(14), LS = R(14), W = R(6), RT = R(-20), RH = R(46), LH = R(46), RK = R(-58), LK = R(-58) } },
		{ 1, {} },
	},
	-- puxar a corda, segurar e soltar (com recuo)
	bow = {
		{ 0, {} },
		{ 0.3, { LS = R(90, 0, -4), RS = R(92, 0, -38), RE = R(118), W = R(0, 28, 0), N = R(0, -12, 0), RT = R(0, 6, 0), RK = R(-6), LK = R(-6) } },
		{ 0.62, { LS = R(90, 0, -2), RS = R(90, 0, -40), RE = R(126), W = R(0, 30, 0), N = R(0, -14, 0), RK = R(-8), LK = R(-8) } },
		{ 0.7, { LS = R(98, 0, 0), RS = R(66, 0, 8), RE = R(30), W = R(-4, 22, 0), RT = R(5) }, "snap" },
		{ 1, {} },
	},
	bowUp = {
		{ 0, {} },
		{ 0.36, { LS = R(152), RS = R(142, 0, -28), RE = R(88), RT = R(12), N = R(22), RK = R(-10), LK = R(-10) } },
		{ 0.62, { LS = R(156), RS = R(128, 0, -8), RE = R(30), RT = R(10), N = R(20) }, "snap" },
		{ 1, {} },
	},
	-- magia com uma mão
	cast = {
		{ 0, {} },
		{ 0.3, { RS = R(138, 0, 20), RE = R(32), W = R(0, -22, 0), N = R(0, 10, 0), RT = R(5), LS = R(15, 0, -10) } },
		{ 0.46, { RS = R(98, 0, -5), RE = R(-4), W = R(0, 15, 0), N = R(0, -6, 0), RT = R(-9), RH = R(16), RK = R(-16) }, "snap" },
		{ 0.7, { RS = R(92), RE = R(5), W = R(0, 10, 0), RT = R(-6), RH = R(10), RK = R(-10) } },
		{ 1, {} },
	},
	castB = {
		{ 0, {} },
		{ 0.3, { LS = R(138, 0, -20), LE = R(32), W = R(0, 22, 0), N = R(0, -10, 0), RT = R(5) } },
		{ 0.46, { LS = R(98, 0, 5), LE = R(-4), W = R(0, -15, 0), N = R(0, 6, 0), RT = R(-9), LH = R(16), LK = R(-16) }, "snap" },
		{ 0.7, { LS = R(92), LE = R(5), W = R(0, -10, 0), RT = R(-6) } },
		{ 1, {} },
	},
	-- magia grande: junta energia no alto e lança para a frente
	castBig = {
		{ 0, {} },
		{ 0.4, { RS = R(174, 0, 28), LS = R(174, 0, -28), RE = R(15), LE = R(15), W = R(-6), RT = R(15), N = R(26), RH = R(-6), LH = R(-6), RK = R(-8), LK = R(-8) }, "slowIn" },
		{ 0.54, { RS = R(98, 0, 12), LS = R(98, 0, -12), W = R(6), RT = R(-13), N = R(-4), RH = R(26), RK = R(-30), LH = R(-10) }, "snap" },
		{ 0.76, { RS = R(88, 0, 8), LS = R(88, 0, -8), RT = R(-9), RH = R(18), RK = R(-22) } },
		{ 1, {} },
	},
	-- guarda (segurando F): braços à frente cruzando a arma, base firme
	block = {
		{ 0, {} },
		{ 1, { RS = R(98, 0, -42), RE = R(60), LS = R(92, 0, 42), LE = R(68), W = R(4, -14, 0), RT = R(-6), RH = R(14), RK = R(-20), LH = R(-6), LK = R(-8), N = R(-8) } },
	},
	-- carregando o golpe pesado (segurando R): arma bem para trás, peso na perna de trás
	charge = {
		{ 0, {} },
		{ 1, { RS = R(162, 0, 48), RE = R(25), LS = R(45, 0, -25), LE = R(20), W = R(0, -50, 0), RT = R(10, 8, 0), RH = R(20), RK = R(-24), LH = R(-14), LK = R(-6), N = R(0, 20, 0) } },
	},
	-- grito: encolhe, depois peito para fora e braços abertos
	roar = {
		{ 0, {} },
		{ 0.18, { RS = R(30, 0, 20), LS = R(30, 0, -20), RE = R(40), LE = R(40), W = R(10), RT = R(-10), RH = R(20), LH = R(20), RK = R(-25), LK = R(-25), N = R(-12) } },
		{ 0.36, { RS = R(124, 0, 76), LS = R(124, 0, -76), W = R(-8), RT = R(14), N = R(30), RH = R(-4), LH = R(-4) }, "snap" },
		{ 0.75, { RS = R(118, 0, 70), LS = R(118, 0, -70), W = R(-6), RT = R(12), N = R(24) } },
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
			N = R(0, 30 * crouch, 0), -- a cabeça "puxa" o giro
			RT = R(-10 * crouch),
			RH = R(22 * crouch),
			LH = R(22 * crouch),
			RK = R(-30 * crouch),
			LK = R(-30 * crouch),
		}
	end,
	-- rolamento: agacha, rola encolhido e levanta já em base
	dodge = function(t)
		local e = smoother(math.clamp((t - 0.08) / 0.8, 0, 1))
		local tuck = math.sin(math.clamp(t / 0.95, 0, 1) * math.pi)
		return {
			RT = R(-360 * e),
			W = R(25 * tuck),
			RH = R(100 * tuck),
			LH = R(100 * tuck),
			RK = R(-118 * tuck),
			LK = R(-118 * tuck),
			RS = R(75 * tuck, 0, 20 * tuck),
			LS = R(75 * tuck, 0, -20 * tuck),
			RE = R(70 * tuck),
			LE = R(70 * tuck),
			N = R(35 * tuck),
		}
	end,
}

-- Postura de combate por tipo de arma (camada leve por cima da locomoção)
local STANCES = {
	sword = { RS = R(28, 0, -12), RE = R(38), LS = R(18, 0, 12), LE = R(20), RT = R(-3), RK = R(-6), LK = R(-6) },
	katana = { RS = R(34, 0, -24), RE = R(68), LS = R(30, 0, 18), LE = R(45), RT = R(-5), W = R(0, -8, 0), RK = R(-8), LK = R(-8) },
	dagger = { RS = R(32, 0, -18), RE = R(72), LS = R(28, 0, 16), LE = R(55), RT = R(-6), RK = R(-10), LK = R(-10) },
	axe = { RS = R(36, 0, -26), RE = R(48), LS = R(40, 0, 30), LE = R(52), RT = R(-4), RK = R(-6), LK = R(-6) },
	hammer = { RS = R(38, 0, -28), RE = R(50), LS = R(42, 0, 32), LE = R(54), RT = R(-5), RK = R(-8), LK = R(-8) },
	spear = { RS = R(42, 0, -16), RE = R(62), LS = R(52, 0, 26), LE = R(32), RT = R(-4), W = R(0, -10, 0), RK = R(-6), LK = R(-6) },
	-- cajado em pé ao lado do corpo: braço quase reto (o antebraço dobrado deitava o cajado)
	staff = { RS = R(14, 0, -12), RE = R(8), LS = R(12, 0, 10), RT = R(-2) },
	bow = { LS = R(22, 0, 4), RS = R(14, 0, -6), RT = R(-2) },
}

local JOINTS = {
	RS = { "RightUpperArm", "RightShoulder" },
	RE = { "RightLowerArm", "RightElbow" },
	RW = { "RightHand", "RightWrist" },
	LS = { "LeftUpperArm", "LeftShoulder" },
	LE = { "LeftLowerArm", "LeftElbow" },
	LW = { "LeftHand", "LeftWrist" },
	W = { "UpperTorso", "Waist" },
	N = { "Head", "Neck" },
	RT = { "LowerTorso", "Root" },
	RH = { "RightUpperLeg", "RightHip" },
	LH = { "LeftUpperLeg", "LeftHip" },
	RK = { "RightLowerLeg", "RightKnee" },
	LK = { "LeftLowerLeg", "LeftKnee" },
	RA = { "RightFoot", "RightAnkle" },
	LA = { "LeftFoot", "LeftAnkle" },
}

-- juntas que continuam o passo quando o golpe é dado andando
local LOWER = { RH = true, LH = true, RK = true, LK = true, RA = true, LA = true }

local states = setmetatable({}, { __mode = "k" }) -- [character] = estado de animação
local motorCache = setmetatable({}, { __mode = "k" })

local function isJoint(item)
	return item:IsA("Motor6D") or item:IsA("AnimationConstraint")
end

-- junta que move a peça: pelo nome; se não achar, a AnimationConstraint cujo Attachment1 está na peça
local function findJoint(character, part, name)
	local joint = part:FindFirstChild(name)
	if joint and isJoint(joint) then
		return joint
	end
	for _, item in character:GetDescendants() do
		if item:IsA("AnimationConstraint") and item.Attachment1 and item.Attachment1.Parent == part then
			return item
		end
	end
	return nil
end

local function motors(character)
	local cached = motorCache[character]
	if cached and cached.RS and cached.RS.Parent then
		return cached
	end
	local result = {}
	for key, path in JOINTS do
		local part = character:FindFirstChild(path[1])
		local motor = part and findJoint(character, part, path[2])
		if motor then
			result[key] = motor
		end
	end
	motorCache[character] = result
	return result
end

local function stateOf(character)
	local s = states[character]
	if not s then
		s = {
			job = nil,
			applied = {},
			from = nil,
			fadeStart = 0,
			fadeDuration = 0,
			stance = 0,
			combatUntil = 0,
			flinchStart = -10,
			flinchPower = 0,
			freezeUntil = 0,
			gallop = 0,
			phase = 0,
			swimPhase = 0,
			speed = 0,
			legYaw = 0,
			air = 0,
			swim = 0,
			lastVy = 0,
			landStart = -10,
			landPower = 0,
			accelLean = 0,
		}
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
	local ease = EASES[nextFrame[3] or "smooth"] or smoother
	local alpha = if span > 0 then ease(math.clamp((t - previous[1]) / span, 0, 1)) else 1
	local result = {}
	for key, cf in previous[2] do
		result[key] = cf:Lerp(nextFrame[2][key] or I, alpha)
	end
	for key, cf in nextFrame[2] do
		if not result[key] then
			result[key] = I:Lerp(cf, alpha)
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

-- congela a pose por um instante no impacto do golpe (dá peso ao acerto)
function Animator.hitstop(character, duration)
	if not character then
		return
	end
	local s = stateOf(character)
	if s.job and not s.job.hold then
		s.freezeUntil = math.max(s.freezeUntil, os.clock() + (duration or 0.05))
	end
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

-- ===================== CHÃO E ÁGUA =====================

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude
groundParams.IgnoreWater = true
local waterParams = RaycastParams.new()
waterParams.FilterType = Enum.RaycastFilterType.Include

local function refreshRayFilters()
	local ignore = {}
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(ignore, other.Character)
		end
	end
	for _, name in { "Inimigos", "Drops" } do
		local folder = workspace:FindFirstChild(name)
		if folder then
			table.insert(ignore, folder)
		end
	end
	groundParams.FilterDescendantsInstances = ignore
	waterParams.FilterDescendantsInstances = { workspace.Terrain }
end

-- distância da raiz até o chão e se está nadando
local function probe(root, humanoid)
	local reach = humanoid.HipHeight + root.Size.Y / 2
	local hit = workspace:Raycast(root.Position, Vector3.new(0, -(reach + 6), 0), groundParams)
	local distance = if hit then root.Position.Y - hit.Position.Y else math.huge
	local swimming = humanoid:GetState() == Enum.HumanoidStateType.Swimming
	if not swimming and distance > reach + 0.8 then
		-- sem chão perto: procura a superfície da água logo acima/abaixo
		local water = workspace:Raycast(root.Position + Vector3.new(0, 3, 0), Vector3.new(0, -6, 0), waterParams)
		swimming = water ~= nil and water.Material == Enum.Material.Water
	end
	return distance - reach, swimming
end

-- ===================== LOCOMOÇÃO =====================

-- pose do corpo pela velocidade (andar, correr, parado, pulo, queda, aterrissagem, nado)
local function locomotion(s, root, humanoid, now, dt, acting)
	local target = {}
	local velocity = root.AssemblyLinearVelocity
	local flat = Vector3.new(velocity.X, 0, velocity.Z)
	local rawSpeed = flat.Magnitude
	local previousSpeed = s.speed
	s.speed = lerp(s.speed, rawSpeed, math.min(1, dt * 12))
	local speed = s.speed
	local gap, swimming = probe(root, humanoid)
	local grounded = gap < 0.9

	-- 1) direção: o quadril gira para o lado do movimento (andar de lado/de costas com a mira travada)
	local forward = root.CFrame.LookVector:Dot(flat)
	local side = root.CFrame.RightVector:Dot(flat)
	local direction = 1
	local goalYaw = 0
	if rawSpeed > 2 then
		local angle = math.atan2(side, forward)
		if math.abs(angle) > math.rad(105) then
			direction = -1
			angle -= math.pi * math.sign(angle)
		end
		goalYaw = math.clamp(angle, math.rad(-55), math.rad(55))
	end
	s.legYaw = lerp(s.legYaw, goalYaw, math.min(1, dt * 10))

	-- 2) ciclo do passo
	local move = math.clamp(speed / 6, 0, 1)
	local run = math.clamp((speed - 8) / 14, 0, 1)
	local stride = lerp(5, 9, run) -- distância de um ciclo (dois passos)
	s.phase = (s.phase + direction * speed * dt / stride * math.pi * 2) % (math.pi * 2)
	local p = s.phase
	local sinp, cosp = math.sin(p), math.cos(p)
	local armDamp = (if acting then 0.15 else 1) * (1 - 0.6 * s.stance)

	local hipAmp = move * lerp(28, 50, run)
	local kneeSwing = lerp(42, 105, run)
	local kneeBase = lerp(8, 16, run)
	local hipForward = run * move * 8
	local rh = sinp * hipAmp + hipForward
	local lh = -sinp * hipAmp + hipForward
	local rk = -(math.max(0, cosp) * kneeSwing + kneeBase) * move
	local lk = -(math.max(0, -cosp) * kneeSwing + kneeBase) * move
	-- sobe e desce: andando o corpo sobe na passagem; correndo, sobe no voo
	local bobWalk = (math.abs(cosp) - 0.6) * 0.18
	local bobRun = (math.abs(sinp) - 0.5) * 0.36
	local bob = lerp(bobWalk, bobRun, run) * move
	local twist = lerp(7, 12, run) * move
	local accel = math.clamp((speed - previousSpeed) / math.max(dt, 1 / 240) * 0.25, -6, 8)
	s.accelLean = lerp(s.accelLean, accel, math.min(1, dt * 6))
	local lean = lerp(3, 13, run) * move + s.accelLean
	local sideLean = -math.clamp(side / 27, -1, 1) * 4
	local yawDeg = math.deg(s.legYaw)

	target.RT = CFrame.new(0, bob, 0) * R(-lean, sinp * twist * 0.5 - yawDeg, sinp * 3 * move + sideLean)
	target.W = R(lean * 0.25, -sinp * twist * 1.4 + yawDeg * 0.85, 0)
	target.N = R(lean * 0.55, sinp * twist * 0.5, 0) -- a cabeça fica estável enquanto o tronco gira
	target.RH = R(rh)
	target.LH = R(lh)
	target.RK = R(rk)
	target.LK = R(lk)
	local armAmp = move * lerp(24, 52, run) * armDamp
	local pump = lerp(12, 80, run) * move
	target.RS = R(-sinp * armAmp, 0, lerp(5, 9, run))
	target.LS = R(sinp * armAmp, 0, -lerp(5, 9, run))
	target.RE = R(pump + math.max(0, -sinp) * 18 * run * move + 6)
	target.LE = R(pump + math.max(0, sinp) * 18 * run * move + 6)

	-- 3) parado: respiração, troca de peso entre as pernas e olhar em volta
	local idle = 1 - move
	if idle > 0.01 then
		local breath = math.sin(now * 2.0)
		local shift = math.sin(now * 0.55)
		local calm = idle * (1 - 0.5 * s.stance)
		target.RT = target.RT * CFrame.new(shift * 0.07 * calm, -0.04 * idle, 0) * R(0, 0, shift * 2.2 * calm)
		target.W = target.W * R(breath * (1.2 + s.stance), 0, 0)
		target.N = target.N * R(-breath * 0.6, (math.sin(now * 0.31) * 7 + math.sin(now * 0.77) * 3) * calm, 0)
		target.RH = target.RH * R(4 * idle, 0, -shift * 2.2 * calm)
		target.LH = target.LH * R(4 * idle, 0, -shift * 2.2 * calm)
		target.RK = target.RK * R(-8 * idle)
		target.LK = target.LK * R(-8 * idle)
		target.RS = target.RS * R(breath * 1.5 * idle, 0, 0)
		target.LS = target.LS * R(breath * 1.5 * idle, 0, 0)
	end

	-- 4) no ar: pulo (perna encolhida) e queda (braços abertos)
	local vy = velocity.Y
	s.air = lerp(s.air, if grounded or swimming then 0 else 1, math.min(1, dt * (if grounded then 14 else 9)))
	if s.air > 0.01 then
		local fall = math.clamp((-vy + 5) / 30, 0, 1)
		local wobble = math.sin(now * 9) * 8 * fall
		local airPose = {
			RT = R(lerp(-6, 4, fall)),
			W = R(lerp(4, -4, fall)),
			N = R(lerp(6, -10, fall)),
			RH = R(lerp(52, 22, fall), 0, lerp(0, 8, fall)),
			RK = R(lerp(-82, -28, fall)),
			LH = R(lerp(-12, 6, fall), 0, lerp(0, -8, fall)),
			LK = R(lerp(-36, -18, fall)),
			RS = R(lerp(-28, 30, fall), 0, lerp(24, 70, fall) + wobble),
			LS = R(lerp(62, 30, fall), 0, -lerp(24, 70, fall) - wobble),
			RE = R(lerp(18, 25, fall)),
			LE = R(lerp(32, 25, fall)),
		}
		for key, cf in airPose do
			target[key] = target[key]:Lerp(cf, s.air)
		end
	end

	-- 5) aterrissagem: amortece nos joelhos conforme a velocidade da queda
	if grounded and s.air < 0.5 and s.lastVy < -28 then
		s.landStart = now
		s.landPower = math.clamp(-s.lastVy / 90, 0.3, 1)
	end
	s.lastVy = if grounded then 0 else vy
	local landT = (now - s.landStart) / 0.34
	if landT < 1 then
		local k = (1 - easeOut(landT)) * s.landPower
		target.RT = target.RT * CFrame.new(0, -0.75 * k, 0) * R(-9 * k)
		target.W = target.W * R(10 * k)
		target.N = target.N * R(-6 * k)
		target.RH = target.RH * R(48 * k)
		target.LH = target.LH * R(48 * k)
		target.RK = target.RK * R(-86 * k)
		target.LK = target.LK * R(-86 * k)
		target.RS = target.RS * R(18 * k, 0, 10 * k)
		target.LS = target.LS * R(18 * k, 0, -10 * k)
	end

	-- 6) nadando: braçada de crawl em movimento, "pedalando" parado
	s.swim = lerp(s.swim, if swimming then 1 else 0, math.min(1, dt * 6))
	if s.swim > 0.01 then
		s.swimPhase = (s.swimPhase + dt * lerp(2.2, 5.5, move)) % (math.pi * 2)
		local q = s.swimPhase
		local stroke = math.deg(q)
		local crawl = {
			RT = R(-78),
			N = R(55),
			RS = R(stroke, 0, 12),
			LS = R(stroke + 180, 0, -12),
			RE = R(20),
			LE = R(20),
			RH = R(math.sin(q * 3) * 20),
			LH = R(-math.sin(q * 3) * 20),
			RK = R(-12),
			LK = R(-12),
		}
		local tread = {
			RT = R(-8),
			N = R(8),
			RS = R(30, 0, 40 + math.sin(q) * 18),
			LS = R(30, 0, -40 - math.sin(q) * 18),
			RE = R(35),
			LE = R(35),
			RH = R(25 + math.sin(q) * 25),
			LH = R(25 - math.sin(q) * 25),
			RK = R(-40 - math.cos(q) * 25),
			LK = R(-40 + math.cos(q) * 25),
		}
		for key, cf in tread do
			target[key] = target[key]:Lerp(cf:Lerp(crawl[key] or I, move), s.swim)
		end
	end

	return target, move > 0.35 and grounded
end

-- ===================== MONTARIA =====================

-- Cavalo: juntas Motor6D criadas pelo servidor ("JuntaPernaFL", "JuntaCabeca", "JuntaCauda"...).
-- Passo (devagar): 4 tempos lateral (TE, DE, TD, DD). Galope (rápido): transverso, as traseiras e
-- depois as dianteiras quase em pares, com o voo depois das dianteiras.
local GAIT_WALK = { BL = 0, FL = 0.25, BR = 0.5, FR = 0.75 }
local GAIT_GALLOP = { BL = 0, BR = 0.1, FL = 0.42, FR = 0.52 }

local function animateHorse(character, s, dt, now)
	local mount = character:FindFirstChild("Montaria")
	local horse = mount and mount:FindFirstChild("Cavalo")
	local body = horse and horse:FindFirstChild("Corpo")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not body or not root then
		return 0, 0, 0
	end
	local velocity = root.AssemblyLinearVelocity
	local rawSpeed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	s.speed = lerp(s.speed, rawSpeed, math.min(1, dt * 6))
	local speed = s.speed
	local amount = math.clamp(speed / 10, 0, 1)
	local gallop = math.clamp((speed - 14) / 16, 0, 1)
	local stride = lerp(6, 18, gallop)
	s.gallop = (s.gallop + speed * dt / stride * math.pi * 2) % (math.pi * 2)
	local phase = s.gallop
	local legAmp = lerp(20, 40, gallop) * amount
	for _, joint in body:GetChildren() do
		if joint:IsA("Motor6D") then
			local name = joint.Name
			local leg = string.match(name, "^JuntaPerna(%a%a)$")
			if leg and GAIT_WALK[leg] then
				local offset = lerp(GAIT_WALK[leg], GAIT_GALLOP[leg], gallop) * math.pi * 2
				local swing = math.sin(phase - offset)
				-- a perna que volta para a frente sobe um pouco mais rápido (passada "redonda")
				joint.Transform = R(swing * legAmp + math.max(0, math.cos(phase - offset)) * 8 * amount, 0, 0)
			elseif name == "JuntaCabeca" then
				local nodWalk = math.sin(phase * 2) * 6
				local nodGallop = math.sin(phase - math.pi * 0.9) * 11
				local breathe = math.sin(now * 1.3) * 3 * (1 - amount)
				joint.Transform = R(lerp(nodWalk, nodGallop, gallop) * amount + breathe, math.sin(now * 0.4) * 6 * (1 - amount), 0)
			elseif name == "JuntaCauda" then
				joint.Transform = R(-(8 + 24 * gallop) * amount + math.sin(now * 1.7) * 4, math.sin(now * 2.3) * 14 * (1 - amount * 0.5), 0)
			end
		end
	end
	return amount, phase, gallop
end

-- cavaleiro sentado: pernas abertas no estribo, mãos nas rédeas, corpo acompanhando o balanço
local function riderPose(amount, phase, gallop, now)
	local bounce = math.sin(phase * (if gallop > 0.5 then 1 else 2))
	local bob = (bounce * lerp(0.08, 0.32, gallop)) * amount
	local pitch = (6 + 10 * gallop) * amount + math.sin(phase + 0.6) * 4 * gallop * amount
	local rein = math.sin(phase - math.pi * 0.9) * 5 * gallop * amount
	local breath = math.sin(now * 2) * (1 - amount)
	return {
		RT = CFrame.new(0, bob, 0) * R(-pitch),
		W = R(math.sin(phase + 1.2) * 3 * amount + breath),
		N = R(pitch * 0.7), -- olhar fica no horizonte
		RH = R(72, 0, 24),
		LH = R(72, 0, -24),
		RK = R(-88 + bounce * 4 * amount),
		LK = R(-88 + bounce * 4 * amount),
		RA = R(18),
		LA = R(18),
		RS = R(lerp(18, 40, amount) + rein, 0, 6),
		LS = R(lerp(18, 40, amount) + rein, 0, -6),
		RE = R(lerp(38, 58, amount)),
		LE = R(lerp(38, 58, amount)),
	}
end

-- passos de corrida (som do Roblox) ficam mudos enquanto monta
local function muteFootsteps(root, s, mute)
	local running = root:FindFirstChild("Running")
	if not running or not running:IsA("Sound") then
		return
	end
	if mute then
		if not s.runVolume then
			s.runVolume = running.Volume
		end
		running.Volume = 0
	elseif s.runVolume then
		running.Volume = s.runVolume
		s.runVolume = nil
	end
end

-- ===================== LAÇO PRINCIPAL =====================

local function pitchOf(cf)
	if not cf then
		return 0
	end
	local x = cf:ToEulerAnglesXYZ()
	return x
end

local function update(player, character, humanoid, now, dt)
	local s = stateOf(character)
	local m = motors(character)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	-- hit-stop: segura a pose (o golpe "trava" no impacto)
	if now < s.freezeUntil then
		if s.job then
			s.job.start += dt
		end
		for key, motor in m do
			motor.Transform = s.applied[key] or I
		end
		return
	end

	-- golpe/magia ou pose segurada
	local job = s.job
	local jobPose = nil
	if job then
		if job.hold then
			jobPose = samplePose(job.pose, job.t)
			if job.pose == "charge" then
				-- carregando: a arma treme cada vez mais
				local power = math.min((now - job.start) / 1.2, 1)
				jobPose.RS = (jobPose.RS or I) * R(math.sin(now * 42) * 1.2 * power, 0, math.cos(now * 37) * 1.2 * power)
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
				jobPose = samplePose(job.pose, t)
			end
		end
	end

	local inCombat = now < s.combatUntil
	s.stance += ((if inCombat then 1 else 0) - s.stance) * math.min(1, dt * 5)
	local mounted = player:GetAttribute("Mounted") == true
	muteFootsteps(root, s, mounted)

	local target, moving
	if mounted then
		-- 1) montado: o cavaleiro substitui toda a locomoção
		local amount, phase, gallop = animateHorse(character, s, dt, now)
		target = riderPose(amount, phase, gallop, now)
		moving = true
	else
		-- 1) locomoção
		target, moving = locomotion(s, root, humanoid, now, dt, jobPose ~= nil)
		-- 2) postura de combate pela arma
		local stance = STANCES[player:GetAttribute("WeaponType") or "sword"]
		if stance and s.stance > 0.01 and not jobPose and s.swim < 0.5 then
			for key, cf in stance do
				if not (moving and LOWER[key]) then
					target[key] = (target[key] or I) * I:Lerp(cf, s.stance)
				end
			end
		end
	end

	-- 3) golpe por cima (andando ou montado: só da cintura para cima)
	if jobPose then
		for key, cf in jobPose do
			if moving and LOWER[key] then
				continue
			elseif moving and key == "RT" then
				target.RT = (target.RT or I) * I:Lerp(cf, 0.4)
			else
				target[key] = (target[key] or I) * cf
			end
		end
	end

	-- 4) tranco ao levar dano (decai em 0,3s), com um passinho para trás
	local flinchT = (now - s.flinchStart) / 0.3
	if flinchT < 1 then
		local k = (1 - easeOut(flinchT)) * s.flinchPower
		target.W = (target.W or I) * R(14 * k, 0, 4 * k)
		target.N = (target.N or I) * R(12 * k)
		target.RT = (target.RT or I) * CFrame.new(0, 0, 0.25 * k) * R(6 * k)
	end

	-- 5) tornozelos: pé plano no chão (soma de quadril + coxa + joelho desfeita no tornozelo)
	if not target.RA then
		local plant = 1 - s.air * 0.75 - s.swim
		if plant > 0 then
			local rootPitch = pitchOf(target.RT)
			for _, side in { { "RH", "RK", "RA" }, { "LH", "LK", "LA" } } do
				local hip, knee = pitchOf(target[side[1]]), pitchOf(target[side[2]])
				-- perna no ar (joelho bem dobrado) deixa o pé mais solto
				local loose = math.clamp(-knee / math.rad(120), 0, 0.7)
				local ankle = -(rootPitch + hip + knee) * plant * (1 - loose)
				target[side[3]] = CFrame.Angles(math.clamp(ankle, math.rad(-45), math.rad(45)), 0, 0)
			end
		end
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
		local goal = target[key] or I
		local from = s.from and s.from[key]
		local offset = if from then from:Lerp(goal, fadeAlpha) else goal
		motor.Transform = offset
		applied[key] = offset
	end
	s.applied = applied
end

-- desliga as animações padrão do Roblox no personagem do jogador local (este módulo faz todas)
local function silenceDefault(character)
	local animate = character:WaitForChild("Animate", 5)
	if animate and animate:IsA("LocalScript") then
		animate.Disabled = true
	end
	local humanoid = character:WaitForChild("Humanoid", 5)
	local animator = humanoid and humanoid:WaitForChild("Animator", 5)
	if animator then
		for _, track in animator:GetPlayingAnimationTracks() do
			track:Stop(0)
		end
	end
end

function Animator.init()
	if localPlayer.Character then
		task.spawn(silenceDefault, localPlayer.Character)
	end
	localPlayer.CharacterAdded:Connect(silenceDefault)
	local filterAt = 0
	local warned = {}
	RunService.Stepped:Connect(function(_, dt)
		local now = os.clock()
		if now - filterAt > 1 then
			filterAt = now
			refreshRayFilters()
		end
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 then
				local ok, err = pcall(update, player, character, humanoid, now, dt)
				if not ok and not warned[err] then
					warned[err] = true -- (avisa uma vez só, não a cada quadro)
					warn("[Animator] " .. tostring(err))
				end
			end
		end
	end)
end

return Animator
