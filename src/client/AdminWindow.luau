-- Painel de administrador (só aparece com o atributo "Admin", que o servidor dá): jogadores do servidor
-- (ir até, trazer, dar ouro/XP, expulsar, banir), balanceamento ao vivo (RemoteConfig, vale em todos os
-- servidores), aviso global, eventos, "Para mim" (o admin enche o próprio personagem) e o registro das ações. O servidor confere tudo de novo.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local RemoteConfig = require(Shared.RemoteConfig)

local UI = require(script.Parent.UI)
local State = require(script.Parent.State)
local Window = require(script.Parent.Window)
local Popups = require(script.Parent.Popups)

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
	for _, name in { "Jogadores", "Balanceamento", "Mundo", "Para mim", "Registro" } do
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
	win = Window.create(screen, { icon = "cog", name = "Admin", title = "PAINEL DE ADMIN", width = 860, height = 560, tabs = { "Jogadores", "Balanceamento", "Mundo", "Para mim", "Registro" }, accent = ACCENT })
	for _, name in { "Jogadores", "Balanceamento", "Mundo", "Para mim", "Registro" } do
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
