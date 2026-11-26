extends SceneTree

## Boss ladder (P6-06, doc 05 §3): the Mayordomo fights differently at Veterano and Campeón;
## Campeón also takes the Veterano block; enemies without tiers don't change.
##   godot --headless --path . -s tests/test_boss_tiers.gd

const BossTiersScript := preload("res://scripts/domain/boss_tiers.gd")
const ResolveSystemScript := preload("res://scripts/domain/resolve_system.gd")

var _fail: int = 0


func _check(cond: bool, what: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + what)
	if not cond:
		_fail += 1


func _initialize() -> void:
	_run.call_deferred()


func _skill_ids(e: Dictionary) -> Array:
	return (e.get("skills", []) as Array).map(func(s): return str(s.get("id", "")))


func _run() -> void:
	await process_frame
	var gs = root.get_node("GameState")
	gs.reset_party_from_catalog()
	var raw: Dictionary = gs._enemies_by_id["mayordomo_hundido"]

	print("Rules")
	var a: Dictionary = BossTiersScript.apply(raw, "aprendiz")
	_check(not a.has("tiers") and not a.has("phases") and not a.has("tier_label") and _skill_ids(a) == _skill_ids(raw), "Aprendiz: the Mayordomo as before")
	var v: Dictionary = BossTiersScript.apply(raw, "veterano")
	_check((v.get("phases", []) as Array).size() == 1 and int(v["phases"][0]["at_hp_pct"]) == 50 and v["tier_label"] == "Veterano", "Veterano: a phase at 50% PV")
	_check(_skill_ids(v) == _skill_ids(raw) and int(v["cycle"]["every"]) == 4, "…same skills and darkness beat")
	var c: Dictionary = BossTiersScript.apply(raw, "campeon")
	_check((c.get("phases", []) as Array).size() == 1, "Campeón keeps the Veterano phase")
	_check(_skill_ids(c).has("agua_de_la_bodega") and not _skill_ids(c).has("la_cuenta_por_favor") and _skill_ids(c).size() == _skill_ids(raw).size(), "…Agua de la bodega replaces La cuenta, por favor")
	_check(int(c["cycle"]["every"]) == 3 and str(c["cycle"]["skill"]) == "pulso_de_oscuridad", "…darkness every 3 rounds (same skill)")
	_check(int(c["summon"]["max_alive"]) == 3 and int(c["summon"]["max_total"]) == 3 and str(c["summon"]["id"]) == "sirviente_ahogado", "…up to 3 servants")
	_check(c["tier_label"] == "Campeón" and str(c["tier_text"]).length() > 20, "…and says how it changed")
	_check(raw.has("tiers") and not raw.has("phases"), "the catalog entry is not changed")
	var rat: Dictionary = BossTiersScript.apply(gs._enemies_by_id["rata_de_troje"], "campeon")
	_check(not rat.has("tier_label") and not rat.has("tiers"), "enemies without tiers don't change")

	print("make_enemy")
	gs.mission_difficulty = ResolveSystemScript.expedition("campeon", 0)
	var boss: Dictionary = gs.make_enemy("mayordomo_hundido", 0)
	_check(_skill_ids(boss).has("agua_de_la_bodega") and boss.has("phases"), "a Campeón expedition gets the Campeón Mayordomo")
	gs.mission_difficulty = ResolveSystemScript.expedition("aprendiz", 0)
	_check(not gs.make_enemy("mayordomo_hundido", 0).has("phases"), "an Aprendiz expedition gets the plain one")

	print("%d failure(s)" % _fail)
	quit(1 if _fail > 0 else 0)
