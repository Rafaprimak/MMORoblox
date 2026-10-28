# Instruções para IAs (e humanos) que desenvolvem este jogo

Este arquivo é a fonte da verdade sobre **como trabalhar neste projeto**. Leia inteiro antes de mudar qualquer coisa. Para saber **o que** construir, veja o [ROADMAP.md](ROADMAP.md). Para rodar o jogo, veja o [README.md](README.md).

---

## 1. Visão geral

- **Jogo:** MMORPG de Hunters no Roblox (mundo aberto, classes, combos por arma, profissões, missões, baús).
- **Linguagem:** Luau. **Ferramenta de build:** Rojo 7 (`default.project.json`).
- **Idioma:** todo texto que o jogador vê é em **português do Brasil**. Comentários também em português. Nomes de variáveis/funções em inglês.
- **Visual:** "blocado" caprichado (Parts simples gerados por código, sem animações com ID). Exceções, todas com reserva para nunca quebrar:
  - **Sons:** IDs da Creator Store em `src/shared/SoundIds.luau` (com reserva interna);
  - **Ícones:** desenhos do game-icons.net (CC BY 3.0) em folhas de atlas (`assets/icones/`, `Icons`/`IconAtlas`);
  - **Natureza:** modelos low-poly gratuitos da Creator Store (`WorldGen/ExternalModels`), salvos no projeto em `assets/modelos/Natureza.rbxm` (vira `ServerStorage.ModelosExternos`; gerado no Studio por `scripts/studio/baixar_modelos.lua`), com `LoadAssetAsync` e as versões blocadas de reserva. Tipo novo/ID novo: edite `ExternalModels.Catalog` e gere o `.rbxm` de novo.
- **Nada de emoji** em nenhum texto ou ícone do jogo (nem nos dados). Ícone = nome do game-icons.net (veja "Ícones" na seção 5).
- **O servidor manda em tudo.** O cliente só desenha, anima e envia intenções. Nunca confie em valores vindos do cliente.

## 2. Regras de ouro

1. **Rode `scripts/verificar.ps1` antes de entregar.** Ele checa sintaxe, nomes errados, chamadas entre módulos que não existem e gera o `.rbxlx`. Não entregue com falha.
2. **Teste no Roblox Studio (Play)** sempre que possível. O analisador não conhece a API do Roblox, então erros de runtime só aparecem jogando. Leia *Janela → Saída*; ignore linhas `CorePackages...` (são do Roblox).
3. **Não quebre o determinismo do mundo.** `src/shared/World.luau` é usado pelo servidor (terreno, altura dos inimigos) e pelo cliente (mapa, nomes de região). Mudar ruído, sementes ou pesos muda o mapa inteiro e pode colocar acampamentos, NPCs e pedras dentro de montanhas ou da água. Se mudar, confira as posições em `Enemies.Camps`, `NPCs.List`, `World.Locations` e `World.Waystones`.
4. **Evite `require` circular.** Use os *ganchos* (seção 5) em vez de um serviço exigir outro que já o exige.
5. **Mudou o formato do save?** Mantenha compatibilidade em `DataService.defaultData()` (o `reconcile` completa campos novos). Se for incompatível, troque `Config.DataStoreName` (ex.: `HunterRPG_v3`) e anote no ROADMAP.
6. **Nada aleatório pago com Robux sem mostrar as chances.** É regra do Roblox (*paid random items*): todas as chances em %, somando 100%, visíveis antes da compra. O Baú Celestial e o Ovo Celestial são pagos com Robux e usam as mesmas janelas de chances; qualquer produto aleatório novo precisa delas. O Passe Premium não é aleatório, mas mostra todas as recompensas antes da compra. Produto novo = entrada em `Config.Products` + entrega em `MonetizationService.grant` (nunca outro `ProcessReceipt`).
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
| `ItemModels` | Modelo 3D de cada item (visual por base em `ItemModels.Looks`): usado na mão, no chão, no ícone e na cena do baú |
| `Arena` | Arena PvP: modos (`Modes`), rodadas, multiplicadores de dano/cura, divisões com títulos e pontos Elo (`delta`) |
| `Seasons` | Temporadas de 8 semanas (`Seasons.info`) e eventos sazonais por data (`activeEvent`) |
| `Dungeons` | Masmorras: portais, 20 andares (`floorInfo`, `tier`, `startFloors`), inimigos por faixa, chefes a cada 5 andares, material, chave, loot exclusivo e loja do Mercador |
| `Guilds` | Regras das guildas: custo/nível para fundar, emblemas, XP por evento (`Points`), metas semanais (`Goals`, `goalsForWeek`), nível (`level`/`xpForLevel`) |
| `Factions`, `Lore` | Facções (degraus, reputação por evento, facção de quem dá cada missão) e páginas do diário de lore (`unlock = { evento, alvo }`) |
| `Raids` | Raide: nome, chefe, nível, fases, vida pelo tamanho do grupo, semana, posição do portal (com `World.addPad`) |
| `Townsfolk` | Moradores e animais da vila: aparência, rotas e falas; posição determinística pelo relógio do servidor |
| `Icons`, `IconAtlas` | Ícones do jogo: `Icons.get(nome)` dá a folha e o recorte; `Icons.Sheets` guarda os IDs das folhas enviadas; `IconAtlas` é gerado por `scripts/icones/montar.py` |
| `Remotes` | Cria (servidor) ou encontra (cliente) os canais de rede |

