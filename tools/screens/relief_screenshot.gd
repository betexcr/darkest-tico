extends SceneTree

## Renders the hub's Iglesia Vieja + Cantina panel (P3-03), for review.
##   xvfb-run -a godot --path . --rendering-driver opengl3 -s tools/screens/relief_screenshot.gd -- <out_dir>
## Saves relief.png (selected hero free, one hero already booked) and relief_booked.png (selected hero booked).

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
	gs.colones = 4000
	for h in gs.roster:
		h["stress"] = 55
	gs.send_to_activity(gs.roster[1], "cantina", "noche_de_fiesta")
	var hub = load("res://scenes/hacienda/hacienda_hub.tscn").instantiate()
	root.add_child(hub)
	await _snap(out_dir, "relief.png")
	hub._selected = gs.roster[1]
	hub._refresh()
	await _snap(out_dir, "relief_booked.png")
	print("saved to ", out_dir)
	quit(0)
