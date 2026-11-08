extends Button

## One of a hero's 4 equipment slots (weapon, armor, accessory1, accessory2).
## Drop an equipment item here to equip it; click to send it back to the inventory.

signal changed(message: String)

const LABELS := {"weapon": "Arma", "armor": "Armadura", "accessory1": "Accesorio", "accessory2": "Accesorio"}

var hero: Dictionary = {}
var slot: String = ""


func setup(slot_id: String) -> void:
	slot = slot_id
	custom_minimum_size = Vector2(44, 48)
	clip_text = true
	add_theme_font_size_override("font_size", 10)
	pressed.connect(_on_pressed)


func show_hero(h: Dictionary) -> void:
	hero = h
	icon = null
	var id: String = str(h.get("equipment", {}).get(slot, "")) if not h.is_empty() else ""
	if id == "":
		text = LABELS.get(slot, slot)
		tooltip_text = "%s vacío. Arrastra aquí un artículo de la alforja." % LABELS.get(slot, slot)
		modulate = Color(1, 1, 1, 0.6)
		return
	modulate = Color.WHITE
	var icon_path: String = "res://assets/items/%s.png" % id
	if ResourceLoader.exists(icon_path):
		icon = load(icon_path) as Texture2D
		expand_icon = true
		text = ""
	else:
		text = str(GameState.get_item(id).get("name", id)).split(" ")[0].substr(0, 8)
	tooltip_text = GameState.item_tooltip(id) + "\nClic para quitarlo."


func _on_pressed() -> void:
	if hero.is_empty():
		return
	changed.emit(GameState.unequip(hero, slot))


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and str(data.get("kind", "")) == "item" and not hero.is_empty() \
		and GameState.can_change_equipment(hero) and GameState.slots_for(str(data.get("id", ""))).has(slot)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	changed.emit(GameState.equip(hero, str(data.get("id", "")), slot))
