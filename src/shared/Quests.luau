-- Missões. Cada missão tem um NPC que oferece (giver) e, opcionalmente, um NPC para entregar (turnIn).
-- Tipos de objetivo:
--   kill(target|"any")  hit(target)       gather(item)   deliver(item, consome na entrega)
--   talk(npc)           explore(location) discover(waystone)
--   craft(item|"forge"|"alchemy")         enchant   upgrade   upgradeTo(nível +N)
--   level(n)            mastery(n)        mount     chest     dodge   ability   finisher
local Quests = {}

local function q(def)
	def.requires = def.requires or {}
	return def
end

Quests.List = {
	-- ===================== HISTÓRIA =====================
	q({
		id = "h01", chain = "main", name = "O Novo Hunter", giver = "lyra", turnIn = "kael",
		text = "Todo Hunter começa no pátio de treino. Procure o Mestre Kael e mostre do que é capaz.",
		objectives = {
			{ type = "talk", npc = "kael", amount = 1, text = "Fale com o Mestre Kael" },
			{ type = "hit", target = "boneco", amount = 12, text = "Golpeie o boneco de treino" },
			{ type = "dodge", amount = 3, text = "Esquive (tecla Q)" },
		},
		reward = { xp = 60, gold = 50, consumables = { pocao_vida = 3 } },
	}),
	q({
		id = "h02", chain = "main", name = "Gosma na Estrada", giver = "kael", turnIn = "lyra",
		text = "Os slimes estão tomando os campos ao norte da vila. Limpe a área e traga provas.",
		requires = { quests = { "h01" } },
		objectives = {
			{ type = "kill", target = "slime", amount = 6, text = "Derrote Slimes" },
			{ type = "deliver", item = "gosma", amount = 3, text = "Entregue Gosmas de Slime" },
		},
		reward = { xp = 120, gold = 80 },
	}),
	q({
		id = "h03", chain = "main", name = "Minério para a Forja", giver = "lyra", turnIn = "bruno",
		text = "O ferreiro Bruno precisa de cobre. As rochas alaranjadas nos campos têm bastante.",
		requires = { quests = { "h02" } },
		objectives = {
			{ type = "gather", item = "minerio_cobre", amount = 6, text = "Minere Cobre (segure E na rocha)" },
			{ type = "gather", item = "madeira", amount = 3, text = "Corte Madeira das árvores marcadas" },
		},
		reward = { xp = 150, gold = 60, materials = { minerio_cobre = 2 } },
	}),
	q({
		id = "h04", chain = "main", name = "Mãos na Bigorna", giver = "bruno", turnIn = "bruno",
		text = "Agora forje algo! Escolha uma receita na forja.",
		requires = { quests = { "h03" } },
		objectives = {
			{ type = "craft", item = "forge", amount = 1, text = "Forje um equipamento" },
			{ type = "upgrade", amount = 1, text = "Aprimore um item" },
		},
		reward = { xp = 220, gold = 100 },
	}),
	q({
		id = "h05", chain = "main", name = "Ervas da Curandeira", giver = "bruno", turnIn = "mira",
		text = "Mira, a alquimista, sempre precisa de ervas. Colha algumas e aprenda a fazer poções.",
		requires = { quests = { "h04" } },
		objectives = {
			{ type = "gather", item = "erva_verde", amount = 5, text = "Colha Ervas Verdes" },
			{ type = "craft", item = "pocao_vida", amount = 1, text = "Prepare uma Poção de Vida" },
		},
		reward = { xp = 250, gold = 80, consumables = { pocao_mana = 2 } },
	}),
	q({
		id = "h06", chain = "main", name = "A Encruzilhada", giver = "mira", turnIn = "nia",
		text = "A caçadora Nia está na encruzilhada ao norte. Ative a pedra de viagem de lá.",
		requires = { quests = { "h05" } },
		objectives = {
			{ type = "discover", target = "encruzilhada", amount = 1, text = "Ative a Pedra da Encruzilhada" },
			{ type = "talk", npc = "nia", amount = 1, text = "Fale com Nia" },
		},
		reward = { xp = 200, gold = 60 },
	}),
	q({
		id = "h07", chain = "main", name = "Caça na Planície", giver = "nia", turnIn = "nia",
		text = "Lobos e javalis atacam viajantes. Mostre que a estrada é segura de novo.",
		requires = { quests = { "h06" } },
		objectives = {
			{ type = "kill", target = "lobo", amount = 5, text = "Derrote Lobos" },
			{ type = "kill", target = "javali", amount = 3, text = "Derrote Javalis (cuidado com a investida!)" },
			{ type = "deliver", item = "couro", amount = 4, text = "Entregue Couro" },
		},
		reward = { xp = 450, gold = 150 },
	}),
	q({
		id = "h08", chain = "main", name = "Uma Montaria Fiel", giver = "nia", turnIn = "pedro",
		text = "Andar a pé é lento. Pedro, o cavalariço da vila, vai te emprestar um cavalo.",
		requires = { quests = { "h07" } },
		grantsMount = true,
		objectives = {
			{ type = "talk", npc = "pedro", amount = 1, text = "Fale com Pedro na vila" },
			{ type = "mount", amount = 1, text = "Monte no cavalo (tecla H)" },
			{ type = "discover", target = "bosque", amount = 1, text = "Cavalgue até a Pedra do Bosque" },
		},
		reward = { xp = 300, gold = 100 },
	}),
	q({
		id = "h09", chain = "main", name = "Sombras no Bosque", giver = "pedro", turnIn = "lyra",
		text = "Goblins montaram acampamentos no Bosque Sombrio. Acabe com eles.",
		requires = { quests = { "h08" }, level = 5 },
		objectives = {
			{ type = "explore", location = "bosque", amount = 1, text = "Explore o Bosque Sombrio" },
			{ type = "kill", target = "goblin", amount = 8, text = "Derrote Goblins" },
			{ type = "kill", target = "goblin_arqueiro", amount = 3, text = "Derrote Goblins Arqueiros" },
		},
		reward = { xp = 800, gold = 250 },
	}),
	q({
		id = "h10", chain = "main", name = "O Despertar da Essência", giver = "lyra", turnIn = "elric",
		text = "Elric, o encantador, pode despertar o poder das suas armas com essência mágica.",
		requires = { quests = { "h09" } },
		objectives = {
			{ type = "deliver", item = "essencia", amount = 3, text = "Junte Essência (monstros ou desmontando itens)" },
			{ type = "enchant", amount = 1, text = "Encante um item com Elric" },
		},
		reward = { xp = 700, gold = 200, materials = { essencia = 2 } },
	}),
	q({
		id = "h11", chain = "main", name = "Ossos Inquietos", giver = "elric", turnIn = "elric",
		text = "Algo desperta os mortos no Planalto das Ruínas. Investigue o templo.",
		requires = { quests = { "h10" }, level = 9 },
		objectives = {
			{ type = "explore", location = "templo_ruinas", amount = 1, text = "Encontre o Templo em Ruínas" },
			{ type = "kill", target = "esqueleto", amount = 10, text = "Derrote Esqueletos" },
			{ type = "kill", target = "esqueleto_mago", amount = 3, text = "Derrote Esqueletos Magos" },
			{ type = "deliver", item = "osso", amount = 5, text = "Entregue Ossos Antigos" },
		},
		reward = { xp = 1800, gold = 400 },
	}),
	q({
		id = "h12", chain = "main", name = "O Guardião de Pedra", giver = "elric", turnIn = "gus",
		text = "O mineiro Gus pediu ajuda: golems tomaram a mina ao norte das ruínas.",
		requires = { quests = { "h11" } },
		objectives = {
			{ type = "explore", location = "mina", amount = 1, text = "Vá até a Mina Abandonada" },
			{ type = "kill", target = "golem", amount = 2, text = "Derrote Golems de Pedra" },
			{ type = "gather", item = "minerio_ferro", amount = 5, text = "Minere Ferro" },
		},
		reward = { xp = 2200, gold = 500, materials = { minerio_ferro = 5 } },
	}),
	q({
		id = "h13", chain = "main", name = "O Portão Selado", giver = "gus", turnIn = "tomas",
		text = "O covil do Rei Goblin fica além da Passagem do Norte. Só Hunters de Rank C passam pelo portão.",
		requires = { quests = { "h12" } },
		objectives = {
			{ type = "level", amount = 10, text = "Alcance o Nível 10 (Rank C)" },
			{ type = "discover", target = "passagem", amount = 1, text = "Ative a Pedra da Passagem" },
			{ type = "talk", npc = "tomas", amount = 1, text = "Fale com o Sargento Tomás" },
		},
		reward = { xp = 1500, gold = 300 },
	}),
	q({
		id = "h14", chain = "main", name = "A Queda do Rei Goblin", giver = "tomas", turnIn = "lyra",
		text = "Entre no covil e derrube o Rei Goblin. Junte outros Hunters se precisar!",
		requires = { quests = { "h13" } },
		objectives = {
			{ type = "explore", location = "cratera", amount = 1, text = "Entre no Covil do Rei Goblin" },
			{ type = "kill", target = "rei_goblin", amount = 1, text = "Derrote o Rei Goblin" },
		},
		reward = { xp = 5000, gold = 1500, chest = "real" },
	}),
	q({
		id = "h15", chain = "main", name = "Mestre de Armas", giver = "lyra", turnIn = "kael",
		text = "Você salvou a vila. Agora torne-se uma lenda: domine sua arma por completo.",
		requires = { quests = { "h14" } },
		objectives = {
			{ type = "mastery", amount = 10, text = "Alcance maestria 10 em alguma arma" },
			{ type = "level", amount = 15, text = "Alcance o Nível 15" },
		},
		reward = { xp = 6000, gold = 2500, chest = "real" },
	}),

	-- ===================== SECUNDÁRIAS =====================
	q({
		id = "s_presas", name = "Colar de Presas", giver = "nia", turnIn = "nia",
		text = "Quero um colar de presas de lobo. Me traga algumas?",
		requires = { quests = { "h07" } },
		objectives = {
			{ type = "kill", target = "lobo", amount = 10, text = "Derrote Lobos" },
			{ type = "deliver", item = "presa", amount = 6, text = "Entregue Presas de Lobo" },
		},
		reward = { xp = 500, gold = 200, consumables = { pocao_vigor = 3 } },
	}),
	q({
		id = "s_caranguejos", name = "Praia Livre", giver = "sol", turnIn = "sol",
		text = "Tire esses caranguejos da praia e traga as carapaças. Elas dão ótimas tigelas!",
		requires = { level = 4 },
		objectives = {
			{ type = "kill", target = "caranguejo", amount = 8, text = "Derrote Caranguejos" },
			{ type = "deliver", item = "carapaca", amount = 5, text = "Entregue Carapaças" },
		},
		reward = { xp = 600, gold = 250 },
	}),
	q({
		id = "s_explorador", name = "O Explorador", giver = "orin", turnIn = "orin",
		text = "Na sua idade eu já tinha visto cada canto desta terra. Vá e veja também!",
		objectives = {
			{ type = "explore", location = "farol", amount = 1, text = "Visite o Farol Abandonado" },
			{ type = "explore", location = "toca_aranhas", amount = 1, text = "Encontre o Ninho das Aranhas" },
			{ type = "explore", location = "templo_ruinas", amount = 1, text = "Encontre o Templo em Ruínas" },
			{ type = "explore", location = "passagem", amount = 1, text = "Chegue à Passagem do Norte" },
		},
		reward = { xp = 1200, gold = 300, materials = { essencia = 3 } },
	}),
	q({
		id = "s_flor", name = "Luz da Lua", giver = "orin", turnIn = "orin",
		text = "A Flor Lunar cresce entre as ruínas. Com ela, Mira prepara elixires poderosos.",
		requires = { quests = { "s_explorador" } },
		objectives = {
			{ type = "gather", item = "flor_lunar", amount = 4, text = "Colha Flores Lunares (Herbalismo 12)" },
		},
		reward = { xp = 1000, gold = 200, consumables = { elixir_forca = 2 } },
	}),
	q({
		id = "s_cogumelos", name = "Cogumelos Azuis", giver = "mira", turnIn = "mira",
		text = "Cogumelos azuis crescem na sombra das árvores do bosque. Faça poções de mana com eles.",
		requires = { quests = { "h05" } },
		objectives = {
			{ type = "gather", item = "cogumelo_azul", amount = 6, text = "Colha Cogumelos Azuis (Herbalismo 4)" },
			{ type = "craft", item = "pocao_mana", amount = 2, text = "Prepare Poções de Mana" },
		},
		reward = { xp = 450, gold = 150 },
	}),
	q({
		id = "s_aranhas", name = "Seda Fina", giver = "otto", turnIn = "otto",
		text = "Seda de aranha gigante vende muito bem na capital. Topa o risco?",
		requires = { level = 7 },
		objectives = {
			{ type = "kill", target = "aranha", amount = 6, text = "Derrote Aranhas Gigantes" },
			{ type = "deliver", item = "seda", amount = 6, text = "Entregue Seda de Aranha" },
		},
		reward = { xp = 900, gold = 450 },
	}),
	q({
		id = "s_aprimorar", name = "Aço Refinado", giver = "bruno", turnIn = "bruno",
		text = "Uma arma +3 já impõe respeito. Mostre que sabe cuidar do seu equipamento.",
		requires = { quests = { "h04" } },
		objectives = {
			{ type = "upgradeTo", amount = 3, text = "Aprimore um item até +3" },
		},
		reward = { xp = 500, gold = 200, materials = { minerio_ferro = 4 } },
	}),
	q({
		id = "s_combo", name = "Fluxo de Combate", giver = "kael", turnIn = "kael",
		text = "Emende golpes até o finalizador e use suas habilidades. É assim que se luta.",
		requires = { quests = { "h01" } },
		objectives = {
			{ type = "finisher", amount = 10, text = "Acerte finalizadores de combo (maestria 3)" },
			{ type = "ability", amount = 10, text = "Use habilidades de classe (teclas 1-4)" },
		},
		reward = { xp = 400, gold = 150 },
	}),
	q({
		id = "s_mitril", name = "Veio de Mitril", giver = "gus", turnIn = "gus",
		text = "Dizem que há mitril nas encostas da Passagem do Norte. Só minerador experiente consegue.",
		requires = { quests = { "h12" } },
		objectives = {
			{ type = "gather", item = "minerio_mitril", amount = 4, text = "Minere Mitril (Mineração 15)" },
		},
		reward = { xp = 2000, gold = 600 },
	}),
}

