extends SceneTree

## Region hazards (P6-02, doc 05 §1): move hazards fire on room moves and apply their outcome,
## light bounds, fight-start hazards (enemy buffs, a shuffled party), the camp ambush bonus,
## false exits, and a region without hazards stays as it was.
##   godot --headless --path . -s tests/test_region_hazards.gd

const HazardsScript := preload("res://scripts/domain/region_hazards.gd")
const CampingSystemScript := preload("res://scripts/domain/camping_system.gd")

var _fail: int = 0
var gs


func _check(cond: bool, what: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + what)
	if not cond:
		_fail += 1


func _initialize() -> void:
	_run.call_deferred()


class StubUnit extends RefCounted:
	const COLOR_STRESS := Color.WHITE
	var data: Dictionary

	func _init(d: Dictionary) -> void:
		data = d

	func play_action(_k: String = "") -> void:
		pass

	func play_hurt(_a: int = 0, _c: bool = false) -> void:
		pass

	func play_death(_a: int = 0, _c: bool = false) -> void:
		pass

	func play_heal(_a: int = 0, _s: int = 0) -> void:
		pass

	func float_text(_t: String = "", _c: Color = Color.WHITE) -> void:
		pass

	func refresh() -> void:
		pass

	func set_active(_on: bool = false) -> void:
		pass

	func set_targeted(_on: bool = false) -> void:
		pass

	func is_dead() -> bool:
		return bool(data.get("dead", false))

	func get_parent():
		return null


