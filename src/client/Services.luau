-- Janelas dos ofícios: Forja (criar/aprimorar), Encantador (encantar/desmontar), Alquimia, Loja e Estábulo.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Recipes = require(Shared.Recipes)
local Rarities = require(Shared.Rarities)
local Perks = require(Shared.Perks)

local UI = require(script.Parent.UI)
local ItemIcon = require(script.Parent.ItemIcon)
local State = require(script.Parent.State)
local Window = require(script.Parent.Window)
local ItemGrid = require(script.Parent.ItemGrid)
local Sounds = require(script.Parent.Sounds)
local Popups = require(script.Parent.Popups)
local Fx = require(script.Parent.Fx)

local Services = {}

Services.openChest = function() end -- preenchido pelo init

local function text(parent, props)
	local merged = { Size = UDim2.new(1, 0, 0, 18), TextScaled = false, TextSize = 15, TextWrapped = true, Font = Enum.Font.GothamBold }
	for key, value in props do
		merged[key] = value
	end
	return UI.label(merged)
end

-- Lista "material: tem/precisa" colorida
local function costLines(parent, cost, y)
	local data = State.data
	local ok = true
	if cost.gold and cost.gold > 0 then
		local has = data.gold >= cost.gold
		ok = ok and has
		text(parent, { Text = ("Ouro: %s / %s"):format(UI.formatNumber(data.gold), UI.formatNumber(cost.gold)), Position = UDim2.fromOffset(0, y), TextColor3 = if has then UI.Colors.Green else UI.Colors.Red, Parent = parent })
		y += 20
	end
	for id, amount in cost.materials or {} do
		local def = Items.Materials[id]
		local have = State.materialCount(id)
		ok = ok and have >= amount
		text(parent, { Text = ("%s: %d / %d"):format(def and def.name or id, have, amount), Position = UDim2.fromOffset(0, y), TextColor3 = if have >= amount then UI.Colors.Green else UI.Colors.Red, Parent = parent })
		y += 20
	end
	return ok, y
end

local function sideList(parent)
	return UI.new("ScrollingFrame", { Size = UDim2.new(0, 300, 1, 0), BackgroundColor3 = UI.Colors.PanelLight, BackgroundTransparency = 0.4, BorderSizePixel = 0, ScrollBarThickness = 5, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = parent }, { UI.corner(10), UI.padding(6), UI.list(5) })
end

local function detailPanel(parent)
	return UI.new("Frame", { Position = UDim2.fromOffset(312, 0), Size = UDim2.new(1, -312, 1, 0), BackgroundColor3 = UI.Colors.PanelLight, BackgroundTransparency = 0.3, Parent = parent }, { UI.corner(10), UI.padding(12) })
end

-- ===================== FORJA =====================
local forge = {}

