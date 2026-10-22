-- Monta o mundo inteiro na ordem certa: terreno, vila, locais, recursos e natureza.
local Lighting = game:GetService("Lighting")

local TerrainGen = require(script.TerrainGen)
local Town = require(script.Town)
local Landmarks = require(script.Landmarks)
local Scatter = require(script.Scatter)
local PointsOfInterest = require(script.PointsOfInterest)

local WorldGen = {}

local function setupLighting()
	Lighting.ClockTime = 14.2
	Lighting.Brightness = 2.8
	Lighting.Ambient = Color3.fromRGB(75, 72, 88)
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 140, 155)
	Lighting.EnvironmentDiffuseScale = 0.9
	Lighting.EnvironmentSpecularScale = 0.8
	Lighting.GlobalShadows = true
	pcall(function()
		Lighting.ShadowSoftness = 0.3
	end)
	for _, child in Lighting:GetChildren() do
		if child:IsA("PostEffect") or child:IsA("Atmosphere") or child:IsA("Sky") then
			child:Destroy()
		end
	end
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.32
	atmosphere.Offset = 0.15
	atmosphere.Color = Color3.fromRGB(205, 200, 225)
	atmosphere.Decay = Color3.fromRGB(120, 110, 160)
	atmosphere.Glare = 0.35
	atmosphere.Haze = 1.9
	atmosphere.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.4
	bloom.Size = 26
	bloom.Threshold = 1.4
	bloom.Parent = Lighting
	local color = Instance.new("ColorCorrectionEffect")
	color.Saturation = 0.18
	color.Contrast = 0.12
	color.TintColor = Color3.fromRGB(255, 249, 240)
	color.Parent = Lighting
	local sunRays = Instance.new("SunRaysEffect")
	sunRays.Intensity = 0.09
	sunRays.Spread = 0.6
	sunRays.Parent = Lighting
	-- leve desfoque no horizonte (profundidade)
	local depth = Instance.new("DepthOfFieldEffect")
	depth.FarIntensity = 0.12
	depth.NearIntensity = 0
	depth.FocusDistance = 40
	depth.InFocusRadius = 140
	depth.Parent = Lighting
	local clouds = Instance.new("Clouds")
	clouds.Cover = 0.55
	clouds.Density = 0.6
	clouds.Parent = workspace.Terrain
end

function WorldGen.build(onProgress)
	setupLighting()
	local rng = Random.new(2026)
	local folder = Instance.new("Folder")
	folder.Name = "Mundo"
	folder.Parent = workspace

	TerrainGen.generate(function(fraction)
		if onProgress then
			onProgress("Esculpindo o terreno", fraction * 0.7)
		end
	end)
	-- cada etapa protegida: se uma falhar, o resto do mundo continua sendo gerado
	local function step(label, fraction, fn)
		if onProgress then
			onProgress(label, fraction)
		end
		local ok, result = pcall(fn)
		if not ok then
			warn(("[WorldGen] Falha em '%s': %s"):format(label, tostring(result)))
			return nil
		end
		return result
	end
	local board = step("Construindo a vila", 0.72, function()
		return Town.build(folder, rng)
	end)
	local landmarks = step("Erguendo ruínas e acampamentos", 0.78, function()
		return Landmarks.build(folder, rng)
	end) or {}
	step("Marcando locais de interesse", 0.81, function()
		return PointsOfInterest.build(folder, rng)
	end)
	step("Espalhando minérios e plantas", 0.84, function()
		return Scatter.resources(folder, rng)
	end)
	step("Plantando a floresta", 0.9, function()
		return Scatter.nature(folder, rng)
	end)
	if onProgress then
		onProgress("Pronto", 1)
	end
	return { barrier = landmarks.barrier, board = board, horse = Town.horse }
end

return WorldGen
