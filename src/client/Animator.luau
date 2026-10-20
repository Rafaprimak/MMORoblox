-- Animações procedurais dos personagens (golpes, magias, esquiva, montaria).
-- Gira as juntas (Motor6D.Transform) por cima das animações padrão do Roblox,
-- então funciona sem precisar enviar arquivos de animação.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Animator = {}

local function R(x, y, z)
	return CFrame.Angles(math.rad(x or 0), math.rad(y or 0), math.rad(z or 0))
end

local function ease(t)
	return 1 - (1 - t) * (1 - t)
end

-- Cada pose é uma lista de quadros { t, juntas }. Juntas: RS/RE (ombro/cotovelo dir.), LS/LE, W (cintura), N (pescoço), RT (raiz), RH/LH (quadris), RK/LK (joelhos)
local POSES = {
	slashA = {
		{ 0, {} },
		{ 0.25, { RS = R(115, 0, 70), RE = R(25), W = R(0, -40, 0) } },
		{ 0.55, { RS = R(80, 0, -45), W = R(0, 40, 0), RT = R(-6) } },
		{ 1, {} },
	},
	slashB = {
		{ 0, {} },
		{ 0.25, { RS = R(70, 0, -45), W = R(0, 35, 0) } },
		{ 0.55, { RS = R(100, 0, 75), W = R(0, -40, 0), RT = R(-6) } },
		{ 1, {} },
	},
	thrust = {
		{ 0, {} },
		{ 0.3, { RS = R(55), RE = R(95), W = R(0, -25, 0), RT = R(4) } },
		{ 0.5, { RS = R(92), RE = R(0), W = R(0, 12, 0), RT = R(-14), LS = R(-25) } },
		{ 1, {} },
	},
	stab = {
		{ 0, {} },
		{ 0.3, { RS = R(40, 0, 15), RE = R(80) } },
		{ 0.55, { RS = R(88, 0, -10), RE = R(0), RT = R(-8) } },
		{ 1, {} },
	},
	overhead = {
		{ 0, {} },
		{ 0.4, { RS = R(175, 0, 10), LS = R(150, 0, -10), RT = R(10), N = R(15) } },
		{ 0.62, { RS = R(35), LS = R(30), RT = R(-18) } },
		{ 1, {} },
	},
	slam = {
		{ 0, {} },
		{ 0.45, { RS = R(175, 0, 20), LS = R(175, 0, -20), RT = R(12), RH = R(25), LH = R(25), RK = R(-35), LK = R(-35) } },
		{ 0.65, { RS = R(20), LS = R(20), RT = R(-22), RH = R(50), LH = R(50), RK = R(-60), LK = R(-60) } },
		{ 1, {} },
	},
	bow = {
		{ 0, {} },
		{ 0.35, { LS = R(90, 0, 0), RS = R(90, 0, -35), RE = R(110), W = R(0, 25, 0) } },
		{ 0.75, { LS = R(90, 0, 0), RS = R(80, 0, -10), RE = R(60), W = R(0, 25, 0) } },
		{ 1, {} },
	},
	bowUp = {
		{ 0, {} },
		{ 0.4, { LS = R(150), RS = R(140, 0, -25), RE = R(80), RT = R(10) } },
		{ 0.8, { LS = R(150), RS = R(130, 0, -10), RT = R(10) } },
		{ 1, {} },
	},
	cast = {
		{ 0, {} },
		{ 0.35, { RS = R(130, 0, 15), RE = R(20), W = R(0, -15, 0) } },
		{ 0.6, { RS = R(95), RE = R(0), W = R(0, 10, 0), RT = R(-6) } },
		{ 1, {} },
	},
	castB = {
		{ 0, {} },
		{ 0.35, { LS = R(130, 0, -15), LE = R(20), W = R(0, 15, 0) } },
		{ 0.6, { LS = R(95), W = R(0, -10, 0), RT = R(-6) } },
		{ 1, {} },
	},
	castBig = {
		{ 0, {} },
		{ 0.45, { RS = R(170, 0, 25), LS = R(170, 0, -25), RT = R(12), N = R(20) } },
		{ 0.65, { RS = R(90, 0, 10), LS = R(90, 0, -10), RT = R(-10) } },
		{ 1, {} },
	},
	-- guarda (segurando F): braços à frente cruzando a arma
	block = {
		{ 0, {} },
		{ 1, { RS = R(95, 0, -40), RE = R(55), LS = R(90, 0, 40), LE = R(65), W = R(0, -12, 0), RT = R(-4) } },
	},
	-- carregando o golpe pesado (segurando R): arma bem para trás
	charge = {
		{ 0, {} },
		{ 1, { RS = R(160, 0, 45), RE = R(20), LS = R(40, 0, -20), W = R(0, -45, 0), RT = R(8), RH = R(15), LH = R(-10) } },
	},
	roar = {
		{ 0, {} },
		{ 0.3, { RS = R(120, 0, 70), LS = R(120, 0, -70), RT = R(12), N = R(25) } },
		{ 0.75, { RS = R(120, 0, 70), LS = R(120, 0, -70), RT = R(12), N = R(25) } },
		{ 1, {} },
	},
}

