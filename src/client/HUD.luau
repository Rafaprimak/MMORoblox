-- HUD: vida/mana/estamina, habilidades com recarga, poções, XP, missões, região e barra de chefe.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local World = require(Shared.World)
local Dungeons = require(Shared.Dungeons)
local Classes = require(Shared.Classes)
local Items = require(Shared.Items)
local Quests = require(Shared.Quests)
local NPCs = require(Shared.NPCs)

local UI = require(script.Parent.UI)
local Sounds = require(script.Parent.Sounds)
local State = require(script.Parent.State)
local EnemyRenderer = require(script.Parent.EnemyRenderer)
local Sky = require(script.Parent.Sky)
local LockOn = require(script.Parent.LockOn)
local Window = require(script.Parent.Window)

local HUD = {}

local player = Players.LocalPlayer
local refs = {}
local abilitySlots = {}
local potionSlots = {}
local cooldowns = {}
local potionCooldowns = {}
local goldValue = Instance.new("NumberValue")
local lastGold, lastLevel = nil, nil
local buffIcons = {}
local cue = { start = 0, duration = 0, active = false }
local charge = { start = 0, active = false }

local BUFF_INFO = {
	grito = { icon = "mighty-horn", color = Color3.fromRGB(255, 120, 60) },
	veneno = { icon = "bubbling-flask", color = Color3.fromRGB(120, 230, 80) },
	elixir = { icon = "flame", color = Color3.fromRGB(255, 150, 40) },
	furia = { icon = "enrage", color = Color3.fromRGB(255, 70, 50) },
	foco = { icon = "eyeball", color = Color3.fromRGB(255, 220, 100) },
	escudo = { icon = "checked-shield", color = Color3.fromRGB(170, 120, 255) },
	frenesi = { icon = "enrage", color = Color3.fromRGB(220, 80, 200) },
	escudo_fe = { icon = "shield-reflect", color = Color3.fromRGB(150, 210, 255) },
	bencao = { icon = "star-swirl", color = Color3.fromRGB(255, 230, 120) },
	provocar = { icon = "enrage", color = Color3.fromRGB(255, 120, 90) },
	furia_crescente = { icon = "flame", color = Color3.fromRGB(255, 90, 40) },
}

local function slot(parent, layoutOrder, key, size)
	local frame = UI.new("Frame", { Size = UDim2.fromOffset(size, size), BackgroundColor3 = UI.Colors.Panel, BackgroundTransparency = 0.15, LayoutOrder = layoutOrder, Parent = parent }, { UI.corner(10), UI.stroke(UI.Colors.Stroke, 2) })
	local icon = UI.icon(nil, { Size = UDim2.fromScale(0.66, 0.66), Position = UDim2.fromScale(0.17, 0.08), Parent = frame })
	local keyLabel = UI.label({ Text = key, Position = UDim2.fromOffset(4, 2), Size = UDim2.fromOffset(18, 14), TextColor3 = UI.Colors.Gold, ZIndex = 3, Parent = frame }, { UI.textStroke(1) })
	local cover = UI.new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35, ZIndex = 2, Parent = frame }, { UI.corner(10) })
	local timer = UI.label({ Text = "", Size = UDim2.fromScale(1, 0.6), Position = UDim2.fromScale(0, 0.2), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 4, Parent = frame }, { UI.textStroke(2) })
	local bottom = UI.label({ Text = "", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 2, 1, -2), Size = UDim2.new(1, -4, 0, 13), TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = UI.Colors.SubText, ZIndex = 3, Parent = frame }, { UI.textStroke(1) })
	local button = UI.new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = frame })
	return { frame = frame, icon = icon, key = keyLabel, cover = cover, timer = timer, bottom = bottom, button = button, stroke = frame:FindFirstChildOfClass("UIStroke"), scale = UI.new("UIScale", { Parent = frame }) }
end

local hudCallbacks = nil

