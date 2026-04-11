extends Control



const HaciendaHubScene := preload("res://scenes/hacienda/hacienda_hub.tscn")

const ExpeditionMapScene := preload("res://scenes/expedition/expedition_map.tscn")

const CombatScene := preload("res://scenes/combat/combat_scene.tscn")





func _ready() -> void:

	await _open_hub()





func _open_hub() -> void:

	for c in get_children():

		c.queue_free()

	await get_tree().process_frame

	var hub := HaciendaHubScene.instantiate() as Control

	hub.start_mission_requested.connect(_on_start_expedition, CONNECT_ONE_SHOT)

	add_child(hub)





func _on_start_expedition() -> void:

	if not GameState.start_mission():

		push_error("Main: no se pudo iniciar la misión (JSON región).")

		return

	await _open_expedition()





func _open_expedition() -> void:

	for c in get_children():

		c.queue_free()

	await get_tree().process_frame

	var exp_map := ExpeditionMapScene.instantiate() as Control

	exp_map.combat_requested.connect(_on_combat_from_expedition, CONNECT_ONE_SHOT)

	exp_map.expedition_finished.connect(_on_expedition_finished, CONNECT_ONE_SHOT)

	add_child(exp_map)





func _on_combat_from_expedition() -> void:

	for c in get_children():

		c.queue_free()

	await get_tree().process_frame

	var combat := CombatScene.instantiate() as Control

	combat.combat_finished.connect(_on_combat_closed_return_expedition, CONNECT_ONE_SHOT)

	add_child(combat)





func _on_combat_closed_return_expedition(_victory: bool) -> void:

	await _open_expedition()





func _on_expedition_finished(_reason: String) -> void:

	SaveService.save_game()

	await _open_hub()


