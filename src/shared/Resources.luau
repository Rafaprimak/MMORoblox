-- Pontos de coleta (minérios, plantas, árvores).
local Resources = {}

Resources.Nodes = {
	cobre = { name = "Rocha de Cobre", item = "minerio_cobre", skill = "mineracao", level = 1, xp = 12, amount = { 1, 2 }, respawn = 25, action = "Minerar", hold = 1.2, color = Color3.fromRGB(255, 140, 45), veins = 7, veinSize = 1.4, sparkle = true },
	ferro = { name = "Rocha de Ferro", item = "minerio_ferro", skill = "mineracao", level = 5, xp = 26, amount = { 1, 2 }, respawn = 35, action = "Minerar", hold = 1.5, color = Color3.fromRGB(170, 180, 200) },
	mitril = { name = "Veio de Mitril", item = "minerio_mitril", skill = "mineracao", level = 15, xp = 60, amount = { 1, 1 }, respawn = 60, action = "Minerar", hold = 2, color = Color3.fromRGB(90, 230, 255), glow = true },
	erva = { name = "Erva Verde", item = "erva_verde", skill = "herbalismo", level = 1, xp = 10, amount = { 1, 3 }, respawn = 20, action = "Colher", hold = 0.7, color = Color3.fromRGB(80, 200, 70) },
	cogumelo = { name = "Cogumelo Azul", item = "cogumelo_azul", skill = "herbalismo", level = 4, xp = 18, amount = { 1, 2 }, respawn = 30, action = "Colher", hold = 0.8, color = Color3.fromRGB(70, 140, 255), glow = true },
	flor_lunar = { name = "Flor Lunar", item = "flor_lunar", skill = "herbalismo", level = 12, xp = 45, amount = { 1, 1 }, respawn = 60, action = "Colher", hold = 1, color = Color3.fromRGB(255, 190, 240), glow = true },
	arvore = { name = "Árvore Robusta", item = "madeira", skill = "lenhador", level = 1, xp = 12, amount = { 1, 3 }, respawn = 30, action = "Cortar", hold = 1.4, color = Color3.fromRGB(140, 100, 60) },
	arvore_antiga = { name = "Árvore Antiga", item = "madeira_antiga", skill = "lenhador", level = 8, xp = 40, amount = { 1, 2 }, respawn = 60, action = "Cortar", hold = 1.8, color = Color3.fromRGB(110, 80, 120) },
}

return Resources
