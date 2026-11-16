#!/usr/bin/env python3
"""scripts/kitchen_data.py（食材の牌・料理の役）を App/Sources/Model/Kitchen.swift に書き出す。
使い方: python3 scripts/build-kitchen.py [--check]
- 料理の食材の組み合わせが重ならないこと、食材の名前が正しいことを確かめる
"""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from kitchen_data import INGREDIENTS, BASE, PRO

ids = [i[0] for i in INGREDIENTS]
seen = {}
for r in BASE + PRO:
    assert len(set(r[4])) == 3, r[0]
    for x in r[4]:
        assert x in ids, (r[0], x)
    key = frozenset(r[4])
    assert key not in seen, f"{r[0]} と {seen.get(key)} の食材が同じ"
    seen[key] = r[0]
assert len({r[0] for r in BASE + PRO}) == len(BASE + PRO)


def s(x):
    return '"' + x.replace('\\', '\\\\').replace('"', '\\"') + '"'


lines = [
    "// このファイルは scripts/build-kitchen.py が scripts/kitchen_data.py から作る。手で直さない。",
    "",
    "extension Kitchen {",
    "    static let ingredients: [Ingredient] = [",
]
for i, (iid, glyph, ja, en, cat) in enumerate(INGREDIENTS):
    lines.append(f"        Ingredient(index: {i}, id: {s(iid)}, glyph: {s(glyph)}, nameJa: {s(ja)}, nameEn: {s(en)}, category: .{cat}),")
lines += ["    ]", "", "    static let recipes: [Recipe] = ["]
for n, r in enumerate(BASE + PRO):
    rid, ja, en, cui, parts, soup, hja, hen = r
    pro = n >= len(BASE)
    p = ", ".join(str(ids.index(x)) for x in sorted(parts, key=ids.index))
    lines.append(
        f"        Recipe(index: {n}, id: {s(rid)}, nameJa: {s(ja)}, nameEn: {s(en)}, cuisine: .{cui}, parts: [{p}], "
        f"soup: {'true' if soup else 'false'}, pro: {'true' if pro else 'false'}, howJa: {s(hja)}, howEn: {s(hen)}),")
lines += ["    ]", "}", ""]
out = "\n".join(lines)
path = Path(__file__).resolve().parent.parent / "App/Sources/Model/Kitchen.swift"
if "--check" in sys.argv:
    if not path.exists() or path.read_text(encoding="utf-8") != out:
        print("Kitchen.swift が最新ではありません: python3 scripts/build-kitchen.py")
        sys.exit(1)
    print(f"ok: 食材 {len(INGREDIENTS)}・料理 {len(BASE)}＋Pro {len(PRO)}")
    sys.exit(0)
path.write_text(out, encoding="utf-8")
print(f"書き出しました: 食材 {len(INGREDIENTS)}・料理 {len(BASE)}＋Pro {len(PRO)}")
