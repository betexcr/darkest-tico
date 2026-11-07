extends Control

## Hacienda hub: Pulpería (items), Iglesia (stress), Terminal de Buses (recruiting),
## roster with party selection/order and EBAIS healing, and expedition start.

signal start_mission_requested

const InventorySlotScript := preload("res://scripts/ui/inventory_slot.gd")
const EquipSlotScript := preload("res://scripts/ui/equip_slot.gd")

@onready var _bg: TextureRect = $BgTexture
@onready var _gold: Label = $Columns/Left/VBox/InfoRow/GoldLabel
@onready var _week: Label = $Columns/Left/VBox/InfoRow/WeekLabel
@onready var _region_option: OptionButton = $Columns/Left/VBox/RegionRow/RegionOption
@onready var _shop_grid: GridContainer = $Columns/Left/VBox/ShopScroll/ShopGrid
@onready var _btn_sell: Button = $Columns/Left/VBox/ShopHead/BtnSell
@onready var _equip_title: Label = $Columns/Right/VBox/EquipTitle
@onready var _equip_row: HBoxContainer = $Columns/Right/VBox/EquipRow
@onready var _pack_grid: GridContainer = $Columns/Right/VBox/PackGrid
@onready var _recruit_box: VBoxContainer = $Columns/Left/VBox/RecruitBox
@onready var _hub_status: Label = $Columns/Left/VBox/HubStatus
@onready var _roster_title: Label = $Columns/Right/VBox/RosterTitle
@onready var _roster_list: VBoxContainer = $Columns/Right/VBox/Scroll/RosterList
@onready var _btn_start: Button = $Columns/Right/VBox/BtnStart

## Hero whose equipment is shown (click a name in the roster).
var _selected: Dictionary = {}
var _equip_slots: Array = []


func _ready() -> void:
	_try_optional_hub_ambient()
	_region_option.clear()
	for r in GameState.PLAYABLE_REGIONS:
		_region_option.add_item(str(r["name"]))
	_region_option.item_selected.connect(_on_region_selected)
	_btn_start.pressed.connect(_on_start_pressed)
	$Columns/Right/VBox/BtnQuit.pressed.connect(_on_quit_pressed)
	$Columns/Left/VBox/BtnIglesia.pressed.connect(_on_iglesia_pressed)
	_sync_region_option_from_state()
	_try_load_hub_background()
	_build_shop()
	_btn_sell.toggled.connect(func(_on: bool): _refresh())
	# Drop any inventory item on the shop list to sell one.
	$Columns/Left/VBox/ShopScroll.set_drag_forwarding(Callable(), _can_drop_sell, _drop_sell)
	for slot in GameState.EQUIP_SLOTS:
		var es = EquipSlotScript.new()
		es.setup(slot)
		es.custom_minimum_size = Vector2(60, 48)
		es.changed.connect(func(msg: String): _say(msg))
		_equip_row.add_child(es)
		_equip_slots.append(es)
	if not GameState.roster.is_empty():
		_selected = GameState.roster[0]
	_hub_status.text = GameState.last_week_report
	_refresh()


func _sync_region_option_from_state() -> void:
	var p: String = GameState.selected_mission_region_path
	for i in GameState.PLAYABLE_REGIONS.size():
		if str(GameState.PLAYABLE_REGIONS[i]["path"]) == p:
			_region_option.select(i)
			return
	_region_option.select(0)


func _on_region_selected(idx: int) -> void:
	if idx >= 0 and idx < GameState.PLAYABLE_REGIONS.size():
		GameState.selected_mission_region_path = str(GameState.PLAYABLE_REGIONS[idx]["path"])
	else:
		GameState.selected_mission_region_path = GameState.DEFAULT_REGION_PATH


func _try_optional_hub_ambient() -> void:
	var apath := "res://assets/audio/hub_loop.ogg"
	if not ResourceLoader.exists(apath):
		return
	var stream: AudioStream = load(apath)
	if stream == null:
		return
	var ap := AudioStreamPlayer.new()
	ap.stream = stream
	ap.volume_db = -10.0
	add_child(ap)
	ap.play()


func _try_load_hub_background() -> void:
	var p := "res://assets/ui_bg/hub_bg.png"
	if ResourceLoader.exists(p):
		var tex := load(p) as Texture2D
		if tex != null:
			_bg.texture = tex
			return
	var img2 := Image.create(512, 512, false, Image.FORMAT_RGB8)
	img2.fill(Color(0.11, 0.07, 0.15))
	_bg.texture = ImageTexture.create_from_image(img2)


