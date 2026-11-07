extends Node


## Party, currencies, JSON catalogs, expedition mission (in-memory only during play).


const DataLoaderScript := preload("res://scripts/data/data_loader.gd")

const ExpeditionLoaderScript := preload("res://scripts/domain/expedition_loader.gd")
const StressSystemScript := preload("res://scripts/domain/stress_system.gd")
const MapGeneratorScript := preload("res://scripts/domain/map_generator.gd")
const ItemEffectsScript := preload("res://scripts/domain/item_effects.gd")


const HEROES_PATH := "res://data/heroes.json"

const SKILLS_PATH := "res://data/skills.json"
const ENEMIES_PATH := "res://data/enemies.json"
const ITEMS_PATH := "res://data/items.json"
const INVENTORY_SLOTS := 16

const DEFAULT_REGION_PATH := "res://data/regions/sotanos.json"
const BOSQUE_REGION_PATH := "res://data/regions/bosque.json"

## Regions offered in the hub picker. Bosque is built but deferred to the Alpha phase (owner decision 2026-11-06).
## To re-enable it, add {"path": BOSQUE_REGION_PATH, "name": "Bosque nuboso maldito"}.
const PLAYABLE_REGIONS := [
	{"path": DEFAULT_REGION_PATH, "name": "Sótanos de la Hacienda"},
]


const SAVE_VERSION := 4


var colones: int = 5000

var week: int = 1


var _heroes_by_id: Dictionary = {}

var _skills_by_id: Dictionary = {}

var _enemies_by_id: Dictionary = {}


## Runtime party (max 4) — dictionaries mutated in combat.

var party: Array = []


## Expedition: not persisted mid-mission (cleared on load).

var mission_active: bool = false

var current_region_id: String = ""

var mission_region_data: Dictionary = {}

var mission_nodes_index: Dictionary = {}

var mission_light: int = 100

var mission_food: int = 8

var current_node_id: String = ""

var visited_node_ids: Array = []

var cleared_node_ids: Array = []

var objective_node_id: String = ""

var mission_params: Dictionary = {}


## Set before opening combat; read by combat_scene.

var combat_context: Dictionary = {}


## Filled by combat_scene when returning to expedition.

var combat_return_victory: bool = false

var combat_return_node_id: String = ""

## Hub prep (applied on next start_mission).
var selected_mission_region_path: String = DEFAULT_REGION_PATH

## Carried items, one entry per inventory slot: {"id": String, "qty": int} (P3-09).
var inventory: Array = []
## Uses of each item in the current room, outside combat. Reset on every move.
var node_item_uses: Dictionary = {}
var _items_by_id: Dictionary = {}
var _item_order: Array = []
var _starter_inventory: Array = []


func _ready() -> void:
	_load_registries()
	reset_inventory_to_starter()


func _load_registries() -> void:
	var h_data = DataLoaderScript.load_json(HEROES_PATH)
	var s_data = DataLoaderScript.load_json(SKILLS_PATH)
	var e_data = DataLoaderScript.load_json(ENEMIES_PATH)
	if h_data is Dictionary:
		_heroes_by_id = DataLoaderScript.heroes_catalog(h_data)
	if s_data is Dictionary:
		_skills_by_id = DataLoaderScript.skills_catalog(s_data)
	if e_data is Dictionary and e_data.get("enemies") is Dictionary:
		_enemies_by_id = e_data["enemies"] as Dictionary
	var i_data = DataLoaderScript.load_json(ITEMS_PATH)
	if i_data is Dictionary:
		for it in i_data.get("items", []):
			if it is Dictionary and it.has("id"):
				_items_by_id[str(it["id"])] = it
				_item_order.append(str(it["id"]))
		_starter_inventory = i_data.get("starter_inventory", [])


# --- Items and inventory (P3-09) ---------------------------------------------

func get_item(item_id: String) -> Dictionary:
	return _items_by_id.get(item_id, {})


## Item ids in data-file order (shop listing).
func all_item_ids() -> Array:
	return _item_order.duplicate()


func reset_inventory_to_starter() -> void:
	inventory.clear()
	for e in _starter_inventory:
		if e is Dictionary:
			add_item(str(e.get("id", "")), int(e.get("qty", 0)))


func item_count(item_id: String) -> int:
	var n: int = 0
	for slot in inventory:
		if str(slot["id"]) == item_id:
			n += int(slot["qty"])
	return n


