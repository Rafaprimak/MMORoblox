-- Modelos blocados dos inimigos com "articulações" para animação procedural no cliente.
-- Cada parte tem um papel (role): body, head, armL, armR, legL, legR, legFL, legFR, legBL, legBR,
-- legA, legB (patas alternadas), tail. joint = ponto de giro (em coordenadas locais).
-- O modelo é montado com os pés em Y = 0 e a frente virada para -Z.
local EnemyModels = {}

local BLACK = Color3.new(0, 0, 0)
local WOOD = Color3.fromRGB(95, 65, 40)

local builders = {}

function builders.slime(add, def)
	local c = def.color
	add("body", Vector3.new(3, 2.4, 3), Vector3.new(0, 1.2, 0), c, Enum.Material.Glass, nil, nil, nil, 0.15)
	add("body", Vector3.new(1.8, 0.5, 1.8), Vector3.new(0, 2.6, 0), c:Lerp(Color3.new(1, 1, 1), 0.35), nil, nil, nil, nil, 0.1)
	add("body", Vector3.new(0.45, 0.65, 0.1), Vector3.new(-0.6, 1.6, -1.52), BLACK)
	add("body", Vector3.new(0.45, 0.65, 0.1), Vector3.new(0.6, 1.6, -1.52), BLACK)
	add("body", Vector3.new(0.8, 0.15, 0.1), Vector3.new(0, 1.05, -1.52), c:Lerp(BLACK, 0.5))
	for _, x in { -0.6, 0.6 } do
		add("body", Vector3.new(0.16, 0.16, 0.05), Vector3.new(x + 0.1, 1.78, -1.58), Color3.new(1, 1, 1), Enum.Material.Neon)
		add("body", Vector3.new(0.35, 0.18, 0.05), Vector3.new(x * 1.45, 1.2, -1.5), Color3.fromRGB(255, 150, 170), nil, nil, nil, nil, 0.3)
	end
	return 2.9
end

function builders.wolf(add, def)
	local fur = def.color
	local dark = fur:Lerp(BLACK, 0.35)
	add("body", Vector3.new(1.6, 1.4, 3.4), Vector3.new(0, 2.2, 0), fur)
	add("body", Vector3.new(1.8, 1.6, 1.4), Vector3.new(0, 2.4, -1.1), dark)
	local neck = Vector3.new(0, 2.7, -1.7)
	add("head", Vector3.new(1.3, 1.2, 1.3), Vector3.new(0, 2.9, -2.2), fur, nil, nil, neck)
	add("head", Vector3.new(0.7, 0.6, 1.0), Vector3.new(0, 2.6, -3.1), dark, nil, nil, neck)
	add("head", Vector3.new(0.3, 0.55, 0.25), Vector3.new(-0.4, 3.7, -2.0), dark, nil, nil, neck)
	add("head", Vector3.new(0.3, 0.55, 0.25), Vector3.new(0.4, 3.7, -2.0), dark, nil, nil, neck)
	add("head", Vector3.new(0.22, 0.15, 0.1), Vector3.new(-0.35, 3.05, -2.87), Color3.fromRGB(255, 220, 60), Enum.Material.Neon, nil, neck)
	add("head", Vector3.new(0.22, 0.15, 0.1), Vector3.new(0.35, 3.05, -2.87), Color3.fromRGB(255, 220, 60), Enum.Material.Neon, nil, neck)
	add("tail", Vector3.new(0.35, 0.35, 1.6), Vector3.new(0, 2.8, 2.2), dark, nil, CFrame.Angles(math.rad(25), 0, 0), Vector3.new(0, 2.6, 1.6))
	add("tail", Vector3.new(0.45, 0.45, 0.6), Vector3.new(0, 3.2, 2.95), fur:Lerp(Color3.new(1, 1, 1), 0.35), nil, CFrame.Angles(math.rad(25), 0, 0), Vector3.new(0, 2.6, 1.6))
	add("head", Vector3.new(0.3, 0.22, 0.12), Vector3.new(0, 2.78, -3.62), BLACK, nil, nil, neck)
	for _, x in { -0.18, 0.18 } do
		add("head", Vector3.new(0.08, 0.2, 0.08), Vector3.new(x, 2.3, -3.45), Color3.fromRGB(245, 240, 225), nil, nil, neck)
	end
	add("body", Vector3.new(1.2, 1.0, 0.5), Vector3.new(0, 1.85, -1.65), fur:Lerp(Color3.new(1, 1, 1), 0.3))
	for i = 0, 3 do
		add("body", Vector3.new(0.3, 0.35, 0.5), Vector3.new(0, 3.0, -1.0 + i * 0.7), dark, nil, CFrame.Angles(math.rad(-20), 0, 0))
	end
	for _, leg in { { "legFL", -0.55, -1.2 }, { "legFR", 0.55, -1.2 }, { "legBL", -0.55, 1.3 }, { "legBR", 0.55, 1.3 } } do
		add(leg[1], Vector3.new(0.45, 1.7, 0.45), Vector3.new(leg[2], 0.85, leg[3]), dark, nil, nil, Vector3.new(leg[2], 1.7, leg[3]))
		add(leg[1], Vector3.new(0.55, 0.25, 0.65), Vector3.new(leg[2], 0.12, leg[3] - 0.08), dark:Lerp(BLACK, 0.3), nil, nil, Vector3.new(leg[2], 1.7, leg[3]))
	end
	return 3.9
