-- Coleta: minerar, colher e cortar. Cada ponto some ao ser coletado e volta depois de um tempo.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Resources = require(Shared.Resources)
local Skills = require(Shared.Skills)
local Remotes = require(Shared.Remotes)

local PlayerService = require(script.Parent.PlayerService)
local SkillService = require(script.Parent.SkillService)

local ResourceService = {}

local function setHarvested(model, harvested)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and p:GetAttribute("Harvestable") then
			if harvested then
				p:SetAttribute("OriginalTransparency", p.Transparency)
				p.Transparency = 1
				p.CanCollide = false
			else
				p.Transparency = p:GetAttribute("OriginalTransparency") or 0
			end
		elseif p:IsA("PointLight") or p:IsA("ParticleEmitter") then
			p.Enabled = not harvested
		end
	end
	model:SetAttribute("Depleted", harvested)
end

local function onTriggered(model, prompt, player)
	if model:GetAttribute("Depleted") then
		return
	end
	local def = Resources.Nodes[model:GetAttribute("NodeType")]
	if not def then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or (root.Position - model:GetPivot().Position).Magnitude > 16 then
		return
	end
	local level = SkillService.getLevel(player, def.skill)
	if level < def.level then
		Remotes.Notify:FireClient(player, { kind = "message", text = ("Precisa de %s nível %d."):format(Skills.List[def.skill].name, def.level) })
		return
	end
	local amount = math.random(def.amount[1], def.amount[2])
	-- chance de coleta extra com nível alto
	if math.random() < math.min(0.4, (level - def.level) * 0.02) then
		amount += 1
	end
	setHarvested(model, true)
	prompt.Enabled = false
	PlayerService.addMaterial(player, def.item, amount)
	SkillService.addXP(player, def.skill, def.xp)
	Remotes.Fx:FireAllClients("gather", model:GetPivot().Position, def.color, def.skill)
	task.delay(def.respawn, function()
		if model.Parent then
			setHarvested(model, false)
			prompt.Enabled = true
		end
	end)
end

function ResourceService.init()
	local positions = {} -- [tipo] = { "x,z", ... }
	for _, model in CollectionService:GetTagged("ResourceNode") do
		local prompt = model:FindFirstChild("ResourcePrompt", true)
		if prompt then
			prompt.Triggered:Connect(function(player)
				onTriggered(model, prompt, player)
			end)
		end
		local nodeType = model:GetAttribute("NodeType")
		if nodeType and model.PrimaryPart then
			local position = model.PrimaryPart.Position
			positions[nodeType] = positions[nodeType] or {}
			table.insert(positions[nodeType], ("%d,%d"):format(math.round(position.X), math.round(position.Z)))
		end
	end
	-- Posições de todos os pontos de coleta para o cliente (com streaming ele só tem as peças por perto):
	-- o Auto e o feixe do objetivo acham o ponto mais perto mesmo longe. Um StringValue por tipo, "x,z;x,z".
	local folder = Instance.new("Folder")
	folder.Name = "PontosColeta"
	for nodeType, list in positions do
		local value = Instance.new("StringValue")
		value.Name = nodeType
		value.Value = table.concat(list, ";")
		value.Parent = folder
	end
	folder.Parent = ReplicatedStorage
end

return ResourceService
