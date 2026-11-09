extends Button

## One Pulpería tile: the item's icon with this week's price under it, like an alforja
## cell. Click = buy (the hub connects `pressed`). Name, effects and description are in
## the hover card (`item_tooltip.gd`).

const ItemTooltipScript := preload("res://scripts/ui/item_tooltip.gd")
const SIZE := Vector2(60, 72)

var item_id: String = ""


func setup(id: String) -> void:
	item_id = id
	set_meta("item_id", id)
	custom_minimum_size = SIZE
	clip_text = true
	focus_mode = Control.FOCUS_NONE
	add_theme_font_size_override("font_size", 11)
	var icon_path: String = "res://assets/items/%s.png" % id
	if ResourceLoader.exists(icon_path):
		icon = load(icon_path) as Texture2D
		expand_icon = true
		icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	ItemTooltipScript.clear_frame(self)
	refresh()


## Price, colour and enabled state for the current colones and town event.
func refresh() -> void:
	var base: int = int(GameState.get_item(item_id).get("price", 0))
	var now: int = GameState.item_price(item_id)
	var blocked: bool = GameState.buy_block_reason(item_id) != ""
	var price: String = "gratis" if now == 0 else "%d ₡" % now
	if icon == null:
		price = "%s\n%s" % [str(GameState.get_item(item_id).get("name", item_id)).split(" ")[0].substr(0, 8), price]
	text = "cerrado" if blocked else price
	var color: Color = Color(0.96, 0.84, 0.56)
	if now < base:
		color = Color(0.62, 0.86, 0.52)
	elif now > base:
		color = Color(0.93, 0.47, 0.4)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		add_theme_color_override(c, color)
	disabled = blocked or GameState.colones < now
	# Godot only shows a tooltip when tooltip_text is set; the card replaces it.
	tooltip_text = GameState.item_tooltip(item_id)


func _make_custom_tooltip(_for_text: String) -> Object:
	var warning: String = GameState.buy_block_reason(item_id)
	if warning == "" and GameState.colones < GameState.item_price(item_id):
		warning = "No alcanza la plata."
	return ItemTooltipScript.build(item_id, "Clic para comprar." if warning == "" else "", warning)