end

function builders.boar(add, def)
	local hide = def.color
	local dark = hide:Lerp(BLACK, 0.4)
	add("body", Vector3.new(2.0, 1.7, 3.2), Vector3.new(0, 1.9, 0), hide)
	add("body", Vector3.new(0.4, 0.6, 2.6), Vector3.new(0, 3.0, -0.2), dark)
	local neck = Vector3.new(0, 2.0, -1.5)
	add("head", Vector3.new(1.4, 1.3, 1.3), Vector3.new(0, 1.9, -2.0), hide, nil, nil, neck)
	add("head", Vector3.new(0.8, 0.6, 0.5), Vector3.new(0, 1.6, -2.85), Color3.fromRGB(200, 140, 130), nil, nil, neck)
	add("head", Vector3.new(0.15, 0.7, 0.15), Vector3.new(-0.42, 1.95, -2.85), Color3.fromRGB(245, 240, 220), nil, CFrame.Angles(math.rad(-20), 0, math.rad(15)), neck)
	add("head", Vector3.new(0.15, 0.7, 0.15), Vector3.new(0.42, 1.95, -2.85), Color3.fromRGB(245, 240, 220), nil, CFrame.Angles(math.rad(-20), 0, math.rad(-15)), neck)
	add("head", Vector3.new(0.2, 0.2, 0.1), Vector3.new(-0.4, 2.25, -2.66), BLACK, nil, nil, neck)
	add("head", Vector3.new(0.2, 0.2, 0.1), Vector3.new(0.4, 2.25, -2.66), BLACK, nil, nil, neck)
	for _, leg in { { "legFL", -0.6, -1.0 }, { "legFR", 0.6, -1.0 }, { "legBL", -0.6, 1.0 }, { "legBR", 0.6, 1.0 } } do
		add(leg[1], Vector3.new(0.5, 1.2, 0.5), Vector3.new(leg[2], 0.6, leg[3]), dark, nil, nil, Vector3.new(leg[2], 1.2, leg[3]))
		add(leg[1], Vector3.new(0.55, 0.22, 0.55), Vector3.new(leg[2], 0.11, leg[3]), Color3.fromRGB(40, 32, 28), nil, nil, Vector3.new(leg[2], 1.2, leg[3]))
	end
	add("tail", Vector3.new(0.18, 0.18, 0.7), Vector3.new(0, 2.3, 1.85), dark, nil, CFrame.Angles(math.rad(-35), 0, 0), Vector3.new(0, 2.3, 1.6))
	return 3.3
end

function builders.crab(add, def)
	local shell = def.color
	local dark = shell:Lerp(BLACK, 0.3)
	add("body", Vector3.new(3, 1.2, 2.2), Vector3.new(0, 1.4, 0), shell)
	add("body", Vector3.new(2.4, 0.4, 1.8), Vector3.new(0, 2.15, 0), shell:Lerp(Color3.new(1, 1, 1), 0.15))
	for _, side in { -1, 1 } do
		add("head", Vector3.new(0.15, 0.6, 0.15), Vector3.new(side * 0.5, 2.3, -0.8), dark, nil, nil, Vector3.new(0, 2, -0.8))
		add("head", Vector3.new(0.35, 0.35, 0.35), Vector3.new(side * 0.5, 2.7, -0.8), BLACK, nil, nil, Vector3.new(0, 2, -0.8), Enum.PartType.Ball)
		local arm = if side < 0 then "armL" else "armR"
		local joint = Vector3.new(side * 1.3, 1.4, -0.5)
		add(arm, Vector3.new(0.45, 0.45, 1.3), Vector3.new(side * 1.6, 1.4, -1.0), dark, nil, CFrame.Angles(0, math.rad(-side * 25), 0), joint)
		add(arm, Vector3.new(0.9, 0.7, 1.0), Vector3.new(side * 1.95, 1.55, -1.9), shell, nil, nil, joint)
		for i, z in { -0.5, 0.2, 0.9 } do
			local role = if (i + (if side > 0 then 1 else 0)) % 2 == 0 then "legA" else "legB"
			add(role, Vector3.new(1.5, 0.25, 0.25), Vector3.new(side * 2.0, 0.8, z), dark, nil, CFrame.Angles(0, 0, math.rad(side * -35)), Vector3.new(side * 1.4, 1.2, z))
		end
	end
	return 3.0
