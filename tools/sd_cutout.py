#!/usr/bin/env python3
"""
Cut generated art out of its background (transparent PNG), for manifest assets marked
"cutout": true (the town buildings, P4-17). Runs after tools/sd_local.py.

Uses BiRefNet (ZhengPeng7/BiRefNet on Hugging Face, MIT licence) through transformers;
rembg's models come from GitHub, which cloud containers can't always reach.

Setup (same venv as tools/sd_local.py):
  pip install transformers timm kornia einops torchvision

Usage (from repo root):
  python tools/sd_cutout.py                    # every "cutout" asset in the manifest
  python tools/sd_cutout.py --only town_iglesia

The PNG is replaced by an RGBA one cropped to the cut-out (plus a small margin), and its
.metadata.json gets "cutout": {"model": ..., "crop": [x, y, w, h]}. Game code never calls this.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MANIFEST = ROOT / "tools" / "art_manifest.json"
MODEL = "ZhengPeng7/BiRefNet"
MARGIN = 6


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--only", nargs="*")
    args = ap.parse_args()
    import torch
    from PIL import Image, ImageFilter
    from torchvision import transforms
    from transformers import AutoModelForImageSegmentation

    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    todo = [a for a in manifest["assets"] if a.get("cutout") and (not args.only or a["id"] in args.only)]
    model = AutoModelForImageSegmentation.from_pretrained(MODEL, trust_remote_code=True)
    model.eval()
    prep = transforms.Compose([
        transforms.Resize((1024, 1024)),
        transforms.ToTensor(),
        transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225]),
    ])
    for a in todo:
        out = ROOT / a["out"]
        meta_path = out.with_suffix(".metadata.json")
        meta = json.loads(meta_path.read_text(encoding="utf-8"))
        if "cutout" in meta:
            print(f"{a['id']}: already cut out")
            continue
        im = Image.open(out).convert("RGB")
        with torch.no_grad():
            pred = model(prep(im).unsqueeze(0))[-1].sigmoid()[0, 0]
        mask = transforms.ToPILImage()(pred).resize(im.size, Image.LANCZOS)
        mask = mask.filter(ImageFilter.GaussianBlur(0.8))
        rgba = im.convert("RGBA")
        rgba.putalpha(mask)
        box = mask.point(lambda v: 255 if v > 24 else 0).getbbox() or (0, 0, im.width, im.height)
        x0, y0 = max(0, box[0] - MARGIN), max(0, box[1] - MARGIN)
        x1, y1 = min(im.width, box[2] + MARGIN), min(im.height, box[3] + MARGIN)
        rgba = rgba.crop((x0, y0, x1, y1))
        rgba.save(out, format="PNG")
        meta["cutout"] = {"model": MODEL, "tool": "tools/sd_cutout.py", "crop": [x0, y0, x1 - x0, y1 - y0]}
        meta_path.write_text(json.dumps(meta, indent=2) + "\n", encoding="utf-8")
        print(f"{a['id']}: cut out, {x1 - x0}x{y1 - y0}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
