-- Estilo artístico (tudo no cliente, só visual):
--   * contorno de desenho animado (cel-shading) nos personagens, NPCs, inimigos e pets por perto:
--     um Highlight só de borda escura. O Roblox desenha no máximo 31 Highlights ao mesmo tempo, então
--     a cada meio segundo só os MAX_OUTLINES mais perto da câmera ganham contorno (configuração "outlines");
--   * vinheta suave nas bordas da tela (moldura "de pintura");
--   * gradação de cor pela hora do dia: dourada no amanhecer/entardecer, azulada à noite
--     (um ColorCorrection próprio, somado ao do servidor; desliga dentro das masmorras, que têm o seu);
--   * névoa leve dentro da mata: a Atmosphere fica mais densa conforme o peso de floresta onde a câmera está
--     (parte do valor que o servidor definiu, que é guardado e respeitado).
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DayNight = require(Shared.DayNight)
local World = require(Shared.World)

local UI = require(script.Parent.UI)
local Prefs = require(script.Parent.Prefs)
local DungeonAtmosphere = require(script.Parent.DungeonAtmosphere)

local ArtStyle = {}

local player = Players.LocalPlayer

local MAX_OUTLINES = 24
local OUTLINE_RANGE = 140
local FOLDERS = { "NPCs", "InimigosVisuais", "Pets" }

-- cor da borda por tipo (quase preta, puxada para o tom de cada um)
local INK = {
	player = Color3.fromRGB(28, 22, 34),
	NPCs = Color3.fromRGB(34, 26, 20),
	InimigosVisuais = Color3.fromRGB(40, 12, 14),
	Pets = Color3.fromRGB(26, 24, 40),
}

local outlines = {} -- [model] = Highlight

local function ink(model, kind)
	local highlight = outlines[model]
	if not highlight then
		highlight = Instance.new("Highlight")
		highlight.Name = "Contorno"
		highlight.FillTransparency = 1
		highlight.OutlineTransparency = 0.12
		highlight.DepthMode = Enum.HighlightDepthMode.Occluded
		highlight.Adornee = model
		highlight.Parent = model
		outlines[model] = highlight
	end
	highlight.OutlineColor = INK[kind] or INK.player
	return highlight
end

local function clearOutline(model)
	local highlight = outlines[model]
	if highlight then
		highlight:Destroy()
		outlines[model] = nil
	end
end

local function pivotOf(model)
	local ok, cf = pcall(model.GetPivot, model)
	return if ok then cf.Position else nil
end

-- escolhe os modelos mais perto da câmera e põe/tira os contornos
local function refreshOutlines()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local enabled = Prefs.get("outlines") ~= false
	local candidates = {}
	if enabled then
		local eye = camera.CFrame.Position
		local function consider(model, kind)
			local position = model:IsA("Model") and pivotOf(model)
			if position then
				local distance = (position - eye).Magnitude
				if distance < OUTLINE_RANGE then
					table.insert(candidates, { model = model, kind = kind, distance = distance })
				end
			end
		end
		for _, other in Players:GetPlayers() do
			if other.Character then
				consider(other.Character, "player")
			end
		end
		for _, name in FOLDERS do
			local folder = workspace:FindFirstChild(name)
			if folder then
				for _, model in folder:GetChildren() do
					consider(model, name)
				end
			end
		end
		table.sort(candidates, function(a, b)
			return a.distance < b.distance
		end)
	end
	local keep = {}
	for i = 1, math.min(#candidates, MAX_OUTLINES) do
		local entry = candidates[i]
		keep[entry.model] = true
		ink(entry.model, entry.kind)
	end
	for model in outlines do
		if not keep[model] or not model.Parent then
			clearOutline(model)
		end
	end
end

-- vinheta: quatro faixas com degradê escuro nas bordas
local function buildVignette()
	local gui = UI.new("ScreenGui", { Name = "Vinheta", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = -10, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = player:WaitForChild("PlayerGui") })
	local sides = {
		{ UDim2.fromScale(1, 0.22), UDim2.fromScale(0, 0), 90 },
		{ UDim2.fromScale(1, 0.22), UDim2.fromScale(0, 0.78), -90 },
		{ UDim2.fromScale(0.16, 1), UDim2.fromScale(0, 0), 0 },
		{ UDim2.fromScale(0.16, 1), UDim2.fromScale(0.84, 0), 180 },
	}
	for _, side in sides do
		UI.new("Frame", { Size = side[1], Position = side[2], BackgroundColor3 = Color3.fromRGB(10, 6, 20), BorderSizePixel = 0, Parent = gui }, {
			UI.new("UIGradient", { Rotation = side[3], Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1) }) }),
		})
	end
	return gui
