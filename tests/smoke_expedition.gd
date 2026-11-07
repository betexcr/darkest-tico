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
		var max_squad: int = 1
		var picks: int = 0
		var info_opened: bool = false
		while _finished == "" and steps < MAX_STEPS:
			steps += 1
			await process_frame
			match int(screen._mode):
				0:  # EXPLORE
					var path: Array = _path(gs, loader, gs.current_node_id, gs.objective_node_id)
					if path.size() >= 2:
						screen._on_room_clicked(str(path[1]))
						rooms_moved += 1
				1, 3:  # EVENT, ENDED: take the first option
					var actions = screen._event_actions.get_children()
					if not actions.is_empty() and not actions[0].disabled:
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
							# Buttons: skills..., Guardia, Pasar. Every 7th turn: Guardia; every 3rd:
							# the last skill (a support skill); otherwise the first attack. Skills that
							# need a target wait for a click on a highlighted unit.
							if hero_turns % 7 == 0 and buttons.size() >= 2:
								guards += 1
								buttons[buttons.size() - 2].pressed.emit()
							elif hero_turns % 3 == 0 and buttons.size() >= 3:
								buttons[buttons.size() - 3].pressed.emit()
							else:
								buttons[0].pressed.emit()
							if not screen._pending.is_empty():
								picks += 1
								var heroes: bool = str(screen._pending["side"]) == "ally"
								var opts: Array = screen._living_units(heroes)
								max_squad = maxi(max_squad, screen._enemy_units.size())
								screen._on_unit_clicked(opts[opts.size() - 1])
		_check(_finished != "", "expedition ended (%s) after %d moves, %d hero turns, %d guards" % [_finished, rooms_moved, hero_turns, guards])
		_check(_finished in ["objective", "defeat"], "ended by boss victory or defeat")
		_check(max_squad > 1, "fought a squad of up to %d enemies" % max_squad)
		_check(picks > 0, "chose targets after pressing a skill %d times" % picks)
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
