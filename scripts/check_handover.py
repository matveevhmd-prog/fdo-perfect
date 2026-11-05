#!/usr/bin/env python3
"""ARCHI — автоматична перевірка пакета передачі `docs/handover/` (stdlib).

Запуск з кореня репозиторію:  python3 scripts/check_handover.py [--bundle]
Код виходу: 0 — помилок (FAIL) немає; 1 — є FAIL. WARN не блокує.
Це автоматизована частина плану `docs/handover/05_CTO_REVIEW_PLAN.md` (перевірки A1…A12);
решта плану — ручна й жива (n8n, Supabase). Результати кожної перевірки друкуються з ID.
"""
import hashlib
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
H = ROOT / "docs" / "handover"
BUNDLE = H / "ARCHI_FULL_PACKAGE.md"
res = []  # (id, status, text)


def rec(i, st, t):
    res.append((i, st, t))


def read(p):
    return Path(p).read_text(encoding="utf8")


def handover_files():
    return sorted(p for p in H.glob("0*.md"))


# ---------- A1 наявність файлів
need = ["00_START_HERE.md", "01_PRODUCT_BRIEF.md", "02_BUSINESS_REQUIREMENTS.md", "03_TECHNICAL_CTO.md",
        "04_METHODOLOGY_FOR_DEVELOPERS.md", "05_CTO_REVIEW_PLAN.md", "06_REVIEW_VALIDATION_PLAN.md",
        "07_REVIEW_REPORT.md", "08_CODE_VS_DOCS_AUDIT_PROMPT.md"]
miss = [n for n in need if not (H / n).exists()]
rec("A1", "FAIL" if miss else "PASS", "відсутні файли: %s" % miss if miss else "усі %d файлів пакета є" % len(need))

META = {"05_CTO_REVIEW_PLAN.md", "06_REVIEW_VALIDATION_PLAN.md", "07_REVIEW_REPORT.md", "08_CODE_VS_DOCS_AUDIT_PROMPT.md"}  # описують перевірки й підкинуті дефекти
alldocs = {p.name: read(p) for p in handover_files()}
docs = {k: v for k, v in alldocs.items() if k not in META}  # зміст перевіряється лише у 00–04
allh = "\n".join(docs.values())
roadmap = read(ROOT / "docs/ROADMAP_TO_RELEASE.md")
claude = read(ROOT / "CLAUDE.md")
techspec = read(ROOT / "docs/ARCHI_TECH_SPEC_v3_1.md")

# ---------- A2 посилання на файли репозиторію
bad = set()
for name, txt in docs.items():
    for m in re.finditer(r"`((?:docs|sql|scripts|workflows|tests)/[^`\s]+)`", txt):
        path = m.group(1).rstrip(".,;:)")
        if any(c in path for c in "*<>{}…"):
            continue
        if not (ROOT / path).exists():
            bad.add((name, path))
rec("A2", "FAIL" if bad else "PASS", "посилання на відсутні файли: %s" % sorted(bad) if bad else "усі посилання на файли репозиторію ведуть на наявні")

# ---------- A3 пункти CLAUDE.md
last = max(int(x) for x in re.findall(r"^(\d+)\. \*\*", claude, re.M))
over = set()
for name, txt in docs.items():
    for m in re.finditer(r"п\. (\d+)(?:[–-](\d+))?", txt):
        for g in m.groups():
            if g and not 1 <= int(g) <= last:
                over.add((name, m.group(0)))
rec("A3", "FAIL" if over else "PASS", "посилання на неіснуючі пункти CLAUDE.md (останній %d): %s" % (last, sorted(over)) if over else "усі посилання «п. N» ≤ %d" % last)

# ---------- A4 ідентифікатори карти
def ids(pattern, text):
    return set(re.findall(pattern, text))

