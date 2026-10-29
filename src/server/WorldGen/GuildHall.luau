-- Salão dos Clãs: casa longa viking a leste da vila, ponto de encontro das guildas.
-- Por fora: base de pedra, paredes de tábuas com mata-juntas, telhado alto com tábuas cruzadas e cabeças
-- de dragão nas pontas, portas abertas, tochas, estandartes, placa e pedra rúnica.
-- Por dentro: duas fileiras de colunas, fogueira comprida no meio, mesas de banquete com bancos, escudos
-- e tochas nas paredes, lustres de ferro, estrado no fundo com a Helena (guildas) e o Ulf (contratos),
-- o Mural de Honra (ranking da semana, desenhado pelo GuildService) e o barril de hidromel do brinde
-- (prompt "BrindeSalao", tratado no GuildService).
-- Montado em unidades de projeto no referencial do salão (x = largura, z = comprimento, -Z = porta) e
-- ampliado × PropScale. Posição, tamanho e chão plano em World.GuildHall.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local World = require(Shared.World)

local Props = require(script.Parent.Props)
local Placement = require(script.Parent.Placement)

local GuildHall = {}

local K = World.PropScale
local M = Enum.Material
local part = Props.part

local WOOD = Color3.fromRGB(92, 62, 40)
local DARK = Color3.fromRGB(58, 40, 28)
local STONE = Color3.fromRGB(112, 108, 100)
local IRON = Color3.fromRGB(45, 43, 42)
local GOLD = Color3.fromRGB(220, 175, 80)
local SHIELDS = { Color3.fromRGB(150, 40, 40), Color3.fromRGB(40, 70, 140), Color3.fromRGB(200, 165, 60), Color3.fromRGB(60, 110, 60) }
local BANNERS = { Color3.fromRGB(140, 35, 40), Color3.fromRGB(35, 60, 130), Color3.fromRGB(45, 95, 55), Color3.fromRGB(150, 110, 35) }

local SIGN_TEXT = "Salão dos Clãs. Aqui as guildas se reúnem. Helena funda e organiza as guildas; Ulf distribui os Contratos do Clã (três por dia, só para quem tem guilda). Um brinde no barril de hidromel dá +10% de XP e de ouro por 30 minutos, uma vez por dia. O Mural de Honra, no fundo, mostra as guildas mais fortes da semana."
local RUNE_TEXT = "Pedra rúnica dos clãs. Os primeiros Hunters que lembraram de ontem juraram aqui lutar juntos até o Orbe se abrir. Cada guilda que funda o seu nome no salão renova a jura: ninguém fica para trás no dia que se repete."

-- cilindro deitado no eixo Z (troncos)
local function log(parent, cf, length, diameter, color)
	return part(parent, { Name = "Tora", Shape = Enum.PartType.Cylinder, Size = Vector3.new(length, diameter, diameter), CFrame = cf * CFrame.Angles(0, math.rad(90), 0), Color = color or WOOD, Material = M.Wood })
end