func _say(msg: String) -> void:
	_hub_status.text = msg
	SaveService.save_game()
	_refresh()


func _refresh() -> void:
	_gold.text = "Colones: %d" % GameState.colones
	_week.text = "Semana: %d" % GameState.week
	_refresh_equipment()
	for b in _shop_grid.get_children():
		var item: Dictionary = GameState.get_item(str(b.get_meta("item_id", "")))
		b.disabled = GameState.colones < int(item.get("price", 0))
	_refresh_recruits()
	_refresh_roster()
	_btn_start.disabled = GameState.living_party_count() <= 0
	_btn_start.text = "Iniciar expedición (%d en la cuadrilla)" % GameState.living_party_count()


# --- Pulpería ----------------------------------------------------------------------

func _build_shop() -> void:
	for id in GameState.all_item_ids():
		var item: Dictionary = GameState.get_item(str(id))
		var b := Button.new()
		b.text = "%s — %d ₡" % [item.get("name", id), int(item.get("price", 0))]
		b.tooltip_text = GameState.item_tooltip(str(id))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		b.add_theme_font_size_override("font_size", 13)
		var icon_path: String = "res://assets/items/%s.png" % str(id)
		if ResourceLoader.exists(icon_path):
			b.icon = load(icon_path) as Texture2D
			b.expand_icon = true
		b.set_meta("item_id", str(id))
		b.set_drag_forwarding(Callable(), _can_drop_sell, _drop_sell)
		b.pressed.connect(func(): _say(GameState.buy_item(str(id))))
		_shop_grid.add_child(b)


func _on_iglesia_pressed() -> void:
	_say(GameState.iglesia_misa_rapida())


# --- Equipment (drag from the alforja onto a slot; click a slot to unequip) ---------

func _refresh_equipment() -> void:
	if _selected.is_empty() or not GameState.roster.has(_selected):
		_selected = GameState.roster[0] if not GameState.roster.is_empty() else {}
	if _btn_sell.button_pressed:
		_equip_title.text = "MODO VENDER: clic en un artículo de la alforja para venderlo (mitad de precio)"
	else:
		_equip_title.text = "Equipo de %s — arrastra desde la alforja (%d/%d espacios)" % [
			_selected.get("name", "—"), GameState.inventory.size(), GameState.INVENTORY_SLOTS]
	for es in _equip_slots:
		es.show_hero(_selected)
	for c in _pack_grid.get_children():
		c.queue_free()
	for k in GameState.INVENTORY_SLOTS:
		var b = InventorySlotScript.new()
		if k < GameState.inventory.size():
			b.setup(str(GameState.inventory[k]["id"]), int(GameState.inventory[k]["qty"]))
			b.used.connect(func(id: String):
				if _btn_sell.button_pressed:
					_say(GameState.sell_item(id))
				elif GameState.is_equipment(id) and not _selected.is_empty():
					_say(GameState.equip(_selected, id))
			)
			if _btn_sell.button_pressed:
				b.modulate = Color(1, 0.85, 0.6)
		else:
			b.setup("", 0)
		_pack_grid.add_child(b)


func _can_drop_sell(_at: Vector2, data: Variant) -> bool:
	return data is Dictionary and str(data.get("kind", "")) == "item"


func _drop_sell(_at: Vector2, data: Variant) -> void:
	_say(GameState.sell_item(str(data.get("id", ""))))


# --- Terminal de Buses ------------------------------------------------------------

func _refresh_recruits() -> void:
	for c in _recruit_box.get_children():
		c.queue_free()
	if GameState.recruit_pool.is_empty():
		var l := Label.new()
		l.text = "No hay más candidatos esta semana."
		_recruit_box.add_child(l)
		return
	for i in GameState.recruit_pool.size():
		var h: Dictionary = GameState.recruit_pool[i]
		var b := Button.new()
		b.text = "Contratar a %s — %s (PV %d, vel. %d) — %d ₡" % [
			h.get("name", "?"), h.get("class_name", ""), int(h.get("hp_max", 0)), int(h.get("speed", 0)), GameState.hire_cost(h)]
		b.tooltip_text = "Habilidades: " + ", ".join(h.get("skill_ids", []).map(
			func(sid): return str(GameState.get_skill(str(sid)).get("name", sid))))
		b.disabled = GameState.colones < GameState.hire_cost(h) or GameState.roster.size() >= GameState.ROSTER_CAP
		b.pressed.connect(func(): _say(GameState.hire_recruit(i)))
		_recruit_box.add_child(b)


# --- Roster, party and EBAIS --------------------------------------------------------

