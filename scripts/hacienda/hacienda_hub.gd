extends Control

## Hacienda hub. Since P4-17 it is a painted town (data/town.json): each building is a
## picture you can hover and click, and a click opens that building's window — Pulpería
## (items), Iglesia Vieja + Cantina (stress activities), Terminal de Buses (recruiting),
## Clínica de Espantos (quirks), Casa Comunal (skill ranks of the selected hero) and Taller
## (equipment). The roster (party, order, EBAIS) and the alforja are on the right; colones,
## region, difficulty and the start button on the bottom bar.

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
const HubActivitiesScript := preload("res://scripts/domain/hub_activities.gd")
const QuirksScript := preload("res://scripts/domain/quirks.gd")
# P4-15: menus in the item-card style.
const CardScript := preload("res://scripts/ui/tooltip_card.gd")
const HeroCardScript := preload("res://scripts/ui/hero_card.gd")
const CardButtonScript := preload("res://scripts/ui/card_button.gd")
const TownBuildingScript := preload("res://scripts/hacienda/town_building.gd")
const ItemHoverScript := preload("res://scripts/ui/item_hover.gd")
const StatusEffectsScript := preload("res://scripts/domain/status_effects.gd")
const CampingSystemScript := preload("res://scripts/domain/camping_system.gd")
const TOWN_PATH := "res://data/town.json"
## Pages that are about one hero show who at the top (click another hero on the right).
const HERO_PAGES := ["iglesia", "cantina", "casa_comunal", "taller", "guardabosques"]

@onready var _bg: TextureRect = $BgTexture
@onready var _town: Control = $Town
@onready var _gold: Label = $BottomBar/Row/GoldLabel
@onready var _week: Label = $Banner/Row/WeekLabel
@onready var _region_option: OptionButton = $BottomBar/Row/RegionOption
@onready var _window: PanelContainer = $Building
@onready var _pages: Control = $Building/VBox/Pages
@onready var _who: HBoxContainer = $Building/VBox/Who
## Two shops (P4-18, owner 2026-11-17): the Pulpería sells consumables, the Taller
## weapons, armor and accessories (with a filter). Sell mode is shared by both.
@onready var _shop_grid: HFlowContainer = $Building/VBox/Pages/pulperia/ShopScroll/ShopGrid
@onready var _btn_sell: Button = $Building/VBox/Pages/pulperia/ShopHead/BtnSell
@onready var _taller_grid: HFlowContainer = $Building/VBox/Pages/taller/ShopScroll/ShopGrid
@onready var _btn_sell_taller: Button = $Building/VBox/Pages/taller/ShopHead/BtnSell
@onready var _shop_filters: HBoxContainer = $Building/VBox/Pages/taller/ShopFilters

const SHOP_FILTERS := [
	["todo", "Todo"], ["weapon", "Armas"], ["armor", "Armaduras"], ["accessory", "Accesorios"],
]
## The Taller's filter.
var _shop_filter: String = "todo"
@onready var _equip_title: Label = $Building/VBox/Pages/taller/EquipTitle
@onready var _equip_row: HBoxContainer = $Building/VBox/Pages/taller/EquipRow
@onready var _pack_grid: GridContainer = $Right/VBox/PackGrid
@onready var _recruit_box: VBoxContainer = $Building/VBox/Pages/terminal/RecruitBox
@onready var _hub_status: Label = $HubStatus
@onready var _roster_title: Label = $Right/VBox/RosterTitle
@onready var _roster_list: VBoxContainer = $Right/VBox/Scroll/RosterList
@onready var _btn_start: Button = $BottomBar/Row/BtnStart
@onready var _skills_title: Label = $Building/VBox/Pages/casa_comunal/SkillsTitle
@onready var _skills_row: HBoxContainer = $Building/VBox/Pages/casa_comunal/SkillsRow
@onready var _clinic_box: VBoxContainer = $Building/VBox/Pages/clinica/Box
@onready var _ranger_box: VBoxContainer = $Building/VBox/Pages/guardabosques/Box

## Alforja cells in the town's right panel (owner 2026-11-19: a bit bigger), 6 per row.
const PACK_SLOT := Vector2(56, 58)

## Hero whose equipment is shown (click a name in the roster).
var _selected: Dictionary = {}
var _equip_slots: Array = []
var _difficulty_option: OptionButton
var _pura_vida: CheckBox
## "Evento de la semana" button in the info row; opens the event card.
var _event_btn: Button
## Iglesia Vieja + Cantina activities for the selected hero (P3-03): building id -> its page's box.
var _relief_boxes: Dictionary = {}
## The town's buildings (P4-17): id -> TownBuilding, and the data rows from data/town.json.
var _buildings: Dictionary = {}
var _town_data: Dictionary = {}
## The building whose window is open ("" = looking at the town).
var _open_building: String = ""
## The town painted as one picture (P4-19) and where each building's crop of it sits.
const PAINTED_PATH := "res://assets/town/town_painted.png"
const PAINTED_LAYOUT := "res://assets/town/painted/layout.json"
var _painted: Texture2D = null
## Taller (owner 2026-11-19): the equipment section folds away so the shop has room. It
## starts closed; clicking a hero opens it for that hero, clicking the same hero closes it.
var _equip_open: bool = false
var _equip_bar: Button
var _painted_rects: Dictionary = {}


func _ready() -> void:
	_try_optional_hub_ambient()
	_region_option.clear()
	for r in GameState.PLAYABLE_REGIONS:
		var rl: int = GameState.region_level(str(r["path"]))
		_region_option.add_item("%s%s" % [r["name"], " (+%d de nivel)" % rl if rl > 0 else ""])
	_region_option.item_selected.connect(_on_region_selected)
	_build_difficulty_picker()
	_btn_start.pressed.connect(_on_start_pressed)
	$BottomBar/Row/BtnQuit.pressed.connect(_on_quit_pressed)
	for bid in ["iglesia", "cantina"]:
		_relief_boxes[bid] = _pages.get_node("%s/Box" % bid)
	$Building/VBox/Head/Close.pressed.connect(close_building)
	_sync_region_option_from_state()
	_try_load_hub_background()
	_build_town()
	_build_shop_filters()
	_build_shop()
	for b in [_btn_sell, _btn_sell_taller]:
		b.toggled.connect(_set_selling)
	# Drop an inventory item on a shop to sell one there.
	$Building/VBox/Pages/pulperia/ShopScroll.set_drag_forwarding(Callable(), _can_drop_sell, _drop_sell.bind("pulperia"))
	$Building/VBox/Pages/taller/ShopScroll.set_drag_forwarding(Callable(), _can_drop_sell, _drop_sell.bind("taller"))
	for slot in GameState.EQUIP_SLOTS:
		var es = EquipSlotScript.new()
		es.setup(slot)
		es.custom_minimum_size = Vector2(72, 60)
		es.changed.connect(func(msg: String): _say(msg))
		_equip_row.add_child(es)
		_equip_slots.append(es)
	if not GameState.roster.is_empty():
		_selected = GameState.roster[0]
	_hub_status.text = GameState.last_week_report
	_build_event_button()
	if OS.is_debug_build():
		var dev := Button.new()
		dev.text = "DEV"
		dev.tooltip_text = "Menú de desarrollo (F12)\nPlata infinita, pasar la semana, subir resolución."
		dev.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dev.pressed.connect(_show_dev_menu)
		$Banner/Row.add_child(dev)
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
	row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var bar: HBoxContainer = $BottomBar/Row
	bar.add_child(row)
	bar.move_child(row, _region_option.get_index() + 1)
	var lbl := Label.new()
	lbl.text = "Dificultad:"
	row.add_child(lbl)
	_difficulty_option = OptionButton.new()
	_difficulty_option.custom_minimum_size = Vector2(160, 0)
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
		_difficulty_option.set_item_tooltip(i, "Héroes de resolución %d–%d. Sobrevivientes ganan %d XP de resolución. Enemigos x%.2f PV, x%.2f daño, x%.2f estrés; paga x%.2f." % [
			int(e.get("min_level", 0)), int(e.get("max_level", 6)), int(e.get("xp", 0)),
			float(e.get("enemy_hp", 1.0)), float(e.get("enemy_dmg", 1.0)), float(e.get("enemy_stress", 1.0)), float(e.get("reward", 1.0))])


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
	_town_data = _load_town()
	var p: String = str(_town_data.get("background", "res://assets/ui_bg/hub_bg.png"))
	var tex: Texture2D = _load_texture(p)
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
	_gold.text = "%d ₡" % GameState.colones
	_gold.tooltip_text = "Colones de la hacienda"
	_week.text = "Semana %d" % GameState.week
	_refresh_equipment()
	_refresh_skills()
	for g in [_shop_grid, _taller_grid]:
		for b in g.get_children():
			if not b.is_queued_for_deletion():
				b.refresh()
	_refresh_relief()
	_refresh_clinic_page()
	_refresh_guardabosques()
	_refresh_town()
	_refresh_who()
	_refresh_event_button()
	_refresh_recruits()
	_refresh_roster()
	var refusing: Array = GameState.party_refusals()
	_btn_start.disabled = GameState.living_party_count() <= 0 or not refusing.is_empty()
	_btn_start.text = "Salir de expedición"
	_btn_start.tooltip_text = "Salir con la cuadrilla (%d héroes)." % GameState.living_party_count()
	if not refusing.is_empty():
		_btn_start.text = "No quieren ir"
		_btn_start.tooltip_text = "%s no quiere ir a una expedición tan fácil: suba la dificultad o cambie la cuadrilla." % ", ".join(refusing.map(func(h): return str(h.get("name", "?"))))


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