## Adds up to `qty`, filling existing stacks first. Returns how many fit.
func add_item(item_id: String, qty: int) -> int:
	var item: Dictionary = get_item(item_id)
	if item.is_empty() or qty <= 0:
		return 0
	var stack: int = maxi(int(item.get("max_stack", 1)), 1)
	var left: int = qty
	for slot in inventory:
		if left <= 0:
			break
		if str(slot["id"]) == item_id and int(slot["qty"]) < stack:
			var put: int = mini(stack - int(slot["qty"]), left)
			slot["qty"] = int(slot["qty"]) + put
			left -= put
	while left > 0 and inventory.size() < INVENTORY_SLOTS:
		var put2: int = mini(stack, left)
		inventory.append({"id": item_id, "qty": put2})
		left -= put2
	return qty - left


func remove_item(item_id: String, qty: int = 1) -> bool:
	if item_count(item_id) < qty:
		return false
	var left: int = qty
	for k in range(inventory.size() - 1, -1, -1):
		if left <= 0:
			break
		var slot: Dictionary = inventory[k]
		if str(slot["id"]) != item_id:
			continue
		var take: int = mini(int(slot["qty"]), left)
		slot["qty"] = int(slot["qty"]) - take
		left -= take
		if int(slot["qty"]) <= 0:
			inventory.remove_at(k)
	return true


## Pulpería. Returns a message for the hub status line.
func buy_item(item_id: String) -> String:
	var item: Dictionary = get_item(item_id)
	if item.is_empty():
		return "Ese artículo no existe."
	var price: int = int(item.get("price", 0))
	if colones < price:
		return "No alcanza: %s cuesta %d ₡." % [item.get("name", item_id), price]
	if add_item(item_id, 1) == 0:
		return "No cabe más en la alforja."
	colones -= price
	return "Compraste %s (-%d ₡)." % [item.get("name", item_id), price]


## Why an item can't be used right now outside combat, or "" if it can.
func item_block_reason_outside_combat(item_id: String) -> String:
	var item: Dictionary = get_item(item_id)
	if item.is_empty() or item_count(item_id) <= 0:
		return "No tienes ese artículo."
	if not ItemEffectsScript.is_usable(item, false):
		if str(item.get("usable", "")) == "curio":
			return "Se usa en un lugar extraño."
		return "Solo se usa en combate."
	var limit: int = int(item.get("uses_per_node", 1))
	if int(node_item_uses.get(item_id, 0)) >= limit:
		return "Ya usaste %s en este lugar." % item.get("name", item_id)
	return ""


## Uses an item outside combat on `hero` (party items affect everyone). Returns log lines.
func use_item_outside_combat(item_id: String, hero: Dictionary) -> PackedStringArray:
	var logs: PackedStringArray = PackedStringArray()
	var why: String = item_block_reason_outside_combat(item_id)
	if why != "":
		logs.append(why)
		return logs
	var item: Dictionary = get_item(item_id)
	remove_item(item_id, 1)
	node_item_uses[item_id] = int(node_item_uses.get(item_id, 0)) + 1
	var light: int = ItemEffectsScript.light_amount(item)
	if light != 0:
		mission_light = clampi(mission_light + light, 0, 100)
		logs.append("La luz sube a %d." % mission_light)
	if str(item.get("target", "")) == "party":
		for h in party:
			if h is Dictionary:
				logs.append_array(ItemEffectsScript.apply_to_hero(item, h))
	elif not hero.is_empty():
		logs.append_array(ItemEffectsScript.apply_to_hero(item, hero))
	return logs


func get_skill(skill_id: String) -> Dictionary:
	return _skills_by_id.get(skill_id, {})


func get_hero_template(hero_id: String) -> Dictionary:
	return _heroes_by_id.get(hero_id, {})


func reset_party_from_catalog() -> void:
	party.clear()
	for h in _get_default_hero_order():
		var t: Dictionary = _heroes_by_id.get(h, {})
		if not t.is_empty():
			party.append(_instantiate_hero(t))


func _get_default_hero_order() -> Array:
	var keys: Array = []
	for id in _heroes_by_id.keys():
		keys.append(str(id))
	keys.sort()
	var preferred: Array = ["campesino", "abuela", "tecnologo", "montador"]
	var out: Array = []
	for p in preferred:
		if _heroes_by_id.has(p):
			out.append(p)
	for k in keys:
		if not out.has(k):
			out.append(k)
		if out.size() >= 4:
			break
	return out


func _instantiate_hero(template: Dictionary) -> Dictionary:
	var hp_max: int = int(template.get("hp_max", 20))
	var stress_max: int = int(template.get("stress_max", 100))
	return {
		"hero_id": template.get("id", ""),
		"name": template.get("name", "???"),
		"class_id": template.get("class_id", ""),
		"hp_max": hp_max,
		"hp": hp_max,
		"stress_max": stress_max,
		"stress": 0,
		"speed": int(template.get("speed", 3)),
		"accuracy": int(template.get("accuracy", 5)),
		"dodge": int(template.get("dodge", 5)),
		"crit": int(template.get("crit", 5)),
		"resolve_level": int(template.get("resolve_level", 0)),
		"skill_ids": template.get("skill_ids", []).duplicate(),
		"al_borde": false,
		"borde_checks": 0,
		"dead": false,
		"affliction_id": "",
		"virtud_id": "",
	}


