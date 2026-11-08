extends Node


## Party, currencies, JSON catalogs, expedition mission (in-memory only during play).


const DataLoaderScript := preload("res://scripts/data/data_loader.gd")

const ExpeditionLoaderScript := preload("res://scripts/domain/expedition_loader.gd")
const StressSystemScript := preload("res://scripts/domain/stress_system.gd")
const MapGeneratorScript := preload("res://scripts/domain/map_generator.gd")
const ItemEffectsScript := preload("res://scripts/domain/item_effects.gd")
const ResolveSystemScript := preload("res://scripts/domain/resolve_system.gd")
const CampingSystemScript := preload("res://scripts/domain/camping_system.gd")


const HEROES_PATH := "res://data/heroes.json"

const SKILLS_PATH := "res://data/skills.json"
const ENEMIES_PATH := "res://data/enemies.json"
const ITEMS_PATH := "res://data/items.json"
const CURIOS_PATH := "res://data/curios.json"
const INVENTORY_SLOTS := 24
const EQUIP_SLOTS := ["weapon", "armor", "accessory1", "accessory2"]
const ELEMENT_NAMES := {
	"fuego": "Fuego", "hielo": "Hielo", "rayo": "Rayo", "agua": "Agua",
	"tierra": "Tierra", "viento": "Viento", "sagrado": "Sagrado", "oscuridad": "Oscuridad",
}

const DEFAULT_REGION_PATH := "res://data/regions/sotanos.json"
const BOSQUE_REGION_PATH := "res://data/regions/bosque.json"

## Regions offered in the hub picker. Bosque is built but deferred to the Alpha phase (owner decision 2026-11-06).
## To re-enable it, add {"path": BOSQUE_REGION_PATH, "name": "Bosque nuboso maldito"}.
const PLAYABLE_REGIONS := [
	{"path": DEFAULT_REGION_PATH, "name": "Sótanos de la Hacienda"},
]


const SAVE_VERSION := 6
const ROSTER_CAP := 8
const PARTY_SIZE := 4
const RECRUIT_POOL_SIZE := 3
## EBAIS (hub clinic): colones per missing HP, with a minimum per visit.
const HEAL_COST_PER_HP := 15
const HEAL_MIN_COST := 100
## Items sell for half their buying price (owner, 2026-11-07).
const SELL_RATE := 0.5


var colones: int = 5000

var week: int = 1


var _heroes_by_id: Dictionary = {}

var _skills_by_id: Dictionary = {}

var _enemies_by_id: Dictionary = {}


## Every hero the player owns (max ROSTER_CAP).
var roster: Array = []
## Heroes going on the next/current expedition, in rank order (max PARTY_SIZE).
## Same dictionaries as in `roster`, so combat changes show up in both.
var party: Array = []
## Candidates at the Terminal de Buses, refreshed every week.
var recruit_pool: Array = []
var _next_uid: int = 1
## True while a fight is on: only `equip_turn_hero` may change equipment, and it costs
## their turn (owner 2026-11-08; before that gear was fully locked in combat).
var equip_locked: bool = false
## The hero waiting for orders during a fight ({} otherwise).
var equip_turn_hero: Dictionary = {}
## Short report of what happened at the end of the last expedition (hub status line).
var last_week_report: String = ""


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


## Set before a fight starts; read by the expedition screen.

var combat_context: Dictionary = {}


## Legacy (pre-P4-09 scene swap); unused by the expedition screen.

var combat_return_victory: bool = false

var combat_return_node_id: String = ""

## Hub prep (applied on next start_mission).
var selected_mission_region_path: String = DEFAULT_REGION_PATH

## Carried items, one entry per inventory slot: {"id": String, "qty": int} (P3-09).
var inventory: Array = []
## Uses of each item by each hero in the current room, outside combat, keyed
## "<hero_id>|<item_id>". The limit is per character, not per team. Reset on every move.
var node_item_uses: Dictionary = {}
var _items_by_id: Dictionary = {}
var _item_order: Array = []
var _starter_inventory: Array = []
var _curios_by_id: Dictionary = {}
## Rooms revealed by curios (map scouting) this mission.
var scouted_node_ids: Array = []

## Expedition difficulty picked in the hub (data/progression.json "difficulties").
var selected_difficulty_id: String = "aprendiz"
var mission_difficulty: Dictionary = {}
## Camping (P3-07): firewood left this mission, rooms already camped in.
var mission_firewood: int = 0
var camped_node_ids: Array = []
## What this expedition earned (victory screen): colones by source, items found, fights won.
var mission_ledger: Dictionary = {}
## Per hero (by uid) at mission start: mental state, to spot new Quebrantos/Virtudes.
var mission_start_snapshot: Dictionary = {}
## Lines from start_mission (under-leveled heroes) for the expedition log.
var mission_start_logs: PackedStringArray = PackedStringArray()
## Built by complete_mission(); read by the victory screen.
var last_expedition_summary: Dictionary = {}


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
	var c_data = DataLoaderScript.load_json(CURIOS_PATH)
	if c_data is Dictionary:
		for c in c_data.get("curios", []):
			if c is Dictionary and c.has("id"):
				_curios_by_id[str(c["id"])] = c


func get_curio(curio_id: String) -> Dictionary:
	return _curios_by_id.get(curio_id, {})


