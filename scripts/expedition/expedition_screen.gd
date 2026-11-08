extends Control

## One screen for the whole expedition (P4-09): explore rooms, resolve events and fight
## in place. Top: stage with the party (enemies join during fights). Bottom left: the
## hero card (active hero in combat, or whoever was clicked). Bottom right: room map or
## inventory, switched with the side tabs.

signal expedition_finished(reason: String)

const StatusEffectsScript := preload("res://scripts/domain/status_effects.gd")
const BattleUnitScript := preload("res://scripts/combat/battle_unit.gd")
const StressSystemScript := preload("res://scripts/domain/stress_system.gd")
const ItemEffectsScript := preload("res://scripts/domain/item_effects.gd")
const InventorySlotScript := preload("res://scripts/ui/inventory_slot.gd")
const EquipSlotScript := preload("res://scripts/ui/equip_slot.gd")

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
@onready var _enemy_info: PanelContainer = $Stage/EnemyInfo
@onready var _enemy_info_name: Label = $Stage/EnemyInfo/VBox/Head/Name
@onready var _enemy_info_health: ProgressBar = $Stage/EnemyInfo/VBox/Health
@onready var _enemy_info_body: RichTextLabel = $Stage/EnemyInfo/VBox/Body

var _mode: int = Mode.EXPLORE
var _hero_units: Array = []
var _enemy_units: Array = []
var _viewed_hero: Dictionary = {}
var _combat_node_id: String = ""
## While choosing a target after pressing a skill/item: {"side": "enemy"|"ally",
## "skill": Dictionary} or {"side": ..., "item": String}. Empty when not choosing.
var _pending: Dictionary = {}
var _equip_slots: Array = []
## Enemy shown in the info panel (click an enemy outside target-picking).
var _inspected: Dictionary = {}
var _inspected_is_hero: bool = false


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
	_build_equip_row()
	$Stage/EnemyInfo/VBox/Head/Close.pressed.connect(_hide_enemy_info)
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
		if key.keycode == KEY_ESCAPE and not _pending.is_empty():
			_cancel_pending()
			get_viewport().set_input_as_handled()
		elif key.keycode == KEY_M:
			_show_page(false)
		elif key.keycode == KEY_I:
			_show_page(true)


# --- Stage ------------------------------------------------------------------------

func _build_party() -> void:
	# Party order = ranks 1..4. The party stands on the RIGHT half facing left (owner 2026-11-08:
	# attack sprites face left so the weapon is in the right arm); rank 1 nearest the middle = first child.
	for h in GameState.party:
		var u = BattleUnitScript.new()
		u.setup(h, true, "res://assets/portraits/%s.png" % str(h.get("hero_id", "")))
		u.clicked.connect(_on_unit_clicked)
		u.equipment_dropped.connect(_on_equipment_changed)
		_hero_units.append(u)
	for u in _hero_units:
		_hero_row.add_child(u)


## Squad order = ranks 1..4. Enemies stand on the LEFT half; rank 1 nearest the middle (last child of EnemyRow).
func _spawn_enemies(squad: Array) -> void:
	_clear_enemies()
	for enemy in squad:
		var u = BattleUnitScript.new()
		u.setup(enemy, false, "res://assets/enemies/%s.png" % str(enemy.get("id", "")))
		u.clicked.connect(_on_unit_clicked)
		_enemy_units.append(u)
	for k in range(_enemy_units.size() - 1, -1, -1):
		_enemy_row.add_child(_enemy_units[k])


func _clear_enemies() -> void:
	for u in _enemy_units:
		u.queue_free()
	_enemy_units.clear()


