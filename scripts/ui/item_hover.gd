extends PanelContainer

## A container (an icon tile, a loot row) that shows an item's card on hover, like the
## alforja and the shops (owner 2026-11-19: loot on the victory screens too).

const ItemTooltipScript := preload("res://scripts/ui/item_tooltip.gd")

var item_id: String = ""
var qty: int = 0


func setup(id: String, amount: int = 1) -> void:
	item_id = id
	qty = amount
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Godot only asks for a tooltip when tooltip_text is set; the card replaces it.
	tooltip_text = str(GameState.get_item(id).get("name", id))
	ItemTooltipScript.clear_frame(self)


## Everything inside lets the mouse through, so the hover (and the card) is this container's.
func _ready() -> void:
	_pass_mouse(self)


static func _pass_mouse(n: Node) -> void:
	for c in n.get_children():
		if c is Control:
			(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_pass_mouse(c)


func _make_custom_tooltip(_for_text: String) -> Object:
	return ItemTooltipScript.build(item_id, "", "", qty) if item_id != "" else null
