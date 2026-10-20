-- Marcadores no mundo: nome dos NPCs com ❗ (missão disponível) / ❓ (entregar),
-- e o marcador do objetivo da missão rastreada (feixe + distância).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local World = require(Shared.World)
local NPCs = require(Shared.NPCs)
local Quests = require(Shared.Quests)
local Enemies = require(Shared.Enemies)
local Resources = require(Shared.Resources)

local UI = require(script.Parent.UI)
local State = require(script.Parent.State)

local WorldMarkers = {}

local player = Players.LocalPlayer
local npcGuis = {}
local beam, beamGui, beamLabel = nil, nil, nil
local target = nil

local function npcPosition(npcId)
	local npc = NPCs.ById[npcId]
	if not npc then
		return nil
	end
	return Vector3.new(npc.x, World.height(npc.x, npc.z), npc.z)
end

local function attachNpcGui(instance)
	local npcId = instance:GetAttribute("NpcId")
	local npc = npcId and NPCs.ById[npcId]
	if not npc or npcGuis[npcId] then
		return
	end
	local adornee = if instance:IsA("Model") then (instance:FindFirstChild("Head") or instance.PrimaryPart) else instance
	local gui = UI.new("BillboardGui", { Size = UDim2.fromOffset(220, 74), StudsOffset = Vector3.new(0, 2.6, 0), MaxDistance = 110, LightInfluence = 0, Adornee = adornee, Parent = adornee })
	local marker = UI.label({ Text = "", Size = UDim2.new(1, 0, 0, 34), TextXAlignment = Enum.TextXAlignment.Center, Font = Enum.Font.GothamBlack, TextColor3 = UI.Colors.Gold, Parent = gui }, { UI.textStroke(2.5) })
	UI.label({ Text = npc.name, Position = UDim2.fromOffset(0, 34), Size = UDim2.new(1, 0, 0, 22), TextXAlignment = Enum.TextXAlignment.Center, Font = Enum.Font.GothamBlack, Parent = gui }, { UI.textStroke(1.5) })
	UI.label({ Text = npc.title, Position = UDim2.fromOffset(0, 56), Size = UDim2.new(1, 0, 0, 16), TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = UI.Colors.SubText, Parent = gui }, { UI.textStroke(1) })
	npcGuis[npcId] = { gui = gui, marker = marker }
end

local function updateNpcMarkers(data)
	local quests = data.quests
	local ready = {}
	for _, entry in (quests and quests.active or {}) do
		local def = Quests.ById[entry.id]
		if def and entry.ready and def.turnIn then
			ready[def.turnIn] = true
		end
		-- objetivo "fale com" também marca o NPC
		if def then
			for i, objective in def.objectives do
				if objective.type == "talk" and entry.objectives[i].progress < 1 then
					ready[objective.npc] = ready[objective.npc] or "talk"
				end
			end
		end
	end
	for npcId, info in npcGuis do
		local available = quests and quests.available and quests.available[npcId]
		if ready[npcId] == true then
			info.marker.Text = "❓"
			info.marker.TextColor3 = UI.Colors.Green
		elseif available and #available > 0 then
			info.marker.Text = "❗"
			info.marker.TextColor3 = UI.Colors.Gold
		elseif ready[npcId] == "talk" then
			info.marker.Text = "💬"
			info.marker.TextColor3 = Color3.fromRGB(150, 220, 255)
		else
			info.marker.Text = ""
		end
	end
end

-- ===================== OBJETIVO =====================

local function nearestCamp(enemyId, from)
	local best, bestDistance = nil, math.huge
	for _, camp in Enemies.Camps do
		if camp.spawns[enemyId] then
			local position = Vector3.new(camp.center.X, World.height(camp.center.X, camp.center.Y), camp.center.Y)
			local distance = (position - from).Magnitude
			if distance < bestDistance then
				best, bestDistance = position, distance
			end
		end
	end
	return best
end

local function nearestNode(itemId, from)
	local best, bestDistance = nil, math.huge
	for _, model in CollectionService:GetTagged("ResourceNode") do
		local def = Resources.Nodes[model:GetAttribute("NodeType")]
		if def and def.item == itemId and not model:GetAttribute("Depleted") and model.PrimaryPart then
			local distance = (model.PrimaryPart.Position - from).Magnitude
			if distance < bestDistance then
				best, bestDistance = model.PrimaryPart.Position, distance
			end
		end
	end
	return best
end

local function enemyDropping(itemId, from)
	local best, bestDistance = nil, math.huge
	for enemyId, def in Enemies.Defs do
		for _, drop in def.drops or {} do
			if drop.id == itemId and drop.chance >= 0.3 then
				local position = nearestCamp(enemyId, from)
				if position and (position - from).Magnitude < bestDistance then
					best, bestDistance = position, (position - from).Magnitude
				end
			end
		end
	end
	return best
