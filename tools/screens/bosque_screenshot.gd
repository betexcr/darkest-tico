extends SceneTree

## Bosque art check (P6-10b): the exploration background and two fights with the new enemies.
##   xvfb-run -a godot --path . --rendering-driver opengl3 -s tools/screens/bosque_screenshot.gd -- <out_dir>
## Saves <out_dir>/bosque_map.png, bosque_fight_1.png (Danta, Mono, Tigrillo) and
## bosque_fight_2.png (Sapos, Viejo, Brujo) and bosque_fight_3.png (Llorona, Leñador, Sapos).

const BOSQUE := "res://data/regions/bosque.json"
const FIGHTS := [["danta_embrujada", "mono_congo_poseido", "tigrillo_bruma"], ["sapo_quebrada", "viejo_del_monte", "brujo_de_la_montana"],
	["llorona_del_rio", "lenador_penado", "sapo_quebrada"]]


func _initialize() -> void:
	_run.call_deferred()


func _shot(path: String) -> void:
	for i in 40:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(path)


func _run() -> void:
	var out_dir: String = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "user://"
	await process_frame
	root.size = Vector2i(1280, 720)
	var gs = root.get_node("GameState")
	gs.reset_party_from_catalog()
	gs.reset_inventory_to_starter()
	gs.start_mission(BOSQUE)
	var screen = load("res://scenes/expedition/expedition_screen.tscn").instantiate()
	root.add_child(screen)
	await _shot(out_dir.path_join("bosque_map.png"))
	var k: int = 0
	for id in gs.mission_nodes_index:
		var nd: Dictionary = gs.mission_nodes_index[id]
		if str(nd.get("type", "")) != "combat" or k >= FIGHTS.size():
			continue
		nd["enemy_ids"] = FIGHTS[k]
		nd.erase("enemy_id")
		screen._start_combat(str(id))
		k += 1
		await _shot(out_dir.path_join("bosque_fight_%d.png" % k))
		if k < FIGHTS.size():
			screen.queue_free()
			await process_frame
			screen = load("res://scenes/expedition/expedition_screen.tscn").instantiate()
			root.add_child(screen)
			await process_frame
	quit(0)
