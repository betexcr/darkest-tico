extends VBoxContainer

## One fighter on the battle stage: sprite + HP bar (+ stress bar for heroes) + name.
## Sprites: res://assets/sprites/<id>/<state>.png for STATES; missing states fall back
## to idle, and a missing idle falls back to the portrait/enemy art passed to setup().
## "Animations" are pose swaps plus tweens (lunge, glow, shake, collapse, breathing).
## Feedback: floating numbers on hits/heals/stress/misses, and status icons above the
## fighter (res://assets/status/<id>.png; a coloured badge if the icon is missing).

signal clicked(unit)
## Equipment dropped on this hero from the inventory (message "" = ok).
signal equipment_dropped(message: String)

const STATES := ["idle", "attack", "cast", "hurt", "ailment", "dead"]
const SPRITE_SIZE := Vector2(140, 210)
const AFFLICTION_NAMES := {"paranoia": "Paranoia", "cobardia": "Cobardía", "ira_ciega": "Ira ciega"}
const VIRTUE_NAMES := {"serenidad": "Serenidad", "firmeza": "Firmeza"}

const StatusEffectsScript := preload("res://scripts/domain/status_effects.gd")
## Status icons come from data/statuses.json (name, description, colour, letter); art in
## res://assets/status/<id>.png, or a coloured letter badge until it exists.
## Some effects share art: id -> icon file id.
const ICON_ALIAS := {"cuidando": "guardia"}
const ICON_SIZE := Vector2(24, 24)
const COLOR_DAMAGE := Color(1.0, 0.3, 0.25)
const COLOR_CRIT := Color(1.0, 0.85, 0.2)
const COLOR_HEAL := Color(0.45, 1.0, 0.5)
const COLOR_STRESS := Color(0.8, 0.6, 1.0)
const COLOR_MISS := Color(0.85, 0.85, 0.85)

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
var _status_row: HBoxContainer
var _status_tex: Dictionary = {}
var _idle_tween: Tween
var _dir: float = 1.0


## Call before adding the unit to the tree.
func setup(unit_data: Dictionary, hero: bool, fallback_path: String) -> void:
	data = unit_data
	is_hero = hero
	# Party on the right facing left, enemies on the left facing right: lunges go toward the middle.
	_dir = -1.0 if hero else 1.0
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

	_status_row = HBoxContainer.new()
	_status_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_status_row.custom_minimum_size = Vector2(0, ICON_SIZE.y)
	_status_row.add_theme_constant_override("separation", 3)
	add_child(_status_row)
	for id in StatusEffectsScript.defs():
		var path := "res://assets/status/%s.png" % str(ICON_ALIAS.get(id, id))
		if ResourceLoader.exists(path):
			_status_tex[id] = load(path)

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
	# Sprites are generated facing LEFT (hero attack poses: weapon in the right arm toward the
	# enemy); enemies are mirrored so they face the party on the right.
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
	if not hero:
		# Details live in the enemy info panel (click); full data needs the Lentes del abuelo.
		tooltip_text = "%s — clic para ver" % data.get("name", "?")


func _can_drop_data(_at_position: Vector2, d: Variant) -> bool:
	return is_hero and d is Dictionary and str(d.get("kind", "")) == "item" \
		and GameState.is_equipment(str(d.get("id", ""))) and not GameState.equip_locked and not is_dead()


func _drop_data(_at_position: Vector2, d: Variant) -> void:
	equipment_dropped.emit(GameState.equip(data, str(d.get("id", ""))))
	refresh()


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
	_refresh_status_icons()


## Icons for every active status effect (with turns left / stacks) and Guard.
func _refresh_status_icons() -> void:
	for c in _status_row.get_children():
		c.queue_free()
	if is_dead():
		return
	for e in StatusEffectsScript.entries(data):
		_status_row.add_child(_make_status_icon(str(e["id"]), int(e["turns"]), int(e["value"]), int(e["stacks"])))


func _make_status_icon(id: String, turns: int, value: int, stacks: int = 1) -> Control:
	var d: Dictionary = StatusEffectsScript.def(id)
	var box := Control.new()
	box.custom_minimum_size = ICON_SIZE
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	var tip: String = str(d.get("name", id))
	match id:
		"sangrado", "veneno":
			tip += " (%d PV por turno)" % value
		"sobado":
			tip += " (+%d PV por turno)" % value
		"susto":
			tip += " (+%d estrés por turno)" % value
		"santiguado":
			tip += " (%d golpe%s)" % [value, "" if value == 1 else "s"]
	if stacks > 1:
		tip += " ×%d" % stacks
	if turns > 0 and turns < 90:
		tip += " — %d turno%s" % [turns, "" if turns == 1 else "s"]
	tip += "\n" + str(d.get("description", ""))
	box.tooltip_text = tip
	if _status_tex.has(id):
		var tr := TextureRect.new()
		tr.texture = _status_tex[id]
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.size = ICON_SIZE
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(tr)
	else:
		var badge := ColorRect.new()
		badge.color = Color.html(str(d.get("color", "#777777")))
		badge.size = ICON_SIZE
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(badge)
		var l := Label.new()
		l.text = str(d.get("letter", id.substr(0, 1).to_upper()))
		l.size = ICON_SIZE
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 14)
		l.add_theme_color_override("font_outline_color", Color.BLACK)
		l.add_theme_constant_override("outline_size", 4)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(l)
	var corner: String = ""
	if id == "santiguado":
		corner = str(value)
	elif stacks > 1:
		corner = "×%d" % stacks
	elif turns > 0 and turns < 90:
		corner = str(turns)
	if corner != "":
		var n := Label.new()
		n.text = corner
		n.position = Vector2(ICON_SIZE.x - 10, ICON_SIZE.y - 14)
		n.add_theme_font_size_override("font_size", 11)
		n.add_theme_color_override("font_outline_color", Color.BLACK)
		n.add_theme_constant_override("outline_size", 4)
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(n)
	return box


