extends SceneTree

## Headless smoke test: plays whole expeditions through the real expedition screen.
##   godot --headless --path . -s tests/smoke_expedition.gd
## Walks toward the boss, takes the first option of every event, fights with each hero's
## first skill, and checks the per-hero item limit. Exit code 1 on any failed check;
## also read the output for "SCRIPT ERROR" lines.

const RUNS := 3
const MAX_STEPS := 3000

var _failures: int = 0
var _finished: String = ""


func _initialize() -> void:
	Engine.time_scale = 20.0
	_run.call_deferred()


func _check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		_failures += 1
		print("  FAIL ", what)


func _run() -> void:
	await process_frame
	var gs = root.get_node("GameState")
	var loader = load("res://scripts/domain/expedition_loader.gd")
	var scene: PackedScene = load("res://scenes/expedition/expedition_screen.tscn")
	for run in RUNS:
		print("Run %d" % (run + 1))
		gs.reset_party_from_catalog()
		gs.reset_inventory_to_starter()
		gs.colones = 5000
		_check(gs.start_mission(), "start_mission")
		_check(gs.mission_nodes_index.size() >= 10, "generated %d rooms" % gs.mission_nodes_index.size())
		var boss: Dictionary = gs.mission_nodes_index.get(gs.objective_node_id, {})
		_check(str(boss.get("type", "")) == "boss", "objective room is the boss")
		_finished = ""
		var screen = scene.instantiate()
		screen.expedition_finished.connect(func(reason: String): _finished = reason)
		root.add_child(screen)
		await process_frame

		# Per-hero item limit: same hero twice in one room is blocked, another hero is allowed.
		var h0: Dictionary = gs.party[0]
		var h1: Dictionary = gs.party[1]
		var before: int = gs.item_count("agua_pipa")
		gs.use_item_outside_combat("agua_pipa", h0)
		_check(gs.item_count("agua_pipa") == before - 1, "hero 1 uses agua de pipa")
		_check(gs.item_block_reason_outside_combat("agua_pipa", h0) != "", "hero 1 blocked from a 2nd use in this room")
		_check(gs.item_block_reason_outside_combat("agua_pipa", h1) == "", "hero 2 may still use it here")

		var steps: int = 0
		var rooms_moved: int = 0
		var hero_turns: int = 0
		var guards: int = 0
		var moves: int = 0
		var max_squad: int = 1
		var picks: int = 0
		var info_opened: bool = false
		# Walk through the camp room first (camping + respite UI), then to the boss.
		var camp_id: String = ""
		for nid in gs.mission_nodes_index:
			if str(gs.mission_nodes_index[nid].get("type", "")) == "camp":
				camp_id = str(nid)
				break
		while _finished == "" and steps < MAX_STEPS:
			steps += 1
			await process_frame
			match int(screen._mode):
				0:  # EXPLORE
					var goal: String = gs.objective_node_id
					if camp_id != "" and gs.camped_node_ids.is_empty() and gs.current_node_id != camp_id:
						goal = camp_id
					var path: Array = _path(gs, loader, gs.current_node_id, goal)
					if path.size() >= 2:
						screen._on_room_clicked(str(path[1]))
						rooms_moved += 1
				1, 3:  # EVENT, ENDED: take the first option that can be used
					var actions = screen._event_actions.get_children().filter(func(b): return b is Button and not b.is_queued_for_deletion() and not b.disabled)
					if not actions.is_empty():
						actions[0].pressed.emit()
				2:  # COMBAT
					var hero: Dictionary = screen._combat.active_hero()
					if not hero.is_empty():
						var buttons = screen._skills.get_children()
						if not buttons.is_empty():
							hero_turns += 1
							if hero_turns == 2 and not screen._enemy_units.is_empty():
								screen._on_unit_clicked(screen._enemy_units[0])
								info_opened = info_opened or screen._enemy_info.visible
							# Buttons: 4 skills, Alforja, Moverse, Guardia, Pasar. Skills out of reach
							# from the hero's position are disabled (pressed.emit() would ignore that,
							# so the bot only presses enabled ones). Every 7th turn: Guardia; every
							# 11th (or when nothing is in reach): Moverse; every 3rd: the last usable skill; otherwise the first
							# usable one (falling back to Moverse, then Guardia). Skills that need a
							# target wait for a click on a highlighted unit.
							var live: Array = buttons.filter(func(b): return not b.is_queued_for_deletion())
							var skill_btns: Array = live.slice(0, 4).filter(func(b): return not b.disabled)
							var by_title: Dictionary = {}
							for b in live:
								by_title[str(b.get("title"))] = b
							var move_b = by_title.get("Moverse", null)
							var can_move: bool = move_b != null and not move_b.disabled
							if hero_turns % 7 == 0 and by_title.has("Guardia"):
								guards += 1
								by_title["Guardia"].pressed.emit()
							elif (hero_turns % 11 == 0 or skill_btns.is_empty()) and can_move:
								moves += 1
								move_b.pressed.emit()
							elif not skill_btns.is_empty():
								(skill_btns[-1] if hero_turns % 3 == 0 else skill_btns[0]).pressed.emit()
							else:
								guards += 1
								by_title["Guardia"].pressed.emit()
							if not screen._pending.is_empty():
								picks += 1
								var heroes: bool = str(screen._pending["side"]) == "ally"
								var opts: Array = screen._living_units(heroes)
								max_squad = maxi(max_squad, screen._enemy_units.size())
								screen._on_unit_clicked(opts[opts.size() - 1])
		_check(_finished != "", "expedition ended (%s) after %d moves, %d hero turns, %d guards" % [_finished, rooms_moved, hero_turns, guards])
		_check(_finished in ["objective", "defeat"], "ended by boss victory or defeat")
		if camp_id != "":
			_check(int(gs.mission_ledger.get("camps", 0)) == 1 or _finished == "defeat", "camped once (%d ambush)" % int(gs.mission_ledger.get("ambushes", 0)))
		if _finished == "objective":
			var sm: Dictionary = gs.last_expedition_summary
			var survivors: Array = sm.get("heroes", []).filter(func(e): return not e["dead"])
			_check(not survivors.is_empty() and survivors.all(func(e): return int(e["xp_gained"]) > 0), "victory summary: every survivor earned Resolve XP")
			gs.last_expedition_summary = {}
		_check(max_squad > 1, "fought a squad of up to %d enemies" % max_squad)
		_check(picks > 0, "chose targets after pressing a skill %d times" % picks)
		_check(moves > 0 or _finished == "defeat", "used Moverse %d times" % moves)
		if run == 0:
			_check(info_opened, "clicking an enemy opens its info panel")
		screen.queue_free()
		await process_frame
	print("%d failure(s)" % _failures)
	quit(1 if _failures > 0 else 0)


## Shortest room path (BFS) using the mission graph.
func _path(gs, loader, from_id: String, to_id: String) -> Array:
	var prev: Dictionary = {from_id: ""}
	var queue: Array = [from_id]
	while not queue.is_empty():
		var cur: String = queue.pop_front()
		if cur == to_id:
			break
		for n in loader.neighbors(gs.mission_region_data, cur):
			if not prev.has(str(n)):
				prev[str(n)] = cur
				queue.append(str(n))
	if not prev.has(to_id):
		return []
	var path: Array = [to_id]
	while path[0] != from_id:
		path.push_front(prev[path[0]])
	return path
