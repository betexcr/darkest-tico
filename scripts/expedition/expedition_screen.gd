extends Control

## One screen for the whole expedition (P4-09): explore rooms, resolve events and fight
## in place. Top: stage with the party (enemies join during fights). Bottom left: the
## hero card (active hero in combat, or whoever was clicked). Bottom right: room map or
## inventory, switched with the side tabs.

signal expedition_finished(reason: String)

## The action row holds this many full-size icons; with more they shrink to ACTION_ICON_SMALL.
const ACTION_ROW_FULL := 9
const ACTION_ICON_SMALL := Vector2(44, 44)
const StatusEffectsScript := preload("res://scripts/domain/status_effects.gd")
const BattleUnitScript := preload("res://scripts/combat/battle_unit.gd")
const StressSystemScript := preload("res://scripts/domain/stress_system.gd")
const ItemEffectsScript := preload("res://scripts/domain/item_effects.gd")
const ResolveSystemScript := preload("res://scripts/domain/resolve_system.gd")
const CampingSystemScript := preload("res://scripts/domain/camping_system.gd")
const InventorySlotScript := preload("res://scripts/ui/inventory_slot.gd")
const EquipSlotScript := preload("res://scripts/ui/equip_slot.gd")
const SkillButtonScript := preload("res://scripts/ui/skill_button.gd")
const SkillRanksScript := preload("res://scripts/domain/skill_ranks.gd")
const FormationScript := preload("res://scripts/domain/formation.gd")
const LightSystemScript := preload("res://scripts/domain/light_system.gd")
const BalanceScript := preload("res://scripts/domain/balance.gd")
const TrapRulesScript := preload("res://scripts/domain/trap_rules.gd")
const CardScript := preload("res://scripts/ui/tooltip_card.gd")
const CombatControllerScript := preload("res://scripts/combat/combat_controller.gd")
const ItemHoverScript := preload("res://scripts/ui/item_hover.gd")

const BG_EXPLORE := "res://assets/ui_bg/expedition_bg.png"
const BG_COMBAT := "res://assets/ui_bg/combat_bg.png"
const DIRS := {"ui_up": Vector2i.UP, "ui_down": Vector2i.DOWN, "ui_left": Vector2i.LEFT, "ui_right": Vector2i.RIGHT}

enum Mode { EXPLORE, EVENT, COMBAT, ENDED }

## Event results (curios, traps) show in a card dialog (owner 2026-11-19), not only in the
## log. Off for headless -s runs (tests, bots), which press the event buttons themselves.
var results_modal: bool = not SaveService.is_script_run()
var _result_dialog: AcceptDialog = null
## Each hero (by uid: a Dictionary key would hash by content and miss once PV changes) as the
## fight began: hp, stress, dead, affliction, virtud.
var _battle_start: Dictionary = {}

@onready var _bg: TextureRect = $BgTexture
@onready var _room_label: Label = $Stage/TopBar/RoomLabel
@onready var _actor_label: Label = $Stage/TopBar/ActorLabel
@onready var _light_label: Label = $Stage/TopBar/LightLabel
@onready var _light_bar: ProgressBar = $Stage/TopBar/LightBar
@onready var _hero_row: HBoxContainer = $Stage/HeroRow
@onready var _enemy_row: HFlowContainer = $Stage/EnemyRow
@onready var _narration: Label = $Stage/Narration
@onready var _event_panel: PanelContainer = $Stage/EventPanel
@onready var _event_title: Label = $Stage/EventPanel/Margin/VBox/EventTitle
@onready var _event_text: Label = $Stage/EventPanel/Margin/VBox/EventText
@onready var _event_actions: HFlowContainer = $Stage/EventPanel/Margin/VBox/EventActions
@onready var _hero_portrait: TextureRect = $BottomPanel/Row/HeroCard/HeroPortrait
@onready var _hero_name: Label = $BottomPanel/Row/HeroInfo/HeroName
@onready var _hero_stats: Label = $BottomPanel/Row/HeroInfo/HeroStats
@onready var _turn_label: Label = $BottomPanel/Row/Actions/TurnLabel
@onready var _skills: HBoxContainer = $BottomPanel/Row/Actions/Skills
@onready var _log: RichTextLabel = $BottomPanel/Row/Actions/Log
@onready var _map_view = $BottomPanel/Row/SidePanel/Pages/MapView
@onready var _inventory: GridContainer = $BottomPanel/Row/SidePanel/Pages/Inventory
@onready var _btn_map: Button = $BottomPanel/Row/SidePanel/Tabs/BtnMap
@onready var _btn_inventory: Button = $BottomPanel/Row/SidePanel/Tabs/BtnInventory
@onready var _combat = $Combat
@onready var _enemy_info: PanelContainer = $Stage/EnemyInfo
@onready var _enemy_info_name: Label = $Stage/EnemyInfo/VBox/Head/Name
@onready var _enemy_info_portrait: TextureRect = $Stage/EnemyInfo/VBox/Head/Portrait
@onready var _enemy_info_health: ProgressBar = $Stage/EnemyInfo/VBox/Health
@onready var _enemy_info_body: RichTextLabel = $Stage/EnemyInfo/VBox/Body

var _mode: int = Mode.EXPLORE
var _hero_units: Array = []
var _enemy_units: Array = []
var _viewed_hero: Dictionary = {}
## "← Adelante" / "Atrás →" on the hero card: fix the formation between fights (P1-03b).
var _formation_row: HBoxContainer
var _combat_node_id: String = ""
## While choosing a target after pressing a skill/item: {"side": "enemy"|"ally",
## "skill": Dictionary} or {"side": ..., "item": String}. Empty when not choosing.
var _pending: Dictionary = {}
var _equip_slots: Array = []
## Enemy shown in the info panel (click an enemy outside target-picking).
var _inspected: Dictionary = {}
var _inspected_is_hero: bool = false
## Camp phase (P3-07): respite left, skills used ("uid:skill"), whether someone keeps watch.
var _camp_respite: int = 0
var _camp_used: Array = []
var _camp_watch: bool = false
## Camp skills each hero got at this fogata (uid -> ids): shared + a random draw of class skills.
var _camp_hands: Dictionary = {}
var _combat_is_ambush: bool = false
## Enemy the player clicked during a fight: single-target attacks/items go straight to it.
var _selected_enemy: Dictionary = {}
## Active hero's equipment when their turn began; a change spends the turn.
var _turn_equipment: Dictionary = {}


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
	_combat.combat_fled.connect(_on_combat_fled)
	_build_equip_row()
	_build_formation_row()
	$Stage/EnemyInfo/VBox/Head/Close.pressed.connect(_hide_enemy_info)
	_show_page(false)
	_view_hero(_first_living_hero())
	_log_line("La cuadrilla entra a %s (%s)." % [GameState.mission_region_data.get("name", "la oscuridad"),
		GameState.mission_difficulty.get("name", "")], "dddddd")
	for l in GameState.mission_start_logs:
		_log_line(l, "cc7744")
	GameState.mission_start_logs = PackedStringArray()
	_enter_room()


