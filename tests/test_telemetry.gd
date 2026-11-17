extends SceneTree

## Local telemetry (P5-01): user://telemetry.jsonl gets mission results, stress spikes and the
## week's colones in / out. Writes to a scratch file, never the real log.
##   godot --headless --path . -s tests/test_telemetry.gd

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
	var tel = root.get_node("Telemetry")
	_check(not tel.enabled, "off by default in a -s script (the real log is never touched)")
	var path: String = "user://test_telemetry.jsonl"
	for p in [path, path + ".1"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	tel.path = path
	tel.enabled = true
	gs.reset_party_from_catalog()
	gs.colones = 1000
	gs.reset_week_counters()

	# Colones in / out: every change counts, whoever makes it.
	gs.colones += 500
	gs.colones -= 200
	gs.add_item("gallo_pinto", 1)
	gs.buy_item("gallo_pinto")
	var price: int = gs.item_price("gallo_pinto")
	_check(gs.week_colones_in == 500 and gs.week_colones_out == 200 + price, "the setter counts money in (%d) and out (%d)" % [gs.week_colones_in, gs.week_colones_out])

	# A stress spike: reaching the resolve check.
	var h: Dictionary = gs.party[0]
	h["stress"] = 90
	h["affliction_id"] = ""
	h["virtud_id"] = ""
	gs.StressSystemScript.add_stress(h, 20)
	var spikes: Array = tel.read_all().filter(func(e): return str(e["kind"]) == "stress_spike")
	_check(spikes.size() == 1 and (str(spikes[0]["result"]).begins_with("quebranto:") or str(spikes[0]["result"]).begins_with("virtud:")), "a stress spike is logged (%s)" % (spikes[0]["result"] if not spikes.is_empty() else "none"))
	_check(not spikes.is_empty() and str(spikes[0]["hero"]) == str(h["hero_id"]) and spikes[0]["in_mission"] == false, "with the hero and where it happened")

	# A mission end.
	gs.start_mission()
	gs.ledger_add("fights", 3)
	gs.log_mission_end("flee")
	var ends: Array = tel.read_all().filter(func(e): return str(e["kind"]) == "mission_end")
	_check(ends.size() == 1 and str(ends[0]["result"]) == "flee" and str(ends[0]["difficulty"]) == "aprendiz" and int(ends[0]["ledger"]["fights"]) == 3, "mission_end: result, difficulty and the ledger")
	_check(not ends.is_empty() and ends[0]["party"].size() == gs.party.size() and ends[0]["party"][0].has("stress"), "…and each hero's state")
	gs.end_mission_abandon()

	# The week: money in / out, then the counters start again.
	var w_in: int = gs.week_colones_in
	var w_out: int = gs.week_colones_out
	gs.end_of_expedition_week()
	var weeks: Array = tel.read_all().filter(func(e): return str(e["kind"]) == "week")
	_check(weeks.size() == 1 and int(weeks[0]["colones_in"]) == w_in and int(weeks[0]["colones_out"]) == w_out and int(weeks[0]["colones"]) == gs.colones, "week: colones, in %d, out %d" % [w_in, w_out])
	_check(gs.week_colones_in == 0 and gs.week_colones_out == 0, "the counters reset for the new week")
	_check(tel.read_all().all(func(e): return e.has("t") and e.has("week")), "every line has a time and the week")

	# The counters survive a save; loading is not income.
	gs.colones += 77
	var data: Dictionary = JSON.parse_string(JSON.stringify(gs.to_save_dict()))
	gs.apply_save_data(data)
	_check(gs.week_colones_in == 77 and gs.week_colones_out == 0, "save round trip keeps the week's counters (loading isn't counted)")

	# Rotation: a big log moves to .1 and a new one starts.
	tel.max_bytes = 200
	for k in 10:
		tel.log_event("filler", {"k": k})
	_check(FileAccess.file_exists(path + ".1") and tel.read_all().size() < 10, "a log past max_bytes rotates to .1")

	tel.enabled = false
	for p in [path, path + ".1"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	print("%d failure(s)" % _fail)
	quit(1 if _fail > 0 else 0)
