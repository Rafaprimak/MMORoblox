# Roadmap — Hunter RPG

Lista do que já existe e do que vem a seguir, em ordem de prioridade. Antes de pegar um item, leia o [AGENTS.md](AGENTS.md).

**Legenda:** ✅ feito · 🧪 feito mas não testado no Studio · ⬜ a fazer
**Tamanho:** (P) poucas horas · (M) 1–3 dias · (G) uma semana ou mais

---

## ✅ Já existe (v2)

- ✅ Mundo procedural com terreno: vila, planícies, bosque, ruínas, lago, praia, montanhas, passagem e covil do chefe
- ✅ 4 classes, 16 habilidades com ranks e pontos por nível
- ✅ 8 tipos de arma com combo próprio; maestria por arma (finalizador no nível 3, ataque pesado no 5)
- ✅ Estamina, corrida, esquiva com invencibilidade, montaria, pedras de viagem e mapa
- ✅ Inimigos com IA (corpo a corpo, à distância, investida, pancada em área), elites, chefe com fases e ajudantes
- ✅ 7 raridades, drops com feixe de luz, baús com roleta e chances visíveis
- ✅ Profissões: mineração, herbalismo, lenhador, ferraria, alquimia, encantamento
- ✅ NPCs de ofício, 25 missões com objetivos variados, contratos diários com bônus
- ✅ HUD, inventário, personagem, diário de missões, diálogo, janelas de ofício, celular com botões na tela

---

## Fase 0 — Estabilizar (prioridade máxima)

Coisas que já existem mas ainda não foram testadas jogando, ou bugs conhecidos.

- ✅ Testar no Studio: forja (criar e aprimorar), encantar e desmontar, alquimia, loja (comprar/vender) (P)
- ✅ Testar montaria (montar, desmontar ao tomar dano, velocidade, pose sentada) (P)
- ✅ Testar Arqueiro e Assassino (projéteis, Passo Sombrio, veneno, ataque pelas costas) (P)
- ✅ Testar o Rei Goblin: investida, pancada em área, invocação, fase de fúria, barra de chefe (P)
- ✅ Testar a cadeia de missões inteira (h01 → h15) e os contratos diários (M)
- ✅ Testar coleta (minérios, plantas, árvores) e o feixe de objetivo apontando para recursos (P)
- ✅ Conferir as correções da última rodada: roleta do baú visível, tecla I, bonecos lado a lado (P)
- 🧪 Balanceamento inicial: slime bate menos e mais devagar (4 a cada 1,6 s) e puxa de mais perto; proteção de iniciante (−35% de dano no nível 1, sumindo até o 5); vida volta rápido fora de combate (5%/s depois de 5 s sem apanhar) (P)
- ⬜ Animações das armas: conferir a pegada de lança, arco e cajado e as poses de golpe (P)
- ⬜ Performance: medir FPS no celular; reduzir a natureza em `Scatter` se precisar; LOD para árvores distantes (M)
  - 🧪 Cenário distante some só no cliente (`DetailCulling`) e configuração "Qualidade gráfica" (baixa/média/alta). **Falta medir no celular.**
- ✅ Investigar os erros `CorePackages` (React) no Output: são internos do Roblox (lista de jogadores/chat novos). O jogo só desliga Mochila e Vida, que é o uso normal; pode ignorar (P)
- 🧪 Mapa: estradas e ruas da vila desenhadas, mais detalhe no relevo, zoom com a roda do mouse ou +/-, arrastar para mover e botão "Eu" (P)
- 🧪 Escala do mundo ×1.5: mapa, casas, árvores, rochas e locais proporcionais ao personagem (`World.Scale`, `Props.scaleModel`) (M)
- 🧪 NPCs apoiados no chão por raycast (alguns ficavam enterrados) (P)
- 🧪 Golpe pesado saiu do botão direito (conflito com a câmera): agora é segurar **R** e carregar (P)
- 🧪 Golpes leves não andam mais para frente (P)
- 🧪 **Combate dinâmico:** ritmo de combo (clicar cedo quebra), estamina por golpe, bloquear/aparar (F), esquiva perfeita, postura e atordoamento, contra-ataque, ataques imbloqueáveis (‼), missões e diárias de aparar/quebrar guarda (G)
- ⬜ Balancear o combate dinâmico depois dos testes: janelas de ritmo/aparar, postura dos inimigos, custo de estamina (P)

