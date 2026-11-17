extends Button

## A button whose hover tooltip is a full card (P4-15), like the item tiles: set `card` to a
## Callable that returns the card Control. `tooltip_text` must stay non-empty (Godot only
## asks for a tooltip when there is text); it is also what screen readers and tests see.

const TooltipCardScript := preload("res://scripts/ui/tooltip_card.gd")

var card: Callable


func _ready() -> void:
	TooltipCardScript.clear_frame(self)


func _make_custom_tooltip(_for_text: String) -> Object:
	if card.is_valid():
		return card.call()
	return null
