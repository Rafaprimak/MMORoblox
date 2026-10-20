-- Sons de teste usando arquivos que já vêm com o Roblox (rbxasset://).
-- Para a versão final, troque pelos IDs de sons da Creator Store.
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local Sounds = {}

local IDS = {
	ping = "rbxasset://sounds/electronicpingshort.wav",
	crit = "rbxasset://sounds/swordlunge.wav",
	equip = "rbxasset://sounds/unsheath.wav",
	swing = "rbxasset://sounds/swordslash.wav",
}

function Sounds.play(name, pitch, volume)
	local id = IDS[name]
	if not id then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.PlaybackSpeed = pitch or 1
	sound.Volume = volume or 0.5
	sound.Parent = SoundService
	sound:Play()
	Debris:AddItem(sound, 4)
end

return Sounds
