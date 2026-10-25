-- Masmorras no cliente: janela do portal (grupo, ponto de retorno, começar), janela do Mercador de
-- Masmorras (loja, itens exclusivos, progresso) e o painel do andar durante a masmorra.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Dungeons = require(Shared.Dungeons)
local Items = require(Shared.Items)
local Perks = require(Shared.Perks)

local UI = require(script.Parent.UI)
local State = require(script.Parent.State)
local Window = require(script.Parent.Window)
local Sounds = require(script.Parent.Sounds)

local DungeonWindow = {}

local portal = {} -- janela do portal
local shop = {} -- janela do mercador
local tracker = {} -- painel do andar
local currentId = nil

local function text(parent, props)
	local merged = { Size = UDim2.new(1, 0, 0, 18), TextScaled = false, TextSize = 15, TextWrapped = true, Font = Enum.Font.GothamBold }
	for key, value in props do
		merged[key] = value
	end
	return UI.label(merged)
end

local function materialName(id)
	local def = Items.Materials[id] or Items.Consumables[id]
	return if def then def.icon .. " " .. def.name else id
end

local function priceText(gold, materialId, amount)
	return ("💰 %s + %d %s"):format(UI.formatNumber(gold), amount, materialName(materialId))
end

local function dungeonInfo(data)
	return (data and data.dungeon) or {}
end

-- ===================== PORTAL =====================

local function renderPortal()
	local data = State.data
	local dungeon = currentId and Dungeons.ById[currentId]
	if not data or not dungeon then
		return
	end
	UI.clear(portal.body)
	local info = dungeonInfo(data)
	local best = (info.best and info.best[dungeon.id]) or 0
	portal.win.title.Text = ("%s %s"):format(dungeon.icon, string.upper(dungeon.name))
	text(portal.body, { Text = dungeon.text, Size = UDim2.new(1, 0, 0, 40), TextColor3 = UI.Colors.SubText, LayoutOrder = 1, Parent = portal.body })
	text(portal.body, { Text = ("Nível mínimo %d  •  recomendado %d+  •  %d andares, chefe a cada %d"):format(dungeon.minLevel, dungeon.level, Dungeons.Floors, Dungeons.BossEvery), LayoutOrder = 2, Parent = portal.body })
	text(portal.body, { Text = ("Seu recorde: %s  •  material: %s (você tem %d)"):format(if best > 0 then ("chefe do andar %d"):format(best) else "nenhum chefe ainda", materialName(dungeon.material), State.materialCount(dungeon.material)), LayoutOrder = 3, TextColor3 = UI.Colors.Gold, Parent = portal.body })
	if dungeon.key then
		local has = State.materialCount(dungeon.key)
		text(portal.body, { Text = ("Precisa de: %s (você tem %d) — quem começa gasta uma"):format(materialName(dungeon.key), has), LayoutOrder = 4, TextColor3 = if has > 0 then Color3.fromRGB(140, 230, 140) else Color3.fromRGB(255, 120, 110), Parent = portal.body })
	end
	-- grupo
	local lobby = info.lobby
	local inLobby = lobby ~= nil and lobby.id == dungeon.id
	local members = if inLobby then table.concat(lobby.members, ", ") else "você ainda não entrou no grupo"
	text(portal.body, { Text = ("👥 Grupo (%d/%d): %s"):format(if inLobby then #lobby.members else 0, Dungeons.MaxPlayers, members), Size = UDim2.new(1, 0, 0, 36), LayoutOrder = 5, Parent = portal.body })
	text(portal.body, { Text = "Quem estiver no grupo e perto do portal entra junto. A vida dos inimigos cresce com o grupo; tanque, suporte e dano fazem diferença.", Size = UDim2.new(1, 0, 0, 36), TextSize = 13, TextColor3 = UI.Colors.SubText, LayoutOrder = 6, Parent = portal.body })
	local row = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, LayoutOrder = 7, Parent = portal.body }, { UI.list(8, true) })
	local joinButton = UI.button({ Text = if inLobby then "Sair do grupo" else "Entrar no grupo", Size = UDim2.fromOffset(180, 38), BackgroundColor3 = if inLobby then Color3.fromRGB(150, 60, 60) else UI.Colors.Accent, Parent = row })
	joinButton.MouseButton1Click:Connect(function()
		if inLobby then
			State.request("dungeonLeaveLobby")
		else
			State.request("dungeonJoin", dungeon.id)
		end
	end)
	if inLobby then
		text(portal.body, { Text = "Começar no andar:", LayoutOrder = 8, Parent = portal.body })
		local floors = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1, LayoutOrder = 9, Parent = portal.body }, { UI.list(8, true) })
		for _, floor in Dungeons.startFloors(best) do
			local button = UI.button({ Text = ("Andar %d"):format(floor), Size = UDim2.fromOffset(110, 40), BackgroundColor3 = UI.Colors.Green, Parent = floors })
			button.MouseButton1Click:Connect(function()
				local result = State.request("dungeonStart", floor)
				if result and result.ok then
					Sounds.play("quest", 1, 0.6)
					portal.win:close()
				end
			end)
		end
	end
