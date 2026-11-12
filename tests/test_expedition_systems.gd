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
	_test_light(gs)
	_test_hunger(gs)
	await _test_traps(gs)
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
	gs.apply_event_outcome({"damage_random": 6})
	_check(int(v["hp"]) == 0 and bool(v.get("al_borde", false)), "curio damage to 0 PV makes the hero Al Borde")
	for other in gs.party:
		other["dead"] = false
		other["al_borde"] = false
		other["hp"] = other["hp_max"]


func _test_light(gs) -> void:
	print("Luz tiers (P1-17)")
	var ls = load("res://scripts/domain/light_system.gd")
	var bal = load("res://scripts/domain/balance.gd")
	var names: Array = [100, 76, 75, 51, 50, 26, 25, 1, 0].map(func(l): return str(ls.tier(l)["id"]))
	_check(names == ["radiante", "radiante", "tenue", "tenue", "penumbra", "penumbra", "oscuro", "oscuro", "negro"], "tier boundaries 76/51/26/1/0: %s" % [names])
	_check(not ls.is_low(51) and ls.is_low(50) and ls.is_low(0), "Penumbra and darker count as low light")

	# Loot: the tier's bonus multiplies the room reward.
	gs.mission_event = {}
	gs.mission_light = 100
	var bright: float = gs.loot_mult()
	gs.mission_light = 0
	var dark: float = gs.loot_mult()
	_check(is_equal_approx(bright, 1.0) and is_equal_approx(dark, 1.0 + ls.val(0, "loot_pct") / 100.0), "loot x%.2f at Radiante, x%.2f at Negro" % [bright, dark])

	# Combat: hero stress taken grows in the dark (_stress_after_mods reads the live Luz).
	var cc = load("res://scripts/combat/combat_controller.gd").new()
	var h := _hero(10)
	gs.mission_light = 100
	var s_bright: int = cc._stress_after_mods(h, 10)
	gs.mission_light = 0
	var s_dark: int = cc._stress_after_mods(h, 10)
	_check(s_bright == 10 and s_dark == int(round(10 * (1.0 + ls.val(0, "stress_pct") / 100.0))), "stress 10 -> %d at Radiante, %d at Negro" % [s_bright, s_dark])
	cc.free()

	# Surprise: forced through the tier numbers.
	bal.override("light.tiers", [
		{"id": "a", "name": "A", "min": 50, "enemy_dmg_pct": 0, "enemy_crit": 0, "stress_pct": 0, "loot_pct": 0, "party_surprised_pct": 0, "enemies_surprised_pct": 100, "trap_pct": 0, "move_stress": 0, "move_stress_all": false, "low": false},
		{"id": "b", "name": "B", "min": 0, "enemy_dmg_pct": 0, "enemy_crit": 0, "stress_pct": 0, "loot_pct": 0, "party_surprised_pct": 100, "enemies_surprised_pct": 0, "trap_pct": 0, "move_stress": 4, "move_stress_all": true, "low": true}])
	_check(ls.roll_surprise(80) == "enemies" and ls.roll_surprise(10) == "party", "surprise rolls follow the tier (100% enemies / 100% party)")
	# Walking in the dark: move_stress to everyone in the all-tier.
	var start_id: String = gs.current_node_id
	var nb: Array = gs.mission_neighbors()
	gs.mission_light = 10
	for p in gs.party:
		p["stress"] = 0
	gs.move_to_node(str(nb[0]))
	_check(gs.party.all(func(p): return int(p["stress"]) == 4), "each move in the darkest tier: +4 stress to every hero")
	gs.mission_light = 90
	var lux0: int = gs.mission_light
	gs.move_to_node(start_id)
	_check(gs.mission_light == lux0 - int(gs.mission_params["light_decay"]) and gs.party.all(func(p): return int(p["stress"]) == 4), "a bright move only costs Luz (%d per move)" % int(gs.mission_params["light_decay"]))
	bal.reset()
	for p in gs.party:
		p["stress"] = 0
	# Apagar la candela.
	gs.mission_light = 60
	var lost: int = gs.snuff_light()
	_check(lost == bal.int_of("light.snuff") and gs.mission_light == 60 - lost, "Apagar la candela: -%d Luz" % lost)
	gs.mission_light = 10
	_check(gs.snuff_light() == 10 and gs.mission_light == 0, "…never below 0")
	# Camp: ambush in low light, exhausted party, Luz resets to light_max.
	var camp = load("res://scripts/domain/camping_system.gd")
	var calm: Array = [{"stress": 10}, {"stress": 20}]
	var tired: Array = [{"stress": 60}, {"stress": 50}]
	_check(camp.ambush_chance(100, false, calm) == 12 and camp.ambush_chance(30, false, calm) == 18, "ambush 12% bright / 18% at Penumbra")
	_check(camp.ambush_chance(100, false, tired) == 16 and camp.ambush_chance(100, true, tired) == 0, "exhausted party (avg stress 50+) +4%; a watch still makes it 0")
	gs.mission_light = 100


