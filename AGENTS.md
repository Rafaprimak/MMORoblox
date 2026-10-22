# Instruções para IAs (e humanos) que desenvolvem este jogo

Este arquivo é a fonte da verdade sobre **como trabalhar neste projeto**. Leia inteiro antes de mudar qualquer coisa. Para saber **o que** construir, veja o [ROADMAP.md](ROADMAP.md). Para rodar o jogo, veja o [README.md](README.md).

---

## 1. Visão geral

- **Jogo:** MMORPG de Hunters no Roblox (mundo aberto, classes, combos por arma, profissões, missões, baús).
- **Linguagem:** Luau. **Ferramenta de build:** Rojo 7 (`default.project.json`).
- **Idioma:** todo texto que o jogador vê é em **português do Brasil**. Comentários também em português. Nomes de variáveis/funções em inglês.
- **Visual:** "blocado" caprichado (Parts simples, sem meshes, imagens ou animações com ID). Tudo é gerado por código. A única exceção são os **sons**: IDs opcionais da Creator Store em `src/shared/SoundIds.luau` (com reserva interna).
- **O servidor manda em tudo.** O cliente só desenha, anima e envia intenções. Nunca confie em valores vindos do cliente.

## 2. Regras de ouro

1. **Rode `scripts/verificar.ps1` antes de entregar.** Ele checa sintaxe, nomes errados, chamadas entre módulos que não existem e gera o `.rbxlx`. Não entregue com falha.
2. **Teste no Roblox Studio (Play)** sempre que possível. O analisador não conhece a API do Roblox, então erros de runtime só aparecem jogando. Leia *Janela → Saída*; ignore linhas `CorePackages...` (são do Roblox).
3. **Não quebre o determinismo do mundo.** `src/shared/World.luau` é usado pelo servidor (terreno, altura dos inimigos) e pelo cliente (mapa, nomes de região). Mudar ruído, sementes ou pesos muda o mapa inteiro e pode colocar acampamentos, NPCs e pedras dentro de montanhas ou da água. Se mudar, confira as posições em `Enemies.Camps`, `NPCs.List`, `World.Locations` e `World.Waystones`.
4. **Evite `require` circular.** Use os *ganchos* (seção 5) em vez de um serviço exigir outro que já o exige.
5. **Mudou o formato do save?** Mantenha compatibilidade em `DataService.defaultData()` (o `reconcile` completa campos novos). Se for incompatível, troque `Config.DataStoreName` (ex.: `HunterRPG_v3`) e anote no ROADMAP.
6. **Nada aleatório pago com Robux sem mostrar as chances.** É regra do Roblox (*paid random items*): todas as chances em %, somando 100%, visíveis antes da compra. Hoje os baús são pagos só com ouro do jogo; mantenha a janela de chances.
7. **Atualize a documentação**: README (como rodar/controles), ROADMAP (marque o que fez) e este arquivo (se criar um padrão novo).
8. **Commits pequenos e descritivos**, em português. Não faça commit do `tools/` nem do `.rbxlx` (já estão no `.gitignore`).

## 3. Rodar, verificar e testar

```powershell
# verificação completa (sintaxe + análise + chamadas entre módulos + build)
powershell -ExecutionPolicy Bypass -File scripts/verificar.ps1

# só gerar o jogo
tools/rojo.exe build default.project.json -o MMOTESTE.rbxlx

# edição ao vivo no Studio (Plugins → Rojo → Connect)
tools/rojo.exe serve default.project.json
```

