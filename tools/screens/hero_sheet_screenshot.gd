extends SceneTree

## The hero sheet (Ficha) for review: a male Exorcista (other-sex portrait, P4-24) and the
## Resistencias grid with icons, plus the tooltip on hovering one resistance.
##   Linux:    xvfb-run -a godot --path . --rendering-driver opengl3 -s tools/screens/hero_sheet_screenshot.gd -- <out_dir>
## Saves hero_sheet.png and hero_sheet_tooltip.png in <out_dir>.

var _out: String = "user://"


func _initialize() -> void:
	_run.call_deferred()


func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(_out.path_join("%s.png" % file))


func _find_tip(n: Node, prefix: String) -> Control:
	if n is Control and str(n.tooltip_text).begins_with(prefix):
		return n
	for c in n.get_children():
		var f := _find_tip(c, prefix)
		if f != null:
			return f
	return null


func _run() -> void:
	if not OS.get_cmdline_user_args().is_empty():
		_out = OS.get_cmdline_user_args()[0]
	await process_frame
	root.size = Vector2i(1280, 720)
	var gs = root.get_node("GameState")
	gs.reset_party_from_catalog()
	gs.reset_inventory_to_starter()
	gs.active_event_id = ""
	var h: Dictionary = gs._instantiate_hero(gs.get_hero_template("exorcista"), "m")
	gs.party[0] = h
	var hub = load("res://scenes/hacienda/hacienda_hub.tscn").instantiate()
	root.add_child(hub)
	for i in 10:
		await process_frame
	hub._show_hero_sheet(h)
	for i in 10:
		await process_frame
	await _shot("hero_sheet")
	var cell := _find_tip(root, "Golpe de gracia")
	if cell != null:
		# The sheet is its own dialog window: send the mouse there, in its coordinates.
		var vp: Viewport = cell.get_viewport()
		var at: Vector2 = cell.get_global_rect().get_center()
		for pos in [at + Vector2(3, 3), at]:
			var ev := InputEventMouseMotion.new()
			ev.position = pos
			ev.global_position = pos
			vp.push_input(ev)
			await process_frame
		await create_timer(1.0).timeout
		await _shot("hero_sheet_tooltip")
	quit()
