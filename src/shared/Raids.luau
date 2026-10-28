-- Raide: o Devorador de Estrelas (até 8 jogadores, fases, prêmio semanal). Regras e posição do portal.
local World = require(script.Parent.World)
local Points = require(script.Parent.Points)

local Raids = {}

local S = World.Scale

Raids.Name = "Coração da Estrela"
Raids.Boss = "devorador"
Raids.MinLevel = 18
Raids.MaxPlayers = 8
Raids.TimeLimit = 15 * 60
Raids.Text = "Uma estrela vermelha caiu atrás das montanhas e algo saiu de dentro dela. Juntem até 8 caçadores: o Devorador tem fases, chuva de estrelas e servos. Prêmio garantido uma vez por semana: baú Real, um item Lendário e ouro."

-- fases pela vida do chefe (fração restante)
Raids.Phases = {
	{ at = 0.7, name = "Chuva de Estrelas", text = "Círculos vermelhos no chão: saia de baixo antes da estrela cair!" },
	{ at = 0.4, name = "Os Servos", text = "Servos de pedra e magos saem das bordas da arena!" },
	{ at = 0.2, name = "Fúria", text = "O Devorador enlouqueceu: mais dano e estrelas mais rápidas!" },
}

-- vida do chefe pelo tamanho do grupo (8 = vida cheia)
function Raids.hpMult(players)
	return 0.3 + 0.7 * math.clamp(players, 1, Raids.MaxPlayers) / Raids.MaxPlayers
end

function Raids.week(time)
	return math.floor(((time or os.time()) - 4 * 86400) / 604800)
end

-- portal no mapa: perto da Passagem do Norte, em chão plano
do
	local x, z = Points.resolve(-45 * S, -200 * S)
	Raids.PortalY = World.addPad(x, z, 14 * World.PropScale, 10 * World.PropScale)
	Raids.PortalX = x
	Raids.PortalZ = z
end

return Raids
