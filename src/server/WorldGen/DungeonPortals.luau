-- Portais das masmorras no mapa: arco de pedra com degraus, runas, braseiros e um redemoinho de luz.
-- O prompt "PortalMasmorra" (atributo DungeonId) é tratado pelo DungeonService.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local World = require(Shared.World)
local Dungeons = require(Shared.Dungeons)

local Props = require(script.Parent.Props)
local Placement = require(script.Parent.Placement)

local DungeonPortals = {}

local part = Props.part
local M = Enum.Material

local THEME = {
	caverna = { stone = Color3.fromRGB(105, 90, 75), glow = Color3.fromRGB(255, 150, 60), material = M.Slate },
	cripta = { stone = Color3.fromRGB(95, 95, 110), glow = Color3.fromRGB(140, 120, 255), material = M.Cobblestone },
}

local function build(parent, dungeon)
	local theme = THEME[dungeon.theme] or THEME.cripta
	local position = dungeon.position
	-- portal virado para a vila
	local toTown = World.TownCenter - position
	local yaw = math.atan2(-toTown.X, -toTown.Z)
	local cf = CFrame.new(position) * CFrame.Angles(0, yaw, 0)
	local model = Instance.new("Model")
	model.Name = "Portal_" .. dungeon.id

	-- plataforma em degraus (enterrada um pouco para não flutuar em chão torto)
	for i, size in { 26, 21, 16 } do
		part(model, { Name = "Degrau", Size = Vector3.new(size, 1.2, size * 0.7), CFrame = cf * CFrame.new(0, -0.6 + i * 1.0, 0), Color = theme.stone:Lerp(Color3.new(0, 0, 0), 0.1 * i), Material = theme.material })
	end
	local floorY = 3.4
	-- pilares com base e capitel
	for _, side in { -1, 1 } do
		local base = cf * CFrame.new(side * 6.5, floorY, 0)
		part(model, { Name = "BasePilar", Size = Vector3.new(3.2, 1.2, 3.2), CFrame = base * CFrame.new(0, 0.6, 0), Color = theme.stone, Material = theme.material })
		part(model, { Name = "Pilar", Size = Vector3.new(2.4, 13, 2.4), CFrame = base * CFrame.new(0, 7.7, 0), Color = theme.stone:Lerp(Color3.new(1, 1, 1), 0.08), Material = theme.material })
		part(model, { Name = "Capitel", Size = Vector3.new(3.2, 1, 3.2), CFrame = base * CFrame.new(0, 14.7, 0), Color = theme.stone, Material = theme.material })
		-- runas acesas nos pilares
		for i = 0, 2 do
			local rune = part(model, { Name = "Runa", Size = Vector3.new(0.9, 0.9, 0.15), CFrame = base * CFrame.new(0, 4 + i * 3.2, -1.25) * CFrame.Angles(0, 0, math.rad(45)), Color = theme.glow, Material = M.Neon, CanCollide = false })
			rune.Transparency = 0.1
		end
		-- braseiro na frente de cada pilar
		local brazier = cf * CFrame.new(side * 10, floorY, -4)
		Props.column(model, brazier, 3, 1.2, Color3.fromRGB(50, 45, 45), M.Metal)
		Props.column(model, brazier * CFrame.new(0, 3, 0), 0.8, 2.6, Color3.fromRGB(60, 55, 55), M.Metal)
		Props.fire(model, (brazier * CFrame.new(0, 3.8, 0)).Position, 1)
	end
	-- verga com pedra-chave e o nome gravado
	-- arco de pedra (aduelas em semicírculo apoiadas nos capitéis) com pedra-chave e runas
	local springY = floorY + 15.2
	local radius = 6.5
	for i = 0, 10 do
		local angle = math.pi * (i + 0.5) / 11
		local stone = if i % 2 == 0 then theme.stone else theme.stone:Lerp(Color3.new(0, 0, 0), 0.12)
		part(model, { Name = "Aduela", Size = Vector3.new(2.0, 2.4, 3.4), CFrame = cf * CFrame.new(math.cos(angle) * radius, springY + math.sin(angle) * radius, 0) * CFrame.Angles(0, 0, angle - math.pi / 2), Color = stone, Material = theme.material })
		if i % 3 == 1 then
			part(model, { Name = "RunaArco", Size = Vector3.new(0.6, 0.6, 0.12), CFrame = cf * CFrame.new(math.cos(angle) * radius, springY + math.sin(angle) * radius, -1.76) * CFrame.Angles(0, 0, math.rad(45)), Color = theme.glow, Material = M.Neon, CanCollide = false })
		end
	end
	part(model, { Name = "PedraChave", Size = Vector3.new(2.4, 3.2, 3.9), CFrame = cf * CFrame.new(0, springY + radius + 0.3, 0), Color = theme.stone:Lerp(Color3.new(1, 1, 1), 0.15), Material = theme.material })
	local gem = part(model, { Name = "Gema", Size = Vector3.new(1.2, 1.2, 1.2), CFrame = cf * CFrame.new(0, springY + radius + 0.3, -2.1) * CFrame.Angles(math.rad(45), 0, math.rad(45)), Color = theme.glow, Material = M.Neon, CanCollide = false })
	CollectionService:AddTag(gem, "Spin")
	-- redemoinho de luz dentro do arco
	local swirl = part(model, {
		Name = "Redemoinho",
		Size = Vector3.new(0.4, 11, 11),
		Shape = Enum.PartType.Cylinder,
		CFrame = cf * CFrame.new(0, floorY + 7.6, 0) * CFrame.Angles(0, math.rad(90), 0),
		Color = theme.glow,
		Material = M.Neon,
		Transparency = 0.35,
		CanCollide = false,
	})
	-- anel em volta do redemoinho
	part(model, { Name = "Anel", Size = Vector3.new(0.5, 12.4, 12.4), Shape = Enum.PartType.Cylinder, CFrame = cf * CFrame.new(0, floorY + 7.6, 0.15) * CFrame.Angles(0, math.rad(90), 0), Color = theme.stone:Lerp(Color3.new(0, 0, 0), 0.3), Material = theme.material, CanCollide = false })
	Props.light(swirl, theme.glow, 30, 2.5, true)
	local sparks = Instance.new("ParticleEmitter")
	sparks.Color = ColorSequence.new(theme.glow, Color3.new(1, 1, 1))
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new(0.5, 0)
	sparks.Lifetime = NumberRange.new(1, 2)
	sparks.Rate = 22
	sparks.Speed = NumberRange.new(1, 3)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Parent = swirl

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PortalMasmorra"
	prompt.ActionText = "Entrar na masmorra"
	prompt.ObjectText = ("%s (nível %d+)"):format(dungeon.name, dungeon.minLevel)
	prompt.MaxActivationDistance = 14
	prompt.HoldDuration = 0.3
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("DungeonId", dungeon.id)
	prompt.Parent = swirl

	Props.billboard(gem, ("%s %s\nnível recomendado %d"):format(dungeon.icon, string.upper(dungeon.name), dungeon.level), theme.glow, 4, 200)
	model.Parent = parent
	Placement.reserve(position.X, position.Z, 16 * World.Scale, "masmorra")
	return model
end

function DungeonPortals.build(parent)
	local folder = Instance.new("Folder")
	folder.Name = "Masmorras"
	folder.Parent = parent
	for _, dungeon in Dungeons.List do
		build(folder, dungeon)
	end
	return folder
end

return DungeonPortals