## Applies a curio outcome (data/curios.json) to the party/mission. Returns log lines.
func apply_curio_outcome(outcome: Dictionary) -> PackedStringArray:
	var logs: PackedStringArray = PackedStringArray()
	var living: Array = []
	for h in party:
		if h is Dictionary and not h.get("dead", false):
			living.append(h)
	if outcome.has("heal_party"):
		for h in living:
			h["hp"] = mini(int(h["hp"]) + int(outcome["heal_party"]), int(h["hp_max"]))
			if bool(h.get("al_borde", false)):
				h["al_borde"] = false
				h["convaleciente"] = true
		logs.append("+%d PV a la cuadrilla." % int(outcome["heal_party"]))
	if outcome.has("stress_party"):
		for h in living:
			logs.append_array(StressSystemScript.add_stress(h, int(outcome["stress_party"])))
		logs.append("Estrés %+d a la cuadrilla." % int(outcome["stress_party"]))
	if outcome.has("damage_random") and not living.is_empty():
		var v: Dictionary = living[randi() % living.size()]
		var amt: int = int(outcome["damage_random"])
		v["hp"] = maxi(int(v["hp"]) - amt, 0)
		logs.append("%s pierde %d PV." % [v.get("name", "?"), amt])
	if outcome.has("colones"):
		var c = outcome["colones"]
		var amt_c: int = randi_range(int(c[0]), int(c[1])) if c is Array and c.size() >= 2 else int(c)
		colones += amt_c
		ledger_add("loot_colones", amt_c)
		logs.append("+%d colones." % amt_c)
	if bool(outcome.get("random_equipment", false)):
		var gear: Array = _item_order.filter(func(id): return is_equipment(str(id)))
		if not gear.is_empty():
			var pick: String = str(gear[randi() % gear.size()])
			if add_item(pick, 1) > 0:
				ledger_item(pick, 1)
				logs.append("Encuentran: %s." % get_item(pick).get("name", pick))
			else:
				logs.append("Había %s, pero no cabe en la alforja." % get_item(pick).get("name", pick))
	var add = outcome.get("add_item", null)
	if add is Dictionary:
		var got: int = add_item(str(add.get("id", "")), int(add.get("qty", 1)))
		ledger_item(str(add.get("id", "")), got)
		if got > 0:
			logs.append("Encuentran: %s." % get_item(str(add.get("id", ""))).get("name", ""))
	if bool(outcome.get("reveal_neighbors", false)):
		for n in mission_neighbors():
			for m in ExpeditionLoaderScript.neighbors(mission_region_data, str(n)):
				if not scouted_node_ids.has(str(m)):
					scouted_node_ids.append(str(m))
		logs.append("Se revelan las salas cercanas.")
	if bool(outcome.get("reveal_map", false)):
		for nid in mission_nodes_index.keys():
			if not scouted_node_ids.has(str(nid)):
				scouted_node_ids.append(str(nid))
		logs.append("Se revela todo el mapa.")
	return logs


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


func _item_use_key(hero: Dictionary, item_id: String) -> String:
	return "%s|%s" % [str(hero.get("uid", hero.get("name", "?"))), item_id]


func sell_price(item_id: String) -> int:
	return int(floor(int(get_item(item_id).get("price", 0)) * SELL_RATE))


## Pulpería buys back one unit at half price. Returns a message for the hub.
func sell_item(item_id: String) -> String:
	if item_count(item_id) <= 0:
		return "No tienes ese artículo."
	var price: int = sell_price(item_id)
	remove_item(item_id, 1)
	colones += price
	return "Vendiste %s (+%d ₡)." % [get_item(item_id).get("name", item_id), price]


## Why `hero` can't use an item right now outside combat, or "" if they can.
func item_block_reason_outside_combat(item_id: String, hero: Dictionary) -> String:
	var item: Dictionary = get_item(item_id)
	if item.is_empty() or item_count(item_id) <= 0:
		return "No tienes ese artículo."
	if not ItemEffectsScript.is_usable(item, false):
		if str(item.get("usable", "")) == "curio":
			return "Se usa en un lugar extraño."
		return "Solo se usa en combate."
	if hero.is_empty() or bool(hero.get("dead", false)):
		return "Elige un héroe vivo."
	var limit: int = int(item.get("uses_per_node", 1))
	if int(node_item_uses.get(_item_use_key(hero, item_id), 0)) >= limit:
		return "%s ya usó %s en este lugar." % [hero.get("name", "?"), item.get("name", item_id)]
	return ""


## `hero` uses an item outside combat: ally items treat that hero, party items affect
## everyone. Counts toward that hero's per-room limit. Returns log lines.
func use_item_outside_combat(item_id: String, hero: Dictionary) -> PackedStringArray:
	var logs: PackedStringArray = PackedStringArray()
	var why: String = item_block_reason_outside_combat(item_id, hero)
	if why != "":
		logs.append(why)
		return logs
	var item: Dictionary = get_item(item_id)
	remove_item(item_id, 1)
	var key: String = _item_use_key(hero, item_id)
	node_item_uses[key] = int(node_item_uses.get(key, 0)) + 1
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


## New game: the four starter classes, all in the party, plus a fresh recruit pool.
func reset_party_from_catalog() -> void:
	roster.clear()
	party.clear()
	for id in ["campesino", "abuela", "tecnologo", "montador"]:
		var t: Dictionary = _heroes_by_id.get(id, {})
		if not t.is_empty():
			var h: Dictionary = _instantiate_hero(t)
			h["uid"] = _take_uid()
			roster.append(h)
			party.append(h)
	refresh_recruits()