function HUD.init(screen, callbacks)
	hudCallbacks = callbacks
	-- ===== painel do jogador =====
	local panel = UI.new("Frame", { Name = "Jogador", Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(330, 112), BackgroundColor3 = UI.Colors.Panel, BackgroundTransparency = 0.12, Parent = screen }, {
		UI.corner(12),
		UI.stroke(UI.Colors.Stroke, 1.5, 0.3),
		UI.new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(160, 160, 180)), Rotation = 90 }),
	})
	UI.ornate(panel, UI.Colors.Trim, 4)
	refs.classBadge = UI.new("Frame", { Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(62, 62), BackgroundColor3 = Config.Ranks[1].color, Parent = panel }, { UI.corner(12), UI.stroke(Color3.new(1, 1, 1), 2, 0.5) })
	refs.classIcon = UI.icon("help", { Size = UDim2.fromScale(0.74, 0.74), Position = UDim2.fromScale(0.13, 0.06), Parent = refs.classBadge })
	refs.rankBadge = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 1, 2), Size = UDim2.fromOffset(40, 20), BackgroundColor3 = Config.Ranks[1].color, ZIndex = 3, Parent = refs.classBadge }, { UI.corner(6), UI.stroke(Color3.new(0, 0, 0), 1.5) })
	refs.rankScale = UI.new("UIScale", { Parent = refs.rankBadge })
	refs.rankText = UI.label({ Text = "E", Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, Font = Enum.Font.GothamBlack, ZIndex = 4, Parent = refs.rankBadge }, { UI.textStroke(1) })
	refs.name = UI.label({ Text = player.DisplayName, Position = UDim2.fromOffset(82, 6), Size = UDim2.fromOffset(240, 20), Font = Enum.Font.GothamBlack, Parent = panel }, { UI.textStroke(1) })
	local _, hpFill, hpText = UI.bar(panel, { Position = UDim2.fromOffset(82, 30), Size = UDim2.fromOffset(238, 18), color = UI.Colors.Health })
	local _, manaFill, manaText = UI.bar(panel, { Position = UDim2.fromOffset(82, 52), Size = UDim2.fromOffset(238, 13), color = UI.Colors.Mana })
	local staminaBack, staminaFill, staminaText = UI.bar(panel, { Position = UDim2.fromOffset(82, 69), Size = UDim2.fromOffset(238, 13), color = UI.Colors.Stamina })
	refs.hpFill, refs.hpText = hpFill, hpText
	refs.manaFill, refs.manaText = manaFill, manaText
	refs.staminaFill, refs.staminaText, refs.staminaBack = staminaFill, staminaText, staminaBack
	UI.icon("two-coins", { Position = UDim2.fromOffset(80, 86), Size = UDim2.fromOffset(22, 22), Color = UI.Colors.Gold, Parent = panel })
	refs.gold = UI.label({ Text = "0", Position = UDim2.fromOffset(106, 87), Size = UDim2.fromOffset(96, 20), TextColor3 = UI.Colors.Gold, Font = Enum.Font.GothamBlack, Parent = panel }, { UI.textStroke(1) })
	refs.goldScale = UI.new("UIScale", { Parent = refs.gold })
	refs.points = UI.label({ Text = "", Position = UDim2.fromOffset(200, 88), Size = UDim2.fromOffset(120, 18), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = Color3.fromRGB(150, 230, 255), Parent = panel }, { UI.textStroke(1) })
	goldValue.Changed:Connect(function(value)
		refs.gold.Text = UI.formatNumber(value)
	end)
	refs.buffs = UI.new("Frame", { Position = UDim2.fromOffset(12, 130), Size = UDim2.fromOffset(330, 30), BackgroundTransparency = 1, Parent = screen }, { UI.list(4, true) })

	-- ===== barra de XP (rodapé) =====
	local xpBack, xpFill, xpText = UI.bar(screen, { Position = UDim2.new(0.5, -300, 1, -14), Size = UDim2.fromOffset(600, 10), color = UI.Colors.Xp, radius = 4, text = false })
	xpBack.AnchorPoint = Vector2.new(0, 0)
	refs.xpFill = xpFill
	refs.xpText = UI.label({ Text = "", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -16), Size = UDim2.fromOffset(400, 14), TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = UI.Colors.SubText, Parent = screen }, { UI.textStroke(1) })
	local _ = xpText

	-- ===== barra de ações =====
	local bar = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -34), Size = UDim2.fromOffset(470, 64), BackgroundTransparency = 1, Parent = screen }, { UI.list(6, true, Enum.HorizontalAlignment.Center) })
	for i = 1, 4 do
		local s = slot(bar, i, tostring(i), 62)
		abilitySlots[i] = s
		s.button.MouseButton1Click:Connect(function()
			callbacks.onAbility(i)
		end)
	end
	UI.new("Frame", { Size = UDim2.fromOffset(10, 62), BackgroundTransparency = 1, LayoutOrder = 5, Parent = bar })
	for i, id in { "pocao_vida", "pocao_mana", "pocao_vigor" } do
		local def = Items.Consumables[id]
		local s = slot(bar, 5 + i, def.key, 52)
		UI.setIcon(s.icon, def.icon)
		s.iconName = def.icon
		potionSlots[id] = s
		s.button.MouseButton1Click:Connect(function()
			State.action("potion", id)
		end)
	end

	-- ===== retículo: segue o mouse (ou o alvo travado) e carrega as barras de ritmo e de carga =====
	-- vermelho = cedo demais (quebra o combo) • branco = espere • verde = clique agora ("Ritmo!")
	local reticle = UI.new("Frame", { Name = "Reticulo", AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(120, 60), BackgroundTransparency = 1, Parent = screen })
	refs.reticle = reticle
	refs.ring = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromOffset(26, 26), BackgroundTransparency = 1, Visible = false, Parent = reticle }, { UI.corner(13), UI.stroke(Color3.new(1, 1, 1), 2, 0.2) })
	refs.ringStroke = refs.ring:FindFirstChildOfClass("UIStroke")
	local cueFrame = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 20), Size = UDim2.fromOffset(110, 8), BackgroundColor3 = Color3.fromRGB(12, 12, 18), BackgroundTransparency = 0.25, Visible = false, Parent = reticle }, { UI.corner(4), UI.stroke(Color3.new(0, 0, 0), 1, 0.4) })
	refs.cueEarly = UI.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.fromRGB(150, 60, 60), BackgroundTransparency = 0.3, Parent = cueFrame }, { UI.corner(6) })
	refs.cueGood = UI.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.fromRGB(80, 220, 110), BackgroundTransparency = 0.25, Parent = cueFrame }, { UI.corner(6) })
	refs.cueMarker = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(0, 4, 1, 8), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 3, Parent = cueFrame }, { UI.corner(2) })
	refs.cueFrame = cueFrame
	local chargeBack, chargeFill, chargeText = UI.bar(reticle, { Position = UDim2.new(0.5, -60, 0, 32), Size = UDim2.fromOffset(120, 14), color = Color3.fromRGB(255, 150, 50), text = "CARREGANDO" })
	chargeBack.Visible = false
	refs.chargeBack, refs.chargeFill, refs.chargeText = chargeBack, chargeFill, chargeText

	-- ===== rastreador de missões =====
	local tracker = UI.new("Frame", { Name = "Missoes", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 150), Size = UDim2.fromOffset(300, 40), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = UI.Colors.Panel, BackgroundTransparency = 0.3, Parent = screen }, { UI.corner(12), UI.stroke(UI.Colors.Stroke, 1.5, 0.4), UI.padding(10), UI.list(3) })
	refs.tracker = tracker

	-- ===== relógio do dia =====
	refs.clock = UI.label({ Text = "", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 122), Size = UDim2.fromOffset(300, 22), TextXAlignment = Enum.TextXAlignment.Right, Font = Enum.Font.GothamBlack, Parent = screen }, { UI.textStroke(1.5) })

	-- ===== nome da região e barra de chefe =====
	refs.region = UI.label({ Text = "", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 14), Size = UDim2.fromOffset(500, 34), TextXAlignment = Enum.TextXAlignment.Center, Font = Enum.Font.GothamBlack, TextColor3 = Color3.fromRGB(255, 240, 200), TextTransparency = 1, Parent = screen })
	refs.regionStroke = UI.textStroke(2)
	refs.regionStroke.Transparency = 1
	refs.regionStroke.Parent = refs.region
	local bossFrame = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 52), Size = UDim2.fromOffset(460, 40), BackgroundTransparency = 1, Visible = false, Parent = screen })
	refs.bossName = UI.label({ Text = "", Size = UDim2.new(1, 0, 0, 18), TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = Color3.fromRGB(255, 100, 80), Font = Enum.Font.GothamBlack, Parent = bossFrame }, { UI.textStroke(1.5) })
	local _, bossFill, bossText = UI.bar(bossFrame, { Position = UDim2.fromOffset(0, 20), Size = UDim2.new(1, 0, 0, 16), color = Color3.fromRGB(200, 40, 40) })
	refs.bossFrame, refs.bossFill, refs.bossText = bossFrame, bossFill, bossText

	-- ===== botões do menu =====
	-- ícones: "backpack", "wizard-face", "scroll-unfurled", "treasure-map", "present", "horse-head", "star-formation", "paw-print", "sands-of-time", "crossed-swords", "cog", "help"
	local menu = UI.new("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 12, 0.5, 20), Size = UDim2.fromOffset(150, 400), BackgroundTransparency = 1, Parent = screen }, { UI.list(4) })
	local entries = {
		{ "Inventário", "I", callbacks.onInventory, nil, "backpack" },
		{ "Personagem", "C", callbacks.onCharacter, nil, "wizard-face" },
		{ "Missões", "J", callbacks.onQuests, nil, "scroll-unfurled" },
		{ "Mapa", "M", callbacks.onMap, nil, "treasure-map" },
		{ "Baús", "B", callbacks.onChest, nil, "present" },
		{ "Montar", "H", function()
			State.action("mount")
		end, nil, "horse-head" },
		{ "Jornada", "K", callbacks.onJourney, "journey", "star-formation" },
		{ "Pets", "G", callbacks.onPets, nil, "paw-print" },
		{ "Presentes", "U", callbacks.onPlaytime, "playtime", "sands-of-time" },
		{ "Auto Caçar", "N", callbacks.onAutoHunt, "autohunt", "crossed-swords" },
		{ "Configurações", "P", callbacks.onSettings, nil, "cog" },
	}
	for i, entry in entries do
		local button = UI.button({ Text = entry[1] .. "  [" .. entry[2] .. "]", Size = UDim2.fromOffset(150, 27), LayoutOrder = i, BackgroundColor3 = UI.Colors.PanelLight, TextXAlignment = Enum.TextXAlignment.Left, Parent = menu })
		button.MouseButton1Click:Connect(entry[3])
		-- ícone à esquerda do texto
		local pad = button:FindFirstChildOfClass("UIPadding") or UI.new("UIPadding", { Parent = button })
		pad.PaddingLeft = UDim.new(0, 30)
		UI.icon(entry[5], { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, -25, 0.5, 0), Size = UDim2.fromOffset(20, 20), ZIndex = button.ZIndex + 1, Parent = button })
		if entry[4] then
			refs.menuButtons = refs.menuButtons or {}
			refs.menuButtons[entry[4]] = { button = button, text = button.Text }
		end
	end
	refs.devPanel = UI.new("Frame", { Size = UDim2.fromOffset(150, 150), BackgroundTransparency = 1, LayoutOrder = 10, Visible = false, Parent = menu }, { UI.list(3) })
	UI.label({ Text = "TESTE (só Studio)", Size = UDim2.fromOffset(150, 14), TextColor3 = UI.Colors.SubText, LayoutOrder = 0, Parent = refs.devPanel }, { UI.textStroke(1) })
	for i, entry in { { "+5.000 XP", "xp" }, { "+5.000 Ouro", "gold" }, { "+Materiais", "materials" }, { "+Perícias", "skills" }, { "Pular dia/noite", "night" } } do
		local button = UI.button({ Text = entry[1], Size = UDim2.fromOffset(150, 24), LayoutOrder = i, BackgroundColor3 = UI.Colors.Dark, Parent = refs.devPanel })
		button.MouseButton1Click:Connect(function()
			State.request("dev", entry[2])
		end)
	end

	-- ===== atualização contínua =====
	local lastRegion = nil
	local regionCheck = 0
	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			UI.setBar(refs.hpFill, humanoid.Health / math.max(humanoid.MaxHealth, 1))
			refs.hpText.Text = ("%s / %s"):format(UI.formatNumber(humanoid.Health), UI.formatNumber(humanoid.MaxHealth))
		end
		local mana, maxMana = player:GetAttribute("Mana") or 0, player:GetAttribute("MaxMana") or 1
		local stamina, maxStamina = player:GetAttribute("Stamina") or 0, player:GetAttribute("MaxStamina") or 1
		UI.setBar(refs.manaFill, mana / maxMana)
		refs.manaText.Text = ("%d / %d"):format(mana, maxMana)
		UI.setBar(refs.staminaFill, stamina / maxStamina)
		refs.staminaText.Text = ("%d / %d"):format(stamina, maxStamina)

		for i, s in abilitySlots do
			local cd = cooldowns[i]
			if cd and now < cd.untilTime then
				local remaining = cd.untilTime - now
				s.cover.Size = UDim2.fromScale(1, remaining / cd.duration)
				s.timer.Text = if remaining > 1 then tostring(math.ceil(remaining)) else ("%.1f"):format(remaining)
			elseif cd then
				cooldowns[i] = nil
				s.cover.Size = UDim2.fromScale(1, 0)
				s.timer.Text = ""
				UI.pulse(s.scale, 1.15)
			end
		end
		for id, s in potionSlots do
			local cd = potionCooldowns[id]
			if cd and now < cd.untilTime then
				s.cover.Size = UDim2.fromScale(1, (cd.untilTime - now) / cd.duration)
			elseif cd then
				potionCooldowns[id] = nil
				s.cover.Size = UDim2.fromScale(1, 0)
			end
		end

		-- retículo: no alvo travado, no centro (celular) ou no mouse
		local locked = LockOn.target()
		local position = nil
		if locked then
			local point, onScreen = workspace.CurrentCamera:WorldToViewportPoint(LockOn.aimPoint(locked))
			if onScreen then
				position = Vector2.new(point.X, point.Y) - GuiService:GetGuiInset()
			end
		end
		if not position then
			if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
				local viewport = workspace.CurrentCamera.ViewportSize
				position = Vector2.new(viewport.X / 2, viewport.Y * 0.42)
			else
				position = UserInputService:GetMouseLocation() - GuiService:GetGuiInset()
			end
		end
		refs.reticle.Position = UDim2.fromOffset(position.X, position.Y)
		refs.reticle.Visible = not Window.anyOpen()
		refs.ring.Visible = locked ~= nil or cue.active or charge.active
		refs.ringStroke.Color = if locked then Color3.fromRGB(255, 80, 70) else Color3.new(1, 1, 1)

		-- barra de ritmo
		if cue.active then
			local total = cue.duration + Config.RhythmWindow
			local elapsed = now - cue.start
			if elapsed > total + 0.05 then
				cue.active = false
				refs.cueFrame.Visible = false
			else
				refs.cueEarly.Size = UDim2.fromScale(cue.duration * Config.FumbleFraction / total, 1)
				refs.cueGood.Position = UDim2.fromScale(cue.duration / total, 0)
				refs.cueGood.Size = UDim2.fromScale(Config.RhythmWindow / total, 1)
				refs.cueMarker.Position = UDim2.fromScale(math.clamp(elapsed / total, 0, 1), 0.5)
				refs.cueMarker.BackgroundColor3 = if elapsed >= cue.duration then Color3.fromRGB(140, 255, 160) else Color3.new(1, 1, 1)
			end
		end
		-- barra de carga
		if charge.active then
			local ratio = math.clamp((now - charge.start) / Config.HeavyChargeTime, 0, 1)
			UI.setBar(refs.chargeFill, ratio)
			refs.chargeText.Text = if ratio >= 1 then "MÁXIMO! SOLTE" else ("%d%%"):format(math.floor(ratio * 100))
			refs.chargeFill.BackgroundColor3 = if ratio >= 1 then Color3.fromRGB(255, 80, 60) else Color3.fromRGB(255, 150, 50)
		end

		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and now > regionCheck then
			regionCheck = now + 0.5
			local night = Sky.isNight()
			refs.clock.Text = Sky.label() .. (if night then "  •  noite: inimigos mais fortes" else "")
			refs.clock.TextColor3 = if night then Color3.fromRGB(170, 180, 255) else Color3.fromRGB(255, 235, 170)
			local dungeonId = player:GetAttribute("Dungeon")
			local dungeon = dungeonId and Dungeons.ById[dungeonId]
			local name = if dungeon then dungeon.name else World.regionName(root.Position.X, root.Position.Z)
			if name ~= lastRegion then
				lastRegion = name
				refs.region.Text = "— " .. name .. " —"
				refs.region.TextTransparency = 0
				refs.regionStroke.Transparency = 0.2
				task.delay(2.5, function()
					if refs.region.Text == "— " .. name .. " —" then
						UI.tween(refs.region, 1, { TextTransparency = 1 })
						UI.tween(refs.regionStroke, 1, { Transparency = 1 })
					end
				end)
			end
			local boss = EnemyRenderer.nearestBoss(root.Position, 130)
			refs.bossFrame.Visible = boss ~= nil
			if boss then
				local hp, maxHp = boss.root:GetAttribute("Hp") or 0, boss.root:GetAttribute("MaxHp") or 1
				refs.bossName.Text = boss.def.name
				UI.setBar(refs.bossFill, hp / maxHp, true)
				refs.bossText.Text = ("%s / %s"):format(UI.formatNumber(hp), UI.formatNumber(maxHp))
			end
		end
	end)
