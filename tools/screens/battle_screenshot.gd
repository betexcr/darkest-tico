extends SceneTree

## Renders the battle stage with status effects and the info panel open, for review.
##   xvfb-run -a godot --path . --rendering-driver opengl3 -s tools/screens/battle_screenshot.gd -- <out_dir>
## Saves <out_dir>/battle_hero.png (hero panel) and battle_enemy.png (enemy panel).

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out_dir: String = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "user://"
	await process_frame
	root.size = Vector2i(1280, 720)
	var gs = root.get_node("GameState")
	var se = load("res://scripts/domain/status_effects.gd")
	gs.reset_party_from_catalog()
	gs.reset_inventory_to_starter()
	gs.add_item("lentes_del_abuelo", 1)
	gs.equip(gs.party[1], "lentes_del_abuelo")
	gs.start_mission()
	var screen = load("res://scenes/expedition/expedition_screen.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	# First combat room on the map.
	for id in gs.mission_nodes_index:
		if str(gs.mission_nodes_index[id].get("type", "")) == "combat":
			screen._start_combat(str(id))
			break
	for i in 30:
		await process_frame
	var h0: Dictionary = gs.party[0]
	se.apply(h0, "sangrado", 3, 2)
	se.apply(h0, "sangrado", 2, 1)
	se.apply(h0, "chiva", 3, 0, {"mods": {"dmg_pct": 15}})
	se.apply(h0, "fichado", 3, 0)
	se.apply(h0, "santiguado", 0, 1)
	h0["convaleciente"] = true
	var e0: Dictionary = screen._combat.enemies[0]
	se.apply(e0, "veneno", 3, 2, {"ignore_resist": true})
	se.apply(e0, "salado", 3, 0, {"mods": {"accuracy": -6, "dmg_pct": -20}, "ignore_resist": true})
	se.apply(e0, "respondon", 3, 0)
	screen._refresh_all()
	screen._show_hero_info(h0)
	for i in 20:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out_dir.path_join("battle_hero.png"))
	screen._show_enemy_info(e0)
	for i in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out_dir.path_join("battle_enemy.png"))
	print("saved to ", out_dir)
	quit(0)