func _take_uid() -> int:
	_next_uid += 1
	return _next_uid - 1


func _instantiate_hero(template: Dictionary) -> Dictionary:
	var hp_max: int = int(template.get("hp_max", 20))
	var names: Array = template.get("names", [])
	return {
		"uid": 0,
		"hero_id": template.get("id", ""),
		"name": str(names[randi() % names.size()]) if not names.is_empty() else str(template.get("name", "???")),
		"class_name": template.get("name", ""),
		"class_id": template.get("class_id", ""),
		"hp_max": hp_max,
		"hp": hp_max,
		"stress_max": 200,
		"stress": 0,
		"speed": int(template.get("speed", 3)),
		"accuracy": int(template.get("accuracy", 5)),
		"dodge": int(template.get("dodge", 5)),
		"crit": int(template.get("crit", 5)),
		"resolve_level": int(template.get("resolve_level", 0)),
		"resolve_xp": ResolveSystemScript.xp_for_level(int(template.get("resolve_level", 0))),
		"skill_ids": template.get("skill_ids", []).duplicate(),
		"camp_skill_ids": template.get("camp_skill_ids", []).duplicate(),
		"camp_buffs": [],
		"al_borde": false,
		"borde_checks": 0,
		"dead": false,
		"affliction_id": "",
		"virtud_id": "",
		"equipment": {},
		"prot": 0,
		"dmg_bonus": 0,
		"stress_resist": 0,
		"element": "",
		"resist": {},
		"immune": [],
		"status_resist": template.get("status_resist", {}).duplicate(),
	}


## Tooltip text for any item: name, description, and what it does.
func item_tooltip(item_id: String) -> String:
	var it: Dictionary = get_item(item_id)
	if it.is_empty():
		return item_id
	var lines: PackedStringArray = PackedStringArray([str(it.get("name", item_id)), str(it.get("description", ""))])
	var labels := {"damage": "Daño", "accuracy": "Precisión", "crit": "Crítico", "dodge": "Esquiva",
		"speed": "Velocidad", "hp_max": "PV máx.", "prot": "Protección %", "stress_resist": "Resist. estrés %"}
	var parts: PackedStringArray = PackedStringArray()
	var slot_names := {"weapon": "Arma", "armor": "Armadura", "accessory": "Accesorio"}
	if it.has("slot"):
		parts.append(str(slot_names.get(str(it["slot"]), it["slot"])))
	for k in it.get("bonus", {}):
		parts.append("%s %+d" % [labels.get(k, k), int(it["bonus"][k])])
	if str(it.get("element", "")) != "":
		parts.append("Elemento: %s" % ELEMENT_NAMES.get(str(it["element"]), it["element"]))
	for e in it.get("resist", {}):
		var m: float = float(it["resist"][e])
		parts.append("%s %s" % ["Inmune a" if m == 0.0 else "Resiste", ELEMENT_NAMES.get(str(e), e)])
	var SE = load("res://scripts/domain/status_effects.gd")
	for st in it.get("immune", []):
		parts.append("Inmune: %s" % SE.display_name(str(st)))
	var cats: Dictionary = {}
	for c in SE.resist_categories():
		cats[str(c["id"])] = str(c["name"])
	for k in it.get("status_resist", {}):
		parts.append("Resist. %s %+d%%" % [cats.get(k, k), int(it["status_resist"][k])])
	var oh = it.get("on_hit", null)
	if oh is Dictionary:
		parts.append("Al golpear: %d%% %s" % [int(round(float(oh.get("chance", 1.0)) * 100)), SE.display_name(str(oh.get("status", ""))).to_lower()])
	var ss = it.get("start_status", null)
	if ss is Dictionary:
		parts.append("Empieza cada pelea: %s" % SE.display_name(str(ss.get("status", ""))).to_lower())
	var fx: Dictionary = it.get("effects", {})
	if bool(fx.get("cure_all", false)):
		parts.append("Quita TODOS los males")
	elif not fx.get("cure", []).is_empty():
		var cn: PackedStringArray = PackedStringArray()
		for c in fx["cure"]:
			cn.append(SE.display_name(str(c)).to_lower())
		parts.append("Quita: " + ", ".join(cn))
	var ap = it.get("effects", {}).get("applies", null)
	if ap is Dictionary and str(it.get("target", "")) != "enemy":
		parts.append("Deja %s" % SE.display_name(str(ap.get("status", ""))).to_lower())
	if not parts.is_empty():
		lines.append(" · ".join(parts))
	var where: String = {
		"explore": "Fuera de combate", "combat": "Solo en combate (gasta el turno)", "both": "Dentro y fuera de combate (en combate gasta el turno)",
		"curio": "Se usa en lugares extraños", "equip": "Arrástralo a un héroe para equiparlo",
	}.get(str(it.get("usable", "")), "")
	if str(it.get("usable", "")) in ["explore", "both"]:
		where += " · %d uso(s) por héroe en cada lugar" % int(it.get("uses_per_node", 1))
	lines.append(where)
	lines.append("Compra %d ₡ · Venta %d ₡" % [int(it.get("price", 0)), sell_price(item_id)])
	return "\n".join(lines)


# --- Equipment (P3-11): 1 weapon, 1 armor, 2 accessories per hero -----------------

func is_equipment(item_id: String) -> bool:
	return str(get_item(item_id).get("usable", "")) == "equip"


