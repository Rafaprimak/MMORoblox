-- Traçado da Vila Aurora (fonte única): ruas, calçadas, praça, becos, lotes das lojas e das casas.
-- Usado pelo terreno (chão sem grama embaixo das ruas), pelo mapa, pela construção (WorldGen/Town),
-- pelos NPCs e pelos moradores. Coordenadas de PROJETO relativas ao centro da praça:
-- x = leste, z = sul (o portal fica ao norte, em z negativo). Multiplique por World.Scale para studs.
-- Direção (facing) em graus: 0 = olha para o norte, 180 = sul, -90 = leste, 90 = oeste.
-- Não exige nenhum módulo (o World usa este aqui).
local TownPlan = {}

TownPlan.StreetHalf = 6 -- ruas com 12 de largura
TownPlan.SidewalkOuter = 9 -- calçadas de 3
TownPlan.FrontLine = 12 -- portas das casas (jardim de 3 entre a calçada e a casa)
TownPlan.PlazaHalf = 26
TownPlan.ArchZ = -94
TownPlan.Radius = 98 -- raio da área plana da vila (o terreno se mistura até Radius + 30)

-- Lojas e NPCs da vila: porta (ou lugar onde o NPC fica) e direção
TownPlan.Services = {
	bruno = { x = -12, z = -40, facing = -90 }, -- forja (lado oeste da rua principal)
	mira = { x = 12, z = -40, facing = 90 }, -- alquimia (lado leste)
	otto = { x = 40, z = -12, facing = 180 }, -- empório (rua transversal leste, lado norte)
	elric = { x = 40, z = 12, facing = 0 }, -- torre (transversal leste, lado sul)
	pedro = { x = -40, z = 10.5, facing = 0 }, -- estábulo (transversal oeste, lado sul)
	kael = { x = 0, z = 42, facing = 0 }, -- entrada do pátio de treino
	lyra = { x = -15, z = -23, facing = 180 }, -- praça, borda norte
	quadro = { x = 15, z = -23, facing = 180 }, -- quadro de contratos
	varg = { x = -12, z = 36, facing = -90 }, -- Covil do Mercador de Masmorras (rua do sul, lado oeste)
	helena = { x = 37, z = 40, facing = 90 }, -- Salão das Guildas (segunda fileira leste, porta para o beco)
}

-- Casas: { x da porta, z da porta, facing, largura, profundidade }
TownPlan.Houses = {
	-- rua principal norte
	{ -12, -62, -90, 12, 12 }, { -12, -80, -90, 10, 10 },
	{ 12, -62, 90, 12, 12 }, { 12, -80, 90, 10, 10 },
	-- rua principal sul
	{ 12, 36, 90, 12, 12 }, -- o lote em frente (x -12) é o Covil do Mercador (serviço "varg")
	-- transversal leste
	{ 64, -12, 180, 12, 12 }, { 82, -12, 180, 10, 10 },
	{ 64, 12, 0, 12, 12 }, { 82, 12, 0, 10, 10 },
	-- transversal oeste
	{ -40, -12, 180, 14, 12 }, { -62, -12, 180, 12, 12 }, { -82, -12, 180, 10, 10 },
	{ -64, 12, 0, 12, 12 }, { -84, 12, 0, 10, 10 },
	-- segunda fileira (portas para os becos)
	{ -37, -40, -90, 12, 10 }, { -37, -62, -90, 12, 10 },
	{ 37, -40, 90, 12, 10 }, { 37, -62, 90, 12, 10 },
	{ -37, 42, -90, 12, 10 }, -- (o lote { 37, 40 } é o Salão das Guildas)
}

-- Faixas de piso: { x1, z1, x2, z2, tipo } (tipo: praca, rua, calcada, beco)
local H, W = TownPlan.StreetHalf, TownPlan.SidewalkOuter
local P = TownPlan.PlazaHalf
TownPlan.Paving = {
	{ -P, -P, P, P, "praca" },
	{ -H, -92, H, -P, "rua" },
	{ -H, P, H, 46, "rua" },
	{ P, -H, 95, H, "rua" },
	{ -95, -H, -P, H, "rua" },
	{ -W, -90, -H, -P, "calcada" }, { H, -90, W, -P, "calcada" },
	{ -W, P, -H, 44, "calcada" }, { H, P, W, 44, "calcada" },
	{ P, -W, 92, -H, "calcada" }, { P, H, 92, W, "calcada" },
	{ -92, -W, -P, -H, "calcada" }, { -92, H, -P, W, "calcada" },
	{ -35, -88, -30, -32, "beco" }, { 30, -88, 35, -32, "beco" },
	{ -92, -31, -30, -27, "beco" }, { 35, -32, 92, -28, "beco" },
	{ 30, 32, 35, 48, "beco" },
}

-- Postes nas calçadas (nos vãos entre lotes): { eixo da rua, posição ao longo dela }
TownPlan.Lamps = {
	{ "z", -28 }, { "z", -52 }, { "z", -71 }, { "z", -88 },
	{ "z", 28 }, { "z", 44 },
	{ "x", 28 }, { "x", 54 }, { "x", 74 }, { "x", 92 },
	{ "x", -28 }, { "x", -53 }, { "x", -74 }, { "x", -92 },
}

local PRIORITY = { praca = 3, rua = 3, calcada = 2, beco = 1 }

-- Tipo de piso no ponto (x, z de projeto), com folga "margin"; nil = sem piso (grama)
function TownPlan.pavingAt(x, z, margin)
	margin = margin or 0
	local best, bestPriority = nil, 0
	for _, strip in TownPlan.Paving do
		local x1, x2 = math.min(strip[1], strip[3]) - margin, math.max(strip[1], strip[3]) + margin
		local z1, z2 = math.min(strip[2], strip[4]) - margin, math.max(strip[2], strip[4]) + margin
		if x >= x1 and x <= x2 and z >= z1 and z <= z2 and PRIORITY[strip[5]] > bestPriority then
			best, bestPriority = strip[5], PRIORITY[strip[5]]
		end
	end
	return best
end

return TownPlan
