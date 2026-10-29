-- Painel de administrador (só aparece com o atributo "Admin", que o servidor dá): jogadores do servidor
-- (ir até, trazer, dar ouro/XP, expulsar, banir), balanceamento ao vivo (RemoteConfig, vale em todos os
-- servidores), aviso global, eventos, "Para mim" (o admin enche o próprio personagem), "Itens" (qualquer item com os perks escolhidos) e o registro das ações. O servidor confere tudo de novo.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local RemoteConfig = require(Shared.RemoteConfig)
local Items = require(Shared.Items)
local Rarities = require(Shared.Rarities)
local Perks = require(Shared.Perks)

local UI = require(script.Parent.UI)
local State = require(script.Parent.State)
local Window = require(script.Parent.Window)
local Popups = require(script.Parent.Popups)
local ItemIcon = require(script.Parent.ItemIcon)

local AdminWindow = {}

local win, openButton
local pages = {}
local snapshot = nil -- último "state" do servidor
local pending = {} -- mudanças de configuração ainda não salvas
local targetBox = nil -- campo "Jogador" da aba Jogadores

local ACCENT = Color3.fromRGB(255, 120, 90)

local function text(parent, props)
	local merged = { TextScaled = false, TextSize = 14, TextWrapped = true, Font = Enum.Font.GothamBold }
	for k, v in props do
		merged[k] = v
	end
	merged.Parent = parent
	return UI.label(merged)
end

local function textBox(parent, props)
	local merged = { Text = "", ClearTextOnFocus = false, BackgroundColor3 = UI.Colors.PanelLight, TextColor3 = UI.Colors.Text, PlaceholderColor3 = UI.Colors.SubText, Font = Enum.Font.Gotham, TextSize = 14, Parent = parent }
	for k, v in props do
		merged[k] = v
	end
	return UI.new("TextBox", merged, { UI.corner(6), UI.padding(6) })
end

local function reply(result)
	-- erros o State.request já mostra
	if result and result.ok and result.msg then
		Popups.message(result.msg, UI.Colors.Green)
	end
end

local function command(sub, args)
	local result = State.request("admin", sub, args)
	reply(result)
	return result
end

local render -- declarada abaixo

local function refresh()
	local result = State.request("admin", "state")
	if result and result.ok then
		snapshot = result
		render()
	end
end

