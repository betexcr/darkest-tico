extends Control

## Room map for generated dungeons (P4-09). Draws revealed rooms on their grid cells,
## corridors between them, and type icons. Centered on the current room.
## Clicking a room next to the current one emits room_clicked.

signal room_clicked(node_id: String)

# P4-06: rooms were 38 px with 32 px icons and hard to tell apart; now bigger, framed in a
# color per room type, with a legend. Current / reachable rooms get an outer ring.
const CELL := 72.0
const ROOM := 56.0
const TYPE_FRAME := 4.0
const LEGEND_FONT := 12
const LEGEND_ROW := 16.0

const COLOR_BG := Color(0.03, 0.025, 0.02)
const COLOR_GRID := Color(0.09, 0.075, 0.06)
const COLOR_CORRIDOR := Color(0.42, 0.36, 0.28)
const COLOR_ROOM := Color(0.2, 0.17, 0.13)
const COLOR_VISITED := Color(0.32, 0.27, 0.2)
const COLOR_CURRENT := Color(0.95, 0.8, 0.35)
const COLOR_REACHABLE := Color(0.55, 0.75, 0.45)
const COLOR_BOSS := Color(0.75, 0.15, 0.12)
## Frame color per room type, and the legend (in this order).
const TYPE_COLORS := {
	"combat": Color(0.93, 0.5, 0.16),
	"trap": Color(0.7, 0.42, 0.9),
	"curio": Color(0.3, 0.72, 0.88),
	"camp": Color(0.42, 0.78, 0.36),
	"safe": Color(0.6, 0.57, 0.5),
	"boss": Color(0.9, 0.12, 0.1),
}
const TYPE_NAMES := {"combat": "Pelea", "trap": "Trampa", "curio": "Curiosidad", "camp": "Fogata", "boss": "Jefe"}

var _icons: Dictionary = {}


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	for t in ["safe", "trap", "combat", "curio", "camp", "objective"]:
		var p: String = "res://assets/map_nodes/%s.png" % t
		if ResourceLoader.exists(p):
			_icons[t] = load(p) as Texture2D
	resized.connect(queue_redraw)


func refresh() -> void:
	queue_redraw()


func _room_center(node_id: String) -> Vector2:
	var here: Vector2i = GameState.node_pos(GameState.current_node_id)
	var p: Vector2i = GameState.node_pos(node_id)
	return Vector2(size.x, size.y - _legend_height()) / 2.0 + Vector2(p - here) * CELL


func _icon_for(nd: Dictionary) -> Texture2D:
	var t: String = str(nd.get("type", ""))
	if t == "boss":
		t = "objective"
	elif t == "empty":
		return null
	return _icons.get(t, null)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_BG)
	var off: Vector2 = Vector2(fmod(size.x / 2.0, CELL), fmod((size.y - _legend_height()) / 2.0, CELL))
	var x: float = off.x - CELL / 2.0
	while x < size.x:
		draw_line(Vector2(x, 0), Vector2(x, size.y), COLOR_GRID)
		x += CELL
	var y: float = off.y - CELL / 2.0
	while y < size.y:
		draw_line(Vector2(0, y), Vector2(size.x, y), COLOR_GRID)
		y += CELL
	if GameState.mission_nodes_index.is_empty():
		return
	var neighbors: Array = GameState.mission_neighbors()
	# Corridors between revealed rooms.
	for e in GameState.mission_region_data.get("edges", []):
		var a: String = str(e.get("from", ""))
		var b: String = str(e.get("to", ""))
		if GameState.is_room_revealed(a) and GameState.is_room_revealed(b):
			var known: bool = GameState.visited_node_ids.has(a) or GameState.visited_node_ids.has(b)
			if known:
				draw_line(_room_center(a), _room_center(b), COLOR_CORRIDOR, 6.0)
	# Rooms.
	var half: Vector2 = Vector2(ROOM, ROOM) / 2.0
	for nid in GameState.mission_nodes_index.keys():
		var id: String = str(nid)
		if not GameState.is_room_revealed(id):
			continue
		var nd: Dictionary = GameState.mission_nodes_index[id]
		var c: Vector2 = _room_center(id)
		var r := Rect2(c - half, Vector2(ROOM, ROOM))
		var fill: Color = COLOR_VISITED if GameState.visited_node_ids.has(id) else COLOR_ROOM
		draw_rect(r, fill)
		var cleared: bool = GameState.is_node_cleared(id)
		var icon: Texture2D = _icon_for(nd)
		if icon != null:
			var tint := Color(1, 1, 1, 0.45) if cleared else Color.WHITE
			draw_texture_rect(icon, r.grow(-TYPE_FRAME), false, tint)
		# Type frame (dimmed once cleared), then the state ring outside it.
		var tc: Color = _type_color(nd)
		if cleared:
			tc = tc.darkened(0.45)
		draw_rect(r.grow(-TYPE_FRAME / 2.0), tc, false, TYPE_FRAME)
		if id == GameState.current_node_id:
			draw_rect(r.grow(4.0), COLOR_CURRENT, false, 4.0)
		elif neighbors.has(id):
			draw_rect(r.grow(3.0), COLOR_REACHABLE, false, 2.0)
		# Roaming mini-boss (P2-05): a red mark on its room once the room is revealed.
		if id == GameState.roaming_node() and id != GameState.current_node_id:
			draw_circle(r.position + Vector2(ROOM - 9, 9), 7.0, COLOR_BOSS)
			draw_arc(r.position + Vector2(ROOM - 9, 9), 7.0, 0.0, TAU, 16, Color.BLACK, 1.5)
	_draw_legend()


