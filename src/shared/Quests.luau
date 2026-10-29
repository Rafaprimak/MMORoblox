-- Missões. Cada missão tem um NPC que oferece (giver) e, opcionalmente, um NPC para entregar (turnIn).
-- Tipos de objetivo:
--   kill(target|"any")  hit(target)       gather(item)   deliver(item, consome na entrega)
--   talk(npc)           explore(location) discover(waystone)
--   craft(item|"forge"|"alchemy")         enchant   upgrade   upgradeTo(nível +N)
--   level(n)            mastery(n)        mount     chest     dodge   ability   finisher
--   parry (aparar)      perfectDodge      rhythm (golpe no ritmo)   stagger (quebrar guarda)   fullCharge
--   poi(target = local) poiSecret(target = local)   worldBoss   invasion   raid   arenaWin
--   dungeonFloor(target = masmorra, amount = andar: recorde de andar limpo)   dungeonBoss(target = masmorra)
-- reward.item = { base, rarity } (item fixo) | reward.exoticWeapon = true (arma do Ciclo do seu tipo)
-- lore = id da página das Crônicas liberada ao entregar a missão
-- reward.faction = { id, amount }: reputação extra com uma facção (Factions)
local Quests = {}

local function q(def)
	def.requires = def.requires or {}
	return def
end

