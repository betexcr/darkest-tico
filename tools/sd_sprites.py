#!/usr/bin/env python3
"""
Generate battle-stage sprites (one image per character per state) from the "sprites"
section of tools/art_manifest.json.

For each character:
  1. `idle` is generated from text (txt2img), full body on a plain background.
  2. Every other state (attack, cast, hurt, ailment, dead) is generated with img2img
     starting from that idle image, so the character keeps the same look.
     Beasts work this way.
  3. Humanoids instead get a *character sheet*: all six poses are drawn in ONE image (a
     grid of cells, each guided by that state's OpenPose skeleton), then cut into six
     sprites. Figures generated together keep the same outfit and weapon; only the pose
     changes (owner requirement, 2026-11-07).
  4. Every call also gets the character's portrait (assets/portraits/<id>.png for heroes,
     assets/enemies/<id>.png for enemies) as an IP-Adapter image prompt, so the sprite looks
     like the portrait: same face, clothes, colors (owner requirement, 2026-11-07).
  5. The background is removed (rembg) and the result is saved as a transparent PNG:
       assets/sprites/<character>/<state>.png  (+ .metadata.json)

Setup: same venv as tools/sd_local.py, plus `pip install "rembg[cpu]"`.

Usage (from repo root):
  python tools/sd_sprites.py                          # everything missing
  python tools/sd_sprites.py --only campesino espanto # some characters
  python tools/sd_sprites.py --only campesino --states hurt dead --force
  python tools/sd_sprites.py --no-cutout              # keep backgrounds (debug)
  python tools/sd_sprites.py --only campesino --try-seeds 2 --ref-scales 0.5 0.7 \
      --preview-dir /tmp/trials                       # compare sheets, write no assets

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


# OpenPose COCO-18 limb pairs and colors, as the ControlNet openpose model expects.
LIMBS = [(1, 2), (1, 5), (2, 3), (3, 4), (5, 6), (6, 7), (1, 8), (8, 9), (9, 10), (1, 11),
         (11, 12), (12, 13), (1, 0), (0, 14), (14, 16), (0, 15), (15, 17)]
COLORS = [(255, 0, 0), (255, 85, 0), (255, 170, 0), (255, 255, 0), (170, 255, 0), (85, 255, 0),
          (0, 255, 0), (0, 255, 85), (0, 255, 170), (0, 255, 255), (0, 170, 255), (0, 85, 255),
          (0, 0, 255), (85, 0, 255), (170, 0, 255), (255, 0, 255), (255, 0, 170), (255, 0, 85)]


def keep_main_figure(im):
    """Drop everything but the biggest blob (after cutout). A lying 'dead' figure leaves empty
    space in its cell, and the model sometimes paints a second character there."""
    import numpy as np
    from PIL import Image
    from scipy import ndimage

    rgba = np.array(im.convert("RGBA"))
    solid = rgba[:, :, 3] > 40
    labels, n = ndimage.label(ndimage.binary_dilation(solid, iterations=6))
    if n <= 1:
        return im
    sizes = ndimage.sum(solid, labels, range(1, n + 1))
    keep = labels == (int(np.argmax(sizes)) + 1)
    rgba[~keep, 3] = 0
    return Image.fromarray(rgba)


def skeleton_for(cfg: dict, c: dict, sid: str):
    """Pose keypoints for one state: the character's own override, else the shared one."""
    return c.get("skeletons", {}).get(sid) or cfg["skeletons"][sid]


