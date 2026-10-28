-- Som ambiente e música em loop, trocando com crossfade pela região, pela noite e perto de chefes.
-- Os IDs vêm do catálogo SoundIds (Ambience/Music). Sem ID preenchido, fica em silêncio.
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local World = require(Shared.World)
local SoundIds = require(Shared.SoundIds)
local Dungeons = require(Shared.Dungeons)

local Sounds = require(script.Parent.Sounds)
local Prefs = require(script.Parent.Prefs)
local EnemyRenderer = require(script.Parent.EnemyRenderer)

local Ambience = {}

local FADE = 2.5
local channels = {} -- [canal] = { sound, id }
local nextBird = 0
local lastCombat = -100 -- última vez que você bateu ou apanhou
local COMBAT_HOLD = 8 -- segundos de música de combate depois da última troca de golpes
local SETTLE = 3 -- a música só troca depois que a "vontade" de trocar durar isto (sem vai e volta)
local combatTrack = nil -- trilha da luta atual (fica a mesma até a luta acabar)
local wantedMusic, wantedSince, playingMusic = nil, 0, nil

-- Chamado quando você acerta um inimigo ou leva dano
function Ambience.combatPing()
	lastCombat = os.clock()
end

-- inimigo vivo mais perto (para escolher a música da luta)
local function nearestEnemy(position, range)
	local folder = workspace:FindFirstChild("Inimigos")
	local best, bestDistance = nil, range
	for _, root in if folder then folder:GetChildren() else {} do
		if root:IsA("BasePart") and not root:GetAttribute("Dead") then
			local distance = (root.Position - position).Magnitude
			if distance < bestDistance then
				best, bestDistance = root, distance
			end
		end
	end
	return best, bestDistance
end

local function baseVolume(channel)
	if channel == "music" then
		return 0.35 * (Prefs.get("musicVolume") or 0.5)
	end
	return 0.45 * (Prefs.get("volume") or 1)
end

-- troca o som de um canal com crossfade (id nil = silêncio); mult ajusta o volume daquele som
local function setChannel(channel, id, mult)
	mult = mult or 1
	local current = channels[channel]
	if current and current.id == id then
		current.sound.Volume = baseVolume(channel) * mult
		return
	end
	if current then
		local old = current.sound
		TweenService:Create(old, TweenInfo.new(FADE), { Volume = 0 }):Play()
		task.delay(FADE + 0.1, function()
			old:Destroy()
		end)
		channels[channel] = nil
	end
	if not id then
		return
	end
	local sound = Instance.new("Sound")
	sound.Name = "Loop_" .. channel
	sound.SoundId = id
	sound.Looped = true
	sound.Volume = 0
	sound.Parent = SoundService
	sound:Play()
	TweenService:Create(sound, TweenInfo.new(FADE), { Volume = baseVolume(channel) * mult }):Play()
	channels[channel] = { sound = sound, id = id }
end

function Ambience.init()
	local player = Players.LocalPlayer
	task.spawn(function()
		while true do
			task.wait(0.5)
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if root then
				local dungeonId = player:GetAttribute("Dungeon")
				local inDungeon = dungeonId ~= nil and Dungeons.ById[dungeonId] ~= nil
				local dungeonSounds = inDungeon and SoundIds.Dungeon[dungeonId]
				local region = if inDungeon then "Masmorra" else World.regionName(root.Position.X, root.Position.Z)
				local night = workspace:GetAttribute("Night") == true
				local ambienceKey = SoundIds.RegionAmbience[region] or "campo"
				if inDungeon then
					setChannel("ambience", dungeonSounds and dungeonSounds.ambience, dungeonSounds and dungeonSounds.ambienceVolume)
				else
					setChannel("ambience", Sounds.loopId("Ambience", ambienceKey))
				end
				setChannel("night", if night and not inDungeon then Sounds.loopId("Ambience", "noite") else nil)
				-- música: combate (pelo tipo do inimigo) > chefe > noite > vila > exploração
				local musicKey
				local enemy, enemyDistance = nearestEnemy(root.Position, 45)
				local fighting = os.clock() - lastCombat < COMBAT_HOLD and enemy ~= nil
				if enemy and enemyDistance < 16 and enemy:GetAttribute("Type") ~= "boneco" then
					fighting = true
					lastCombat = math.max(lastCombat, os.clock() - COMBAT_HOLD + 3)
				end
				local combatId = nil
				if fighting and enemy and enemy:GetAttribute("Type") ~= "boneco" then
					-- a trilha é escolhida no começo da luta e não muda a cada inimigo diferente
					combatTrack = combatTrack or SoundIds.Combat[enemy:GetAttribute("Type")] or SoundIds.Combat.padrao
					combatId = combatTrack
				elseif not fighting then
					combatTrack = nil
				end
				if combatId then
					musicKey = "combate"
				elseif EnemyRenderer.nearestBoss(root.Position, 130) then
					musicKey = "chefe"
				elseif night or inDungeon then
					musicKey = "noite" -- nas masmorras, a música calma e escura entre as lutas
				elseif region == "Vila Aurora" then
					musicKey = "vila"
				else
					musicKey = "exploracao"
				end
				local trackId
				if dungeonSounds then
					-- masmorra: só as trilhas dela (nada do mundo aberto)
					local fightingHere = os.clock() - lastCombat < COMBAT_HOLD and enemy ~= nil
					trackId = if EnemyRenderer.nearestBoss(root.Position, 130) then dungeonSounds.boss elseif fightingHere then dungeonSounds.combat else dungeonSounds.music
				elseif combatId then
					trackId = combatId
				else
					trackId = Sounds.loopId("Music", musicKey) or (if musicKey == "noite" then Sounds.loopId("Music", "exploracao") else nil)
				end
				-- troca só quando a escolha se mantém por SETTLE segundos (entrar em luta troca na hora)
				if trackId ~= wantedMusic then
					wantedMusic, wantedSince = trackId, os.clock()
				end
				if trackId ~= playingMusic and (os.clock() - wantedSince >= SETTLE or (combatId ~= nil and trackId == combatId)) then
					playingMusic = trackId
					setChannel("music", trackId)
				elseif trackId == playingMusic then
					setChannel("music", trackId) -- só acerta o volume
				end
				-- pássaros cantando de vez em quando (de dia, fora das montanhas)
				local now = os.clock()
				if not night and now > nextBird and ambienceKey ~= "montanha" and ambienceKey ~= "ruinas" and ambienceKey ~= "costa" then
					nextBird = now + math.random(5, 13)
					local bird = Instance.new("Sound")
					bird.SoundId = SoundIds.Birds[math.random(1, #SoundIds.Birds)]
					bird.Volume = 0.25 * (Prefs.get("volume") or 1)
					bird.PlaybackSpeed = 0.9 + math.random() * 0.25
					bird.Parent = SoundService
					bird:Play()
					game:GetService("Debris"):AddItem(bird, 4)
				end
			end
		end
	end)
end

return Ambience
