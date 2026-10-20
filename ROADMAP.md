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

- 🧪 Testar no Studio: forja (criar e aprimorar), encantar e desmontar, alquimia, loja (comprar/vender) (P)
- 🧪 Testar montaria (montar, desmontar ao tomar dano, velocidade, pose sentada) (P)
- 🧪 Testar Arqueiro e Assassino (projéteis, Passo Sombrio, veneno, ataque pelas costas) (P)
- 🧪 Testar o Rei Goblin: investida, pancada em área, invocação, fase de fúria, barra de chefe (P)
- 🧪 Testar a cadeia de missões inteira (h01 → h15) e os contratos diários (M)
- 🧪 Testar coleta (minérios, plantas, árvores) e o feixe de objetivo apontando para recursos (P)
- 🧪 Conferir as correções da última rodada: roleta do baú visível, tecla I, bonecos lado a lado (P)
- ⬜ Balanceamento inicial: slimes tiraram 80% da vida de um Mago nível 1 (P)
- ⬜ Animações das armas: conferir a pegada de lança, arco e cajado e as poses de golpe (P)
- ⬜ Performance: medir FPS no celular; reduzir a natureza em `Scatter` se precisar; LOD para árvores distantes (M)
- ⬜ Investigar os erros `CorePackages` (React) no Output, provavelmente causados por `SetCoreGuiEnabled` (P)
- ⬜ Mapa: desenhar as estradas e permitir zoom (P)

## Fase 1 — Polimento do que já existe

- ⬜ Arte: trocar os modelos blocados por meshes (Creator Store, IA do Studio ou artista), começando pelas armas lendárias e pelos chefes (G)
- ⬜ Animações reais (Animation Editor) para golpes, magias e inimigos, mantendo o `Animator` procedural como reserva (G)
- ⬜ Sons de verdade: golpes por tipo de arma, magias, passos, ambiente por bioma, música da vila e do chefe (M)
- ⬜ VFX melhores: rastros por raridade, impacto por elemento, aura de nível alto (M)
- ⬜ Tutorial guiado nos primeiros 5 minutos (setas, dicas contextuais) (M)
- ⬜ Ciclo de dia e noite, com inimigos mais fortes à noite (M)
- ⬜ Configurações: volume, sensibilidade, mostrar/esconder números de dano (P)
- ⬜ Ícones: trocar emojis por imagens próprias (M)

## Fase 2 — Conteúdo

- ⬜ **Dungeons instanciadas** (portais com andares, sala do chefe, baú final) para 1 a 4 jogadores (G)
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

- ⬜ Árvore de talentos por classe (passivas que mudam o estilo de jogo) (G)
- ⬜ Subclasses no Rank B (ex.: Guerreiro → Paladino/Berserker) (G)
- ⬜ Sets de equipamento com bônus por 2/4 peças; capacete, botas e acessórios (M)
- ⬜ Gemas e soquetes (M)
- ⬜ Pets que coletam drops e dão bônus (M)
- ⬜ Prestígio/renascimento após o nível máximo, com bônus permanente (M)
- ⬜ Conquistas e títulos (P)
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

## Projects (organização por iniciativas)

Sugestão de organização no GitHub Projects para execução deste roadmap:

- ⬜ **Project: Fase 0 — Estabilizar**
  - Foco: testes completos no Studio, correção de bugs críticos e balanceamento inicial.
- ⬜ **Project: Fase 1 — Polimento**
  - Foco: melhorar apresentação (arte, animação, som, VFX) e experiência dos primeiros minutos.
- ⬜ **Project: Fase 2 — Conteúdo**
  - Foco: expandir regiões, dungeons, profissões e linhas de missão.
- ⬜ **Project: Fase 3 — Social**
  - Foco: funcionalidades MMO (party, guilda, troca, mercado, PvP opcional).
- ⬜ **Project: Fase 4 — Progressão**
  - Foco: metas de longo prazo (talentos, subclasses, sets, pets, prestígio).
- ⬜ **Project: Fase 5 — Economia e monetização**
  - Foco: sustentabilidade da economia e monetização sem pay-to-win.
- ⬜ **Project: Fase 6 — Lançamento**
  - Foco: publicação, segurança, analytics e otimização final.

---

## Como atualizar este arquivo

- Ao terminar um item: troque ⬜ por ✅ (ou 🧪 se não testou no Studio) e, se útil, adicione uma linha curta do que foi feito.
- Itens novos entram na fase certa, com tamanho estimado.
- Bugs encontrados vão para a **Fase 0**.
