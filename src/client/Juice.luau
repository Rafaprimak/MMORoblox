-- "Sensação de jogo": poeira nos pés ao correr, nuvem de poeira ao aterrissar, câmera que abre um
-- pouco na corrida/montaria (somada ao "soco" de campo de visão dos golpes) e partículas do ambiente
-- conforme a região: folhas caindo no bosque, pólen nos campos, neve nas montanhas, cinzas no covil.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local World = require(Shared.World)

local Fx = require(script.Parent.Fx)
local Prefs = require(script.Parent.Prefs)

local Juice = {}

local BASE_FOV = 70
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local folder = Instance.new("Folder")
folder.Name = "Poeira"
folder.Parent = workspace

local DUST_COLORS = {
	[Enum.Material.Grass] = Color3.fromRGB(150, 170, 110),
	[Enum.Material.LeafyGrass] = Color3.fromRGB(130, 150, 100),
	[Enum.Material.Sand] = Color3.fromRGB(225, 205, 160),
	[Enum.Material.Snow] = Color3.fromRGB(240, 245, 250),
	[Enum.Material.Mud] = Color3.fromRGB(110, 90, 65),
	[Enum.Material.Ground] = Color3.fromRGB(150, 125, 95),
}

local function puff(position, color, size, count, spread)
	for _ = 1, count do
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Shape = Enum.PartType.Ball
		p.Material = Enum.Material.SmoothPlastic
		p.Color = color
		p.Transparency = 0.35
		p.Size = Vector3.one * size * (0.6 + math.random() * 0.5)
		local offset = Vector3.new((math.random() - 0.5) * spread, 0, (math.random() - 0.5) * spread)
		p.CFrame = CFrame.new(position + offset)
		p.Parent = folder
		local rise = offset.Unit * spread * 0.4 + Vector3.new(0, size * 0.8, 0)
		if rise ~= rise then
			rise = Vector3.new(0, size * 0.8, 0)
		end
		TweenService:Create(p, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = p.Size * 2.2, Transparency = 1, CFrame = p.CFrame + rise }):Play()
		Debris:AddItem(p, 0.6)
	end
end

local function dustColor(humanoid)
	local material = humanoid.FloorMaterial
	return DUST_COLORS[material] or Color3.fromRGB(170, 165, 155), material
end

-- ===================== PASSOS E ATERRISSAGEM =====================

local stepTimers = setmetatable({}, { __mode = "k" })

