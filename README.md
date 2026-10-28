# Hunter RPG — MMORPG no Roblox (protótipo)

MMORPG de Hunters em mundo aberto: terreno com biomas, 4 classes com 16 habilidades, estilo de luta diferente para cada tipo de arma, estamina, profissões, NPCs de ofício, missões com história e baús com roleta.

> **Estado:** protótipo jogável com visual "blocado" (feito de peças simples), para testar a jogabilidade antes da arte final. O progresso **não é salvo** enquanto o jogo não for publicado no Roblox.

---

## 🚀 Como rodar (passo a passo)

O código fica em arquivos `.luau` na pasta `src/`. A ferramenta **[Rojo](https://rojo.space)** junta esses arquivos num arquivo de jogo (`.rbxlx`) que o Roblox Studio abre.

### 1. Instale o que precisa

| O quê | Onde conseguir |
|---|---|
| **Roblox Studio** (grátis) | https://create.roblox.com → *Start Creating* (precisa de conta Roblox) |
| **Rojo 7** | https://github.com/rojo-rbx/rojo/releases → baixe o `.zip` do seu sistema |

Abra o Roblox Studio pelo menos uma vez e faça login antes de continuar.

### 2. Baixe o projeto

- **Com Git:**
  ```bash
  git clone https://github.com/Rafaprimak/MMORoblox.git
  ```
- **Sem Git:** na página do repositório, clique em **Code → Download ZIP** e extraia.

### 3. Coloque o Rojo no projeto

Extraia o `.zip` do Rojo e coloque o executável dentro de uma pasta `tools` na raiz do projeto:

```
MMORoblox/
├── tools/
│   └── rojo.exe        ← (no Mac/Linux: rojo)
├── src/
├── default.project.json
└── 1-gerar-jogo.bat
```

Se você já tem o Rojo instalado no sistema (comando `rojo` funcionando no terminal), pode pular esta etapa.

### 4. Gere o arquivo do jogo

**Windows:** dê dois cliques em **`1-gerar-jogo.bat`**.

**Mac / Linux** (ou Windows pelo terminal), na pasta do projeto:
```bash
./tools/rojo build default.project.json -o MMOTESTE.rbxlx
```
> No Mac, se o sistema bloquear o Rojo: `chmod +x tools/rojo` e depois permita em *Ajustes do Sistema → Privacidade e Segurança*.

Isso cria o arquivo **`MMOTESTE.rbxlx`**.

### 5. Abra e jogue

1. Abra o **`MMOTESTE.rbxlx`** no Roblox Studio (dois cliques no arquivo, ou *Arquivo → Abrir do arquivo*).
2. Aperte **Play (F5)**.
3. Espere a tela de carregamento: o servidor gera o mundo inteiro na hora (10 a 30 segundos).
4. Escolha sua classe.
5. Procure a **Capitã Lyra** (❗ na cabeça) perto da praça. A coluna de luz amarela no mundo sempre aponta o próximo objetivo.

> No modo de edição o mundo aparece vazio: ele só é criado quando o jogo roda. Isso é normal.

---

## 🎮 Controles

| Ação | PC | Celular |
|---|---|---|
| Atacar / emendar combo | Clique **no ritmo** (barra embaixo do retículo: clicar cedo demais quebra o combo) | Botão ⚔ |
| Travar a mira no inimigo | **T** ou botão do meio do mouse (mexa o mouse rápido para o lado para trocar de alvo) | Botão 🎯 |
| Ataque pesado carregado | Segure e solte **R** (maestria 5 da arma) | Segure 💥 |
| Bloquear / aparar | Segure **F** (soltar e apertar logo antes do golpe = aparar) | Segure 🛡 |
| Esquivar (rolamento) | **Q** (no último instante = esquiva perfeita) | Botão ↩ |
| Correr | **Shift** (gasta estamina) | Botão 🏃 |
| Habilidades da classe | **1, 2, 3, 4** | Botões 1–4 |
| Poções | **Z** vida, **X** mana, **V** vigor | Toque na barra |
| Montar / desmontar | **H** | Botão 🐴 |
| Inventário / Personagem / Missões / Mapa / Baús | **I / C / J / M / B** | Botões à esquerda (no mapa: roda do mouse = zoom, arrastar = mover) |
| Jornada (recompensa diária, passe, conquistas, títulos) | **K** | Botão ⭐ |
| Pets | **G** | Botão 🐾 |
| Configurações (volume, música, sensibilidade, qualidade gráfica, números de dano...) | **P** | Botão ⚙ |
| Presentes por tempo no servidor | **U** | Botão 🎁 Presentes |
| Auto Caçar (só VIP; pode ficar 100% AFK; mover o personagem desliga) | **N** | Botão ⚔ Auto Caçar |
| Trocar com outro jogador (nível 5+) | **E** perto dele | Botão "Trocar" em cima do jogador |
| Convidar para o grupo | **T** perto dele | Botão "Convidar para o grupo" em cima do jogador |
| Falar com o grupo | digite **/g mensagem** no chat (ou /grupo) | o mesmo |
| Guilda | **L** (fundar com a Helena, no Salão das Guildas) | botão "Guilda" |
| Falar com a guilda | digite **/gu mensagem** no chat (ou /guilda) | o mesmo |
| Fusão (9 itens da mesma raridade → 1 maior) | — | Inventário → ⚗ Fundir, ou o Bruno |
| Falar, coletar, viajar | **E** perto do NPC, rocha, planta ou pedra | Toque no aviso |

O botão direito do mouse fica livre para girar a câmera.

### Combate

- **Ritmo:** cada golpe do combo tem uma janela verde. Clicar nela dá bônus de dano; clicar antes (zona vermelha) quebra o combo.
- **Inimigos avisam:** ❗ amarelo = golpe que pode ser **bloqueado ou aparado** (F). ‼ vermelho = investida ou pancada **imbloqueável**: esquive (Q).
- **Aparar** (F logo antes do golpe) atordoa a postura do inimigo e libera um contra-ataque crítico.
- **Postura:** a barra amarela embaixo da vida do inimigo enche com golpes pesados e aparadas. Cheia, o inimigo fica atordoado e toma +50% de dano.
- **Contra-ataque:** acertar o inimigo logo depois de ele atacar dá +30% de dano.

### Modo teste (só no Studio)

À esquerda da tela aparecem os botões **+5.000 XP**, **+5.000 Ouro**, **+Materiais**, **+Perícias** e **Pular dia/noite**, para testar sem precisar farmar nem esperar a noite. Eles não funcionam num jogo publicado.

---

## 🗺️ O que tem no jogo

- **Mundo:** Vila Aurora (sul), Campos Verdejantes, Bosque Sombrio (leste), Planalto das Ruínas (oeste), lago com santuário, praia com farol e píer, montanhas nevadas, Passagem do Norte com o Portão Selado (Nível 10) e o Covil do Rei Goblin.
- **Classes e papéis (como num MMORPG):** Guerreiro (**tanque**: muita vida, ameaça em dobro e Provocar), Clérigo (**suporte**: curas, escudos e bênçãos para os aliados por perto), Mago (**controle**: área e congelamento), Arqueiro e Assassino (**dano**). Os inimigos atacam quem gera mais ameaça.
- **Árvore de talentos (tecla C):** 8 habilidades por classe (4 básicas + 4 avançadas que custam 1 ponto); você escolhe quais 4 vão nas teclas 1-4. Passivas em 3 ramos por classe, com tiers. Redistribuir pontos é grátis até o nível 10.
- **Armas:** espada, machado, martelo, lança, katana, adaga, arco e cajado, cada uma com combo e ataque pesado próprios. A maestria da arma sobe com o uso: nível 3 libera o finalizador do combo e nível 5 o ataque pesado.
- **Raridades:** Comum, Incomum, Raro, Épico, Lendário, Mítico e Secreto, mais os **Únicos**: 8 itens com efeito próprio (Lâmina do Eclipse, Punho do Colosso, Arco da Viúva, Coroa do Rei Goblin, Anel do Lich...) que só caem de chefes, com 1,5% de chance por chefe (o dobro no andar 20).
- **Conjuntos:** 3 conjuntos de 4 peças (um por masmorra) com bônus ao equipar 2 e 4 peças (o de 4 liga um efeito: Pilhagem, Pacto Espectral, Erupção).
- **Itens em 3D:** cada item tem o próprio modelo (sem emojis): ele aparece na mão, no chão quando cai, no inventário, na forja, no baú e na loja. O que você equipa aparece vestido no personagem com o mesmo visual (armadura, elmo, botas, amuleto e anel).
- **Equipamento:** arma, armadura, elmo, botas, amuleto e anel (mais de 70 bases, até o tier 3). Cada item sorteia **perks** próprios pela raridade, no estilo Destiny (Fúria Crescente, Explosão Fatal, Eco, Tempestade, Segunda Chance, Espinhos...). O Bruno reforja os perks.
- **Pets (tecla G):** seguem você, sobem de nível com os abates e dão bônus. Ovos no Otto, pagos com ouro, com as chances visíveis; ovos raros caem de Elites e chefes.
- **Jornada (tecla K):** recompensa diária em sequência de 7 dias, Passe do Hunter grátis com 50 tiers, 15 conquistas com títulos e marcos de nível.
- **Profissões:** Mineração, Herbalismo, Lenhador, Ferraria, Alquimia e Encantamento.
- **NPCs:** Bruno (forja, aprimoramento e reforja), Elric (encantar e desmontar), Mira (poções), Otto (loja, baús e ovos de pet), Kael (classes), Pedro (cavalo), Varg (Mercador de Masmorras, no Covil do Mercador na rua do sul), Quadro de Recompensas (contratos diários) e NPCs espalhados pelo mapa. A forja, a alquimia, a torre do Elric e o empório do Otto são construções com interior: entre para falar com eles.
- **Missões:** 15 da história e 10 secundárias (caçar, coletar, entregar, explorar, ativar pedras, forjar, encantar, montar, aparar, esquivar no tempo certo...), mais 3 contratos diários sorteados de uma lista.
- **Inimigos:** slimes, lobos, javalis (investida), caranguejos, goblins e arqueiros, aranhas, esqueletos e magos, golems (pancada em área), versões **Elite** e o chefe **Rei Goblin**.
- **Masmorras (o endgame):** três portais no mapa — **Toca dos Goblins** (nível 5+), **Cripta Esquecida** (10+) e **Abismo de Pedra** (15+). Grupo de 1 a 4 jogadores, cópia só sua; começa quando **todos dão Pronto** no portal.
  - **20 andares em uma corrida só** (sem ponto de retorno: saiu, recomeça), com um **chefe a cada 5** (baú com item exclusivo para cada membro).
  - Cada andar é uma **planta de várias salas** grandes (hall de entrada, 2 a 4 salas de combate em sequência com grade entre elas, salas laterais e a sala da escada), com portas em arco e salas temáticas: mina, caverna de cristais, acampamento goblin e fungos gigantes; salão de pilares, ossuário, capela e catacumba; lago de lava, colunas de basalto, forja e obsidiana.
  - Clima próprio (escuro, névoa e poeira ou brasas no ar) e **trilhas próprias** de cada masmorra (explorar, lutar, chefe); a música de batalha do mundo aberto não toca lá dentro.
  - Cada andar sorteia uma **mecânica** (exterminar, sobreviver a ondas, puxar 3 alavancas com emboscada, grelhas de fogo no chão) e um **objetivo extra** com bônus (limpar a tempo, ninguém cair, caçar o Campeão antes que fuja, pegar 3 relíquias).
  - **Segredos:** tijolo solto na parede que abre um **baú secreto**, **baú suspeito** (tesouro ou mímico) e **altar de bênção** para o grupo.
  - Cada masmorra tem **material próprio** e **itens exclusivos com perk de assinatura** (+dano dentro das masmorras). O **Mercador de Masmorras** (Varg, na praça) troca o material por chaves da masmorra seguinte, poções grandes, tônicos e itens exclusivos.
- **Viagem:** pedras de teletransporte (pelo mapa), cavalo e corrida.
- **Vila Aurora:** ruas largas calçadas (principal do portal ao pátio de treino e transversal), praça com chafariz e feira, casas com jardim e porta para a rua, vielas e becos. Cada comerciante tem sua loja temática: ferraria de tijolos com forja aberta, chalé de alquimia com horta de ervas, torre do encantador e empório do Otto.
- **Baús e ovos:** ao abrir um baú, seu personagem aparece no fundo ajoelhando, abrindo a tampa e erguendo o item; ao chocar um ovo, ele racha na sua frente e o pet salta para fora.
- **Locais de interesse:** Moinho dos Campos, Círculo de Pedras, Torre de Vigia Abandonada, Estátua do Herói Caído, Acampamento Abandonado, Observatório em Ruínas, Cemitério Antigo, Altar Esquecido e Navio Naufragado. Descobrir dá XP e ouro, e cada um tem um baú escondido (aparecem como ❓ no mapa).
- **Vila viva:** moradores passeando e conversando (com balões de fala), guardas fazendo ronda, crianças correndo em volta do chafariz, galinhas, gatos e cachorro soltos, pássaros no céu, borboletas de dia e vaga-lumes à noite; feira com barracas, bancos, poço, carroça, varal, galinheiro, canteiros, bandeirinhas e janelas que acendem à noite.
- **Dia e noite:** 14 min de dia e 6 de noite. À noite os inimigos batem mais forte e aparecem mais Elites, mas XP, ouro e equipamentos rendem mais.
- **Tutorial:** dicas no topo da tela nos primeiros níveis (dá para pular ou recomeçar nas Configurações).
- **Visual:** rastro da arma por raridade (Lendário+ solta faíscas), faíscas de impacto por elemento, aura do rank (D em diante), armaduras, elmos e botas visíveis no personagem (capa no Lendário+), animações com transição suave e cavalo animado.

### 🔊 Sons e música

O Roblox removeu os sons antigos que vinham no Studio, então os sons do jogo ficam num catálogo para você preencher: **`src/shared/SoundIds.luau`**. Para cada efeito, ambiente (vila, floresta, praia...) e música (vila, exploração, noite, chefe) há um campo `id`:

1. No Studio, abra **Caixa de ferramentas → Creator Store → Áudio** e procure (ex.: "sword swing", "forest ambience", "medieval town music"). Prefira sons enviados pela conta **Roblox** (livres para usar).
2. Clique com o botão direito no som → **Copiar ID do recurso**.
3. Cole no campo: `id = "rbxassetid://123456789"`.

**Música de combate:** ao lutar, a música troca para a do tipo de inimigo mais perto (slime, lobo, esqueleto, golem, rei goblin...) e volta para a da região uns 8 segundos depois da luta. Os IDs ficam em `SoundIds.Combat` (catálogo licenciado APM do Roblox); bonecos de treino não trocam a música.

Campos vazios usam um som interno de reserva (ou ficam em silêncio). Ao abrir o jogo, cada ID é testado; se algum não carregar, aparece um aviso no Output e o jogo usa a reserva.

### Versão em inglês (e outras línguas)

O jogo é escrito em português e usa a **tradução automática do Roblox** para os outros idiomas (inclusive textos criados por script): no [Creator Dashboard](https://create.roblox.com/dashboard/creations), abra o jogo → **Localização** → idioma de origem **Português (Brasil)** → ligue **Captura automática de texto** e **Tradução automática** para inglês, espanhol etc. Revise as traduções dos textos mais vistos (menu, missões) na mesma tela.

### Ícones (game-icons.net)

O jogo não usa emojis: todos os ícones são desenhos do [game-icons.net](https://game-icons.net) (licença CC BY 3.0, créditos na janela de Configurações), juntados em 3 folhas em `assets/icones/`. **Uma vez só**, envie as folhas ao Roblox:

1. No Studio, abra o **Gerenciador de ativos** (*Janela → Gerenciador de ativos*; na interface antiga, *Exibir → Gerenciador de ativos*) e clique no botão **Importação em massa** (*Bulk Import*, a seta para cima no topo do painel). **Não** use *Importar 3D*: essa janela só aceita modelos (FBX/OBJ/GLB).
2. Na janela que abrir, vá até a pasta do projeto **`MMOTESTE\assets\icones`** (não é a `src\shared`) e escolha `folha1.png`, `folha2.png` e `folha3.png`.
3. Elas aparecem em *Imagens* no Gerenciador de ativos. Clique com o botão direito em cada uma → **Copiar ID do ativo**.
4. Cole em `src/shared/Icons.luau`, na mesma ordem (ou mande os 3 IDs para quem cuida do código): `Icons.Sheets = { "rbxassetid://ID_DA_FOLHA1", "rbxassetid://ID_DA_FOLHA2", "rbxassetid://ID_DA_FOLHA3" }`.

Enquanto as folhas não estiverem enviadas, cada ícone aparece como um losango ◆.

Para trocar ou adicionar um ícone: escreva o nome do game-icons.net no código (`icon = "crossed-swords"`, `UI.icon("key", {...})`) e rode `python scripts/icones/montar.py`. Ele baixa o que falta, remonta as folhas e diz quais mudaram (só essas precisam ser enviadas de novo, trocando o ID).

### Modelos 3D da natureza

Árvores, pinheiros, palmeiras, árvores secas, pedras e arbustos usam modelos **low-poly gratuitos da Creator Store**, listados em `src/server/WorldGen/ExternalModels.luau`. Para vê-los **no Studio** (e no jogo publicado), salve-os uma vez dentro do projeto:

1. Abra o jogo no Studio (o `MMOTESTE.rbxlx` gerado pelo Rojo), modo de edição (sem apertar Play).
2. Abra a **Barra de comandos** (*Exibir → Barra de comandos*), cole a linha única que está no topo de `scripts/studio/baixar_modelos.lua` e aperte **Ctrl+Enter** (ou clique em **Correr**, à direita da barra). Só Enter pula linha e não executa. Os 13 modelos aparecem em `ServerStorage → Natureza`.
3. No Explorer, botão direito em **Natureza** → **Salvar em arquivo...** → salve como **`MMOTESTE\assets\modelos\Natureza.rbxm`**.
4. Gere o jogo de novo (passo 4) e abra. As árvores novas aparecem no Play.

Sem esse arquivo, o jogo publicado ainda tenta baixar os modelos na hora (precisa de *Configurações do jogo → Segurança → Permitir o carregamento de ativos de terceiros*); se nada funcionar, a natureza blocada é usada, sem quebrar nada.

---

## 🛠️ Para quem vai editar o código

- **[AGENTS.md](AGENTS.md):** regras, arquitetura e receitas para desenvolver (vale para pessoas e IAs).
- **[ROADMAP.md](ROADMAP.md):** o que já existe e as próximas features, por prioridade.
- **Verificação antes de cada commit:** `powershell -ExecutionPolicy Bypass -File scripts/verificar.ps1`

### Edição ao vivo (recomendado)

Com isso, qualquer arquivo salvo em `src/` aparece no Studio na hora, sem gerar o `.rbxlx` de novo.

1. Instale o plugin do Rojo no Studio: rode **`3-instalar-plugin-rojo.bat`** (ou `rojo plugin install`) e reinicie o Studio.
2. Rode **`2-sincronizar-ao-vivo.bat`** (ou `rojo serve default.project.json`) e deixe a janela aberta.
3. No Studio, abra o `MMOTESTE.rbxlx` e clique em **Plugins → Rojo → Connect**.

### Onde fica cada coisa

| Arquivo | O que tem |
|---|---|
| `src/shared/Config.luau` | Vida, mana, estamina, velocidades, curva de XP |
| `src/shared/WeaponStyles.luau` | Combos e ataques pesados de cada arma |
| `src/shared/Classes.luau` | Classes e habilidades |
| `src/shared/Items.luau` | Armas, armaduras, materiais, poções e encantamentos |
| `src/shared/Rarities.luau` | Raridades e chances de drop/baú |
| `src/shared/Recipes.luau` | Receitas da forja e da alquimia |
| `src/shared/Enemies.luau` | Inimigos e acampamentos |
| `src/shared/Quests.luau` | Missões e contratos diários |
| `src/shared/NPCs.luau` | NPCs, posições e falas |
| `src/shared/World.luau` | Relevo, biomas, estradas, locais e pedras de viagem |
| `src/server/WorldGen/` | Construção do mundo (terreno, vila, locais, natureza) |
| `src/server/` | Combate, inimigos, missões, ofícios, dados |
| `src/client/` | HUD, janelas, efeitos, animações, controles |

Como o Rojo monta o jogo:

```
src/shared  → ReplicatedStorage.Shared              (regras e dados usados pelos dois lados)
src/server  → ServerScriptService.Server            (lógica do servidor)
src/client  → StarterPlayer.StarterPlayerScripts.Client  (interface e controles)
```

---

## ❓ Problemas comuns

| Problema | Solução |
|---|---|
| "Rojo não encontrado" ao rodar o `.bat` | Coloque o `rojo.exe` na pasta `tools/` (passo 3). |
| Windows avisa que o `rojo.exe` pode ser perigoso | É o aviso padrão para programas baixados da internet. O Rojo é open source e usado pela comunidade Roblox. Clique em *Mais informações → Executar assim mesmo*. |
| Aviso amarelo "DataStore indisponível" no Output | Normal no Studio sem publicar: o progresso não é salvo. Para salvar, publique o jogo e ative *Game Settings → Security → Enable Studio Access to API Services*. |
| Linhas vermelhas `CorePackages...` no Output | Vêm da interface interna do Roblox, não do jogo. Pode ignorar. |
| Janela "Migração de iluminação" ao abrir | Não deve mais aparecer (o projeto já define o estilo de luz). Se aparecer, clique em *Continuar*. |
| O mundo aparece vazio no modo de edição | Normal: ele é gerado quando você aperta Play. |
| Ícones aparecem como losangos ◆ | As folhas de ícones ainda não foram enviadas ao Roblox. Veja "Ícones (game-icons.net)". |
| Aviso "[ExternalModels] ... não carregaram" | Falta o `assets/modelos/Natureza.rbxm`: siga "Modelos 3D da natureza". Até lá a natureza fica blocada. |
| A janela de importar só mostra arquivos 3D | É o *Importar 3D*. Para as folhas de ícones use o *Gerenciador de ativos → Importação em massa*. |
| Jogo pesado | É o primeiro protótipo; reduza o zoom de câmera ou feche outros programas. Para ajustar, diminua as quantidades em `src/server/WorldGen/Scatter.luau`. |

Para ver erros: no Studio, **Janela → Saída** (*View → Output* em inglês).

---

A versão anterior (v1) está guardada em `versoes/v1`.
