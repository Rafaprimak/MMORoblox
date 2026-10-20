-- Utilitários de interface: criação de instâncias, cores e formatação.
local TweenService = game:GetService("TweenService")

local UI = {}

UI.Colors = {
	Panel = Color3.fromRGB(20, 22, 30),
	PanelLight = Color3.fromRGB(34, 37, 50),
	Stroke = Color3.fromRGB(70, 75, 100),
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
	end)
	local function release()
		TweenService:Create(scale, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end
	button.MouseButton1Up:Connect(release)
	button.MouseLeave:Connect(release)
	return button
end

-- Barra de progresso; retorna back, fill, label
function UI.bar(parent, props)
	local back = UI.new("Frame", {
		Position = props.Position,
		Size = props.Size,
		BackgroundColor3 = Color3.fromRGB(12, 12, 18),
		BackgroundTransparency = 0.15,
		LayoutOrder = props.LayoutOrder,
		Parent = parent,
	}, { UI.corner(props.radius or 5) })
	local fill = UI.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = props.color or UI.Colors.Gold, Parent = back }, { UI.corner(props.radius or 5) })
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

function UI.statIcon(item)
	return if item.slot == "armor" then "❤" else "⚔"
end

-- Ajusta a escala de uma janela ao tamanho da tela
function UI.fitScale(width, height)
	local camera = workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	return math.min(1, (viewport.X - 24) / width, (viewport.Y - 70) / height)
end

return UI
