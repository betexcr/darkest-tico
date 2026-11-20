extends SceneTree

## Renders the town-event card (P4-26: title, picture, flavour text, effects) for review.
##   xvfb-run -a godot --path . --rendering-driver opengl3 -s tools/screens/town_event_screenshot.gd -- <out_dir> [event_id ...]
## Saves event_<id>.png for each id (default: a good, a bad and a special event).

func _initialize() -> void:
	_run.call_deferred()


func _snap(out_dir: String, file: String) -> void:
	for i in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out_dir.path_join(file))


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out_dir: String = args[0] if not args.is_empty() else "user://"
	var ids: Array = Array(args.slice(1)) if args.size() > 1 else ["fiesta_patronal", "corte_de_luz", "bandoleros_en_el_camino"]
	await process_frame
	root.size = Vector2i(1280, 720)
	var gs = root.get_node("GameState")
	gs.reset_party_from_catalog()
	gs.colones = 2000
	var hub = load("res://scenes/hacienda/hacienda_hub.tscn").instantiate()
	root.add_child(hub)
	await _snap(out_dir, "_hub.png")
	for id in ids:
		for d in hub.get_children():
			if d is AcceptDialog:
				d.hide()
		gs.active_event_id = str(id)
		gs.event_report = PackedStringArray()
		hub._show_event_card()
		await create_timer(0.3).timeout
		await _snap(out_dir, "event_%s.png" % id)
	print("saved to ", out_dir)
	quit(0)
