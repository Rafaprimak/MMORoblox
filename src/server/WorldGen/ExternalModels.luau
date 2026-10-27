-- Modelos 3D da Creator Store (gratuitos, low-poly) para a natureza: carvalhos, pinheiros, palmeiras,
-- árvores secas, pedras e arbustos. Carregados uma vez no servidor com AssetService:LoadAssetAsync e
-- clonados por Props.oak/pine/... no lugar das versões blocadas.
--   * Precisa do jogo publicado e de "Permitir o carregamento de ativos de terceiros" ligado
--     (Configurações do jogo → Segurança). Sem isso (ou no Studio sem publicar) o carregamento falha e
--     as árvores blocadas continuam: nada quebra.
--   * Limpeza: scripts, sons, luzes, humanoides e prompts são apagados; tudo ancorado; só a parte de baixo
--     das árvores (tronco) tem colisão, para a copa não prender ninguém.
--   * Pacote (vários modelos espalhados num só) vira várias variações.
--   * Altura: cada tipo tem uma altura-alvo parecida com a das árvores blocadas (× scale do Props).
local AssetService = game:GetService("AssetService")

local ExternalModels = {}

-- [tipo] = { ids da Creator Store, altura-alvo (studs × scale), colisão: "trunk" | "all" | "none" }
ExternalModels.Catalog = {
	oak = { ids = { 4893246329, 3287226226, 10707210767 }, height = 18, collide = "trunk" },
	pine = { ids = { 12549617200, 5616880673, 8559395722 }, height = 18, collide = "trunk" },
	palm = { ids = { 10354687850 }, height = 13, collide = "trunk" },
	deadTree = { ids = { 5575673162, 70515116941793 }, height = 11, collide = "trunk" },
	rock = { ids = { 7299047040, 2128776869 }, height = 2.6, collide = "all" },
	bush = { ids = { 14720410685, 7191673673 }, height = 3.2, collide = "none" },
}

local REMOVE = { "LuaSourceContainer", "Sound", "Light", "Humanoid", "ProximityPrompt", "ClickDetector", "Tool", "Fire", "Smoke", "Sparkles", "ParticleEmitter", "BillboardGui", "SurfaceGui" }
local TRUNK_FRACTION = 0.4 -- abaixo de 40% da altura = tronco (com colisão)

local templates = {} -- [tipo] = { { model, height, scale } }
local loaded = false

local function clean(root)
	for _, item in root:GetDescendants() do
		for _, className in REMOVE do
			if item:IsA(className) then
				item:Destroy()
				break
			end
		end
	end
	for _, item in root:GetDescendants() do
		if item:IsA("BasePart") then
			item.Anchored = true
			item.CanTouch = false
			item.Locked = true
		end
	end
end

local function partsOf(root)
	local list = {}
	if root:IsA("BasePart") then
		table.insert(list, root)
	end
	for _, item in root:GetDescendants() do
		if item:IsA("BasePart") then
			table.insert(list, item)
		end
	end
	return list
end

-- caixa (centro, tamanho) de um modelo ou peça
local function bounds(root)
	if root:IsA("Model") then
		local cf, size = root:GetBoundingBox()
		return cf.Position, size
	end
	return root.Position, root.Size
end

