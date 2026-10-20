# Instruções para IAs (e humanos) que desenvolvem este jogo

Este arquivo é a fonte da verdade sobre **como trabalhar neste projeto**. Leia inteiro antes de mudar qualquer coisa. Para saber **o que** construir, veja o [ROADMAP.md](ROADMAP.md). Para rodar o jogo, veja o [README.md](README.md).

---

## 1. Visão geral

- **Jogo:** MMORPG de Hunters no Roblox (mundo aberto, classes, combos por arma, profissões, missões, baús).
- **Linguagem:** Luau. **Ferramenta de build:** Rojo 7 (`default.project.json`).
- **Idioma:** todo texto que o jogador vê é em **português do Brasil**. Comentários também em português. Nomes de variáveis/funções em inglês.
- **Visual:** protótipo "blocado" (Parts simples). Não há assets externos (meshes, imagens, animações, sons com ID). Tudo é gerado por código.
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
| `WeaponModels` | Arma presa na mão (com rastro) |

### Client

| Módulo | Papel |
|---|---|
| `init.client` | Liga tudo, despacha eventos `Fx`/`Notify`, atalhos de teclado |
| `State` | Último estado vindo do servidor + `State.request()` / `State.action()` |
| `UI`, `Window`, `ItemGrid` | Helpers de interface, janela genérica com abas, grade de itens |
| `HUD`, `Popups`, `Fx`, `Sounds` | Barras, notificações, efeitos visuais, sons |
| `Controller` | Entrada do jogador (combo, esquiva, corrida, habilidades, celular) |
| `Animator` | Animações procedurais (gira `Motor6D.Transform` em `RunService.Stepped`) |
| `EnemyRenderer` | Desenha/anima inimigos a partir das raízes do servidor |
| `WorldMarkers` | ❗/❓ nos NPCs e o feixe do objetivo |
| `Inventory`, `Character`, `QuestLog`, `Dialog`, `Services`, `Chest`, `MapWindow`, `ClassSelect`, `Loading` | Janelas |

## 5. Contratos e padrões

### Ganchos (evitam `require` circular)
Definidos como funções vazias no módulo e preenchidos em `init.server.luau`:
`PlayerService.QuestHook / QuestSummary / OnDamaged`, `CombatService.QuestHook / BeforeAction`, `AbilityService.QuestHook`, `CraftingService.QuestHook`, `ShopService.QuestHook`, `TravelService.QuestHook`, `NPCService.QuestHook`, `SkillService.OnChanged`, `EnemyService.OnKilled / OnHit / FireProjectile`.

Ordem de dependência (quem pode exigir quem): `DataService → SkillService → PlayerService → EnemyService → ProjectileService → CombatService → AbilityService`; `ShopService → QuestService`. Para eventos de missão, chame o gancho `QuestHook(player, tipo, alvo, quantidade)`.

### Rede (`src/shared/Remotes.luau`)
- **`Action`** (RemoteEvent, cliente→servidor, rápido): `attack(index, aim)`, `heavy(aim)`, `dodge`, `sprint(bool)`, `ability(slot, aim, point)`, `potion(id)`, `mount`, `talk(npcId)`.
- **`Request`** (RemoteFunction, interface): `sync, equip, sell, sellJunk, chooseClass, rankAbility, forge, upgrade, enchant, disassemble, alchemy, buy, sellMaterial, openChest, acceptQuest, turnInQuest, abandonQuest, trackQuest, travel, buyMount, dev`. **Sempre retorna `{ ok = bool, msg = "texto para o jogador" }`.** No cliente use `State.request()`, que já mostra `msg` em caso de erro.
- **`DataUpdate`** (servidor→cliente): estado completo, montado em `PlayerService.sync()`. Para mandar algo novo à UI, adicione no payload. Marque mudanças com `PlayerService.markDirty(player)` (o envio é agrupado ~6x/s).
- **`Notify`** (servidor→cliente): `{ kind = ... }` com `loot, material, consumable, levelup, rankup, skillup, ability, quest, questAccepted, questReady, discover, announce, banner, message, chest`. Tratado em `Popups.handle`.
- **`Fx`** (servidor→cliente): `(kind, ...)` com `hit, death, gold, xp, hurt, evaded, telegraph, explosion, projectile, projectileEnd, rain, meteor, blink, gather, drop, potion, potionCooldown, buff, selfDash, selfJump, cooldown, swing, cast, dodge, noStamina, exhausted, noMana`. Tratado na tabela `FX_HANDLERS` em `init.client`.
- **Tabelas pela rede:** só arrays puros ou dicionários com chave string. Nada de chaves misturadas.

### Atributos e tags
- **Jogador:** `Mana, MaxMana, Stamina, MaxStamina, Level, Class, WeaponType, Mounted`.
- **Raiz de inimigo** (pasta `workspace.Inimigos`): `Type, Elite, Level, Hp, MaxHp, Action ("tipo:contador"), Dot, Dead`.
- **Workspace:** `WorldReady, WorldStatus, WorldProgress`.
- **Tags:** `Rainbow` (cor arco-íris), `Spin` (gira), `ResourceNode`, `Waystone`, `NPC`.

### Inimigos: servidor x cliente
O servidor move só uma **parte invisível** (raiz) a 10 Hz e muda atributos. O cliente (`EnemyRenderer`) constrói o modelo de `EnemyModels`, suaviza o movimento, anima pernas/braços pelo `role`, encaixa os pés no terreno e faz o efeito de morte. **Nunca crie partes visuais de inimigo no servidor.**

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
| **Missão nova** | `Quests.List` (giver/turnIn, `requires`, objetivos). Tipos de objetivo existentes: `kill, hit, gather, deliver, talk, explore, discover, craft, enchant, upgrade, upgradeTo, level, mastery, mount, chest, dodge, ability, finisher` |
| **Tipo de objetivo novo** | `QuestService` (`matches`/`progressOf`), disparar o `QuestHook` no lugar certo, `WorldMarkers.objectiveTarget` (para onde o feixe aponta) |
| **NPC novo** | `NPCs.List` (posição em terreno plano), construção em `WorldGen/Town` ou `Landmarks`, serviço em `Dialog.services` + `Services` |
| **Recurso de coleta** | `Resources.Nodes` + regra em `Scatter` (`NODE_RULES`) + visual em `buildNode` |
| **Objeto de cenário** | Função em `Props`, posicionamento com `Placement.canPlace` + `Placement.reserve` (obrigatório, evita sobreposição) |
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
