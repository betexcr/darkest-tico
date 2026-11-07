extends Control

## One screen for the whole expedition (P4-09): explore rooms, resolve events and fight
## in place. Top: stage with the party (enemies join during fights). Bottom left: the
## hero card (active hero in combat, or whoever was clicked). Bottom right: room map or
## inventory, switched with the side tabs.

signal expedition_finished(reason: String)

const BattleUnitScript := preload("res://scripts/combat/battle_unit.gd")
const StressSystemScript := preload("res://scripts/domain/stress_system.gd")
const ItemEffectsScript := preload("res://scripts/domain/item_effects.gd")

const BG_EXPLORE := "res://assets/ui_bg/expedition_bg.png"
const BG_COMBAT := "res://assets/ui_bg/combat_bg.png"
const DIRS := {"ui_up": Vector2i.UP, "ui_down": Vector2i.DOWN, "ui_left": Vector2i.LEFT, "ui_right": Vector2i.RIGHT}

enum Mode { EXPLORE, EVENT, COMBAT, ENDED }

@onready var _bg: TextureRect = $BgTexture
@onready var _room_label: Label = $Stage/TopBar/RoomLabel
@onready var _actor_label: Label = $Stage/TopBar/ActorLabel
@onready var _light_label: Label = $Stage/TopBar/LightLabel
@onready var _light_bar: ProgressBar = $Stage/TopBar/LightBar
@onready var _hero_row: HBoxContainer = $Stage/HeroRow
@onready var _enemy_row: HBoxContainer = $Stage/EnemyRow
@onready var _narration: Label = $Stage/Narration
@onready var _event_panel: PanelContainer = $Stage/EventPanel
@onready var _event_title: Label = $Stage/EventPanel/Margin/VBox/EventTitle
@onready var _event_text: Label = $Stage/EventPanel/Margin/VBox/EventText
@onready var _event_actions: HBoxContainer = $Stage/EventPanel/Margin/VBox/EventActions
@onready var _hero_portrait: TextureRect = $BottomPanel/Row/HeroCard/HeroPortrait
@onready var _hero_name: Label = $BottomPanel/Row/HeroInfo/HeroName
@onready var _hero_stats: Label = $BottomPanel/Row/HeroInfo/HeroStats
@onready var _turn_label: Label = $BottomPanel/Row/Actions/TurnLabel
@onready var _skills: HFlowContainer = $BottomPanel/Row/Actions/Skills
@onready var _log: RichTextLabel = $BottomPanel/Row/Actions/Log
@onready var _map_view = $BottomPanel/Row/SidePanel/Pages/MapView
@onready var _inventory: GridContainer = $BottomPanel/Row/SidePanel/Pages/Inventory
@onready var _btn_map: Button = $BottomPanel/Row/SidePanel/Tabs/BtnMap
@onready var _btn_inventory: Button = $BottomPanel/Row/SidePanel/Tabs/BtnInventory
@onready var _combat = $Combat

var _mode: int = Mode.EXPLORE
var _hero_units: Array = []
var _enemy_units: Array = []
var _viewed_hero: Dictionary = {}
var _combat_node_id: String = ""


func _ready() -> void:
	_set_background(BG_EXPLORE)
	_build_party()
	_map_view.room_clicked.connect(_on_room_clicked)
	_btn_map.pressed.connect(_show_page.bind(false))
	_btn_inventory.pressed.connect(_show_page.bind(true))
	$BottomPanel/Row/SidePanel/Tabs/Pad/BtnUp.pressed.connect(_try_move.bind(Vector2i.UP))
	$BottomPanel/Row/SidePanel/Tabs/Pad/BtnDown.pressed.connect(_try_move.bind(Vector2i.DOWN))
	$BottomPanel/Row/SidePanel/Tabs/Pad/BtnLeft.pressed.connect(_try_move.bind(Vector2i.LEFT))
	$BottomPanel/Row/SidePanel/Tabs/Pad/BtnRight.pressed.connect(_try_move.bind(Vector2i.RIGHT))
	_combat.hero_turn_started.connect(_on_hero_turn)
	_combat.actor_changed.connect(func(t: String): _actor_label.text = t)
	_combat.logged.connect(_log_line)
	_combat.enemy_changed.connect(_refresh_all)
	_combat.combat_over.connect(_on_combat_over)
	_show_page(false)
	_view_hero(_first_living_hero())
	_log_line("La cuadrilla entra a %s." % GameState.mission_region_data.get("name", "la oscuridad"), "dddddd")
	_enter_room()