## The hero/enemy details panel closes on a click anywhere but a fighter or the panel itself
## (owner 2026-11-19). Seen before the GUI, so the click still does whatever it was for.
func _input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT or not _enemy_info.visible:
		return
	if _enemy_info.get_global_rect().has_point(mb.position):
		return
	# The painted part of each fighter (a hero's unit box spans the whole stage height).
	for u in _hero_units + _enemy_units:
		if is_instance_valid(u) and u.is_visible_in_tree() and u._holder.get_global_rect().grow(12.0).has_point(mb.position):
			return
	_hide_enemy_info()


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
		u.setup(h, true, GameState.portrait_path(h))
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
	for u in _enemy_units:
		_enemy_row.add_child(u)
	CombatControllerScript.layout_enemy_row(_enemy_units)


## Combat's enemy_spawner (P2-04): the stage unit for an enemy that joins mid-fight. The
## controller appends it to the shared unit array and lines up the row.
func _spawn_enemy_unit(enemy: Dictionary):
	var u = BattleUnitScript.new()
	u.setup(enemy, false, "res://assets/enemies/%s.png" % str(enemy.get("id", "")))
	u.clicked.connect(_on_unit_clicked)
	_enemy_row.add_child(u)
	return u


func _clear_enemies() -> void:
	for u in _enemy_units:
		u.queue_free()
	_enemy_units.clear()


func _on_unit_clicked(unit) -> void:
	# Defeated enemies can't be selected or inspected.
	if not unit.is_hero and unit.is_dead():
		return
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
		_select_enemy(unit.data)


## In a fight, clicking an enemy makes it the target: attacks skip the target prompt.
func _select_enemy(e: Dictionary) -> void:
	if _mode != Mode.COMBAT or e.get("dead", false) or not _combat.targetable_enemies().has(e):
		return
	_selected_enemy = e
	_combat.set_target(e)


func _set_background(path: String) -> void:
	if ResourceLoader.exists(path):
		_bg.texture = load(path) as Texture2D


func _refresh_all() -> void:
	for u in _hero_units:
		u.refresh()
	for u in _enemy_units:
		u.refresh()
	_light_bar.value = GameState.mission_light
	var lux: int = GameState.mission_light
	_light_label.text = "Luz %d · %s" % [lux, LightSystemScript.tier_name(lux)]
	var light_tip: String = "Luz %d · %s
%s" % [lux, LightSystemScript.tier_name(lux), LightSystemScript.effects_text(lux)]
	_light_label.tooltip_text = light_tip
	# Labels ignore the mouse by default; the Luz tooltip needs hover.
	_light_label.mouse_filter = Control.MOUSE_FILTER_PASS
	_light_bar.tooltip_text = light_tip
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
	_enemy_info.offset_top = 36.0
	_enemy_info.offset_bottom = 462.0
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
	_set_info_portrait("res://assets/enemies/%s.png" % str(e.get("id", "")))
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
	_set_info_portrait(GameState.portrait_path(h))
	_enemy_info_health.max_value = 100
	_enemy_info_health.value = int(round(100.0 * hp / hp_max))
	var lines: PackedStringArray = PackedStringArray()
	lines.append("PV [b]%d/%d[/b] · Estrés [b]%d[/b]/200" % [hp, hp_max, int(h.get("stress", 0))])
	lines.append(_resolve_line(h))
	var se = StatusEffectsScript
	lines.append("Prec %d · Esq %d · Vel %d · Crít %d%% · Prot %d%%" % [
		int(h.get("accuracy", 0)) + se.stat(h, "accuracy"), int(h.get("dodge", 0)) + se.stat(h, "dodge"),
		int(h.get("speed", 0)) + se.stat(h, "speed"), int(h.get("crit", 0)) + se.stat(h, "crit"),
		clampi(int(h.get("prot", 0)) + se.stat(h, "prot"), 0, 80)])
	if bool(h.get("dead", false)):
		lines.append("Caído.")
	else:
		if bool(h.get("al_borde", false)):
			# Doc 01 §2.4: the odds of surviving the next hit (drop with each roll and high stress).
			lines.append("[color=#dd8844]Al Borde: sobrevive al próximo golpe con [b]%d%%[/b].[/color]" % int(round(CombatResolver.death_save_chance(h) * 100)))
		lines.append(_effects_bbcode(h))
		lines.append(_resist_bbcode(h, true))
	_enemy_info_body.text = "\n".join(lines)


func _set_info_portrait(path: String) -> void:
	_enemy_info_portrait.texture = GameState.load_texture(path)
	_enemy_info_portrait.visible = _enemy_info_portrait.texture != null


## Icon for a status id as bbcode: the art if it exists, else a coloured letter badge.
func _status_icon_bb(id: String) -> String:
	var file: String = {"cuidando": "guardia"}.get(id, id)
	var path := "res://assets/status/%s.png" % file
	if ResourceLoader.exists(path):
		return "[img=18x18]%s[/img]" % path
	var d: Dictionary = StatusEffectsScript.def(id)
	return "[bgcolor=%s][color=#ffffff] %s [/color][/bgcolor]" % [str(d.get("color", "#777777")), str(d.get("letter", "?"))]


## "Resolución 2 · Baquiano (9/14 XP)".
func _resolve_line(h: Dictionary) -> String:
	var lvl: int = int(h.get("resolve_level", 0))
	var pr: Dictionary = ResolveSystemScript.progress(h)
	var xp: String = "máximo" if lvl >= ResolveSystemScript.MAX_LEVEL else "%d/%d XP" % [int(pr["current"]), int(pr["needed"])]
	return "Resolución [b]%d[/b] · %s (%s)" % [lvl, ResolveSystemScript.level_name(lvl), xp]


## Active buffs/debuffs: one line each with icon, name, turns/stacks and what it does.
func _effects_bbcode(u: Dictionary) -> String:
	var out: PackedStringArray = PackedStringArray(["[color=#e8d7a8]Efectos[/color]"])
	var list: Array = StatusEffectsScript.entries(u)
	var camp: Array = u.get("camp_buffs", [])
	if list.is_empty() and camp.is_empty():
		out.append("[color=#999999]Ninguno.[/color]")
	for b in camp:
		var n: int = int(b.get("fights", 0))
		var when: String = "toda la expedición" if n >= 99 else "%d pelea%s" % [n, "" if n == 1 else "s"]
		var bad: bool = CampingSystemScript.is_debuff(b.get("mods", {}))
		out.append("[color=#%s][b]%s[/b][/color] [color=#bbbbbb](%s, %s)[/color] [%s]" % [
			"e07a6a" if bad else "ffd27a", str(b.get("name", "?")), str(b.get("from", "fogata")), when,
			CampingSystemScript.mods_text(b.get("mods", {}))])
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
	# Reach (P1-03a) and forced moves (P1-03b).
	if str(sk.get("target", "single")) != "party":
		parts.append("alcanza %s" % FormationScript.ranks_text(FormationScript.target_ranks(sk)))
	var mt: int = int(sk.get("move_target", 0))
	if mt != 0:
		parts.append("jala %d adelante" % -mt if mt < 0 else "empuja %d atrás" % mt)
	if bool(sk.get("shuffle_target", false)):
		parts.append("revuelve la posición")
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


