extends SceneTree

## P5-04: retreat from a fight (as in Darkest Dungeon).
##   godot --headless --path . -s tests/test_retreat.gd

var _fail: int = 0


## Stand-in for BattleUnit: same calls, no drawing.
class StubUnit extends RefCounted:
	const COLOR_STRESS := Color.WHITE
	var data: Dictionary

	func _init(d: Dictionary) -> void:
		data = d

	func play_action(_kind: String = "") -> void:
		pass

	func play_hurt(_amount: int = 0, _crit: bool = false) -> void:
		pass

	func play_death(_amount: int = 0, _crit: bool = false) -> void:
		pass

	func play_heal(_hp: int = 0, _stress: int = 0) -> void:
		pass

	func float_text(_text: String = "", _color: Color = Color.WHITE) -> void:
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


func _check(cond: bool, what: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + what)
	if not cond:
		_fail += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var gs = root.get_node("GameState")
	var bal = load("res://scripts/domain/balance.gd")
	gs.reset_party_from_catalog()
	gs.selected_difficulty_id = "aprendiz"
	_check(gs.start_mission(), "start an expedition")
	var start: String = gs.current_node_id
	# Walk until the party stands in a combat room.
	var fight_room: String = ""
	var guard: int = 0
	while fight_room == "" and guard < 60:
		guard += 1
		var moved: bool = false
		for nid in gs.mission_neighbors():
			if not gs.visited_node_ids.has(nid):
				gs.move_to_node(str(nid))
				moved = true
				break
		if not moved:
			gs.move_to_node(str(gs.mission_neighbors()[0]))
		var t: String = str(gs.current_node().get("type", ""))
		if t == "combat" or t == "boss":
			fight_room = gs.current_node_id
		else:
			gs.mark_node_cleared(gs.current_node_id)
	_check(fight_room != "" and fight_room != start, "walked into a combat room")
	var came_from: String = gs.previous_node_id
	_check(came_from != "" and gs.mission_neighbors().has(came_from), "GameState remembers the room the party came from")

	var cc = load("res://scripts/combat/combat_controller.gd").new()
	cc.instant = true
	root.add_child(cc)
	var fled: Array = [0]
	var over: Array = [0]
	cc.combat_fled.connect(func(): fled[0] += 1)
	cc.combat_over.connect(func(_v): over[0] += 1)

	print("A failed try spends the turn")
	bal.override("combat.retreat_chance", 0.0)
	_start(gs, cc, fight_room, false)
	var hero: Dictionary = await _wait_hero(cc)
	_check(not hero.is_empty() and cc.can_retreat(), "a hero is up and may call a retreat")
	var stress0: int = _party_stress(gs)
	cc.retreat()
	var next: Dictionary = await _wait_hero(cc)
	_check(fled[0] == 0 and cc.is_running(), "chance 0: the fight goes on")
	_check(not next.is_empty() and not is_same(next, hero), "the turn passed to someone else")
	cc._close_fight()

	print("A good retreat ends the fight")
	bal.override("combat.retreat_chance", 1.0)
	bal.override("combat.retreat_stress", 10)
	gs.mission_light = int(bal.num("light.max"))
	for h in gs.party:
		h["stress"] = 0
	_start(gs, cc, fight_room, false)
	hero = await _wait_hero(cc)
	cc.retreat()
	_check(fled[0] == 1 and over[0] == 0 and not cc.is_running(), "chance 1: combat_fled once, no victory or defeat")
	_check(gs.party.all(func(h): return int(h.get("stress", 0)) == 10 and not h.get("dead", false)), "every hero gains combat.retreat_stress (10) and lives")
	_check(not gs.is_node_cleared(fight_room), "the room is not cleared")
	_check(gs.retreat_to_previous_room() and gs.current_node_id == came_from and gs.previous_node_id == fight_room, "the party is back in the room it came from")
	gs.build_combat_context_for_node(fight_room)
	var squad: Array = gs.combat_context["enemies"]
	_check(not squad.is_empty() and squad.all(func(e): return int(e["hp"]) == int(e["hp_max"]) and not e.get("dead", false)), "walking in again finds the enemies at full PV")

	print("No retreat from a night ambush")
	gs.move_to_node(fight_room)
	_start(gs, cc, fight_room, true)
	hero = await _wait_hero(cc)
	_check(not hero.is_empty() and not cc.can_retreat(), "an ambush can't be left")
	cc.retreat()
	_check(fled[0] == 1 and cc.is_running() and is_same(cc.active_hero(), hero), "retreat() does nothing there: same hero, same turn")
	cc._close_fight()

	bal.reset()
	cc.queue_free()
	gs.end_mission_abandon()
	print("%d failure(s)" % _fail)
	quit(1 if _fail > 0 else 0)


func _start(gs, cc, node_id: String, ambush: bool) -> void:
	gs.build_combat_context_for_node(node_id)
	var squad: Array = gs.combat_context["enemies"]
	cc.start(gs.party, squad, gs.party.map(func(h): return StubUnit.new(h)), squad.map(func(e): return StubUnit.new(e)), false, false, ambush)


## Lets the controller run enemy turns until a hero is up ({} if the fight ended first).
func _wait_hero(cc) -> Dictionary:
	for _k in 600:
		if not cc.is_running():
			return {}
		if not cc.active_hero().is_empty():
			return cc.active_hero()
		await process_frame
	return {}


func _party_stress(gs) -> int:
	var n: int = 0
	for h in gs.party:
		n += int(h.get("stress", 0))
	return n
