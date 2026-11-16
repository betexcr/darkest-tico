extends RefCounted

## Iglesia Vieja + Cantina del Centro (doc 02 §7, P3-03): stress-relief activities.
## Pure rules over data/hub_activities.json; GameState owns the heroes, colones and the week.
## A hero's booking lives on hero["busy"] = {building, activity, cost, weeks_left, resolved}.

const PATH := "res://data/hub_activities.json"
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
			push_error("hub_activities.json: missing or invalid")
	return _data


static func buildings() -> Array:
	return data().get("buildings", [])


static func building(building_id: String) -> Dictionary:
	for b in buildings():
		if b is Dictionary and str(b.get("id", "")) == building_id:
			return b
	return {}


static func building_name(building_id: String) -> String:
	return str(building(building_id).get("name", building_id))


static func activity(building_id: String, activity_id: String) -> Dictionary:
	for a in building(building_id).get("activities", []):
		if a is Dictionary and str(a.get("id", "")) == activity_id:
			return a
	return {}


## The activity a hero is booked into ({} if free).
static func booked(hero: Dictionary) -> Dictionary:
	var b = hero.get("busy", null)
	if not b is Dictionary:
		return {}
	return activity(str(b.get("building", "")), str(b.get("activity", "")))


static func is_busy(hero: Dictionary) -> bool:
	return hero.get("busy", null) is Dictionary


## Booked this week and not resolved yet: holds a slot and can still be cancelled.
static func is_pending(hero: Dictionary) -> bool:
	return is_busy(hero) and not bool(hero["busy"].get("resolved", false))


static func slots(act: Dictionary) -> int:
	return int(BalanceScript.req(act, "slots", "hub_activities.json activity"))


## How many heroes in `roster` hold a slot of this activity this week.
static func slots_used(roster: Array, building_id: String, activity_id: String) -> int:
	var n: int = 0
	for h in roster:
		if h is Dictionary and is_pending(h) and str(h["busy"].get("building", "")) == building_id \
				and str(h["busy"].get("activity", "")) == activity_id:
			n += 1
	return n


## Price after the town event's service multiplier (`mult`).
static func cost(act: Dictionary, mult: float) -> int:
	return int(round(int(BalanceScript.req(act, "cost", "hub_activities.json activity")) * mult))


static func relief_range(act: Dictionary, mult: float) -> Array:
	var r: Array = BalanceScript.req(act, "relief", "hub_activities.json activity")
	return [int(floor(int(r[0]) * mult)), int(floor(int(r[1]) * mult))]


static func roll_relief(act: Dictionary, mult: float) -> int:
	var r: Array = relief_range(act, mult)
	return randi_range(int(r[0]), int(r[1]))


## One side effect drawn by weight, or {} (no side effect this time). `roll` in [0, 1).
static func roll_side_effect(act: Dictionary, roll: float = randf()) -> Dictionary:
	if roll >= float(BalanceScript.req(act, "side_chance", "hub_activities.json activity")):
		return {}
	var pool: Array = act.get("side_effects", [])
	var total: int = 0
	for s in pool:
		total += int(s.get("weight", 1))
	if total <= 0:
		return {}
	var pick: int = randi() % total
	for s in pool:
		pick -= int(s.get("weight", 1))
		if pick < 0:
			return s
	return {}


## [min, max] amount of a side effect, rolled.
static func roll_amount(side: Dictionary) -> int:
	var a: Array = BalanceScript.req(side, "amount", "hub_activities.json side effect")
	return randi_range(int(a[0]), int(a[1]))


## "Meditación — 1000 ₡, -25–40 estrés" line for buttons and tooltips.
static func summary(act: Dictionary, price: int, relief: Array) -> String:
	return "%s — %s, -%d–%d estrés" % [act.get("name", "?"), "gratis" if price == 0 else "%d ₡" % price, int(relief[0]), int(relief[1])]