end

local SERVICE_NPC = { forge = "bruno", alchemy = "mira", enchant = "elric", upgrade = "bruno", upgradeTo = "bruno", chest = "otto", hit = "kael", parry = "kael", rhythm = "kael" }

local function objectiveTarget(def, entry, from)
	if entry.ready and def.turnIn then
		return npcPosition(def.turnIn), "Entregar"
	end
	for i, objective in def.objectives do
		local progress = entry.objectives[i]
		if progress.progress < progress.amount then
			local kind = objective.type
			if kind == "kill" and objective.target ~= "any" then
				return nearestCamp(objective.target, from), objective.text
			elseif kind == "hit" then
				return npcPosition("kael"), objective.text
			elseif kind == "gather" then
				return nearestNode(objective.item, from) or enemyDropping(objective.item, from), objective.text
			elseif kind == "deliver" then
				return nearestNode(objective.item, from) or enemyDropping(objective.item, from), objective.text
			elseif kind == "talk" then
				return npcPosition(objective.npc), objective.text
			elseif kind == "explore" then
				local loc = World.Locations[objective.location]
				if loc then
					return Vector3.new(loc.x, World.height(loc.x, loc.z), loc.z), objective.text
				end
			elseif kind == "discover" then
				local stone = World.WaystoneById[objective.target]
				if stone then
					return Vector3.new(stone.x, World.height(stone.x, stone.z), stone.z), objective.text
				end
			elseif kind == "craft" then
				local npcId = if objective.item == "forge" or (objective.item and not string.find(objective.item, "pocao") and objective.item ~= "alchemy" and objective.item ~= "elixir_forca") then "bruno" else "mira"
				return npcPosition(npcId), objective.text
			elseif SERVICE_NPC[kind] then
				return npcPosition(SERVICE_NPC[kind]), objective.text
			end
		end
	end
	return nil
end

local function ensureBeam()
	if beam then
		return
	end
	beam = Instance.new("Part")
	beam.Name = "MarcadorObjetivo"
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.CanTouch = false
	beam.CastShadow = false
	beam.Shape = Enum.PartType.Cylinder
	beam.Size = Vector3.new(60, 1.2, 1.2)
	beam.Material = Enum.Material.Neon
	beam.Color = Color3.fromRGB(255, 215, 80)
	beam.Transparency = 0.6
	beam.Parent = workspace
	beamGui = UI.new("BillboardGui", { Size = UDim2.fromOffset(200, 40), AlwaysOnTop = true, LightInfluence = 0, Adornee = beam, Parent = beam })
	beamLabel = UI.label({ Text = "", Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = Color3.fromRGB(255, 225, 120), Font = Enum.Font.GothamBlack, Parent = beamGui }, { UI.textStroke(2) })
end

local function refreshTarget()
	local data = State.data
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	target = nil
	if not data or not data.quests or not root then
		return
	end
	local tracked = nil
	for _, entry in data.quests.active do
		if entry.id == data.quests.tracked then
			tracked = entry
		end
	end
	tracked = tracked or data.quests.active[1]
	if not tracked then
		-- sem missão: aponta para o NPC mais próximo com missão
		local best, bestDistance = nil, math.huge
		for npcId, list in data.quests.available or {} do
			if #list > 0 then
				local position = npcPosition(npcId)
				if position and (position - root.Position).Magnitude < bestDistance then
					best, bestDistance = position, (position - root.Position).Magnitude
				end
			end
		end
		if best then
			target = { position = best, text = "Nova missão" }
		end
		return
	end
	local def = Quests.ById[tracked.id]
	if def then
		local position, text = objectiveTarget(def, tracked, root.Position)
		if position then
			target = { position = position, text = text }
		end
	end
end

function WorldMarkers.init()
	for _, instance in CollectionService:GetTagged("NPC") do
		attachNpcGui(instance)
	end
	CollectionService:GetInstanceAddedSignal("NPC"):Connect(attachNpcGui)
	State.Changed:Connect(function(data)
		updateNpcMarkers(data)
		refreshTarget()
	end)
	ensureBeam()
	local nextRefresh = 0
	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		if now > nextRefresh then
			nextRefresh = now + 1.5
			refreshTarget()
		end
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not target or not root then
			beam.Parent = nil
			return
		end
		local distance = (Vector3.new(target.position.X, 0, target.position.Z) - Vector3.new(root.Position.X, 0, root.Position.Z)).Magnitude
		if distance < 10 then
			beam.Parent = nil
			return
		end
		beam.Parent = workspace
		beam.CFrame = CFrame.new(target.position + Vector3.new(0, 30, 0)) * CFrame.Angles(0, 0, math.rad(90))
		beamLabel.Text = ("📍 %s • %dm"):format(target.text, math.floor(distance))
	end)
end

return WorldMarkers