end

local function biped(add, skin, cloth, dark, eye)
	add("legL", Vector3.new(0.6, 1.2, 0.6), Vector3.new(-0.45, 0.6, 0), dark, nil, nil, Vector3.new(-0.45, 1.2, 0))
	add("legR", Vector3.new(0.6, 1.2, 0.6), Vector3.new(0.45, 0.6, 0), dark, nil, nil, Vector3.new(0.45, 1.2, 0))
	add("body", Vector3.new(1.8, 1.6, 1.1), Vector3.new(0, 2.0, 0), cloth)
	add("body", Vector3.new(1.85, 0.25, 1.15), Vector3.new(0, 1.3, 0), dark)
	add("armL", Vector3.new(0.5, 1.4, 0.5), Vector3.new(-1.15, 2.0, 0), skin, nil, nil, Vector3.new(-1.15, 2.6, 0))
	add("armR", Vector3.new(0.5, 1.4, 0.5), Vector3.new(1.15, 2.0, 0), skin, nil, nil, Vector3.new(1.15, 2.6, 0))
	local neck = Vector3.new(0, 2.8, 0)
	add("head", Vector3.new(1.6, 1.4, 1.4), Vector3.new(0, 3.5, 0), skin, nil, nil, neck)
	add("head", Vector3.new(0.9, 0.3, 0.2), Vector3.new(-1.1, 3.75, 0), skin, nil, CFrame.Angles(0, 0, math.rad(20)), neck)
	add("head", Vector3.new(0.9, 0.3, 0.2), Vector3.new(1.1, 3.75, 0), skin, nil, CFrame.Angles(0, 0, math.rad(-20)), neck)
	add("head", Vector3.new(0.32, 0.25, 0.1), Vector3.new(-0.4, 3.65, -0.72), eye, Enum.Material.Neon, nil, neck)
	add("head", Vector3.new(0.32, 0.25, 0.1), Vector3.new(0.4, 3.65, -0.72), eye, Enum.Material.Neon, nil, neck)
	add("head", Vector3.new(0.3, 0.45, 0.35), Vector3.new(0, 3.35, -0.85), skin:Lerp(BLACK, 0.15), nil, nil, neck)
	add("head", Vector3.new(0.9, 0.12, 0.1), Vector3.new(0, 3.05, -0.72), BLACK, nil, nil, neck)
	for _, x in { -0.25, 0.25 } do
		add("head", Vector3.new(0.12, 0.2, 0.1), Vector3.new(x, 2.98, -0.74), Color3.fromRGB(245, 240, 220), nil, nil, neck)
	end
	add("armL", Vector3.new(0.55, 0.45, 0.55), Vector3.new(-1.15, 1.15, 0), skin:Lerp(BLACK, 0.1), nil, nil, Vector3.new(-1.15, 2.6, 0))
	add("armR", Vector3.new(0.55, 0.45, 0.55), Vector3.new(1.15, 1.15, 0), skin:Lerp(BLACK, 0.1), nil, nil, Vector3.new(1.15, 2.6, 0))
	add("legL", Vector3.new(0.7, 0.3, 0.9), Vector3.new(-0.45, 0.15, -0.15), dark:Lerp(BLACK, 0.3), nil, nil, Vector3.new(-0.45, 1.2, 0))
	add("legR", Vector3.new(0.7, 0.3, 0.9), Vector3.new(0.45, 0.15, -0.15), dark:Lerp(BLACK, 0.3), nil, nil, Vector3.new(0.45, 1.2, 0))
	add("body", Vector3.new(0.45, 0.45, 0.3), Vector3.new(0.6, 1.25, -0.62), Color3.fromRGB(120, 85, 50), Enum.Material.Fabric)
	add("body", Vector3.new(0.9, 0.8, 0.12), Vector3.new(0, 0.85, -0.58), cloth:Lerp(BLACK, 0.2), Enum.Material.Fabric)
