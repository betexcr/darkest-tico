extends SceneTree

## Battlefield formation (P1-03a): positions 1-4, rank-limited skills, collapse of the
## fallen, "Moverse", enemy AI reach and "se reacomoda", squad order.
##   godot --headless --path . -s tests/test_formation.gd

var _fail: int = 0


func _check(cond: bool, what: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + what)
	if not cond:
		_fail += 1


func _initialize() -> void:
	Engine.time_scale = 20.0
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var fm = load("res://scripts/domain/formation.gd")
	_test_rules(fm)
	await _test_combat(fm)
	print("%d failure(s)" % _fail)
	quit(1 if _fail > 0 else 0)


func _test_rules(fm) -> void:
	print("Rules (formation.gd)")
	var a := {"name": "a"}
	var b := {"name": "b", "dead": true}
	var c := {"name": "c"}
	var d := {"name": "d"}
	var side: Array = [a, b, c, d]
	_check(fm.position_of(a, side) == 1 and fm.position_of(c, side) == 2 and fm.position_of(d, side) == 3, "positions count only the living")
	_check(fm.position_of(b, side) == 0, "the dead have no position")
	_check(fm.at_positions(side, [1.0, 2.0]) == [a, c], "at_positions (JSON floats work)")
	_check(fm.collapse_order(side) == [0, 2, 3, 1], "collapse: living first, dead last, order kept")
	_check(fm.neighbours(c, side) == [a, d], "neighbours skip the dead")
	_check(fm.neighbours(a, side) == [c], "position 1 has one neighbour")

	var foes: Array = [{"name": "e1"}, {"name": "e2"}, {"name": "e3"}]
	var melee := {"kind": "attack", "target": "enemy", "use_ranks": [1, 2], "target_ranks": [1, 2]}
	_check(fm.can_use(melee, a, side, foes, true), "melee from position 1 reaches enemies 1-2")
	_check(not fm.can_use(melee, d, side, foes, true), "melee can't be used from position 3")
	var far := {"kind": "attack", "target": "enemy", "use_ranks": [1], "target_ranks": [4]}
	_check(not fm.can_use(far, a, side, foes, true), "nothing in reach (no enemy in position 4)")
	_check(fm.can_use({"target": "party", "use_ranks": [1]}, a, side, foes, false), "party skill only needs use_ranks")
	_check(fm.valid_targets(melee, foes) == [foes[0], foes[1]], "valid targets: positions 1-2")
	var se = load("res://scripts/domain/status_effects.gd")
	se.apply(foes[0], "agazapado", 2, 0)
	_check(fm.valid_targets(melee, foes) == [foes[1]], "a hidden (Agazapado) enemy in reach can't be picked while another can")
	_check(fm.valid_targets({"target_ranks": [1]}, foes) == [foes[0]], "…unless it is the only one in reach")
	se.remove(foes[0], "agazapado")
	_check(fm.valid_targets({}, foes).size() == 3, "no target_ranks: every enemy")

	var bat := {"name": "bat", "ranks": [3, 4]}
	var x := {"name": "x"}
	_check(fm.step_toward(bat, [bat, x], [3, 4]) == x, "an enemy out of place steps back toward its ranks")
	_check(fm.step_toward(x, [bat, x], []).is_empty(), "no preferred ranks: no step")
	var boss := {"name": "boss", "ranks": [1, 2]}
	var esc := {"name": "esc", "ranks": [1, 2]}
	var back := {"name": "back", "ranks": [3, 4]}
	_check(fm.sort_squad([back, boss, esc]) == [boss, esc, back], "squads sort by preferred position, ties keep order")
	_check(fm.ranks_text([1, 2]) == "1–2" and fm.ranks_text([2.0, 3.0, 4.0]) == "2–4" and fm.ranks_text([1, 3]) == "1, 3", "ranks_text")


