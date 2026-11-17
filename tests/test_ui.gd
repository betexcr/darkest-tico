extends SceneTree

## Menus in the item-card style (P4-15): the game-wide theme, the hover cards (heroes,
## candidates, Iglesia/Cantina activities) and the card dialogs (Clínica, town event,
## provisions, dismiss) all build without errors. The combat action bar keeps its buttons
## between turns (P4-16), so a skill tooltip stays up while other units act.
##   godot --headless --path . -s tests/test_ui.gd

var _fail: int = 0


func _check(cond: bool, what: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + what)
	if not cond:
		_fail += 1


func _initialize() -> void:
	_run.call_deferred()


func _dialogs(hub) -> Array:
	return hub.get_children().filter(func(c): return c is AcceptDialog and not c.is_queued_for_deletion())


## Builds a hover card and frees it (cards from card.call() are not in the tree).
func _builds(card: Callable) -> bool:
	if not card.is_valid():
		return false
	var c = card.call()
	var ok: bool = c is Control
	if c is Node:
		c.free()
	return ok


func _close_all(hub) -> void:
	for d in _dialogs(hub):
		d.hide()
	await process_frame


func _run() -> void:
	await process_frame
	var gs = root.get_node("GameState")
	var q = load("res://scripts/domain/quirks.gd")
	gs.reset_party_from_catalog()
	gs.colones = 5000
	q.add(gs.roster[0], "madrugador")
	q.add(gs.roster[0], "dengue")
	q.add(gs.roster[0], "mano_de_piedra")

	print("Theme")
	var th: Theme = root.theme
	_check(th != null and th.has_stylebox("normal", "Button") and th.has_stylebox("embedded_border", "Window"), "the game-wide theme is on the root window (buttons, dialogs)")

	var hub = load("res://scenes/hacienda/hacienda_hub.tscn").instantiate()
	root.add_child(hub)
	await process_frame

	print("Hover cards")
	var ok: bool = true
	for row in hub._roster_list.get_children():
		var info = row.get_child(0).get_child(1)
		ok = ok and _builds(info.card)
	_check(ok, "every roster hero has a hero card")
	ok = true
	for b in hub._recruit_box.get_children():
		ok = ok and b.get("card") != null and _builds(b.card)
	_check(ok and hub._recruit_box.get_child_count() > 0, "every candidate at the terminal has a hero card")
	var acts: Array = []
	for bx in hub._relief_boxes.values():
		for c in bx.get_children():
			if c is Button and c.get("card") != null:
				acts.append(c)
	_check(acts.size() == 6 and acts.all(func(b): return _builds(b.card)), "the 6 Iglesia/Cantina activities have cards")

	print("Card dialogs")
	hub._show_clinic(gs.roster[0])
	await process_frame
	var d: Array = _dialogs(hub)
	_check(d.size() == 1 and d[0].title.begins_with("Clínica de Espantos"), "the Clínica card opens")
	await _close_all(hub)
	hub._confirm_dismiss(gs.roster[1])
	await process_frame
	d = _dialogs(hub)
	_check(d.size() == 1 and d[0] is ConfirmationDialog and d[0].ok_button_text == "Despedir", "the dismiss card opens")
	await _close_all(hub)
	gs.inventory.clear()
	hub._confirm_provisions()
	await process_frame
	d = _dialogs(hub)
	_check(d.size() == 1 and d[0].ok_button_text == "Salir así", "the provisions card opens")
	await _close_all(hub)
	ok = true
	for ev in gs.TownEventsScript.all():
		gs.active_event_id = str(ev["id"])
		gs.event_report = PackedStringArray()
		hub._show_event_card()
		await process_frame
		ok = ok and _dialogs(hub).size() == 1 and _dialogs(hub)[0].title == str(ev["name"])
		await _close_all(hub)
	_check(ok, "every town event's card opens (%d)" % gs.TownEventsScript.all().size())
	gs.active_event_id = ""
	hub.queue_free()
	await process_frame
	await _town(gs)
	await _combat_bar(gs)

	print("%d failure(s)" % _fail)
	quit(1 if _fail > 0 else 0)


## Live (not queued-for-deletion) children of the combat bar.
func _bar(screen) -> Array:
	return screen._skills.get_children().filter(func(c): return not c.is_queued_for_deletion())


## Waits (up to 30 s of real time: the fight plays its animations) for a hero's turn.
func _wait_turn(screen) -> Dictionary:
	var until: int = Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < until:
		var h: Dictionary = screen._combat.active_hero()
		if not h.is_empty() and _bar(screen).any(func(b): return not b.disabled):
			return h
		if int(screen._mode) == 1:  # an event popup (hunger, a room event): take the first option
			var acts: Array = screen._event_actions.get_children().filter(func(b): return b is Button and not b.is_queued_for_deletion() and not b.disabled)
			if not acts.is_empty():
				acts[0].pressed.emit()
		await process_frame
	return {}


