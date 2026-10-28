-- Placas do mundo (prompt "LerPlaca", ver Props.readable): abre um pergaminho com o título e o texto.
local UI = require(script.Parent.UI)
local Window = require(script.Parent.Window)
local Sounds = require(script.Parent.Sounds)

local SignReader = {}

local win, body

function SignReader.open(title, text)
	if type(title) ~= "string" or type(text) ~= "string" then
		return
	end
	win.title.Text = string.upper(title)
	UI.clear(body)
	UI.label({ Text = text, Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextScaled = false, TextSize = 17, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Font = Enum.Font.Gotham, TextColor3 = Color3.fromRGB(240, 228, 200), Parent = body })
	Sounds.play("ping", 0.8, 0.3)
	win:open()
end

function SignReader.init(screen)
	win = Window.create(screen, { icon = "wooden-sign", name = "Placa", title = "PLACA", width = 560, height = 360, accent = Color3.fromRGB(200, 160, 100) })
	body = UI.new("ScrollingFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = win.content }, { UI.list(6), UI.padding(10) })
end

return SignReader
