extends VBoxContainer

## One fighter on the battle stage: sprite + HP bar (+ stress bar for heroes) + name.
## Sprites: res://assets/sprites/<id>/<state>.png for STATES; missing states fall back
## to idle, and a missing idle falls back to the portrait/enemy art passed to setup().
## "Animations" are pose swaps plus tweens (lunge, glow, shake, collapse, breathing).

signal clicked(unit)

const STATES := ["idle", "attack", "cast", "hurt", "ailment", "dead"]
const SPRITE_SIZE := Vector2(140, 210)
const AFFLICTION_NAMES := {"paranoia": "Paranoia", "cobardia": "Cobardía", "ira_ciega": "Ira ciega"}
const VIRTUE_NAMES := {"serenidad": "Serenidad", "firmeza": "Firmeza"}

var data: Dictionary = {}
var is_hero: bool = true

var _tex: Dictionary = {}
var _holder: Control
var _sprite: TextureRect
var _marker: ColorRect
var _hp_bar: ProgressBar
var _stress_bar: ProgressBar
var _name_label: Label
var _status_label: Label
var _idle_tween: Tween
var _dir: float = 1.0


## Call before adding the unit to the tree.
func setup(unit_data: Dictionary, hero: bool, fallback_path: String) -> void:
	data = unit_data
	is_hero = hero
	_dir = 1.0 if hero else -1.0
	alignment = BoxContainer.ALIGNMENT_END
	custom_minimum_size = Vector2(SPRITE_SIZE.x, 0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_constant_override("separation", 3)

	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 13)
	_status_label.add_theme_color_override("font_color", Color(0.95, 0.75, 0.45))
	_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_status_label)

	_holder = Control.new()
	_holder.custom_minimum_size = SPRITE_SIZE
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_holder)

	_marker = ColorRect.new()
	_marker.color = Color(0.95, 0.8, 0.35, 0.9)
	_marker.position = Vector2(15, SPRITE_SIZE.y - 3)
	_marker.size = Vector2(SPRITE_SIZE.x - 30, 4)
	_marker.visible = false
	_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_holder.add_child(_marker)

	_sprite = TextureRect.new()
	_sprite.size = SPRITE_SIZE
	_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_sprite.pivot_offset = Vector2(SPRITE_SIZE.x / 2.0, SPRITE_SIZE.y)
	# Sprites are generated facing right; enemies face the party.
	_sprite.flip_h = not hero
	_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_holder.add_child(_sprite)

	_hp_bar = _make_bar(Color(0.72, 0.13, 0.13))
	add_child(_hp_bar)
	if hero:
		_stress_bar = _make_bar(Color(0.78, 0.74, 0.9))
		add_child(_stress_bar)

	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 13)
	_name_label.clip_text = true
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_name_label)

	_load_textures(fallback_path)


func _ready() -> void:
	refresh()
	rest()


func _make_bar(fill: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(SPRITE_SIZE.x - 20, 7)
	bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.06, 0.06, 0.9)
	var fg := StyleBoxFlat.new()
	fg.bg_color = fill
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fg)
	return bar


func _load_textures(fallback_path: String) -> void:
	var id: String = str(data.get("hero_id", "")) if is_hero else str(data.get("id", ""))
	for st in STATES:
		var p: String = "res://assets/sprites/%s/%s.png" % [id, st]
		if ResourceLoader.exists(p):
			_tex[st] = load(p) as Texture2D
	if not _tex.has("idle") and ResourceLoader.exists(fallback_path):
		_tex["idle"] = load(fallback_path) as Texture2D


func _show_state(state: String) -> void:
	_sprite.texture = _tex.get(state, _tex.get("idle", null))


func is_dead() -> bool:
	return bool(data.get("dead", false))


func refresh() -> void:
	_hp_bar.max_value = maxi(int(data.get("hp_max", 1)), 1)
	_hp_bar.value = int(data.get("hp", 0))
	if _stress_bar != null:
		_stress_bar.max_value = 200
		_stress_bar.value = int(data.get("stress", 0))
	_name_label.text = str(data.get("name", "?"))
	_status_label.text = _status_text()


func _status_text() -> String:
	if is_dead():
		return "Caído"
	var parts: PackedStringArray = PackedStringArray()
	if bool(data.get("al_borde", false)):
		parts.append("Al Borde")
	var aff: String = str(data.get("affliction_id", ""))
	if aff != "":
		parts.append(AFFLICTION_NAMES.get(aff, aff))
	var vir: String = str(data.get("virtud_id", ""))
	if vir != "":
		parts.append(VIRTUE_NAMES.get(vir, vir))
	if bool(data.get("stunned", false)):
		parts.append("Aturdido")
	return " · ".join(parts)


