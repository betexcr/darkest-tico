extends RefCounted

## Shared look of every tooltip in the game: an opaque dark card with a warm border, a
## gold title, a thin rule and wrapped body text.
##
## - Plain `tooltip_text` tooltips are restyled automatically by the `TooltipStyler`
##   autoload, which calls `from_text`. Write them as "Title\nbody…" or "Title — body".
## - Controls that build their own tooltip (`_make_custom_tooltip`) call `clear_frame(self)`
##   once and return `text_card(...)` or `scripts/ui/item_tooltip.gd`'s card.
##
## No autoloads are used here, so any script may preload this file.

const WIDTH := 300.0
## Width inside the card's border and padding. Wrapped labels get an explicit width:
## Godot sizes the tooltip popup before layout, when an autowrap label still reports the
## height of its narrowest form, which would leave a tall empty card.
const INNER := WIDTH - 24.0
## Lines up to this many characters are not wrapped (short tooltips stay compact).
const WRAP_CHARS := 42
const BG := Color(0.075, 0.058, 0.048, 1.0)
const BORDER := Color(0.72, 0.56, 0.3, 1.0)
const GOLD := Color(0.96, 0.84, 0.56)
const TEXT := Color(0.93, 0.9, 0.84)
const MUTED := Color(0.66, 0.61, 0.54)
const GOOD := Color(0.62, 0.86, 0.52)
const BAD := Color(0.93, 0.47, 0.4)
const HINT := Color(0.75, 0.8, 0.9)
## Body lines that start like this are instructions and get the hint colour.
const HINT_PREFIXES := ["Clic ", "Arrastra", "Arrástra", "Esc "]


## Godot draws its own see-through frame (TooltipPanel) around a custom tooltip; blank it
## for `control` so only the opaque card shows.
static func clear_frame(control: Control) -> void:
	var th := Theme.new()
	th.set_stylebox("panel", "TooltipPanel", StyleBoxEmpty.new())
	control.theme = th


## Empty card: a PanelContainer with a VBoxContainer inside (returned as [card, column]).
static func new_card(wide: bool = true) -> Array:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", card_box() if wide else card_box(8))
	if wide:
		card.custom_minimum_size = Vector2(WIDTH, 0)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	card.add_child(col)
	return [card, col]


## Card for a plain tooltip string.
##   "Title\nline\nline"  -> title, rule, body lines
##   "Title — body"       -> title, rule, body
##   "Just a sentence."   -> body only
static func from_text(text: String) -> Control:
	var lines: PackedStringArray = text.strip_edges().split("\n", false)
	var title: String = ""
	if lines.size() > 1:
		title = lines[0]
		lines.remove_at(0)
	elif lines.size() == 1 and lines[0].contains(" — "):
		var cut: int = lines[0].find(" — ")
		title = lines[0].substr(0, cut)
		var rest: String = lines[0].substr(cut + 3)
		lines[0] = rest.substr(0, 1).to_upper() + rest.substr(1)
	return text_card(title, lines)


## Generic card: optional gold `title`, body `lines`, `bullets` (one effect per row) and
## a `hint` at the bottom. Short content keeps its natural width; long content wraps.
static func text_card(title: String, lines: Array, bullets: Array = [], hint: String = "") -> Control:
	var longest: int = title.length() + 4
	for l in lines:
		longest = maxi(longest, str(l).length())
	for b in bullets:
		longest = maxi(longest, str(b).length() + 3)
	longest = maxi(longest, hint.length())
	var wide: bool = longest > WRAP_CHARS
	var made: Array = new_card(wide)
	var col: VBoxContainer = made[1]
	col.add_theme_constant_override("separation", 5)
	var inner: float = INNER if wide else 0.0
	if title != "":
		col.add_child(title_label(title, 15, inner))
		if not lines.is_empty() or not bullets.is_empty() or hint != "":
			col.add_child(rule())
	for l in lines:
		var s: String = str(l)
		var is_hint: bool = HINT_PREFIXES.any(func(p): return s.begins_with(p))
		col.add_child(label(s, 12 if is_hint else 13, HINT if is_hint else TEXT, wide, inner))
	if not bullets.is_empty():
		col.add_child(bullet_list(bullets, wide))
	if hint != "":
		col.add_child(label(hint, 12, HINT, wide, inner))
	return made[0]


## One row per entry with a small diamond; entries with a negative number are red.
static func bullet_list(entries: Array, wrap: bool = true) -> Control:
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 2)
	for s in entries:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var negative: bool = str(s).contains(" -")
		row.add_child(label("◆", 9, BAD if negative else GOOD, false))
		var l := label(str(s), 14, BAD if negative else TEXT, wrap, INNER - 20.0)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		list.add_child(row)
	return list


static func title_label(text: String, size: int, width: float = INNER) -> Label:
	var l := label(text, size, GOLD, width > 0.0, width)
	var bold := FontVariation.new()
	bold.variation_embolden = 0.7
	l.add_theme_font_override("font", bold)
	return l


static func label(text: String, size: int, color: Color, wrap: bool = true, width: float = INNER) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(width, 0)
	return l


static func rule() -> Control:
	var r := ColorRect.new()
	r.color = Color(BORDER, 0.35)
	r.custom_minimum_size = Vector2(0, 1)
	return r


static func flat(bg: Color, border: Color, width: int, radius: int, margin: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	return sb


static func card_box(margin: int = 12) -> StyleBoxFlat:
	var sb := flat(BG, BORDER, 2, 6, margin)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	return sb
