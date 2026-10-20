-- NPCs humanoides (avatar R15 com cores e chapéus blocados) e conversa.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local World = require(Shared.World)
local NPCs = require(Shared.NPCs)

local NPCService = {}

NPCService.QuestHook = function(_player, _kind, _target, _amount) end

local folder = Instance.new("Folder")
folder.Name = "NPCs"
folder.Parent = workspace

local function hatPart(parent, head, size, offset, color, material, shape)
	local p = Instance.new("Part")
	if shape then
		p.Shape = shape
	end
	p.Size = size
	p.CFrame = head.CFrame * offset
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local CYL = CFrame.Angles(0, 0, math.rad(90))

local function addHat(model, head, style, color)
	local s = head.Size.Y
	if style == "helmet" then
		hatPart(model, head, Vector3.new(s * 1.15, s * 0.6, s * 1.15), CFrame.new(0, s * 0.35, 0), Color3.fromRGB(150, 150, 160), Enum.Material.Metal)
		hatPart(model, head, Vector3.new(0.2, s * 0.5, s * 0.3), CFrame.new(0, s * 0.6, 0), Color3.fromRGB(180, 40, 40), Enum.Material.Fabric)
	elseif style == "bandana" then
		hatPart(model, head, Vector3.new(s * 1.08, s * 0.3, s * 1.08), CFrame.new(0, s * 0.3, 0), Color3.fromRGB(160, 40, 40), Enum.Material.Fabric)
	elseif style == "witch" or style == "wizard" then
		local hatColor = if style == "witch" then Color3.fromRGB(40, 70, 50) else Color3.fromRGB(70, 50, 140)
		hatPart(model, head, Vector3.new(0.2, s * 1.8, s * 1.8), CFrame.new(0, s * 0.5, 0) * CYL, hatColor, Enum.Material.Fabric, Enum.PartType.Cylinder)
		for i = 1, 4 do
			hatPart(model, head, Vector3.new(s * 0.45, s * (1.1 - i * 0.22), s * (1.1 - i * 0.22)), CFrame.new(0, s * (0.6 + i * 0.4), -i * 0.05) * CYL, hatColor, Enum.Material.Fabric, Enum.PartType.Cylinder)
		end
	elseif style == "cap" then
		hatPart(model, head, Vector3.new(s * 1.08, s * 0.4, s * 1.08), CFrame.new(0, s * 0.4, 0), color or Color3.fromRGB(60, 80, 140), Enum.Material.Fabric)
		hatPart(model, head, Vector3.new(s * 0.9, 0.12, s * 0.6), CFrame.new(0, s * 0.25, -s * 0.7), color or Color3.fromRGB(60, 80, 140), Enum.Material.Fabric)
	elseif style == "headband" then
		hatPart(model, head, Vector3.new(s * 1.06, s * 0.18, s * 1.06), CFrame.new(0, s * 0.2, 0), Color3.fromRGB(220, 220, 220), Enum.Material.Fabric)
	elseif style == "straw" then
		hatPart(model, head, Vector3.new(0.15, s * 2.4, s * 2.4), CFrame.new(0, s * 0.45, 0) * CYL, Color3.fromRGB(225, 195, 110), Enum.Material.Fabric, Enum.PartType.Cylinder)
		hatPart(model, head, Vector3.new(s * 0.45, s * 1.05, s * 1.05), CFrame.new(0, s * 0.65, 0) * CYL, Color3.fromRGB(225, 195, 110), Enum.Material.Fabric, Enum.PartType.Cylinder)
	elseif style == "hood" then
		hatPart(model, head, Vector3.new(s * 1.2, s * 1.15, s * 1.2), CFrame.new(0, s * 0.12, s * 0.08), Color3.fromRGB(70, 90, 50), Enum.Material.Fabric)
	elseif style == "miner" then
		hatPart(model, head, Vector3.new(s * 1.12, s * 0.5, s * 1.12), CFrame.new(0, s * 0.4, 0), Color3.fromRGB(230, 180, 40), Enum.Material.SmoothPlastic)
		local lamp = hatPart(model, head, Vector3.new(0.35, 0.35, 0.2), CFrame.new(0, s * 0.45, -s * 0.58), Color3.fromRGB(255, 250, 200), Enum.Material.Neon)
		local light = Instance.new("SpotLight")
		light.Brightness = 3
		light.Range = 20
		light.Face = Enum.NormalId.Front
		light.Parent = lamp
	end