end

function builders.goblin(add, def)
	biped(add, def.color, Color3.fromRGB(110, 75, 45), Color3.fromRGB(60, 45, 30), Color3.fromRGB(255, 40, 40))
	add("armR", Vector3.new(0.45, 2.2, 0.45), Vector3.new(1.15, 1.6, -0.9), WOOD, Enum.Material.Wood, CFrame.Angles(math.rad(-60), 0, 0), Vector3.new(1.15, 2.6, 0))
	add("armR", Vector3.new(0.75, 0.75, 0.75), Vector3.new(1.15, 2.15, -1.85), WOOD:Lerp(BLACK, 0.2), Enum.Material.Wood, nil, Vector3.new(1.15, 2.6, 0))
	return 4.3
end

function builders.goblinArcher(add, def)
	biped(add, def.color, Color3.fromRGB(70, 90, 50), Color3.fromRGB(50, 45, 30), Color3.fromRGB(255, 200, 40))
	local neck = Vector3.new(0, 2.8, 0)
	add("head", Vector3.new(1.75, 0.5, 1.55), Vector3.new(0, 4.35, 0.05), Color3.fromRGB(60, 80, 45), nil, nil, neck)
	add("armL", Vector3.new(0.2, 2.6, 0.2), Vector3.new(-1.15, 1.9, -0.6), WOOD, Enum.Material.Wood, nil, Vector3.new(-1.15, 2.6, 0))
	add("armL", Vector3.new(0.05, 2.4, 0.05), Vector3.new(-1.15, 1.9, -0.35), Color3.fromRGB(230, 230, 230), nil, nil, Vector3.new(-1.15, 2.6, 0))
	add("body", Vector3.new(0.5, 1.5, 0.5), Vector3.new(0.45, 2.3, 0.75), WOOD, Enum.Material.Wood, CFrame.Angles(0, 0, math.rad(20)))
	return 4.6
end

function builders.goblinKing(add, def)
	biped(add, def.color, Color3.fromRGB(120, 30, 30), Color3.fromRGB(60, 40, 25), Color3.fromRGB(255, 60, 20))
	local gold = Color3.fromRGB(255, 200, 40)
	local neck = Vector3.new(0, 2.8, 0)
	add("head", Vector3.new(1.7, 0.45, 1.5), Vector3.new(0, 4.4, 0), gold, Enum.Material.Neon, nil, neck)
	for _, x in { -0.6, 0, 0.6 } do
		add("head", Vector3.new(0.3, 0.5, 0.3), Vector3.new(x, 4.85, -0.6), gold, Enum.Material.Neon, nil, neck)
	end
	add("body", Vector3.new(2.2, 2.6, 0.2), Vector3.new(0, 1.9, 0.7), Color3.fromRGB(150, 20, 30), Enum.Material.Fabric)
	add("armR", Vector3.new(0.5, 2.6, 0.5), Vector3.new(1.15, 1.5, -1.0), WOOD, Enum.Material.Wood, CFrame.Angles(math.rad(-60), 0, 0), Vector3.new(1.15, 2.6, 0))
	add("armR", Vector3.new(1.0, 1.0, 1.0), Vector3.new(1.15, 2.2, -2.15), Color3.fromRGB(90, 90, 100), Enum.Material.Metal, nil, Vector3.new(1.15, 2.6, 0))
	return 5.1
end