local function watchLanding(character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not humanoid or not root then
		return
	end
	local fallSpeed = 0
	humanoid.StateChanged:Connect(function(_, new)
		if new == Enum.HumanoidStateType.Freefall then
			fallSpeed = 0
		elseif new == Enum.HumanoidStateType.Landed and fallSpeed > 28 then
			local color = dustColor(humanoid)
			puff(root.Position - Vector3.new(0, 2.8, 0), color, 1.4, 8, 3)
			if character == player.Character then
				Fx.shake(0.12, math.clamp(fallSpeed / 120, 0.1, 0.4))
			end
		end
	end)
	RunService.Heartbeat:Connect(function()
		if root.Parent then
			fallSpeed = math.max(fallSpeed, -root.AssemblyLinearVelocity.Y)
		end
	end)
end

-- ===================== PARTÍCULAS DO AMBIENTE =====================

local AMBIENT = {
	bosque = { color = ColorSequence.new(Color3.fromRGB(200, 140, 50), Color3.fromRGB(110, 150, 60)), size = 0.5, rate = 14, speed = 1.5, accel = Vector3.new(1.5, -2.5, 0.5), rotation = true, light = 0, life = 7 },
	campo = { color = ColorSequence.new(Color3.fromRGB(255, 255, 240)), size = 0.18, rate = 18, speed = 0.6, accel = Vector3.new(1, -0.15, 0.4), light = 0.4, life = 9 },
	montanha = { color = ColorSequence.new(Color3.fromRGB(250, 252, 255)), size = 0.3, rate = 45, speed = 2, accel = Vector3.new(2, -6, 0), light = 0.2, life = 6 },
	cinzas = { color = ColorSequence.new(Color3.fromRGB(255, 120, 50), Color3.fromRGB(90, 80, 80)), size = 0.22, rate = 25, speed = 1, accel = Vector3.new(0, 1.2, 0), light = 0.8, life = 6 },
}

local function regionAmbient(position)
	local w = World.weights(position.X, position.Z)
	local h = World.height(position.X, position.Z)
	if w.crater > 0.3 then
		return "cinzas"
	elseif w.mountain > 0.5 or World.designHeight(h) > 110 then
		return "montanha"
	elseif w.forest > 0.45 then
		return "bosque"
	elseif w.town < 0.3 and w.ocean < 0.1 and w.lake < 0.2 then
		return "campo"
	end
	return nil
end

function Juice.init()
	-- emissor que acompanha a câmera (uma caixa grande acima do jogador)
	local emitterPart = Instance.new("Part")
	emitterPart.Name = "ParticulasAmbiente"
	emitterPart.Anchored = true
	emitterPart.CanCollide = false
	emitterPart.CanQuery = false
	emitterPart.CanTouch = false
	emitterPart.Transparency = 1
	emitterPart.Size = Vector3.new(90, 2, 90)
	emitterPart.Parent = workspace
	local emitter = Instance.new("ParticleEmitter")
	emitter.EmissionDirection = Enum.NormalId.Bottom
	emitter.SpreadAngle = Vector2.new(30, 30)
	emitter.Enabled = false
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.Parent = emitterPart
	local currentAmbient = nil

	local function setAmbient(kind)
		if kind == currentAmbient then
			return
		end
		currentAmbient = kind
		local def = kind and AMBIENT[kind]
		emitter.Enabled = def ~= nil
		if def then
			emitter.Color = def.color
			emitter.Size = NumberSequence.new(def.size)
			emitter.Rate = def.rate
			emitter.Speed = NumberRange.new(def.speed * 0.5, def.speed)
			emitter.Acceleration = def.accel
			emitter.LightEmission = def.light
			emitter.Lifetime = NumberRange.new(def.life * 0.7, def.life)
			emitter.Rotation = NumberRange.new(0, 360)
			emitter.RotSpeed = if def.rotation then NumberRange.new(-120, 120) else NumberRange.new(0, 0)
			emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, 0.1), NumberSequenceKeypoint.new(0.85, 0.2), NumberSequenceKeypoint.new(1, 1) })
		end
	end

	for _, other in Players:GetPlayers() do
		if other.Character then
			task.spawn(watchLanding, other.Character)
		end
		other.CharacterAdded:Connect(watchLanding)
	end
	Players.PlayerAdded:Connect(function(other)
		other.CharacterAdded:Connect(watchLanding)
	end)

	local ambientCheck = 0
	RunService.RenderStepped:Connect(function(dt)
		local now = os.clock()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		-- câmera abre um pouco correndo/montado + "soco" dos golpes (Fx.fovKick)
		local speed = 0
		if root then
			local velocity = root.AssemblyLinearVelocity
			speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
		end
		local sprintBoost = math.clamp((speed - 18) / 25, 0, 1) * 8
		local kick = 0
		if Fx.fovKick and Prefs.get("shake") then
			local t = (now - Fx.fovKick.start) / Fx.fovKick.duration
			if t < 1 then
				kick = Fx.fovKick.amount * (1 - t) * (1 - t)
			end
		end
		local goal = BASE_FOV + sprintBoost - kick
		camera.FieldOfView += (goal - camera.FieldOfView) * math.min(1, dt * (if kick > 0 then 30 else 6))

		-- poeira nos pés de quem está correndo
		for _, other in Players:GetPlayers() do
			local otherCharacter = other.Character
			local humanoid = otherCharacter and otherCharacter:FindFirstChildOfClass("Humanoid")
			local otherRoot = otherCharacter and otherCharacter:FindFirstChild("HumanoidRootPart")
			if humanoid and otherRoot and humanoid.FloorMaterial ~= Enum.Material.Air then
				local velocity = otherRoot.AssemblyLinearVelocity
				local flatSpeed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
				if flatSpeed > 20 then
					local nextAt = stepTimers[otherCharacter] or 0
					if now > nextAt then
						stepTimers[otherCharacter] = now + (if other:GetAttribute("Mounted") then 0.12 else 0.22)
						local color = dustColor(humanoid)
						local feet = otherRoot.Position - Vector3.new(0, if other:GetAttribute("Mounted") then 5.5 else 2.9, 0)
						puff(feet, color, if other:GetAttribute("Mounted") then 1.1 else 0.7, 2, 1.2)
					end
				end
			end
		end

		-- partículas do ambiente
		if root then
			emitterPart.CFrame = CFrame.new(root.Position + Vector3.new(0, 28, 0))
			if now > ambientCheck then
				ambientCheck = now + 1
				setAmbient(regionAmbient(root.Position))
			end
		end
	end)
end

return Juice
