extends SceneTree

## Expedition systems (P1-17, P1-18, P2-01), for review: the hunger stop, a trap room, the
## Luz HUD tooltip in the dark, and the hub's provisions prompt.
##   Windows:  Godot_v4.7.2-stable_win64.exe --path . -s tools/screens/expedition_events_screenshot.gd -- <out_dir>
##   Linux:    xvfb-run -a godot --path . --rendering-driver opengl3 -s tools/screens/expedition_events_screenshot.gd -- <out_dir>
## Saves events_<name>.png in <out_dir>.

var _out: String = "user://"


func _initialize() -> void:
	_run.call_deferred()


func _shot(file: String) -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(_out.path_join("events_%s.png" % file))
	print("saved events_%s.png" % file)


func _hover(target: Control) -> void:
	var at: Vector2 = target.get_global_rect().get_center()
	for pos in [at + Vector2(3, 3), at]:
		var ev := InputEventMouseMotion.new()
		ev.position = pos
		ev.global_position = pos
		root.push_input(ev)
		await process_frame
	await create_timer(1.2).timeout


func _run() -> void:
	if not OS.get_cmdline_user_args().is_empty():
		_out = OS.get_cmdline_user_args()[0]
	await process_frame
	root.size = Vector2i(1280, 720)
	var gs = root.get_node("GameState")
	gs.reset_party_from_catalog()
	gs.reset_inventory_to_starter()
	gs.start_mission()
	var screen = load("res://scenes/expedition/expedition_screen.tscn").instantiate()
	root.add_child(screen)
	await process_frame

	# Hunger stop with only 2 gallo pinto for 4 heroes.
	gs.inventory.clear()
	gs.add_item("gallo_pinto", 2)
	gs.mission_light = 60
	screen._refresh_all()
	screen._open_hunger()
	await _shot("hunger")
	screen._close_event()

	# A trap room in Penumbra.
	gs.mission_nodes_index["shot_trap"] = {"id": "shot_trap", "type": "trap", "trap_id": "alambre_de_pua", "label": "Alambre de púas"}
	gs.current_node_id = "shot_trap"
	gs.mission_light = 40
	screen._refresh_all()
	screen._open_trap()
	await _shot("trap")
	screen._close_event()

	# The Luz HUD in the dark, with its tooltip.
	screen._mode = 0
	gs.mission_light = 12
	screen._refresh_all()
	screen._show_explore_actions()
	await _hover(screen._light_label)
	await _shot("light_tooltip")
	screen.queue_free()
	await process_frame

	# The hub's provisions prompt (alforja short of the recommended food and candles).
	gs.mission_active = false
	gs.inventory.clear()
	gs.add_item("gallo_pinto", 3)
	var hub = load("res://scenes/hacienda/hacienda_hub.tscn").instantiate()
	root.add_child(hub)
	await process_frame
	hub._confirm_provisions(gs.missing_provisions())
	await _shot("provisions")
	quit(0)
