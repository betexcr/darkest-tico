extends SceneTree

## Renders the camp (respite menu), both victory-screen pages and the hub roster, for review.
##   xvfb-run -a godot --path . --rendering-driver opengl3 -s tools/screens/progression_screenshot.gd -- <out_dir>
## Saves camp.png, victory_rewards.png, victory_heroes.png, hub.png, hub_event.png in <out_dir>.

func _initialize() -> void:
	_run.call_deferred()


func _snap(out_dir: String, file: String) -> void:
	for i in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out_dir.path_join(file))


func _run() -> void:
	var out_dir: String = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "user://"
	await process_frame
	root.size = Vector2i(1280, 720)
	var gs = root.get_node("GameState")
	gs.reset_party_from_catalog()
	gs.reset_inventory_to_starter()
	gs.start_mission()
	var screen = load("res://scenes/expedition/expedition_screen.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	# Camp: skip straight to the respite menu after a feast.
	screen._camp_begin()
	await process_frame
	var feast = screen._event_actions.get_children().filter(func(b): return b is Button and not b.is_queued_for_deletion())[0]
	feast.pressed.emit()
	await process_frame
	var tec: Dictionary = gs.party[2]
	screen._camp_use(tec, load("res://scripts/domain/camping_system.gd").skill("dron_vigia"), {})
	await _snap(out_dir, "camp.png")
	# Victory: a finished expedition with loot, a fallen hero, a new Quebranto and a level-up.
	gs.party[0]["resolve_xp"] = 6
	gs.party[0]["resolve_level"] = 1
	gs.party[3]["dead"] = true
	gs.party[1]["affliction_id"] = "desesperanza"
	gs.party[2]["virtud_id"] = "punteria"
	gs.ledger_add("loot_colones", 1125)
	gs.ledger_add("fights", 4)
	gs.ledger_add("elites", 1)
	gs.ledger_add("bosses", 1)
	gs.ledger_add("curios", 2)
	gs.ledger_item("gallo_pinto", 2)
	gs.ledger_item("machete_cartago", 1)
	gs.ledger_item("venda_manta", 3)
	gs.complete_mission()
	gs.end_mission_abandon()
	screen.queue_free()
	var victory = load("res://scripts/expedition/victory_screen.gd").new()
	root.add_child(victory)
	await _snap(out_dir, "victory_rewards.png")
	victory._on_next()
	await _snap(out_dir, "victory_heroes.png")
	victory.queue_free()
	gs.party[3]["dead"] = false
	gs.selected_difficulty_id = "veterano"
	var hub = load("res://scenes/hacienda/hacienda_hub.tscn").instantiate()
	root.add_child(hub)
	await _snap(out_dir, "hub.png")
	# Town event card with choices (Día de los Difuntos).
	hub.queue_free()
	var fallen: Dictionary = gs.party[3].duplicate(true)
	fallen["dead"] = true
	fallen["resolve_level"] = 2
	gs.graveyard.append(fallen)
	gs.draw_town_event("dia_de_difuntos")
	var hub2 = load("res://scenes/hacienda/hacienda_hub.tscn").instantiate()
	root.add_child(hub2)
	await _snap(out_dir, "hub_event.png")
	print("saved to ", out_dir)
	quit(0)
