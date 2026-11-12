#!/usr/bin/env python3
"""
Validate game data JSON without needing Godot installed.

Checks that JSON parses and that cross-references resolve:
  - hero skill_ids -> data/skills.json, camp_skill_ids -> data/camp_skills.json
  - data/camp_skills.json (targets, effects, mods, cures, class lists) and data/progression.json
  - data/statuses.json mental_mods -> Quebranto/Virtud ids in scripts/domain/stress_system.gd
  - data/town_events.json: effect keys, categories, services, item/class/region references
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
import re
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
    # Casa Comunal skill ranks (doc 02 §4, doc 04 §3.3); keys match skill_ranks.gd BONUS_KEYS.
    rank_keys = {"damage_min", "damage_max", "skill_accuracy", "skill_crit", "heal_min", "heal_max",
                 "stress_relief", "status_chance", "status_value", "status_mods"}
    sr = prog.get("skill_ranks", {})
    max_rank = int(sr.get("max_rank", 0))
    if max_rank < 2:
        errors.append("progression.json: skill_ranks.max_rank must be at least 2")
    costs = sr.get("costs", [])
    if len(costs) != max_rank + 1 or any(costs[r] <= costs[r - 1] for r in range(3, len(costs))) \
            or any(int(c) <= 0 for c in costs[2:]):
        errors.append("progression.json: skill_ranks.costs needs max_rank + 1 entries, rising and > 0 from rank 2")
    mres = sr.get("min_resolve", [])
    if len(mres) != max_rank + 1 or mres[2:] != sorted(mres[2:]) or any(not 0 <= int(m) <= 6 for m in mres):
        errors.append("progression.json: skill_ranks.min_resolve needs max_rank + 1 entries, non-decreasing, 0-6")
    for k in sr.get("per_rank", {}):
        if k not in rank_keys:
            errors.append(f"progression.json: skill_ranks.per_rank unknown key '{k}'")
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

    # Town events (docs/02 §12): known effect keys, valid references.
    te_raw = load(DATA / "town_events.json") or {}
    te_ids = set()
    item_map = {i.get("id"): i for i in (load(DATA / "items.json") or {}).get("items", [])}
    class_ids = {h.get("class_id") for h in (load(DATA / "heroes.json") or {}).get("heroes", [])}
    region_ids = {rp.stem for rp in (DATA / "regions").glob("*.json")}
    fx_keys = {"price_pct", "first_buy_pct", "sell_rate", "blocked_items", "closed", "service_pct", "relief_pct",
               "gift_colones", "gift_item", "idle_stress", "idle_cure_quebranto", "all_cure_quebranto",
               "idle_class_level", "add_recruits", "extra_recruits", "add_roster_free", "hire_veteran",
               "resurrect", "steal_items", "offer", "mission"}
    mission_keys = {"region", "xp_pct", "dmg_pct", "virtue_pct", "light_decay_pct", "loot_pct", "items_pct",
                    "firewood", "no_level_limits", "tough", "treasure", "quebranto_start_stress"}
    cats = {"consumable", "healing", "weapon", "armor", "accessory"}
    services = {"iglesia", "ebais", "terminal", "pulperia_compra", "pulperia_venta", "casa_comunal"}
    for ev in te_raw.get("events", []):
        eid = ev.get("id")
        where = f"town_events.json: '{eid}'"
        if eid in te_ids:
            errors.append(f"{where} duplicate id")
        te_ids.add(eid)
        for f in ("name", "text", "kind", "category", "dd"):
            if not ev.get(f):
                errors.append(f"{where} missing '{f}'")
        if ev.get("kind") not in ("positive", "negative", "special"):
            errors.append(f"{where} invalid kind")
        fx = ev.get("effects", {})
        if not fx:
            errors.append(f"{where} has no effects")
        for k in fx:
            if k not in fx_keys:
                errors.append(f"{where} unknown effect '{k}'")
        for grp in ("price_pct", "first_buy_pct", "sell_rate"):
            for k in fx.get(grp, {}):
                if k not in cats:
                    errors.append(f"{where} {grp}: unknown category '{k}'")
        for c in fx.get("closed", []) + list(fx.get("service_pct", {})):
            if c not in services:
                errors.append(f"{where} unknown service '{c}'")
        for iid in fx.get("blocked_items", []):
            if iid not in item_map:
                errors.append(f"{where} blocks unknown item '{iid}'")
        if fx.get("gift_item") and fx["gift_item"] not in ("weapon", "armor", "accessory"):
            errors.append(f"{where} gift_item must be weapon/armor/accessory")
        for k in ("idle_class_level",):
            if k in fx and fx[k] not in class_ids:
                errors.append(f"{where} unknown class '{fx[k]}'")
        if "add_recruits" in fx and fx["add_recruits"].get("class") not in class_ids:
            errors.append(f"{where} add_recruits: unknown class")
        m = fx.get("mission", {})
        for k in m:
            if k not in mission_keys:
                errors.append(f"{where} unknown mission key '{k}'")
        if m.get("region") and m["region"] not in region_ids:
            errors.append(f"{where} unknown region '{m['region']}'")
    if not 0 <= int(te_raw.get("chance_pct", -1)) <= 100:
        errors.append("town_events.json: chance_pct must be 0-100")

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
        cat_ids = {c["id"] for c in statuses_raw.get("resist_categories", [])}
        for st in (en.get("status_resist") or {}):
            if st not in ailments and st not in cat_ids:
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
        for k in sk.get("rank_bonus", {}):
            if k not in rank_keys:
                errors.append(f"skills.json: '{sid}' rank_bonus unknown key '{k}'")
    res_ids = {c["id"] for c in statuses_raw.get("resist_categories", [])}
    # Owner rule (2026-11-11): every class has its own skills, starting with its own basic
    # attack (the first skill, kind attack). No skill id is shared by two classes.
    skill_owner = {}
    for hid, hero in heroes.items():
        for sid in hero.get("skill_ids", []):
            if sid in skill_owner and skill_owner[sid] != hid:
                errors.append(f"heroes.json: skill '{sid}' is used by both '{skill_owner[sid]}' and '{hid}'")
            skill_owner.setdefault(sid, hid)
        first = hero.get("skill_ids", [None])[0] if hero.get("skill_ids") else None
        if skills.get(first, {}).get("kind") != "attack":
            errors.append(f"heroes.json: hero '{hid}' must start with its basic attack (first skill, kind attack)")

    # Forced moves (P1-03b): move_target / shuffle_target only on skills that hit one unit on
    # the other side; status "resist" aliases must name a resist category.
    cat_ids_all = {c["id"] for c in statuses_raw.get("resist_categories", [])}
    for sid_, st_ in status_defs.items():
        if "resist" in st_ and st_["resist"] not in cat_ids_all:
            errors.append(f"statuses.json: '{sid_}' resist alias '{st_['resist']}' is not a resist category")

    def check_moves(where: str, x: dict, single: bool) -> None:
        if "move_target" in x:
            mt = x["move_target"]
            if not isinstance(mt, int) or isinstance(mt, bool) or mt == 0 or not -3 <= mt <= 3:
                errors.append(f"{where}: move_target must be a non-zero int in -3..3")
        if "shuffle_target" in x and not isinstance(x["shuffle_target"], bool):
            errors.append(f"{where}: shuffle_target must be true/false")
        if ("move_target" in x or x.get("shuffle_target")) and not single:
            errors.append(f"{where}: move_target/shuffle_target only on single-target skills that hit the other side")

    for sid_, sk_ in skills.items():
        check_moves(f"skills.json: '{sid_}'", sk_, sk_.get("target") == "enemy")
    for eid_, en_ in enemies.items():
        for x in en_.get("skills", []):
            check_moves(f"enemies.json: '{eid_}.{x.get('id')}'", x, x.get("target", "single") != "party")

    # Formation (P1-03a): battlefield positions 1-4 (1 = front). See scripts/domain/formation.gd.
    def positions_ok(v):
        return isinstance(v, list) and len(v) > 0 and all(isinstance(p, int) and 1 <= p <= 4 for p in v) \
            and len(set(v)) == len(v)

    for sid, sk in skills.items():
        if not positions_ok(sk.get("use_ranks")):
            errors.append(f"skills.json: '{sid}' needs use_ranks (positions 1-4)")
        if sk.get("target") == "enemy" and not positions_ok(sk.get("target_ranks")):
            errors.append(f"skills.json: '{sid}' (enemy target) needs target_ranks (positions 1-4)")
        if sk.get("target") != "enemy" and "target_ranks" in sk:
            errors.append(f"skills.json: '{sid}' has target_ranks but does not target an enemy")
    for hid, hero in heroes.items():
        if not positions_ok(hero.get("ranks")):
            errors.append(f"heroes.json: '{hid}' needs ranks (preferred positions 1-4)")
            continue
        # Never stuck: from one of its own positions the class can hit enemy position 1.
        if not any(skills.get(s, {}).get("kind") == "attack"
                   and set(skills[s].get("use_ranks", [])) & set(hero["ranks"])
                   and 1 in skills[s].get("target_ranks", [])
                   for s in hero.get("skill_ids", []) if s in skills):
            errors.append(f"heroes.json: '{hid}' has no attack that reaches enemy position 1 from its own positions")
    for eid, en in enemies.items():
        if not positions_ok(en.get("ranks")):
            errors.append(f"enemies.json: '{eid}' needs ranks (preferred positions 1-4)")
        reach1 = False
        for x in en.get("skills", []):
            where = f"enemies.json: '{eid}.{x.get('id')}'"
            if "use_ranks" in x and not positions_ok(x["use_ranks"]):
                errors.append(f"{where} use_ranks must be positions 1-4")
            if x.get("target", "single") == "party":
                reach1 = reach1 or "use_ranks" not in x
                continue
            if not positions_ok(x.get("target_ranks")):
                errors.append(f"{where} (single target) needs target_ranks (positions 1-4)")
            elif 1 in x["target_ranks"] and "use_ranks" not in x:
                reach1 = True
        # Never stuck: from any position, the enemy can hit the hero in position 1 (or everyone).
        if not reach1:
            errors.append(f"enemies.json: '{eid}' needs a skill usable anywhere that reaches hero position 1 (or a party skill)")
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

    check_balance(errors)
    check_domain_magic_numbers(errors)

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


# --- P1-06: data/balance.json ------------------------------------------------------------
# Every key the code reads (scripts/domain/balance.gd paths) and what it may hold:
# "chance" 0-1, "pct" 0-100 points, "pos" > 0 number, "int>=0" whole number, "mult" > 0.
BALANCE_KEYS = {
    "combat.hit_base": "chance", "combat.hit_per_point": "chance", "combat.hit_min": "chance",
    "combat.hit_max": "chance", "combat.initiative_jitter": "int>=0", "combat.crit_cap": "chance",
    "combat.crit_mult": "mult", "combat.prot_cap": "pct", "combat.guard_mult": "chance",
    "combat.miss_stress": "int>=0", "combat.encarrerado_turns": "int>=0", "combat.enemy_base_crit": "pct",
    "crits.party_relief": "int>=0", "crits.enemy_crit_stress": "int>=0",
    "death.base": "pct", "death.check_penalty": "int>=0", "death.collapse_penalty": "int>=0",
    "stress.resolve_threshold": "pos", "stress.colapso": "pos", "stress.colapso_survive": "int>=0",
    "stress.quebranto_chance": "chance", "stress.virtud_reset": "int>=0",
    "stress.stress_resist_min": "int", "stress.stress_resist_max": "pct", "stress.status_resist_cap": "pct",
    "afflictions.paranoia_refuse": "chance", "afflictions.cobardia_skip": "chance",
    "afflictions.cobardia_stress": "int>=0", "afflictions.ira_ciega_chance": "chance",
    "afflictions.ira_ciega_self_stress": "int>=0", "afflictions.bravata_chance": "chance",
    "afflictions.bravata_light": "int>=0", "afflictions.desesperanza_chance": "chance",
    "afflictions.desesperanza_stress": "int>=0", "afflictions.serenidad_mult": "mult",
    "afflictions.esperanza_relief": "int>=0", "afflictions.vigor_regen": "int>=0",
    "afflictions.abnegacion_chance": "chance",
    "enemies.boss_hp_mult": "mult", "enemies.elite_hp_mult": "mult",
    "hub.start_colones": "int>=0", "hub.sell_rate": "chance", "hub.heal_cost_per_hp": "int>=0",
    "hub.heal_min_cost": "int>=0", "hub.iglesia_cost": "int>=0", "hub.iglesia_relief": "int>=0",
    "hub.iglesia_backfire_chance": "chance", "hub.iglesia_backfire_stress": "int>=0",
    "limits.roster_cap": "pos", "limits.inventory_slots": "pos", "limits.recruit_pool": "pos",
    "limits.graveyard_cap": "pos", "light.max": "pos",
}


def check_balance(errors: list) -> None:
    bal = load(DATA / "balance.json")
    if not bal:
        errors.append("balance.json: missing or invalid")
        return

    def get(path):
        node = bal
        for part in path.split("."):
            if not isinstance(node, dict) or part not in node:
                return None
            node = node[part]
        return node

    for path, kind in BALANCE_KEYS.items():
        v = get(path)
        num = isinstance(v, (int, float)) and not isinstance(v, bool)
        ok = num and {
            "chance": lambda x: 0 <= x <= 1,
            "pct": lambda x: 0 <= x <= 100,
            "pos": lambda x: x > 0,
            "int>=0": lambda x: x >= 0 and float(x).is_integer(),
            "int": lambda x: float(x).is_integer(),
            "mult": lambda x: x > 0,
        }[kind](v)
        if not ok:
            errors.append(f"balance.json: '{path}' must be {kind} (is {v!r})")
    if (get("combat.hit_min") or 0) >= (get("combat.hit_max") or 0):
        errors.append("balance.json: combat.hit_min must be below combat.hit_max")
    if not (0 < (get("stress.resolve_threshold") or 0) < (get("stress.colapso") or 0)):
        errors.append("balance.json: need 0 < stress.resolve_threshold < stress.colapso")
    if (get("stress.colapso_survive") or 0) >= (get("stress.colapso") or 0):
        errors.append("balance.json: stress.colapso_survive must be below stress.colapso")
    sp = get("death.stress_penalties")
    if not isinstance(sp, list) or not sp or any(not isinstance(p, list) or len(p) != 2 for p in sp) \
            or [p[0] for p in sp] != sorted(p[0] for p in sp):
        errors.append("balance.json: death.stress_penalties must be [[stress, points], ...] sorted by stress")
    sc = get("enemies.squad_hp_scale")
    if not isinstance(sc, list) or len(sc) != 5 or any(not isinstance(x, (int, float)) or x <= 0 for x in sc):
        errors.append("balance.json: enemies.squad_hp_scale needs 5 positive numbers (squad size 0-4)")
    dmg = get("afflictions.ira_ciega_damage")
    if not isinstance(dmg, list) or len(dmg) != 2 or dmg[0] > dmg[1] or dmg[0] < 0:
        errors.append("balance.json: afflictions.ira_ciega_damage must be [min, max]")
    # Every Balance path used in scripts must be listed above (so it is checked).
    used = set()
    for gd in (ROOT / "scripts").rglob("*.gd"):
        used |= set(re.findall(r'BalanceScript\.(?:num|int_of|arr|value)\("([a-z_.]+)"\)', gd.read_text(encoding="utf-8")))
    arrays = {"death.stress_penalties", "enemies.squad_hp_scale", "afflictions.ira_ciega_damage"}
    for path in sorted(used - set(BALANCE_KEYS) - arrays):
        errors.append(f"balance.json: scripts read '{path}' but the validator doesn't check it (add it to BALANCE_KEYS)")


# "No magic balance numbers left in scripts/domain/" (P1-06). Flags numeric consts and
# numeric .get(..., N) fallbacks other than 0/1; a line may opt out with "# structural".
MAGIC_ALLOW = {"MAX_LEVEL"}


def check_domain_magic_numbers(errors: list) -> None:
    const_re = re.compile(r'^const ([A-Z_]+) := (-?[0-9.]+|\[[-0-9., \[\]]+\])\s*(#.*)?$')
    get_re = re.compile(r'\.get\("[^"]+", (-?[0-9.]+|\[[-0-9., ]+\])\)')
    for gd in sorted((ROOT / "scripts" / "domain").glob("*.gd")):
        for n, line in enumerate(gd.read_text(encoding="utf-8").splitlines(), 1):
            if "# structural" in line or line.lstrip().startswith("#"):
                continue
            m = const_re.match(line)
            if m and m.group(1) not in MAGIC_ALLOW:
                errors.append(f"{gd.relative_to(ROOT)}:{n}: balance const {m.group(1)} belongs in data (or mark '# structural')")
            for g in get_re.finditer(line):
                if g.group(1) not in ("0", "1", "0.0", "1.0", "-1"):
                    errors.append(f"{gd.relative_to(ROOT)}:{n}: numeric fallback {g.group(0)} duplicates data (use Balance.req or mark '# structural')")


if __name__ == "__main__":
    sys.exit(main())
