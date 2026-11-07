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
	_check(h["immune"].has("aturdido") and float(h["resist"].get("rayo", 1.0)) == 0.75, "accessories give stun immunity and lightning resistance")
	gs.equip(h, "reloj_del_abuelo")
	_check(gs.item_count("ojo_de_venado") == 1, "a third accessory swaps one back to the inventory")
	_check(gs.equip(h, "agua_pipa") != "", "consumables can't be equipped")
	gs.unequip(h, "weapon")
	_check(str(h["element"]) == "" and gs.item_count("machete_bendito") == 1, "unequip returns the item and clears the element")
	_check(int(h["accuracy"]) == base_acc, "stats return to base")
	gs.equip_locked = true
	_check(gs.equip(h, "machete_bendito") != "", "no equipping during a fight")
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
	print("%d failure(s)" % _fail)
	quit(1 if _fail > 0 else 0)
