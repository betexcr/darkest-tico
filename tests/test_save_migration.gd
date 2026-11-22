extends SceneTree

## Save migrations (P3-08): every tests/fixtures/save_v<N>.json is a real save written by the
## game at that version (tools: the commit that introduced each SAVE_VERSION, run headless; see
## tests/fixtures/README.md). Each one must load with today's GameState.apply_save_data, keep
## its progress, gain every field later versions added, and save + load again unchanged.
##   godot --headless --path . -s tests/test_save_migration.gd

const FIXTURES := "res://tests/fixtures"

var _fail: int = 0


func _check(cond: bool, what: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + what)
	if not cond:
		_fail += 1


func _initialize() -> void:
	_run.call_deferred()


func _fixtures() -> Array:
	var out: Array = []
	for f in DirAccess.get_files_at(FIXTURES):
		if f.begins_with("save_v") and f.ends_with(".json"):
			out.append(f)
	out.sort_custom(func(a, b): return int(a.trim_prefix("save_v").trim_suffix(".json")) < int(b.trim_prefix("save_v").trim_suffix(".json")))
	return out


func _run() -> void:
	await process_frame
	var gs = root.get_node("GameState")
	var files: Array = _fixtures()
	_check(files.size() >= 10, "fixtures for %d old save versions" % files.size())
	for f in files:
		var raw = JSON.parse_string(FileAccess.get_file_as_string("%s/%s" % [FIXTURES, f]))
		if not raw is Dictionary:
			_check(false, "%s parses" % f)
			continue
		var v: int = int(raw.get("version", 0))
		_check(v < gs.SAVE_VERSION, "%s is an older version (v%d < v%d)" % [f, v, gs.SAVE_VERSION])
		gs.reset_party_from_catalog()
		gs.colones = 0
		gs.week = 1
		gs.apply_save_data(raw.duplicate(true))
		# Compare with what the old save actually holds (v3 had no week and no alforja).
		_check(gs.colones == int(raw["colones"]) and (not raw.has("week") or gs.week == int(raw["week"])), "v%d: colones%s kept" % [v, " and week" if raw.has("week") else ""])
		_check(not gs.roster.is_empty() and not gs.party.is_empty(), "v%d: a roster and a party (%d / %d)" % [v, gs.roster.size(), gs.party.size()])
		var had_food: int = 0
		for e in raw.get("inventory", []):
			if e is Dictionary and str(e.get("id", "")) == "gallo_pinto":
				had_food += int(e.get("qty", 0))
		_check(gs.item_count("gallo_pinto") >= had_food, "v%d: the alforja kept its gallo pinto (%d of %d)" % [v, gs.item_count("gallo_pinto"), had_food])
		var h0: Dictionary = gs.roster[0]
		_check(int(h0.get("stress", -1)) == 37, "v%d: the first hero's stress kept" % v)
		var bad: Array = []
		for h in gs.roster:
			for k in ["uid", "sex", "class_name", "gear_ranks", "skill_ids", "hp", "hp_max", "stress"]:
				if not h.has(k):
					bad.append("%s.%s" % [h.get("name", "?"), k])
			if int(h.get("hp", 0)) > int(h.get("hp_max", 0)) or int(h.get("hp_max", 0)) <= 0:
				bad.append("%s.hp" % h.get("name", "?"))
		_check(bad.is_empty(), "v%d: every hero has today's fields%s" % [v, (" (missing " + ", ".join(bad) + ")") if not bad.is_empty() else ""])
		var eq = h0.get("equipment", {})
		if raw.has("roster") and raw["roster"] is Array and raw["roster"][0].get("equipment", {}) is Dictionary \
				and str(raw["roster"][0].get("equipment", {}).get("weapon", "")) != "":
			_check(eq is Dictionary and str(eq.get("weapon", "")) == "machete_cartago", "v%d: the equipped machete kept" % v)
		_check(gs.reliquias >= 0 and gs.building_levels is Dictionary and gs.feria_stock.size() > 0, "v%d: Reliquias, upgrades and a Feria stall set up" % v)
		var again: Dictionary = gs.to_save_dict()
		_check(int(again["version"]) == gs.SAVE_VERSION, "v%d: saves again as v%d" % [v, gs.SAVE_VERSION])
		# The first reload may still fill defaults (recruits rolled fresh for saves that had none,
		# whole-number resistances, a sorted camp-skill list); after it nothing may be lost and
		# the save must be stable.
		var text1: String = JSON.stringify(again, "", true)
		gs.apply_save_data(JSON.parse_string(text1))
		var second: Dictionary = gs.to_save_dict()
		var text2: String = JSON.stringify(second, "", true)
		_check(_lost(again, second).is_empty(), "v%d: reloading it loses nothing%s" % [v, ("" if _lost(again, second).is_empty() else " (lost " + ", ".join(_lost(again, second)) + ")")])
		gs.apply_save_data(JSON.parse_string(text2))
		_check(JSON.stringify(gs.to_save_dict(), "", true) == text2, "v%d: and from then on it loads back unchanged" % v)
	print("%d failure(s)" % _fail)
	quit(1 if _fail > 0 else 0)


## Keys present in `a` but gone in `b` (dictionaries compared recursively, arrays by index).
func _lost(a, b, path: String = "") -> Array:
	var out: Array = []
	if a is Dictionary and b is Dictionary:
		for k in a:
			if not b.has(k):
				out.append(path + str(k))
			else:
				out.append_array(_lost(a[k], b[k], path + str(k) + "."))
	elif a is Array and b is Array:
		if b.size() < a.size():
			out.append(path + "[%d → %d]" % [a.size(), b.size()])
		for i in mini(a.size(), b.size()):
			out.append_array(_lost(a[i], b[i], path + "%d." % i))
	return out
