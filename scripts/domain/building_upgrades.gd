extends RefCounted

## Building upgrades (P3-16 / P3-18 / P3-21, doc 02 §4/§7/§9/§11): tracks per building, bought
## level by level with Reliquias del Abuelo + colones. Pure rules over data/upgrades.json;
## GameState owns `building_levels` ({building: {track: level}}), the Reliquias and colones.

const PATH := "res://data/upgrades.json"
const BalanceScript := preload("res://scripts/domain/balance.gd")

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f != null:
			var j := JSON.new()
			if j.parse(f.get_as_text()) == OK and j.data is Dictionary:
				_data = j.data
		if _data.is_empty():
			push_error("upgrades.json: missing or invalid")
	return _data


static func building_ids() -> Array:
	return (data().get("buildings", {}) as Dictionary).keys()


static func tracks(building_id: String) -> Array:
	return data().get("buildings", {}).get(building_id, [])


static func track(building_id: String, track_id: String) -> Dictionary:
	for t in tracks(building_id):
		if str(t.get("id", "")) == track_id:
			return t
	return {}


## The track of `building_id` with this effect ({} if the building has none).
static func track_with_effect(building_id: String, effect: String) -> Dictionary:
	for t in tracks(building_id):
		if str(t.get("effect", "")) == effect:
			return t
	return {}


static func max_level(t: Dictionary) -> int:
	return (t.get("levels", []) as Array).size()


## Bought level of a track, 0..max (unknown or bad entries count as 0).
static func level(levels: Dictionary, building_id: String, track_id: String) -> int:
	var b = levels.get(building_id, {})
	if not b is Dictionary:
		return 0
	return clampi(int(b.get(track_id, 0)), 0, max_level(track(building_id, track_id)))


## The track's value at `lv` (its base at 0).
static func value_at(t: Dictionary, lv: int) -> float:
	if lv <= 0:
		return float(BalanceScript.req(t, "base", "upgrades.json track"))
	var lvls: Array = t.get("levels", [])
	return float(BalanceScript.req(lvls[mini(lv, lvls.size()) - 1], "value", "upgrades.json level"))


## Current value of `effect` for a building ("" track → the effect's neutral 0).
static func effect_value(levels: Dictionary, building_id: String, effect: String) -> float:
	var t: Dictionary = track_with_effect(building_id, effect)
	if t.is_empty():
		return 0.0
	return value_at(t, level(levels, building_id, str(t.get("id", ""))))


## {reliquias, colones} for the next level, or {} at max.
static func next_cost(levels: Dictionary, building_id: String, track_id: String) -> Dictionary:
	var t: Dictionary = track(building_id, track_id)
	var lv: int = level(levels, building_id, track_id)
	if t.is_empty() or lv >= max_level(t):
		return {}
	var step: Dictionary = t["levels"][lv]
	return {"reliquias": int(BalanceScript.req(step, "reliquias", "upgrades.json level")),
		"colones": int(BalanceScript.req(step, "colones", "upgrades.json level"))}


## "" when the next level can be bought; otherwise why not (Spanish, for the hub).
static func block_reason(levels: Dictionary, building_id: String, track_id: String, reliquias: int, colones: int) -> String:
	var t: Dictionary = track(building_id, track_id)
	if t.is_empty():
		return "Esa mejora no existe."
	var c: Dictionary = next_cost(levels, building_id, track_id)
	if c.is_empty():
		return "Ya está al máximo."
	if reliquias < int(c["reliquias"]):
		return "Faltan Reliquias del Abuelo: cuesta %d (hay %d)." % [int(c["reliquias"]), reliquias]
	if colones < int(c["colones"]):
		return "No alcanza: cuesta %d ₡." % int(c["colones"])
	return ""


## "+10% alivio" style text for a value of this effect (Spanish, for rows and tooltips).
static func effect_text(effect: String, v: float) -> String:
	match effect:
		"rank_cap":
			return "rango máximo %d" % int(v)
		"rank_discount", "cost_discount", "lesson_discount":
			return "-%d%% de precio" % int(round(v * 100.0))
		"relief_bonus":
			return "+%d%% de alivio" % int(round(v * 100.0))
		"extra_slots":
			return "+%d cupo%s por actividad" % [int(v), "" if int(v) == 1 else "s"]
		"extra_stock":
			return "+%d accesorio%s en el puesto" % [int(v), "" if int(v) == 1 else "s"]
		"camp_extra_class_skills":
			return "+%d habilidad%s de oficio por fogata" % [int(v), "" if int(v) == 1 else "es"]
	return str(v)


## Keeps only known buildings and tracks, levels clamped (save loading).
static func sanitize(raw) -> Dictionary:
	var out: Dictionary = {}
	if not raw is Dictionary:
		return out
	for bid in building_ids():
		var b = raw.get(bid, {})
		if not b is Dictionary:
			continue
		for t in tracks(bid):
			var lv: int = clampi(int(b.get(str(t["id"]), 0)), 0, max_level(t))
			if lv > 0:
				if not out.has(bid):
					out[bid] = {}
				out[bid][str(t["id"])] = lv
	return out
