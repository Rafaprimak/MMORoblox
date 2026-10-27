-- Janela de Configurações (tecla P): volume, sensibilidade, números de dano, tremida, barra de ritmo, dicas.
-- As mudanças valem na hora (Prefs) e são salvas no servidor um segundo depois da última alteração.
local UI = require(script.Parent.UI)
local Window = require(script.Parent.Window)
local State = require(script.Parent.State)
local Prefs = require(script.Parent.Prefs)
local Sounds = require(script.Parent.Sounds)

local SettingsWindow = {}

SettingsWindow.onRestartTutorial = nil -- function()

local win = nil
local saveToken = 0

local function scheduleSave()
	saveToken += 1
	local token = saveToken
	task.delay(1, function()
		if token == saveToken then
			State.request("settings", Prefs.all())
		end
	end)
end

local function row(parent, order, title, subtitle)
	local frame = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 50), BackgroundColor3 = UI.Colors.PanelLight, BackgroundTransparency = 0.3, LayoutOrder = order, Parent = parent }, { UI.corner(8) })
	UI.label({ Text = title, Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -200, 0, 20), Font = Enum.Font.GothamBlack, Parent = frame }, { UI.textStroke(1) })
	if subtitle then
		UI.label({ Text = subtitle, Position = UDim2.fromOffset(12, 27), Size = UDim2.new(1, -200, 0, 16), TextColor3 = UI.Colors.SubText, Parent = frame })
	end
	return frame
end

local function stepper(parent, order, title, subtitle, key, step, min, max, format)
	local frame = row(parent, order, title, subtitle)
	local value = UI.label({ Text = "", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -52, 0.5, 0), Size = UDim2.fromOffset(80, 24), TextXAlignment = Enum.TextXAlignment.Center, Font = Enum.Font.GothamBlack, TextColor3 = UI.Colors.Gold, Parent = frame }, { UI.textStroke(1) })
	local minus = UI.button({ Text = "−", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -136, 0.5, 0), Size = UDim2.fromOffset(36, 32), BackgroundColor3 = UI.Colors.Dark, Parent = frame })
	local plus = UI.button({ Text = "+", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(36, 32), BackgroundColor3 = UI.Colors.Dark, Parent = frame })
	local function refresh()
		value.Text = format(Prefs.get(key))
	end
	local function change(delta)
		local new = math.clamp(math.floor((Prefs.get(key) + delta) / step + 0.5) * step, min, max)
		Prefs.set(key, new)
		refresh()
		scheduleSave()
		if key == "volume" then
			Sounds.play("ping", 1.4, 0.5)
		end
	end
	minus.MouseButton1Click:Connect(function()
		change(-step)
	end)
	plus.MouseButton1Click:Connect(function()
		change(step)
	end)
	return refresh
end

local function toggle(parent, order, title, subtitle, key)
	local frame = row(parent, order, title, subtitle)
	local button = UI.button({ Text = "", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(162, 32), Parent = frame })
	local function refresh()
		local on = Prefs.get(key) == true
		button.Text = if on then "LIGADO" else "DESLIGADO"
		button.BackgroundColor3 = if on then UI.Colors.Green else UI.Colors.Dark
	end
	button.MouseButton1Click:Connect(function()
		Prefs.set(key, not Prefs.get(key))
		refresh()
		scheduleSave()
	end)
	return refresh
end

function SettingsWindow.init(screen)
	win = Window.create(screen, { icon = "cog", title = "Configurações", width = 560, height = 660, name = "Configuracoes" })
	local list = UI.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = win.content }, { UI.list(6) })
	local refreshers = {
		stepper(list, 1, "Volume dos efeitos", "Golpes, interface e avisos", "volume", 0.1, 0, 1, function(v)
			return ("%d%%"):format(math.floor(v * 100 + 0.5))
		end),
		stepper(list, 2, "Volume da música", "Música e ambiente de cada região", "musicVolume", 0.1, 0, 1, function(v)
			return ("%d%%"):format(math.floor(v * 100 + 0.5))
		end),
		stepper(list, 2, "Sensibilidade da câmera", "Velocidade ao girar com o mouse", "sensitivity", 0.1, 0.2, 3, function(v)
			return ("%.1fx"):format(v)
		end),
		stepper(list, 2, "Qualidade gráfica", "Distância do cenário (baixa ajuda no celular)", "quality", 1, 1, 3, function(v)
			return ({ "Baixa", "Média", "Alta" })[math.clamp(math.floor(v), 1, 3)]
		end),
		toggle(list, 3, "Números de dano", "Mostrar o dano em cima dos inimigos", "damageNumbers"),
		toggle(list, 4, "Tremida de câmera", "Impactos fortes, críticos e aparadas", "shake"),
		toggle(list, 5, "Barra de ritmo do combo", "Mostra quando clicar para emendar o combo", "rhythmBar"),
		toggle(list, 6, "Dicas do tutorial", "Dicas no topo da tela nos primeiros minutos", "tips"),
		toggle(list, 6, "Contorno de anime", "Borda escura nos personagens, NPCs e inimigos por perto", "outlines"),
	}
	local restart = UI.button({ Text = "Recomeçar o tutorial", Size = UDim2.fromOffset(220, 34), LayoutOrder = 7, BackgroundColor3 = UI.Colors.Accent, Parent = list })
	-- créditos exigidos pela licença dos ícones (CC BY 3.0)
	UI.label({ Text = "Ícones: game-icons.net (Lorc, Delapouite e outros), licença CC BY 3.0", Size = UDim2.new(1, -10, 0, 16), LayoutOrder = 8, TextColor3 = UI.Colors.SubText, Font = Enum.Font.Gotham, Parent = list })
	restart.MouseButton1Click:Connect(function()
		Prefs.set("tips", true)
		scheduleSave()
		for _, refresh in refreshers do
			refresh()
		end
		if SettingsWindow.onRestartTutorial then
			SettingsWindow.onRestartTutorial()
		end
		win:close()
	end)
	win.onOpen = function()
		for _, refresh in refreshers do
			refresh()
		end
	end
end

function SettingsWindow.toggle()
	win:toggle()
end

return SettingsWindow
