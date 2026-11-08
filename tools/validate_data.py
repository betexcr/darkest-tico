#!/usr/bin/env python3
"""
Validate game data JSON without needing Godot installed.

Checks that JSON parses and that cross-references resolve:
  - hero skill_ids -> data/skills.json, camp_skill_ids -> data/camp_skills.json
  - data/camp_skills.json (targets, effects, mods, cures, class lists) and data/progression.json
  - data/statuses.json mental_mods -> Quebranto/Virtud ids in scripts/domain/stress_system.gd
  - region start/objective nodes, edges, enemy_id -> nodes / data/enemies.json
    (regions with a "generator" block: enemy pools and boss -> data/enemies.json)
  - every non-start region node is reachable from start_node
  - assets/**/*.png have a sibling .metadata.json (warning only; see .cursor/rules/stable-diffusion-assets.mdc)
  - data/items.json: valid usable/target values, starter inventory refs
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

    statuses_raw = load(DATA / "statuses.json") or {}
    status_defs = statuses_raw.get("statuses", {})
    ailments = {k for k, v in status_defs.items() if v.get("kind") == "negative"}
    stat_keys = {"accuracy", "dodge", "speed", "crit", "prot", "dmg_pct", "stress_pct"}
    for k, v in status_defs.items():
        for f in ("name", "kind", "description", "color"):
            if not v.get(f):
                errors.append(f"statuses.json: '{k}' missing '{f}'")

    def check_applies(where: str, v) -> None:
        for ap in ([v] if isinstance(v, dict) else (v or [])):
            if ap.get("status") not in status_defs:
                errors.append(f"{where}: applies unknown status '{ap.get('status')}'")
            for mk in (ap.get("mods") or {}):
                if mk not in stat_keys:
                    errors.append(f"{where}: unknown stat '{mk}' in mods")

    skills = as_id_map(load(skills_path), "skills", skills_path)
    camp_raw = load(DATA / "camp_skills.json") or {}
    camp_skills = {c.get("id"): c for c in camp_raw.get("skills", [])}
    neg_or_all = set(ailments) | {"all_negative"}

    def check_camp_effects(where: str, eff: dict) -> None:
        for k in eff:
            if k not in ("stress", "heal_pct", "cure", "buff"):
                errors.append(f"{where}: unknown effect '{k}'")
        for c in eff.get("cure", []):
            if c not in neg_or_all:
                errors.append(f"{where}: cures unknown status '{c}'")
        buff = eff.get("buff")
        if buff is not None:
            if not buff.get("mods") or int(buff.get("fights", 0)) < 1:
                errors.append(f"{where}: buff needs mods and fights >= 1")
            for mk in buff.get("mods", {}):
                if mk not in stat_keys:
                    errors.append(f"{where}: unknown stat '{mk}' in buff mods")

    if len(camp_skills) != len(camp_raw.get("skills", [])):
        errors.append("camp_skills.json: duplicate skill ids")
    for cid, c in camp_skills.items():
        where = f"camp_skills.json: '{cid}'"
        if not c.get("name") or not c.get("desc"):
            errors.append(f"{where} needs name and desc")
        if c.get("target") not in ("self", "ally", "others", "party"):
            errors.append(f"{where} has invalid target '{c.get('target')}'")
        if not 1 <= int(c.get("cost", 0)) <= int(camp_raw.get("respite_points", 12)):
            errors.append(f"{where} cost must be 1..respite_points")
        if not c.get("classes"):
            errors.append(f"{where} needs a classes list")
        check_camp_effects(where, c.get("effects", {}))
        check_camp_effects(where + " self", c.get("self_effects", {}))
    for m in camp_raw.get("meals", []):
        if int(m.get("food", -1)) < 0 or not m.get("name"):
            errors.append(f"camp_skills.json: meal '{m.get('id')}' needs name and food >= 0")

    prog = load(DATA / "progression.json") or {}
    thr = prog.get("resolve", {}).get("xp_thresholds", [])
    if len(thr) != 7 or thr != sorted(thr) or (thr and thr[0] != 0):
        errors.append("progression.json: xp_thresholds must be 7 rising values starting at 0")
    if len(prog.get("resolve", {}).get("level_names", [])) != 7:
        errors.append("progression.json: level_names needs 7 names (levels 0-6)")
    for k in prog.get("resolve", {}).get("resist_per_level", {}):
        if k not in {c["id"] for c in statuses_raw.get("resist_categories", [])}:
            errors.append(f"progression.json: resist_per_level unknown category '{k}'")
    for d in prog.get("difficulties", []):
        if not (0 <= d.get("min_level", -1) <= d.get("level", -1) <= d.get("max_level", -1) <= 6):
            errors.append(f"progression.json: difficulty '{d.get('id')}' needs 0 <= min_level <= level <= max_level <= 6")
        if int(d.get("xp", 0)) <= 0:
            errors.append(f"progression.json: difficulty '{d.get('id')}' needs xp > 0")
    if not prog.get("difficulties"):
        errors.append("progression.json: no difficulties")
    # Region levels (doc 05 §4): every region has one, Sótanos is the easiest.
    region_levels = {}
    for rp in sorted((DATA / "regions").glob("*.json")):
        rl = (load(rp) or {}).get("region_level")
        if not isinstance(rl, int) or rl < 0:
            errors.append(f"regions/{rp.name}: needs region_level (int >= 0)")
        else:
            region_levels[rp.stem] = rl
    if "sotanos" in region_levels and region_levels["sotanos"] != min(region_levels.values()):
        errors.append("regions: Sótanos must have the lowest region_level")

    stress_src = (ROOT / "scripts/domain/stress_system.gd").read_text(encoding="utf-8")
    mental_ids = set()
    for const in ("AFFLICTIONS", "VIRTUDES"):
        line = next((l for l in stress_src.splitlines() if l.startswith(f"const {const}")), "")
        mental_ids |= set(x.strip(' "') for x in line.split("[", 1)[-1].rstrip("]").split(","))
    for mid, mods in statuses_raw.get("mental_mods", {}).items():
        if mid not in mental_ids:
            errors.append(f"statuses.json: mental_mods '{mid}' is not a Quebranto/Virtud")
        for mk in mods:
            if mk not in stat_keys | {"deathblow"}:
                errors.append(f"statuses.json: mental_mods '{mid}' unknown stat '{mk}'")
    heroes = as_id_map(load(heroes_path), "heroes", heroes_path)
    enemies = as_id_map(load(enemies_path), "enemies", enemies_path)

    # Owner rule (2026-11-07): one basic attack + 1-3 specials; one special magical or ailment.
    for eid, en in enemies.items():
        eskills = en.get("skills", [])
        basics = [x for x in eskills if x.get("basic")]
        specials = [x for x in eskills if not x.get("basic")]
        if len(basics) != 1:
            errors.append(f"enemies.json: '{eid}' needs exactly one basic attack (has {len(basics)})")
        if not 1 <= len(specials) <= 3:
            errors.append(f"enemies.json: '{eid}' needs 1-3 special abilities (has {len(specials)})")
        if specials and not any(x.get("type") == "magical" or x.get("applies") for x in specials):
            errors.append(f"enemies.json: '{eid}' needs a magical or ailment special")
        known_el = {"fuego", "hielo", "rayo", "agua", "tierra", "viento", "sagrado", "oscuridad"}
        if not en.get("elements"):
            errors.append(f"enemies.json: '{eid}' needs elemental affinities (owner rule)")
        for st in (en.get("status_resist") or {}):
            if st not in ailments:
                errors.append(f"enemies.json: '{eid}' resists unknown status '{st}'")
        for e in en.get("elements", {}):
            if e not in known_el:
                errors.append(f"enemies.json: '{eid}' has unknown element '{e}'")
        for x in eskills:
            if x.get("element") and x["element"] not in known_el:
                errors.append(f"enemies.json: '{eid}.{x.get('id')}' has unknown element")
            if x.get("type") not in ("physical", "magical"):
                errors.append(f"enemies.json: '{eid}.{x.get('id')}' has invalid type")
            check_applies(f"enemies.json: '{eid}.{x.get('id')}'", x.get("applies"))
            check_applies(f"enemies.json: '{eid}.{x.get('id')}' self", x.get("self_applies"))
            if not x.get("name"):
                errors.append(f"enemies.json: '{eid}.{x.get('id')}' has no name")

    for sid, sk in skills.items():
        if sk.get("kind") not in ("attack", "heal", "buff"):
            errors.append(f"skills.json: '{sid}' has invalid kind '{sk.get('kind')}'")
        if sk.get("target", "self") not in ("enemy", "self", "ally", "party"):
            errors.append(f"skills.json: '{sid}' has invalid target '{sk.get('target')}'")
        check_applies(f"skills.json: '{sid}'", sk.get("applies"))
        check_applies(f"skills.json: '{sid}' self", sk.get("self_applies"))
        for c in sk.get("cure", []):
            if c not in status_defs:
                errors.append(f"skills.json: '{sid}' cures unknown status '{c}'")
    res_ids = {c["id"] for c in statuses_raw.get("resist_categories", [])}
    for hid, hero in heroes.items():
        for k in hero.get("status_resist", {}):
            if k not in res_ids:
                errors.append(f"heroes.json: '{hid}' resists unknown category '{k}'")
        for sid in hero.get("skill_ids", []):
            if sid not in skills:
                errors.append(f"heroes.json: hero '{hid}' references unknown skill '{sid}'")
        # Owner rule (2026-11-07): every class has a skill that helps an ally or the party.
        if not any(skills.get(s, {}).get("target") in ("ally", "party") for s in hero.get("skill_ids", [])):
            errors.append(f"heroes.json: hero '{hid}' has no ally or party skill")
        # Camping (P3-07): 4 camp skills, each usable by the class (or shared "*").
        cids = hero.get("camp_skill_ids", [])
        if len(cids) != 4:
            errors.append(f"heroes.json: hero '{hid}' needs 4 camp_skill_ids (has {len(cids)})")
        for cid in cids:
            csk = camp_skills.get(cid)
            if csk is None:
                errors.append(f"heroes.json: hero '{hid}' references unknown camp skill '{cid}'")
            elif "*" not in csk.get("classes", []) and hero.get("class_id") not in csk.get("classes", []):
                errors.append(f"heroes.json: hero '{hid}' can't use camp skill '{cid}' (class list)")

    for region_path in sorted((DATA / "regions").glob("*.json")):
        rel = region_path.relative_to(ROOT)
        region = load(region_path)
        if region is None:
            continue
        gen = region.get("generator")
        if gen is not None:
            for key in ("enemy_pool", "elite_pool"):
                for eid in gen.get(key, []):
                    if eid not in enemies:
                        errors.append(f"{rel}: generator.{key} references unknown enemy '{eid}'")
            boss = gen.get("boss_enemy_id")
            if boss not in enemies:
                errors.append(f"{rel}: generator.boss_enemy_id '{boss}' is not an enemy")
            lo, hi = (gen.get("rooms") or [0, 0])[:2]
            if not (3 <= lo <= hi):
                errors.append(f"{rel}: generator.rooms must be [min, max] with 3 <= min <= max")
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

    items_path = DATA / "items.json"
    items_raw = load(items_path)
    items = as_id_map(items_raw, "items", items_path)
    for iid, it in items.items():
        elements = set((items_raw or {}).get("elements", []))
        if it.get("usable") == "equip":
            if it.get("slot") not in ("weapon", "armor", "accessory"):
                errors.append(f"items.json: '{iid}' has invalid slot '{it.get('slot')}'")
            if it.get("element") and it["element"] not in elements:
                errors.append(f"items.json: '{iid}' has unknown element '{it['element']}'")
            for e in it.get("resist", {}):
                if e not in elements:
                    errors.append(f"items.json: '{iid}' resists unknown element '{e}'")
            res_cats = {c["id"] for c in statuses_raw.get("resist_categories", [])}
            for k in it.get("status_resist", {}):
                if k not in res_cats:
                    errors.append(f"items.json: '{iid}' resists unknown category '{k}'")
            check_applies(f"items.json: '{iid}' on_hit", it.get("on_hit"))
            check_applies(f"items.json: '{iid}' start_status", it.get("start_status"))
            for st in it.get("immune", []):
                if st not in ailments:
                    errors.append(f"items.json: '{iid}' immune to unknown ailment '{st}'")
            continue
        fx = it.get("effects", {})
        if fx.get("element") and fx["element"] not in elements:
            errors.append(f"items.json: '{iid}' damage element '{fx['element']}' unknown")
        check_applies(f"items.json: '{iid}'", fx.get("applies"))
        for c in fx.get("cure", []):
            if c not in status_defs:
                errors.append(f"items.json: '{iid}' cures unknown status '{c}'")
        if it.get("usable") not in ("explore", "combat", "both", "curio"):
            errors.append(f"items.json: '{iid}' has invalid usable '{it.get('usable')}'")
        if it.get("target") not in ("ally", "party", "enemy", "none"):
            errors.append(f"items.json: '{iid}' has invalid target '{it.get('target')}'")
        if int(it.get("uses_per_node", 1)) < 1 or int(it.get("max_stack", 1)) < 1:
            errors.append(f"items.json: '{iid}' needs uses_per_node >= 1 and max_stack >= 1")
    for e in (items_raw or {}).get("starter_inventory", []):
        if e.get("id") not in items:
            errors.append(f"items.json: starter_inventory references unknown item '{e.get('id')}'")

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
        f"\n{len(heroes)} heroes, {len(skills)} skills, {len(enemies)} enemies, {len(items)} items, "
        f"{len(list((DATA / 'regions').glob('*.json')))} regions — "
        f"{len(errors)} error(s), {len(warnings)} warning(s)"
    )
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
