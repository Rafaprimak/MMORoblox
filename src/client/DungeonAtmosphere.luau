-- Clima das masmorras (só no cliente): enquanto o jogador tem o atributo "Dungeon", a luz do mundo dá
-- lugar a um ambiente escuro com névoa e cor do tema, sem céu nem nuvens, com poeira (ou brasas)
-- flutuando perto da câmera. Ao sair, tudo volta ao que estava.
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Dungeons = require(Shared.Dungeons)

local DungeonAtmosphere = {}

local player = Players.LocalPlayer

-- por tema: luz ambiente, névoa da atmosfera, tom da imagem e o que flutua no ar
local MOODS = {
	-- raide (atributo Raid): noite cósmica violeta, névoa de nebulosa, estrelas cintilando e cadentes
	raide = {
		-- clara o bastante para 8 jogadores enxergarem os círculos de dano (antes: escura demais)
		ambient = Color3.fromRGB(150, 130, 190), outdoor = Color3.fromRGB(170, 150, 215), brightness = 2.4,
		fog = Color3.fromRGB(90, 60, 150), decay = Color3.fromRGB(170, 90, 190), density = 0.1,
		tint = Color3.fromRGB(245, 235, 255), saturation = 0.2, contrast = 0.1,
		motes = Color3.fromRGB(255, 240, 200), embers = true, stars = true,
	},
	caverna = {
		ambient = Color3.fromRGB(58, 48, 40), outdoor = Color3.fromRGB(30, 26, 22), brightness = 0.4,
		fog = Color3.fromRGB(44, 34, 26), decay = Color3.fromRGB(30, 22, 16), density = 0.5,
		tint = Color3.fromRGB(255, 236, 214), saturation = -0.05, contrast = 0.18,
		motes = Color3.fromRGB(220, 190, 150),
	},
	cripta = {
		ambient = Color3.fromRGB(46, 46, 66), outdoor = Color3.fromRGB(22, 22, 34), brightness = 0.35,
		fog = Color3.fromRGB(26, 26, 40), decay = Color3.fromRGB(16, 16, 28), density = 0.55,
		tint = Color3.fromRGB(222, 220, 255), saturation = -0.2, contrast = 0.2,
		motes = Color3.fromRGB(190, 200, 255),
	},
	abismo = {
		ambient = Color3.fromRGB(70, 34, 24), outdoor = Color3.fromRGB(34, 14, 10), brightness = 0.4,
		fog = Color3.fromRGB(46, 16, 10), decay = Color3.fromRGB(30, 8, 4), density = 0.5,
		tint = Color3.fromRGB(255, 222, 200), saturation = 0.05, contrast = 0.22,
		motes = Color3.fromRGB(255, 130, 50), embers = true,
	},
}

local saved = nil
local color, emitterPart

local function save()
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	saved = {
		Ambient = Lighting.Ambient,
		OutdoorAmbient = Lighting.OutdoorAmbient,
		Brightness = Lighting.Brightness,
		EnvironmentDiffuseScale = Lighting.EnvironmentDiffuseScale,
		EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale,
		atmosphere = atmosphere and { Density = atmosphere.Density, Color = atmosphere.Color, Decay = atmosphere.Decay, Glare = atmosphere.Glare, Haze = atmosphere.Haze, Offset = atmosphere.Offset },
	}
end

local function restore()
	if not saved then
		return
	end
	for key, value in saved do
		if key ~= "atmosphere" then
			Lighting[key] = value
		end
	end
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere and saved.atmosphere then
		for key, value in saved.atmosphere do
			atmosphere[key] = value
		end
	end
	local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds")
	if clouds then
		clouds.Enabled = true
	end
	for _, effect in Lighting:GetChildren() do
		if effect:IsA("SunRaysEffect") then
			effect.Enabled = true
		end
	end
	if color then
		color:Destroy()
		color = nil
	end
	if emitterPart then
		emitterPart:Destroy()
		emitterPart = nil
	end
	saved = nil
end

local function makeMotes(mood)
	local part = Instance.new("Part")
	part.Name = "PoeiraMasmorra"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.new(60, 20, 60)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(mood.motes)
	emitter.LightEmission = if mood.embers then 1 else 0.4
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.4), NumberSequenceKeypoint.new(1, 1) })
	emitter.Size = NumberSequence.new(if mood.embers then 0.18 else 0.12)
	emitter.Lifetime = NumberRange.new(5, 9)
	emitter.Rate = if mood.embers then 25 else 35
	emitter.Speed = NumberRange.new(0.2, 0.8)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = if mood.embers then Vector3.new(0, 0.8, 0) else Vector3.new(0, -0.05, 0)
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	emitter.Parent = part
	if mood.stars then
		-- estrelas cadentes riscando o céu
		local streaks = Instance.new("ParticleEmitter")
		streaks.Color = ColorSequence.new(Color3.fromRGB(255, 230, 180), Color3.fromRGB(255, 120, 230))
		streaks.LightEmission = 1
		streaks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
		streaks.Lifetime = NumberRange.new(0.8, 1.4)
		streaks.Rate = 6
		streaks.Speed = NumberRange.new(60, 90)
		streaks.EmissionDirection = Enum.NormalId.Bottom
		streaks.SpreadAngle = Vector2.new(25, 25)
		streaks.Acceleration = Vector3.new(-20, 0, 0)
		streaks.Drag = 0
		streaks.Parent = part
		part.Size = Vector3.new(160, 40, 160)
	end
	part.Parent = workspace.CurrentCamera
	return part
end

-- aplica todo quadro (o servidor ainda muda a luz do mundo no ciclo de dia e noite)
local function apply(mood)
	Lighting.Ambient = mood.ambient
	Lighting.OutdoorAmbient = mood.outdoor
	Lighting.Brightness = mood.brightness
	Lighting.EnvironmentDiffuseScale = 0.25
	Lighting.EnvironmentSpecularScale = 0.3
	Lighting.ClockTime = 0
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		atmosphere.Density = mood.density
		atmosphere.Color = mood.fog
		atmosphere.Decay = mood.decay
		atmosphere.Glare = 0
		atmosphere.Haze = 2.2
		atmosphere.Offset = 0
	end
end

function DungeonAtmosphere.inDungeon()
	local id = player:GetAttribute("Dungeon")
	return id ~= nil and Dungeons.ById[id] ~= nil
end

function DungeonAtmosphere.init()
	local currentMood = nil
	RunService.RenderStepped:Connect(function()
		local id = player:GetAttribute("Dungeon")
		local dungeon = id and Dungeons.ById[id]
		local mood = if player:GetAttribute("Raid") then MOODS.raide else dungeon and MOODS[dungeon.theme]
		if mood ~= currentMood then
			restore()
			currentMood = mood
			if mood then
				save()
				color = Instance.new("ColorCorrectionEffect")
				color.Name = "CorMasmorra"
				color.TintColor = mood.tint
				color.Saturation = mood.saturation
				color.Contrast = mood.contrast
				color.Brightness = -0.02
				color.Parent = Lighting
				emitterPart = makeMotes(mood)
				local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds")
				if clouds then
					clouds.Enabled = false
				end
				for _, effect in Lighting:GetChildren() do
					if effect:IsA("SunRaysEffect") then
						effect.Enabled = false
					end
				end
			end
		end
		if mood then
			apply(mood)
			local camera = workspace.CurrentCamera
			if emitterPart and camera then
				emitterPart.CFrame = CFrame.new(camera.CFrame.Position + (if mood.stars then Vector3.new(0, 30, 0) else Vector3.zero))
			end
		end
	end)
end

return DungeonAtmosphere
