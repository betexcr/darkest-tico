extends SceneTree

## Region framework (P6-01): the region list, unlocks from bosses beaten, regions still being
## built, the Bosque on the generator, clears in the save, and old saves.
##   godot --headless --path . -s tests/test_regions.gd

const RegionProgressScript := preload("res://scripts/domain/region_progress.gd")
const SOTANOS := "res://data/regions/sotanos.json"
const BOSQUE := "res://data/regions/bosque.json"
const CANAVERALES := "res://data/regions/canaverales.json"

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
	gs.regions_cleared = {}

	print("Rules")
	var bosque_row: Dictionary = RegionProgressScript.entry_by_id("bosque")
	_check(RegionProgressScript.entries()[0]["id"] == "sotanos", "the Sótanos come first")
	_check(not RegionProgressScript.is_unlocked(bosque_row, {}), "the Bosque starts closed")
	_check(RegionProgressScript.is_unlocked(bosque_row, {"sotanos": {"aprendiz": 1}}), "…and opens once the Sótanos boss is beaten")
	_check(not RegionProgressScript.is_unlocked(bosque_row, {"sotanos": {"aprendiz": 0}}), "a zero count is not a clear")
	var any_row := {"id": "x", "unlock": {"cleared_any": ["bosque", "canaverales"]}}
	_check(not RegionProgressScript.is_unlocked(any_row, {"sotanos": {"aprendiz": 1}}) and RegionProgressScript.is_unlocked(any_row, {"bosque": {"campeon": 1}}), "cleared_any: either one opens it")
	var count_row := {"id": "y", "unlock": {"cleared_count": 2}}
	_check(not RegionProgressScript.is_unlocked(count_row, {"sotanos": {"aprendiz": 3}}) and RegionProgressScript.is_unlocked(count_row, {"sotanos": {"aprendiz": 1}, "bosque": {"veterano": 1}}), "cleared_count counts regions, not clears")
	_check(not RegionProgressScript.visible({"wip": true}, false) and RegionProgressScript.visible({"wip": true}, true) and RegionProgressScript.visible({}, false), "a region still being built shows only in debug builds")

	_check(RegionProgressScript.visible(bosque_row, false), "the Bosque is open in release builds (P6-10c)")
	print("GameState")
	_check(gs.region_unlocked(SOTANOS) and not gs.region_unlocked(BOSQUE), "Sótanos open, Bosque closed")
	var why: String = gs.region_lock_reason(BOSQUE)
	_check(why.contains("Mayordomo") and why.contains("Sótanos"), "the reason names the boss and the region (%s)" % why)
	gs.selected_mission_region_path = SOTANOS
	gs.selected_difficulty_id = "aprendiz"
	_check(gs.start_mission(), "a Sótanos expedition starts")
	var sum: Dictionary = gs.complete_mission()
	gs.end_mission_abandon()
	_check(int(gs.regions_cleared.get("sotanos", {}).get("aprendiz", 0)) == 1, "beating the boss records the clear")
	_check(gs.region_unlocked(BOSQUE) and gs.region_lock_reason(BOSQUE) == "", "…and opens the Bosque")
	_check(Array(sum.get("regions_opened", [])).has("Bosque Nuboso Maldito"), "the victory summary says the Bosque opened")
	gs.start_mission(SOTANOS)
	var again: Dictionary = gs.complete_mission()
	gs.end_mission_abandon()
	_check(Array(again.get("regions_opened", [])).is_empty() and int(gs.regions_cleared["sotanos"]["aprendiz"]) == 2, "a second clear opens nothing new")

	print("Bosque on the generator")
	_check(gs.start_mission(BOSQUE), "a Bosque expedition starts")
	var boss_ok: bool = false
	for nid in gs.mission_nodes_index:
		var nd: Dictionary = gs.mission_nodes_index[nid]
		if bool(nd.get("is_boss", false)):
			boss_ok = str(nd.get("enemy_id", "")) == "segua_boss"
	_check(boss_ok and gs.mission_nodes_index.size() >= 10, "its map has La Segua in the boss room (%d rooms)" % gs.mission_nodes_index.size())
	_check(int(gs.mission_difficulty.get("level", 0)) == 2, "region level 1 adds to the difficulty (expedition level 2)")
	gs.end_mission_abandon()
	# P6-10a: Bosque maps use only Bosque enemies and events.
	var bgen: Dictionary = gs.ExpeditionLoaderScript.load_region(BOSQUE)["generator"]
	var allowed: Array = bgen["enemy_pool"] + bgen["elite_pool"] + [bgen["boss_enemy_id"]]
	for sq in bgen["squads"]:
		allowed += sq
	var only_bosque: bool = true
	for seed in 20:
		var m: Dictionary = gs.MapGeneratorScript.generate(gs.ExpeditionLoaderScript.load_region(BOSQUE), seed)
		for nd in m["nodes"]:
			for id in nd.get("enemy_ids", [nd.get("enemy_id", "")] if nd.has("enemy_id") else []):
				only_bosque = only_bosque and allowed.has(id)
			if nd.has("curio_id"):
				only_bosque = only_bosque and (bgen["curios"] as Array).has(nd["curio_id"])
			if nd.has("trap_id"):
				only_bosque = only_bosque and (bgen["traps"] as Array).has(nd["trap_id"])
	_check(only_bosque, "20 Bosque maps hold only Bosque enemies, curios and traps")
	_check((bgen["curios"] as Array).size() + (bgen["traps"] as Array).size() >= 20 and (bgen["enemy_pool"] as Array).size() >= 8, "the Bosque has >= 20 events and >= 8 regular enemies")
	_check(gs.expand_packs(["danta_embrujada", "brujo_de_la_montana", "mono_congo_poseido"]) == ["danta_embrujada", "brujo_de_la_montana", "mono_congo_poseido"] and gs.enemy_size("danta_embrujada") == 2, "the large Danta plus two more fill the four positions")

	print("Cañaverales on the generator (P6-11a)")
	var cana_row: Dictionary = RegionProgressScript.entry_by_id("canaverales")
	_check(not cana_row.is_empty() and RegionProgressScript.is_unlocked(cana_row, {"sotanos": {"aprendiz": 1}}), "the Cañaverales open once the Sótanos boss is beaten")
	var cgen: Dictionary = gs.ExpeditionLoaderScript.load_region(CANAVERALES)["generator"]
	var callowed: Array = cgen["enemy_pool"] + cgen["elite_pool"] + [cgen["boss_enemy_id"]] + cgen.get("boss_escort", [])
	for sq in cgen["squads"]:
		callowed += sq
	var only_cana: bool = true
	var boss_cana: bool = true
	for seed in 20:
		var m: Dictionary = gs.MapGeneratorScript.generate(gs.ExpeditionLoaderScript.load_region(CANAVERALES), seed)
		for nd in m["nodes"]:
			for id in nd.get("enemy_ids", [nd.get("enemy_id", "")] if nd.has("enemy_id") else []):
				only_cana = only_cana and callowed.has(id)
			if bool(nd.get("is_boss", false)):
				boss_cana = boss_cana and str(nd.get("enemy_id", "")) == "capataz_de_ceniza"
			if nd.has("curio_id"):
				only_cana = only_cana and (cgen["curios"] as Array).has(nd["curio_id"])
			if nd.has("trap_id"):
				only_cana = only_cana and (cgen["traps"] as Array).has(nd["trap_id"])
	_check(only_cana and boss_cana, "20 Cañaverales maps hold only Cañaverales enemies and events, with the Capataz in the boss room")
	_check((cgen["curios"] as Array).size() + (cgen["traps"] as Array).size() >= 20 and (cgen["enemy_pool"] as Array).size() >= 8, "the Cañaverales have >= 20 events and >= 8 regular enemies")
	_check(gs.expand_packs(["zompopas_de_mayo", "rata_canera"]).size() == 4, "a swarm squad (two packs) fills the four positions")
	_check(gs.start_mission(CANAVERALES) and int(gs.mission_difficulty.get("level", 0)) == 2, "a Cañaverales expedition starts at region level 1")
	gs.end_mission_abandon()

	print("Saves")
	var d: Dictionary = JSON.parse_string(JSON.stringify(gs.to_save_dict()))
	_check(int(d["version"]) == 20 and d.has("regions_cleared"), "save v20 keeps the clears")
	gs.regions_cleared = {}
	gs.apply_save_data(d)
	_check(int(gs.regions_cleared.get("sotanos", {}).get("aprendiz", 0)) == 2, "…and loads them back")
	d["regions_cleared"] = {}
	d["selected_mission_region_path"] = BOSQUE
	gs.apply_save_data(d)
	_check(gs.selected_mission_region_path == SOTANOS, "a saved region that is closed falls back to the Sótanos")
	var f: FileAccess = FileAccess.open("res://tests/fixtures/save_v19.json", FileAccess.READ)
	gs.apply_save_data(JSON.parse_string(f.get_as_text()))
	_check(gs.regions_cleared.is_empty() and gs.selected_mission_region_path == SOTANOS, "a v19 save loads with no clears")

	print("%d failure(s)" % _fail)
	quit(1 if _fail > 0 else 0)