func _on_unit_clicked(unit) -> void:
	if not _pending.is_empty():
		var side: String = "ally" if unit.is_hero else "enemy"
		if side == str(_pending["side"]) and _living_units(unit.is_hero).has(unit):
			_execute_pending(unit.data)
		return
	if unit.is_hero:
		_view_hero(unit.data)
		_show_hero_info(unit.data)
	else:
		_show_enemy_info(unit.data)


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
	if _enemy_info.visible:
		if _inspected_is_hero:
			_show_hero_info(_inspected)
		else:
			_show_enemy_info(_inspected)


# --- Enemy info (click an enemy): health %, or everything with the Lentes del abuelo --

func _hide_enemy_info() -> void:
	_enemy_info.visible = false
	_inspected = {}


## The info panel opens on the side away from the clicked unit (party right, enemies left).
func _place_info_panel(on_left: bool) -> void:
	_enemy_info.offset_top = 44.0
	_enemy_info.offset_bottom = 446.0
	_enemy_info.anchor_left = 0.0 if on_left else 1.0
	_enemy_info.anchor_right = 0.0 if on_left else 1.0
	_enemy_info.offset_left = 12.0 if on_left else -342.0
	_enemy_info.offset_right = 342.0 if on_left else -12.0
	_enemy_info.grow_horizontal = Control.GROW_DIRECTION_END if on_left else Control.GROW_DIRECTION_BEGIN


func _show_enemy_info(e: Dictionary) -> void:
	if e.is_empty():
		_hide_enemy_info()
		return
	_inspected = e
	_inspected_is_hero = false
	_enemy_info.visible = true
	_place_info_panel(false)
	var hp: int = int(e.get("hp", 0))
	var hp_max: int = maxi(int(e.get("hp_max", 1)), 1)
	var pct: int = int(round(100.0 * hp / hp_max))
	_enemy_info_name.text = str(e.get("name", "?"))
	_enemy_info_health.max_value = 100
	_enemy_info_health.value = pct
	var lines: PackedStringArray = PackedStringArray()
	if bool(e.get("dead", false)):
		lines.append("Derrotado.")
	elif not GameState.party_can_scout():
		lines.append("Salud: [b]%d%%[/b]" % pct)
		lines.append("[color=#999999]Con los Lentes del abuelo verías su vida exacta, sus ataques y sus debilidades.[/color]")
	else:
		lines.append("PV [b]%d/%d[/b] (%d%%) · Vel %d · Esq %d · Prec %d" % [
			hp, hp_max, pct, int(e.get("speed", 0)), int(e.get("dodge", 0)), int(e.get("accuracy", 0))])
		lines.append("[color=#e8d7a8]Ataques[/color]")
		for sk in e.get("skills", []):
			lines.append("• [b]%s[/b] — %s" % [sk.get("name", "?"), _enemy_skill_summary(sk)])
		lines.append("[color=#e8d7a8]Afinidades[/color]")
		lines.append(_affinity_summary(e.get("elements", {})))
	if not bool(e.get("dead", false)):
		lines.append(_effects_bbcode(e))
		if GameState.party_can_scout():
			lines.append(_resist_bbcode(e, false))
		else:
			lines.append("[color=#e8d7a8]Resistencias[/color]\n[color=#999999]Con los Lentes del abuelo verías sus resistencias.[/color]")
	_enemy_info_body.text = "\n".join(lines)