func _refresh_roster() -> void:
	for c in _roster_list.get_children():
		c.queue_free()
	_roster_title.text = "Héroes (%d/%d) — cuadrilla %d/%d, en orden de rango" % [
		GameState.roster.size(), GameState.ROSTER_CAP, GameState.party.size(), GameState.PARTY_SIZE]
	# Party first (rank order), then the rest.
	var ordered: Array = GameState.party.duplicate()
	for h in GameState.roster:
		if not GameState.is_in_party(h):
			ordered.append(h)
	for h in ordered:
		_roster_list.add_child(_roster_row(h))


func _roster_row(h: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var pic := TextureRect.new()
	pic.custom_minimum_size = Vector2(44, 44)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var p: String = "res://assets/portraits/%s.png" % str(h.get("hero_id", ""))
	if ResourceLoader.exists(p):
		pic.texture = load(p) as Texture2D
	row.add_child(pic)
	var info := Button.new()
	info.flat = true
	info.alignment = HORIZONTAL_ALIGNMENT_LEFT
	info.tooltip_text = "Clic para ver y cambiar su equipo."
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_font_size_override("font_size", 13)
	if is_same(h, _selected):
		info.add_theme_color_override("font_color", Color(1, 0.9, 0.55))
	info.pressed.connect(func():
		_selected = h
		_refresh()
	)
	var extra: String = ""
	var aff: String = str(h.get("affliction_id", ""))
	if aff != "":
		extra = " · Quebranto: %s" % aff.capitalize()
	var in_party: bool = GameState.is_in_party(h)
	var rank: String = ""
	if in_party:
		rank = "%d. " % (GameState.party.find(h) + 1)
	info.text = "%s%s — %s\nPV %d/%d · Estrés %d · Prot %d%% · Daño %+d%s" % [
		rank, h.get("name", "?"), h.get("class_name", ""), int(h.get("hp", 0)), int(h.get("hp_max", 0)),
		int(h.get("stress", 0)), int(h.get("prot", 0)), int(h.get("dmg_bonus", 0)), extra]
	row.add_child(info)
	var cost: int = GameState.heal_cost(h)
	if cost > 0:
		var heal := Button.new()
		heal.text = "EBAIS %d ₡" % cost
		heal.tooltip_text = "Curar todos los PV en el EBAIS del pueblo."
		heal.disabled = GameState.colones < cost
		heal.pressed.connect(func(): _say(GameState.heal_hero(h)))
		row.add_child(heal)
	if in_party:
		var up := Button.new()
		up.text = "↑"
		up.tooltip_text = "Subir de rango (más adelante)"
		up.pressed.connect(func():
			GameState.move_in_party(h, -1)
			_say("")
		)
		row.add_child(up)
		var down := Button.new()
		down.text = "↓"
		down.tooltip_text = "Bajar de rango (más atrás)"
		down.pressed.connect(func():
			GameState.move_in_party(h, 1)
			_say("")
		)
		row.add_child(down)
	var fire := Button.new()
	fire.text = "Despedir"
	fire.tooltip_text = "Despedir a este héroe para siempre. Su equipo vuelve a la alforja."
	fire.add_theme_color_override("font_color", Color(0.95, 0.55, 0.5))
	fire.disabled = GameState.roster.size() <= 1
	fire.pressed.connect(_confirm_dismiss.bind(h))
	row.add_child(fire)
	var cb := CheckBox.new()
	cb.text = "Cuadrilla"
	cb.button_pressed = in_party
	cb.toggled.connect(func(on: bool): _say(GameState.set_in_party(h, on)))
	row.add_child(cb)
	return row


func _confirm_dismiss(h: Dictionary) -> void:
	var dlg := ConfirmationDialog.new()
	dlg.title = "Despedir"
	dlg.dialog_text = "¿Despedir a %s (%s)? No vuelve. Su equipo regresa a la alforja." % [
		h.get("name", "?"), h.get("class_name", "")]
	dlg.ok_button_text = "Despedir"
	dlg.cancel_button_text = "Cancelar"
	dlg.confirmed.connect(func():
		if is_same(_selected, h):
			_selected = {}
		_say(GameState.dismiss_hero(h))
	)
	dlg.visibility_changed.connect(func():
		if not dlg.visible:
			dlg.queue_free()
	)
	add_child(dlg)
	dlg.popup_centered()


func _on_start_pressed() -> void:
	if GameState.living_party_count() <= 0:
		_hub_status.text = "Elige al menos un héroe para la cuadrilla."
		return
	start_mission_requested.emit()


func _on_quit_pressed() -> void:
	get_tree().quit()
