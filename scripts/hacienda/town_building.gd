extends TextureRect

## One building of the town view (P4-17): its painted picture (a cut-out PNG), clickable
## only on its painted pixels. Hovering lights it up with a warm outline and shows its
## name plate; a building closed by the town event is drawn grey and says so.

signal chosen(id: String)

const PLATE_GAP := 6.0  # structural: pixels between the roof and the name plate
const HIT_ALPHA := 0.35  # structural: a pixel at least this opaque counts as the building

const OUTLINE_SHADER := """
shader_type canvas_item;
uniform vec4 glow : source_color = vec4(1.0, 0.78, 0.38, 1.0);
uniform float width = 3.0;
uniform float hover = 0.0;
uniform float grey = 0.0;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = 0.0;
	for (int i = 0; i < 16; i++) {
		float ang = 6.2831853 * float(i) / 16.0;
		a = max(a, texture(TEXTURE, UV + vec2(cos(ang), sin(ang)) * TEXTURE_PIXEL_SIZE * width).a);
	}
	vec3 col = c.rgb * (1.0 + 0.3 * hover);
	float lum = dot(col, vec3(0.3, 0.59, 0.11));
	col = mix(col, vec3(lum) * 0.7, grey);
	float edge = clamp(a - c.a, 0.0, 1.0) * hover;
	COLOR = vec4(mix(col, glow.rgb, edge), max(c.a, edge * glow.a));
}
"""

static var _shader: Shader = null

var id: String = ""
var title: String = ""
var blurb: String = ""
## A short note on the plate ("Cerrada esta semana", "No compra"), "" for none.
var note: String = ""
var closed: bool = false
var _mask: Image = null
var _plate: PanelContainer = null
var _plate_label: Label = null
var _hover: bool = false


func setup(data: Dictionary, tex: Texture2D) -> void:
	id = str(data.get("id", ""))
	title = str(data.get("name", id))
	blurb = str(data.get("text", ""))
	texture = tex
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if tex != null:
		_mask = tex.get_image()
		if _mask != null and _mask.is_compressed():
			_mask.decompress()
	if _shader == null:
		_shader = Shader.new()
		_shader.code = OUTLINE_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	material = mat
	mouse_entered.connect(func(): _set_hover(true))
	mouse_exited.connect(func(): _set_hover(false))
	_build_plate()


func set_closed(on: bool, p_note: String = "") -> void:
	closed = on
	note = p_note
	(material as ShaderMaterial).set_shader_parameter("grey", 0.75 if on else 0.0)
	_update_plate()


## Only the painted pixels are the building: the corners of the picture let clicks through
## to whatever stands behind.
func _has_point(point: Vector2) -> bool:
	if _mask == null or size.x <= 0.0 or size.y <= 0.0:
		return Rect2(Vector2.ZERO, size).has_point(point)
	if not Rect2(Vector2.ZERO, size).has_point(point):
		return false
	var px := Vector2i(int(point.x / size.x * _mask.get_width()), int(point.y / size.y * _mask.get_height()))
	px = px.clamp(Vector2i.ZERO, Vector2i(_mask.get_width() - 1, _mask.get_height() - 1))
	return _mask.get_pixelv(px).a >= HIT_ALPHA


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		chosen.emit(id)


func _set_hover(on: bool) -> void:
	_hover = on
	(material as ShaderMaterial).set_shader_parameter("hover", 1.0 if on else 0.0)
	_update_plate()


func is_hovered() -> bool:
	return _hover


## The name plate floats over the roof, outside the picture, so it lives on the parent.
func _build_plate() -> void:
	_plate = PanelContainer.new()
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.07, 0.05, 0.04, 0.92)
	box.border_color = Color(0.78, 0.6, 0.32)
	box.set_border_width_all(1)
	box.set_corner_radius_all(3)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 3
	box.content_margin_bottom = 4
	_plate.add_theme_stylebox_override("panel", box)
	_plate_label = Label.new()
	_plate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_plate_label.add_theme_font_size_override("font_size", 15)
	_plate_label.add_theme_color_override("font_color", Color(0.98, 0.86, 0.58))
	_plate.add_child(_plate_label)
	_plate.visible = false
	_plate.z_index = 10
	ready.connect(func(): get_parent().add_child.call_deferred(_plate))
	resized.connect(_place_plate)
	item_rect_changed.connect(_place_plate)


func _update_plate() -> void:
	if _plate == null:
		return
	_plate_label.text = title if note == "" else "%s\n%s" % [title, note]
	_plate.visible = _hover
	_plate.reset_size()
	_place_plate()


func _place_plate() -> void:
	if _plate == null:
		return
	var w: float = _plate.get_combined_minimum_size().x
	var h: float = _plate.get_combined_minimum_size().y
	_plate.position = Vector2(position.x + (size.x - w) / 2.0, maxf(position.y - h - PLATE_GAP, 2.0))


func _exit_tree() -> void:
	if is_instance_valid(_plate):
		_plate.queue_free()
