extends Control

signal combat_requested
signal expedition_finished(reason: String)

const ExpeditionLoaderScript := preload("res://scripts/domain/expedition_loader.gd")
const StressSystemScript := preload("res://scripts/domain/stress_system.gd")

@onready var _title: Label = $VBox/Title
@onready var _light_bar: ProgressBar = $VBox/LightRow/LightBar
@onready var _light_val: Label = $VBox/LightRow/LightValue
@onready var _food: Label = $VBox/FoodLabel
@onready var _node_label: Label = $VBox/CurrentNodeLabel
@onready var _log: RichTextLabel = $VBox/Log
@onready var _moves: VBoxContainer = $VBox/MovesBox
@onready var _resolver: PanelContainer = $VBox/Resolver
@onready var _resolver_text: Label = $VBox/Resolver/Margin/VBox/ResolverText
@onready var _resolver_actions: VBoxContainer = $VBox/Resolver/Margin/VBox/ResolverActions
@onready var _btn_flee: Button = $VBox/BtnFlee
@onready var _bg: TextureRect = $BgTexture

var _busy: bool = false


func _ready() -> void:
	_try_load_expedition_bg()
	_btn_flee.pressed.connect(_on_flee_pressed)
	_resolver.visible = false
	_process_combat_return()
	_resume_at_current_node()


func _log_line(s: String) -> void:
	_log.append_text(s + "\n")


func _log_line_color(hex_no_hash: String, s: String) -> void:
	_log.append_text("[color=#%s]%s[/color]\n" % [hex_no_hash, s])


func _try_load_expedition_bg() -> void:
	var p := "res://assets/ui_bg/expedition_bg.png"
	if ResourceLoader.exists(p):
		var tex := load(p) as Texture2D
		if tex != null:
			_bg.texture = tex
			_bg.visible = true
			return
	var img2 := Image.create(512, 512, false, Image.FORMAT_RGB8)
	img2.fill(Color(0.05, 0.09, 0.07))
	_bg.texture = ImageTexture.create_from_image(img2)
	_bg.visible = true


func _combat_node_tag(nd: Dictionary) -> String:
	if bool(nd.get("is_boss", false)):
		return " [JEFE]"
	if bool(nd.get("is_elite", false)):
		return " [ÉLITE]"
	return ""


func _refresh_header() -> void:
	_title.text = GameState.mission_region_data.get("name", "Expedición")
	_light_bar.max_value = 100.0
	_light_bar.value = GameState.mission_light
	_light_val.text = "Luz %d/100 (umbral oscuro: <%d)" % [
		GameState.mission_light,
		int(GameState.mission_params.get("low_light_threshold", 40)),
	]
	_food.text = "Comida: %d" % GameState.mission_food
	var cn: Dictionary = GameState.current_node()
	_node_label.text = "Nodo: %s — %s" % [cn.get("id", "?"), cn.get("label", "")]


func _process_combat_return() -> void:
	if GameState.combat_return_node_id.is_empty():
		return
	var nid: String = GameState.combat_return_node_id
	var v: bool = GameState.combat_return_victory
	GameState.clear_combat_return_flags()
	if v:
		GameState.mark_node_cleared(nid)
		var nd: Dictionary = GameState.mission_nodes_index.get(nid, {})
		var pay: int = int(nd.get("reward_colones", 0))
		GameState.colones += pay
		_log_line_color("66aa66", "Combate ganado en %s. +%d colones." % [nd.get("label", nid), pay])
	else:
		_log_line("Combate perdido en %s. Puedes reintentar o huir." % GameState.mission_nodes_index.get(nid, {}).get("label", nid))


func _resume_at_current_node() -> void:
	_busy = false
	_refresh_header()
	_clear_children(_moves)
	_clear_children(_resolver_actions)
	_resolver.visible = false
	var cn: Dictionary = GameState.current_node()
	var typ: String = str(cn.get("type", "safe"))
	var nid: String = str(cn.get("id", ""))
	match typ:
		"safe":
			_show_travel_buttons()
		"trap":
			_show_trap_resolver(cn)
		"curio":
			_show_curio_resolver(cn)
		"camp":
			_show_camp_resolver(cn)
		"combat":
			if GameState.is_node_cleared(nid):
				_show_travel_buttons()
			else:
				_show_combat_prompt(nid)
		"objective":
			_show_objective_resolver(cn)
		_:
			_show_travel_buttons()


func _clear_children(n: Node) -> void:
	for c in n.get_children():
		c.queue_free()