## Iglesia Vieja stub: group prayer, small risk of bad mood.
func iglesia_misa_rapida() -> String:
	if colones < 800:
		return "No alcanza para la colecta (800 colones)."
	colones -= 800
	for h in party:
		if h is Dictionary and not h.get("dead", false):
			for _x in StressSystemScript.add_stress(h, -10):
				pass
	if randf() < 0.12:
		var living: Array = []
		for h in party:
			if h is Dictionary and not h.get("dead", false):
				living.append(h)
		if not living.is_empty():
			var v: Dictionary = living[randi() % living.size()]
			for _x in StressSystemScript.add_stress(v, 8):
				pass
			return "La misa ayuda, pero %s sigue inquieto (+8 estrés)." % v.get("name", "?")
	return "La Iglesia Vieja devuelve un poco de calma (-10 estrés, cuadrilla)."


func start_mission(region_path: String = "") -> bool:
	var path: String = region_path if region_path != "" else selected_mission_region_path
	var r: Dictionary = ExpeditionLoaderScript.load_region(path)
	if r.is_empty():
		return false
	if r.has("generator"):
		var g: Dictionary = MapGeneratorScript.generate(r, randi())
		for k in ["nodes", "edges", "start_node", "objective_node", "undirected", "seed"]:
			r[k] = g[k]
	mission_region_data = r
	mission_nodes_index = ExpeditionLoaderScript.node_by_id(r)
	current_region_id = str(r.get("region_id", ""))
	mission_light = mini(100, int(r.get("initial_light", 100)))
	mission_food = item_count("gallo_pinto")
	node_item_uses.clear()
	current_node_id = str(r.get("start_node", "n0"))
	objective_node_id = str(r.get("objective_node", ""))
	visited_node_ids = [current_node_id]
	cleared_node_ids = []
	mission_active = true
	mission_params = {
		"light_decay": int(r.get("light_decay_per_move", 5)),
		"low_light_threshold": int(r.get("low_light_threshold", 40)),
		"low_light_stress": int(r.get("low_light_stress", 3)),
		"objective_reward": int(r.get("objective_reward_colones", 0)),
	}
	combat_context.clear()
	combat_return_victory = false
	combat_return_node_id = ""
	return true


func end_mission_abandon() -> void:
	mission_active = false
	mission_region_data.clear()
	mission_nodes_index.clear()
	combat_context.clear()
	combat_return_node_id = ""
	combat_return_victory = false


func mission_neighbors() -> Array:
	return ExpeditionLoaderScript.neighbors(mission_region_data, current_node_id)


func move_to_node(target_id: String) -> bool:
	if not target_id in mission_neighbors():
		return false
	var decay: int = int(mission_params.get("light_decay", 5))
	mission_light = maxi(mission_light - decay, 0)
	current_node_id = target_id
	node_item_uses.clear()
	if not visited_node_ids.has(target_id):
		visited_node_ids.append(target_id)
	_apply_low_light_stress_on_travel()
	return true


## Tuning: when Luz falls below threshold after a move, random living hero gains stress.

func _apply_low_light_stress_on_travel() -> void:
	var thr: int = int(mission_params.get("low_light_threshold", 40))
	var st: int = int(mission_params.get("low_light_stress", 3))
	if mission_light >= thr:
		return
	var living: Array = []
	for h in party:
		if h is Dictionary and not h.get("dead", false):
			living.append(h)
	if living.is_empty():
		return
	var victim: Dictionary = living[randi() % living.size()]
	for _x in StressSystemScript.add_stress(victim, st):
		pass


## Grid position of a room (generated maps only), or Vector2i(-1, -1).
func node_pos(node_id: String) -> Vector2i:
	var p = mission_nodes_index.get(node_id, {}).get("pos", null)
	if p is Array and p.size() >= 2:
		return Vector2i(int(p[0]), int(p[1]))
	return Vector2i(-1, -1)


## Neighbor of the current room in a grid direction (e.g. Vector2i.UP), or "".
func neighbor_in_direction(dir: Vector2i) -> String:
	var here: Vector2i = node_pos(current_node_id)
	for nid in mission_neighbors():
		if node_pos(str(nid)) - here == dir:
			return str(nid)
	return ""


