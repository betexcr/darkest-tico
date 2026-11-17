extends SceneTree

## P1-06: balance numbers come from data/balance.json (scripts/domain/balance.gd).
## Changing a value through Balance.override changes the game's behaviour.
##   godot --headless --path . -s tests/test_balance.gd

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
	var bal = load("res://scripts/domain/balance.gd")
	var cr = load("res://scripts/domain/combat_resolver.gd")
	var stress = load("res://scripts/domain/stress_system.gd")

	print("Values match data/balance.json")
	_check(is_equal_approx(cr.hit_chance(0, 0, 0), bal.num("combat.hit_base")), "hit chance at even stats = combat.hit_base (%.2f)" % bal.num("combat.hit_base"))
	_check(is_equal_approx(cr.hit_chance(100, 0, 0), bal.num("combat.hit_max")) and is_equal_approx(cr.hit_chance(0, 0, 100), bal.num("combat.hit_min")), "hit band clamps to combat.hit_min..hit_max")
	_check(cr.final_damage(10, 0, 0, 1.0, true) == int(round(10 * bal.num("combat.crit_mult"))), "crit damage uses combat.crit_mult")
	_check(gs.inventory_slots() == bal.int_of("limits.inventory_slots") and gs.roster_cap() == bal.int_of("limits.roster_cap"), "limits come from limits.*")
	_check(is_equal_approx(gs.leader_hp_mult({"is_boss": true}), bal.num("enemies.boss_hp_mult")) and is_equal_approx(gs.leader_hp_mult({"is_elite": true}), bal.num("enemies.elite_hp_mult")) and gs.leader_hp_mult({}) == 1.0, "boss / elite leader HP multipliers")

	print("Overrides change behaviour")
	bal.override("combat.crit_mult", 2.0)
	_check(cr.final_damage(10, 0, 0, 1.0, true) == 20, "crit_mult 2.0: a crit of 10 deals 20")
	bal.override("combat.hit_base", 0.5)
	_check(is_equal_approx(cr.hit_chance(0, 0, 0), 0.5), "hit_base 0.5: even stats hit 50%")
	bal.override("death.check_penalty", 0)
	var h := {"name": "H", "stress": 0, "borde_checks": 3, "status_resist": {"golpe_de_gracia": 67}}
	_check(is_equal_approx(cr.death_save_chance(h), 0.67), "check_penalty 0: no decay after 3 rolls")
	gs.active_event_id = ""
	var price: int = int(gs.get_item("gallo_pinto").get("price", 0))
	bal.override("hub.sell_rate", 1.0)
	_check(gs.sell_price("gallo_pinto") == price, "sell_rate 1.0: the Pulpería pays full price (%d)" % price)
	bal.override("limits.inventory_slots", 30)
	_check(gs.inventory_slots() == 30, "inventory_slots 30")
	bal.override("stress.resolve_threshold", 50)
	var s := {"name": "S", "stress": 40, "hp": 10, "hp_max": 10}
	stress.add_stress(s, 15)
	_check(str(s.get("affliction_id", "")) != "" or str(s.get("virtud_id", "")) != "", "resolve_threshold 50: crossing 50 triggers the resolve check")

	print("Dragging fights (P5-02b)")
	bal.reset()
	var first: int = bal.int_of("combat.drag_round")
	var first_boss: int = bal.int_of("combat.drag_round_boss")
	_check(stress.drag_stress(first - 1) == 0 and stress.drag_stress(1) == 0, "no drag stress before round combat.drag_round (%d)" % first)
	_check(stress.drag_stress(first) == bal.int_of("combat.drag_stress"), "round %d: combat.drag_stress (%d)" % [first, bal.int_of("combat.drag_stress")])
	_check(stress.drag_stress(first + 3) == bal.int_of("combat.drag_stress") + 3 * bal.int_of("combat.drag_stress_step"), "it grows by combat.drag_stress_step every round")
	_check(first_boss >= first and stress.drag_stress(first_boss - 1, true) == 0 and stress.drag_stress(first_boss, true) == bal.int_of("combat.drag_stress"), "boss fights start at combat.drag_round_boss (%d)" % first_boss)
	bal.override("combat.drag_round", 2)
	bal.override("combat.drag_stress", 7)
	bal.override("combat.drag_stress_step", 0)
	_check(stress.drag_stress(1) == 0 and stress.drag_stress(2) == 7 and stress.drag_stress(9) == 7, "overrides: from round 2, a flat 7")
	# The controller applies it at the start of the round, to every living hero.
	var cc = load("res://scripts/combat/combat_controller.gd").new()
	cc.instant = true
	root.add_child(cc)
	var alive := {"name": "Viva", "hp": 10, "hp_max": 10, "stress": 0}
	var fallen := {"name": "Caída", "hp": 0, "hp_max": 10, "stress": 0, "dead": true}
	cc.party = [alive, fallen]
	gs.mission_light = int(bal.num("light.max"))
	cc._round = 1
	cc._apply_drag_stress()
	_check(int(alive["stress"]) == 0, "round 1: nobody gains stress")
	cc._round = 2
	cc._apply_drag_stress()
	_check(int(alive["stress"]) == 7 and int(fallen["stress"]) == 0, "round 2: every living hero gains 7, the fallen none")
	cc.queue_free()
	# A hero pinned at the cap collapses; a second Colapso in the fight is a death roll.
	bal.override("death.base", 0)
	var worn := {"name": "Rendida", "hp": 10, "hp_max": 10, "stress": bal.int_of("stress.colapso"), "status_resist": {"golpe_de_gracia": 0}}
	stress.apply_drag(worn, 7)
	_check(bool(worn.get("al_borde", false)) and not bool(worn.get("dead", false)), "drag at the stress cap: the first Colapso of the fight drops the hero to Al Borde")
	worn["al_borde"] = false
	worn["hp"] = 5
	worn["stress"] = bal.int_of("stress.colapso") - 4
	stress.add_stress(worn, 7)
	_check(bool(worn.get("dead", false)), "healed back up and collapsing again in the same fight: death roll (0% here, so the hero dies)")
	var fresh := {"name": "Nueva", "hp": 10, "hp_max": 10, "stress": 20}
	stress.apply_drag(fresh, 7)
	_check(int(fresh["stress"]) == 27 and not bool(fresh.get("al_borde", false)), "below the cap, drag is plain stress")

	bal.reset()
	_check(gs.sell_price("gallo_pinto") == int(floor(price * bal.num("hub.sell_rate"))) and gs.inventory_slots() == 24, "reset restores the data values")
	print("%d failure(s)" % _fail)
	quit(1 if _fail > 0 else 0)