## Which hero slots can hold this item.
func slots_for(item_id: String) -> Array:
	match str(get_item(item_id).get("slot", "")):
		"weapon":
			return ["weapon"]
		"armor":
			return ["armor"]
		"accessory":
			return ["accessory1", "accessory2"]
	return []


## Out of combat anyone may change gear. In combat only the hero whose turn it is
## (equip_turn_hero), and doing so spends that turn (owner 2026-11-08).
func can_change_equipment(hero: Dictionary) -> bool:
	return not equip_locked or (not hero.is_empty() and is_same(hero, equip_turn_hero))


## Equip from the inventory. `slot` "" picks the right (or first free accessory) slot.
## Whatever was in the slot goes back to the inventory. Returns an error, or "".
func equip(hero: Dictionary, item_id: String, slot: String = "") -> String:
	if not can_change_equipment(hero):
		return "En combate solo el héroe en turno cambia su equipo (le cuesta el turno)."
	var allowed: Array = slots_for(item_id)
	if allowed.is_empty():
		return "Eso no se puede equipar."
	if item_count(item_id) <= 0:
		return "No tienes ese artículo."
	if bool(hero.get("dead", false)):
		return "%s ya no puede equiparse." % hero.get("name", "?")
	if not hero.get("equipment") is Dictionary:
		hero["equipment"] = {}
	var eq: Dictionary = hero["equipment"]
	if slot == "":
		slot = allowed[0]
		for s in allowed:
			if str(eq.get(s, "")) == "":
				slot = s
				break
	if not allowed.has(slot):
		return "%s no va en ese espacio." % get_item(item_id).get("name", item_id)
	remove_item(item_id, 1)
	var old: String = str(eq.get(slot, ""))
	if old != "" and add_item(old, 1) == 0:
		add_item(item_id, 1)
		return "No hay espacio en la alforja para guardar %s." % get_item(old).get("name", old)
	eq[slot] = item_id
	recompute_stats(hero)
	return ""


func unequip(hero: Dictionary, slot: String) -> String:
	if not can_change_equipment(hero):
		return "En combate solo el héroe en turno cambia su equipo (le cuesta el turno)."
	var eq = hero.get("equipment", {})
	if not eq is Dictionary or str(eq.get(slot, "")) == "":
		return ""
	var id: String = str(eq[slot])
	if add_item(id, 1) == 0:
		return "La alforja está llena."
	eq.erase(slot)
	recompute_stats(hero)
	return ""


## Rebuilds a hero's combat stats from the class template plus equipment.
## Sets accuracy, crit, dodge, speed, hp_max (HP clamped), prot (%), dmg_bonus,
## stress_resist (%), element (weapon), resist {element: mult}, immune [ailments].
func recompute_stats(hero: Dictionary) -> void:
	var t: Dictionary = get_hero_template(str(hero.get("hero_id", "")))
	if t.is_empty():
		return
	var stats: Dictionary = {
		"accuracy": int(t.get("accuracy", 5)), "crit": int(t.get("crit", 5)), "dodge": int(t.get("dodge", 5)),
		"speed": int(t.get("speed", 3)), "hp_max": int(t.get("hp_max", 20)),
		"prot": 0, "damage": 0, "stress_resist": 0,
	}
	var resist: Dictionary = {}
	var immune: Array = []
	# Status resistances in % (data/statuses.json resist_categories): class base + equipment.
	var sres: Dictionary = {}
	var base_res = t.get("status_resist", {})
	if base_res is Dictionary:
		for k in base_res:
			sres[k] = int(base_res[k])
	# Resolve level (docs/01 §6): + resistances per level.
	var lvl: int = int(hero.get("resolve_level", 0))
	for k in ResolveSystemScript.cfg().get("resist_per_level", {}):
		sres[k] = int(sres.get(k, 0)) + ResolveSystemScript.resist_bonus(lvl, str(k))
	var element: String = ""
	var scout: bool = false
	var on_hit: Array = []
	var start_status: Array = []
	var eq = hero.get("equipment", {})
	if eq is Dictionary:
		for slot in eq:
			var item: Dictionary = get_item(str(eq[slot]))
			for k in item.get("bonus", {}):
				stats[k] = int(stats.get(k, 0)) + int(item["bonus"][k])
			for e in item.get("resist", {}):
				resist[e] = float(resist.get(e, 1.0)) * float(item["resist"][e])
			for st in item.get("immune", []):
				if not immune.has(st):
					immune.append(st)
			for k in item.get("status_resist", {}):
				sres[k] = int(sres.get(k, 0)) + int(item["status_resist"][k])
			if str(slot) == "weapon":
				element = str(item.get("element", ""))
				if item.get("on_hit", null) is Dictionary:
					on_hit.append(item["on_hit"])
			if item.get("start_status", null) is Dictionary:
				start_status.append(item["start_status"])
			if bool(item.get("scout", false)):
				scout = true
	for k in ["accuracy", "crit", "dodge", "speed", "hp_max"]:
		hero[k] = stats[k]
	hero["hp_max"] = maxi(int(hero["hp_max"]), 1)
	hero["hp"] = mini(int(hero.get("hp", hero["hp_max"])), int(hero["hp_max"]))
	hero["prot"] = clampi(int(stats["prot"]), 0, 80)
	hero["dmg_bonus"] = int(stats["damage"])
	hero["stress_resist"] = clampi(int(stats["stress_resist"]), -50, 80)
	hero["element"] = element
	hero["resist"] = resist
	hero["immune"] = immune
	for k in sres:
		sres[k] = clampi(int(sres[k]), 0, 95)
	hero["status_resist"] = sres
	hero["on_hit"] = on_hit
	hero["start_status"] = start_status
	hero["scout"] = scout


