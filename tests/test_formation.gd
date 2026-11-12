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

	# P1-03b: forced moves shift the others (insert, not swap); the dead stay at the back.
	var p1 := {"name": "p1"}
	var p2 := {"name": "p2"}
	var p3 := {"name": "p3"}
	var px := {"name": "px", "dead": true}
	var line: Array = [p1, p2, p3, px]
	_check(fm.move_by(line, p1, 2) == [p2, p3, p1, px], "move_by +2: p1 goes to position 3, the others step up")
	_check(fm.move_by(line, p3, -1) == [p1, p3, p2, px], "move_by -1: pulled one forward")
	_check(fm.move_by(line, p2, 9) == [p1, p3, p2, px] and fm.move_by(line, p1, -5) == line, "moves clamp to the living positions")
	_check(fm.move_to(line, p3, 1) == [p3, p1, p2, px], "move_to position 1")
	var se2 = load("res://scripts/domain/status_effects.gd")
	se2.apply(p2, "amarrado", 2, 0, {"ignore_resist": true})
	_check(not fm.can_move(p2) and fm.can_move(p1) and not fm.can_move(px), "Amarrado (and the dead) can't move")


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

	# P1-05: enemies crit (x1.5 and a +10 stress shock on the hero hit). Skill stress is 0, so
	# any stress gained here comes from a crit.
	var crits: Array = [0]
	var count_crit := func(text: String, _c: String): if text.contains("CRÍTICO de"): crits[0] += 1
	cc.logged.connect(count_crit)
	foe["crit"] = 100
	foe["skills"] = [{"id": "test3", "name": "Prueba", "type": "physical", "damage": [2, 2], "accuracy": 200, "target": "single", "stress": 0}]
	var stress_before: int = cc.party.reduce(func(acc, h): return acc + int(h["stress"]), 0)
	for i in 10:
		await cc._enemy_turn(foe)
	var stress_after: int = cc.party.reduce(func(acc, h): return acc + int(h["stress"]), 0)
	cc.logged.disconnect(count_crit)
	foe.erase("crit")
	_check(crits[0] > 0 and stress_after > stress_before, "enemy crits happen (%d in 10) and shock the hero hit (+%d stress)" % [crits[0], stress_after - stress_before])

	# Nothing in reach: the enemy steps toward its preferred positions instead.
	foe["skills"] = [{"id": "test2", "name": "Prueba", "type": "physical", "damage": [1, 1], "target": "single", "use_ranks": [3, 4], "target_ranks": [1]}]
	foe["ranks"] = [3, 4]
	var pos0: int = fm.position_of(foe, cc.enemies)
	await cc._enemy_turn(foe)
	_check(pos0 == 1 and fm.position_of(foe, cc.enemies) == 2, "out of reach: the enemy se reacomoda (position %d -> %d)" % [pos0, fm.position_of(foe, cc.enemies)])
	_check(_rows_match(screen, cc), "rows follow the enemy's step")
	foe["skills"] = saved_skills

	await _test_forced_moves(fm, gs, screen, cc)
	screen.queue_free()
	await process_frame


