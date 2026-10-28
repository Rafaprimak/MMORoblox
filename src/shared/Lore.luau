-- Diário de lore (Crônicas): a história do Orbe Infinito, em páginas liberadas pelo que o jogador faz.
-- unlock = { evento de missão, alvo } (alvo nil = qualquer) ou { "quest", id } (ao entregar a missão).
-- Páginas na ordem da história.
local Lore = {}

Lore.Pages = {
	{
		id = "orbe",
		title = "O Orbe Infinito",
		hint = "Complete a missão \"O Dia que Volta\".",
		unlock = { "quest", "h05b" },
		text = "Há muito tempo, a mana do mundo transbordou. A Maré de Mana muda tudo o que toca: quem não tem resistência vira monstro. Para salvar a Vila Aurora, três arquimagos (Elric, Serafina e Valdrik) ergueram uma barreira em volta do vale: o Orbe Infinito. Mas para segurar algo tão grande, eles amarraram a barreira ao próprio tempo. Todo dia, o Orbe volta para a mesma manhã. Os monstros renascem, os moradores repetem as mesmas palavras e ninguém lembra. Ninguém, menos os Hunters.",
	},
	{
		id = "mutacao",
		title = "A Maré de Mana",
		hint = "Complete a missão \"O Despertar da Essência\".",
		unlock = { "quest", "h10" },
		text = "Slimes são água que bebeu mana. Lobos ficam maiores a cada dia que volta. Goblins aprenderam a falar. A essência que cai deles é a mesma mana que os mudou, só que parada e quieta. Elric diz que a resistência dos Hunters é um dom raro: o corpo de vocês bebe a mana sem se perder nela. Por isso vocês ficam mais fortes a cada dia repetido, enquanto o resto do vale continua igual.",
	},
	{
		id = "aurora",
		title = "A Vila Aurora",
		hint = "Descubra o Moinho dos Campos e seu segredo.",
		unlock = { "poiSecret", "moinho" },
		text = "Antes da barreira, Aurora era um acampamento de caçadores. Diziam que o sol nascia ali antes de qualquer outro lugar. O fazendeiro do moinho guardava as moedas da primeira colheita num fardo de feno, \"para o dia em que a vila precisar\". Ele ainda guarda. Todo dia, de novo.",
	},
	{
		id = "serafina",
		title = "A Arquimaga do Lago",
		hint = "Complete a missão \"A Arquimaga do Lago\".",
		unlock = { "quest", "h10c" },
		text = "Serafina era a mais jovem dos três. Quando a barreira começou a falhar, ela entrou no lago e adormeceu dentro dele, virando a âncora viva do Orbe. O Velho Orin era aprendiz dela; ele é o único morador que às vezes lembra de um dia anterior, como se um pouco da mana dela tivesse ficado nele. Nas noites calmas, a água do santuário brilha no ritmo de uma respiração.",
	},
	{
		id = "menires",
		title = "As Pedras que Lembram",
		hint = "Encontre o segredo do Círculo de Pedras.",
		unlock = { "poiSecret", "circulo" },
		text = "O Círculo de Pedras é mais velho que o Orbe. É o único lugar do vale que não volta no tempo: as marcas feitas nele ontem continuam lá hoje. Os arquimagos usaram os menires para medir a barreira. Uma runa, apagada há séculos, ainda responde ao toque de quem carrega mana no sangue.",
	},
	{
		id = "caravana",
		title = "A Caravana Perdida",
		hint = "Cave a terra revolvida no Acampamento Abandonado.",
		unlock = { "poiSecret", "acampamento" },
		text = "A caravana levava ferro e um cristal de mana para o forte do norte. Os goblins atacaram de surpresa e levaram o cristal; o cofre foi enterrado a tempo. Entre as moedas havia um bilhete: \"o Rei Goblin quer o cristal para mandar nos outros; não deixem chegar à cratera\".",
	},
	{
		id = "guarnicao",
		title = "A Última Guarnição",
		hint = "Ache o alçapão escondido na Torre de Vigia.",
		unlock = { "poiSecret", "vigia" },
		text = "A torre de vigia caiu numa única noite. No último relatório, os soldados escreveram: \"uma estrela vermelha caiu além das montanhas; o céu rachou como vidro; os goblins não vêm sozinhos, algo os comanda do norte\". Ninguém voltou para buscar o soldo escondido no alçapão.",
	},
	{
		id = "heroi",
		title = "O Herói de Pedra",
		hint = "Examine a coluna rachada na praça da Estátua.",
		unlock = { "poiSecret", "estatua" },
		text = "A estátua lembra Aldric, o primeiro Hunter de Aurora, o primeiro a lembrar do dia anterior. No diário escondido na coluna, ele conta que perdeu o braço esquerdo selando o Portão do Norte e que o selo só aguentaria \"enquanto houver caçadores dispostos a lembrar\".",
	},
	{
		id = "cripta",
		title = "Os Primeiros Guardiões",
		hint = "Complete a missão \"A Cripta Esquecida\".",
		unlock = { "quest", "h11b" },
		text = "Antes dos arquimagos, a vila era protegida por guardiões que davam a própria vida à terra. Eles foram enterrados embaixo do cemitério, e os ossos deles ainda seguram um pedaço da barreira. Quando a mana entrou na cripta, um deles acordou faminto: o Rei Lich. Ele não quer destruir a vila. Ele quer voltar a protegê-la, do único jeito que ainda entende.",
	},
	{
		id = "mortos",
		title = "O Campo dos Mortos",
		hint = "Leia a lápide sem nome no Cemitério Antigo.",
		unlock = { "poiSecret", "cemiterio" },
		text = "Debaixo da lápide sem nome está a guardiã que morreu defendendo a cripta. Seu bilhete de despedida pede perdão: ela não conseguiu impedir que o Rei Lich levasse os ossos dos antigos para baixo da terra.",
	},
	{
		id = "valdrik",
		title = "O Diário de Valdrik",
		hint = "Complete a missão \"O Diário de Valdrik\".",
		unlock = { "quest", "h12b" },
		text = "\"A barreira nos salvou e nos prendeu. Uma vila que vive o mesmo dia para sempre não está viva.\" Valdrik, o terceiro arquimago, queria quebrar o ciclo sem deixar a Maré entrar. Ele foi para o norte estudar as estrelas, porque acreditava que a mana do céu era mais calma que a da terra. As últimas páginas falam de uma luz vermelha crescendo no céu, cada dia um pouco maior.",
	},
	{
		id = "astrologos",
		title = "Os Astrólogos",
		hint = "Alinhe a lente do astrolábio no Observatório.",
		unlock = { "poiSecret", "observatorio" },
		text = "Os astrólogos da academia mapeavam as estrelas para prever as marés de mana. Na última noite registrada, escreveram que uma estrela vermelha não seguia o céu: ela vinha em direção ao vale.",
	},
	{
		id = "floresta",
		title = "O Templo da Floresta",
		hint = "Deixe uma oferenda no Altar Esquecido.",
		unlock = { "poiSecret", "altar" },
		text = "Antes das cidades, as tribos da floresta faziam oferendas ao espírito do bosque. Os guardiões de pedra ainda abrem os olhos à noite, esperando alguém que se lembre do pacto: a floresta protege quem a respeita.",
	},
	{
		id = "capitao",
		title = "O Ouro do Capitão",
		hint = "Pegue a garrafa na areia perto do Navio Naufragado.",
		unlock = { "poiSecret", "naufragio" },
		text = "O navio não veio de fora: nada entra no Orbe. Ele foi construído aqui, por gente que tentou atravessar a barreira pelo mar. A mensagem na garrafa termina com uma frase tremida: \"a água vira parede; voltamos para a mesma praia toda manhã\".",
	},
	{
		id = "rei",
		title = "A Queda do Rei Goblin",
		hint = "Derrote o Rei Goblin no covil da cratera.",
		unlock = { "kill", "rei_goblin" },
		text = "O Rei Goblin caiu e o cristal roubado voltou para as mãos certas. Nos pés do trono, gravado em pedra antiga, um símbolo que não é goblin: o mesmo selo dos arquimagos, partido ao meio por uma rachadura vermelha.",
	},
	{
		id = "profundezas",
		title = "O Que Respira Embaixo",
		hint = "Derrote o chefe de qualquer masmorra.",
		unlock = { "dungeonBoss" },
		text = "As masmorras não foram cavadas: cresceram. Cada vez que o dia volta, um pouco de mana fica presa embaixo da terra, e os andares ficam mais fundos. Os chefes não protegem tesouros; protegem as raízes da barreira.",
	},
	{
		id = "ancora",
		title = "A Âncora do Norte",
		hint = "Complete a missão \"A Âncora do Norte\".",
		unlock = { "quest", "h15c" },
		text = "No fundo do Abismo de Pedra, a âncora de Valdrik está rachada de cima para baixo. A rachadura não veio da terra: veio do céu. Valdrik ainda está lá, meio homem e meio pedra, segurando a fenda com as próprias mãos. Ele não lembra mais o próprio nome, mas lembra de uma coisa: \"a estrela tem fome\".",
	},
	{
		id = "despertar",
		title = "O Despertar",
		hint = "Ajude a derrotar um chefe de mundo.",
		unlock = { "worldBoss" },
		text = "Pela rachadura no céu, a mana do meteoro escorre para dentro do Orbe. Às vezes ela se junta num corpo só, enorme: o Behemoth de Mana. Sozinho, ninguém derruba um colosso. Quando o chão tremer, os caçadores do vale precisam se juntar.",
	},
	{
		id = "estrela",
		title = "A Estrela Vermelha",
		hint = "Complete a missão \"A Estrela Vermelha\".",
		unlock = { "quest", "h15d" },
		text = "A estrela vermelha era um meteoro de mana pura. Ele bateu no Orbe, rachou a barreira no norte e caiu na passagem. Desde então o dia volta mais rápido, os monstros mudam mais e as âncoras sangram. O meteoro não está parado: dentro dele, alguma coisa está crescendo.",
	},
	{
		id = "coracao",
		title = "O Coração da Estrela",
		hint = "Derrote o Devorador de Estrelas na raide.",
		unlock = { "raid" },
		text = "Dentro do meteoro nasceu o Devorador de Estrelas, uma fome feita de luz que comia a barreira por dentro. Quando ele caiu, o coração do meteoro se partiu em fragmentos que ainda brilham. Os Hunters que os carregam dizem ouvir um batimento, baixinho, quando a noite fica escura demais.",
	},
	{
		id = "horizontes",
		title = "Novos Horizontes",
		hint = "Complete a missão \"Novos Horizontes\".",
		unlock = { "quest", "h17" },
		text = "Sem o Devorador, a rachadura parou de crescer. Elric, Serafina e o que restou de Valdrik concordaram: a barreira não precisa mais ser uma prisão. Ela pode ter uma porta. Do lado de fora há terras que ninguém do vale vê há séculos, e a Maré de Mana ainda está lá. Por isso a porta só vai abrir sob a proteção de quem lembra: você.",
	},
}
Lore.ById = {}
for _, page in Lore.Pages do
	Lore.ById[page.id] = page
end

return Lore
