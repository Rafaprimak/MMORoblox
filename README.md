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
| Atacar / emendar combo | Clique (segure para continuar) | Botão ⚔ |
| Ataque pesado | Botão direito ou **R** (maestria 5 da arma) | Botão 💥 |
| Esquivar (rolamento) | **Q** | Botão ↩ |
| Correr | **Shift** (gasta estamina) | Botão 🏃 |
| Habilidades da classe | **1, 2, 3, 4** | Botões 1–4 |
| Poções | **Z** vida, **X** mana, **V** vigor | Toque na barra |
| Montar / desmontar | **H** | Botão 🐴 |
| Inventário / Personagem / Missões / Mapa / Baús | **I / C / J / M / B** | Botões à esquerda |
| Falar, coletar, viajar | **E** perto do NPC, rocha, planta ou pedra | Toque no aviso |

### Modo teste (só no Studio)

À esquerda da tela aparecem os botões **+5.000 XP**, **+5.000 Ouro**, **+Materiais** e **+Perícias**, para testar sem precisar farmar. Eles não funcionam num jogo publicado.

---

## 🗺️ O que tem no jogo

- **Mundo:** Vila Aurora (sul), Campos Verdejantes, Bosque Sombrio (leste), Planalto das Ruínas (oeste), lago com santuário, praia com farol e píer, montanhas nevadas, Passagem do Norte com o Portão Selado (Nível 10) e o Covil do Rei Goblin.
- **Classes:** Guerreiro, Arqueiro, Mago e Assassino. Cada uma tem 4 habilidades (liberadas nos níveis 1, 3, 6 e 10) que sobem de rank com pontos (1 por nível).
- **Armas:** espada, machado, martelo, lança, katana, adaga, arco e cajado, cada uma com combo e ataque pesado próprios. A maestria da arma sobe com o uso: nível 3 libera o finalizador do combo e nível 5 o ataque pesado.
- **Raridades:** Comum, Incomum, Raro, Épico, Lendário, Mítico e Secreto.
- **Profissões:** Mineração, Herbalismo, Lenhador, Ferraria, Alquimia e Encantamento.
- **NPCs:** Bruno (forja e aprimoramento), Elric (encantar e desmontar), Mira (poções), Otto (loja e baús), Kael (classes), Pedro (cavalo), Quadro de Recompensas (contratos diários) e NPCs espalhados pelo mapa.
- **Missões:** 15 da história e 10 secundárias (caçar, coletar, entregar, explorar, ativar pedras, forjar, encantar, montar, esquivar...), mais 3 contratos diários.
- **Inimigos:** slimes, lobos, javalis (investida), caranguejos, goblins e arqueiros, aranhas, esqueletos e magos, golems (pancada em área), versões **Elite** e o chefe **Rei Goblin**.
- **Viagem:** pedras de teletransporte (pelo mapa), cavalo e corrida.

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
| Janela "Migração de iluminação" ao abrir | Clique em *Continuar*. |
| O mundo aparece vazio no modo de edição | Normal: ele é gerado quando você aperta Play. |
| Jogo pesado | É o primeiro protótipo; reduza o zoom de câmera ou feche outros programas. Para ajustar, diminua as quantidades em `src/server/WorldGen/Scatter.luau`. |

Para ver erros: no Studio, **Janela → Saída** (*View → Output* em inglês).

---

A versão anterior (v1) está guardada em `versoes/v1`.