local function skeletonBody(add, bone, eye)
	add("legL", Vector3.new(0.4, 1.6, 0.4), Vector3.new(-0.4, 0.8, 0), bone, nil, nil, Vector3.new(-0.4, 1.6, 0))
	add("legR", Vector3.new(0.4, 1.6, 0.4), Vector3.new(0.4, 0.8, 0), bone, nil, nil, Vector3.new(0.4, 1.6, 0))
	add("body", Vector3.new(1.2, 0.4, 0.6), Vector3.new(0, 1.8, 0), bone)
	add("body", Vector3.new(0.3, 1.2, 0.3), Vector3.new(0, 2.5, 0), bone)
	for i = 0, 2 do
		add("body", Vector3.new(1.5 - i * 0.15, 0.18, 0.85), Vector3.new(0, 2.7 + i * 0.3, 0), bone)
	end
	add("armL", Vector3.new(0.35, 1.6, 0.35), Vector3.new(-1.0, 2.75, 0), bone, nil, nil, Vector3.new(-1.0, 3.5, 0))
	add("armR", Vector3.new(0.35, 1.6, 0.35), Vector3.new(1.0, 2.75, 0), bone, nil, nil, Vector3.new(1.0, 3.5, 0))
	local neck = Vector3.new(0, 3.5, 0)
	add("head", Vector3.new(1.3, 1.3, 1.3), Vector3.new(0, 4.1, 0), bone, nil, nil, neck)
	add("head", Vector3.new(0.9, 0.35, 0.3), Vector3.new(0, 3.5, -0.5), bone:Lerp(BLACK, 0.1), nil, nil, neck)
	add("head", Vector3.new(0.35, 0.35, 0.1), Vector3.new(-0.3, 4.2, -0.66), eye, Enum.Material.Neon, nil, neck)
	add("head", Vector3.new(0.35, 0.35, 0.1), Vector3.new(0.3, 4.2, -0.66), eye, Enum.Material.Neon, nil, neck)
	for i = -2, 2 do
		add("head", Vector3.new(0.1, 0.16, 0.06), Vector3.new(i * 0.16, 3.62, -0.67), Color3.fromRGB(250, 245, 230), nil, nil, neck)
	end
	add("body", Vector3.new(0.9, 0.35, 0.5), Vector3.new(0, 1.65, 0), bone:Lerp(BLACK, 0.12))
end

function builders.skeleton(add, def)
	skeletonBody(add, def.color, Color3.fromRGB(80, 220, 255))
	local neck = Vector3.new(0, 3.5, 0)
	add("head", Vector3.new(1.45, 0.6, 1.45), Vector3.new(0, 4.65, 0), Color3.fromRGB(110, 105, 100), Enum.Material.Metal, CFrame.Angles(0, 0, math.rad(6)), neck)
	add("head", Vector3.new(0.2, 0.5, 1.5), Vector3.new(0, 5.05, 0), Color3.fromRGB(150, 40, 40), Enum.Material.Fabric, nil, neck)
	add("armR", Vector3.new(0.25, 2.6, 0.12), Vector3.new(1.0, 2.6, -1.2), Color3.fromRGB(150, 150, 160), Enum.Material.Metal, CFrame.Angles(math.rad(-70), 0, 0), Vector3.new(1.0, 3.5, 0))
	add("armL", Vector3.new(0.2, 1.6, 1.3), Vector3.new(-1.25, 2.6, -0.3), Color3.fromRGB(110, 80, 50), Enum.Material.Wood, nil, Vector3.new(-1.0, 3.5, 0))
	return 4.8
end

function builders.skeletonMage(add, def)
	skeletonBody(add, def.color, Color3.fromRGB(200, 80, 255))
	local robe = Color3.fromRGB(60, 30, 90)
	add("body", Vector3.new(1.6, 2.2, 1.0), Vector3.new(0, 1.9, 0), robe, Enum.Material.Fabric)
	add("head", Vector3.new(1.5, 0.9, 1.5), Vector3.new(0, 4.75, 0.05), robe, Enum.Material.Fabric, nil, Vector3.new(0, 3.5, 0))
	add("armR", Vector3.new(0.25, 4.2, 0.25), Vector3.new(1.0, 2.6, -0.5), WOOD, Enum.Material.Wood, nil, Vector3.new(1.0, 3.5, 0))
	add("armR", Vector3.new(0.75, 0.75, 0.75), Vector3.new(1.0, 4.85, -0.5), Color3.fromRGB(200, 90, 255), Enum.Material.Neon, nil, Vector3.new(1.0, 3.5, 0), Enum.PartType.Ball)
	return 5.2
end