### Server

| Módulo | Papel |
|---|---|
| `init.server` | Ordem de inicialização, ganchos entre serviços, handlers de `Action` e `Request`, spawn dos jogadores |
| `WorldGen/` | `TerrainGen` (voxels), `Town`, `Landmarks`, `Scatter` (natureza + recursos), `Props` (biblioteca de peças), `Placement` (anti-sobreposição), `ExternalModels` (modelos low-poly da Creator Store para a natureza, com reserva blocada) |
| `DataService` | Carregar/salvar (DataStore) com trava de sessão (`{ format = 3, data, lock = { jobId, time } }`), `UpdateAsync`, novas tentativas e cópia de segurança; `release` na saída, `releaseAll` no fechamento |
| `AntiCheat` | Limite de pedidos por canal (`AntiCheat.allow`), argumentos válidos (`validArgs`), serviços de NPC só por perto (`ServiceActions`/`nearService`/`nearNpc`) e movimento 20x/s: velocidade/teleporte, atravessar parede, voo/pulo infinito/flutuar, giro de arremesso, personagem sem Humanoid; jogadores não colidem entre si (grupo `Jogadores`) |
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
| `DungeonBuilder` | Peças das masmorras: salas por tema e tipo (`decor.*`), paredes com porta em arco, corredores com grade (`corridor`/`openGate`), escada, tochas |
| `DungeonService` | Grupo no portal, cópia da masmorra longe do mapa (x ≈ 6000), um andar por vez com mecânica, objetivo extra, segredos e altar; chefes, baús, pontos de retorno, Mercador de Masmorras |
| `EventService` | Eventos sazonais (`Seasons.Events`): enfeites na vila (`EnfeitesEvento`), bônus no `ExtraBonus` (`xpGain`, `goldFind`, `dropFind`), meta de abates com título (`data.events`), atributo `Evento` no workspace |
| `ArenaService` | Arena PvP: fila, partidas em coliseus longe do mapa (x ≈ -12000), rodadas, pontos da temporada (`data.arena`), ranking (`Arena_T<temporada>`); preenche os ganchos `EnemyService.Proxies/ProxyDamage/ProxyDot/ProxyParried` e `AbilityService.IsAlly` |
| `VipService` | VIP (game pass `Config.VipGamePassId`; no Studio todos são VIP) e o atributo `AutoFarm` (Auto Caçar, desliga nas masmorras) |
| `MonetizationService` | Compras com Robux (`Config.Products`): o único `ProcessReceipt` do jogo; entrega uma vez por `PurchaseId` (`data.purchases`) e salva na hora |
| `FusionService` | Fusão de equipamentos: 9 da mesma raridade → 1 acima (`Config.Fusion`) |
| `TradeService` | Troca entre jogadores com Pronto/Confirmar, validação na hora de trocar e `data.tradeLog` |
| `MarketService` | Mercado global: anúncio no DataStore `Mercado_v1` (fonte da verdade), índice no MemoryStore `MercadoIndice` (busca por preço), custódia no perfil (`data.market.selling/buying`), `settle` resolve a custódia pelo estado do anúncio (vendido/cancelado/expirado). Nunca dê item/ouro do mercado fora do `settle` |
| `GuildService` | Guildas: registro no DataStore `Guildas_v1` (sempre por `UpdateAsync`), nomes únicos em `GuildasNomes_v1`, pontos dos membros (`track`, ligado ao `questHook`) em buffer gravado de minuto em minuto, metas semanais, banco, ranking (OrderedDataStore por semana), chat e avisos entre servidores (MessagingService "Guildas"), bônus de nível no `ExtraBonus`, [SIGLA] no `Humanoid.DisplayName` |
| `ChronicleService` | Reputação e lore: `track` (pelo `questHook`), `onQuestDone` (pelo `QuestService.OnComplete`, recebe a missão), recompensa de degrau na hora; `data.factions/factionTiers/lore` |
| `RaidService` | Raide: portal (estrela caída), arena no espaço (x = 12000), sala com Pronto, fases do Devorador (chuva de estrelas, servos, fúria), prêmio semanal (`data.raidWeek`), volta à arena ao morrer; atributo `Raid` no jogador |
| `PartyService` | Grupos no mundo aberto (até 5): convite/aceitar/sair/expulsar, `nearbyMembers`/`xpBonus` para dividir abates (usado no `OnKilled`), canal de chat `Grupo<id>` no TextChatService |
| `WorldEventService` | Chefe de mundo (`Config.WorldBossFirst/Interval`) e invasão noturna da vila em ondas; acampamentos criados na hora com `worldEvent`; recompensa os participantes; publica o evento nos atributos `Event*` do workspace |
| `PlaytimeService` | Presentes por tempo seguido no mesmo servidor (`Config.PlaytimeRewards`), por sessão |
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
| `Ambience` | Ambiente e música em loop por região/noite/chefe/combate, com crossfade (`Ambience.combatPing()` ao bater/apanhar) |
| `RevealScene` | Cena 3D (ViewportFrame + WorldModel) com uma cópia do personagem abrindo o baú ou vendo o ovo chocar |
| `ItemIcon` | Ícone 3D (ViewportFrame) de item, com modelo guardado por base/raridade e giro opcional |
| `DungeonWindow` | Janela do portal (grupo e andar inicial), janela do Mercador de Masmorras e painel do andar |
| `DungeonAtmosphere` | Clima das masmorras no cliente (luz, névoa, tom, poeira/brasas) enquanto o jogador tem o atributo `Dungeon` |
| `AutoHunt` | Auto Caçar no cliente (só com `AutoFarm`): anda até o inimigo mais perto, ataca no ritmo (`Controller.autoAttack`), toma poção e volta ao ponto de partida |
| `Store` | Cliente: abre a compra com Robux (`Store.buy(chave)`) e mostra o preço; produto com id 0 = no Studio entrega de graça para testar |
| `ArenaWindow` | Janela da Arena (menu, sem tecla): fila, divisão, ranking, histórico; placar no topo durante a luta |
| `FusionWindow`, `TradeWindow` | Janelas de fusão e de troca (o botão "Trocar" é um ProximityPrompt local em cada outro jogador) |
| `PlaytimeWindow` | Janela de Presentes (tecla U) com o tempo neste servidor |
| `MarketWindow` | Janela do Mercado (Comprar / Vender / Meus anúncios), aberta pelo serviço `market` do Otto |
| `GuildWindow` | Guilda (tecla L): fundar, membros e cargos, banco, metas, ranking; chat /gu; painel de convite |
| `ChroniclesWindow` | Crônicas (tecla Y): facções e diário de lore |
| `RaidWindow` | Janela da raide (chefe girando em 3D, vitrine do conjunto Estelar, sala) e painel durante a luta |
| `PartyUI` | Grupo: convite (tecla T em cima do jogador), quadros dos colegas, nome verde em cima deles, `PartyUI.members()` para o mapa, chat `/g` |
| `EventTracker` | Painel do evento do mundo no topo da tela + marcador no mundo; `EventTracker.position()` para o mapa |
| `ArtStyle` | Estilo artístico: contorno de anime (Highlight só de borda) nos ~24 modelos mais perto, vinheta e gradação de cor pela hora do dia (configuração `outlines`) |
| `DetailCulling` | Desempenho: tira do cliente o cenário de `Mundo.Natureza` longe da câmera (distância pela configuração `quality`). Não coloque nada interativo nessa pasta |
| `Juice` | Sensação de jogo: poeira nos pés e ao aterrissar, câmera que abre na corrida (+ `Fx.fovKick` dos golpes), partículas do ambiente por região |
| `TownLife` | Desenha e anima moradores, animais, pássaros, borboletas e vaga-lumes da vila (só perto dela) |
| `Controller` | Entrada do jogador (combo, esquiva, corrida, habilidades, celular) |
| `Animator` | TODAS as animações dos jogadores, procedurais (escreve `Motor6D.Transform` em `RunService.Stepped`; o `Animate` padrão do Roblox é desligado): locomoção, montaria, golpes, hit-stop |
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
- **`Request`** (RemoteFunction, interface): `sync, equip, sell, sellJunk, chooseClass, rankAbility, forge, upgrade, enchant, disassemble, alchemy, buy, sellMaterial, openChest, acceptQuest, turnInQuest, abandonQuest, trackQuest, travel, buyMount, settings, tutorial, setLoadout, learnTalent, respec, reforge, buyEgg, equipPet, releasePet, claimLogin, claimPass, setTitle, arenaJoin, arenaLeave, arenaForfeit, arenaRanking, dungeonJoin, dungeonLeaveLobby, dungeonReady, dungeonExit, dungeonBuy, dungeonBuyLoot, claimPlaytime, autoFarm, afkRejoin, devPremium, fuse, tradeInvite, tradeRespond, tradeOffer, tradeReady, tradeConfirm, tradeCancel, partyInvite, partyRespond, partyLeave, partyKick, partyLooking, partyList, marketSell, marketBuy, marketCancel, marketBrowse, marketMine, dungeonRanking, raidJoin, raidLeave, raidReady, raidExit, guildCreate, guildInvite, guildRespond, guildLeave, guildKick, guildRank, guildBank, guildClaim, guildChat, guildRanking, dev`. **Sempre retorna `{ ok = bool, msg = "texto para o jogador" }`.** No cliente use `State.request()`, que já mostra `msg` em caso de erro.
- **`DataUpdate`** (servidor→cliente): estado completo, montado em `PlayerService.sync()`. Para mandar algo novo à UI, adicione no payload. Marque mudanças com `PlayerService.markDirty(player)` (o envio é agrupado ~6x/s).
- **`Notify`** (servidor→cliente): `{ kind = ... }` com `loot, material, consumable, levelup, rankup, skillup, ability, quest, questAccepted, questReady, discover, announce, banner, message, chest, pet, passTier, achievement, reward, dungeonPortal, tradeInvite, tradeOpen, partyInvite, guildInvite, guildChat, raidPortal`. Tratado em `Popups.handle`.
- **`Fx`** (servidor→cliente): `(kind, ...)` com `hit, death, gold, xp, hurt, evaded, telegraph, explosion, projectile, projectileEnd, rain, meteor, blink, gather, drop, potion, potionCooldown, buff, selfDash, selfJump, cooldown, swing, cast, dodge, noStamina, exhausted, noMana` e, do combate dinâmico, `parry, blocked, guardBreak, perfectDodge, rhythm, stagger, block, charge`, e de suporte/perks `heal, sanctuary, taunted, chain`. O `hit` leva o `element` do golpe. Tratado na tabela `FX_HANDLERS` em `init.client`.
- **Tabelas pela rede:** só arrays puros ou dicionários com chave string. Nada de chaves misturadas.
- **Teleporte feito pelo servidor** (`character:PivotTo` num jogador): chame `AntiCheat.allowTeleport(player, segundos)` antes, senão o anti-trapaça devolve o personagem para trás. Lançou o jogador para o alto (pulo de habilidade): `AntiCheat.allowAir(player, segundos)`.
- **Pedido novo de serviço de NPC** (só funciona perto dele): adicione em `AntiCheat.ServiceActions` com o serviço de `NPCs.List`. Argumentos de `Action`/`Request` passam por `AntiCheat.validArgs` (sem Instance/CFrame; tabelas até 64 chaves e 3 níveis; textos até 200).
- **Parede que não pode ser atravessada:** peça ancorada, `CanCollide`, de pé e com mais de 6 studs de largura (peças menores o anti-trapaça ignora).
- **Save:** nunca use `SetAsync` no perfil; grave só por `DataService` (ele respeita a trava de sessão). Para gravar na hora (troca, compra), use `DataService.save(player)`, que retorna `true` se gravou. Operação que mexe em algo fora do perfil (mercado) só segue se esse save der certo.