end

function HUD.setCooldown(slot, duration)
	if duration <= 0 then
		cooldowns[slot] = { untilTime = 0, duration = 1 }
		return
	end
	cooldowns[slot] = { untilTime = os.clock() + duration, duration = duration }
end

function HUD.showAttackCue(duration)
	cue.start = os.clock()
	cue.duration = duration
	cue.active = true
	refs.cueFrame.Visible = true
end

function HUD.flashFumble()
	refs.cueFrame.BackgroundColor3 = Color3.fromRGB(150, 40, 40)
	UI.tween(refs.cueFrame, 0.35, { BackgroundColor3 = Color3.fromRGB(12, 12, 18) })
end

function HUD.setCharge(active)
	charge.active = active
	charge.start = os.clock()
	refs.chargeBack.Visible = active
	if active then
		UI.setBar(refs.chargeFill, 0)
	end
end

function HUD.setPotionCooldown(id, duration)
	potionCooldowns[id] = { untilTime = os.clock() + duration, duration = duration }
end

function HUD.flashStamina()
	refs.staminaBack.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
	UI.tween(refs.staminaBack, 0.5, { BackgroundColor3 = Color3.fromRGB(12, 12, 18) })
end

function HUD.addBuff(id, duration)
	local info = BUFF_INFO[id] or { icon = "star-formation", color = UI.Colors.Gold }
	if not buffIcons[id] then
		Sounds.play("powerUp", 1, 0.4)
	end
	local old = buffIcons[id]
	if old then
		old:Destroy()
	end
	local frame = UI.new("Frame", { Size = UDim2.fromOffset(30, 30), BackgroundColor3 = UI.Colors.Panel, BackgroundTransparency = 0.2, Parent = refs.buffs }, { UI.corner(6), UI.stroke(info.color, 2) })
	UI.icon(info.icon, { Size = UDim2.fromScale(0.8, 0.8), Position = UDim2.fromScale(0.1, 0.1), Color = info.color:Lerp(Color3.new(1, 1, 1), 0.35), Parent = frame })
	buffIcons[id] = frame
	task.delay(duration, function()
		if buffIcons[id] == frame then
			buffIcons[id] = nil
		end
		frame:Destroy()
	end)
