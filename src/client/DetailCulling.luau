-- Desempenho: tira do mundo (só neste cliente) as árvores, pedras, arbustos e flores longe da câmera
-- e devolve quando você chega perto. A distância depende da "Qualidade gráfica" nas configurações.
-- Só mexe em workspace.Mundo.Natureza (cenário parado; nada ali é mudado pelo servidor depois).
local RunService = game:GetService("RunService")

local Prefs = require(script.Parent.Prefs)

local DetailCulling = {}

-- distância de desenho (studs) por qualidade: 1 baixa, 2 média, 3 alta
local DISTANCE = { 450, 800, 1300 } -- mundo em escala realista: árvores enormes aparecem de longe
-- coisas pequenas somem antes (fração da distância)
local SMALL_FRACTION = 0.45
local BATCH = 250 -- modelos conferidos por quadro

local entries = {} -- { model, position, small, hidden }
local folder

local function register(model)
	if not model:IsA("Model") and not model:IsA("BasePart") then
		return
	end
	local position
	local small = false
	if model:IsA("Model") then
		local cf, size = model:GetBoundingBox()
		position = cf.Position
		small = size.Magnitude < 14
	else
		position = model.Position
		small = model.Size.Magnitude < 14
	end
	table.insert(entries, { model = model, position = position, small = small, hidden = false })
end

function DetailCulling.init()
	task.spawn(function()
		while not workspace:GetAttribute("WorldReady") do
			task.wait(1)
		end
		local world = workspace:WaitForChild("Mundo", 60)
		folder = world and world:WaitForChild("Natureza", 60)
		if not folder then
			return
		end
		task.wait(2) -- espera a natureza terminar de chegar do servidor
		for i, child in folder:GetChildren() do
			register(child)
			if i % 300 == 0 then
				task.wait()
			end
		end
		local cursor = 1
		RunService.Heartbeat:Connect(function()
			local camera = workspace.CurrentCamera
			if not camera or #entries == 0 then
				return
			end
			local eye = camera.CFrame.Position
			local quality = math.clamp(math.floor(Prefs.get("quality") or 2), 1, 3)
			local far = DISTANCE[quality]
			for _ = 1, math.min(BATCH, #entries) do
				local entry = entries[cursor]
				cursor = cursor % #entries + 1
				local limit = if entry.small then far * SMALL_FRACTION else far
				local offset = entry.position - eye
				local hide = offset.X * offset.X + offset.Z * offset.Z > limit * limit
				if hide ~= entry.hidden then
					entry.hidden = hide
					entry.model.Parent = if hide then nil else folder
				end
			end
		end)
	end)
end

return DetailCulling