func _test_combat(fm) -> void:
	print("Combat (controller + stage)")
	var gs = root.get_node("GameState")
	gs.reset_party_from_catalog()
	gs.start_mission()
	_check(gs.party.map(func(h): return str(h["hero_id"])) == ["campesino", "montador", "abuela", "tecnologo"], "starting party stands in its classes' positions")
	var node_id: String = ""
	for id in gs.mission_nodes_index:
		if str(gs.mission_nodes_index[id].get("type", "")) == "combat":
			node_id = str(id)
			break
	var nd: Dictionary = gs.mission_nodes_index[node_id]
	nd["enemy_ids"] = ["murcielago_bodega", "peon_penado", "rata_de_troje"]
	nd.erase("is_elite")
	nd.erase("is_boss")
	var screen = load("res://scenes/expedition/expedition_screen.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	screen._start_combat(node_id)
	var cc = screen._combat
	_check(cc.enemies.map(func(e): return str(e["id"])) == ["peon_penado", "rata_de_troje", "murcielago_bodega"], "squad sorted: Peón (1-2), Rata (1-3), Murciélago (3-4)")
	_check(_rows_match(screen, cc), "stage rows match the formation at the start")
	var hero: Dictionary = {}
	for i in 900:
		await process_frame
		hero = cc.active_hero()
		if not hero.is_empty():
			break
	_check(not hero.is_empty(), "a hero's turn comes up")
	if hero.is_empty():
		return

	# Action bar: skills out of reach are disabled; Moverse is there.
	var buttons: Array = screen._skills.get_children().filter(func(b): return not b.is_queued_for_deletion())
	var ok_bar: bool = true
	for k in hero["skill_ids"].size():
		var sk: Dictionary = gs.hero_skill(hero, str(hero["skill_ids"][k]))
		ok_bar = ok_bar and bool(buttons[k].disabled) == not cc.skill_usable(hero, sk)
	_check(ok_bar, "skill buttons are disabled exactly when out of reach (%s, position %d)" % [hero["name"], cc.position_of(hero)])
	_check(buttons.any(func(b): return str(b.get("title")) == "Moverse"), "the action bar has a Moverse button")

	# Targets follow target_ranks; the default target is the front-most one in reach.
	var back_only := {"kind": "attack", "target": "enemy", "use_ranks": [1, 2, 3, 4], "target_ranks": [3]}
	_check(cc.current_target(back_only) == cc.enemies[2], "default target for a position-3 skill is the enemy in position 3")
	_check(cc.targets_for({"target_ranks": [1, 2]}) == [cc.enemies[0], cc.enemies[1]], "targets_for: enemies in positions 1-2")

	# Moverse: swap with a neighbour, arrays + units + stage rows in sync, turn spent.
	var other: Dictionary = cc.move_options(hero)[0]
	var p_hero: int = cc.position_of(hero)
	var p_other: int = cc.position_of(other)
	var turn_before: int = cc._turn_index
	cc.move_hero(other)
	await process_frame
	_check(cc.position_of(hero) == p_other and cc.position_of(other) == p_hero, "Moverse swaps positions (%d <-> %d)" % [p_hero, p_other])
	_check(_rows_match(screen, cc), "units and stage rows follow the swap")
	for i in 60:
		await process_frame
	_check(cc._turn_index > turn_before or cc._round > 1 or not is_same(cc.active_hero(), hero), "Moverse spends the turn")

	# Wait for the next hero turn so nothing else runs while we poke the controller.
	for i in 900:
		await process_frame
		if not cc.active_hero().is_empty():
			break

	# Collapse: a fallen enemy goes to the back, data and stage stay aligned.
	var front: Dictionary = cc.enemies[0]
	front["hp"] = 0
	front["dead"] = true
	cc._collapse_ranks()
	_check(is_same(cc.enemies[cc.enemies.size() - 1], front) and fm.position_of(cc.enemies[0], cc.enemies) == 1, "a fallen enemy moves to the back; the next one is position 1")
	_check(_rows_match(screen, cc), "enemy units and rows follow the collapse")

	# Enemy AI only hits heroes in the skill's reach.
	var foe: Dictionary = cc.enemies[0]
	var saved_skills: Array = foe["skills"]
	foe["skills"] = [{"id": "test", "name": "Prueba", "type": "physical", "damage": [1, 1], "accuracy": 200, "target": "single", "target_ranks": [4], "stress": 0}]
	var hp_before: Array = cc.party.map(func(h): return int(h["hp"]))
	for i in 6:
		await cc._enemy_turn(foe)
	var hit: Array = []
	for k in cc.party.size():
		if int(cc.party[k]["hp"]) < int(hp_before[k]):
			hit.append(fm.position_of(cc.party[k], cc.party))
	_check(not hit.is_empty() and hit.all(func(p): return p == 4), "an enemy skill with reach 4 only hits position 4 (hit: %s)" % str(hit))

	# Nothing in reach: the enemy steps toward its preferred positions instead.
	foe["skills"] = [{"id": "test2", "name": "Prueba", "type": "physical", "damage": [1, 1], "target": "single", "use_ranks": [3, 4], "target_ranks": [1]}]
	foe["ranks"] = [3, 4]
	var pos0: int = fm.position_of(foe, cc.enemies)
	await cc._enemy_turn(foe)
	_check(pos0 == 1 and fm.position_of(foe, cc.enemies) == 2, "out of reach: the enemy se reacomoda (position %d -> %d)" % [pos0, fm.position_of(foe, cc.enemies)])
	_check(_rows_match(screen, cc), "rows follow the enemy's step")
	foe["skills"] = saved_skills
	screen.queue_free()
	await process_frame


## hero_units / enemy_units line up with the data arrays and with the stage rows
## (heroes from the middle outward; enemies laid out in reverse).
func _rows_match(screen, cc) -> bool:
	for k in cc.party.size():
		if not is_same(cc.hero_units[k].data, cc.party[k]):
			return false
		if cc.hero_units[k].get_index() != k:
			return false
	var n: int = cc.enemies.size()
	for k in n:
		if not is_same(cc.enemy_units[k].data, cc.enemies[k]):
			return false
		if cc.enemy_units[k].get_index() != n - 1 - k:
			return false
	return true
