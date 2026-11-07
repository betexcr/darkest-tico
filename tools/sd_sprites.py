#!/usr/bin/env python3
"""
Generate battle-stage sprites (one image per character per state) from the "sprites"
section of tools/art_manifest.json.

For each character:
  1. `idle` is generated from text (txt2img), full body on a plain background.
  2. Every other state (attack, cast, hurt, ailment, dead) is generated with img2img
     starting from that idle image, so the character keeps the same look.
  3. The background is removed (rembg) and the result is saved as a transparent PNG:
       assets/sprites/<character>/<state>.png  (+ .metadata.json)

Setup: same venv as tools/sd_local.py, plus `pip install "rembg[cpu]"`.

Usage (from repo root):
  python tools/sd_sprites.py                          # everything missing
  python tools/sd_sprites.py --only campesino espanto # some characters
  python tools/sd_sprites.py --only campesino --states hurt dead --force
  python tools/sd_sprites.py --no-cutout              # keep backgrounds (debug)

Game code never calls this; it only writes files under assets/sprites/.
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
# Idle images before background removal; img2img starts from these. Not committed:
# if missing they are rebuilt from the idle seed, which gives the same image.
CACHE = ROOT / "tools" / ".sprite_cache"


def load_pipelines(model: str):
    import torch
    from diffusers import (
        DPMSolverMultistepScheduler,
        StableDiffusionImg2ImgPipeline,
        StableDiffusionPipeline,
    )

    device = "cuda" if torch.cuda.is_available() else "cpu"
    dtype = torch.float16 if device == "cuda" else torch.float32
    kwargs = {"torch_dtype": dtype, "safety_checker": None, "requires_safety_checker": False}
    try:
        txt = StableDiffusionPipeline.from_pretrained(model, variant="fp16", **kwargs)
    except (OSError, ValueError):
        txt = StableDiffusionPipeline.from_pretrained(model, **kwargs)
    txt.scheduler = DPMSolverMultistepScheduler.from_config(
        txt.scheduler.config, use_karras_sigmas=True, algorithm_type="dpmsolver++"
    )
    txt = txt.to(device)
    txt.set_progress_bar_config(disable=True)
    img = StableDiffusionImg2ImgPipeline(**txt.components)
    img.set_progress_bar_config(disable=True)
    return txt, img, device, torch


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--only", nargs="*", help="character ids")
    ap.add_argument("--states", nargs="*", help="state ids (default: all)")
    ap.add_argument("--force", action="store_true", help="regenerate even if the PNG exists")
    ap.add_argument("--no-cutout", action="store_true", help="skip background removal")
    args = ap.parse_args()

    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    cfg = manifest["sprites"]
    states = cfg["states"]
    chars = cfg["characters"]
    if args.only:
        known = {c["id"] for c in chars}
        bad = set(args.only) - known
        if bad:
            print(f"Unknown characters: {', '.join(sorted(bad))}", file=sys.stderr)
            return 2
        chars = [c for c in chars if c["id"] in set(args.only)]
    state_ids = [s["id"] for s in states]
    if args.states:
        bad = set(args.states) - set(state_ids)
        if bad:
            print(f"Unknown states: {', '.join(sorted(bad))}", file=sys.stderr)
            return 2

    def wanted(cid: str, sid: str) -> bool:
        if args.states and sid not in args.states:
            return False
        out = ROOT / cfg["out_dir"] / cid / f"{sid}.png"
        return args.force or not out.exists()

    todo = [(c, s) for c in chars for s in states if wanted(c["id"], s["id"])]
    if not todo:
        print("Nothing to generate. Use --force to redo.")
        return 0

    txt, img2img, device, torch = load_pipelines(manifest["model"])
    remover = None
    if not args.no_cutout:
        from rembg import new_session, remove

        session = new_session(cfg.get("cutout_model", "isnet-general-use"))
        remover = lambda im: remove(im, session=session)  # noqa: E731

    from PIL import Image

    w, h = cfg["size"]
    steps = int(cfg.get("steps", manifest["steps"]))
    guidance = float(manifest["cfg_scale"])
    negative = f'{cfg["negative_extra"]}, {manifest["negative_prompt"]}'
    print(f"Generating {len(todo)} sprite(s) on {device}, {w}x{h}, {steps} steps", flush=True)

    raw_cache: dict[str, Image.Image] = {}
    for i, (c, s) in enumerate(todo, 1):
        cid, sid = c["id"], s["id"]
        out = ROOT / cfg["out_dir"] / cid / f"{sid}.png"
        raw_path = CACHE / cid / "idle_raw.png"
        seed = int(c["seed"]) + state_ids.index(sid)
        prompt = cfg["prompt_template"].format(
            look=c["look"], pose=s["pose"], style=manifest["style_suffix"]
        )
        gen = torch.Generator(device="cpu").manual_seed(seed)
        t0 = time.time()
        if s["mode"] == "txt2img":
            image = txt(
                prompt=prompt, negative_prompt=negative, width=w, height=h,
                num_inference_steps=steps, guidance_scale=guidance, generator=gen,
            ).images[0]
            if sid == "idle":
                raw_path.parent.mkdir(parents=True, exist_ok=True)
                image.save(raw_path)
                raw_cache[cid] = image
        else:
            base = raw_cache.get(cid)
            if base is None and raw_path.exists():
                base = Image.open(raw_path).convert("RGB")
            if base is None:
                idle = states[state_ids.index("idle")]
                base = txt(
                    prompt=cfg["prompt_template"].format(
                        look=c["look"], pose=idle["pose"], style=manifest["style_suffix"]
                    ),
                    negative_prompt=negative, width=w, height=h, num_inference_steps=steps,
                    guidance_scale=guidance,
                    generator=torch.Generator(device="cpu").manual_seed(int(c["seed"])),
                ).images[0]
                raw_path.parent.mkdir(parents=True, exist_ok=True)
                base.save(raw_path)
            raw_cache[cid] = base
            image = img2img(
                prompt=prompt, negative_prompt=negative, image=base,
                strength=float(s["strength"]), num_inference_steps=steps,
                guidance_scale=guidance, generator=gen,
            ).images[0]
        if remover is not None:
            image = remover(image)
        out.parent.mkdir(parents=True, exist_ok=True)
        image.save(out, format="PNG")
        meta = {
            "id": f"sprite_{cid}_{sid}",
            "prompt": prompt,
            "negative_prompt": negative,
            "seed": seed,
            "steps": steps,
            "cfg_scale": guidance,
            "sampler": manifest["sampler"],
            "resolution": f"{w}x{h}",
            "mode": s["mode"],
            "strength": s.get("strength"),
            "init_image": None if s["mode"] == "txt2img" else "idle (same character, before cutout)",
            "cutout": None if remover is None else cfg.get("cutout_model", "isnet-general-use"),
            "model": manifest["model"],
            "generator": "tools/sd_sprites.py (diffusers)",
            "timestamp": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        }
        out.with_suffix(".metadata.json").write_text(
            json.dumps(meta, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
        )
        print(f"[{i}/{len(todo)}] {out.relative_to(ROOT)} ({time.time() - t0:.0f}s)", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