## Fase 1 — Polimento do que já existe

- ⬜ Arte: trocar os modelos blocados por meshes (Creator Store, IA do Studio ou artista), começando pelas armas lendárias e pelos chefes (G)
- ⬜ Animações reais (Animation Editor) para golpes, magias e inimigos, mantendo o `Animator` procedural como reserva (G)
  - 🧪 Animator procedural reescrito: crossfade, smootherstep, quadros com antecipação/acompanhamento, postura de combate por arma, respiração, inclinação ao correr, tranco ao levar dano
- 🧪 Montaria animada: cavalo novo com juntas (pernas, cabeça e cauda galopando) (M)
- 🧪 Travar a mira no inimigo (T / botão do meio), estilo souls; barras de ritmo e carga no retículo (M)
- 🧪 Modelagem caprichada: armas detalhadas por tipo, armadura/elmo/botas visíveis (capa no Lendário+), árvores, pedras e inimigos com mais detalhe (G)
- 🧪 Forja, alquimia, torre do encantador e empório viram construções com interior (NPCs lá dentro); câmera Invisicam (M)
- 🧪 Vila reformulada: ruas, calçadas, praça, vielas e becos; casas alinhadas sem sobreposição; chão da vila alinhado à grade de voxels (NPCs e bancos não afundam mais) (M)
- 🧪 Vila mais espaçosa (ruas de 12, praça de 52, jardins na frente das casas), traçado em `TownPlan`, chão sem grama embaixo do calçamento, lojas temáticas (ferraria de tijolos com pátio de trabalho, chalé de alquimia com horta, empório com piso quadriculado), pisos variados nas casas, móveis na altura certa (M)
- 🧪 Calibração da altura do terreno (o chão visível ficava ~meio voxel acima da conta e cobria pisos e pés) (P)
- 🧪 Som com a biblioteca oficial do Roblox: golpes, acertos, aparar, bloqueio, magias, explosões, moedas, nível, baús, interface; música na vila, explorando, à noite e no chefe; vento e pássaros (M)
- 🧪 Interface com identidade própria (azul-noite e dourado, moldura dupla, fita no título, fonte serifada) (M)
- 🧪 Modelagem: telhados com telhas, cumeeira e oitões; casas com alicerce, viga, peitoril, porta de tábuas com arco; NPCs com cabelo, barba e roupa do ofício (M)
- 🧪 Música de combate por tipo de inimigo (slime, lobo/javali, caranguejo, goblin, aranha, esqueleto, golem, rei goblin), com crossfade de volta para a região depois da luta (P)
- 🧪 Fachadas refeitas: casas com batentes e verga de pedra, pedra-chave, porta recuada com travessas, alpendre de duas águas, janelas com moldura, venezianas e floreiras (também na frente); lojas com vão da porta sem peças sobrepostas (sem "tremido" na batente), mísulas, soleira e janelas da frente; vitrines do empório do lado de fora (M)
- 🧪 Polimento: terreno sem grama animada na vila (pisos e pés visíveis), portas sem folha atravessando o batente, cena de revelação animada por cinemática direta, poeira ao correr/aterrissar, câmera que abre na corrida, folhas/pólen/neve/cinzas por região, luz e cor ajustadas, botões e janelas com degradê e efeito ao passar o mouse (M)
- 🧪 Cena de revelação: seu personagem abre o baú (tampa, feixe de luz, ergue o item) e vê o ovo rachar e o pet aparecer (M)
- 🧪 9 locais de interesse com descoberta, baú escondido, marcadores no mapa e conquistas (M)
- 🧪 Vila viva: 10 moradores com rotas e balões de fala, guardas, crianças, animais, pássaros, borboletas, vaga-lumes; feira, bancos, poço, carroça, varal, galinheiro, canteiros, bandeirinhas, janelas que acendem à noite (M)
- ⬜ Sons de verdade: golpes por tipo de arma, magias, passos, ambiente por bioma, música da vila e do chefe (M)
  - 🧪 Sistema pronto: catálogo `SoundIds` (efeitos, ambiente por região, música de vila/exploração/noite/chefe), pré-carregamento com reserva automática, crossfade e volume de música. **Falta escolher os IDs na Creator Store** (passo a passo no README).
