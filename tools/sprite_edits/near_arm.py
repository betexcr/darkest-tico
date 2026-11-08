# Repaint a raised FAR arm as the NEAR (right) arm: a new upper arm from the near shoulder,
# across the chest, to the raised forearm. Sleeve texture is cloned from the raised sleeve.
# usage: near_arm.py <src.png> <out.png> '<json>'
#   json: {"p0":[x,y] (sleeve near the hand), "p1":[x,y] (sleeve toward its root),
#          "q0":[x,y] (near shoulder), "q1":[x,y] (where the new upper arm meets the forearm),
#          "width":22, "erase":[[[x,y],...], ...] (polygons to make transparent)}
import json, math, sys
from PIL import Image, ImageDraw, ImageFilter
import numpy as np
src, out, cfg = sys.argv[1], sys.argv[2], json.loads(sys.argv[3])
im = Image.open(src).convert("RGBA")
a = np.array(im)
for poly in cfg.get("erase", []):
    m = Image.new("L", im.size, 0); ImageDraw.Draw(m).polygon([tuple(p) for p in poly], fill=255)
    a[np.array(m) > 0, 3] = 0
base = Image.fromarray(a)
wd = int(cfg.get("width", 22))
p0, p1 = cfg.get("tp0", cfg["p0"]), cfg.get("tp1", cfg["p1"])   # texture source line (default: the raised sleeve)
L = math.hypot(p1[0] - p0[0], p1[1] - p0[1]); ang = math.degrees(math.atan2(p1[1] - p0[1], p1[0] - p0[0]))
rot = im.rotate(ang, center=tuple(p0), resample=Image.BICUBIC)
strip = rot.crop((p0[0], p0[1] - wd // 2, p0[0] + int(L), p0[1] + wd // 2))
q0, q1 = cfg["q0"], cfg["q1"]
Lq = math.hypot(q1[0] - q0[0], q1[1] - q0[1]); angq = math.degrees(math.atan2(q1[1] - q0[1], q1[0] - q0[0]))
st = strip.resize((int(Lq) + 6, wd), Image.BICUBIC)
canvas = Image.new("RGBA", im.size, (0, 0, 0, 0)); canvas.paste(st, (q0[0], q0[1] - wd // 2))
canvas = canvas.rotate(-angq, center=tuple(q0), resample=Image.BICUBIC)
mask = Image.new("L", im.size, 0); ImageDraw.Draw(mask).line([tuple(q0), tuple(q1)], fill=255, width=wd)
mask = mask.filter(ImageFilter.GaussianBlur(2))
ca = np.array(canvas); ca[:, :, 3] = np.minimum(ca[:, :, 3], np.array(mask))
if cfg.get("fill"):   # flat sleeve colour with a highlight down the middle (the blend pass adds the detail)
    r, g, b = cfg["fill"]
    yy, xx = np.mgrid[0:im.size[1], 0:im.size[0]]
    nx0, ny0 = -(q1[1] - q0[1]) / Lq, (q1[0] - q0[0]) / Lq
    dist = np.abs((xx - q0[0]) * nx0 + (yy - q0[1]) * ny0) / (wd / 2)
    shade = np.clip(1.25 - 0.75 * dist, 0.45, 1.25)
    ca[:, :, 0] = np.clip(r * shade, 0, 255); ca[:, :, 1] = np.clip(g * shade, 0, 255); ca[:, :, 2] = np.clip(b * shade, 0, 255)
    ca[:, :, 3] = np.array(mask)
res = base.copy(); res.alpha_composite(Image.fromarray(ca))
if cfg.get("outline", True):   # dark edges so the arm reads as a separate limb in front of the torso
    d = ImageDraw.Draw(res)
    nx, ny = -(q1[1] - q0[1]) / Lq, (q1[0] - q0[0]) / Lq
    for sgn in (-1, 1):
        off = sgn * (wd / 2 - 1)
        d.line([(q0[0] + nx * off, q0[1] + ny * off), (q1[0] + nx * off, q1[1] + ny * off)], fill=(20, 18, 16, 255), width=2)
res.save(out)
