-- Tutorial guiado: dicas no topo da tela, uma por vez, que avançam quando o jogador faz a ação.
-- Os passos feitos são salvos no servidor (Request "tutorial"). Some no nível 6+, se pular ou se
-- desligar "Dicas do tutorial" nas Configurações.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local UI = require(script.Parent.UI)
local State = require(script.Parent.State)
local Prefs = require(script.Parent.Prefs)
local Sounds = require(script.Parent.Sounds)

local Tutorial = {}

local MAX_LEVEL = 5

-- event: nome do evento que conclui o passo (Tutorial.event); count: quantas vezes
local STEPS = {
	{ id = "andar", text = "Ande com W A S D. Segure o botão direito do mouse para girar a câmera.", event = "moved" },
	{ id = "missao", text = "Fale com a Capitã Lyra (! na cabeça): chegue perto e aperte E.", event = "quest" },
	{ id = "feixe", text = "A coluna de luz amarela sempre aponta o próximo objetivo. Siga-a!", event = "walked" },
	{ id = "atacar", text = "Clique para atacar. Clique de novo quando a barrinha ficar VERDE: combo no ritmo!", event = "rhythm", count = 2 },
	{ id = "bloquear", text = "Segure F para bloquear. Aperte F logo antes do golpe (! amarelo) para APARAR.", event = "block", count = 2 },
	{ id = "esquivar", text = "Aperte Q para esquivar. Golpes com ‼ vermelho não podem ser bloqueados: esquive!", event = "dodge" },
	{ id = "inventario", text = "Abra o inventário (I) para equipar os itens que você ganhar.", event = "inventory" },
	{ id = "mapa", text = "Segure Shift para correr. No mapa (M) você viaja entre pedras de viagem ativadas.", event = "map" },
}

local frame, counter, label, scale = nil, nil, nil, nil
local done = {}
local loaded = false
local skipped = false
local current = nil
local progress = 0
local startPosition = nil

local function eligible()
	local data = State.data
	return data ~= nil and data.class ~= nil and data.level <= MAX_LEVEL and not skipped and Prefs.get("tips") == true
end

local function nextStep()
	for index, step in STEPS do
		if not done[step.id] then
			return step, index
		end
	end
	return nil
end

local function show()
	if not eligible() then
		frame.Visible = false
		current = nil
		return
	end
	local step, index = nextStep()
	if not step then
		frame.Visible = false
		current = nil
		return
	end
	if current ~= step then
		current = step
		progress = 0
		startPosition = nil
		counter.Text = ("DICA %d/%d"):format(index, #STEPS)
		label.Text = step.text
		scale.Scale = 0.85
		UI.tween(scale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	frame.Visible = true
end

local function complete(step)
	done[step.id] = true
	State.request("tutorial", step.id)
	Sounds.play("ping", 1.9, 0.4)
	current = nil
	if not nextStep() then
		frame.Visible = false
		if Tutorial.onFinished then
			Tutorial.onFinished()
		end
		return
	end
	task.delay(0.6, show)
end

Tutorial.onFinished = nil -- function() (o init mostra um aviso)

-- Chamado pelo init quando algo acontece ("rhythm", "block", "dodge", "inventory", "map", "quest"...)
function Tutorial.event(name)
	if not current or not frame.Visible or current.event ~= name then
		return
	end
	progress += 1
	if progress >= (current.count or 1) then
		complete(current)
	end
end

function Tutorial.restart()
	done = {}
	skipped = false
	current = nil
	State.request("tutorial", "restart")
	show()
end

function Tutorial.init(screen)
	frame = UI.new("Frame", {
		Name = "Tutorial",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 98),
		Size = UDim2.fromOffset(560, 62),
		BackgroundColor3 = UI.Colors.Panel,
		BackgroundTransparency = 0.12,
		Visible = false,
		Parent = screen,
	}, { UI.corner(12), UI.stroke(UI.Colors.Gold, 2, 0.2) })
	scale = UI.new("UIScale", { Parent = frame })
	counter = UI.label({ Text = "", Position = UDim2.fromOffset(14, 6), Size = UDim2.fromOffset(200, 16), TextColor3 = UI.Colors.Gold, Font = Enum.Font.GothamBlack, Parent = frame }, { UI.textStroke(1) })
	label = UI.label({ Text = "", Position = UDim2.fromOffset(14, 24), Size = UDim2.new(1, -28, 0, 32), TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Font = Enum.Font.GothamBold, Parent = frame }, { UI.textStroke(1) })
	local skip = UI.button({ Text = "Pular tutorial", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 5), Size = UDim2.fromOffset(110, 20), BackgroundColor3 = UI.Colors.Dark, Parent = frame })
	skip.MouseButton1Click:Connect(function()
		skipped = true
		State.request("tutorial", "skip")
		show()
	end)

	State.Changed:Connect(function(data)
		if not loaded and data.tutorial then
			loaded = true
			skipped = data.tutorial.skipped == true
			for id in data.tutorial.done or {} do
				done[id] = true
			end
		end
		-- passo da missão: conta assim que houver uma missão ativa ou concluída
		if current and current.event == "quest" and data.quests and (#data.quests.active > 0) then
			Tutorial.event("quest")
		end
		show()
	end)

	-- passos de movimento: medidos aqui mesmo
	local player = Players.LocalPlayer
	RunService.Heartbeat:Connect(function()
		if not current or not frame.Visible then
			return
		end
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not root then
			return
		end
		if current.event == "moved" or current.event == "walked" then
			startPosition = startPosition or root.Position
			local needed = if current.event == "moved" then 12 else 45
			if (root.Position - startPosition).Magnitude > needed then
				Tutorial.event(current.event)
			end
		end
	end)
end

return Tutorial
