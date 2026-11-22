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
		var info = row.get_child(0).get_child(1).get_child(0)
		ok = ok and _builds(info.card)
	_check(ok, "every roster hero has a hero card")
	ok = true
	for r in hub._recruit_box.get_children():
		ok = ok and r.has_meta("hire") and r.get_meta("hire") is Button and r.get_meta("hire").text.begins_with("Contratar")
	_check(ok and hub._recruit_box.get_child_count() > 0, "every candidate at the terminal is a card row with its own hire button (owner 2026-11-19)")
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
	hub._show_hero_sheet(gs.roster[0])
	await process_frame
	d = _dialogs(hub)
	var cats: Array = load("res://scripts/domain/status_effects.gd").resist_categories()
	var tips: Array = []
	if d.size() == 1:
		tips = d[0].find_children("*", "HBoxContainer", true, false).filter(func(c): return str(c.tooltip_text) != "")
	ok = tips.size() >= cats.size()
	for cat in cats:
		var found: Array = tips.filter(func(c): return str(c.tooltip_text).begins_with(str(cat["name"]) + " — "))
		ok = ok and found.size() == 1 and str(found[0].tooltip_text).contains(str(cat["desc"])) \
			and (found[0].get_child(0) is TextureRect and found[0].get_child(0).texture != null or found[0].get_child(0) is PanelContainer)
	_check(ok, "the hero sheet shows every resistance with an icon and a tooltip")
	# Other-sex art (P4-24) that the editor hasn't imported yet still loads (raw PNG fallback).
	_check(gs.load_texture("res://assets/portraits/exorcista_m.png") != null and gs.load_texture("res://assets/portraits/nope.png") == null, "portraits load, imported or not")
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
		var ed: Array = _dialogs(hub)
		ok = ok and ed.size() == 1 and str(ed[0].get_meta("event_id", "")) == str(ev["id"])
		var et: Label = null if ed.is_empty() else ed[0].find_child("EventTitle", true, false)
		ok = ok and et != null and et.text == str(ev["name"])
		var pic: TextureRect = null if ed.is_empty() else ed[0].find_child("Picture", true, false)
		ok = ok and pic != null and pic.texture != null
		await _close_all(hub)
	_check(ok, "every town event's card opens with its title and picture (%d)" % gs.TownEventsScript.all().size())
	gs.active_event_id = ""
	hub.queue_free()
	await process_frame
	await _town(gs)
	await _event_result(gs)
	await _combat_bar(gs)

	print("%d failure(s)" % _fail)
	quit(1 if _fail > 0 else 0)


## Live (not queued-for-deletion) children of the combat bar.
func _bar(screen) -> Array:
	return screen._skills.get_children().filter(func(c): return not c.is_queued_for_deletion())