### Atributos e tags
- **Jogador:** `Mana, MaxMana, Stamina, MaxStamina, Level, Class, WeaponType, Mounted, Pet, PetLevel, Title, TitleId, Dungeon, Raid, Vip, AutoFarm, AutoAnchor` (ponto de caça do Auto Caçar).
- **Raiz de inimigo** (pasta `workspace.Inimigos`): `Type, Elite, Level, Hp, MaxHp, Posture, MaxPosture, Staggered, Action ("tipo:contador"), Dot, Dead`.
- **Workspace:** `WorldReady, WorldStatus, WorldProgress, DayEpoch, Night` e o evento do mundo atual: `EventKind` ("boss" | "invasion"), `EventName, EventPlace, EventX, EventZ, EventEnds` (horário do servidor), `EventWave, EventWaves`. Evento sazonal: `Evento` (id ativo) e `EventoForcado` (teste no Studio).
- **Tags:** `Rainbow` (cor arco-íris), `Spin` (gira), `ResourceNode`, `Waystone`, `NPC`, `NightLight` (peça que acende à noite; use `Props.nightLight(part)`).

### Inimigos: servidor x cliente
O servidor move só uma **parte invisível** (raiz) a 10 Hz e muda atributos. O cliente (`EnemyRenderer`) constrói o modelo de `EnemyModels`, suaviza o movimento, anima pernas/braços pelo `role`, encaixa os pés no terreno e faz o efeito de morte. **Nunca crie partes visuais de inimigo no servidor.**

