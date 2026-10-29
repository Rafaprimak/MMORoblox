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
local Items = require(Shared.Items)

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

-- Segredo do local: um mecanismo escondido (feno, runa, alçapão...). Recompensa uma vez por jogador.
local function onSecret(player, prompt)
	local poi = Points.ById[prompt:GetAttribute("PoiId") or ""]
	local data = DataService.get(player)
	local root = rootOf(player)
	local holder = prompt.Parent
	if not poi or not poi.secret or not data or not root or not holder or not holder:IsA("BasePart") then
		return
	end
	if (holder.Position - root.Position).Magnitude > 22 then
		return
	end
	if data.poiSecrets[poi.id] then
		Remotes.Notify:FireClient(player, { kind = "message", text = "Você já descobriu o segredo deste lugar." })
		return
	end
	data.poiSecrets[poi.id] = true
	local reward = poi.secret
	PlayerService.addGold(player, reward.gold or 0)
	local extra = ""
	if reward.material and Items.Materials[reward.material[1]] then
		PlayerService.addMaterial(player, reward.material[1], reward.material[2])
		extra = ("  •  +%d %s"):format(reward.material[2], Items.Materials[reward.material[1]].name)
	end
	Remotes.Notify:FireClient(player, {
		kind = "banner",
		text = "SEGREDO ENCONTRADO!",
		sub = ("%s  +%d de ouro%s"):format(reward.text or "", reward.gold or 0, extra),
		color = Color3.fromRGB(150, 230, 255),
		duration = 6,
	})
	ExploreService.QuestHook(player, "poiSecret", poi.id, 1)
	PlayerService.markDirty(player)
end

local secretPrompts = {} -- [poiId] = prompt "SegredoLocal"

-- Auto (VIP com Auto Caçar ligado): pega o segredo do local quando o personagem já está ao lado dele.
-- Mesmas regras do prompt (distância conferida no onSecret).
function ExploreService.autoSecret(player, poiId)
	local prompt = secretPrompts[poiId]
	if not player:GetAttribute("AutoFarm") or not prompt or not prompt.Parent then
		return { ok = false }
	end
	onSecret(player, prompt)
	return { ok = true }
end

function ExploreService.start()
	-- posição de cada segredo para o cliente (o Auto vai direto até ele, mesmo antes de chegar pelo streaming)
	local published = Instance.new("Folder")
	published.Name = "SegredosLocais"
	local locals = workspace:FindFirstChild("LocaisDeInteresse", true)
	for _, prompt in if locals then locals:GetDescendants() else {} do
		local poiId = prompt:GetAttribute("PoiId")
		if prompt:IsA("ProximityPrompt") and prompt.Name == "SegredoLocal" and poiId and prompt.Parent:IsA("BasePart") then
			secretPrompts[poiId] = prompt
			local value = Instance.new("Vector3Value")
			value.Name = poiId
			value.Value = prompt.Parent.Position
			value.Parent = published
		end
	end
	published.Parent = ReplicatedStorage
	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		if prompt.Name == "BauLocal" then
			onChest(player, prompt)
		elseif prompt.Name == "SegredoLocal" then
			onSecret(player, prompt)
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
