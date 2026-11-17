#!/usr/bin/env python3
"""
Cut generated art out of its background (transparent PNG), for manifest assets marked
"cutout": true (the town buildings, P4-17). Runs after tools/sd_local.py.

A scene-parsing model (openmmlab/upernet-convnext-small on Hugging Face, MIT licence,
ADE20K classes; built into transformers, no remote code) labels every pixel. Sky, ground
and landscape go; what is left (the building, its porch, a bus, signs) stays. Only the
biggest connected piece is kept, holes are filled and the edge is softened.

Setup (same venv as tools/sd_local.py):
  pip install transformers scipy

Usage (from repo root):
  python tools/sd_cutout.py                    # every "cutout" asset in the manifest
  python tools/sd_cutout.py --only town_iglesia
  python tools/sd_cutout.py --file in.png --out out.png   # try it on any picture

The PNG is replaced by an RGBA one cropped to the cut-out (plus a small margin), and its
.metadata.json gets "cutout": {"model": ..., "crop": [x, y, w, h]}. Game code never calls this.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MANIFEST = ROOT / "tools" / "art_manifest.json"
MODEL = "openmmlab/upernet-convnext-small"
MARGIN = 6
## Pixels shaved off and grown back on the mask: removes thin strays (wires, stray lines).
OPEN = 5
## ADE20K labels that are background in a town picture.
DROP = {
    "sky", "floor", "road", "grass", "earth", "ground", "mountain", "field", "sand", "sidewalk",
    "hill", "dirt track", "path", "water", "sea", "river", "land", "tree", "plant", "flora",
    "rock", "stone", "runway", "lake", "snow",
}


def load_model():
    from transformers import AutoImageProcessor, UperNetForSemanticSegmentation

    proc = AutoImageProcessor.from_pretrained(MODEL)
    model = UperNetForSemanticSegmentation.from_pretrained(MODEL)
    model.eval()
    return proc, model


def cut(im, proc, model):
    """Returns (rgba cropped, crop box)."""
    import numpy as np
    import torch
    from PIL import Image, ImageFilter
    from scipy import ndimage

    with torch.no_grad():
        out = model(**proc(images=im, return_tensors="pt"))
    seg = proc.post_process_semantic_segmentation(out, target_sizes=[im.size[::-1]])[0].numpy()
    labels = model.config.id2label
    drop_ids = [i for i, name in labels.items() if any(d == part.strip() for part in name.split(",") for d in DROP)]
    keep = ~np.isin(seg, drop_ids)
    keep = ndimage.binary_opening(keep, iterations=OPEN)
    # The biggest piece only (stray bits of other houses go), with its holes filled.
    lab, n = ndimage.label(keep)
    if n > 0:
        sizes = ndimage.sum(keep, lab, range(1, n + 1))
        keep = lab == (int(np.argmax(sizes)) + 1)
    keep = ndimage.binary_fill_holes(keep)
    mask = Image.fromarray((keep * 255).astype("uint8")).filter(ImageFilter.GaussianBlur(1.2))
    rgba = im.convert("RGBA")
    rgba.putalpha(mask)
    box = mask.point(lambda v: 255 if v > 24 else 0).getbbox() or (0, 0, im.width, im.height)
    x0, y0 = max(0, box[0] - MARGIN), max(0, box[1] - MARGIN)
    x1, y1 = min(im.width, box[2] + MARGIN), min(im.height, box[3] + MARGIN)
    return rgba.crop((x0, y0, x1, y1)), [x0, y0, x1 - x0, y1 - y0]


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--only", nargs="*")
    ap.add_argument("--file", help="cut out this picture instead of manifest assets (needs --out)")
    ap.add_argument("--out")
    args = ap.parse_args()
    from PIL import Image

    proc, model = load_model()
    if args.file:
        rgba, crop = cut(Image.open(args.file).convert("RGB"), proc, model)
        rgba.save(args.out, format="PNG")
        print(f"{args.file}: {crop}")
        return 0
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    todo = [a for a in manifest["assets"] if a.get("cutout") and (not args.only or a["id"] in args.only)]
    for a in todo:
        out = ROOT / a["out"]
        meta_path = out.with_suffix(".metadata.json")
        meta = json.loads(meta_path.read_text(encoding="utf-8"))
        if "cutout" in meta:
            print(f"{a['id']}: already cut out")
            continue
        rgba, crop = cut(Image.open(out).convert("RGB"), proc, model)
        rgba.save(out, format="PNG")
        meta["cutout"] = {"model": MODEL, "tool": "tools/sd_cutout.py", "crop": crop}
        meta_path.write_text(json.dumps(meta, indent=2) + "\n", encoding="utf-8")
        print(f"{a['id']}: cut out, {crop[2]}x{crop[3]}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
