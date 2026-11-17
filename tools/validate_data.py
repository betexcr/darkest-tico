#!/usr/bin/env python3
"""
Validate game data JSON without needing Godot installed.

Checks that JSON parses and that cross-references resolve:
  - hero skill_ids -> data/skills.json, camp_skill_ids -> data/camp_skills.json
  - data/camp_skills.json (targets, effects, mods, cures, class lists) and data/progression.json
  - data/statuses.json mental_mods -> Quebranto/Virtud ids in scripts/domain/stress_system.gd
  - data/town_events.json: effect keys, categories, services, item/class/region references
  - data/hub_activities.json: Iglesia/Cantina activities (costs, slots, relief, side effects)
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

    if not isinstance(camp_raw.get("no_firewood_relief"), int) or camp_raw["no_firewood_relief"] < 0:
        errors.append("camp_skills.json: no_firewood_relief must be a whole number >= 0")
    amb = camp_raw.get("ambush", {})
    for k in ("base_pct", "low_light_pct", "exhausted_pct", "exhausted_stress"):
        if not isinstance(amb.get(k), int) or amb.get(k) < 0:
            errors.append(f"camp_skills.json: ambush.{k} must be a whole number >= 0")
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
    services = {"iglesia", "cantina", "ebais", "terminal", "pulperia_compra", "pulperia_venta", "casa_comunal"}
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

    # Iglesia Vieja + Cantina activities (doc 02 §7, P3-03).
    ha_raw = load(DATA / "hub_activities.json") or {}
    side_kinds = {"buff", "debuff", "lose_colones", "gain_colones", "lose_item", "extra_week", "stress"}

    def is_range(v):
        return isinstance(v, list) and len(v) == 2 and all(isinstance(x, int) and x >= 0 for x in v) and v[0] <= v[1]

    bids = [b.get("id") for b in ha_raw.get("buildings", [])]
    if sorted(bids) != ["cantina", "iglesia"]:
        errors.append("hub_activities.json: needs exactly the buildings 'iglesia' and 'cantina'")
    for bld in ha_raw.get("buildings", []):
        bw = f"hub_activities.json: '{bld.get('id')}'"
        if not bld.get("name"):
            errors.append(f"{bw} needs a name")
        acts = bld.get("activities", [])
        if len(acts) != 3:
            errors.append(f"{bw} needs 3 activities (doc 02 §7)")
        if len({a.get("id") for a in acts}) != len(acts):
            errors.append(f"{bw} duplicate activity ids")
        for act in acts:
            aw = f"{bw}.{act.get('id')}"
            if not act.get("name") or not act.get("text"):
                errors.append(f"{aw} needs name and text")
            if not isinstance(act.get("cost"), int) or act["cost"] < 0:
                errors.append(f"{aw} cost must be a whole number >= 0")
            if not isinstance(act.get("slots"), int) or act["slots"] < 1:
                errors.append(f"{aw} slots must be a whole number >= 1")
            if not is_range(act.get("relief")) or act["relief"][1] <= 0:
                errors.append(f"{aw} relief must be [min, max] with max > 0")
            sc = act.get("side_chance")
            if not isinstance(sc, (int, float)) or not 0 <= sc <= 1:
                errors.append(f"{aw} side_chance must be 0-1")
            if not act.get("side_effects"):
                errors.append(f"{aw} needs side_effects (doc 02 §7)")
            for se in act.get("side_effects", []):
                k = se.get("kind")
                sw = f"{aw} side effect '{k}'"
                if k not in side_kinds:
                    errors.append(f"{sw}: unknown kind")
                if not isinstance(se.get("weight"), int) or se["weight"] < 1:
                    errors.append(f"{sw}: weight must be a whole number >= 1")
                txt = se.get("text", "")
                need = 2 if k in ("lose_colones", "gain_colones", "lose_item", "stress") else 1
                if txt.count("%") != need:
                    errors.append(f"{sw}: text needs {need} placeholder(s) (hero name first)")
                if k in ("buff", "debuff"):
                    mods = se.get("mods") or {}
                    if not se.get("name") or not mods or not isinstance(se.get("fights"), int) or se["fights"] < 1:
                        errors.append(f"{sw}: needs name, mods and fights >= 1")
                    for mk in mods:
                        if mk not in stat_keys:
                            errors.append(f"{sw}: unknown stat '{mk}'")
                    score = sum(-v if mk == "stress_pct" else v for mk, v in mods.items())
                    if (score < 0) != (k == "debuff"):
                        errors.append(f"{sw}: mods don't match the kind (buff helps, debuff hurts)")
                if k in ("lose_colones", "gain_colones", "stress") and not is_range(se.get("amount")):
                    errors.append(f"{sw}: amount must be [min, max]")

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
            check_moves(f"enemies.json: '{eid_}.{x.get('id')}'", x, x.get("target", "single") not in ("party", "allies"))

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
    def _is_negative_status(a):
        return status_defs.get(a.get("status"), {}).get("kind") == "negative"

    # P2-04 enemy gimmicks (doc 05 §2.6); rules in scripts/combat/combat_controller.gd.
    for eid, en in enemies.items():
        where = f"enemies.json: '{eid}'"
        g = en.get("grudge")
        if g is not None and not (isinstance(g.get("dmg_pct"), int) and g["dmg_pct"] > 0 and isinstance(g.get("max"), int) and g["max"] >= 1):
            errors.append(f"{where} grudge needs dmg_pct > 0 and max >= 1")
        if "pack" in en and not (isinstance(en["pack"], int) and 2 <= en["pack"] <= 4):
            errors.append(f"{where} pack must be 2-4")
        if "on_hit_light" in en and not (isinstance(en["on_hit_light"], int) and en["on_hit_light"] < 0):
            errors.append(f"{where} on_hit_light must be a negative whole number")
        if "riposte_when_marked" in en and not isinstance(en["riposte_when_marked"], bool):
            errors.append(f"{where} riposte_when_marked must be true/false")
        # P2-05 bosses: summons, a skill on a beat, fleeing mini-bosses, anti-guard skills.
        sm = en.get("summon")
        if sm is not None and not (sm.get("id") in enemies and isinstance(sm.get("every"), int) and sm["every"] >= 1
                                   and isinstance(sm.get("max_alive"), int) and 1 <= sm["max_alive"] <= 3 and sm.get("text")
                                   and isinstance(sm.get("max_total"), int) and 1 <= sm["max_total"] <= 4):
            errors.append(f"{where} summon needs a known id, every >= 1, max_alive 1-3, max_total 1-4 (so the fight ends) and text")
        cy = en.get("cycle")
        if cy is not None and not (cy.get("skill") in {x.get("id") for x in en.get("skills", [])} and isinstance(cy.get("every"), int) and cy["every"] >= 2):
            errors.append(f"{where} cycle needs one of its own skills and every >= 2")
        if "flee_after" in en and not (isinstance(en["flee_after"], int) and en["flee_after"] >= 1):
            errors.append(f"{where} flee_after must be a whole number >= 1")
        for x in en.get("skills", []):
            if "vs_guard_pct" in x and not (isinstance(x["vs_guard_pct"], int) and x["vs_guard_pct"] > 0):
                errors.append(f"{where}.{x.get('id')} vs_guard_pct must be a whole number > 0")
        rf = en.get("reinforce")
        if rf is not None:
            if not (isinstance(rf.get("after_round"), int) and rf["after_round"] >= 1 and isinstance(rf.get("count"), int) and 1 <= rf["count"] <= 3):
                errors.append(f"{where} reinforce needs after_round >= 1 and count 1-3")
            if not rf.get("ids") or any(i not in enemies for i in rf.get("ids", [])):
                errors.append(f"{where} reinforce ids must be known enemies")
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
            if x.get("target") == "allies":
                # P2-04: buffs allies in ally_ranks (no damage); doesn't count as reaching the heroes.
                if not positions_ok(x.get("ally_ranks")):
                    errors.append(f"{where} (allies) needs ally_ranks (positions 1-4)")
                if not x.get("applies") or any(_is_negative_status(a) for a in (x["applies"] if isinstance(x["applies"], list) else [x["applies"]])):
                    errors.append(f"{where} (allies) needs positive applies")
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
    # P2-01 / P2-09: event outcomes (curios.json, traps.json) use one vocabulary
    # (GameState.apply_event_outcome); every key, status, stat and item must exist.
    outcome_keys = {"heal_party", "stress_party", "colones", "damage_random", "damage_party", "add_item",
                    "reveal_neighbors", "reveal_map", "random_equipment", "applies", "buff", "debuff",
                    "ambush", "weight", "text", "light", "stress_random"}

    def check_outcome(where: str, o) -> None:
        if not isinstance(o, dict):
            errors.append(f"{where}: outcome must be an object")
            return
        for k in o:
            if k not in outcome_keys:
                errors.append(f"{where}: unknown outcome key '{k}'")
        for k in ("light", "stress_random", "stress_party", "heal_party", "damage_random", "damage_party"):
            if k in o and not isinstance(o[k], int):
                errors.append(f"{where}: '{k}' must be a whole number")
        check_applies(where, o.get("applies"))
        for bk in ("buff", "debuff"):
            b = o.get(bk)
            if b is None:
                continue
            if not b.get("name") or not b.get("mods") or not isinstance(b.get("fights"), int) or b["fights"] < 1:
                errors.append(f"{where}: {bk} needs name, mods and fights >= 1")
            for mk in b.get("mods", {}):
                if mk not in stat_keys:
                    errors.append(f"{where}: unknown stat '{mk}' in {bk} mods")
        amb = o.get("ambush")
        if amb is not None and amb is not True and not (isinstance(amb, list) and len(amb) == 2 and 1 <= amb[0] <= amb[1] <= 4):
            errors.append(f"{where}: ambush must be true or [min, max] enemies (1-4)")
        add = o.get("add_item")
        if add is not None and add.get("id") not in items:
            errors.append(f"{where}: add_item references unknown item '{add.get('id')}'")

    curios_raw = load(DATA / "curios.json") or {}
    curio_ids = set()
    for c in curios_raw.get("curios", []):
        where = f"curios.json: '{c.get('id')}'"
        if c.get("id") in curio_ids:
            errors.append(f"{where}: duplicate id")
        curio_ids.add(c.get("id"))
        for f in ("name", "text"):
            if not c.get(f):
                errors.append(f"{where}: needs '{f}'")
        if c.get("key_item") and c["key_item"] not in items:
            errors.append(f"{where}: key_item '{c['key_item']}' is not an item")
        if c.get("key_item"):
            check_outcome(where + " key_outcome", c.get("key_outcome", {}))
            if not c.get("key_text"):
                errors.append(f"{where}: key_item needs key_text")
        # P2-02: a curio is either examined blind or a choice event (doc 07 §5), not both.
        choices = c.get("choices")
        if bool(choices) == bool(c.get("blind")):
            errors.append(f"{where}: needs either a blind outcome table or choices (not both)")
        for k, o in enumerate(c.get("blind", [])):
            check_outcome(f"{where} blind[{k}]", o)
            if not o.get("text"):
                errors.append(f"{where} blind[{k}]: needs text")
        if choices:
            if len(choices) < 2:
                errors.append(f"{where}: a choice event needs at least 2 choices")
            if all(ch.get("item") or ch.get("cost") for ch in choices):
                errors.append(f"{where}: at least one choice must be free (it is the way out)")
        for k, ch in enumerate(choices or []):
            cw = f"{where} choices[{k}]"
            if not ch.get("label") or not ch.get("outcomes"):
                errors.append(f"{cw}: needs label and outcomes")
            if ch.get("item") and ch["item"] not in items:
                errors.append(f"{cw}: item '{ch['item']}' is not an item")
            if "cost" in ch and (not isinstance(ch["cost"], int) or ch["cost"] < 1):
                errors.append(f"{cw}: cost must be a whole number >= 1")
            for j, o in enumerate(ch.get("outcomes", [])):
                check_outcome(f"{cw} outcomes[{j}]", o)
                if not o.get("text"):
                    errors.append(f"{cw} outcomes[{j}]: needs text")
    traps_raw = load(DATA / "traps.json") or {}
    trap_ids = set()
    for k in ("disarm_min", "disarm_max", "disarm_relief", "careful_light", "careful_trigger_pct"):
        if not isinstance(traps_raw.get(k), int) or not 0 <= traps_raw[k] <= 100:
            errors.append(f"traps.json: '{k}' must be a whole number 0-100")
    for t in traps_raw.get("traps", []):
        where = f"traps.json: '{t.get('id')}'"
        if t.get("id") in trap_ids:
            errors.append(f"{where}: duplicate id")
        trap_ids.add(t.get("id"))
        for f in ("name", "text", "fail_text"):
            if not t.get(f):
                errors.append(f"{where}: needs '{f}'")
        if not isinstance(t.get("difficulty"), int) or not 0 <= t["difficulty"] <= 100:
            errors.append(f"{where}: difficulty must be a whole number 0-100")
        check_outcome(where + " effects", t.get("effects", {}))
    enemy_ids_all = set(enemies)
    for rp in sorted((DATA / "regions").glob("*.json")):
        reg = load(rp) or {}
        gen = reg.get("generator") or {}
        for cid in gen.get("curios", []):
            if cid not in curio_ids:
                errors.append(f"regions/{rp.name}: generator.curios references unknown curio '{cid}'")
        for tid in gen.get("traps", []):
            if tid not in trap_ids:
                errors.append(f"regions/{rp.name}: generator.traps references unknown trap '{tid}'")
        for sq in gen.get("squads", []):
            if not isinstance(sq, list) or not 1 <= len(sq) <= 4 or any(e not in enemy_ids_all for e in sq):
                errors.append(f"regions/{rp.name}: generator.squads entry {sq} must list 1-4 known enemies")
        if gen.get("squads") and not (isinstance(gen.get("squad_template_pct"), int) and 0 <= gen["squad_template_pct"] <= 100):
            errors.append(f"regions/{rp.name}: generator.squad_template_pct must be 0-100 when squads are listed")
        rm = gen.get("roaming")
        if rm is not None:
            diffs = {d.get("id") for d in (load(DATA / "progression.json") or {}).get("difficulties", [])}
            bc = rm.get("bounty_colones")
            if rm.get("enemy_id") not in enemy_ids_all or any(e not in enemy_ids_all for e in rm.get("escort", [])):
                errors.append(f"regions/{rp.name}: roaming enemy_id / escort must be known enemies")
            if not isinstance(rm.get("chance_pct"), dict) or any(k not in diffs or not 0 <= v <= 100 for k, v in rm["chance_pct"].items()):
                errors.append(f"regions/{rp.name}: roaming chance_pct must be {{difficulty id: 0-100}}")
            if not (isinstance(rm.get("move_every"), int) and rm["move_every"] >= 1) or not rm.get("encounter_text"):
                errors.append(f"regions/{rp.name}: roaming needs move_every >= 1 and encounter_text")
            if not (isinstance(bc, list) and len(bc) == 2 and 0 <= bc[0] <= bc[1]):
                errors.append(f"regions/{rp.name}: roaming bounty_colones must be [min, max]")
            if not enemies.get(rm.get("enemy_id"), {}).get("flee_after"):
                errors.append(f"regions/{rp.name}: the roaming mini-boss needs flee_after (doc 05 §3.2: it escapes if not killed fast)")
        if rp.stem == "sotanos" and len(gen.get("squads", [])) < 3:
            errors.append(f"regions/{rp.name}: P2-04 wants at least 3 mixed squads")
        if rp.stem == "sotanos" and len(set(gen.get("curios", [])) | set(gen.get("traps", []))) < 30:
            errors.append(f"regions/{rp.name}: P2-02 wants at least 30 room events (curios + traps) in the pools")
        for n in reg.get("nodes", []):
            if n.get("type") == "trap" and n.get("trap_id") not in trap_ids:
                errors.append(f"regions/{rp.name}: trap node '{n.get('id')}' needs a known trap_id")
    if "gallo_pinto" not in items:
        errors.append("items.json: 'gallo_pinto' is the food item (camp meal, travel hunger) and must exist")
    # P1-18: recommended provisions per region (the hub offers to buy what is missing).
    for rp in sorted((DATA / "regions").glob("*.json")):
        prov = (load(rp) or {}).get("provisions", {})
        if not isinstance(prov, dict):
            errors.append(f"regions/{rp.name}: provisions must be {{item_id: qty}}")
            continue
        for iid, qty in prov.items():
            if iid not in items:
                errors.append(f"regions/{rp.name}: provisions references unknown item '{iid}'")
            if not isinstance(qty, int) or qty < 1:
                errors.append(f"regions/{rp.name}: provisions '{iid}' needs a whole number >= 1")

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
    "hub.heal_min_cost": "int>=0",
    "limits.roster_cap": "pos", "limits.inventory_slots": "pos", "limits.recruit_pool": "pos",
    "limits.graveyard_cap": "pos", "light.max": "pos", "light.snuff": "int>=0",
    "hunger.every_moves": "pos", "hunger.hp_pct": "pct", "hunger.stress": "int>=0",
}

# P1-17: every Luz tier needs these keys (numbers are percent points / stress; may be negative).
LIGHT_TIER_KEYS = ("id", "name", "min", "hero_accuracy", "enemy_dmg_pct", "enemy_crit", "stress_pct", "loot_pct",
                   "party_surprised_pct", "enemies_surprised_pct", "trap_pct", "move_stress",
                   "move_stress_all", "low")


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
    tiers = get("light.tiers")
    if not isinstance(tiers, list) or not tiers:
        errors.append("balance.json: light.tiers must be a non-empty list")
    else:
        mins = [t.get("min") for t in tiers if isinstance(t, dict)]
        if mins != sorted(mins, reverse=True) or len(set(mins)) != len(mins) or mins[-1] != 0:
            errors.append("balance.json: light.tiers must be brightest first with distinct mins, the last at 0")
        for t in tiers:
            missing = [k for k in LIGHT_TIER_KEYS if k not in t]
            if missing:
                errors.append(f"balance.json: light tier '{t.get('id')}' is missing {missing}")
            elif not 0 <= t["party_surprised_pct"] + t["enemies_surprised_pct"] <= 100:
                errors.append(f"balance.json: light tier '{t['id']}' surprise chances must add up to 0-100")
    # Every Balance path used in scripts must be listed above (so it is checked).
    used = set()
    for gd in (ROOT / "scripts").rglob("*.gd"):
        used |= set(re.findall(r'BalanceScript\.(?:num|int_of|arr|value)\("([a-z_.]+)"\)', gd.read_text(encoding="utf-8")))
    arrays = {"death.stress_penalties", "enemies.squad_hp_scale", "afflictions.ira_ciega_damage", "light.tiers"}
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
