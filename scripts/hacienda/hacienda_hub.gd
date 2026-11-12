extends Control

## Hacienda hub: Pulpería (items), Iglesia (stress), Terminal de Buses (recruiting),
## roster with party selection/order and EBAIS healing, Casa Comunal (skill ranks of the
## selected hero), and expedition start.

signal start_mission_requested

const InventorySlotScript := preload("res://scripts/ui/inventory_slot.gd")
const ShopSlotScript := preload("res://scripts/ui/shop_slot.gd")
const EquipSlotScript := preload("res://scripts/ui/equip_slot.gd")
const StressSystemScript := preload("res://scripts/domain/stress_system.gd")
const ResolveSystemScript := preload("res://scripts/domain/resolve_system.gd")
const TownEventsScript := preload("res://scripts/domain/town_events.gd")
const SkillRanksScript := preload("res://scripts/domain/skill_ranks.gd")
const SkillButtonScript := preload("res://scripts/ui/skill_button.gd")
const FormationScript := preload("res://scripts/domain/formation.gd")

@onready var _bg: TextureRect = $BgTexture
@onready var _gold: Label = $Columns/Left/VBox/InfoRow/GoldLabel
@onready var _week: Label = $Columns/Left/VBox/InfoRow/WeekLabel
@onready var _region_option: OptionButton = $Columns/Left/VBox/RegionRow/RegionOption
@onready var _shop_grid: HFlowContainer = $Columns/Left/VBox/ShopScroll/ShopGrid
@onready var _btn_sell: Button = $Columns/Left/VBox/ShopHead/BtnSell
@onready var _shop_filters: HBoxContainer = $Columns/Left/VBox/ShopFilters

const SHOP_FILTERS := [
	["todo", "Todo"], ["consumable", "Consumibles"], ["weapon", "Armas"],
	["armor", "Armaduras"], ["accessory", "Accesorios"],
]
var _shop_filter: String = "todo"
@onready var _equip_title: Label = $Columns/Right/VBox/EquipTitle
@onready var _equip_row: HBoxContainer = $Columns/Right/VBox/EquipRow
@onready var _pack_grid: GridContainer = $Columns/Right/VBox/PackGrid
@onready var _recruit_box: VBoxContainer = $Columns/Left/VBox/RecruitBox
@onready var _hub_status: Label = $Columns/Left/VBox/HubStatus
@onready var _roster_title: Label = $Columns/Right/VBox/RosterTitle
@onready var _roster_list: VBoxContainer = $Columns/Right/VBox/Scroll/RosterList
@onready var _btn_start: Button = $Columns/Right/VBox/BtnStart
@onready var _skills_title: Label = $Columns/Right/VBox/SkillsTitle
@onready var _skills_row: HBoxContainer = $Columns/Right/VBox/SkillsRow

## Hero whose equipment is shown (click a name in the roster).
var _selected: Dictionary = {}
var _equip_slots: Array = []
var _difficulty_option: OptionButton
var _pura_vida: CheckBox
## "Evento de la semana" button in the info row; opens the event card.
var _event_btn: Button


func _ready() -> void:
	_try_optional_hub_ambient()
	_region_option.clear()
	for r in GameState.PLAYABLE_REGIONS:
		var rl: int = GameState.region_level(str(r["path"]))
		_region_option.add_item("%s%s" % [r["name"], " (+%d de nivel)" % rl if rl > 0 else ""])
	_region_option.item_selected.connect(_on_region_selected)
	_build_difficulty_picker()
	_btn_start.pressed.connect(_on_start_pressed)
	$Columns/Right/VBox/BtnQuit.pressed.connect(_on_quit_pressed)
	$Columns/Left/VBox/BtnIglesia.pressed.connect(_on_iglesia_pressed)
	_sync_region_option_from_state()
	_try_load_hub_background()
	_build_shop_filters()
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
	_build_event_button()
	_refresh()
	if not GameState.event_seen and GameState.active_event_id != "":
		_show_event_card.call_deferred()


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
	_refresh_difficulty_labels()
	_refresh()