end

-- Altura real do chão (terreno em voxels ou plataformas do mapa), por raycast de cima para baixo.
-- A fórmula do relevo é só aproximada depois de virar voxel, então não serve para encostar os pés.
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
groundParams.RespectCanCollide = true -- ignora copas de árvores e enfeites sem colisão
function NPCService.groundHeight(x, z)
	local list = { workspace.Terrain }
	local world = workspace:FindFirstChild("Mundo")
	if world then
		table.insert(list, world)
	end
	groundParams.FilterDescendantsInstances = list
	local result = workspace:Raycast(Vector3.new(x, 500, z), Vector3.new(0, -700, 0), groundParams)
	if result then
		return result.Position.Y
	end
	return World.height(x, z)
end

local function blockNpc(npc)
	-- reserva caso o avatar R15 não possa ser criado
	local model = Instance.new("Model")
	local function block(name, size, offset, color)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = CFrame.new(offset)
		p.Color = color
		p.Anchored = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.Parent = model
		return p
	end
	block("Perna", Vector3.new(0.9, 2, 1), Vector3.new(-0.5, 1, 0), npc.pants)
	block("Perna", Vector3.new(0.9, 2, 1), Vector3.new(0.5, 1, 0), npc.pants)
	local torso = block("UpperTorso", Vector3.new(2, 2, 1), Vector3.new(0, 3, 0), npc.shirt)
	block("Braco", Vector3.new(1, 2, 1), Vector3.new(-1.5, 3, 0), npc.shirt)
	block("Braco", Vector3.new(1, 2, 1), Vector3.new(1.5, 3, 0), npc.shirt)
	local head = block("Head", Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, 4.6, 0), npc.skin)
	local root = block("HumanoidRootPart", Vector3.new(2, 2, 1), Vector3.new(0, 3, 0), npc.shirt)
	root.Transparency = 1
	model.PrimaryPart = root
	return model, head, torso
end

local function createNpc(npc)
	local model, head
	local ok = pcall(function()
		local description = Instance.new("HumanoidDescription")
		description.HeadColor = npc.skin
		description.LeftArmColor = npc.shirt
		description.RightArmColor = npc.shirt
		description.TorsoColor = npc.shirt
		description.LeftLegColor = npc.pants
		description.RightLegColor = npc.pants
		model = Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if ok and model and model:FindFirstChild("HumanoidRootPart") then
		head = model:FindFirstChild("Head")
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		end
		model.PrimaryPart = model.HumanoidRootPart
		for _, p in model:GetDescendants() do
			if p:IsA("BasePart") then
				p.Anchored = true
			end
		end
	else
		model, head = blockNpc(npc)
	end
	model.Name = npc.name
	local ground = NPCService.groundHeight(npc.x, npc.z)
	-- altura da raiz acima do chão: em R15 é HipHeight + metade da raiz
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model.PrimaryPart
	local rootHeight = if humanoid and root then humanoid.HipHeight + root.Size.Y / 2 else 3
	if rootHeight < 2 then
		rootHeight = 3
	end
	model:PivotTo(CFrame.new(npc.x, ground + rootHeight, npc.z) * CFrame.Angles(0, npc.yaw, 0))
	if head then
		addHat(model, head, npc.hat)
	end
	return model
end

local function addPrompt(parentPart, npc)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "NPCPrompt"
	prompt.ActionText = if npc.board then "Ver contratos" else "Falar"
	prompt.ObjectText = npc.name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("NpcId", npc.id)
	prompt.Parent = parentPart
	prompt.Triggered:Connect(function(player)
		NPCService.talk(player, npc.id)
	end)
	return prompt
end

function NPCService.talk(player, npcId)
	if typeof(npcId) ~= "string" or not NPCs.ById[npcId] then
		return
	end
	NPCService.QuestHook(player, "talk", npcId, 1)
end

function NPCService.spawn(boardPart)
	for _, npc in NPCs.List do
		if npc.board then
			if boardPart then
				boardPart:SetAttribute("NpcId", npc.id)
				CollectionService:AddTag(boardPart, "NPC")
				addPrompt(boardPart, npc)
			end
		else
			local model = createNpc(npc)
			model:SetAttribute("NpcId", npc.id)
			CollectionService:AddTag(model, "NPC")
			model.Parent = folder
			addPrompt(model.PrimaryPart, npc)
		end
	end
end

return NPCService