## Between fights the player can fix the formation (fights, Moverse and enemy shoves leave it
## changed). In combat the card hides these: "Moverse" on the action bar does it there.
func _build_formation_row() -> void:
	_formation_row = HBoxContainer.new()
	_formation_row.add_theme_constant_override("separation", 4)
	for spec in [[-1, "← Adelante", "Pasar una posición hacia adelante (más cerca de los enemigos)."],
			[1, "Atrás →", "Pasar una posición hacia atrás."]]:
		var b := Button.new()
		b.text = spec[1]
		b.tooltip_text = spec[2]
		b.add_theme_font_size_override("font_size", 12)
		b.focus_mode = Control.FOCUS_NONE
		var delta: int = spec[0]
		b.pressed.connect(func(): _reorder_party(_viewed_hero, delta))
		_formation_row.add_child(b)
	$BottomPanel/Row/HeroInfo.add_child(_formation_row)


## Moves a hero one position in the formation outside combat (data, units and stage row).
func _reorder_party(hero: Dictionary, delta: int) -> void:
	if _mode == Mode.COMBAT or hero.is_empty() or hero.get("dead", false):
		return
	var before: int = FormationScript.position_of(hero, GameState.party)
	var order: Array = FormationScript.move_by(GameState.party, hero, delta)
	var units: Array = []
	for h in order:
		for u in _hero_units:
			if is_same(u.data, h):
				units.append(u)
	if units.size() != order.size():
		return
	for k in order.size():
		GameState.party[k] = order[k]
		_hero_units[k] = units[k]
		_hero_row.move_child(units[k], k)
	var after: int = FormationScript.position_of(hero, GameState.party)
	if after != before:
		_log_line("%s pasa a la posición %d." % [hero.get("name", "?"), after], "88aacc")
	_refresh_all()


func _on_equipment_changed(message: String) -> void:
	if message != "":
		_log_line(message, "aaaaaa")
	var hero: Dictionary = GameState.equip_turn_hero
	if _mode == Mode.COMBAT and not hero.is_empty() and _equipment_of(hero) != _turn_equipment:
		# The swap already happened; it costs the hero's turn.
		GameState.equip_turn_hero = {}
		_lock_skills()
		_refresh_all()
		_combat.spend_turn_on_equipment()
		return
	_refresh_all()


func _equipment_of(hero: Dictionary) -> Dictionary:
	var eq = hero.get("equipment", {})
	return (eq as Dictionary).duplicate() if eq is Dictionary else {}


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
	if _formation_row != null:
		var pos: int = FormationScript.position_of(hero, GameState.party) if not hero.is_empty() else 0
		var n: int = FormationScript.living(GameState.party).size()
		_formation_row.visible = _mode != Mode.COMBAT and pos > 0
		if _formation_row.get_child_count() == 2:
			_formation_row.get_child(0).disabled = pos <= 1
			_formation_row.get_child(1).disabled = pos >= n
	if hero.is_empty():
		return
	var p: String = GameState.portrait_path(hero)
	_hero_portrait.texture = GameState.load_texture(p)
	_hero_name.text = "%s\n%s" % [hero.get("name", "?"), hero.get("class_name", "")]
	var lines: PackedStringArray = PackedStringArray()
	lines.append("PV %d/%d · Estrés %d · Resolución %d" % [int(hero.get("hp", 0)), int(hero.get("hp_max", 0)),
		int(hero.get("stress", 0)), int(hero.get("resolve_level", 0))])
	lines.append("Prec %d · Crít %d%% · Esq %d" % [int(hero.get("accuracy", 0)), int(hero.get("crit", 0)), int(hero.get("dodge", 0))])
	lines.append("Vel %d · Prot %d%% · Daño %+d" % [int(hero.get("speed", 0)), int(hero.get("prot", 0)), int(hero.get("dmg_bonus", 0))])
	# Battlefield position (P1-03a) and the class's preferred ones.
	var pos: int = FormationScript.position_of(hero, GameState.party)
	if pos > 0:
		var ideal: Array = GameState.get_hero_template(str(hero.get("hero_id", ""))).get("ranks", [])
		lines.append("Posición %d%s" % [pos, " (ideal %s)" % FormationScript.ranks_text(ideal) if not ideal.is_empty() else ""])
	if str(hero.get("element", "")) != "":
		lines.append("Arma de %s" % GameState.ELEMENT_NAMES.get(str(hero["element"]), hero["element"]))
	if bool(hero.get("dead", false)):
		lines.append("Caído")
	elif bool(hero.get("al_borde", false)):
		lines.append("Al Borde")
	var aff: String = str(hero.get("affliction_id", ""))
	if aff != "":
		lines.append("Quebranto: %s" % StressSystemScript.affliction_name(aff))
	var vir: String = str(hero.get("virtud_id", ""))
	if vir != "":
		lines.append("Virtud: %s" % StressSystemScript.virtud_name(vir))
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
	for k in GameState.inventory_slots():
		var b = InventorySlotScript.new()
		if k < GameState.inventory.size():
			var slot: Dictionary = GameState.inventory[k]
			b.setup(str(slot["id"]), int(slot["qty"]))
			b.used.connect(_on_item_pressed)
			var sid: String = str(slot["id"])
			if _mode == Mode.COMBAT and not GameState.is_equipment(sid) and not ItemEffectsScript.is_usable(GameState.get_item(sid), true):
				b.modulate = Color(1, 1, 1, 0.35)
		else:
			b.setup("", 0)
		_inventory.add_child(b)


func _on_item_pressed(item_id: String) -> void:
	if GameState.is_equipment(item_id):
		# Click = equip on the selected hero (or drag it onto a slot / a hero). In a fight
		# only the hero whose turn it is can change gear, and it spends the turn.
		var target: Dictionary = _viewed_hero if not _viewed_hero.is_empty() else _first_living_hero()
		if _mode == Mode.COMBAT:
			if not _pending.is_empty():
				return
			target = GameState.equip_turn_hero
			if target.is_empty():
				_log_line("Ahora no: espera el turno del héroe que se va a cambiar.", "888888")
				return
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
	if GameState.hunger_due():
		_open_hunger()
		return
	_resolve_room()


## What the room holds, after any hunger stop.
func _resolve_room() -> void:
	var nd: Dictionary = GameState.current_node()
	var nid: String = GameState.current_node_id
	# The roaming mini-boss (P2-05) is waiting here, cleared room or not.
	if GameState.roaming_here():
		_narrate(str(GameState.mission_region_data.get("generator", {}).get("roaming", {}).get("encounter_text", "Algo les cierra el paso.")))
		GameState.build_roaming_context(nid)
		_start_combat_from_context(nid)
		return
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
	flee.tooltip_text = "Volver a la hacienda sin completar el objetivo. La cuadrilla se lleva los colones y artículos que ya encontró; no hay paga del objetivo ni experiencia de resolución."
	flee.pressed.connect(_on_flee_pressed)
	_skills.add_child(flee)
	var snuff := Button.new()
	snuff.text = "Apagar la candela (-%d Luz)" % BalanceScript.int_of("light.snuff")
	snuff.tooltip_text = "Bajar la Luz a propósito: más botín, pero más peligro y más estrés."
	snuff.disabled = GameState.mission_light <= 0
	snuff.pressed.connect(_on_snuff_pressed)
	_skills.add_child(snuff)


func _on_snuff_pressed() -> void:
	if _mode != Mode.EXPLORE:
		return
	var lost: int = GameState.snuff_light()
	if lost > 0:
		_narrate("Bajan la mecha de la candela (-%d Luz). Ahora: %s." % [lost, LightSystemScript.tier_name(GameState.mission_light)])
	_refresh_all()
	_show_explore_actions()