### Escala do mundo
- **Escala realista, três números em `World`:**
  - `World.Scale` (3) = tamanho do **mapa**. Posições do mapa em `World`, `Points`, `Dungeons`, `Enemies.Camps` e NPCs fora da vila são escritas em **coordenadas de projeto** (mapa de -512 a 512) e convertidas por `× World.Scale` no próprio módulo.
  - `World.PropScale` (1,5) = tamanho das **coisas** em relação ao personagem: construções, móveis, a vila inteira (`TownPlan`, NPCs da vila com `at`/`service`, `Townsfolk`, acampamentos com `town = true`) e espaçamentos dentro de uma estrutura. Construções usam `Props.scaleModel(model, pivot, World.PropScale)`; o raio de `Placement.reserve` de uma estrutura também.
  - `World.HeightScale` (1,8) = o relevo é esticado em volta do nível do mar. Limiares de altura (neve, pinheiro, "alto demais") comparam `World.designHeight(h)` com o valor de projeto.
  - Estrutura que precisa acompanhar o mapa (portão do norte cobrindo a passagem, anel da cratera) usa `World.Scale`.
- **Chão plano:** `World.addPad(x, z, raio, rampa)` aplaina o relevo em volta de um ponto (registrado na carga dos módulos: marcos em `World`, locais em `Points`, portais em `Dungeons`). Pad novo = registrar no módulo compartilhado, nunca só no servidor (o cliente calcula a mesma altura).
- **Natureza em camadas** (`Scatter.nature`): árvores adultas (`TREE_SCALE` 3) reservam só o tronco, árvores jovens, sub-bosque (arbustos, samambaias, troncos caídos, tocos), clareiras por ruído; o `ArtStyle` engrossa a névoa dentro da mata.
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

