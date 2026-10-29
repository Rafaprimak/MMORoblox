-- Ciclo de dia e noite: guarda o começo do ciclo, marca workspace.Night, ajusta a luz e avisa os jogadores.
-- O cliente move o sol sozinho (Lighting.ClockTime local, suave); aqui só mudam o ambiente e as regras.
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local DayNight = require(Shared.DayNight)
local Remotes = require(Shared.Remotes)

local DayNightService = {}

local TRANSITION = 25 -- segundos de transição da luz

local NIGHT_LOOK = {
	lighting = { Brightness = 1.9, Ambient = Color3.fromRGB(90, 98, 135), OutdoorAmbient = Color3.fromRGB(135, 145, 195), ExposureCompensation = 0.35 },
	atmosphere = { Color = Color3.fromRGB(125, 135, 190), Decay = Color3.fromRGB(70, 72, 120), Density = 0.3 },
	color = { TintColor = Color3.fromRGB(215, 225, 255), Saturation = -0.03 },
}

local dayLook = nil
local night = nil

local function capture()
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	local color = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	dayLook = {
		lighting = { Brightness = Lighting.Brightness, Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient, ExposureCompensation = Lighting.ExposureCompensation },
		atmosphere = atmosphere and { Color = atmosphere.Color, Decay = atmosphere.Decay, Density = atmosphere.Density },
		color = color and { TintColor = color.TintColor, Saturation = color.Saturation },
	}
end

local function applyLook(look, duration)
	local info = TweenInfo.new(duration, Enum.EasingStyle.Sine)
	TweenService:Create(Lighting, info, look.lighting):Play()
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere and look.atmosphere then
		TweenService:Create(atmosphere, info, look.atmosphere):Play()
	end
	local color = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	if color and look.color then
		TweenService:Create(color, info, look.color):Play()
	end
end

local function setNight(value, announce)
	if night == value then
		return
	end
	night = value
	workspace:SetAttribute("Night", value)
	applyLook(if value then NIGHT_LOOK else dayLook, if announce then TRANSITION else 0)
	if not announce then
		return
	end
	if value then
		Remotes.Notify:FireAllClients({
			kind = "banner",
			text = "A noite caiu",
			sub = ("Inimigos %d%% mais fortes e mais Elites  •  +%d%% de XP, ouro e equipamentos"):format(math.floor((Config.NightEnemyDamage - 1) * 100 + 0.5), math.floor(Config.NightRewardBonus * 100 + 0.5)),
			color = Color3.fromRGB(150, 160, 255),
			duration = 5,
		})
	else
		Remotes.Notify:FireAllClients({ kind = "banner", text = "Amanheceu", sub = "Os monstros voltam ao normal", color = Color3.fromRGB(255, 220, 120), duration = 4 })
	end
end

function DayNightService.isNight()
	return night == true
end

function DayNightService.start()
	capture()
	workspace:SetAttribute("DayEpoch", workspace:GetServerTimeNow() - DayNight.offsetFor(Config.StartClock))
	setNight(DayNight.isNight(DayNight.now()), false)
	task.spawn(function()
		while true do
			task.wait(1)
			setNight(DayNight.isNight(DayNight.now()), true)
		end
	end)
end

-- Teste no Studio: pula direto para a próxima troca (dia ↔ noite)
function DayNightService.skip()
	local now = workspace:GetServerTimeNow()
	local epoch = workspace:GetAttribute("DayEpoch") or 0
	workspace:SetAttribute("DayEpoch", epoch - DayNight.secondsToChange(now, epoch) - 2)
	setNight(DayNight.isNight(DayNight.now()), true)
end

return DayNightService