## One icon tile per item (data/items.json), in file order: consumables at the Pulpería,
## equipment in the Taller's chosen category. The tile shows the price; name, stats and
## description are in its tooltip card.
func _build_shop() -> void:
	for g in [_shop_grid, _taller_grid]:
		for c in g.get_children():
			c.queue_free()
	for id in GameState.all_item_ids():
		var item: Dictionary = GameState.get_item(str(id))
		var shop: String = GameState.shop_of(str(id))
		if shop == "taller" and _shop_filter != "todo" and _category(item) != _shop_filter:
			continue
		var b = ShopSlotScript.new()
		b.setup(str(id))
		b.set_drag_forwarding(Callable(), _can_drop_sell, _drop_sell.bind(shop))
		b.pressed.connect(func(): _say(GameState.buy_item(str(id))))
		(_taller_grid if shop == "taller" else _shop_grid).add_child(b)


## Sell mode is one switch shown in both shops.
func _set_selling(on: bool) -> void:
	for b in [_btn_sell, _btn_sell_taller]:
		b.set_pressed_no_signal(on)
	_refresh()


func _selling() -> bool:
	return _btn_sell.button_pressed


## Where a sale happens: the shop whose window is open, else the item's own shop ("").
func _sell_shop() -> String:
	return _open_building if _open_building in ["pulperia", "taller"] else ""


# --- Iglesia Vieja + Cantina del Centro (P3-03) ---------------------------------------

## One page per building (P4-17): the selected hero can be sent to one of its activities
## for the week (pays now, skips the next expedition, stress comes off when the week ends).
func _refresh_relief() -> void:
	for b in HubActivitiesScript.buildings():
		var bid: String = str(b.get("id", ""))
		if _relief_boxes.has(bid):
			_fill_relief(_relief_boxes[bid], b)


func _fill_relief(box: VBoxContainer, b: Dictionary) -> void:
	for c in box.get_children():
		c.queue_free()
	var bid: String = str(b.get("id", ""))
	var h: Dictionary = _selected
	var head := CardScript.label("", 14, CardScript.TEXT, true, 0.0)
	box.add_child(head)
	if h.is_empty():
		head.text = "Elija un héroe a la derecha."
		return
	if GameState.in_clinic(h):
		head.text = "%s pasa la semana en la Clínica de Espantos. No sale de expedición." % h.get("name", "?")
		return
	if HubActivitiesScript.is_busy(h):
		var act: Dictionary = HubActivitiesScript.booked(h)
		var bname: String = HubActivitiesScript.building_name(str(h["busy"].get("building", "")))
		if HubActivitiesScript.is_pending(h):
			head.text = "%s pasa la semana en %s: %s. No sale de expedición." % [h.get("name", "?"), bname, act.get("name", "?")]
			if str(h["busy"].get("building", "")) == bid:
				var cancel := Button.new()
				cancel.text = "Cancelar %s (+%d ₡ de vuelta)" % [act.get("name", "?"), int(h["busy"].get("cost", 0))]
				cancel.pressed.connect(func(): _say(GameState.cancel_activity(h)))
				box.add_child(cancel)
		else:
			head.text = "%s sigue en %s una semana más (%s)." % [h.get("name", "?"), bname, act.get("name", "?")]
		return
	head.text = "Mandar a %s (estrés %d) una semana — no sale de expedición:" % [h.get("name", "?"), int(h.get("stress", 0))]
	var closed: bool = TownEventsScript.is_closed(GameState.active_event(), bid)
	if closed:
		box.add_child(CardScript.label("Cerrada esta semana: no recibe a nadie.", 14, CardScript.BAD, false))
	for a in b.get("activities", []):
		var aid: String = str(a.get("id", ""))
		var btn = CardButtonScript.new()
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(0, 40)
		var price: int = GameState.activity_cost(bid, aid)
		var rel: Array = GameState.activity_relief_range(bid, aid)
		var used: int = GameState.activity_slots_used(bid, aid)
		var cap: int = HubActivitiesScript.slots(a)
		btn.text = "%s — %s · quita %d–%d de estrés · cupos %d/%d" % [a.get("name", aid),
			"gratis" if price == 0 else "%d ₡" % price, int(rel[0]), int(rel[1]), used, cap]
		var why: String = GameState.activity_block_reason(h, bid, aid)
		var lines: PackedStringArray = PackedStringArray([str(a.get("name", aid)), str(a.get("text", "")),
			"Quita %d–%d de estrés y el Quebranto al terminar la semana." % [int(rel[0]), int(rel[1])],
			"Cupos ocupados: %d de %d. Puede tener efectos secundarios." % [used, cap]])
		if why != "":
			lines.append(why)
		btn.tooltip_text = "\n".join(lines)
		btn.card = _activity_card.bind(b, a, price, rel, used, cap, why)
		btn.disabled = why != ""
		btn.pressed.connect(func(): _say(GameState.send_to_activity(h, bid, aid)))
		box.add_child(btn)


# --- Clínica de Espantos (P3-06) -----------------------------------------------------

## The Clínica page (P4-17): every hero with their quirks; a click opens that hero's card.
## Guardabosques del Arenal (P3-13): the selected hero's 6 class camp skills (known or not,
## the fixed one) and their 2 shared ones. Learn, fix or let go, swap a shared one.
func _refresh_guardabosques() -> void:
	for c in _ranger_box.get_children():
		c.queue_free()
	var h: Dictionary = _selected
	if h.is_empty():
		return
	var per: int = CampingSystemScript.class_skills_per_camp()
	var closed: String = GameState.camp_closed_reason()
	if closed != "":
		_ranger_box.add_child(CardScript.label(closed, 13, CardScript.BAD, true, 0.0))
	_ranger_box.add_child(CardScript.label("En cada fogata, %s lleva sus 2 habilidades compartidas y %d de las de su oficio que conozca, al azar. Una fija sale siempre." % [h.get("name", "?"), per],
		13, CardScript.MUTED, true, 0.0))
	_ranger_box.add_child(CardScript.section("De su oficio — conoce %d de %d" % [CampingSystemScript.known_ids(h).size(), CampingSystemScript.class_pool(h).size()]))
	var fixed: String = CampingSystemScript.fixed_id(h)
	for sk in CampingSystemScript.class_pool(h):
		var sid: String = str(sk["id"])
		var known: bool = CampingSystemScript.knows(h, sid)
		var b := Button.new()
		b.custom_minimum_size = Vector2(150, 0)
		if not known:
			b.text = "Aprender — %d ₡" % GameState.camp_price("learn")
			var why: String = GameState.camp_learn_block_reason(h, sid)
			b.disabled = why != ""
			b.tooltip_text = "Aprender %s\n%s" % [sk.get("name", sid), why if why != "" else "Desde ahora puede salirle en las fogatas."]
			b.pressed.connect(func(): _say(GameState.learn_camp_skill(h, sid)))
		elif sid == fixed:
			b.text = "Soltar (gratis)"
			b.tooltip_text = "Soltar %s\nVuelve a salir al azar, como las demás." % sk.get("name", sid)
			b.pressed.connect(func(): _say(GameState.fix_camp_skill(h, "")))
		else:
			b.text = "Fijar — %d ₡" % GameState.camp_price("fix")
			var why2: String = GameState.camp_fix_block_reason(h, sid)
			b.disabled = why2 != ""
			b.tooltip_text = "Fijar %s\n%s" % [sk.get("name", sid), why2 if why2 != "" else "Le sale en cada fogata%s." % (" (en vez de %s)" % CampingSystemScript.skill(fixed).get("name", "") if fixed != "" else "")]
			b.pressed.connect(func(): _say(GameState.fix_camp_skill(h, sid)))
		var tag: String = "Fija" if sid == fixed else ("La conoce" if known else "No la conoce")
		var tag_col: Color = CardScript.GOOD if sid == fixed else (CardScript.TEXT if known else CardScript.MUTED)
		_ranger_box.add_child(_ranger_row(sk, tag, tag_col, [b], known))
	_ranger_box.add_child(CardScript.section("Compartidas — lleva 2 de 3"))
	var others: Array = GameState.camp_shared_options(h)
	for sk in CampingSystemScript.shared_skills(h):
		var btns: Array = []
		for nid in others:
			var b := Button.new()
			b.text = "Cambiar por %s — %d ₡" % [CampingSystemScript.skill(nid).get("name", nid), GameState.camp_price("shared_swap")]
			var why3: String = GameState.camp_swap_block_reason(h, str(sk["id"]), nid)
			b.disabled = why3 != ""
			b.tooltip_text = "%s\n%s" % [CampingSystemScript.skill(nid).get("name", nid), why3 if why3 != "" else str(CampingSystemScript.skill(nid).get("desc", ""))]
			b.pressed.connect(func(): _say(GameState.swap_shared_camp_skill(h, str(sk["id"]), nid)))
			btns.append(b)
		_ranger_box.add_child(_ranger_row(sk, "La lleva", CardScript.TEXT, btns, true))


