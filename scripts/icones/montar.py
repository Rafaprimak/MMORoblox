# Monta as folhas de ícones (atlas) do jogo a partir dos nomes usados no código.
#
# Ícones: game-icons.net (CC BY 3.0, créditos no README e nas Configurações do jogo).
# Uso:  python scripts/icones/montar.py
#   1) procura no src/ os nomes de ícone usados (icon = "nome", UI.icon("nome"), UI.setIcon(x, "nome"),
#      Icons.get("nome") e os talentos node(..., "nome", ...));
#   2) baixa os que faltam do game-icons.net (branco com fundo transparente) para scripts/icones/cache;
#   3) monta assets/icones/folhaN.png (1024x1024, células de 128 px) mantendo a posição dos ícones
#      que já existiam (assim uma folha já enviada ao Roblox só muda se ganhar ícone novo);
#   4) escreve src/shared/IconAtlas.luau e diz quais folhas mudaram (essas precisam ser enviadas de novo).
import hashlib
import io
import json
import os
import re
import sys
import urllib.request

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
HERE = os.path.dirname(os.path.abspath(__file__))
CACHE = os.path.join(HERE, "cache")
OUT = os.path.join(ROOT, "assets", "icones")
ATLAS_LUA = os.path.join(ROOT, "src", "shared", "IconAtlas.luau")
HASHES = os.path.join(OUT, "folhas.json")

SHEET = 1024
CELL = 128
PAD = 8
COLUMNS = SHEET // CELL
PER_SHEET = COLUMNS * COLUMNS

PATTERNS = [
    r'\bicon\s*=\s*"([a-z0-9]+(?:-[a-z0-9]+)*)"',
    r'UI\.icon\(\s*"([a-z0-9]+(?:-[a-z0-9]+)*)"',
    r'UI\.setIcon\([^,()]+,\s*"([a-z0-9]+(?:-[a-z0-9]+)*)"',
    r'Icons\.\w+\(\s*"([a-z0-9]+(?:-[a-z0-9]+)*)"',
    r'node\("[^"]+",\s*"[^"]+",\s*\d+,\s*\d+,\s*"[^"]+",\s*"([a-z0-9]+(?:-[a-z0-9]+)*)"',
    r'touchAction\("[^"]+",\s*"([a-z0-9]+(?:-[a-z0-9]+)*)"',
    r'--\s*ícones?:\s*((?:"[a-z0-9-]+"[,\s]*)+)',  # ícones escolhidos em tempo de execução
]


def catalog():
    authors = {}
    with open(os.path.join(HERE, "catalogo.txt"), encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line.endswith(".svg"):
                author, name = line[:-4].split("/")
                authors.setdefault(name, author)
    return authors


def used_names():
    found = set()
    for folder, _, files in os.walk(os.path.join(ROOT, "src")):
        for file in files:
            if not file.endswith(".luau") or file == "IconAtlas.luau":
                continue
            text = open(os.path.join(folder, file), encoding="utf-8").read()
            for pattern in PATTERNS:
                for match in re.findall(pattern, text):
                    found.update(re.findall(r"[a-z0-9]+(?:-[a-z0-9]+)*", match))
    return found


def previous_order():
    if not os.path.exists(ATLAS_LUA):
        return []
    text = open(ATLAS_LUA, encoding="utf-8").read()
    entries = re.findall(r'\["([a-z0-9-]+)"\]\s*=\s*\{\s*(\d+),\s*(\d+)\s*\}', text)
    order = []
    for name, sheet, index in entries:
        order.append(((int(sheet) - 1) * PER_SHEET + int(index), name))
    order.sort()
    slots = []
    for position, name in order:
        while len(slots) < position:
            slots.append(None)
        slots.append(name)
    return slots


def fetch(name, author):
    os.makedirs(CACHE, exist_ok=True)
    path = os.path.join(CACHE, name + ".png")
    if not os.path.exists(path):
        url = f"https://game-icons.net/icons/ffffff/transparent/1x1/{author}/{name}.png"
        request = urllib.request.Request(url, headers={"User-Agent": "MMOTESTE-icones"})
        with urllib.request.urlopen(request, timeout=30) as response, open(path, "wb") as out:
            out.write(response.read())
    return Image.open(path).convert("RGBA")


def main():
    authors = catalog()
    names = used_names()
    unknown = sorted(n for n in names if n not in authors)
    if unknown:
        print("Ícones que não existem no game-icons.net:", ", ".join(unknown))
        sys.exit(1)
    slots = previous_order()
    # tira os que não são mais usados (deixa o buraco: as outras posições não mudam)
    slots = [n if n in names else None for n in slots]
    for name in sorted(names):
        if name not in slots:
            hole = next((i for i, n in enumerate(slots) if n is None), None)
            if hole is None:
                slots.append(name)
            else:
                slots[hole] = name
    sheets = max(1, (len(slots) + PER_SHEET - 1) // PER_SHEET)
    os.makedirs(OUT, exist_ok=True)
    old_hashes = json.load(open(HASHES)) if os.path.exists(HASHES) else {}
    new_hashes = {}
    changed = []
    for s in range(sheets):
        image = Image.new("RGBA", (SHEET, SHEET), (255, 255, 255, 0))
        for i in range(PER_SHEET):
            index = s * PER_SHEET + i
            name = slots[index] if index < len(slots) else None
            if not name:
                continue
            icon = fetch(name, authors[name]).resize((CELL - PAD * 2, CELL - PAD * 2), Image.LANCZOS)
            x, y = (i % COLUMNS) * CELL + PAD, (i // COLUMNS) * CELL + PAD
            image.alpha_composite(icon, (x, y))
        buffer = io.BytesIO()
        image.save(buffer, "PNG", optimize=True)
        data = buffer.getvalue()
        file = f"folha{s + 1}.png"
        open(os.path.join(OUT, file), "wb").write(data)
        digest = hashlib.sha1(data).hexdigest()
        new_hashes[file] = digest
        if old_hashes.get(file) != digest:
            changed.append(file)
    json.dump(new_hashes, open(HASHES, "w"), indent=1)
    lines = [
        "-- GERADO por scripts/icones/montar.py: não edite à mão.",
        "-- [nome do ícone] = { folha, posição na folha } (posição = linha * colunas + coluna)",
        "return {",
        f"\tcell = {CELL},",
        f"\tcolumns = {COLUMNS},",
        f"\tsheets = {sheets},",
        "\ticons = {",
    ]
    for index, name in enumerate(slots):
        if name:
            lines.append(f'\t\t["{name}"] = {{ {index // PER_SHEET + 1}, {index % PER_SHEET} }},')
    lines += ["\t},", "}", ""]
    open(ATLAS_LUA, "w", encoding="utf-8", newline="\n").write("\n".join(lines))
    print(f"{len(names)} ícones em {sheets} folha(s).")
    if changed:
        print("Folhas novas/alteradas (envie ao Roblox e atualize Icons.Sheets):", ", ".join(changed))
    else:
        print("Nenhuma folha mudou.")


if __name__ == "__main__":
    main()