function builders.spider(add, def)
	local c = def.color
	add("body", Vector3.new(1.8, 1.0, 1.8), Vector3.new(0, 1.5, -0.6), c)
	add("body", Vector3.new(2.4, 1.9, 2.7), Vector3.new(0, 2.0, 1.6), c:Lerp(Color3.fromRGB(120, 20, 30), 0.25), nil, nil, nil, Enum.PartType.Ball)
	for _, eye in { { -0.3, 1.75, -1.5 }, { 0.3, 1.75, -1.5 }, { -0.6, 1.6, -1.42 }, { 0.6, 1.6, -1.42 } } do
		add("head", Vector3.new(0.22, 0.22, 0.1), Vector3.new(eye[1], eye[2], eye[3]), Color3.fromRGB(255, 30, 30), Enum.Material.Neon, nil, Vector3.new(0, 1.5, -1))
	end
	add("head", Vector3.new(0.2, 0.5, 0.2), Vector3.new(-0.25, 1.1, -1.55), BLACK, nil, nil, Vector3.new(0, 1.5, -1))
	add("head", Vector3.new(0.2, 0.5, 0.2), Vector3.new(0.25, 1.1, -1.55), BLACK, nil, nil, Vector3.new(0, 1.5, -1))
	for i = 0, 2 do
		add("body", Vector3.new(1.9 - i * 0.35, 0.18, 0.35), Vector3.new(0, 2.95 - i * 0.05, 1.0 + i * 0.6), Color3.fromRGB(230, 60, 40), Enum.Material.Neon)
	end
	for _, side in { -1, 1 } do
		for i, z in { -1.3, -0.6, 0.1, 0.8 } do
			local role = if (i + (if side > 0 then 1 else 0)) % 2 == 0 then "legA" else "legB"
			add(role, Vector3.new(2.8, 0.25, 0.25), Vector3.new(side * 1.9, 1.15, z), c:Lerp(BLACK, 0.3), nil, CFrame.Angles(0, math.rad(side * (z * 18)), math.rad(side * -32)), Vector3.new(side * 0.8, 1.5, z))
		end
	end
	return 3.0
end

function builders.golem(add, def)
	local stone = def.color
	local dark = stone:Lerp(BLACK, 0.25)
	local glow = Color3.fromRGB(255, 140, 40)
	add("legL", Vector3.new(1.3, 2.2, 1.3), Vector3.new(-0.9, 1.1, 0), dark, Enum.Material.Rock, nil, Vector3.new(-0.9, 2.2, 0))
	add("legR", Vector3.new(1.3, 2.2, 1.3), Vector3.new(0.9, 1.1, 0), dark, Enum.Material.Rock, nil, Vector3.new(0.9, 2.2, 0))
	add("body", Vector3.new(3.6, 2.8, 2.2), Vector3.new(0, 3.6, 0), stone, Enum.Material.Rock)
	add("body", Vector3.new(1.0, 1.0, 0.3), Vector3.new(0, 3.8, -1.12), glow, Enum.Material.Neon)
	add("body", Vector3.new(1.1, 0.9, 1.1), Vector3.new(-1.6, 5.2, 0), dark, Enum.Material.Rock, CFrame.Angles(0.3, 0.4, 0.2))
	add("body", Vector3.new(1.0, 0.8, 1.0), Vector3.new(1.6, 5.2, 0.1), dark, Enum.Material.Rock, CFrame.Angles(-0.2, 0.7, -0.3))
	add("body", Vector3.new(3.0, 0.25, 1.8), Vector3.new(0, 5.05, 0.1), Color3.fromRGB(80, 120, 60), Enum.Material.Grass)
	add("body", Vector3.new(0.15, 1.6, 0.1), Vector3.new(-0.9, 3.4, -1.12), glow, Enum.Material.Neon, CFrame.Angles(0, 0, math.rad(25)))
	add("body", Vector3.new(0.15, 1.2, 0.1), Vector3.new(1.0, 3.2, -1.12), glow, Enum.Material.Neon, CFrame.Angles(0, 0, math.rad(-35)))
	add("body", Vector3.new(0.5, 1.1, 0.5), Vector3.new(0.8, 5.6, 0.7), Color3.fromRGB(120, 200, 255), Enum.Material.Neon, CFrame.Angles(math.rad(20), 0, math.rad(-15)))
	local neck = Vector3.new(0, 5.0, 0)
	add("head", Vector3.new(1.4, 1.1, 1.3), Vector3.new(0, 5.5, -0.2), stone, Enum.Material.Rock, nil, neck)
	add("head", Vector3.new(0.3, 0.2, 0.1), Vector3.new(-0.35, 5.6, -0.87), glow, Enum.Material.Neon, nil, neck)
	add("head", Vector3.new(0.3, 0.2, 0.1), Vector3.new(0.35, 5.6, -0.87), glow, Enum.Material.Neon, nil, neck)
	for _, side in { -1, 1 } do
		local arm = if side < 0 then "armL" else "armR"
		local joint = Vector3.new(side * 2.4, 4.8, 0)
		add(arm, Vector3.new(1.2, 3.0, 1.2), Vector3.new(side * 2.5, 3.4, 0), stone, Enum.Material.Rock, nil, joint)
		add(arm, Vector3.new(1.6, 1.4, 1.6), Vector3.new(side * 2.55, 1.6, 0), dark, Enum.Material.Rock, nil, joint)
	end
	return 6.1
end

