extends SceneTree

## Renders the town view (P4-17), for review.
##   xvfb-run -a godot --path . --rendering-driver opengl3 -s tools/screens/town_screenshot.gd -- <out_dir>
## Saves town.png, town_hover.png (mouse over the Iglesia) and town_<building>.png for each
## building's window.

func _initialize() -> void:
	_run.call_deferred()


func _snap(out_dir: String, file: String) -> void:
	for i in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out_dir.path_join(file))


func _move(at: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = at
	ev.global_position = at
	root.push_input(ev)


func _run() -> void:
	var out_dir: String = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "user://"
	await process_frame
	root.size = Vector2i(1280, 720)
	var gs = root.get_node("GameState")
	gs.reset_party_from_catalog()
	gs.colones = 4200
	gs.party[1]["hp"] = int(gs.party[1]["hp_max"]) - 9
	gs.party[2]["stress"] = 64
	load("res://scripts/domain/quirks.gd").add(gs.roster[0], "dengue")
	var hub = load("res://scenes/hacienda/hacienda_hub.tscn").instantiate()
	root.add_child(hub)
	hub._selected = gs.party[2]
	hub._refresh()
	_move(Vector2(300, 690))
	await _snap(out_dir, "town.png")
	var ig: Control = hub._buildings["iglesia"]
	_move(ig.get_global_rect().get_center())
	await create_timer(0.3).timeout
	await _snap(out_dir, "town_hover.png")
	var gb: Control = hub._buildings.get("guardabosques")
	if gb != null:
		_move(gb.get_global_rect().get_center())
		await create_timer(0.3).timeout
		await _snap(out_dir, "town_hover_guardabosques.png")
	_move(Vector2(300, 690))
	for bid in hub._buildings:
		hub.open_building(bid)
		await _snap(out_dir, "town_%s.png" % bid)
		hub.close_building()
	print("saved to ", out_dir)
	quit(0)
