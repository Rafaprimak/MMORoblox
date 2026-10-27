-- Utilitários de interface: criação de instâncias, cores, ícones e formatação.
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Icons = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Icons"))

local UI = {}

-- sons dos botões (carregado só na hora para não criar dependência circular)
local soundModule = nil
local function buttonSound(name, volume)
	if not soundModule then
		local ok, module = pcall(require, script.Parent.Sounds)
		soundModule = if ok then module else false
	end
	if soundModule then
		soundModule.play(name, 1, volume)
	end
end

-- Tema: azul-noite com acabamento dourado (estilo fantasia)
UI.Colors = {
	Panel = Color3.fromRGB(19, 21, 36),
	PanelLight = Color3.fromRGB(34, 37, 58),
	Stroke = Color3.fromRGB(92, 84, 70),
	Trim = Color3.fromRGB(214, 178, 96),
	TrimDark = Color3.fromRGB(120, 92, 44),
	Ribbon = Color3.fromRGB(120, 30, 38),
	Text = Color3.fromRGB(240, 240, 245),
	SubText = Color3.fromRGB(165, 170, 190),
	Gold = Color3.fromRGB(255, 205, 60),
	Green = Color3.fromRGB(90, 220, 110),
	Red = Color3.fromRGB(235, 70, 70),
	Accent = Color3.fromRGB(110, 90, 255),
	Xp = Color3.fromRGB(80, 170, 255),
	Health = Color3.fromRGB(225, 60, 60),
	Mana = Color3.fromRGB(70, 130, 255),
	Stamina = Color3.fromRGB(240, 200, 60),
	Dark = Color3.fromRGB(60, 60, 72),
	Icon = Color3.fromRGB(255, 234, 180), -- tinta padrão dos ícones (marfim dourado)
}

function UI.new(className, props, children)
	local instance = Instance.new(className)
	local parent = nil
	if props then
		for key, value in props do
			if key == "Parent" then
				parent = value
			else
				instance[key] = value
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

-- Fonte serifada dos títulos (com reserva para a Gotham se a família não carregar)
UI.TitleFont = Font.new("rbxasset://fonts/families/Merriweather.json", Enum.FontWeight.Bold)

-- Moldura ornamentada: borda dourada dupla e um losango em cada canto
function UI.ornate(frame, color, inset)
	color = color or UI.Colors.Trim
	inset = inset or 5
	local stroke = frame:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = color
		stroke.Thickness = 2
		stroke.Transparency = 0.1
	else
		UI.new("UIStroke", { Color = color, Thickness = 2, Transparency = 0.1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = frame })
	end
	UI.new("Frame", { Name = "BordaInterna", Position = UDim2.fromOffset(inset, inset), Size = UDim2.new(1, -inset * 2, 1, -inset * 2), BackgroundTransparency = 1, ZIndex = 0, Parent = frame }, {
		UI.new("UICorner", { CornerRadius = UDim.new(0, 8) }),
		UI.new("UIStroke", { Color = color, Thickness = 1, Transparency = 0.65 }),
	})
	for _, corner in { Vector2.new(0, 0), Vector2.new(1, 0), Vector2.new(0, 1), Vector2.new(1, 1) } do
		UI.new("Frame", {
			Name = "Losango",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(corner.X, corner.Y),
			Size = UDim2.fromOffset(12, 12),
			Rotation = 45,
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			ZIndex = 8,
			Parent = frame,
		}, { UI.new("UIStroke", { Color = UI.Colors.TrimDark, Thickness = 1.5 }) })
	end
	return frame
end

function UI.corner(radius)
	return UI.new("UICorner", { CornerRadius = UDim.new(0, radius or 8) })
end

function UI.stroke(color, thickness, transparency)
	return UI.new("UIStroke", {
		Color = color or UI.Colors.Stroke,
		Thickness = thickness or 1.5,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function UI.textStroke(thickness)
	return UI.new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = thickness or 1.5, Transparency = 0.2 })
end

function UI.padding(px)
	return UI.new("UIPadding", {
		PaddingTop = UDim.new(0, px),
		PaddingBottom = UDim.new(0, px),
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
	})
end

function UI.list(padding, horizontal, align)
	return UI.new("UIListLayout", {
		Padding = UDim.new(0, padding or 6),
		FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Left,
	})
end