-- Devorador de Estrelas (chefe da raide): criatura cósmica flutuante de cristal. Tentáculos que ondulam
-- (tentacle), núcleo de estrela no peito, asas de nebulosa, garras de luz, crânio de três olhos, coroa de
-- fragmentos girando (orbit) e cinturão de meteoros girando ao contrário (orbitR).
function builders.devorador(add, def)
	local body = def.color
	local dark = body:Lerp(BLACK, 0.45)
	local star = Color3.fromRGB(255, 236, 170)
	local magenta = Color3.fromRGB(255, 110, 225)
	local cyan = Color3.fromRGB(120, 225, 255)
	local glass = Enum.Material.Glass
	local neon = Enum.Material.Neon
	-- tentáculos embaixo (ele flutua: as pontas quase tocam o chão)
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2 + 0.3
		local cx, cz = math.cos(a), math.sin(a)
		local joint = Vector3.new(cx * 1.1, 3.4, cz * 1.1)
		add("tentacle", Vector3.new(0.6, 1.7, 0.6), Vector3.new(cx * 1.35, 2.6, cz * 1.35), dark, glass, CFrame.Angles(cz * 0.25, 0, -cx * 0.25), joint)
		add("tentacle", Vector3.new(0.45, 1.4, 0.45), Vector3.new(cx * 1.75, 1.3, cz * 1.75), body, glass, CFrame.Angles(cz * 0.4, 0, -cx * 0.4), joint)
		add("tentacle", Vector3.new(0.3, 0.6, 0.3), Vector3.new(cx * 2.0, 0.4, cz * 2.0), magenta, neon, nil, joint)
	end
	-- tronco de cristal
	add("body", Vector3.new(2.4, 1.6, 2.0), Vector3.new(0, 3.9, 0), dark, glass, nil, nil, nil, 0.05)
	add("body", Vector3.new(3.2, 2.6, 2.4), Vector3.new(0, 5.5, 0), body, glass, nil, nil, nil, 0.05)
	for _, side in { -1, 1 } do
		add("body", Vector3.new(1.2, 2.2, 0.5), Vector3.new(side * 1.3, 5.6, -1.05), dark, glass, CFrame.Angles(0, side * 0.35, side * 0.2))
		add("body", Vector3.new(1.4, 1.2, 1.4), Vector3.new(side * 2.1, 6.5, 0), dark, glass, CFrame.Angles(0.3, side * 0.6, side * 0.4))
	end
	-- núcleo de estrela e faíscas em volta
	add("body", Vector3.one * 1.5, Vector3.new(0, 5.4, -1.2), star, neon, nil, nil, Enum.PartType.Ball)
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2
		add("body", Vector3.one * 0.25, Vector3.new(math.cos(a) * 1.1, 5.4 + math.sin(a) * 1.1, -1.3), cyan, neon)
	end
	-- asas de nebulosa (duas camadas translúcidas)
	for _, side in { -1, 1 } do
		add("body", Vector3.new(0.15, 4.4, 3.2), Vector3.new(side * 2.5, 7.0, 1.4), magenta, neon, CFrame.Angles(0, side * 0.6, side * 0.45), nil, nil, 0.55)
		add("body", Vector3.new(0.12, 3.2, 2.2), Vector3.new(side * 2.3, 6.6, 1.2), cyan, neon, CFrame.Angles(0, side * 0.5, side * 0.3), nil, nil, 0.7)
	end
	-- braços com garras de luz
	for _, side in { -1, 1 } do
		local arm = if side < 0 then "armL" else "armR"
		local joint = Vector3.new(side * 2.1, 6.4, 0)
		add(arm, Vector3.new(0.9, 2.6, 0.9), Vector3.new(side * 2.6, 5.0, 0), body, glass, nil, joint)
		add(arm, Vector3.new(0.8, 2.2, 0.8), Vector3.new(side * 2.8, 3.1, -0.3), dark, glass, CFrame.Angles(0.25, 0, 0), joint)
		for c = -1, 1 do
			add(arm, Vector3.new(0.22, 1.2, 0.22), Vector3.new(side * 2.8 + c * 0.32, 1.6, -0.75), magenta, neon, CFrame.Angles(-0.4, 0, c * 0.25), joint)
		end
	end
	-- crânio de três olhos, mandíbula e chifres
	local neck = Vector3.new(0, 6.8, 0)
	add("head", Vector3.new(1.8, 1.5, 1.6), Vector3.new(0, 7.6, -0.2), dark, glass, nil, neck)
	add("head", Vector3.new(1.95, 0.35, 0.7), Vector3.new(0, 8.1, -0.75), body, glass, nil, neck)
	add("head", Vector3.new(1.3, 0.4, 1.0), Vector3.new(0, 6.85, -0.6), dark, glass, nil, neck)
	for _, side in { -1, 1 } do
		add("head", Vector3.new(0.38, 0.2, 0.1), Vector3.new(side * 0.45, 7.65, -1.02), magenta, neon, nil, neck)
		add("head", Vector3.new(0.35, 1.5, 0.35), Vector3.new(side * 0.75, 8.6, 0.1), dark, glass, CFrame.Angles(0, 0, side * -0.45), neck)
		add("head", Vector3.new(0.25, 0.45, 0.25), Vector3.new(side * 1.12, 9.35, 0.1), cyan, neon, CFrame.Angles(0, 0, side * -0.45), neck)
	end
	add("head", Vector3.new(0.3, 0.3, 0.1), Vector3.new(0, 8.0, -1.0), star, neon, CFrame.Angles(0, 0, math.rad(45)), neck)
	-- coroa de fragmentos girando
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2
		add("orbit", Vector3.new(0.3, 1.0, 0.3), Vector3.new(math.cos(a) * 1.7, 9.8, math.sin(a) * 1.7), if k % 2 == 0 then star else cyan, neon, CFrame.Angles(math.sin(a) * 0.3, 0, math.cos(a) * 0.3), Vector3.new(0, 9.8, 0))
	end
	-- cinturão de meteoros girando ao contrário
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2
		local size = 0.6 + (k % 3) * 0.15
		add("orbitR", Vector3.one * size, Vector3.new(math.cos(a) * 3.3, 4.3 + (k % 2) * 0.6, math.sin(a) * 3.3), Color3.fromRGB(70, 55, 80), Enum.Material.Basalt, CFrame.Angles(a, a * 2, 0), Vector3.new(0, 4.3, 0))
		add("orbitR", Vector3.one * (size * 0.4), Vector3.new(math.cos(a) * 3.3, 4.3 + (k % 2) * 0.6 + size * 0.45, math.sin(a) * 3.3), magenta, neon, nil, Vector3.new(0, 4.3, 0))
	end
	return 10.2