func _test_hunger(gs) -> void:
	print("Travel hunger (P1-18)")
	var bal = load("res://scripts/domain/balance.gd")
	var every: int = bal.int_of("hunger.every_moves")
	gs.mission_light = 100
	gs.moves_since_meal = 0
	var a: String = gs.current_node_id
	var b: String = str(gs.mission_neighbors()[0])
	for k in every - 1:
		gs.move_to_node(b if k % 2 == 0 else a)
	_check(not gs.hunger_due(), "not hungry after %d moves" % (every - 1))
	gs.move_to_node(b if gs.current_node_id == a else a)
	_check(gs.hunger_due(), "hungry after %d moves" % every)

	for p in gs.party:
		p["hp"] = p["hp_max"]
		p["stress"] = 0
	gs.inventory.clear()
	gs.add_item("gallo_pinto", 6)
	gs.travel_meal(4)
	_check(gs.item_count("gallo_pinto") == 2 and not gs.hunger_due(), "everyone eats: 4 gallo pinto, count reset")
	_check(gs.party.all(func(p): return int(p["hp"]) == int(p["hp_max"]) and int(p["stress"]) == 0), "…and nobody suffers")

	# Short of food: the most hurt eat first; the rest lose PV (never below 1) and gain stress.
	gs.party[2]["hp"] = 1
	gs.travel_meal(2)
	var hungry: Array = gs.party.filter(func(p): return int(p["stress"]) == bal.int_of("hunger.stress"))
	_check(gs.item_count("gallo_pinto") == 0 and hungry.size() == 2, "2 gallo pinto for 4 heroes: 2 go hungry (+%d stress)" % bal.int_of("hunger.stress"))
	_check(int(gs.party[2]["stress"]) == 0 and int(gs.party[2]["hp"]) == 1, "the most hurt hero eats first")
	var h0: Dictionary = hungry[0]
	_check(int(h0["hp"]) == int(h0["hp_max"]) - int(round(int(h0["hp_max"]) * bal.int_of("hunger.hp_pct") / 100.0)), "hunger costs %d%% of max PV" % bal.int_of("hunger.hp_pct"))
	var weak := {"name": "Débil", "hp": 1, "hp_max": 30, "stress": 0}
	load("res://scripts/domain/camping_system.gd").travel_meal([weak], 0)
	_check(int(weak["hp"]) == 1 and not weak.get("al_borde", false), "hunger never drops a hero below 1 PV")
	gs.travel_meal(4)
	_check(gs.item_count("gallo_pinto") == 0, "with no food nobody eats (nothing goes negative)")

	# Provisions: the region's recommended list against the alforja.
	gs.inventory.clear()
	gs.add_item("gallo_pinto", 3)
	var miss: Array = gs.missing_provisions()
	var gp: Array = miss.filter(func(m): return m["id"] == "gallo_pinto")
	_check(not gp.is_empty() and int(gp[0]["missing"]) == 7 and int(gp[0]["price"]) == 7 * gs.item_price("gallo_pinto"), "provisions: 7 gallo pinto missing of 10 (%d ₡)" % (int(gp[0]["price"]) if not gp.is_empty() else -1))
	gs.colones = 100000
	gs.buy_missing_provisions()
	_check(gs.missing_provisions().is_empty() and gs.item_count("gallo_pinto") == 10, "buying what is missing fills the recommended list")
	for p in gs.party:
		p["hp"] = p["hp_max"]
		p["stress"] = 0
	gs.moves_since_meal = 0


