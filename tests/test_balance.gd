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

	bal.reset()
	_check(gs.sell_price("gallo_pinto") == int(floor(price * bal.num("hub.sell_rate"))) and gs.inventory_slots() == 24, "reset restores the data values")
	print("%d failure(s)" % _fail)
	quit(1 if _fail > 0 else 0)