func _ranger_row(sk: Dictionary, tag: String, tag_col: Color, buttons: Array, lit: bool) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", CardScript.flat(Color(0.1, 0.075, 0.06), Color(0.5, 0.38, 0.22, 0.7 if lit else 0.3), 1, 4, 8))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(CardScript.label("%s (%d pts.)" % [sk.get("name", "?"), int(sk.get("cost", 0))], 13, CardScript.TEXT if lit else CardScript.MUTED, false))
	info.add_child(CardScript.label(str(sk.get("desc", "")), 12, CardScript.MUTED, true, 0.0))
	row.add_child(info)
	var chip: Control = CardScript.chip(tag, tag_col, 11)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(chip)
	for b in buttons:
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(b)
	return panel


func _refresh_clinic_page() -> void:
	for c in _clinic_box.get_children():
		c.queue_free()
	var closed: bool = TownEventsScript.is_closed(GameState.active_event(), "clinica")
	_clinic_box.add_child(CardScript.label("Cerrada esta semana." if closed else
		"Un rasgo malo y uno bueno por semana; las enfermedades, cuando sea. Cada tratamiento deja al héroe aquí el resto de la semana.",
		13, CardScript.BAD if closed else CardScript.MUTED, true, 0.0))
	for h in GameState.roster:
		_add_clinic_button(h, closed)


## One card row per hero, like the Terminal's (owner 2026-11-19): portrait, name, class
## and resolve; PV and stress; the quirk badges (hover: what each does); "Tratar" opens
## the hero's Clínica card.
func _add_clinic_button(h: Dictionary, closed: bool = false) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", CardScript.flat(Color(0.1, 0.075, 0.06), Color(0.5, 0.38, 0.22, 0.7), 1, 4, 10))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)
	var head: Control = HeroCardScript.header(h, 56.0)
	head.custom_minimum_size = Vector2(230, 0)
	row.add_child(head)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 6)
	var qs: Array = QuirksScript.of(h)
	var stay: String = " · en la Clínica esta semana" if GameState.in_clinic(h) else ""
	info.add_child(CardScript.label("PV %d/%d · Estrés %d%s" % [int(h.get("hp", 0)), int(h.get("hp_max", 0)), int(h.get("stress", 0)), stay], 13, CardScript.TEXT, false))
	if qs.is_empty():
		info.add_child(CardScript.label("Sin rasgos ni enfermedades.", 12, CardScript.MUTED, false))
	else:
		info.add_child(HeroCardScript.quirk_chips(h))
	row.add_child(info)
	var b := Button.new()
	b.text = "Tratar\n(%d)" % qs.size()
	b.custom_minimum_size = Vector2(110, 0)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.disabled = qs.is_empty() or closed
	b.tooltip_text = "Clínica de Espantos — cerrada esta semana" if closed else ("Clínica de Espantos\nQuitar rasgos malos, fijar o quitar los buenos y curar enfermedades de %s." % h.get("name", "?"))
	b.pressed.connect(_show_clinic.bind(h))
	row.add_child(b)
	panel.set_meta("treat", b)
	_clinic_box.add_child(panel)


## The Clínica card for one hero (P3-06, restyled P4-15): hero header, then one row per
## quirk grouped by kind, each with its effects and the treatments it allows.
func _show_clinic(h: Dictionary) -> void:
	var made: Array = _card_dialog("Clínica de Espantos — %s" % h.get("name", "?"), 600.0)
	var dlg: AcceptDialog = made[0]
	var col: VBoxContainer = made[1]
	dlg.ok_button_text = "Cerrar"
	col.add_child(HeroCardScript.header(h, 64.0))
	var stay: String = "%s pasa esta semana en la Clínica." % h.get("name", "?") if GameState.in_clinic(h) else \
		"Cada tratamiento deja a %s en la Clínica el resto de la semana (no sale de expedición)." % h.get("name", "?")
	col.add_child(CardScript.label(stay, 12, CardScript.HINT, true, 576.0))
	col.add_child(CardScript.label("Por semana: un tratamiento de rasgos malos y uno de rasgos buenos; las enfermedades, cuando sea. Precios según la resolución.", 12, CardScript.MUTED, true, 576.0))
	var opts: Array = GameState.clinic_options(h)
	if opts.is_empty():
		col.add_child(CardScript.rule())
		col.add_child(CardScript.label("%s no tiene rasgos ni enfermedades." % h.get("name", "?"), 14, CardScript.TEXT, false))
	# Long lists scroll inside the card so the dialog always fits the screen.
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if opts.size() > 3:
		var scroll := ScrollContainer.new()
		scroll.custom_minimum_size = Vector2(600, 400)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		list.custom_minimum_size = Vector2(584, 0)
		scroll.add_child(list)
		col.add_child(scroll)
	else:
		col.add_child(list)
	for kind in ["disease", "negative", "positive"]:
		var group: Array = opts.filter(func(o): return str(o["kind"]) == kind)
		if group.is_empty():
			continue
		list.add_child(CardScript.rule())
		list.add_child(CardScript.section({"disease": "Enfermedades", "negative": "Rasgos malos", "positive": "Rasgos buenos"}[kind]))
		for o in group:
			list.add_child(_clinic_row(dlg, h, o))
	add_child(dlg)
	_popup_card(dlg)


## One quirk in the Clínica: coloured edge, name + tag, description, effects, buttons.
func _clinic_row(dlg: AcceptDialog, h: Dictionary, o: Dictionary) -> Control:
	var hue: Color = HeroCardScript.QUIRK_COLORS.get(str(o["kind"]), CardScript.MUTED)
	var panel := PanelContainer.new()
	var box := CardScript.flat(Color(0.11, 0.085, 0.07), Color(hue, 0.5), 1, 4, 8)
	box.border_width_left = 4
	box.border_color = hue
	panel.add_theme_stylebox_override("panel", box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 3)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 6)
	var nm := CardScript.title_label(str(o["name"]), 15, 0.0)
	nm.add_theme_color_override("font_color", hue.lightened(0.35))
	name_row.add_child(nm)
	name_row.add_child(CardScript.chip(HeroCardScript.QUIRK_TAGS.get(str(o["kind"]), ""), hue))
	if bool(o["locked"]):
		name_row.add_child(CardScript.chip("Fijado", CardScript.GOLD.darkened(0.2)))
	info.add_child(name_row)
	info.add_child(CardScript.label(str(o["desc"]), 12, CardScript.MUTED, true, 340.0))
	info.add_child(CardScript.bullet_list(str(o["effects"]).split(", "), true))
	row.add_child(info)
	var acts := VBoxContainer.new()
	acts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	acts.add_theme_constant_override("separation", 4)
	for a in o["actions"]:
		var b := Button.new()
		b.text = str(a["label"])
		b.custom_minimum_size = Vector2(150, 0)
		b.disabled = not bool(a["enabled"])
		b.tooltip_text = str(a["reason"]) if not bool(a["enabled"]) else "%s\n%s" % [a["label"], "Se queda la semana en la Clínica."]
		var qid: String = str(o["id"])
		var act: String = str(a["action"])
		b.pressed.connect(func():
			dlg.hide()
			_say(GameState.clinic_treat(h, qid, act))
		)
		acts.add_child(b)
		if not bool(a["enabled"]):
			acts.add_child(CardScript.label(str(a["reason"]), 11, CardScript.BAD, true, 150.0))
	row.add_child(acts)
	return panel


## A themed dialog with a card column inside (P4-15). Returns [dialog, column].
func _card_dialog(title: String, width: float = 520.0, confirm: bool = false) -> Array:
	var dlg: AcceptDialog = ConfirmationDialog.new() if confirm else AcceptDialog.new()
	dlg.title = title
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(width, 0)
	col.add_theme_constant_override("separation", 8)
	dlg.add_child(col)
	dlg.visibility_changed.connect(func():
		if not dlg.visible:
			dlg.queue_free()
	)
	return [dlg, col]


## Autowrapped labels report a huge height on the first pass: size to content after layout.
func _popup_card(dlg: AcceptDialog) -> void:
	dlg.popup_centered()
	await get_tree().process_frame
	if is_instance_valid(dlg):
		dlg.reset_size()
		dlg.popup_centered()


