extends Button

## Speaker button (P4-04a): opens a small card with the "Efectos" volume slider (sound
## effects and UI sounds together) and a mute box, kept in user://settings.cfg by the Sfx
## autoload. Music and voices get their own sliders here later (P4-04b/c).

const CardScript := preload("res://scripts/ui/tooltip_card.gd")
const ICON := Color(0.95, 0.85, 0.62)

var _popup: PopupPanel = null
var slider: HSlider = null
var mute_box: CheckBox = null


func _init() -> void:
	custom_minimum_size = Vector2(38, 34)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tooltip_text = "Sonido\nVolumen de los efectos y los sonidos de los menús."
	pressed.connect(_open)


## A speaker (and its waves, or a cross when muted), drawn so no font glyph is needed.
func _draw() -> void:
	var c: Vector2 = size * 0.5
	var u: float = minf(size.x, size.y) / 34.0
	var body := PackedVector2Array([c + Vector2(-9, -4) * u, c + Vector2(-5, -4) * u, c + Vector2(1, -9) * u,
		c + Vector2(1, 9) * u, c + Vector2(-5, 4) * u, c + Vector2(-9, 4) * u])
	draw_colored_polygon(body, ICON)
	if Sfx.muted or Sfx.volume < Sfx.MIN_LINEAR:
		draw_line(c + Vector2(4, -4) * u, c + Vector2(11, 4) * u, ICON, 2.0 * u)
		draw_line(c + Vector2(4, 4) * u, c + Vector2(11, -4) * u, ICON, 2.0 * u)
		return
	var waves: int = 1 + int(Sfx.volume > 0.35) + int(Sfx.volume > 0.7)
	for k in waves:
		draw_arc(c + Vector2(1, 0) * u, (5.0 + 4.0 * k) * u, -0.9, 0.9, 12, ICON, 1.6 * u)


func _open() -> void:
	if _popup == null:
		_popup = PopupPanel.new()
		_popup.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		var parts: Array = CardScript.new_card(false)
		var col: VBoxContainer = parts[1]
		col.add_child(CardScript.title_label("Sonido", 18, 240.0))
		col.add_child(CardScript.section("Efectos"))
		slider = HSlider.new()
		slider.min_value = 0
		slider.max_value = 100
		slider.step = 1
		slider.custom_minimum_size = Vector2(220, 24)
		col.add_child(slider)
		mute_box = CheckBox.new()
		mute_box.text = "Silenciar"
		col.add_child(mute_box)
		col.add_child(CardScript.label("La música y las voces vienen después.", 12, CardScript.MUTED, true, 230.0))
		_popup.add_child(parts[0])
		add_child(_popup)
		slider.value_changed.connect(func(v: float):
			Sfx.set_volume(v / 100.0, mute_box.button_pressed)
			Sfx.play("ui_click")
			queue_redraw())
		mute_box.toggled.connect(func(on: bool):
			Sfx.set_volume(slider.value / 100.0, on)
			queue_redraw())
	slider.set_value_no_signal(roundf(Sfx.volume * 100.0))
	mute_box.set_pressed_no_signal(Sfx.muted)
	_popup.reset_size()
	var at: Vector2 = get_screen_position() + Vector2(size.x - _popup.size.x, size.y + 4)
	_popup.popup(Rect2i(Vector2i(at.round()), _popup.size))
