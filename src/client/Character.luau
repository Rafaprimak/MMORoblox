-- Personagem: habilidades da classe (gastar pontos), perícias (maestrias e profissões) e atributos.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Classes = require(Shared.Classes)
local Skills = require(Shared.Skills)
local Items = require(Shared.Items)

local UI = require(script.Parent.UI)
local State = require(script.Parent.State)
local Window = require(script.Parent.Window)
local Sounds = require(script.Parent.Sounds)

local Character = {}

local win, body

local function renderAbilities(data)
	local class = Classes.List[data.class]
	if not class then
		UI.label({ Text = "Escolha uma classe primeiro.", Size = UDim2.new(1, 0, 0, 24), Parent = body })
		return
	end
	UI.label({ Text = ("%s %s  •  ⭐ Pontos de habilidade: %d"):format(class.icon, class.name, data.skillPoints), Size = UDim2.new(1, -10, 0, 24), TextColor3 = class.color, Font = Enum.Font.GothamBlack, LayoutOrder = 0, Parent = body }, { UI.textStroke(1) })
	for slot, abilityId in class.abilities do
		local ability = Classes.Abilities[abilityId]
		local info = data.abilities[slot] or { rank = 0, unlocked = false }
		local row = UI.new("Frame", { Size = UDim2.new(1, -10, 0, 86), BackgroundColor3 = UI.Colors.PanelLight, BackgroundTransparency = 0.25, LayoutOrder = slot, Parent = body }, { UI.corner(10), UI.stroke(if info.unlocked then UI.Colors.Mana else UI.Colors.Stroke, 1.5) })
		UI.label({ Text = ability.icon, Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(52, 52), TextXAlignment = Enum.TextXAlignment.Center, TextTransparency = if info.unlocked then 0 else 0.6, Parent = row })
		UI.label({ Text = ("[%d] %s"):format(slot, ability.name), Position = UDim2.fromOffset(72, 6), Size = UDim2.new(1, -200, 0, 22), Font = Enum.Font.GothamBlack, Parent = row }, { UI.textStroke(1) })
		local status = if info.unlocked then ("Rank %d/%d  •  %d mana  •  recarga %.1fs"):format(info.rank, Classes.MaxAbilityRank, ability.mana, info.cooldown) else ("🔒 Destrava no nível %d"):format(ability.unlock)
		UI.label({ Text = status, Position = UDim2.fromOffset(72, 28), Size = UDim2.new(1, -200, 0, 16), TextColor3 = if info.unlocked then UI.Colors.Mana else UI.Colors.SubText, Parent = row })
		UI.label({ Text = ability.description, Position = UDim2.fromOffset(72, 46), Size = UDim2.new(1, -200, 0, 34), TextScaled = false, TextSize = 14, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Font = Enum.Font.Gotham, TextColor3 = UI.Colors.SubText, Parent = row })
		-- pips de rank
		for r = 1, Classes.MaxAbilityRank do
			UI.new("Frame", { Position = UDim2.new(1, -118 + (r - 1) * 14, 0, 12), Size = UDim2.fromOffset(10, 10), BackgroundColor3 = if r <= info.rank then UI.Colors.Gold else UI.Colors.Dark, Parent = row }, { UI.corner(5) })
		end
		local canRank = info.unlocked and info.rank < Classes.MaxAbilityRank and data.skillPoints > 0
		local button = UI.button({ Text = if info.rank >= Classes.MaxAbilityRank then "MÁX" else "+ RANK", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -10, 1, -10), Size = UDim2.fromOffset(100, 32), BackgroundColor3 = if canRank then UI.Colors.Green else UI.Colors.Dark, Parent = row })
		button.MouseButton1Click:Connect(function()
			if canRank then
				local result = State.request("rankAbility", abilityId)
				if result and result.ok then
					Sounds.play("ping", 1.5, 0.5)
				end
			end
		end)
	end
	UI.label({ Text = "Cada rank: +15% de efeito e -6% de recarga. Você ganha 1 ponto por nível.", Size = UDim2.new(1, -10, 0, 18), TextColor3 = UI.Colors.SubText, Font = Enum.Font.Gotham, LayoutOrder = 10, Parent = body })
end

