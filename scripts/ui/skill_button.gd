extends Button

## Icon-only action button for the combat bar: a SkillIcon fills the button and hovering
## shows a tooltip with the action's name (bold) and what it does.

const SkillIconScript := preload("res://scripts/ui/skill_icon.gd")
const TooltipCardScript := preload("res://scripts/ui/tooltip_card.gd")
const SIZE := Vector2(52, 52)
## How an effects line starts (see `_skill_tooltip` in expedition_screen.gd).
const EFFECT_PREFIXES := ["Ataque:", "Cura ", "Alivia ", "Objetivo:"]

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
	TooltipCardScript.clear_frame(self)


## `body` is "description\neffect · effect · effect" (or just one of the two): the
## description is plain text and each effect gets its own row.
func _make_custom_tooltip(_for_text: String) -> Object:
	var lines: Array = Array(body.split("\n", false))
	var bullets: Array = []
	var last: String = str(lines[-1]) if not lines.is_empty() else ""
	if lines.size() > 1 or last.contains(" · ") or EFFECT_PREFIXES.any(func(p): return last.begins_with(p)):
		bullets = Array(str(lines.pop_back()).split(" · ", false))
	return TooltipCardScript.text_card(title, lines, bullets)