Quests.List = {
	-- ===================== HISTÓRIA: O ORBE INFINITO =====================
	-- A Vila Aurora vive dentro do Orbe Infinito, a barreira de mana erguida pelos três arquimagos
	-- (Elric, Serafina e Valdrik). A barreira protege da Maré de Mana lá fora, que muda quem não tem
	-- resistência (a origem dos monstros), mas também é uma bolha de tempo: o dia volta e se repete
	-- (por isso monstros renascem e os moradores repetem as mesmas falas). Só quem tem resistência à
	-- mana lembra do dia anterior: os Hunters. XP pensado para chegar ao nível 20 com folga.

	-- ===== ATO I: A AURORA QUE SE REPETE (níveis 1-5) =====
	q({
		id = "h01", chain = "main", name = "O Hunter que Lembra", giver = "lyra", turnIn = "kael",
		text = "Toda manhã a Vila Aurora acorda igual: o mesmo sol, as mesmas conversas. Mas você lembra do dia anterior, e isso faz de você um Hunter. Procure o Mestre Kael no pátio de treino.",
		objectives = {
			{ type = "talk", npc = "kael", amount = 1, text = "Fale com o Mestre Kael" },
			{ type = "hit", target = "boneco", amount = 12, text = "Golpeie o boneco de treino" },
			{ type = "dodge", amount = 3, text = "Esquive (tecla Q)" },
			{ type = "parry", amount = 2, text = "Apare o golpe do boneco (F quando aparecer !)" },
		},
		reward = { xp = 300, gold = 60, consumables = { pocao_vida = 3 } },
	}),
	q({
		id = "h02", chain = "main", name = "Gosma na Estrada", giver = "kael", turnIn = "lyra",
		text = "Slimes são a mutação mais simples que existe: água parada que bebeu mana demais. Eles voltam todo dia, mas hoje alguém precisa limpar os campos ao norte.",
		requires = { quests = { "h01" } },
		objectives = {
			{ type = "kill", target = "slime", amount = 6, text = "Derrote Slimes" },
			{ type = "deliver", item = "gosma", amount = 3, text = "Entregue Gosmas de Slime" },
		},
		reward = { xp = 500, gold = 80 },
	}),
	q({
		id = "h03", chain = "main", name = "Minério para a Forja", giver = "lyra", turnIn = "bruno",
		text = "O ferreiro Bruno precisa de cobre. As rochas alaranjadas dos campos têm bastante. Ele vai jurar que pediu isso pela primeira vez.",
		requires = { quests = { "h02" } },
		objectives = {
			{ type = "gather", item = "minerio_cobre", amount = 6, text = "Minere Cobre (segure E na rocha)" },
			{ type = "gather", item = "madeira", amount = 3, text = "Corte Madeira das árvores marcadas" },
		},
		reward = { xp = 600, gold = 60, materials = { minerio_cobre = 2 } },
	}),
	q({
		id = "h04", chain = "main", name = "Mãos na Bigorna", giver = "bruno", turnIn = "bruno",
		text = "\"Aço não esquece\", diz o Bruno. O que você forja hoje continua com você amanhã, mesmo quando o dia volta.",
		requires = { quests = { "h03" } },
		objectives = {
			{ type = "craft", item = "forge", amount = 1, text = "Forje um equipamento" },
			{ type = "upgrade", amount = 1, text = "Aprimore um item" },
		},
		reward = { xp = 800, gold = 100 },
	}),
	q({
		id = "h05", chain = "main", name = "Ervas da Curandeira", giver = "bruno", turnIn = "mira",
		text = "Mira, a alquimista, sempre precisa de ervas. Colha algumas e aprenda a fazer poções.",
		requires = { quests = { "h04" } },
		objectives = {
			{ type = "gather", item = "erva_verde", amount = 5, text = "Colha Ervas Verdes" },
			{ type = "craft", item = "pocao_vida", amount = 1, text = "Prepare uma Poção de Vida" },
		},
		reward = { xp = 900, gold = 80, consumables = { pocao_mana = 2 } },
	}),
	q({
		id = "h05b", chain = "main", name = "O Dia que Volta", giver = "mira", turnIn = "elric",
		lore = "orbe",
		text = "\"Você também percebeu? Ontem o Bruno me disse exatamente a mesma frase.\" Mira está assustada. Converse com a Capitã Lyra e com o Bruno e depois suba a torre do Elric: ele sabe mais do que conta.",
		requires = { quests = { "h05" } },
		objectives = {
			{ type = "talk", npc = "lyra", amount = 1, text = "Converse com a Capitã Lyra" },
			{ type = "talk", npc = "bruno", amount = 1, text = "Converse com o Bruno" },
			{ type = "talk", npc = "elric", amount = 1, text = "Suba a torre do Arquimago Elric" },
		},
		reward = { xp = 1000, gold = 120 },
	}),
	q({
		id = "h06", chain = "main", name = "A Encruzilhada", giver = "elric", turnIn = "nia",
		text = "Elric quer saber até onde a mana engrossou. A caçadora Nia vigia a encruzilhada ao norte: ative a pedra de viagem de lá e fale com ela.",
		requires = { quests = { "h05b" } },
		objectives = {
			{ type = "discover", target = "encruzilhada", amount = 1, text = "Ative a Pedra da Encruzilhada" },
			{ type = "talk", npc = "nia", amount = 1, text = "Fale com Nia" },
		},
		reward = { xp = 1200, gold = 80 },
	}),
	q({
		id = "h07", chain = "main", name = "Caça na Planície", giver = "nia", turnIn = "nia",
		text = "Lobos e javalis que bebem a mana dos riachos ficam maiores a cada dia que volta. Mostre que a estrada é segura de novo.",
		requires = { quests = { "h06" } },
		objectives = {
			{ type = "kill", target = "lobo", amount = 5, text = "Derrote Lobos" },
			{ type = "kill", target = "javali", amount = 3, text = "Derrote Javalis (cuidado com a investida!)" },
			{ type = "deliver", item = "couro", amount = 4, text = "Entregue Couro" },
		},
		reward = { xp = 1600, gold = 150 },
	}),
	q({
		id = "h08", chain = "main", name = "Uma Montaria Fiel", giver = "nia", turnIn = "pedro",
		text = "O vale é grande demais para ir a pé. Pedro, o cavalariço da vila, vai te emprestar um cavalo.",
		requires = { quests = { "h07" } },
		grantsMount = true,
		objectives = {
			{ type = "talk", npc = "pedro", amount = 1, text = "Fale com Pedro na vila" },
			{ type = "mount", amount = 1, text = "Monte no cavalo (tecla H)" },
			{ type = "discover", target = "bosque", amount = 1, text = "Cavalgue até a Pedra do Bosque" },
		},
		reward = { xp = 1600, gold = 100 },
	}),

	-- ===== ATO II: A MARÉ DE MANA (níveis 5-10) =====
	q({
		id = "h09", chain = "main", name = "Sombras no Bosque", giver = "pedro", turnIn = "lyra",
		text = "Goblins nunca foram tão organizados. Alguém está dando mana para eles. Desmanche os acampamentos do Bosque Sombrio.",
		requires = { quests = { "h08" }, level = 5 },
		objectives = {
			{ type = "explore", location = "bosque", amount = 1, text = "Explore o Bosque Sombrio" },
			{ type = "kill", target = "goblin", amount = 8, text = "Derrote Goblins" },
			{ type = "kill", target = "goblin_arqueiro", amount = 3, text = "Derrote Goblins Arqueiros" },
		},
		reward = { xp = 4000, gold = 250 },
	}),
	q({
		id = "h09b", chain = "main", name = "A Toca dos Goblins", giver = "lyra", turnIn = "lyra",
		text = "Os goblins cavaram túneis sob as colinas do leste: a Toca. Junte até 4 Hunters no portal, desçam e derrubem o Capitão Goblin no 5º andar.",
		requires = { quests = { "h09" }, level = 6 },
		objectives = {
			{ type = "dungeonFloor", target = "toca", amount = 5, text = "Toca dos Goblins: limpe até o andar 5" },
		},
		reward = { xp = 6000, gold = 400, chest = "prata" },
	}),
	q({
		id = "h10", chain = "main", name = "O Despertar da Essência", giver = "lyra", turnIn = "elric",
		lore = "mutacao",
		text = "A essência que cai dos monstros é mana condensada: o mesmo veneno que os criou. Nas mãos certas, vira poder. Leve essência ao Elric.",
		requires = { quests = { "h09b" } },
		objectives = {
			{ type = "deliver", item = "essencia", amount = 3, text = "Junte Essência (monstros ou desmontando itens)" },
			{ type = "enchant", amount = 1, text = "Encante um item com Elric" },
		},
		reward = { xp = 4500, gold = 200, materials = { essencia = 2 } },
	}),
	q({
		id = "h10b", chain = "main", name = "O Ninho", giver = "elric", turnIn = "nia",
		text = "Elric sente mana demais vindo do leste. As aranhas do Ninho cresceram além do normal: descubra por quê.",
		requires = { quests = { "h10" }, level = 7 },
		objectives = {
			{ type = "explore", location = "toca_aranhas", amount = 1, text = "Encontre o Ninho das Aranhas" },
			{ type = "kill", target = "aranha", amount = 10, text = "Derrote Aranhas Gigantes" },
		},
		reward = { xp = 6500, gold = 300 },
	}),
	q({
		id = "h10c", chain = "main", name = "A Arquimaga do Lago", giver = "nia", turnIn = "orin",
		lore = "serafina",
		text = "Nia ouviu do Velho Orin uma história: a segunda arquimaga, Serafina, dorme dentro do Santuário do Lago, segurando a barreira. Vá até lá.",
		requires = { quests = { "h10b" } },
		objectives = {
			{ type = "explore", location = "santuario_lago", amount = 1, text = "Visite o Santuário do Lago" },
			{ type = "talk", npc = "orin", amount = 1, text = "Fale com o Velho Orin, aprendiz de Serafina" },
		},
		reward = { xp = 6000, gold = 300 },
	}),
	q({
		id = "h10d", chain = "main", name = "Pedras que Lembram", giver = "orin", turnIn = "orin",
		text = "\"O Círculo de Pedras é o único lugar do vale que não volta no tempo\", diz Orin. \"Toque a runa e ele vai te mostrar o que a barreira esconde.\"",
		requires = { quests = { "h10c" } },
		objectives = {
			{ type = "poi", target = "circulo", amount = 1, text = "Descubra o Círculo de Pedras" },
			{ type = "poiSecret", target = "circulo", amount = 1, text = "Desperte a runa do Círculo" },
		},
		reward = { xp = 7000, gold = 350, faction = { id = "circulo", amount = 120 } },
	}),
	q({
		id = "h10e", chain = "main", name = "O Fundo da Toca", giver = "orin", turnIn = "lyra",
		text = "A runa mostrou um cristal de mana roubado brilhando no fundo da Toca: é ele que alimenta os goblins. Desça até o 10º andar e derrube a Rainha Aranha que o guarda.",
		requires = { quests = { "h10d" }, level = 8 },
		objectives = {
			{ type = "dungeonFloor", target = "toca", amount = 10, text = "Toca dos Goblins: limpe até o andar 10" },
		},
		reward = { xp = 12000, gold = 800, materials = { chave_cripta = 1 } },
	}),

	-- ===== ATO III: AS TRÊS ÂNCORAS (níveis 10-15) =====
	q({
		id = "h11", chain = "main", name = "Ossos Inquietos", giver = "lyra", turnIn = "elric",
		text = "Com a barreira enfraquecendo, até os mortos do Planalto das Ruínas sentem a mana. Investigue o templo.",
		requires = { quests = { "h10e" }, level = 10 },
		objectives = {
			{ type = "explore", location = "templo_ruinas", amount = 1, text = "Encontre o Templo em Ruínas" },
			{ type = "kill", target = "esqueleto", amount = 10, text = "Derrote Esqueletos" },
			{ type = "kill", target = "esqueleto_mago", amount = 3, text = "Derrote Esqueletos Magos" },
			{ type = "deliver", item = "osso", amount = 5, text = "Entregue Ossos Antigos" },
		},
		reward = { xp = 13000, gold = 600 },
	}),
	q({
		id = "h11b", chain = "main", name = "A Cripta Esquecida", giver = "elric", turnIn = "elric",
		lore = "cripta",
		text = "Embaixo do cemitério dormem os primeiros guardiões, que sustentavam a barreira antes dos arquimagos. Algo os acordou. Use a Chave da Cripta e chegue ao 5º andar.",
		requires = { quests = { "h11" } },
		objectives = {
			{ type = "dungeonFloor", target = "cripta", amount = 5, text = "Cripta Esquecida: limpe até o andar 5" },
		},
		reward = { xp = 16000, gold = 900, chest = "prata" },
	}),
	q({
		id = "h12", chain = "main", name = "O Guardião de Pedra", giver = "elric", turnIn = "gus",
		text = "O mineiro Gus pediu ajuda: golems de pedra viva tomaram a mina ao norte das ruínas.",
		requires = { quests = { "h11b" } },
		objectives = {
			{ type = "explore", location = "mina", amount = 1, text = "Vá até a Mina Abandonada" },
			{ type = "kill", target = "golem", amount = 2, text = "Derrote Golems de Pedra" },
			{ type = "gather", item = "minerio_ferro", amount = 5, text = "Minere Ferro" },
		},
		reward = { xp = 14000, gold = 700, materials = { minerio_ferro = 5 } },
	}),
	q({
		id = "h12b", chain = "main", name = "O Diário de Valdrik", giver = "gus", turnIn = "elric",
		lore = "valdrik",
		text = "Gus achou na mina as anotações de Valdrik, o terceiro arquimago. Ele queria quebrar o ciclo e foi para o norte estudar as estrelas. Siga os passos dele até o Observatório.",
		requires = { quests = { "h12" } },
		objectives = {
			{ type = "poi", target = "observatorio", amount = 1, text = "Descubra o Observatório" },
			{ type = "poiSecret", target = "observatorio", amount = 1, text = "Alinhe a lente do astrolábio" },
		},
		reward = { xp = 15000, gold = 800, faction = { id = "circulo", amount = 200 } },
	}),
	q({
		id = "h13", chain = "main", name = "O Portão Selado", giver = "elric", turnIn = "tomas",
		text = "O astrolábio aponta para o norte, além do Portão Selado. Só Hunters de Rank C passam por ele.",
		requires = { quests = { "h12b" } },
		objectives = {
			{ type = "level", amount = 10, text = "Alcance o Nível 10 (Rank C)" },
			{ type = "discover", target = "passagem", amount = 1, text = "Ative a Pedra da Passagem" },
			{ type = "talk", npc = "tomas", amount = 1, text = "Fale com o Sargento Tomás" },
		},
		reward = { xp = 10000, gold = 500 },
	}),
	q({
		id = "h14", chain = "main", name = "A Queda do Rei Goblin", giver = "tomas", turnIn = "lyra",
		text = "O cristal roubado está com o Rei Goblin, no covil da cratera. Entre e derrube-o. Junte outros Hunters se precisar!",
		requires = { quests = { "h13" } },
		objectives = {
			{ type = "explore", location = "cratera", amount = 1, text = "Entre no Covil do Rei Goblin" },
			{ type = "kill", target = "rei_goblin", amount = 1, text = "Derrote o Rei Goblin" },
		},
		reward = { xp = 20000, gold = 1500, chest = "real" },
	}),
	q({
		id = "h14b", chain = "main", name = "O Guardião da Cripta", giver = "lyra", turnIn = "elric",
		text = "Com o cristal de volta, Elric consegue ouvir a primeira âncora: ela pede socorro do fundo da Cripta. Desça até o 10º andar.",
		requires = { quests = { "h14" }, level = 12 },
		objectives = {
			{ type = "dungeonFloor", target = "cripta", amount = 10, text = "Cripta Esquecida: limpe até o andar 10" },
		},
		reward = { xp = 24000, gold = 1200, materials = { chave_abismo = 1 } },
	}),
	q({
		id = "h14c", chain = "main", name = "Juramento da Guarda", giver = "elric", turnIn = "lyra",
		text = "A Maré de Mana engrossa: magos esqueletos e golems saem das ruínas toda noite. A Capitã Lyra pede ajuda para segurar a linha.",
		requires = { quests = { "h14b" } },
		objectives = {
			{ type = "kill", target = "esqueleto_mago", amount = 12, text = "Derrote Esqueletos Magos" },
			{ type = "kill", target = "golem", amount = 4, text = "Derrote Golems de Pedra" },
		},
		reward = { xp = 20000, gold = 1000, faction = { id = "guarda", amount = 300 } },
	}),

	-- ===== ATO IV: A ESTRELA VERMELHA (níveis 15-20) =====
	q({
		id = "h15", chain = "main", name = "Mestre de Armas", giver = "lyra", turnIn = "kael",
		text = "O que vem pela frente pede um Hunter de verdade. Mestre Kael quer ver você dominar a sua arma.",
		requires = { quests = { "h14c" }, level = 14 },
		objectives = {
			{ type = "mastery", amount = 10, text = "Alcance maestria 10 em alguma arma" },
		},
		reward = { xp = 20000, gold = 2500, chest = "real" },
	}),
	q({
		id = "h15b", chain = "main", name = "O Abismo de Pedra", giver = "kael", turnIn = "elric",
		text = "A terceira âncora, a de Valdrik, fica no coração das montanhas: o Abismo de Pedra. Use a Chave do Abismo e chegue ao 5º andar.",
		requires = { quests = { "h15" }, level = 15 },
		objectives = {
			{ type = "dungeonFloor", target = "abismo", amount = 5, text = "Abismo de Pedra: limpe até o andar 5" },
		},
		reward = { xp = 30000, gold = 2000 },
	}),
	q({
		id = "h15c", chain = "main", name = "A Âncora do Norte", giver = "elric", turnIn = "elric",
		lore = "ancora",
		text = "Lá embaixo, a âncora de Valdrik está rachada. E a rachadura não veio de dentro: veio do céu. Desça até o 10º andar e descubra o que aconteceu.",
		requires = { quests = { "h15b" } },
		objectives = {
			{ type = "dungeonFloor", target = "abismo", amount = 10, text = "Abismo de Pedra: limpe até o andar 10" },
		},
		reward = { xp = 35000, gold = 2500 },
	}),
	q({
		id = "h15d", chain = "main", name = "A Estrela Vermelha", giver = "elric", turnIn = "tomas",
		lore = "estrela",
		text = "Os soldados da Torre de Vigia viram uma estrela vermelha cair no norte, na noite em que tudo começou a piorar. Procure o último relatório deles.",
		requires = { quests = { "h15c" } },
		objectives = {
			{ type = "poi", target = "vigia", amount = 1, text = "Descubra a Torre de Vigia" },
			{ type = "poiSecret", target = "vigia", amount = 1, text = "Abra o alçapão e leia o relatório" },
			{ type = "talk", npc = "tomas", amount = 1, text = "Mostre o relatório ao Sargento Tomás" },
		},
		reward = { xp = 35000, gold = 2500 },
	}),
	q({
		id = "h15e", chain = "main", name = "O Coração do Abismo", giver = "tomas", turnIn = "elric",
		text = "Valdrik ainda está lá embaixo, preso na âncora, tentando fechar a rachadura sozinho. Desça até o 15º andar do Abismo e libere a passagem.",
		requires = { quests = { "h15d" }, level = 17 },
		objectives = {
			{ type = "dungeonFloor", target = "abismo", amount = 15, text = "Abismo de Pedra: limpe até o andar 15" },
		},
		reward = { xp = 45000, gold = 3000, chest = "real" },
	}),
	q({
		id = "h16", chain = "main", name = "O Coração da Estrela", giver = "elric", turnIn = "lyra",
		lore = "coracao",
		text = "A estrela vermelha era um meteoro de mana, e dentro dele nasceu o Devorador de Estrelas, que come a barreira por dentro. Junte um grupo (até 8) na estrela caída do norte e destrua o coração do meteoro.",
		requires = { quests = { "h15e" }, level = 18 },
		objectives = {
			{ type = "raid", amount = 1, text = "Derrote o Devorador de Estrelas na raide" },
		},
		reward = { xp = 60000, gold = 5000, chest = "real" },
	}),

	-- ===== EPÍLOGO: NOVOS HORIZONTES =====
	q({
		id = "h17", chain = "main", name = "Novos Horizontes", giver = "lyra", turnIn = "elric",
		lore = "horizontes",
		text = "Com o meteoro destruído, a rachadura parou de crescer. Elric diz que agora a barreira pode ter uma porta, e que ela vai abrir sob a sua proteção.",
		requires = { quests = { "h16" } },
		objectives = {
			{ type = "level", amount = 20, text = "Alcance o Nível 20" },
			{ type = "talk", npc = "elric", amount = 1, text = "Fale com o Arquimago Elric" },
		},
		reward = { xp = 10000, gold = 5000, chest = "real" },
	}),

	-- ===================== LENDAS (depois do nível 20): ITENS EXÓTICOS =====================
	-- Cada missão dá um item Exótico (só um equipado por vez). Todas liberam juntas depois de "Novos Horizontes".
	q({
		id = "x_ciclo", chain = "lenda", name = "Lenda: O Arsenal do Ciclo", giver = "kael", turnIn = "kael",
		text = "Kael guarda o molde de uma arma forjada no primeiro dia do Orbe. Prove que dominou o ciclo: limpe a Toca inteira e derrube 1.500 monstros.",
		requires = { quests = { "h17" }, level = 20 },
		objectives = {
			{ type = "dungeonFloor", target = "toca", amount = 20, text = "Toca dos Goblins: limpe os 20 andares" },
			{ type = "kill", target = "any", amount = 1500, text = "Derrote monstros" },
		},
		reward = { xp = 20000, gold = 5000, exoticWeapon = true },
	}),
	q({
		id = "x_egide", chain = "lenda", name = "Lenda: A Égide de Aurora", giver = "lyra", turnIn = "lyra",
		text = "A couraça do primeiro capitão da Guarda só aceita quem sabe defender. Limpe a Cripta inteira e apare 200 golpes.",
		requires = { quests = { "h17" }, level = 20 },
		objectives = {
			{ type = "dungeonFloor", target = "cripta", amount = 20, text = "Cripta Esquecida: limpe os 20 andares" },
			{ type = "parry", amount = 200, text = "Apare golpes" },
		},
		reward = { xp = 20000, gold = 5000, item = { base = "egide_aurora", rarity = "Exotico" } },
	}),
	q({
		id = "x_coroa", chain = "lenda", name = "Lenda: A Coroa dos Arquimagos", giver = "elric", turnIn = "elric",
		text = "Elric, Serafina e Valdrik dividiram uma coroa de cristal. Valdrik quer que ela fique com você. Limpe o Abismo inteiro e encante 25 itens.",
		requires = { quests = { "h17" }, level = 20 },
		objectives = {
			{ type = "dungeonFloor", target = "abismo", amount = 20, text = "Abismo de Pedra: limpe os 20 andares" },
			{ type = "enchant", amount = 25, text = "Encante itens" },
		},
		reward = { xp = 20000, gold = 5000, item = { base = "coroa_arquimagos", rarity = "Exotico" } },
	}),
	q({
		id = "x_passos", chain = "lenda", name = "Lenda: Os Passos do Tempo", giver = "nia", turnIn = "nia",
		text = "Nia diz que existem botas que andam entre um segundo e outro. Faça 250 esquivas perfeitas e ajude a derrubar o Behemoth de Mana duas vezes.",
		requires = { quests = { "h17" }, level = 20 },
		objectives = {
			{ type = "perfectDodge", amount = 250, text = "Faça esquivas perfeitas" },
			{ type = "worldBoss", amount = 2, text = "Ajude a derrotar o Behemoth de Mana" },
		},
		reward = { xp = 20000, gold = 5000, item = { base = "passos_tempo", rarity = "Exotico" } },
	}),
	q({
		id = "x_coracao", chain = "lenda", name = "Lenda: O Coração Partido", giver = "orin", turnIn = "orin",
		text = "Dos restos do meteoro, Serafina pode moldar um amuleto. Ela só precisa de mais pedaços do coração: derrote o Devorador mais 5 vezes.",
		requires = { quests = { "h17" }, level = 20 },
		objectives = {
			{ type = "raid", amount = 5, text = "Derrote o Devorador de Estrelas na raide" },
		},
		reward = { xp = 25000, gold = 6000, item = { base = "coracao_partido", rarity = "Exotico" } },
	}),
	q({
		id = "x_horizonte", chain = "lenda", name = "Lenda: O Anel do Horizonte", giver = "tomas", turnIn = "tomas",
		text = "O anel do primeiro explorador que saiu do vale passa de campeão em campeão. Vença 25 lutas na Arena e mostre que é digno.",
		requires = { quests = { "h17" }, level = 20 },
		objectives = {
			{ type = "arenaWin", amount = 25, text = "Vença lutas na Arena" },
		},
		reward = { xp = 20000, gold = 5000, item = { base = "anel_horizonte", rarity = "Exotico" } },
	}),
	-- grind pesado (pedido para durar semanas): as duas exóticas mais difíceis do jogo
	q({
		id = "x_caca", chain = "lenda", name = "Lenda: A Caçada Infinita", giver = "kael", turnIn = "kael",
		text = "Dizem que o primeiro Hunter caçou por mil dias repetidos até o elmo dele aprender a caçar sozinho. Kael quer ver se você aguenta o mesmo.",
		requires = { quests = { "x_ciclo" }, level = 20 },
		objectives = {
			{ type = "kill", target = "any", amount = 6000, text = "Derrote monstros" },
			{ type = "dungeonBoss", amount = 40, text = "Derrote chefes de masmorra" },
			{ type = "worldBoss", amount = 3, text = "Ajude a derrotar o Behemoth de Mana" },
			{ type = "stagger", amount = 500, text = "Quebre a guarda de inimigos" },
		},
		reward = { xp = 40000, gold = 15000, item = { base = "elmo_caca_infinita", rarity = "Exotico" } },
	}),
	q({
		id = "x_colecionador", chain = "lenda", name = "Lenda: O Colecionador do Vale", giver = "otto", turnIn = "otto",
		text = "Otto tem um amuleto que nunca vendeu: \"só para quem já pegou tudo o que este vale tem\". Colete, forje, prepare e abra baús até ele acreditar em você.",
		requires = { quests = { "h17" }, level = 20 },
		objectives = {
			{ type = "gather", item = "any", amount = 2000, text = "Colete recursos (minério, ervas, madeira)" },
			{ type = "craft", item = "forge", amount = 60, text = "Forje equipamentos" },
			{ type = "craft", item = "alchemy", amount = 150, text = "Prepare poções" },
			{ type = "chest", amount = 120, text = "Abra baús" },
			{ type = "upgradeTo", amount = 10, text = "Aprimore um item até +10" },
		},
		reward = { xp = 40000, gold = 15000, item = { base = "amuleto_colecionador", rarity = "Exotico" } },
	}),

	-- ===================== SECUNDÁRIAS =====================
	-- ===================== CADEIAS DAS REGIÕES =====================
	-- Campos (Orin, no lago): fazenda, pedras e o herói de pedra
	q({
		id = "r_campos1", chain = "campos", name = "A Fazenda Silenciosa", giver = "orin", turnIn = "orin",
		text = "O moinho dos campos parou de girar e os javalis tomaram a plantação. Vá ver o que aconteceu.",
		requires = { level = 3 },
		objectives = {
			{ type = "poi", target = "moinho", amount = 1, text = "Descubra o Moinho dos Campos" },
			{ type = "kill", target = "javali", amount = 6, text = "Expulse os Javalis" },
		},
		reward = { xp = 400, gold = 150, faction = { id = "guarda", amount = 60 } },
	}),
	q({
		id = "r_campos2", chain = "campos", name = "Pedras que Cantam", giver = "orin", turnIn = "orin",
		text = "Os menires do Círculo de Pedras zumbem à noite. Dizem que uma runa apagada ainda responde ao toque.",
		requires = { quests = { "r_campos1" } },
		objectives = {
			{ type = "poi", target = "circulo", amount = 1, text = "Descubra o Círculo de Pedras" },
			{ type = "poiSecret", target = "circulo", amount = 1, text = "Encontre o segredo do Círculo" },
		},
		reward = { xp = 600, gold = 200, faction = { id = "circulo", amount = 120 } },
	}),
	q({
		id = "r_campos3", chain = "campos", name = "O Herói de Pedra", giver = "orin", turnIn = "orin",
		text = "A estátua do herói Aldric guarda algo na praça. Os lobos rondam por lá: cuidado.",
		requires = { quests = { "r_campos2" } },
		objectives = {
			{ type = "poi", target = "estatua", amount = 1, text = "Descubra a Estátua do Herói" },
			{ type = "kill", target = "lobo", amount = 8, text = "Derrote os Lobos da praça" },
			{ type = "poiSecret", target = "estatua", amount = 1, text = "Encontre o segredo da Estátua" },
		},
		reward = { xp = 900, gold = 300, chest = "prata", faction = { id = "guarda", amount = 150 } },
	}),
	-- Bosque (Nia, na encruzilhada): caravana, goblins e o templo da floresta
	q({
		id = "r_bosque1", chain = "bosque", name = "A Caravana Atacada", giver = "nia", turnIn = "nia",
		text = "Uma caravana de ferro sumiu a caminho do norte. Os rastros levam para o leste.",
		requires = { level = 6 },
		objectives = {
			{ type = "poi", target = "acampamento", amount = 1, text = "Encontre a caravana" },
			{ type = "kill", target = "goblin", amount = 8, text = "Derrote Goblins" },
			{ type = "poiSecret", target = "acampamento", amount = 1, text = "Ache o que foi enterrado" },
		},
		reward = { xp = 1100, gold = 300, faction = { id = "liga", amount = 120 } },
	}),
	q({
		id = "r_bosque2", chain = "bosque", name = "Teias no Templo", giver = "nia", turnIn = "nia",
		text = "As aranhas tomaram o templo antigo do bosque. Limpe o caminho até o altar.",
		requires = { quests = { "r_bosque1" } },
		objectives = {
			{ type = "poi", target = "altar", amount = 1, text = "Descubra o Altar Esquecido" },
			{ type = "kill", target = "aranha", amount = 8, text = "Derrote Aranhas Gigantes" },
		},
		reward = { xp = 1400, gold = 350, faction = { id = "liga", amount = 150 } },
	}),
	q({
		id = "r_bosque3", chain = "bosque", name = "O Pacto da Floresta", giver = "nia", turnIn = "elric",
		text = "Os guardiões de pedra esperam uma oferenda. Cumpra o pacto e conte ao mago Elric.",
		requires = { quests = { "r_bosque2" } },
		objectives = {
			{ type = "poiSecret", target = "altar", amount = 1, text = "Deixe uma oferenda no altar" },
		},
		reward = { xp = 1600, gold = 400, chest = "prata", faction = { id = "circulo", amount = 200 } },
	}),
	-- Ruínas (Gus, perto da mina): cemitério, academia e as estrelas
	q({
		id = "r_ruinas1", chain = "ruinas", name = "Vozes no Cemitério", giver = "gus", turnIn = "gus",
		text = "Os mortos do cemitério antigo não descansam. Descubra por quê.",
		requires = { level = 10 },
		objectives = {
			{ type = "poi", target = "cemiterio", amount = 1, text = "Descubra o Cemitério Antigo" },
			{ type = "kill", target = "esqueleto", amount = 10, text = "Derrote Esqueletos" },
			{ type = "poiSecret", target = "cemiterio", amount = 1, text = "Leia a lápide sem nome" },
		},
		reward = { xp = 2200, gold = 500, faction = { id = "guarda", amount = 150 } },
	}),
	q({
		id = "r_ruinas2", chain = "ruinas", name = "A Academia Perdida", giver = "gus", turnIn = "gus",
		text = "Os astrólogos estudavam as estrelas nas ruínas a oeste. Os magos esqueletos ainda guardam o lugar.",
		requires = { quests = { "r_ruinas1" } },
		objectives = {
			{ type = "poi", target = "observatorio", amount = 1, text = "Descubra o Observatório" },
			{ type = "kill", target = "esqueleto_mago", amount = 5, text = "Derrote Esqueletos Magos" },
		},
		reward = { xp = 2600, gold = 550, faction = { id = "circulo", amount = 150 } },
	}),
	q({
		id = "r_ruinas3", chain = "ruinas", name = "A Estrela Vermelha", giver = "gus", turnIn = "elric",
		text = "Alinhe a lente do astrolábio e leve ao Elric o que as estrelas mostrarem.",
		requires = { quests = { "r_ruinas2" } },
		objectives = {
			{ type = "poiSecret", target = "observatorio", amount = 1, text = "Alinhe a lente do astrolábio" },
		},
		reward = { xp = 3000, gold = 650, chest = "prata", faction = { id = "circulo", amount = 250 } },
	}),
	-- Costa (Sol, na praia): naufrágio, garrafa e o farol
	q({
		id = "r_costa1", chain = "costa", name = "Destroços na Areia", giver = "sol", turnIn = "sol",
		text = "Um navio encalhou na costa. Os caranguejos estão saqueando a carga.",
		requires = { level = 5 },
		objectives = {
			{ type = "poi", target = "naufragio", amount = 1, text = "Descubra o Navio Naufragado" },
			{ type = "kill", target = "caranguejo", amount = 8, text = "Afaste os Caranguejos" },
		},
		reward = { xp = 900, gold = 250, faction = { id = "guarda", amount = 80 } },
	}),
	q({
		id = "r_costa2", chain = "costa", name = "A Garrafa do Capitão", giver = "sol", turnIn = "sol",
		text = "O capitão sempre deixava mensagens em garrafas. Procure na beira da água.",
		requires = { quests = { "r_costa1" } },
		objectives = {
			{ type = "poiSecret", target = "naufragio", amount = 1, text = "Encontre a garrafa na areia" },
		},
		reward = { xp = 1100, gold = 300, faction = { id = "circulo", amount = 100 } },
	}),
	q({
		id = "r_costa3", chain = "costa", name = "O Farol Apagado", giver = "sol", turnIn = "sol",
		text = "O mapa do capitão aponta para o farol abandonado. Vá até lá antes que anoiteça.",
		requires = { quests = { "r_costa2" } },
		objectives = {
			{ type = "explore", location = "farol", amount = 1, text = "Chegue ao Farol Abandonado" },
			{ type = "kill", target = "caranguejo", amount = 10, text = "Limpe o caminho" },
		},
		reward = { xp = 1400, gold = 400, chest = "prata", faction = { id = "guarda", amount = 150 } },
	}),
	-- Norte (Tomás, na passagem): posto avançado e a defesa da vila
	q({
		id = "r_norte1", chain = "norte", name = "O Posto Avançado", giver = "tomas", turnIn = "tomas",
		text = "A torre de vigia caiu e os goblins usam o posto. Retome o lugar.",
		requires = { level = 8 },
		objectives = {
			{ type = "poi", target = "vigia", amount = 1, text = "Descubra a Torre de Vigia" },
			{ type = "kill", target = "goblin_arqueiro", amount = 6, text = "Derrote Goblins Arqueiros" },
			{ type = "poiSecret", target = "vigia", amount = 1, text = "Abra o alçapão" },
		},
		reward = { xp = 1800, gold = 450, faction = { id = "guarda", amount = 150 } },
	}),
	q({
		id = "r_norte2", chain = "norte", name = "Quando a Noite Cai", giver = "tomas", turnIn = "lyra",
		text = "Os relatórios avisam: à noite, monstros atacam a entrada da vila. Ajude a defendê-la.",
		requires = { quests = { "r_norte1" } },
		objectives = {
			{ type = "invasion", amount = 1, text = "Defenda a vila de uma invasão noturna" },
		},
		reward = { xp = 2500, gold = 600, chest = "prata", faction = { id = "guarda", amount = 300 } },
	}),
	q({
		id = "r_norte3", chain = "norte", name = "Juntos Contra o Colosso", giver = "lyra", turnIn = "kael",
		text = "Quando um chefe de mundo aparecer, junte-se aos outros caçadores e derrube-o.",
		requires = { quests = { "r_norte2" } },
		objectives = {
			{ type = "worldBoss", amount = 1, text = "Ajude a derrotar um chefe de mundo" },
		},
		reward = { xp = 3500, gold = 800, chest = "real", faction = { id = "liga", amount = 300 } },
	}),

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
		text = "Luta boa não é apertar botão sem parar: ataque no ritmo, apare, esquive no último instante e quebre a guarda do inimigo.",
		requires = { quests = { "h01" } },
		objectives = {
			{ type = "rhythm", amount = 15, text = "Acerte golpes no Ritmo (clique quando o golpe termina)" },
			{ type = "parry", amount = 5, text = "Apare golpes (F na hora certa)" },
			{ type = "perfectDodge", amount = 3, text = "Faça esquivas perfeitas (Q no último instante)" },
			{ type = "finisher", amount = 10, text = "Acerte finalizadores de combo (maestria 3)" },
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
	{ id = "d_esquiva", name = "Treino de Esquiva", objectives = { { type = "perfectDodge", amount = 8, text = "Faça esquivas perfeitas" } }, reward = { xp = 300, gold = 150 } },
	{ id = "d_aparar", name = "Treino de Guarda", objectives = { { type = "parry", amount = 10, text = "Apare golpes inimigos" } }, reward = { xp = 350, gold = 160 } },
	{ id = "d_quebra", name = "Quebra-Guardas", objectives = { { type = "stagger", amount = 10, text = "Quebre a guarda de inimigos" } }, reward = { xp = 400, gold = 180 } },
	{ id = "d_caranguejo", name = "Contrato: Praia", minLevel = 4, objectives = { { type = "kill", target = "caranguejo", amount = 10, text = "Derrote Caranguejos" } }, reward = { xp = 450, gold = 220 } },
}
Quests.DailyBonus = { gold = 500, chest = "prata" }

-- Contratos da Guilda (Ulf, no Salão das Guildas): só para quem tem guilda; 3 por dia, entregues ao Ulf.
-- Cada entrega dispara o evento "guildContract" (pontos e meta semanal da guilda). Os de entrega
-- (deliver) abastecem o salão: o material sai da sua bolsa na hora de entregar.
Quests.GuildPool = {
	{ id = "g_lobos", name = "Guilda: Matilha na Estrada", objectives = { { type = "kill", target = "lobo", amount = 20, text = "Derrote Lobos" } }, reward = { xp = 600, gold = 300 } },
	{ id = "g_javalis", name = "Guilda: Carne para o Banquete", objectives = { { type = "kill", target = "javali", amount = 12, text = "Derrote Javalis" }, { type = "deliver", item = "couro", amount = 8, text = "Entregue Couro" } }, reward = { xp = 700, gold = 350 } },
	{ id = "g_lenha", name = "Guilda: Lenha para a Fogueira", objectives = { { type = "deliver", item = "madeira", amount = 25, text = "Entregue Madeira" } }, reward = { xp = 500, gold = 300 } },
	{ id = "g_hidromel", name = "Guilda: Ervas do Hidromel", objectives = { { type = "deliver", item = "erva_verde", amount = 15, text = "Entregue Ervas Verdes" }, { type = "deliver", item = "cogumelo_azul", amount = 5, text = "Entregue Cogumelos Azuis" } }, reward = { xp = 600, gold = 320 } },
	{ id = "g_ferro", name = "Guilda: Ferro para as Lâminas", minLevel = 5, objectives = { { type = "deliver", item = "minerio_ferro", amount = 15, text = "Entregue Minério de Ferro" } }, reward = { xp = 900, gold = 450 } },
	{ id = "g_goblins", name = "Guilda: Ataque ao Acampamento", minLevel = 5, objectives = { { type = "kill", target = "goblin", amount = 20, text = "Derrote Goblins" }, { type = "kill", target = "goblin_arqueiro", amount = 8, text = "Derrote Arqueiros Goblins" } }, reward = { xp = 1100, gold = 500 } },
	{ id = "g_aranhas", name = "Guilda: Seda para as Velas", minLevel = 7, objectives = { { type = "kill", target = "aranha", amount = 15, text = "Derrote Aranhas" }, { type = "deliver", item = "seda", amount = 10, text = "Entregue Seda" } }, reward = { xp = 1400, gold = 600 } },
	{ id = "g_ossos", name = "Guilda: Os Mortos Inquietos", minLevel = 9, objectives = { { type = "kill", target = "esqueleto", amount = 20, text = "Derrote Esqueletos" }, { type = "kill", target = "esqueleto_mago", amount = 6, text = "Derrote Esqueletos Magos" } }, reward = { xp = 1800, gold = 700 } },
	{ id = "g_golem", name = "Guilda: Coração de Pedra", minLevel = 12, objectives = { { type = "kill", target = "golem", amount = 4, text = "Derrote Golems" }, { type = "deliver", item = "nucleo_golem", amount = 2, text = "Entregue Núcleos de Golem" } }, reward = { xp = 2500, gold = 900, chest = "prata" } },
	{ id = "g_masmorra", name = "Guilda: Descida em Grupo", minLevel = 8, objectives = { { type = "dungeonBoss", amount = 1, text = "Derrote um chefe de masmorra" } }, reward = { xp = 2000, gold = 800, chest = "prata" } },
	{ id = "g_mundo", name = "Guilda: Fera do Mundo", minLevel = 10, objectives = { { type = "worldBoss", amount = 1, text = "Lute contra um chefe de mundo" } }, reward = { xp = 2000, gold = 800, chest = "prata" } },
	{ id = "g_guarda", name = "Guilda: Escudo e Machado", objectives = { { type = "parry", amount = 15, text = "Apare golpes inimigos" }, { type = "stagger", amount = 8, text = "Quebre guardas" } }, reward = { xp = 700, gold = 350 } },
	{ id = "g_arena", name = "Guilda: Honra na Arena", minLevel = 10, objectives = { { type = "arenaWin", amount = 2, text = "Vença lutas na Arena" } }, reward = { xp = 1500, gold = 700 } },
	{ id = "g_segredos", name = "Guilda: Histórias para o Escaldo", minLevel = 4, objectives = { { type = "chest", amount = 3, text = "Abra baús" } }, reward = { xp = 600, gold = 400 } },
}

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
for _, contract in Quests.GuildPool do
	contract.giver = "ulf"
	contract.turnIn = "ulf"
	contract.daily = true
	contract.guild = true
	contract.text = "Contrato da Guilda, entregue ao Ulf no Salão das Guildas. Rende pontos para a sua guilda. Renova todo dia."
	contract.requires = { level = contract.minLevel }
	Quests.ById[contract.id] = contract
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
	if reward.exoticWeapon then
		table.insert(parts, "Arma EXÓTICA do seu tipo")
	elseif reward.item then
		table.insert(parts, "Item EXÓTICO")
	end
	if reward.faction then
		table.insert(parts, ("+%d de reputação"):format(reward.faction.amount or 0))
	end
	return table.concat(parts, "  •  ")
end

return Quests
