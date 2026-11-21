extends SceneTree

## Feria Nocturna (P3-05a/b), for review: the town with the Feria's carreta (hovered), its
## page with this week's stall (a cursed trinket on top, Cadena de Comerciantes 1, the
## Mejoras rows), the page with the equipment fold open, and the Taller without accessories.
##   Windows:  Godot_v4.7.2-stable_win64.exe --path . -s tools/screens/feria_screenshot.gd -- <out_dir>
##   Linux:    xvfb-run -a godot --path . --rendering-driver opengl3 -s tools/screens/feria_screenshot.gd -- <out_dir>
## Saves feria_town.png, feria_page.png, feria_equip.png and feria_taller.png in <out_dir>.


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
	gs.week = 5
	gs.reliquias = 3
	gs.building_levels = {"feria": {"feria_cadena": 1}}
	gs.refresh_feria()
	if not gs.feria_stock.any(func(i): return gs.is_cursed(str(i))):
		gs.feria_stock.append("diente_de_la_segua")  # P3-05b: show a cursed trinket on the stall
	var hub = load("res://scenes/hacienda/hacienda_hub.tscn").instantiate()
	root.add_child(hub)
	await process_frame
	hub._selected = gs.roster[0]
	var b = hub._buildings.get("feria")
	if b != null:
		b._set_hover(true)
	await _snap(out_dir, "feria_town.png")
	if b != null:
		b._set_hover(false)
	gs.buy_item(str(gs.feria_stock[0]))
	hub.open_building("feria")
	hub._refresh()
	await _snap(out_dir, "feria_page.png")
	hub._equip_open = true
	hub._refresh_who()
	await _snap(out_dir, "feria_equip.png")
	hub.open_building("taller")
	hub._refresh()
	await _snap(out_dir, "feria_taller.png")
	print("saved to ", out_dir)
	quit(0)