-- um pacote (vários modelos espalhados) vira várias variações; um modelo só fica inteiro
local function variantsOf(asset)
	local root = asset
	local children = {}
	for _, child in root:GetChildren() do
		if child:IsA("Model") or child:IsA("BasePart") then
			table.insert(children, child)
		end
	end
	if #children == 1 and children[1]:IsA("Model") then
		return variantsOf(children[1])
	end
	if #children >= 3 then
		local _, whole = bounds(root)
		local extents = {}
		for _, child in children do
			local _, size = bounds(child)
			table.insert(extents, math.max(size.X, size.Z))
		end
		table.sort(extents)
		local median = extents[math.ceil(#extents / 2)]
		if math.max(whole.X, whole.Z) > median * 3 then
			return children -- pacote: cada filho é uma variação
		end
	end
	return { root }
end

-- deixa a variação pronta para clonar: Model com o pivô no chão, no centro
local function prepare(variant, collide)
	local model = variant
	if variant:IsA("BasePart") then
		model = Instance.new("Model")
		variant.Parent = model
	end
	local center, size = bounds(model)
	if size.Y < 0.2 then
		return nil
	end
	local bottom = center.Y - size.Y / 2
	model.WorldPivot = CFrame.new(center.X, bottom, center.Z)
	for _, part in partsOf(model) do
		if collide == "none" then
			part.CanCollide = false
		elseif collide == "trunk" then
			part.CanCollide = part.Position.Y - bottom < size.Y * TRUNK_FRACTION and math.max(part.Size.X, part.Size.Z) < size.Y * 0.5
		end
		part.CastShadow = true
	end
	-- árvore feita de uma malha só (tronco + copa juntos): colisão invisível só no tronco
	if collide == "trunk" then
		local solid = false
		for _, part in partsOf(model) do
			solid = solid or part.CanCollide
		end
		if not solid then
			local width = math.max(size.Y * 0.07, 0.6)
			local trunk = Instance.new("Part")
			trunk.Name = "ColisaoTronco"
			trunk.Shape = Enum.PartType.Cylinder
			trunk.Size = Vector3.new(size.Y * 0.45, width, width)
			trunk.CFrame = CFrame.new(center.X, bottom + size.Y * 0.225, center.Z) * CFrame.Angles(0, 0, math.pi / 2)
			trunk.Anchored = true
			trunk.CanTouch = false
			trunk.Transparency = 1
			trunk.Parent = model
		end
	end
	model.Parent = nil
	return { model = model, height = size.Y, scale = model:GetScale() }
end

local function loadOne(kind, id, entry)
	local ok, asset = pcall(AssetService.LoadAssetAsync, AssetService, id)
	if not ok or not asset then
		return false, asset
	end
	clean(asset)
	for _, variant in variantsOf(asset) do
		local template = prepare(variant, entry.collide)
		if template then
			templates[kind] = templates[kind] or {}
			table.insert(templates[kind], template)
		end
	end
	return true
end

-- Carrega tudo (em paralelo). Chame antes de espalhar a natureza.
function ExternalModels.preload()
	if loaded then
		return
	end
	loaded = true
	local pending, failures, firstError = 0, 0, nil
	for kind, entry in ExternalModels.Catalog do
		for _, id in entry.ids do
			pending += 1
			task.spawn(function()
				local ok, err = loadOne(kind, id, entry)
				if not ok then
					failures += 1
					firstError = firstError or err
				end
				pending -= 1
			end)
		end
	end
	local start = os.clock()
	while pending > 0 and os.clock() - start < 30 do
		task.wait(0.1)
	end
	if failures > 0 then
		warn(("[ExternalModels] %d modelo(s) da Creator Store não carregaram; usando os blocados no lugar. "
			.. "Publique o jogo e ligue \"Permitir o carregamento de ativos de terceiros\" em Configurações do jogo → Segurança. (%s)"):format(failures, tostring(firstError)))
	end
end

-- Coloca uma cópia do modelo; nil se não há modelo carregado desse tipo (aí o Props usa o blocado)
function ExternalModels.place(kind, parent, ground, scale, rng)
	local list = templates[kind]
	if not list or #list == 0 then
		return nil
	end
	local template = list[rng:NextInteger(1, #list)]
	local entry = ExternalModels.Catalog[kind]
	local target = entry.height * scale * rng:NextNumber(0.85, 1.15)
	local model = template.model:Clone()
	model.Name = kind
	model:ScaleTo(template.scale * target / template.height)
	model:PivotTo(ground * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
	model.Parent = parent
	return model
end

return ExternalModels