-- assinatura do que a forja mostra (ouro, materiais, itens): evita recriar os ícones 3D à toa
local function forgeKey(data)
	local parts = { tostring(forge.win.tab), tostring(forge.recipe), tostring(forge.selected), tostring(data.gold), tostring(State.skillLevel("ferraria")) }
	local materialIds = {}
	for id in data.materials or {} do
		table.insert(materialIds, id)
	end
	table.sort(materialIds)
	for _, id in materialIds do
		table.insert(parts, id .. "=" .. tostring(data.materials[id]))
	end
	for _, item in data.inventory or {} do
		table.insert(parts, ("%s:%d:%s:%d"):format(item.uid, item.upgrade, item.rarity, #(item.perks or {})))
	end
	return table.concat(parts, "|")
end

local function renderForge()
	local data = State.data
	if not data then
		return
	end
	local key = forgeKey(data)
	if forge.lastKey == key then
		return
	end
	forge.lastKey = key
	UI.clear(forge.list)
	UI.clear(forge.detail)
	local ferraria = State.skillLevel("ferraria")
	forge.win.title.Text = ("FORJA DO BRUNO  •  Ferraria Nv. %d"):format(ferraria)
	if forge.win.tab == "Criar" then
		forge.list.Visible = true
		forge.grid.Visible = false
		for i, recipe in Recipes.Forge do
			local base = Items.Bases[recipe.result]
			local locked = ferraria < recipe.skill
			local button = UI.button({
				Text = ("%s%s"):format(base.name, if locked then ("  %d"):format(recipe.skill) else ""),
				Size = UDim2.new(1, -4, 0, 36),
				LayoutOrder = i,
				TextXAlignment = Enum.TextXAlignment.Left,
				BackgroundColor3 = if forge.recipe == i then UI.Colors.Accent elseif locked then UI.Colors.Dark else UI.Colors.Panel,
				Parent = forge.list,
			})
			-- miniatura 3D do item à esquerda do nome
			ItemIcon.new(button, recipe.result, "Comum", { Size = UDim2.fromOffset(30, 30), Position = UDim2.new(0, -4, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), glow = false, ZIndex = button.ZIndex + 1 })
			local padding = button:FindFirstChildOfClass("UIPadding")
			if padding then
				padding.PaddingLeft = UDim.new(0, 34)
			end
			button.MouseButton1Click:Connect(function()
				forge.recipe = i
				renderForge()
			end)
		end
		local recipe = forge.recipe and Recipes.Forge[forge.recipe]
		if not recipe then
			text(forge.detail, { Text = "Escolha uma receita. Itens forjados saem no seu nível, com raridade aleatória — quanto maior sua Ferraria, maior a chance de raridades altas.", Size = UDim2.new(1, 0, 0, 120), TextColor3 = UI.Colors.SubText, Parent = forge.detail })
			return
		end
		local base = Items.Bases[recipe.result]
		text(forge.detail, { Text = base.name, Size = UDim2.new(1, -110, 0, 26), TextSize = 22, Font = Enum.Font.GothamBlack, Parent = forge.detail })
		ItemIcon.new(forge.detail, recipe.result, "Raro", { Size = UDim2.fromOffset(100, 100), Position = UDim2.new(1, -4, 0, 0), AnchorPoint = Vector2.new(1, 0), spin = true })
		local kind = if base.slot ~= "weapon" then (Items.Slots[base.slot] or {}).name or "Equipamento" else (Items.WeaponTypes[base.weaponType] or {}).name or "Arma"
		text(forge.detail, { Text = ("%s  •  Poder base %d  •  Ferraria %d"):format(kind, base.power, recipe.skill), Position = UDim2.fromOffset(0, 30), TextColor3 = UI.Colors.SubText, Parent = forge.detail })
		local ok = costLines(forge.detail, { gold = recipe.gold, materials = recipe.materials }, 60)
		ok = ok and ferraria >= recipe.skill
		local button = UI.button({ Text = "FORJAR", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = if ok then Color3.fromRGB(220, 130, 40) else UI.Colors.Dark, Parent = forge.detail })
		button.MouseButton1Click:Connect(function()
			local result = State.request("forge", forge.recipe)
			if result and result.ok then
				Sounds.play("crit", 0.8, 0.6)
				Fx.shake(0.15, 0.3)
				Popups.loot(result.item)
				local rarity = Rarities.ById[result.item.rarity]
				if rarity and rarity.order < 4 then
					Popups.burst("FORJADO!", Color3.fromRGB(255, 170, 60), result.item.name)
				end
			end
		end)
	else
		forge.list.Visible = false
		forge.grid.Visible = true
		ItemGrid.render(forge.grid, data.inventory, forge.selected, function(uid)
			forge.selected = uid
			renderForge()
		end)
		local item = forge.selected and ItemGrid.find(data.inventory, forge.selected)
		if not item then
			text(forge.detail, { Text = "Escolha um item para aprimorar. Cada nível dá +12% de poder.", Size = UDim2.new(1, 0, 0, 60), TextColor3 = UI.Colors.SubText, Parent = forge.detail })
			return
		end
		local rarity = Rarities.ById[item.rarity]
		text(forge.detail, { Text = item.name, Size = UDim2.new(1, 0, 0, 26), TextSize = 20, Font = Enum.Font.GothamBlack, TextColor3 = rarity.color, Parent = forge.detail })
		if forge.win.tab == "Reforjar" then
			-- perks atuais e custo para sortear de novo
			local y = 32
			if #item.perks == 0 then
				text(forge.detail, { Text = "Este item não tem perks (Comum). Itens Incomuns ou melhores têm 1 a 3 perks.", Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, 40), TextColor3 = UI.Colors.SubText, Parent = forge.detail })
				return
			end
			for _, perkId in item.perks do
				local perk = Perks.List[perkId]
				if perk then
					text(forge.detail, { Text = ("%s: %s"):format(perk.name, perk.text), Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, 36), TextColor3 = if perk.major then UI.Colors.Gold else Color3.fromRGB(150, 220, 255), Parent = forge.detail })
					y += 38
				end
			end
			local ok = costLines(forge.detail, item.reforgeCost, y + 6)
			local button = UI.button({ Text = "REFORJAR PERKS", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = if ok then Color3.fromRGB(80, 140, 220) else UI.Colors.Dark, Parent = forge.detail })
			button.MouseButton1Click:Connect(function()
				local result = State.request("reforge", item.uid)
				if result and result.ok then
					Sounds.play("ping", 1.6, 0.6)
					Popups.burst("PERKS NOVOS!", Color3.fromRGB(120, 200, 255), result.item.name)
				end
			end)
			return
		end
		if item.upgrade >= item.maxUpgrade then
			text(forge.detail, { Text = "Nível máximo de aprimoramento!", Position = UDim2.fromOffset(0, 34), TextColor3 = UI.Colors.Gold, Parent = forge.detail })
			return
		end
		local nextPower = math.floor(item.power * (1 + 0.12 * (item.upgrade + 1)) / (1 + 0.12 * item.upgrade))
		text(forge.detail, { Text = ("+%d → +%d   •   %s %d → %d"):format(item.upgrade, item.upgrade + 1, UI.statWord(item), item.power, nextPower), Position = UDim2.fromOffset(0, 32), TextColor3 = UI.Colors.Green, Parent = forge.detail })
		local ok = costLines(forge.detail, { gold = item.upgradeGold, materials = item.upgradeMaterials }, 60)
		local button = UI.button({ Text = "▲ APRIMORAR", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = if ok then Color3.fromRGB(220, 150, 30) else UI.Colors.Dark, Parent = forge.detail })
		button.MouseButton1Click:Connect(function()
			local result = State.request("upgrade", item.uid)
			if result and result.ok then
				Sounds.play("ping", 1.2 + result.upgrade * 0.08, 0.6)
				Popups.burst(("APRIMORADO +%d!"):format(result.upgrade), UI.Colors.Gold)
				Fx.shake(0.15, 0.3)
			end
		end)
	end
