#!/usr/bin/env python3
"""
Optional: call Automatic1111-style txt2img API and save PNGs into assets/.

Uses stdlib only (urllib). Server: http://127.0.0.1:7860 with API enabled (e.g. webui.py --api).

Writes a sibling `.metadata.json` next to each PNG for reproducible asset generation.

Usage:
  python tools/sd_export.py --out assets/ui_bg/hub_bg.png --prompt "your subject..."
"""

from __future__ import annotations

import argparse
import base64
import json
import os
import random
import sys
import urllib.error
import urllib.request
from datetime import datetime

DEFAULT_URL = "http://127.0.0.1:7860/sdapi/v1/txt2img"

def _load_style() -> tuple[str, str, str]:
    """Style comes from tools/art_manifest.json so every tool produces the same look."""
    manifest = os.path.join(os.path.dirname(os.path.abspath(__file__)), "art_manifest.json")
    with open(manifest, encoding="utf-8") as f:
        m = json.load(f)
    return m["style_suffix"], m["negative_prompt"], m.get("prompt_template", "{subject}, {style}")


STYLE_SUFFIX, NEGATIVE, PROMPT_TEMPLATE = _load_style()


def _parse_info(body: dict) -> dict:
    """Parse A1111 `info` field safely; return empty dict if missing or malformed."""
    raw = body.get("info")
    if raw is None:
        return {}
    if isinstance(raw, dict):
        return raw
    if not isinstance(raw, str) or not raw.strip():
        return {}
    try:
        parsed = json.loads(raw)
        return parsed if isinstance(parsed, dict) else {}
    except (json.JSONDecodeError, TypeError):
        return {}


def _metadata_json_path(image_path: str) -> str:
    """Same basename as PNG, extension `.metadata.json` (handles `.png` suffix once)."""
    root, ext = os.path.splitext(image_path)
    if ext.lower() == ".png":
        return root + ".metadata.json"
    return image_path + ".metadata.json"


def main() -> int:
    ap = argparse.ArgumentParser(description="SD txt2img -> PNG + metadata (A1111 API)")
    ap.add_argument("--url", default=DEFAULT_URL, help="Full txt2img URL")
    ap.add_argument("--out", required=True, help="Output PNG path (under repo)")
    ap.add_argument("--prompt", required=True, help="Subject prompt")
    ap.add_argument("--negative", default=NEGATIVE)
    ap.add_argument("--width", type=int, default=768)
    ap.add_argument("--height", type=int, default=512)
    ap.add_argument("--steps", type=int, default=28)
    ap.add_argument("--cfg", type=float, default=7.0)
    ap.add_argument(
        "--seed",
        type=int,
        default=None,
        help="RNG seed (if omitted, a random seed is chosen and logged)",
    )
    args = ap.parse_args()

    if args.seed is not None:
        request_seed = args.seed
    else:
        request_seed = random.randint(0, 2**32 - 1)
        print(f"Using random seed: {request_seed}", file=sys.stderr)

    full_prompt = PROMPT_TEMPLATE.format(subject=args.prompt.strip(), style=STYLE_SUFFIX)
    payload = {
        "prompt": full_prompt,
        "negative_prompt": args.negative,
        "steps": args.steps,
        "width": args.width,
        "height": args.height,
        "cfg_scale": args.cfg,
        "seed": request_seed,
        "save_images": False,
    }
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        args.url,
        data=data,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=600) as resp:
            body = json.loads(resp.read().decode("utf-8"))
    except urllib.error.URLError as e:
        print("Request failed:", e, file=sys.stderr)
        print(
            "Hint: enable API in Automatic1111, or fix URL for your UI.",
            file=sys.stderr,
        )
        return 1

    images = body.get("images") or []
    if not images:
        print("No images in response:", body.keys(), file=sys.stderr)
        return 1

    info_dict = _parse_info(body)

    def _seed_final() -> int:
        s = info_dict.get("seed")
        if s is not None:
            try:
                return int(s)
            except (TypeError, ValueError):
                pass
        return int(request_seed)

    seed_stored = _seed_final()

    metadata = {
        "prompt": info_dict.get("prompt") or full_prompt,
        "negative_prompt": info_dict.get("negative_prompt") or args.negative,
        "seed": seed_stored,
        "sampler": info_dict.get("sampler_name"),
        "steps": info_dict.get("steps") if info_dict.get("steps") is not None else args.steps,
        "cfg_scale": info_dict.get("cfg_scale")
        if info_dict.get("cfg_scale") is not None
        else args.cfg,
        "width": info_dict.get("width") if info_dict.get("width") is not None else args.width,
        "height": info_dict.get("height") if info_dict.get("height") is not None else args.height,
        "model": info_dict.get("sd_model_name"),
        "timestamp": datetime.utcnow().isoformat(),
    }

    raw = base64.b64decode(images[0])
    out = os.path.abspath(args.out)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "wb") as f:
        f.write(raw)

    json_path = _metadata_json_path(out)
    with open(json_path, "w", encoding="utf-8") as f:
        json.dump(metadata, f, indent=2)
        f.write("\n")

    print("Saved:")
    print(f"- image: {out}")
    print(f"- metadata: {json_path}")
    print(f"- seed: {seed_stored}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