func _combat_bar(gs) -> void:
	print("Combat bar")
	gs.reset_party_from_catalog()
	gs.selected_difficulty_id = "aprendiz"
	_check(gs.start_mission(), "start an expedition")
	# Walk next to a combat room, then step in through the screen.
	var fight_room: String = ""
	for step in 60:
		for nid in gs.mission_neighbors():
			if str(gs.mission_nodes_index.get(nid, {}).get("type", "")) == "combat":
				fight_room = str(nid)
				break
		if fight_room != "":
			break
		var nxt: String = ""
		for nid in gs.mission_neighbors():
			if not gs.visited_node_ids.has(nid):
				nxt = str(nid)
				break
		gs.move_to_node(nxt if nxt != "" else str(gs.mission_neighbors()[0]))
		gs.mark_node_cleared(gs.current_node_id)
	var screen = load("res://scenes/expedition/expedition_screen.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	screen._on_room_clicked(fight_room)
	var hero: Dictionary = await _wait_turn(screen)
	_check(fight_room != "" and not hero.is_empty(), "a hero's turn comes up in a fight (room %s, mode %d)" % [fight_room, int(screen._mode)])
	var before: Array = _bar(screen)
	var guard_b = before.filter(func(b): return str(b.get("title")) == "Guardia")
	_check(guard_b.size() == 1, "the bar has Guardia")
	if guard_b.size() == 1:
		guard_b[0].pressed.emit()
		var locked: Array = _bar(screen)
		var same: bool = locked.size() == before.size() and range(locked.size()).all(func(i): return is_same(locked[i], before[i]) and locked[i].is_inside_tree())
		# Locked until the next hero's turn, which may already have started (no enemy in between).
		var hero_up: bool = not screen._combat.active_hero().is_empty() and not is_same(screen._combat.active_hero(), hero)
		_check(same and (hero_up or locked.all(func(b): return b.disabled)),
			"after acting, the same buttons stay up, locked (their tooltips don't vanish)")
		var calls: Array = [0]
		var was: bool = locked[0].disabled
		var old_action: Callable = locked[0].action
		locked[0].disabled = true
		locked[0].action = func(): calls[0] += 1
		locked[0].pressed.emit()
		_check(calls[0] == 0, "a locked button does nothing")
		locked[0].disabled = was
		locked[0].action = old_action
		var next: Dictionary = await _wait_turn(screen)
		if not next.is_empty():
			var after: Array = _bar(screen)
			_check(is_same(after[0], before[0]) and after.size() == before.size(), "the next hero's turn reuses the same buttons")
			_check(after.all(func(b): return b.title != ""), "and refills them for that hero")
	screen.queue_free()
	gs.end_mission_abandon()
	await process_frame


## The town view (P4-17): a picture per building; hover lights it and names it, a click
## opens its window with its page, Esc or "Volver al pueblo" closes it.
func _town(gs) -> void:
	print("Town view")
	root.size = Vector2i(1280, 720)  # headless windows start at 64x64
	gs.reset_party_from_catalog()
	gs.active_event_id = ""
	var hub = load("res://scenes/hacienda/hacienda_hub.tscn").instantiate()
	root.add_child(hub)
	await process_frame
	await process_frame
	var ids: Array = hub._buildings.keys()
	ids.sort()
	_check(ids == ["cantina", "casa_comunal", "clinica", "iglesia", "pulperia", "taller", "terminal"], "the town has the 7 buildings (%s)" % ", ".join(ids))
	var ok: bool = true
	for bid in hub._buildings:
		var b = hub._buildings[bid]
		ok = ok and b.size.x > 40.0 and b.size.y > 40.0 and Rect2(Vector2.ZERO, hub.size).encloses(Rect2(b.position, b.size).grow(-4.0))
	_check(ok, "every building is on screen (screen %s)" % hub.size)
	var ig = hub._buildings.get("iglesia")
	if ig != null:
		_check(not ig._has_point(Vector2(1, 1)), "a transparent corner of the picture is not the building")
		_check(ig._has_point(ig.size / 2.0), "its middle is")
		ig._set_hover(true)
		await process_frame
		_check(ig._plate.visible and ig._plate.is_inside_tree() and ig._plate_label.text.begins_with("Iglesia Vieja"), "hovering shows the name plate")
		ig._set_hover(false)
		_check(not ig._plate.visible, "and leaving hides it")
	ok = true
	for bid in hub._buildings:
		hub._buildings[bid].chosen.emit(bid)
		await process_frame
		var shown: Array = hub._pages.get_children().filter(func(p): return p.visible).map(func(p): return str(p.name))
		ok = ok and hub._window.visible and shown == [bid] and hub.get_node("Building/VBox/Head/Texts/Name").text == str(hub._buildings[bid].title)
		hub.close_building()
	_check(ok, "clicking each building opens its own window and page")
	_check(not hub._window.visible, "Volver al pueblo closes it")
	hub.open_building("casa_comunal")
	await process_frame
	_check(hub._who.visible and hub._skills_row.get_child_count() > 0, "the Casa Comunal shows whose skills they are")
	hub.close_building()
	hub.queue_free()
	await process_frame
	# A town event that closes the terminal greys it out.
	var te = gs.TownEventsScript
	var closing: Array = te.all().filter(func(e): return e.get("effects", {}).get("closed", []).has("terminal"))
	if not closing.is_empty():
		gs.active_event_id = str(closing[0]["id"])
		hub = load("res://scenes/hacienda/hacienda_hub.tscn").instantiate()
		root.add_child(hub)
		await process_frame
		var t = hub._buildings.get("terminal")
		_check(t != null and t.closed and t.note.contains("Cerrada"), "a building closed by the town event is greyed out")
		hub.queue_free()
		gs.active_event_id = ""
		await process_frame
