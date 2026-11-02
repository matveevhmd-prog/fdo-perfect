#!/usr/bin/env python3
"""ARCHI — перевірка узгодженості документації (без залежностей, лише stdlib).

Запуск з кореня репозиторію:  python3 scripts/check_docs.py
Код виходу: 0 — помилок немає; 1 — є помилки (ERR). Попередження (WARN) не блокують.

Перевіряє те, що ламалося повторно (RELEASE_PLAN §154, DECISIONS_REGISTER):
  1. CLAUDE.md: пункти закритих рішень пронумеровані послідовно й без дублів; «п. 1–N» = останньому пункту.
  2. RELEASE_PLAN.md: номери розділів унікальні.
  3. Версія й кількість вузлів у workflows/DEMO_Archi_Agent_Core.json = README.md (шапка) і NODE_MAP.md (шапка).
  4. docs/README.md (індекс) = фактичний перелік docs/*.md.
  5. Посилання `docs/…`, `sql/…`, `scripts/…`, `workflows/…`, `tests/…` у документах ведуть на наявні файли.
  6. DECISIONS_REGISTER.md містить усі пункти CLAUDE.md.
  7. ROADMAP_TO_RELEASE.md: кожен OD-N / W-N.N, на який є посилання, визначений у таблиці.
  8. Літерал токена Telegram-бота у файлах = 0.
"""
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
errs, warns = [], []


def err(m):
    errs.append(m)


def warn(m):
    warns.append(m)


def read(p):
    return (ROOT / p).read_text(encoding="utf8")


# ---------- 1. CLAUDE.md
claude = read("CLAUDE.md")
head = claude.split("\n---\n", 1)[0]
nums = [int(m.group(1)) for m in re.finditer(r"^(\d+)\. \*\*", head, re.M)]
if nums != list(range(1, len(nums) + 1)):
    dup = sorted({n for n in nums if nums.count(n) > 1})
    err(f"CLAUDE.md: нумерація пунктів не послідовна: {nums} (дублі: {dup})")
last = nums[-1] if nums else 0
for m in re.finditer(r"п\. 1[–-](\d+)", claude):
    if int(m.group(1)) != last:
        err(f"CLAUDE.md: посилання «п. 1–{m.group(1)}» не збігається з останнім пунктом {last}")

# ---------- 2. RELEASE_PLAN
rp = read("docs/RELEASE_PLAN.md")
secs = [int(x) for x in re.findall(r"^## (\d+)\.", rp, re.M)]
dups = sorted({n for n in secs if secs.count(n) > 1})
if dups:
    err(f"RELEASE_PLAN.md: дублі номерів розділів: {dups}")

# ---------- 3. Версія й кількість вузлів
wf = json.loads(read("workflows/DEMO_Archi_Agent_Core.json"))
wf = wf.get("workflow", wf)
vid, n_nodes = wf.get("versionId", ""), len(wf["nodes"])
for f, lines in (("README.md", 45), ("docs/NODE_MAP.md", 6)):
    top = "\n".join(read(f).split("\n")[:lines])
    if vid[:8] not in top:
        err(f"{f}: у шапці немає versionId {vid[:8]}… з workflows/DEMO_Archi_Agent_Core.json")
    if not (re.search(rf"\b{n_nodes}\s+(вузл|нод)", top) or re.search(rf"вузл\w*:?\s*{n_nodes}\b", top)):
        err(f"{f}: у шапці немає кількості вузлів {n_nodes}")

# ---------- 4. Індекс документів
docs = sorted(p.name for p in (ROOT / "docs").glob("*.md") if p.name != "README.md")
idx_path = ROOT / "docs" / "README.md"
if not idx_path.exists():
    err("docs/README.md (індекс документів) відсутній")
else:
    idx = idx_path.read_text(encoding="utf8")
    listed = set(re.findall(r"`([A-Za-z0-9_.\-]+\.md)`", idx))
    for d in docs:
        if d not in listed:
            err(f"docs/README.md: файл docs/{d} не внесений в індекс")
    for l in sorted(listed):
        if l not in docs and not (ROOT / "docs" / "archive" / l).exists() and not (ROOT / l).exists():
            err(f"docs/README.md: у індексі згадано {l}, якого немає")