## Expedition difficulty (docs/01 §6): Aprendiz / Veterano / Campeón, next to the region.
func _build_difficulty_picker() -> void:
	var row := HBoxContainer.new()
	var box: VBoxContainer = $Columns/Left/VBox
	box.add_child(row)
	box.move_child(row, $Columns/Left/VBox/RegionRow.get_index() + 1)
	var lbl := Label.new()
	lbl.text = "Dificultad:"
	row.add_child(lbl)
	_difficulty_option = OptionButton.new()
	_difficulty_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var diffs: Array = ResolveSystemScript.difficulties()
	for i in diffs.size():
		_difficulty_option.add_item(str(diffs[i].get("name", "?")))
		if str(diffs[i].get("id", "")) == GameState.selected_difficulty_id:
			_difficulty_option.select(i)
	_difficulty_option.item_selected.connect(func(idx: int):
		GameState.selected_difficulty_id = str(diffs[idx].get("id", "aprendiz"))
		_say("")
	)
	row.add_child(_difficulty_option)
	_pura_vida = CheckBox.new()
	_pura_vida.text = "Pura Vida"
	_pura_vida.tooltip_text = "Modo Pura Vida (como el modo Radiante): suben de resolución más rápido y aceptan expediciones de hasta 2 niveles menos."
	_pura_vida.button_pressed = GameState.radiant_mode
	_pura_vida.toggled.connect(func(on: bool):
		GameState.set_radiant_mode(on)
		_refresh_difficulty_labels()
		_say("Modo Pura Vida %s." % ("activado" if on else "desactivado"))
	)
	row.add_child(_pura_vida)
	_refresh_difficulty_labels()


## Labels show the expedition level for the selected region (difficulty + region level).
func _refresh_difficulty_labels() -> void:
	if _difficulty_option == null:
		return
	var diffs: Array = ResolveSystemScript.difficulties()
	for i in diffs.size():
		var e: Dictionary = GameState.selected_expedition(str(diffs[i].get("id", "")))
		_difficulty_option.set_item_text(i, "%s (nivel %d)" % [e.get("name", "?"), int(e.get("level", 1))])
		_difficulty_option.set_item_tooltip(i, "Héroes de resolución %d–%d. Sobrevivientes ganan %d XP de resolución. Enemigos x%.2f PV, x%.2f daño; paga x%.2f." % [
			int(e.get("min_level", 0)), int(e.get("max_level", 6)), int(e.get("xp", 0)),
			float(e.get("enemy_hp", 1.0)), float(e.get("enemy_dmg", 1.0)), float(e.get("reward", 1.0))])


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
	_refresh_skills()
	for b in _shop_grid.get_children():
		if not b.is_queued_for_deletion():
			b.refresh()
	var igl: Button = $Columns/Left/VBox/BtnIglesia
	var closed: bool = TownEventsScript.is_closed(GameState.active_event(), "iglesia")
	igl.text = "Iglesia Vieja: cerrada esta semana" if closed else "Iglesia Vieja: misa rápida (%s, -%d estrés a todos)" % [
		"gratis" if GameState.iglesia_cost() == 0 else "%d ₡" % GameState.iglesia_cost(), GameState.iglesia_relief()]
	igl.disabled = closed or GameState.colones < GameState.iglesia_cost()
	_refresh_event_button()
	_refresh_recruits()
	_refresh_roster()
	var refusing: Array = GameState.party_refusals()
	_btn_start.disabled = GameState.living_party_count() <= 0 or not refusing.is_empty()
	_btn_start.text = "Iniciar expedición (%d en la cuadrilla)" % GameState.living_party_count()
	if not refusing.is_empty():
		_btn_start.text = "%s no quiere ir a una expedición tan fácil" % ", ".join(refusing.map(func(h): return str(h.get("name", "?"))))


# --- Pulpería ----------------------------------------------------------------------

func _build_shop_filters() -> void:
	var group := ButtonGroup.new()
	for f in SHOP_FILTERS:
		var b := Button.new()
		b.text = f[1]
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = f[0] == _shop_filter
		b.add_theme_font_size_override("font_size", 13)
		b.pressed.connect(func():
			_shop_filter = f[0]
			_build_shop()
			_refresh()
		)
		_shop_filters.add_child(b)


## Shop category of an item: consumable (incl. curio keys), weapon, armor or accessory.
func _category(item: Dictionary) -> String:
	if str(item.get("usable", "")) == "equip":
		return str(item.get("slot", ""))
	return "consumable"


