extends Control

## Victory screen after a completed expedition (reads GameState.last_expedition_summary).
## Page 1: the encargo reward, colones and items picked up, what the party went through.
## Page 2: one card per hero: Resolve XP gained, level badge + XP bar, level-ups, new
## Quebranto/Virtud, the fallen. Built in code; main.gd shows it before the hub.

signal continue_pressed

const ResolveSystemScript := preload("res://scripts/domain/resolve_system.gd")
const StressSystemScript := preload("res://scripts/domain/stress_system.gd")

const GOLD := Color(0.95, 0.82, 0.55)
const DIM := Color(0.62, 0.58, 0.52)
const RED := Color(0.92, 0.42, 0.38)
const BLUE := Color(0.55, 0.78, 1.0)
const GREEN := Color(0.55, 0.85, 0.5)
const BG_PATH := "res://assets/ui_bg/expedition_bg.png"

var summary: Dictionary = {}
var page: int = 0
var _body: VBoxContainer
var _next: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	summary = GameState.last_expedition_summary
	var bg := TextureRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if ResourceLoader.exists(BG_PATH):
		bg.texture = load(BG_PATH) as Texture2D
	add_child(bg)
	var dark := ColorRect.new()
	dark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dark.color = Color(0, 0, 0, 0.72)
	add_child(dark)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(720, 0)
	panel.add_theme_stylebox_override("panel", _box(Color(0.07, 0.05, 0.06, 0.96), Color(0.62, 0.48, 0.25), 2))
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	panel.add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	margin.add_child(col)
	col.add_child(_label("¡Victoria!", 32, GOLD, true))
	col.add_child(_label("%s — %s" % [summary.get("region_name", ""), summary.get("difficulty_name", "")], 15, DIM, true))
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 8)
	col.add_child(_body)
	_next = Button.new()
	_next.custom_minimum_size = Vector2(220, 40)
	_next.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_next.add_theme_font_size_override("font_size", 18)
	_next.pressed.connect(_on_next)
	col.add_child(_next)
	_show_page(0)


func _on_next() -> void:
	if page == 0:
		_show_page(1)
	else:
		continue_pressed.emit()


func _show_page(p: int) -> void:
	page = p
	for c in _body.get_children():
		c.queue_free()
	if p == 0:
		_build_rewards()
		_next.text = "Siguiente"
	else:
		_build_heroes()
		_next.text = "Volver a la hacienda"


# --- Page 1: rewards ---------------------------------------------------------------

func _build_rewards() -> void:
	var led: Dictionary = summary.get("ledger", {})
	var quest: int = int(led.get("objective_colones", 0))
	var loot: int = int(led.get("loot_colones", 0))
	_body.add_child(_banner("Recompensa del encargo"))
	_body.add_child(_money_row("Foco de corrupción purgado", quest))
	_body.add_child(_banner("Botín recogido"))
	_body.add_child(_money_row("Colones de peleas y curiosidades", loot))
	var items: Dictionary = led.get("items", {})
	if items.is_empty():
		_body.add_child(_label("Ningún artículo encontrado.", 14, DIM, true))
	else:
		var grid := HFlowContainer.new()
		grid.alignment = FlowContainer.ALIGNMENT_CENTER
		grid.add_theme_constant_override("h_separation", 6)
		for id in items:
			grid.add_child(_item_tile(str(id), int(items[id])))
		_body.add_child(grid)
	_body.add_child(_banner("La expedición"))
	var parts: PackedStringArray = PackedStringArray()
	parts.append("Peleas ganadas: %d" % int(led.get("fights", 0)))
	if int(led.get("elites", 0)) > 0:
		parts.append("élites: %d" % int(led["elites"]))
	if int(led.get("bosses", 0)) > 0:
		parts.append("jefes: %d" % int(led["bosses"]))
	parts.append("curiosidades: %d" % int(led.get("curios", 0)))
	parts.append("fogatas: %d" % int(led.get("camps", 0)))
	if int(led.get("ambushes", 0)) > 0:
		parts.append("emboscadas: %d" % int(led["ambushes"]))
	_body.add_child(_label(" · ".join(parts), 14, Color(0.85, 0.82, 0.76), true))
	var total := _label("Total: %d ₡" % (quest + loot), 22, GOLD, true)
	_body.add_child(total)


func _money_row(text: String, amount: int) -> Control:
	var row := HBoxContainer.new()
	var l := _label(text, 15, Color(0.88, 0.85, 0.8), false)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	row.add_child(_label("%d ₡" % amount, 20, GOLD, false))
	return row