road_od = ids(r"\| (OD-\d+) \|", roadmap)
road_w = ids(r"\| (W\d+\.\d+)[  |]", roadmap)
road_wd = ids(r"\| (WD\.\d+) ", roadmap)
road_r = ids(r"\| (R-\d+) \|", roadmap)
ts_d = ids(r"\| (D\d+) \|", techspec)
used_od = ids(r"\bOD-\d+", allh)
used_w = ids(r"\bW\d+\.\d+(?!\d)", allh)
used_wd = ids(r"\bWD\.\d+", allh)
used_r = ids(r"\bR-[1-9]\d?\b", allh)  # R-06 з чекпойнта — не критерій релізу
miss4 = sorted((used_od - road_od) | (used_w - road_w) | (used_wd - road_wd) | (used_r - road_r))
rec("A4", "FAIL" if miss4 else "PASS", "ID, яких немає в карті: %s" % miss4 if miss4 else "OD/W/WD/R з пакета визначені в ROADMAP (%d OD, %d W, %d WD, %d R)" % (len(used_od), len(used_w), len(used_wd), len(used_r)))
used_d = ids(r"\bD(?:1[0-4]|[1-9])\b", docs["03_TECHNICAL_CTO.md"])
rec("A4b", "WARN" if (used_d - ts_d) else "PASS", "D-номери без рядка в TECH_SPEC: %s" % sorted(used_d - ts_d) if (used_d - ts_d) else "D-номери з 03 є в TECH_SPEC §11")

# ---------- A4c: кожен вузол W карти згаданий у 00–04 (повнота каталогу фіч, R1.4)
unc = sorted(road_w - used_w, key=lambda x: [int(i) for i in x[1:].split(".")])
rec("A13", "FAIL" if unc else "PASS", "вузли карти без згадки в пакеті: %s" % unc if unc else "усі %d вузлів W карти згадані в пакеті" % len(road_w))

# ---------- A5 критерії R-1…R-14 у вимогах
brd = docs["02_BUSINESS_REQUIREMENTS.md"]
missr = [f"R-{i}" for i in range(1, 15) if not re.search(rf"\| R-{i} \|", brd)]
rec("A5", "FAIL" if missr else "PASS", "критерії без рядка в 02 §6: %s" % missr if missr else "усі R-1…R-14 є в 02 §6")

# ---------- A6 відкриті OD з карти є в 02 §8
sec8 = brd[brd.index("## 8. Відкриті рішення"):]
def expand(txt):
    out = set(re.findall(r"OD-(\d+)", txt))
    for a, b in re.findall(r"OD-(\d+)\s*[…\-–]\s*OD-(\d+)", txt):
        out |= {str(i) for i in range(int(a), int(b) + 1)}
    return out
have = expand("\n".join(l for l in sec8.splitlines() if l.startswith("|")))  # лише рядки таблиці (у вступі є діапазон OD-1…OD-25)
openod = set()
for m in re.finditer(r"^\| (OD-(\d+)) \|(.*)$", roadmap, re.M):
    row = m.group(3)
    if "Закрито" not in row and "~~" not in row:
        openod.add(m.group(2))
miss6 = sorted(openod - have, key=int)
rec("A6", "FAIL" if miss6 else "PASS", "відкриті OD з карти відсутні в 02 §8: %s" % ["OD-" + x for x in miss6] if miss6 else "усі відкриті OD карти (%d) є в 02 §8" % len(openod))

# ---------- A7 унікальність і джерела BR/NFR
brs = re.findall(r"^\| (BR-\d+) \|(.*)\|\s*$", brd, re.M)
dup = [k for k in {a for a, _ in brs} if [a for a, _ in brs].count(k) > 1]
nosrc = [a for a, rest in brs if not rest.rsplit("|", 1)[-1].strip()]
rec("A7", "FAIL" if (dup or nosrc) else "PASS", "дублі: %s; без джерела: %s" % (dup, nosrc) if (dup or nosrc) else "BR-вимог %d, дублів немає, кожна має джерело" % len(brs))

# ---------- A8 секрети
pat = re.compile(r"\d{8,}:AA[A-Za-z0-9_-]{20,}|sk-[A-Za-z0-9]{20,}|eyJ[A-Za-z0-9_-]{20,}\.|AIza[0-9A-Za-z_-]{30,}|-----BEGIN [A-Z ]*KEY")
hits = [(n, m.group(0)[:12]) for n, t in docs.items() for m in pat.finditer(t)]
if BUNDLE.exists():
    hits += [("BUNDLE", m.group(0)[:12]) for m in pat.finditer(read(BUNDLE))]
rec("A8", "FAIL" if hits else "PASS", "знайдено схожі на секрети рядки: %s" % hits if hits else "секретів у пакеті й збірці немає")