end

-- ===================== ENCANTADOR =====================
local enchant = {}

local function renderEnchant()
	local data = State.data
	if not data then
		return
	end
	UI.clear(enchant.detail)
	local level = State.skillLevel("encantamento")
	enchant.win.title.Text = ("TORRE DO ELRIC  •  Encantamento Nv. %d"):format(level)
	local disassemble = enchant.win.tab == "Desmontar"
	ItemGrid.render(enchant.grid, data.inventory, enchant.selected, function(uid)
		enchant.selected = uid
		renderEnchant()
	end, if disassemble then function(item)
		return not item.equipped
	end else nil)
	local item = enchant.selected and ItemGrid.find(data.inventory, enchant.selected)
	if not item then
		text(enchant.detail, {
			Text = if disassemble then "Desmonte itens que você não usa para conseguir Essência Mágica." else "Escolha um item para encantar. O encantamento atual é substituído por um novo aleatório.",
			Size = UDim2.new(1, 0, 0, 80),
			TextColor3 = UI.Colors.SubText,
			Parent = enchant.detail,
		})
		return
	end
	local rarity = Rarities.ById[item.rarity]
	text(enchant.detail, { Text = item.name, Size = UDim2.new(1, 0, 0, 26), TextSize = 20, Font = Enum.Font.GothamBlack, TextColor3 = rarity.color, Parent = enchant.detail })
	if disassemble then
		if item.equipped then
			text(enchant.detail, { Text = "Desequipe antes de desmontar.", Position = UDim2.fromOffset(0, 34), TextColor3 = UI.Colors.Red, Parent = enchant.detail })
			return
		end
		text(enchant.detail, { Text = ("Rende %d Essência Mágica"):format(item.disassemble), Position = UDim2.fromOffset(0, 34), TextColor3 = Color3.fromRGB(200, 150, 255), Parent = enchant.detail })
		local button = UI.button({ Text = "DESMONTAR", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = Color3.fromRGB(140, 70, 160), Parent = enchant.detail })
		button.MouseButton1Click:Connect(function()
			if enchant.confirm ~= item.uid then
				enchant.confirm = item.uid
				button.Text = "Clique de novo para confirmar"
				return
			end
			enchant.confirm = nil
			local result = State.request("disassemble", item.uid)
			if result and result.ok then
				enchant.selected = nil
				Sounds.play("ping", 1.8, 0.5)
			end
		end)
		return
	end
	text(enchant.detail, { Text = "Atual: " .. (item.enchantText or "nenhum"), Position = UDim2.fromOffset(0, 32), TextColor3 = Color3.fromRGB(200, 150, 255), Parent = enchant.detail })
	local maxTier = math.min(5, 2 + math.floor(level / 6))
	local possible = {}
	for _, id in Items.EnchantsBySlot[Items.enchantSlot(item.slot)] or {} do
		table.insert(possible, Items.Enchants[id].name)
	end
	text(enchant.detail, { Text = ("Possíveis: %s\nTier máximo agora: %s (sobe com Encantamento)"):format(table.concat(possible, ", "), Items.roman(maxTier)), Position = UDim2.fromOffset(0, 54), Size = UDim2.new(1, 0, 0, 56), TextColor3 = UI.Colors.SubText, Font = Enum.Font.Gotham, Parent = enchant.detail })
	local ok = costLines(enchant.detail, item.enchantCost, 116)
	local button = UI.button({ Text = "ENCANTAR", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = if ok then Color3.fromRGB(150, 80, 230) else UI.Colors.Dark, Parent = enchant.detail })
	button.MouseButton1Click:Connect(function()
		local result = State.request("enchant", item.uid)
		if result and result.ok then
			Sounds.play("ping", 1.5, 0.6)
			Fx.shake(0.15, 0.25)
			Popups.burst("ENCANTADO!", Color3.fromRGB(200, 150, 255), result.item.enchantText)
		end
	end)