end

-- ===================== MERCADOR =====================

local function shopRow(parent, order, height)
	return UI.new("Frame", { Size = UDim2.new(1, -8, 0, height or 54), BackgroundColor3 = UI.Colors.PanelLight, BackgroundTransparency = 0.3, LayoutOrder = order, Parent = parent }, { UI.corner(10) })
end

local function renderShop()
	local data = State.data
	if not data then
		return
	end
	UI.clear(shop.list)
	shop.win.title.Text = ("🏰 MERCADOR DE MASMORRAS  •  💰 %s"):format(UI.formatNumber(data.gold))
	local wallet = {}
	for _, dungeon in Dungeons.List do
		table.insert(wallet, ("%s %d"):format(Items.Materials[dungeon.material].icon, State.materialCount(dungeon.material)))
	end
	text(shop.list, { Text = "Seus materiais de masmorra: " .. table.concat(wallet, "   "), LayoutOrder = 0, TextColor3 = UI.Colors.Gold, Parent = shop.list })
	if shop.win.tab == "Loja" then
		for i, entry in Dungeons.Shop do
			local def = Items.Consumables[entry.id] or Items.Materials[entry.id]
			local row = shopRow(shop.list, i)
			UI.label({ Text = def.icon, Position = UDim2.fromOffset(10, 8), Size = UDim2.fromOffset(38, 38), TextXAlignment = Enum.TextXAlignment.Center, Parent = row })
			local owned = if entry.kind == "consumable" then (data.consumables[entry.id] or 0) else State.materialCount(entry.id)
			local detail = if entry.kind == "key" then ("abre a %s"):format(Dungeons.ById[def.key].name) elseif def.heal then ("cura %d%% da vida"):format(math.floor(def.heal * 100)) elseif def.defenseBuff then ("+%d%% de defesa por %d s"):format(math.floor(def.defenseBuff * 100), def.buffTime) elseif def.damageBuff then ("+%d%% de dano por %d s"):format(math.floor(def.damageBuff * 100), def.buffTime) else ""
			text(row, { Text = ("%s  (você tem %d)"):format(def.name, owned), Position = UDim2.fromOffset(56, 6), Size = UDim2.new(1, -200, 0, 20), Parent = row })
			text(row, { Text = detail .. "  •  " .. priceText(entry.gold, entry.material[1], entry.material[2]), Position = UDim2.fromOffset(56, 28), Size = UDim2.new(1, -200, 0, 18), TextSize = 13, TextColor3 = UI.Colors.SubText, Parent = row })
			local button = UI.button({ Text = "Comprar", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(120, 36), BackgroundColor3 = UI.Colors.Green, Parent = row })
			button.MouseButton1Click:Connect(function()
				local result = State.request("dungeonBuy", i)
				if result and result.ok then
					Sounds.play("coin", 1, 0.5)
				end
			end)
		end
	elseif shop.win.tab == "Exclusivos" then
		local price = Dungeons.LootPrice
		text(shop.list, { Text = ("Itens que só existem nas masmorras, sempre com o perk de assinatura. Aqui saem %s; nos baús dos chefes podem sair melhores."):format(price.rarity), Size = UDim2.new(1, 0, 0, 36), TextSize = 13, TextColor3 = UI.Colors.SubText, LayoutOrder = 1, Parent = shop.list })
		local order = 2
		for _, dungeon in Dungeons.List do
			text(shop.list, { Text = dungeon.icon .. " " .. string.upper(dungeon.name), LayoutOrder = order, TextColor3 = UI.Colors.Gold, Parent = shop.list })
			order += 1
			for _, baseId in dungeon.loot do
				local base = Items.Bases[baseId]
				local perk = Perks.List[base.signature]
				local row = shopRow(shop.list, order, 58)
				order += 1
				local icon = if base.weaponType then Items.WeaponTypes[base.weaponType].icon else Items.Slots[base.slot].icon
				UI.label({ Text = icon, Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(36, 36), TextXAlignment = Enum.TextXAlignment.Center, Parent = row })
				text(row, { Text = ("%s  •  %s"):format(base.name, if base.weaponType then Items.WeaponTypes[base.weaponType].name else Items.Slots[base.slot].name), Position = UDim2.fromOffset(54, 5), Size = UDim2.new(1, -210, 0, 18), Parent = row })
				text(row, { Text = ("%s %s: %s"):format(perk.icon, perk.name, perk.text), Position = UDim2.fromOffset(54, 24), Size = UDim2.new(1, -210, 0, 30), TextSize = 12, TextColor3 = Color3.fromRGB(200, 180, 255), Parent = row })
				local button = UI.button({ Text = ("%d %s"):format(price.material, Items.Materials[dungeon.material].icon), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(140, 38), BackgroundColor3 = Color3.fromRGB(120, 70, 170), Parent = row })
				button.MouseButton1Click:Connect(function()
					local result = State.request("dungeonBuyLoot", baseId)
					if result and result.ok then
						Sounds.play("lootRare", 1, 0.6)
					end
				end)
			end
		end
		text(shop.list, { Text = ("Cada um custa 💰 %s + %d do material da masmorra dele."):format(UI.formatNumber(price.gold), price.material), LayoutOrder = order, TextColor3 = UI.Colors.SubText, Parent = shop.list })
	else
		local best = dungeonInfo(data).best or {}
		for i, dungeon in Dungeons.List do
			local reached = best[dungeon.id] or 0
			local row = shopRow(shop.list, i, 92)
			text(row, { Text = ("%s %s  •  nível %d+"):format(dungeon.icon, dungeon.name, dungeon.minLevel), Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 0, 20), TextColor3 = UI.Colors.Gold, Parent = row })
			text(row, { Text = dungeon.text, Position = UDim2.fromOffset(12, 28), Size = UDim2.new(1, -24, 0, 34), TextSize = 12, TextColor3 = UI.Colors.SubText, Parent = row })
			local bosses = {}
			for floor = Dungeons.BossEvery, Dungeons.Floors, Dungeons.BossEvery do
				table.insert(bosses, (if reached >= floor then "✔" else "•") .. " " .. floor)
			end
			text(row, { Text = ("Chefes: %s   •   %s"):format(table.concat(bosses, "  "), if dungeon.key then "precisa de " .. materialName(dungeon.key) else "entrada livre"), Position = UDim2.fromOffset(12, 66), Size = UDim2.new(1, -24, 0, 18), TextSize = 13, Parent = row })
		end
	end