func _on_flee_pressed() -> void:
	if _mode != Mode.EXPLORE:
		return
	_end_expedition("flee", "La cuadrilla vuelve a la hacienda sin terminar el trabajo. Se llevan lo que ya habían encontrado; la paga del objetivo y la experiencia se quedan en el sótano.")


# --- Travel hunger (P1-18) -------------------------------------------------------------

## DD hunger check: time to eat, one gallo pinto per living hero; then the room resolves.
func _open_hunger() -> void:
	var need: int = CampingSystemScript.travel_meal_cost(GameState.party)
	var food: int = GameState.item_count("gallo_pinto")
	_open_event("Hambre", "La cuadrilla tiene hambre. Comer cuesta %d gallo pinto (uno por héroe); llevan %d. Quien no come lo va a sentir." % [need, food])
	if food >= need:
		_event_button("Comer (%d gallo pinto)" % need, _hunger_meal.bind(need))
	elif food > 0:
		_event_button("Repartir lo que hay (%d de %d comen)" % [food, need], _hunger_meal.bind(food))
	_event_button("Aguantar el hambre", _hunger_meal.bind(0))


func _hunger_meal(fed: int) -> void:
	for l in GameState.travel_meal(fed):
		_log_line(l, "cc7744" if fed < CampingSystemScript.travel_meal_cost(GameState.party) else "ffd27a")
	_close_event()
	_mode = Mode.EXPLORE
	_refresh_all()
	_resolve_room()


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


func _resolve_event(text: String, lines: PackedStringArray = PackedStringArray()) -> void:
	var title: String = _event_title.text
	GameState.mark_node_cleared(GameState.current_node_id)
	_close_event()
	_mode = Mode.EXPLORE
	_narrate(text)
	_refresh_all()
	if not _check_wipe():
		_show_result(title, text, lines)


## Good (1), bad (-1) or neutral (0) for one result line. Stress and light read the other way
## round from PV: "estrés -6" is good news, "Luz -25" bad.
static func _result_tone(line: String) -> int:
	var t: String = line.to_lower()
	var re := RegEx.create_from_string("estrés\\s*([+-]\\d+)")
	var m := re.search(t)
	if m != null:
		return -1 if m.get_string(1).begins_with("+") else 1
	re = RegEx.create_from_string("luz\\s*([+-]\\d+)")
	m = re.search(t)
	if m != null:
		return 1 if m.get_string(1).begins_with("+") else -1
	for bad in ["pierde", "no cabe", "emboscada", "quebranto", "muere", "cae", "al borde", "sangr", "envenen", "atarant", "susto", "salado", "fichado"]:
		if t.contains(bad):
			return -1
	for good in ["+", "encuentran", "recupera", "desarma", "virtud", "ya no está", "limpio"]:
		if t.contains(good):
			return 1
	return 0


## The result of an event as a card dialog: what happened, then each effect (bad ones in
## red). Exploring waits until it is closed; `then` runs after (an ambush starts its fight).
func _show_result(title: String, text: String, lines: PackedStringArray, then: Callable = Callable()) -> void:
	_card_dialog(title if title != "" else "Resultado", func(col: VBoxContainer):
		col.add_child(CardScript.label(text, 15, CardScript.TEXT, true, 460.0))
		if not lines.is_empty():
			col.add_child(CardScript.rule())
			col.add_child(CardScript.section("Resultado"))
			for l in lines:
				col.add_child(_tone_label(l))
	, then)


## One result line, green ▲ / red ▼ / neutral by what it means (_result_tone).
func _tone_label(l: String) -> Label:
	var tone: int = _result_tone(l)
	return CardScript.label(("▲ " if tone > 0 else ("▼ " if tone < 0 else "• ")) + l.strip_edges(), 14,
		CardScript.GOOD if tone > 0 else (CardScript.BAD if tone < 0 else CardScript.TEXT), true, 460.0)


## A card dialog in the game's style (title, `fill` builds the column). Exploring waits until
## it is closed; `then` runs after. Off in headless -s runs (results_modal).
func _card_dialog(title: String, fill: Callable, then: Callable = Callable()) -> void:
	if not results_modal:
		if then.is_valid():
			then.call()
		return
	var dlg := AcceptDialog.new()
	dlg.title = title
	dlg.ok_button_text = "Continuar"
	dlg.exclusive = true
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(460, 0)
	col.add_theme_constant_override("separation", 8)
	dlg.add_child(col)
	fill.call(col)
	var was: int = _mode
	_mode = Mode.EVENT
	_result_dialog = dlg
	dlg.visibility_changed.connect(func():
		if dlg.visible:
			return
		_result_dialog = null
		dlg.queue_free()
		if _mode == Mode.EVENT:
			_mode = was
		if then.is_valid():
			then.call()
	)
	add_child(dlg)
	dlg.popup_centered()
	await get_tree().process_frame
	if is_instance_valid(dlg):
		dlg.reset_size()
		dlg.popup_centered()


## After a won fight (P5-10, owner 2026-11-19): the loot (colones, drops, what did not fit)
## and how each hero came out of it (PV, stress, fallen, new Quebranto / Virtud).
func _show_battle_result(title: String, pay: int, drops: Dictionary, then: Callable = Callable()) -> void:
	_card_dialog(title, func(col: VBoxContainer):
		col.add_child(CardScript.section("Botín"))
		var any: bool = false
		if pay > 0:
			col.add_child(_tone_label("+%d colones" % pay))
			any = true
		if int(drops.get("reliquias", 0)) > 0:
			col.add_child(_tone_label("+%d Reliquia del Abuelo" % int(drops["reliquias"])))
			any = true
		for id in drops.get("got", []):
			# Hover the row for the item's card, as in the alforja (owner 2026-11-19).
			var hover = ItemHoverScript.new()
			hover.setup(str(id))
			hover.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
			hover.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(CardScript.picture("res://assets/items/%s.png" % id, 40.0))
			var nm := CardScript.label(str(GameState.get_item(str(id)).get("name", id)), 15, CardScript.GOOD, false)
			nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(nm)
			hover.add_child(row)
			col.add_child(hover)
			any = true
		for id in drops.get("lost", []):
			col.add_child(_tone_label("%s: no cabe en la alforja" % GameState.get_item(str(id)).get("name", id)))
			any = true
		if not any:
			col.add_child(CardScript.label("Nada esta vez.", 13, CardScript.MUTED, false))
		col.add_child(CardScript.rule())
		col.add_child(CardScript.section("La cuadrilla"))
		for h in GameState.party:
			var b: Dictionary = _battle_start.get(int(h.get("uid", 0)), {})
			if b.is_empty() or bool(b.get("dead", false)):
				continue
			var who: String = str(h.get("name", "?"))
			if bool(h.get("dead", false)):
				col.add_child(_tone_label("%s cae en la pelea" % who))
				continue
			var parts: PackedStringArray = PackedStringArray()
			var dhp: int = int(h.get("hp", 0)) - int(b["hp"])
			var dst: int = int(h.get("stress", 0)) - int(b["stress"])
			if dhp != 0:
				parts.append("PV %d → %d" % [int(b["hp"]), int(h.get("hp", 0))])
			if dst != 0:
				parts.append("estrés %+d" % dst)
			var line: String = "%s: %s" % [who, ", ".join(parts) if not parts.is_empty() else "sin un rasguño"]
			var lbl := CardScript.label(line, 14, CardScript.BAD if (dhp < 0 or dst > 0) else (CardScript.GOOD if parts.is_empty() or dhp > 0 or dst < 0 else CardScript.TEXT), true, 460.0)
			col.add_child(lbl)
			var aff: String = str(h.get("affliction_id", ""))
			if aff != "" and aff != str(b["aff"]):
				col.add_child(_tone_label("%s: Quebranto — %s" % [who, StressSystemScript.affliction_name(aff)]))
			var vir: String = str(h.get("virtud_id", ""))
			if vir != "" and vir != str(b["vir"]):
				col.add_child(_tone_label("%s: +Virtud — %s" % [who, StressSystemScript.virtud_name(vir)]))
	, then)