## Someone alive in the party wears the Lentes del abuelo: full enemy data is shown.
func party_can_scout() -> bool:
	for h in party:
		if h is Dictionary and not h.get("dead", false) and bool(h.get("scout", false)):
			return true
	return false


# --- Roster, recruiting, party (P3-01 / P3-02) ------------------------------------

func hire_cost(hero: Dictionary) -> int:
	return int(get_hero_template(str(hero.get("hero_id", ""))).get("hire_cost", 800))


func refresh_recruits() -> void:
	recruit_pool.clear()
	var ids: Array = _heroes_by_id.keys()
	for _k in RECRUIT_POOL_SIZE:
		if ids.is_empty():
			break
		recruit_pool.append(_instantiate_hero(_heroes_by_id[ids[randi() % ids.size()]]))


## Terminal de Buses de Sarchí. Returns a message for the hub.
func hire_recruit(index: int) -> String:
	if index < 0 or index >= recruit_pool.size():
		return "Ese candidato ya se fue en el bus."
	if roster.size() >= ROSTER_CAP:
		return "La hacienda no tiene más camas (máximo %d héroes)." % ROSTER_CAP
	var h: Dictionary = recruit_pool[index]
	var cost: int = hire_cost(h)
	if colones < cost:
		return "No alcanza: contratar a %s cuesta %d ₡." % [h.get("name", "?"), cost]
	colones -= cost
	h["uid"] = _take_uid()
	roster.append(h)
	recruit_pool.remove_at(index)
	if party.size() < PARTY_SIZE:
		party.append(h)
	return "%s (%s) se baja del bus y se une a la hacienda (-%d ₡)." % [h.get("name", "?"), h.get("class_name", ""), cost]


## Dismiss a hero for good: equipment goes back to the inventory first (refused if it
## doesn't fit, so nothing is lost). The last hero can't be dismissed.
func dismiss_hero(hero: Dictionary) -> String:
	if roster.size() <= 1:
		return "La hacienda no puede quedarse sin nadie."
	var eq = hero.get("equipment", {})
	var gear: Array = eq.values() if eq is Dictionary else []
	if inventory.size() + gear.size() > INVENTORY_SLOTS:
		return "No hay espacio en la alforja para guardar el equipo de %s." % hero.get("name", "?")
	for id in gear:
		add_item(str(id), 1)
	set_in_party(hero, false)
	for k in roster.size():
		if is_same(roster[k], hero):
			roster.remove_at(k)
			break
	var msg: String = "%s se despide de la hacienda y se va en el bus." % hero.get("name", "?")
	if not gear.is_empty():
		msg += " Su equipo quedó en la alforja."
	return msg


func is_in_party(hero: Dictionary) -> bool:
	for p in party:
		if is_same(p, hero):
			return true
	return false


func set_in_party(hero: Dictionary, on: bool) -> String:
	if on:
		if is_in_party(hero):
			return ""
		if party.size() >= PARTY_SIZE:
			return "La cuadrilla ya tiene %d héroes." % PARTY_SIZE
		if bool(hero.get("dead", false)):
			return "%s ya no puede salir." % hero.get("name", "?")
		party.append(hero)
		return ""
	for k in party.size():
		if is_same(party[k], hero):
			party.remove_at(k)
			break
	return ""


## Moves a party member one rank forward (-1) or back (+1).
func move_in_party(hero: Dictionary, delta: int) -> void:
	for k in party.size():
		if is_same(party[k], hero):
			var j: int = clampi(k + delta, 0, party.size() - 1)
			if j != k:
				party[k] = party[j]
				party[j] = hero
			return


func living_party_count() -> int:
	var n: int = 0
	for h in party:
		if h is Dictionary and not h.get("dead", false):
			n += 1
	return n


## EBAIS: price to bring a hero back to full HP (0 if already full).
func heal_cost(hero: Dictionary) -> int:
	var missing: int = int(hero.get("hp_max", 0)) - int(hero.get("hp", 0))
	if missing <= 0 or bool(hero.get("dead", false)):
		return 0
	return maxi(missing * HEAL_COST_PER_HP, HEAL_MIN_COST)


func heal_hero(hero: Dictionary) -> String:
	var cost: int = heal_cost(hero)
	if cost <= 0:
		return "%s no necesita el EBAIS." % hero.get("name", "?")
	if colones < cost:
		return "No alcanza: curar a %s cuesta %d ₡." % [hero.get("name", "?"), cost]
	colones -= cost
	hero["hp"] = int(hero["hp_max"])
	hero["al_borde"] = false
	return "En el EBAIS atienden a %s: PV al máximo (-%d ₡)." % [hero.get("name", "?"), cost]


## One week passes after every expedition (doc 02 §1): the fallen leave the roster,
## survivors leave Al Borde, recruits rotate.
func end_of_expedition_week() -> void:
	week += 1
	var fallen: PackedStringArray = PackedStringArray()
	for k in range(roster.size() - 1, -1, -1):
		var h: Dictionary = roster[k]
		if bool(h.get("dead", false)):
			fallen.append(str(h.get("name", "?")))
			roster.remove_at(k)
		else:
			h["al_borde"] = false
			h.erase("convaleciente")
			h["borde_checks"] = 0
			h["hp"] = maxi(int(h.get("hp", 0)), 1)
			h.erase("guarding")
			h.erase("statuses")
	for k in range(party.size() - 1, -1, -1):
		if bool(party[k].get("dead", false)):
			party.remove_at(k)
	refresh_recruits()
	last_week_report = "Semana %d." % week
	if not fallen.is_empty():
		last_week_report += " Descansen en paz: %s." % ", ".join(fallen)
	last_week_report += " Llegaron candidatos nuevos a la terminal."


