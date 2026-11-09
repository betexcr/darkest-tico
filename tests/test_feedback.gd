extends SceneTree

## Battle feedback: status icons above a fighter and floating damage/heal/stress numbers.
##   godot --headless --path . -s tests/test_feedback.gd

var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		_failures += 1
		print("  FAIL ", what)


func _popups(u) -> int:
	var n: int = 0
	for c in u._holder.get_children():
		if c.has_meta("popup"):
			n += 1
	return n


func _run() -> void:
	await process_frame
	var Unit = load("res://scripts/combat/battle_unit.gd")
	var hero := {"name": "Prueba", "hero_id": "campesino", "hp": 20, "hp_max": 30, "stress": 10,
		"statuses": {"sangrado": {"turns": 2, "value": 2}, "veneno": {"turns": 3, "value": 1}}, "guarding": true}
	var u = Unit.new()
	u.setup(hero, true, "res://assets/portraits/campesino.png")
	root.add_child(u)
	await process_frame
	u.refresh()
	await process_frame
	_check(u._status_row.get_child_count() == 3, "sangrado + veneno + guard show 3 icons (%d)" % u._status_row.get_child_count())
	_check(not u._status_label.text.contains("Sangrado"), "ailments are icons, not text")
	var tip: String = u._status_row.get_child(0).tooltip_text
	_check(tip.contains("turno"), "icon tooltip shows turns left (%s)" % tip)
	hero.erase("statuses")
	hero["guarding"] = false
	u.refresh()
	await process_frame
	_check(u._status_row.get_child_count() == 0, "icons cleared when statuses end")

	u.play_hurt(7, false)
	await process_frame
	_check(_popups(u) == 1, "damage shows a floating number")
	u.play_heal(4, 5)
	await process_frame
	_check(_popups(u) == 3, "heal + stress relief show two more numbers")
	await create_timer(1.6).timeout
	_check(_popups(u) == 0, "floating numbers fade out and are freed")

	var enemy := {"name": "Espanto", "id": "espanto", "hp": 0, "hp_max": 20, "dead": true}
	var e = Unit.new()
	e.setup(enemy, false, "res://assets/enemies/espanto.png")
	root.add_child(e)
	await process_frame
	e.refresh()
	_check(e._status_row.get_child_count() == 0, "dead fighters show no icons")
	# Defeated enemies: drawn behind the living, and clicks pass through them.
	e.rest()
	var clicks: Array = []
	e.clicked.connect(func(_u): clicks.append(1))
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	e._gui_input(click)
	_check(clicks.is_empty() and e.mouse_filter == Control.MOUSE_FILTER_IGNORE, "a defeated enemy can't be clicked")
	_check(e.z_index < u.z_index, "the fallen are drawn behind the living")
	print("%d failure(s)" % _failures)
	quit(1 if _failures > 0 else 0)
