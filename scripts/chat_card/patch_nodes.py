#!/usr/bin/env python3
"""П2b: будує нові jsCode для Build Request Body і Sanitize Reply з експорту workflow + шматків цієї папки.
Використання: patch_nodes.py <in_workflow.json> <out_dir>  → out_dir/{Build_Request_Body,Sanitize_Reply}.js"""
import json, sys, os
here = os.path.dirname(os.path.abspath(__file__))
wf = json.load(open(sys.argv[1])); out = sys.argv[2]; os.makedirs(out, exist_ok=True)
code = {n['name']: n['parameters']['jsCode'] for n in wf['nodes'] if 'jsCode' in n['parameters']}
brb = code['Build Request Body']; san = code['Sanitize Reply']
def rep(s, old, new):
    assert s.count(old) == 1, ('anchor count', s.count(old), old[:60])
    return s.replace(old, new)
cards = open(os.path.join(here, 'brb_cards.js')).read()
# 1. блок збірки картки — перед визначенням system
brb = rep(brb, "const LAYOUT = 'ВЕРСТКА", cards + "\nconst LAYOUT = 'ВЕРСТКА")
# playbook треба підмінити ПІСЛЯ блоку cards: додаємо перед const system
brb = rep(brb, "const system = 'Ти — стратегічний", "if (CARD_MODE) playbook = CARD_JSON_PLAYBOOK;\nconst system = 'Ти — стратегічний")
# 3. вихід
brb = rep(brb, "return [{ json: { body: body, chat_id: $('Telegram Trigger').item.json.message.chat.id, icons: icons } }];",
          "return [{ json: { body: body, chat_id: $('Telegram Trigger').item.json.message.chat.id, icons: icons, cardData: CARD_DATA } }];")
# B-15: слово «код» у заголовках фокусу Q3/Q4/Q5
brb = rep(brb, "(зібрав код з «Прохання ПМа», блокерів і відсутніх прогнозів)", "(зі звітів ПМа: прохання, блокери, відсутні прогнози)")
brb = rep(brb, "Не оплачено (код): ", "Не оплачено: ")
brb = rep(brb, "що відомо (код): ", "що відомо: ")
brb = rep(brb, "кожен пункт: проєкт, що вирішити, чия це вимога.", "кожен пункт: проєкт, що вирішити, чия це вимога (ПМ чи блокер проєкту); слово «код» не вживати.")
# Sanitize Reply
cs = open(os.path.join(here, 'sanitize_card.js')).read()
san = rep(san, "let t = validateReply(raw);", cs + "\nlet cardD = null; try { cardD = $('Build Request Body').first().json.cardData || null; } catch (e) { cardD = null; }\nlet t = cardD ? composeCard(cardD, raw) : validateReply(raw);")
open(os.path.join(out, 'Build_Request_Body.js'), 'w').write(brb)
open(os.path.join(out, 'Sanitize_Reply.js'), 'w').write(san)
print('ok', len(brb), len(san))