## Floating text over the sprite that rises and fades (does not block the caller).
func float_text(text: String, color: Color, big: bool = false) -> void:
	if _holder == null or not is_inside_tree():
		return
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 30 if big else 22)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.size = Vector2(SPRITE_SIZE.x, 36)
	# Stack popups that arrive together so they don't overlap.
	var stacked: int = 0
	for c in _holder.get_children():
		if c.has_meta("popup"):
			stacked += 1
	l.set_meta("popup", true)
	l.position = Vector2(0, SPRITE_SIZE.y * 0.25 - stacked * 26)
	l.pivot_offset = l.size / 2.0
	l.scale = Vector2(1.4, 1.4) if big else Vector2.ONE
	_holder.add_child(l)
	var t := l.create_tween().set_parallel(true)
	t.tween_property(l, "position:y", l.position.y - 46.0, 1.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "scale", Vector2.ONE, 0.25)
	t.tween_property(l, "modulate:a", 0.0, 0.45).set_delay(0.75)
	t.chain().tween_callback(l.queue_free)


func _status_text() -> String:
	if is_dead():
		return "Caído"
	var parts: PackedStringArray = PackedStringArray()
	var aff: String = str(data.get("affliction_id", ""))
	if aff != "":
		parts.append(AFFLICTION_NAMES.get(aff, aff))
	var vir: String = str(data.get("virtud_id", ""))
	if vir != "":
		parts.append(VIRTUE_NAMES.get(vir, vir))
	# Ailments and Guard are shown as icons (_refresh_status_icons).
	return " · ".join(parts)


func _resting_state() -> String:
	if is_dead():
		return "dead"
	if bool(data.get("al_borde", false)) or str(data.get("affliction_id", "")) != "" or StatusEffectsScript.any(data):
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


## Highlight as a valid pick while the player chooses a target (green for allies,
## red for enemies).
func set_selectable(on: bool) -> void:
	_marker.visible = on
	_marker.color = Color(0.35, 0.85, 0.45, 0.95) if is_hero else Color(0.95, 0.25, 0.2, 0.95)
	_name_label.add_theme_color_override("font_color", Color(0.75, 1, 0.75) if (on and is_hero) else (Color(1, 0.7, 0.65) if on else Color(0.9, 0.9, 0.9)))


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


func play_hurt(amount: int = 0, crit: bool = false) -> void:
	_stop_idle()
	_show_state("hurt")
	if amount > 0:
		float_text(("¡-%d!" if crit else "-%d") % amount, COLOR_CRIT if crit else COLOR_DAMAGE, crit)
	# Impact: a white flash, then red, with a shake.
	_sprite.modulate = Color(2.2, 2.2, 2.2)
	var t := create_tween()
	t.tween_property(_sprite, "modulate", Color(1.7, 0.45, 0.45), 0.06)
	for i in 3:
		t.tween_property(_sprite, "position:x", 7.0, 0.04)
		t.tween_property(_sprite, "position:x", -7.0, 0.04)
	t.tween_property(_sprite, "position:x", 0.0, 0.04)
	t.tween_property(_sprite, "modulate", Color.WHITE, 0.25)
	await t.finished
	rest()


func play_heal(hp_gain: int = 0, stress_relief: int = 0) -> void:
	if hp_gain > 0:
		float_text("+%d" % hp_gain, COLOR_HEAL)
	if stress_relief > 0:
		float_text("-%d estrés" % stress_relief, COLOR_STRESS)
	var t := create_tween()
	t.tween_property(_sprite, "modulate", Color(0.7, 1.5, 0.8), 0.15)
	t.tween_property(_sprite, "modulate", Color.WHITE, 0.35)
	await t.finished
	refresh()


func play_death(amount: int = 0, crit: bool = false) -> void:
	_stop_idle()
	_show_state("hurt")
	if amount > 0:
		float_text(("¡-%d!" if crit else "-%d") % amount, COLOR_CRIT if crit else COLOR_DAMAGE, crit)
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
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(self)