-- mesa comprida de banquete: tampo em tábuas curtas (cada uma menor que uma "parede" do anti-trapaça)
local function feastTable(parent, cf, width, length, height, rng)
	local pieces = math.ceil(length / 5.5)
	local step = length / pieces
	for i = 0, pieces - 1 do
		part(parent, { Name = "Tampo", Size = Vector3.new(width, 0.35, step - 0.08), CFrame = cf * CFrame.new(0, height, -length / 2 + step * (i + 0.5)), Color = Color3.fromRGB(105, 70, 45):Lerp(DARK, rng:NextNumber(0, 0.25)), Material = M.WoodPlanks })
	end
	for _, z in { -length / 2 + 0.6, 0, length / 2 - 0.6 } do
		for _, x in { -1, 1 } do
			part(parent, { Name = "Pe", Size = Vector3.new(0.45, height - 0.18, 0.45), CFrame = cf * CFrame.new(x * (width / 2 - 0.4), (height - 0.18) / 2, z), Color = DARK, Material = M.Wood })
		end
	end
	-- pratos, canecas, carne e velas
	local top = height + 0.175
	for z = -length / 2 + 2, length / 2 - 2, 3 do
		local side = if (z // 3) % 2 == 0 then -1 else 1
		local spot = cf * CFrame.new(side * 0.7, top, z)
		Props.column(parent, spot, 0.08, 1, Color3.fromRGB(160, 150, 135), M.Metal)
		if rng:NextNumber() < 0.5 then
			Props.ball(parent, (spot * CFrame.new(0, 0.3, 0)).Position, 0.6, Color3.fromRGB(140, 75, 40), M.SmoothPlastic, { CanCollide = false })
		end
		Props.column(parent, cf * CFrame.new(-side * 0.8, top, z + 0.8), 0.6, 0.45, Color3.fromRGB(120, 85, 50), M.Wood)
	end
	for _, z in { -length / 4, length / 4 } do
		Props.column(parent, cf * CFrame.new(0, top, z), 0.7, 0.35, Color3.fromRGB(235, 225, 200), M.SmoothPlastic)
		local flame = part(parent, { Name = "Vela", Size = Vector3.new(0.2, 0.35, 0.2), CFrame = cf * CFrame.new(0, top + 0.9, z), Color = Color3.fromRGB(255, 200, 110), Material = M.Neon, CanCollide = false })
		Props.light(flame, Color3.fromRGB(255, 180, 100), 12, 1)
	end
end

-- lustre de ferro pendurado na viga (argola de barras, velas e luz quente)
local function chandelier(parent, cf, hangFrom)
	local drop = hangFrom - cf.Position.Y
	part(parent, { Name = "Corrente", Size = Vector3.new(0.15, drop, 0.15), CFrame = cf * CFrame.new(0, drop / 2, 0), Color = IRON, Material = M.Metal, CanCollide = false })
	for i = 0, 3 do
		part(parent, { Name = "Argola", Size = Vector3.new(2.6, 0.2, 0.2), CFrame = cf * CFrame.Angles(0, math.rad(i * 90), 0) * CFrame.new(0, 0, 1.2), Color = IRON, Material = M.Metal, CanCollide = false })
		local candle = part(parent, { Name = "Vela", Size = Vector3.new(0.3, 0.5, 0.3), CFrame = cf * CFrame.Angles(0, math.rad(i * 90 + 45), 0) * CFrame.new(0, 0.35, 1.6), Color = Color3.fromRGB(255, 210, 130), Material = M.Neon, CanCollide = false })
		if i == 0 then
			Props.light(candle, Color3.fromRGB(255, 185, 110), 22, 1.4)
		end
	end
end

-- tocha de parede (cf: -Z aponta para dentro do salão)
local function wallTorch(parent, cf)
	part(parent, { Name = "Suporte", Size = Vector3.new(0.4, 0.4, 1), CFrame = cf * CFrame.new(0, 0, -0.5), Color = IRON, Material = M.Metal })
	part(parent, { Name = "Cabo", Size = Vector3.new(0.35, 1.4, 0.35), CFrame = cf * CFrame.new(0, 0.5, -1.1), Color = DARK, Material = M.Wood })
	Props.fire(parent, (cf * CFrame.new(0, 1.2, -1.1)).Position, 0.55)
end

-- escudo redondo pendurado na parede lateral (cf: -X aponta para fora da parede, rumo ao salão)
local function shield(parent, cf, color)
	part(parent, { Name = "Escudo", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 2.8, 2.8), CFrame = cf, Color = color, Material = M.Wood })
	part(parent, { Name = "Faixa", Size = Vector3.new(0.32, 2.7, 0.45), CFrame = cf, Color = color:Lerp(Color3.new(1, 1, 1), 0.35), Material = M.Fabric })
	Props.ball(parent, (cf * CFrame.new(-0.25, 0, 0)).Position, 0.7, Color3.fromRGB(150, 140, 120), M.Metal, { CanCollide = false })
end