func _add_travel_row(node: Dictionary, tstr: String, tag: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var typ: String = str(node.get("type", "safe"))
	var icon_path: String = "res://assets/map_nodes/%s.png" % typ
	if ResourceLoader.exists(icon_path):
		var icon_tex := load(icon_path) as Texture2D
		if icon_tex != null:
			var icon_rect := TextureRect.new()
			icon_rect.custom_minimum_size = Vector2(40, 40)
			icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_rect.texture = icon_tex
			row.add_child(icon_rect)
	var b := Button.new()
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.text = "Ir → %s (%s)%s" % [node.get("label", tstr), typ, tag]
	b.pressed.connect(_on_travel_pressed.bind(tstr))
	row.add_child(b)
	_moves.add_child(row)


func _show_travel_buttons() -> void:
	var neigh: Array = GameState.mission_neighbors()
	if neigh.is_empty():
		var l := Label.new()
		l.text = "No hay salidas. Misión bloqueada."
		_moves.add_child(l)
		return
	for tid in neigh:
		var tstr: String = str(tid)
		var node: Dictionary = GameState.mission_nodes_index.get(tstr, {})
		var tag := _combat_node_tag(node) if str(node.get("type", "")) == "combat" else ""
		_add_travel_row(node, tstr, tag)


func _on_travel_pressed(target_id: String) -> void:
	if _busy:
		return
	if not GameState.move_to_node(target_id):
		return
	_log_line("Te mueves. La luz baja.")
	_resume_at_current_node()


func _show_trap_resolver(_cn: Dictionary) -> void:
	_busy = true
	_resolver.visible = true
	_resolver_text.text = "Trampa: escalas resbalosas o vigas. Elige cómo pasar."
	_add_resolver_button("Con cuidado (calma)", _trap_careful)
	_add_resolver_button("A la rápida (riesgo)", _trap_fast)


func _trap_careful() -> void:
	_close_resolver()
	if randf() < 0.25:
		_apply_party_stress(5)
		_log_line("Aun así resbalaste. +5 estrés (grupo).")
	else:
		_log_line("Pasaste sin incidentes.")
	_show_travel_buttons()
	_busy = false


func _trap_fast() -> void:
	_close_resolver()
	if randf() < 0.45:
		_damage_random_hero(4)
		_log_line("¡Caída! Un héroe pierde 4 HP.")
	else:
		_log_line("Llegaste vivo, pero sudando.")
		_apply_party_stress(2)
	_show_travel_buttons()
	_busy = false


func _show_curio_resolver(_cn: Dictionary) -> void:
	_busy = true
	_resolver.visible = true
	_resolver_text.text = "Lugar extraño: examinas el altar o la caja."
	_add_resolver_button("Tocar el altar", _curio_touch)
	_add_resolver_button("Ignorar", _curio_ignore)


func _curio_touch() -> void:
	_close_resolver()
	var roll: float = randf()
	if roll < 0.35:
		_heal_party(3)
		_log_line("Calor extraño. +3 HP a todos.")
	elif roll < 0.65:
		_apply_party_stress(6)
		_log_line("Visiones. +6 estrés (grupo).")
	else:
		GameState.colones += 120
		_log_line("Encuentras monedas viejas. +120 colones.")
	_show_travel_buttons()
	_busy = false


func _curio_ignore() -> void:
	_close_resolver()
	_log_line("Sigues adelante sin mirar atrás.")
	_show_travel_buttons()
	_busy = false


func _show_camp_resolver(_cn: Dictionary) -> void:
	_busy = true
	_resolver.visible = true
	_resolver_text.text = "Fogata de trocha: puedes cocinar si tienes comida."
	_add_resolver_button("Comida completa (2 comida, descanso)", _camp_feast)
	_add_resolver_button("Solo calentar manos", _camp_skip)


func _camp_feast() -> void:
	if GameState.mission_food < 2:
		_resolver_text.text = "Necesitas 2 de comida para un festín."
		return
	_close_resolver()
	GameState.mission_food -= 2
	_heal_party(6)
	_apply_party_stress(-4)
	_log_line("Festín humilde. -4 estrés, +6 HP, -2 comida.")
	_show_travel_buttons()
	_busy = false


func _camp_skip() -> void:
	_close_resolver()
	_apply_party_stress(-2)
	_log_line("Un respiro corto. -2 estrés.")
	_show_travel_buttons()
	_busy = false


func _show_combat_prompt(nid: String) -> void:
	_busy = true
	_resolver.visible = true
	var nd: Dictionary = GameState.mission_nodes_index.get(nid, {})
	var tag := _combat_node_tag(nd)
	_resolver_text.text = "Enemigo acechando%s. ¿Entrar en combate?" % tag
	_add_resolver_button("Luchar", func ():
		GameState.build_combat_context_for_node(nid)
		combat_requested.emit()
	)
	_add_resolver_button("Retroceder (quedarse aquí)", func ():
		_close_resolver()
		_busy = false
		_log_line("Vacilas en el umbral…")
		call_deferred("_show_travel_buttons")
	)


func _show_objective_resolver(_cn: Dictionary) -> void:
	_busy = true
	_resolver.visible = true
	_resolver_text.text = "Foco de corrupción: puedes purgar la misión y volver a la hacienda."
	_add_resolver_button("Completar objetivo", func ():
		GameState.apply_objective_rewards()
		_log_line("La corrupción retrocede por ahora. Recompensa aplicada.")
		_close_resolver()
		GameState.end_mission_abandon()
		expedition_finished.emit("objective")
	)


func _add_resolver_button(text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.pressed.connect(func ():
		if b.disabled:
			return
		b.disabled = true
		cb.call()
	)
	_resolver_actions.add_child(b)


func _close_resolver() -> void:
	_resolver.visible = false
	_clear_children(_resolver_actions)


func _apply_party_stress(delta: int) -> void:
	for h in GameState.party:
		if h is Dictionary and not h.get("dead", false):
			for x in StressSystemScript.add_stress(h, delta):
				_log_line(x)


func _heal_party(amt: int) -> void:
	for h in GameState.party:
		if h is Dictionary and not h.get("dead", false):
			var hm: int = int(h["hp_max"])
			h["hp"] = mini(int(h["hp"]) + amt, hm)


func _damage_random_hero(amt: int) -> void:
	var living: Array = []
	for h in GameState.party:
		if h is Dictionary and not h.get("dead", false):
			living.append(h)
	if living.is_empty():
		return
	var h: Dictionary = living[randi() % living.size()]
	h["hp"] = maxi(int(h["hp"]) - amt, 0)


func _on_flee_pressed() -> void:
	GameState.end_mission_abandon()
	expedition_finished.emit("flee")
