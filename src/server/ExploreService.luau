-- Locais de interesse: descoberta ao chegar perto (XP, ouro e aviso) e o baú escondido de cada local
-- (abre uma vez por jogador; o conteúdo sai de um baú da loja, com a roleta no cliente).
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Points = require(Shared.Points)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local PlayerService = require(script.Parent.PlayerService)
local ShopService = require(script.Parent.ShopService)

local ExploreService = {}

ExploreService.QuestHook = function(_player, _kind, _target, _amount) end

local function rootOf(player)
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function discover(player, data, poi)
	data.poi[poi.id] = true
	PlayerService.addXP(player, poi.xp)
	PlayerService.addGold(player, poi.gold)
	Remotes.Notify:FireClient(player, {
		kind = "banner",
		text = ("Local descoberto: %s"):format(poi.name),
		sub = ("+%d XP  •  +%d de ouro  •  procure o baú escondido!"):format(poi.xp, poi.gold),
		color = Color3.fromRGB(255, 215, 120),
		duration = 5,
	})
	ExploreService.QuestHook(player, "poi", poi.id, 1)
	PlayerService.markDirty(player)
end

local function onChest(player, prompt)
	local poi = Points.ById[prompt:GetAttribute("PoiId") or ""]
	local data = DataService.get(player)
	local root = rootOf(player)
	local holder = prompt.Parent
	if not poi or not data or not root or not holder or not holder:IsA("BasePart") then
		return
	end
	if (holder.Position - root.Position).Magnitude > 20 then
		return
	end
	if not data.poi[poi.id] then
		discover(player, data, poi)
	end
	if data.poiChests[poi.id] then
		Remotes.Notify:FireClient(player, { kind = "message", text = "Você já abriu este baú. Explore outros locais!" })
		return
	end
	data.poiChests[poi.id] = true
	ShopService.grant(player, poi.chest)
	ExploreService.QuestHook(player, "poiChest", poi.id, 1)
	PlayerService.markDirty(player)
end

function ExploreService.start()
	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		if prompt.Name == "BauLocal" then
			onChest(player, prompt)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				local data = DataService.get(player)
				local root = rootOf(player)
				if data and root then
					for _, poi in Points.List do
						if not data.poi[poi.id] then
							local dx, dz = root.Position.X - poi.x, root.Position.Z - poi.z
							if dx * dx + dz * dz < poi.radius * poi.radius then
								discover(player, data, poi)
							end
						end
					end
				end
			end
		end
	end)
end

return ExploreService