# ---------- A9 термін «залишок»
lines = []
for n, t in docs.items():
    for i, l in enumerate(t.splitlines(), 1):
        if re.search(r"залишок(?!\s+(?:коштів|на\s+рахунк))", l, re.I) and not re.search(r"заборон|не вживає|колонк|назва|історичн|не прогнозу|не використов|«залишок»", l, re.I):
            lines.append("%s:%d" % (n, i))
rec("A9", "FAIL" if lines else "PASS", "«залишок» поза контекстом заборони: %s" % lines if lines else "термін «залишок» лише в контексті заборони/історичної колонки")

# ---------- A10 числа проти репозиторію
core = json.loads(read(ROOT / "workflows/DEMO_Archi_Agent_Core.json"))
n_nodes, vid = len(core["nodes"]), core.get("versionId", "")
bad10 = []
for n, t in docs.items():
    for m in re.finditer(r"(\d+) (?:вузол|вузл)", t):
        if int(m.group(1)) > 150 and int(m.group(1)) != n_nodes:
            bad10.append((n, m.group(0)))
    for m in re.finditer(r"a4c89c3c[-0-9a-f]*", t):
        if len(m.group(0)) > 8 and m.group(0) != vid:
            bad10.append((n, m.group(0)))
# A10b: канонічні документи не містять застарілої версії core (лише в рядках про поточний стан)
stale = []
for f in ["docs/ARCHI_TECH_SPEC_v3_1.md", "README.md"]:
    for i, l in enumerate(read(ROOT / f).splitlines(), 1):
        if re.search(r"\| Core workflow \|", l) and "a4c89c3c" not in l:
            stale.append("%s:%d" % (f, i))
rec("A10b", "FAIL" if stale else "PASS", "реєстр середовища з застарілою версією core: %s" % stale if stale else "реєстр core у TECH_SPEC = поточна версія")
rec("A10", "FAIL" if bad10 else "PASS", "розбіжності з експортом core (вузлів %d, версія %s): %s" % (n_nodes, vid[:8], bad10) if bad10 else "кількість вузлів (%d) і версія core (%s) у пакеті = експорт" % (n_nodes, vid[:8]))

# ---------- A11 таблиці markdown: однакова кількість колонок
bad11 = []
for n, t in alldocs.items():
    blk = []
    for i, l in enumerate(t.splitlines() + [""], 1):
        if l.startswith("|"):
            blk.append((i, len(re.findall(r"(?<!\\)\|", l))))
        else:
            if blk and len({c for _, c in blk}) > 1:
                bad11.append((n, blk[0][0]))
            blk = []
rec("A11", "FAIL" if bad11 else "PASS", "таблиці з різною кількістю колонок (файл, перший рядок): %s" % bad11 if bad11 else "усі таблиці мають сталу кількість колонок")

# ---------- A12 збірка (--bundle)
if "--bundle" in sys.argv or BUNDLE.exists():
    if not BUNDLE.exists():
        rec("A12", "FAIL", "збірки немає")
    else:
        b = read(BUNDLE)
        manifest = re.findall(r"<!-- SOURCE (\S+) sha256=([0-9a-f]{64}) bytes=(\d+) -->", b)
        bad12 = []
        for path, sha, nb in manifest:
            src = (ROOT / path).read_bytes()
            if hashlib.sha256(src).hexdigest() != sha:
                bad12.append((path, "sha змінився після збірки"))
            elif src.decode("utf8") not in b:
                bad12.append((path, "текст не міститься у збірці дослівно"))
        must = ["CLAUDE.md", "docs/ROADMAP_TO_RELEASE.md", "docs/FORMULAS.md", "docs/ARCHI_TECH_SPEC_v3_1.md", "SECURITY.md"]
        absent = [m for m in must if m not in {p for p, _, _ in manifest}]
        rec("A12", "FAIL" if (bad12 or absent) else "PASS", "збірка: розбіжності %s; відсутні обов'язкові %s" % (bad12, absent) if (bad12 or absent) else "збірка містить %d джерел дослівно, sha256 збігаються з файлами" % len(manifest))

w = max(len(r[0]) for r in res)
for i, st, t in res:
    print("%-*s  %-4s  %s" % (w, i, st, t))
fails = sum(1 for r in res if r[1] == "FAIL")
print("\nПідсумок: PASS %d · WARN %d · FAIL %d" % (sum(1 for r in res if r[1] == "PASS"), sum(1 for r in res if r[1] == "WARN"), fails))
sys.exit(1 if fails else 0)