func _type_color(nd: Dictionary) -> Color:
	return TYPE_COLORS.get(str(nd.get("type", "")), Color(0.45, 0.4, 0.33))


## Legend chips: [type, position] in rows that wrap to the map's width, bottom-left.
func _legend_layout() -> Array:
	var font: Font = get_theme_default_font()
	var out: Array = []
	var x: float = 8.0
	var row: int = 0
	for t in TYPE_NAMES:
		var w: float = 14.0 + font.get_string_size(TYPE_NAMES[t], HORIZONTAL_ALIGNMENT_LEFT, -1, LEGEND_FONT).x
		if x + w > size.x - 4.0 and x > 8.0:
			x = 8.0
			row += 1
		out.append([t, Vector2(x, row * LEGEND_ROW)])
		x += w + 10.0
	return out


func _legend_height() -> float:
	var rows: int = 1
	for it in _legend_layout():
		rows = maxi(rows, int(it[1].y / LEGEND_ROW) + 1)
	return rows * LEGEND_ROW + 6.0


## The legend strip at the bottom of the map: a color chip and the name of each room type.
func _draw_legend() -> void:
	var font: Font = get_theme_default_font()
	var top: float = size.y - _legend_height()
	draw_rect(Rect2(0, top, size.x, size.y - top), Color(COLOR_BG, 0.9))
	for it in _legend_layout():
		var at: Vector2 = Vector2(it[1].x, top + 3.0 + it[1].y)
		draw_rect(Rect2(at + Vector2(0, 4), Vector2(9, 9)), TYPE_COLORS[it[0]])
		draw_string(font, at + Vector2(13, 13), TYPE_NAMES[it[0]], HORIZONTAL_ALIGNMENT_LEFT, -1, LEGEND_FONT, Color(0.85, 0.8, 0.7))


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	for nid in GameState.mission_neighbors():
		var id: String = str(nid)
		var r := Rect2(_room_center(id) - Vector2(ROOM, ROOM) / 2.0, Vector2(ROOM, ROOM))
		if r.has_point(mb.position):
			room_clicked.emit(id)
			accept_event()
			return


func _get_tooltip(at_position: Vector2) -> String:
	for nid in GameState.mission_nodes_index.keys():
		var id: String = str(nid)
		if not GameState.is_room_revealed(id):
			continue
		var r := Rect2(_room_center(id) - Vector2(ROOM, ROOM) / 2.0, Vector2(ROOM, ROOM))
		if r.has_point(at_position):
			var nd: Dictionary = GameState.mission_nodes_index[id]
			var tag: String = " (despejado)" if GameState.is_node_cleared(id) else ""
			if id == GameState.roaming_node():
				tag += "\n¡Rastro del Cadejo! Anda rondando: se mueve de sala en sala."
			return "%s%s" % [nd.get("label", id), tag]
	return ""
