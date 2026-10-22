-- Personagem: habilidades (aprender, rank, teclas 1-4), talentos (passivas em 3 ramos), perícias e atributos.
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

local function header(data, class)
	local role = Classes.Roles[class.role]
	local row = UI.new("Frame", { Size = UDim2.new(1, -10, 0, 30), BackgroundTransparency = 1, LayoutOrder = 0, Parent = body })
	UI.label({ Text = ("%s %s  •  %s %s"):format(class.icon, class.name, role and role.icon or "", role and role.name or ""), Size = UDim2.new(0.6, 0, 1, 0), TextColor3 = class.color, Font = Enum.Font.GothamBlack, Parent = row }, { UI.textStroke(1) })
	UI.label({ Text = ("⭐ Pontos de talento: %d"):format(data.skillPoints), AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0.4, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = if data.skillPoints > 0 then UI.Colors.Gold else UI.Colors.SubText, Font = Enum.Font.GothamBlack, Parent = row }, { UI.textStroke(1) })
end

local function renderAbilities(data)
	local class = Classes.List[data.class]
	if not class then
		UI.label({ Text = "Escolha uma classe primeiro.", Size = UDim2.new(1, 0, 0, 24), Parent = body })
		return
	end
	header(data, class)
	UI.label({ Text = "Básicas vêm de graça no nível. Avançadas (✦) custam 1 ponto para aprender. Escolha quais 4 levar nas teclas 1-4.", Size = UDim2.new(1, -10, 0, 18), TextColor3 = UI.Colors.SubText, Font = Enum.Font.Gotham, LayoutOrder = 1, Parent = body })
	for order, info in data.tree or {} do
		local ability = Classes.Abilities[info.id]
		if ability then
			local learned = info.rank > 0
			local available = data.level >= info.unlock
			local row = UI.new("Frame", { Size = UDim2.new(1, -10, 0, 92), BackgroundColor3 = UI.Colors.PanelLight, BackgroundTransparency = 0.25, LayoutOrder = 10 + order, Parent = body }, { UI.corner(10), UI.stroke(if info.slot > 0 then UI.Colors.Gold elseif learned then UI.Colors.Mana else UI.Colors.Stroke, 1.5) })
			UI.label({ Text = ability.icon, Position = UDim2.fromOffset(10, 12), Size = UDim2.fromOffset(52, 52), TextXAlignment = Enum.TextXAlignment.Center, TextTransparency = if learned then 0 else 0.55, Parent = row })
			UI.label({ Text = (if info.advanced then "✦ " else "") .. ability.name, Position = UDim2.fromOffset(72, 6), Size = UDim2.new(1, -300, 0, 22), Font = Enum.Font.GothamBlack, TextColor3 = if info.advanced then Color3.fromRGB(255, 220, 140) else UI.Colors.Text, Parent = row }, { UI.textStroke(1) })
			local status
			if learned then
				status = ("Rank %d/%d  •  %d mana  •  recarga %.1fs"):format(info.rank, Classes.MaxAbilityRank, ability.mana, Classes.rankCooldown(ability, info.rank))
			elseif available then
				status = "Disponível para aprender (1 ponto)"
			else
				status = ("🔒 Nível %d"):format(info.unlock)
			end
			UI.label({ Text = status, Position = UDim2.fromOffset(72, 28), Size = UDim2.new(1, -300, 0, 16), TextColor3 = if learned then UI.Colors.Mana else UI.Colors.SubText, Parent = row })
			UI.label({ Text = ability.description, Position = UDim2.fromOffset(72, 46), Size = UDim2.new(1, -300, 0, 40), TextScaled = false, TextSize = 14, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Font = Enum.Font.Gotham, TextColor3 = UI.Colors.SubText, Parent = row })
			for r = 1, Classes.MaxAbilityRank do
				UI.new("Frame", { Position = UDim2.new(1, -218 + (r - 1) * 14, 0, 12), Size = UDim2.fromOffset(10, 10), BackgroundColor3 = if r <= info.rank then UI.Colors.Gold else UI.Colors.Dark, Parent = row }, { UI.corner(5) })
			end
			-- aprender / subir rank
			local canRank = available and info.rank < Classes.MaxAbilityRank and data.skillPoints > 0
			local label = if not learned then "APRENDER" elseif info.rank >= Classes.MaxAbilityRank then "MÁX" else "+ RANK"
			local rankButton = UI.button({ Text = label, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 30), Size = UDim2.fromOffset(130, 26), BackgroundColor3 = if canRank then UI.Colors.Green else UI.Colors.Dark, Parent = row })
			rankButton.MouseButton1Click:Connect(function()
				if canRank then
					local result = State.request("rankAbility", info.id)
					if result and result.ok then
						Sounds.play("ping", if result.learned then 1.2 else 1.5, 0.5)
					end
				end
			end)
			-- espaço 1-4
			for slot = 1, 4 do
				local active = info.slot == slot
				local slotButton = UI.button({ Text = tostring(slot), AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -10 - (4 - slot) * 34, 1, -8), Size = UDim2.fromOffset(30, 26), BackgroundColor3 = if active then UI.Colors.Gold elseif learned then UI.Colors.Accent else UI.Colors.Dark, TextColor3 = if active then Color3.new(0, 0, 0) else Color3.new(1, 1, 1), Parent = row })
				slotButton.MouseButton1Click:Connect(function()
					if not learned then
						State.onError("Aprenda essa habilidade primeiro.")
						return
					end
					local result = State.request("setLoadout", slot, if active then "" else info.id)
					if result and result.ok then
						Sounds.play("equip", 1.2, 0.4)
					end
				end)
			end
		end
	end
	UI.label({ Text = "Cada rank: +15% de efeito e -6% de recarga. Você ganha 1 ponto de talento por nível.", Size = UDim2.new(1, -10, 0, 18), TextColor3 = UI.Colors.SubText, Font = Enum.Font.Gotham, LayoutOrder = 100, Parent = body })
