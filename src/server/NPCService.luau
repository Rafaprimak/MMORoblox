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
	elseif style == "wide" then
		-- chapéu de aba larga de viajante, com faixa e pena
		hatPart(model, head, Vector3.new(0.12, s * 2.1, s * 2.1), CFrame.new(0, s * 0.42, 0) * CYL, Color3.fromRGB(45, 32, 28), Enum.Material.Fabric, Enum.PartType.Cylinder)
		hatPart(model, head, Vector3.new(s * 0.55, s * 1.05, s * 1.05), CFrame.new(0, s * 0.7, 0) * CYL, Color3.fromRGB(55, 40, 34), Enum.Material.Fabric, Enum.PartType.Cylinder)
		hatPart(model, head, Vector3.new(s * 0.16, s * 1.08, s * 1.08), CFrame.new(0, s * 0.52, 0) * CYL, Color3.fromRGB(120, 60, 150), Enum.Material.Fabric, Enum.PartType.Cylinder)
		hatPart(model, head, Vector3.new(0.08, s * 0.9, s * 0.22), CFrame.new(s * 0.5, s * 0.85, s * 0.15) * CFrame.Angles(0, 0, math.rad(-25)), Color3.fromRGB(200, 60, 60), Enum.Material.Fabric)
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
-- startY: de onde o raio começa (NPCs dentro de casas começam abaixo do telhado)
function NPCService.groundHeight(x, z, startY)
	local list = { workspace.Terrain }
	local world = workspace:FindFirstChild("Mundo")
	if world then
		table.insert(list, world)
	end
	groundParams.FilterDescendantsInstances = list
	local top = startY or 500
	local result = workspace:Raycast(Vector3.new(x, top, z), Vector3.new(0, -(top + 200), 0), groundParams)
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

-- Visual de cada NPC: cabelo, barba e roupa do ofício (peças presas no corpo R15)
local LOOKS = {
	lyra = { hair = Color3.fromRGB(150, 70, 35), long = true, outfit = "armor" },
	bruno = { hair = Color3.fromRGB(40, 30, 25), beard = Color3.fromRGB(40, 30, 25), outfit = "apron" },
	mira = { hair = Color3.fromRGB(60, 35, 25), long = true, outfit = "robe", robe = Color3.fromRGB(50, 110, 70) },
	elric = { hair = Color3.fromRGB(220, 220, 225), beard = Color3.fromRGB(225, 225, 230), longBeard = true, outfit = "robe", robe = Color3.fromRGB(75, 45, 130) },
	otto = { hair = Color3.fromRGB(90, 60, 35), beard = Color3.fromRGB(90, 60, 35), outfit = "vest" },
	kael = { hair = Color3.fromRGB(25, 25, 25), beard = Color3.fromRGB(25, 25, 25), outfit = "tunic" },
	pedro = { hair = Color3.fromRGB(130, 90, 50), outfit = "tunic" },
	nia = { hair = Color3.fromRGB(30, 20, 15), long = true, outfit = "tunic" },
	gus = { hair = Color3.fromRGB(70, 50, 35), beard = Color3.fromRGB(70, 50, 35), outfit = "apron" },
	orin = { hair = Color3.fromRGB(235, 235, 240), beard = Color3.fromRGB(240, 240, 245), longBeard = true, outfit = "robe", robe = Color3.fromRGB(200, 200, 210) },
	tomas = { hair = Color3.fromRGB(60, 45, 30), beard = Color3.fromRGB(60, 45, 30), outfit = "armor" },
	sol = { hair = Color3.fromRGB(20, 15, 10), long = true, outfit = "vest" },
	varg = { hair = Color3.fromRGB(70, 65, 70), beard = Color3.fromRGB(80, 75, 80), longBeard = true, outfit = "merchant" },
}