end

-- ===================== ALQUIMIA =====================
local alchemy = {}

local function renderAlchemy()
	local data = State.data
	if not data then
		return
	end
	UI.clear(alchemy.list)
	local level = State.skillLevel("alquimia")
	alchemy.win.title.Text = ("CALDEIRÃO DA MIRA  •  Alquimia Nv. %d"):format(level)
	for i, recipe in Recipes.Alchemy do
		local def = Items.Consumables[recipe.result]
		local row = UI.new("Frame", { Size = UDim2.new(1, -8, 0, 92), BackgroundColor3 = UI.Colors.PanelLight, BackgroundTransparency = 0.3, LayoutOrder = i, Parent = alchemy.list }, { UI.corner(10) })
		UI.icon(def.icon, { Position = UDim2.fromOffset(10, 18), Size = UDim2.fromOffset(52, 52), Parent = row })
		text(row, { Text = ("%s  x%d   (Alquimia %d)"):format(def.name, recipe.count, recipe.skill), Position = UDim2.fromOffset(72, 8), TextSize = 17, Font = Enum.Font.GothamBlack, TextColor3 = if level >= recipe.skill then UI.Colors.Text else UI.Colors.Red, Parent = row })
		local holder = UI.new("Frame", { Position = UDim2.fromOffset(72, 30), Size = UDim2.new(1, -220, 0, 60), BackgroundTransparency = 1, Parent = row })
		local ok = costLines(holder, { gold = recipe.gold, materials = recipe.materials }, 0)
		ok = ok and level >= recipe.skill
		local button = UI.button({ Text = "PREPARAR", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(130, 40), BackgroundColor3 = if ok then UI.Colors.Green else UI.Colors.Dark, Parent = row })
		button.MouseButton1Click:Connect(function()
			local result = State.request("alchemy", i)
			if result and result.ok then
				Sounds.play("ping", 1.4, 0.5)
				Popups.burst(("+%d %s"):format(result.count, def.name), Color3.fromRGB(120, 255, 140))
			end
		end)
	end