end

function builders.dummy(add, def)
	local straw = def.color
	add("body", Vector3.new(2, 0.3, 2), Vector3.new(0, 0.15, 0), WOOD, Enum.Material.Wood)
	add("body", Vector3.new(0.4, 4, 0.4), Vector3.new(0, 2, 0), WOOD, Enum.Material.Wood)
	add("body", Vector3.new(1.6, 1.8, 1.0), Vector3.new(0, 3.3, 0), straw, Enum.Material.Fabric)
	add("body", Vector3.new(3.2, 0.35, 0.35), Vector3.new(0, 3.7, 0), WOOD, Enum.Material.Wood)
	add("body", Vector3.new(1.1, 1.1, 1.1), Vector3.new(0, 4.75, 0), straw, Enum.Material.Fabric)
	add("body", Vector3.new(0.9, 0.9, 0.1), Vector3.new(0, 3.4, -0.52), Color3.fromRGB(200, 40, 40))
	add("body", Vector3.new(0.5, 0.5, 0.11), Vector3.new(0, 3.4, -0.53), Color3.new(1, 1, 1))
	return 5.4
end

-- Retorna { model, parts = { {part, base, role, joint} }, height }
function EnemyModels.build(def, elite)
	local model = Instance.new("Model")
	model.Name = def.name
	local scale = (def.scale or 1) * (if elite then 1.35 else 1)
	local parts = {}

	local function add(role, size, position, color, material, rotation, joint, shape, transparency)
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.CastShadow = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		if shape then
			p.Shape = shape
		end
		p.Size = size * scale
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		p.Transparency = transparency or 0
		local base = CFrame.new(position * scale)
		if rotation then
			base *= rotation
		end
		p.CFrame = base
		p.Parent = model
		table.insert(parts, { part = p, base = base, role = role, joint = if joint then joint * scale else nil, color = color })
		return p
	end

	local builder = builders[def.model] or builders.slime
	local height = builder(add, def) * scale
	return { model = model, parts = parts, height = height, scale = scale }
end

-- Altura do modelo sem construir (usada pelo servidor para hitbox)
local heightCache = {}
function EnemyModels.height(def, elite)
	local key = (def.model or "slime") .. (if elite then "_e" else "") .. tostring(def.scale or 1)
	if not heightCache[key] then
		local built = EnemyModels.build(def, elite)
		heightCache[key] = built.height
		built.model:Destroy()
	end
	return heightCache[key]
end

return EnemyModels
