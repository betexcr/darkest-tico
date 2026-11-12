extends SceneTree

## Town events (Tico versions of Darkest Dungeon's), Modo Pura Vida, Mano vuelta.
##   godot --headless --path . -s tests/test_town_events.gd

var _fail: int = 0


func _check(cond: bool, what: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + what)
	if not cond:
		_fail += 1


func _initialize() -> void:
	_run.call_deferred()


func _fresh(gs) -> void:
	gs.end_mission_abandon()
	gs.reset_party_from_catalog()
	gs.reset_inventory_to_starter()
	gs.colones = 20000
	gs.week = 5
	gs.graveyard.clear()
	gs.stolen_items.clear()
	gs.events_done_once.clear()
	gs.active_event_id = ""
	gs.event_flags = {}
	gs.set_radiant_mode(false)
	gs.selected_difficulty_id = "aprendiz"


func _run() -> void:
	await process_frame
	var gs = root.get_node("GameState")
	var te = load("res://scripts/domain/town_events.gd")
	var rs = load("res://scripts/domain/resolve_system.gd")
	var stress = load("res://scripts/domain/stress_system.gd")

	print("Data")
	_check(te.all().size() >= 50, "%d town events" % te.all().size())
	var dd: Dictionary = {}
	for e in te.all():
		dd[str(e.get("dd", ""))] = true
	for name in ["Helping Hand", "Bumper Crop", "Lost Shipment", "Caregivers Convention", "Absent Abbot",
			"A Day Long Awaited", "From Beyond", "A Thief in the Night", "Brigand Incursion", "Experienced Hero for Hire"]:
		_check(dd.has(name), "has a Tico version of '%s'" % name)

	print("Every event can be drawn and applied")
	var hub_scene: PackedScene = load("res://scenes/hacienda/hacienda_hub.tscn")
	for e in te.all():
		_fresh(gs)
		var dead: Dictionary = gs.party[3]
		dead["dead"] = true
		gs.graveyard.append(dead.duplicate(true))
		gs.party[0]["affliction_id"] = "nervios"
		gs.party[1]["affliction_id"] = "bravata"
		gs.draw_town_event(str(e["id"]))
		var hub = hub_scene.instantiate()
		root.add_child(hub)
		await process_frame
		hub.queue_free()
		await process_frame
		await process_frame
		_check(gs.active_event_id == str(e["id"]) and te.effect_lines(e).size() > 0, "%s: applies and describes itself" % e["id"])
	await process_frame

	print("Prices and services")
	_fresh(gs)
	gs.draw_town_event("cosecha_de_frijoles")
	_check(gs.item_price("gallo_pinto") == 0, "Cosecha de frijoles: consumables free")
	_check(gs.item_price("machete_cartago") == int(gs.get_item("machete_cartago")["price"]), "…weapons unchanged")
	gs.draw_town_event("huelga_de_transportistas")
	var gp: int = int(gs.get_item("gallo_pinto")["price"])
	_check(gs.item_price("gallo_pinto") == int(round(gp * 1.5)), "Huelga de transportistas: gallo pinto %d -> %d" % [gp, gs.item_price("gallo_pinto")])
	gs.draw_town_event("guino_de_la_pulpera")
	var acc: String = "escapulario"
	var full: int = int(gs.get_item(acc)["price"])
	_check(gs.item_price(acc) == int(round(full * 0.2)), "La pulpera anda de buenas: first accessory -80%")
	gs.buy_item(acc)
	_check(gs.item_price(acc) == full, "…only the first one")
	gs.draw_town_event("compraventa")
	_check(gs.sell_price(acc) == full, "Compraventa: accessories sell at full price")
	gs.draw_town_event("ley_seca")
	_check(gs.buy_block_reason("guaro_contrabando") != "" and gs.buy_block_reason("gallo_pinto") == "", "Ley seca: no guaro, gallo pinto ok")
	gs.draw_town_event("asalto_a_la_pulperia")
	_check(gs.buy_item("gallo_pinto").begins_with("La pulpería está cerrada"), "Asaltaron la pulpería: can't buy")
	gs.draw_town_event("corte_de_luz")
	_check(gs.sell_item("gallo_pinto").begins_with("La pulpería no compra"), "Corte de luz: can't sell")
	gs.draw_town_event("el_padre_de_gira")
	_check(gs.iglesia_misa_rapida().begins_with("La Iglesia Vieja está cerrada"), "El padre anda de gira: Iglesia closed")
	gs.party[0]["hp"] = 10
	var ebais_full: int = maxi((int(gs.party[0]["hp_max"]) - 10) * gs.BalanceScript.int_of("hub.heal_cost_per_hp"), gs.BalanceScript.int_of("hub.heal_min_cost"))
	_check(gs.heal_cost(gs.party[0]) == ebais_full / 2, "…EBAIS at half price")
	gs.draw_town_event("feria_de_la_salud")
	var before_c: int = gs.colones
	gs.heal_hero(gs.party[0])
	_check(gs.colones == before_c and int(gs.party[0]["hp"]) == int(gs.party[0]["hp_max"]), "Feria de la salud: EBAIS free")
	gs.draw_town_event("romeria")
	_check(gs.iglesia_cost() == 0, "Romería: misa free")
	gs.draw_town_event("mananita_de_sol")
	_check(gs.iglesia_relief() == 13, "Mañanitas de sol: misa relieves 13 instead of 10")
	gs.draw_town_event("arreglan_la_terminal")
	_check(gs.hire_recruit(0).begins_with("La terminal está cerrada"), "Arreglan la terminal: no hiring")

	print("Heroes")
	_fresh(gs)
	var idle: Dictionary = gs.recruit_pool[0]
	idle["uid"] = 999
	gs.roster.append(idle)
	idle["stress"] = 50
	gs.draw_town_event("semana_pura_vida")
	_check(int(idle["stress"]) == 10 and int(gs.party[0]["stress"]) == 0, "Una semana pura vida: idle hero -40 stress, party untouched")
	idle["class_id"] = "montador"
	var lvl0: int = int(idle["resolve_level"])
	gs.draw_town_event("corridas_a_la_tica")
	_check(int(idle["resolve_level"]) == lvl0 + 1, "Corridas: idle Montador +1 resolve level")
	var pool0: int = gs.recruit_pool.size()
	gs.draw_town_event("llego_el_bus_de_la_frontera")
	_check(gs.recruit_pool.size() == pool0 + 6, "Bus de la frontera: +6 candidates")
	gs.draw_town_event("epoca_de_zafra")
	var last2: Array = gs.recruit_pool.slice(gs.recruit_pool.size() - 2)
	_check(last2.all(func(h): return h["class_id"] == "machetero"), "Época de zafra: 2 Macheteros at the terminal")
	gs.draw_town_event("veterano_de_las_bananeras")
	var vet: Dictionary = gs.recruit_pool[gs.recruit_pool.size() - 1]
	_check(int(vet["resolve_level"]) == 6 and gs.hire_cost(vet) == 6000, "Veterano: Resolución 6 for 6000 ₡")
	var r0: int = gs.roster.size()
	gs.draw_town_event("forastero")
	_check(gs.roster.size() == r0 + 1, "Un forastero joins the roster for free")

	print("Special")
	_fresh(gs)
	var fallen: Dictionary = gs.party[3].duplicate(true)
	fallen["dead"] = true
	fallen["resolve_level"] = 3
	fallen["uid"] = 777
	gs.party.remove_at(3)
	gs.roster.remove_at(3)
	gs.graveyard.append(fallen)
	gs.draw_town_event("dia_de_difuntos")
	_check(gs.resurrect_candidates().size() == 1, "Día de los Difuntos offers the fallen")
	gs.resurrect(777)
	var back: Array = gs.roster.filter(func(h): return int(h["uid"]) == 777)
	_check(back.size() == 1 and not back[0]["dead"] and int(back[0]["resolve_level"]) == 3 and back[0]["equipment"].is_empty(), "…comes back with its level, without gear")
	_check(gs.resurrect_candidates().is_empty(), "…only one per event")
	var inv0: int = gs.item_count("gallo_pinto") + gs.item_count("agua_pipa")
	gs.draw_town_event("ladron_de_gallinas")
	_check(gs.stolen_items.size() >= 1, "Ladrón de gallinas steals %d items" % gs.stolen_items.size())
	gs.draw_town_event("limpia_general")
	for h in gs.roster:
		h["stress"] = 80
	gs.take_event_offer()
	_check(gs.roster.all(func(h): return int(h["stress"]) == 30), "Limpia general: -50 stress for 1500 ₡")
	_check(gs.event_offer().is_empty(), "…once")

	print("Expedition modifiers")
	_fresh(gs)
	gs.stolen_items = ["gallo_pinto"]
	gs.draw_town_event("ventilaron_los_sotanos")
	_check(gs.start_mission(), "start in Sótanos")
	_check(int(gs.mission_difficulty["xp"]) == 5, "Ventilaron los sótanos: XP 4 -> 5 (+33%)")
	_check(gs.party[0]["camp_buffs"].any(func(b): return int(b["mods"].get("dmg_pct", 0)) == 15), "…+15% damage buff all expedition")
	var sm: Dictionary = gs.complete_mission()
	_check(int(sm["ledger"]["items"].get("gallo_pinto", 0)) >= 1 and gs.stolen_items.is_empty(), "stolen items come back on a completed expedition")
	gs.end_mission_abandon()
	_check(gs.party[0]["camp_buffs"].is_empty(), "event buff ends with the mission")
	gs.draw_town_event("sol_en_la_neblina")
	gs.start_mission()
	_check(int(gs.mission_difficulty["xp"]) == 4, "Sol en el bosque nuboso does nothing in Sótanos")
	gs.end_mission_abandon()
	gs.draw_town_event("veranillo_de_san_juan")
	gs.start_mission()
	_check(int(gs.mission_params["light_decay"]) < 5, "Veranillo de San Juan: Luz decays slower (%d)" % int(gs.mission_params["light_decay"]))
	gs.end_mission_abandon()
	gs.draw_town_event("club_de_excursionistas")
	gs.start_mission()
	_check(gs.mission_firewood == 2, "Club de excursionistas: 2 leña")
	gs.end_mission_abandon()
	gs.draw_town_event("fiesta_patronal")
	gs.start_mission()
	_check(is_equal_approx(stress.virtue_bonus, 0.15), "Fiesta patronal: +15% Virtud chance")
	gs.end_mission_abandon()
	_check(stress.virtue_bonus == 0.0, "…cleared after the mission")
	gs.draw_town_event("bandoleros_en_el_camino")
	gs.start_mission()
	_check(int(gs.mission_difficulty["xp"]) == 8 and float(gs.mission_difficulty["enemy_hp"]) > 1.2, "Bandoleros: XP x2, tougher enemies")
	gs.end_mission_abandon()
	gs.draw_town_event("rumor_de_botija")
	gs.start_mission()
	var c0: int = gs.colones
	gs.complete_mission()
	_check(int(gs.mission_ledger.get("treasure_colones", 0)) >= 1000, "Rumor de botija: treasure on completion")
	gs.end_mission_abandon()

	print("Level limits: Mano vuelta and Modo Pura Vida")
	_fresh(gs)
	gs.party[0]["resolve_level"] = 4
	_check(gs.party_refusals().size() == 1, "Resolución 4 refuses Aprendiz")
	gs.draw_town_event("mano_vuelta")
	_check(gs.party_refusals().is_empty(), "Mano vuelta: nobody refuses")
	gs.active_event_id = ""
	gs.set_radiant_mode(true)
	_check(gs.party_refusals().is_empty(), "Pura Vida: Resolución 4 accepts Aprendiz (range 0-4)")
	gs.party[0]["resolve_level"] = 5
	_check(gs.party_refusals().size() == 1, "Pura Vida: Resolución 5 still refuses Aprendiz")
	_check(rs.level_for_xp(7) == 2 and rs.level_for_xp(40) == 6, "Pura Vida XP curve (7 -> level 2, 40 -> level 6)")
	gs.set_radiant_mode(false)
	_check(rs.level_for_xp(7) == 1, "normal curve: 7 XP is level 1")

	print("Deck")
	var deck: Array = []
	var ctx: Dictionary = {"week": 1, "done_once": [], "graveyard": 0, "inventory": 0, "quebrantos": 0, "quebrantos_in_party": 0}
	_check(te.draw(deck, ctx, 99) == "", "roll above chance_pct: no event")
	var seen: Dictionary = {}
	for _k in 200:
		var id: String = te.draw(deck, ctx, 0)
		seen[id] = true
	_check(not seen.has("dia_de_difuntos") and not seen.has("primera_piedra") and not seen.has(""), "requirements and week limits respected")
	_check(seen.size() > 30, "the deck cycles through many events (%d)" % seen.size())

	print("Save round trip")
	_fresh(gs)
	gs.set_radiant_mode(true)
	gs.draw_town_event("forastero")
	gs.graveyard.append(gs.party[0].duplicate(true))
	var data: Dictionary = JSON.parse_string(JSON.stringify(gs.to_save_dict()))
	gs.set_radiant_mode(false)
	gs.active_event_id = ""
	gs.apply_save_data(data)
	_check(gs.radiant_mode and rs.radiant, "Pura Vida saved")
	_check(gs.active_event_id == "forastero" and gs.events_done_once.has("forastero"), "event and once-list saved")
	_check(gs.graveyard.size() == 1, "graveyard saved")
	var old: Dictionary = data.duplicate(true)
	for k in ["radiant_mode", "active_event_id", "event_deck", "events_done_once", "graveyard"]:
		old.erase(k)
	gs.apply_save_data(old)
	_check(not gs.radiant_mode and gs.active_event_id == "", "v6 save loads with no event and Pura Vida off")

	print("%d failure(s)" % _fail)
	quit(1 if _fail > 0 else 0)
