-- Desenha e anima os pets de todos os jogadores (atributos "Pet" e "PetLevel" do dono).
-- Cada modelo é feito de peças com um "papel" (perna, asa, cauda...) animado por código:
-- patinhas andando, asas batendo, slime quicando, flutuar e seguir o dono suavemente.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Pets = require(Shared.Pets)

local UI = require(script.Parent.UI)

local PetRenderer = {}

local folder = Instance.new("Folder")
folder.Name = "Pets"
folder.Parent = workspace

local active = {} -- [player] = rec
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local EYE = Color3.fromRGB(25, 25, 30)

-- ===================== MODELOS =====================

local function newPart(model, size, color, material, shape)
	local p = Instance.new("Part")
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Parent = model
	return p
end

-- cada peça: { part, offset = CFrame em relação à raiz, role = "body"/"legFL"/... , pivot = ponto de giro }
local function piece(list, part, offset, role, pivot)
	table.insert(list, { part = part, offset = offset, role = role or "static", pivot = pivot or Vector3.zero })
end

local function eyes(model, list, headOffset, spread, size, role)
	-- olhos grandes e brilhantes (dois pontos de luz), com pálpebra suave por cima
	for _, x in { -spread, spread } do
		local eye = newPart(model, Vector3.one * size, EYE, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		piece(list, eye, headOffset * CFrame.new(x, 0, 0), role or "head")
		local shine = newPart(model, Vector3.one * size * 0.38, Color3.new(1, 1, 1), Enum.Material.Neon, Enum.PartType.Ball)
		piece(list, shine, headOffset * CFrame.new(x + size * 0.18, size * 0.2, -size * 0.32), role or "head")
		local small = newPart(model, Vector3.one * size * 0.18, Color3.new(1, 1, 1), Enum.Material.Neon, Enum.PartType.Ball)
		piece(list, small, headOffset * CFrame.new(x - size * 0.16, -size * 0.18, -size * 0.36), role or "head")
	end
end

-- cápsula (cilindro com duas meias esferas) deitada no eixo Z
local function capsule(model, list, length, diameter, offset, color, material, role, pivot)
	local cylinder = newPart(model, Vector3.new(length, diameter, diameter), color, material, Enum.PartType.Cylinder)
	piece(list, cylinder, offset * CFrame.Angles(0, math.rad(90), 0), role, pivot)
	for _, z in { -length / 2, length / 2 } do
		local cap = newPart(model, Vector3.one * diameter, color, material, Enum.PartType.Ball)
		piece(list, cap, offset * CFrame.new(0, 0, z), role, pivot)
	end
end

-- cápsula em pé (eixo Y)
local function capsuleY(model, list, length, diameter, offset, color, material, role, pivot)
	local cylinder = newPart(model, Vector3.new(length, diameter, diameter), color, material, Enum.PartType.Cylinder)
	piece(list, cylinder, offset * CFrame.Angles(0, 0, math.rad(90)), role, pivot)
	for _, y in { -length / 2, length / 2 } do
		local cap = newPart(model, Vector3.one * diameter, color, material, Enum.PartType.Ball)
		piece(list, cap, offset * CFrame.new(0, y, 0), role, pivot)
	end
end

local function darker(color, amount)
	return color:Lerp(Color3.new(0, 0, 0), amount or 0.2)
end

local function lighter(color, amount)
	return color:Lerp(Color3.new(1, 1, 1), amount or 0.2)
end

local BUILDERS = {}

function BUILDERS.slime(model, def, list)
	local body = newPart(model, Vector3.one * 2.1, def.color, Enum.Material.Glass, Enum.PartType.Ball)
	body.Transparency = 0.2
	piece(list, body, CFrame.new(0, 1.0, 0), "squish")
	local base = newPart(model, Vector3.new(0.5, 2.3, 2.3), def.color, Enum.Material.Glass, Enum.PartType.Cylinder)
	base.Transparency = 0.2
	piece(list, base, CFrame.new(0, 0.3, 0) * CFrame.Angles(0, 0, math.rad(90)), "squish")
	local core = newPart(model, Vector3.one * 0.75, def.accent, Enum.Material.Neon, Enum.PartType.Ball)
	piece(list, core, CFrame.new(0, 0.9, 0.15), "squish")
	-- brilho no topo, bolhinhas dentro e boquinha
	local gloss = newPart(model, Vector3.one * 0.45, Color3.new(1, 1, 1), Enum.Material.Neon, Enum.PartType.Ball)
	gloss.Transparency = 0.3
	piece(list, gloss, CFrame.new(-0.45, 1.65, -0.5), "squish")
	for i = 0, 2 do
		local bubble = newPart(model, Vector3.one * (0.18 + i * 0.05), lighter(def.color, 0.5), Enum.Material.Neon, Enum.PartType.Ball)
		bubble.Transparency = 0.4
		piece(list, bubble, CFrame.new(0.4 - i * 0.3, 0.6 + i * 0.3, 0.3), "squish")
	end
	eyes(model, list, CFrame.new(0, 1.2, -0.98), 0.38, 0.34, "squish")
	local mouth = newPart(model, Vector3.new(0.35, 0.08, 0.05), EYE)
	piece(list, mouth, CFrame.new(0, 0.85, -1.04), "squish")
	for _, x in { -0.62, 0.62 } do
		local blush = newPart(model, Vector3.new(0.28, 0.12, 0.05), Color3.fromRGB(255, 150, 160), Enum.Material.Neon)
		blush.Transparency = 0.4
		piece(list, blush, CFrame.new(x, 0.95, -0.97), "squish")
	end
	return 0
end

function BUILDERS.quadruped(model, def, list)
	local fur, accent = def.color, def.accent
	-- corpo arredondado (cápsula) com peito e barriga mais claros
	capsule(model, list, 1.2, 1.15, CFrame.new(0, 1.15, 0.1), fur, Enum.Material.SmoothPlastic, "body")
	local chest = newPart(model, Vector3.one * 0.9, accent, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	piece(list, chest, CFrame.new(0, 1.0, -0.55), "body")
	local belly = newPart(model, Vector3.new(0.75, 0.35, 1.2), accent)
	piece(list, belly, CFrame.new(0, 0.68, 0.15), "body")
	if def.stripes then
		for i = 0, 3 do
			local stripe = newPart(model, Vector3.new(1.2, 0.14, 0.12), def.stripes)
			piece(list, stripe, CFrame.new(0, 1.42, -0.45 + i * 0.4) * CFrame.Angles(0, 0, math.rad(if i % 2 == 0 then 8 else -8)), "body")
		end
	end
	-- cabeça redonda grande (estilo chibi), focinho, nariz, boca e bochechas
	local head = newPart(model, Vector3.one * 1.35, fur, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	piece(list, head, CFrame.new(0, 2.0, -1.05), "head")
	local muzzle = newPart(model, Vector3.one * 0.62, accent, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	piece(list, muzzle, CFrame.new(0, 1.78, -1.62), "head")
	local nose = newPart(model, Vector3.new(0.24, 0.16, 0.14), EYE, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	piece(list, nose, CFrame.new(0, 1.92, -1.92), "head")
	local mouth = newPart(model, Vector3.new(0.2, 0.05, 0.05), EYE)
	piece(list, mouth, CFrame.new(0, 1.66, -1.91), "head")
	eyes(model, list, CFrame.new(0, 2.15, -1.62), 0.3, 0.26)
	if def.stripes then
		for _, x in { -0.32, 0, 0.32 } do
			local mark = newPart(model, Vector3.new(0.08, 0.32, 0.08), def.stripes)
			piece(list, mark, CFrame.new(x, 2.62, -1.4) * CFrame.Angles(math.rad(-30), 0, 0), "head")
		end
	end
	if def.whiskers ~= false and (def.ears == "pointy") then
		for _, side in { -1, 1 } do
			for k = 0, 1 do
				local whisker = newPart(model, Vector3.new(0.5, 0.03, 0.03), Color3.fromRGB(240, 240, 240))
				piece(list, whisker, CFrame.new(side * 0.42, 1.78 + k * 0.08, -1.8) * CFrame.Angles(0, 0, math.rad(side * (8 - k * 14))), "head")
			end
		end
	end
	-- orelhas: pontudas (com parte de dentro) ou caídas
	for _, side in { -1, 1 } do
		if def.ears == "floppy" then
			capsuleY(model, list, 0.35, 0.36, CFrame.new(side * 0.68, 1.95, -1.0) * CFrame.Angles(0, 0, math.rad(side * -20)), darker(fur, 0.25), Enum.Material.SmoothPlastic, "ears", Vector3.new(0, 0.3, 0))
		else
			local ear = newPart(model, Vector3.new(0.18, 0.62, 0.48), fur, nil, Enum.PartType.Wedge)
			piece(list, ear, CFrame.new(side * 0.4, 2.75, -0.95) * CFrame.Angles(0, math.rad(180), math.rad(side * -12)), "ears", Vector3.new(0, -0.3, 0))
			local inner = newPart(model, Vector3.new(0.08, 0.4, 0.28), Color3.fromRGB(255, 170, 180), nil, Enum.PartType.Wedge)
			piece(list, inner, CFrame.new(side * 0.4, 2.7, -1.05) * CFrame.Angles(0, math.rad(180), math.rad(side * -12)), "ears", Vector3.new(0, -0.3, 0.1))
		end
	end
	-- chifre e crina (unicórnio)
	if def.horn then
		for i = 0, 3 do
			local ring = newPart(model, Vector3.new(0.26 - i * 0.05, 0.22, 0.26 - i * 0.05), Color3.fromRGB(255, 220, 120), Enum.Material.Neon)
			piece(list, ring, CFrame.new(0, 2.72 + i * 0.2, -1.38 - i * 0.07) * CFrame.Angles(math.rad(-20), math.rad(i * 30), 0), "head")
		end
		for i = 0, 4 do
			local mane = newPart(model, Vector3.new(0.22, 0.5, 0.4), if i % 2 == 0 then accent else lighter(accent, 0.3), Enum.Material.Neon, Enum.PartType.Wedge)
			mane.Transparency = 0.1
			piece(list, mane, CFrame.new(0, 2.55 - i * 0.22, -0.7 + i * 0.25) * CFrame.Angles(math.rad(-20), 0, 0), "head")
		end
	end
	-- coleira com plaquinha (cachorro)
	if def.collar then
		local collar = newPart(model, Vector3.new(0.25, 1.05, 1.05), def.collar, Enum.Material.Fabric, Enum.PartType.Cylinder)
		piece(list, collar, CFrame.new(0, 1.45, -0.72) * CFrame.Angles(0, math.rad(90), math.rad(70)), "body")
		local tag = newPart(model, Vector3.one * 0.22, Color3.fromRGB(240, 200, 70), Enum.Material.Metal, Enum.PartType.Ball)
		piece(list, tag, CFrame.new(0, 1.15, -1.18), "body")
	end
	-- pernas com patinhas (ou cascos)
	local legs = { { "legFL", -0.38, -0.55 }, { "legFR", 0.38, -0.55 }, { "legBL", -0.38, 0.75 }, { "legBR", 0.38, 0.75 } }
	for _, leg in legs do
		local part = newPart(model, Vector3.new(0.75, 0.38, 0.38), darker(fur, 0.08), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		piece(list, part, CFrame.new(leg[2], 0.48, leg[3]) * CFrame.Angles(0, 0, math.rad(90)), leg[1], Vector3.new(0, 0.38, 0))
		if def.horn then
			local hoof = newPart(model, Vector3.new(0.2, 0.42, 0.42), Color3.fromRGB(240, 200, 90), Enum.Material.Metal, Enum.PartType.Cylinder)
			piece(list, hoof, CFrame.new(leg[2], 0.1, leg[3]) * CFrame.Angles(0, 0, math.rad(90)), leg[1], Vector3.new(0, 0.38, 0))
		else
			local paw = newPart(model, Vector3.one * 0.46, accent, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
			piece(list, paw, CFrame.new(leg[2], 0.16, leg[3] - 0.06), leg[1], Vector3.new(0, 0.38, 0))
		end
	end
	-- cauda em segmentos (felpuda na raposa/lobo/tigre)
	local big = def.tail == "big"
	for i = 0, 2 do
		local size = if big then 0.55 + i * 0.12 else 0.26
		local segment = newPart(model, Vector3.one * size, if i == 2 and big then accent else fur, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		piece(list, segment, CFrame.new(0, 1.45 + i * 0.28, 1.15 + i * 0.32), "tail", Vector3.new(0, -0.28 * i, -0.32 * i - 0.2))
	end
	return 0
end

function BUILDERS.bunny(model, def, list)
	local fur, accent = def.color, def.accent
	local body = newPart(model, Vector3.one * 1.5, fur, nil, Enum.PartType.Ball)
	piece(list, body, CFrame.new(0, 0.8, 0.1), "body")
	local belly = newPart(model, Vector3.one * 1.0, Color3.new(1, 1, 1), nil, Enum.PartType.Ball)
	piece(list, belly, CFrame.new(0, 0.7, -0.35), "body")
	local head = newPart(model, Vector3.one * 1.25, fur, nil, Enum.PartType.Ball)
	piece(list, head, CFrame.new(0, 1.65, -0.55), "head")
	for _, side in { -1, 1 } do
		local cheek = newPart(model, Vector3.one * 0.5, Color3.new(1, 1, 1), nil, Enum.PartType.Ball)
		piece(list, cheek, CFrame.new(side * 0.25, 1.45, -1.05), "head")
	end
	eyes(model, list, CFrame.new(0, 1.8, -1.08), 0.28, 0.24)
	local nose = newPart(model, Vector3.one * 0.18, accent, Enum.Material.Neon, Enum.PartType.Ball)
	piece(list, nose, CFrame.new(0, 1.58, -1.22), "head")
	local teeth = newPart(model, Vector3.new(0.18, 0.16, 0.05), Color3.new(1, 1, 1))
	piece(list, teeth, CFrame.new(0, 1.36, -1.22), "head")
	for _, side in { -1, 1 } do
		capsuleY(model, list, 0.75, 0.32, CFrame.new(side * 0.25, 2.65, -0.45) * CFrame.Angles(0, 0, math.rad(side * -10)), fur, nil, "ears", Vector3.new(0, -0.5, 0))
		local inner = newPart(model, Vector3.new(0.14, 0.75, 0.05), accent)
		piece(list, inner, CFrame.new(side * 0.25, 2.65, -0.62) * CFrame.Angles(0, 0, math.rad(side * -10)), "ears", Vector3.new(0, -0.5, 0.17))
		-- pezões
		capsule(model, list, 0.35, 0.36, CFrame.new(side * 0.42, 0.18, -0.15), fur, nil, if side < 0 then "legFL" else "legFR", Vector3.new(0, 0.2, 0))
	end
	local tail = newPart(model, Vector3.one * 0.55, Color3.new(1, 1, 1), nil, Enum.PartType.Ball)
	piece(list, tail, CFrame.new(0, 0.85, 0.9), "tail", Vector3.new(0, 0, -0.2))
	return 0
end

function BUILDERS.bird(model, def, list)
	local plumage, accent = def.color, def.accent
	local owl = def.tufts == true
	local body = newPart(model, Vector3.one * 1.4, plumage, nil, Enum.PartType.Ball)
	piece(list, body, CFrame.new(0, 0, 0), "body")
	local belly = newPart(model, Vector3.one * 1.0, accent, nil, Enum.PartType.Ball)
	piece(list, belly, CFrame.new(0, -0.12, -0.32), "body")
	-- penas do peito em fileiras
	for row = 0, 2 do
		for col = -1, 1 do
			local feather = newPart(model, Vector3.new(0.22, 0.12, 0.08), darker(accent, 0.15), nil, Enum.PartType.Wedge)
			piece(list, feather, CFrame.new(col * 0.22 + (row % 2) * 0.11, -0.05 - row * 0.2, -0.8) * CFrame.Angles(math.rad(180), 0, 0), "body")
		end
	end
	-- rosto (disco claro na coruja), olhos grandes e bico
	if owl then
		for _, x in { -0.25, 0.25 } do
			local disc = newPart(model, Vector3.new(0.08, 0.62, 0.62), lighter(plumage, 0.45), nil, Enum.PartType.Cylinder)
			piece(list, disc, CFrame.new(x, 0.32, -0.66) * CFrame.Angles(0, math.rad(90), 0), "head")
		end
		for _, side in { -1, 1 } do
			local tuft = newPart(model, Vector3.new(0.15, 0.45, 0.3), darker(plumage, 0.2), nil, Enum.PartType.Wedge)
			piece(list, tuft, CFrame.new(side * 0.4, 0.75, -0.3) * CFrame.Angles(0, 0, math.rad(side * -15)), "head")
		end
	end
	eyes(model, list, CFrame.new(0, 0.32, -0.72), 0.25, if owl then 0.32 else 0.24)
	local beak = newPart(model, Vector3.new(0.2, 0.26, 0.32), Color3.fromRGB(255, 190, 60), nil, Enum.PartType.Wedge)
	piece(list, beak, CFrame.new(0, 0.08, -0.8) * CFrame.Angles(math.rad(180), 0, 0), "head")
	-- crista de fogo (fênix)
	if def.glow then
		for i = 0, 2 do
			local crest = newPart(model, Vector3.new(0.1, 0.5 - i * 0.1, 0.25), if i == 0 then Color3.fromRGB(255, 230, 120) else accent, Enum.Material.Neon, Enum.PartType.Wedge)
			piece(list, crest, CFrame.new(0, 0.82 - i * 0.05, -0.2 + i * 0.2) * CFrame.Angles(math.rad(-20 - i * 15), 0, 0), "head")
		end
	end
	-- asas em camadas de penas
	for _, side in { -1, 1 } do
		local role = if side < 0 then "wingL" else "wingR"
		for k = 0, 2 do
			local feather = newPart(model, Vector3.new(0.95 - k * 0.18, 0.1, 0.5), if k == 2 then accent else darker(plumage, k * 0.08), if def.glow and k == 2 then Enum.Material.Neon else Enum.Material.SmoothPlastic)
			piece(list, feather, CFrame.new(side * (0.85 + k * 0.08), 0.15 - k * 0.12, 0.05 + k * 0.18), role, Vector3.new(-side * (0.45 + k * 0.08), 0, 0))
		end
	end
	-- leque de penas da cauda
	for k = -1, 1 do
		local tail = newPart(model, Vector3.new(0.24, 0.08, 0.75), if def.glow then accent else darker(plumage, 0.1), if def.glow then Enum.Material.Neon else Enum.Material.SmoothPlastic)
		piece(list, tail, CFrame.new(k * 0.18, -0.3, 0.8) * CFrame.Angles(math.rad(25), math.rad(k * 20), 0), "tail", Vector3.new(0, 0, -0.35))
	end
	for _, x in { -0.25, 0.25 } do
		local foot = newPart(model, Vector3.new(0.12, 0.25, 0.12), Color3.fromRGB(255, 190, 60))
		piece(list, foot, CFrame.new(x, -0.75, -0.05), "body")
	end
	if def.glow then
		local flames = Instance.new("ParticleEmitter")
		flames.Color = ColorSequence.new(Color3.fromRGB(255, 230, 120), accent)
		flames.LightEmission = 1
		flames.Size = NumberSequence.new(0.35, 0)
		flames.Lifetime = NumberRange.new(0.4, 0.8)
		flames.Rate = 18
		flames.Speed = NumberRange.new(0.5, 1.5)
		flames.Acceleration = Vector3.new(0, 2, 0)
		flames.Parent = body
	end
	return 2.6
end

function BUILDERS.turtle(model, def, list)
	local skin, shell = def.color, def.accent
	-- casco em domo com placas hexagonais e borda
	local dome = newPart(model, Vector3.one * 2.0, shell, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	piece(list, dome, CFrame.new(0, 0.55, 0), "body")
	local rim = newPart(model, Vector3.new(0.3, 2.3, 2.3), darker(shell, 0.2), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	piece(list, rim, CFrame.new(0, 0.55, 0) * CFrame.Angles(0, 0, math.rad(90)), "body")
	local belly = newPart(model, Vector3.new(0.25, 2.0, 2.0), lighter(skin, 0.35), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	piece(list, belly, CFrame.new(0, 0.35, 0) * CFrame.Angles(0, 0, math.rad(90)), "body")
	for i = 0, 6 do
		local angle = i / 6 * math.pi * 2
		local radius = if i == 6 then 0 else 0.55
		local plate = newPart(model, Vector3.new(0.55, 0.12, 0.55), lighter(shell, 0.12), Enum.Material.SmoothPlastic)
		piece(list, plate, CFrame.new(math.cos(angle) * radius, 1.5 - (if i == 6 then -0.03 else 0.12), math.sin(angle) * radius) * CFrame.Angles(0, angle, 0), "body")
	end
	local head = newPart(model, Vector3.one * 0.8, skin, nil, Enum.PartType.Ball)
	piece(list, head, CFrame.new(0, 0.7, -1.3), "head")
	eyes(model, list, CFrame.new(0, 0.85, -1.62), 0.2, 0.18)
	local smile = newPart(model, Vector3.new(0.3, 0.05, 0.05), EYE)
	piece(list, smile, CFrame.new(0, 0.58, -1.68), "head")
	for _, leg in { { "legFL", -0.75, -0.7 }, { "legFR", 0.75, -0.7 }, { "legBL", -0.75, 0.7 }, { "legBR", 0.75, 0.7 } } do
		local part = newPart(model, Vector3.one * 0.55, skin, nil, Enum.PartType.Ball)
		piece(list, part, CFrame.new(leg[2], 0.25, leg[3]), leg[1], Vector3.new(0, 0.2, 0))
	end
	local tail = newPart(model, Vector3.new(0.2, 0.2, 0.45), skin, nil, Enum.PartType.Wedge)
	piece(list, tail, CFrame.new(0, 0.35, 1.2), "tail", Vector3.new(0, 0, -0.2))
	return 0
end

function BUILDERS.golem(model, def, list)
	local rock, glow = def.color, def.accent
	local body = newPart(model, Vector3.new(1.6, 1.4, 1.15), rock, Enum.Material.Slate)
	piece(list, body, CFrame.new(0, 1.4, 0) * CFrame.Angles(0, 0, math.rad(3)), "body")
	local belly = newPart(model, Vector3.new(1.3, 0.6, 1.2), darker(rock, 0.1), Enum.Material.Slate)
	piece(list, belly, CFrame.new(0, 0.85, 0), "body")
	for _, offset in { CFrame.new(-0.55, 1.95, 0.2), CFrame.new(0.6, 1.9, -0.1), CFrame.new(0, 1.15, 0.5) } do
		local chunk = newPart(model, Vector3.new(0.6, 0.5, 0.55), lighter(rock, 0.08), Enum.Material.Slate)
		piece(list, chunk, offset * CFrame.Angles(0.3, 0.6, 0.2), "body")
	end
	-- rachaduras e coração brilhando
	local core = newPart(model, Vector3.new(0.5, 0.5, 0.12), glow, Enum.Material.Neon)
	piece(list, core, CFrame.new(0, 1.5, -0.6) * CFrame.Angles(0, 0, math.rad(45)), "body")
	for _, angle in { 25, -35, 70 } do
		local crack = newPart(model, Vector3.new(0.06, 0.55, 0.06), glow, Enum.Material.Neon)
		piece(list, crack, CFrame.new(0, 1.5, -0.6) * CFrame.Angles(0, 0, math.rad(angle)) * CFrame.new(0, 0.4, 0), "body")
	end
	local head = newPart(model, Vector3.new(1.0, 0.8, 0.9), rock, Enum.Material.Slate)
	piece(list, head, CFrame.new(0, 2.45, -0.05), "head")
	local brow = newPart(model, Vector3.new(1.05, 0.2, 0.3), darker(rock, 0.2), Enum.Material.Slate)
	piece(list, brow, CFrame.new(0, 2.65, -0.42), "head")
	for _, x in { -0.22, 0.22 } do
		local eye = newPart(model, Vector3.new(0.22, 0.14, 0.08), glow, Enum.Material.Neon)
		piece(list, eye, CFrame.new(x, 2.48, -0.52), "head")
	end
	-- cristal nas costas e musgo
	local crystal = newPart(model, Vector3.new(0.4, 0.9, 0.4), glow, Enum.Material.Neon)
	piece(list, crystal, CFrame.new(0.3, 2.3, 0.45) * CFrame.Angles(math.rad(25), 0, math.rad(-15)), "body")
	local moss = newPart(model, Vector3.new(0.7, 0.12, 0.6), Color3.fromRGB(80, 130, 60), Enum.Material.Grass)
	piece(list, moss, CFrame.new(-0.3, 2.86, 0.05), "head")
	for _, side in { -1, 1 } do
		local arm = newPart(model, Vector3.new(0.5, 1.0, 0.55), rock, Enum.Material.Slate)
		piece(list, arm, CFrame.new(side * 1.1, 1.45, 0), if side < 0 then "legFL" else "legFR", Vector3.new(0, 0.5, 0))
		local fist = newPart(model, Vector3.one * 0.62, darker(rock, 0.1), Enum.Material.Slate, Enum.PartType.Ball)
		piece(list, fist, CFrame.new(side * 1.12, 0.8, -0.05), if side < 0 then "legFL" else "legFR", Vector3.new(0, 1.15, 0))
		local leg = newPart(model, Vector3.new(0.55, 0.7, 0.6), rock, Enum.Material.Slate)
		piece(list, leg, CFrame.new(side * 0.45, 0.35, 0), if side < 0 then "legBL" else "legBR", Vector3.new(0, 0.3, 0))
	end
	return 0
end

function BUILDERS.wisp(model, def, list)
	-- fadinha: corpinho, cabeça com cabelo, quatro asas de luz, aura e brilhos
	local glow, accent = def.color, def.accent
	capsuleY(model, list, 0.35, 0.42, CFrame.new(0, -0.1, 0), accent, Enum.Material.SmoothPlastic, "squish")
	local skirt = newPart(model, Vector3.new(0.55, 0.6, 0.6), lighter(accent, 0.2), Enum.Material.Neon, Enum.PartType.Wedge)
	skirt.Transparency = 0.2
	piece(list, skirt, CFrame.new(0, -0.4, 0), "squish")
	local head = newPart(model, Vector3.one * 0.62, Color3.fromRGB(255, 225, 200), nil, Enum.PartType.Ball)
	piece(list, head, CFrame.new(0, 0.45, 0), "squish")
	local hair = newPart(model, Vector3.one * 0.68, glow, Enum.Material.Neon, Enum.PartType.Ball)
	hair.Transparency = 0.15
	piece(list, hair, CFrame.new(0, 0.55, 0.08), "squish")
	eyes(model, list, CFrame.new(0, 0.45, -0.3), 0.12, 0.12, "squish")
	local halo = newPart(model, Vector3.one * 1.8, glow, Enum.Material.ForceField, Enum.PartType.Ball)
	piece(list, halo, CFrame.new(), "squish")
	for _, side in { -1, 1 } do
		for k = 0, 1 do
			local wing = newPart(model, Vector3.new(0.75 - k * 0.2, 0.04, 0.5 - k * 0.1), accent, Enum.Material.Neon)
			wing.Transparency = 0.35
			piece(list, wing, CFrame.new(side * (0.48 - k * 0.05), 0.15 - k * 0.32, 0.18) * CFrame.Angles(0, math.rad(side * (15 + k * 20)), 0), if side < 0 then "wingL" else "wingR", Vector3.new(-side * 0.35, 0, 0))
		end
	end
	local wand = newPart(model, Vector3.new(0.05, 0.5, 0.05), Color3.fromRGB(240, 220, 160), Enum.Material.Metal)
	piece(list, wand, CFrame.new(0.32, -0.05, -0.12) * CFrame.Angles(math.rad(-30), 0, 0), "squish")
	local star = newPart(model, Vector3.one * 0.14, Color3.fromRGB(255, 240, 150), Enum.Material.Neon, Enum.PartType.Ball)
	piece(list, star, CFrame.new(0.32, 0.18, -0.26), "squish")
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Color = ColorSequence.new(glow, accent)
	sparkles.LightEmission = 1
	sparkles.Size = NumberSequence.new(0.18, 0)
	sparkles.Lifetime = NumberRange.new(0.6, 1.2)
	sparkles.Rate = 14
	sparkles.Speed = NumberRange.new(0.3, 0.8)
	sparkles.Parent = halo
	return 3
end

function BUILDERS.dragon(model, def, list)
	local scale, accent = def.color, def.accent
	-- corpo gordinho com barriga em placas
	local body = newPart(model, Vector3.one * 1.35, scale, nil, Enum.PartType.Ball)
	piece(list, body, CFrame.new(0, 0, 0.1), "body")
	for i = 0, 3 do
		local plate = newPart(model, Vector3.new(0.7 - i * 0.08, 0.16, 0.12), accent)
		piece(list, plate, CFrame.new(0, 0.2 - i * 0.22, -0.62 + i * 0.03), "body")
	end
	-- cabeça com focinho, narinas, olhos e chifres curvos
	local head = newPart(model, Vector3.one * 1.05, scale, nil, Enum.PartType.Ball)
	piece(list, head, CFrame.new(0, 0.7, -0.75), "head")
	local snout = newPart(model, Vector3.one * 0.62, lighter(scale, 0.1), nil, Enum.PartType.Ball)
	piece(list, snout, CFrame.new(0, 0.52, -1.25), "head")
	for _, x in { -0.12, 0.12 } do
		local nostril = newPart(model, Vector3.one * 0.08, EYE, nil, Enum.PartType.Ball)
		piece(list, nostril, CFrame.new(x, 0.62, -1.54), "head")
	end
	eyes(model, list, CFrame.new(0, 0.9, -1.15), 0.24, 0.22)
	for _, side in { -1, 1 } do
		local hornBase = newPart(model, Vector3.new(0.16, 0.38, 0.16), accent)
		piece(list, hornBase, CFrame.new(side * 0.28, 1.25, -0.55) * CFrame.Angles(math.rad(-30), 0, math.rad(side * -15)), "head")
		local hornTip = newPart(model, Vector3.new(0.11, 0.3, 0.11), lighter(accent, 0.3))
		piece(list, hornTip, CFrame.new(side * 0.34, 1.45, -0.38) * CFrame.Angles(math.rad(-60), 0, math.rad(side * -15)), "head")
	end
	-- espinhos nas costas
	for i = 0, 3 do
		local spike = newPart(model, Vector3.new(0.1, 0.32 - i * 0.04, 0.3), accent, nil, Enum.PartType.Wedge)
		piece(list, spike, CFrame.new(0, 0.7 - i * 0.12, -0.15 + i * 0.32), "body")
	end
	-- asas com "ossos" e membrana em três gomos
	for _, side in { -1, 1 } do
		local role = if side < 0 then "wingL" else "wingR"
		local bone = newPart(model, Vector3.new(1.3, 0.1, 0.1), darker(scale, 0.2))
		piece(list, bone, CFrame.new(side * 1.0, 0.55, 0.0), role, Vector3.new(-side * 0.65, 0, 0))
		for k = 0, 2 do
			local membrane = newPart(model, Vector3.new(0.55, 0.05, 0.8 - k * 0.15), accent:Lerp(scale, 0.4), if def.glow then Enum.Material.Neon else Enum.Material.SmoothPlastic)
			membrane.Transparency = if def.glow then 0.25 else 0
			piece(list, membrane, CFrame.new(side * (0.6 + k * 0.42), 0.5, 0.42 - k * 0.05), role, Vector3.new(-side * (0.25 + k * 0.42), 0, 0))
		end
	end
	-- cauda em segmentos com ponta em pá
	for i = 0, 2 do
		local segment = newPart(model, Vector3.one * (0.5 - i * 0.1), scale, nil, Enum.PartType.Ball)
		piece(list, segment, CFrame.new(0, -0.15 - i * 0.05, 0.85 + i * 0.38), "tail", Vector3.new(0, 0, -0.38 * i - 0.2))
	end
	local spade = newPart(model, Vector3.new(0.08, 0.45, 0.45), accent, if def.glow then Enum.Material.Neon else Enum.Material.SmoothPlastic, Enum.PartType.Wedge)
	piece(list, spade, CFrame.new(0, -0.25, 2.05) * CFrame.Angles(0, math.rad(90), 0), "tail", Vector3.new(0, 0, -1.3))
	for _, leg in { { "legFL", -0.38, -0.3 }, { "legFR", 0.38, -0.3 }, { "legBL", -0.4, 0.4 }, { "legBR", 0.4, 0.4 } } do
		local part = newPart(model, Vector3.one * 0.42, darker(scale, 0.1), nil, Enum.PartType.Ball)
		piece(list, part, CFrame.new(leg[2], -0.6, leg[3]), leg[1], Vector3.new(0, 0.2, 0))
	end
	if def.stars then
		local stars = Instance.new("ParticleEmitter")
		stars.Color = ColorSequence.new(Color3.new(1, 1, 1), accent)
		stars.LightEmission = 1
		stars.Size = NumberSequence.new(0.15, 0)
		stars.Lifetime = NumberRange.new(0.8, 1.6)
		stars.Rate = 16
		stars.Speed = NumberRange.new(0.2, 0.6)
		stars.SpreadAngle = Vector2.new(180, 180)
		stars.Parent = body
		for _ = 1, 6 do
			local dot = newPart(model, Vector3.one * 0.1, Color3.new(1, 1, 1), Enum.Material.Neon, Enum.PartType.Ball)
			piece(list, dot, CFrame.new(math.random(-40, 40) / 100, math.random(0, 50) / 100, math.random(-20, 60) / 100), "body")
		end
	end
	return 3
end

local function build(petId, level)
	local def = Pets.List[petId]
	if not def then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = "Pet_" .. petId
	local list = {}
	local builder = BUILDERS[def.shape] or BUILDERS.slime
	local hover = builder(model, def, list)
	if def.glow and list[1] then
		local light = Instance.new("PointLight")
		light.Color = def.color
		light.Range = 8
		light.Brightness = 1.2
		light.Parent = list[1].part
	end
	-- nível em cima do pet
	local tag = UI.new("BillboardGui", { Size = UDim2.fromOffset(90, 18), StudsOffset = Vector3.new(0, 2.6, 0), MaxDistance = 45, LightInfluence = 0, Adornee = list[1].part, Parent = list[1].part })
	local label = UI.label({ Text = ("%s Nv. %d"):format(def.name, level or 1), Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = Color3.fromRGB(220, 255, 230), Parent = tag }, { UI.textStroke(1) })
	model.Parent = folder
	return { model = model, pieces = list, def = def, hover = hover, label = label }
end

-- ===================== ANIMAÇÃO =====================

local function animate(entry, t, moving, flying)
	local role = entry.role
	local walk = if moving then math.sin(t * 14) else 0
	local angle = CFrame.identity
	if role == "legFL" or role == "legBR" then
		angle = CFrame.Angles(walk * 0.7, 0, 0)
	elseif role == "legFR" or role == "legBL" then
		angle = CFrame.Angles(-walk * 0.7, 0, 0)
	elseif role == "wingL" then
		angle = CFrame.Angles(0, 0, math.sin(t * (if moving then 16 else 9)) * 0.7)
	elseif role == "wingR" then
		angle = CFrame.Angles(0, 0, -math.sin(t * (if moving then 16 else 9)) * 0.7)
	elseif role == "tail" then
		angle = CFrame.Angles(0, math.sin(t * (if moving then 10 else 4)) * 0.35, 0)
	elseif role == "head" then
		angle = CFrame.Angles(math.sin(t * 2) * 0.05, math.sin(t * 0.7) * 0.12, 0)
	elseif role == "ears" then
		angle = CFrame.Angles(math.sin(t * 3) * 0.12 + (if moving then 0.25 else 0), 0, 0)
	end
	if angle == CFrame.identity then
		return entry.offset
	end
	-- gira em volta do pivô da peça
	local pivot = entry.pivot
	return entry.offset * CFrame.new(pivot) * angle * CFrame.new(-pivot)
end

-- chão embaixo do pet: o raio começa na altura do dono (assim dentro de casa ele não "sobe" no telhado)
-- e atravessa peças sem colisão (folhas, enfeites, efeitos)
local function groundY(position, owner, ownerY)
	local ignore = { folder, workspace:FindFirstChild("Efeitos"), workspace:FindFirstChild("Drops") }
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(ignore, other.Character)
		end
	end
	local origin = Vector3.new(position.X, ownerY + 1.5, position.Z)
	for _ = 1, 4 do
		rayParams.FilterDescendantsInstances = ignore
		local result = workspace:Raycast(origin, Vector3.new(0, -(origin.Y - ownerY) - 30, 0), rayParams)
		if not result then
			return nil
		end
		local hit = result.Instance
		if hit:IsA("Terrain") or (hit:IsA("BasePart") and hit.CanCollide) then
			return result.Position.Y
		end
		table.insert(ignore, hit)
	end
	return nil
end

local function update(owner, rec, dt, now)
	local character = owner.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		rec.model.Parent = nil
		return
	end
	rec.model.Parent = folder
	local flying = rec.def.fly == true
	-- alvo: atrás e ao lado do dono
	local side = if rec.side then rec.side else 1
	local goal = (root.CFrame * CFrame.new(2.6 * side, 0, 2.8)).Position
	local position = rec.position or goal
	if (position - goal).Magnitude > 60 then
		position = goal
	end
	local offset = Vector3.new(goal.X - position.X, 0, goal.Z - position.Z)
	local distance = offset.Magnitude
	local moving = distance > 0.6
	if moving then
		local speed = math.clamp(distance * 4, 6, 60)
		position += offset.Unit * math.min(distance, speed * dt)
	end
	-- altura: chão (com pulinho) ou flutuando ao lado do dono
	local y
	if flying then
		y = root.Position.Y + 0.8 + math.sin(now * 2.4) * 0.35
	else
		rec.groundTimer = (rec.groundTimer or 0) - dt
		if rec.groundTimer <= 0 or not rec.ground then
			rec.groundTimer = 0.15
			rec.ground = groundY(position, owner, root.Position.Y) or (root.Position.Y - 3)
		end
		local hop = if moving and rec.def.shape ~= "turtle" then math.abs(math.sin(now * 9)) * 0.45 else 0
		y = rec.ground + hop
	end
	position = Vector3.new(position.X, y, position.Z)
	rec.position = position
	-- olha para onde anda (ou para a frente do dono parado)
	local look = if moving then offset.Unit else root.CFrame.LookVector * Vector3.new(1, 0, 1)
	if look.Magnitude < 0.01 then
		look = Vector3.new(0, 0, -1)
	end
	local targetYaw = math.atan2(-look.X, -look.Z)
	rec.yaw = rec.yaw or targetYaw
	local delta = (targetYaw - rec.yaw + math.pi) % (2 * math.pi) - math.pi
	rec.yaw += delta * math.min(1, dt * 8)
	local base = CFrame.new(position) * CFrame.Angles(0, rec.yaw, 0)
	-- slime: achata e estica
	local parts, frames = {}, {}
	for _, entry in rec.pieces do
		local cf = base * animate(entry, now + rec.phase, moving, flying)
		if entry.role == "squish" then
			local squish = math.sin(now * (if moving then 12 else 4)) * (if moving then 0.18 else 0.07)
			cf = base * CFrame.new(0, squish * 0.5, 0) * entry.offset
			entry.part.Size = entry.baseSize * Vector3.new(1 - squish * 0.5, 1 + squish, 1 - squish * 0.5)
		end
		table.insert(parts, entry.part)
		table.insert(frames, cf)
	end
	workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
end

local function refresh(owner)
	local old = active[owner]
	local petId = owner:GetAttribute("Pet")
	local level = owner:GetAttribute("PetLevel") or 1
	if old and old.id == petId then
		old.label.Text = ("%s Nv. %d"):format(old.def.name, level)
		return
	end
	if old then
		old.model:Destroy()
		active[owner] = nil
	end
	if not petId then
		return
	end
	local rec = build(petId, level)
	if not rec then
		return
	end
	for _, entry in rec.pieces do
		entry.baseSize = entry.part.Size
	end
	rec.id = petId
	rec.phase = math.random() * 10
	rec.side = if owner == Players.LocalPlayer then 1 else -1
	active[owner] = rec
end

local function watch(owner)
	owner:GetAttributeChangedSignal("Pet"):Connect(function()
		refresh(owner)
	end)
	owner:GetAttributeChangedSignal("PetLevel"):Connect(function()
		refresh(owner)
	end)
	refresh(owner)
end

function PetRenderer.init()
	for _, owner in Players:GetPlayers() do
		watch(owner)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(owner)
		local rec = active[owner]
		if rec then
			rec.model:Destroy()
			active[owner] = nil
		end
	end)
	RunService.RenderStepped:Connect(function(dt)
		local now = os.clock()
		for owner, rec in active do
			update(owner, rec, math.min(dt, 0.1), now)
		end
	end)
end

-- modelo de exemplo (para a janela de pets)
PetRenderer.build = build

return PetRenderer