## One icon tile per item (data/items.json) in the selected category, in file order.
## The tile shows the price; name, stats and description are in its tooltip card.
func _build_shop() -> void:
	for c in _shop_grid.get_children():
		c.queue_free()
	for id in GameState.all_item_ids():
		var item: Dictionary = GameState.get_item(str(id))
		if _shop_filter != "todo" and _category(item) != _shop_filter:
			continue
		var b = ShopSlotScript.new()
		b.setup(str(id))
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
			_selected.get("name", "—"), GameState.inventory.size(), GameState.inventory_slots()]
	for es in _equip_slots:
		es.show_hero(_selected)
	for c in _pack_grid.get_children():
		c.queue_free()
	for k in GameState.inventory_slots():
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


# --- Casa Comunal de Oficios (skill ranks) -------------------------------------------

## The selected hero's 4 skills: icon with rank pips, then "Rango N — X ₡" to train the next rank.
func _refresh_skills() -> void:
	for c in _skills_row.get_children():
		c.queue_free()
	if _selected.is_empty():
		_skills_title.text = "Casa Comunal de Oficios"
		return
	_skills_title.text = "Casa Comunal de Oficios — habilidades de %s (Resolución %d)" % [
		_selected.get("name", "—"), int(_selected.get("resolve_level", 0))]
	var h: Dictionary = _selected
	for sid in h.get("skill_ids", []):
		var sk: Dictionary = GameState.hero_skill(h, str(sid))
		if sk.is_empty():
			continue
		var rank: int = int(sk.get("rank", 1))
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 3)
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 6)
		var icon = SkillButtonScript.new()
		icon.setup(str(sid), str(sk.get("kind", "attack")), "%s (rango %d)" % [sk.get("name", sid), rank],
			SkillButtonScript.body_for(sk), rank, SkillRanksScript.max_rank())
		top.add_child(icon)
		var nm := Label.new()
		nm.text = str(sk.get("name", sid))
		nm.add_theme_font_size_override("font_size", 12)
		nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.custom_minimum_size = Vector2(60, 0)
		top.add_child(nm)
		col.add_child(top)
		var buy := Button.new()
		buy.add_theme_font_size_override("font_size", 12)
		buy.clip_text = true
		var why: String = GameState.skill_rank_block_reason(h, str(sid))
		if rank >= SkillRanksScript.max_rank():
			buy.text = "Rango máx."
			buy.disabled = true
			buy.tooltip_text = "%s ya está en el rango más alto." % sk.get("name", sid)
		else:
			var cost: int = GameState.skill_rank_cost(h, str(sid))
			var need: int = SkillRanksScript.min_resolve_for(rank + 1)
			# Disabled buttons may not show a tooltip, so the resolve gate is in the label itself.
			if int(h.get("resolve_level", 0)) < need:
				buy.text = "Rango %d: Resolución %d" % [rank + 1, need]
			else:
				buy.text = "Rango %d — %s" % [rank + 1, "gratis" if cost == 0 else "%d ₡" % cost]
			buy.disabled = why != ""
			var gain: PackedStringArray = SkillRanksScript.preview_lines(GameState.get_skill(str(sid)), rank)
			var lines: PackedStringArray = PackedStringArray(["Entrenar %s al rango %d" % [sk.get("name", sid), rank + 1]])
			if not gain.is_empty():
				lines.append("Al subir: " + ", ".join(gain))
			if why != "":
				lines.append(why)
			buy.tooltip_text = "\n".join(lines)
			buy.pressed.connect(func(): _say(GameState.buy_skill_rank(h, str(sid))))
		col.add_child(buy)
		_skills_row.add_child(col)


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
		b.disabled = GameState.colones < GameState.hire_cost(h) or GameState.roster.size() >= GameState.roster_cap() \
			or TownEventsScript.is_closed(GameState.active_event(), "terminal")
		b.pressed.connect(func(): _say(GameState.hire_recruit(i)))
		_recruit_box.add_child(b)


# --- Roster, party and EBAIS --------------------------------------------------------

