extends RefCounted

## The item card shown when hovering an item anywhere (Pulpería, alforja, equipment slots,
## combat alforja): icon, name, category, description, one line per effect, where it is
## used and its prices. Fully opaque so it reads over any background.
##
## A control uses it by calling `clear_frame(self)` once and returning `build(...)` from
## `_make_custom_tooltip`. Its `tooltip_text` must still be non-empty or Godot shows nothing.

const TooltipCardScript := preload("res://scripts/ui/tooltip_card.gd")
const INNER: float = TooltipCardScript.INNER
const BORDER: Color = TooltipCardScript.BORDER
const GOLD: Color = TooltipCardScript.GOLD
const TEXT: Color = TooltipCardScript.TEXT
const MUTED: Color = TooltipCardScript.MUTED
const GOOD: Color = TooltipCardScript.GOOD
const BAD: Color = TooltipCardScript.BAD
## Category chip colours, by slot ("" = consumable).
const KIND_COLORS := {
	"weapon": Color(0.74, 0.3, 0.24),
	"armor": Color(0.27, 0.45, 0.66),
	"accessory": Color(0.52, 0.36, 0.66),
	"": Color(0.3, 0.52, 0.3),
}


static func clear_frame(control: Control) -> void:
	TooltipCardScript.clear_frame(control)


## `note` is an extra hint at the bottom ("Clic para comprar"); `warning` is shown in red
## (why it can't be bought); `qty` > 1 adds "×N" next to the name.
static func build(item_id: String, note: String = "", warning: String = "", qty: int = 0) -> Control:
	var p: Dictionary = GameState.item_tooltip_parts(item_id)
	var made: Array = TooltipCardScript.new_card()
	var card: PanelContainer = made[0]
	var col: VBoxContainer = made[1]
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
	titles.add_child(TooltipCardScript.title_label(name_text, 17, INNER - 68.0 if ResourceLoader.exists(icon_path) else INNER))
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
		col.add_child(TooltipCardScript.bullet_list(stats))

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
		col.add_child(_label(note, 12, TooltipCardScript.HINT))
	return card


static func _label(text: String, size: int, color: Color, wrap: bool = true, width: float = INNER) -> Label:
	return TooltipCardScript.label(text, size, color, wrap, width)


static func _rule() -> Control:
	return TooltipCardScript.rule()


static func _flat(bg: Color, border: Color, width: int, radius: int, margin: int) -> StyleBoxFlat:
	return TooltipCardScript.flat(bg, border, width, radius, margin)
