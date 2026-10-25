-- Céu do cliente: move o sol suavemente (ClockTime local, calculado pelo DayNight) e acende os
-- postes e lanternas (tag "NightLight") quando anoitece.
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DayNight = require(Shared.DayNight)

local Sky = {}

local OFF_COLOR = Color3.fromRGB(120, 110, 95)

local function setLamp(part, on)
	if not part:IsA("BasePart") then
		return
	end
	if part:GetAttribute("OnColor") == nil then
		part:SetAttribute("OnColor", part.Color)
	end
	part.Material = if on then Enum.Material.Neon else Enum.Material.Glass
	part.Color = if on then part:GetAttribute("OnColor") else (part:GetAttribute("OffColor") or OFF_COLOR)
	for _, child in part:GetChildren() do
		if child:IsA("Light") then
			child.Enabled = on
		end
	end
end

local function refreshLamps()
	local on = workspace:GetAttribute("Night") == true
	for _, part in CollectionService:GetTagged("NightLight") do
		setLamp(part, on)
	end
end

function Sky.isNight()
	return workspace:GetAttribute("Night") == true
end

-- texto curto para o HUD: "☀ 09:30" ou "🌙 22:10"
function Sky.label()
	local clock = DayNight.now()
	return (if DayNight.isNight(clock) then "🌙 " else "☀ ") .. DayNight.format(clock)
end

function Sky.init()
	workspace:GetAttributeChangedSignal("Night"):Connect(refreshLamps)
	CollectionService:GetInstanceAddedSignal("NightLight"):Connect(function(part)
		setLamp(part, workspace:GetAttribute("Night") == true)
	end)
	refreshLamps()
	RunService.RenderStepped:Connect(function()
		-- nas masmorras quem cuida da luz é o DungeonAtmosphere
		if workspace:GetAttribute("DayEpoch") and not game:GetService("Players").LocalPlayer:GetAttribute("Dungeon") then
			Lighting.ClockTime = DayNight.now()
		end
	end)
end

return Sky
