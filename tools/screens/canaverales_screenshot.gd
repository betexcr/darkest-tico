extends SceneTree

## Cañaverales art check (P6-11b): the exploration background and two fights with the new enemies.
##   xvfb-run -a godot --path . --rendering-driver opengl3 -s tools/screens/canaverales_screenshot.gd -- <out_dir>
## Saves <out_dir>/canaverales_map.png and canaverales_fight_1..4.png (Buey; the swarm; Tulevieja,
## Rezadora, Boyero, Espantapájaros; the Capataz).

const REGION := "res://data/regions/canaverales.json"
const FIGHTS := [["buey_de_ceniza", "quemador_de_cana", "machetero_de_zafra"], ["zompopas_de_mayo", "rata_canera"],
	["tulevieja", "rezadora_del_porton", "boyero_maldito", "espantapajaros_del_canal"], ["capataz_de_ceniza", "quemador_de_cana"]]


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
	gs.start_mission(REGION)
	var screen = load("res://scenes/expedition/expedition_screen.tscn").instantiate()
	root.add_child(screen)
	await _shot(out_dir.path_join("canaverales_map.png"))
	var k: int = 0
	for id in gs.mission_nodes_index:
		var nd: Dictionary = gs.mission_nodes_index[id]
		if str(nd.get("type", "")) != "combat" or k >= FIGHTS.size():
			continue
		nd["enemy_ids"] = FIGHTS[k]
		nd.erase("enemy_id")
		screen._start_combat(str(id))
		k += 1
		await _shot(out_dir.path_join("canaverales_fight_%d.png" % k))
		if k < FIGHTS.size():
			screen.queue_free()
			await process_frame
			screen = load("res://scenes/expedition/expedition_screen.tscn").instantiate()
			root.add_child(screen)
			await process_frame
	quit(0)
