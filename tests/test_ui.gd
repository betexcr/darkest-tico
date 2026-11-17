extends SceneTree

## Menus in the item-card style (P4-15): the game-wide theme, the hover cards (heroes,
## candidates, Iglesia/Cantina activities) and the card dialogs (Clínica, town event,
## provisions, dismiss) all build without errors.
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
		var info = row.get_child(1)
		ok = ok and _builds(info.card)
	_check(ok, "every roster hero has a hero card")
	ok = true
	for b in hub._recruit_box.get_children():
		ok = ok and b.get("card") != null and _builds(b.card)
	_check(ok and hub._recruit_box.get_child_count() > 0, "every candidate at the terminal has a hero card")
	var acts: Array = []
	for row in hub._relief_box.get_children():
		if row is HBoxContainer:
			for c in row.get_children():
				if c is Button:
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

	print("%d failure(s)" % _fail)
	quit(1 if _fail > 0 else 0)
