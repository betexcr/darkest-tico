extends Button

## Icon-only action button for the combat bar: a SkillIcon fills the button and hovering
## shows a tooltip with the action's name (bold) and what it does.

const SkillIconScript := preload("res://scripts/ui/skill_icon.gd")
const TooltipCardScript := preload("res://scripts/ui/tooltip_card.gd")
const SkillRanksScript := preload("res://scripts/domain/skill_ranks.gd")
const StatusEffectsScript := preload("res://scripts/domain/status_effects.gd")
const SIZE := Vector2(52, 52)
## How an effects line starts (see `body_for`).
const EFFECT_PREFIXES := ["Ataque:", "Cura ", "Alivia ", "Objetivo:"]

var title: String = ""
var body: String = ""


const PIP_ON := Color(0.95, 0.78, 0.35)
const PIP_OFF := Color(0.2, 0.17, 0.13, 0.9)
const PIP_EDGE := Color(0, 0, 0, 0.85)


## `icon_id` is the skill id (or "_guard"/"_pass"); `kind` picks the background colour.
## `rank` > 0 draws Casa Comunal rank pips (filled up to `rank`, out of `max_rank`) along the bottom.
func setup(icon_id: String, kind: String, p_title: String, p_body: String, rank: int = 0, max_rank: int = 5) -> void:
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
	if rank > 0:
		_add_pips(rank, max_rank)
	TooltipCardScript.clear_frame(self)


func _add_pips(rank: int, max_rank: int) -> void:
	var pips := Control.new()
	pips.name = "RankPips"
	pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pips.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	pips.offset_top = -9
	pips.offset_bottom = -2
	pips.draw.connect(func():
		var r: float = 2.6
		var gap: float = 7.0
		var x0: float = (pips.size.x - gap * float(max_rank - 1)) / 2.0
		for k in max_rank:
			var c := Vector2(x0 + gap * k, pips.size.y / 2.0)
			pips.draw_circle(c, r + 1.0, PIP_EDGE)
			pips.draw_circle(c, r, PIP_ON if k < rank else PIP_OFF)
	)
	add_child(pips)


## Tooltip body for a hero skill (already at the hero's rank, see GameState.hero_skill):
## "description\neffect · effect · …". Used by the combat bar and the Casa Comunal.
static func body_for(sk: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	if str(sk.get("kind", "")) == "attack":
		parts.append("Ataque: %d–%d de daño" % [int(sk.get("damage_min", 0)), int(sk.get("damage_max", 0))])
		if int(sk.get("skill_accuracy", 0)) > 0:
			parts.append("Precisión +%d" % int(sk["skill_accuracy"]))
		if int(sk.get("skill_crit", 0)) > 0:
			parts.append("Crítico +%d%%" % int(sk["skill_crit"]))
	if sk.has("heal_min"):
		parts.append("Cura %d–%d PV" % [int(sk.get("heal_min", 0)), int(sk.get("heal_max", 0))])
	var rel: int = int(sk.get("stress_relief", sk.get("self_stress_relief", 0)))
	if rel > 0:
		parts.append("Alivia %d de estrés" % rel)
	for key in ["applies", "self_applies"]:
		for ap in SkillRanksScript.as_list(sk.get(key, null)):
			var nm: String = StatusEffectsScript.display_name(str(ap.get("status", "")))
			var chance: float = float(ap.get("chance", 1.0))
			if chance < 1.0:
				parts.append("%s: %d%%" % [nm, int(round(chance * 100.0))])
			if ap.get("mods") is Dictionary:
				for m in ap["mods"]:
					if ap["mods"][m] is float or ap["mods"][m] is int:
						parts.append("%s: %+d %s" % [nm, int(ap["mods"][m]), SkillRanksScript.MOD_NAMES.get(str(m), str(m))])
	var who: String = {"self": "a sí mismo", "ally": "al aliado elegido", "party": "a toda la cuadrilla"}.get(str(sk.get("target", "")), "")
	if who != "":
		parts.append("Objetivo: " + who)
	var desc: String = str(sk.get("description", ""))
	return "%s\n%s" % [desc, " · ".join(parts)] if desc != "" else " · ".join(parts)


## `body` is "description\neffect · effect · effect" (or just one of the two): the
## description is plain text and each effect gets its own row.
func _make_custom_tooltip(_for_text: String) -> Object:
	var lines: Array = Array(body.split("\n", false))
	var bullets: Array = []
	var last: String = str(lines[-1]) if not lines.is_empty() else ""
	if lines.size() > 1 or last.contains(" · ") or EFFECT_PREFIXES.any(func(p): return last.begins_with(p)):
		bullets = Array(str(lines.pop_back()).split(" · ", false))
	return TooltipCardScript.text_card(title, lines, bullets)
