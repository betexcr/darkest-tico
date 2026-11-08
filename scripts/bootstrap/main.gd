extends Control

## Swaps between the hacienda hub and the expedition screen (exploration + combat).

const HaciendaHubScene := preload("res://scenes/hacienda/hacienda_hub.tscn")
const ExpeditionScreenScene := preload("res://scenes/expedition/expedition_screen.tscn")
const VictoryScreenScript := preload("res://scripts/expedition/victory_screen.gd")


func _ready() -> void:
	await _open_hub()


func _clear() -> void:
	for c in get_children():
		c.queue_free()
	await get_tree().process_frame


func _open_hub() -> void:
	await _clear()
	var hub := HaciendaHubScene.instantiate() as Control
	hub.start_mission_requested.connect(_on_start_expedition, CONNECT_ONE_SHOT)
	add_child(hub)


func _on_start_expedition() -> void:
	if not GameState.start_mission():
		push_error("Main: no se pudo iniciar la misión (JSON región).")
		return
	await _clear()
	var screen := ExpeditionScreenScene.instantiate() as Control
	screen.expedition_finished.connect(_on_expedition_finished, CONNECT_ONE_SHOT)
	add_child(screen)


func _on_expedition_finished(reason: String) -> void:
	# Completed expeditions show the victory screen (loot + Resolve XP) before the hub.
	if reason == "objective" and not GameState.last_expedition_summary.is_empty():
		await _clear()
		var victory := VictoryScreenScript.new()
		victory.continue_pressed.connect(_back_to_hub, CONNECT_ONE_SHOT)
		add_child(victory)
		return
	await _back_to_hub()


func _back_to_hub() -> void:
	GameState.last_expedition_summary = {}
	GameState.end_of_expedition_week()
	SaveService.save_game()
	await _open_hub()
