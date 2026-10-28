# Gera localization/Traducoes.csv (tabela de tradução do Roblox) a partir de scripts/traducao/traducoes.py.
# Uso: python scripts/traducao/gerar.py
import csv
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from traducoes import T  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(HERE))
out = os.path.join(ROOT, 'localization', 'Traducoes.csv')
os.makedirs(os.path.dirname(out), exist_ok=True)
with open(out, 'w', encoding='utf-8', newline='') as f:
    writer = csv.writer(f)
    writer.writerow(['Key', 'Source', 'Context', 'Example', 'en', 'es'])
    for source in sorted(T):
        en, es = T[source]
        writer.writerow(['', source, '', '', en, es])
print(f'{len(T)} textos em {out}')
