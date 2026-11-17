#!/usr/bin/env python3
"""
Paints the town view as ONE picture (P4-19, owner 2026-11-17: "make the buildings make
sense together, not a collage").

  1. Lays out the scene from data/town.json in its 1280x720 design space: the backdrop,
     a dirt plaza and road, the unclickable `filler` houses, then the buildings back to
     front (cut-outs from tools/sd_cutout.py), each with a contact shadow.
  2. Repaints the whole layout with Stable Diffusion img2img (same model and style as
     tools/sd_local.py) so light, fog, perspective and brushwork are shared. `strength`
     keeps the buildings where the layout put them.
  3. Cuts each building back out of the painted town with its own cut-out's alpha:
     assets/town/painted/<id>.png. The game draws town_painted.png as the town and those
     crops on top, so hover and clicks still know exactly where each building is.

Setup: same venv as tools/sd_local.py. Usage (from repo root):
  python tools/town_paint.py                       # writes assets/town/town_painted.png + painted/*.png
  python tools/town_paint.py --preview-dir DIR --strengths 0.45 0.6   # candidates only
Every PNG gets a .metadata.json. Game code never calls this.
"""

from __future__ import annotations

import argparse
import json
import time
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TOWN = ROOT / "data" / "town.json"
MANIFEST = ROOT / "tools" / "art_manifest.json"
OUT = ROOT / "assets" / "town" / "town_painted.png"
CROPS = ROOT / "assets" / "town" / "painted"
PROMPT = (
    "dark fantasy painting, a small rural Costa Rican village plaza at night, adobe and wooden houses "
    "with clay tile roofs around a dirt square, white colonial church, warm lamplight, fog, volcano behind, "
    "dark gothic oil painting, folk horror, deep black shadows, muted earthy colors, painterly brushstrokes, game art"
)
SEED = 5300
STRENGTH = 0.7
## ControlNet (canny edges of the layout) keeps every building where the layout put it even
## at a strength high enough to repaint the town as one scene. openrail licence, native diffusers.
CONTROLNET = "lllyasviel/sd-controlnet-canny"
CONTROL_SCALE = 0.8


def res(p: str) -> Path:
    return ROOT / p.replace("res://", "")


def place(img, x: float, bottom: float, height: float):
    """Scaled image and its top-left, the same math as hacienda_hub.gd _layout_town (k = 1)."""
    from PIL import Image

    w = height * img.width / max(img.height, 1)
    sized = img.resize((max(1, round(w)), max(1, round(height))), Image.LANCZOS)
    return sized, (round(x - w / 2.0), round(bottom - height))


def compose(town: dict):
    from PIL import Image, ImageDraw, ImageEnhance, ImageFilter

    W, H = town["design_size"]
    canvas = Image.open(res(town["background"])).convert("RGBA").resize((W, H), Image.LANCZOS)
    # Earth under the town (not fog, or the buildings float), with a lighter dirt road and
    # some grain so the painter reads it as ground.
    import random

    top = int(town.get("ground_top", 330))
    ground = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gd = ImageDraw.Draw(ground)
    for y in range(top, H):
        t = (y - top) / max(H - top, 1)
        gd.line([(0, y), (W, y)], fill=(40 + int(20 * t), 29 + int(12 * t), 22 + int(8 * t), int(min(1.0, t * 3.0) * 255)))
    rnd = random.Random(7)
    for _ in range(2200):
        x, y = rnd.randrange(W), rnd.randrange(top + 30, H)
        c = rnd.randrange(-14, 14)
        gd.ellipse([x, y, x + rnd.randrange(2, 7), y + rnd.randrange(1, 3)], fill=(58 + c, 43 + c, 33 + c, 200))
    road = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(road).polygon([(400, 410), (540, 410), (720, H), (210, H)], fill=(105, 82, 60, 150))
    ground.alpha_composite(road.filter(ImageFilter.GaussianBlur(14)))
    canvas.alpha_composite(ground)
    rows = []
    for f in town.get("filler", []):
        rows.append((f, False))
    for b in town["buildings"]:
        rows.append((b, True))
    rows.sort(key=lambda r: float(r[0]["bottom"]))
    placed = {}
    for row, is_building in rows:
        img = Image.open(res(row["art"])).convert("RGBA")
        sized, (px, py) = place(img, float(row["x"]), float(row["bottom"]), float(row["height"]))
        if not is_building:
            # Fillers sit back in the dark so the eye goes to the real buildings.
            rgb = ImageEnhance.Brightness(sized.convert("RGB")).enhance(0.55)
            rgb.putalpha(sized.getchannel("A"))
            sized = rgb
        # Contact shadow so it stands on the ground.
        sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        bw = sized.width
        ImageDraw.Draw(sh).ellipse([px - bw * 0.05, py + sized.height - 14, px + bw * 1.05, py + sized.height + 14], fill=(0, 0, 0, 170))
        canvas.alpha_composite(sh.filter(ImageFilter.GaussianBlur(8)))
        canvas.alpha_composite(sized, (px, py))
        if is_building:
            placed[row["id"]] = (px, py, sized.getchannel("A"))
    return canvas.convert("RGB"), placed