end

local function objectiveLine(parent, order, text, progress, amount, done)
	UI.label({
		Text = (if done then "✔ " else "• ") .. text .. (if amount > 1 and not done then ("  %s/%s"):format(UI.formatNumber(progress), UI.formatNumber(amount)) else ""),
		Size = UDim2.new(1, 0, 0, 16),
		TextColor3 = if done then UI.Colors.Green else UI.Colors.Text,
		LayoutOrder = order,
		Font = Enum.Font.GothamBold,
		Parent = parent,
	}, { UI.textStroke(1) })
end

local function updateTracker(data)
	local tracker = refs.tracker
	UI.clear(tracker)
	local quests = data.quests
	UI.label({ Text = "MISSÕES  (J)", Size = UDim2.new(1, 0, 0, 18), TextColor3 = UI.Colors.Gold, Font = Enum.Font.GothamBlack, LayoutOrder = 0, Parent = tracker }, { UI.textStroke(1) })
	if not quests or #quests.active == 0 then
		local hint = "Procure NPCs com ! na cabeça"
		UI.label({ Text = hint, Size = UDim2.new(1, 0, 0, 16), TextColor3 = UI.Colors.SubText, LayoutOrder = 1, Parent = tracker })
		return
	end
	local order = 1
	local tracked = nil
	for _, entry in quests.active do
		if entry.id == quests.tracked then
			tracked = entry
		end
	end
	tracked = tracked or quests.active[1]
	local def = Quests.ById[tracked.id]
	if def then
		UI.label({ Text = def.name, Size = UDim2.new(1, 0, 0, 18), Font = Enum.Font.GothamBlack, LayoutOrder = order, Parent = tracker }, { UI.textStroke(1) })
		order += 1
		if tracked.ready and def.turnIn then
			local npc = NPCs.ById[def.turnIn]
			objectiveLine(tracker, order, "Fale com " .. (if npc then npc.name else "?"), 1, 1, false)
			order += 1
		else
			for i, objective in def.objectives do
				local progress = tracked.objectives[i]
				objectiveLine(tracker, order, objective.text, progress.progress, progress.amount, progress.progress >= progress.amount)
				order += 1
			end
		end
	end
	local others = 0
	for _, entry in quests.active do
		if entry ~= tracked and others < 3 then
			local otherDef = Quests.ById[entry.id]
			if otherDef then
				others += 1
				UI.label({ Text = (if entry.ready then "! " else "◦ ") .. otherDef.name, Size = UDim2.new(1, 0, 0, 15), TextColor3 = if entry.ready then UI.Colors.Gold else UI.Colors.SubText, Font = Enum.Font.Gotham, LayoutOrder = order, Parent = tracker })
				order += 1
			end
		end
	end
