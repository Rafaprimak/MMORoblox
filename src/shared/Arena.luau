-- Arena PvP (dados puros): modos, pontuação (estilo Elo), divisões por pontos e recompensas.
-- A temporada vem de Seasons (a pontuação recomeça a cada temporada; o ranking também).
local Arena = {}

Arena.Name = "Coliseu de Aurora"
Arena.MinLevel = 8

Arena.Modes = {
	duelo = { id = "duelo", name = "Duelo 1x1", teamSize = 1, icon = "crossed-swords", text = "Você contra outro caçador. Melhor de 3 rodadas." },
	equipes = { id = "equipes", name = "Equipes 3x3", teamSize = 3, icon = "checked-shield", text = "Três contra três, times montados pelos pontos. Melhor de 3 rodadas." },
}
Arena.ModeOrder = { "duelo", "equipes" }

Arena.RoundsToWin = 2
Arena.RoundTime = 90 -- segundos; no fim ganha o time com mais vida somada (em %)
Arena.Countdown = 5
Arena.DamageMult = 0.3 -- dano de jogador em jogador (golpes e habilidades)
Arena.HealMult = 0.5 -- curas valem menos dentro da arena
Arena.StartRating = 1000
Arena.K = 32

-- divisões (pontos mínimos) e o título que cada uma dá ao ser alcançada
-- ícones: "crossed-swords", "checked-shield", "laurel-crown", "trophy"
Arena.Divisions = {
	{ id = "bronze", name = "Bronze", rating = 0, color = Color3.fromRGB(205, 127, 70) },
	{ id = "prata", name = "Prata", rating = 1100, color = Color3.fromRGB(200, 205, 220), title = "gladiador_prata" },
	{ id = "ouro", name = "Ouro", rating = 1250, color = Color3.fromRGB(255, 205, 70), title = "gladiador_ouro" },
	{ id = "platina", name = "Platina", rating = 1400, color = Color3.fromRGB(120, 230, 210), title = "gladiador_platina" },
	{ id = "diamante", name = "Diamante", rating = 1600, color = Color3.fromRGB(120, 180, 255), title = "gladiador_diamante" },
	{ id = "campeao", name = "Campeão", rating = 1850, color = Color3.fromRGB(255, 90, 90), title = "campeao_arena" },
}

-- prêmio por partida
Arena.Rewards = {
	win = { gold = 250, xp = 400 },
	loss = { gold = 80, xp = 120 },
}

function Arena.division(rating)
	local index = 1
	for i, division in Arena.Divisions do
		if rating >= division.rating then
			index = i
		end
	end
	return Arena.Divisions[index], index
end

-- variação de pontos (Elo) para quem tem "rating" contra a média "opponent"
function Arena.delta(rating, opponent, won)
	local expected = 1 / (1 + 10 ^ ((opponent - rating) / 400))
	local delta = Arena.K * ((if won then 1 else 0) - expected)
	return math.floor(delta + (if delta >= 0 then 0.5 else -0.5))
end

return Arena
