extends SceneTree

## Roster, recruiting, EBAIS, weekly turnover, save round trip, hub scene load.
##   godot --headless --path . -s tests/test_hub.gd

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
	gs.colones = 5000
	_check(gs.roster.size() == 4 and gs.party.size() == 4, "new game: 4 heroes, all in the party")
	_check(gs.recruit_pool.size() == 3, "3 candidates at the terminal")
	var uids: Array = gs.roster.map(func(h): return int(h["uid"]))
	_check(uids.size() == 4 and not uids.has(0), "every hero has a unique uid")
	var cost: int = gs.hire_cost(gs.recruit_pool[0])
	gs.hire_recruit(0)
	_check(gs.roster.size() == 5 and gs.colones == 5000 - cost, "hiring adds to the roster and costs %d" % cost)
	_check(gs.party.size() == 4, "a full party is not changed by hiring")
	var hired: Dictionary = gs.roster[4]
	_check(gs.set_in_party(hired, true) != "", "5th party member is refused")
	gs.set_in_party(gs.party[3], false)
	gs.set_in_party(hired, true)
	_check(gs.is_in_party(hired) and gs.party.size() == 4, "swap a hero into the party")
	gs.move_in_party(hired, -3)
	_check(is_same(gs.party[0], hired), "move to rank 1")
	var h0: Dictionary = gs.party[1]
	h0["hp"] = int(h0["hp_max"]) - 10
	_check(gs.heal_cost(h0) == maxi(10 * gs.BalanceScript.int_of("hub.heal_cost_per_hp"), gs.BalanceScript.int_of("hub.heal_min_cost")), "EBAIS price follows missing HP")
	var before: int = gs.colones
	gs.heal_hero(h0)
	_check(int(h0["hp"]) == int(h0["hp_max"]) and gs.colones < before, "EBAIS heals to full for colones")
	gs.party[2]["dead"] = true
	var dead_name: String = str(gs.party[2]["name"])
	var week: int = gs.week
	gs.end_of_expedition_week()
	_check(gs.week == week + 1, "a week passes after an expedition")
	_check(gs.roster.size() == 4 and gs.party.size() == 3, "the fallen leave roster and party")
	_check(gs.last_week_report.contains(dead_name), "week report names the fallen")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(gs.to_save_dict()))
	var party_names: Array = gs.party.map(func(h): return str(h["name"]))
	gs.apply_save_data(saved)
	_check(gs.roster.size() == 4 and gs.party.size() == 3, "save round trip keeps roster and party")
	_check(gs.party.map(func(h): return str(h["name"])) == party_names, "party order survives save/load")
	_check(is_same(gs.party[0], gs.roster.filter(func(h): return is_same(h, gs.party[0]))[0]), "party entries are roster entries")
	var old_save := {"version": 4, "colones": 100, "week": 3, "party": [gs.roster[0].duplicate(true)]}
	old_save["party"][0].erase("uid")
	gs.apply_save_data(old_save)
	_check(gs.roster.size() == 1 and gs.party.size() == 1 and int(gs.roster[0]["uid"]) > 0, "v4 save migrates to roster")
	gs.inventory.clear()
	gs.add_item("cotona_de_cuero", 1)
	var c0: int = gs.colones
	gs.sell_item("cotona_de_cuero")
	_check(gs.colones - c0 == 350 and gs.item_count("cotona_de_cuero") == 0, "selling pays half the price (700 -> 350)")
	_check(gs.sell_item("cotona_de_cuero") != "" and gs.colones - c0 == 350, "can't sell what you don't have")
	gs.reset_party_from_catalog()
	gs.inventory.clear()
	var leaver: Dictionary = gs.party[1]
	gs.add_item("cotona_de_cuero", 1)
	gs.equip(leaver, "cotona_de_cuero")
	var msg: String = gs.dismiss_hero(leaver)
	_check(gs.roster.size() == 3 and not gs.is_in_party(leaver), "dismiss removes the hero from roster and party")
	_check(gs.item_count("cotona_de_cuero") == 1, "dismissed hero's equipment returns to the inventory (%s)" % msg)
	while gs.roster.size() > 1:
		gs.dismiss_hero(gs.roster[0])
	_check(gs.dismiss_hero(gs.roster[0]) != "" and gs.roster.size() == 1, "the last hero can't be dismissed")
	gs.reset_party_from_catalog()
	var hub = load("res://scenes/hacienda/hacienda_hub.tscn").instantiate()
	root.add_child(hub)
	await process_frame
	await process_frame
	_check(hub._roster_list.get_child_count() == 4, "hub lists 4 heroes")
	_check(hub._recruit_box.get_child_count() == 3, "hub lists 3 candidates")
	var counts: Dictionary = {}
	for f in ["todo", "consumable", "weapon", "armor", "accessory"]:
		hub._shop_filter = f
		hub._build_shop()
		await process_frame
		counts[f] = hub._shop_grid.get_children().filter(func(b): return not b.is_queued_for_deletion()).size()
	_check(counts["todo"] == gs.all_item_ids().size(), "store 'Todo' lists all %d items" % counts["todo"])
	_check(counts["consumable"] + counts["weapon"] + counts["armor"] + counts["accessory"] == counts["todo"],
		"filters split the store: %d consumibles, %d armas, %d armaduras, %d accesorios" % [
		counts["consumable"], counts["weapon"], counts["armor"], counts["accessory"]])
	# Pulpería tiles are icons with a price; the full text lives in the tooltip card.
	hub._shop_filter = "todo"
	hub._build_shop()
	await process_frame
	var tiles: Array = hub._shop_grid.get_children().filter(func(b): return not b.is_queued_for_deletion())
	var tile = tiles[0]
	_check(tile.icon != null and tile.text == "%d ₡" % gs.item_price(tile.item_id), "store tile shows icon + price only (%s)" % tile.text)
	var card = tile._make_custom_tooltip("")
	_check(card is Control and card.get_theme_stylebox("panel").bg_color.a == 1.0, "item tooltip is an opaque card")
	card.free()
	var c1: int = gs.item_count(tile.item_id)
	gs.colones = 5000
	tile.pressed.emit()
	_check(gs.item_count(tile.item_id) == c1 + 1, "clicking a store tile buys the item")
	gs.colones = 0
	hub._refresh()
	_check(tile.disabled, "store tiles disable when the colones don't reach")
	print("%d failure(s)" % _fail)
	quit(1 if _fail > 0 else 0)
