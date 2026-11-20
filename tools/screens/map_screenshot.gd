extends SceneTree

## Expedition room map (P4-06), for review: every room scouted, a few visited, one cleared.
##   Windows:  Godot_v4.7.2-stable_win64.exe --path . -s tools/screens/map_screenshot.gd -- <out_dir>
##   Linux:    xvfb-run -a godot --path . --rendering-driver opengl3 -s tools/screens/map_screenshot.gd -- <out_dir>
## Saves map_full.png (the whole screen) and map_crop.png (the map panel) in <out_dir>.

var _out: String = "user://"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if not OS.get_cmdline_user_args().is_empty():
		_out = OS.get_cmdline_user_args()[0]
	await process_frame
	root.size = Vector2i(1920, 1080)
	var gs = root.get_node("GameState")
	seed(7)
	gs.reset_party_from_catalog()
	gs.reset_inventory_to_starter()
	gs.start_mission()
	# Scout every room so each type shows; visit the start and its first neighbour.
	for nid in gs.mission_nodes_index:
		if not gs.scouted_node_ids.has(str(nid)):
			gs.scouted_node_ids.append(str(nid))
	var first: Array = gs.mission_neighbors()
	if not first.is_empty() and not gs.visited_node_ids.has(str(first[0])):
		gs.visited_node_ids.append(str(first[0]))
	var screen = load("res://scenes/expedition/expedition_screen.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	screen._mode = 0
	screen._refresh_all()
	screen._show_explore_actions()
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png(_out.path_join("map_full.png"))
	var r: Rect2 = screen._map_view.get_global_rect()
	var scale: Vector2 = Vector2(img.get_size()) / root.get_visible_rect().size
	img.get_region(Rect2i(Vector2i(r.position * scale), Vector2i(r.size * scale))).save_png(_out.path_join("map_crop.png"))
	print("saved map_full.png, map_crop.png (map %s)" % [r])
	quit()