## Card shown when hovering an Iglesia/Cantina activity.
func _activity_card(b: Dictionary, a: Dictionary, price: int, rel: Array, used: int, cap: int, why: String) -> Control:
	var made: Array = CardScript.new_card()
	var col: VBoxContainer = made[1]
	var hue: Color = Color(0.45, 0.58, 0.78) if str(b.get("id", "")) == "iglesia" else Color(0.82, 0.6, 0.3)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	var t := CardScript.title_label(str(a.get("name", "")), 17, 0.0)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(CardScript.chip(str(b.get("name", "")), hue))
	col.add_child(head)
	col.add_child(CardScript.label(str(a.get("text", "")), 13, CardScript.MUTED))
	col.add_child(CardScript.rule())
	col.add_child(CardScript.bullet_list([
		"Quita %d–%d de estrés al terminar la semana" % [int(rel[0]), int(rel[1])],
		"Le quita el Quebranto",
		"No sale de expedición esta semana",
		"Cupos: %d de %d ocupados" % [used, cap],
	]))
	var fx: Array = a.get("side_effects", [])
	if not fx.is_empty():
		col.add_child(CardScript.section("Puede pasar (%d%%)" % int(round(float(a.get("side_chance", 0)) * 100.0))))
		var names: PackedStringArray = PackedStringArray()
		for s in fx:
			names.append(_side_effect_name(s))
		col.add_child(CardScript.label(", ".join(names), 12, CardScript.TEXT))
	col.add_child(CardScript.rule())
	col.add_child(CardScript.label("Cuesta %s" % ("gratis" if price == 0 else "%d ₡" % price), 14, CardScript.GOLD, false))
	if why != "":
		col.add_child(CardScript.label(why, 12, CardScript.BAD))
	else:
		col.add_child(CardScript.label("Clic para mandarlo esta semana.", 12, CardScript.HINT))
	return made[0]


static func _side_effect_name(s: Dictionary) -> String:
	match str(s.get("kind", "")):
		"buff":
			return "%s (bueno)" % s.get("name", "")
		"debuff":
			return "%s (malo)" % s.get("name", "")
		"lose_colones":
			return "pierde plata"
		"gain_colones":
			return "gana plata"
		"lose_item":
			return "empeña algo"
		"extra_week":
			return "una semana más"
		"stress":
			return "más estrés"
	return str(s.get("kind", ""))

# --- Equipment (drag from the alforja onto a slot; click a slot to unequip) ---------

func _refresh_equipment() -> void:
	if _selected.is_empty() or not GameState.roster.has(_selected):
		_selected = GameState.roster[0] if not GameState.roster.is_empty() else {}
	_equip_title.text = "Arrastre armas, armaduras y accesorios desde la alforja (a la derecha) hasta un espacio, o haga clic en la pieza en la alforja. Clic en un espacio para quitarla. En expedición no se cambia el equipo en plena pelea."
	var pack_title: Label = $Right/VBox/PackTitle
	if _selling():
		pack_title.text = "Vendiendo: clic en un artículo (mitad de precio)"
		pack_title.add_theme_color_override("font_color", Color(1, 0.7, 0.45))
	else:
		pack_title.text = "Alforja (%d/%d espacios)" % [GameState.inventory.size(), GameState.inventory_slots()]
		pack_title.remove_theme_color_override("font_color")
	for es in _equip_slots:
		es.show_hero(_selected)
	for c in _pack_grid.get_children():
		c.queue_free()
	for k in GameState.inventory_slots():
		var b = InventorySlotScript.new()
		if k < GameState.inventory.size():
			b.setup(str(GameState.inventory[k]["id"]), int(GameState.inventory[k]["qty"]))
			b.used.connect(func(id: String):
				if _selling():
					_say(GameState.sell_item(id, _sell_shop()))
				elif GameState.is_equipment(id) and not _selected.is_empty():
					_say(GameState.equip(_selected, id))
			)
			if _selling():
				b.modulate = Color(1, 0.85, 0.6)
		else:
			b.setup("", 0)
		b.custom_minimum_size = PACK_SLOT
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


func _drop_sell(_at: Vector2, data: Variant, shop: String = "pulperia") -> void:
	_say(GameState.sell_item(str(data.get("id", "")), shop))


# --- Terminal de Buses ------------------------------------------------------------

## One card row per candidate (owner 2026-11-19: the info in the row, not in a tooltip):
## portrait, name, class and resolve; stats and ideal positions; skill icons (hover for each
## skill); quirks; and the hire button on the right.
func _refresh_recruits() -> void:
	for c in _recruit_box.get_children():
		c.queue_free()
	if GameState.recruit_pool.is_empty():
		var l := Label.new()
		l.text = "No hay más candidatos esta semana."
		_recruit_box.add_child(l)
		return
	var closed: bool = TownEventsScript.is_closed(GameState.active_event(), "terminal")
	for i in GameState.recruit_pool.size():
		_recruit_box.add_child(_recruit_row(i, GameState.recruit_pool[i], closed))


func _recruit_row(i: int, h: Dictionary, closed: bool) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", CardScript.flat(Color(0.1, 0.075, 0.06), Color(0.5, 0.38, 0.22, 0.7), 1, 4, 10))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)
	var head: Control = HeroCardScript.header(h, 56.0)
	head.custom_minimum_size = Vector2(230, 0)
	row.add_child(head)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 4)
	var ideal: Array = GameState.get_hero_template(str(h.get("hero_id", ""))).get("ranks", [])
	info.add_child(CardScript.label("PV %d · Vel %d · Prot %d%% · Posiciones %s" % [int(h.get("hp_max", 0)), int(h.get("speed", 0)),
		int(h.get("prot", 0)), FormationScript.ranks_text(ideal) if not ideal.is_empty() else "1–4"], 13, CardScript.TEXT, false))
	var skills := HBoxContainer.new()
	skills.add_theme_constant_override("separation", 4)
	var names: PackedStringArray = PackedStringArray()
	for sid in h.get("skill_ids", []):
		var sk: Dictionary = GameState.hero_skill(h, str(sid))
		if sk.is_empty():
			continue
		var icon = SkillButtonScript.new()
		icon.setup(str(sid), str(sk.get("kind", "attack")), "%s (rango %d)" % [sk.get("name", sid), int(sk.get("rank", 1))],
			SkillButtonScript.body_for(sk), int(sk.get("rank", 1)), SkillRanksScript.max_rank())
		icon.custom_minimum_size = Vector2(36, 36)
		skills.add_child(icon)
		names.append(str(sk.get("name", sid)))
	info.add_child(skills)
	info.add_child(CardScript.label(" · ".join(names), 12, CardScript.MUTED, true, 0.0))
	if not QuirksScript.of(h).is_empty():
		info.add_child(HeroCardScript.quirk_chips(h))
	row.add_child(info)
	var price: int = GameState.hire_cost(h)
	var full: bool = GameState.roster.size() >= GameState.roster_cap()
	var hire := Button.new()
	hire.text = "Contratar\n%s" % ("gratis" if price == 0 else "%d ₡" % price)
	hire.custom_minimum_size = Vector2(120, 0)
	hire.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hire.disabled = GameState.colones < price or full or closed
	hire.tooltip_text = "" if not hire.disabled else ("La terminal está cerrada esta semana." if closed
		else ("No hay más camas en la hacienda." if full else "No alcanza la plata."))
	hire.pressed.connect(func(): _say(GameState.hire_recruit(i)))
	row.add_child(hire)
	panel.set_meta("hire", hire)
	return panel


# --- Roster, party and EBAIS --------------------------------------------------------

func _refresh_roster() -> void:
	for c in _roster_list.get_children():
		c.queue_free()
	_roster_title.text = "Héroes %d/%d · cuadrilla %d/%d" % [
		GameState.roster.size(), GameState.roster_cap(), GameState.party.size(), GameState.PARTY_SIZE]
	_roster_title.tooltip_text = "Cuadrilla en orden de posición: 1 = adelante. Use ↑ ↓ para cambiar el orden."
	_roster_title.mouse_filter = Control.MOUSE_FILTER_PASS
	# Party first (rank order), then the rest.
	var ordered: Array = GameState.party.duplicate()
	for h in GameState.roster:
		if not GameState.is_in_party(h):
			ordered.append(h)
	for h in ordered:
		_roster_list.add_child(_roster_row(h))


## Two lines (P4-17, the roster panel is narrow): portrait + name and numbers, then the
## buttons (EBAIS, order, party, dismiss). The card on hover has everything else.
## What a click on a roster row does: the full sheet in the town view, else pick the hero
## for the open building.
func _roster_click_hint() -> String:
	return "Clic para ver su ficha completa." if _open_building == "" else "Clic para elegirlo en este edificio."


## Resistances in the hero sheet: icon + name + % per category, with a tooltip saying what
## each one protects against (desc in data/statuses.json resist_categories).
func _resist_grid(h: Dictionary) -> Control:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 4)
	for cat in StatusEffectsScript.resist_categories():
		var id: String = str(cat.get("id", ""))
		var v: int = StatusEffectsScript.resist_value(h, id)
		var cell := HBoxContainer.new()
		cell.add_theme_constant_override("separation", 6)
		cell.mouse_filter = Control.MOUSE_FILTER_STOP
		cell.tooltip_text = "%s — %s\n%s" % [cat.get("name", id), "Inmune" if v >= 100 else "%d%%" % v, cat.get("desc", "")]
		var tex: Texture2D = GameState.load_texture("res://assets/status/%s.png" % str(cat.get("icon", id)))
		if tex != null:
			var icon := TextureRect.new()
			icon.texture = tex
			icon.custom_minimum_size = Vector2(20, 20)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cell.add_child(icon)
		else:
			var d: Dictionary = StatusEffectsScript.def(id)
			var badge := CardScript.chip(str(cat.get("letter", d.get("letter", "?"))), Color(str(cat.get("color", d.get("color", "#777777")))))
			badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cell.add_child(badge)
		cell.add_child(CardScript.label(str(cat.get("name", id)), 12, CardScript.MUTED, false))
		cell.add_child(CardScript.label("Inmune" if v >= 100 else "%d%%" % v, 12, Color(0.53, 0.67, 1.0) if v >= 100 else CardScript.TEXT, false))
		grid.add_child(cell)
	return grid