## Iglesia Vieja stub: group prayer, small risk of bad mood.
func iglesia_misa_rapida() -> String:
	if colones < 800:
		return "No alcanza para la colecta (800 colones)."
	colones -= 800
	for h in roster:
		if h is Dictionary and not h.get("dead", false):
			for _x in StressSystemScript.add_stress(h, -10):
				pass
	if randf() < 0.12:
		var living: Array = []
		for h in roster:
			if h is Dictionary and not h.get("dead", false):
				living.append(h)
		if not living.is_empty():
			var v: Dictionary = living[randi() % living.size()]
			for _x in StressSystemScript.add_stress(v, 8):
				pass
			return "La misa ayuda, pero %s sigue inquieto (+8 estrés)." % v.get("name", "?")
	return "La Iglesia Vieja devuelve un poco de calma (-10 estrés a todos los héroes)."


func start_mission(region_path: String = "") -> bool:
	var path: String = region_path if region_path != "" else selected_mission_region_path
	if living_party_count() <= 0:
		return false
	if not party_refusals().is_empty():
		return false
	var r: Dictionary = ExpeditionLoaderScript.load_region(path)
	if r.is_empty():
		return false
	if r.has("generator"):
		var g: Dictionary = MapGeneratorScript.generate(r, randi())
		for k in ["nodes", "edges", "start_node", "objective_node", "undirected", "seed"]:
			r[k] = g[k]
	mission_region_data = r
	scouted_node_ids = []
	for n in r.get("nodes", []):
		if n is Dictionary and n.has("curio_id"):
			n["label"] = str(get_curio(str(n["curio_id"])).get("name", n.get("label", "")))
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
	mission_difficulty = ResolveSystemScript.expedition(selected_difficulty_id, int(r.get("region_level", 0)))
	mission_firewood = int(r.get("firewood", CampingSystemScript.data().get("firewood_per_expedition", 1)))
	camped_node_ids = []
	mission_ledger = {"loot_colones": 0, "objective_colones": 0, "items": {}, "fights": 0, "elites": 0,
		"bosses": 0, "ambushes": 0, "curios": 0, "camps": 0, "rooms": 0}
	_prepare_party_for_mission()
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


## Snapshot each hero's mental state and apply the under-level penalty (docs/01 §6).
func _prepare_party_for_mission() -> void:
	mission_start_snapshot.clear()
	mission_start_logs = PackedStringArray()
	for h in party:
		if not h is Dictionary:
			continue
		h["camp_buffs"] = []
		h["underlevel_stress_pct"] = 0
		mission_start_snapshot[int(h.get("uid", 0))] = {
			"affliction_id": str(h.get("affliction_id", "")),
			"virtud_id": str(h.get("virtud_id", "")),
			"resolve_level": int(h.get("resolve_level", 0)),
		}
		if h.get("dead", false):
			continue
		var short: int = ResolveSystemScript.underlevel(h, mission_difficulty)
		if short > 0:
			var st: int = ResolveSystemScript.underlevel_start_stress(short)
			mission_start_logs.append("%s no tiene la resolución para una expedición %s: +%d estrés y %+d%% de estrés recibido." % [
				h.get("name", "?"), str(mission_difficulty.get("name", "")), st, ResolveSystemScript.underlevel_stress_pct(short)])
			mission_start_logs.append_array(StressSystemScript.add_stress(h, st))
			h["underlevel_stress_pct"] = ResolveSystemScript.underlevel_stress_pct(short)


## Level of a region (doc 05 §4 order; Sótanos = 0), from its JSON. Cached per path.
var _region_levels: Dictionary = {}


func region_level(path: String = "") -> int:
	var p: String = path if path != "" else selected_mission_region_path
	if not _region_levels.has(p):
		_region_levels[p] = int(ExpeditionLoaderScript.load_region(p).get("region_level", 0))
	return int(_region_levels[p])


## The expedition the hub would start: picked difficulty + selected region's level.
func selected_expedition(diff_id: String = "") -> Dictionary:
	return ResolveSystemScript.expedition(diff_id if diff_id != "" else selected_difficulty_id, region_level())


## Heroes in the party who refuse the selected expedition (too seasoned for it).
func party_refusals(diff_id: String = "") -> Array:
	var diff: Dictionary = selected_expedition(diff_id)
	return party.filter(func(h): return h is Dictionary and not h.get("dead", false) and ResolveSystemScript.refuses(h, diff))


## Heroes in the party below the selected difficulty's level (they go, with a stress penalty).
func party_underleveled(diff_id: String = "") -> Array:
	var diff: Dictionary = selected_expedition(diff_id)
	return party.filter(func(h): return h is Dictionary and not h.get("dead", false) and ResolveSystemScript.underlevel(h, diff) > 0)


## Victory-screen bookkeeping. kind: a counter in mission_ledger ("fights", "curios"…).
func ledger_add(kind: String, amount: int = 1) -> void:
	if mission_active:
		mission_ledger[kind] = int(mission_ledger.get(kind, 0)) + amount


