extends SceneTree

## Hovers a sample of controls and saves what the tooltip looks like, for review.
##   xvfb-run -a godot --path . --rendering-driver opengl3 -s tools/screens/tooltip_screenshot.gd -- <out_dir>
## Saves tip_<name>.png in <out_dir> (hub: sell, pura vida, hero, event; battle: skill, guard, status, enemy, map).

var _out: String = "user://"


func _initialize() -> void:
	_run.call_deferred()


## Move the mouse onto `target` (or a point), wait out Godot's tooltip delay, save, move away.
func _hover(target, file: String) -> void:
	var at: Vector2 = target.get_global_rect().get_center() if target is Control else target
	for pos in [at + Vector2(3, 3), at]:
		var ev := InputEventMouseMotion.new()
		ev.position = pos
		ev.global_position = pos
		root.push_input(ev)
		await process_frame
	await create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(_out.path_join("tip_%s.png" % file))
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
	var se = load("res://scripts/domain/status_effects.gd")
	gs.reset_party_from_catalog()
	gs.reset_inventory_to_starter()
	gs.draw_town_event("dia_de_difuntos")
	var hub = load("res://scenes/hacienda/hacienda_hub.tscn").instantiate()
	root.add_child(hub)
	for i in 10:
		await process_frame
	# The event card opens by itself on arrival; close it.
	for w in hub.get_children():
		if w is AcceptDialog:
			w.hide()
	await process_frame
	await _hover(hub._btn_sell, "hub_sell")
	await _hover(hub._pura_vida, "hub_pura_vida")
	await _hover(hub._roster_list.get_child(0).get_global_rect().position + Vector2(140, 20), "hub_hero")
	await _hover(hub._event_btn, "hub_event")
	hub.queue_free()
	gs.start_mission()
	var screen = load("res://scenes/expedition/expedition_screen.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	for id in gs.mission_nodes_index:
		if str(gs.mission_nodes_index[id].get("type", "")) == "combat":
			screen._start_combat(str(id))
			break
	for i in 30:
		await process_frame
	var e0: Dictionary = screen._combat.enemies[0]
	se.apply(e0, "veneno", 3, 2, {"ignore_resist": true})
	screen._refresh_all()
	for i in 600:
		await process_frame
		if screen._skills.get_child_count() > 3:
			break
	var buttons: Array = screen._skills.get_children().filter(func(b): return not b.is_queued_for_deletion())
	await _hover(buttons[0], "battle_skill")
	await _hover(buttons[buttons.size() - 2], "battle_guard")
	await _hover(screen._enemy_units[0]._status_row.get_child(0), "battle_status")
	await _hover(screen._enemy_units[0]._sprite, "battle_enemy")
	await _hover(screen.get_node("BottomPanel/Row/SidePanel/Pages/MapView"), "battle_map")
	print("saved to ", _out)
	quit(0)
