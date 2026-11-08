# Hand-painted status icon: one big glossy blood drop on black (SD kept drawing spheres/scenery).
# usage: python tools/sprite_edits/status_sangrado_drop.py  -> assets/status/sangrado.png (+ metadata)
import json, math
from datetime import datetime, timezone
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
K, N = 8, 64                      # draw at 8x, output 64 px
S = N * K
img = Image.new("RGBA", (S, S), (8, 6, 6, 255))
# teardrop: circle at the bottom + point at the top
cx, cy, r = S * 0.5, S * 0.62, S * 0.28
top = (cx, S * 0.08)
shape = Image.new("L", (S, S), 0); d = ImageDraw.Draw(shape)
d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=255)
# tangent lines from the tip to the circle
dist = cy - top[1]; a = math.asin(r / dist)
for sgn in (-1, 1):
    tx = cx + sgn * r * math.cos(a); ty = cy - r * math.sin(a)
    d.polygon([top, (tx, ty), (cx, cy)], fill=255)
# body colour: dark crimson with a vertical gradient
body = Image.new("RGBA", (S, S))
for y in range(S):
    t = y / S
    col = (int(150 - 70 * t), int(10 + 4 * (1 - t)), int(14 + 6 * (1 - t)), 255)
    ImageDraw.Draw(body).line([(0, y), (S, y)], fill=col)
img.paste(body, (0, 0), shape)
# rim shadow on the right, glossy highlights on the left
sh = Image.new("L", (S, S), 0); ImageDraw.Draw(sh).ellipse([cx - r * 0.35, cy - r * 1.05, cx + r * 1.25, cy + r * 1.0], fill=150)
sh = Image.composite(sh, Image.new("L", (S, S), 0), shape).filter(ImageFilter.GaussianBlur(K * 2))
img.paste(Image.new("RGBA", (S, S), (25, 0, 2, 255)), (0, 0), sh)
hl = Image.new("L", (S, S), 0); d2 = ImageDraw.Draw(hl)
d2.ellipse([cx - r * 0.62, cy - r * 0.55, cx - r * 0.18, cy + r * 0.05], fill=210)
d2.ellipse([cx - r * 0.18, S * 0.28, cx - r * 0.02, S * 0.40], fill=150)
hl = hl.filter(ImageFilter.GaussianBlur(K * 1.2))
img.paste(Image.new("RGBA", (S, S), (255, 205, 200, 255)), (0, 0), hl)
# soft red glow behind the drop
glow = shape.filter(ImageFilter.GaussianBlur(K * 4)).point(lambda v: int(v * 0.35))
base = Image.new("RGBA", (S, S), (8, 6, 6, 255)); base.paste(Image.new("RGBA", (S, S), (90, 0, 4, 255)), (0, 0), glow)
base.paste(img, (0, 0), shape.filter(ImageFilter.GaussianBlur(K * 0.4)))
out = base.resize((N, N), Image.LANCZOS)
p = ROOT / "assets/status/sangrado.png"
out.save(p)
p.with_suffix(".metadata.json").write_text(json.dumps({
    "id": "status_sangrado", "generator": "tools/sprite_edits/status_sangrado_drop.py (hand-painted with PIL, no model)",
    "note": "Stable Diffusion attempts (seeds 6401-6406) produced spheres, faces and buildings; owner asked for a big drop of blood.",
    "resolution": f"{S}x{S} drawn, downsampled to {N}x{N}",
    "timestamp": datetime.now(timezone.utc).isoformat(timespec="seconds"),
}, indent=2) + "\n", encoding="utf-8")
print(p)