## Waits (up to 30 s of real time: the fight plays its animations) for a hero's turn.
func _wait_turn(screen) -> Dictionary:
	var until: int = Time.get_ticks_msec() + 120000  # wall clock: a busy machine (parallel imports, sims) can be slow
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
	# Picking a target lights only what the skill can reach (owner 2026-11-19).
	if not hero.is_empty():
		var atk: Dictionary = {}
		for sid in hero.get("skill_ids", []):
			var sk: Dictionary = gs.hero_skill(hero, str(sid))
			if str(sk.get("kind", "")) == "attack" and screen._combat.skill_usable(hero, sk):
				atk = sk
				break
		if not atk.is_empty():
			screen._selected_enemy = {}
			screen._begin_pending({"side": "enemy", "skill": atk})
			var reach: Array = screen._combat.targets_for(atk)
			var lit: Array = screen._enemy_units.filter(func(u): return u._selectable or u._targeted)
			_check(lit.all(func(u): return reach.has(u.data)) and lit.size() == screen._enemy_units.filter(func(u): return reach.has(u.data) and not u.is_dead()).size(),
				"%s lights exactly the enemies it can reach (%d)" % [atk.get("name", ""), lit.size()])
			screen._cancel_pending()
		var se = load("res://scripts/domain/status_effects.gd")
		var victim: Dictionary = gs.party[1]
		se.apply(victim, "embargado", 3, 0, {"ignore_resist": true})
		var heal_pick: Array = screen._living_units(true, {"side": "ally", "item": "agua_pipa"}).map(func(u): return u.data)
		var calm_pick: Array = screen._living_units(true, {"side": "ally", "item": "cafe_chorreado"}).map(func(u): return u.data)
		_check(se.has(victim, "embargado") and not heal_pick.has(victim) and calm_pick.has(victim), "an Embargado ally can't be picked for a heal (but can for other help)")
		se.remove(victim, "embargado")
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
	_check(ids == ["cantina", "casa_comunal", "clinica", "feria", "guardabosques", "iglesia", "pulperia", "taller", "terminal"], "the town has the 9 buildings (%s)" % ", ".join(ids))
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
	# Taller (owner 2026-11-19): the equipment section starts folded; a hero click toggles it.
	hub.open_building("taller")
	await process_frame
	_check(not hub._equip_open and not hub._equip_row.visible and not hub._who.visible, "the Taller opens with the equipment folded away")
	# The roster rebuilds after every click: fetch the hero's button each time.
	var info := func(i: int): return hub._roster_list.get_children().filter(func(r): return not r.is_queued_for_deletion())[i].get_child(0).get_child(1).get_child(0)
	info.call(1).pressed.emit()
	await process_frame
	_check(hub._equip_open and hub._equip_row.visible and is_same(hub._selected, gs.party[1]), "clicking a hero opens it for that hero")
	info.call(1).pressed.emit()
	await process_frame
	_check(not hub._equip_open and not hub._equip_row.visible, "clicking the same hero again closes it")
	info.call(1).pressed.emit()
	await process_frame
	info.call(0).pressed.emit()
	await process_frame
	_check(hub._equip_open and is_same(hub._selected, gs.party[0]), "clicking another hero while open switches to them")
	hub._equip_bar.pressed.emit()
	_check(not hub._equip_open and not hub._equip_row.visible, "the bar closes it too")
	# Dragging a piece of equipment lights up the slots it can go into (owner 2026-11-19).
	hub._equip_open = true
	hub._refresh()
	await process_frame
	var weapon: String = gs.all_item_ids().filter(func(i): return str(gs.get_item(str(i)).get("slot", "")) == "weapon")[0]
	var acc: String = gs.all_item_ids().filter(func(i): return str(gs.get_item(str(i)).get("slot", "")) == "accessory")[0]
	var lit := func(): return hub._equip_slots.filter(func(es): return es.drop_hint).map(func(es): return str(es.slot))
	hub._equip_slots[0].force_drag({"kind": "item", "id": weapon}, Label.new())
	await process_frame
	_check(lit.call() == ["weapon"], "dragging a weapon lights only the weapon slot (%s)" % ", ".join(lit.call()))
	root.gui_cancel_drag()
	await process_frame
	_check(lit.call().is_empty(), "the light goes out when the drag ends")
	hub._equip_slots[0].force_drag({"kind": "item", "id": acc}, Label.new())
	await process_frame
	_check(lit.call() == ["accessory1", "accessory2"], "an accessory lights both accessory slots")
	root.gui_cancel_drag()
	await process_frame
	hub.close_building()
	hub.open_building("casa_comunal")
	await process_frame
	_check(hub._who.visible and hub._skills_row.get_child_count() > 0, "the Casa Comunal shows whose skills they are")
	hub.close_building()
	hub.open_building("guardabosques")
	await process_frame
	var rows: Array = hub._ranger_box.get_children().filter(func(c): return c is PanelContainer and not c.is_queued_for_deletion())
	_check(hub._who.visible and rows.size() == 8, "the Guardabosques lists the hero's 6 class + 2 shared camp skills (%d rows)" % rows.size())
	var col0: int = gs.colones
	var learn: Array = []
	for r in rows:
		for b in r.find_children("*", "Button", true, false):
			if b.text.begins_with("Aprender") and not b.disabled:
				learn.append(b)
	if not learn.is_empty():
		learn[0].pressed.emit()
		await process_frame
	_check(learn.size() == 3 and gs.colones == col0 - gs.BalanceScript.int_of("camp.learn_price"), "…'Aprender' on an unknown skill teaches it")
	hub.close_building()
	# With no building open, a hero click opens their full sheet (owner 2026-11-19).
	await process_frame
	info.call(2).pressed.emit()
	await process_frame
	var sheets: Array = hub.get_children().filter(func(c): return c is AcceptDialog and c.visible and c.title.begins_with("Ficha de"))
	_check(sheets.size() == 1 and sheets[0].title == "Ficha de %s" % gs.party[2]["name"], "a hero click in the town opens their sheet")
	if sheets.size() == 1:
		var texts: Array = []
		var stack: Array = [sheets[0]]
		var skills: int = 0
		var gear: int = 0
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			stack.append_array(n.get_children())
			if n is Label:
				texts.append(n.text)
			if n is Button and n.get_script() == hub.SkillButtonScript:
				skills += 1
			if n.get_script() == hub.ItemHoverScript:
				gear += 1
		var all_t: String = " ".join(texts)
		_check(all_t.contains("Precisión") and all_t.contains("Protección") and all_t.contains("RESISTENCIAS") and all_t.contains("EQUIPO"), "…with stats, resistances and equipment")
		_check(skills == gs.party[2]["skill_ids"].size(), "…and every skill as an icon with its card (%d)" % skills)
		# Owner 2026-11-21: a click inside keeps the sheet open, a click outside closes it.
		var sheet: AcceptDialog = sheets[0]
		var inside := Vector2(sheet.position) + Vector2(sheet.size) * 0.5
		await _click(inside)
		_check(sheet.visible, "…a click inside the sheet keeps it open")
		await _click(Vector2(sheet.position) - Vector2(30, 30))
		_check(not is_instance_valid(sheet) or not sheet.visible, "…a click outside the sheet closes it")
		if is_instance_valid(sheet) and sheet.visible:
			sheet.hide()
	_check(hub._roster_click_hint().contains("ficha"), "the roster hint says a click opens the sheet")
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