end

function HUD.update(data)
	local class = Classes.List[data.class]
	local rank = Config.getRank(data.level)
	UI.setIcon(refs.classIcon, if class then class.icon else "help")
	refs.classBadge.BackgroundColor3 = if class then class.color else UI.Colors.Dark
	refs.rankBadge.BackgroundColor3 = rank.color
	if refs.rankText.Text ~= rank.name and lastLevel then
		UI.pulse(refs.rankScale, 1.6)
	end
	refs.rankText.Text = rank.name
	refs.name.Text = ("%s  •  Nv. %d %s"):format(player.DisplayName, data.level, if class then class.name else "")
	refs.points.Text = if data.skillPoints > 0 then ("%d ponto(s) [C]"):format(data.skillPoints) else ""

	if lastLevel and data.level > lastLevel then
		refs.xpFill.Size = UDim2.fromScale(0, 1)
	end
	UI.setBar(refs.xpFill, data.xp / math.max(data.xpNext, 1), true)
	refs.xpText.Text = ("Nível %d  •  %s / %s XP"):format(data.level, UI.formatNumber(data.xp), UI.formatNumber(data.xpNext))
	lastLevel = data.level

	if lastGold == nil then
		goldValue.Value = data.gold
		refs.gold.Text = UI.formatNumber(data.gold)
	elseif data.gold ~= lastGold then
		TweenService:Create(goldValue, TweenInfo.new(0.6, Enum.EasingStyle.Quad), { Value = data.gold }):Play()
		if data.gold > lastGold then
			UI.pulse(refs.goldScale, 1.25)
		end
	end
	lastGold = data.gold

	for i, s in abilitySlots do
		local info = data.abilities and data.abilities[i]
		local ability = info and Classes.Abilities[info.id]
		if ability then
			UI.setIcon(s.icon, ability.icon, if info.unlocked then UI.Colors.Icon else UI.Colors.SubText, if info.unlocked then 0 else 0.45)
			s.bottom.Text = if info.unlocked then ("R%d • %d"):format(info.rank, ability.mana) else ("Nv. %d"):format(ability.unlock)
			s.stroke.Color = if info.unlocked then UI.Colors.Mana else UI.Colors.Stroke
		else
			UI.setIcon(s.icon, nil)
			s.bottom.Text = ""
		end
	end
	for id, s in potionSlots do
		local count = data.consumables and data.consumables[id] or 0
		s.bottom.Text = "x" .. count
		UI.setIcon(s.icon, s.iconName, nil, if count > 0 then 0 else 0.55)
	end
	updateTracker(data)
	refs.devPanel.Visible = data.isStudio == true
	-- presentes de tempo prontos e Auto Caçar (VIP)
	local playtime = refs.menuButtons and refs.menuButtons.playtime
	if playtime and hudCallbacks and hudCallbacks.playtimeReady then
		local ready = hudCallbacks.playtimeReady()
		playtime.button.Text = playtime.text .. (if ready > 0 then ("  !%d"):format(ready) else "")
		playtime.button.BackgroundColor3 = if ready > 0 then Color3.fromRGB(120, 95, 25) else UI.Colors.PanelLight
	end
	local auto = refs.menuButtons and refs.menuButtons.autohunt
	if auto then
		local player = game:GetService("Players").LocalPlayer
		local on = player:GetAttribute("AutoFarm") == true
		auto.button.Text = auto.text .. (if on then "  ✔" elseif not player:GetAttribute("Vip") then "  VIP" else "")
		auto.button.BackgroundColor3 = if on then Color3.fromRGB(40, 110, 60) else UI.Colors.PanelLight
	end
	-- aviso de recompensa para resgatar na Jornada
	local journey = refs.menuButtons and refs.menuButtons.journey
	if journey then
		local progress = data.progress
		local claim = progress ~= nil and (progress.login.canClaim or progress.pass.tier > progress.pass.claimed)
		journey.button.Text = journey.text .. (if claim then "  !" else "")
		journey.button.BackgroundColor3 = if claim then Color3.fromRGB(120, 95, 25) else UI.Colors.PanelLight
	end
end

return HUD