func ledger_item(item_id: String, qty: int) -> void:
	if mission_active and qty > 0:
		var items: Dictionary = mission_ledger.get("items", {})
		items[item_id] = int(items.get(item_id, 0)) + qty
		mission_ledger["items"] = items


## Colones a won fight in this room pays (room reward × difficulty).
func combat_reward(node_id: String) -> int:
	var nd: Dictionary = mission_nodes_index.get(node_id, {})
	return int(round(int(nd.get("reward_colones", 0)) * float(mission_difficulty.get("reward", 1.0))))


func can_camp_at(node_id: String) -> bool:
	return mission_firewood > 0 and not camped_node_ids.has(node_id)


func end_mission_abandon() -> void:
	mission_active = false
	for h in party:
		if h is Dictionary:
			h["camp_buffs"] = []
			h["underlevel_stress_pct"] = 0
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
	if visited_node_ids.has(node_id) or node_id == objective_node_id or scouted_node_ids.has(node_id):
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


## HP multiplier per member for a squad of n (fights stay short when 3-4 enemies show up).
const SQUAD_HP_SCALE := [1.0, 1.0, 0.75, 0.6, 0.5]


## Builds combat_context["enemies"] for a room: fresh copies with scaled HP; duplicate
## names get A/B/C. combat_context["enemy"] is the leader (kept for older callers).
func build_combat_context_for_node(node_id: String) -> void:
	var nd0: Dictionary = mission_nodes_index.get(node_id, {})
	var ids: Array = nd0.get("enemy_ids", [])
	if ids.is_empty():
		ids = [str(nd0.get("enemy_id", "espanto"))]
	var squad_scale: float = SQUAD_HP_SCALE[mini(ids.size(), SQUAD_HP_SCALE.size() - 1)]
	var squad: Array = []
	var seen: Dictionary = {}
	for k in ids.size():
		var raw_en = _enemies_by_id.get(str(ids[k]), {})
		var en: Dictionary = (raw_en as Dictionary).duplicate(true) if raw_en is Dictionary else {}
		if en.is_empty():
			en = {"id": "espanto", "name": "Espanto del Sótano", "hp_max": 45, "speed": 4, "dodge": 5, "accuracy": 8}
		var hp: float = float(en.get("hp_max", 40))
		if k == 0 and bool(nd0.get("is_boss", false)):
			hp *= 1.45
		else:
			if k == 0 and bool(nd0.get("is_elite", false)):
				hp *= 1.25
			hp *= squad_scale
		hp *= float(mission_difficulty.get("enemy_hp", 1.0))
		en["hp_max"] = maxi(int(ceil(hp)), 1)
		en["hp"] = en["hp_max"]
		en["dead"] = false
		en["accuracy"] = int(en.get("accuracy", 8)) + int(mission_difficulty.get("enemy_accuracy", 0))
		en["dmg_mult"] = float(mission_difficulty.get("enemy_dmg", 1.0))
		# Tougher tiers resist ailments more (doc 05 §4: +10% Veterano, +20% Campeón).
		var er: int = int(mission_difficulty.get("enemy_resist", 0))
		if er != 0 and en.get("status_resist", null) is Dictionary:
			for rk in en["status_resist"]:
				en["status_resist"][rk] = int(en["status_resist"][rk]) + er
		seen[str(en["id"])] = int(seen.get(str(en["id"]), 0)) + 1
		squad.append(en)
	var counts: Dictionary = {}
	for en in squad:
		if int(seen[str(en["id"])]) > 1:
			counts[str(en["id"])] = int(counts.get(str(en["id"]), 0)) + 1
			en["name"] = "%s %s" % [en.get("name", "?"), "ABCD"[int(counts[str(en["id"])]) - 1]]
	_build_single_context(node_id)
	combat_context["enemies"] = squad
	combat_context["enemy"] = squad[0]


func _build_single_context(node_id: String) -> void:
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
	var rew: int = int(round(int(mission_params.get("objective_reward", 0)) * float(mission_difficulty.get("reward", 1.0))))
	colones += rew
	ledger_add("objective_colones", rew)


## Objective done: pay out, give every survivor Resolve XP, build the victory summary.
## Call before end_mission_abandon(); returns last_expedition_summary.
func complete_mission() -> Dictionary:
	apply_objective_rewards()
	var xp: int = int(mission_difficulty.get("xp", 2))
	var heroes: Array = []
	for h in party:
		if not h is Dictionary:
			continue
		var snap: Dictionary = mission_start_snapshot.get(int(h.get("uid", 0)), {})
		var e: Dictionary = {
			"uid": int(h.get("uid", 0)), "hero_id": str(h.get("hero_id", "")), "name": str(h.get("name", "?")),
			"class_name": str(h.get("class_name", "")), "dead": bool(h.get("dead", false)),
			"xp_gained": 0, "level_before": int(h.get("resolve_level", 0)), "level_after": int(h.get("resolve_level", 0)),
			"affliction_id": str(h.get("affliction_id", "")), "virtud_id": str(h.get("virtud_id", "")),
			"new_affliction": false, "new_virtud": false,
		}
		if not e["dead"]:
			var res: Dictionary = ResolveSystemScript.grant_xp(h, xp)
			e["xp_gained"] = xp
			e["level_after"] = int(res["level_after"])
			if int(res["level_after"]) != int(res["level_before"]):
				recompute_stats(h)
		e["new_affliction"] = e["affliction_id"] != "" and e["affliction_id"] != str(snap.get("affliction_id", ""))
		e["new_virtud"] = e["virtud_id"] != "" and e["virtud_id"] != str(snap.get("virtud_id", ""))
		e["resolve_xp"] = int(h.get("resolve_xp", 0))
		e["hp"] = int(h.get("hp", 0))
		e["hp_max"] = int(h.get("hp_max", 1))
		e["stress"] = int(h.get("stress", 0))
		heroes.append(e)
	last_expedition_summary = {
		"region_name": str(mission_region_data.get("name", "Expedición")),
		"difficulty_name": "%s, nivel %d" % [str(mission_difficulty.get("name", "")), int(mission_difficulty.get("level", 1))],
		"xp": xp,
		"ledger": mission_ledger.duplicate(true),
		"heroes": heroes,
	}
	return last_expedition_summary