## The hero's full sheet (owner 2026-11-19), opened by clicking a roster row while no building
## is open: big portrait, state, every stat, resistances, equipment (item cards on hover),
## the four skills with their rank (skill cards on hover), quirks with what they do, and the
## expedition record.
func _show_hero_sheet(h: Dictionary) -> void:
	var made: Array = _card_dialog("Ficha de %s" % h.get("name", "?"), 620.0)
	var dlg: AcceptDialog = made[0]
	var outer: VBoxContainer = made[1]
	dlg.ok_button_text = "Cerrar"
	var scroll := ScrollContainer.new()
	scroll.name = "SheetScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(620, 560)
	outer.add_child(scroll)
	var col := VBoxContainer.new()
	col.name = "Sheet"
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 8)
	scroll.add_child(col)
	var CW: float = 590.0
	# Portrait, name, class, resolve and state.
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	top.add_child(CardScript.picture(HeroCardScript.portrait_path(h), 150.0))
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", 4)
	titles.add_child(CardScript.title_label(str(h.get("name", "?")), 22, 0.0))
	titles.add_child(CardScript.label(str(h.get("class_name", "")), 15, CardScript.MUTED, false))
	var lvl: int = int(h.get("resolve_level", 0))
	var pr: Dictionary = ResolveSystemScript.progress(h)
	var xp: String = "máxima" if lvl >= ResolveSystemScript.MAX_LEVEL else "%d/%d XP para la siguiente" % [int(pr["current"]), int(pr["needed"])]
	titles.add_child(CardScript.label("Resolución %d · %s (%s)" % [lvl, ResolveSystemScript.level_name(lvl), xp], 13, CardScript.TEXT, false))
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 4)
	chips.add_theme_constant_override("v_separation", 3)
	var aff: String = str(h.get("affliction_id", ""))
	if aff != "":
		chips.add_child(CardScript.chip("Quebranto: %s" % StressSystemScript.affliction_name(aff), Color(0.82, 0.32, 0.28), 11))
	elif str(h.get("virtud_id", "")) != "":
		chips.add_child(CardScript.chip("Virtud: %s" % StressSystemScript.virtud_name(str(h["virtud_id"])), Color(0.45, 0.72, 0.4), 11))
	if GameState.is_in_party(h):
		chips.add_child(CardScript.chip("Cuadrilla · posición %d" % (GameState.party.find(h) + 1), Color(0.72, 0.56, 0.3), 11))
	if GameState.busy_place(h) != "":
		chips.add_child(CardScript.chip("Esta semana en %s" % GameState.busy_place(h), Color(0.5, 0.55, 0.7), 11))
	titles.add_child(chips)
	var ideal: Array = GameState.get_hero_template(str(h.get("hero_id", ""))).get("ranks", [])
	titles.add_child(CardScript.label("Posiciones ideales en combate: %s" % (FormationScript.ranks_text(ideal) if not ideal.is_empty() else "1–4"), 12, CardScript.MUTED, false))
	top.add_child(titles)
	col.add_child(top)
	col.add_child(CardScript.rule())
	# Stats.
	col.add_child(CardScript.section("Estadísticas"))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 4)
	var stat_rows: Array = [
		["PV", "%d/%d" % [int(h.get("hp", 0)), int(h.get("hp_max", 0))]],
		["Estrés", "%d/200" % int(h.get("stress", 0))],
		["Velocidad", str(int(h.get("speed", 0)))],
		["Precisión", str(int(h.get("accuracy", 0)))],
		["Esquiva", str(int(h.get("dodge", 0)))],
		["Crítico", "%d%%" % int(h.get("crit", 0))],
		["Protección", "%d%%" % int(h.get("prot", 0))],
		["Daño extra", "%+d" % int(h.get("dmg_bonus", 0))],
		["Resist. estrés", "%d%%" % int(h.get("stress_resist", 0))],
	]
	if str(h.get("element", "")) != "":
		stat_rows.append(["Arma de", str(GameState.ELEMENT_NAMES.get(str(h["element"]), h["element"]))])
	for r in stat_rows:
		grid.add_child(CardScript.label(str(r[0]), 13, CardScript.MUTED, false))
		grid.add_child(CardScript.label(str(r[1]), 13, CardScript.TEXT, false))
	col.add_child(grid)
	# Resistances (status) and elements from equipment.
	col.add_child(CardScript.section("Resistencias"))
	col.add_child(_resist_grid(h))
	var el: PackedStringArray = PackedStringArray()
	var rs = h.get("resist", {})
	if rs is Dictionary:
		for e in rs:
			el.append("%s ×%s" % [GameState.ELEMENT_NAMES.get(str(e), e), String.num(float(rs[e]), 2)])
	if not el.is_empty():
		col.add_child(CardScript.label("Elementos: " + " · ".join(el), 12, CardScript.TEXT, true, CW))
	col.add_child(CardScript.rule())
	# Equipment.
	col.add_child(CardScript.section("Equipo"))
	var eq_row := HBoxContainer.new()
	eq_row.add_theme_constant_override("separation", 8)
	var eq = h.get("equipment", {})
	var slot_names := {"weapon": "Arma", "armor": "Armadura", "accessory1": "Accesorio", "accessory2": "Accesorio"}
	for slot in GameState.EQUIP_SLOTS:
		var id: String = str(eq.get(slot, "")) if eq is Dictionary else ""
		var box := VBoxContainer.new()
		box.custom_minimum_size = Vector2(138, 0)
		box.add_theme_constant_override("separation", 2)
		box.add_child(CardScript.label(str(slot_names.get(slot, slot)), 11, CardScript.HINT, false))
		if id == "":
			box.add_child(CardScript.label("— vacío —", 12, CardScript.MUTED, false))
		else:
			var tile = ItemHoverScript.new()
			tile.setup(id)
			var tr := HBoxContainer.new()
			tr.add_theme_constant_override("separation", 6)
			tr.add_child(CardScript.picture("res://assets/items/%s.png" % id, 40.0))
			tr.add_child(CardScript.label(str(GameState.get_item(id).get("name", id)), 12, CardScript.TEXT, true, 84.0))
			tile.add_child(tr)
			box.add_child(tile)
		eq_row.add_child(box)
	col.add_child(eq_row)
	col.add_child(CardScript.rule())
	# Skills: icon (card on hover) with rank pips, then name and what it does.
	col.add_child(CardScript.section("Habilidades"))
	for sid in h.get("skill_ids", []):
		var sk: Dictionary = GameState.hero_skill(h, str(sid))
		if sk.is_empty():
			continue
		var rank: int = int(sk.get("rank", 1))
		var srow := HBoxContainer.new()
		srow.add_theme_constant_override("separation", 10)
		var icon = SkillButtonScript.new()
		icon.setup(str(sid), str(sk.get("kind", "attack")), "%s (rango %d)" % [sk.get("name", sid), rank],
			SkillButtonScript.body_for(sk), rank, SkillRanksScript.max_rank())
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		srow.add_child(icon)
		var stext := VBoxContainer.new()
		stext.add_theme_constant_override("separation", 1)
		stext.add_child(CardScript.label("%s · rango %d/%d" % [sk.get("name", sid), rank, SkillRanksScript.max_rank()], 14, CardScript.GOLD, false))
		var body: PackedStringArray = SkillButtonScript.body_for(sk).split("\n")
		for line in body:
			stext.add_child(CardScript.label(line, 12, CardScript.TEXT if line == body[body.size() - 1] else CardScript.MUTED, true, 520.0))
		srow.add_child(stext)
		col.add_child(srow)
	col.add_child(CardScript.rule())
	# Quirks: badge (tooltip) and the flavour + effect written out.
	col.add_child(CardScript.section("Rasgos y enfermedades"))
	var qs: Array = QuirksScript.of(h)
	if qs.is_empty():
		col.add_child(CardScript.label("Ninguno.", 12, CardScript.MUTED, false))
	for e in qs:
		var q: Dictionary = QuirksScript.get_quirk(str(e["id"]))
		var qrow := HBoxContainer.new()
		qrow.add_theme_constant_override("separation", 8)
		var chip: Control = CardScript.chip(str(q.get("name", "")) + (" · fijado" if bool(e.get("locked", false)) else ""),
			HeroCardScript.QUIRK_COLORS.get(str(q.get("kind", "")), CardScript.MUTED), 11)
		chip.tooltip_text = HeroCardScript.quirk_tooltip(str(e["id"]), bool(e.get("locked", false)))
		chip.mouse_filter = Control.MOUSE_FILTER_STOP
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		qrow.add_child(chip)
		qrow.add_child(CardScript.label("%s — %s" % [q.get("desc", ""), QuirksScript.mods_text(str(e["id"]))], 12, CardScript.TEXT, true, 400.0))
		col.add_child(qrow)
	# Camp skills (fogata).
	var camp: Array = CampingSystemScript.hero_skills(h)
	if not camp.is_empty():
		col.add_child(CardScript.rule())
		col.add_child(CardScript.section("Habilidades de fogata"))
		for cs in CampingSystemScript.shared_skills(h):
			col.add_child(CardScript.label("◆ %s (%d pts.) — %s" % [cs.get("name", "?"), int(cs.get("cost", 0)), cs.get("desc", "")], 12, CardScript.TEXT, true, CW))
		col.add_child(CardScript.label("De su oficio (en cada fogata le salen %d de las que conoce, al azar):" % CampingSystemScript.class_skills_per_camp(), 12, CardScript.MUTED, true, CW))
		var fx: String = CampingSystemScript.fixed_id(h)
		for cs in CampingSystemScript.class_pool(h):
			var k: bool = CampingSystemScript.knows(h, str(cs["id"]))
			var mark: String = " · fija" if str(cs["id"]) == fx else ("" if k else " · no la conoce (Guardabosques)")
			col.add_child(CardScript.label("%s %s (%d pts.)%s — %s" % ["◇" if k else "·", cs.get("name", "?"), int(cs.get("cost", 0)), mark, cs.get("desc", "")], 12, CardScript.TEXT if k else CardScript.MUTED, true, CW))
	if int(h.get("borde_checks", 0)) > 0:
		col.add_child(CardScript.label("Ya sobrevivió %d golpe(s) de gracia en esta expedición." % int(h["borde_checks"]), 12, CardScript.BAD, true, CW))
	add_child(dlg)
	_popup_card(dlg)