## Event results in a card dialog (owner 2026-11-19), not only in the log.
func _event_result(gs) -> void:
	print("Event result card")
	gs.reset_party_from_catalog()
	gs.start_mission()
	var screen = load("res://scenes/expedition/expedition_screen.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	screen.results_modal = true
	screen._open_event("Cajón de la carreta", "Hay algo envuelto en hoja.")
	screen._apply_outcome("En el cajón hay provisiones envueltas en hoja.", {"colones": 40})
	await process_frame
	var dlg = screen._result_dialog
	_check(dlg != null and dlg.visible and dlg.title == "Cajón de la carreta", "the result opens as a card dialog with the event's name")
	_check(int(screen._mode) == 1, "exploring waits while it is open")
	dlg.hide()
	await process_frame
	_check(screen._result_dialog == null and int(screen._mode) == 0, "Continuar closes it and exploring goes on")
	var tone = screen.get_script()
	_check(tone._result_tone("Lalo: estrés -6.") == 1 and tone._result_tone("Estrés +5 a la cuadrilla.") == -1 and tone._result_tone("Luz -25.") == -1
		and tone._result_tone("+40 colones.") == 1 and tone._result_tone("Lalo pierde 4 PV.") == -1, "good and bad results are told apart (stress and Luz read the right way)")
	# Six enemies (a boss with summons and the fallen, owner 2026-11-19) stack in two lines,
	# smaller, positions 1-4 below; they never spill over the party.
	var six: Array = []
	for i in 6:
		six.append(gs.make_enemy("sirviente_ahogado", 6))
	root.size = Vector2i(1280, 720)
	screen._spawn_enemies(six)
	for i in 3:
		await process_frame
	var units: Array = screen._enemy_units
	var bl = load("res://scripts/combat/battle_unit.gd")
	_check(units.all(func(u): return u._size == bl.ENEMY_COMPACT), "with 6 enemies every portrait is compact")
	var front_y: float = units[0].global_position.y
	_check(units.slice(0, 4).all(func(u): return is_equal_approx(u.global_position.y, front_y)) and units[4].global_position.y < front_y - 40.0,
		"positions 1-4 on the lower line, the rest stacked above")
	var right_edge: float = units.map(func(u): return u.get_global_rect().end.x).max()
	_check(right_edge <= screen._hero_row.get_global_rect().position.x + 1.0, "no enemy reaches into the party's half (%.0f)" % right_edge)
	_check(units[0].get_global_rect().position.x > units[3].get_global_rect().position.x, "position 1 is nearest the middle")
	# The details panel closes on a click anywhere but a fighter or the panel itself.
	screen._show_enemy_info(units[0].data)
	var click := func(at: Vector2):
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = true
		ev.position = at
		screen._input(ev)
	click.call(units[1].get_global_rect().get_center())
	_check(screen._enemy_info.visible, "a click on another fighter leaves it open (the fighter's own click updates it)")
	click.call(Vector2(640, 700))
	_check(not screen._enemy_info.visible, "a click on the bottom panel closes it")
	screen._show_enemy_info(units[0].data)
	click.call(Vector2(screen._hero_units[1]._holder.get_global_rect().get_center().x, 60))
	_check(not screen._enemy_info.visible, "a click on the empty stage (even above a hero) closes it")
	screen._clear_enemies()
	_check(load("res://scripts/domain/formation.gd").target_ranks(gs.get_skill("dron_casero")).has(1), "Dron Casero (long-range) reaches enemy position 1")
	# The battle card after a won fight (P5-10): loot and how each hero came out.
	var h0: Dictionary = gs.party[0]
	screen._battle_start = {}
	for h in gs.party:
		screen._battle_start[int(h["uid"])] = {"hp": int(h["hp"]), "stress": int(h["stress"]), "dead": false, "aff": "", "vir": ""}
	h0["hp"] = int(h0["hp"]) - 7
	h0["stress"] = int(h0["stress"]) + 9
	screen._show_battle_result("¡Victoria!", 120, {"got": ["agua_pipa"], "lost": ["bombeta"]})
	await process_frame
	var bd = screen._result_dialog
	var texts: Array = []
	var walk: Array = [bd] if bd != null else []
	while not walk.is_empty():
		var n = walk.pop_front()
		if n is Label:
			texts.append(str(n.text))
		walk.append_array(n.get_children())
	var all: String = " | ".join(texts)
	_check(bd != null and bd.title == "¡Victoria!", "a won fight opens the battle card")
	_check(all.contains("+120 colones") and all.contains("Agua de pipa") and all.contains("no cabe"), "it lists the colones, the drop and what didn't fit")
	_check(all.contains("%s: PV" % h0["name"]) and all.contains("estrés +9"), "and what each hero lost (%s)" % all.substr(0, 120))
	# Loot rows show the item's card on hover (owner 2026-11-19).
	var hovers: Array = []
	var stack: Array = [bd]
	while not stack.is_empty():
		var n = stack.pop_back()
		if n.get_script() == load("res://scripts/ui/item_hover.gd"):
			hovers.append(n)
		stack.append_array(n.get_children())
	var card = hovers[0]._make_custom_tooltip("") if not hovers.is_empty() else null
	_check(hovers.size() == 1 and hovers[0].item_id == "agua_pipa" and card is Control, "the looted item shows its item card on hover")
	if card is Node:
		card.free()
	var vs = load("res://scripts/expedition/victory_screen.gd").new()
	var tile = vs._item_tile("agua_pipa", 2)
	var tcard = tile._make_custom_tooltip("")
	_check(tile.item_id == "agua_pipa" and tcard is Control, "and so do the item tiles on the expedition's victory screen")
	tcard.free()
	tile.free()
	vs.free()
	bd.hide()
	await process_frame
	screen.queue_free()
	gs.end_mission_abandon()
	await process_frame


func _click(at: Vector2) -> void:
	for down in [true, false]:
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		mb.pressed = down
		mb.position = at
		mb.global_position = at
		root.push_input(mb)
		await process_frame
	await process_frame
