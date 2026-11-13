extends Node

## Campaign save, user://save.json (P1-19 hardening, after the dev save was lost on 2026-11-12).
## - Headless `-s` scripts (tests, tools/sim_combat.gd, tools/screens/*) never read or write the
##   real save. Several of them can run at once; one that read a half-written file used to start
##   a new game and save it over the owner's save.
## - A save is written to a temp file, read back, the previous good save becomes `.bak`, and only
##   then is the temp file renamed into place. A crash mid-write leaves the old save intact.
## - A save that fails to load is never overwritten: it is copied aside
##   (save.broken-<unix time>.json) and the `.bak` is loaded instead when it is readable.

const SAVE_PATH := "user://save.json"

## Where the campaign is saved. Tests point it at a scratch folder.
var save_path: String = SAVE_PATH
## False while a `-s` script runs: save_game() and load_game() do nothing.
var enabled: bool = true


func _ready() -> void:
	enabled = not is_script_run()
	if not enabled:
		# Scripts start from a fresh catalog party, not the owner's campaign.
		GameState.reset_party_from_catalog()
		return
	if not load_game():
		GameState.reset_party_from_catalog()
	save_game()


## True when Godot was started with `-s`/`--script` (the main loop is the script's SceneTree).
static func is_script_run() -> bool:
	var args: PackedStringArray = OS.get_cmdline_args()
	if args.has("-s") or args.has("--script"):
		return true
	var loop: MainLoop = Engine.get_main_loop()
	return loop != null and loop.get_script() != null


func save_game() -> void:
	if not enabled:
		return
	save_to(save_path, GameState.to_save_dict())


func load_game() -> bool:
	if not enabled:
		return false
	return load_from(save_path)


static func backup_path(path: String) -> String:
	return path + ".bak"


## Writes `data` to `path` safely (temp file, read back, old save → .bak, rename). False on failure.
func save_to(path: String, data: Dictionary) -> bool:
	var tmp: String = path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("SaveService: cannot write %s (%s)" % [tmp, error_string(FileAccess.get_open_error())])
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	if _read(tmp) == null:
		push_warning("SaveService: %s did not read back; the old save is kept" % tmp)
		DirAccess.remove_absolute(_abs(tmp))
		return false
	if FileAccess.file_exists(path):
		if _read(path) != null:
			# The current save is good: it becomes the backup.
			var bak: String = backup_path(path)
			if FileAccess.file_exists(bak):
				DirAccess.remove_absolute(_abs(bak))
			DirAccess.rename_absolute(_abs(path), _abs(bak))
		else:
			# Unreadable: load_from already copied it aside; keep the older .bak as is.
			DirAccess.remove_absolute(_abs(path))
	var err: Error = DirAccess.rename_absolute(_abs(tmp), _abs(path))
	if err != OK:
		push_warning("SaveService: cannot move %s into place (%s)" % [tmp, error_string(err)])
		return false
	return true


## Loads `path` into GameState. An unreadable save is copied aside and the `.bak` is tried.
func load_from(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var data: Variant = _read(path)
	if data != null:
		GameState.apply_save_data(data)
		return true
	var kept: String = _keep_broken(path)
	push_warning("SaveService: %s is unreadable; copied to %s" % [path, kept])
	var bak: String = backup_path(path)
	if FileAccess.file_exists(bak):
		data = _read(bak)
		if data != null:
			push_warning("SaveService: loaded the backup %s" % bak)
			GameState.apply_save_data(data)
			return true
	return false


## The parsed save (a Dictionary) or null when the file is missing, empty or not valid JSON.
static func _read(path: String) -> Variant:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	# JSON.parse() returns the error instead of printing it (a broken save is handled, not a bug).
	var json := JSON.new()
	if json.parse(f.get_as_text()) != OK or not (json.data is Dictionary):
		return null
	return json.data


## Copies an unreadable save next to it as <name>.broken-<unix time>.json; returns that path.
static func _keep_broken(path: String) -> String:
	var dest: String = "%s.broken-%d.json" % [path.get_basename(), int(Time.get_unix_time_from_system())]
	DirAccess.copy_absolute(_abs(path), _abs(dest))
	return dest


static func _abs(path: String) -> String:
	return ProjectSettings.globalize_path(path)