local function skillRow(data, id, order)
	local def = Skills.List[id]
	local entry = data.skills[id] or { level = 1, xp = 0 }
	local row = UI.new("Frame", { Size = UDim2.new(1, -10, 0, 50), BackgroundColor3 = UI.Colors.PanelLight, BackgroundTransparency = 0.3, LayoutOrder = order, Parent = body }, { UI.corner(8) })
	UI.label({ Text = def.icon, Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(34, 34), TextXAlignment = Enum.TextXAlignment.Center, Parent = row })
	UI.label({ Text = ("%s  •  Nv. %d"):format(def.name, entry.level), Position = UDim2.fromOffset(50, 4), Size = UDim2.new(0.5, 0, 0, 20), Font = Enum.Font.GothamBlack, Parent = row })
	local xpNext = Config.skillXpToNext(entry.level)
	local _, fill, label = UI.bar(row, { Position = UDim2.new(0, 50, 0, 28), Size = UDim2.new(1, -60, 0, 14), color = if def.kind == "mastery" then UI.Colors.Red else UI.Colors.Green })
	UI.setBar(fill, entry.xp / xpNext)
	label.Text = ("%d / %d"):format(entry.xp, xpNext)
	local hint = def.description
	if def.kind == "mastery" then
		local nextPerk = nil
		for _, perk in Skills.MasteryPerks do
			if perk.level > entry.level then
				nextPerk = perk
				break
			end
		end
		hint = ("+%d%% de dano"):format(entry.level * 2) .. (if nextPerk then ("  •  Nv. %d: %s"):format(nextPerk.level, nextPerk.text) else "")
	end
	UI.label({ Text = hint or "", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 6), Size = UDim2.new(0.5, -20, 0, 16), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = UI.Colors.SubText, Font = Enum.Font.Gotham, Parent = row })
end

local function renderSkills(data)
	UI.label({ Text = "⚔️ MAESTRIAS (sobem usando a arma)", Size = UDim2.new(1, -10, 0, 22), TextColor3 = UI.Colors.Red, Font = Enum.Font.GothamBlack, LayoutOrder = 0, Parent = body })
	for i, id in Skills.MasteryOrder do
		skillRow(data, id, i)
	end
	UI.label({ Text = "🛠️ PROFISSÕES (coleta e fabricação)", Size = UDim2.new(1, -10, 0, 22), TextColor3 = UI.Colors.Green, Font = Enum.Font.GothamBlack, LayoutOrder = 20, Parent = body })
	for i, id in Skills.ProfessionOrder do
		skillRow(data, id, 20 + i)
	end
end

local function renderStats(data)
	local stats = data.stats
	local class = Classes.List[data.class]
	local weaponType = Items.WeaponTypes[stats.weaponType]
	local rows = {
		{ "Classe", if class then class.icon .. " " .. class.name else "—" },
		{ "Nível / Rank", ("%d  •  Rank %s"):format(data.level, Config.getRank(data.level).name) },
		{ "Arma", ("%s %s (maestria %d)"):format(weaponType and weaponType.icon or "", weaponType and weaponType.name or "", stats.masteryLevel) },
		{ "Afinidade de classe", if stats.affinity then "✔ +15% de dano" else "✘ arma de outra classe" },
		{ "Ataque", UI.formatNumber(stats.attack) },
		{ "Vida máxima", UI.formatNumber(stats.maxHealth) },
		{ "Mana máxima", UI.formatNumber(stats.maxMana) },
		{ "Estamina máxima", UI.formatNumber(stats.maxStamina) },
		{ "Defesa", ("%d (reduz %d%% do dano)"):format(stats.defense, math.floor(stats.defense / (stats.defense + 100) * 100)) },
		{ "Chance de crítico", ("%d%%"):format(math.floor(stats.crit * 100)) },
		{ "Dano crítico", ("x%.2f"):format(stats.critMult) },
		{ "Velocidade de ataque", ("%d%%"):format(math.floor(stats.attackSpeed * 100)) },
		{ "Roubo de vida", ("%d%%"):format(math.floor(stats.lifesteal * 100)) },
	}
	for i, row in rows do
		local frame = UI.new("Frame", { Size = UDim2.new(1, -10, 0, 30), BackgroundColor3 = UI.Colors.PanelLight, BackgroundTransparency = if i % 2 == 0 then 0.5 else 0.25, LayoutOrder = i, Parent = body }, { UI.corner(6) })
		UI.label({ Text = row[1], Position = UDim2.fromOffset(10, 5), Size = UDim2.new(0.45, 0, 0, 20), TextColor3 = UI.Colors.SubText, Parent = frame })
		UI.label({ Text = row[2], AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 5), Size = UDim2.new(0.55, 0, 0, 20), TextXAlignment = Enum.TextXAlignment.Right, Parent = frame })
	end
end

local function render()
	local data = State.data
	if not data then
		return
	end
	UI.clear(body)
	if win.tab == "Habilidades" then
		renderAbilities(data)
	elseif win.tab == "Perícias" then
		renderSkills(data)
	else
		renderStats(data)
	end
end

function Character.init(screen)
	win = Window.create(screen, { name = "Personagem", title = "🧙 PERSONAGEM", width = 680, height = 540, tabs = { "Habilidades", "Perícias", "Atributos" }, accent = Color3.fromRGB(150, 210, 255) })
	body = UI.new("ScrollingFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = win.content }, { UI.list(7) })
	win.onTab = render
	win.onOpen = render
	State.Changed:Connect(function()
		if win:isOpen() then
			render()
		end
	end)
end

function Character.toggle()
	win:toggle()
end

return Character