def edges(layout):
    import cv2
    import numpy as np
    from PIL import Image

    e = cv2.Canny(np.asarray(layout.convert("L")), 60, 160)
    return Image.fromarray(np.stack([e, e, e], axis=-1))


def paint(layout, strength: float, seed: int, manifest: dict, control_scale: float = CONTROL_SCALE):
    import torch
    from diffusers import ControlNetModel, DPMSolverMultistepScheduler, StableDiffusionControlNetImg2ImgPipeline

    cn = ControlNetModel.from_pretrained(CONTROLNET, torch_dtype=torch.float32)
    pipe = StableDiffusionControlNetImg2ImgPipeline.from_pretrained(
        manifest["model"], controlnet=cn, torch_dtype=torch.float32, safety_checker=None, requires_safety_checker=False
    )
    pipe.scheduler = DPMSolverMultistepScheduler.from_config(
        pipe.scheduler.config, use_karras_sigmas=True, algorithm_type="dpmsolver++"
    )
    pipe.set_progress_bar_config(disable=True)
    gen = torch.Generator(device="cpu").manual_seed(seed)
    return pipe(
        prompt=PROMPT,
        negative_prompt=manifest["negative_prompt"],
        image=layout,
        control_image=edges(layout),
        controlnet_conditioning_scale=control_scale,
        strength=strength,
        num_inference_steps=int(manifest["steps"]) + 5,
        guidance_scale=float(manifest["cfg_scale"]),
        generator=gen,
    ).images[0]


def meta(strength: float, seed: int, manifest: dict, extra: dict) -> dict:
    d = {
        "id": "town_painted",
        "prompt": PROMPT,
        "negative_prompt": manifest["negative_prompt"],
        "seed": seed,
        "steps": int(manifest["steps"]) + 5,
        "cfg_scale": float(manifest["cfg_scale"]),
        "sampler": "DPM++ 2M Karras",
        "mode": "img2img + ControlNet canny",
        "strength": strength,
        "controlnet": CONTROLNET,
        "controlnet_conditioning_scale": CONTROL_SCALE,
        "init": "layout from data/town.json (tools/town_paint.py compose)",
        "model": manifest["model"],
        "generator": "tools/town_paint.py (diffusers)",
        "timestamp": datetime.now(timezone.utc).isoformat(timespec="seconds"),
    }
    d.update(extra)
    return d


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--preview-dir")
    ap.add_argument("--strengths", nargs="*", type=float)
    ap.add_argument("--seed", type=int, default=SEED)
    ap.add_argument("--strength", type=float, default=STRENGTH)
    args = ap.parse_args()
    town = json.loads(TOWN.read_text(encoding="utf-8"))
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    layout, placed = compose(town)
    if args.preview_dir:
        out = Path(args.preview_dir)
        out.mkdir(parents=True, exist_ok=True)
        layout.save(out / "layout.png")
        for s in args.strengths or [args.strength]:
            t0 = time.time()
            edges(layout).save(out / "edges.png")
            paint(layout, s, args.seed, manifest).save(out / f"cn_{s:.2f}_{args.seed}.png")
            print(f"strength {s}: {time.time() - t0:.0f}s")
        return 0
    painted = paint(layout, args.strength, args.seed, manifest)
    if painted.size != layout.size:
        painted = painted.resize(layout.size)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    painted.save(OUT)
    OUT.with_suffix(".metadata.json").write_text(json.dumps(meta(args.strength, args.seed, manifest, {}), indent=2) + "\n", encoding="utf-8")
    CROPS.mkdir(parents=True, exist_ok=True)
    for bid, (px, py, alpha) in placed.items():
        crop = painted.crop((px, py, px + alpha.width, py + alpha.height)).convert("RGBA")
        crop.putalpha(alpha)
        p = CROPS / f"{bid}.png"
        crop.save(p)
        p.with_suffix(".metadata.json").write_text(json.dumps(meta(args.strength, args.seed, manifest, {
            "id": f"town_painted_{bid}", "crop_of": "assets/town/town_painted.png",
            "rect": [px, py, alpha.width, alpha.height], "alpha_from": f"its cut-out in data/town.json"}), indent=2) + "\n", encoding="utf-8")
    rects = {bid: [px, py, a.width, a.height] for bid, (px, py, a) in placed.items()}
    (CROPS / "layout.json").write_text(json.dumps({"_doc": "Where each crop sits in town_painted.png (design pixels), written by tools/town_paint.py.", "rects": rects}, indent=2) + "\n", encoding="utf-8")
    print(f"wrote {OUT} and {len(placed)} building crops")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
