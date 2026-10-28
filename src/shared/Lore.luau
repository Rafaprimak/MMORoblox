-- Diário de lore: páginas da história do mundo, liberadas pelo que o jogador descobre.
-- unlock = { evento de missão, alvo } (alvo nil = qualquer). Páginas na ordem da história.
local Lore = {}

Lore.Pages = {
	{
		id = "aurora",
		title = "A Vila Aurora",
		hint = "Descubra o Moinho dos Campos e seu segredo.",
		unlock = { "poiSecret", "moinho" },
		text = "Antes de ser vila, Aurora era um acampamento de caçadores. Diziam que o sol nascia ali antes de qualquer outro lugar, e que quem acordasse cedo veria a luz cair sobre o vale como ouro derretido. O fazendeiro do moinho guardava as moedas da primeira colheita num fardo de feno: \"para o dia em que a vila precisar\".",
	},
	{
		id = "menires",
		title = "As Pedras que Cantam",
		hint = "Encontre o segredo do Círculo de Pedras.",
		unlock = { "poiSecret", "circulo" },
		text = "O Círculo de Pedras é mais velho que qualquer reino. Os arcanos acreditam que os menires guardam a memória do mundo e zumbem quando alguém os desperta. Uma runa, apagada há séculos, ainda responde ao toque de quem carrega essência mágica.",
	},
	{
		id = "guarnicao",
		title = "A Última Guarnição",
		hint = "Ache o alçapão escondido na Torre de Vigia.",
		unlock = { "poiSecret", "vigia" },
		text = "A torre de vigia caiu numa única noite. Os soldados esconderam o soldo sob o alçapão e escreveram no último relatório: \"os goblins não vêm sozinhos; algo os comanda do norte\". Ninguém voltou para buscar o ouro.",
	},
	{
		id = "heroi",
		title = "O Herói de Pedra",
		hint = "Examine a coluna rachada na praça da Estátua.",
		unlock = { "poiSecret", "estatua" },
		text = "A estátua lembra Aldric, o primeiro Hunter de Aurora. No diário escondido na coluna ele conta que perdeu o braço esquerdo selando o Portão do Norte, e que o selo só aguentaria \"enquanto houver caçadores dispostos a vigiá-lo\".",
	},
	{
		id = "caravana",
		title = "A Caravana Perdida",
		hint = "Cave a terra revolvida no Acampamento Abandonado.",
		unlock = { "poiSecret", "acampamento" },
		text = "A caravana levava ferro e mantimentos para o forte do norte. Os goblins atacaram de surpresa, mas o cofre foi enterrado a tempo. Entre as moedas havia um bilhete: \"o Rei Goblin quer o ferro para forjar armas; não deixem chegar à cratera\".",
	},
	{
		id = "astrologos",
		title = "Os Astrólogos",
		hint = "Alinhe a lente do astrolábio no Observatório.",
		unlock = { "poiSecret", "observatorio" },
		text = "Os astrólogos da academia mapeavam as estrelas para prever as marés de essência. Na última noite registrada, escreveram que uma estrela vermelha nasceu sobre as montanhas, e que as masmorras começaram a \"respirar\" de novo.",
	},
	{
		id = "mortos",
		title = "O Campo dos Mortos",
		hint = "Leia a lápide sem nome no Cemitério Antigo.",
		unlock = { "poiSecret", "cemiterio" },
		text = "Debaixo da lápide sem nome está a guardiã que morreu defendendo a cripta. Seu bilhete de despedida pede perdão: ela não conseguiu impedir que o Rei Lich levasse os ossos dos antigos para baixo da terra.",
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
		text = "O capitão do navio fugia de uma tempestade que não era natural: as nuvens vinham do norte, da mesma cratera de onde saem os goblins. O mapa na garrafa termina com uma frase tremida: \"o mar também está com medo\".",
	},
	{
		id = "rei",
		title = "A Queda do Rei Goblin",
		hint = "Derrote o Rei Goblin no covil da cratera.",
		unlock = { "kill", "rei_goblin" },
		text = "O Rei Goblin caiu, mas seu trono era só uma cadeira emprestada. Nos pés do trono, gravado em pedra antiga, um símbolo que não é goblin: o mesmo selo que aparece nas portas das masmorras.",
	},
	{
		id = "profundezas",
		title = "O Que Respira Embaixo",
		hint = "Derrote o chefe de qualquer masmorra.",
		unlock = { "dungeonBoss" },
		text = "As masmorras não foram cavadas: cresceram. Cada andar é um pouco mais antigo que o anterior, como se o mundo guardasse por baixo tudo o que esqueceu. Os chefes não protegem tesouros; protegem o caminho para baixo.",
	},
	{
		id = "despertar",
		title = "O Despertar",
		hint = "Ajude a derrotar um chefe de mundo.",
		unlock = { "worldBoss" },
		text = "Os chefes de mundo sobem das profundezas quando a estrela vermelha fica mais forte. Os caçadores de Aurora já sabem: quando o chão tremer e o céu escurecer, é hora de se juntar. Sozinho, ninguém derruba um colosso.",
	},
	{
		id = "coracao",
		title = "O Coração da Estrela",
		hint = "Derrote o Devorador de Estrelas na raide.",
		unlock = { "raid" },
		text = "A estrela vermelha não era uma estrela: era um ovo. O Devorador nasceu dela faminto de luz, e cada estrela que ele engole deixa o céu um pouco mais escuro. Quando cai, o coração dele se parte em fragmentos que ainda brilham. Os caçadores que os carregam dizem ouvir um batimento, baixinho, quando a noite fica escura demais.",
	},
}
Lore.ById = {}
for _, page in Lore.Pages do
	Lore.ById[page.id] = page
end

return Lore
