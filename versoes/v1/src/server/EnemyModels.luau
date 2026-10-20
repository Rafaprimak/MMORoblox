-- Modelos blocados dos inimigos. Cada builder recebe add(size, position, color, material, transparency, rotation)
-- com o "chão" do modelo em Y = 0 e a frente virada para -Z. Retorna a altura do modelo.
local EnemyModels = {}

local function newPart(model, size, cframe, color, material, transparency)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Transparency = transparency or 0
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

local builders = {}

function builders.slime(add, def)
	local c = def.color
	add(Vector3.new(3, 2.4, 3), Vector3.new(0, 1.2, 0), c, Enum.Material.SmoothPlastic, 0.1)
	add(Vector3.new(2, 0.5, 2), Vector3.new(0, 2.6, 0), c:Lerp(Color3.new(1, 1, 1), 0.3), nil, 0.1)
	add(Vector3.new(0.45, 0.65, 0.1), Vector3.new(-0.6, 1.6, -1.52), Color3.new(0, 0, 0))
	add(Vector3.new(0.45, 0.65, 0.1), Vector3.new(0.6, 1.6, -1.52), Color3.new(0, 0, 0))
	return 2.85
end

function builders.goblin(add, def)
	local skin = def.color
	local cloth = Color3.fromRGB(110, 75, 45)
	local dark = Color3.fromRGB(60, 45, 30)
	local eye = Color3.fromRGB(255, 40, 40)
	add(Vector3.new(0.6, 1.2, 0.6), Vector3.new(-0.45, 0.6, 0), dark)
	add(Vector3.new(0.6, 1.2, 0.6), Vector3.new(0.45, 0.6, 0), dark)
	add(Vector3.new(1.8, 1.6, 1.1), Vector3.new(0, 2.0, 0), cloth)
	add(Vector3.new(0.5, 1.4, 0.5), Vector3.new(-1.15, 2.0, 0), skin)
	add(Vector3.new(0.5, 1.4, 0.5), Vector3.new(1.15, 2.0, 0), skin)
	add(Vector3.new(1.6, 1.4, 1.4), Vector3.new(0, 3.5, 0), skin)
	add(Vector3.new(0.9, 0.3, 0.2), Vector3.new(-1.1, 3.75, 0), skin, nil, nil, CFrame.Angles(0, 0, math.rad(20)))
	add(Vector3.new(0.9, 0.3, 0.2), Vector3.new(1.1, 3.75, 0), skin, nil, nil, CFrame.Angles(0, 0, math.rad(-20)))
	add(Vector3.new(0.32, 0.25, 0.1), Vector3.new(-0.4, 3.65, -0.72), eye, Enum.Material.Neon)
	add(Vector3.new(0.32, 0.25, 0.1), Vector3.new(0.4, 3.65, -0.72), eye, Enum.Material.Neon)
	add(Vector3.new(0.3, 0.45, 0.35), Vector3.new(0, 3.35, -0.85), skin:Lerp(Color3.new(0, 0, 0), 0.15))
	add(Vector3.new(0.45, 2.2, 0.45), Vector3.new(1.15, 2.1, -0.9), Color3.fromRGB(90, 60, 35), Enum.Material.Wood, nil, CFrame.Angles(math.rad(-60), 0, 0))
	local height = 4.3
	if def.crown then
		local gold = Color3.fromRGB(255, 200, 40)
		add(Vector3.new(1.7, 0.45, 1.5), Vector3.new(0, 4.4, 0), gold, Enum.Material.Neon)
		for _, x in { -0.6, 0, 0.6 } do
			add(Vector3.new(0.3, 0.5, 0.3), Vector3.new(x, 4.85, -0.6), gold, Enum.Material.Neon)
		end
		height = 5.1
	end
	return height
end

function builders.skeleton(add, def)
	local bone = def.color
	local eye = Color3.fromRGB(80, 220, 255)
	add(Vector3.new(0.4, 1.6, 0.4), Vector3.new(-0.4, 0.8, 0), bone)
	add(Vector3.new(0.4, 1.6, 0.4), Vector3.new(0.4, 0.8, 0), bone)
	add(Vector3.new(1.2, 0.4, 0.6), Vector3.new(0, 1.8, 0), bone)
	add(Vector3.new(0.3, 1.2, 0.3), Vector3.new(0, 2.6, 0), bone)
	add(Vector3.new(1.5, 1.0, 0.8), Vector3.new(0, 3.0, 0), bone)
	add(Vector3.new(0.35, 1.6, 0.35), Vector3.new(-1.0, 2.9, 0), bone)
	add(Vector3.new(0.35, 1.6, 0.35), Vector3.new(1.0, 2.9, 0), bone)
	add(Vector3.new(1.3, 1.3, 1.3), Vector3.new(0, 4.1, 0), bone)
	add(Vector3.new(0.35, 0.35, 0.1), Vector3.new(-0.3, 4.2, -0.66), eye, Enum.Material.Neon)
	add(Vector3.new(0.35, 0.35, 0.1), Vector3.new(0.3, 4.2, -0.66), eye, Enum.Material.Neon)
	add(Vector3.new(0.25, 2.6, 0.12), Vector3.new(1.0, 3.0, -1.1), Color3.fromRGB(150, 150, 160), Enum.Material.Metal, nil, CFrame.Angles(math.rad(-70), 0, 0))
	return 4.8
end

-- Retorna: model, altura, lista de partes visíveis {part, color} (usada no flash de dano)
function EnemyModels.build(def)
	local model = Instance.new("Model")
	model.Name = def.name
	local scale = def.scale or 1
	local parts = {}

	local function add(size, position, color, material, transparency, rotation)
		local cframe = CFrame.new(position * scale)
		if rotation then
			cframe *= rotation
		end
		local p = newPart(model, size * scale, cframe, color, material, transparency)
		table.insert(parts, { part = p, color = color })
		return p
	end

	local builder = builders[def.shape] or builders.slime
	local height = builder(add, def) * scale
	local radius = def.radius or 1.5

	local root = newPart(model, Vector3.new(radius * 2, height, radius * 2), CFrame.new(0, height / 2, 0), Color3.new(1, 1, 1), nil, 1)
	root.Name = "Root"
	model.PrimaryPart = root

	return model, height, parts
end

return EnemyModels
