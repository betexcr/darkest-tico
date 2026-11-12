extends SceneTree

## Expedition systems outside combat: shared hero damage (P1-16), Luz tiers (P1-17), travel
## hunger (P1-18), traps (P2-01), curio outcomes and camp fixes (P2-09).
##   godot --headless --path . -s tests/test_expedition_systems.gd

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
	gs.start_mission()
	_test_hero_damage(gs)
	load("res://scripts/domain/balance.gd").reset()
	print("%d failure(s)" % _fail)
	quit(1 if _fail > 0 else 0)


func _hero(hp: int = 10) -> Dictionary:
	return {"name": "Prueba", "hp": hp, "hp_max": 20, "stress": 0}


func _test_hero_damage(gs) -> void:
	print("Hero damage outside combat (P1-16)")
	var hd = load("res://scripts/domain/hero_damage.gd")
	var h := _hero(10)
	hd.take(h, 4)
	_check(int(h["hp"]) == 6 and not h.get("al_borde", false), "damage below the PV left just subtracts")
	var logs: PackedStringArray = hd.take(h, 9)
	_check(int(h["hp"]) == 0 and bool(h.get("al_borde", false)) and not h.get("dead", false), "dropping to 0 PV makes the hero Al Borde")
	_check(logs.size() == 1 and logs[0].contains("Al Borde"), "…and says so")
	# A hit while Al Borde rolls Golpe de gracia; with no resist the hero dies.
	h["status_resist"] = {"golpe_de_gracia": 0}
	hd.take(h, 1)
	_check(bool(h.get("dead", false)) and int(h.get("borde_checks", 0)) == 1, "a hit while Al Borde rolls Golpe de gracia (0%: dies)")
	var safe := _hero(3)
	hd.take(safe, 50, false)
	_check(int(safe["hp"]) == 1 and not safe.get("al_borde", false), "can_kill = false floors at 1 PV")

	# Curio damage goes through the same rule.
	var v: Dictionary = gs.party[0]
	for other in gs.party.slice(1):
		other["dead"] = true
	v["hp"] = 2
	gs.apply_curio_outcome({"damage_random": 6})
	_check(int(v["hp"]) == 0 and bool(v.get("al_borde", false)), "curio damage to 0 PV makes the hero Al Borde")
	for other in gs.party:
		other["dead"] = false
		other["al_borde"] = false
		other["hp"] = other["hp_max"]
