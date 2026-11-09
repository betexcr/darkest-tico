extends RefCounted

## The item card shown when hovering an item anywhere (Pulpería, alforja, equipment slots,
## combat alforja): icon, name, category, description, one line per effect, where it is
## used and its prices. Fully opaque so it reads over any background.
##
## A control uses it by calling `clear_frame(self)` once and returning `build(...)` from
## `_make_custom_tooltip`. Its `tooltip_text` must still be non-empty or Godot shows nothing.

const WIDTH := 300.0
## Width inside the card's border and padding. Wrapped labels get an explicit width:
## Godot sizes the tooltip popup before layout, when an autowrap label still reports the
## height of its narrowest form, which left a tall empty card.
const INNER := WIDTH - 24.0
const BG := Color(0.075, 0.058, 0.048, 1.0)
const BORDER := Color(0.72, 0.56, 0.3, 1.0)
const GOLD := Color(0.96, 0.84, 0.56)
const TEXT := Color(0.93, 0.9, 0.84)
const MUTED := Color(0.66, 0.61, 0.54)
const GOOD := Color(0.62, 0.86, 0.52)
const BAD := Color(0.93, 0.47, 0.4)
## Category chip colours, by slot ("" = consumable).
const KIND_COLORS := {
	"weapon": Color(0.74, 0.3, 0.24),
	"armor": Color(0.27, 0.45, 0.66),
	"accessory": Color(0.52, 0.36, 0.66),
	"": Color(0.3, 0.52, 0.3),
}


## Godot draws its own see-through frame (TooltipPanel) around a custom tooltip; blank it
## for `control` so only the opaque card shows.
static func clear_frame(control: Control) -> void:
	var th := Theme.new()
	th.set_stylebox("panel", "TooltipPanel", StyleBoxEmpty.new())
	control.theme = th


## `note` is an extra hint at the bottom ("Clic para comprar"); `warning` is shown in red
## (why it can't be bought); `qty` > 1 adds "×N" next to the name.
static func build(item_id: String, note: String = "", warning: String = "", qty: int = 0) -> Control:
	var p: Dictionary = GameState.item_tooltip_parts(item_id)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _card_box())
	card.custom_minimum_size = Vector2(WIDTH, 0)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	card.add_child(col)
	if p.is_empty():
		col.add_child(_label(item_id, 14, TEXT))
		return card

	# Header: framed icon, name, category chip.
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	col.add_child(head)
	var icon_path: String = "res://assets/items/%s.png" % item_id
	if ResourceLoader.exists(icon_path):
		var frame := PanelContainer.new()
		frame.add_theme_stylebox_override("panel", _flat(Color(0.14, 0.11, 0.09), BORDER.darkened(0.3), 1, 4, 3))
		frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var tex := TextureRect.new()
		tex.texture = load(icon_path) as Texture2D
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.custom_minimum_size = Vector2(52, 52)
		frame.add_child(tex)
		head.add_child(frame)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	titles.add_theme_constant_override("separation", 4)
	head.add_child(titles)
	var name_text: String = str(p["name"]) + (" ×%d" % qty if qty > 1 else "")
	var name_label := _label(name_text, 17, GOLD, true, INNER - 68.0 if ResourceLoader.exists(icon_path) else INNER)
	var bold := FontVariation.new()
	bold.variation_embolden = 0.7
	name_label.add_theme_font_override("font", bold)
	titles.add_child(name_label)
	var chip := PanelContainer.new()
	chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var chip_color: Color = KIND_COLORS.get(str(p["slot"]), KIND_COLORS[""])
	var chip_box := _flat(chip_color.darkened(0.45), chip_color, 1, 8, 0)
	chip_box.content_margin_left = 8
	chip_box.content_margin_right = 8
	chip_box.content_margin_top = 1
	chip_box.content_margin_bottom = 1
	chip.add_theme_stylebox_override("panel", chip_box)
	chip.add_child(_label(str(p["kind"]).to_upper(), 10, chip_color.lightened(0.6), false))
	titles.add_child(chip)

	if str(p["description"]) != "":
		col.add_child(_label(str(p["description"]), 13, MUTED))

	# Effects: one per line.
	var stats: Array = p["stats"]
	if not stats.is_empty():
		col.add_child(_rule())
		var list := VBoxContainer.new()
		list.add_theme_constant_override("separation", 2)
		col.add_child(list)
		for s in stats:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 6)
			var negative: bool = str(s).contains(" -")
			row.add_child(_label("◆", 9, BAD if negative else GOOD, false))
			var l := _label(str(s), 14, BAD if negative else TEXT, true, INNER - 20.0)
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(l)
			list.add_child(row)

	if str(p["where"]) != "":
		col.add_child(_label(str(p["where"]), 12, MUTED))

	# Prices.
	col.add_child(_rule())
	var prices := HBoxContainer.new()
	col.add_child(prices)
	var now: int = int(p["now"])
	var base: int = int(p["price"])
	var buy_text: String = "Compra %d ₡" % base
	var buy_color: Color = GOLD
	if now != base:
		buy_text = "Compra %s (antes %d)" % ["gratis" if now == 0 else "%d ₡" % now, base]
		buy_color = GOOD if now < base else BAD
	var buy := _label(buy_text, 13, buy_color, false)
	buy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prices.add_child(buy)
	prices.add_child(_label("Venta %d ₡" % int(p["sell"]), 13, MUTED, false))

	if warning != "":
		col.add_child(_label(warning, 12, BAD))
	if note != "":
		col.add_child(_label(note, 12, Color(0.75, 0.8, 0.9)))
	return card


static func _label(text: String, size: int, color: Color, wrap: bool = true, width: float = INNER) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(width, 0)
	return l


static func _rule() -> Control:
	var r := ColorRect.new()
	r.color = Color(BORDER, 0.35)
	r.custom_minimum_size = Vector2(0, 1)
	return r


static func _flat(bg: Color, border: Color, width: int, radius: int, margin: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	return sb


static func _card_box() -> StyleBoxFlat:
	var sb := _flat(BG, BORDER, 2, 6, 12)
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = 6
	return sb