func _test_traps(gs) -> void:
	print("Traps (P2-01)")
	var tr = load("res://scripts/domain/trap_rules.gd")
	var ls = load("res://scripts/domain/light_system.gd")
	var se = load("res://scripts/domain/status_effects.gd")
	var trap: Dictionary = tr.get_trap("alambre_de_pua")
	_check(not trap.is_empty(), "alambre_de_pua is in traps.json")
	var best: int = 0
	for h in gs.party:
		best = maxi(best, se.resist_value(h, "trampa"))
	var bright: int = tr.disarm_chance(trap, gs.party, 100)
	var dark: int = tr.disarm_chance(trap, gs.party, 0)
	_check(bright == clampi(best + ls.val(100, "trap_pct") - int(trap["difficulty"]), tr.num("disarm_min"), tr.num("disarm_max")), "disarm = best trampa %d + Luz %+d - difficulty %d -> %d%%" % [best, ls.val(100, "trap_pct"), int(trap["difficulty"]), bright])
	_check(dark < bright, "darker is harder to disarm (%d%% at Negro)" % dark)
	_check(tr.disarm_chance({"difficulty": -999}, gs.party, 100) == tr.num("disarm_max") and tr.disarm_chance({"difficulty": 999}, gs.party, 0) == tr.num("disarm_min"), "disarm chance is clamped")

	# Springing: alambre bleeds the hero it cuts; piso hundido roots them (resists off).
	var resists: Array = gs.party.map(func(p): return p.get("status_resist", {}))
	for p in gs.party:
		p["hp"] = p["hp_max"]
		p["status_resist"] = {}
		se.clear(p)
	gs.apply_event_outcome(trap["effects"])
	var cut: Array = gs.party.filter(func(p): return int(p["hp"]) < int(p["hp_max"]))
	_check(cut.size() == 1 and se.has(cut[0], "sangrado"), "Alambre de púas: one hero loses PV and bleeds")
	for p in gs.party:
		p["hp"] = p["hp_max"]
		se.clear(p)
	gs.apply_event_outcome(tr.get_trap("piso_hundido")["effects"])
	_check(gs.party.filter(func(p): return se.has(p, "amarrado")).size() == 1, "Piso hundido: one hero is Amarrado")
	for k in gs.party.size():
		gs.party[k]["hp"] = gs.party[k]["hp_max"]
		gs.party[k]["status_resist"] = resists[k]
		se.clear(gs.party[k])

	# The generator gives trap rooms a trap_id (try seeds until a map has a trap room).
	var mg = load("res://scripts/domain/map_generator.gd")
	var region: Dictionary = load("res://scripts/domain/expedition_loader.gd").load_region("res://data/regions/sotanos.json")
	var gen_trap: Dictionary = {}
	for sd in 40:
		for n in mg.generate(region, sd)["nodes"]:
			if str(n.get("type", "")) == "trap":
				gen_trap = n
		if not gen_trap.is_empty():
			break
	_check(not gen_trap.is_empty() and region["generator"]["traps"].has(str(gen_trap.get("trap_id", ""))), "generated trap rooms carry a trap_id from the region list (%s)" % gen_trap.get("trap_id", "?"))
	# The real trap event: "Pasar con cuidado" costs Luz (trigger chance forced to 0).
	var trap_id: String = "sim_trap"
	gs.mission_nodes_index[trap_id] = {"id": trap_id, "type": "trap", "trap_id": "vigas_inestables", "label": "Vigas inestables"}
	var screen = load("res://scenes/expedition/expedition_screen.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	gs.current_node_id = trap_id
	gs.mission_light = 100
	var saved: int = tr.data()["careful_trigger_pct"]
	tr.data()["careful_trigger_pct"] = 0
	screen._open_trap()
	var buttons: Array = screen._event_actions.get_children().filter(func(b): return b is Button and not b.is_queued_for_deletion())
	_check(buttons.size() == 2 and str(buttons[0].text).begins_with("Desarmar") and str(buttons[1].text).begins_with("Pasar con cuidado"), "trap event offers Desarmar and Pasar con cuidado")
	buttons[1].pressed.emit()
	_check(gs.mission_light == 100 - tr.num("careful_light") and gs.is_node_cleared(trap_id), "Pasar con cuidado: -%d Luz, room cleared" % tr.num("careful_light"))
	tr.data()["careful_trigger_pct"] = saved
	gs.mission_nodes_index.erase(trap_id)
	screen.queue_free()
	await process_frame
	gs.mission_light = 100
