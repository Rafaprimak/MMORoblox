-- Aura de rank em volta de cada jogador (desenhada no cliente, a partir do atributo "Rank", o índice
-- em Config.Ranks que sobe nos exames).
-- Rank E não tem aura; do D ao S ela fica mais densa e brilhante, na cor do rank.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Progression = require(Shared.Progression)

local UI = require(script.Parent.UI)

local Auras = {}

-- por posição do rank em Config.Ranks
local RATE = { 0, 2, 5, 9, 14, 22 }

local function rankIndex(player)
	return math.clamp(math.floor(tonumber(player:GetAttribute("Rank")) or 1), 1, #Config.Ranks)
end

local function refresh(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local index = rankIndex(player)
	local rank = Config.Ranks[index]
	local emitter = root:FindFirstChild("AuraRank")
	local light = root:FindFirstChild("LuzRank")
	if (RATE[index] or 0) <= 0 then
		if emitter then
			emitter:Destroy()
		end
		if light then
			light:Destroy()
		end
		return
	end
	if not emitter then
		emitter = Instance.new("ParticleEmitter")
		emitter.Name = "AuraRank"
		emitter.LightEmission = 1
		emitter.LightInfluence = 0
		emitter.Lifetime = NumberRange.new(1, 1.8)
		emitter.Speed = NumberRange.new(0.4, 1.2)
		emitter.Acceleration = Vector3.new(0, 3.5, 0)
		emitter.SpreadAngle = Vector2.new(25, 25)
		emitter.EmissionDirection = Enum.NormalId.Top
		emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.35), NumberSequenceKeypoint.new(1, 1) })
		emitter.Parent = root
	end
	emitter.Color = ColorSequence.new(rank.color, rank.color:Lerp(Color3.new(1, 1, 1), 0.5))
	emitter.Size = NumberSequence.new(0.18 + index * 0.04, 0)
	emitter.Rate = RATE[index]
	-- A e S: brilho em volta do corpo
	if index >= 5 then
		if not light then
			light = Instance.new("PointLight")
			light.Name = "LuzRank"
			light.Parent = root
		end
		light.Color = rank.color
		light.Range = 8 + (index - 5) * 4
		light.Brightness = 0.8
	elseif light then
		light:Destroy()
	end
end

-- título em cima da cabeça (atributos "Title"/"TitleId")
local function refreshTitle(player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head then
		return
	end
	local old = head:FindFirstChild("TituloHunter")
	local titleId = player:GetAttribute("TitleId")
	local title = titleId and Progression.Titles[titleId]
	if not title or titleId == "novato" then
		if old then
			old:Destroy()
		end
		return
	end
	local gui = old or UI.new("BillboardGui", { Name = "TituloHunter", Size = UDim2.fromOffset(220, 22), StudsOffset = Vector3.new(0, 3.1, 0), MaxDistance = 70, LightInfluence = 0, Adornee = head, Parent = head })
	local label = gui:FindFirstChild("Texto") or UI.label({ Name = "Texto", Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, Font = Enum.Font.GothamBlack, Parent = gui }, { UI.textStroke(1.5) })
	label.Text = "« " .. title.name .. " »"
	label.TextColor3 = title.color
	if title.rainbow then
		CollectionService:AddTag(label, "RainbowText")
	else
		CollectionService:RemoveTag(label, "RainbowText")
	end
end

local function watch(player)
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("HumanoidRootPart", 10)
		character:WaitForChild("Head", 10)
		refresh(player)
		refreshTitle(player)
	end)
	player:GetAttributeChangedSignal("Rank"):Connect(function()
		refresh(player)
	end)
	player:GetAttributeChangedSignal("TitleId"):Connect(function()
		refreshTitle(player)
	end)
	refresh(player)
	refreshTitle(player)
end

function Auras.init()
	-- títulos arco-íris
	RunService.Heartbeat:Connect(function()
		local color = Color3.fromHSV((os.clock() * 0.25) % 1, 0.7, 1)
		for _, label in CollectionService:GetTagged("RainbowText") do
			label.TextColor3 = color
		end
	end)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
end

return Auras