# ---------- 5. Посилання на файли
PATH_RE = re.compile(r"`((?:docs|sql|scripts|workflows|tests)/[A-Za-z0-9_./\-]+\.[A-Za-z0-9]+)`")
PLANNED = {
    "docs/DEMO_RUNSHEET_2026-11-03.md": "створюється в сесії С2 (START_PROMPT_DEMO_AND_CLOSE)",
    "docs/ARCHI_FEATURES_v1.md": "запланований, не створений (ROADMAP W0.5)",
}
JOURNAL = ("docs/RELEASE_PLAN.md", "docs/DOC_AUDIT_", "docs/CTO_CHECKPOINT_")  # журнали: історичні посилання допустимі
md_files = [p for p in ROOT.rglob("*.md") if ".git" not in p.parts and "archive" not in p.parts]
for p in md_files:
    rel = p.relative_to(ROOT).as_posix()
    if rel.startswith(JOURNAL):
        continue
    for m in PATH_RE.finditer(p.read_text(encoding="utf8")):
        ref = m.group(1)
        if "*" in ref or "<" in ref or "…" in ref or "0X" in ref or ref in PLANNED:
            continue
        if not (ROOT / ref).exists():
            if (ROOT / "docs" / "archive" / Path(ref).name).exists():
                warn(f"{rel}: «{ref}» переміщено в docs/archive/")
            else:
                err(f"{rel}: посилання на неіснуючий файл «{ref}»")

# ---------- 6. Реєстр рішень
if (ROOT / "docs" / "DECISIONS_REGISTER.md").exists():
    reg = read("docs/DECISIONS_REGISTER.md")
    secA = reg.split("## B.", 1)[0]
    reg_nums = sorted(int(x) for x in re.findall(r"^\| (\d+) \|", secA, re.M))
    if reg_nums != list(range(1, last + 1)):
        err(f"DECISIONS_REGISTER.md: розділ A охоплює пункти {reg_nums}, у CLAUDE.md їх 1–{last}")
else:
    err("docs/DECISIONS_REGISTER.md відсутній")

# ---------- 7. Карта
rm = read("docs/ROADMAP_TO_RELEASE.md")
defd_od = set(re.findall(r"^\| (OD-\d+) \|", rm, re.M))
used_od = set(re.findall(r"\bOD-\d+\b", rm))
for o in sorted(used_od - defd_od, key=lambda x: int(x[3:])):
    err(f"ROADMAP_TO_RELEASE.md: {o} згадано, але не визначено в таблиці рішень")
defd_w = set(re.findall(r"^\| (W\d+\.\d+) ", rm, re.M))
used_w = set(re.findall(r"\bW\d+\.\d+\b", rm))
for w in sorted(used_w - defd_w):
    err(f"ROADMAP_TO_RELEASE.md: {w} згадано, але не визначено як пункт потоку")
all_ids = re.findall(r"^\| (W\d+\.\d+) ", rm, re.M)
for w in sorted({x for x in all_ids if all_ids.count(x) > 1}):
    err(f"ROADMAP_TO_RELEASE.md: дубль пункту {w}")

# ---------- 8. Токен
TOKEN = re.compile(r"[0-9]{8,}:AA[A-Za-z0-9_-]{30,}")
tracked = subprocess.run(["git", "ls-files"], cwd=ROOT, capture_output=True, text=True).stdout.split("\n")
for f in tracked:
    if not f or f.endswith((".png", ".jpg", ".pyc", ".xlsx")):
        continue
    try:
        if TOKEN.search((ROOT / f).read_text(encoding="utf8", errors="ignore")):
            err(f"{f}: знайдено літерал токена Telegram-бота")
    except (FileNotFoundError, IsADirectoryError):
        pass

# ---------- підсумок
for w in warns:
    print("WARN", w)
for e in errs:
    print("ERR ", e)
print(f"\nПідсумок: помилок {len(errs)}, попереджень {len(warns)}; пунктів CLAUDE.md {last}; розділів RELEASE_PLAN {len(set(secs))}; "
      f"вузлів core {n_nodes} ({vid[:8]}); документів у docs/ {len(docs)}")
sys.exit(1 if errs else 0)
