extends Button

## One inventory cell. Click = use (emits `used`); drag it onto an equipment slot or a
## hero on the stage to equip (P3-11).

signal used(item_id: String)

const ItemTooltipScript := preload("res://scripts/ui/item_tooltip.gd")

## Extra hint at the bottom of the tooltip card ("Usarlo gasta el turno.").
var tooltip_note: String = ""

var item_id: String = ""
var qty: int = 0


func setup(id: String, amount: int) -> void:
	item_id = id
	qty = amount
	custom_minimum_size = Vector2(44, 48)
	clip_text = true
	add_theme_font_size_override("font_size", 11)
	if id == "":
		disabled = true
		return
	var item: Dictionary = GameState.get_item(id)
	var icon_path: String = "res://assets/items/%s.png" % id
	if ResourceLoader.exists(icon_path):
		icon = load(icon_path) as Texture2D
		expand_icon = true
		text = str(amount) if amount > 1 else ""
	else:
		var short: String = str(item.get("name", id)).split(" ")[0].substr(0, 7)
		text = "%s\n×%d" % [short, amount] if amount > 1 else short
	# Godot only shows a tooltip when tooltip_text is set; the card replaces it.
	tooltip_text = GameState.item_tooltip(id)
	ItemTooltipScript.clear_frame(self)
	pressed.connect(func(): used.emit(item_id))


func _make_custom_tooltip(_for_text: String) -> Object:
	return ItemTooltipScript.build(item_id, tooltip_note, "", qty)


func _get_drag_data(_at_position: Vector2) -> Variant:
	if item_id == "":
		return null
	var preview := Label.new()
	preview.text = str(GameState.get_item(item_id).get("name", item_id))
	preview.add_theme_color_override("font_color", Color(0.95, 0.82, 0.55))
	set_drag_preview(preview)
	return {"kind": "item", "id": item_id}