### Temporadas, passe e eventos
- `Seasons.index()` dá a temporada (8 semanas desde `Seasons.Epoch`). Coisas "da temporada" guardam o número e recomeçam quando ele muda: o passe (`ProgressionService` `checkSeason`, `data.progress.pass.season`) e a Arena (`ArenaService` `arenaData`, `data.arena.season`).
- Passe: trilha grátis `Progression.passReward(tier)` e Premium `Progression.passPremiumReward(tier)`; a compra (`Config.Products.pass_premium`, `kind = "pass"`) chama `ProgressionService.unlockPremium`.
- Evento novo: entrada em `Seasons.Events` (datas, `bonus`, `goal`, `title`, `reward`) + título em `Progression.Titles` + função de enfeites em `EventService` (`BUILDERS`). Bônus de drop: `bonus.dropFind` (lido no abate do `init.server`).

### Arena PvP (dano entre jogadores)
- Não existe "PvP solto": jogador só acerta jogador dentro de uma luta da arena. As consultas do `EnemyService` (`inCone`, `inRadius`, `alongSegment`, `nearest`) recebem o **atacante** como último argumento; se ele está numa luta, devolvem só os oponentes como registros `proxy = true` (com `pos`, `yaw`, `hp`, `maxHp`, `root`, `player`).
- `EnemyService.damage/applyDot/parried` desviam esses registros para o `ArenaService`, que chama `PlayerService.damagePlayer(..., { nonLethal = true })` (esquiva, aparar, bloqueio e perks de defesa valem; ninguém morre, cai com 1 de vida).
- **Consulta nova de alvo em golpe, habilidade, perk ou projétil:** passe o jogador que ataca (`EnemyService.inRadius(c, r, nil, player)`; projéteis com `owner = player`). Sem isso a habilidade não acerta na arena.
- Cura/escudo em aliados: use `alliesNear(player, ...)` (respeita `AbilityService.IsAlly`: na arena só o próprio time).
- Na arena: sem poções (`useConsumable`), curas × `PlayerService.ArenaHealMult`. Atributos `Arena` (id da luta) e `ArenaTeam`.

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
- **Peças não podem se atravessar com faces no mesmo plano** (o Roblox pisca/"treme" a textura). Em vãos de porta, cada peça ocupa a sua faixa: vão | batente | parede, com a verga apoiada nos batentes e a parede acima começando no topo da verga (ver `Props.house` e `Props.building`). Enfeites encostam na parede (face com face), não entram nela. Janela de fachada pronta: `Props.facadeWindow(model, face, largura, altura, { shutters, rng })`, com `face` na superfície externa e -Z para fora.