## Night ambush at a camp (doc 07 §6): 2–3 monsters from the region's pool, no payout.
func build_ambush_context(node_id: String) -> void:
	var gen: Dictionary = mission_region_data.get("generator", {})
	var pool: Array = gen.get("enemy_pool", ["espanto"])
	var cnt: Array = CampingSystemScript.data().get("ambush", {}).get("enemy_count", [2, 3])
	var n: int = randi_range(int(cnt[0]), int(cnt[1]))
	var ids: Array = []
	for _k in n:
		ids.append(str(pool[randi() % pool.size()]))
	var nd: Dictionary = mission_nodes_index.get(node_id, {})
	var saved: Dictionary = nd.duplicate()
	nd["enemy_ids"] = ids
	nd.erase("is_boss")
	nd.erase("is_elite")
	nd["reward_colones"] = 0
	build_combat_context_for_node(node_id)
	nd.clear()
	nd.merge(saved)
	combat_context["is_ambush"] = true


func is_region_playable(path: String) -> bool:
	for r in PLAYABLE_REGIONS:
		if str(r["path"]) == path:
			return true
	return false


func apply_save_data(data: Dictionary) -> void:
	colones = int(data.get("colones", colones))
	week = int(data.get("week", week))
	selected_mission_region_path = str(data.get("selected_mission_region_path", DEFAULT_REGION_PATH))
	# v6: expedition difficulty.
	selected_difficulty_id = str(ResolveSystemScript.difficulty(str(data.get("selected_difficulty_id", "aprendiz"))).get("id", "aprendiz"))
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
	# v5: roster + party by uid + recruit pool. v4 and older only had `party`.
	roster.clear()
	party.clear()
	_next_uid = maxi(int(data.get("next_uid", 1)), 1)
	var raw_roster = data.get("roster", data.get("party", []))
	if raw_roster is Array:
		for e in raw_roster:
			if e is Dictionary:
				var h: Dictionary = _sanitize_runtime_hero(e)
				if int(h.get("uid", 0)) <= 0:
					h["uid"] = _next_uid
				_next_uid = maxi(_next_uid, int(h["uid"]) + 1)
				roster.append(h)
	# JSON numbers load as floats: compare uids as ints.
	var raw_uids = data.get("party_uids", null)
	var uids: Array = []
	if raw_uids is Array:
		for u in raw_uids:
			uids.append(int(u))
	for uid in uids:
		for h in roster:
			if int(h["uid"]) == uid and party.size() < PARTY_SIZE:
				party.append(h)
	if not raw_uids is Array:
		for h in roster:
			if party.size() < PARTY_SIZE:
				party.append(h)
	recruit_pool.clear()
	var raw_pool = data.get("recruit_pool", null)
	if raw_pool is Array and not raw_pool.is_empty():
		for e in raw_pool:
			if e is Dictionary:
				recruit_pool.append(_sanitize_runtime_hero(e))
	else:
		refresh_recruits()
	# Never resume mid-expedition in this slice.
	end_mission_abandon()


func _sanitize_runtime_hero(e: Dictionary) -> Dictionary:
	var out := e.duplicate(true)
	var t: Dictionary = get_hero_template(str(out.get("hero_id", "")))
	if not out.has("class_name"):
		out["class_name"] = t.get("name", "")
	out["uid"] = int(out.get("uid", 0))
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
	if not out.get("equipment") is Dictionary:
		out["equipment"] = {}
	# v6: resolve XP and camp skills (older saves: XP at the floor of their level, class loadout).
	out["resolve_level"] = clampi(int(out.get("resolve_level", 0)), 0, ResolveSystemScript.MAX_LEVEL)
	out["resolve_xp"] = maxi(int(out.get("resolve_xp", ResolveSystemScript.xp_for_level(int(out["resolve_level"])))), 0)
	if not out.get("camp_skill_ids") is Array or (out["camp_skill_ids"] as Array).is_empty():
		out["camp_skill_ids"] = t.get("camp_skill_ids", []).duplicate()
	out["camp_buffs"] = []
	out["underlevel_stress_pct"] = 0
	recompute_stats(out)
	var smax: int = maxi(int(out.get("stress_max", 200)), 200)
	out["stress_max"] = smax
	out["stress"] = clampi(int(out.get("stress", 0)), 0, smax)
	return out


func to_save_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"colones": colones,
		"week": week,
		"roster": roster.duplicate(true),
		"party_uids": party.map(func(h): return int(h["uid"])),
		"recruit_pool": recruit_pool.duplicate(true),
		"next_uid": _next_uid,
		"selected_mission_region_path": selected_mission_region_path,
		"selected_difficulty_id": selected_difficulty_id,
		"inventory": inventory.duplicate(true),
	}

