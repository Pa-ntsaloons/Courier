"""Render the Courier logo. Usage: python make_logo.py <out_dir>"""
import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

S = 1600  # draw big, downsample for smooth edges
out_dir = Path(sys.argv[1])
out_dir.mkdir(parents=True, exist_ok=True)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(len(a)))


# --- Background: radial gradient, deep navy -> near black ---------------------
bg = Image.new("RGBA", (S, S))
px = bg.load()
c_in, c_out = (38, 52, 96, 255), (8, 10, 22, 255)
cx = cy = S / 2
maxd = math.hypot(cx, cy)
for y in range(S):
    for x in range(S):
        t = min(1.0, math.hypot(x - cx, y - cy * 0.85) / (maxd * 0.85))
        px[x, y] = lerp(c_in, c_out, t ** 1.3)

# Rounded-square mask
mask = Image.new("L", (S, S), 0)
ImageDraw.Draw(mask).rounded_rectangle([0, 0, S - 1, S - 1], radius=int(S * 0.16), fill=255)

img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
img.paste(bg, (0, 0), mask)
d = ImageDraw.Draw(img)

# --- Gold double border --------------------------------------------------------
gold, gold_dark = (232, 186, 84, 255), (140, 98, 30, 255)
inset = int(S * 0.035)
d.rounded_rectangle([inset, inset, S - inset, S - inset], radius=int(S * 0.13), outline=gold_dark, width=int(S * 0.028))
d.rounded_rectangle([inset, inset, S - inset, S - inset], radius=int(S * 0.13), outline=gold, width=int(S * 0.014))

# --- Speed lines (courier = fast delivery) ------------------------------------
for i, (y, length) in enumerate([(0.44, 0.08), (0.53, 0.11), (0.62, 0.07)]):
    yy = int(S * y)
    x1 = int(S * 0.205)
    d.rounded_rectangle([x1 - int(S * length), yy - int(S * 0.012), x1, yy + int(S * 0.012)],
                        radius=int(S * 0.012), fill=(232, 186, 84, 170))

# --- Envelope -------------------------------------------------------------------
ex0, ey0, ex1, ey1 = int(S * 0.24), int(S * 0.32), int(S * 0.84), int(S * 0.72)
shadow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
ImageDraw.Draw(shadow).rounded_rectangle([ex0 + 18, ey0 + 30, ex1 + 18, ey1 + 30], radius=30, fill=(0, 0, 0, 150))
shadow = shadow.filter(ImageFilter.GaussianBlur(28))
img.alpha_composite(shadow)
d = ImageDraw.Draw(img)

parch, parch_dark, edge = (244, 226, 184, 255), (214, 186, 132, 255), (120, 84, 40, 255)
d.rounded_rectangle([ex0, ey0, ex1, ey1], radius=30, fill=parch, outline=edge, width=10)
mx = (ex0 + ex1) // 2
# lower side folds
d.polygon([(ex0 + 8, ey1 - 8), (mx, ey0 + int((ey1 - ey0) * 0.55)), (ex1 - 8, ey1 - 8)], fill=parch_dark)
d.line([(ex0 + 8, ey1 - 8), (mx, ey0 + int((ey1 - ey0) * 0.55)), (ex1 - 8, ey1 - 8)], fill=edge, width=8)
# top flap
flap_tip = (mx, ey0 + int((ey1 - ey0) * 0.62))
d.polygon([(ex0 + 6, ey0 + 6), flap_tip, (ex1 - 6, ey0 + 6)], fill=(236, 214, 166, 255))
d.line([(ex0 + 6, ey0 + 6), flap_tip, (ex1 - 6, ey0 + 6)], fill=edge, width=10, joint="curve")

# --- Wax seal with a contact silhouette ---------------------------------------
sx, sy, r = flap_tip[0], flap_tip[1] - int(S * 0.01), int(S * 0.115)
# irregular wax blob
blob = []
for k in range(36):
    a = 2 * math.pi * k / 36
    rr = r * (1.0 + 0.06 * math.sin(a * 5) + 0.03 * math.cos(a * 9))
    blob.append((sx + rr * math.cos(a), sy + rr * math.sin(a)))
d.polygon(blob, fill=(150, 22, 28, 255))
d.ellipse([sx - r * 0.80, sy - r * 0.80, sx + r * 0.80, sy + r * 0.80], fill=(186, 34, 40, 255))
d.ellipse([sx - r * 0.80, sy - r * 0.80, sx + r * 0.80, sy + r * 0.80], outline=(120, 14, 20, 255), width=8)
# highlight
d.arc([sx - r * 0.66, sy - r * 0.66, sx + r * 0.66, sy + r * 0.66], 200, 290, fill=(236, 110, 110, 200), width=10)
# person silhouette (head + shoulders) in gold
hr = r * 0.20
d.ellipse([sx - hr, sy - r * 0.46 - hr, sx + hr, sy - r * 0.46 + hr], fill=gold)
d.chord([sx - r * 0.42, sy - r * 0.12, sx + r * 0.42, sy + r * 0.70], 180, 360, fill=gold)

# --- Export ---------------------------------------------------------------------
for size in (400, 800):
    img.resize((size, size), Image.LANCZOS).save(out_dir / f"logo-{size}.png")
print("ok")