function UI.label(props, children)
	local merged = {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextColor3 = UI.Colors.Text,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	}
	for key, value in props do
		merged[key] = value
	end
	if props.FontFace then
		merged.Font = nil -- senão a fonte padrão pode sobrescrever a FontFace
	end
	return UI.new("TextLabel", merged, children)
end

-- Botão com "afundadinha" ao clicar
function UI.button(props, children)
	local merged = {
		AutoButtonColor = true,
		BackgroundColor3 = UI.Colors.Accent,
		Font = Enum.Font.GothamBlack,
		TextColor3 = Color3.new(1, 1, 1),
		TextScaled = true,
	}
	for key, value in props do
		merged[key] = value
	end
	local button = UI.new("TextButton", merged, children)
	UI.corner(8).Parent = button
	-- brilho de cima para baixo (mantém a cor do botão), borda escura suave e contorno no texto
	UI.new("UIGradient", { Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(180, 180, 192)), Rotation = 90, Parent = button })
	if not button:FindFirstChildOfClass("UIStroke") then
		UI.new("UIStroke", { Color = UI.Colors.Trim, Thickness = 1.2, Transparency = 0.55, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = button })
	end
	button.TextStrokeTransparency = 0.65
	UI.new("UIPadding", {
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
		PaddingTop = UDim.new(0, 5),
		PaddingBottom = UDim.new(0, 5),
		Parent = button,
	})
	local scale = UI.new("UIScale", { Parent = button })
	button.MouseButton1Down:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.06), { Scale = 0.93 }):Play()
		buttonSound("click", 0.35)
	end)
	local function release()
		TweenService:Create(scale, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end
	button.MouseButton1Up:Connect(release)
	button.MouseLeave:Connect(release)
	button.MouseEnter:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Quad), { Scale = 1.04 }):Play()
		buttonSound("hover", 0.12)
	end)
	return button
end

-- Barra de progresso; retorna back, fill, label
function UI.bar(parent, props)
	local back = UI.new("Frame", {
		Position = props.Position,
		Size = props.Size,
		BackgroundColor3 = Color3.fromRGB(10, 10, 18),
		BackgroundTransparency = 0.1,
		LayoutOrder = props.LayoutOrder,
		Parent = parent,
	}, { UI.corner(props.radius or 5), UI.new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 1.2, Transparency = 0.3 }) })
	local fill = UI.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = props.color or UI.Colors.Gold, Parent = back }, {
		UI.corner(props.radius or 5),
		UI.new("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)), ColorSequenceKeypoint.new(0.45, Color3.fromRGB(235, 235, 235)), ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 150, 160)) }), Rotation = 90 }),
	})
	-- reflexo no topo da barra
	UI.new("Frame", { Name = "Reflexo", Position = UDim2.new(0, 3, 0, 2), Size = UDim2.new(1, -6, 0.28, 0), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.75, BorderSizePixel = 0, ZIndex = 2, Parent = fill }, { UI.corner(4) })
	local label = nil
	if props.text ~= false then
		label = UI.label({
			Size = UDim2.fromScale(1, 1),
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = 3,
			Text = props.text or "",
			Parent = back,
		}, { UI.textStroke(1) })
	end
	return back, fill, label
end

function UI.setBar(fill, ratio, animate)
	ratio = math.clamp(ratio, 0, 1)
	if animate then
		TweenService:Create(fill, TweenInfo.new(0.25), { Size = UDim2.fromScale(ratio, 1) }):Play()
	else
		fill.Size = UDim2.fromScale(ratio, 1)
	end
end

function UI.clear(container)
	for _, child in container:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

function UI.tween(instance, duration, goals, style, direction)
	local tween = TweenService:Create(instance, TweenInfo.new(duration, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), goals)
	tween:Play()
	return tween
end

