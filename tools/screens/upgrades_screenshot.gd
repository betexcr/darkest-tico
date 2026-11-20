extends SceneTree

## Building upgrades (P3-16 / P3-18 / P3-21), for review: the Mejoras section on the Casa
## Comunal, Iglesia, Cantina and Guardabosques pages, with some levels bought.
##   Windows:  Godot_v4.7.2-stable_win64.exe --path . -s tools/screens/upgrades_screenshot.gd -- <out_dir>
##   Linux:    xvfb-run -a godot --path . --rendering-driver opengl3 -s tools/screens/upgrades_screenshot.gd -- <out_dir>
## Saves upgrades_<building>.png in <out_dir>.


func _initialize() -> void:
	_run.call_deferred()


func _snap(out_dir: String, file: String) -> void:
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out_dir.path_join(file))


func _run() -> void:
	var out_dir: String = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "user://"
	await process_frame
	root.size = Vector2i(1920, 1080)
	var gs = root.get_node("GameState")
	gs.reset_party_from_catalog()
	gs.reset_inventory_to_starter()
	gs.active_event_id = ""
	gs.colones = 6000
	gs.reliquias = 3
	gs.building_levels = {"casa_comunal": {"maestria_oficio": 1}, "iglesia": {"iglesia_limosna": 2}, "cantina": {"cantina_corredor": 2}}
	for h in gs.roster:
		h["stress"] = 55
	gs.roster[0]["resolve_level"] = 5
	var hub = load("res://scenes/hacienda/hacienda_hub.tscn").instantiate()
	root.add_child(hub)
	await process_frame
	hub._selected = gs.roster[0]
	for bid in ["casa_comunal", "iglesia", "cantina", "guardabosques"]:
		hub.open_building(bid)
		hub._refresh()
		await _snap(out_dir, "upgrades_%s.png" % bid)
	print("saved to ", out_dir)
	quit(0)