func _unhandled_input(event: InputEvent) -> void:
	for action in DIRS:
		if event.is_action_pressed(action):
			_try_move(DIRS[action])
			get_viewport().set_input_as_handled()
			return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo:
		if key.keycode == KEY_M:
			_show_page(false)
		elif key.keycode == KEY_I:
			_show_page(true)


# --- Stage ------------------------------------------------------------------------

func _build_party() -> void:
	# Party order = ranks 1..4; rank 1 stands nearest the middle, so add rank 4 first.
	for h in GameState.party:
		var u = BattleUnitScript.new()
		u.setup(h, true, "res://assets/portraits/%s.png" % str(h.get("hero_id", "")))
		u.clicked.connect(_on_unit_clicked)
		_hero_units.append(u)
	for k in range(_hero_units.size() - 1, -1, -1):
		_hero_row.add_child(_hero_units[k])


func _spawn_enemy(enemy: Dictionary) -> void:
	_clear_enemies()
	var u = BattleUnitScript.new()
	u.setup(enemy, false, "res://assets/enemies/%s.png" % str(enemy.get("id", "")))
	u.clicked.connect(_on_unit_clicked)
	_enemy_units.append(u)
	_enemy_row.add_child(u)


func _clear_enemies() -> void:
	for u in _enemy_units:
		u.queue_free()
	_enemy_units.clear()


func _on_unit_clicked(unit) -> void:
	if unit.is_hero:
		_view_hero(unit.data)


func _set_background(path: String) -> void:
	if ResourceLoader.exists(path):
		_bg.texture = load(path) as Texture2D


func _refresh_all() -> void:
	for u in _hero_units:
		u.refresh()
	for u in _enemy_units:
		u.refresh()
	_light_bar.value = GameState.mission_light
	var thr: int = int(GameState.mission_params.get("low_light_threshold", 40))
	_light_label.text = "Luz %d%s" % [GameState.mission_light, " (oscuro)" if GameState.mission_light < thr else ""]
	_view_hero(_viewed_hero)
	_refresh_inventory()
	_map_view.refresh()


# --- Hero card --------------------------------------------------------------------

func _first_living_hero() -> Dictionary:
	for h in GameState.party:
		if h is Dictionary and not h.get("dead", false):
			return h
	return GameState.party[0] if not GameState.party.is_empty() else {}


func _view_hero(hero: Dictionary) -> void:
	_viewed_hero = hero
	for k in _hero_units.size():
		var u = _hero_units[k]
		if _mode != Mode.COMBAT:
			u.set_active(is_same(u.data, hero))
	if hero.is_empty():
		return
	var p: String = "res://assets/portraits/%s.png" % str(hero.get("hero_id", ""))
	_hero_portrait.texture = load(p) as Texture2D if ResourceLoader.exists(p) else null
	_hero_name.text = str(hero.get("name", "?"))
	var lines: PackedStringArray = PackedStringArray()
	lines.append("PV %d/%d" % [int(hero.get("hp", 0)), int(hero.get("hp_max", 0))])
	lines.append("Estrés %d/200" % int(hero.get("stress", 0)))
	lines.append("Precisión %d" % int(hero.get("accuracy", 0)))
	lines.append("Crítico %d%%" % int(hero.get("crit", 0)))
	lines.append("Esquiva %d" % int(hero.get("dodge", 0)))
	lines.append("Velocidad %d" % int(hero.get("speed", 0)))
	if bool(hero.get("dead", false)):
		lines.append("Caído")
	elif bool(hero.get("al_borde", false)):
		lines.append("Al Borde")
	var aff: String = str(hero.get("affliction_id", ""))
	if aff != "":
		lines.append("Quebranto: %s" % aff.capitalize())
	var vir: String = str(hero.get("virtud_id", ""))
	if vir != "":
		lines.append("Virtud: %s" % vir.capitalize())
	_hero_stats.text = "\n".join(lines)