Ferramentas esperadas em `tools/` (não versionadas): `rojo.exe` ([releases](https://github.com/rojo-rbx/rojo/releases)), `luau-compile.exe` e `luau-analyze.exe` ([releases](https://github.com/luau-lang/luau/releases)).

**No Studio:** botões de teste à esquerda (+XP, +Ouro, +Materiais, +Perícias) só aparecem e só funcionam no Studio (`RunService:IsStudio()`). Use-os para chegar rápido em conteúdo de nível alto.

## 4. Arquitetura

```
src/shared  → ReplicatedStorage.Shared                   dados e regras usados pelos dois lados
src/server  → ServerScriptService.Server (Script)        lógica autoritativa
src/client  → StarterPlayerScripts.Client (LocalScript)  interface, efeitos, animação, controles
```

### Shared (dados puros + funções sem efeito colateral)

| Módulo | Papel |
|---|---|
| `Config` | Números de balanceamento, ranks, curvas de XP |
| `Rarities` | Raridades, pesos de drop (`weight`) e de baú (`chestWeight`), sorteio |
| `Items` | Bases de equipamento, materiais, consumíveis, encantamentos, fórmulas (poder, venda, custo) e `describe()` (versão para a UI) |
| `WeaponStyles` | Combos e ataque pesado de cada tipo de arma |
| `Classes` | Classes e habilidades (`kind` decide o executor no servidor) |
| `Skills` | Maestrias e profissões, bônus por nível |
| `Recipes` | Forja, alquimia, loja |
| `Enemies` | Definições de inimigos e acampamentos |
| `EnemyModels` | Modelos blocados com papéis de articulação (usado pelo cliente para desenhar e pelo servidor só para medir altura) |
| `Quests` | Missões da história, secundárias e contratos diários |
| `NPCs` | NPCs, posições, aparência, serviços |
| `Resources` | Pontos de coleta |
| `Chests` | Baús |
| `World` | Relevo, biomas, estradas, locais, pedras de viagem |
| `DayNight` | Hora do dia determinística (`DayNight.now()`), usada pelo servidor e pelo cliente |
| `Perks` | Perks dos itens (estilo Destiny): catálogo, sorteio por raridade (`Perks.roll`) |
| `Pets` | Pets, ovos (chances em %) e bônus por nível |
| `Progression` | Login diário, Passe do Hunter, conquistas, marcos de nível e títulos |
| `SoundIds` | Catálogo de áudio (efeitos, ambiente, música): IDs da Creator Store + reserva |
| `TownPlan` | Traçado da vila (fonte única): ruas, calçadas, praça, becos, lotes das lojas e casas, postes. Usado pelo terreno, NPCs, construção e moradores |
| `Points` | Locais de interesse (posição achada de forma determinística em chão seco e plano), recompensa e baú |
| `Townsfolk` | Moradores e animais da vila: aparência, rotas e falas; posição determinística pelo relógio do servidor |
| `Remotes` | Cria (servidor) ou encontra (cliente) os canais de rede |

### Server

| Módulo | Papel |
|---|---|
| `init.server` | Ordem de inicialização, ganchos entre serviços, handlers de `Action` e `Request`, spawn dos jogadores |
| `WorldGen/` | `TerrainGen` (voxels), `Town`, `Landmarks`, `Scatter` (natureza + recursos), `Props` (biblioteca de peças), `Placement` (anti-sobreposição) |
| `DataService` | Carregar/salvar (DataStore) |
| `PlayerService` | Atributos, recursos (mana/estamina), dano no jogador, inventário, materiais, classe, ranks, poções, sincronização com o cliente |
| `SkillService` | XP de maestrias e profissões |
| `CombatService` | Combos, ataque pesado, esquiva, cálculo de dano (`dealDamage`) |
| `AbilityService` | Executores das habilidades por `kind` |
| `EnemyService` | Spawn, IA (10x/s), ataques com aviso, status, consultas espaciais |
| `ProjectileService` | Projéteis simulados no servidor |
| `LootService` | Drops de equipamento com feixe de luz, rolagem de materiais |
| `ResourceService` | Coleta (minerar, colher, cortar) |
| `CraftingService` | Forja, aprimorar, encantar, desmontar, alquimia, loja |
| `ShopService` | Baús |
| `QuestService` | Aceitar, progresso, entrega, diárias, exploração |
| `TravelService` | Pedras de viagem, montaria, portão do norte |
| `NPCService` | Cria NPCs e prompts de conversa |
| `DayNightService` | Ciclo de dia e noite: `workspace.Night`, luz do ambiente, avisos, `skip()` para teste |
| `PerkService` | Gatilhos dos perks no combate (`modify`, `afterHit`, `onKill`, `onParry`, `onPerfectDodge`, `onFullCharge`) |
| `PetService` | Ovos, equipar/soltar pets, XP do pet, bônus (`ExtraBonus`), drops raros |
| `ExploreService` | Descoberta dos locais de interesse e baús escondidos (prompt `BauLocal`) |
| `ProgressionService` | Conta tudo pelos ganchos de missão: conquistas, passe, login diário, títulos, marcos de nível |
| `WeaponModels` | Arma presa na mão (com rastro) |

### Client

| Módulo | Papel |
|---|---|
| `init.client` | Liga tudo, despacha eventos `Fx`/`Notify`, atalhos de teclado |
| `State` | Último estado vindo do servidor + `State.request()` / `State.action()` |
| `UI`, `Window`, `ItemGrid` | Helpers de interface, janela genérica com abas, grade de itens |
| `HUD`, `Popups`, `Fx`, `Sounds` | Barras, notificações, efeitos visuais, sons (`Sounds.List`: cole IDs da Creator Store em `id`) |
| `Prefs`, `SettingsWindow` | Configurações do jogador (valores sem dependências + janela, tecla P) |
| `Sky`, `Auras` | Sol suave e postes que acendem à noite; aura de rank nos jogadores |
| `Tutorial` | Dicas guiadas dos primeiros minutos (avançam com `Tutorial.event(nome)`) |
| `LockOn` | Travar a mira no inimigo (câmera, rosto do personagem, mira de golpes e habilidades) |
| `PetRenderer`, `PetsWindow` | Desenha/anima os pets de todos; janela de pets e ovos (tecla G) |
| `JourneyWindow` | Jornada (tecla K): diário, passe, conquistas, títulos |
| `Ambience` | Ambiente e música em loop por região/noite/chefe, com crossfade |
| `RevealScene` | Cena 3D (ViewportFrame + WorldModel) com uma cópia do personagem abrindo o baú ou vendo o ovo chocar |
| `TownLife` | Desenha e anima moradores, animais, pássaros, borboletas e vaga-lumes da vila (só perto dela) |
| `Controller` | Entrada do jogador (combo, esquiva, corrida, habilidades, celular) |
| `Animator` | Animações procedurais (gira `Motor6D.Transform` em `RunService.Stepped`) |
| `EnemyRenderer` | Desenha/anima inimigos a partir das raízes do servidor |
| `WorldMarkers` | ❗/❓ nos NPCs e o feixe do objetivo |
| `Inventory`, `Character`, `QuestLog`, `Dialog`, `Services`, `Chest`, `MapWindow`, `ClassSelect`, `Loading` | Janelas |

## 5. Contratos e padrões

### Ganchos (evitam `require` circular)
Definidos como funções vazias no módulo e preenchidos em `init.server.luau`:
`PlayerService.QuestHook / QuestSummary / OnDamaged`, `CombatService.QuestHook / BeforeAction`, `AbilityService.QuestHook`, `CraftingService.QuestHook`, `ShopService.QuestHook`, `TravelService.QuestHook`, `NPCService.QuestHook`, `SkillService.OnChanged`, `EnemyService.OnKilled / OnHit / FireProjectile / OnStagger`, `PlayerService.OnParry / OnPerfectDodge / OnThorns / ExtraBonus / ExtraSync`, `QuestService.OnComplete`, `PetService.QuestHook`.

Todo evento de missão (`questHook` no init) vai também para `ProgressionService.track`: para uma conquista nova, basta usar um tipo de evento que já é disparado.

Ordem de dependência (quem pode exigir quem): `DataService → SkillService → PlayerService → EnemyService → ProjectileService → CombatService → AbilityService`; `ShopService → QuestService`. Para eventos de missão, chame o gancho `QuestHook(player, tipo, alvo, quantidade)`.

### Rede (`src/shared/Remotes.luau`)
- **`Action`** (RemoteEvent, cliente→servidor, rápido): `attack(index, aim)`, `heavyStart`, `heavy(aim)` (solta o pesado carregado), `block(bool)`, `dodge`, `sprint(bool)`, `ability(slot, aim, point)`, `potion(id)`, `mount`, `talk(npcId)`.
- **`Request`** (RemoteFunction, interface): `sync, equip, sell, sellJunk, chooseClass, rankAbility, forge, upgrade, enchant, disassemble, alchemy, buy, sellMaterial, openChest, acceptQuest, turnInQuest, abandonQuest, trackQuest, travel, buyMount, settings, tutorial, setLoadout, learnTalent, respec, reforge, buyEgg, equipPet, releasePet, claimLogin, claimPass, setTitle, dev`. **Sempre retorna `{ ok = bool, msg = "texto para o jogador" }`.** No cliente use `State.request()`, que já mostra `msg` em caso de erro.
- **`DataUpdate`** (servidor→cliente): estado completo, montado em `PlayerService.sync()`. Para mandar algo novo à UI, adicione no payload. Marque mudanças com `PlayerService.markDirty(player)` (o envio é agrupado ~6x/s).
- **`Notify`** (servidor→cliente): `{ kind = ... }` com `loot, material, consumable, levelup, rankup, skillup, ability, quest, questAccepted, questReady, discover, announce, banner, message, chest, pet, passTier, achievement, reward`. Tratado em `Popups.handle`.
- **`Fx`** (servidor→cliente): `(kind, ...)` com `hit, death, gold, xp, hurt, evaded, telegraph, explosion, projectile, projectileEnd, rain, meteor, blink, gather, drop, potion, potionCooldown, buff, selfDash, selfJump, cooldown, swing, cast, dodge, noStamina, exhausted, noMana` e, do combate dinâmico, `parry, blocked, guardBreak, perfectDodge, rhythm, stagger, block, charge`, e de suporte/perks `heal, sanctuary, taunted, chain`. O `hit` leva o `element` do golpe. Tratado na tabela `FX_HANDLERS` em `init.client`.
- **Tabelas pela rede:** só arrays puros ou dicionários com chave string. Nada de chaves misturadas.

### Atributos e tags
- **Jogador:** `Mana, MaxMana, Stamina, MaxStamina, Level, Class, WeaponType, Mounted, Pet, PetLevel, Title, TitleId`.
- **Raiz de inimigo** (pasta `workspace.Inimigos`): `Type, Elite, Level, Hp, MaxHp, Posture, MaxPosture, Staggered, Action ("tipo:contador"), Dot, Dead`.
- **Workspace:** `WorldReady, WorldStatus, WorldProgress, DayEpoch, Night`.
- **Tags:** `Rainbow` (cor arco-íris), `Spin` (gira), `ResourceNode`, `Waystone`, `NPC`, `NightLight` (peça que acende à noite; use `Props.nightLight(part)`).

### Inimigos: servidor x cliente
O servidor move só uma **parte invisível** (raiz) a 10 Hz e muda atributos. O cliente (`EnemyRenderer`) constrói o modelo de `EnemyModels`, suaviza o movimento, anima pernas/braços pelo `role`, encaixa os pés no terreno e faz o efeito de morte. **Nunca crie partes visuais de inimigo no servidor.**

### Escala do mundo
- `World.Scale` (1.5) multiplica tudo do mapa. As posições em `World`, `NPCs.List` e `Enemies.Camps` são escritas em **coordenadas de projeto** e convertidas por `× World.Scale` no próprio módulo. Escreva posições novas nesse mesmo espaço.
- Construções e objetos são montados no tamanho base e depois escalados com `Props.scaleModel(model, pivot, fator)` (em volta de um ponto no chão). O raio de `Placement.reserve` também vai `× World.Scale`.
- Distâncias do servidor (perto do NPC, descoberta de pedra, barreira) já consideram a escala; em checagens novas, use studs reais.
- NPCs são apoiados no chão por raycast (`NPCService.groundHeight`), não pela altura calculada do terreno.

### Combate dinâmico
- Os golpes **não avançam** o personagem (sem `lunge`); só os pesados de lança e katana têm `dash`.
- O servidor valida o ritmo do combo (`CombatService`): clicar na janela `Config.RhythmWindow` depois do fim de cada golpe dá bônus; o cliente quebra o combo se o clique vier antes de `Config.FumbleFraction` do golpe.
- `PlayerService.damagePlayer(player, dano, origem, { unblockable, source })` decide esquiva perfeita, aparar, bloqueio ou dano e retorna `"hit" | "blocked" | "parried" | "evaded"`. Ataques imbloqueáveis (investida, pancada em área) passam `unblockable = true` e aparecem com ‼ vermelho no cliente; os bloqueáveis com ❗ amarelo.
- **Postura:** cada golpe soma `posture` (multiplicador da arma em `WeaponStyles`). Cheia, o inimigo fica `Staggered` por `Config.StaggerTime` e toma bônus de dano. Inimigos podem definir `posture` em `Enemies.Defs` (padrão `8·√hp`).
- Depois de atacar, o inimigo fica em `recover`; acertar nessa hora é contra-ataque (`Config.CounterBonus`).
- Teclas: clique = combo, **R** segurado = pesado carregado, **F** segurado = bloquear/aparar, **Q** = esquiva. O botão direito do mouse é da câmera; não use.

### Dia, noite e configurações
- A hora vem de `DayNight.now()` (relógio do servidor + `workspace.DayEpoch`). O cliente move o sol localmente todo frame; o servidor só muda o ambiente da luz e o atributo `Night`. Não escreva em `Lighting.ClockTime` no servidor.
- Regras da noite ficam em `Config.Night*` (dano e Elites dos inimigos, XP/ouro/drops). Para algo novo "só à noite", leia `workspace:GetAttribute("Night")`.
- Configurações novas: adicione em `Config.DefaultSettings` (o `reconcile` completa saves antigos), na janela `SettingsWindow` e leia com `Prefs.get(chave)`. O servidor valida em `PlayerService.saveSettings`.
- `Fx.hit` recebe o `element` do golpe (estilo da habilidade ou `fire`/`blood` pelo encantamento) para as faíscas do impacto.

### Classes, talentos e ameaça
- Cada classe tem `role` (tank, support, dps, control), `threat` e `abilities` (4 básicas, grátis) + `extra` (4 avançadas, `advanced = true`, custam 1 ponto). O loadout das teclas 1-4 fica em `data.loadout` (`PlayerService.getLoadout`).
- Passivas em `Classes.Passives[classe]` (3 ramos, tiers liberados por `Classes.TierPoints`). Os bônus viram `stats.bonus` em `PlayerService.getStats` (junto com acessórios, perks de stats e pet). Chaves de bônus novas precisam ser lidas em algum lugar (ver o comentário em `Classes`).
- Ameaça: `EnemyService` soma `dano × PlayerService.threatMultiplier` e persegue o maior (`topThreat`); `EnemyService.taunt` força o alvo; curas usam `addThreatNear`.

### Itens, perks e pets
- Espaços em `Items.SlotOrder`; `Items.Slots[slot].kind` diz se a peça dá vida (`health`) ou ataque (`attack`). Acessórios têm `stats` (escalados por `Items.getStats`).
- Perk novo: adicione em `Perks.List` (com `stats` fixos ou com gatilho em `PerkService`). Perks com gatilho de dano recebido ficam em `PlayerService.damagePlayer`.
- Pet novo: `Pets.List` (+ um `shape` existente em `PetRenderer`) e coloque nas `odds` de algum ovo (sempre somando 100).
- Danos extras de perks vão direto em `EnemyService.damage` com `info.perk = true` (não disparam perks de novo).

### Construções com interior
- `Props.building` monta casa com porta aberta, piso, janelas, luzes internas e telhado (porta em z = 0, salão para +Z). NPCs com `indoor` em `NPCs.List` ficam lá dentro; a porta fica em `doorX/doorZ`.
- A câmera usa **Invisicam** (`DevCameraOcclusionMode`): paredes ficam transparentes em vez de puxar a câmera.
- NPCs `indoor` procuram o chão abaixo do telhado (`NPCService.groundHeight(x, z, startY)`).

### Vida da vila
- Moradores e animais **não existem no servidor**: `Townsfolk` calcula a posição a partir de `workspace:GetServerTimeNow()`, então todos os clientes veem a mesma cena sem rede. Morador novo = entrada em `Townsfolk.Villagers` com `route` (pontos de `Townsfolk.point(ângulo, raio)` que não atravessem construções).
- **Traçado:** tudo fica em `src/shared/TownPlan.luau` (ruas, calçadas, praça, becos, `Services` das lojas/NPCs, `Houses`, `Lamps`), em coordenadas de projeto relativas à praça (x leste, z sul). `WorldGen/Town` constrói a partir dele, `NPCs` usa `TownPlan.Services` e o `World` usa `TownPlan.pavingAt` para pôr chão sem grama embaixo do calçamento (a grama animada atravessa peças finas). Ao mudar o traçado, confira lotes vizinhos e as rotas em `Townsfolk`.
- **Altura dos móveis:** construções são montadas em unidades de projeto e ampliadas ×1,5. Balcão ~1,8, mesa ~1,9, banco ~1,1 (antes de ampliar); assim ficam na cintura do personagem.
- `World.TownHeight` é múltiplo de 4 a partir de -24 (fundo do TerrainGen): assim o voxel fica cheio e o chão sai exatamente na altura usada pelas construções. Não use um valor quebrado (o terreno cobre pisos e NPCs).
- Enfeites da vila ficam em `Town.decorate` (bancos, feira, poço, carroça, varal, galinheiro, canteiros, bandeirinhas) com posições candidatas e `Placement`.
- Janelas que acendem à noite: `Props.nightWindow(part)` (cor de dia em `OffColor`).

### Animação e áudio
- `Animator` faz crossfade entre poses (`play`, `hold`, `stop`), tem camadas de postura por arma (`STANCES`), respiração, inclinação e `flinch`. Pose nova = quadros `{ t, juntas }` em `POSES`.
- O cavalo da montaria tem grupos (`PernaFL`..., `Cabeca`, `Cauda`) ligados ao `Corpo` por Motor6D criados em `TravelService.mount`; o cliente anima as juntas `Junta*`.
- Som novo: adicione em `SoundIds.Effects` (com `reserva`) e toque com `Sounds.play(nome)`. Ambiente/música: `SoundIds.Ambience/Music` + `SoundIds.RegionAmbience`.

### Interface
- Janelas novas: `Window.create(screen, { title, width, height, tabs, accent })` + `win.onOpen`/`win.onTab`; re-renderize em `State.Changed` só se `win:isOpen()`.
- Toda `ScreenGui` criada por script deve ter `ZIndexBehavior = Enum.ZIndexBehavior.Sibling` (o padrão `Global` faz elementos sumirem atrás do fundo).
- Use `UI.label`, `UI.button`, `UI.bar` e as cores de `UI.Colors`.

## 6. Receitas (como adicionar coisas)

| Quero adicionar | Onde mexer |
|---|---|
| **Arma/armadura nova** | `Items.Bases` (+ `Items.ChestPool`, `Enemies.Defs[x].pool`, `Recipes.Forge` se fizer sentido) |
| **Tipo de arma novo** | `Items.WeaponTypes`, `WeaponStyles.<tipo>`, `Skills.List` (maestria com `weaponType`), `WeaponModels` (modelo e estilo de pegada), poses em `Animator` se precisar, `Classes.List[x].weapons` |
| **Inimigo novo** | `Enemies.Defs` (comportamento: `melee`, `ranged`, `charger`, `slammer`, `boss`, `dummy`), um builder em `EnemyModels` (use `role` e `joint` para animar), um acampamento em `Enemies.Camps` em terreno seco e acessível |
| **Habilidade nova** | `Classes.Abilities` (escolha ou crie um `kind`), executor em `AbilityService.executors`, pose em `Animator` |
| **Missão nova** | `Quests.List` (giver/turnIn, `requires`, objetivos). Tipos de objetivo existentes: `kill, hit, gather, deliver, talk, explore, discover, craft, enchant, upgrade, upgradeTo, level, mastery, mount, chest, dodge, ability, finisher, parry, perfectDodge, rhythm, stagger, fullCharge` |
| **Tipo de objetivo novo** | `QuestService` (`matches`/`progressOf`), disparar o `QuestHook` no lugar certo, `WorldMarkers.objectiveTarget` (para onde o feixe aponta) |
| **NPC novo** | `NPCs.List` (posição em terreno plano; `indoor` se ficar dentro de uma construção), construção em `WorldGen/Town` ou `Landmarks`, serviço em `Dialog.services` + `Services` |
| **Perk novo** | `Perks.List` (pool `weapon` ou `gear`; `stats` fixos ou gatilho em `PerkService`) |
| **Pet novo** | `Pets.List` + `odds` de um ovo (somando 100) |
| **Conquista nova** | `Progression.Achievements` (evento de missão existente) + título em `Progression.Titles` |
| **Passiva/talento** | `Classes.Passives[classe]` (ramo, tier, máximo, stats por rank) |
| **Recurso de coleta** | `Resources.Nodes` + regra em `Scatter` (`NODE_RULES`) + visual em `buildNode` |
| **Objeto de cenário** | Função em `Props`, posicionamento com `Placement.canPlace` + `Placement.reserve` (obrigatório, evita sobreposição) |
| **Local de interesse** | `Points` (kind, recompensa, baú) + construtor em `WorldGen/PointsOfInterest` (retorna onde fica o baú) |
| **Local/pedra de viagem** | `World.Locations` / `World.Waystones` (+ estrada em `World.Roads` se quiser) |

## 7. Armadilhas já conhecidas (aprendidas testando)

- **Teclas reservadas do Roblox:** `I`/`O` são zoom da câmera (o inventário usa `ContextActionService:BindActionAtPriority` para ganhar prioridade), `Esc` abre o menu do Roblox, `E` é o padrão dos ProximityPrompts, `Tab` é a lista de jogadores. O Shift-lock foi desligado no `default.project.json` para o Shift virar corrida.
- **Emojis novos não renderizam** (ex.: 🪄, 🪵 viram quadrados). Prefira emojis antigos e confira no Play.
- **NPC com `Players:CreateHumanoidModelFromDescription`:** posicione a raiz em `HipHeight + raiz.Size.Y/2` acima do chão (bounding box não é confiável).
- **Personagens só nascem com o mundo pronto** (`Players.CharacterAutoLoads = false` + `LoadCharacter`). O respawn é manual (`Humanoid.Died`).
- **DataStore não funciona no Studio sem publicar.** O aviso amarelo é esperado e o save fica desligado.
- **`Motor6D.Transform` só funciona se alterado em `RunService.Stepped`** (depois das animações padrão).
- **WriteVoxels:** região alinhada à grade de 4 studs e arrays `[x][y][z]` com o tamanho exato da região.
- **PowerShell 5.1:** scripts `.ps1` com acentos precisam ser salvos em UTF-8 **com BOM**.
- **`.bat` precisam de CRLF** (garantido pelo `.gitattributes`).

## 8. Checklist antes de entregar

- [ ] `scripts/verificar.ps1` passou
- [ ] Testei no Studio o que mudei e não há erros dos nossos scripts no Output
- [ ] Textos para o jogador em português, sem emojis que não renderizam
- [ ] Nada confia no cliente (custos, distância do NPC, cooldowns validados no servidor)
- [ ] Objetos novos no mundo usam `Placement` e não ficam na água/montanha
- [ ] README/ROADMAP/AGENTS atualizados
- [ ] Commit com mensagem clara