- 🧪 VFX melhores: rastros por raridade e encantamento, faíscas na ponta (Lendário+), impacto por elemento, aura por rank (M)
- 🧪 Tutorial guiado nos primeiros minutos: 8 dicas que avançam com a ação (andar, missão, feixe, ritmo, aparar, esquiva, inventário, mapa), salvas no servidor (M)
- 🧪 Ciclo de dia e noite (14 + 6 min): inimigos mais fortes e mais Elites à noite, +XP/ouro/drops, postes acesos, relógio no HUD (M)
- 🧪 Configurações (P): volume, sensibilidade, números de dano, tremida, barra de ritmo, dicas, recomeçar tutorial (P)
- 🧪 Ícones: itens com modelo 3D próprio (`ItemModels`) em todas as janelas, na mão, no chão e no baú (M)
  - ⬜ Usar os mesmos modelos de elmo/armadura/botas no personagem (hoje são peças genéricas por raridade)

## Fase 2 — Conteúdo

- 🧪 **Masmorras instanciadas (endgame)**: Toca dos Goblins (5+), Cripta Esquecida (10+), Abismo de Pedra (15+); grupo de 1 a 4 no portal, começa quando todos dão Pronto; 20 andares em uma corrida só (sem ponto de retorno; `data.dungeons` guarda o recorde); chefe a cada 5 andares com baú por membro; força dos inimigos sobe por andar e a vida pelo tamanho do grupo (G)
  - 🧪 Itens Únicos (estilo UT): raridade Única fora dos baús, 8 itens com efeito próprio caindo de chefes (1,5%, dobro no andar 20) e anúncio para o servidor
  - 🧪 Conjuntos: 3 conjuntos de 4 peças com bônus de 2 e 4 peças
  - 🧪 Andares com mecânica sorteada (ondas, alavancas com emboscada, grelhas de fogo), objetivo extra com bônus (tempo, ninguém cair, caçada ao Campeão, relíquias), tijolo solto com baú secreto, baú suspeito (mímico), altar de bênção
  - 🧪 Material e itens exclusivos por masmorra (18 bases) com perk de assinatura; Mercador de Masmorras (Varg) com chaves, poção grande, tônico de pedra e itens exclusivos; 4 conquistas e títulos
  - ⬜ Balancear vida/dano dos andares e dos chefes depois de testar em grupo
  - ⬜ Mais mecânicas (proteger cristal, plataformas, salas escuras), modificadores semanais e ranking de tempo
- 🧪 Corrigido: o chefe nunca era marcado como chefe (`def.boss`), então a barra do chefe e a música de chefe não apareciam
- ⬜ Novas regiões e níveis 20–40: Pântano Venenoso, Deserto de Âmbar, Pico Vulcânico, cada uma com 3 inimigos, 1 chefe e recursos tier 3 (G)
- ⬜ World boss com horário e anúncio global, com recompensa por participação (M)
- ⬜ Eventos sazonais com skins temporárias (Halloween, Natal), seguindo a ideia da "camada de meme rotativa" (M)
- ⬜ Mais missões secundárias, missões repetíveis por região e uma cadeia da história para ranks B → S (M)
- ⬜ Pesca como profissão (o píer e o lago já existem) (M)
- ⬜ Culinária: comidas com buffs temporários (M)

