extends Button

## Icon-only action button for the combat bar: a SkillIcon fills the button and hovering
## shows a tooltip with the action's name (bold) and what it does.

const SkillIconScript := preload("res://scripts/ui/skill_icon.gd")
const SIZE := Vector2(52, 52)

var title: String = ""
var body: String = ""


## `icon_id` is the skill id (or "_guard"/"_pass"); `kind` picks the background colour.
func setup(icon_id: String, kind: String, p_title: String, p_body: String) -> void:
	title = p_title
	body = p_body
	custom_minimum_size = SIZE
	focus_mode = Control.FOCUS_NONE
	# Godot only shows a tooltip when tooltip_text is set; the custom one replaces it.
	tooltip_text = "%s\n%s" % [p_title, p_body]
	var ic = SkillIconScript.new()
	ic.setup(icon_id, kind, p_title)
	ic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ic.offset_left = 3
	ic.offset_top = 3
	ic.offset_right = -3
	ic.offset_bottom = -3
	add_child(ic)
	# The popup's own frame (TooltipPanel) is see-through by default; make it transparent
	# with no margin so only the opaque box from _make_custom_tooltip shows.
	var th := Theme.new()
	var empty := StyleBoxEmpty.new()
	th.set_stylebox("panel", "TooltipPanel", empty)
	theme = th


## Opaque dark box with a warm border, so the text reads over the stage art.
static func _tooltip_box() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.055, 0.045, 1.0)
	sb.border_color = Color(0.6, 0.48, 0.3, 1.0)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(8)
	return sb


func _make_custom_tooltip(_for_text: String) -> Object:
	# The default tooltip panel is see-through: replace it with an opaque one.
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", _tooltip_box())
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.scroll_active = false
	rt.custom_minimum_size = Vector2(280, 0)
	rt.add_theme_font_size_override("normal_font_size", 13)
	rt.add_theme_font_size_override("bold_font_size", 14)
	rt.add_theme_color_override("default_color", Color(0.95, 0.93, 0.88))
	rt.text = "[b][color=#f0d890]%s[/color][/b]\n%s" % [title, body]
	box.add_child(rt)
	return box
