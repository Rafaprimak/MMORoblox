-- Sons do jogo. Os IDs ficam no catálogo compartilhado (módulo SoundIds): cole lá os IDs da Creator Store.
-- Na abertura, Sounds.preload() testa cada ID; os que falharem usam a "reserva" (sons internos do Roblox).
local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SoundIds = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SoundIds"))

local Prefs = require(script.Parent.Prefs)

local Sounds = {}

local failed = {} -- [assetId] = true quando o ID não carregou

local function resolve(name)
	local entry = SoundIds.Effects[name]
	if not entry then
		return nil
	end
	if entry.id ~= "" and not failed[entry.id] then
		return entry.id
	end
	return if entry.reserva ~= "" then entry.reserva else nil
end

local function make(name, pitch, volume, parent)
	local id = resolve(name)
	local master = Prefs.get("volume") or 1
	if not id or master <= 0 then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.PlaybackSpeed = pitch or 1
	sound.Volume = (volume or 0.5) * master
	sound.Parent = parent
	sound:Play()
	Debris:AddItem(sound, 6)
	return sound
end

function Sounds.play(name, pitch, volume)
	make(name, pitch, volume, SoundService)
end

-- Som 3D preso a uma parte (outros jogadores e inimigos)
function Sounds.playAt(part, name, pitch, volume)
	if not part then
		return
	end
	local sound = make(name, pitch, volume, part)
	if sound then
		sound.RollOffMaxDistance = 80
	end
end

-- ID utilizável de um loop (ambiente/música) ou nil
function Sounds.loopId(category, name)
	local list = SoundIds[category]
	local entry = list and list[name]
	if entry and entry.id ~= "" and not failed[entry.id] then
		return entry.id
	end
	return nil
end

-- Testa todos os IDs preenchidos (em segundo plano). IDs quebrados passam a usar a reserva.
function Sounds.preload()
	task.spawn(function()
		local list = {}
		for _, category in { SoundIds.Effects, SoundIds.Ambience, SoundIds.Music } do
			for _, entry in category do
				if entry.id ~= "" then
					local sound = Instance.new("Sound")
					sound.SoundId = entry.id
					table.insert(list, sound)
				end
			end
		end
		if #list == 0 then
			return
		end
		pcall(function()
			ContentProvider:PreloadAsync(list, function(assetId, status)
				if status ~= Enum.AssetFetchStatus.Success then
					failed[assetId] = true
					warn("[Sons] Não carregou: " .. tostring(assetId) .. " (usando a reserva)")
				end
			end)
		end)
		for _, sound in list do
			sound:Destroy()
		end
	end)
end

return Sounds