func _roster_row(h: Dictionary) -> Control:
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 2)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	# Portrait | name and numbers over a small button line | ↑↓ stacked on the right (owner
	# 2026-11-19: the four party heroes fit the panel without scrolling).
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 0)
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 4)
	var arrows := VBoxContainer.new()
	arrows.add_theme_constant_override("separation", 2)
	arrows.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var pic := TextureRect.new()
	pic.custom_minimum_size = Vector2(44, 44)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var p: String = GameState.portrait_path(h)
	pic.texture = GameState.load_texture(p)
	row.add_child(pic)
	var info = CardButtonScript.new()
	info.flat = true
	info.alignment = HORIZONTAL_ALIGNMENT_LEFT
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_font_size_override("font_size", 13)
	if is_same(h, _selected):
		info.add_theme_color_override("font_color", Color(1, 0.9, 0.55))
	info.pressed.connect(func():
		# With no building open, a click opens the hero's full sheet (owner 2026-11-19).
		if _open_building == "":
			_selected = h
			_refresh()
			_show_hero_sheet(h)
			return
		if _open_building == "taller":
			_equip_open = not (_equip_open and is_same(_selected, h))
		_selected = h
		_refresh()
	)
	var extra: String = ""
	var aff: String = str(h.get("affliction_id", ""))
	if aff != "":
		extra = " · Quebranto: %s" % StressSystemScript.affliction_name(aff)
	elif str(h.get("virtud_id", "")) != "":
		extra = " · Virtud: %s" % StressSystemScript.virtud_name(str(h["virtud_id"]))
	if GameState.in_clinic(h):
		extra += " · En la Clínica esta semana"
	elif HubActivitiesScript.is_busy(h):
		extra += " · En %s (%s)" % [HubActivitiesScript.building_name(str(h["busy"].get("building", ""))),
			HubActivitiesScript.booked(h).get("name", "?")]
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
	info.text = "%s%s — %s%s\nPV %d/%d · Estrés %d · Res. %d%s" % [
		rank, h.get("name", "?"), h.get("class_name", ""), extra,
		int(h.get("hp", 0)), int(h.get("hp_max", 0)), int(h.get("stress", 0)), lvl, warn]
	if warn != "":
		info.add_theme_color_override("font_color", Color(1, 0.9, 0.55) if is_same(h, _selected) else Color(0.95, 0.7, 0.5))
	# Long lines clip instead of pushing the buttons off-screen; the tooltip has everything.
	info.clip_text = true
	var ranks: PackedStringArray = PackedStringArray()
	for sid in h.get("skill_ids", []):
		ranks.append("%s %d" % [GameState.get_skill(str(sid)).get("name", sid), SkillRanksScript.rank(h, str(sid))])
	info.tooltip_text = "%s\nResolución %d: %s (%s)\nPosiciones ideales en combate: %s (el orden de la cuadrilla es la posición: 1 = adelante)\nHabilidades (rango): %s\n%s" % [
		info.text, lvl, ResolveSystemScript.level_name(lvl), xp, ideal_txt, ", ".join(ranks), _roster_click_hint()]
	var quirk_names: Array = QuirksScript.of(h).map(func(e): return "%s%s" % [QuirksScript.get_quirk(str(e["id"])).get("name", ""), " (fijado)" if e.get("locked", false) else ""])
	if not quirk_names.is_empty():
		info.tooltip_text += "\nRasgos: " + ", ".join(quirk_names)
	var card_lines: Array = ["Posiciones ideales: %s" % ideal_txt]
	if GameState.busy_place(h) != "":
		card_lines.append("Esta semana en %s." % GameState.busy_place(h))
	info.card = HeroCardScript.build.bind(h, _roster_click_hint(), warn.strip_edges().trim_prefix("⚠ "), card_lines)
	mid.add_child(info)
	row.add_child(mid)
	var cost: int = GameState.heal_cost(h)
	if int(h.get("hp", 0)) < int(h.get("hp_max", 0)) and not h.get("dead", false):
		var heal := Button.new()
		var ebais_closed: bool = TownEventsScript.is_closed(GameState.active_event(), "ebais")
		heal.text = "EBAIS cerrado" if ebais_closed else ("EBAIS gratis" if cost == 0 else "EBAIS %d ₡" % cost)
		heal.tooltip_text = "Curar todos los PV en el EBAIS del pueblo."
		heal.disabled = ebais_closed or GameState.colones < cost
		heal.pressed.connect(func(): _say(GameState.heal_hero(h)))
		btns.add_child(heal)
	if in_party:
		var up := Button.new()
		up.text = "↑"
		up.tooltip_text = "Subir de rango (más adelante)"
		up.pressed.connect(func():
			GameState.move_in_party(h, -1)
			_say("")
		)
		arrows.add_child(up)
		var down := Button.new()
		down.text = "↓"
		down.tooltip_text = "Bajar de rango (más atrás)"
		down.pressed.connect(func():
			GameState.move_in_party(h, 1)
			_say("")
		)
		arrows.add_child(down)
	var fire := Button.new()
	fire.text = "Despedir"
	fire.tooltip_text = "Despedir a este héroe para siempre. Su equipo vuelve a la alforja."
	fire.add_theme_color_override("font_color", Color(0.95, 0.55, 0.5))
	fire.disabled = GameState.roster.size() <= 1
	fire.pressed.connect(_confirm_dismiss.bind(h))
	btns.add_child(fire)
	var cb := CheckBox.new()
	cb.text = "Cuadrilla"
	cb.button_pressed = in_party
	cb.disabled = GameState.hero_busy(h) and not in_party
	cb.toggled.connect(func(on: bool): _say(GameState.set_in_party(h, on)))
	btns.add_child(cb)
	for c in btns.get_children() + arrows.get_children():
		if c is Button:
			c.add_theme_font_size_override("font_size", 12)
			c.custom_minimum_size.y = 24
	for c in arrows.get_children():
		c.custom_minimum_size = Vector2(28, 26)
	mid.add_child(btns)
	row.add_child(arrows)
	outer.add_child(row)
	outer.add_child(HSeparator.new())
	return outer


func _confirm_dismiss(h: Dictionary) -> void:
	var made: Array = _card_dialog("Despedir a %s" % h.get("name", "?"), 460.0, true)
	var dlg: ConfirmationDialog = made[0]
	var col: VBoxContainer = made[1]
	col.add_child(HeroCardScript.header(h))
	col.add_child(CardScript.rule())
	col.add_child(CardScript.label("Se va de la hacienda y no vuelve.", 14, CardScript.BAD, false))
	col.add_child(CardScript.label("Su equipo regresa a la alforja.", 12, CardScript.MUTED, false))
	dlg.ok_button_text = "Despedir"
	dlg.cancel_button_text = "Cancelar"
	dlg.confirmed.connect(func():
		if is_same(_selected, h):
			_selected = {}
		_say(GameState.dismiss_hero(h))
	)
	add_child(dlg)
	_popup_card(dlg)


func _on_start_pressed() -> void:
	if GameState.living_party_count() <= 0:
		_hub_status.text = "Elige al menos un héroe para la cuadrilla."
		return
	if not GameState.party_refusals().is_empty():
		_hub_status.text = "Héroes de mucha resolución no salen a expediciones fáciles: sube la dificultad o cambia la cuadrilla."
		return
	# Covered for exploring every room: nothing to ask.
	if GameState.missing_provisions("", "full").is_empty():
		start_mission_requested.emit()
		return
	_confirm_provisions()


