extends SceneTree

## Renders the hub's Clínica de Espantos card (P3-06), for review.
##   xvfb-run -a godot --path . --rendering-driver opengl3 -s tools/screens/clinic_screenshot.gd -- <out_dir>
## Saves clinic_hub.png, hover_activity.png, hover_recruit.png, hover_roster.png, clinic.png, dismiss.png.

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
	# Hover cards (P4-15): an Iglesia activity, a candidate at the terminal, a roster hero.
	for pair in [["hover_activity.png", hub._relief_box.get_child(1).get_child(1)],
			["hover_recruit.png", hub._recruit_box.get_child(0)],
			["hover_roster.png", hub._roster_list.get_child(0).get_child(1)]]:
		var ctl: Control = pair[1]
		var ev := InputEventMouseMotion.new()
		ev.position = ctl.get_global_rect().get_center()
		ev.global_position = ev.position
		root.push_input(ev)
		await create_timer(1.2).timeout
		await _snap(out_dir, str(pair[0]))
		var away := InputEventMouseMotion.new()
		away.position = Vector2(5, 5)
		away.global_position = away.position
		root.push_input(away)
		await create_timer(0.3).timeout
	hub._show_clinic(h)
	await _snap(out_dir, "clinic.png")
	hub._confirm_dismiss(h)
	await _snap(out_dir, "dismiss.png")
	print("saved to ", out_dir)
	quit(0)