def draw_skeleton(points, size):
    from PIL import Image, ImageDraw

    w, h = size
    im = Image.new("RGB", (w, h), (0, 0, 0))
    d = ImageDraw.Draw(im)
    # A keypoint may be null (hidden, e.g. the far ear of a turned head): it and its limbs are skipped.
    px = [None if p is None else (p[0] * w, p[1] * h) for p in points]
    for k, (a, b) in enumerate(LIMBS):
        if px[a] is None or px[b] is None:
            continue
        c = tuple(int(v * 0.6) for v in COLORS[k])
        d.line([px[a], px[b]], fill=c, width=max(4, w // 64))
    for k, p in enumerate(px):
        if p is None:
            continue
        x, y = p
        r = max(3, w // 128)
        d.ellipse([x - r, y - r, x + r, y + r], fill=COLORS[k])
    return im


_REF_MEMO: dict = {}


def reference_image(cfg: dict, c: dict):
    """The character's portrait (IP-Adapter image prompt), or None."""
    if c["id"] in _REF_MEMO:
        return _REF_MEMO[c["id"]]
    _REF_MEMO[c["id"]] = img = _reference_image(cfg, c)
    return img


def _reference_image(cfg: dict, c: dict):
    from PIL import Image

    ref = cfg.get("reference")
    if not ref:
        return None
    for d in ref.get("dirs", []):
        p = ROOT / d / f'{c.get("portrait", c["id"])}.png'
        if not p.exists():
            continue
        if not ref.get("cutout", True):
            return Image.open(p).convert("RGB")
        # The portrait's own background (jungle, rooms) would leak into the sprite, so the
        # reference is the portrait cut out and placed on flat grey. Cached per character.
        cached = CACHE / f'{c["id"]}_ref.png'
        if cached.exists() and cached.stat().st_mtime >= p.stat().st_mtime:
            return Image.open(cached).convert("RGB")
        from rembg import new_session, remove

        cut = remove(Image.open(p).convert("RGB"), session=new_session(cfg.get("cutout_model", "isnet-general-use")))
        grey = Image.new("RGBA", cut.size, (128, 128, 128, 255))
        grey.alpha_composite(cut)
        CACHE.mkdir(parents=True, exist_ok=True)
        grey.convert("RGB").save(cached)
        return grey.convert("RGB")
    return None


def reference_note(cfg: dict, c: dict):
    ref = cfg.get("reference")
    if not ref or reference_image(cfg, c) is None:
        return None
    for d in ref.get("dirs", []):
        p = f'{d}/{c.get("portrait", c["id"])}.png'
        if (ROOT / p).exists():
            return {"image": p, "ip_adapter": f'{ref["repo"]}/{ref["subfolder"]}/{ref["weight"]}',
                    "scale": float(ref.get("scale", 0.6))}
    return None


def load_pipelines(model: str, control_model: str, ref: dict | None = None, weapon_model: str | None = None):
    import torch
    from diffusers import (
        ControlNetModel,
        DPMSolverMultistepScheduler,
        StableDiffusionControlNetImg2ImgPipeline,
        StableDiffusionControlNetPipeline,
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
    if ref:
        txt.load_ip_adapter(ref["repo"], subfolder=ref["subfolder"], weight_name=ref["weight"])
        txt.set_ip_adapter_scale(float(ref.get("scale", 0.6)))
    txt = txt.to(device)
    try:
        cn = ControlNetModel.from_pretrained(control_model, variant="fp16", torch_dtype=dtype)
    except (OSError, ValueError):
        cn = ControlNetModel.from_pretrained(control_model, torch_dtype=dtype)
    cn = cn.to(device)
    comps = txt.components
    pipes = {
        "txt": txt,
        "img": StableDiffusionImg2ImgPipeline(**comps),
        "txt_pose": StableDiffusionControlNetPipeline(**comps, controlnet=cn),
        "img_pose": StableDiffusionControlNetImg2ImgPipeline(**comps, controlnet=cn),
    }
    if weapon_model:
        # Second ControlNet (scribble): a drawn weapon shape, so the weapon goes where we want it.
        cw = ControlNetModel.from_pretrained(weapon_model, torch_dtype=dtype).to(device)
        pipes["txt_pose_weapon"] = StableDiffusionControlNetPipeline(**comps, controlnet=[cn, cw])
    for p in pipes.values():
        p.set_progress_bar_config(disable=True)
    return pipes, device, torch


def draw_weapon(cfg: dict, c: dict, sid: str, size):
    """Scribble image (white on black) of the character's weapon for one state, or None.
    The weapon starts at the hands (mean of both wrists) and points along `angle`
    (degrees, 0 = toward the enemy on the right, positive = up)."""
    import math

    from PIL import Image, ImageDraw

    guide = cfg.get("weapon_guide", {})
    if sid not in guide.get("states", []):
        return None
    shape = dict(guide.get("default", {}), **c.get("weapon_shape", {}))
    kind = shape.get("kind", "line")
    if kind == "none":
        return None
    w, h = size
    pts = skeleton_for(cfg, c, sid)
    # "hand": "right" / "left" holds it in one hand; default: between both wrists (two-handed)
    which = {"right": (4,), "left": (7,)}.get(shape.get("hand", ""), (4, 7))
    hands = [pts[i] for i in which if pts[i] is not None]
    x0 = sum(p[0] for p in hands) / len(hands) * w
    y0 = sum(p[1] for p in hands) / len(hands) * h
    ang = math.radians(float(shape.get("angle", 20)))
    length = float(shape.get("length", 0.35)) * w
    x1, y1 = x0 + math.cos(ang) * length, y0 - math.sin(ang) * length
    lw = max(3, int(float(shape.get("width", 0.025)) * w))
    im = Image.new("RGB", (w, h), (0, 0, 0))
    d = ImageDraw.Draw(im)
    if kind == "box":  # e.g. a drone held out in front
        r = length / 2
        cx, cy = x0 + math.cos(ang) * r * 1.4, y0 - math.sin(ang) * r * 1.4
        d.rectangle([cx - r, cy - r * 0.45, cx + r, cy + r * 0.45], outline=(255, 255, 255), width=lw)
        d.line([(x0, y0), (cx - r, cy)], fill=(255, 255, 255), width=max(2, lw // 2))
        return im
    d.line([(x0, y0), (x1, y1)], fill=(255, 255, 255), width=lw)
    if kind == "rope":  # lasso: wavy rope from the hand to a wide OPEN loop (a closed circle reads as a disc)
        im = Image.new("RGB", (w, h), (0, 0, 0))
        d = ImageDraw.Draw(im)
        n = 24
        rope = []
        for k in range(n + 1):
            t = k / n
            wob = math.sin(t * math.pi * 3) * 0.025 * w
            rope.append((x0 + (x1 - x0) * t - math.sin(ang) * wob, y0 + (y1 - y0) * t - math.cos(ang) * wob))
        d.line(rope, fill=(255, 255, 255), width=lw, joint="curve")
        rx = float(shape.get("loop", 0.12)) * w
        ry = rx * 0.6
        d.arc([x1, y1 - ry, x1 + 2 * rx, y1 + ry], 200, 520, fill=(255, 255, 255), width=lw)
        return im
    if kind == "loop":  # lasso: rope out to a loop
        r = float(shape.get("loop", 0.12)) * w
        d.ellipse([x1 - r, y1 - r, x1 + r, y1 + r], outline=(255, 255, 255), width=lw)
    elif kind == "cross":  # crucifix: crossbar near the far end
        bx, by = x0 + math.cos(ang) * length * 0.7, y0 - math.sin(ang) * length * 0.7
        px, py = math.sin(ang) * length * 0.25, math.cos(ang) * length * 0.25
        d.line([(bx - px, by - py), (bx + px, by + py)], fill=(255, 255, 255), width=lw)
    elif kind == "bowl":  # ladle line + a bowl near the hands
        r = length * 0.3
        d.arc([x0 - r, y0, x0 + r, y0 + r * 1.2], 0, 180, fill=(255, 255, 255), width=lw)
    return im


def sprite_reference(cid: str, sid: str = "idle", crop: float = 1.0):
    """The character's own finished sprite (e.g. idle), padded to a square on grey, as an
    IP-Adapter reference. The portrait is a close-up: redrawing a full-body pose from it
    smears big features (a wide hat brim) across the figure. None if the sprite is missing."""
    from PIL import Image

    p = ROOT / "assets" / "sprites" / cid / f"{sid}.png"
    if not p.exists():
        return None
    im = Image.open(p).convert("RGBA")
    if crop < 1.0:  # keep only the top part (e.g. drop a weapon hanging at the side)
        im = im.crop((0, 0, im.width, int(im.height * crop)))
    side = max(im.size)
    sq = Image.new("RGBA", (side, side), (128, 128, 128, 255))
    sq.alpha_composite(im, ((side - im.width) // 2, (side - im.height) // 2))
    return sq.convert("RGB")


def redo_prompt(cfg: dict, manifest: dict, c: dict, sid: str) -> str:
    st = {s["id"]: s for s in cfg["states"]}[sid]
    pose_text = c.get("redo_poses", {}).get(sid) or st.get("redo_pose", st["pose"])
    pose_text = pose_text.replace("{weapon}", c.get("weapon", "a weapon"))
    look = c.get("redo_looks", {}).get(sid) or c["look"]
    return cfg["prompt_template"].format(look=look, pose=pose_text, style=cfg.get("style", manifest["style_suffix"]))


def redo_seed(cfg: dict, c: dict, sid: str) -> int:
    order = [s["id"] for s in cfg["states"]]
    return int(c.get("redo_seeds", {}).get(sid, int(c["seed"]) + order.index(sid)))


def generate_sheet(pipes, cfg, manifest, c, negative, steps, guidance, control_scale, torch, ref_kw=None,
                   raw_sheet=None):
    """All states of one humanoid in one image. Returns {state_id: PIL.Image}, sheet."""
    from PIL import Image

    sheet = cfg["sheet"]
    cols, rows = int(sheet["cols"]), int(sheet["rows"])
    cw, ch = sheet["cell"]
    order = [s["id"] for s in cfg["states"]]
    pose = Image.new("RGB", (cols * cw, rows * ch), (0, 0, 0))
    for i, sid in enumerate(order):
        cell = draw_skeleton(skeleton_for(cfg, c, sid), (cw, ch))
        pose.paste(cell, ((i % cols) * cw, (i // cols) * ch))
    prompt = sheet["prompt_template"].format(
        look=c["look"], weapon=c.get("weapon", "a weapon"), style=cfg.get("style", manifest["style_suffix"])
    )
    img = raw_sheet.copy() if raw_sheet is not None else pipes["txt_pose"](
        prompt=prompt, image=pose, width=cols * cw, height=rows * ch,
        controlnet_conditioning_scale=control_scale, negative_prompt=negative,
        num_inference_steps=steps, guidance_scale=guidance,
        generator=torch.Generator(device="cpu").manual_seed(int(c["seed"])),
        **(ref_kw or {}),
    ).images[0]
    raw = img.copy()
    out = {}
    for i, sid in enumerate(order):
        x, y = (i % cols) * cw, (i // cols) * ch
        out[sid] = img.crop((x, y, x + cw, y + ch))
    # Small sheet cells lose detail (e.g. a raised weapon). States listed in sheet.redo_states
    # are redrawn as one full-size figure, starting from their own cell (keeps the colors),
    # guided by the same skeleton and the portrait, then put back into the sheet.
    w, h = cfg["size"]
    states = {s["id"]: s for s in cfg["states"]}
    for sid in sheet.get("redo_states", []):
        st = states[sid]
        p = redo_prompt(cfg, manifest, c, sid)
        # redo_mode "txt": draw from scratch (pose + portrait only) so the old cell's weapon
        # placement can't leak in; "img" (default): start from the cell to keep its colors.
        skel = draw_skeleton(skeleton_for(cfg, c, sid), (w, h))
        weapon = draw_weapon(cfg, c, sid, (w, h)) if "txt_pose_weapon" in pipes else None
        scale = float(st.get("redo_pose_scale", control_scale))
        if weapon is not None:
            src = dict(image=[skel, weapon], width=w, height=h)
            pipe = pipes["txt_pose_weapon"]
            scale = [scale, float(cfg["weapon_guide"].get("scale", 0.7))]
        elif st.get("redo_mode", "img") == "txt":
            src = dict(image=skel, width=w, height=h)
            pipe = pipes["txt_pose"]
        else:
            src = dict(image=out[sid].resize((w, h)), control_image=skel, strength=float(st.get("redo_strength", 0.75)))
            pipe = pipes["img_pose"]
        # Per-character portrait strength for redrawn states (a portrait detail can leak in as an object).
        ref_scale = c.get("redo_ref_scale", {}).get(sid)
        ref_from = c.get("redo_reference", cfg["sheet"].get("redo_reference", "portrait"))
        if ref_kw and ref_from != "portrait":
            own = sprite_reference(c["id"], ref_from, float(c.get("redo_reference_crop", 1.0)))
            if own is not None:
                ref_kw = {"ip_adapter_image": own}
        if ref_kw and ref_scale is not None:
            pipes["txt"].set_ip_adapter_scale(float(ref_scale))
        big = pipe(
            prompt=p, **src, controlnet_conditioning_scale=scale,
            negative_prompt=negative, num_inference_steps=steps, guidance_scale=guidance,
            generator=torch.Generator(device="cpu").manual_seed(redo_seed(cfg, c, sid)),
            **(ref_kw or {}),
        ).images[0]
        if ref_kw and ref_scale is not None:
            pipes["txt"].set_ip_adapter_scale(float(cfg.get("reference", {}).get("scale", 0.6)))
        out[sid] = big.resize((cw, ch), Image.LANCZOS)
        i = order.index(sid)
        img.paste(out[sid], ((i % cols) * cw, (i // cols) * ch))
    return out, img, prompt, raw


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--only", nargs="*", help="character ids")
    ap.add_argument("--states", nargs="*", help="state ids (default: all)")
    ap.add_argument("--force", action="store_true", help="regenerate even if the PNG exists")
    ap.add_argument("--no-cutout", action="store_true", help="skip background removal")
    ap.add_argument("--try-seeds", type=int, default=0,
                    help="humanoids only: render N sheets (seed, seed+1, ...) into --preview-dir, write no assets")
    ap.add_argument("--preview-dir", default="", help="where --try-seeds writes its sheets")
    ap.add_argument("--redo-tries", type=int, default=0,
                    help="with --states <redo state(s)> and --preview-dir: write N variants (redo seed, +1, ...) "
                         "into <preview-dir>/<id>/ instead of assets; then set redo_seeds and run --force")
    ap.add_argument("--ref-scales", nargs="*", type=float, help="--try-seeds: portrait strengths to compare")
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

    if args.try_seeds > 0:
        if not args.preview_dir:
            print("--try-seeds needs --preview-dir", file=sys.stderr)
            return 2
        prev = Path(args.preview_dir)
        prev.mkdir(parents=True, exist_ok=True)
        pipes, device, torch = load_pipelines(manifest["model"], cfg["control_model"], cfg.get("reference"),
                                           cfg.get("weapon_guide", {}).get("control_model"))
        steps = int(cfg.get("steps", manifest["steps"]))
        scales = args.ref_scales or [float(cfg.get("reference", {}).get("scale", 0.6))]
        negative = cfg.get("negative") or f'{cfg["negative_extra"]}, {manifest["negative_prompt"]}'
        for c in chars:
            if c.get("body", "humanoid") == "beast":
                continue
            ref_img = reference_image(cfg, c)
            n = 0
            for scale in scales:
                for k in range(args.try_seeds):
                    seed = int(c["seed"]) + k
                    t0 = time.time()
                    ref_kw = {}
                    if ref_img is not None:
                        pipes["txt"].set_ip_adapter_scale(scale)
                        ref_kw = {"ip_adapter_image": ref_img}
                    _, sheet_img, _, _ = generate_sheet(
                        pipes, cfg, manifest, dict(c, seed=seed),
                        f'{c["negative_extra"]}, {negative}' if c.get("negative_extra") else negative, steps,
                        float(manifest["cfg_scale"]), float(cfg.get("control_scale", 1.0)), torch, ref_kw,
                    )
                    sheet_img.save(prev / f"{c['id']}_seed{seed}_ref{scale:g}.png")
                    n += 1
                    print(f"[{n}/{args.try_seeds * len(scales)}] {c['id']} seed {seed} ref {scale:g} "
                          f"({time.time() - t0:.0f}s)", flush=True)
        return 0

    def wanted(cid: str, sid: str) -> bool:
        if args.states and sid not in args.states:
            return False
        out = ROOT / cfg["out_dir"] / cid / f"{sid}.png"
        return args.force or not out.exists()

    todo = [(c, s) for c in chars for s in states if wanted(c["id"], s["id"])]
    if not todo:
        print("Nothing to generate. Use --force to redo.")
        return 0

    pipes, device, torch = load_pipelines(manifest["model"], cfg["control_model"], cfg.get("reference"),
                                           cfg.get("weapon_guide", {}).get("control_model"))
    control_scale = float(cfg.get("control_scale", 1.0))
    skeletons = cfg.get("skeletons", {})
    remover = None
    if not args.no_cutout:
        from rembg import new_session, remove

        session = new_session(cfg.get("cutout_model", "isnet-general-use"))
        remover = lambda im: remove(im, session=session)  # noqa: E731

    from PIL import Image

    w, h = cfg["size"]
    steps = int(cfg.get("steps", manifest["steps"]))
    guidance = float(manifest["cfg_scale"])
    negative = cfg.get("negative") or f'{cfg["negative_extra"]}, {manifest["negative_prompt"]}'
    print(f"Generating {len(todo)} sprite(s) on {device}, {w}x{h}, {steps} steps", flush=True)

    raw_cache: dict[str, Image.Image] = {}
    done_sheets: set = set()
    use_sheet = "sheet" in cfg
    for i, (c, s) in enumerate(todo, 1):
        if use_sheet and c.get("body", "humanoid") != "beast":
            cid = c["id"]
            if cid in done_sheets:
                continue
            done_sheets.add(cid)
            t0 = time.time()
            ref_img = reference_image(cfg, c)
            # Only redrawn states asked for (e.g. --states attack) and the raw sheet is cached:
            # reuse it instead of drawing the whole sheet again.
            raw_path = CACHE / f"{cid}_sheet_raw.png"
            redo_only = bool(args.states) and set(args.states) <= set(cfg["sheet"].get("redo_states", []))
            raw_sheet = Image.open(raw_path).convert("RGB") if redo_only and raw_path.exists() else None
            neg_c = f'{c["negative_extra"]}, {negative}' if c.get("negative_extra") else negative
            if args.redo_tries and raw_sheet is not None:
                prev = Path(args.preview_dir) / cid
                prev.mkdir(parents=True, exist_ok=True)
                for k in range(args.redo_tries):
                    seeds = {sid: redo_seed(cfg, c, sid) + k for sid in args.states}
                    ck = dict(c, redo_seeds={**c.get("redo_seeds", {}), **seeds})
                    crops_k, *_ = generate_sheet(
                        pipes, cfg, manifest, ck, neg_c, steps, guidance, control_scale, torch,
                        {"ip_adapter_image": ref_img} if ref_img is not None else None, raw_sheet,
                    )
                    for sid in args.states:
                        im = remover(crops_k[sid]) if remover is not None else crops_k[sid]
                        im.save(prev / f"{sid}_{seeds[sid]}.png")
                        # Metadata as the final asset would have it: copy both files into
                        # assets/sprites/<id>/<state>.* and set redo_seeds to keep it reproducible.
                        st = next(x for x in cfg["states"] if x["id"] == sid)
                        meta = {
                            "id": f"sprite_{cid}_{sid}",
                            "prompt": redo_prompt(cfg, manifest, ck, sid), "negative_prompt": neg_c,
                            "seed": seeds[sid], "sheet_seed": int(c["seed"]), "steps": steps, "cfg_scale": guidance,
                            "sampler": manifest["sampler"], "resolution": "%dx%d, scaled into a %dx%d cell" % (
                                cfg["size"][0], cfg["size"][1], cfg["sheet"]["cell"][0], cfg["sheet"]["cell"][1]),
                            "mode": "txt2img" if st.get("redo_mode") == "txt" else "img2img from the sheet cell",
                            "pose_control": cfg["control_model"],
                            "weapon_control": cfg.get("weapon_guide", {}).get("control_model")
                            if draw_weapon(cfg, ck, sid, (64, 96)) is not None else None,
                            "reference": reference_note(cfg, c)
                            if c.get("redo_reference", cfg["sheet"].get("redo_reference", "portrait")) == "portrait"
                            else {"image": f"assets/sprites/{cid}/{c.get('redo_reference', cfg['sheet'].get('redo_reference'))}.png (padded square on grey)",
                                  "ip_adapter": reference_note(cfg, c)["ip_adapter"] if reference_note(cfg, c) else None},
                            "cutout": None if remover is None else cfg.get("cutout_model", "isnet-general-use"),
                            "model": manifest["model"], "generator": "tools/sd_sprites.py (diffusers)",
                            "timestamp": datetime.now(timezone.utc).isoformat(timespec="seconds"),
                        }
                        (prev / f"{sid}_{seeds[sid]}.metadata.json").write_text(
                            json.dumps(meta, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
                    print(f"[{k + 1}/{args.redo_tries}] {cid} {'/'.join(args.states)} seeds "
                          f"{sorted(seeds.values())} ({time.time() - t0:.0f}s)", flush=True)
                continue
            crops, sheet_img, prompt, raw = generate_sheet(
                pipes, cfg, manifest, c, neg_c, steps, guidance, control_scale, torch,
                {"ip_adapter_image": ref_img} if ref_img is not None else None, raw_sheet,
            )
            CACHE.mkdir(parents=True, exist_ok=True)
            sheet_img.save(CACHE / f"{cid}_sheet.png")
            raw.save(raw_path)
            for k, (sid, crop) in enumerate(crops.items()):
                if args.states and sid not in args.states:
                    continue
                image = remover(crop) if remover is not None else crop
                if remover is not None and sid in cfg["sheet"].get("single_figure_states", []):
                    image = keep_main_figure(image)
                out = ROOT / cfg["out_dir"] / cid / f"{sid}.png"
                out.parent.mkdir(parents=True, exist_ok=True)
                image.save(out, format="PNG")
                meta = {
                    "id": f"sprite_{cid}_{sid}",
                    "prompt": prompt,
                    "negative_prompt": neg_c,
                    "seed": int(c["seed"]),
                    "steps": steps,
                    "cfg_scale": guidance,
                    "sampler": manifest["sampler"],
                    "resolution": "%dx%d sheet, cell %d of %d" % (
                        sheet_img.width, sheet_img.height, k + 1, len(crops)),
                    "mode": "sheet",
                    "pose_control": cfg["control_model"],
                    "reference": reference_note(cfg, c),
                    "cutout": None if remover is None else cfg.get("cutout_model", "isnet-general-use"),
                    "model": manifest["model"],
                    "generator": "tools/sd_sprites.py (diffusers)",
                    "timestamp": datetime.now(timezone.utc).isoformat(timespec="seconds"),
                }
                if sid in cfg["sheet"].get("redo_states", []):
                    meta["redo"] = {
                        "prompt": redo_prompt(cfg, manifest, c, sid), "seed": redo_seed(cfg, c, sid),
                        "mode": ("txt2img" if next(x for x in cfg["states"] if x["id"] == sid).get("redo_mode") == "txt"
                                 else "img2img from the sheet cell") + " + openpose + portrait",
                        "strength": float(next(x for x in cfg["states"] if x["id"] == sid).get("redo_strength", 0.75)),
                    }
                out.with_suffix(".metadata.json").write_text(
                    json.dumps(meta, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
                )
            print(f"[{i}/{len(todo)}] {cid}: sheet of {len(crops)} poses ({time.time() - t0:.0f}s)", flush=True)
            continue
        cid, sid = c["id"], s["id"]
        out = ROOT / cfg["out_dir"] / cid / f"{sid}.png"
        raw_path = CACHE / cid / "idle_raw.png"
        seed = int(c["seed"]) + state_ids.index(sid)
        pose_text = s.get("beast_pose", s["pose"]) if c.get("body") == "beast" else s["pose"]
        pose_text = pose_text.replace("{weapon}", c.get("weapon", "a weapon"))
        prompt = cfg["prompt_template"].format(look=c["look"], pose=pose_text, style=cfg.get("style", manifest["style_suffix"]))
        gen = torch.Generator(device="cpu").manual_seed(seed)
        t0 = time.time()
        beast = c.get("body", "humanoid") == "beast"
        pose_img = None
        if not beast and sid in skeletons:
            pose_img = draw_skeleton(skeletons[sid], (w, h))
        neg_c = f'{c["negative_extra"]}, {negative}' if c.get("negative_extra") else negative
        common = dict(negative_prompt=neg_c, num_inference_steps=steps, guidance_scale=guidance, generator=gen)
        ref_img = reference_image(cfg, c)
        if ref_img is not None:
            common["ip_adapter_image"] = ref_img
        if s["mode"] == "txt2img":
            if pose_img is not None:
                image = pipes["txt_pose"](prompt=prompt, image=pose_img, width=w, height=h,
                                          controlnet_conditioning_scale=control_scale, **common).images[0]
            else:
                image = pipes["txt"](prompt=prompt, width=w, height=h, **common).images[0]
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
                idle_prompt = cfg["prompt_template"].format(look=c["look"], pose=idle["pose"], style=cfg.get("style", manifest["style_suffix"]))
                idle_gen = dict(common, generator=torch.Generator(device="cpu").manual_seed(int(c["seed"])))
                if not beast and "idle" in skeletons:
                    base = pipes["txt_pose"](prompt=idle_prompt, image=draw_skeleton(skeletons["idle"], (w, h)),
                                             width=w, height=h, controlnet_conditioning_scale=control_scale,
                                             **idle_gen).images[0]
                else:
                    base = pipes["txt"](prompt=idle_prompt, width=w, height=h, **idle_gen).images[0]
                raw_path.parent.mkdir(parents=True, exist_ok=True)
                base.save(raw_path)
            raw_cache[cid] = base
            strength = float(s.get("beast_strength", s["strength"])) if beast else float(s["strength"])
            if pose_img is not None:
                image = pipes["img_pose"](prompt=prompt, image=base, control_image=pose_img, strength=strength,
                                          controlnet_conditioning_scale=control_scale, **common).images[0]
            else:
                image = pipes["img"](prompt=prompt, image=base, strength=strength, **common).images[0]
        if remover is not None:
            image = remover(image)
        out.parent.mkdir(parents=True, exist_ok=True)
        image.save(out, format="PNG")
        meta = {
            "id": f"sprite_{cid}_{sid}",
            "prompt": prompt,
            "negative_prompt": neg_c,
            "seed": seed,
            "steps": steps,
            "cfg_scale": guidance,
            "sampler": manifest["sampler"],
            "resolution": f"{w}x{h}",
            "mode": s["mode"],
            "strength": None if s["mode"] == "txt2img" else (
                s.get("beast_strength", s.get("strength")) if c.get("body") == "beast" else s.get("strength")
            ),
            "pose_control": None if (c.get("body") == "beast" or sid not in skeletons) else cfg["control_model"],
            "init_image": None if s["mode"] == "txt2img" else "idle (same character, before cutout)",
            "reference": reference_note(cfg, c),
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