end

-- gradação pela hora: { hora, tinta, saturação, contraste }
local GRADE = {
	{ 0, Color3.fromRGB(215, 225, 255), -0.03, 0.02 },
	{ 5.5, Color3.fromRGB(215, 215, 255), 0, 0.05 },
	{ 6.6, Color3.fromRGB(255, 222, 196), 0.08, 0.06 },
	{ 9, Color3.fromRGB(255, 248, 238), 0.06, 0.04 },
	{ 15.5, Color3.fromRGB(255, 246, 232), 0.06, 0.04 },
	{ 17.6, Color3.fromRGB(255, 214, 178), 0.12, 0.08 },
	{ 18.7, Color3.fromRGB(235, 205, 235), 0.04, 0.07 },
	{ 20, Color3.fromRGB(215, 225, 255), -0.03, 0.02 },
	{ 24, Color3.fromRGB(215, 225, 255), -0.03, 0.02 },
}

local function gradeAt(clock)
	for i = 1, #GRADE - 1 do
		local a, b = GRADE[i], GRADE[i + 1]
		if clock >= a[1] and clock <= b[1] then
			local t = (clock - a[1]) / math.max(b[1] - a[1], 0.001)
			return a[2]:Lerp(b[2], t), a[3] + (b[3] - a[3]) * t, a[4] + (b[4] - a[4]) * t
		end
	end
	return GRADE[1][2], GRADE[1][3], GRADE[1][4]
end

-- névoa da mata: guarda a densidade/neblina do servidor e soma um pouco conforme a floresta
local mist = { base = nil, haze = nil, written = nil, writtenHaze = nil, amount = 0 }
local function updateMist(inDungeon)
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	local camera = workspace.CurrentCamera
	if not atmosphere or not camera then
		return
	end
	-- o servidor (ou a masmorra) mudou o valor: esse vira a nova base
	if mist.written == nil or math.abs(atmosphere.Density - mist.written) > 0.001 then
		mist.base, mist.haze = atmosphere.Density, atmosphere.Haze
	end
	local target = 0
	if not inDungeon then
		local position = camera.CFrame.Position
		target = World.weights(position.X, position.Z).forest
	end
	mist.amount += (target - mist.amount) * 0.25
	atmosphere.Density = math.clamp(mist.base + mist.amount * 0.12, 0, 1)
	atmosphere.Haze = math.clamp(mist.haze + mist.amount * 1.2, 0, 10)
	mist.written, mist.writtenHaze = atmosphere.Density, atmosphere.Haze
end

function ArtStyle.init()
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "EstiloHora"
	grade.Parent = Lighting
	task.spawn(buildVignette)
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.5 then
			return
		end
		elapsed = 0
		refreshOutlines()
		local inDungeon = DungeonAtmosphere.inDungeon() or player:GetAttribute("Raid") == true
		updateMist(inDungeon)
		grade.Enabled = not inDungeon
		if not inDungeon then
			local tint, saturation, contrast = gradeAt(DayNight.now() % 24)
			grade.TintColor = tint
			grade.Saturation = saturation
			grade.Contrast = contrast
		end
	end)
end

return ArtStyle