func _item_tile(id: String, qty: int) -> Control:
	var tile := PanelContainer.new()
	tile.custom_minimum_size = Vector2(56, 56)
	tile.add_theme_stylebox_override("panel", _box(Color(0.12, 0.09, 0.08), Color(0.4, 0.32, 0.2), 1))
	tile.tooltip_text = "%s ×%d" % [GameState.get_item(id).get("name", id), qty]
	var stack := Control.new()
	tile.add_child(stack)
	var p: String = "res://assets/items/%s.png" % id
	if ResourceLoader.exists(p):
		var icon := TextureRect.new()
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = load(p) as Texture2D
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_child(icon)
	else:
		var name_l := _label(str(GameState.get_item(id).get("name", id)), 10, Color.WHITE, true)
		name_l.autowrap_mode = TextServer.AUTOWRAP_WORD
		name_l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		stack.add_child(name_l)
	if qty > 1:
		var q := _label(str(qty), 13, GOLD, false)
		q.position = Vector2(3, 0)
		stack.add_child(q)
	return tile


# --- Page 2: heroes --------------------------------------------------------------------

func _build_heroes() -> void:
	_body.add_child(_banner("La cuadrilla — +%d XP de resolución por sobreviviente" % int(summary.get("xp", 0))))
	for e in summary.get("heroes", []):
		_body.add_child(_hero_card(e))


func _hero_card(e: Dictionary) -> Control:
	var dead: bool = bool(e.get("dead", false))
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _box(Color(0.16, 0.06, 0.06, 0.9) if not dead else Color(0.1, 0.1, 0.1, 0.9), Color(0.35, 0.24, 0.16), 1))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	# Portrait
	var pic := TextureRect.new()
	pic.custom_minimum_size = Vector2(64, 64)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var p: String = "res://assets/portraits/%s.png" % str(e.get("hero_id", ""))
	if ResourceLoader.exists(p):
		pic.texture = load(p) as Texture2D
	if dead:
		pic.modulate = Color(0.4, 0.4, 0.4)
	row.add_child(pic)
	# Name, XP, what happened
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 2)
	var head := HBoxContainer.new()
	var nm := _label("%s — %s" % [e.get("name", "?"), e.get("class_name", "")], 16, GOLD if not dead else DIM, false)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(nm)
	head.add_child(_label("Sin XP" if dead else "+%d XP de resolución" % int(e.get("xp_gained", 0)), 14, DIM if dead else GREEN, false))
	mid.add_child(head)
	var lines: Array = []
	if dead:
		lines.append(["Cayó en la expedición. Descanse en paz.", RED])
	else:
		if int(e.get("level_after", 0)) > int(e.get("level_before", 0)):
			lines.append(["¡Sube a Resolución %d: %s!" % [int(e["level_after"]), ResolveSystemScript.level_name(int(e["level_after"]))], GOLD])
		var aff: String = str(e.get("affliction_id", ""))
		var vir: String = str(e.get("virtud_id", ""))
		if aff != "":
			lines.append(["%sQuebranto: %s" % ["Nuevo " if bool(e.get("new_affliction", false)) else "", StressSystemScript.affliction_name(aff)], RED])
		if vir != "":
			lines.append(["%sVirtud: %s" % ["Nueva " if bool(e.get("new_virtud", false)) else "", StressSystemScript.virtud_name(vir)], BLUE])
		lines.append(["PV %d/%d · Estrés %d" % [int(e.get("hp", 0)), int(e.get("hp_max", 0)), int(e.get("stress", 0))], DIM])
	for l in lines:
		mid.add_child(_label(str(l[0]), 13, l[1], false))
	row.add_child(mid)
	# Level badge + XP bar
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(150, 0)
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	var lvl: int = int(e.get("level_after", 0))
	var badge := PanelContainer.new()
	badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	badge.custom_minimum_size = Vector2(40, 40)
	var bs := _box(Color(0.12, 0.28, 0.18), Color(0.55, 0.85, 0.5), 2)
	bs.set_corner_radius_all(20)
	badge.add_theme_stylebox_override("panel", bs)
	badge.add_child(_label(str(lvl), 20, Color.WHITE, true))
	right.add_child(badge)
	right.add_child(_label(ResolveSystemScript.level_name(lvl), 12, DIM, true))
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(140, 10)
	bar.show_percentage = false
	bar.add_theme_stylebox_override("fill", _box(Color(0.45, 0.78, 0.42), Color(0.45, 0.78, 0.42), 0))
	bar.add_theme_stylebox_override("background", _box(Color(0.12, 0.1, 0.1), Color(0.3, 0.26, 0.22), 1))
	var fake: Dictionary = {"resolve_level": lvl, "resolve_xp": int(e.get("resolve_xp", 0))}
	var pr: Dictionary = ResolveSystemScript.progress(fake)
	bar.max_value = maxi(int(pr["needed"]), 1)
	bar.value = int(pr["current"])
	right.add_child(bar)
	right.add_child(_label("máximo" if lvl >= ResolveSystemScript.MAX_LEVEL else "%d/%d XP" % [int(pr["current"]), int(pr["needed"])], 11, DIM, true))
	row.add_child(right)
	return card


# --- Helpers ---------------------------------------------------------------------------

func _label(text: String, size: int, color: Color, centered: bool) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if centered:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _banner(text: String) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _box(Color(0.14, 0.2, 0.26), Color(0.4, 0.5, 0.58), 1))
	p.add_child(_label(text, 15, Color(0.9, 0.9, 0.85), true))
	return p


func _box(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	return sb