end

-- ===================== LOJA =====================
local shop = {}

local function renderShop()
	local data = State.data
	if not data then
		return
	end
	UI.clear(shop.list)
	shop.win.title.Text = ("BARRACA DO OTTO  •  %s ouro"):format(UI.formatNumber(data.gold))
	if shop.win.tab == "Comprar" then
		for i, id in Recipes.Shop do
			local def = Items.Consumables[id]
			local row = UI.new("Frame", { Size = UDim2.new(1, -8, 0, 54), BackgroundColor3 = UI.Colors.PanelLight, BackgroundTransparency = 0.3, LayoutOrder = i, Parent = shop.list }, { UI.corner(10) })
			UI.icon(def.icon, { Position = UDim2.fromOffset(10, 8), Size = UDim2.fromOffset(38, 38), Parent = row })
			text(row, { Text = ("%s  •  %d ouro  (você tem %d)"):format(def.name, def.price, data.consumables[id] or 0), Position = UDim2.fromOffset(56, 17), Size = UDim2.new(1, -260, 0, 20), Parent = row })
			for j, amount in { 1, 5 } do
				local button = UI.button({ Text = "x" .. amount, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10 - (2 - j) * 92, 0.5, 0), Size = UDim2.fromOffset(84, 36), BackgroundColor3 = UI.Colors.Green, Parent = row })
				button.MouseButton1Click:Connect(function()
					local result = State.request("buy", id, amount)
					if result and result.ok then
						Sounds.play("ping", 1.6, 0.4)
					end
				end)
			end
		end
		local chest = UI.button({ Text = "Ver Baús do Hunter", Size = UDim2.new(1, -8, 0, 44), LayoutOrder = 99, BackgroundColor3 = Color3.fromRGB(220, 150, 40), Parent = shop.list })
		chest.MouseButton1Click:Connect(function()
			Services.openChest()
		end)
	else
		local entries = {}
		for id, count in data.materials do
			if Items.Materials[id] and count > 0 then
				table.insert(entries, { id = id, count = count, def = Items.Materials[id] })
			end
		end
		table.sort(entries, function(a, b)
			return a.def.name < b.def.name
		end)
		if #entries == 0 then
			text(shop.list, { Text = "Você não tem materiais para vender.", TextColor3 = UI.Colors.SubText, Parent = shop.list })
		end
		for i, entry in entries do
			local row = UI.new("Frame", { Size = UDim2.new(1, -8, 0, 46), BackgroundColor3 = UI.Colors.PanelLight, BackgroundTransparency = 0.3, LayoutOrder = i, Parent = shop.list }, { UI.corner(10) })
			text(row, { Text = ("%s  x%d  •  %d ouro cada"):format(entry.def.name, entry.count, entry.def.sell), Position = UDim2.fromOffset(12, 13), Size = UDim2.new(1, -230, 0, 20), Parent = row })
			for j, amount in { 1, entry.count } do
				local button = UI.button({ Text = if j == 1 then "Vender 1" else "Vender tudo", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10 - (2 - j) * 104, 0.5, 0), Size = UDim2.fromOffset(98, 32), BackgroundColor3 = Color3.fromRGB(150, 110, 40), Parent = row })
				button.MouseButton1Click:Connect(function()
					local result = State.request("sellMaterial", entry.id, amount)
					if result and result.ok then
						Sounds.play("ping", 0.9, 0.4)
					end
				end)
			end
		end
	end
end

-- ===================== ESTÁBULO =====================
local stable = {}

