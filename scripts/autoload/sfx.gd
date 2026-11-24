extends Node

## Sound effects and UI sounds (P4-04a, owner 2026-11-24; music and voices come later).
##   Sfx.play("hit")              # one of the id's files, random pitch, on its bus
## Sounds are data (data/sfx.json: id -> files, bus, volume_db, pitch_jitter), from CC0 packs
## (tools/import_sfx.py, assets/audio/CREDITS.md). An unknown id or missing file is silent.
## Buses: Master > SFX, UI, Music, Voice (Music/Voice wait for P4-04b/c). Every button in the
## game clicks (ui_click) and ticks on hover (ui_hover) unless it has meta "no_ui_sfx".
## The "Efectos" volume and mute (scripts/ui/volume_button.gd) drive SFX and UI together and
## are kept in user://settings.cfg, not in the save. A `-s` script run never reads or writes it.

const DATA_PATH := "res://data/sfx.json"
const SETTINGS_PATH := "user://settings.cfg"
const BUSES := ["SFX", "UI", "Music", "Voice"]
## Players in the pool: as many sounds as can overlap.
const POOL := 10
## The same id again within this many ms is skipped (six enemies hit at once stay one hit).
const COOLDOWN_MS := 45
## Below this slider value the buses are silent.
const MIN_LINEAR := 0.001

## Emitted for every sound actually started (tests listen to it).
signal played(id: String)

var _sounds: Dictionary = {}
var _streams: Dictionary = {}
var _players: Array = []
var _next: int = 0
var _last_ms: Dictionary = {}
var _settings_on: bool = true
## "Efectos" volume, 0–1, and mute.
var volume: float = 0.8
var muted: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_buses()
	_load_data()
	for i in POOL:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_settings_on = not _is_script_run()
	load_settings()
	get_tree().node_added.connect(_on_node_added)


static func _is_script_run() -> bool:
	var args: PackedStringArray = OS.get_cmdline_args()
	if args.has("-s") or args.has("--script"):
		return true
	var loop: MainLoop = Engine.get_main_loop()
	return loop != null and loop.get_script() != null


func _ensure_buses() -> void:
	for b in BUSES:
		if AudioServer.get_bus_index(b) < 0:
			AudioServer.add_bus()
			var i: int = AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b)
			AudioServer.set_bus_send(i, "Master")


func _load_data() -> void:
	var f := FileAccess.open(DATA_PATH, FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	if d is Dictionary and d.get("sounds", null) is Dictionary:
		_sounds = d["sounds"]


func has_sound(id: String) -> bool:
	return _sounds.has(id)


func ids() -> Array:
	return _sounds.keys()


func _stream(path: String) -> AudioStream:
	if not _streams.has(path):
		var st: AudioStream = null
		if ResourceLoader.exists(path):
			st = load(path)
		elif FileAccess.file_exists(path) and path.ends_with(".ogg"):
			# *.import is git-ignored: a fresh checkout has the file before Godot imports it.
			st = AudioStreamOggVorbis.load_from_file(path)
		_streams[path] = st
	return _streams[path]


## Plays one of `id`'s files. opts: "volume_db" (added), "pitch" (multiplies). Returns
## whether a sound started.
func play(id: String, opts: Dictionary = {}) -> bool:
	var s = _sounds.get(id, null)
	if not s is Dictionary or (s["files"] as Array).is_empty():
		return false
	var now: int = Time.get_ticks_msec()
	if now - int(_last_ms.get(id, -100000)) < COOLDOWN_MS:
		return false
	var files: Array = s["files"]
	var stream: AudioStream = _stream(str(files[randi() % files.size()]))
	if stream == null:
		return false
	_last_ms[id] = now
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = stream
	p.bus = str(s.get("bus", "SFX"))
	p.volume_db = float(s.get("volume_db", 0.0)) + float(opts.get("volume_db", 0.0))
	var j: float = float(s.get("pitch_jitter", 0.0))
	p.pitch_scale = maxf(0.1, (1.0 + randf_range(-j, j)) * float(opts.get("pitch", 1.0)))
	p.play()
	played.emit(id)
	return true


# --- Volume ------------------------------------------------------------------------------

func set_volume(v: float, mute: bool) -> void:
	volume = clampf(v, 0.0, 1.0)
	muted = mute
	_apply()
	save_settings()


func _apply() -> void:
	for b in ["SFX", "UI"]:
		var i: int = AudioServer.get_bus_index(b)
		if i < 0:
			continue
		var silent: bool = muted or volume < MIN_LINEAR
		AudioServer.set_bus_mute(i, silent)
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(volume, MIN_LINEAR)))


func load_settings() -> void:
	if _settings_on:
		var c := ConfigFile.new()
		if c.load(SETTINGS_PATH) == OK:
			volume = clampf(float(c.get_value("audio", "sfx_volume", volume)), 0.0, 1.0)
			muted = bool(c.get_value("audio", "sfx_muted", muted))
	_apply()


func save_settings() -> void:
	if not _settings_on:
		return
	var c := ConfigFile.new()
	c.load(SETTINGS_PATH)
	c.set_value("audio", "sfx_volume", volume)
	c.set_value("audio", "sfx_muted", muted)
	c.save(SETTINGS_PATH)


# --- Every button clicks -----------------------------------------------------------------

func _on_node_added(node: Node) -> void:
	var b := node as BaseButton
	if b == null or b.has_meta("sfx_hooked"):
		return
	b.set_meta("sfx_hooked", true)
	b.pressed.connect(_on_button_pressed.bind(b))
	b.mouse_entered.connect(_on_button_hover.bind(b))
	b.gui_input.connect(_on_button_input.bind(b))


func _on_button_pressed(b: BaseButton) -> void:
	if b.has_meta("no_ui_sfx"):
		return
	if b is CheckBox or b is CheckButton:
		play("ui_toggle")
	else:
		play("ui_click")


func _on_button_hover(b: BaseButton) -> void:
	if not b.disabled and not b.has_meta("no_ui_sfx"):
		play("ui_hover")


## A click on a disabled button: "no" (it can't be done now; its tooltip says why).
func _on_button_input(ev: InputEvent, b: BaseButton) -> void:
	var mb := ev as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and b.disabled and not b.has_meta("no_ui_sfx"):
		play("ui_denied")
