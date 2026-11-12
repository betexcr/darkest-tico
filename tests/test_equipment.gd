extends SceneTree

## Equipment, stat recompute, elements, immunities.
##   godot --headless --path . -s tests/test_equipment.gd

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
	gs.inventory.clear()
	var h: Dictionary = gs.party[0]
	var base_acc: int = int(h["accuracy"])
	for id in ["machete_bendito", "chaleco_de_guachiman", "ojo_de_venado", "botas_de_hule", "reloj_del_abuelo"]:
		gs.add_item(id, 1)
	_check(gs.equip(h, "machete_bendito") == "", "equip a weapon")
	_check(str(h["element"]) == "sagrado" and int(h["dmg_bonus"]) == 1, "weapon gives holy element and +1 damage")
	_check(gs.equip(h, "chaleco_de_guachiman") == "" and int(h["prot"]) == 20, "armour gives 20% protection")
	gs.equip(h, "ojo_de_venado")
	gs.equip(h, "botas_de_hule")
	_check(str(h["equipment"]["accessory1"]) == "ojo_de_venado" and str(h["equipment"]["accessory2"]) == "botas_de_hule", "two accessories fill both slots")
	_check(int(h["status_resist"].get("salado", 0)) == 30 + 35 and float(h["resist"].get("rayo", 1.0)) == 0.75, "accessories give debuff resist (ojo de venado) and lightning resistance")
	gs.equip(h, "reloj_del_abuelo")
	_check(gs.item_count("ojo_de_venado") == 1, "a third accessory swaps one back to the inventory")
	_check(gs.equip(h, "agua_pipa") != "", "consumables can't be equipped")
	gs.unequip(h, "weapon")
	_check(str(h["element"]) == "" and gs.item_count("machete_bendito") == 1, "unequip returns the item and clears the element")
	_check(int(h["accuracy"]) == base_acc, "stats return to base")
	gs.equip_locked = true
	_check(gs.equip(h, "machete_bendito") != "", "no equipping during a fight")
	gs.equip_turn_hero = h
	_check(gs.equip(h, "machete_bendito") == "", "the hero whose turn it is may change gear mid-fight")
	var other: Dictionary = {"name": "Otro", "equipment": {}}
	_check(gs.equip(other, "agua_pipa") != "" and not gs.can_change_equipment(other), "other heroes can't change gear mid-fight")
	gs.unequip(h, "weapon")
	gs.equip_turn_hero = {}
	gs.equip_locked = false
	var se = load("res://scripts/domain/status_effects.gd")
	h["immune"] = ["aturdido"]
	se.apply(h, "aturdido", 1, 0)
	_check(not se.has(h, "aturdido"), "immunity blocks the ailment")
	var c = load("res://scripts/combat/combat_controller.gd").new()
	var ghost := {"name": "Espanto", "elements": {"sagrado": 1.5, "oscuridad": 0.5, "agua": 0.0}}
	_check(c._elemental(10, "sagrado", ghost) == 15, "weakness: holy 10 -> 15")
	_check(c._elemental(10, "oscuridad", ghost) == 5, "resistance: dark 10 -> 5")
	_check(c._elemental(10, "agua", ghost) == 0, "immunity: water 10 -> 0")
	_check(c._elemental(10, "", ghost) == 10, "plain attacks unchanged")
	var tank := {"name": "T", "hp": 30, "hp_max": 30, "prot": 20, "guarding": true}
	c._apply_damage_to_hero(tank, 10, true)
	_check(int(tank["hp"]) == 26, "protection then guard: 10 -> 8 -> 4")
	c.free()
	var saved: Dictionary = JSON.parse_string(JSON.stringify(gs.to_save_dict()))
	gs.apply_save_data(saved)
	_check(str(gs.party[0]["equipment"].get("armor", "")) == "chaleco_de_guachiman" and int(gs.party[0]["prot"]) == 20, "equipment survives save/load")
	gs.reset_party_from_catalog()
	gs.inventory.clear()
	_check(not gs.party_can_scout(), "no scouting without the Lentes")
	gs.add_item("lentes_del_abuelo", 1)
	gs.equip(gs.party[2], "lentes_del_abuelo")
	_check(gs.party_can_scout(), "Lentes del abuelo on any party member enables scouting")
	var before_c: int = gs.colones
	var logs: PackedStringArray = gs.apply_event_outcome(gs.get_curio("caja_abuelo")["key_outcome"])
	var gained: int = gs.colones - before_c
	var gear_found: bool = gs.inventory.any(func(sl): return gs.is_equipment(str(sl["id"])))
	_check(gained >= 250 and gained <= 700, "caja del abuelo: random 250-700 colones (got %d)" % gained)
	_check(gear_found, "caja del abuelo: a random piece of equipment (%s)" % ", ".join(logs))
	var c2 = load("res://scripts/combat/combat_controller.gd").new()
	var foe := {"name": "F", "hp": 50, "hp_max": 50, "dead": false, "elements": {"agua": 0.0}}
	c2.enemies = [foe]
	c2.target_enemy = foe
	_check(c2._elemental(6, "agua", foe) == 0, "water throwable does nothing to a water-immune foe")
	c2.free()

	# --- Status resistances from class + equipment, weapon on-hit, start-of-fight effects ---
	var sx = load("res://scripts/domain/status_effects.gd")
	gs.reset_party_from_catalog()
	gs.inventory.clear()
	var camp: Dictionary = gs.party[0]
	_check(sx.resist_value(camp, "aturdido") == 40 and sx.resist_value(camp, "golpe_de_gracia") == 67, "campesino base resistances: stun 40%, death blow 67%")
	gs.add_item("termo_de_cafe", 1)
	gs.equip(camp, "termo_de_cafe")
	_check(sx.resist_value(camp, "aturdido") == 50, "termo de café: +10% stun resist")
	gs.add_item("panuelo_de_la_abuela", 1)
	gs.equip(camp, "panuelo_de_la_abuela")
	_check(sx.resist_value(camp, "sangrado") == 100, "immunity shows as 100%")
	gs.unequip(camp, "accessory1")
	gs.unequip(camp, "accessory2")
	gs.add_item("medallita_de_la_negrita", 1)
	gs.equip(camp, "medallita_de_la_negrita")
	_check(camp.get("start_status", []).size() == 1, "medallita: a start-of-fight effect")
	gs.add_item("machete_cartago", 1)
	gs.equip(camp, "machete_cartago")
	_check(camp.get("on_hit", []).size() == 1 and str(camp["on_hit"][0]["status"]) == "sangrado", "machete de Cartago: bleed on hit")
	var ix = load("res://scripts/domain/item_effects.gd")
	ix.apply_to_hero(gs.get_item("agua_de_sapo"), camp)
	_check(sx.has(camp, "chiva") and sx.stat(camp, "speed") == 2, "agua de sapo: Chiva +2 speed")
	_check(gs.item_tooltip("termo_de_cafe").contains("Resist. Atarantado"), "tooltips list status resistances")
	print("%d failure(s)" % _fail)
	quit(1 if _fail > 0 else 0)
