-- Catálogo de áudio do jogo. Os IDs atuais são da biblioteca oficial enviada pela conta "Roblox"
-- (livres para usar). Para trocar: Studio → Caixa de ferramentas → Creator Store → Áudio.
-- Formato: id = "rbxassetid://123456789". Vazio = usa a "reserva" (sons que vêm dentro do Roblox)
-- ou fica em silêncio. Na abertura do jogo o cliente pré-carrega tudo: ID inválido cai na reserva.
local SoundIds = {}

local R = "rbxasset://sounds/"

-- Efeitos (um disparo)
SoundIds.Effects = {
	ping = { id = "rbxassetid://15675059323", reserva = R .. "volume_slider.ogg", desc = "Interface, notificações" },
	hover = { id = "rbxassetid://10066931761", reserva = "", desc = "Mouse sobre um botão" },
	click = { id = "rbxassetid://15675032796", reserva = R .. "volume_slider.ogg", desc = "Clique em botão" },
	crit = { id = "rbxassetid://12222216", reserva = R .. "action_jump_land.mp3", desc = "Impacto forte / crítico" },
	swing = { id = "rbxassetid://12222200", reserva = R .. "action_jump.mp3", desc = "Golpe no ar (leve)" },
	swingHeavy = { id = "rbxassetid://12222208", reserva = R .. "action_jump.mp3", desc = "Golpe pesado no ar" },
	hit = { id = "rbxassetid://12222046", reserva = R .. "action_jump_land.mp3", desc = "Golpe acertando carne" },
	hitMetal = { id = "rbxassetid://12222216", reserva = R .. "action_jump_land.mp3", desc = "Golpe acertando armadura/pedra" },
	parry = { id = "rbxassetid://12222225", reserva = R .. "action_jump_land.mp3", desc = "Aparar (metal com metal)" },
	block = { id = "rbxassetid://12221984", reserva = R .. "action_jump_land.mp3", desc = "Bloqueio" },
	dodge = { id = "rbxassetid://15675024286", reserva = R .. "action_jump.mp3", desc = "Rolamento" },
	bow = { id = "rbxassetid://12222103", reserva = R .. "action_jump.mp3", desc = "Disparo de flecha" },
	cast = { id = "rbxassetid://17208327798", reserva = "", desc = "Magia lançada" },
	fire = { id = "rbxassetid://3149249837", reserva = R .. "impact_explosion_03.mp3", desc = "Fogo / explosão de fogo" },
	ice = { id = "rbxassetid://12222005", reserva = "", desc = "Gelo / congelar" },
	holy = { id = "rbxassetid://15675043410", reserva = "", desc = "Luz sagrada / cura" },
	explosion = { id = "rbxassetid://3149249837", reserva = R .. "impact_explosion_03.mp3", desc = "Explosão" },
	heal = { id = "rbxassetid://15675043410", reserva = "", desc = "Cura" },
	equip = { id = "rbxassetid://17208323435", reserva = R .. "action_get_up.mp3", desc = "Equipar" },
	coin = { id = "rbxassetid://127645268874265", reserva = R .. "volume_slider.ogg", desc = "Ouro" },
	loot = { id = "rbxassetid://17208319162", reserva = R .. "volume_slider.ogg", desc = "Item comum caiu" },
	lootRare = { id = "rbxassetid://17208361335", reserva = R .. "volume_slider.ogg", desc = "Item raro caiu" },
	levelup = { id = "rbxassetid://12222253", reserva = R .. "volume_slider.ogg", desc = "Subiu de nível" },
	quest = { id = "rbxassetid://99366249808641", reserva = R .. "volume_slider.ogg", desc = "Missão completa" },
	chest = { id = "rbxassetid://365549814", reserva = R .. "action_get_up.mp3", desc = "Baú abrindo" },
	hurt = { id = "rbxassetid://79348298352567", reserva = R .. "ouch.ogg", desc = "Jogador levou dano" },
	enemyDeath = { id = "rbxassetid://12222152", reserva = R .. "action_jump_land.mp3", desc = "Inimigo derrotado" },
	gallop = { id = "rbxassetid://12221952", reserva = R .. "action_footsteps_plastic.mp3", desc = "Cascos do cavalo" },
	splash = { id = "rbxassetid://12222054", reserva = R .. "impact_water.mp3", desc = "Água" },
	hatch = { id = "rbxassetid://15675055424", reserva = R .. "volume_slider.ogg", desc = "Ovo de pet chocando" },
}

-- Ambiente em loop (por região). Fica em silêncio enquanto o id estiver vazio.
SoundIds.Ambience = {
	vila = { id = "", desc = "Vila: pássaros, gente conversando ao longe" },
	campo = { id = "", desc = "Campos: vento leve e pássaros" },
	bosque = { id = "", desc = "Floresta: folhas, corujas" },
	costa = { id = "", desc = "Praia: ondas e gaivotas" },
	montanha = { id = "rbxassetid://15675021174", desc = "Montanha: vento forte" },
	ruinas = { id = "", desc = "Ruínas: vento com eco" },
	noite = { id = "", desc = "Noite: grilos (toca junto com a região)" },
}

-- Música em loop (crossfade ao trocar)
SoundIds.Music = {
	vila = { id = "rbxassetid://15930255433", desc = "Música calma da vila" },
	exploracao = { id = "rbxassetid://130053244401794", desc = "Música de aventura (fora da vila)" },
	noite = { id = "rbxassetid://15675069601", desc = "Música da noite" },
	chefe = { id = "rbxassetid://17422163655", desc = "Música de chefe" },
}

-- Cantos de pássaros soltos (tocados de vez em quando de dia na vila, campos e bosque)
SoundIds.Birds = { "rbxassetid://79205036324023", "rbxassetid://99631809815420", "rbxassetid://106557401612525" }

-- qual ambiente cada região usa
SoundIds.RegionAmbience = {
	["Vila Aurora"] = "vila",
	["Campos Verdejantes"] = "campo",
	["Bosque Sombrio"] = "bosque",
	["Costa Dourada"] = "costa",
	["Lago Espelhado"] = "campo",
	["Montanhas Geladas"] = "montanha",
	["Passagem do Norte"] = "montanha",
	["Planalto das Ruínas"] = "ruinas",
	["Covil do Rei Goblin"] = "ruinas",
}

return SoundIds