# --- Side panel: map / inventory ----------------------------------------------------

func _show_page(inventory: bool) -> void:
	_map_view.visible = not inventory
	_inventory.visible = inventory
	_btn_map.set_pressed_no_signal(not inventory)
	_btn_inventory.set_pressed_no_signal(inventory)
	if inventory:
		_refresh_inventory()
	else:
		_map_view.refresh()


func _refresh_inventory() -> void:
	for c in _inventory.get_children():
		c.queue_free()
	for k in GameState.INVENTORY_SLOTS:
		var b := Button.new()
		b.custom_minimum_size = Vector2(44, 52)
		b.clip_text = true
		b.add_theme_font_size_override("font_size", 11)
		if k < GameState.inventory.size():
			var slot: Dictionary = GameState.inventory[k]
			var id: String = str(slot["id"])
			var item: Dictionary = GameState.get_item(id)
			var icon_path: String = "res://assets/items/%s.png" % id
			if ResourceLoader.exists(icon_path):
				b.icon = load(icon_path) as Texture2D
				b.expand_icon = true
				b.text = "%d" % int(slot["qty"])
				b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
			else:
				b.text = "%s\n×%d" % [_short_name(str(item.get("name", id))), int(slot["qty"])]
			b.tooltip_text = "%s ×%d\n%s\n%s" % [item.get("name", id), int(slot["qty"]), item.get("description", ""), _usage_hint(item)]
			b.pressed.connect(_on_item_pressed.bind(id))
		else:
			b.disabled = true
		_inventory.add_child(b)


func _short_name(n: String) -> String:
	var first: String = n.split(" ")[0]
	return first.substr(0, 7)


func _usage_hint(item: Dictionary) -> String:
	var where: String = {
		"explore": "Fuera de combate", "combat": "Solo en combate",
		"both": "Dentro y fuera de combate", "curio": "Se usa en lugares extraños",
	}.get(str(item.get("usable", "")), "")
	if str(item.get("usable", "")) in ["explore", "both"]:
		where += " · %d uso(s) por héroe en cada lugar" % int(item.get("uses_per_node", 1))
	if str(item.get("target", "")) == "ally":
		where += " · se aplica al héroe seleccionado"
	return where


func _on_item_pressed(item_id: String) -> void:
	match _mode:
		Mode.COMBAT:
			if _combat.active_hero().is_empty():
				return
			_clear_skills()
			_combat.use_item(item_id, _viewed_hero)
		Mode.EXPLORE:
			var target: Dictionary = _viewed_hero
			if target.is_empty() or target.get("dead", false):
				target = _first_living_hero()
			for l in GameState.use_item_outside_combat(item_id, target):
				_log_line(l, "")
			_refresh_all()
		_:
			_log_line("Ahora no.", "888888")


# --- Exploration ------------------------------------------------------------------

func _try_move(dir: Vector2i) -> void:
	if _mode != Mode.EXPLORE:
		return
	var nid: String = GameState.neighbor_in_direction(dir)
	if nid == "":
		return
	_on_room_clicked(nid)


func _on_room_clicked(node_id: String) -> void:
	if _mode != Mode.EXPLORE:
		return
	if not GameState.move_to_node(node_id):
		return
	_enter_room()


func _enter_room() -> void:
	_set_background(BG_EXPLORE)
	_close_event()
	_clear_skills()
	_actor_label.text = ""
	var nd: Dictionary = GameState.current_node()
	var nid: String = GameState.current_node_id
	_room_label.text = "%s — %s" % [GameState.mission_region_data.get("name", ""), nd.get("label", nid)]
	_mode = Mode.EXPLORE
	_refresh_all()
	_show_explore_actions()
	if GameState.is_node_cleared(nid):
		_narrate("%s (despejado)." % nd.get("label", nid))
		return
	match str(nd.get("type", "")):
		"combat", "boss":
			_start_combat(nid)
		"trap":
			_open_trap()
		"curio":
			_open_curio()
		"camp":
			_open_camp()
		"safe":
			_narrate("%s. Por ahora, silencio." % nd.get("label", ""))
			GameState.mark_node_cleared(nid)
		_:
			_narrate("%s." % nd.get("label", ""))
			GameState.mark_node_cleared(nid)