end

-- ===================== PAINEL DO ANDAR =====================

local function renderTracker()
	local run = dungeonInfo(State.data).run
	tracker.frame.Visible = run ~= nil
	if not run then
		return
	end
	local dungeon = Dungeons.ById[run.id]
	tracker.title.Text = ("%s %s"):format(dungeon and dungeon.icon or "", dungeon and dungeon.name or "")
	tracker.floor.Text = ("Andar %d/%d%s"):format(run.floor, run.floors, if run.boss then "  •  👑 CHEFE" else "")
	local lines = {}
	if run.finished then
		table.insert(lines, ("🏆 Concluída! Fecha em %d s"):format(run.closesIn or 0))
	elseif run.cleared then
		table.insert(lines, if run.floor < run.floors then "✔ Andar limpo: desçam a escada" else "✔ Andar limpo")
	else
		table.insert(lines, ("⚔ %s  •  inimigos: %d"):format(run.mechanic or "", run.enemies))
	end
	if run.objective then
		table.insert(lines, "⭐ " .. run.objective)
	end
	if run.canClaim then
		table.insert(lines, "🎁 Abra o baú do chefe!")
	end
	table.insert(lines, "👥 " .. table.concat(run.members, ", "))
	tracker.body.Text = table.concat(lines, "\n")
