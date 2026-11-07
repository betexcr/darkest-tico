extends Control

signal start_mission_requested

@onready var _roster: RichTextLabel = $VBox/RosterText
@onready var _gold: Label = $VBox/GoldLabel
@onready var _week: Label = $VBox/WeekLabel
@onready var _bg: TextureRect = $BgTexture
@onready var _region_option: OptionButton = $VBox/RegionRow/RegionOption
@onready var _shop_grid: GridContainer = $VBox/ShopGrid
@onready var _pack_label: Label = $VBox/PackLabel
@onready var _hub_status: Label = $VBox/HubStatus


func _ready() -> void:
	_try_optional_hub_ambient()
	_region_option.clear()
	for r in GameState.PLAYABLE_REGIONS:
		_region_option.add_item(str(r["name"]))
	_region_option.item_selected.connect(_on_region_selected)
	$VBox/BtnStart.pressed.connect(_on_start_pressed)
	$VBox/BtnQuit.pressed.connect(_on_quit_pressed)
	$VBox/BtnIglesia.pressed.connect(_on_iglesia_pressed)
	_sync_region_option_from_state()
	_try_load_hub_background()
	_build_shop()
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
	_hub_status.text = ""


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
			_bg.visible = true
			return
	var img2 := Image.create(512, 512, false, Image.FORMAT_RGB8)
	img2.fill(Color(0.11, 0.07, 0.15))
	_bg.texture = ImageTexture.create_from_image(img2)
	_bg.visible = true


func _refresh() -> void:
	_gold.text = "Colones: %d" % GameState.colones
	_week.text = "Semana: %d" % GameState.week
	var pack: PackedStringArray = PackedStringArray()
	for id in GameState.all_item_ids():
		var n: int = GameState.item_count(str(id))
		if n > 0:
			pack.append("%s ×%d" % [GameState.get_item(str(id)).get("name", id), n])
	_pack_label.text = "Alforja (%d/%d espacios): %s" % [
		GameState.inventory.size(), GameState.INVENTORY_SLOTS,
		", ".join(pack) if not pack.is_empty() else "vacía",
	]
	for b in _shop_grid.get_children():
		var item: Dictionary = GameState.get_item(str(b.get_meta("item_id", "")))
		b.disabled = GameState.colones < int(item.get("price", 0))
	var lines: PackedStringArray = PackedStringArray()
	var i := 1
	for h in GameState.party:
		if h is Dictionary:
			var tag := "☠" if h.get("dead", false) else "✓"
			var aff := str(h.get("affliction_id", ""))
			var vir := str(h.get("virtud_id", ""))
			var mental := ""
			if aff != "":
				mental = " [%s]" % aff
			elif vir != "":
				mental = " (%s)" % vir
			lines.append(
				"%d. %s %s — HP %d/%d  Estrés %d/%d%s" % [
					i,
					tag,
					h.get("name", "?"),
					h.get("hp", 0),
					h.get("hp_max", 20),
					h.get("stress", 0),
					h.get("stress_max", 200),
					mental,
				]
			)
		i += 1
	_roster.text = "\n".join(lines)


## One "buy" button per item (data/items.json), in file order.
func _build_shop() -> void:
	for id in GameState.all_item_ids():
		var item: Dictionary = GameState.get_item(str(id))
		var b := Button.new()
		b.text = "%s — %d ₡" % [item.get("name", id), int(item.get("price", 0))]
		b.tooltip_text = str(item.get("description", ""))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.set_meta("item_id", str(id))
		b.pressed.connect(_on_buy_pressed.bind(str(id)))
		_shop_grid.add_child(b)


func _on_buy_pressed(item_id: String) -> void:
	_hub_status.text = GameState.buy_item(item_id)
	SaveService.save_game()
	_refresh()


func _on_iglesia_pressed() -> void:
	var msg: String = GameState.iglesia_misa_rapida()
	_hub_status.text = msg
	_refresh()


func _on_start_pressed() -> void:
	start_mission_requested.emit()


func _on_quit_pressed() -> void:
	get_tree().quit()
