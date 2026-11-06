#!/usr/bin/env python3
"""
Validate game data JSON without needing Godot installed.

Checks that JSON parses and that cross-references resolve:
  - hero skill_ids -> data/skills.json
  - region start/objective nodes, edges, enemy_id -> nodes / data/enemies.json
  - every non-start region node is reachable from start_node
  - assets/**/*.png have a sibling .metadata.json (warning only; see .cursor/rules/stable-diffusion-assets.mdc)
  - tools/art_manifest.json ids are unique, write under assets/, and have been generated (warning)

Usage (from repo root):
  python3 tools/validate_data.py

Exit code 0 = no errors (warnings allowed), 1 = errors found.
Run this before every handoff (see AGENTS.md).
"""

from __future__ import annotations

import json
import sys
from collections import deque
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "data"

errors: list[str] = []
warnings: list[str] = []


def load(path: Path):
    try:
        with path.open(encoding="utf-8") as f:
            return json.load(f)
    except (OSError, json.JSONDecodeError) as exc:
        errors.append(f"{path.relative_to(ROOT)}: cannot load JSON ({exc})")
        return None


def as_id_map(raw, key: str, path: Path) -> dict:
    """Accept either {key: {id: {...}}} or {key: [{id: ...}]}."""
    if raw is None:
        return {}
    block = raw.get(key)
    if isinstance(block, dict):
        return block
    if isinstance(block, list):
        out = {}
        for item in block:
            iid = item.get("id")
            if not iid:
                errors.append(f"{path.relative_to(ROOT)}: entry without id in '{key}'")
                continue
            if iid in out:
                errors.append(f"{path.relative_to(ROOT)}: duplicate id '{iid}'")
            out[iid] = item
        return out
    errors.append(f"{path.relative_to(ROOT)}: missing '{key}' list/dict")
    return {}


def main() -> int:
    skills_path = DATA / "skills.json"
    heroes_path = DATA / "heroes.json"
    enemies_path = DATA / "enemies.json"

    skills = as_id_map(load(skills_path), "skills", skills_path)
    heroes = as_id_map(load(heroes_path), "heroes", heroes_path)
    enemies = as_id_map(load(enemies_path), "enemies", enemies_path)

    for hid, hero in heroes.items():
        for sid in hero.get("skill_ids", []):
            if sid not in skills:
                errors.append(f"heroes.json: hero '{hid}' references unknown skill '{sid}'")

    for region_path in sorted((DATA / "regions").glob("*.json")):
        rel = region_path.relative_to(ROOT)
        region = load(region_path)
        if region is None:
            continue
        nodes = {}
        for n in region.get("nodes", []):
            nid = n.get("id")
            if not nid:
                errors.append(f"{rel}: node without id")
                continue
            if nid in nodes:
                errors.append(f"{rel}: duplicate node id '{nid}'")
            nodes[nid] = n
            if n.get("type") == "combat":
                eid = n.get("enemy_id", "")
                if eid not in enemies:
                    errors.append(f"{rel}: node '{nid}' references unknown enemy '{eid}'")
        for key in ("start_node", "objective_node"):
            if region.get(key) not in nodes:
                errors.append(f"{rel}: {key} '{region.get(key)}' is not a node")
        adj: dict[str, set] = {nid: set() for nid in nodes}
        for e in region.get("edges", []):
            a, b = e.get("from"), e.get("to")
            if a not in nodes or b not in nodes:
                errors.append(f"{rel}: edge {a}->{b} references a missing node")
                continue
            adj[a].add(b)
            adj[b].add(a)
        start = region.get("start_node")
        if start in nodes:
            seen = {start}
            q = deque([start])
            while q:
                cur = q.popleft()
                for nxt in adj[cur]:
                    if nxt not in seen:
                        seen.add(nxt)
                        q.append(nxt)
            for nid in nodes:
                if nid not in seen:
                    errors.append(f"{rel}: node '{nid}' unreachable from start")

    for png in sorted((ROOT / "assets").rglob("*.png")):
        meta = png.with_suffix(".metadata.json")
        if not meta.exists():
            warnings.append(f"{png.relative_to(ROOT)}: no .metadata.json (placeholder?)")

    manifest_path = ROOT / "tools" / "art_manifest.json"
    manifest = load(manifest_path)
    if manifest:
        seen_ids: set = set()
        for a in manifest.get("assets", []):
            aid, out = a.get("id"), a.get("out", "")
            if aid in seen_ids:
                errors.append(f"art_manifest.json: duplicate id '{aid}'")
            seen_ids.add(aid)
            if not out.startswith("assets/"):
                errors.append(f"art_manifest.json: '{aid}' writes outside assets/ ({out})")
            elif not (ROOT / out).exists():
                warnings.append(f"art_manifest.json: '{aid}' not generated yet ({out})")

    for w in warnings:
        print(f"WARN  {w}")
    for e in errors:
        print(f"ERROR {e}")
    print(
        f"\n{len(heroes)} heroes, {len(skills)} skills, {len(enemies)} enemies, "
        f"{len(list((DATA / 'regions').glob('*.json')))} regions — "
        f"{len(errors)} error(s), {len(warnings)} warning(s)"
    )
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