-- Poses calculadas (giro completo, rolamento)
local FUNCTION_POSES = {
	spin = function(t)
		local e = ease(t)
		return { W = R(0, -360 * e, 0), RS = R(85, 0, 85), LS = R(60, 0, -60), RT = R(-8 * math.sin(t * math.pi)) }
	end,
	dodge = function(t)
		local e = ease(t)
		local tuck = math.sin(t * math.pi)
		return {
			RT = R(-360 * e),
			RH = R(90 * tuck),
			LH = R(90 * tuck),
			RK = R(-100 * tuck),
			LK = R(-100 * tuck),
			RS = R(60 * tuck),
			LS = R(60 * tuck),
		}
	end,
}

local MOUNTED = { RH = R(75, 0, 18), LH = R(75, 0, -18), RK = R(-75), LK = R(-75), RS = R(25), LS = R(25) }

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

local jobs = {} -- [character] = { pose, start, duration }
local motorCache = setmetatable({}, { __mode = "k" })

local function motors(character)
	local cached = motorCache[character]
	if cached then
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
	local alpha = if span > 0 then ease((t - previous[1]) / span) else 1
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

function Animator.play(character, poseName, duration, withTrail)
	if not character or not poseName then
		return
	end
	jobs[character] = { pose = poseName, start = os.clock(), duration = math.max(duration or 0.4, 0.1), trail = withTrail }
	if withTrail then
		setTrail(character, true)
	end
end

-- Mantém uma pose parada (guarda, carregar golpe) até chamar Animator.stop
function Animator.hold(character, poseName, t)
	if not character or not poseName then
		return
	end
	jobs[character] = { pose = poseName, start = os.clock(), duration = 1, hold = true, t = t or 1, blend = 0 }
end

function Animator.stop(character)
	local job = character and jobs[character]
	if job and job.hold then
		jobs[character] = nil
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

function Animator.init()
	RunService.Stepped:Connect(function()
		local now = os.clock()
		for character, job in jobs do
			if not character.Parent then
				jobs[character] = nil
				continue
			end
			if job.hold then
				-- entra na pose suavemente (0,12s) e fica parado nela
				job.blend = math.min(1, (now - job.start) / 0.12)
				local pose = samplePose(job.pose, job.t * job.blend)
				local m = motors(character)
				for key, offset in pose do
					local motor = m[key]
					if motor then
						motor.Transform = motor.Transform * offset
					end
				end
				continue
			end
			local t = (now - job.start) / job.duration
			if t >= 1 then
				jobs[character] = nil
				if job.trail then
					setTrail(character, false)
				end
				continue
			end
			local pose = samplePose(job.pose, t)
			local m = motors(character)
			for key, offset in pose do
				local motor = m[key]
				if motor then
					motor.Transform = motor.Transform * offset
				end
			end
		end
		-- montados
		for _, player in Players:GetPlayers() do
			local character = player.Character
			if character and player:GetAttribute("Mounted") and not jobs[character] then
				local m = motors(character)
				for key, offset in MOUNTED do
					local motor = m[key]
					if motor then
						motor.Transform = motor.Transform * offset
					end
				end
			end
		end
	end)
end

return Animator
