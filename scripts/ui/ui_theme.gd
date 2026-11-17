extends RefCounted

## One theme for the whole game in the item-card palette (P4-15, owner 2026-11-17: menus in
## the style of the item tooltips). Built in code from `tooltip_card.gd`'s colours so the
## cards, buttons and dialogs never drift apart. The TooltipStyler autoload sets it on the
## root window; every screen, dialog and dropdown inherits it.
##
## Covers: Button (and toggle/OptionButton/MenuButton through it), CheckBox, dialogs
## (Window frame and title, AcceptDialog panel), PopupMenu (dropdown lists), scroll bars.
## Scene-level overrides (the hub columns, the expedition cards) still win.

const C := preload("res://scripts/ui/tooltip_card.gd")

## Button fills: warm dark wood, a touch lighter on hover.
const FILL := Color(0.13, 0.1, 0.08, 0.96)
const FILL_HOVER := Color(0.2, 0.15, 0.11, 0.98)
const FILL_PRESSED := Color(0.27, 0.19, 0.11, 1.0)
const FILL_DISABLED := Color(0.09, 0.075, 0.065, 0.85)
const EDGE := Color(0.45, 0.35, 0.2, 1.0)
const EDGE_DISABLED := Color(0.28, 0.23, 0.17, 0.8)


static func build() -> Theme:
	var t := Theme.new()
	_buttons(t, "Button")
	_buttons(t, "OptionButton")
	_buttons(t, "MenuButton")
	_check(t, "CheckBox")
	_check(t, "CheckButton")
	_dialogs(t)
	_popup_menu(t)
	_scroll(t, "VScrollBar")
	_scroll(t, "HScrollBar")
	return t


static func button_box(fill: Color, edge: Color, width: int = 1) -> StyleBoxFlat:
	var sb := C.flat(fill, edge, width, 4, 0)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	return sb


static func _buttons(t: Theme, type: String) -> void:
	t.set_stylebox("normal", type, button_box(FILL, EDGE))
	t.set_stylebox("hover", type, button_box(FILL_HOVER, C.GOLD))
	t.set_stylebox("pressed", type, button_box(FILL_PRESSED, C.GOLD, 2))
	t.set_stylebox("hover_pressed", type, button_box(FILL_PRESSED, C.GOLD, 2))
	t.set_stylebox("disabled", type, button_box(FILL_DISABLED, EDGE_DISABLED))
	var focus := button_box(Color(0, 0, 0, 0), Color(C.GOLD, 0.7))
	focus.draw_center = false
	t.set_stylebox("focus", type, focus)
	t.set_color("font_color", type, C.TEXT)
	t.set_color("font_hover_color", type, C.GOLD)
	t.set_color("font_pressed_color", type, C.GOLD)
	t.set_color("font_hover_pressed_color", type, C.GOLD)
	t.set_color("font_focus_color", type, C.TEXT)
	t.set_color("font_disabled_color", type, Color(C.MUTED, 0.7))
	t.set_color("icon_normal_color", type, Color.WHITE)
	t.set_color("icon_disabled_color", type, Color(1, 1, 1, 0.45))


static func _check(t: Theme, type: String) -> void:
	for s in ["normal", "pressed", "hover", "hover_pressed", "disabled", "focus"]:
		t.set_stylebox(s, type, StyleBoxEmpty.new())
	t.set_color("font_color", type, C.TEXT)
	t.set_color("font_hover_color", type, C.GOLD)
	t.set_color("font_pressed_color", type, C.GOLD)
	t.set_color("font_hover_pressed_color", type, C.GOLD)
	t.set_color("font_disabled_color", type, Color(C.MUTED, 0.6))


## Dialogs: the card itself (opaque, warm border) with a gold title bar.
static func _dialogs(t: Theme) -> void:
	var frame := C.flat(C.BG, C.BORDER, 2, 6, 0)
	frame.expand_margin_left = 10
	frame.expand_margin_right = 10
	frame.expand_margin_bottom = 10
	frame.expand_margin_top = 34
	frame.shadow_color = Color(0, 0, 0, 0.55)
	frame.shadow_size = 14
	t.set_stylebox("embedded_border", "Window", frame)
	t.set_stylebox("embedded_unfocused_border", "Window", frame)
	t.set_color("title_color", "Window", C.GOLD)
	t.set_constant("title_height", "Window", 32)
	t.set_font_size("title_font_size", "Window", 16)
	t.set_color("title_outline_modulate", "Window", Color(0, 0, 0, 0.6))
	var panel := C.flat(C.BG, Color(0, 0, 0, 0), 0, 0, 0)
	panel.content_margin_left = 12
	panel.content_margin_right = 12
	panel.content_margin_top = 8
	panel.content_margin_bottom = 8
	for type in ["AcceptDialog", "ConfirmationDialog"]:
		t.set_stylebox("panel", type, panel)
		t.set_constant("buttons_separation", type, 10)
	t.set_color("font_color", "Label", C.TEXT)


static func _popup_menu(t: Theme) -> void:
	t.set_stylebox("panel", "PopupMenu", C.card_box(6))
	var hover := C.flat(FILL_HOVER, C.GOLD, 1, 3, 0)
	t.set_stylebox("hover", "PopupMenu", hover)
	t.set_color("font_color", "PopupMenu", C.TEXT)
	t.set_color("font_hover_color", "PopupMenu", C.GOLD)
	t.set_color("font_disabled_color", "PopupMenu", Color(C.MUTED, 0.6))
	t.set_color("font_separator_color", "PopupMenu", C.MUTED)


static func _scroll(t: Theme, type: String) -> void:
	var track := C.flat(Color(0.06, 0.05, 0.04, 0.6), Color(0, 0, 0, 0), 0, 4, 0)
	t.set_stylebox("scroll", type, track)
	t.set_stylebox("scroll_focus", type, track)
	t.set_stylebox("grabber", type, C.flat(Color(EDGE, 0.8), Color(0, 0, 0, 0), 0, 4, 0))
	t.set_stylebox("grabber_highlight", type, C.flat(C.BORDER, Color(0, 0, 0, 0), 0, 4, 0))
	t.set_stylebox("grabber_pressed", type, C.flat(C.GOLD, Color(0, 0, 0, 0), 0, 4, 0))