### Masmorras
- Tudo é dado em `src/shared/Dungeons.luau`. Masmorra nova = entrada em `DESIGN` (posição de projeto do portal, `pools` por faixa de andares, `bosses` nos andares 5/10/15/20, `material`, `key`, `loot`) + tema em `DungeonService.THEMES` (se for novo) + material/chave em `Items.Materials` + bases exclusivas em `Items.Bases` (`dungeon`, `signature`) + perk de assinatura em `Perks.List` (`exclusive`, nunca sorteado).
- O andar é montado na hora por `DungeonService` em `workspace.Masmorras` (pares e ímpares em lugares diferentes; o anterior é apagado depois do teleporte). A planta é uma grade (`CELL`): patamar → salas de combate (cada uma com `mechanic`, acampamento próprio e grade na saída) → escada, mais salas laterais (altar, baú ou mímico). As peças vêm do `DungeonBuilder`; tipo de sala novo = função em `decor` + nome em `Themes[tema].kinds` (enfeites encostados nas paredes, centro livre para a luta).
- Música dentro das masmorras: só `SoundIds.Dungeon[id]` (`music`, `combat`, `boss`, `ambience`); o `Ambience` não usa a música do mundo aberto lá dentro. O `Sky` não mexe no relógio da luz enquanto o jogador está numa masmorra. Os inimigos usam o `EnemyService` normal com um "acampamento" de sala: `floorY` (piso plano), `bounds` (paredes), `hpMult`, `damageMult`, `levelBonus`, sem `respawn` (não renascem), `dungeonId` e `floor`.
- Mecânicas (`MECHANICS`) e objetivos extras (`OBJECTIVES`) ficam no topo do `DungeonService`; o texto do painel sai de `mechanicText`/`objectiveText`. Para uma mecânica nova: monte as peças em `buildFloor`, trate no `update` e escreva o texto.
- **Modificadores da semana:** `Dungeons.Modifiers` + `Dungeons.weeklyModifiers()` (2 por semana, determinístico), aplicados no `spawnOptions` do `DungeonService` (todo inimigo de masmorra nasce por ele). Ranking de tempo: OrderedDataStore `MasmorraTempo_<id>_<semana>` (pedido `dungeonRanking`).
- `def.boss` agora é calculado em `Enemies` (`behavior == "boss"`). Chefes só de masmorra têm `dungeon = true`.
- Grupo: cada membro manda `dungeonReady`; com todos prontos, conta 3 s e começa (`launch`). Sempre do andar 1; a chave sai do líder (primeiro do grupo).

### Itens: modelos 3D, Únicos e conjuntos
- **Item novo** = = base em `Items.Bases` + visual em `ItemModels.Looks[baseId]` (sem entrada usa um visual padrão pelo tier). Construtores por tipo de arma (`weapon.*`) e por espaço (`gear.*`) no `ItemModels`; armas têm o cabo na origem e a ponta em +Y, equipamentos ficam centrados com a frente em -Z.
- **Vestido no corpo:** `ItemModels.worn(baseId, raridade, tamanhos)` devolve as peças por parte do corpo R15 (`worn.armor/helmet/boots/amulet/ring`, lendo o mesmo `Looks`); o `PlayerService` (`applyGearVisual`) solda em `Visual_<espaço>`. O elmo esconde chapéus/cabelos do avatar (atributo `TransparenciaOriginal`). Estilo novo de item precisa de visual no ícone (`gear.*`) e no corpo (`worn.*`).
- Na interface, use `ItemIcon.new(pai, baseId, raridade, { Size, Position, spin, glow })`.

### Ícones
- Todo `icon` nos dados (classes, habilidades, talentos, perks, pets, ovos, baús, materiais, conquistas, locais...) é o **nome de um ícone do game-icons.net** (ex.: `"crossed-swords"`, catálogo em `scripts/icones/catalogo.txt`).
- Na interface: `UI.icon(nome, { Size, Position, Color, Transparency, Parent })` cria o ícone (sombra + desenho tingido + losango de reserva) e `UI.setIcon(icone, nome, cor, transparência)` troca. Texto **não** leva o ícone junto: mostre o ícone ao lado (ver o menu do `HUD`, as opções do `Dialog` e a fita do `Window`, que aceita `icon`).
- Depois de usar um nome novo, rode `python scripts/icones/montar.py`. Ele acha os nomes em `icon = "..."`, `UI.icon("...")`, `UI.setIcon(x, "...")`, `Icons.get("...")`, `touchAction(..., "...")`, nos talentos `node(...)` e em comentários `-- ícones: "a", "b"` (para nomes escolhidos em tempo de execução). As folhas que mudarem precisam ser enviadas de novo ao Roblox (novo ID em `Icons.Sheets`). Telas que redesenham com o `State.Changed` precisam evitar recriar ícones à toa (ver a assinatura em `ItemGrid.render`, `forgeKey` e `renderShop`).
- **Exclusivos da raide:** bases com `raid = true` (fora do Baú Celestial e dos sorteios) e perks `exclusive = "raide"`; caem só do `devorador` (pool dele). O modelo do chefe é `EnemyModels.devorador`, com papéis de animação próprios: `orbit`/`orbitR` (anéis girando) e `tentacle` (ondulando), tratados no `EnemyRenderer`.
- **Único:** raridade `Unico` (peso 0: nunca sai de sorteio nem de baú). Base com `unique = true` e `signature` = perk com `exclusive = "unique"`; quem deixa cair: `Enemies.Defs[x].uniques` (chance `Enemies.UniqueChance`). Efeitos dos perks únicos no `PerkService` (golpes/abates) e no `PlayerService.damagePlayer` (defesa).
- **Conjunto:** `Items.Sets[id]` (peças e bônus por quantidade) + `set = id` nas bases. `PlayerService.getStats` conta as peças, soma os `stats` e liga o `perk` do bônus (perk com `exclusive = "set"`).
- Eventos de missão/conquista: `dungeonBoss`, `dungeon` (andar 20), `dungeonSecret`, `dungeonObjective`. Atributo do jogador: `Dungeon` (id da masmorra em que está). Bônus `dungeonDamage` (perks de assinatura) é aplicado em `EnemyService.damage`.

