extends Node

## Restyles every plain tooltip in the game (any control with `tooltip_text`, option
## lists, future ones) as a `TooltipCard`, so no screen has to do anything.
##
## Godot shows a default tooltip as a PopupPanel ("TooltipPanel") holding one Label
## ("TooltipLabel"). When that popup enters the tree we hide the label and put the card
## next to it. Tooltips built with `_make_custom_tooltip` hold something else and are
## left alone.

const TooltipCardScript := preload("res://scripts/ui/tooltip_card.gd")


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	var popup := node as PopupPanel
	if popup == null or popup.theme_type_variation != &"TooltipPanel" or popup.get_child_count() != 1:
		return
	var plain := popup.get_child(0) as Label
	if plain == null or plain.theme_type_variation != &"TooltipLabel" or plain.text.strip_edges() == "":
		return
	popup.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var text: String = plain.text
	# Emptied as well as hidden: the popup is sized from every child, visible or not.
	plain.text = ""
	plain.hide()
	popup.add_child(TooltipCardScript.from_text(text))
