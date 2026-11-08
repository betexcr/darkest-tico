extends SceneTree

## Using consumables in battle through the action bar's Alforja button: the item is used,
## the hero's turn is spent, and non-combat items are not offered.
##   godot --headless --path . -s tests/test_combat_items.gd

var _fail: int = 0


func _check(cond: bool, what: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + what)
	if not cond:
		_fail += 1


func _initialize() -> void:
	Engine.time_scale = 20.0
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var gs = root.get_node("GameState")
	gs.reset_party_from_catalog()
	gs.inventory.clear()
	gs.add_item("agua_pipa", 2)
	gs.add_item("gallo_pinto", 2)       # exploration only
	gs.add_item("agua_de_la_negrita", 1)
	gs.start_mission()
	var screen = load("res://scenes/expedition/expedition_screen.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	for id in gs.mission_nodes_index:
		if str(gs.mission_nodes_index[id].get("type", "")) == "combat":
			screen._start_combat(str(id))
			break
	# Wait for the first hero turn.
	var hero: Dictionary = {}
	for i in 600:
		await process_frame
		hero = screen._combat.active_hero()
		if not hero.is_empty():
			break
	_check(not hero.is_empty(), "a hero's turn comes up")
	var names: Array = []
	for b in screen._skills.get_children():
		names.append(str(b.get("title")) if b.get("title") != null else "")
	_check(names.has("Alforja"), "the action bar has an Alforja button")
	screen._show_combat_items(hero)
	await process_frame
	var offered: Array = []
	for b in screen._skills.get_children():
		if b.get("item_id") != null and str(b.item_id) != "":
			offered.append(str(b.item_id))
	_check(offered.has("agua_pipa") and offered.has("agua_de_la_negrita"), "combat items are offered (%s)" % ", ".join(offered))
	_check(not offered.has("gallo_pinto"), "exploration-only items are not offered")
	hero["hp"] = 1
	var before_qty: int = gs.item_count("agua_pipa")
	var turn_before: int = screen._combat._turn_index
	var round_before: int = screen._combat._round
	screen._on_item_pressed("agua_pipa")
	if not screen._pending.is_empty():
		screen._execute_pending(hero)
	for i in 120:
		await process_frame
		if screen._combat._turn_index != turn_before or screen._combat._round != round_before:
			break
	_check(gs.item_count("agua_pipa") == before_qty - 1, "the item is used up")
	_check(int(hero["hp"]) > 1 or bool(hero.get("dead", false)), "it took effect (agua de pipa heals)")
	_check(screen._combat._turn_index != turn_before or screen._combat._round != round_before, "using it spent the hero's turn")
	print("%d failure(s)" % _fail)
	quit(1 if _fail > 0 else 0)