end

-- ===================== INIT =====================

function DungeonWindow.init(screen)
	portal.win = Window.create(screen, { name = "Masmorra", title = "🏰 MASMORRA", width = 560, height = 470, accent = Color3.fromRGB(180, 120, 255) })
	portal.body = UI.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = portal.win.content }, { UI.list(8) })
	portal.win.onOpen = renderPortal

	shop.win = Window.create(screen, { name = "MercadorMasmorras", title = "🏰 MERCADOR DE MASMORRAS", width = 700, height = 520, tabs = { "Loja", "Exclusivos", "Masmorras" }, accent = Color3.fromRGB(180, 120, 255) })
	shop.list = UI.new("ScrollingFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 5, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = shop.win.content }, { UI.list(8) })
	shop.win.onOpen = renderShop
	shop.win.onTab = renderShop

	-- painel do andar (lado direito da tela)
	tracker.frame = UI.new("Frame", {
		Name = "PainelMasmorra",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 210),
		Size = UDim2.fromOffset(300, 150),
		BackgroundColor3 = UI.Colors.Panel,
		BackgroundTransparency = 0.15,
		Visible = false,
		Parent = screen,
	}, { UI.corner(10) })
	UI.ornate(tracker.frame, UI.Colors.Trim, 4)
	tracker.title = UI.label({ Text = "", Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 20), FontFace = UI.TitleFont, TextColor3 = Color3.fromRGB(255, 225, 160), Parent = tracker.frame }, { UI.textStroke(1) })
	tracker.floor = UI.label({ Text = "", Position = UDim2.fromOffset(12, 30), Size = UDim2.new(1, -24, 0, 16), TextColor3 = UI.Colors.Gold, Parent = tracker.frame })
	tracker.body = text(tracker.frame, { Text = "", Position = UDim2.fromOffset(12, 50), Size = UDim2.new(1, -24, 0, 70), TextSize = 13, TextYAlignment = Enum.TextYAlignment.Top, Parent = tracker.frame })
	local exit = UI.button({ Text = "Sair da masmorra", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -10, 1, -8), Size = UDim2.fromOffset(150, 26), BackgroundColor3 = Color3.fromRGB(150, 60, 60), Parent = tracker.frame })
	exit.MouseButton1Click:Connect(function()
		State.request("dungeonExit")
	end)

	State.Changed:Connect(function()
		renderTracker()
		if portal.win:isOpen() then
			renderPortal()
		elseif shop.win:isOpen() then
			renderShop()
		end
	end)
end

-- abre a janela do portal (pelo prompt no mapa)
function DungeonWindow.openPortal(id)
	currentId = id
	Window.closeAll()
	portal.win:open()
end

function DungeonWindow.openShop()
	shop.win:open()
end

return DungeonWindow