function UI.pulse(scaleObject, amount)
	scaleObject.Scale = amount or 1.2
	UI.tween(scaleObject, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
end

function UI.fadeOut(root, duration)
	local info = TweenInfo.new(duration)
	local targets = root:GetDescendants()
	table.insert(targets, root)
	for _, obj in targets do
		if obj:IsA("TextLabel") or obj:IsA("TextButton") then
			TweenService:Create(obj, info, { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
		elseif obj:IsA("Frame") then
			TweenService:Create(obj, info, { BackgroundTransparency = 1 }):Play()
		elseif obj:IsA("UIStroke") then
			TweenService:Create(obj, info, { Transparency = 1 }):Play()
		end
	end
end

function UI.formatNumber(n)
	n = math.floor(n)
	local digits = tostring(math.abs(n))
	local formatted = digits:reverse():gsub("(%d%d%d)", "%1."):reverse()
	if formatted:sub(1, 1) == "." then
		formatted = formatted:sub(2)
	end
	return (if n < 0 then "-" else "") .. formatted
end

function UI.formatTime(seconds)
	seconds = math.max(0, math.floor(seconds))
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	if hours > 0 then
		return ("%dh %02dm"):format(hours, minutes)
	end
	return ("%dm %02ds"):format(minutes, seconds % 60)
end

function UI.formatPercent(percent)
	if percent >= 10 then
		return ("%.0f%%"):format(percent)
	elseif percent >= 1 then
		return ("%.1f%%"):format(percent)
	end
	return ("%.2f%%"):format(percent)
end

-- nome do ícone do atributo principal do item (vida para armaduras, ataque para o resto)
function UI.statIcon(item)
	return if item.slot == "armor" or item.slot == "helmet" or item.slot == "boots" then "heart-plus" else "crossed-swords"
end

-- palavra do atributo principal (para textos)
function UI.statWord(item)
	return if item.slot == "armor" or item.slot == "helmet" or item.slot == "boots" then "Vida" else "Ataque"
end

-- ===================== ÍCONES =====================
-- Ícone do atlas (ver Icons): moldura transparente com sombra, desenho tingido com brilho metálico
-- (degradê) e um losango de reserva enquanto a folha não foi enviada ao Roblox.
-- props: as de qualquer GuiObject (Size, Position, AnchorPoint, LayoutOrder, ZIndex, Parent) +
-- Color (tinta) e Transparency.
function UI.setIcon(holder, name, color, transparency)
	if not holder then
		return
	end
	local image, offset, size = Icons.get(name)
	local shadow, art, reserve = holder:FindFirstChild("Sombra"), holder:FindFirstChild("Imagem"), holder:FindFirstChild("Reserva")
	if not art then
		return
	end
	if color then
		holder:SetAttribute("Tint", color)
	end
	local tint = holder:GetAttribute("Tint") or UI.Colors.Icon
	if transparency then
		holder:SetAttribute("Fade", transparency)
	end
	local fade = holder:GetAttribute("Fade") or 0
	for _, layer in { shadow, art } do
		layer.Image = image or ""
		layer.ImageRectOffset = offset or Vector2.zero
		layer.ImageRectSize = size or Vector2.zero
	end
	art.ImageColor3 = tint
	art.ImageTransparency = fade
	shadow.ImageTransparency = 0.45 + fade * 0.55
	reserve.Visible = image == nil and name ~= nil and name ~= ""
	reserve.TextColor3 = tint
	reserve.TextTransparency = fade
end

function UI.icon(name, props)
	props = props or {}
	local holder = UI.new("Frame", { Name = "Icone", BackgroundTransparency = 1, Size = props.Size or UDim2.fromOffset(32, 32) })
	for key, value in props do
		if key ~= "Color" and key ~= "Transparency" and key ~= "Parent" then
			holder[key] = value
		end
	end
	local zIndex = props.ZIndex or 1
	UI.new("ImageLabel", { Name = "Sombra", BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit, ImageColor3 = Color3.new(0, 0, 0), Position = UDim2.new(0, 2, 0, 2), Size = UDim2.fromScale(1, 1), ZIndex = zIndex, Parent = holder })
	UI.new("ImageLabel", { Name = "Imagem", BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit, Size = UDim2.fromScale(1, 1), ZIndex = zIndex, Parent = holder }, {
		UI.new("UIGradient", { Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(190, 180, 165)), Rotation = 90 }),
	})
	UI.new("TextLabel", { Name = "Reserva", Text = "◆", BackgroundTransparency = 1, TextScaled = true, Font = Enum.Font.GothamBold, Size = UDim2.fromScale(0.6, 0.6), Position = UDim2.fromScale(0.2, 0.2), Visible = false, ZIndex = zIndex, Parent = holder })
	UI.setIcon(holder, name, props.Color, props.Transparency)
	holder.Parent = props.Parent
	return holder
end

-- Ajusta a escala de uma janela ao tamanho da tela
function UI.fitScale(width, height)
	local camera = workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	return math.min(1, (viewport.X - 24) / width, (viewport.Y - 70) / height)
end

return UI
