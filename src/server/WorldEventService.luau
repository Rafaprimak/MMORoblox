-- Eventos do mundo aberto (motivo para os jogadores se juntarem):
--   * CHEFE DE MUNDO: de tempos em tempos (Config.WorldBossInterval) um chefe aparece num ponto do mapa,
--     com vida que cresce com o número de jogadores no servidor. Aviso para todos, marcador no mapa e no
--     HUD. Quem ajudou a derrotar (dano ou suporte) ganha ouro extra e um baú de prata; se ninguém
--     derrotar a tempo, ele vai embora.
--   * INVASÃO NOTURNA: quando a noite cai (e há jogadores), monstros atacam a entrada norte da vila em
--     3 ondas (a última com um capitão). Quem defendeu ganha ouro e um baú.
-- O cliente lê o evento atual nos atributos do workspace: EventKind ("boss" | "invasion" | nil),
-- EventName, EventPlace, EventX, EventZ, EventEnds (horário do servidor), EventWave, EventWaves.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local World = require(Shared.World)
local Points = require(Shared.Points)
local TownPlan = require(Shared.TownPlan)
local Enemies = require(Shared.Enemies)
local Remotes = require(Shared.Remotes)

local EnemyService = require(script.Parent.EnemyService)
local PlayerService = require(script.Parent.PlayerService)
local ShopService = require(script.Parent.ShopService)

local WorldEventService = {}

WorldEventService.QuestHook = function(_player, _kind, _target, _amount) end

local S = World.Scale

-- chefes possíveis: ponto do mapa (projeto) e nome do lugar
local BOSSES = {
	{ boss = "rainha_aranha", place = "Bosque Sombrio", x = 230, z = -40 },
	{ boss = "senhor_ossos", place = "Planalto das Ruínas", x = -230, z = -30 },
	{ boss = "guardiao_cripta", place = "Campos Verdejantes", x = 70, z = 20 },
	{ boss = "capitao_goblin", place = "Encruzilhada", x = -60, z = -20 },
	{ boss = "colosso_abismo", place = "Sopé das Montanhas", x = 150, z = -240 },
}
local WORLD_BOSS = "behemoth_mana" -- chefe próprio do evento (modelo e vida feitos para ~20 jogadores)
local BOSS_DURATION = 15 * 60
local BOSS_RADIUS = 34

local current = nil -- evento em andamento