## Fog of war (docs/01 §4.3): a room's type is known once visited or next to a visited room.
func is_room_revealed(node_id: String) -> bool:
	if visited_node_ids.has(node_id) or node_id == objective_node_id:
		return true
	for v in visited_node_ids:
		if ExpeditionLoaderScript.neighbors(mission_region_data, str(v)).has(node_id):
			return true
	return false


func current_node() -> Dictionary:
	return mission_nodes_index.get(current_node_id, {})


func is_node_cleared(node_id: String) -> bool:
	return cleared_node_ids.has(node_id)


func mark_node_cleared(node_id: String) -> void:
	if not cleared_node_ids.has(node_id):
		cleared_node_ids.append(node_id)


func build_combat_context_for_node(node_id: String) -> void:
	var nd: Dictionary = mission_nodes_index.get(node_id, {})
	var en: Dictionary = {}
	var eid: String = str(nd.get("enemy_id", ""))
	if eid != "" and _enemies_by_id.has(eid):
		var raw_en: Variant = _enemies_by_id[eid]
		if raw_en is Dictionary:
			en = (raw_en as Dictionary).duplicate(true)
	if en.is_empty() and nd.get("enemy") is Dictionary:
		en = (nd["enemy"] as Dictionary).duplicate(true)
	if en.is_empty():
		en = {
			"id": "espanto",
			"name": "Espanto del Sótano",
			"hp_max": 45,
			"speed": 4,
			"dodge": 5,
			"accuracy": 8,
		}
	var hp_max: int = int(en.get("hp_max", 40))
	if bool(nd.get("is_elite", false)):
		hp_max = int(ceili(float(hp_max) * 1.25))
	if bool(nd.get("is_boss", false)):
		hp_max = int(ceili(float(hp_max) * 1.45))
	en["hp_max"] = hp_max
	en["hp"] = hp_max
	en["dead"] = false
	combat_context = {
		"node_id": node_id,
		"enemy": en,
		"reward_colones": int(nd.get("reward_colones", 0)),
		"is_elite": bool(nd.get("is_elite", false)),
		"is_boss": bool(nd.get("is_boss", false)),
	}


func clear_combat_return_flags() -> void:
	combat_return_victory = false
	combat_return_node_id = ""


func apply_objective_rewards() -> void:
	var rew: int = int(mission_params.get("objective_reward", 0))
	colones += rew
	week += 1


func is_region_playable(path: String) -> bool:
	for r in PLAYABLE_REGIONS:
		if str(r["path"]) == path:
			return true
	return false


func apply_save_data(data: Dictionary) -> void:
	colones = int(data.get("colones", colones))
	week = int(data.get("week", week))
	selected_mission_region_path = str(data.get("selected_mission_region_path", DEFAULT_REGION_PATH))
	if not is_region_playable(selected_mission_region_path):
		selected_mission_region_path = DEFAULT_REGION_PATH
	# v4: inventory. Older saves keep the starter pack and convert hub purchases to items.
	var raw_inv = data.get("inventory", null)
	if raw_inv is Array:
		inventory.clear()
		for e in raw_inv:
			if e is Dictionary:
				add_item(str(e.get("id", "")), int(e.get("qty", 0)))
	else:
		add_item("gallo_pinto", int(data.get("hub_pending_food", 0)))
		add_item("candela_sebo", int(ceil(int(data.get("hub_pending_light_bonus", 0)) / 15.0)))
	var raw_party = data.get("party", [])
	party.clear()
	if raw_party is Array:
		for e in raw_party:
			if e is Dictionary:
				party.append(_sanitize_runtime_hero(e))
	# Never resume mid-expedition in this slice.
	end_mission_abandon()


func _sanitize_runtime_hero(e: Dictionary) -> Dictionary:
	var out := e.duplicate(true)
	out["hp"] = clampi(int(out.get("hp", 1)), 0, int(out.get("hp_max", 1)))
	out["dead"] = bool(out.get("dead", false))
	out["al_borde"] = bool(out.get("al_borde", false))
	out["borde_checks"] = int(out.get("borde_checks", 0))
	if not out.has("skill_ids"):
		out["skill_ids"] = []
	if not out.has("affliction_id"):
		out["affliction_id"] = ""
	if not out.has("virtud_id"):
		out["virtud_id"] = ""
	var smax: int = maxi(int(out.get("stress_max", 200)), 200)
	out["stress_max"] = smax
	out["stress"] = clampi(int(out.get("stress", 0)), 0, smax)
	return out


func to_save_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"colones": colones,
		"week": week,
		"party": party.duplicate(true),
		"selected_mission_region_path": selected_mission_region_path,
		"inventory": inventory.duplicate(true),
	}