-- ===================== JOGADORES =====================
local function renderPlayers(page)
	local scroll = UI.new("ScrollingFrame", { Size = UDim2.new(1, 0, 1, -110), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = page }, { UI.list(4) })
	for i, entry in snapshot.players do
		local row = UI.new("Frame", { Size = UDim2.new(1, -8, 0, 36), BackgroundColor3 = UI.Colors.PanelLight, LayoutOrder = i, Parent = scroll }, { UI.corner(6) })
		text(row, { Text = ("%s (@%s)  •  Nv. %d %s  •  %s ouro"):format(entry.display, entry.name, entry.level, entry.class, UI.formatNumber(entry.gold)), Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -330, 1, 0), TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd })
		local buttons = UI.new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Size = UDim2.fromOffset(316, 28), BackgroundTransparency = 1, Parent = row }, { UI.list(4, true) })
		for order, action in { { "Ir", "visit" }, { "Trazer", "bring" }, { "Expulsar", "kick" }, { "Banir", "ban" } } do
			local button = UI.button({ Text = action[1], Size = UDim2.fromOffset(75, 28), LayoutOrder = order, BackgroundColor3 = if action[2] == "ban" or action[2] == "kick" then Color3.fromRGB(150, 50, 50) else UI.Colors.Dark, Parent = buttons })
			button.MouseButton1Click:Connect(function()
				if action[2] == "kick" or action[2] == "ban" then
					targetBox.Text = entry.name
					Popups.message("Preencha o motivo embaixo e confirme.", UI.Colors.Gold)
				else
					command(action[2], { target = entry.name })
				end
			end)
		end
	end
	-- ações com motivo / valores
	local form = UI.new("Frame", { Position = UDim2.new(0, 0, 1, -104), Size = UDim2.new(1, 0, 0, 104), BackgroundTransparency = 1, Parent = page })
	targetBox = textBox(form, { PlaceholderText = "Jogador (nome ou UserId)", Size = UDim2.new(0.3, -4, 0, 32) })
	local reason = textBox(form, { PlaceholderText = "Motivo", Position = UDim2.new(0.3, 4, 0, 0), Size = UDim2.new(0.5, -8, 0, 32) })
	local hours = textBox(form, { PlaceholderText = "Horas (0 = sempre)", Position = UDim2.new(0.8, 4, 0, 0), Size = UDim2.new(0.2, -4, 0, 32) })
	local gold = textBox(form, { PlaceholderText = "Ouro", Position = UDim2.fromOffset(0, 38), Size = UDim2.new(0.15, -4, 0, 32) })
	local xp = textBox(form, { PlaceholderText = "XP", Position = UDim2.new(0.15, 4, 0, 38), Size = UDim2.new(0.15, -8, 0, 32) })
	local actions = UI.new("Frame", { Position = UDim2.new(0.3, 4, 0, 38), Size = UDim2.new(0.7, -4, 0, 32), BackgroundTransparency = 1, Parent = form }, { UI.list(6, true) })
	local function args()
		return { target = targetBox.Text, reason = reason.Text, hours = tonumber(hours.Text) or 0, gold = tonumber(gold.Text) or 0, xp = tonumber(xp.Text) or 0 }
	end
	for order, action in { { "Dar ouro/XP", "give", UI.Colors.Green }, { "Expulsar", "kick", Color3.fromRGB(170, 80, 50) }, { "Banir", "ban", Color3.fromRGB(170, 40, 40) }, { "Desbanir", "unban", UI.Colors.Dark } } do
		local button = UI.button({ Text = action[1], Size = UDim2.fromOffset(120, 32), LayoutOrder = order, BackgroundColor3 = action[3], Parent = actions })
		button.MouseButton1Click:Connect(function()
			command(action[2], args())
			task.delay(0.5, refresh)
		end)
	end
	text(form, { Text = ("Servidor %s  •  aberto há %s  •  %d jogador(es)"):format(string.sub(snapshot.jobId ~= "" and snapshot.jobId or "Studio", 1, 8), UI.formatTime(snapshot.uptime), #snapshot.players), Position = UDim2.fromOffset(0, 80), Size = UDim2.new(1, 0, 0, 18), TextSize = 12, TextColor3 = UI.Colors.SubText })
end

-- ===================== BALANCEAMENTO =====================
local function renderBalance(page)
	local scroll = UI.new("ScrollingFrame", { Size = UDim2.new(1, 0, 1, -52), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = page }, { UI.list(6) })
	for i, field in RemoteConfig.Fields do
		local current = if pending[field.key] ~= nil then pending[field.key] else snapshot.config[field.key]
		local changed = pending[field.key] ~= nil and pending[field.key] ~= snapshot.config[field.key]
		local row = UI.new("Frame", { Size = UDim2.new(1, -8, 0, 52), BackgroundColor3 = UI.Colors.PanelLight, LayoutOrder = i, Parent = scroll }, { UI.corner(6), UI.stroke(if changed then UI.Colors.Gold else UI.Colors.Stroke, 1, 0.4) })
		text(row, { Text = field.name, Position = UDim2.fromOffset(10, 4), Size = UDim2.new(0.5, -10, 0, 20), TextColor3 = if changed then UI.Colors.Gold else UI.Colors.Text })
		text(row, { Text = field.text, Position = UDim2.fromOffset(10, 24), Size = UDim2.new(0.6, -10, 0, 24), TextSize = 12, TextColor3 = UI.Colors.SubText })
		if field.kind == "text" then
			local box = textBox(row, { Text = current or "", PlaceholderText = "(nenhuma)", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.new(0.38, 0, 0, 34) })
			box.FocusLost:Connect(function()
				pending[field.key] = box.Text
				render()
			end)
		else
			local holder = UI.new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(190, 34), BackgroundTransparency = 1, Parent = row })
			local minus = UI.button({ Text = "-", Size = UDim2.fromOffset(40, 34), BackgroundColor3 = UI.Colors.Dark, Parent = holder })
			local box = textBox(holder, { Text = tostring(current), Position = UDim2.fromOffset(46, 0), Size = UDim2.fromOffset(98, 34), TextXAlignment = Enum.TextXAlignment.Center })
			local plus = UI.button({ Text = "+", Position = UDim2.fromOffset(150, 0), Size = UDim2.fromOffset(40, 34), BackgroundColor3 = UI.Colors.Dark, Parent = holder })
			local function set(value)
				pending[field.key] = RemoteConfig.validate(field.key, value) or current
				render()
			end
			minus.MouseButton1Click:Connect(function()
				set(current - field.step)
			end)
			plus.MouseButton1Click:Connect(function()
				set(current + field.step)
			end)
			box.FocusLost:Connect(function()
				set(tonumber(box.Text) or current)
			end)
		end
	end
	local save = UI.button({ Text = "Salvar em todos os servidores", Position = UDim2.new(0, 0, 1, -44), Size = UDim2.new(0.6, -4, 0, 40), BackgroundColor3 = UI.Colors.Green, Parent = page })
	save.MouseButton1Click:Connect(function()
		local result = command("setConfig", pending)
		if result and result.ok then
			pending = {}
			refresh()
		end
	end)
	local reset = UI.button({ Text = "Descartar / padrão", Position = UDim2.new(0.6, 4, 1, -44), Size = UDim2.new(0.4, -4, 0, 40), BackgroundColor3 = UI.Colors.Dark, Parent = page })
	reset.MouseButton1Click:Connect(function()
		if next(pending) ~= nil then
			pending = {}
		else
			pending = RemoteConfig.defaults()
		end
		render()
	end)
end

-- ===================== MUNDO =====================
local function renderWorld(page)
	text(page, { Text = "AVISO GLOBAL (todos os servidores; passa pelo filtro do Roblox)", Size = UDim2.new(1, 0, 0, 18), TextColor3 = ACCENT, Font = Enum.Font.GothamBlack })
	local box = textBox(page, { PlaceholderText = "Ex.: Servidor reinicia em 5 minutos!", Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, -130, 0, 38) })
	local send = UI.button({ Text = "Enviar", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 24), Size = UDim2.fromOffset(120, 38), BackgroundColor3 = ACCENT, Parent = page })
	send.MouseButton1Click:Connect(function()
		local result = command("announce", box.Text)
		if result and result.ok then
			box.Text = ""
		end
	end)
	text(page, { Text = "EVENTOS (só neste servidor)", Position = UDim2.fromOffset(0, 80), Size = UDim2.new(1, 0, 0, 18), TextColor3 = ACCENT, Font = Enum.Font.GothamBlack })
	local row = UI.new("Frame", { Position = UDim2.fromOffset(0, 104), Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, Parent = page }, { UI.list(8, true) })
	for order, action in { { "Chefe de mundo", "worldboss" }, { "Invasão", "invasion" }, { "Próximo evento sazonal", "event" } } do
		local button = UI.button({ Text = action[1], Size = UDim2.fromOffset(200, 40), LayoutOrder = order, BackgroundColor3 = UI.Colors.Dark, Parent = row })
		button.MouseButton1Click:Connect(function()
			command(action[2])
		end)
	end
