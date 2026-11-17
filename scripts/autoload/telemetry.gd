extends Node

## Local telemetry (P5-01): one JSON object per line in user://telemetry.jsonl, for balance
## work (P5-02; summary: tools/telemetry_report.py). Nothing leaves the machine.
## Kinds: session, mission_end, stress_spike, week (GameState and the expedition screen log
## them). Like SaveService, it is off while a `-s` script runs unless a test or tool turns it
## on with its own path (tools/playtest_campaign.gd -- --telemetry <path>).

const TELEMETRY_PATH := "user://telemetry.jsonl"

var path: String = TELEMETRY_PATH
var enabled: bool = true
## The log moves to <path>.1 (replacing an older one) when it grows past this many bytes.
var max_bytes: int = 2000000


func _ready() -> void:
	enabled = not SaveService.is_script_run()
	log_event("session", {"save_version": GameState.SAVE_VERSION, "colones": GameState.colones,
		"roster": GameState.roster.size()})


## Appends one event. Every line gets "kind", "t" (unix time) and "week".
func log_event(kind: String, data: Dictionary = {}) -> void:
	if not enabled:
		return
	var line: Dictionary = data.duplicate(true)
	line["kind"] = kind
	line["t"] = int(Time.get_unix_time_from_system())
	line["week"] = GameState.week
	_rotate_if_big()
	var f: FileAccess = FileAccess.open(path, FileAccess.READ_WRITE) if FileAccess.file_exists(path) else FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("Telemetry: can't write %s" % path)
		return
	f.seek_end()
	f.store_line(JSON.stringify(line))
	f.close()


## Every event in the log at `p` (default: the current path), oldest first.
func read_all(p: String = "") -> Array:
	var src: String = p if p != "" else path
	var out: Array = []
	if not FileAccess.file_exists(src):
		return out
	for l in FileAccess.get_file_as_string(src).split("\n", false):
		var v = JSON.parse_string(l)
		if v is Dictionary:
			out.append(v)
	return out


func _rotate_if_big() -> void:
	if not FileAccess.file_exists(path):
		return
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var size: int = f.get_length()
	f.close()
	if size < max_bytes:
		return
	var old: String = path + ".1"
	if FileAccess.file_exists(old):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(old))
	DirAccess.rename_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(old))