func _resting_state() -> String:
	if is_dead():
		return "dead"
	if bool(data.get("al_borde", false)) or str(data.get("affliction_id", "")) != "" or bool(data.get("stunned", false)):
		return "ailment"
	return "idle"


## Go back to the resting pose (idle, ailment or dead) and breathe if alive.
func rest() -> void:
	refresh()
	_sprite.position = Vector2.ZERO
	_sprite.modulate = Color.WHITE
	var st: String = _resting_state()
	if st == "dead":
		_apply_dead_look()
		return
	_sprite.rotation_degrees = 0.0
	_show_state(st)
	_start_idle()


func _start_idle() -> void:
	_stop_idle()
	_sprite.scale = Vector2.ONE
	var dur: float = randf_range(1.1, 1.5)
	_idle_tween = create_tween().set_loops()
	_idle_tween.tween_property(_sprite, "scale", Vector2(1.0, 1.025), dur).set_trans(Tween.TRANS_SINE)
	_idle_tween.tween_property(_sprite, "scale", Vector2.ONE, dur).set_trans(Tween.TRANS_SINE)


func _stop_idle() -> void:
	if _idle_tween != null and _idle_tween.is_valid():
		_idle_tween.kill()
	_idle_tween = null
	_sprite.scale = Vector2.ONE


func set_active(on: bool) -> void:
	_marker.visible = on
	_marker.color = Color(0.95, 0.8, 0.35, 0.9)
	_name_label.add_theme_color_override("font_color", Color(1, 0.9, 0.55) if on else Color(0.9, 0.9, 0.9))


func set_targeted(on: bool) -> void:
	_name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	if on:
		_marker.visible = true
		_marker.color = Color(0.85, 0.2, 0.2, 0.9)
	else:
		_marker.visible = false


## Attack (lunge toward the other side) or cast (glow). Returns after the motion.
func play_action(state: String) -> void:
	_stop_idle()
	_show_state(state)
	var t := create_tween()
	if state == "attack":
		t.tween_property(_sprite, "position:x", 45.0 * _dir, 0.12).set_trans(Tween.TRANS_QUAD)
		t.tween_interval(0.35)
		t.tween_property(_sprite, "position:x", 0.0, 0.2)
	else:
		t.tween_property(_sprite, "modulate", Color(1.5, 1.35, 1.0), 0.15)
		t.tween_interval(0.45)
		t.tween_property(_sprite, "modulate", Color.WHITE, 0.2)
	await t.finished
	rest()


func play_hurt() -> void:
	_stop_idle()
	_show_state("hurt")
	_sprite.modulate = Color(1.7, 0.45, 0.45)
	var t := create_tween()
	for i in 3:
		t.tween_property(_sprite, "position:x", 7.0, 0.04)
		t.tween_property(_sprite, "position:x", -7.0, 0.04)
	t.tween_property(_sprite, "position:x", 0.0, 0.04)
	t.tween_property(_sprite, "modulate", Color.WHITE, 0.25)
	await t.finished
	rest()


func play_heal() -> void:
	var t := create_tween()
	t.tween_property(_sprite, "modulate", Color(0.7, 1.5, 0.8), 0.15)
	t.tween_property(_sprite, "modulate", Color.WHITE, 0.35)
	await t.finished
	refresh()


func play_death() -> void:
	_stop_idle()
	_show_state("hurt")
	_sprite.modulate = Color(1.7, 0.45, 0.45)
	var t := create_tween()
	t.tween_property(_sprite, "modulate", Color.WHITE, 0.2)
	await t.finished
	_apply_dead_look()
	var t2 := create_tween()
	_sprite.modulate = Color(1, 1, 1, 0.0)
	t2.tween_property(_sprite, "modulate", Color(0.6, 0.55, 0.55, 0.9), 0.5)
	await t2.finished
	refresh()


func _apply_dead_look() -> void:
	_stop_idle()
	_show_state("dead")
	if not _tex.has("dead"):
		# No corpse sprite yet: tip the idle pose over.
		_sprite.rotation_degrees = -80.0 * _dir
	_sprite.modulate = Color(0.6, 0.55, 0.55, 0.9)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(self)
