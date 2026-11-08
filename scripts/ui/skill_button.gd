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


func _make_custom_tooltip(_for_text: String) -> Object:
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.scroll_active = false
	rt.custom_minimum_size = Vector2(280, 0)
	rt.add_theme_font_size_override("normal_font_size", 13)
	rt.add_theme_font_size_override("bold_font_size", 14)
	rt.text = "[b][color=#f0d890]%s[/color][/b]\n%s" % [title, body]
	return rt
