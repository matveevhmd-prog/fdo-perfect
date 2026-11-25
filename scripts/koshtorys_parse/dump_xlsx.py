# Вивантаження листів Кошториса в JSON у форматі Google Sheets API (UNFORMATTED_VALUE): порожні клітинки всередині — '', хвостові порожні відсікаються.
# Використання: python3 -I dump_xlsx.py <xlsx> <out.json>
import sys, json, datetime, openpyxl
def ser(v):
    if isinstance(v, datetime.datetime): v = v.date()
    if isinstance(v, datetime.date): return (v - datetime.date(1899, 12, 30)).days
    return v
def grid(ws, max_row, max_col):
    rows = []
    for r in ws.iter_rows(min_row=1, max_row=max_row, max_col=max_col, values_only=True):
        row = [('' if v is None else ser(v)) for v in r]
        while row and row[-1] == '': row.pop()
        rows.append(row)
    while rows and not rows[-1]: rows.pop()
    return rows
wb = openpyxl.load_workbook(sys.argv[1], data_only=True)
out = {}
for ws in wb:
    if ws.title.startswith('DEMO-') and ws.title.endswith('-АН'): out[ws.title] = grid(ws, 11, 2)
    elif ws.title.startswith('DEMO-'): out[ws.title] = grid(ws, 300, 24)
    elif ws.title == 'Графік_оплат': out[ws.title] = grid(ws, 2000, 14)
json.dump(out, open(sys.argv[2], 'w'), ensure_ascii=False)
print({k: len(v) for k, v in out.items()})