-- estandarte de pano liso (sem mastro), cf no topo do pano
local function cloth(parent, name, cf, width, height, color)
	part(parent, { Name = "Vara", Size = Vector3.new(width + 0.6, 0.25, 0.25), CFrame = cf, Color = DARK, Material = M.Wood, CanCollide = false })
	local banner = part(parent, { Name = name, Size = Vector3.new(width, height, 0.1), CFrame = cf * CFrame.new(0, -height / 2 - 0.1, 0), Color = color, Material = M.Fabric, CanCollide = false })
	part(parent, { Name = "Franja", Size = Vector3.new(width + 0.05, 0.35, 0.12), CFrame = cf * CFrame.new(0, -height - 0.2, 0), Color = GOLD, Material = M.Fabric, CanCollide = false })
	return banner
end

function GuildHall.build(parent, rng)
	local hall = World.GuildHall
	local W, L, H = hall.width, hall.length, 9
	local halfW, halfL = W / 2, L / 2
	local PL = 1.2 -- topo da base de pedra
	local F = PL + 0.2 -- piso de tábuas
	local T = PL + H -- topo das paredes
	local DOOR = 5 -- meia largura do vão da porta (com os batentes fica 8 de vão livre)
	local cf = CFrame.new(hall.x, hall.y, hall.z) * CFrame.Angles(0, hall.yaw, 0)
	local model = Instance.new("Model")
	model.Name = "SalaoDosClas"

	-- ===== estrutura =====
	part(model, { Name = "Base", Size = Vector3.new(W + 2, PL + 3, L + 2), CFrame = cf * CFrame.new(0, PL - (PL + 3) / 2, 0), Color = STONE, Material = M.Cobblestone })
	part(model, { Name = "Piso", Size = Vector3.new(W - 2, 0.2, L - 2), CFrame = cf * CFrame.new(0, PL + 0.1, 0), Color = Color3.fromRGB(120, 85, 55), Material = M.WoodPlanks })
	for _, sx in { -1, 1 } do
		part(model, { Name = "Parede", Size = Vector3.new(1, H, L), CFrame = cf * CFrame.new(sx * (halfW - 0.5), PL + H / 2, 0), Color = WOOD, Material = M.WoodPlanks })
		part(model, { Name = "Parede", Size = Vector3.new(halfW - 1 - DOOR, H, 1), CFrame = cf * CFrame.new(sx * (DOOR + (halfW - 1 - DOOR) / 2), PL + H / 2, -halfL + 0.5), Color = WOOD, Material = M.WoodPlanks })
		part(model, { Name = "Batente", Size = Vector3.new(1, 8, 1.6), CFrame = cf * CFrame.new(sx * (DOOR - 0.5), PL + 4, -halfL + 0.5), Color = DARK, Material = M.Wood })
	end
	part(model, { Name = "Parede", Size = Vector3.new(W - 2, H, 1), CFrame = cf * CFrame.new(0, PL + H / 2, halfL - 0.5), Color = WOOD, Material = M.WoodPlanks })
	part(model, { Name = "Verga", Size = Vector3.new(DOOR * 2, H - 8, 1), CFrame = cf * CFrame.new(0, PL + 8 + (H - 8) / 2, -halfL + 0.5), Color = WOOD, Material = M.WoodPlanks })
	-- quinas e mata-juntas por fora (tábuas verticais escuras)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			part(model, { Name = "Quina", Size = Vector3.new(1.4, H + 0.6, 1.4), CFrame = cf * CFrame.new(sx * halfW, PL + (H + 0.6) / 2, sz * halfL), Color = DARK, Material = M.Wood })
		end
		for z = -halfL + 4, halfL - 4, 4 do
			part(model, { Name = "MataJunta", Size = Vector3.new(0.3, H, 0.5), CFrame = cf * CFrame.new(sx * (halfW + 0.15), PL + H / 2, z), Color = DARK, Material = M.Wood })
		end
	end
	for x = -halfW + 4, halfW - 4, 4 do
		part(model, { Name = "MataJunta", Size = Vector3.new(0.5, H, 0.3), CFrame = cf * CFrame.new(x, PL + H / 2, halfL + 0.15), Color = DARK, Material = M.Wood })
		if math.abs(x) > DOOR + 1 then
			part(model, { Name = "MataJunta", Size = Vector3.new(0.5, H, 0.3), CFrame = cf * CFrame.new(x, PL + H / 2, -halfL - 0.15), Color = DARK, Material = M.Wood })
		end
	end
	-- viga entalhada sobre a porta, com o nome do salão
	local beam = part(model, { Name = "VigaEntalhada", Size = Vector3.new(DOOR * 2 + 3, 0.9, 0.4), CFrame = cf * CFrame.new(0, PL + 8.45, -halfL - 0.2), Color = DARK, Material = M.Wood })
	Props.engrave(beam, "SALÃO DOS CLÃS", GOLD, { Enum.NormalId.Front })
	Props.readable(beam, "Salão dos Clãs", SIGN_TEXT, 24)
	-- portas abertas para fora
	for _, sx in { -1, 1 } do
		local hinge = cf * CFrame.new(sx * DOOR, PL + 0.1 + 3.8, -halfL - 0.2)
		local leaf = hinge * CFrame.Angles(0, math.rad(sx * 70), 0) * CFrame.new(sx * 2.4, 0, 0)
		part(model, { Name = "Porta", Size = Vector3.new(4.8, 7.6, 0.35), CFrame = leaf, Color = Color3.fromRGB(80, 55, 35), Material = M.WoodPlanks })
		for _, y in { -2.4, 2.4 } do
			part(model, { Name = "Ferragem", Size = Vector3.new(4.2, 0.3, 0.1), CFrame = leaf * CFrame.new(0, y, -0.22), Color = IRON, Material = M.Metal })
		end
	end
	-- degraus da entrada (afundados no chão para não ficarem no ar)
	part(model, { Name = "Degrau", Size = Vector3.new(DOOR * 2 + 4, 1.4, 1.2), CFrame = cf * CFrame.new(0, -0.3, -halfL - 1 - 1.8), Color = STONE, Material = M.Slate })
	part(model, { Name = "Degrau", Size = Vector3.new(DOOR * 2 + 4, 1.8, 1.2), CFrame = cf * CFrame.new(0, -0.1, -halfL - 1 - 0.6), Color = STONE, Material = M.Slate })

	-- ===== telhado alto com tábuas cruzadas e cabeças de dragão =====
	local pitch = 42
	local rise = Props.roof(model, cf * CFrame.new(0, T, 0), W, L, pitch, Color3.fromRGB(85, 62, 45))
	local angle = math.rad(pitch)
	for _, sz in { -1, 1 } do
		for i, side in { -1, 1 } do
			local d = Vector3.new(-side * math.cos(angle), math.sin(angle), 0) -- da beira até a cumeeira
			local n = Vector3.new(side * math.sin(angle), math.cos(angle), 0) -- para fora do telhado
			local z = sz * (halfL + 1.25 + (i - 1) * 0.45)
			local ridge = Vector3.new(0, T + rise, z) + n * 0.6
			local phi = math.atan2(d.Y, d.X)
			part(model, { Name = "TabuaCruzada", Size = Vector3.new(9, 0.7, 0.4), CFrame = cf * CFrame.new(ridge - d * 0.5) * CFrame.Angles(0, 0, phi), Color = DARK, Material = M.Wood })
			local head = cf * CFrame.new(ridge + d * 4.4) * CFrame.Angles(0, 0, phi)
			part(model, { Name = "CabecaDragao", Size = Vector3.new(1.8, 1.1, 0.9), CFrame = head, Color = Color3.fromRGB(70, 48, 32), Material = M.Wood })
			part(model, { Name = "Focinho", Size = Vector3.new(1, 0.6, 0.7), CFrame = head * CFrame.new(1.2, -0.15, 0), Color = Color3.fromRGB(70, 48, 32), Material = M.Wood })
			for _, ez in { -0.47, 0.47 } do
				part(model, { Name = "Olho", Size = Vector3.new(0.25, 0.25, 0.06), CFrame = head * CFrame.new(0.4, 0.2, ez), Color = Color3.fromRGB(255, 90, 40), Material = M.Neon, CanCollide = false })
			end
		end
	end
	-- fumaça saindo pela cumeeira (em cima da fogueira)
	local vent = part(model, { Name = "Respiro", Size = Vector3.new(2, 0.4, 3), CFrame = cf * CFrame.new(0, T + rise + 0.9, -2), Color = DARK, Material = M.Wood, CanCollide = false })
	Props.smoke(vent, 5)

	-- ===== interior: colunas, vigas e tirantes =====
	local postTop = T + 4.4
	for z = -32, 32, 8 do
		for _, sx in { -1, 1 } do
			Props.column(model, cf * CFrame.new(sx * 15, F, z), postTop - F, 1.2, DARK, M.Wood)
		end
		part(model, { Name = "Tirante", Size = Vector3.new(W - 2, 0.8, 0.8), CFrame = cf * CFrame.new(0, T - 0.4, z), Color = DARK, Material = M.Wood, CanCollide = false })
	end
	for _, sx in { -1, 1 } do
		part(model, { Name = "Terca", Size = Vector3.new(1, 0.9, L - 2), CFrame = cf * CFrame.new(sx * 15, postTop + 0.45, 0), Color = DARK, Material = M.Wood, CanCollide = false })
	end

	-- ===== fogueira comprida =====
	local hearthZ = -2
	for _, sx in { -1, 1 } do
		part(model, { Name = "BordaFogueira", Size = Vector3.new(0.8, 0.8, 30), CFrame = cf * CFrame.new(sx * 2.1, F + 0.4, hearthZ), Color = STONE, Material = M.Slate })
	end
	for _, sz in { -1, 1 } do
		part(model, { Name = "BordaFogueira", Size = Vector3.new(3.4, 0.8, 0.8), CFrame = cf * CFrame.new(0, F + 0.4, hearthZ + sz * 14.6), Color = STONE, Material = M.Slate })
	end
	part(model, { Name = "Brasas", Size = Vector3.new(3.4, 0.2, 28.4), CFrame = cf * CFrame.new(0, F + 0.1, hearthZ), Color = Color3.fromRGB(255, 95, 30), Material = M.Neon, CanCollide = false, Transparency = 0.2 })
	for _, z in { -9, 0, 9 } do
		for _, a in { -30, 30 } do
			part(model, { Name = "Lenha", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.6, 0.5, 0.5), CFrame = cf * CFrame.new(0, F + 0.45, hearthZ + z) * CFrame.Angles(0, math.rad(a), 0), Color = Color3.fromRGB(50, 32, 22), Material = M.Wood, CanCollide = false })
		end
		Props.fire(model, (cf * CFrame.new(0, F + 0.4, hearthZ + z)).Position, 1.3)
	end
	-- caldeirão num tripé na ponta da fogueira
	for i = 0, 2 do
		part(model, { Name = "Tripe", Size = Vector3.new(0.25, 4.4, 0.25), CFrame = cf * CFrame.new(0, F + 2, hearthZ + 13) * CFrame.Angles(0, math.rad(i * 120), 0) * CFrame.new(0, 0, 1.1) * CFrame.Angles(math.rad(-15), 0, 0), Color = IRON, Material = M.Metal, CanCollide = false })
	end
	Props.ball(model, (cf * CFrame.new(0, F + 2.2, hearthZ + 13)).Position, 1.8, IRON, M.Metal, { CanCollide = false })

	-- ===== mesas de banquete e bancos =====
	for _, sx in { -1, 1 } do
		feastTable(model, cf * CFrame.new(sx * 9.5, F, hearthZ), 3.2, 36, 1.9, rng)
		for _, bx in { -2.3, 2.3 } do
			part(model, { Name = "Banco", Size = Vector3.new(0.9, 1.1, 34), CFrame = cf * CFrame.new(sx * 9.5 + bx, F + 0.55, hearthZ), Color = WOOD, Material = M.Wood })
		end
		for _, z in { -16, 0, 16 } do
			chandelier(model, cf * CFrame.new(sx * 9.5, T - 3.2, z), T - 0.8)
		end
	end

	-- ===== paredes por dentro: escudos, tochas e estandartes =====
	for _, sx in { -1, 1 } do
		local inner = sx * (halfW - 1)
		for i, z in { -32, -24, -16, -8, 0, 8, 16, 24, 32 } do
			shield(model, cf * CFrame.new(inner - sx * 0.15, F + 6, z) * CFrame.Angles(0, if sx < 0 then math.rad(180) else 0, 0), SHIELDS[(i + (if sx < 0 then 1 else 0)) % #SHIELDS + 1])
		end
		for _, z in { -28, -12, 4, 20 } do
			wallTorch(model, cf * CFrame.new(inner, F + 4, z) * CFrame.Angles(0, math.rad(sx * 90), 0))
		end
	end
	for i, z in { -16, 0, 16 } do
		for j, x in { -5, 5 } do
			Props.banner(model, cf * CFrame.new(x, T - 0.95, z - 0.6), BANNERS[(i + j) % #BANNERS + 1])
		end
	end

	-- ===== estrado do fundo =====
	part(model, { Name = "Estrado", Size = Vector3.new(26, 1, 8), CFrame = cf * CFrame.new(0, F + 0.5, 34), Color = DARK, Material = M.WoodPlanks })
	part(model, { Name = "Degrau", Size = Vector3.new(26, 0.5, 1), CFrame = cf * CFrame.new(0, F + 0.25, 29.5), Color = DARK, Material = M.WoodPlanks })
	part(model, { Name = "Pele", Size = Vector3.new(10, 0.08, 5), CFrame = cf * CFrame.new(0, F + 1.04, 33.5), Color = Color3.fromRGB(150, 120, 90), Material = M.Fabric, CanCollide = false })
	local top = F + 1
	-- mesinhas da Helena (x = -8.5) e do Ulf (x = 8.5); os NPCs ficam em z = 34 (NPCs.List), dos lados do mural
	for _, x in { -8.5, 8.5 } do
		local desk = cf * CFrame.new(x, top, 31.6)
		part(model, { Name = "Mesinha", Size = Vector3.new(3.6, 0.3, 1.5), CFrame = desk * CFrame.new(0, 1.9, 0), Color = Color3.fromRGB(105, 70, 45), Material = M.WoodPlanks })
		for _, lx in { -1.5, 1.5 } do
			part(model, { Name = "Pe", Size = Vector3.new(0.35, 1.75, 0.35), CFrame = desk * CFrame.new(lx, 0.875, 0), Color = DARK, Material = M.Wood })
		end
	end
	-- pergaminhos e tinteiro do Ulf, livro da Helena
	for i = 0, 2 do
		part(model, { Name = "Pergaminho", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 0.3, 0.3), CFrame = cf * CFrame.new(8.5 - 0.6 + i * 0.6, top + 2.2, 31.5) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(230, 215, 175), Material = M.SmoothPlastic })
	end
	part(model, { Name = "Livro", Size = Vector3.new(1.2, 0.25, 0.9), CFrame = cf * CFrame.new(-8.5, top + 2.18, 31.5), Color = Color3.fromRGB(120, 40, 40), Material = M.Fabric })
	-- quadro de contratos atrás do Ulf
	for _, x in { 11.2, 14.8 } do
		part(model, { Name = "PosteQuadro", Size = Vector3.new(0.4, 5.5, 0.4), CFrame = cf * CFrame.new(x, top + 2.75, 36.5), Color = DARK, Material = M.Wood })
	end
	local board = part(model, { Name = "QuadroContratos", Size = Vector3.new(3.6, 2.6, 0.3), CFrame = cf * CFrame.new(13, top + 3.8, 36.5), Color = Color3.fromRGB(130, 95, 60), Material = M.WoodPlanks })
	for i = 0, 3 do
		part(model, { Name = "Aviso", Size = Vector3.new(0.9, 1.1, 0.05), CFrame = cf * CFrame.new(11.8 + (i % 2) * 1.2 + (i // 2) * 0.6, top + 4.3 - (i // 2) * 1.2, 36.33) * CFrame.Angles(0, 0, math.rad((i - 1.5) * 5)), Color = Color3.fromRGB(235, 225, 195), Material = M.SmoothPlastic, CanCollide = false })
	end
	Props.readable(board, "Contratos do Clã", "Três contratos por dia, só para quem tem guilda. Pegue com o Ulf, faça e entregue aqui. Cada entrega rende ouro, XP e 25 pontos para a sua guilda (e conta na meta \"Contratos do Clã\" quando ela sai na semana).", 18)
	-- emblemas atrás da Helena
	for i = 0, 2 do
		part(model, { Name = "Emblema", Size = Vector3.new(1.4, 1.4, 0.15), CFrame = cf * CFrame.new(-14.8 + i * 1.8, top + 4, 38.92) * CFrame.Angles(0, 0, math.rad(45)), Color = BANNERS[i + 1], Material = M.Fabric, CanCollide = false })
	end
	-- braseiros nas pontas do estrado
	for _, x in { -11.5, 11.5 } do
		Props.column(model, cf * CFrame.new(x, top, 31), 2.2, 0.6, IRON, M.Metal)
		Props.column(model, cf * CFrame.new(x, top + 2.2, 31), 0.6, 1.8, IRON, M.Metal)
		Props.fire(model, (cf * CFrame.new(x, top + 2.6, 31)).Position, 0.8)
	end

	-- ===== Mural de Honra e estandartes de honra (cores das 3 primeiras guildas da semana) =====
	part(model, { Name = "MolduraMural", Size = Vector3.new(15, 7, 0.2), CFrame = cf * CFrame.new(0, F + 5.4, halfL - 1.1), Color = DARK, Material = M.Wood })
	part(model, { Name = "MuralHonra", Size = Vector3.new(14, 6, 0.3), CFrame = cf * CFrame.new(0, F + 5.4, halfL - 1.35), Color = Color3.fromRGB(40, 32, 26), Material = M.Wood })
	cloth(model, "EstandarteHonra1", cf * CFrame.new(0, T + 8, halfL - 0.6), 4, 7, Color3.fromRGB(90, 85, 80))
	cloth(model, "EstandarteHonra2", cf * CFrame.new(-16.5, T - 1.2, halfL - 1.25), 3, 5.5, Color3.fromRGB(90, 85, 80))
	cloth(model, "EstandarteHonra3", cf * CFrame.new(16.5, T - 1.2, halfL - 1.25), 3, 5.5, Color3.fromRGB(90, 85, 80))

	-- ===== barril de hidromel (brinde) e canto das armas =====
	local mead = Props.column(model, cf * CFrame.new(17.2, F, -30), 3.2, 2.4, Color3.fromRGB(110, 72, 40), M.Wood)
	mead.Name = "BarrilHidromel"
	for _, y in { 0.5, 2.7 } do
		Props.column(model, cf * CFrame.new(17.2, F + y - 0.12, -30), 0.24, 2.5, IRON, M.Metal)
	end
	part(model, { Name = "Torneira", Size = Vector3.new(0.6, 0.25, 0.25), CFrame = cf * CFrame.new(15.85, F + 1, -30), Color = Color3.fromRGB(170, 140, 80), Material = M.Metal })
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BrindeSalao"
	prompt.ActionText = "Brindar"
	prompt.ObjectText = "Barril de Hidromel"
	prompt.HoldDuration = 0.6
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = mead
	for i, z in { -34.2, -36.4 } do
		log(model, cf * CFrame.new(17.2, F + 1.1, z) * CFrame.Angles(0, math.rad(90), 0), 3, 2.2, Color3.fromRGB(100, 66, 38))
		if i == 1 then
			log(model, cf * CFrame.new(17.2, F + 3, -35.3) * CFrame.Angles(0, math.rad(90), 0), 3, 2.2, Color3.fromRGB(100, 66, 38))
		end
	end
	part(model, { Name = "Mesinha", Size = Vector3.new(1.6, 0.25, 2.2), CFrame = cf * CFrame.new(17.4, F + 1.9, -26.6), Color = Color3.fromRGB(105, 70, 45), Material = M.WoodPlanks })
	part(model, { Name = "Pe", Size = Vector3.new(0.4, 1.78, 0.4), CFrame = cf * CFrame.new(17.4, F + 0.89, -26.6), Color = DARK, Material = M.Wood })
	for i = 0, 2 do
		part(model, { Name = "Chifre", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 0.35, 0.35), CFrame = cf * CFrame.new(17.4, F + 2.25, -27.4 + i * 0.75) * CFrame.Angles(0, 0, math.rad(35)), Color = Color3.fromRGB(225, 205, 160), Material = M.SmoothPlastic, CanCollide = false })
	end
	-- suporte de armas (lado esquerdo da entrada)
	for _, z in { -32.5, -27.5 } do
		part(model, { Name = "PosteArmas", Size = Vector3.new(0.4, 3.6, 0.4), CFrame = cf * CFrame.new(-17.6, F + 1.8, z), Color = DARK, Material = M.Wood })
	end
	part(model, { Name = "TravessaArmas", Size = Vector3.new(0.3, 0.3, 5.4), CFrame = cf * CFrame.new(-17.6, F + 3.3, -30), Color = DARK, Material = M.Wood })
	for i = 0, 2 do
		local z = -31.6 + i * 1.6
		part(model, { Name = "Cabo", Size = Vector3.new(0.2, 3.4, 0.2), CFrame = cf * CFrame.new(-17.35, F + 1.75, z) * CFrame.Angles(math.rad(8), 0, 0), Color = Color3.fromRGB(90, 60, 38), Material = M.Wood, CanCollide = false })
		part(model, { Name = "Lamina", Size = Vector3.new(0.12, 0.9, 1), CFrame = cf * CFrame.new(-17.35, F + 3.2, z + 0.4) * CFrame.Angles(math.rad(8), 0, 0), Color = Color3.fromRGB(170, 170, 175), Material = M.Metal, CanCollide = false })
	end

	-- ===== lado de fora =====
	local front = -halfL - 4
	for _, sx in { -1, 1 } do
		-- tochas altas na porta
		part(model, { Name = "PosteTocha", Size = Vector3.new(0.8, 6, 0.8), CFrame = cf * CFrame.new(sx * 8, 3 - 0.5, front), Color = DARK, Material = M.Wood })
		Props.column(model, cf * CFrame.new(sx * 8, 5.5, front), 0.6, 1.6, IRON, M.Metal)
		local flame = Props.fire(model, (cf * CFrame.new(sx * 8, 6.1, front)).Position, 0.8)
		Props.nightLight(flame)
		-- mastros com estandartes
		part(model, { Name = "Mastro", Size = Vector3.new(0.5, 12.5, 0.5), CFrame = cf * CFrame.new(sx * 14, 6.25 - 0.5, front - 2), Color = DARK, Material = M.Wood })
		Props.banner(model, cf * CFrame.new(sx * 14, 11.4, front - 2.4), BANNERS[if sx < 0 then 1 else 2])
		-- barris na parede da frente
		Props.barrel(model, cf * CFrame.new(sx * 17, 0, -halfL - 2.6), 0.9)
	end
	-- lenha empilhada na parede lateral
	for row = 0, 2 do
		for col = 0, 3 - row do
			log(model, cf * CFrame.new(halfW + 1.5 + col * 0.92 + row * 0.46, 0.45 + row * 0.8, -14), 6, 0.9, Color3.fromRGB(105, 75, 50))
		end
	end
	-- placa e pedra rúnica no caminho
	Props.signpost(model, cf * CFrame.new(-9, 0, -halfL - 13), "Salão dos Clãs", SIGN_TEXT, GOLD)
	local rune = part(model, { Name = "PedraRunica", Size = Vector3.new(2.6, 5.5, 0.9), CFrame = cf * CFrame.new(9, 2.2, -halfL - 13) * CFrame.Angles(math.rad(-4), 0, math.rad(3)), Color = Color3.fromRGB(105, 105, 110), Material = M.Slate })
	Props.engrave(rune, "CLÃS", Color3.fromRGB(140, 200, 255), { Enum.NormalId.Front })
	Props.readable(rune, "Pedra Rúnica dos Clãs", RUNE_TEXT, 18)

	model.Parent = parent
	Props.scaleModel(model, cf, K)
	Placement.reserve(hall.x, hall.z, 72, "salao")
	local yard = cf * CFrame.new(0, 0, (-halfL - 12) * K)
	Placement.reserve(yard.X, yard.Z, 26, "salao")
	return model
end

return GuildHall
