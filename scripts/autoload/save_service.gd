extends Node

const SAVE_PATH := "user://save.json"


func _ready() -> void:
	if not load_game():
		GameState.reset_party_from_catalog()
	save_game()


func save_game() -> void:
	var json := JSON.stringify(GameState.to_save_dict(), "\t")
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("SaveService: cannot write %s" % SAVE_PATH)
		return
	f.store_string(json)


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed == null or not (parsed is Dictionary):
		return false
	GameState.apply_save_data(parsed)
	return true