local function setEvent(info)
	workspace:SetAttribute("EventKind", info and info.kind or nil)
	workspace:SetAttribute("EventName", info and info.name or nil)
	workspace:SetAttribute("EventPlace", info and info.place or nil)
	workspace:SetAttribute("EventX", info and info.x or nil)
	workspace:SetAttribute("EventZ", info and info.z or nil)
	workspace:SetAttribute("EventEnds", info and info.ends or nil)
	workspace:SetAttribute("EventWave", info and info.wave or nil)
	workspace:SetAttribute("EventWaves", info and info.waves and #info.waves or nil)
end

local function announce(text, sub, color)
	Remotes.Notify:FireAllClients({ kind = "announce", text = text, sub = sub, color = color })
end

local function playerCount()
	return #Players:GetPlayers()
end

-- recompensa de quem participou (dano, suporte ou estava lutando perto)
local function rewardParticipants(participants, gold, chest, label, event)
	for player in participants do
		if player.Parent == Players then
			WorldEventService.QuestHook(player, event, nil, 1)
			PlayerService.addGold(player, gold)
			ShopService.grant(player, chest)
			Remotes.Notify:FireClient(player, { kind = "banner", text = label, sub = ("+%d de ouro e um baú de %s"):format(gold, chest), color = Color3.fromRGB(255, 215, 120), duration = 5 })
		end
	end
end

-- ===================== CHEFE DE MUNDO =====================

local function startBoss()
	if current then
		return
	end
	local choice = BOSSES[math.random(1, #BOSSES)]
	local def = Enemies.Defs[WORLD_BOSS]
	if not def then
		return
	end
	local x, z = Points.resolve(choice.x * S, choice.z * S)
	local camp = { id = "evento_chefe", center = Vector2.new(x, z), radius = BOSS_RADIUS, worldEvent = "boss" }
	local players = playerCount()
	local rec = EnemyService.spawn(camp, WORLD_BOSS, {
		position = Vector3.new(x, World.height(x, z), z),
		-- vida fixa para ~20 caçadores; só cresce se o servidor tiver mais gente que isso
		hpMult = math.max(1, players / 20),
		levelBonus = 3,
		damageMult = 1.15,
		rewardMult = 5,
	})
	if not rec then
		return
	end
	current = { kind = "boss", name = def.name, place = choice.place, x = x, z = z, ends = workspace:GetServerTimeNow() + BOSS_DURATION, camp = camp, rec = rec, participants = {} }
	setEvent(current)
	announce(("CHEFE DE MUNDO: %s apareceu no %s!"):format(def.name, choice.place), "Junte-se aos outros caçadores (marcado no mapa)", Color3.fromRGB(255, 120, 70))
end

local function endBoss(defeated)
	local event = current
	current = nil
	setEvent(nil)
	if not event then
		return
	end
	if defeated then
		local count = 0
		for _ in event.participants do
			count += 1
		end
		announce(("%s foi derrotado por %d caçador(es)!"):format(event.name, count), "Os participantes ganharam baús", Color3.fromRGB(120, 230, 140))
		rewardParticipants(event.participants, 2500, "real", "CHEFE DE MUNDO DERROTADO!", "worldBoss")
	else
		EnemyService.despawn(event.rec)
		announce(("%s voltou para as sombras..."):format(event.name), "Ninguém conseguiu derrotá-lo a tempo", Color3.fromRGB(180, 160, 200))
	end
end

-- ===================== INVASÃO NOTURNA =====================

local function invasionWaves(averageLevel)
	if averageLevel < 9 then
		return { { goblin = 5 }, { goblin = 4, goblin_arqueiro = 2 }, { goblin = 4, goblin_arqueiro = 2, capitao_goblin = 1 } }
	elseif averageLevel < 14 then
		return { { goblin = 4, goblin_arqueiro = 3 }, { esqueleto = 4, esqueleto_mago = 1 }, { esqueleto = 4, esqueleto_mago = 2, capitao_goblin = 1 } }
	end
	return { { esqueleto = 5, esqueleto_mago = 2 }, { esqueleto = 4, esqueleto_mago = 2, golem = 1 }, { esqueleto = 4, esqueleto_mago = 3, senhor_ossos = 1 } }
end

local function averageLevel()
	local total, count = 0, 0
	for _, player in Players:GetPlayers() do
		total += player:GetAttribute("Level") or 1
		count += 1
	end
	return if count > 0 then total / count else 1
end

local function spawnWave(event)
	local wave = event.waves[event.wave]
	for enemyId, amount in wave do
		for _ = 1, amount do
			EnemyService.spawn(event.camp, enemyId, { levelBonus = 1, hpMult = 1 + 0.15 * playerCount() })
		end
	end
	setEvent(event)
	announce(("INVASÃO: onda %d de %d na entrada norte da vila!"):format(event.wave, #event.waves), "Defendam a Vila Aurora!", Color3.fromRGB(255, 100, 80))
end

local function startInvasion()
	if current or playerCount() == 0 then
		return
	end
	local P = World.PropScale
	-- fora do arco norte da vila
	local x = World.TownCenter.X
	local z = World.TownCenter.Z + (TownPlan.ArchZ - 40) * P
	local camp = { id = "evento_invasao", center = Vector2.new(x, z), radius = 26, worldEvent = "invasion" }
	local waves = invasionWaves(averageLevel())
	current = { kind = "invasion", name = "Invasão da Vila", place = "Entrada norte da vila", x = x, z = z, ends = workspace:GetServerTimeNow() + 8 * 60, camp = camp, wave = 1, waves = waves, participants = {}, nextCheck = os.clock() + 5 }
	current.waves = waves
	spawnWave(current)
end

local function endInvasion(won)
	local event = current
	current = nil
	setEvent(nil)
	if not event then
		return
	end
	EnemyService.clearCamp(event.camp)
	if won then
		announce("A VILA FOI DEFENDIDA!", "Os defensores ganharam baús", Color3.fromRGB(120, 230, 140))
		rewardParticipants(event.participants, 400, "prata", "VILA DEFENDIDA!", "invasion")
	else
		announce("Os invasores recuaram com o amanhecer...", nil, Color3.fromRGB(180, 160, 200))
	end
end

-- ===================== GANCHOS =====================

-- chamado pelo init.server no OnKilled de qualquer inimigo
function WorldEventService.onKilled(rec, contributors)
	local event = current
	if not event or rec.camp ~= event.camp then
		return
	end
	for player in contributors do
		event.participants[player] = true
	end
	if event.kind == "boss" and rec == event.rec then
		endBoss(true)
	end
end

-- teste no Studio (painel de teste): começa um evento agora
function WorldEventService.forceBoss()
	pcall(startBoss)
end

function WorldEventService.forceInvasion()
	pcall(startInvasion)
end

function WorldEventService.start()
	-- primeiro chefe alguns minutos depois de abrir o servidor; depois no intervalo
	task.spawn(function()
		task.wait(Config.WorldBossFirst)
		while true do
			if playerCount() > 0 then
				pcall(startBoss)
			end
			task.wait(Config.WorldBossInterval)
		end
	end)
	-- invasão: não é toda noite. Depois de uma, passam pelo menos Config.InvasionGapNights noites;
	-- depois disso, cada noite tem Config.InvasionChance de chance
	local nightsSince = Config.InvasionGapNights
	workspace:GetAttributeChangedSignal("Night"):Connect(function()
		if workspace:GetAttribute("Night") then
			nightsSince += 1
			if nightsSince > Config.InvasionGapNights and math.random() < Config.InvasionChance then
				nightsSince = 0
				task.delay(20, function()
					pcall(startInvasion)
				end)
			end
		elseif current and current.kind == "invasion" then
			endInvasion(false)
		end
	end)
	-- andamento (fim do tempo, próxima onda)
	task.spawn(function()
		while true do
			task.wait(2)
			local event = current
			if event then
				if workspace:GetServerTimeNow() > event.ends then
					if event.kind == "boss" then
						endBoss(false)
					else
						endInvasion(false)
					end
				elseif event.kind == "invasion" and EnemyService.aliveInCamp(event.camp) == 0 then
					if event.wave >= #event.waves then
						endInvasion(true)
					else
						event.wave += 1
						spawnWave(event)
					end
				end
			end
		end
	end)
end

return WorldEventService
