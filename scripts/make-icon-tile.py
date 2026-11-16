#!/usr/bin/env python3
"""献立マージャンのアイコン：赤い漆の地に金の縁、象牙の牌（翡翠の背）に「膳」、牌の上に湯気。1024×1024・透過なし。"""
import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

S = 1024
OUT = os.path.join(os.path.dirname(__file__), "..", "App", "Resources", "Assets.xcassets", "AppIcon.appiconset", "AppIcon.png")
img = Image.new("RGB", (S, S), (126, 19, 17))
d = ImageDraw.Draw(img)
# 地：上が明るい赤のグラデーション
for y in range(S):
    t = y / S
    r = int(196 * (1 - t) + 110 * t); g = int(40 * (1 - t) + 16 * t); b = int(32 * (1 - t) + 14 * t)
    d.line([(0, y), (S, y)], fill=(r, g, b))
# 金の二重の縁
d.rounded_rectangle([40, 40, S - 40, S - 40], radius=120, outline=(229, 182, 81), width=18)
d.rounded_rectangle([78, 78, S - 78, S - 78], radius=90, outline=(229, 182, 81), width=6)
# 牌の影
tile = Image.new("RGBA", (S, S), (0, 0, 0, 0))
td = ImageDraw.Draw(tile)
x0, y0, w, h = 302, 300, 420, 560
td.rounded_rectangle([x0 + 10, y0 + 40, x0 + w + 10, y0 + h + 40], radius=60, fill=(0, 0, 0, 110))
tile = tile.filter(ImageFilter.GaussianBlur(18))
img.paste(tile, (0, 0), tile)
d = ImageDraw.Draw(img)
# 翡翠の背（厚み）
d.rounded_rectangle([x0, y0 + 46, x0 + w, y0 + h + 46], radius=60, fill=(30, 94, 67))
# 象牙の面
d.rounded_rectangle([x0, y0, x0 + w, y0 + h], radius=60, fill=(248, 242, 227))
d.rounded_rectangle([x0 + 26, y0 + 26, x0 + w - 26, y0 + h - 26], radius=40, outline=(226, 214, 188), width=8)
font = ImageFont.truetype("/usr/share/fonts/truetype/wqy/wqy-zenhei.ttc", 330)
text = "膳"
bbox = d.textbbox((0, 0), text, font=font)
tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
tx = x0 + (w - tw) / 2 - bbox[0]; ty = y0 + (h - th) / 2 - bbox[1]
d.text((tx, ty + 6), text, font=font, fill=(255, 255, 255))
d.text((tx, ty), text, font=font, fill=(192, 50, 42))
# 湯気（3 本の S 字）
for i, cx in enumerate([432, 512, 592]):
    pts = []
    for k in range(40):
        t = k / 39
        yy = 250 - t * 170
        xx = cx + 26 * __import__("math").sin(t * 6.28 + i)
        pts.append((xx, yy))
    d.line(pts, fill=(255, 245, 225), width=22, joint="curve")
img.save(OUT, "PNG")
print("wrote", OUT, img.size, img.mode)