end

-- ===================== PARA MIM =====================
-- O admin enche o próprio personagem; dá para clicar de novo sempre que gastar (repõe até o máximo)
local function renderSelf(page)
	text(page, { Text = "PARA MIM (só no seu personagem; fica no registro)", Size = UDim2.new(1, 0, 0, 18), TextColor3 = ACCENT, Font = Enum.Font.GothamBlack })
	text(page, { Text = "Cada botão repõe até o máximo: clique de novo quando gastar.", Position = UDim2.fromOffset(0, 22), Size = UDim2.new(1, 0, 0, 16), TextSize = 13, TextColor3 = UI.Colors.SubText })
	local grid = UI.new("Frame", { Position = UDim2.fromOffset(0, 50), Size = UDim2.new(1, 0, 1, -50), BackgroundTransparency = 1, Parent = page }, {
		UI.new("UIGridLayout", { CellSize = UDim2.fromOffset(260, 64), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	for order, action in {
		{ "Tudo no máximo", "all", "Nível, ouro, materiais e perícias", ACCENT },
		{ "Nível máximo", "xp", "XP até o nível " .. Config.MaxLevel, UI.Colors.Dark },
		{ "Ouro infinito", "gold", "Enche até 99.999.999 de ouro", UI.Colors.Dark },
		{ "Materiais infinitos", "materials", "999 de cada material, 99 de cada poção", UI.Colors.Dark },
		{ "Perícias máximas", "skills", "Maestrias e profissões no máximo", UI.Colors.Dark },
	} do
		local button = UI.button({ Text = "", LayoutOrder = order, BackgroundColor3 = action[4], Parent = grid })
		text(button, { Text = action[1], Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 24), Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left })
		text(button, { Text = action[3], Position = UDim2.fromOffset(12, 34), Size = UDim2.new(1, -24, 0, 18), TextSize = 13, TextColor3 = UI.Colors.SubText, TextXAlignment = Enum.TextXAlignment.Left })
		button.MouseButton1Click:Connect(function()
			command("self", { kind = action[2] })
		end)
	end
end

-- ===================== ITENS =====================
-- Item sob medida: escolhe a base (busca + filtro por espaço), raridade, nível, aprimoramento,
-- encantamento e os perks (ou sorteados). O servidor (handlers.item) valida tudo de novo.
local MAX_PERKS = 6
local form = { search = "", slot = nil, base = nil, rarity = "Lendario", level = Config.MaxLevel, upgrade = Items.MaxUpgrade, perks = {}, randomPerks = false, allPerks = false, enchant = nil, enchantTier = 5, target = "" }

local function sortedBases()
	local list = {}
	for id, base in Items.Bases do
		if (not form.slot or base.slot == form.slot) and (form.search == "" or string.find(string.lower(base.name), string.lower(form.search), 1, true)) then
			table.insert(list, id)
		end
	end
	table.sort(list, function(a, b)
		local x, y = Items.Bases[a], Items.Bases[b]
		local sx, sy = Items.Slots[x.slot].order, Items.Slots[y.slot].order
		if sx ~= sy then
			return sx < sy
		end
		if (x.tier or 0) ~= (y.tier or 0) then
			return (x.tier or 0) < (y.tier or 0)
		end
		return x.name < y.name
	end)
	return list
end

local function baseTag(base)
	return if base.exotic then "Exótico" elseif base.unique then "Único" elseif base.raid then "Raide" elseif base.dungeon then "Masmorra" elseif base.field then "Campo" else "T" .. tostring(base.tier or 0)
end

local function selectBase(id)
	local old = form.base and Items.Bases[form.base]
	local base = Items.Bases[id]
	form.base = id
	if base.exotic then
		form.rarity = "Exotico"
	elseif base.unique then
		form.rarity = "Unico"
	elseif form.rarity == "Exotico" or form.rarity == "Unico" then
		form.rarity = "Lendario"
	end
	if not old or Perks.poolForSlot(old.slot) ~= Perks.poolForSlot(base.slot) or old.signature or base.signature then
		form.perks = {}
	end
	if base.signature and not table.find(form.perks, base.signature) then
		table.insert(form.perks, 1, base.signature)
	end
	if not old or Items.enchantSlot(old.slot) ~= Items.enchantSlot(base.slot) then
		form.enchant = nil
	end
end

local function numberBox(parent, label, value, position, onSet)
	text(parent, { Text = label, Position = position, Size = UDim2.fromOffset(120, 16), TextSize = 12, TextColor3 = UI.Colors.SubText, TextXAlignment = Enum.TextXAlignment.Left })
	local box = textBox(parent, { Text = tostring(value), Position = position + UDim2.fromOffset(0, 17), Size = UDim2.fromOffset(120, 28) })
	box.FocusLost:Connect(function()
		onSet(tonumber(box.Text))
		render()
	end)
	return box
end

local function renderItems(page)
	-- coluna 1: busca, filtro por espaço e lista das bases
	local search = textBox(page, { Text = form.search, PlaceholderText = "Buscar item (Enter)", Size = UDim2.fromOffset(290, 30) })
	search.FocusLost:Connect(function()
		form.search = search.Text
		render()
	end)
	local filters = UI.new("Frame", { Position = UDim2.fromOffset(0, 36), Size = UDim2.fromOffset(290, 50), BackgroundTransparency = 1, Parent = page }, {
		UI.new("UIGridLayout", { CellSize = UDim2.fromOffset(68, 22), CellPadding = UDim2.fromOffset(6, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local slotOptions = { { false, "Todos" } }
	for _, slot in Items.SlotOrder do
		table.insert(slotOptions, { slot, Items.Slots[slot].name })
	end
	for order, option in slotOptions do
		local value = option[1] or nil
		local button = UI.button({ Text = option[2], TextSize = 12, LayoutOrder = order, BackgroundColor3 = if form.slot == value then ACCENT else UI.Colors.Dark, Parent = filters })
		button.MouseButton1Click:Connect(function()
			form.slot = value
			render()
		end)
	end
	local list = UI.new("ScrollingFrame", { Position = UDim2.fromOffset(0, 92), Size = UDim2.new(0, 290, 1, -92), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = page }, { UI.list(3) })
	for order, id in sortedBases() do
		local base = Items.Bases[id]
		local button = UI.button({ Text = ("%s  •  %s  •  %s"):format(base.name, Items.Slots[base.slot].name, baseTag(base)), TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -10, 0, 24), LayoutOrder = order, BackgroundColor3 = if form.base == id then ACCENT else UI.Colors.PanelLight, Parent = list })
		button.MouseButton1Click:Connect(function()
			selectBase(id)
			render()
		end)
	end

	-- coluna 2: raridade, números, encantamento, jogador, prévia e botão de criar
	local mid = UI.new("Frame", { Position = UDim2.fromOffset(302, 0), Size = UDim2.new(0, 254, 1, 0), BackgroundTransparency = 1, Parent = page })
	text(mid, { Text = "RARIDADE", Size = UDim2.new(1, 0, 0, 16), TextSize = 12, TextColor3 = ACCENT, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left })
	local rarities = UI.new("Frame", { Position = UDim2.fromOffset(0, 18), Size = UDim2.fromOffset(254, 84), BackgroundTransparency = 1, Parent = mid }, {
		UI.new("UIGridLayout", { CellSize = UDim2.fromOffset(80, 24), CellPadding = UDim2.fromOffset(7, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	for order, rarity in Rarities.List do
		local chosen = form.rarity == rarity.id
		local button = UI.button({ Text = rarity.name, TextSize = 12, LayoutOrder = order, TextColor3 = if chosen then Color3.new(0, 0, 0) else rarity.color, BackgroundColor3 = if chosen then rarity.color else UI.Colors.Dark, Parent = rarities })
		button.MouseButton1Click:Connect(function()
			form.rarity = rarity.id
			render()
		end)
	end
	numberBox(mid, "Nível (1-" .. Config.MaxLevel .. ")", form.level, UDim2.fromOffset(0, 108), function(value)
		form.level = math.clamp(math.floor(value or form.level), 1, Config.MaxLevel)
	end)
	numberBox(mid, "Aprimoramento (0-" .. Items.MaxUpgrade .. ")", form.upgrade, UDim2.fromOffset(132, 108), function(value)
		form.upgrade = math.clamp(math.floor(value or form.upgrade), 0, Items.MaxUpgrade)
	end)
	local base = form.base and Items.Bases[form.base]
	-- encantamento: cada clique passa para o próximo do tipo do item (depois do último volta a nenhum)
	text(mid, { Text = "Encantamento", Position = UDim2.fromOffset(0, 158), Size = UDim2.fromOffset(120, 16), TextSize = 12, TextColor3 = UI.Colors.SubText, TextXAlignment = Enum.TextXAlignment.Left })
	local enchantDef = form.enchant and Items.Enchants[form.enchant]
	local enchantButton = UI.button({ Text = if enchantDef then enchantDef.name else "Nenhum", TextSize = 13, Position = UDim2.fromOffset(0, 175), Size = UDim2.fromOffset(120, 28), BackgroundColor3 = if enchantDef then UI.Colors.Accent else UI.Colors.Dark, Parent = mid })
	enchantButton.MouseButton1Click:Connect(function()
		if not base then
			return
		end
		local options = Items.EnchantsBySlot[Items.enchantSlot(base.slot)]
		local index = form.enchant and table.find(options, form.enchant) or 0
		form.enchant = options[index + 1]
		render()
	end)
	numberBox(mid, "Tier do encanto (1-5)", form.enchantTier, UDim2.fromOffset(132, 158), function(value)
		form.enchantTier = math.clamp(math.floor(value or form.enchantTier), 1, 5)
	end)
	text(mid, { Text = "Jogador (vazio = você)", Position = UDim2.fromOffset(0, 208), Size = UDim2.new(1, 0, 0, 16), TextSize = 12, TextColor3 = UI.Colors.SubText, TextXAlignment = Enum.TextXAlignment.Left })
	local targetInput = textBox(mid, { Text = form.target, PlaceholderText = "nome do jogador", Position = UDim2.fromOffset(0, 225), Size = UDim2.new(1, 0, 0, 28) })
	targetInput.FocusLost:Connect(function()
		form.target = targetInput.Text
	end)
	local preview = UI.new("Frame", { Position = UDim2.fromOffset(0, 262), Size = UDim2.new(1, 0, 0, 120), BackgroundColor3 = UI.Colors.PanelLight, BackgroundTransparency = 0.3, Parent = mid }, { UI.corner(8) })
	local rarity = Rarities.ById[form.rarity]
	if base then
		ItemIcon.new(preview, form.base, form.rarity, { Size = UDim2.fromOffset(84, 84), Position = UDim2.fromOffset(8, 18), spin = true })
		text(preview, { Text = base.name, Position = UDim2.fromOffset(100, 10), Size = UDim2.new(1, -108, 0, 40), TextColor3 = rarity.color, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top })
		text(preview, {
			Text = ("%s • nível %d • +%d\n%s\n%s"):format(rarity.name, form.level, form.upgrade, if form.randomPerks then "perks sorteados" else ("%d perk(s)"):format(#form.perks), if enchantDef then ("%s %s"):format(enchantDef.name, Items.roman(form.enchantTier)) else "sem encanto"),
			Position = UDim2.fromOffset(100, 52),
			Size = UDim2.new(1, -108, 0, 60),
			TextSize = 12,
			TextColor3 = UI.Colors.SubText,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
		})
	else
		text(preview, { Text = "Escolha um item na lista.", Size = UDim2.fromScale(1, 1), TextColor3 = UI.Colors.SubText, TextXAlignment = Enum.TextXAlignment.Center })
	end
	local create = UI.button({ Text = "CRIAR ITEM", Font = Enum.Font.GothamBlack, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = if base then UI.Colors.Green else UI.Colors.Dark, Parent = mid })
	create.MouseButton1Click:Connect(function()
		if not base then
			return
		end
		command("item", {
			base = form.base,
			rarity = form.rarity,
			level = form.level,
			upgrade = form.upgrade,
			perks = form.perks,
			randomPerks = form.randomPerks,
			enchant = if form.enchant then { id = form.enchant, tier = form.enchantTier } else nil,
			target = form.target,
		})
	end)

	-- coluna 3: perks (os do tipo do item; "Todos" mostra também os do outro tipo e os exclusivos)
	local right = UI.new("Frame", { Position = UDim2.fromOffset(568, 0), Size = UDim2.new(1, -568, 1, 0), BackgroundTransparency = 1, Parent = page })
	text(right, { Text = ("PERKS  %d/%d"):format(#form.perks, MAX_PERKS), Size = UDim2.new(1, 0, 0, 16), TextSize = 12, TextColor3 = ACCENT, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left })
	local toggles = UI.new("Frame", { Position = UDim2.fromOffset(0, 18), Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, Parent = right }, { UI.list(6, true) })
	for order, toggle in { { "randomPerks", "Sorteados" }, { "allPerks", "Todos" } } do
		local button = UI.button({ Text = toggle[2], TextSize = 12, LayoutOrder = order, Size = UDim2.fromOffset(84, 24), BackgroundColor3 = if form[toggle[1]] then ACCENT else UI.Colors.Dark, Parent = toggles })
		button.MouseButton1Click:Connect(function()
			form[toggle[1]] = not form[toggle[1]]
			render()
		end)
	end
	local clear = UI.button({ Text = "Limpar", TextSize = 12, LayoutOrder = 3, Size = UDim2.fromOffset(70, 24), BackgroundColor3 = UI.Colors.Dark, Parent = toggles })
	clear.MouseButton1Click:Connect(function()
		form.perks = {}
		render()
	end)
	local perkList = UI.new("ScrollingFrame", { Position = UDim2.fromOffset(0, 48), Size = UDim2.new(1, 0, 1, -48), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = right }, { UI.list(3) })
	if form.randomPerks then
		text(perkList, { Text = "Os perks serão sorteados pela raridade, como num drop.", Size = UDim2.new(1, -8, 0, 40), TextSize = 13, TextColor3 = UI.Colors.SubText })
		return
	end
	local pool = base and Perks.poolForSlot(base.slot)
	local ids = {}
	for id, perk in Perks.List do
		if form.allPerks or ((not pool or perk.pool == pool) and not perk.exclusive) or table.find(form.perks, id) then
			table.insert(ids, id)
		end
	end
	table.sort(ids, function(a, b)
		return Perks.List[a].name < Perks.List[b].name
	end)
	for order, id in ids do
		local perk = Perks.List[id]
		local chosen = table.find(form.perks, id) ~= nil
		local row = UI.button({ Text = "", LayoutOrder = order, Size = UDim2.new(1, -8, 0, 44), BackgroundColor3 = if chosen then Color3.fromRGB(60, 110, 70) else UI.Colors.PanelLight, Parent = perkList })
		text(row, { Text = (if chosen then "✔ " else "") .. perk.name .. (if perk.major then "  ★" else "") .. (if perk.exclusive then "  (" .. perk.exclusive .. ")" else ""), Position = UDim2.fromOffset(8, 3), Size = UDim2.new(1, -16, 0, 16), TextSize = 13, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd, TextXAlignment = Enum.TextXAlignment.Left })
		text(row, { Text = perk.text or "", Position = UDim2.fromOffset(8, 20), Size = UDim2.new(1, -16, 0, 22), TextSize = 11, TextColor3 = UI.Colors.SubText, TextTruncate = Enum.TextTruncate.AtEnd, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top })
		row.MouseButton1Click:Connect(function()
			local index = table.find(form.perks, id)
			if index then
				table.remove(form.perks, index)
			elseif #form.perks < MAX_PERKS then
				table.insert(form.perks, id)
			else
				Popups.message(("No máximo %d perks."):format(MAX_PERKS), UI.Colors.Red)
				return
			end
			render()
		end)
	end
end

-- ===================== REGISTRO =====================
local function renderLog(page)
	local scroll = UI.new("ScrollingFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = page }, { UI.list(3) })
	if #snapshot.log == 0 then
		text(scroll, { Text = "Nenhuma ação registrada.", Size = UDim2.new(1, 0, 0, 20), TextColor3 = UI.Colors.SubText })
	end
	for i, entry in snapshot.log do
		text(scroll, { Text = ("%s  •  %s  •  %s  %s"):format(os.date("%d/%m %H:%M", entry.t), entry.admin, entry.action, entry.detail), Size = UDim2.new(1, -8, 0, 20), TextSize = 13, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd, LayoutOrder = i })
	end
end

function render()
	if not win or not win:isOpen() or not snapshot then
		return
	end
	for _, name in { "Jogadores", "Balanceamento", "Mundo", "Para mim", "Itens", "Registro" } do
		UI.clear(pages[name])
	end
	local page = pages[win.tab]
	if win.tab == "Jogadores" then
		renderPlayers(page)
	elseif win.tab == "Balanceamento" then
		renderBalance(page)
	elseif win.tab == "Mundo" then
		renderWorld(page)
	elseif win.tab == "Para mim" then
		renderSelf(page)
	elseif win.tab == "Itens" then
		renderItems(page)
	else
		renderLog(page)
	end
end

function AdminWindow.toggle()
	if not Players.LocalPlayer:GetAttribute("Admin") then
		return
	end
	if win:isOpen() then
		win:close()
	else
		win:open()
	end
end

function AdminWindow.init(screen)
	win = Window.create(screen, { icon = "cog", name = "Admin", title = "PAINEL DE ADMIN", width = 860, height = 560, tabs = { "Jogadores", "Balanceamento", "Mundo", "Para mim", "Itens", "Registro" }, accent = ACCENT })
	for _, name in { "Jogadores", "Balanceamento", "Mundo", "Para mim", "Itens", "Registro" } do
		pages[name] = UI.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = win.content })
	end
	win.onTab = function(name)
		for tabName, page in pages do
			page.Visible = tabName == name
		end
		render()
	end
	win.onOpen = function()
		pending = {}
		win.onTab(win.tab)
		task.spawn(refresh)
	end
	-- botão no canto (só para admins)
	openButton = UI.button({ Text = "ADMIN", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 12, 1, -12), Size = UDim2.fromOffset(80, 28), BackgroundColor3 = ACCENT, Visible = false, Parent = screen })
	openButton.MouseButton1Click:Connect(AdminWindow.toggle)
	local function updateButton()
		openButton.Visible = Players.LocalPlayer:GetAttribute("Admin") == true
	end
	Players.LocalPlayer:GetAttributeChangedSignal("Admin"):Connect(updateButton)
	updateButton()
end

return AdminWindow