func _refresh_roster() -> void:
	for c in _roster_list.get_children():
		c.queue_free()
	_roster_title.text = "Héroes (%d/%d) — cuadrilla %d/%d, en orden de rango" % [
		GameState.roster.size(), GameState.roster_cap(), GameState.party.size(), GameState.PARTY_SIZE]
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
	info.tooltip_text = "Clic para ver su equipo y sus habilidades."
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
		extra = " · Quebranto: %s" % StressSystemScript.affliction_name(aff)
	elif str(h.get("virtud_id", "")) != "":
		extra = " · Virtud: %s" % StressSystemScript.virtud_name(str(h["virtud_id"]))
	var in_party: bool = GameState.is_in_party(h)
	var rank: String = ""
	if in_party:
		rank = "%d. " % (GameState.party.find(h) + 1)
	var lvl: int = int(h.get("resolve_level", 0))
	var pr: Dictionary = ResolveSystemScript.progress(h)
	var xp: String = "máx." if lvl >= ResolveSystemScript.MAX_LEVEL else "%d/%d XP" % [int(pr["current"]), int(pr["needed"])]
	var diff: Dictionary = GameState.selected_expedition()
	var warn: String = ""
	if ResolveSystemScript.refuses(h, diff):
		warn = " ⚠ no va a %s" % diff.get("name", "")
	elif ResolveSystemScript.underlevel(h, diff) > 0:
		warn = " ⚠ le falta resolución"
	# Formation (P1-03a): party order = battlefield position; warn outside the class's positions.
	var ideal: Array = GameState.get_hero_template(str(h.get("hero_id", ""))).get("ranks", [])
	var ideal_txt: String = FormationScript.ranks_text(ideal) if not ideal.is_empty() else "1–4"
	if in_party and not ideal.is_empty() and not ideal.map(func(x): return int(x)).has(GameState.party.find(h) + 1):
		warn += " ⚠ fuera de posición (ideal %s)" % ideal_txt
	info.text = "%s%s — %s%s\nRes. %d (%s)%s · PV %d/%d · Estrés %d · Prot %d%% · Daño %+d" % [
		rank, h.get("name", "?"), h.get("class_name", ""), extra, lvl, xp, warn,
		int(h.get("hp", 0)), int(h.get("hp_max", 0)),
		int(h.get("stress", 0)), int(h.get("prot", 0)), int(h.get("dmg_bonus", 0))]
	# Long lines clip instead of pushing the buttons off-screen; the tooltip has everything.
	info.clip_text = true
	var ranks: PackedStringArray = PackedStringArray()
	for sid in h.get("skill_ids", []):
		ranks.append("%s %d" % [GameState.get_skill(str(sid)).get("name", sid), SkillRanksScript.rank(h, str(sid))])
	info.tooltip_text = "%s\nResolución %d: %s (%s)\nPosiciones ideales en combate: %s (el orden de la cuadrilla es la posición: 1 = adelante)\nHabilidades (rango): %s\nClic para ver su equipo y sus habilidades." % [
		info.text, lvl, ResolveSystemScript.level_name(lvl), xp, ideal_txt, ", ".join(ranks)]
	row.add_child(info)
	var cost: int = GameState.heal_cost(h)
	if int(h.get("hp", 0)) < int(h.get("hp_max", 0)) and not h.get("dead", false):
		var heal := Button.new()
		var ebais_closed: bool = TownEventsScript.is_closed(GameState.active_event(), "ebais")
		heal.text = "EBAIS cerrado" if ebais_closed else ("EBAIS gratis" if cost == 0 else "EBAIS %d ₡" % cost)
		heal.tooltip_text = "Curar todos los PV en el EBAIS del pueblo."
		heal.disabled = ebais_closed or GameState.colones < cost
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
	if not GameState.party_refusals().is_empty():
		_hub_status.text = "Héroes de mucha resolución no salen a expediciones fáciles: sube la dificultad o cambia la cuadrilla."
		return
	var missing: Array = GameState.missing_provisions()
	if missing.is_empty():
		start_mission_requested.emit()
		return
	_confirm_provisions(missing)


