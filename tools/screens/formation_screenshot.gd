extends SceneTree

## Battlefield positions (P1-03a), for review: the hub warning for a hero out of position,
## a battle action bar with skills greyed out by position, the Moverse prompt, and the
## stage after an enemy falls (the corpse goes to the back).
##   Windows:  Godot_v4.7.2-stable_win64.exe --path . -s tools/screens/formation_screenshot.gd -- <out_dir>
##   Linux:    xvfb-run -a godot --path . --rendering-driver opengl3 -s tools/screens/formation_screenshot.gd -- <out_dir>
## Saves formation_<name>.png in <out_dir>.

var _out: String = "user://"


func _initialize() -> void:
	_run.call_deferred()


func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(_out.path_join("formation_%s.png" % file))


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
	# Campesino (1-2) sent to the back, Tecnólogo (2-4) to the front: both out of position.
	var campe: Dictionary = gs.party[0]
	gs.party.remove_at(0)
	gs.party.append(campe)
	var tec: Dictionary = gs.party[2]
	gs.party.remove_at(2)
	gs.party.insert(0, tec)
	var hub = load("res://scenes/hacienda/hacienda_hub.tscn").instantiate()
	root.add_child(hub)
	for i in 10:
		await process_frame
	await _shot("hub")
	hub.queue_free()
	gs.start_mission()
	var screen = load("res://scenes/expedition/expedition_screen.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	for id in gs.mission_nodes_index:
		var nd: Dictionary = gs.mission_nodes_index[id]
		if str(nd.get("type", "")) == "combat":
			nd["enemy_ids"] = ["murcielago_bodega", "peon_penado", "rata_de_troje"]
			screen._start_combat(str(id))
			break
	# Wait for a hero turn with at least one skill out of reach.
	var cc = screen._combat
	var shot_bar: bool = false
	for i in 4000:
		await process_frame
		var hero: Dictionary = cc.active_hero()
		if hero.is_empty():
			continue
		var buttons: Array = screen._skills.get_children().filter(func(b): return not b.is_queued_for_deletion())
		var off: Array = buttons.slice(0, 4).filter(func(b): return b.disabled)
		if off.is_empty():
			cc.pass_turn()
			continue
		await create_timer(0.3).timeout
		await _shot("bar")
		await _hover(off[0], "bar_disabled_tip")
		var ok: Array = buttons.slice(0, 4).filter(func(b): return not b.disabled)
		if not ok.is_empty():
			await _hover(ok[0], "bar_enabled_tip")
		var mv: Array = buttons.filter(func(b): return str(b.get("title")) == "Moverse")
		if not mv.is_empty() and not mv[0].disabled:
			mv[0].pressed.emit()
			await create_timer(0.2).timeout
			await _shot("move_prompt")
			screen._cancel_pending()
		shot_bar = true
		break
	if not shot_bar:
		push_warning("no hero turn with a greyed-out skill reached")
	# Collapse: the front enemy falls and goes to the back.
	cc.enemies[0]["hp"] = 0
	cc.enemies[0]["dead"] = true
	cc.enemy_units[0].refresh()
	cc._collapse_ranks()
	cc._refresh_units()
	await create_timer(0.4).timeout
	await _shot("collapse")
	# P1-05: an enemy crit (log + popup) and an Al Borde hero's death-roll odds.
	var foe: Dictionary = cc.enemies[0]
	foe["crit"] = 100
	for i in 12:
		await cc._enemy_turn(foe)
		if screen._log.get_parsed_text().contains("CRÍTICO de"):
			break
	await _shot("enemy_crit")
	var h: Dictionary = cc.party[1]
	h["hp"] = 0
	h["al_borde"] = true
	h["borde_checks"] = 1
	h["stress"] = 110
	cc._refresh_units()
	screen._show_hero_info(h)
	await create_timer(0.3).timeout
	await _shot("al_borde_info")
	screen._hide_enemy_info()
	# P1-03b: a push on the front enemy, an Amarrado hero, and the out-of-combat reorder buttons.
	for e in cc.enemies:
		e["status_resist"]["movimiento"] = 0
	await cc._force_move(cc.enemies[0], {"move_target": 1})
	load("res://scripts/domain/status_effects.gd").apply(cc.party[2], "amarrado", 2, 0, {"ignore_resist": true})
	cc._refresh_units()
	await create_timer(0.1).timeout
	await _shot("push_amarrado")
	screen._mode = screen.Mode.EXPLORE
	screen._view_hero(cc.party[2])
	await create_timer(0.2).timeout
	await _shot("reorder_buttons")
	print("saved to ", _out)
	quit(0)
