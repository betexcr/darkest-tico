#!/usr/bin/env python3
"""
Batch-generate game art from tools/art_manifest.json with a local diffusers pipeline.

No A1111 server needed; runs on CPU (slow but works) or CUDA if available.
Every PNG gets a sibling .metadata.json (see .cursor/rules/stable-diffusion-assets.mdc).

Setup (one time, outside the repo, e.g. a venv):
  pip install --index-url https://download.pytorch.org/whl/cpu torch   # or the CUDA build
  pip install diffusers transformers accelerate safetensors pillow

Usage (from repo root):
  python tools/sd_local.py                      # generate everything missing
  python tools/sd_local.py --force              # regenerate all
  python tools/sd_local.py --only enemy_espanto portrait_abuela
  python tools/sd_local.py --steps 12           # quick draft pass
  python tools/sd_local.py --only enemy_espanto --try-seeds 3 --preview-dir /tmp/previews
      # 3 candidates (seed, seed+1, seed+2); copy the best PNG + .metadata.json into
      # assets/ and set that seed in the manifest so it stays reproducible

Game code never calls this; it only writes files under assets/.
"""

from __future__ import annotations

import argparse
import json
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MANIFEST = ROOT / "tools" / "art_manifest.json"


def load_pipeline(model: str):
    import torch
    from diffusers import DPMSolverMultistepScheduler, StableDiffusionPipeline

    device = "cuda" if torch.cuda.is_available() else "cpu"
    dtype = torch.float16 if device == "cuda" else torch.float32
    kwargs = {"torch_dtype": dtype, "safety_checker": None, "requires_safety_checker": False}
    try:
        pipe = StableDiffusionPipeline.from_pretrained(model, variant="fp16", **kwargs)
    except (OSError, ValueError):
        pipe = StableDiffusionPipeline.from_pretrained(model, **kwargs)
    # "DPM++ 2M Karras" in A1111 terms.
    pipe.scheduler = DPMSolverMultistepScheduler.from_config(
        pipe.scheduler.config, use_karras_sigmas=True, algorithm_type="dpmsolver++"
    )
    pipe = pipe.to(device)
    pipe.set_progress_bar_config(disable=True)
    if device == "cpu":
        torch.set_num_threads(max(1, torch.get_num_threads()))
    return pipe, device, torch


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--only", nargs="*", help="asset ids to generate")
    ap.add_argument("--force", action="store_true", help="overwrite existing PNGs that have metadata")
    ap.add_argument("--steps", type=int, default=None, help="override manifest steps")
    ap.add_argument(
        "--try-seeds",
        type=int,
        default=0,
        metavar="N",
        help="write N candidates per asset (manifest seed, seed+1, ...) to --preview-dir instead of assets/",
    )
    ap.add_argument("--preview-dir", default=None, help="where --try-seeds writes candidates")
    args = ap.parse_args()
    if args.try_seeds and not args.preview_dir:
        ap.error("--try-seeds needs --preview-dir (keep previews out of assets/)")

    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    assets = manifest["assets"]
    if args.only:
        wanted = set(args.only)
        unknown = wanted - {a["id"] for a in assets}
        if unknown:
            print(f"Unknown ids: {', '.join(sorted(unknown))}", file=sys.stderr)
            return 2
        assets = [a for a in assets if a["id"] in wanted]

    todo = []
    for a in assets:
        out = ROOT / a["out"]
        meta = out.with_suffix(".metadata.json")
        if out.exists() and meta.exists() and not args.force and not args.only:
            continue
        todo.append(a)
    if not todo:
        print("Nothing to generate (all assets have metadata). Use --force or --only.")
        return 0

    pipe, device, torch = load_pipeline(manifest["model"])
    steps = args.steps or int(manifest["steps"])
    cfg = float(manifest["cfg_scale"])
    base_negative = manifest["negative_prompt"]
    print(f"Generating {len(todo)} asset(s) on {device}, {steps} steps")

    jobs = []
    for a in todo:
        if args.try_seeds:
            for k in range(args.try_seeds):
                seed = int(a["seed"]) + k
                jobs.append((a, seed, Path(args.preview_dir) / f'{a["id"]}_{seed}.png'))
        else:
            jobs.append((a, int(a["seed"]), ROOT / a["out"]))

    for i, (a, seed, out) in enumerate(jobs, 1):
        template = manifest.get("prompt_template", "{subject}, {style}")
        prompt = template.format(subject=a["subject"], style=a.get("style", manifest["style_suffix"]))
        negative = (a["negative_extra"] + ", " + base_negative) if a.get("negative_extra") else base_negative
        w, h = a["size"]
        t0 = time.time()
        gen = torch.Generator(device="cpu").manual_seed(seed)
        image = pipe(
            prompt=prompt,
            negative_prompt=negative,
            width=w,
            height=h,
            num_inference_steps=steps,
            guidance_scale=cfg,
            generator=gen,
        ).images[0]
        from PIL import Image, ImageEnhance

        out_size = a.get("out_size")
        if out_size and tuple(out_size) != (w, h):
            image = image.resize(tuple(out_size), Image.LANCZOS)
        # Optional deterministic post-processing, e.g. "post": {"brightness": 1.4, "contrast": 1.2}
        post = a.get("post", {})
        if "brightness" in post:
            image = ImageEnhance.Brightness(image).enhance(float(post["brightness"]))
        if "contrast" in post:
            image = ImageEnhance.Contrast(image).enhance(float(post["contrast"]))
        out.parent.mkdir(parents=True, exist_ok=True)
        image.save(out, format="PNG")
        meta = {
            "id": a["id"],
            "prompt": prompt,
            "negative_prompt": negative,
            "seed": seed,
            "steps": steps,
            "cfg_scale": cfg,
            "sampler": manifest["sampler"],
            "resolution": f"{w}x{h}",
            "output_resolution": f"{image.width}x{image.height}",
            "post": post or None,
            "model": manifest["model"],
            "generator": "tools/sd_local.py (diffusers)",
            "timestamp": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        }
        out.with_suffix(".metadata.json").write_text(
            json.dumps(meta, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
        )
        print(f"[{i}/{len(jobs)}] {out} ({time.time() - t0:.0f}s)", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
