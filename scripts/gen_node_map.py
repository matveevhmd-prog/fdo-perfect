#!/usr/bin/env python3
"""Генерує docs/NODE_MAP.md з workflows/DEMO_Archi_Agent_Core.json (CLAUDE.md п. 14, рішення 6).
Запуск після кожного переекспорту workflow: python3 scripts/gen_node_map.py
Карта не редагується руками — лише перегенеровується."""
import json, collections, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'workflows', 'DEMO_Archi_Agent_Core.json')
OUT = os.path.join(ROOT, 'docs', 'NODE_MAP.md')

d = json.load(open(SRC, encoding='utf-8'))
nodes = d['nodes']
out_edges = collections.defaultdict(list)
in_edges = collections.defaultdict(list)
for src, conns in d.get('connections', {}).items():
    for kind, outputs in conns.items():
        for i, targets in enumerate(outputs or []):
            for t in targets or []:
                label = t['node'] + ('' if kind == 'main' else f' ({kind})')
                if kind == 'main' and len(outputs) > 1:
                    label = f'[{i}] ' + label
                out_edges[src].append(label)
                in_edges[t['node']].append(src)

def group(name):
    return name.split(':')[0].strip() if ':' in name else '(без префікса)'

by_group = collections.defaultdict(list)
for n in nodes:
    by_group[group(n['name'])].append(n)

types = collections.Counter(n['type'].split('.')[-1] for n in nodes)
lines = [
    '# ARCHI — карта вузлів core workflow (згенеровано)',
    '',
    f"> **Не редагувати руками.** Джерело — `workflows/DEMO_Archi_Agent_Core.json`; генератор — `scripts/gen_node_map.py` (`CLAUDE.md` п. 14, рішення 6).",
    f"> Workflow `{d.get('id')}`, `versionId {d.get('versionId')}`, вузлів: {len(nodes)}, груп за префіксом: {len(by_group)}.",
    '',
    '## Типи вузлів',
    '',
    '| Тип | Кількість |',
    '|---|---|',
]
lines += [f'| `{t}` | {c} |' for t, c in types.most_common()]
for g in sorted(by_group, key=lambda x: (x == '(без префікса)', x)):
    lines += ['', f'## {g} ({len(by_group[g])})', '', '| Вузол | Тип | Звідки | Куди |', '|---|---|---|---|']
    for n in sorted(by_group[g], key=lambda x: x['name']):
        frm = ', '.join(sorted(set(in_edges.get(n['name'], [])))) or '—'
        to = ', '.join(out_edges.get(n['name'], [])) or '—'
        lines.append(f"| {n['name']} | `{n['type'].split('.')[-1]}` | {frm} | {to} |")
open(OUT, 'w', encoding='utf-8').write('\n'.join(lines) + '\n')
print(f'{OUT}: {len(nodes)} вузлів, {len(by_group)} груп')
