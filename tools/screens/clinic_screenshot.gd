extends SceneTree

## Renders the hub's Clínica de Espantos card (P3-06), for review.
##   xvfb-run -a godot --path . --rendering-driver opengl3 -s tools/screens/clinic_screenshot.gd -- <out_dir>
## Saves clinic.png.

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
	var q = load("res://scripts/domain/quirks.gd")
	gs.reset_party_from_catalog()
	gs.colones = 9000
	var h: Dictionary = gs.roster[0]
	for id in ["madrugador", "pura_vida", "mano_de_piedra", "descreido", "dengue"]:
		q.add(h, id)
	q.set_locked(h, "madrugador", true)
	var hub = load("res://scenes/hacienda/hacienda_hub.tscn").instantiate()
	root.add_child(hub)
	await _snap(out_dir, "clinic_hub.png")
	hub._show_clinic(h)
	await _snap(out_dir, "clinic.png")
	print("saved to ", out_dir)
	quit(0)