## P1-03b: push, pull, shuffle, Amarrado, resist, and fixing the formation out of combat.
func _test_forced_moves(fm, gs, screen, cc) -> void:
	print("Forced moves (P1-03b)")
	var se = load("res://scripts/domain/status_effects.gd")
	for e in cc.enemies + cc.party:
		e["status_resist"]["movimiento"] = 0
		e["hp"] = maxi(int(e["hp"]), 1) if e.get("dead", false) else 999
		e["hp_max"] = maxi(int(e.get("hp_max", 1)), int(e["hp"]))
	var e1: Dictionary = cc.enemies[0]
	var e2: Dictionary = cc.enemies[1]
	await cc._force_move(e1, {"move_target": 1})
	_check(fm.position_of(e1, cc.enemies) == 2 and fm.position_of(e2, cc.enemies) == 1, "a push sends the front enemy back one; the next steps up")
	_check(_rows_match(screen, cc), "rows follow the push")
	await cc._force_move(e1, {"move_target": -1})
	_check(fm.position_of(e1, cc.enemies) == 1, "a pull brings it forward again")
	e1["status_resist"]["movimiento"] = 100
	await cc._force_move(e1, {"move_target": 1})
	_check(fm.position_of(e1, cc.enemies) == 1, "Empujones 100%: it doesn't move")
	e1["status_resist"]["movimiento"] = 0
	se.apply(e1, "amarrado", 2, 0, {"ignore_resist": true})
	await cc._force_move(e1, {"move_target": 1})
	_check(fm.position_of(e1, cc.enemies) == 1, "Amarrado: forced moves fail")
	se.remove(e1, "amarrado")

	# A real hero skill: Patada de Corral (push 1) from the Montador.
	var mont: Dictionary = cc.party.filter(func(h): return str(h["hero_id"]) == "montador")[0]
	var patada: Dictionary = gs.hero_skill(mont, "patada_de_corral").duplicate(true)
	patada.erase("applies")
	# Hits are capped at 95%: make this one certain so the check isn't flaky.
	var bal = load("res://scripts/domain/balance.gd")
	bal.override("combat.hit_min", 1.0)
	bal.override("combat.hit_max", 1.0)
	cc._resolve_hero_attack(mont, patada, e1)
	bal.reset()
	await cc._apply_queued_moves()
	_check(fm.position_of(e1, cc.enemies) == 2, "Patada de Corral pushes the enemy it hits back one position")
	var body: String = load("res://scripts/ui/skill_button.gd").body_for(gs.hero_skill(mont, "patada_de_corral"))
	var body2: String = load("res://scripts/ui/skill_button.gd").body_for(gs.get_skill("reten"))
	_check(body.contains("Lo empuja 1 posición hacia atrás") and body2.contains("Lo jala 1 posición hacia adelante"), "tooltips say who gets pushed or pulled")
	_check(_rows_match(screen, cc), "rows follow the Patada")

	# Enemy skills on heroes: Cadenazo drags forward, Travesura shuffles.
	var h2: Dictionary = cc.party[1]
	await cc._force_move(h2, {"move_target": -1})
	_check(fm.position_of(h2, cc.party) == 1 and _rows_match(screen, cc), "Cadenazo-style pull drags a hero to position 1")
	var hs: Dictionary = cc.party[2]
	var p0: int = fm.position_of(hs, cc.party)
	await cc._force_move(hs, {"shuffle_target": true})
	_check(fm.position_of(hs, cc.party) != p0 and _rows_match(screen, cc), "a shuffle puts the hero somewhere else (%d -> %d)" % [p0, fm.position_of(hs, cc.party)])

	# Amarrado blocks Moverse both ways.
	var a0: Dictionary = cc.party[0]
	var a1: Dictionary = cc.party[1]
	se.apply(a1, "amarrado", 2, 0, {"ignore_resist": true})
	_check(not cc.move_options(a0).has(a1), "nobody can swap places with an Amarrado hero")
	_check(cc.move_options(a1).is_empty(), "an Amarrado hero can't use Moverse")
	se.remove(a1, "amarrado")
	_check(se.resist_chance({"status_resist": {"movimiento": 40}}, "amarrado") == 40, "Amarrado is resisted with Empujones (movimiento)")

	# Out of combat: "← Adelante" / "Atrás →" on the hero card.
	screen._mode = screen.Mode.EXPLORE
	var first: Dictionary = gs.party[0]
	screen._reorder_party(first, 1)
	_check(fm.position_of(first, gs.party) == 2 and _rows_match(screen, cc), "Atrás → moves the hero back one (party, units and row)")
	screen._reorder_party(first, -1)
	_check(fm.position_of(first, gs.party) == 1, "← Adelante moves it forward again")
	screen._mode = screen.Mode.COMBAT
	screen._reorder_party(first, 1)
	_check(fm.position_of(first, gs.party) == 1, "the card buttons do nothing in combat")


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
