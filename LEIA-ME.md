# MMOTESTE: Hunter RPG v2 (protótipo blocado)

Mundo aberto gerado por terreno de verdade, 4 classes com 16 habilidades, estilos de luta diferentes por arma, estamina, profissões, NPCs de ofício e missões com história.

## Como testar

0. Primeira vez depois de clonar: baixe o Rojo em https://github.com/rojo-rbx/rojo/releases (arquivo `rojo-...-windows-x86_64.zip`) e coloque o `rojo.exe` na pasta `tools/` (ela não vai para o repositório).
1. Dê dois cliques em `1-gerar-jogo.bat` (gera `MMOTESTE.rbxlx`).
2. Abra `MMOTESTE.rbxlx` no Roblox Studio e aperte **Play (F5)**.
3. O servidor gera o mundo em ~10 a 20 segundos (aparece uma tela de carregamento).
4. Escolha a classe e fale com a **Capitã Lyra** (❗ na cabeça), perto da praça.
5. Erros aparecem em *Janela → Saída*. As linhas `CorePackages...` são internas do Roblox e podem ser ignoradas.

## Controles

| Ação | Tecla |
|---|---|
| Atacar / combo | Clique (segure para emendar) |
| Ataque pesado | Botão direito ou R (maestria 5) |
| Esquivar (rolamento) | Q |
| Correr | Shift (gasta estamina) |
| Habilidades | 1, 2, 3, 4 |
| Poções | Z (vida), X (mana), V (vigor) |
| Montar / desmontar | H |
| Inventário / Personagem / Missões / Mapa / Baús | I / C / J / M / B |
| Falar, coletar, viajar | E perto do NPC, rocha, planta ou pedra |

## O que tem

- **Mundo:** continente com colinas, Bosque Sombrio (leste), Planalto das Ruínas (oeste), lago, praia com farol e píer, montanhas nevadas, Passagem do Norte com Portão Selado (Nível 10) e o Covil do Rei Goblin.
- **Classes:** Guerreiro, Arqueiro, Mago e Assassino. Cada uma tem 4 habilidades (níveis 1, 3, 6 e 10) que sobem de rank com pontos (1 por nível).
- **Armas com estilo próprio:** espada (combo de 3), machado (golpes largos), martelo (pancadas em área), lança (alcance longo), katana (rápida, crítico), adaga (muito rápida, dano pelas costas), arco e cajado (projéteis). Cada arma tem maestria: nível 3 libera o finalizador do combo e nível 5 o ataque pesado.
- **Profissões:** Mineração, Herbalismo, Lenhador, Ferraria, Alquimia e Encantamento.
- **NPCs:** Bruno (forja e aprimoramento), Elric (encantar e desmontar), Mira (poções), Otto (loja e baús), Kael (classes), Pedro (cavalo), Quadro de Recompensas (contratos diários), além de NPCs no campo.
- **Missões:** 15 da história e 10 secundárias, com objetivos de caçar, coletar, entregar, explorar, ativar pedras, forjar, encantar, montar e esquivar. Mais 3 contratos diários.
- **Viagem:** pedras de teletransporte (pelo mapa), cavalo e corrida.

## Modo teste (só no Studio)

Os botões **+5.000 XP**, **+5.000 Ouro**, **+Materiais** e **+Perícias** aparecem só no Studio, para testar rápido.

## Editar ao vivo

1. O plugin do Rojo já foi instalado no Studio.
2. Rode `2-sincronizar-ao-vivo.bat` e deixe a janela aberta.
3. No Studio: **Plugins → Rojo → Connect**.

## Onde mexer

| Arquivo | O que tem |
|---|---|
| `src/shared/Config.luau` | Vida, mana, estamina, velocidades, XP |
| `src/shared/WeaponStyles.luau` | Combos e ataques pesados de cada arma |
| `src/shared/Classes.luau` | Classes e habilidades |
| `src/shared/Items.luau` | Armas, armaduras, materiais, poções e encantamentos |
| `src/shared/Recipes.luau` | Receitas da forja e alquimia |
| `src/shared/Enemies.luau` | Inimigos e acampamentos |
| `src/shared/Quests.luau` | Missões e contratos diários |
| `src/shared/World.luau` | Relevo, biomas, estradas e locais |
| `src/server/WorldGen/` | Construção do mundo (terreno, vila, locais, natureza) |

A versão anterior está guardada em `versoes/v1`.
