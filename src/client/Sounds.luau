-- Sons do jogo. Cada som tem um "id" (cole aqui um rbxassetid://... da Creator Store para trocar)
-- e um "reserva" com um dos poucos arquivos que ainda vêm dentro do Roblox (rbxasset://sounds/...).
-- O Roblox removeu os sons antigos (swordslash.wav etc.), então sem IDs próprios o jogo fica quase mudo.
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local Prefs = require(script.Parent.Prefs)

local Sounds = {}

Sounds.List = {
	ping = { id = "", reserva = "rbxasset://sounds/volume_slider.ogg" }, -- interface, notificações
	crit = { id = "", reserva = "rbxasset://sounds/action_jump_land.mp3" }, -- impacto forte
	swing = { id = "", reserva = "rbxasset://sounds/action_jump.mp3" }, -- golpe no ar
	equip = { id = "", reserva = "rbxasset://sounds/action_get_up.mp3" }, -- equipar, escolher classe
	explosion = { id = "", reserva = "rbxasset://sounds/impact_explosion_03.mp3" }, -- explosões, pancadas
	splash = { id = "", reserva = "rbxasset://sounds/impact_water.mp3" }, -- água
}

local function resolve(name)
	local entry = Sounds.List[name]
	if not entry then
		return nil
	end
	return if entry.id ~= "" then entry.id else entry.reserva
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
	Debris:AddItem(sound, 4)
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

return Sounds
