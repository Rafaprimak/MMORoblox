-- Desempenho: tira do mundo (só neste cliente) as árvores, pedras, arbustos e flores longe da câmera
-- e devolve quando você chega perto. A distância depende da "Qualidade gráfica" nas configurações.
-- Só mexe em workspace.Mundo.Natureza (cenário parado; nada ali é mudado pelo servidor depois).
-- Com StreamingEnabled o Roblox também tira e devolve esses modelos: quem chega depois entra na lista
-- (ChildAdded) e quem o Roblox apagou sai dela (mudar o Parent de um modelo apagado dá erro).
local RunService = game:GetService("RunService")

local Prefs = require(script.Parent.Prefs)

local DetailCulling = {}

-- distância de desenho (studs) por qualidade: 1 baixa, 2 média, 3 alta
local DISTANCE = { 450, 800, 1300 } -- mundo em escala realista: árvores enormes aparecem de longe
-- coisas pequenas somem antes (fração da distância)
local SMALL_FRACTION = 0.45
local BATCH = 250 -- modelos conferidos por quadro

local entries = {} -- { model, position, small, hidden }
local known = {} -- [modelo] = true (já está na lista)
local folder

local function register(model)
	if known[model] or (not model:IsA("Model") and not model:IsA("BasePart")) then
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
	known[model] = true
	table.insert(entries, { model = model, position = position, small = small, hidden = false })
end

-- tira da lista (troca com o último para não abrir buraco)
local function removeAt(index)
	known[entries[index].model] = nil
	entries[index] = entries[#entries]
	entries[#entries] = nil
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
		folder.ChildAdded:Connect(function(child)
			task.defer(register, child)
		end)
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
				if #entries == 0 then
					break
				end
				if cursor > #entries then
					cursor = 1
				end
				local entry = entries[cursor]
				-- visível mas sem pai = o Roblox tirou do cliente (streaming): esquece
				if not entry.hidden and entry.model.Parent ~= folder then
					removeAt(cursor)
					continue
				end
				cursor += 1
				local limit = if entry.small then far * SMALL_FRACTION else far
				local offset = entry.position - eye
				local hide = offset.X * offset.X + offset.Z * offset.Z > limit * limit
				if hide ~= entry.hidden then
					local ok = pcall(function()
						entry.model.Parent = if hide then nil else folder
					end)
					if ok then
						entry.hidden = hide
					else
						-- o Roblox apagou o modelo enquanto estava escondido; ele volta pelo ChildAdded
						removeAt(cursor - 1)
					end
				end
			end
		end)
	end)
end

return DetailCulling
