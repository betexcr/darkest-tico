extends RefCounted

## The hero card (P4-15): portrait, name, class, resolve and state chips, stats, skills and
## quirks, in the item-card style. Used for the roster, the Terminal's candidates and the
## Clínica / dismiss dialogs. `note` is a hint at the bottom, `warning` a red line.

const C := preload("res://scripts/ui/tooltip_card.gd")
const QuirksScript := preload("res://scripts/domain/quirks.gd")
const StressSystemScript := preload("res://scripts/domain/stress_system.gd")
const ResolveSystemScript := preload("res://scripts/domain/resolve_system.gd")
const SkillRanksScript := preload("res://scripts/domain/skill_ranks.gd")

const QUIRK_COLORS := {
	"positive": Color(0.45, 0.72, 0.4),
	"negative": Color(0.82, 0.38, 0.32),
	"disease": Color(0.78, 0.64, 0.3),
}
const QUIRK_TAGS := {"positive": "Bueno", "negative": "Malo", "disease": "Enfermedad"}


static func portrait_path(h: Dictionary) -> String:
	return "res://assets/portraits/%s.png" % str(h.get("hero_id", ""))


## Header row: framed portrait, gold name, class, then chips (resolve, Quebranto/Virtud, busy).
static func header(h: Dictionary, side: float = 56.0) -> Control:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.add_child(C.picture(portrait_path(h), side))
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	titles.add_theme_constant_override("separation", 3)
	titles.add_child(C.title_label(str(h.get("name", "?")), 17, 0.0))
	titles.add_child(C.label(str(h.get("class_name", "")), 13, C.MUTED, false))
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 4)
	chips.add_theme_constant_override("v_separation", 3)
	var lvl: int = int(h.get("resolve_level", 0))
	chips.add_child(C.chip("Res. %d · %s" % [lvl, ResolveSystemScript.level_name(lvl)], Color(0.72, 0.56, 0.3)))
	var aff: String = str(h.get("affliction_id", ""))
	if aff != "":
		chips.add_child(C.chip("Quebranto: %s" % StressSystemScript.affliction_name(aff), Color(0.82, 0.32, 0.28)))
	elif str(h.get("virtud_id", "")) != "":
		chips.add_child(C.chip("Virtud: %s" % StressSystemScript.virtud_name(str(h["virtud_id"])), Color(0.45, 0.72, 0.4)))
	titles.add_child(chips)
	head.add_child(titles)
	return head


## Quirk chips, coloured by kind ("FIJADO" marks a locked one).
static func quirk_chips(h: Dictionary) -> Control:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 4)
	flow.add_theme_constant_override("v_separation", 3)
	for e in QuirksScript.of(h):
		var q: Dictionary = QuirksScript.get_quirk(str(e["id"]))
		var name: String = str(q.get("name", "")) + (" · fijado" if bool(e.get("locked", false)) else "")
		var chip: Control = C.chip(name, QUIRK_COLORS.get(str(q.get("kind", "")), C.MUTED), 10)
		chip.tooltip_text = quirk_tooltip(str(e["id"]), bool(e.get("locked", false)))
		chip.mouse_filter = Control.MOUSE_FILTER_STOP
		flow.add_child(chip)
	return flow


## Tooltip for a quirk badge (owner 2026-11-19): name, kind, flavour, then what it does.
static func quirk_tooltip(id: String, locked: bool = false) -> String:
	var q: Dictionary = QuirksScript.get_quirk(id)
	var kind: String = {"positive": "Rasgo bueno", "negative": "Rasgo malo", "disease": "Enfermedad"}.get(str(q.get("kind", "")), "")
	var lines: PackedStringArray = PackedStringArray(["%s — %s" % [q.get("name", id), kind], str(q.get("desc", "")),
		"Efecto: " + QuirksScript.mods_text(id)])
	if locked:
		lines.append("Fijado: no se pierde con rasgos nuevos.")
	elif str(q.get("kind", "")) == "disease":
		lines.append("Se cura en la Clínica de Espantos.")
	return "\n".join(lines)


static func build(h: Dictionary, note: String = "", warning: String = "", extra_lines: Array = []) -> Control:
	var made: Array = C.new_card()
	var col: VBoxContainer = made[1]
	col.add_child(header(h))
	col.add_child(C.rule())
	var stats := PackedStringArray([
		"PV %d/%d" % [int(h.get("hp", 0)), int(h.get("hp_max", 0))],
		"Estrés %d" % int(h.get("stress", 0)),
		"Vel %d" % int(h.get("speed", 0)),
		"Prot %d%%" % int(h.get("prot", 0)),
	])
	col.add_child(C.label(" · ".join(stats), 13, C.TEXT, false))
	for l in extra_lines:
		col.add_child(C.label(str(l), 12, C.MUTED, true))
	var skills: PackedStringArray = PackedStringArray()
	for sid in h.get("skill_ids", []):
		skills.append("%s %d" % [GameState.get_skill(str(sid)).get("name", sid), SkillRanksScript.rank(h, str(sid))])
	if not skills.is_empty():
		col.add_child(C.section("Habilidades"))
		col.add_child(C.label(", ".join(skills), 12, C.TEXT, true))
	if not QuirksScript.of(h).is_empty():
		col.add_child(C.section("Rasgos"))
		col.add_child(quirk_chips(h))
	if warning != "":
		col.add_child(C.label(warning, 12, C.BAD, true))
	if note != "":
		col.add_child(C.label(note, 12, C.HINT, true))
	return made[0]