## Hero view in the same panel: health, stats, active effects and resistances.
func _show_hero_info(h: Dictionary) -> void:
	if h.is_empty():
		_hide_enemy_info()
		return
	_inspected = h
	_inspected_is_hero = true
	_enemy_info.visible = true
	_place_info_panel(true)
	var hp: int = int(h.get("hp", 0))
	var hp_max: int = maxi(int(h.get("hp_max", 1)), 1)
	_enemy_info_name.text = "%s — %s" % [h.get("name", "?"), h.get("class_name", "")]
	_enemy_info_health.max_value = 100
	_enemy_info_health.value = int(round(100.0 * hp / hp_max))
	var lines: PackedStringArray = PackedStringArray()
	lines.append("PV [b]%d/%d[/b] · Estrés [b]%d[/b]/200" % [hp, hp_max, int(h.get("stress", 0))])
	var se = StatusEffectsScript
	lines.append("Prec %d · Esq %d · Vel %d · Crít %d%% · Prot %d%%" % [
		int(h.get("accuracy", 0)) + se.stat(h, "accuracy"), int(h.get("dodge", 0)) + se.stat(h, "dodge"),
		int(h.get("speed", 0)) + se.stat(h, "speed"), int(h.get("crit", 0)) + se.stat(h, "crit"),
		clampi(int(h.get("prot", 0)) + se.stat(h, "prot"), 0, 80)])
	if bool(h.get("dead", false)):
		lines.append("Caído.")
	else:
		lines.append(_effects_bbcode(h))
		lines.append(_resist_bbcode(h, true))
	_enemy_info_body.text = "\n".join(lines)


## Icon for a status id as bbcode: the art if it exists, else a coloured letter badge.
func _status_icon_bb(id: String) -> String:
	var file: String = {"cuidando": "guardia"}.get(id, id)
	var path := "res://assets/status/%s.png" % file
	if ResourceLoader.exists(path):
		return "[img=18x18]%s[/img]" % path
	var d: Dictionary = StatusEffectsScript.def(id)
	return "[bgcolor=%s][color=#ffffff] %s [/color][/bgcolor]" % [str(d.get("color", "#777777")), str(d.get("letter", "?"))]


## Active buffs/debuffs: one line each with icon, name, turns/stacks and what it does.
func _effects_bbcode(u: Dictionary) -> String:
	var out: PackedStringArray = PackedStringArray(["[color=#e8d7a8]Efectos[/color]"])
	var list: Array = StatusEffectsScript.entries(u)
	if list.is_empty():
		out.append("[color=#999999]Ninguno.[/color]")
	for e in list:
		var id: String = str(e["id"])
		var d: Dictionary = StatusEffectsScript.def(id)
		var extra: PackedStringArray = PackedStringArray()
		match id:
			"sangrado", "veneno":
				extra.append("%d PV/turno" % int(e["value"]))
			"sobado":
				extra.append("+%d PV/turno" % int(e["value"]))
			"susto":
				extra.append("+%d estrés/turno" % int(e["value"]))
			"santiguado":
				extra.append("%d golpe%s" % [int(e["value"]), "" if int(e["value"]) == 1 else "s"])
		if int(e["stacks"]) > 1:
			extra.append("×%d" % int(e["stacks"]))
		if int(e["turns"]) > 0 and int(e["turns"]) < 90:
			extra.append("%d turno%s" % [int(e["turns"]), "" if int(e["turns"]) == 1 else "s"])
		var mods: String = _mods_text(u, id)
		var col: String = "#ff8a7a" if StatusEffectsScript.is_negative(id) else "#9fd4ff"
		# Hover the name for the full description.
		out.append("%s [hint=%s][color=%s][b]%s[/b][/color][/hint]%s %s" % [
			_status_icon_bb(id), str(d.get("description", "")).replace("]", ")"), col, str(d.get("name", id)),
			(" [color=#bbbbbb](" + ", ".join(extra) + ")[/color]") if not extra.is_empty() else "", mods])
	return "\n".join(out)


## Stat changes of a salado/chiva effect, e.g. "[Prec -5, Daño -15%]".
func _mods_text(u: Dictionary, id: String) -> String:
	if not id in ["salado", "chiva"]:
		return ""
	var tot: Dictionary = {}
	for s in u["statuses"][id]["stacks"]:
		for k in s.get("mods", {}):
			tot[k] = int(tot.get(k, 0)) + int(s["mods"][k])
	var names := {"accuracy": "Prec", "dodge": "Esq", "speed": "Vel", "crit": "Crít", "prot": "Prot", "dmg_pct": "Daño", "stress_pct": "Estrés"}
	var parts: PackedStringArray = PackedStringArray()
	for k in tot:
		var pct: String = "%" if k in ["dmg_pct", "stress_pct", "prot", "crit"] else ""
		parts.append("%s %+d%s" % [names.get(k, k), int(tot[k]), pct])
	return "[" + ", ".join(parts) + "] " if not parts.is_empty() else ""


