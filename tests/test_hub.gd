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
	_check(cost == 0 and gs.roster.size() == 5 and gs.colones == 5000, "hiring adds to the roster and is free (owner 2026-11-15, as in Darkest Dungeon)")
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
	# P4-18 / P3-05a: the Pulpería sells consumables, the Taller weapons and armor, the
	# Feria Nocturna this week's accessories.
	var live := func(g): return g.get_children().filter(func(b): return not b.is_queued_for_deletion())
	var equip_ids: Array = gs.all_item_ids().filter(func(i): return gs.is_equipment(str(i)))
	var acc_ids: Array = equip_ids.filter(func(i): return gs.is_accessory(str(i)))
	hub._shop_filter = "todo"
	hub._build_shop()
	await process_frame
	var pul: Array = live.call(hub._shop_grid)
	_check(pul.size() == gs.all_item_ids().size() - equip_ids.size() and pul.all(func(t): return not gs.is_equipment(t.item_id)),
		"the Pulpería sells only consumables (%d)" % pul.size())
	_check(live.call(hub._taller_grid).size() == equip_ids.size() - acc_ids.size(), "the Taller sells all %d weapons and armors, no accessories" % (equip_ids.size() - acc_ids.size()))
	var counts: Dictionary = {}
	for f in ["weapon", "armor"]:
		hub._shop_filter = f
		hub._build_shop()
		await process_frame
		counts[f] = live.call(hub._taller_grid).size()
	_check(counts["weapon"] + counts["armor"] == equip_ids.size() - acc_ids.size(),
		"the Taller's filters split it: %d armas, %d armaduras" % [counts["weapon"], counts["armor"]])
	var stall: Array = live.call(hub._feria_grid)
	_check(stall.size() == gs.feria_stock.size() and gs.feria_stock.size() == mini(gs.BalanceScript.int_of("feria.stock_size"), acc_ids.size()),
		"the Feria Nocturna shows this week's %d accessories" % stall.size())
	_check(stall.all(func(t): return gs.is_accessory(t.item_id)), "…all of them accessories")
	_check(gs.shop_of("gallo_pinto") == "pulperia" and gs.shop_of("cotona_de_cuero") == "taller" and gs.shop_of(str(acc_ids[0])) == "feria",
		"shop_of: food at the Pulpería, armor at the Taller, accessories at the Feria")
	var gone: String = ""
	for a in acc_ids:
		if not gs.feria_stock.has(a):
			gone = str(a)
			break
	_check(gone == "" or gs.buy_item(gone).begins_with("La Feria Nocturna no trae"), "an accessory not on the stall this week can't be bought")
	var on_stall: String = str(gs.feria_stock[0])
	gs.colones = 5000
	var c_f: int = gs.colones
	_check(gs.buy_item(on_stall).begins_with("Compraste") and gs.colones < c_f and not gs.feria_stock.has(on_stall), "buying one takes it off the stall")
	hub._refresh()
	await process_frame
	_check(live.call(hub._feria_grid).size() == gs.feria_stock.size(), "the stall's tiles follow (%d left)" % gs.feria_stock.size())
	_check(gs.buy_item(on_stall).begins_with("La Feria Nocturna no trae"), "…one of each: no second one this week")
	_check(gs.sell_item(on_stall, "taller").begins_with("El taller solo compra"), "the Taller doesn't buy accessories")
	var c_s: int = gs.colones
	_check(gs.sell_item(on_stall).begins_with("Vendiste") and gs.colones - c_s == int(gs.get_item(on_stall)["price"]) / 2 and not gs.feria_stock.has(on_stall),
		"the Feria buys it back at half price (it doesn't go back on the stall)")
	gs.end_of_expedition_week()
	_check(gs.feria_stock.size() == mini(gs.BalanceScript.int_of("feria.stock_size"), acc_ids.size()), "a new week brings a full stall again")
	var fsave: Dictionary = gs.to_save_dict()
	var kept: Array = gs.feria_stock.duplicate()
	gs.feria_stock = []
	gs.apply_save_data(fsave)
	_check(gs.feria_stock == kept, "the stall is saved and loaded")
	fsave.erase("feria_stock")
	gs.apply_save_data(fsave)
	_check(gs.feria_stock.size() > 0, "an old save (v15) gets a fresh stall")
	gs.add_item("gallo_pinto", 1)
	_check(gs.sell_item("gallo_pinto", "taller").begins_with("El taller solo compra"), "the Taller doesn't buy food")
	gs.add_item("cotona_de_cuero", 1)
	_check(gs.sell_item("cotona_de_cuero", "pulperia").begins_with("La pulpería no compra equipo"), "the Pulpería doesn't buy equipment")
	_check(gs.sell_item("cotona_de_cuero", "feria").begins_with("La Feria Nocturna solo compra accesorios"), "the Feria doesn't buy armor")
	var c2: int = gs.colones
	_check(gs.sell_item("cotona_de_cuero").begins_with("Vendiste") and gs.colones - c2 == 350, "with no shop given, it sells at its own shop (the Taller)")
	# Pulpería tiles are icons with a price; the full text lives in the tooltip card.
	hub._shop_filter = "todo"
	hub._build_shop()
	await process_frame
	var tiles: Array = live.call(hub._shop_grid)
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
	# Every item says what it does (owner 2026-11-19): anything with effects, curio keys or
	# scouting has at least one line on its card.
	var silent: Array = gs.all_item_ids().filter(func(i):
		var it: Dictionary = gs.get_item(str(i))
		var does: bool = not it.get("effects", {}).is_empty() or not it.get("curio_keys", []).is_empty() or bool(it.get("scout", false))
		return does and gs.item_tooltip_parts(str(i))["stats"].is_empty())
	_check(silent.is_empty(), "every item card describes its effects (silent: %s)" % ", ".join(silent))
	var pipa: Array = gs.item_tooltip_parts("agua_pipa")["stats"]
	_check(pipa.has("Cura 8 PV"), "agua de pipa: 'Cura 8 PV'")
	# Dev menu (owner 2026-11-19): infinite money, next week now, +1 resolución.
	gs.reset_party_from_catalog()
	gs.dev_set_infinite_money(true)
	var rich: int = gs.colones
	gs.buy_item("gallo_pinto")
	_check(rich == gs.DEV_MONEY and gs.colones == gs.DEV_MONEY, "infinite money: buying doesn't lower the bank")
	gs.dev_set_infinite_money(false)
	gs.colones = 1000
	_check(gs.colones == 1000, "turned off, colones behave again")
	var wk: int = gs.week
	var stressed: Dictionary = gs.party[0]
	stressed["stress"] = 50
	var old_pool: Array = gs.recruit_pool.duplicate()
	gs.dev_skip_week()
	_check(gs.week == wk + 1, "next week: the week number goes up")
	_check(int(stressed["stress"]) == 50 - gs.BalanceScript.int_of("hub.idle_stress_relief"), "…a party hero rests at home too (no expedition)")
	_check(gs.recruit_pool != old_pool or old_pool.is_empty(), "…new candidates at the terminal")
	var lv: int = int(gs.party[1]["resolve_level"])
	gs.dev_add_resolve(gs.party[1])
	_check(int(gs.party[1]["resolve_level"]) == lv + 1 and int(gs.party[1]["resolve_xp"]) == gs.ResolveSystemScript.xp_for_level(lv + 1), "+1 resolución: one level, with its XP")
	# Men and women (owner 2026-11-19): sex, names, class name and art follow it.
	var camp_t: Dictionary = gs.get_hero_template("campesino")
	var hf: Dictionary = gs._instantiate_hero(camp_t, "f")
	var hm: Dictionary = gs._instantiate_hero(camp_t, "m")
	_check(hf["sex"] == "f" and camp_t["names_f"].has(hf["name"]) and hf["class_name"] == "Campesina Machetera", "a woman gets a woman's name and the class name for her")
	_check(hm["sex"] == "m" and camp_t["names_m"].has(hm["name"]) and hm["class_name"] == "Campesino Machetero", "a man too")
	_check(gs.art_id(hm) == "campesino" and gs.art_id(hf) == "campesino_f", "art: the class's own set for its base sex, <id>_<sex> for the other")
	_check(gs.portrait_path(hf).begins_with("res://assets/portraits/campesino"), "the portrait path is the woman's (or the base one until it exists)")
	var both: Dictionary = {}
	for i in 400:
		both[gs._instantiate_hero(camp_t)["sex"]] = true
	_check(both.has("m") and both.has("f"), "recruits come as men and women")
	gs.reset_party_from_catalog()
	while gs.roster.size() < 12:
		gs.roster.append(gs._instantiate_hero(camp_t, "m"))
	var nm: Array = gs.roster.filter(func(x): return x["hero_id"] == "campesino").map(func(x): return x["name"])
	var uniq: Dictionary = {}
	for n in nm:
		uniq[n] = true
	_check(uniq.size() == nm.size(), "names don't repeat while the class list has free ones (%d campesinos)" % nm.size())
	var old: Dictionary = gs._sanitize_runtime_hero({"hero_id": "abuela", "name": "Doña Cuca", "hp": 10, "hp_max": 20})
	var old2: Dictionary = gs._sanitize_runtime_hero({"hero_id": "abuela", "name": "Don Ramón", "hp": 10, "hp_max": 20})
	var old3: Dictionary = gs._sanitize_runtime_hero({"hero_id": "curandero", "name": "Nadie", "hp": 10, "hp_max": 20})
	_check(old["sex"] == "f" and old2["sex"] == "m" and old2["class_name"] == "Abuelo Sabio" and old3["sex"] == "f", "old saves: sex from the name lists, else the class's base sex")
	gs.reset_party_from_catalog()
	gs.dev_set_colones(4321)
	_check(gs.colones == 4321 and not gs.dev_infinite_money, "dev: set an exact amount of colones")
	gs.dev_set_infinite_money(true)
	gs.dev_set_colones(50)
	_check(gs.colones == 50 and not gs.dev_infinite_money, "…which also turns infinite money off")
	gs.dev_skip_week()
	gs.party[0]["stress"] = 90
	gs.add_item("gallo_pinto", 3)
	gs.dev_reset_campaign()
	var start_inv: int = 0
	for it in gs.inventory:
		start_inv += 1
	_check(gs.week == 1 and gs.colones == gs.BalanceScript.int_of("hub.start_colones"), "dev reset: week 1 and the starting colones")
	_check(gs.roster.size() == 4 and gs.party.size() == 4 and int(gs.party[0]["stress"]) == 0, "…the four starter heroes, fresh")
	_check(not gs.get_item("gallo_pinto").is_empty() and gs.get_hero_template("campesino").size() > 0, "…catalogs still loaded")
	_check(start_inv > 0 and not gs.recruit_pool.is_empty(), "…starter alforja and new candidates")
	# New campaign (owner 2026-11-20): random classes, always 2 warriors in front + 2 supports.
	var combos: Dictionary = {}
	for _i in 30:
		gs.reset_party_from_catalog(true)
		var roles: Array = gs.party.map(func(h): return str(gs.get_hero_template(str(h["hero_id"])).get("role", "")))
		var ids: Array = gs.party.map(func(h): return str(h["hero_id"]))
		var start_ids: Dictionary = {}
		for id in ids:
			start_ids[id] = true
		if roles != ["warrior", "warrior", "support", "support"] or start_ids.size() != 4:
			_check(false, "new campaign party is 2 warriors then 2 supports, no class twice (got %s)" % [ids])
			break
		combos[",".join(ids)] = true
	_check(combos.size() > 1, "…and the classes change between new campaigns")
	gs.reset_party_from_catalog()
	_check(gs.party.map(func(h): return str(h["hero_id"])) == ["campesino", "montador", "abuela", "tecnologo"], "…while scripts keep the fixed starter party")
	print("%d failure(s)" % _fail)
	quit(1 if _fail > 0 else 0)