## A trap or curio can kill (P1-16): with nobody left standing the expedition is lost.
func _check_wipe() -> bool:
	if GameState.living_party_count() > 0:
		return false
	_end_expedition("defeat", "La cuadrilla ha caído. La hacienda guarda silencio.")
	return true


## Trap rooms (P2-01, doc 07 §4; data/traps.json): disarm it, or cross carefully and spend Luz.
func _open_trap() -> void:
	var trap: Dictionary = TrapRulesScript.get_trap(str(GameState.current_node().get("trap_id", "")))
	if trap.is_empty():
		trap = TrapRulesScript.get_trap(str(TrapRulesScript.data().get("traps", [{}])[0].get("id", "")))
	var chance: int = TrapRulesScript.disarm_chance(trap, GameState.party, GameState.mission_light)
	var spotter: Dictionary = TrapRulesScript.spotter(GameState.party)
	var careful_light: int = TrapRulesScript.num("careful_light")
	var careful_pct: int = TrapRulesScript.num("careful_trigger_pct")
	# Owner 2026-11-22: event choices never show odds or outcomes; the result shows after the pick.
	_open_event(str(trap.get("name", "Trampa")), "%s

%s la vio primero." % [trap.get("text", ""), spotter.get("name", "Alguien")])
	_event_button("Desarmar", func():
		if randi() % 100 < chance:
			var relief: int = TrapRulesScript.num("disarm_relief")
			var got: PackedStringArray = PackedStringArray(["%s: -%d estrés" % [spotter.get("name", "Alguien"), relief]])
			for l in StressSystemScript.add_stress(spotter, -relief):
				_log_line(l, "88bb88")
				got.append(l)
			_resolve_event("%s desarma la trampa. ¡Qué nivel!" % spotter.get("name", "Alguien"), got)
		else:
			_spring_trap(trap)
	)
	_event_button("Pasar con cuidado", func():
		GameState.mission_light = maxi(GameState.mission_light - careful_light, 0)
		if randi() % 100 < careful_pct:
			_spring_trap(trap)
		else:
			_resolve_event("Pasan despacio, tanteando cada paso. La trampa no salta.", PackedStringArray(["Luz -%d" % careful_light]))
	)


func _spring_trap(trap: Dictionary) -> void:
	_apply_outcome(str(trap.get("fail_text", "¡La trampa salta!")), trap.get("effects", {}))


func _open_curio() -> void:
	# P2-10: a choice event out of its moment turns into its fallback curio.
	var rc: Dictionary = GameState.room_curio()
	var curio: Dictionary = rc["curio"]
	if str(rc["note"]) != "":
		_narrate(str(rc["note"]))
		_room_label.text = "%s — %s" % [GameState.mission_region_data.get("name", ""), GameState.current_node().get("label", "")]
	if curio.is_empty():
		_open_event("Lugar extraño", "%s. Algo te llama." % GameState.current_node().get("label", ""))
		_event_button("Dejarlo", func(): _resolve_event("Siguen adelante sin mirar atrás."))
		return
	_open_event(str(curio.get("name", "Lugar extraño")), str(curio.get("text", "")))
	for opt in GameState.curio_options(curio):
		_event_button(str(opt["label"]), func():
			var o: Dictionary = GameState.pick_curio_option(opt)
			if o.is_empty():
				_resolve_event("No pasa nada.")
			else:
				_curio_result(str(o.get("text", "")), o)
		)
		if not bool(opt["enabled"]):
			var b: Button = _event_actions.get_child(_event_actions.get_child_count() - 1)
			b.disabled = true
			b.tooltip_text = str(opt["reason"])
	if GameState.curio_can_leave(curio):
		_event_button("Dejarlo", func(): _resolve_event("Siguen adelante sin mirar atrás."))


func _curio_result(text: String, outcome: Dictionary) -> void:
	_apply_outcome(text, outcome)


## An event outcome (curio or trap): effects, then either an ambush fight or the room clears.
func _apply_outcome(text: String, outcome: Dictionary) -> void:
	var lines: PackedStringArray = GameState.apply_event_outcome(outcome)
	for l in lines:
		_log_line(l, "cc9944")
	if _check_wipe():
		return
	var amb = outcome.get("ambush", null)
	if amb is Array or (amb is bool and amb):
		var title: String = _event_title.text
		_close_event()
		_narrate(text)
		GameState.ledger_add("ambushes")
		GameState.build_ambush_context(GameState.current_node_id, amb if amb is Array else [])
		lines.append("¡Emboscada!")
		_show_result(title, text, lines, func(): _start_combat_from_context(GameState.current_node_id))
		return
	_resolve_event(text, lines)


func _open_camp() -> void:
	var nid: String = GameState.current_node_id
	if not GameState.can_camp_at(nid):
		_open_event("Fogata de trocha", "No queda leña para acampar. Solo pueden calentarse las manos.")
		var warm: int = int(BalanceScript.req(CampingSystemScript.data(), "no_firewood_relief", "camp_skills.json"))
		_event_button("Calentarse", func():
			_party_stress(-warm)
			_resolve_event("Un respiro corto. -%d estrés." % warm)
		)
		return
	_open_event("Fogata de trocha", "Leña: %d. Acampar gasta una: comen, usan habilidades de campamento (%d puntos de respiro) y duermen. La Luz vuelve a %d, pero la noche puede traer una emboscada." % [
		GameState.mission_firewood, CampingSystemScript.respite_points(), GameState.light_max()])
	_event_button("Acampar", _camp_begin)
	_event_button("Seguir sin acampar", func():
		# Not cleared: the fogata stays available if they come back.
		_close_event()
		_mode = Mode.EXPLORE
		_narrate("Guardan la leña para más adelante.")
		_refresh_all()
	)


func _camp_begin() -> void:
	GameState.mission_firewood -= 1
	GameState.camped_node_ids.append(GameState.current_node_id)
	GameState.ledger_add("camps")
	_camp_respite = CampingSystemScript.respite_points()
	_camp_used = []
	_camp_watch = false
	_camp_hands = {}
	for h in CampingSystemScript.living(GameState.party):
		_camp_hands[int(h.get("uid", 0))] = CampingSystemScript.deal_hand(h, GameState.camp_extra_class_skills())
	_log_line("Encienden la fogata (-1 leña).", "ffd27a")
	_camp_meal()


func _camp_meal() -> void:
	var food: int = GameState.item_count("gallo_pinto")
	_open_event("Fogata — la comida", "¿Cuánto comen? Tienen %d gallo pinto. La cuenta es para 4 héroes; baja si son menos." % food)
	for meal in CampingSystemScript.meals():
		var cost: int = CampingSystemScript.meal_cost(meal, GameState.party)
		_event_button("%s (%d gallo pinto): %s" % [meal.get("name", "?"), cost, CampingSystemScript.meal_summary(meal)], func():
			if GameState.item_count("gallo_pinto") < cost:
				_camp_meal()
				return
			if cost > 0:
				GameState.remove_item("gallo_pinto", cost)
			# Any camp meal (even a fast) is the party's meal: the hunger count restarts.
			GameState.moves_since_meal = 0
			_log_line("%s. %s" % [meal.get("name", ""), meal.get("text", "")], "ffd27a")
			for l in CampingSystemScript.apply_meal(meal, GameState.party):
				_log_line(l, "cc7744")
			_refresh_all()
			_camp_respite_menu()
		)
		# The new button is the last child (old ones are only queued for deletion).
		_event_actions.get_child(_event_actions.get_child_count() - 1).disabled = cost > food


## Respite: every living hero's camp skills; ally skills then ask for a companion.
func _camp_respite_menu() -> void:
	_open_event("Fogata — respiro: %d puntos" % _camp_respite,
		"Cada héroe puede usar cada una de sus habilidades una vez. Las de su oficio cambian en cada fogata.%s Pasa el mouse por una habilidad para ver qué hace." % (
			" Alguien hace guardia: no habrá emboscada." if _camp_watch else ""))
	var rest := Button.new()
	rest.text = "Dormir"
	rest.tooltip_text = "Terminar el campamento (los puntos que sobren se pierden)."
	rest.pressed.connect(_camp_sleep)
	_event_actions.add_child(rest)
	# One row per hero: name, then tonight's camp skills (cost in brackets; hover for the effect).
	for h in CampingSystemScript.living(GameState.party):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		var who := Label.new()
		who.text = str(h.get("name", "?"))
		who.custom_minimum_size = Vector2(96, 0)
		who.add_theme_font_size_override("font_size", 13)
		who.add_theme_color_override("font_color", Color(0.95, 0.82, 0.55))
		row.add_child(who)
		for sk in camp_hand(h):
			var b := Button.new()
			b.text = "%s (%d)" % [sk.get("name", "?"), int(sk.get("cost", 0))]
			b.add_theme_font_size_override("font_size", 13)
			b.tooltip_text = "%s — %s" % [h.get("name", "?"), sk.get("desc", "")]
			b.disabled = not CampingSystemScript.can_use(h, sk, GameState.party, _camp_respite, _camp_used)
			b.pressed.connect(_camp_pick.bind(h, sk))
			row.add_child(b)
		_event_actions.add_child(row)


## Tonight's camp skills for this hero (dealt when the fogata is lit).
func camp_hand(h: Dictionary) -> Array:
	var uid: int = int(h.get("uid", 0))
	if not _camp_hands.has(uid):
		_camp_hands[uid] = CampingSystemScript.deal_hand(h, GameState.camp_extra_class_skills())
	return CampingSystemScript.hand_skills(_camp_hands[uid])


func _camp_pick(user: Dictionary, sk: Dictionary) -> void:
	if str(sk.get("target", "")) != "ally":
		_camp_use(user, sk, {})
		return
	_open_event("Fogata — %s" % sk.get("name", "?"), "%s: ¿a quién? %s" % [user.get("name", "?"), sk.get("desc", "")])
	for h in CampingSystemScript.living(GameState.party):
		if is_same(h, user):
			continue
		_event_button("%s (PV %d/%d, estrés %d)" % [h.get("name", "?"), int(h.get("hp", 0)), int(h.get("hp_max", 0)), int(h.get("stress", 0))],
			_camp_use.bind(user, sk, h))
	_event_button("Cancelar", _camp_respite_menu)


func _camp_use(user: Dictionary, sk: Dictionary, ally: Dictionary) -> void:
	if not CampingSystemScript.can_use(user, sk, GameState.party, _camp_respite, _camp_used):
		_camp_respite_menu()
		return
	_camp_respite -= int(sk.get("cost", 0))
	CampingSystemScript.mark_used(user, sk, _camp_used)
	var res: Dictionary = CampingSystemScript.use_skill(user, sk, GameState.party, ally)
	for l in res["logs"]:
		_log_line(l, "ffd27a")
	_camp_watch = _camp_watch or bool(res["prevent_ambush"])
	_refresh_all()
	_camp_respite_menu()


func _camp_sleep() -> void:
	var chance: int = CampingSystemScript.ambush_chance(GameState.mission_light, _camp_watch, GameState.party)
	GameState.mission_light = GameState.light_max()
	GameState.mark_node_cleared(GameState.current_node_id)
	if randi() % 100 < chance:
		_close_event()
		_log_line("¡Emboscada nocturna! Algo sale de la oscuridad.", "cc4444")
		GameState.ledger_add("ambushes")
		GameState.build_ambush_context(GameState.current_node_id)
		_start_combat_from_context(GameState.current_node_id)
		return
	_resolve_event("La noche pasa tranquila. Amanece y la Luz vuelve a %d." % GameState.light_max())


func _party_stress(delta: int) -> void:
	for h in GameState.party:
		if h is Dictionary and not h.get("dead", false):
			for l in StressSystemScript.add_stress(h, delta):
				_log_line(l, "cc7744")


# --- Combat -----------------------------------------------------------------------

func _start_combat(node_id: String) -> void:
	GameState.build_combat_context_for_node(node_id)
	_start_combat_from_context(node_id)


func _start_combat_from_context(node_id: String) -> void:
	var ctx: Dictionary = GameState.combat_context
	var squad: Array = ctx.get("enemies", [])
	if squad.is_empty():
		return
	_mode = Mode.COMBAT
	_combat_node_id = node_id
	# For the battle result card (P5-10): how each hero walked in.
	_battle_start = {}
	for h in GameState.party:
		_battle_start[int(h.get("uid", 0))] = {"hp": int(h.get("hp", 0)), "stress": int(h.get("stress", 0)), "dead": bool(h.get("dead", false)),
			"aff": str(h.get("affliction_id", "")), "vir": str(h.get("virtud_id", ""))}
	_set_background(BG_COMBAT)
	_clear_skills()
	_turn_label.text = ""
	_spawn_enemies(squad)
	_selected_enemy = {}
	GameState.equip_locked = true
	_combat_is_ambush = bool(ctx.get("is_ambush", false))
	GameState.equip_turn_hero = {}
	# Luz tiers (P1-17): in the dark the party may be caught off guard; in good light they
	# may catch the enemies instead.
	var surprise: String = str(ctx.get("surprise", ""))
	var note: String = ""
	if surprise == "party":
		note = "¡Los agarraron desprevenidos en la %s!" % LightSystemScript.tier_name(GameState.mission_light).to_lower()
	elif surprise == "enemies":
		note = "¡La cuadrilla los agarra desprevenidos!"
	_combat.enemy_spawner = _spawn_enemy_unit
	_combat.start(GameState.party, squad, _hero_units, _enemy_units,
		bool(ctx.get("is_elite", false)), bool(ctx.get("is_boss", false)), _combat_is_ambush or surprise == "party",
		surprise == "enemies", note)


func _update_turn_label() -> void:
	var hero: Dictionary = _combat.active_hero()
	if hero.is_empty():
		return
	_turn_label.text = "Turno de %s — habilidad, artículo de la alforja, o cambiar equipo (pierde el turno)." % hero.get("name", "?")


# --- Choosing a target after pressing a skill or item -----------------------------

## Units the player may click for `action` (default: the pending one): enemies in the
## skill's reach (target_ranks; hidden ones only if nobody else is), any living hero for
## ally skills/items, or the acting hero's neighbours for "Moverse".
func _living_units(heroes: bool, action: Dictionary = {}) -> Array:
	if action.is_empty():
		action = _pending
	if heroes:
		if bool(action.get("move", false)):
			var near: Array = _combat.move_options(_combat.active_hero())
			return _hero_units.filter(func(u): return near.has(u.data))
		# A heal can't land on an Embargado ally (P2-04), so they are not a choice (owner 2026-11-19).
		var heals: bool = _action_heals(action)
		return _hero_units.filter(func(u): return not u.is_dead() and not (heals and StatusEffectsScript.has(u.data, "embargado")))
	var open: Array = _combat.targets_for(action["skill"]) if action.has("skill") else _combat.targetable_enemies()
	return _enemy_units.filter(func(u): return not u.is_dead() and open.has(u.data))


## The skill or item heals PV (Embargado allies can't be picked for it).
static func _action_heals(action: Dictionary) -> bool:
	if action.has("skill"):
		return int(action["skill"].get("heal_min", 0)) > 0
	if action.has("item"):
		return int(GameState.get_item(str(action["item"])).get("effects", {}).get("heal", 0)) > 0
	return false


## Single-target skills/items ask for a click on an enemy (or ally); with one valid
## choice they go straight through. Self/party ones run at once.
func _begin_pending(action: Dictionary) -> void:
	GameState.equip_turn_hero = {}
	var side: String = str(action.get("side", ""))
	if side == "":
		_execute_pending({}, action)
		return
	var options: Array = _living_units(side == "ally", action)
	if options.is_empty() and side == "ally" and _action_heals(action):
		_log_line("Nadie se puede curar: los heridos están embargados.", "c0a060")
		return
	if options.size() <= 1 and not bool(action.get("move", false)):
		_execute_pending(options[0].data if not options.is_empty() else {}, action)
		return
	if side == "enemy" and not _selected_enemy.is_empty():
		for u in options:
			if is_same(u.data, _selected_enemy):
				_execute_pending(_selected_enemy, action)
				return
	_pending = action
	_clear_skills()
	if bool(action.get("move", false)):
		_turn_label.text = "Moverse: elige con quién cambiar de lugar (clic en un héroe al lado; Esc o Cancelar para volver)."
	else:
		var what: String = str(action["skill"].get("name", "")) if action.has("skill") else str(GameState.get_item(str(action["item"])).get("name", ""))
		_turn_label.text = "%s: elige a quién %s (clic en %s; Esc o Cancelar para volver)." % [
			what, "atacar" if side == "enemy" else "ayudar", "un enemigo" if side == "enemy" else "un héroe"]
	for u in options:
		u.set_selectable(true)
	# Only what this skill can reach glows: the current-target marker steps aside meanwhile.
	for u in _enemy_units:
		if not options.has(u):
			u.set_targeted(false)
	var cancel := Button.new()
	cancel.text = "Cancelar"
	cancel.pressed.connect(_cancel_pending)
	_skills.add_child(cancel)


func _clear_selectable() -> void:
	for u in _hero_units + _enemy_units:
		u.set_selectable(false)
	if _mode == Mode.COMBAT and _combat.is_running():
		_combat._refresh_markers()


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
	_lock_skills()
	var side: String = str(action.get("side", ""))
	if side == "enemy" and not target.is_empty():
		_selected_enemy = target
		_combat.set_target(target)
	var ally: Dictionary = target if side == "ally" else {}
	if bool(action.get("move", false)):
		_combat.move_hero(target)
	elif action.has("skill"):
		_combat.use_skill(action["skill"], ally)
	else:
		_combat.use_item(str(action["item"]), ally)


func _on_hero_turn(hero: Dictionary) -> void:
	_view_hero(hero)
	_pending = {}
	_clear_selectable()
	_bar_begin()
	_update_turn_label()
	GameState.equip_turn_hero = hero
	_turn_equipment = _equipment_of(hero)
	# One row of icons: the hero's skills, then Alforja, Moverse, Guardia, Retirada and Pasar.
	# Hover = name + description. Skills out of reach from this position are greyed out.
	# The buttons are reused from turn to turn (P4-16): an open tooltip stays up while the
	# other units act.
	var blocked: int = 0
	for sid in hero.get("skill_ids", []):
		var sk: Dictionary = GameState.hero_skill(hero, str(sid))
		if sk.is_empty():
			continue
		var rank: int = int(sk.get("rank", 1))
		var side: String = {"enemy": "enemy", "ally": "ally"}.get(str(sk.get("target", "enemy" if str(sk.get("kind", "")) == "attack" else "self")), "")
		var usable: bool = _combat.skill_usable(hero, sk)
		_bar_button(str(sid), str(sk.get("kind", "attack")), "%s (rango %d)" % [sk.get("name", sid), rank], _skill_tooltip(sk),
			func(): _begin_pending({"side": side, "skill": sk}), usable, rank, SkillRanksScript.max_rank())
		if not usable:
			blocked += 1
	_bar_button("_items", "item", "Alforja", "Usar un artículo (agua de pipa, venda, café...). Usarlo gasta el turno.",
		_show_combat_items.bind(hero))
	_bar_button("_move", "guard", "Moverse", "Cambia de lugar con el héroe de al lado (adelante o atrás). Gasta el turno.",
		func(): _begin_pending({"side": "ally", "move": true}), not _combat.move_options(hero).is_empty())
	var act := func(what: Callable) -> Callable:
		return func():
			GameState.equip_turn_hero = {}
			_lock_skills()
			what.call()
	_bar_button("_guard", "guard", "Guardia", "Se cubre: recibe la mitad del daño físico hasta su próximo turno.",
		act.call(_combat.guard))
	_bar_button("_retreat", "pass", "Retirada", "Sacar a la cuadrilla de la pelea: %d%% de salir (si falla, se pierde el turno). Todos ganan %d de estrés y vuelven a la sala anterior; los enemigos se quedan esperando.%s" % [
		int(round(BalanceScript.num("combat.retreat_chance") * 100.0)), BalanceScript.int_of("combat.retreat_stress"),
		"" if _combat.can_retreat() else " De una emboscada no hay retirada."],
		act.call(_combat.retreat), _combat.can_retreat())
	_bar_button("_pass", "pass", "Pasar", "No hace nada este turno.", act.call(_combat.pass_turn))
	_bar_end()
	if blocked > 0:
		_turn_label.text += " Desde la posición %d, %s." % [_combat.position_of(hero),
			"una habilidad no alcanza" if blocked == 1 else "%d habilidades no alcanzan" % blocked]
	_refresh_all()


## The combat action bar (P4-16) keeps its SkillButtons between turns so that the tooltip
## under the mouse is never freed: `_bar_begin` starts a fill, `_bar_button` reconfigures
## the next button in place (or adds one), `_bar_end` drops the extras. Anything else in
## the row (Cancelar, the alforja's items, exploring buttons) makes it start from scratch.
var _bar_slot: int = 0


func _bar_kids() -> Array:
	return _skills.get_children().filter(func(c): return not c.is_queued_for_deletion())


func _bar_begin() -> void:
	_bar_slot = 0
	if _bar_kids().any(func(c): return not (c is SkillButtonScript)):
		_clear_skills()


func _bar_button(icon_id: String, kind: String, title: String, body: String, action: Callable,
		enabled: bool = true, rank: int = 0, max_rank: int = 5) -> void:
	var kids: Array = _bar_kids()
	var b
	if _bar_slot < kids.size():
		b = kids[_bar_slot]
	else:
		b = SkillButtonScript.new()
		_skills.add_child(b)
	_bar_slot += 1
	b.setup(icon_id, kind, title, body, rank, max_rank)
	b.action = action
	b.disabled = not enabled
	b.modulate = Color.WHITE if enabled else Color(1, 1, 1, 0.35)


func _bar_end() -> void:
	var kids: Array = _bar_kids()
	for i in range(_bar_slot, kids.size()):
		kids[i].queue_free()
	# Nine icons don't fit the row at full size (P5-04 added Retirada): make them a bit smaller.
	if _bar_slot > ACTION_ROW_FULL:
		for i in _bar_slot:
			kids[i].custom_minimum_size = ACTION_ICON_SMALL


## A hero has acted: the bar stays (so its tooltips do) but nothing can be pressed until the
## next hero's turn. A bar that isn't the skill row (Cancelar, the alforja) is cleared.
func _lock_skills() -> void:
	if _bar_kids().any(func(c): return not (c is SkillButtonScript)):
		_clear_skills()
		return
	for c in _bar_kids():
		c.disabled = true
		if c.modulate.a > 0.6:
			c.modulate = Color(1, 1, 1, 0.6)


## Action bar → Alforja: the consumables usable in combat, as icons with counts.
## Picking one asks for a target (if it needs one) and spends the hero's turn.
func _show_combat_items(hero: Dictionary) -> void:
	if _combat.active_hero().is_empty() or not _pending.is_empty():
		return
	_clear_skills()
	var shown: int = 0
	for slot in GameState.inventory:
		var id: String = str(slot["id"])
		var it: Dictionary = GameState.get_item(id)
		if GameState.is_equipment(id) or not ItemEffectsScript.is_usable(it, true):
			continue
		var b = InventorySlotScript.new()
		b.setup(id, int(slot["qty"]))
		b.custom_minimum_size = Vector2(52, 52)
		b.tooltip_note = "Usarlo gasta el turno."
		b.used.connect(_on_item_pressed)
		_skills.add_child(b)
		shown += 1
	if shown == 0:
		_log_line("La alforja no tiene nada que sirva en combate.", "999999")
	var back := Button.new()
	back.text = "Volver"
	back.pressed.connect(func(): _on_hero_turn(hero))
	_skills.add_child(back)
	_turn_label.text = "Alforja de %s: elige un artículo (gasta el turno)." % hero.get("name", "?")


func _skill_tooltip(sk: Dictionary) -> String:
	return SkillButtonScript.body_for(sk)


func _clear_skills() -> void:
	for c in _skills.get_children():
		c.queue_free()


## The party left the fight (P5-04): back to the room they came from. The room they fled
## stays as it was, so walking in again starts the fight over.
func _on_combat_fled() -> void:
	GameState.equip_locked = false
	GameState.equip_turn_hero = {}
	_selected_enemy = {}
	_hide_enemy_info()
	_pending = {}
	_clear_selectable()
	GameState.retreat_to_previous_room()
	_clear_enemies()
	for u in _hero_units:
		u.set_active(false)
	_set_background(BG_EXPLORE)
	_mode = Mode.EXPLORE
	_actor_label.text = ""
	var nd: Dictionary = GameState.current_node()
	_room_label.text = "%s — %s" % [GameState.mission_region_data.get("name", ""), nd.get("label", GameState.current_node_id)]
	_show_explore_actions()
	_narrate("La cuadrilla retrocede a %s. Lo que dejaron atrás sigue ahí." % nd.get("label", "la sala anterior"))
	_view_hero(_viewed_hero if not _viewed_hero.get("dead", false) else _first_living_hero())
	_refresh_all()


func _on_combat_over(victory: bool) -> void:
	GameState.equip_locked = false
	GameState.equip_turn_hero = {}
	_selected_enemy = {}
	_hide_enemy_info()
	_pending = {}
	_clear_selectable()
	var nd: Dictionary = GameState.mission_nodes_index.get(_combat_node_id, {})
	if not victory:
		_end_expedition("defeat", "La cuadrilla ha caído. La hacienda guarda silencio.")
		return
	var roaming: bool = bool(GameState.combat_context.get("is_roaming", false))
	if not roaming or GameState.roaming_clears_room(_combat_node_id):
		GameState.mark_node_cleared(_combat_node_id)
	GameState.ledger_add("fights")
	GameState.note_fight_won()
	var won_pay: int = 0
	var won_rel: int = 0
	if roaming:
		# Roaming mini-boss (P2-05): a bounty if it died, nothing if it ran off.
		var fled: bool = GameState.combat_context.get("enemies", []).any(func(e): return bool(e.get("fled", false)))
		for l in GameState.finish_roaming(not fled):
			_log_line(l, "66aa66" if not fled else "cc9944")
	elif _combat_is_ambush:
		var at_camp: bool = str(nd.get("type", "")) == "camp"
		_log_line("Repelieron la emboscada.%s" % (" Amanece." if at_camp else ""), "66aa66")
	else:
		var pay: int = GameState.combat_reward(_combat_node_id)
		won_pay = pay
		GameState.colones += pay
		GameState.ledger_add("loot_colones", pay)
		if bool(nd.get("is_boss", false)):
			GameState.ledger_add("bosses")
		elif bool(nd.get("is_elite", false)):
			GameState.ledger_add("elites")
		_log_line("Botín: +%d colones." % pay, "66aa66")
		if bool(nd.get("is_elite", false)) and not bool(nd.get("is_boss", false)):
			var rel: String = GameState.roll_elite_reliquia()
			if rel != "":
				won_rel = 1
				_log_line(rel, "66aa66")
	# Enemy drops (P5-10): logged; the boss's go to the expedition's victory screen.
	var drops: Dictionary = GameState.roll_drops(_combat.enemies)
	drops["reliquias"] = won_rel
	for id in drops["got"]:
		_log_line("Botín: %s." % GameState.get_item(str(id)).get("name", id), "66aa66")
	for id in drops["lost"]:
		_log_line("%s no cabe en la alforja." % GameState.get_item(str(id)).get("name", id), "cc9944")
	if not _combat_is_ambush and (bool(nd.get("is_boss", false)) or _combat_node_id == GameState.objective_node_id):
		GameState.complete_mission()
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
	# The battle card (P5-10); after a roaming mini-boss in a curio or trap room, the room's
	# own event is still there once it is closed.
	var after := func():
		if roaming and not GameState.is_node_cleared(_combat_node_id):
			_resolve_room()
	_show_battle_result("¡Victoria!", won_pay, drops, after)


func _end_expedition(reason: String, text: String) -> void:
	GameState.log_mission_end(reason)
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