### Vida da vila
- Moradores e animais **não existem no servidor**: `Townsfolk` calcula a posição a partir de `workspace:GetServerTimeNow()`, então todos os clientes veem a mesma cena sem rede. Morador novo = entrada em `Townsfolk.Villagers` com `route` (pontos de `Townsfolk.point(ângulo, raio)` que não atravessem construções).
- **Traçado:** tudo fica em `src/shared/TownPlan.luau` (ruas, calçadas, praça, becos, `Services` das lojas/NPCs, `Houses`, `Lamps`), em coordenadas de projeto relativas à praça (x leste, z sul). `WorldGen/Town` constrói a partir dele, `NPCs` usa `TownPlan.Services` e o `World` usa `TownPlan.pavingAt` para pôr chão sem grama embaixo do calçamento (a grama animada atravessa peças finas). Ao mudar o traçado, confira lotes vizinhos e as rotas em `Townsfolk`.
- **Altura real do terreno:** o Roblox desenha a superfície de um voxel cheio mais alto que a conta. O `TerrainGen` calibra isso no começo (laje de teste + raycast) e compensa em `TerrainGen.Bias`; assim o chão visível bate com `World.height`/`World.TownHeight`. Não remova a calibração.
- **Grama animada:** o material `Grass` do terreno desenha folhinhas que atravessam peças finas (pisos, calçamento) e escondem pés e móveis. Na vila o terreno usa `LeafyGrass` (sem folhinhas) e chão de pedra/terra embaixo do calçamento. Onde houver piso fino sobre o terreno, evite `Grass` embaixo.
- **Cena de revelação:** dentro de `ViewportFrame` os `Motor6D` não movem as peças; o `RevealScene` ancora tudo e calcula a pose por cinemática direta (peça-mãe × C0 × giro × C1⁻¹).
- **Altura dos móveis:** construções são montadas em unidades de projeto e ampliadas ×1,5. Balcão ~1,8, mesa ~1,9, banco ~1,1 (antes de ampliar); assim ficam na cintura do personagem.
- `World.TownHeight` é múltiplo de 4 a partir de -24 (fundo do TerrainGen): assim o voxel fica cheio e o chão sai exatamente na altura usada pelas construções. Não use um valor quebrado (o terreno cobre pisos e NPCs).
- Enfeites da vila ficam em `Town.decorate` (bancos, feira, poço, carroça, varal, galinheiro, canteiros, bandeirinhas) com posições candidatas e `Placement`.
- Janelas que acendem à noite: `Props.nightWindow(part)` (cor de dia em `OffColor`).

