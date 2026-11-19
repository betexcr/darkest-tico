extends RefCounted

## Quirks and diseases (P3-06, doc 02 §6; data/quirks.json, numbers in balance.json "quirks").
## A hero's quirks live on hero["quirks"] = [{id, locked}]. Pure rules: the catalog, stat
## mods (read by StatusEffects.stat), buildings a hero refuses, gaining after an expedition,
## and the Clínica's prices and weekly limits. GameState owns colones and the week.

const PATH := "res://data/quirks.json"
const BalanceScript := preload("res://scripts/domain/balance.gd")

static var _data: Dictionary = {}
static var _by_id: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f != null:
			var parsed = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				_data = parsed
				for q in _data.get("quirks", []):
					if q is Dictionary:
						_by_id[str(q.get("id", ""))] = q
		if _data.is_empty():
			push_error("quirks.json: missing or invalid")
	return _data


static func get_quirk(id: String) -> Dictionary:
	data()
	return _by_id.get(id, {})


static func all_of(kind: String) -> Array:
	return data().get("quirks", []).filter(func(q): return str(q.get("kind", "")) == kind)


## The hero's quirk entries [{id, locked}] that still exist in the catalog.
static func of(hero: Dictionary) -> Array:
	var q = hero.get("quirks", null)
	if not q is Array:
		return []
	return (q as Array).filter(func(e): return e is Dictionary and not get_quirk(str(e.get("id", ""))).is_empty())


static func ids_of(hero: Dictionary, kind: String = "") -> Array:
	return of(hero).filter(func(e): return kind == "" or kind_of(str(e["id"])) == kind).map(func(e): return str(e["id"]))


static func kind_of(id: String) -> String:
	return str(get_quirk(id).get("kind", ""))


static func has(hero: Dictionary, id: String) -> bool:
	return ids_of(hero).has(id)


static func is_locked(hero: Dictionary, id: String) -> bool:
	for e in of(hero):
		if str(e["id"]) == id:
			return bool(e.get("locked", false))
	return false


## Sum of one stat from the hero's quirks and diseases (combat stats, StatusEffects.stat).
static func mod(unit: Dictionary, key: String) -> int:
	var n: int = 0
	for e in of(unit):
		n += int(get_quirk(str(e["id"])).get("mods", {}).get(key, 0))
	return n


## The quirk that keeps the hero out of `building` (iglesia | cantina), or {}.
static func refusal(hero: Dictionary, building: String) -> Dictionary:
	for e in of(hero):
		var q: Dictionary = get_quirk(str(e["id"]))
		if q.get("refuses", []).has(building):
			return q
	return {}


static func add(hero: Dictionary, id: String) -> void:
	if get_quirk(id).is_empty() or has(hero, id):
		return
	if not hero.get("quirks", null) is Array:
		hero["quirks"] = []
	hero["quirks"].append({"id": id, "locked": false})


static func remove(hero: Dictionary, id: String) -> void:
	if hero.get("quirks", null) is Array:
		hero["quirks"] = (hero["quirks"] as Array).filter(func(e): return not (e is Dictionary and str(e.get("id", "")) == id))


static func set_locked(hero: Dictionary, id: String, on: bool) -> void:
	for e in hero.get("quirks", []):
		if e is Dictionary and str(e.get("id", "")) == id:
			e["locked"] = on


static func cap(kind: String) -> int:
	match kind:
		"positive":
			return BalanceScript.int_of("quirks.max_positive")
		"negative":
			return BalanceScript.int_of("quirks.max_negative")
	return BalanceScript.int_of("quirks.max_negative")


## Gains one random quirk of `kind` the hero doesn't have. At the cap it replaces a random
## unlocked one of that kind (nothing if all are locked). Returns the new quirk id or "".
static func gain(hero: Dictionary, kind: String) -> String:
	var mine: Array = ids_of(hero, kind)
	var pool: Array = all_of(kind).filter(func(q): return not mine.has(str(q["id"])))
	if pool.is_empty():
		return ""
	if kind != "disease" and mine.size() >= cap(kind):
		var loose: Array = mine.filter(func(id): return not is_locked(hero, id))
		if loose.is_empty():
			return ""
		remove(hero, str(loose[randi() % loose.size()]))
	var id: String = str(pool[randi() % pool.size()]["id"])
	add(hero, id)
	return id


## After an expedition: at most one new quirk (owner 2026-11-19). The positive, negative and
## disease chances are rolled in random order and the first hit wins. Returns the new ids.
static func roll_after_expedition(hero: Dictionary) -> Array:
	var rolls: Array = [["positive", "quirks.positive_chance"], ["negative", "quirks.negative_chance"], ["disease", "quirks.disease_chance"]]
	rolls.shuffle()
	for pair in rolls:
		if randf() < BalanceScript.num(str(pair[1])):
			var id: String = gain(hero, str(pair[0]))
			if id != "":
				return [id]
	return []


## A recruit at the terminal may arrive with a positive and a negative quirk.
static func roll_recruit(hero: Dictionary) -> void:
	if randf() < BalanceScript.num("quirks.recruit_positive_chance"):
		gain(hero, "positive")
	if randf() < BalanceScript.num("quirks.recruit_negative_chance"):
		gain(hero, "negative")


# --- Clínica de Espantos ------------------------------------------------------------------

## Resolve tier for prices: 0 below tier_levels[0], 1 below tier_levels[1], else 2.
static func tier(hero: Dictionary) -> int:
	var lv: int = int(hero.get("resolve_level", 0))
	var t: int = 0
	for b in BalanceScript.arr("quirks.tier_levels"):
		if lv >= int(b):
			t += 1
	return t


## Price of a Clínica treatment: remove_negative | positive (lock or remove) | disease.
static func cost(op: String, hero: Dictionary) -> int:
	var table: Array = BalanceScript.arr("quirks.%s_cost" % op)
	if table.is_empty():
		return 0
	return int(table[mini(tier(hero), table.size() - 1)])


## The Clínica operation a quirk takes: remove_negative, positive or disease.
static func op_for(id: String) -> String:
	match kind_of(id):
		"negative":
			return "remove_negative"
		"positive":
			return "positive"
	return "disease"


## Whether the hero already used this week's negative / positive treatment (diseases: never).
static func used_this_week(hero: Dictionary, op: String, week: int) -> bool:
	if op == "disease":
		return false
	var c = hero.get("clinic", null)
	return c is Dictionary and int(c.get("week", -1)) == week and bool(c.get(op, false))


static func mark_used(hero: Dictionary, op: String, week: int) -> void:
	var c = hero.get("clinic", null)
	if not c is Dictionary or int(c.get("week", -1)) != week:
		c = {"week": week}
	c[op] = true
	hero["clinic"] = c  # GameState adds "stay" (P3-19: the hero spends the week there)


## "+2 velocidad, -10% daño" for tooltips.
static func mods_text(id: String) -> String:
	var parts: PackedStringArray = PackedStringArray()
	var labels: Dictionary = {"accuracy": "precisión", "dodge": "esquiva", "speed": "velocidad", "crit": "crítico",
		"prot": "% protección", "dmg_pct": "% daño", "stress_pct": "% estrés recibido"}
	var m: Dictionary = get_quirk(id).get("mods", {})
	for k in m:
		parts.append("%+d %s" % [int(m[k]), labels.get(str(k), str(k))])
	for b in get_quirk(id).get("refuses", []):
		parts.append("no va a la %s" % ("Iglesia Vieja" if str(b) == "iglesia" else "Cantina"))
	return ", ".join(parts)
