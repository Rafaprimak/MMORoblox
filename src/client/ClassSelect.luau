-- Escolha de classe (obrigatória na primeira vez; depois, troca paga com o Mestre Kael).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Classes = require(Shared.Classes)
local Items = require(Shared.Items)

local UI = require(script.Parent.UI)
local State = require(script.Parent.State)
local Sounds = require(script.Parent.Sounds)
local Popups = require(script.Parent.Popups)

local ClassSelect = {}

local gui, title, subtitle, closeButton, cards
local changeMode = false

local function statBar(parent, y, label, value, color)
	UI.label({ Text = label, Position = UDim2.fromOffset(12, y), Size = UDim2.fromOffset(70, 16), TextColor3 = UI.Colors.SubText, Parent = parent })
	local _, fill = UI.bar(parent, { Position = UDim2.new(0, 84, 0, y + 2), Size = UDim2.new(1, -100, 0, 12), color = color, text = false })
	UI.setBar(fill, value)
end

local function render()
	UI.clear(cards)
	local data = State.data
	for i, classId in Classes.Order do
		local class = Classes.List[classId]
		local role = Classes.Roles[class.role]
		local card = UI.new("Frame", { Size = UDim2.fromOffset(210, 460), BackgroundColor3 = UI.Colors.Panel, LayoutOrder = i, Parent = cards }, { UI.corner(14), UI.stroke(class.color, 3) })
		UI.label({ Text = class.icon, Position = UDim2.fromOffset(0, 10), Size = UDim2.new(1, 0, 0, 60), TextXAlignment = Enum.TextXAlignment.Center, Parent = card })
		UI.label({ Text = class.name, Position = UDim2.fromOffset(0, 74), Size = UDim2.new(1, 0, 0, 30), TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = class.color, Font = Enum.Font.GothamBlack, Parent = card }, { UI.textStroke(1.5) })
		if role then
			local badge = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 104), Size = UDim2.fromOffset(150, 22), BackgroundColor3 = role.color, Parent = card }, { UI.corner(11) })
			UI.label({ Text = role.icon .. " " .. string.upper(role.name), Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, Font = Enum.Font.GothamBlack, TextColor3 = Color3.new(1, 1, 1), Parent = badge }, { UI.textStroke(1) })
		end
		UI.label({ Text = class.description, Position = UDim2.fromOffset(10, 130), Size = UDim2.new(1, -20, 0, 54), TextScaled = false, TextSize = 14, TextWrapped = true, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Center, Parent = card })
		statBar(card, 188, "Vida", class.health / 1.4, UI.Colors.Health)
		statBar(card, 208, "Mana", class.mana / 1.8, UI.Colors.Mana)
		statBar(card, 228, "Estamina", class.stamina / 1.4, UI.Colors.Stamina)
		local weapons = {}
		for weaponType in class.weapons do
			local def = Items.WeaponTypes[weaponType]
			table.insert(weapons, def.icon .. " " .. def.name)
		end
		table.sort(weapons)
		UI.label({ Text = "Armas: " .. table.concat(weapons, ", "), Position = UDim2.fromOffset(12, 250), Size = UDim2.new(1, -24, 0, 32), TextScaled = false, TextSize = 13, TextWrapped = true, Parent = card })
		local abilityLines = {}
		for _, abilityId in class.abilities do
			local ability = Classes.Abilities[abilityId]
			table.insert(abilityLines, ("%s %s (Nv. %d)"):format(ability.icon, ability.name, ability.unlock))
		end
		UI.label({ Text = table.concat(abilityLines, "\n"), Position = UDim2.fromOffset(12, 286), Size = UDim2.new(1, -24, 0, 100), TextScaled = false, TextSize = 13, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Font = Enum.Font.Gotham, Parent = card })
		local current = data and data.class == classId
		local button = UI.button({
			Text = if current then "SUA CLASSE" elseif changeMode then ("TROCAR  💰%d"):format(Config.ClassChangePrice) else "ESCOLHER",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -12),
			Size = UDim2.new(1, -24, 0, 46),
			BackgroundColor3 = if current then UI.Colors.Dark else class.color,
			Parent = card,
		})
		button.MouseButton1Click:Connect(function()
			if current then
				return
			end
			local result = State.request("chooseClass", classId)
			if result and result.ok then
				Sounds.play("equip", 1, 0.7)
				gui.Enabled = false
				Popups.burst(class.icon .. " " .. string.upper(class.name), class.color, "Sua jornada começa! Fale com a Capitã Lyra (❗)")
			end
		end)
	end
end

function ClassSelect.init()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	gui = UI.new("ScreenGui", { Name = "EscolhaClasse", DisplayOrder = 20, IgnoreGuiInset = true, ResetOnSpawn = false, Enabled = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = playerGui })
	local back = UI.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(8, 8, 14), BackgroundTransparency = 0.15, Parent = gui })
	local holder = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(1150, 580), BackgroundTransparency = 1, Parent = back })
	local scale = UI.new("UIScale", { Parent = holder })
	title = UI.label({ Text = "ESCOLHA SUA CLASSE", Size = UDim2.new(1, 0, 0, 44), TextXAlignment = Enum.TextXAlignment.Center, Font = Enum.Font.GothamBlack, TextColor3 = UI.Colors.Gold, Parent = holder }, { UI.textStroke(2) })
	subtitle = UI.label({ Text = "Cada classe tem armas, habilidades e estilo de luta próprios.", Position = UDim2.fromOffset(0, 46), Size = UDim2.new(1, 0, 0, 22), TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = UI.Colors.SubText, Parent = holder })
	cards = UI.new("Frame", { Position = UDim2.fromOffset(0, 90), Size = UDim2.new(1, 0, 0, 470), BackgroundTransparency = 1, Parent = holder }, { UI.list(14, true, Enum.HorizontalAlignment.Center) })
	closeButton = UI.button({ Text = "X", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(40, 40), BackgroundColor3 = UI.Colors.Red, Parent = holder })
	closeButton.MouseButton1Click:Connect(function()
		gui.Enabled = false
	end)
	local function fit()
		scale.Scale = UI.fitScale(1150, 580)
	end
	fit()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
end

function ClassSelect.open(change)
	changeMode = change == true
	closeButton.Visible = changeMode
	subtitle.Text = if changeMode then ("Trocar de classe custa %d de ouro e devolve seus pontos de habilidade."):format(Config.ClassChangePrice) else "Tanque, suporte ou dano: cada classe tem um papel no grupo, armas e habilidades próprias. (Dá para trocar depois com o Mestre Kael.)"
	render()
	gui.Enabled = true
end

function ClassSelect.isOpen()
	return gui ~= nil and gui.Enabled
end

return ClassSelect