### Animação e áudio
- `Animator` faz TODAS as animações dos jogadores (o script `Animate` do Roblox é desligado no personagem local e as juntas são escritas direto, não somadas). Camadas: locomoção (`locomotion`: parado, andar/correr por ciclo de passo, quadril virando para andar de lado/de costas, pulo, queda, aterrissagem, nado) ou cavaleiro (`riderPose` + galope em `animateHorse`), postura por arma (`STANCES`), golpe somado por cima (andando/montado só da cintura para cima), `flinch`, `hitstop` e tornozelos automáticos. Pose nova = quadros `{ t, juntas, curva }` em `POSES` (curva `snap` no quadro do golpe, `slowIn` em antecipação pesada; padrão `smooth`).
- O cavalo da montaria tem grupos (`PernaFL`..., `Cabeca`, `Cauda`) ligados ao `Corpo` por Motor6D criados em `TravelService.mount`; o cliente anima as juntas `Junta*`.
- Som novo: adicione em `SoundIds.Effects` (com `reserva`) e toque com `Sounds.play(nome)`. Para efeitos, prefira a biblioteca licenciada **APM** (`creatorTargetId=7462718749`: whooshes, impactos e metal de cinema) ou a da conta Roblox; os áudios públicos de usuários costumam ser recortes de outros jogos (os estilo Dragon Ball foram testados e não combinaram com o universo do jogo). Ambiente/música: `SoundIds.Ambience/Music` + `SoundIds.RegionAmbience`. Música de combate: `SoundIds.Combat[tipoDoInimigo]` (inimigo novo sem entrada usa `padrao`); músicas licenciadas da conta APMOfficial (`creatorTargetId=7462718749`). Os IDs atuais são da biblioteca oficial da conta "Roblox" (ID 1); para achar mais, a API pública `apis.roblox.com/toolbox-service/v1/marketplace/3?keyword=...&creatorTargetId=1&creatorType=1` lista áudios oficiais e `.../items/details?assetIds=...` mostra os nomes.
- **Interface:** tema azul-noite e dourado. Janelas e painéis usam `UI.ornate(frame)` (borda dupla e losangos), títulos usam `UI.TitleFont` (Merriweather) em `FontFace`, botões já vêm com degradê, borda dourada e sons de clique/hover.

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
| **Missão nova** | `Quests.List` (giver/turnIn, `requires`, objetivos). Tipos de objetivo existentes: `kill, hit, gather, deliver, talk, explore, discover, craft, enchant, upgrade, upgradeTo, level, mastery, mount, chest, dodge, ability, finisher, parry, perfectDodge, rhythm, stagger, fullCharge, poi, poiSecret, worldBoss, invasion` (e `reward.faction = { id, amount }`) |
| **Tipo de objetivo novo** | `QuestService` (`matches`/`progressOf`), disparar o `QuestHook` no lugar certo, `WorldMarkers.objectiveTarget` (para onde o feixe aponta) |
| **NPC novo** | `NPCs.List` (posição em terreno plano; `indoor` se ficar dentro de uma construção), construção em `WorldGen/Town` ou `Landmarks`, serviço em `Dialog.services` + `Services` |
| **Perk novo** | `Perks.List` (pool `weapon` ou `gear`; `stats` fixos ou gatilho em `PerkService`) |
| **Pet novo** | `Pets.List` + `odds` de um ovo (somando 100) |
| **Página de lore / facção** | `Lore.Pages` (texto, dica e `unlock` por evento de missão) / `Factions.List` + pontos em `Factions.Events` (títulos dos degraus em `Progression.Titles` como `<facção>_honrado/exaltado`) |
| **Conquista nova** | `Progression.Achievements` (evento de missão existente) + título em `Progression.Titles` |
| **Passiva/talento** | `Classes.Passives[classe]` (ramo, tier, máximo, stats por rank) |
| **Recurso de coleta** | `Resources.Nodes` + regra em `Scatter` (`NODE_RULES`) + visual em `buildNode` |
| **Objeto de cenário** | Função em `Props`, posicionamento com `Placement.canPlace` + `Placement.reserve` (obrigatório, evita sobreposição) |
| **Local de interesse** | `Points` (kind, recompensa, baú, `secret` = recompensa do segredo, `guards` = inimigos do local) + construtor em `WorldGen/PointsOfInterest` (peça principal; retorna onde fica o baú) + entorno em `WorldGen/PoiAreas` (`extras[kind]`: construções em volta e o objeto do segredo, prompt `SegredoLocal`) |
| **Local/pedra de viagem** | `World.Locations` / `World.Waystones` (+ estrada em `World.Roads` se quiser) |

## 7. Armadilhas já conhecidas (aprendidas testando)

- **Teclas reservadas do Roblox:** `I`/`O` são zoom da câmera (o inventário usa `ContextActionService:BindActionAtPriority` para ganhar prioridade), `Esc` abre o menu do Roblox, `E` é o padrão dos ProximityPrompts, `Tab` é a lista de jogadores. O Shift-lock foi desligado no `default.project.json` para o Shift virar corrida.
- **Não use emoji** (vários nem renderizam e o jogo não tem nenhum). Símbolos tipográficos simples (✦ ★ ◆ • → ✔ ✕ ▲ ▼) podem ficar no texto.
- **`AssetService:LoadAssetAsync`** (modelos da Creator Store) só funciona com o jogo publicado e "Permitir o carregamento de ativos de terceiros" ligado; por isso os modelos ficam salvos no projeto (`.rbxm`). O download direto (assetdelivery) exige login: gere o arquivo pelo Studio (`game:GetObjects` na barra de comandos).
- **NPC com `Players:CreateHumanoidModelFromDescription`:** posicione a raiz em `HipHeight + raiz.Size.Y/2` acima do chão (bounding box não é confiável).
- **Personagens só nascem com o mundo pronto** (`Players.CharacterAutoLoads = false` + `LoadCharacter`). O respawn é manual (`Humanoid.Died`).
- **DataStore não funciona no Studio sem publicar.** O aviso amarelo é esperado e o save fica desligado.
- **`Motor6D.Transform` só funciona se alterado em `RunService.Stepped`** (depois das animações padrão).
- **Juntas do personagem podem não ser `Motor6D`:** com o *Avatar Joint Upgrade* (padrão novo do Roblox) o R15 nasce com `AnimationConstraint` (anexos `Attachment0/1`, também com `Transform`). Nunca procure só `Motor6D` em personagem de jogador; veja `Animator.findJoint` e `RevealScene.jointInfo`.
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