-- Contratos diários (o Quadro de Recompensas sorteia 3 por dia)
Quests.DailyPool = {
	{ id = "d_slime", name = "Contrato: Slimes", objectives = { { type = "kill", target = "slime", amount = 25, text = "Derrote Slimes" } }, reward = { xp = 250, gold = 150 } },
	{ id = "d_lobo", name = "Contrato: Lobos", objectives = { { type = "kill", target = "lobo", amount = 12, text = "Derrote Lobos" } }, reward = { xp = 350, gold = 180 } },
	{ id = "d_goblin", name = "Contrato: Goblins", minLevel = 5, objectives = { { type = "kill", target = "goblin", amount = 15, text = "Derrote Goblins" } }, reward = { xp = 700, gold = 300 } },
	{ id = "d_esqueleto", name = "Contrato: Esqueletos", minLevel = 9, objectives = { { type = "kill", target = "esqueleto", amount = 15, text = "Derrote Esqueletos" } }, reward = { xp = 1500, gold = 500 } },
	{ id = "d_rei", name = "Contrato: Rei Goblin", minLevel = 10, objectives = { { type = "kill", target = "rei_goblin", amount = 1, text = "Derrote o Rei Goblin" } }, reward = { xp = 2000, gold = 800, chest = "prata" } },
	{ id = "d_ervas", name = "Encomenda: Ervas", objectives = { { type = "gather", item = "erva_verde", amount = 10, text = "Colha Ervas Verdes" } }, reward = { xp = 250, gold = 150 } },
	{ id = "d_cobre", name = "Encomenda: Cobre", objectives = { { type = "gather", item = "minerio_cobre", amount = 10, text = "Minere Cobre" } }, reward = { xp = 250, gold = 150 } },
	{ id = "d_madeira", name = "Encomenda: Madeira", objectives = { { type = "gather", item = "madeira", amount = 10, text = "Corte Madeira" } }, reward = { xp = 250, gold = 150 } },
	{ id = "d_pocoes", name = "Encomenda: Poções", objectives = { { type = "craft", item = "alchemy", amount = 3, text = "Prepare poções" } }, reward = { xp = 300, gold = 200 } },
	{ id = "d_forja", name = "Encomenda: Forja", objectives = { { type = "craft", item = "forge", amount = 1, text = "Forje um equipamento" } }, reward = { xp = 300, gold = 200 } },
	{ id = "d_aprimorar", name = "Treino de Ferreiro", objectives = { { type = "upgrade", amount = 2, text = "Aprimore itens" } }, reward = { xp = 300, gold = 150 } },
	{ id = "d_baus", name = "Caça ao Tesouro", objectives = { { type = "chest", amount = 2, text = "Abra baús" } }, reward = { xp = 200, gold = 250 } },
	{ id = "d_habilidades", name = "Treino de Classe", objectives = { { type = "ability", amount = 20, text = "Use habilidades" } }, reward = { xp = 400, gold = 150 } },
	{ id = "d_esquiva", name = "Treino de Esquiva", objectives = { { type = "dodge", amount = 20, text = "Esquive" } }, reward = { xp = 250, gold = 120 } },
	{ id = "d_caranguejo", name = "Contrato: Praia", minLevel = 4, objectives = { { type = "kill", target = "caranguejo", amount = 10, text = "Derrote Caranguejos" } }, reward = { xp = 450, gold = 220 } },
}
Quests.DailyBonus = { gold = 500, chest = "prata" }

Quests.ById = {}
for _, quest in Quests.List do
	Quests.ById[quest.id] = quest
end
for _, daily in Quests.DailyPool do
	daily.giver = "quadro"
	daily.daily = true
	daily.text = "Contrato do Quadro de Recompensas. Renova todo dia."
	daily.requires = { level = daily.minLevel }
	Quests.ById[daily.id] = daily
end

function Quests.rewardText(reward)
	local parts = {}
	if reward.xp then
		table.insert(parts, "+" .. reward.xp .. " XP")
	end
	if reward.gold then
		table.insert(parts, "+" .. reward.gold .. " Ouro")
	end
	if reward.chest then
		table.insert(parts, "Baú " .. (if reward.chest == "real" then "Real" elseif reward.chest == "prata" then "de Prata" else "de Bronze"))
	end
	if reward.consumables or reward.materials then
		table.insert(parts, "Itens")
	end
	return table.concat(parts, "  •  ")
end

return Quests
