"""Render the Courier logo in the same style as Pa_nts' other addon logos:
dark rounded tile, light grey border, flat gold + cream icon with dark outlines.

Usage: python make_logo.py <out_dir>
"""
import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw

S = 1600  # draw big, downsample for smooth edges
out_dir = Path(sys.argv[1])
out_dir.mkdir(parents=True, exist_ok=True)

# Palette sampled from the reference logos
TILE_DARK = (13, 13, 13, 255)
TILE_LIGHT = (20, 20, 23, 255)
BORDER = (153, 153, 153, 255)
BORDER_INNER = (116, 116, 116, 255)
GOLD = (255, 209, 0, 255)
GOLD_DARK = (214, 150, 0, 255)
CREAM = (254, 252, 214, 255)
CREAM_SHADE = (200, 186, 156, 255)
OUTLINE = (58, 40, 34, 255)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(len(a)))


img = Image.new("RGBA", (S, S), (0, 0, 0, 0))

# --- Tile: dark fill with a subtle top-to-bottom gradient, grey border ----------
radius = int(S * 0.10)
grad = Image.new("RGBA", (S, S))
gd = ImageDraw.Draw(grad)
for y in range(S):
    gd.line([(0, y), (S, y)], fill=lerp(TILE_LIGHT, TILE_DARK, y / S))
mask = Image.new("L", (S, S), 0)
ImageDraw.Draw(mask).rounded_rectangle([0, 0, S - 1, S - 1], radius=radius, fill=255)
img.paste(grad, (0, 0), mask)

d = ImageDraw.Draw(img)
bw = int(S * 0.036)
d.rounded_rectangle([0, 0, S - 1, S - 1], radius=radius, outline=BORDER, width=bw)
d.rounded_rectangle([bw, bw, S - 1 - bw, S - 1 - bw], radius=radius - bw, outline=BORDER_INNER, width=int(S * 0.008))

# --- Envelope: cream, shaded toward the edges like the book pages ---------------
ex0, ey0, ex1, ey1 = int(S * 0.20), int(S * 0.43), int(S * 0.80), int(S * 0.80)
env = Image.new("RGBA", (S, S), (0, 0, 0, 0))
ep = env.load()
cx, cy = (ex0 + ex1) / 2, (ey0 + ey1) / 2
hw, hh = (ex1 - ex0) / 2, (ey1 - ey0) / 2
for y in range(ey0, ey1):
    for x in range(ex0, ex1):
        t = max(abs(x - cx) / hw, abs(y - cy) / hh)
        ep[x, y] = lerp(CREAM, CREAM_SHADE, max(0.0, (t - 0.55) / 0.45) ** 1.6)
emask = Image.new("L", (S, S), 0)
ImageDraw.Draw(emask).rounded_rectangle([ex0, ey0, ex1, ey1], radius=int(S * 0.025), fill=255)
img.paste(env, (0, 0), emask)

d = ImageDraw.Draw(img)
ow = int(S * 0.016)
mx = (ex0 + ex1) // 2
# top flap
d.line([(ex0 + ow, ey0 + ow), (mx, ey0 + int((ey1 - ey0) * 0.58)), (ex1 - ow, ey0 + ow)], fill=OUTLINE, width=ow, joint="curve")
# outline
d.rounded_rectangle([ex0, ey0, ex1, ey1], radius=int(S * 0.025), outline=OUTLINE, width=ow)

# --- Gold contact badge above the envelope (like the coin on the book logo) ------
bx, by, br = S // 2, int(S * 0.30), int(S * 0.125)
d.ellipse([bx - br - ow, by - br - ow, bx + br + ow, by + br + ow], fill=OUTLINE)
d.ellipse([bx - br, by - br, bx + br, by + br], fill=GOLD)
ring = int(br * 0.74)
d.ellipse([bx - ring, by - ring, bx + ring, by + ring], outline=GOLD_DARK, width=int(S * 0.014))
# person silhouette
hr = br * 0.22
d.ellipse([bx - hr, by - br * 0.40 - hr, bx + hr, by - br * 0.40 + hr], fill=GOLD_DARK)
d.chord([bx - br * 0.44, by - br * 0.06, bx + br * 0.44, by + br * 0.78], 180, 360, fill=GOLD_DARK)

# --- Export ---------------------------------------------------------------------
for size in (400, 800):
    img.resize((size, size), Image.LANCZOS).save(out_dir / f"logo-{size}.png")
print("ok")
