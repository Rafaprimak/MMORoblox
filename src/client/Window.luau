-- Janela genérica (título, fechar, abas, escala para caber na tela). Só uma janela aberta por vez.
local UI = require(script.Parent.UI)

local Window = {}

local all = {}

function Window.closeAll(except)
	for _, win in all do
		if win ~= except and win.frame.Visible then
			win:close()
		end
	end
end

function Window.anyOpen()
	for _, win in all do
		if win.frame.Visible then
			return true
		end
	end
	return false
end

-- options: title, width, height, accent, persistent (não fecha com Esc)
function Window.create(screen, options)
	local win = { width = options.width, height = options.height, onOpen = nil, onClose = nil, persistent = options.persistent }
	win.frame = UI.new("Frame", {
		Name = options.name or "Janela",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(options.width, options.height),
		BackgroundColor3 = UI.Colors.Panel,
		BackgroundTransparency = 0.04,
		Visible = false,
		ZIndex = 20,
		Parent = screen,
	}, { UI.corner(14), UI.stroke(options.accent or UI.Colors.Stroke, 2) })
	win.scale = UI.new("UIScale", { Parent = win.frame })
	win.title = UI.label({
		Text = options.title,
		Position = UDim2.fromOffset(16, 10),
		Size = UDim2.new(1, -120, 0, 30),
		Font = Enum.Font.GothamBlack,
		TextColor3 = options.accent or UI.Colors.Text,
		Parent = win.frame,
	}, { UI.textStroke(1) })
	local close = UI.button({ Text = "X", Position = UDim2.new(1, -46, 0, 8), Size = UDim2.fromOffset(36, 34), BackgroundColor3 = UI.Colors.Red, Parent = win.frame })
	close.MouseButton1Click:Connect(function()
		win:close()
	end)
	win.closeButton = close
	local top = if options.tabs then 92 else 50
	win.content = UI.new("Frame", {
		Position = UDim2.fromOffset(14, top),
		Size = UDim2.new(1, -28, 1, -top - 12),
		BackgroundTransparency = 1,
		Parent = win.frame,
	})

	if options.tabs then
		win.tabButtons = {}
		win.tab = options.tabs[1]
		local row = UI.new("Frame", { Position = UDim2.fromOffset(14, 48), Size = UDim2.new(1, -28, 0, 34), BackgroundTransparency = 1, Parent = win.frame }, { UI.list(6, true) })
		for i, name in options.tabs do
			local button = UI.button({ Text = name, Size = UDim2.fromOffset(math.min(170, (options.width - 40) / #options.tabs - 6), 32), LayoutOrder = i, BackgroundColor3 = UI.Colors.PanelLight, Parent = row })
			win.tabButtons[name] = button
			button.MouseButton1Click:Connect(function()
				win:setTab(name)
			end)
		end
	end

	function win:setTab(name)
		self.tab = name
		for tabName, button in self.tabButtons or {} do
			button.BackgroundColor3 = if tabName == name then (options.accent or UI.Colors.Accent) else UI.Colors.PanelLight
		end
		if self.onTab then
			self.onTab(name)
		end
	end

	function win:open()
		Window.closeAll(self)
		self.frame.Visible = true
		local target = UI.fitScale(self.width, self.height)
		self.scale.Scale = target * 0.88
		UI.tween(self.scale, 0.2, { Scale = target }, Enum.EasingStyle.Back)
		if self.tabButtons then
			self:setTab(self.tab)
		end
		if self.onOpen then
			self.onOpen()
		end
	end

	function win:close()
		self.frame.Visible = false
		if self.onClose then
			self.onClose()
		end
	end

	function win:toggle()
		if self.frame.Visible then
			self:close()
		else
			self:open()
		end
	end

	function win:isOpen()
		return self.frame.Visible
	end

	if options.tabs then
		win:setTab(options.tabs[1])
	end
	table.insert(all, win)
	return win
end

return Window