## Resistances as a two-column % table (Darkest Dungeon style).
func _resist_bbcode(u: Dictionary, hero: bool) -> String:
	var cats: Array = StatusEffectsScript.resist_categories().filter(func(c): return hero or not bool(c.get("heroes_only", false)))
	var t: String = "[color=#e8d7a8]Resistencias[/color]\n[table=6]"
	for c in cats:
		var v: int = StatusEffectsScript.resist_value(u, str(c["id"]))
		var col: String = "#ffffff" if v < 100 else "#88aaff"
		t += "[cell]%s[/cell][cell] %s [/cell][cell][color=%s]%s[/color]   [/cell]" % [
			_status_icon_bb(str(c.get("icon", c["id"]))), str(c["name"]), col, ("Inmune" if v >= 100 else "%d%%" % v)]
	if cats.size() % 2 == 1:
		t += "[cell][/cell][cell][/cell][cell][/cell]"
	return t + "[/table]"


func _enemy_skill_summary(sk: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	var kind: String = "mágico" if str(sk.get("type", "")) == "magical" else "físico"
	var el: String = str(sk.get("element", ""))
	if el != "":
		kind += " de %s" % GameState.ELEMENT_NAMES.get(el, el)
	parts.append(kind)
	var dmg: Array = sk.get("damage", [0, 0])
	if int(dmg[1]) > 0:
		parts.append("%d–%d daño" % [int(dmg[0]), int(dmg[1])])
	if str(sk.get("target", "")) == "party":
		parts.append("a toda la cuadrilla")
	if int(sk.get("stress", 0)) > 0:
		parts.append("+%d estrés" % int(sk["stress"]))
	for ap in _applies_of(sk.get("applies", null)):
		var c: int = int(round(float(ap.get("chance", 1.0)) * 100))
		parts.append(("%d%% " % c if c < 100 else "") + StatusEffectsScript.display_name(str(ap.get("status", ""))).to_lower())
	for ap in _applies_of(sk.get("self_applies", null)):
		parts.append("se vuelve " + StatusEffectsScript.display_name(str(ap.get("status", ""))).to_lower())
	if int(sk.get("vs_marked_pct", 0)) > 0:
		parts.append("+%d%% a fichados" % int(sk["vs_marked_pct"]))
	if bool(sk.get("ignores_guard", false)):
		parts.append("ignora la guardia")
	if int(sk.get("light", 0)) != 0:
		parts.append("luz %+d" % int(sk["light"]))
	if int(sk.get("steal_colones", 0)) > 0:
		parts.append("roba colones")
	if bool(sk.get("basic", false)):
		parts.append("ataque básico")
	return ", ".join(parts)


func _applies_of(v) -> Array:
	if v is Dictionary:
		return [v]
	return v if v is Array else []


func _affinity_summary(els) -> String:
	var weak: PackedStringArray = PackedStringArray()
	var res: PackedStringArray = PackedStringArray()
	var imm: PackedStringArray = PackedStringArray()
	if els is Dictionary:
		for k in els:
			var n: String = str(GameState.ELEMENT_NAMES.get(str(k), k))
			var m: float = float(els[k])
			if m == 0.0:
				imm.append(n)
			elif m > 1.0:
				weak.append("%s ×%s" % [n, str(m)])
			elif m < 1.0:
				res.append("%s ×%s" % [n, str(m)])
	var out: PackedStringArray = PackedStringArray()
	if not weak.is_empty():
		out.append("[color=#ffcc55]Débil:[/color] " + ", ".join(weak))
	if not res.is_empty():
		out.append("[color=#aaaaaa]Resiste:[/color] " + ", ".join(res))
	if not imm.is_empty():
		out.append("[color=#88aaff]Inmune:[/color] " + ", ".join(imm))
	return "\n".join(out) if not out.is_empty() else "Ninguna"


# --- Hero card --------------------------------------------------------------------

func _build_equip_row() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	for slot in GameState.EQUIP_SLOTS:
		var es = EquipSlotScript.new()
		es.setup(slot)
		es.changed.connect(_on_equipment_changed)
		row.add_child(es)
		_equip_slots.append(es)
	$BottomPanel/Row/HeroInfo.add_child(row)


func _on_equipment_changed(message: String) -> void:
	if message != "":
		_log_line(message, "aaaaaa")
	_refresh_all()


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
	_hero_name.text = "%s\n%s" % [hero.get("name", "?"), hero.get("class_name", "")]
	var lines: PackedStringArray = PackedStringArray()
	lines.append("PV %d/%d · Estrés %d" % [int(hero.get("hp", 0)), int(hero.get("hp_max", 0)), int(hero.get("stress", 0))])
	lines.append("Prec %d · Crít %d%% · Esq %d" % [int(hero.get("accuracy", 0)), int(hero.get("crit", 0)), int(hero.get("dodge", 0))])
	lines.append("Vel %d · Prot %d%% · Daño %+d" % [int(hero.get("speed", 0)), int(hero.get("prot", 0)), int(hero.get("dmg_bonus", 0))])
	if str(hero.get("element", "")) != "":
		lines.append("Arma de %s" % GameState.ELEMENT_NAMES.get(str(hero["element"]), hero["element"]))
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
	for es in _equip_slots:
		es.show_hero(hero)


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
		var b = InventorySlotScript.new()
		if k < GameState.inventory.size():
			var slot: Dictionary = GameState.inventory[k]
			b.setup(str(slot["id"]), int(slot["qty"]))
			b.used.connect(_on_item_pressed)
		else:
			b.setup("", 0)
		_inventory.add_child(b)


func _on_item_pressed(item_id: String) -> void:
	if GameState.is_equipment(item_id):
		# Click = equip on the selected hero (or drag it onto a slot / a hero).
		var target: Dictionary = _viewed_hero if not _viewed_hero.is_empty() else _first_living_hero()
		_on_equipment_changed(GameState.equip(target, item_id))
		return
	match _mode:
		Mode.COMBAT:
			if _combat.active_hero().is_empty() or not _pending.is_empty():
				return
			var item: Dictionary = GameState.get_item(item_id)
			if not ItemEffectsScript.is_usable(item, true):
				_log_line("%s no se usa en combate." % item.get("name", item_id), "aaaaaa")
				return
			var t: String = str(item.get("target", "ally"))
			_begin_pending({"side": "enemy" if t == "enemy" else ("ally" if t == "ally" else ""), "item": item_id})
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


## Best "trampa" resistance in the living party (%): the one who spots it guides the rest.
func _trap_sense() -> int:
	var best: int = 0
	for h in GameState.party:
		if h is Dictionary and not h.get("dead", false):
			best = maxi(best, StatusEffectsScript.resist_value(h, "trampa"))
	return best


func _open_trap() -> void:
	_open_event("Trampa", "%s. Elige cómo pasar." % GameState.current_node().get("label", "Algo cruje"))
	var sense: int = _trap_sense()
	_event_button("Con cuidado", func():
		if randi() % 100 < sense:
			_resolve_event("Alguien vio la trampa a tiempo (Trampas %d%%). Pasaron sin incidentes." % sense)
		elif randf() < 0.25:
			_party_stress(5)
			_resolve_event("Aun así resbalaron. +5 estrés a la cuadrilla.")
		else:
			_resolve_event("Pasaron sin incidentes.")
	)
	_event_button("A la rápida", func():
		if randi() % 100 < sense / 2:
			_resolve_event("Saltaron la trampa sin pensarlo (Trampas %d%%)." % sense)
		elif randf() < 0.45:
			var who: Dictionary = _damage_random_hero(4)
			_resolve_event("¡Caída! %s pierde 4 PV." % who.get("name", "Alguien"))
		else:
			_party_stress(2)
			_resolve_event("Llegaron vivos, pero sudando. +2 estrés.")
	)


func _open_curio() -> void:
	var curio: Dictionary = GameState.get_curio(str(GameState.current_node().get("curio_id", "")))
	if curio.is_empty():
		_open_event("Lugar extraño", "%s. Algo te llama." % GameState.current_node().get("label", ""))
		_event_button("Dejarlo", func(): _resolve_event("Siguen adelante sin mirar atrás."))
		return
	_open_event(str(curio.get("name", "Lugar extraño")), str(curio.get("text", "")))
	var key: String = str(curio.get("key_item", ""))
	if key != "" and GameState.item_count(key) > 0:
		_event_button("Usar %s" % GameState.get_item(key).get("name", key), func():
			GameState.remove_item(key, 1)
			_curio_result(str(curio.get("key_text", "")), curio.get("key_outcome", {}))
		)
	_event_button("Examinar", func():
		var table: Array = curio.get("blind", [])
		var total: float = 0.0
		for o in table:
			total += float(o.get("weight", 1))
		var roll: float = randf() * total
		for o in table:
			roll -= float(o.get("weight", 1))
			if roll <= 0.0:
				_curio_result(str(o.get("text", "")), o)
				return
		_resolve_event("No pasa nada.")
	)
	_event_button("Dejarlo", func(): _resolve_event("Siguen adelante sin mirar atrás."))


func _curio_result(text: String, outcome: Dictionary) -> void:
	var logs: PackedStringArray = GameState.apply_curio_outcome(outcome)
	for l in logs:
		_log_line(l, "cc9944")
	_resolve_event(text)


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
	var squad: Array = ctx.get("enemies", [])
	if squad.is_empty():
		return
	_mode = Mode.COMBAT
	_combat_node_id = node_id
	_set_background(BG_COMBAT)
	_clear_skills()
	_turn_label.text = ""
	_spawn_enemies(squad)
	GameState.equip_locked = true
	_combat.start(GameState.party, squad, _hero_units, _enemy_units,
		bool(ctx.get("is_elite", false)), bool(ctx.get("is_boss", false)))


func _update_turn_label() -> void:
	var hero: Dictionary = _combat.active_hero()
	if hero.is_empty():
		return
	_turn_label.text = "Turno de %s — elige una habilidad o un artículo de la alforja." % hero.get("name", "?")


# --- Choosing a target after pressing a skill or item -----------------------------

func _living_units(heroes: bool) -> Array:
	if heroes:
		return _hero_units.filter(func(u): return not u.is_dead())
	# Hidden (agazapado) enemies can't be picked while others are left.
	var open: Array = _combat.targetable_enemies()
	return _enemy_units.filter(func(u): return not u.is_dead() and open.has(u.data))


## Single-target skills/items ask for a click on an enemy (or ally); with one valid
## choice they go straight through. Self/party ones run at once.
func _begin_pending(action: Dictionary) -> void:
	var side: String = str(action.get("side", ""))
	if side == "":
		_execute_pending({}, action)
		return
	var options: Array = _living_units(side == "ally")
	if options.size() <= 1:
		_execute_pending(options[0].data if not options.is_empty() else {}, action)
		return
	_pending = action
	_clear_skills()
	var what: String = str(action["skill"].get("name", "")) if action.has("skill") else str(GameState.get_item(str(action["item"])).get("name", ""))
	_turn_label.text = "%s: elige a quién %s (clic en %s; Esc o Cancelar para volver)." % [
		what, "atacar" if side == "enemy" else "ayudar", "un enemigo" if side == "enemy" else "un héroe"]
	for u in options:
		u.set_selectable(true)
	var cancel := Button.new()
	cancel.text = "Cancelar"
	cancel.pressed.connect(_cancel_pending)
	_skills.add_child(cancel)


func _clear_selectable() -> void:
	for u in _hero_units + _enemy_units:
		u.set_selectable(false)


func _cancel_pending() -> void:
	_pending = {}
	_clear_selectable()
	var hero: Dictionary = _combat.active_hero()
	if not hero.is_empty():
		_on_hero_turn(hero)


func _execute_pending(target: Dictionary, action: Dictionary = {}) -> void:
	if action.is_empty():
		action = _pending
	_pending = {}
	_clear_selectable()
	_clear_skills()
	var side: String = str(action.get("side", ""))
	if side == "enemy" and not target.is_empty():
		_combat.set_target(target)
	var ally: Dictionary = target if side == "ally" else {}
	if action.has("skill"):
		_combat.use_skill(action["skill"], ally)
	else:
		_combat.use_item(str(action["item"]), ally)


func _on_hero_turn(hero: Dictionary) -> void:
	_view_hero(hero)
	_pending = {}
	_clear_selectable()
	_clear_skills()
	_update_turn_label()
	for sid in hero.get("skill_ids", []):
		var sk: Dictionary = GameState.get_skill(str(sid))
		if sk.is_empty():
			continue
		var b := Button.new()
		b.text = str(sk.get("name", sid))
		b.tooltip_text = _skill_tooltip(sk)
		var side: String = {"enemy": "enemy", "ally": "ally"}.get(str(sk.get("target", "enemy" if str(sk.get("kind", "")) == "attack" else "self")), "")
		b.pressed.connect(func(): _begin_pending({"side": side, "skill": sk}))
		_skills.add_child(b)
	var guard_btn := Button.new()
	guard_btn.text = "Guardia"
	guard_btn.tooltip_text = "Se cubre: recibe la mitad del daño físico hasta su próximo turno."
	guard_btn.pressed.connect(func():
		_clear_skills()
		_combat.guard()
	)
	_skills.add_child(guard_btn)
	var pass_btn := Button.new()
	pass_btn.text = "Pasar"
	pass_btn.pressed.connect(func():
		_clear_skills()
		_combat.pass_turn()
	)
	_skills.add_child(pass_btn)
	_refresh_all()


func _skill_tooltip(sk: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	if str(sk.get("kind", "")) == "attack":
		parts.append("Ataque: %d–%d de daño" % [int(sk.get("damage_min", 0)), int(sk.get("damage_max", 0))])
	if sk.has("heal_min"):
		parts.append("Cura %d–%d PV" % [int(sk.get("heal_min", 0)), int(sk.get("heal_max", 0))])
	var rel: int = int(sk.get("stress_relief", sk.get("self_stress_relief", 0)))
	if rel > 0:
		parts.append("Alivia %d de estrés" % rel)
	var who: String = {"self": "a sí mismo", "ally": "al aliado elegido", "party": "a toda la cuadrilla"}.get(str(sk.get("target", "")), "")
	if who != "":
		parts.append("Objetivo: " + who)
	var desc: String = str(sk.get("description", ""))
	return "%s\n%s" % [desc, " · ".join(parts)] if desc != "" else " · ".join(parts)


func _clear_skills() -> void:
	for c in _skills.get_children():
		c.queue_free()


func _on_combat_over(victory: bool) -> void:
	GameState.equip_locked = false
	_hide_enemy_info()
	_pending = {}
	_clear_selectable()
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
		_end_expedition("objective", "%s ha caído. La corrupción del sótano retrocede… por ahora." % GameState.combat_context.get("enemies", [{}])[0].get("name", "El jefe"))
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