func _show_explore_actions() -> void:
	_clear_skills()
	_turn_label.text = "Explorando: flechas o clic en una sala vecina. Clic en un héroe para verlo."
	var flee := Button.new()
	flee.text = "Abandonar expedición"
	flee.tooltip_text = "Volver a la hacienda sin completar el objetivo."
	flee.pressed.connect(_on_flee_pressed)
	_skills.add_child(flee)


func _on_flee_pressed() -> void:
	if _mode != Mode.EXPLORE:
		return
	_end_expedition("flee", "La cuadrilla vuelve a la hacienda con las manos vacías.")


# --- Events (trap / curio / camp) -----------------------------------------------------

func _open_event(title: String, text: String) -> void:
	_mode = Mode.EVENT
	_event_title.text = title
	_event_text.text = text
	for c in _event_actions.get_children():
		c.queue_free()
	_event_panel.visible = true


func _event_button(text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.pressed.connect(func():
		if b.disabled:
			return
		b.disabled = true
		cb.call()
	)
	_event_actions.add_child(b)


func _close_event() -> void:
	_event_panel.visible = false
	for c in _event_actions.get_children():
		c.queue_free()


func _resolve_event(text: String) -> void:
	GameState.mark_node_cleared(GameState.current_node_id)
	_close_event()
	_mode = Mode.EXPLORE
	_narrate(text)
	_refresh_all()


func _open_trap() -> void:
	_open_event("Trampa", "%s. Elige cómo pasar." % GameState.current_node().get("label", "Algo cruje"))
	_event_button("Con cuidado", func():
		if randf() < 0.25:
			_party_stress(5)
			_resolve_event("Aun así resbalaron. +5 estrés a la cuadrilla.")
		else:
			_resolve_event("Pasaron sin incidentes.")
	)
	_event_button("A la rápida", func():
		if randf() < 0.45:
			var who: Dictionary = _damage_random_hero(4)
			_resolve_event("¡Caída! %s pierde 4 PV." % who.get("name", "Alguien"))
		else:
			_party_stress(2)
			_resolve_event("Llegaron vivos, pero sudando. +2 estrés.")
	)


func _open_curio() -> void:
	_open_event("Lugar extraño", "%s. Algo te llama." % GameState.current_node().get("label", ""))
	_event_button("Examinar", func():
		var roll: float = randf()
		if roll < 0.35:
			_heal_party(3)
			_resolve_event("Un calor extraño. +3 PV a todos.")
		elif roll < 0.65:
			_party_stress(6)
			_resolve_event("Visiones. +6 estrés a la cuadrilla.")
		else:
			GameState.colones += 120
			_resolve_event("Monedas viejas. +120 colones.")
	)
	_event_button("Dejarlo", func(): _resolve_event("Siguen adelante sin mirar atrás."))


func _open_camp() -> void:
	var food: int = GameState.item_count("gallo_pinto")
	_open_event("Fogata de trocha", "Pueden acampar. Tienen %d gallo pinto." % food)
	_event_button("Festín (2 gallo pinto)", func():
		if GameState.item_count("gallo_pinto") < 2:
			_event_text.text = "No alcanza: se necesitan 2 gallo pinto."
			return
		GameState.remove_item("gallo_pinto", 2)
		_heal_party(6)
		_party_stress(-10)
		_resolve_event("Festín humilde. +6 PV y -10 estrés a todos.")
	)
	_event_button("Solo calentarse", func():
		_party_stress(-3)
		_resolve_event("Un respiro corto. -3 estrés.")
	)


func _party_stress(delta: int) -> void:
	for h in GameState.party:
		if h is Dictionary and not h.get("dead", false):
			for l in StressSystemScript.add_stress(h, delta):
				_log_line(l, "cc7744")


func _heal_party(amt: int) -> void:
	for h in GameState.party:
		if h is Dictionary and not h.get("dead", false):
			h["hp"] = mini(int(h["hp"]) + amt, int(h["hp_max"]))
			if int(h["hp"]) > 0:
				h["al_borde"] = false


func _damage_random_hero(amt: int) -> Dictionary:
	var living: Array = []
	for h in GameState.party:
		if h is Dictionary and not h.get("dead", false):
			living.append(h)
	if living.is_empty():
		return {}
	var h: Dictionary = living[randi() % living.size()]
	h["hp"] = maxi(int(h["hp"]) - amt, 0)
	return h


# --- Combat -----------------------------------------------------------------------

func _start_combat(node_id: String) -> void:
	GameState.build_combat_context_for_node(node_id)
	var ctx: Dictionary = GameState.combat_context
	var enemy: Dictionary = ctx.get("enemy", {})
	if enemy.is_empty():
		return
	_mode = Mode.COMBAT
	_combat_node_id = node_id
	_set_background(BG_COMBAT)
	_clear_skills()
	_turn_label.text = ""
	_spawn_enemy(enemy)
	_combat.start(GameState.party, enemy, _hero_units, _enemy_units,
		bool(ctx.get("is_elite", false)), bool(ctx.get("is_boss", false)))


func _on_hero_turn(hero: Dictionary) -> void:
	_view_hero(hero)
	_clear_skills()
	_turn_label.text = "Turno de %s — elige una acción, o un artículo de la alforja." % hero.get("name", "?")
	for sid in hero.get("skill_ids", []):
		var sk: Dictionary = GameState.get_skill(str(sid))
		if sk.is_empty():
			continue
		var b := Button.new()
		b.text = str(sk.get("name", sid))
		b.tooltip_text = _skill_tooltip(sk)
		b.pressed.connect(func():
			_clear_skills()
			_combat.use_skill(sk)
		)
		_skills.add_child(b)
	var pass_btn := Button.new()
	pass_btn.text = "Pasar"
	pass_btn.pressed.connect(func():
		_clear_skills()
		_combat.pass_turn()
	)
	_skills.add_child(pass_btn)
	_refresh_all()


func _skill_tooltip(sk: Dictionary) -> String:
	match str(sk.get("kind", "")):
		"attack":
			return "Ataque: %d–%d de daño" % [int(sk.get("damage_min", 0)), int(sk.get("damage_max", 0))]
		"heal":
			return "Curación: %d–%d PV" % [int(sk.get("heal_min", 0)), int(sk.get("heal_max", 0))]
		"buff":
			return "Alivia %d de estrés" % int(sk.get("self_stress_relief", 0))
	return ""


func _clear_skills() -> void:
	for c in _skills.get_children():
		c.queue_free()


func _on_combat_over(victory: bool) -> void:
	var nd: Dictionary = GameState.mission_nodes_index.get(_combat_node_id, {})
	if not victory:
		_end_expedition("defeat", "La cuadrilla ha caído. La hacienda guarda silencio.")
		return
	GameState.mark_node_cleared(_combat_node_id)
	var pay: int = int(nd.get("reward_colones", 0))
	GameState.colones += pay
	_log_line("Botín: +%d colones." % pay, "66aa66")
	if bool(nd.get("is_boss", false)) or _combat_node_id == GameState.objective_node_id:
		GameState.apply_objective_rewards()
		_end_expedition("objective", "%s ha caído. La corrupción del sótano retrocede… por ahora." % GameState.combat_context.get("enemy", {}).get("name", "El jefe"))
		return
	await get_tree().create_timer(0.6).timeout
	_clear_enemies()
	for u in _hero_units:
		u.set_active(false)
	_set_background(BG_EXPLORE)
	_mode = Mode.EXPLORE
	_actor_label.text = ""
	_show_explore_actions()
	_narrate("La sala queda en silencio.")
	_view_hero(_viewed_hero if not _viewed_hero.get("dead", false) else _first_living_hero())
	_refresh_all()


func _end_expedition(reason: String, text: String) -> void:
	_mode = Mode.ENDED
	_clear_skills()
	_open_event("Fin de la expedición", text)
	_mode = Mode.ENDED
	_event_button("Volver a la hacienda", func():
		GameState.end_mission_abandon()
		expedition_finished.emit(reason)
	)


# --- Log --------------------------------------------------------------------------

func _log_line(text: String, color: String) -> void:
	if color == "":
		_log.append_text(text + "\n")
	else:
		_log.append_text("[color=#%s]%s[/color]\n" % [color, text])
	_narration.text = text


func _narrate(text: String) -> void:
	_log_line(text, "e8d7a8")