func _run() -> void:
	await process_frame
	gs = root.get_node("GameState")
	gs.reset_party_from_catalog()

	print("Rules")
	var region := {"hazards": [
		{"id": "a", "name": "Flora", "text": "Roza.", "trigger": "move", "chance_pct": 100, "outcome": {"stress_party": 3}},
		{"id": "b", "name": "Oscuro", "text": "Solo a oscuras.", "trigger": "move", "chance_pct": 100, "max_light": 40, "outcome": {"stress_party": 1}},
		{"id": "c", "name": "Niebla", "text": "Más visitas.", "trigger": "camp", "chance_pct": 100, "max_light": 50, "ambush_pct": 15}]}
	_check(HazardsScript.for_trigger(region, "move", 90).size() == 1 and HazardsScript.for_trigger(region, "move", 30).size() == 2, "light bounds decide which hazards count")
	_check(HazardsScript.ambush_bonus(region, 30) == 15 and HazardsScript.ambush_bonus(region, 80) == 0, "the camp bonus only in the dark")
	_check(HazardsScript.fires({"chance_pct": 30}, 0.29) and not HazardsScript.fires({"chance_pct": 30}, 0.31), "chance_pct is a percentage")
	_check(HazardsScript.describe(region)[0] == "Flora: Roza.", "describe gives 'name: text'")
	var base: int = CampingSystemScript.ambush_chance(90, false, [], 0)
	_check(CampingSystemScript.ambush_chance(90, false, [], 15) == base + 15 and CampingSystemScript.ambush_chance(90, true, [], 15) == 0, "the bonus adds to the night ambush (a watch still stops it)")

	print("On the map")
	gs.selected_mission_region_path = "res://data/regions/sotanos.json"
	gs.start_mission()
	gs.mission_region_data["hazards"] = region["hazards"]
	var h0: Dictionary = gs.party[0]
	var st: int = int(h0.get("stress", 0))
	gs.mission_light = 90
	gs.move_to_node(str(gs.mission_neighbors()[0]))
	_check(gs.pending_hazards.size() == 1 and gs.pending_hazards[0]["name"] == "Flora" and int(h0["stress"]) > st, "a move hazard fires and its outcome applies")
	gs.pending_hazards.clear()
	gs.mission_region_data["hazards"] = [{"id": "x", "name": "Salida falsa", "text": "No era por aquí.", "trigger": "move", "chance_pct": 100, "outcome": {"send_back": true}}]
	var here: String = gs.current_node_id
	var nxt: String = ""
	for n in gs.mission_neighbors():
		if str(n) != here:
			nxt = str(n)
	gs.move_to_node(nxt)
	_check(gs.current_node_id == here, "a false exit sends the party back to the room before")
	gs.pending_hazards.clear()
	var order: Array = gs.party.map(func(h): return int(h["uid"]))
	var shuffled: bool = false
	for _k in 20:
		gs.apply_event_outcome({"shuffle_party": true})
		if gs.party.map(func(h): return int(h["uid"])) != order:
			shuffled = true
			break
	_check(shuffled and gs.party.size() == 4, "shuffle_party changes the formation")
	gs.end_mission_abandon()

	print("Party split (P6-12)")
	gs.start_mission()
	var split_log: PackedStringArray = gs.apply_event_outcome({"lose_hero": {"stress": 6}})
	var lost: Array = gs.party.filter(func(h): return gs.is_lost(h))
	_check(lost.size() == 1 and gs.fight_party().size() == gs.party.size() - 1 and split_log.size() > 0, "the fog takes one hero out of the next fight")
	gs.apply_event_outcome({"lose_hero": true})
	_check(gs.party.filter(func(h): return gs.is_lost(h)).size() == 1, "never two lost at once")
	var lost_h: Dictionary = lost[0]
	var st0: int = int(lost_h.get("stress", 0))
	var fought: Array = gs.fight_party()
	fought.reverse()
	gs.rejoin_lost_heroes(fought)
	_check(not gs.is_lost(lost_h) and gs.party.size() == 4 and is_same(gs.party[3], lost_h) and int(lost_h["stress"]) >= st0 + 6, "after the fight they come back at the back of the formation, with the stress")
	_check(is_same(gs.party[0], fought[0]), "the fight's formation is kept for the others")
	for h in gs.party.slice(1):
		h["dead"] = true
	gs.apply_event_outcome({"lose_hero": true})
	_check(gs.fight_party().size() == gs.party.size(), "the last one standing is never lost")
	for h in gs.party:
		h.erase("dead")
	gs.end_mission_abandon()

	print("Fight start")
	gs.start_mission()
	gs.mission_region_data["hazards"] = [{"id": "t", "name": "Tótem del culto", "text": "Los enemigos se crecen.", "trigger": "fight_start", "chance_pct": 100,
		"enemy_applies": {"status": "chiva", "turns": 3, "mods": {"dmg_pct": 10}}, "outcome": {"shuffle_party": true}}]
	var cc = load("res://scripts/combat/combat_controller.gd").new()
	cc.instant = true
	root.add_child(cc)
	var foes: Array = [gs.make_enemy("espanto", 1), gs.make_enemy("rata_de_troje", 2)]
	var units: Array = gs.party.map(func(h): return StubUnit.new(h))
	cc.start(gs.party, foes, units, foes.map(func(e): return StubUnit.new(e)), false, false)
	_check(foes.all(func(e): return gs.StatusEffectsScript.has(e, "chiva")), "a totem buffs every enemy at the start")
	var aligned: bool = true
	for k in gs.party.size():
		aligned = aligned and is_same(cc.hero_units[k].data, gs.party[k])
	_check(aligned, "after a shuffle every stage unit still sits with its hero")
	cc.queue_free()
	gs.end_mission_abandon()

	print("Regions")
	var sot: Dictionary = gs.ExpeditionLoaderScript.load_region("res://data/regions/sotanos.json")
	var bos: Dictionary = gs.ExpeditionLoaderScript.load_region("res://data/regions/bosque.json")
	_check(HazardsScript.all(sot).is_empty(), "the Sótanos have no region hazards (balance unchanged)")
	_check(HazardsScript.all(bos).size() >= 2 and HazardsScript.ambush_bonus(bos, 30) > 0, "the Bosque has poison flora and a foggy-night ambush bonus")

	print("%d failure(s)" % _fail)
	quit(1 if _fail > 0 else 0)