## DD-style provisioning (P1-18, P5-02e; card P4-15): before leaving, show the region's two
## recommended kits (a run straight to the boss, or exploring every room) against the
## alforja, and offer to buy what either one lacks at the Pulpería.
func _confirm_provisions() -> void:
	var made: Array = _card_dialog("Provisiones", 480.0, true)
	var dlg: ConfirmationDialog = made[0]
	var col: VBoxContainer = made[1]
	col.add_child(CardScript.label("Provisiones recomendadas para esta expedición:", 14, CardScript.TEXT, false))
	var totals: Dictionary = {}
	for kit in ["short", "full"]:
		var missing: Array = GameState.missing_provisions("", kit)
		var total: int = 0
		col.add_child(CardScript.rule())
		col.add_child(CardScript.section("Vuelta corta (directo al jefe)" if kit == "short" else "Explorar todo"))
		if missing.is_empty():
			col.add_child(CardScript.label("Ya está completa.", 13, CardScript.GOOD, false))
		for m in missing:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			row.add_child(CardScript.picture("res://assets/items/%s.png" % str(m["id"]), 30.0))
			var nm := CardScript.label("%d × %s" % [int(m["missing"]), m["name"]], 14, CardScript.TEXT, false)
			nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(nm)
			var pr := CardScript.label("%d ₡" % int(m["price"]), 14, CardScript.GOLD, false)
			pr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(pr)
			col.add_child(row)
			total += int(m["price"])
		totals[kit] = total
	col.add_child(CardScript.label("Sin comida, la cuadrilla pasa hambre; sin candelas, camina a oscuras.", 12, CardScript.HINT, true, 456.0))
	dlg.ok_button_text = "Salir así"
	dlg.cancel_button_text = "Volver"
	if int(totals["short"]) > 0:
		dlg.add_button("Vuelta corta (%d ₡)" % int(totals["short"]), true, "short")
	dlg.add_button("Explorar todo (%d ₡)" % int(totals["full"]), true, "full")
	dlg.confirmed.connect(func(): start_mission_requested.emit())
	dlg.custom_action.connect(func(action: StringName):
		dlg.hide()
		_say(GameState.buy_missing_provisions("", str(action)))
	)
	add_child(dlg)
	_popup_card(dlg)


func _on_quit_pressed() -> void:
	get_tree().quit()


# --- Town view (P4-17) ------------------------------------------------------------------

## Loads a picture. *.import files are not in git, so right after a pull the editor may not
## have imported new art yet: then the PNG is read straight from disk.
static func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var tex := load(path) as Texture2D
		if tex != null:
			return tex
	if FileAccess.file_exists(path):
		var img := Image.load_from_file(path)
		if img != null and not img.is_empty():
			return ImageTexture.create_from_image(img)
	push_warning("Town art missing: %s" % path)
	return null


static func _load_town() -> Dictionary:
	var f := FileAccess.open(TOWN_PATH, FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}


## One TownBuilding per data/town.json row, drawn back to front (by where it stands).
func _build_town() -> void:
	# P4-19: the town painted as one picture (tools/town_paint.py). Each building is then its
	# crop of that painting, at the exact rect the tool wrote, so the town reads as one place.
	_painted = _load_texture(PAINTED_PATH) if ResourceLoader.exists(PAINTED_PATH) or FileAccess.file_exists(PAINTED_PATH) else null
	_painted_rects = {}
	if _painted != null:
		var f := FileAccess.open(PAINTED_LAYOUT, FileAccess.READ)
		var parsed = JSON.parse_string(f.get_as_text()) if f != null else null
		if parsed is Dictionary:
			_painted_rects = parsed.get("rects", {})
		var pic := TextureRect.new()
		pic.name = "Painting"
		pic.texture = _painted
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_SCALE
		_town.add_child(pic)
		_bg.texture = _painted
		_bg.modulate = Color(0.55, 0.5, 0.55)
	# The plaza: dirt fading in under the buildings, so they stand on something.
	var grad := Gradient.new()
	grad.set_color(0, Color(0.09, 0.06, 0.05, 0.0))
	grad.set_color(1, Color(0.075, 0.05, 0.04, 0.97))
	grad.add_point(0.35, Color(0.1, 0.07, 0.055, 0.75))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	var ground := TextureRect.new()
	ground.name = "Ground"
	ground.texture = gt
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ground.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ground.stretch_mode = TextureRect.STRETCH_SCALE
	if _painted == null:
		_town.add_child(ground)
	var rows: Array = _town_data.get("buildings", []).duplicate()
	rows.sort_custom(func(a, b): return float(a.get("bottom", 0)) < float(b.get("bottom", 0)))
	for row in rows:
		var art: String = str(row.get("art", ""))
		var bid: String = str(row.get("id", ""))
		var tex: Texture2D = null
		if _painted_rects.has(bid):
			tex = _load_texture("%s/%s.png" % [PAINTED_PATH.get_base_dir().path_join("painted"), bid])
		if tex == null:
			tex = _load_texture(art)
		if tex == null:
			continue
		var b = TownBuildingScript.new()
		b.setup(row, tex)
		b.set_meta("row", row)
		b.chosen.connect(open_building)
		_town.add_child(b)
		_buildings[str(row.get("id", ""))] = b
	_town.resized.connect(_layout_town)
	_layout_town()


## Places the buildings: design coordinates scaled to the screen, keeping the art's aspect.
func _layout_town() -> void:
	var design: Array = _town_data.get("design_size", [1280, 720])
	var k: float = minf(_town.size.x / float(design[0]), _town.size.y / float(design[1]))
	if k <= 0.0:
		k = 1.0
	var pic: Control = _town.get_node_or_null("Painting")
	if pic != null:
		pic.position = Vector2.ZERO
		pic.size = Vector2(float(design[0]), float(design[1])) * k
	var ground: Control = _town.get_node_or_null("Ground")
	if ground != null:
		var top: float = float(_town_data.get("ground_top", 360)) * k
		ground.position = Vector2(0, top)
		ground.size = Vector2(_town.size.x, _town.size.y - top)
	for bid in _buildings:
		var b = _buildings[bid]
		var row: Dictionary = b.get_meta("row")
		if _painted_rects.has(bid):
			var r: Array = _painted_rects[bid]
			b.position = Vector2(float(r[0]), float(r[1])) * k
			b.size = Vector2(float(r[2]), float(r[3])) * k
			continue
		var tex: Texture2D = b.texture
		var h: float = float(row.get("height", 200)) * k
		var w: float = h * float(tex.get_width()) / float(maxi(tex.get_height(), 1))
		b.size = Vector2(w, h)
		b.position = Vector2(float(row.get("x", 0)) * k - w / 2.0, float(row.get("bottom", 0)) * k - h)


## Greys out what a town event closed and notes partial closures on the name plate.
func _refresh_town() -> void:
	var ev: Dictionary = GameState.active_event()
	for bid in _buildings:
		var b = _buildings[bid]
		var row: Dictionary = b.get_meta("row")
		var closed: bool = false
		for c in row.get("closed_by", []):
			closed = closed or TownEventsScript.is_closed(ev, str(c))
		var notes: PackedStringArray = PackedStringArray()
		if closed:
			notes.append("Cerrada esta semana")
		var note_by: Dictionary = row.get("note_by", {})
		for c in note_by:
			if TownEventsScript.is_closed(ev, str(c)):
				notes.append(str(note_by[c]))
		b.set_closed(closed, " · ".join(notes))


## Opens a building's window (its page of the hub). Clicking the same one again closes it.
func open_building(bid: String) -> void:
	if not _buildings.has(bid) and _pages.get_node_or_null(bid) == null:
		return
	_open_building = bid
	var row: Dictionary = _buildings[bid].get_meta("row") if _buildings.has(bid) else {}
	$Building/VBox/Head/Texts/Name.text = str(row.get("name", bid))
	$Building/VBox/Head/Texts/Blurb.text = str(row.get("text", ""))
	$Building/VBox/Head/Picture.texture = _buildings[bid].texture if _buildings.has(bid) else null
	for page in _pages.get_children():
		page.visible = page.name == bid
	_window.visible = true
	if bid == "taller":
		_equip_open = false
	_refresh_who()


func close_building() -> void:
	_open_building = ""
	_window.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if OS.is_debug_build() and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F12:
		_show_dev_menu()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") and _window.visible:
		close_building()
		get_viewport().set_input_as_handled()


## "Para: <hero>" strip on the pages that work on the selected hero.
func _refresh_who() -> void:
	if _who == null:
		return
	for c in _who.get_children():
		c.queue_free()
	_refresh_equip_fold()
	_who.visible = _window.visible and _open_building in HERO_PAGES and not _selected.is_empty() \
		and (_open_building != "taller" or _equip_open)
	if not _who.visible:
		return
	var head: Control = HeroCardScript.header(_selected, 44.0)
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_who.add_child(head)
	_who.add_child(CardScript.label("Clic en otro héroe a la derecha para cambiar.", 12, CardScript.HINT, false))
	_who.get_child(1).size_flags_vertical = Control.SIZE_SHRINK_CENTER


