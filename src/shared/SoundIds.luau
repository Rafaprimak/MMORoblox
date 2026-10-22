-- Catálogo de áudio do jogo. COLE AQUI os IDs da Creator Store (Studio → Caixa de ferramentas →
-- Creator Store → Áudio; prefira sons enviados pela conta "Roblox", que são livres para usar).
-- Formato: id = "rbxassetid://123456789". Vazio = usa a "reserva" (sons que vêm dentro do Roblox)
-- ou fica em silêncio. Na abertura do jogo o cliente pré-carrega tudo: ID inválido cai na reserva.
local SoundIds = {}

local R = "rbxasset://sounds/"

-- Efeitos (um disparo)
SoundIds.Effects = {
	ping = { id = "", reserva = R .. "volume_slider.ogg", desc = "Interface, notificações" },
	click = { id = "", reserva = R .. "volume_slider.ogg", desc = "Clique em botão" },
	crit = { id = "", reserva = R .. "action_jump_land.mp3", desc = "Impacto forte / crítico" },
	swing = { id = "", reserva = R .. "action_jump.mp3", desc = "Golpe no ar (leve)" },
	swingHeavy = { id = "", reserva = R .. "action_jump.mp3", desc = "Golpe pesado no ar" },
	hit = { id = "", reserva = R .. "action_jump_land.mp3", desc = "Golpe acertando carne" },
	hitMetal = { id = "", reserva = R .. "action_jump_land.mp3", desc = "Golpe acertando armadura/pedra" },
	parry = { id = "", reserva = R .. "action_jump_land.mp3", desc = "Aparar (metal com metal)" },
	block = { id = "", reserva = R .. "action_jump_land.mp3", desc = "Bloqueio" },
	dodge = { id = "", reserva = R .. "action_jump.mp3", desc = "Rolamento" },
	bow = { id = "", reserva = R .. "action_jump.mp3", desc = "Disparo de flecha" },
	cast = { id = "", reserva = "", desc = "Magia lançada" },
	fire = { id = "", reserva = R .. "impact_explosion_03.mp3", desc = "Fogo / explosão de fogo" },
	ice = { id = "", reserva = "", desc = "Gelo / congelar" },
	holy = { id = "", reserva = "", desc = "Luz sagrada / cura" },
	explosion = { id = "", reserva = R .. "impact_explosion_03.mp3", desc = "Explosão" },
	heal = { id = "", reserva = "", desc = "Cura" },
	equip = { id = "", reserva = R .. "action_get_up.mp3", desc = "Equipar" },
	coin = { id = "", reserva = R .. "volume_slider.ogg", desc = "Ouro" },
	loot = { id = "", reserva = R .. "volume_slider.ogg", desc = "Item comum caiu" },
	lootRare = { id = "", reserva = R .. "volume_slider.ogg", desc = "Item raro caiu" },
	levelup = { id = "", reserva = R .. "volume_slider.ogg", desc = "Subiu de nível" },
	quest = { id = "", reserva = R .. "volume_slider.ogg", desc = "Missão completa" },
	chest = { id = "", reserva = R .. "action_get_up.mp3", desc = "Baú abrindo" },
	hurt = { id = "", reserva = R .. "ouch.ogg", desc = "Jogador levou dano" },
	enemyDeath = { id = "", reserva = R .. "action_jump_land.mp3", desc = "Inimigo derrotado" },
	gallop = { id = "", reserva = R .. "action_footsteps_plastic.mp3", desc = "Cascos do cavalo" },
	splash = { id = "", reserva = R .. "impact_water.mp3", desc = "Água" },
	hatch = { id = "", reserva = R .. "volume_slider.ogg", desc = "Ovo de pet chocando" },
}

-- Ambiente em loop (por região). Fica em silêncio enquanto o id estiver vazio.
SoundIds.Ambience = {
	vila = { id = "", desc = "Vila: pássaros, gente conversando ao longe" },
	campo = { id = "", desc = "Campos: vento leve e pássaros" },
	bosque = { id = "", desc = "Floresta: folhas, corujas" },
	costa = { id = "", desc = "Praia: ondas e gaivotas" },
	montanha = { id = "", desc = "Montanha: vento forte" },
	ruinas = { id = "", desc = "Ruínas: vento com eco" },
	noite = { id = "", desc = "Noite: grilos (toca junto com a região)" },
}

-- Música em loop (crossfade ao trocar)
SoundIds.Music = {
	vila = { id = "", desc = "Música calma da vila" },
	exploracao = { id = "", desc = "Música de aventura (fora da vila)" },
	noite = { id = "", desc = "Música da noite" },
	chefe = { id = "", desc = "Música de chefe" },
}

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