## Fase 3 — Social (o "MMO")

- ⬜ Grupos (party): XP e loot compartilhados, marcador dos colegas no mapa (M)
- ⬜ Guildas: criação, cargos, chat, banco da guilda e missões de guilda (G)
- ⬜ Troca entre jogadores com confirmação dupla e registro (M)
- ⬜ Leilão/mercado global (com DataStore/MemoryStore) (G)
- ⬜ Rankings: nível, poder de equipamento, kills do chefe, por semana (M)
- ⬜ Arena PvP opcional (duelo 1v1 e 3v3) com rank próprio (G)
- ⬜ Emotes e chat com balões (P)

## Fase 4 — Progressão de longo prazo

- 🧪 Árvore de talentos por classe: 8 habilidades (4 avançadas), loadout das teclas 1-4, passivas em 3 ramos com tiers, redistribuir pontos (G)
- 🧪 Papéis de grupo: Guerreiro tanque (ameaça e Provocar), Clérigo suporte (classe nova: curas, escudos, bênçãos), Mago controle, Arqueiro/Assassino dano; sistema de ameaça nos inimigos (G)
- 🧪 Perks nos itens (estilo Destiny), 0 a 3 por raridade, com reforja no Bruno (G)
- 🧪 Elmo, botas, amuleto e anel; 45 bases novas incluindo tier 3 (M)
- 🧪 Pets com bônus, nível e ovos com chances visíveis (M)
- 🧪 Jornada: login diário em sequência, Passe do Hunter grátis (50 tiers), 15 conquistas com títulos, marcos de nível (G)
- ⬜ Subclasses no Rank B (ex.: Guerreiro → Paladino/Berserker) (G)
- 🧪 Sets de equipamento com bônus por 2/4 peças (ver Masmorras) (M)
- ⬜ Gemas e soquetes (M)
- ⬜ Pets que coletam os drops sozinhos (o resto dos pets já existe) (P)
- ⬜ Prestígio/renascimento após o nível máximo, com bônus permanente (M)
- ✅ Conquistas e títulos (ver Jornada acima)
- ⬜ Casa do jogador (housing) com troféus de chefes (G)

## Fase 5 — Economia e monetização (sem pay-to-win)

- ⬜ Game passes cosméticos: auras, montarias especiais, rastros de arma (M)
- ⬜ Passe de temporada com trilha grátis + premium (M)
- ⬜ Revisar a economia: fontes e ralos de ouro, preços, inflação (M)
- ⬜ **Regra obrigatória:** qualquer item aleatório comprado com Robux, direta ou indiretamente, mostra todas as chances em % antes da compra (política do Roblox de *paid random items*) (P)
- ⬜ Mais inventário, com expansão comprável por ouro e Robux (P)

## Fase 6 — Lançamento

- ⬜ Publicar o jogo; ligar *Enable Studio Access to API Services* e testar o salvamento real (P)
- ⬜ Salvamento robusto: session locking (ProfileStore/ProfileService ou equivalente), retentativas, backup (M)
- ⬜ Anti-exploit: limite de taxa nos remotes, validação de distância/velocidade, checagem de teleporte (M)
- ⬜ Analytics: retenção, funil da história, onde os jogadores morrem/desistem (M)
- ⬜ Tradução para inglês (LocalizationService) (M)
- ⬜ Otimização para celular: StreamingEnabled, menos partes, UI testada em telas pequenas (G)
- ⬜ Ícone, thumbnails e trailer (M)

---

## Como atualizar este arquivo

- Ao terminar um item: troque ⬜ por ✅ (ou 🧪 se não testou no Studio) e, se útil, adicione uma linha curta do que foi feito.
- Itens novos entram na fase certa, com tamanho estimado.
- Bugs encontrados vão para a **Fase 0**.