## The Taller's fold bar: "▸ Equipo de X" (closed) / "▾ Equipo de X ✕" (open), and the
## slots and their help shown only while it is open.
func _refresh_equip_fold() -> void:
	if _equip_bar == null:
		_equip_bar = Button.new()
		_equip_bar.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_equip_bar.tooltip_text = "Equipo del héroe\nClic aquí o en un héroe a la derecha para abrirlo; clic en el mismo héroe para cerrarlo."
		_equip_bar.pressed.connect(func():
			_equip_open = not _equip_open
			_refresh_who()
		)
		var page: Control = _pages.get_node("taller")
		page.add_child(_equip_bar)
		page.move_child(_equip_bar, 0)
	var who: String = str(_selected.get("name", "—"))
	_equip_bar.text = ("▾ Equipo de %s  ✕" % who) if _equip_open else ("▸ Equipo de %s (clic en un héroe para ponerle o quitarle equipo)" % who)
	_equip_title.visible = _equip_open
	_equip_row.visible = _equip_open


# --- Dev menu (debug builds only, owner 2026-11-19) -------------------------------------

## Plata infinita, the next week right away (the same week change as coming back from an
## expedition, without one) and +1 resolución per hero. Debug builds only (DEV button, F12).
func _show_dev_menu() -> void:
	if not OS.is_debug_build():
		return
	var made: Array = _card_dialog("Menú de desarrollo", 480.0)
	var dlg: AcceptDialog = made[0]
	var col: VBoxContainer = made[1]
	dlg.ok_button_text = "Cerrar"
	var reopen := func():
		dlg.hide()
		_show_dev_menu.call_deferred()
	var money := CheckBox.new()
	money.text = "Plata infinita (%d ₡ siempre)" % GameState.DEV_MONEY
	money.button_pressed = GameState.dev_infinite_money
	money.toggled.connect(func(on: bool):
		GameState.dev_set_infinite_money(on)
		_say("Plata infinita %s." % ("activada" if on else "desactivada"))
	)
	col.add_child(money)
	var cash_row := HBoxContainer.new()
	cash_row.add_theme_constant_override("separation", 10)
	var cash_lbl := Label.new()
	cash_lbl.text = "Colones en la bolsa:"
	cash_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cash_row.add_child(cash_lbl)
	var cash := SpinBox.new()
	cash.name = "DevColones"
	cash.max_value = GameState.DEV_MONEY
	cash.step = 1
	cash.value = GameState.colones
	cash.suffix = "₡"
	cash.custom_minimum_size = Vector2(150, 0)
	cash_row.add_child(cash)
	var set_cash := Button.new()
	set_cash.text = "Poner"
	set_cash.tooltip_text = "Deja exactamente esa cantidad de colones (apaga la plata infinita)."
	set_cash.pressed.connect(func():
		cash.apply()
		GameState.dev_set_colones(int(cash.value))
		SaveService.save_game()
		_say("Ahora hay %d ₡ en la bolsa." % GameState.colones)
		_refresh()
		reopen.call()
	)
	cash_row.add_child(set_cash)
	col.add_child(cash_row)
	var week := Button.new()
	week.text = "Pasar a la semana %d ya (sin expedición)" % (GameState.week + 1)
	week.tooltip_text = "Todo lo de un cambio de semana: descanso en la hacienda, fin de la Iglesia/Cantina y la Clínica, candidatos nuevos y el evento del pueblo."
	week.pressed.connect(func():
		GameState.dev_skip_week()
		SaveService.save_game()
		_hub_status.text = GameState.last_week_report
		_build_shop()
		_refresh()
		reopen.call()
		if GameState.active_event_id != "" and not GameState.event_seen:
			_show_event_card.call_deferred()
	)
	col.add_child(week)
	col.add_child(CardScript.rule())
	col.add_child(CardScript.section("Resolución"))
	# The hero list scrolls (up to 30 beds), so the dialog never runs off the screen.
	var hero_scroll := ScrollContainer.new()
	hero_scroll.name = "DevHeroes"
	hero_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hero_scroll.custom_minimum_size = Vector2(0, minf(300.0, 52.0 * GameState.roster.size()))
	var hero_col := VBoxContainer.new()
	hero_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_col.add_theme_constant_override("separation", 6)
	hero_scroll.add_child(hero_col)
	col.add_child(hero_scroll)
	for h in GameState.roster:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var head: Control = HeroCardScript.header(h, 40.0)
		head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(head)
		var up := Button.new()
		up.text = "+1 Resolución"
		up.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		up.disabled = int(h.get("resolve_level", 0)) >= ResolveSystemScript.MAX_LEVEL
		up.pressed.connect(func():
			_say(GameState.dev_add_resolve(h))
			reopen.call()
		)
		row.add_child(up)
		hero_col.add_child(row)
	col.add_child(CardScript.rule())
	var wipe := Button.new()
	wipe.text = "Reiniciar el juego desde cero…"
	wipe.tooltip_text = "Borra la partida guardada y empieza como la primera vez: semana 1, los cuatro héroes iniciales, la alforja y la plata de inicio."
	wipe.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45))
	wipe.pressed.connect(func():
		dlg.hide()
		_confirm_dev_reset.call_deferred()
	)
	col.add_child(wipe)
	add_child(dlg)
	_popup_card(dlg)


## Asks before wiping the campaign; then the save is deleted and the town reloads fresh.
func _confirm_dev_reset() -> void:
	var made: Array = _card_dialog("¿Reiniciar todo?", 420.0)
	var dlg: AcceptDialog = made[0]
	var col: VBoxContainer = made[1]
	col.add_child(CardScript.label("Se borra la partida guardada (y su respaldo) y el juego empieza como la primera vez. No se puede deshacer.", 14, CardScript.TEXT, true))
	dlg.ok_button_text = "Reiniciar"
	dlg.add_cancel_button("Cancelar")
	dlg.confirmed.connect(dev_reset_game)
	add_child(dlg)
	_popup_card(dlg)


## The dev reset itself (tests call it directly).
func dev_reset_game() -> void:
	SaveService.wipe_save()
	GameState.dev_reset_campaign()
	SaveService.save_game()
	if is_inside_tree() and get_tree().current_scene == self:
		get_tree().reload_current_scene.call_deferred()


# --- Town event of the week (docs/02 §12) -----------------------------------------------

func _build_event_button() -> void:
	_event_btn = Button.new()
	_event_btn.add_theme_font_size_override("font_size", 14)
	_event_btn.custom_minimum_size = Vector2(250, 0)
	_event_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_event_btn.clip_text = true
	_event_btn.pressed.connect(_show_event_card)
	$Banner/Row.add_child(_event_btn)


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
	var made: Array = _card_dialog(str(ev.get("name", "")), 540.0)
	var dlg: AcceptDialog = made[0]
	var col: VBoxContainer = made[1]
	dlg.ok_button_text = "Entendido"
	var hue: Color = {"positive": Color(0.45, 0.72, 0.4), "negative": Color(0.82, 0.38, 0.32)}.get(str(ev.get("kind", "")), Color(0.78, 0.64, 0.3))
	col.add_child(CardScript.chip(TownEventsScript.kind_label(ev), hue, 11))
	col.add_child(CardScript.label(str(ev.get("text", "")), 14, CardScript.TEXT, true, 540.0))
	# What happened right away (if we still have the report) + what lasts the week.
	var lines: PackedStringArray = GameState.event_report.duplicate()
	lines.append_array(TownEventsScript.effect_lines(ev, GameState.event_report.is_empty()))
	if not lines.is_empty():
		col.add_child(CardScript.rule())
		col.add_child(CardScript.section("Esta semana"))
		col.add_child(CardScript.bullet_list(Array(lines), true))
	var back: Array = GameState.resurrect_candidates()
	if not back.is_empty():
		col.add_child(CardScript.rule())
		col.add_child(CardScript.section("Traer de vuelta a uno"))
	for h in back:
		var b = CardButtonScript.new()
		b.text = "Traer de vuelta a %s — %s, Resolución %d" % [h.get("name", "?"), h.get("class_name", ""), int(h.get("resolve_level", 0))]
		b.tooltip_text = b.text
		b.card = HeroCardScript.build.bind(h, "Vuelve con su resolución, pero sin equipo.")
		b.pressed.connect(func():
			dlg.hide()
			_say(GameState.resurrect(int(h.get("uid", 0))))
		)
		col.add_child(b)
	var offer: Dictionary = GameState.event_offer()
	if not offer.is_empty():
		col.add_child(CardScript.rule())
		var ob := Button.new()
		ob.text = "%s — %d ₡" % [offer.get("label", ""), int(offer.get("cost", 0))]
		ob.disabled = GameState.colones < int(offer.get("cost", 0))
		ob.pressed.connect(func():
			dlg.hide()
			_say(GameState.take_event_offer())
		)
		col.add_child(ob)
	add_child(dlg)
	_popup_card(dlg)