local function renderStable()
	local data = State.data
	if not data then
		return
	end
	UI.clear(stable.body)
	if data.mount then
		text(stable.body, { Text = "Você já tem um cavalo!\n\nAperte H para montar e desmontar. Montado você corre bem mais rápido, mas é derrubado se tomar dano ou atacar.", Size = UDim2.new(1, 0, 0, 140), TextSize = 17, Parent = stable.body })
		return
	end
	text(stable.body, { Text = ("Um cavalo fiel deixa você %d%% mais rápido.\n\nPreço: %d ouro (ou complete a missão \"Uma Montaria Fiel\")."):format(math.floor((Config.MountSpeed / Config.WalkSpeed - 1) * 100), Config.MountPrice), Size = UDim2.new(1, 0, 0, 120), TextSize = 17, Parent = stable.body })
	local button = UI.button({ Text = ("COMPRAR CAVALO  %d ouro"):format(Config.MountPrice), AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 46), BackgroundColor3 = if data.gold >= Config.MountPrice then UI.Colors.Green else UI.Colors.Dark, Parent = stable.body })
	button.MouseButton1Click:Connect(function()
		local result = State.request("buyMount")
		if result and result.ok then
			Popups.burst("NOVO CAVALO!", Color3.fromRGB(230, 190, 120), "Aperte H para montar")
		end
	end)
end

function Services.init(screen)
	forge.win = Window.create(screen, { icon = "anvil-impact", name = "Forja", title = "FORJA", width = 760, height = 500, tabs = { "Criar", "Aprimorar", "Reforjar" }, accent = Color3.fromRGB(255, 150, 60) })
	forge.list = sideList(forge.win.content)
	forge.grid = ItemGrid.create(forge.win.content, { Position = UDim2.fromOffset(0, 0), Size = UDim2.new(0, 300, 1, 0), cell = 66 })
	forge.detail = detailPanel(forge.win.content)
	forge.win.onTab = renderForge
	forge.win.onOpen = renderForge

	enchant.win = Window.create(screen, { icon = "sparkles", name = "Encantador", title = "ENCANTADOR", width = 760, height = 500, tabs = { "Encantar", "Desmontar" }, accent = Color3.fromRGB(190, 130, 255) })
	enchant.grid = ItemGrid.create(enchant.win.content, { Position = UDim2.fromOffset(0, 0), Size = UDim2.new(0, 300, 1, 0), cell = 66 })
	enchant.detail = detailPanel(enchant.win.content)
	enchant.win.onTab = renderEnchant
	enchant.win.onOpen = renderEnchant

	alchemy.win = Window.create(screen, { icon = "bubbling-flask", name = "Alquimia", title = "ALQUIMIA", width = 640, height = 480, accent = Color3.fromRGB(120, 255, 150) })
	alchemy.list = UI.new("ScrollingFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 5, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = alchemy.win.content }, { UI.list(8) })
	alchemy.win.onOpen = renderAlchemy

	shop.win = Window.create(screen, { icon = "shopping-cart", name = "Loja", title = "LOJA", width = 640, height = 480, tabs = { "Comprar", "Vender" }, accent = UI.Colors.Gold })
	shop.list = UI.new("ScrollingFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 5, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = shop.win.content }, { UI.list(8) })
	shop.win.onTab = renderShop
	shop.win.onOpen = renderShop

	stable.win = Window.create(screen, { icon = "horse-head", name = "Estabulo", title = "ESTÁBULO DO PEDRO", width = 460, height = 320, accent = Color3.fromRGB(230, 190, 120) })
	stable.body = UI.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = stable.win.content })
	stable.win.onOpen = renderStable

	State.Changed:Connect(function()
		if forge.win:isOpen() then
			renderForge()
		elseif enchant.win:isOpen() then
			renderEnchant()
		elseif alchemy.win:isOpen() then
			renderAlchemy()
		elseif shop.win:isOpen() then
			renderShop()
		elseif stable.win:isOpen() then
			renderStable()
		end
	end)
end

function Services.open(service)
	if service == "forge" then
		forge.win:open()
	elseif service == "enchant" then
		enchant.win:open()
	elseif service == "alchemy" then
		alchemy.win:open()
	elseif service == "shop" then
		shop.win:open()
	elseif service == "stable" then
		stable.win:open()
	end
end

return Services