## DD-style provisioning (P1-18): warn when the alforja lacks the region's recommended
## food and candles, and offer to buy what is missing at the Pulpería.
func _confirm_provisions(missing: Array) -> void:
	var lines: PackedStringArray = PackedStringArray()
	var total: int = 0
	for m in missing:
		lines.append("· %d × %s (%d ₡)" % [int(m["missing"]), m["name"], int(m["price"])])
		total += int(m["price"])
	var dlg := ConfirmationDialog.new()
	dlg.title = "Provisiones"
	dlg.dialog_text = "Para esta expedición se recomienda llevar más:\n%s\n\nSin comida, la cuadrilla pasa hambre; sin candelas, camina a oscuras." % "\n".join(lines)
	dlg.ok_button_text = "Salir así"
	dlg.cancel_button_text = "Volver"
	dlg.add_button("Comprar lo que falta (%d ₡)" % total, true, "buy")
	dlg.confirmed.connect(func(): start_mission_requested.emit())
	dlg.custom_action.connect(func(action: StringName):
		if action == &"buy":
			dlg.hide()
			_say(GameState.buy_missing_provisions())
	)
	dlg.visibility_changed.connect(func():
		if not dlg.visible:
			dlg.queue_free()
	)
	add_child(dlg)
	dlg.popup_centered()


func _on_quit_pressed() -> void:
	get_tree().quit()


# --- Town event of the week (docs/02 §12) -----------------------------------------------

func _build_event_button() -> void:
	_event_btn = Button.new()
	_event_btn.add_theme_font_size_override("font_size", 14)
	_event_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_event_btn.clip_text = true
	_event_btn.pressed.connect(_show_event_card)
	$Columns/Left/VBox/InfoRow.add_child(_event_btn)


func _refresh_event_button() -> void:
	if _event_btn == null:
		return
	var ev: Dictionary = GameState.active_event()
	_event_btn.disabled = ev.is_empty()
	_event_btn.text = "Sin novedades esta semana" if ev.is_empty() else "Evento: %s" % ev.get("name", "")
	var col := Color(0.6, 0.85, 0.55) if str(ev.get("kind", "")) == "positive" else (Color(0.95, 0.55, 0.5) if str(ev.get("kind", "")) == "negative" else Color(0.95, 0.82, 0.55))
	_event_btn.add_theme_color_override("font_color", col)
	_event_btn.tooltip_text = "" if ev.is_empty() else "\n".join(TownEventsScript.effect_lines(ev))


## Event card: name, text, what it changes, what already happened, and any choices.
func _show_event_card() -> void:
	var ev: Dictionary = GameState.active_event()
	if ev.is_empty():
		return
	GameState.event_seen = true
	SaveService.save_game()
	var dlg := AcceptDialog.new()
	dlg.title = "%s — %s" % [TownEventsScript.kind_label(ev), ev.get("name", "")]
	dlg.ok_button_text = "Entendido"
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(520, 0)
	box.add_theme_constant_override("separation", 8)
	var body := Label.new()
	body.text = str(ev.get("text", ""))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(520, 0)
	box.add_child(body)
	# What happened right away (if we still have the report) + what lasts the week.
	var lines: PackedStringArray = GameState.event_report.duplicate()
	lines.append_array(TownEventsScript.effect_lines(ev, GameState.event_report.is_empty()))
	if not lines.is_empty():
		var fx := Label.new()
		fx.text = "• " + "\n• ".join(lines)
		fx.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		fx.custom_minimum_size = Vector2(520, 0)
		fx.add_theme_color_override("font_color", Color(0.95, 0.82, 0.55))
		box.add_child(fx)
	for h in GameState.resurrect_candidates():
		var b := Button.new()
		b.text = "Traer de vuelta a %s — %s, Resolución %d" % [h.get("name", "?"), h.get("class_name", ""), int(h.get("resolve_level", 0))]
		b.pressed.connect(func():
			dlg.hide()
			_say(GameState.resurrect(int(h.get("uid", 0))))
		)
		box.add_child(b)
	var offer: Dictionary = GameState.event_offer()
	if not offer.is_empty():
		var ob := Button.new()
		ob.text = "%s — %d ₡" % [offer.get("label", ""), int(offer.get("cost", 0))]
		ob.disabled = GameState.colones < int(offer.get("cost", 0))
		ob.pressed.connect(func():
			dlg.hide()
			_say(GameState.take_event_offer())
		)
		box.add_child(ob)
	dlg.add_child(box)
	dlg.visibility_changed.connect(func():
		if not dlg.visible:
			dlg.queue_free()
	)
	add_child(dlg)
	# Autowrapped labels report a huge height on the first pass: size to content after layout.
	dlg.popup_centered(Vector2i(560, 0))
	await get_tree().process_frame
	if is_instance_valid(dlg):
		dlg.reset_size()
		dlg.popup_centered()

