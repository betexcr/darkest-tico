extends Control

## Room map for generated dungeons (P4-09). Draws revealed rooms on their grid cells,
## corridors between them, and type icons. Centered on the current room.
## Clicking a room next to the current one emits room_clicked.

signal room_clicked(node_id: String)

const CELL := 64.0
const ROOM := 38.0

const COLOR_BG := Color(0.03, 0.025, 0.02)
const COLOR_GRID := Color(0.09, 0.075, 0.06)
const COLOR_CORRIDOR := Color(0.42, 0.36, 0.28)
const COLOR_ROOM := Color(0.2, 0.17, 0.13)
const COLOR_VISITED := Color(0.32, 0.27, 0.2)
const COLOR_CURRENT := Color(0.95, 0.8, 0.35)
const COLOR_REACHABLE := Color(0.55, 0.75, 0.45)
const COLOR_BOSS := Color(0.75, 0.15, 0.12)

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
	return size / 2.0 + Vector2(p - here) * CELL


func _icon_for(nd: Dictionary) -> Texture2D:
	var t: String = str(nd.get("type", ""))
	if t == "boss":
		t = "objective"
	elif t == "empty":
		return null
	return _icons.get(t, null)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_BG)
	var off: Vector2 = Vector2(fmod(size.x / 2.0, CELL), fmod(size.y / 2.0, CELL))
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
		var icon: Texture2D = _icon_for(nd)
		if icon != null:
			var tint := Color(1, 1, 1, 0.45) if GameState.is_node_cleared(id) else Color.WHITE
			draw_texture_rect(icon, r.grow(-3), false, tint)
		var border: Color = Color(0.5, 0.42, 0.3)
		var width: float = 2.0
		if id == GameState.current_node_id:
			border = COLOR_CURRENT
			width = 4.0
		elif str(nd.get("type", "")) == "boss":
			border = COLOR_BOSS
			width = 3.0
		elif neighbors.has(id):
			border = COLOR_REACHABLE
			width = 3.0
		draw_rect(r, border, false, width)


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
			return "%s%s" % [nd.get("label", id), tag]
	return ""