end

local function renderTalents(data)
	local class = Classes.List[data.class]
	if not class then
		UI.label({ Text = "Escolha uma classe primeiro.", Size = UDim2.new(1, 0, 0, 24), Parent = body })
		return
	end
	header(data, class)
	local talents = data.talents or {}
	local respecPrice = if data.level >= 10 then Classes.RespecPrice else 0
	local respec = UI.button({ Text = if respecPrice > 0 then ("↺ Redistribuir pontos  💰%d"):format(respecPrice) else "↺ Redistribuir pontos (grátis até o nível 10)", Size = UDim2.new(1, -10, 0, 28), BackgroundColor3 = UI.Colors.Dark, LayoutOrder = 1, Parent = body })
	respec.MouseButton1Click:Connect(function()
		State.request("respec")
	end)
	local columns = UI.new("Frame", { Size = UDim2.new(1, -10, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 2, Parent = body }, { UI.list(8, true) })
	for index, branch in Classes.Branches[data.class] or {} do
		local spent = Classes.branchPoints(data.class, talents, branch.id)
		local column = UI.new("Frame", { Size = UDim2.new(1 / 3, -6, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = UI.Colors.PanelLight, BackgroundTransparency = 0.4, LayoutOrder = index, Parent = columns }, { UI.corner(10), UI.stroke(branch.color, 1.5, 0.3), UI.padding(6), UI.list(6) })
		UI.label({ Text = ("%s %s  •  %d pts"):format(branch.icon, branch.name, spent), Size = UDim2.new(1, 0, 0, 22), TextColor3 = branch.color, Font = Enum.Font.GothamBlack, LayoutOrder = 0, Parent = column }, { UI.textStroke(1) })
		UI.label({ Text = branch.text, Size = UDim2.new(1, 0, 0, 16), TextColor3 = UI.Colors.SubText, Font = Enum.Font.Gotham, LayoutOrder = 1, Parent = column })
		local order = 2
		for _, passive in Classes.Passives[data.class] do
			if passive.branch == branch.id then
				local rank = talents[passive.id] or 0
				local needed = Classes.TierPoints[passive.tier] or 0
				local unlocked = spent >= needed
				local canBuy = unlocked and rank < passive.max and data.skillPoints > 0
				local card = UI.new("TextButton", { Text = "", AutoButtonColor = canBuy, Size = UDim2.new(1, 0, 0, 74), BackgroundColor3 = if rank >= passive.max then Color3.fromRGB(70, 60, 25) elseif rank > 0 then Color3.fromRGB(35, 55, 45) else UI.Colors.Panel, BackgroundTransparency = if unlocked then 0.05 else 0.5, LayoutOrder = order, Parent = column }, { UI.corner(8), UI.stroke(if canBuy then UI.Colors.Gold else UI.Colors.Stroke, if canBuy then 2 else 1) })
				order += 1
				UI.label({ Text = passive.icon, Position = UDim2.fromOffset(4, 6), Size = UDim2.fromOffset(34, 34), TextXAlignment = Enum.TextXAlignment.Center, TextTransparency = if unlocked then 0 else 0.6, Parent = card })
				UI.label({ Text = passive.name, Position = UDim2.fromOffset(40, 4), Size = UDim2.new(1, -44, 0, 18), Font = Enum.Font.GothamBlack, TextColor3 = if unlocked then UI.Colors.Text else UI.Colors.SubText, Parent = card })
				UI.label({ Text = if unlocked then ("Rank %d/%d"):format(rank, passive.max) else ("🔒 %d pts no ramo"):format(needed), Position = UDim2.fromOffset(40, 22), Size = UDim2.new(1, -44, 0, 14), TextColor3 = if rank > 0 then UI.Colors.Gold else UI.Colors.SubText, Parent = card })
				UI.label({ Text = passive.text, Position = UDim2.fromOffset(6, 42), Size = UDim2.new(1, -12, 0, 28), TextScaled = false, TextSize = 13, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Font = Enum.Font.Gotham, TextColor3 = UI.Colors.SubText, Parent = card })
				card.MouseButton1Click:Connect(function()
					if canBuy then
						local result = State.request("learnTalent", passive.id)
						if result and result.ok then
							Sounds.play("ping", 1.4 + rank * 0.1, 0.5)
						end
					end
				end)
			end
		end
	end
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
	elseif win.tab == "Talentos" then
		renderTalents(data)
	elseif win.tab == "Perícias" then
		renderSkills(data)
	else
		renderStats(data)
	end
end

function Character.init(screen)
	win = Window.create(screen, { name = "Personagem", title = "🧙 PERSONAGEM", width = 780, height = 580, tabs = { "Habilidades", "Talentos", "Perícias", "Atributos" }, accent = Color3.fromRGB(150, 210, 255) })
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