local function addLook(model, npc)
	local look = LOOKS[npc.id]
	local head = model:FindFirstChild("Head")
	local torso = model:FindFirstChild("UpperTorso")
	local lower = model:FindFirstChild("LowerTorso")
	if not look or not head or not torso then
		return
	end
	local function piece(attach, size, offset, color, material, shape)
		local p = hatPart(model, attach, size, offset, color, material, shape)
		return p
	end
	local hs = head.Size
	local ts = torso.Size
	-- cabelo atrás e dos lados (aparece por baixo dos chapéus)
	piece(head, Vector3.new(hs.X * 1.08, hs.Y * (if look.long then 1.25 else 0.7), hs.Z * 0.35), CFrame.new(0, if look.long then -0.05 else 0.2, hs.Z * 0.42), look.hair, Enum.Material.SmoothPlastic)
	for _, side in { -1, 1 } do
		piece(head, Vector3.new(hs.X * 0.12, hs.Y * 0.55, hs.Z * 0.5), CFrame.new(side * hs.X * 0.52, 0.15, 0.15), look.hair, Enum.Material.SmoothPlastic)
	end
	if look.beard then
		piece(head, Vector3.new(hs.X * 0.85, hs.Y * (if look.longBeard then 0.75 else 0.35), hs.Z * 0.3), CFrame.new(0, -hs.Y * (if look.longBeard then 0.48 else 0.32), -hs.Z * 0.45), look.beard, Enum.Material.SmoothPlastic)
		piece(head, Vector3.new(hs.X * 0.5, hs.Y * 0.1, hs.Z * 0.12), CFrame.new(0, -hs.Y * 0.08, -hs.Z * 0.56), look.beard, Enum.Material.SmoothPlastic) -- bigode
	end
	-- roupa do ofício
	if look.outfit == "apron" then
		piece(torso, Vector3.new(ts.X * 0.8, ts.Y * 0.95, 0.12), CFrame.new(0, -0.1, -ts.Z / 2 - 0.06), Color3.fromRGB(110, 70, 40), Enum.Material.Fabric)
		if lower then
			piece(lower, Vector3.new(lower.Size.X * 0.85, 1.6, 0.12), CFrame.new(0, -0.6, -lower.Size.Z / 2 - 0.06), Color3.fromRGB(110, 70, 40), Enum.Material.Fabric)
		end
		for _, side in { -1, 1 } do
			piece(torso, Vector3.new(0.2, ts.Y, ts.Z + 0.15), CFrame.new(side * ts.X * 0.3, 0.05, 0), Color3.fromRGB(80, 50, 30), Enum.Material.Fabric)
		end
	elseif look.outfit == "robe" then
		local robe = look.robe or Color3.fromRGB(80, 60, 120)
		piece(torso, ts + Vector3.new(0.15, 0.05, 0.15), CFrame.new(), robe, Enum.Material.Fabric)
		if lower then
			piece(lower, Vector3.new(lower.Size.X + 0.35, 2.6, lower.Size.Z + 0.45), CFrame.new(0, -1.1, 0), robe, Enum.Material.Fabric)
			piece(lower, Vector3.new(lower.Size.X + 0.4, 0.25, lower.Size.Z + 0.5), CFrame.new(0, 0.1, 0), Color3.fromRGB(220, 180, 90), Enum.Material.Metal)
		end
		piece(torso, Vector3.new(0.35, ts.Y, 0.1), CFrame.new(0, 0, -ts.Z / 2 - 0.1), Color3.fromRGB(220, 180, 90), Enum.Material.Fabric)
	elseif look.outfit == "vest" then
		for _, side in { -1, 1 } do
			piece(torso, Vector3.new(ts.X * 0.38, ts.Y * 0.95, 0.12), CFrame.new(side * ts.X * 0.3, 0, -ts.Z / 2 - 0.06), Color3.fromRGB(120, 40, 40), Enum.Material.Fabric)
		end
		for i = 0, 2 do
			piece(torso, Vector3.one * 0.18, CFrame.new(ts.X * 0.12, 0.5 - i * 0.5, -ts.Z / 2 - 0.13), Color3.fromRGB(230, 190, 80), Enum.Material.Metal, Enum.PartType.Ball)
		end
		if lower then
			piece(lower, Vector3.new(lower.Size.X + 0.1, 0.3, lower.Size.Z + 0.1), CFrame.new(0, 0.15, 0), Color3.fromRGB(60, 40, 25), Enum.Material.Fabric)
		end
	elseif look.outfit == "merchant" then
		-- casaco longo de viajante, cinto com bolsas e chaves, bandoleira com frascos
		local coat = Color3.fromRGB(70, 45, 85)
		piece(torso, ts + Vector3.new(0.18, 0.05, 0.18), CFrame.new(), coat, Enum.Material.Fabric)
		piece(torso, Vector3.new(ts.X * 0.3, ts.Y, 0.08), CFrame.new(0, 0, -ts.Z / 2 - 0.1), Color3.fromRGB(150, 120, 90), Enum.Material.Fabric)
		for _, side in { -1, 1 } do
			piece(torso, Vector3.new(ts.X * 0.18, ts.Y * 0.9, 0.06), CFrame.new(side * ts.X * 0.22, 0.05, -ts.Z / 2 - 0.12), Color3.fromRGB(200, 170, 90), Enum.Material.Fabric) -- lapelas
		end
		piece(torso, Vector3.new(ts.X * 1.25, 0.22, ts.Z + 0.3), CFrame.new(0, 0.1, 0) * CFrame.Angles(0, 0, math.rad(35)), Color3.fromRGB(60, 40, 25), Enum.Material.Leather)
		for i = 0, 2 do
			piece(torso, Vector3.new(0.22, 0.34, 0.22), CFrame.new(-0.45 + i * 0.32, 0.4 - i * 0.22, -ts.Z / 2 - 0.2), Color3.fromHSV(0.1 + i * 0.3, 0.7, 1), Enum.Material.Neon)
		end
		if lower then
			piece(lower, Vector3.new(lower.Size.X + 0.3, 2.2, lower.Size.Z + 0.35), CFrame.new(0, -0.95, 0.03), coat, Enum.Material.Fabric)
			piece(lower, Vector3.new(lower.Size.X + 0.36, 0.28, lower.Size.Z + 0.4), CFrame.new(0, 0.12, 0), Color3.fromRGB(60, 40, 25), Enum.Material.Leather)
			piece(lower, Vector3.new(0.3, 0.3, 0.12), CFrame.new(0, 0.12, -lower.Size.Z / 2 - 0.24), Color3.fromRGB(220, 180, 90), Enum.Material.Metal)
			for _, side in { -1, 1 } do
				piece(lower, Vector3.new(0.45, 0.45, 0.3), CFrame.new(side * lower.Size.X * 0.42, -0.2, -lower.Size.Z / 2 - 0.22), Color3.fromRGB(110, 75, 45), Enum.Material.Leather)
			end
			-- molho de chaves pendurado no cinto
			for i = 0, 2 do
				piece(lower, Vector3.new(0.08, 0.4, 0.06), CFrame.new(0.35 + i * 0.1, -0.15, -lower.Size.Z / 2 - 0.25) * CFrame.Angles(0, 0, math.rad(-15 + i * 15)), Color3.fromRGB(220, 190, 110), Enum.Material.Metal)
			end
		end
	elseif look.outfit == "armor" then
		piece(torso, ts + Vector3.new(0.2, 0.05, 0.2), CFrame.new(), Color3.fromRGB(150, 155, 165), Enum.Material.Metal)
		piece(torso, Vector3.new(ts.X * 0.5, ts.Y * 0.4, 0.15), CFrame.new(0, 0.2, -ts.Z / 2 - 0.12), Color3.fromRGB(40, 70, 150), Enum.Material.Fabric)
		for _, side in { -1, 1 } do
			piece(torso, Vector3.new(0.9, 0.4, 1.2), CFrame.new(side * (ts.X / 2 + 0.25), ts.Y / 2 - 0.1, 0) * CFrame.Angles(0, 0, math.rad(-side * 12)), Color3.fromRGB(170, 175, 185), Enum.Material.Metal)
		end
	else -- túnica com cinto e faixa
		if lower then
			piece(lower, Vector3.new(lower.Size.X + 0.12, 0.3, lower.Size.Z + 0.12), CFrame.new(0, 0.15, 0), Color3.fromRGB(70, 45, 25), Enum.Material.Fabric)
			piece(lower, Vector3.new(0.3, 0.3, 0.15), CFrame.new(0, 0.15, -lower.Size.Z / 2 - 0.12), Color3.fromRGB(220, 180, 90), Enum.Material.Metal)
		end
		piece(torso, Vector3.new(0.3, ts.Y * 1.15, 0.1), CFrame.new(0, 0, -ts.Z / 2 - 0.06) * CFrame.Angles(0, 0, math.rad(35)), Color3.fromRGB(180, 50, 50), Enum.Material.Fabric)
	end
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
	local ground = NPCService.groundHeight(npc.x, npc.z, if npc.indoor then World.TownHeight + 5 * World.Scale else nil)
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
		addLook(model, npc)
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
