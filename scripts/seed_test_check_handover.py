#!/usr/bin/env python3
"""ARCHI — валідація V2 (docs/handover/06): підкидає 11 відомих дефектів у тимчасову копію й перевіряє, що check_handover.py їх ловить.
Запуск з кореня: python3 scripts/seed_test_check_handover.py   (потрібна збірка: python3 scripts/build_handover_bundle.py)"""
import shutil, subprocess, re, sys
from pathlib import Path
import tempfile
SRC=Path(__file__).resolve().parent.parent; BASE=Path(tempfile.gettempdir())/'archi_seed_test'
def fresh():
    if BASE.exists(): shutil.rmtree(BASE)
    shutil.copytree(SRC, BASE, ignore=shutil.ignore_patterns('.git'))
def run():
    r=subprocess.run(['python3','scripts/check_handover.py'],cwd=BASE,capture_output=True,text=True)
    return {l.split()[0]:l.split()[1] for l in r.stdout.splitlines() if re.match(r'^A\d+b?\s',l)}
def edit(path,fn):
    p=BASE/path; p.write_text(fn(p.read_text(encoding='utf8')),encoding='utf8')
H='docs/handover/'
tests=[
 ('S1','A2',H+'01_PRODUCT_BRIEF.md',lambda t:t+'\nСм. `docs/NO_SUCH_FILE.md`\n'),
 ('S2','A4',H+'02_BUSINESS_REQUIREMENTS.md',lambda t:t+'\nДив. OD-99\n'),
 ('S3','A3',H+'01_PRODUCT_BRIEF.md',lambda t:t+'\nДив. п. 99\n'),
 ('S4','A10',H+'03_TECHNICAL_CTO.md',lambda t:t+'\nWorkflow має 205 вузлів\n'),
 ('S5','A8',H+'01_PRODUCT_BRIEF.md',lambda t:t+'\nтокен 123456789:AA'+'B'*30+'\n'),
 ('S6','A9',H+'04_METHODOLOGY_FOR_DEVELOPERS.md',lambda t:t+'\nETC — це залишок годин\n'),
 ('S7','A5',H+'02_BUSINESS_REQUIREMENTS.md',lambda t:re.sub(r'^\| R-7 \|.*\n','',t,flags=re.M)),
 ('S8','A6',H+'02_BUSINESS_REQUIREMENTS.md',lambda t:re.sub(r'^\| OD-14 \|.*\n','',t,flags=re.M)),
 ('S9','A11',H+'02_BUSINESS_REQUIREMENTS.md',lambda t:t.replace('| BR-01 | ','| BR-01 | | ',1)),
 ('S10','A7',H+'02_BUSINESS_REQUIREMENTS.md',lambda t:t.replace('| BR-02 |','| BR-01 |',1)),
]
fresh(); base=run(); print('БАЗА:',{k:v for k,v in base.items() if v!='PASS'} or 'усе PASS')
ok=0
for sid,chk,path,fn in tests:
    fresh(); edit(path,fn); r=run()
    hit=r.get(chk)=='FAIL'; ok+=hit
    print(sid,chk,'виявлено' if hit else 'ПРОПУЩЕНО',{k:v for k,v in r.items() if v!='PASS'})
# S11: зміна в збірці
fresh(); b=BASE/'docs/handover/ARCHI_FULL_PACKAGE.md'; t=b.read_text(encoding='utf8'); i=t.index('SOURCE CLAUDE.md'); i=t.index('ЗАФІКСОВАНІ РІШЕННЯ',i); b.write_text(t[:i]+'Х'+t[i+1:],encoding='utf8'); r=run()
hit=r.get('A12')=='FAIL'; ok+=hit; print('S11 A12','виявлено' if hit else 'ПРОПУЩЕНО',{k:v for k,v in r.items() if v!='PASS'})
print('Виявлено %d з 11'%ok)
