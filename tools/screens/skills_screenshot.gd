extends SceneTree

## Casa Comunal skill ranks, for review (P3-04): the hub row for a Resolución 2 hero (one
## skill trainable, one waiting on resolve) and the battle action bar with rank pips.
##   Windows:  Godot_v4.7.2-stable_win64.exe --path . -s tools/screens/skills_screenshot.gd -- <out_dir>
##   Linux:    xvfb-run -a godot --path . --rendering-driver opengl3 -s tools/screens/skills_screenshot.gd -- <out_dir>
## Saves skills_<name>.png in <out_dir>.

var _out: String = "user://"


func _initialize() -> void:
	_run.call_deferred()


func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(_out.path_join("skills_%s.png" % file))


## Move the mouse onto `target`, wait out Godot's tooltip delay, save, move away.
func _hover(target: Control, file: String) -> void:
	var at: Vector2 = target.get_global_rect().get_center()
	for pos in [at + Vector2(3, 3), at]:
		var ev := InputEventMouseMotion.new()
		ev.position = pos
		ev.global_position = pos
		root.push_input(ev)
		await process_frame
	await create_timer(1.0).timeout
	await _shot(file)
	var away := InputEventMouseMotion.new()
	away.position = Vector2(2, 2)
	away.global_position = away.position
	root.push_input(away)
	await create_timer(0.3).timeout


func _run() -> void:
	if not OS.get_cmdline_user_args().is_empty():
		_out = OS.get_cmdline_user_args()[0]
	await process_frame
	root.size = Vector2i(1280, 720)
	var gs = root.get_node("GameState")
	gs.reset_party_from_catalog()
	gs.reset_inventory_to_starter()
	gs.active_event_id = ""
	gs.colones = 5000
	# Toño: Resolución 2, Machetazo at rank 3 (rank 4 needs Resolución 3), the rest at 1-2.
	var h: Dictionary = gs.party[0]
	h["resolve_level"] = 2
	h["resolve_xp"] = load("res://scripts/domain/resolve_system.gd").xp_for_level(2)
	h["skill_ranks"] = {str(h["skill_ids"][0]): 3, str(h["skill_ids"][2]): 2}
	for k in range(1, gs.party.size()):
		gs.party[k]["skill_ranks"] = {str(gs.party[k]["skill_ids"][0]): 2}
	var hub = load("res://scenes/hacienda/hacienda_hub.tscn").instantiate()
	root.add_child(hub)
	for i in 10:
		await process_frame
	await _shot("hub")
	var cols: Array = hub._skills_row.get_children()
	await _hover(cols[0].get_child(1), "hub_gated")
	await _hover(cols[1].get_child(1), "hub_buyable")
	await _hover(cols[0].get_child(0).get_child(0), "hub_icon")
	# Every other party hero's row (their own basic attack icons, P2-08).
	for k in range(1, gs.party.size()):
		hub._selected = gs.party[k]
		hub._refresh()
		for i in 3:
			await process_frame
		await _shot("hub_%s" % gs.party[k]["hero_id"])
	hub.queue_free()
	gs.start_mission()
	var screen = load("res://scenes/expedition/expedition_screen.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	for id in gs.mission_nodes_index:
		if str(gs.mission_nodes_index[id].get("type", "")) == "combat":
			screen._start_combat(str(id))
			break
	# Enemies may act first: wait (up to ~50 s) for a hero's action bar.
	var buttons: Array = []
	for i in 3000:
		await process_frame
		buttons = screen._skills.get_children().filter(func(b): return not b.is_queued_for_deletion())
		if buttons.size() > 3:
			break
	if buttons.size() > 3:
		await create_timer(0.5).timeout
		await _hover(buttons[0], "battle_skill")
	else:
		push_warning("no hero turn reached; battle shot skipped")
	print("saved to ", _out)
	quit(0)
