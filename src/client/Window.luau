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
	}, { UI.corner(14), UI.stroke(UI.Colors.Trim, 2) })
	win.scale = UI.new("UIScale", { Parent = win.frame })
	-- fundo azul-noite com degradê, moldura dourada dupla e losangos nos cantos
	UI.new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(150, 150, 175)), Rotation = 90, Parent = win.frame })
	UI.ornate(win.frame, UI.Colors.Trim, 6)
	-- faixa do título em fita (com a cor de destaque da janela) por cima da borda de cima
	local accent = options.accent or UI.Colors.Accent
	local ribbon = UI.new("Frame", {
		Name = "Fita",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 2),
		Size = UDim2.fromOffset(0, 38),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = UI.Colors.Ribbon:Lerp(accent, 0.25),
		ZIndex = 6,
		Parent = win.frame,
	}, {
		UI.corner(8),
		UI.new("UIStroke", { Color = UI.Colors.Trim, Thickness = 2 }),
		UI.new("UIGradient", { Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(160, 150, 150)), Rotation = 90 }),
		UI.new("UIPadding", { PaddingLeft = UDim.new(0, 26), PaddingRight = UDim.new(0, 26) }),
	})
	win.title = UI.label({
		Text = options.title,
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		TextScaled = false,
		TextSize = 21,
		FontFace = UI.TitleFont,
		TextColor3 = Color3.fromRGB(255, 232, 170),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 7,
		Parent = ribbon,
	}, { UI.textStroke(1.5) })
	local close = UI.button({ Text = "✕", Position = UDim2.new(1, -48, 0, 12), Size = UDim2.fromOffset(34, 32), BackgroundColor3 = Color3.fromRGB(150, 40, 45), ZIndex = 6, Parent = win.frame })
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
			local selected = tabName == name
			button.BackgroundColor3 = if selected then UI.Colors.Trim else UI.Colors.PanelLight
			button.TextColor3 = if selected then Color3.fromRGB(40, 28, 12) else Color3.fromRGB(235, 220, 180)
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
