extends SceneTree

## Unlockable skills (P3-17): learning a class's extra skills at the Casa Comunal, choosing the
## 4 a hero brings (free in town, basic attack fixed, never on an expedition), ranks on skills
## left at home, prices, saves and old saves.
##   godot --headless --path . -s tests/test_skill_loadout.gd

const LoadoutScript := preload("res://scripts/domain/skill_loadout.gd")
const BalanceScript := preload("res://scripts/domain/balance.gd")

var _fail: int = 0


func _check(cond: bool, what: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + what)
	if not cond:
		_fail += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var gs = root.get_node("GameState")
	gs.reset_party_from_catalog()
	gs.active_event_id = ""
	gs.building_levels = {}
	gs.mission_active = false
	gs.colones = 50000

	print("Data")
	for t in gs._heroes_by_id.values():
		var all: Array = LoadoutScript.class_skills(t)
		_check(all.size() == 7 and t.get("skill_ids", []).size() == 4, "%s: 7 class skills, 4 to start" % t.get("id"))
		var basic: Dictionary = gs.get_skill(str(t["skill_ids"][0]))
		_check(LoadoutScript.reaches_front([t["skill_ids"][0]], t, gs.get_skill), "%s: the basic attack alone reaches enemy position 1 (%s)" % [t.get("id"), basic.get("name")])

	var campe: Dictionary = {}
	for h in gs.roster:
		if str(h.get("hero_id", "")) == "campesino":
			campe = h
	_check(not campe.is_empty(), "test hero: a Campesino")
	var t: Dictionary = gs.hero_template(campe)
	var starter: Array = t["skill_ids"]
	_check(LoadoutScript.known(campe) == starter and campe.get("skill_known", []) == starter, "a recruit knows the class's 4")
	_check(LoadoutScript.learnable(campe, t) == t["extra_skill_ids"], "…and can learn the other 3")

	print("Learning")
	campe["resolve_level"] = 0
	var base: int = BalanceScript.int_of("hub.skill_learn_cost")
	_check(gs.skill_learn_cost(campe) == base, "learning costs %d ₡ at resolve tier 0" % base)
	campe["resolve_level"] = 6
	_check(gs.skill_learn_cost(campe) == int(round(base * gs.tier_price_mult(campe))) and gs.skill_learn_cost(campe) > base, "…more for a seasoned hero (%d)" % gs.skill_learn_cost(campe))
	campe["resolve_level"] = 0
	var c0: int = gs.colones
	var extra: String = str(t["extra_skill_ids"][0])
	var msg: String = gs.learn_skill(campe, extra)
	_check(LoadoutScript.knows(campe, extra) and gs.colones == c0 - base and msg.contains("aprende"), "learn %s (%s)" % [extra, msg])
	_check(not campe["skill_ids"].has(extra), "a new skill is learned, not brought yet")
	_check(gs.skill_learn_block_reason(campe, extra).contains("Ya la sabe"), "can't learn it twice")
	_check(gs.skill_learn_block_reason(campe, "sopa_milagrosa").contains("oficio"), "can't learn another class's skill")
	gs.colones = 10
	_check(gs.skill_learn_block_reason(campe, str(t["extra_skill_ids"][1])).contains("No alcanza"), "can't learn without the money")
	gs.colones = 50000

	print("Choosing the 4")
	_check(gs.skill_slot_block_reason(campe, 0, extra).contains("básico"), "the basic attack's slot is fixed")
	_check(gs.skill_slot_block_reason(campe, 2, str(t["extra_skill_ids"][1])).contains("no la sabe"), "an unknown skill can't be brought")
	var old: String = str(campe["skill_ids"][2])
	msg = gs.set_skill_slot(campe, 2, extra)
	_check(str(campe["skill_ids"][2]) == extra and campe["skill_ids"].size() == 4 and LoadoutScript.benched(campe, t) == [old], "swap %s in for %s (%s)" % [extra, old, msg])
	var s1: String = str(campe["skill_ids"][1])
	gs.set_skill_slot(campe, 1, extra)
	_check(str(campe["skill_ids"][1]) == extra and str(campe["skill_ids"][2]) == s1, "a skill already brought swaps places")
	gs.mission_active = true
	_check(gs.skill_slot_block_reason(campe, 3, old).contains("expedición"), "no swaps on an expedition")
	gs.mission_active = false
	_check(gs.skill_slot_block_reason(campe, 3, old) == "", "…but fine back in town")

	print("Ranks on a skill left at home")
	campe["resolve_level"] = 6
	_check(gs.skill_rank_block_reason(campe, old) == "", "a known skill left at home can still be trained")
	gs.buy_skill_rank(campe, old)
	gs.set_skill_slot(campe, 3, old)
	_check(gs.SkillRanksScript.rank(campe, old) == 2 and gs.hero_skill(campe, old).get("damage_min", 0) >= gs.get_skill(old).get("damage_min", 0), "its rank comes back with it")
	_check(gs.skill_rank_block_reason(campe, str(t["extra_skill_ids"][2])).contains("No conoce"), "an unlearned skill can't be trained")

	print("No loadout that can't reach the front")
	# A made-up back-row class: "d" is its only attack that reaches enemy position 1.
	var fake: Dictionary = {"id": "x", "ranks": [3, 4], "skill_ids": ["b", "d", "c", "x"], "extra_skill_ids": ["e", "h"]}
	var sk := {"b": {"kind": "buff", "target": "self"}, "c": {"kind": "buff", "target": "self"}, "x": {"kind": "heal", "target": "ally"},
		"d": {"kind": "attack", "use_ranks": [3, 4], "target_ranks": [1, 2]},
		"e": {"kind": "attack", "use_ranks": [3, 4], "target_ranks": [3, 4]},
		"h": {"kind": "attack", "use_ranks": [3, 4], "target_ranks": [1, 2, 3, 4]}}
	var lookup: Callable = func(id): return sk.get(id, {})
	var fh: Dictionary = {"skill_ids": ["b", "d", "c", "x"], "skill_known": ["b", "d", "c", "x", "e", "h"]}
	_check(LoadoutScript.swap_block_reason(fh, fake, 1, "e", false, lookup).contains("adelante"), "swapping out the only front-reaching attack is refused")
	_check(LoadoutScript.swap_block_reason(fh, fake, 1, "h", false, lookup) == "", "…unless the new skill reaches the front too")
	_check(LoadoutScript.swap_block_reason(fh, fake, 3, "e", false, lookup) == "", "…and any other slot is free")

	print("Saves")
	var uid: int = int(campe.get("uid", 0))
	var loadout: Array = campe["skill_ids"].duplicate()
	var known: Array = LoadoutScript.known(campe)
	var d: Dictionary = gs.to_save_dict()
	_check(int(d.get("version", 0)) == 19, "save version 19")
	gs.reset_party_from_catalog()
	gs.apply_save_data(JSON.parse_string(JSON.stringify(d)))
	var back: Dictionary = {}
	for h in gs.roster:
		if int(h.get("uid", -1)) == uid:
			back = h
	_check(not back.is_empty() and back["skill_ids"] == loadout and LoadoutScript.known(back) == known and gs.SkillRanksScript.rank(back, old) == 2,
		"loadout, learned skills and ranks survive a save (%s)" % str(back.get("skill_ids")))
	# A broken loadout (basic attack moved, an unknown skill) falls back to the class's 4.
	var bad: Dictionary = JSON.parse_string(JSON.stringify(d))
	for h in bad["roster"]:
		if int(h.get("uid", -1)) == uid:
			h["skill_ids"] = [extra, starter[0], starter[1], starter[2]]
	gs.apply_save_data(bad)
	for h in gs.roster:
		if int(h.get("uid", -1)) == uid:
			back = h
	_check(back["skill_ids"] == starter and LoadoutScript.knows(back, extra) and gs.SkillRanksScript.rank(back, old) == 2, "a broken loadout falls back to the class's 4, keeping what was learned")
	var f: FileAccess = FileAccess.open("res://tests/fixtures/save_v18.json", FileAccess.READ)
	gs.apply_save_data(JSON.parse_string(f.get_as_text()))
	var ok: bool = not gs.roster.is_empty()
	for h in gs.roster:
		var ht: Dictionary = gs.hero_template(h)
		ok = ok and h["skill_ids"] == ht["skill_ids"] and h["skill_known"] == ht["skill_ids"]
	_check(ok, "a v18 save: every hero knows and brings the class's 4")

	print("%d failure(s)" % _fail)
	quit(1 if _fail > 0 else 0)
