extends RefCounted

## Combat status effects (P1-04; owner 2026-11-08: all Darkest Dungeon status effects with
## Tico names). Definitions: data/statuses.json. Pure rules, no nodes.
##
## Stored on a unit dictionary as
##   unit["statuses"][id] = {"stacks": [{"turns": int, "value": int, "mods": {stat: delta}}], "by_uid": int}
## Stacking effects (sangrado, veneno, susto, salado, chiva, sobado, espabilado) keep one stack per
## application, each expiring on its own; the rest keep a single stack that a new application refreshes.
## Cleared when a fight ends (Convaleciente is a hero flag that lasts the whole expedition).
##
##   sangrado / veneno  lose the stacks' total value in HP at the start of each turn (ignores protection)
##   sobado             heal its total value at the start of each turn, before bleed/blight
##   susto              heroes gain its total value in stress at the start of each turn
##   aturdido           skip the next turn, then gain Espabilado (+50% stun resist per stack) until a normal turn
##   salado / chiva     stat changes in "mods" (accuracy, dodge, speed, crit, prot, dmg_pct, stress_pct)
##   encarrerado        crit buff: +15% damage, +5 crit for 2 turns
##   fichado            marked: enemies prefer the unit; "vs_marked_pct" skills deal extra damage
##   cuidado / cuidando ally guard: the guardian (by_uid) takes single-target attacks; ends if it is stunned
##   respondon          counter-attacks whoever attacks it
##   santiguado         blocks the damage of the next N direct attacks (value = blocks, max 2)
##   agazapado          can't be picked by single-target attacks while other targets exist; lost when attacking

const DATA_PATH := "res://data/statuses.json"
const DEFAULT_TURNS := 3

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open(DATA_PATH, FileAccess.READ)
		if f != null:
			var parsed = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				_data = parsed
	return _data


static func defs() -> Dictionary:
	return data().get("statuses", {})


static func def(id: String) -> Dictionary:
	return defs().get(id, {})


static func display_name(id: String) -> String:
	return str(def(id).get("name", id))


static func is_negative(id: String) -> bool:
	return str(def(id).get("kind", "negative")) == "negative"


static func _stacks(unit: Dictionary, id: String) -> Array:
	var st = unit.get("statuses", {})
	if st is Dictionary and st.has(id):
		var e = st[id]
		if e is Dictionary:
			if e.has("stacks"):
				return e["stacks"]
			# Old single-entry shape {"turns", "value"}: migrate in place.
			var stack: Dictionary = {"turns": int(e.get("turns", 1)), "value": int(e.get("value", 0))}
			st[id] = {"stacks": [stack]}
			return st[id]["stacks"]
	return []


static func has(unit: Dictionary, status: String) -> bool:
	return not _stacks(unit, status).is_empty()


static func any(unit: Dictionary) -> bool:
	var st = unit.get("statuses", {})
	if not st is Dictionary:
		return false
	for id in st:
		if has(unit, str(id)) and is_negative(str(id)):
			return true
	return false


static func total_value(unit: Dictionary, id: String) -> int:
	var n: int = 0
	for s in _stacks(unit, id):
		n += int(s.get("value", 0))
	return n


static func turns_left(unit: Dictionary, id: String) -> int:
	var n: int = 0
	for s in _stacks(unit, id):
		n = maxi(n, int(s.get("turns", 0)))
	return n


static func stack_count(unit: Dictionary, id: String) -> int:
	return _stacks(unit, id).size()


static func labels(unit: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var st = unit.get("statuses", {})
	if st is Dictionary:
		for k in st:
			if has(unit, str(k)):
				out.append(display_name(str(k)))
	return out


## Active effects for the UI: [{id, turns, value, stacks}] (plus the hero states Al Borde / Convaleciente).
static func entries(unit: Dictionary) -> Array:
	var out: Array = []
	if bool(unit.get("al_borde", false)):
		out.append({"id": "al_borde", "turns": 0, "value": 0, "stacks": 1})
	if bool(unit.get("convaleciente", false)) and not bool(unit.get("al_borde", false)):
		out.append({"id": "convaleciente", "turns": 0, "value": 0, "stacks": 1})
	var st = unit.get("statuses", {})
	if st is Dictionary:
		for k in st:
			var id := str(k)
			if has(unit, id):
				out.append({"id": id, "turns": turns_left(unit, id), "value": total_value(unit, id), "stacks": stack_count(unit, id)})
	if bool(unit.get("guarding", false)):
		out.append({"id": "guardia", "turns": 0, "value": 0, "stacks": 1})
	return out


## Chance (0-100) that `unit` resists `status`.
static func resist_chance(unit: Dictionary, status: String) -> int:
	var r: int = 0
	var table = unit.get("status_resist", {})
	if table is Dictionary:
		r = int(table.get(status, 0))
	if status == "aturdido":
		r += stack_count(unit, "espabilado") * int(data().get("espabilado_stun_resist", 50))
	return clampi(r, 0, 100)


## Applies one status. Returns a log line ("" if nothing happened).
## opts: "mods" (stat deltas for salado/chiva), "by_uid" (guardian for cuidado), "crit" (DoTs last 5),
## "ignore_resist" (bool).
static func apply(unit: Dictionary, status: String, turns: int, value: int, opts: Dictionary = {}) -> String:
	if not defs().has(status) or bool(unit.get("dead", false)):
		return ""
	var who: String = str(unit.get("name", "?"))
	if unit.get("immune", []).has(status):
		return "%s es inmune a %s." % [who, display_name(status).to_lower()]
	var d: Dictionary = def(status)
	if is_negative(status) and not bool(d.get("irresistible", false)) and not bool(opts.get("ignore_resist", false)):
		var r: int = resist_chance(unit, status)
		if r > 0 and randi() % 100 < r:
			return "%s resiste: no queda %s." % [who, display_name(status).to_lower()]
	if turns <= 0:
		turns = int(data().get("default_turns", DEFAULT_TURNS))
	if bool(opts.get("crit", false)) and status in ["sangrado", "veneno"]:
		turns = maxi(turns, int(data().get("crit_dot_turns", 5)))
	if not unit.get("statuses") is Dictionary:
		unit["statuses"] = {}
	var st: Dictionary = unit["statuses"]
	var stack: Dictionary = {"turns": turns, "value": value}
	if opts.has("mods"):
		stack["mods"] = opts["mods"]
	match status:
		"santiguado":
			var blocks: int = mini(total_value(unit, status) + maxi(value, 1), int(data().get("santiguado_max", 2)))
			st[status] = {"stacks": [{"turns": 99, "value": blocks}]}
			return "%s se santigua: bloquea %d golpe%s." % [who, blocks, "" if blocks == 1 else "s"]
		"aturdido":
			st[status] = {"stacks": [{"turns": 1, "value": 0}]}
			# A stunned guardian stops guarding.
			if has(unit, "cuidando"):
				st.erase("cuidando")
				return "%s queda %s y deja de cuidar." % [who, display_name(status).to_lower()]
		_:
			if bool(d.get("stacks", false)):
				var cur: Array = _stacks(unit, status)
				cur.append(stack)
				st[status] = {"stacks": cur}
			else:
				var old: Array = _stacks(unit, status)
				if not old.is_empty():
					stack["turns"] = maxi(stack["turns"], int(old[0].get("turns", 0)))
					stack["value"] = maxi(stack["value"], int(old[0].get("value", 0)))
				st[status] = {"stacks": [stack]}
	if opts.has("by_uid"):
		st[status]["by_uid"] = int(opts["by_uid"])
	return "%s: %s." % [who, display_name(status)]


static func remove(unit: Dictionary, status: String) -> bool:
	var st = unit.get("statuses", {})
	if st is Dictionary and st.has(status):
		st.erase(status)
		return true
	return false


## Sum of one stat's changes from salado/chiva/encarrerado stacks and the Al Borde / Convaleciente states.
## Stats: accuracy, dodge, speed, crit, prot, dmg_pct, stress_pct.
static func stat(unit: Dictionary, key: String) -> int:
	var n: int = 0
	for id in ["salado", "chiva"]:
		for s in _stacks(unit, id):
			var m = s.get("mods", {})
			if m is Dictionary:
				n += int(m.get(key, 0))
	if has(unit, "encarrerado"):
		n += int(data().get("encarrerado_mods", {}).get(key, 0))
	var sm: Dictionary = data().get("state_mods", {})
	if bool(unit.get("al_borde", false)):
		n += int(sm.get("al_borde", {}).get(key, 0))
	elif bool(unit.get("convaleciente", false)):
		n += int(sm.get("convaleciente", {}).get(key, 0))
	return n


## Start of the unit's turn. Returns {"damage", "heal", "stress", "skip", "logs"}.
## Values are returned, not applied, so the caller can run Al Borde / death / stress rules.
## Timed stacks lose a turn here; Espabilado drops at the start of a normal (not stunned) turn.
static func tick(unit: Dictionary) -> Dictionary:
	var res: Dictionary = {"damage": 0, "heal": 0, "stress": 0, "skip": false, "logs": PackedStringArray()}
	var st = unit.get("statuses", {})
	if not st is Dictionary or st.is_empty():
		return res
	var who: String = str(unit.get("name", "?"))
	var stunned: bool = has(unit, "aturdido")
	if not stunned and has(unit, "espabilado"):
		st.erase("espabilado")
	var heal: int = total_value(unit, "sobado")
	if heal > 0:
		res["heal"] = heal
		res["logs"].append("%s recupera %d PV (sobado)." % [who, heal])
	for id in ["sangrado", "veneno"]:
		var v: int = total_value(unit, id)
		if v > 0:
			res["damage"] = int(res["damage"]) + v
			res["logs"].append("%s pierde %d PV (%s)." % [who, v, display_name(id).to_lower()])
	var fright: int = total_value(unit, "susto")
	if fright > 0 and unit.has("stress"):
		res["stress"] = fright
		res["logs"].append("%s tiene susto: estrés +%d." % [who, fright])
	if stunned:
		res["skip"] = true
		res["logs"].append("%s está atarantado y pierde el turno." % who)
		st.erase("aturdido")
		var cur: Array = _stacks(unit, "espabilado")
		cur.append({"turns": 99, "value": 0})
		st["espabilado"] = {"stacks": cur}
	# Count down every timed stack (santiguado/espabilado use 99 = until spent / next normal turn).
	for k in st.keys():
		var id := str(k)
		if id in ["espabilado", "santiguado"]:
			continue
		var keep: Array = []
		for s in _stacks(unit, id):
			s["turns"] = int(s.get("turns", 1)) - 1
			if int(s["turns"]) > 0:
				keep.append(s)
		if keep.is_empty():
			st.erase(id)
		else:
			st[id]["stacks"] = keep
	return res


## Uses one Santiguado block if the unit has one. Returns true if the hit is blocked.
static func use_aegis(unit: Dictionary) -> bool:
	var s: Array = _stacks(unit, "santiguado")
	if s.is_empty() or int(s[0].get("value", 0)) <= 0:
		return false
	s[0]["value"] = int(s[0]["value"]) - 1
	if int(s[0]["value"]) <= 0:
		remove(unit, "santiguado")
	return true


## Units that single-target attacks may pick: hidden (agazapado) ones only if nobody else is left.
static func targetable(units: Array) -> Array:
	var alive: Array = units.filter(func(u): return u is Dictionary and not bool(u.get("dead", false)))
	var open: Array = alive.filter(func(u): return not has(u, "agazapado"))
	return open if not open.is_empty() else alive


## Enemy AI target pick: marked (fichado) units are chosen most of the time.
static func pick_target(units: Array) -> Dictionary:
	var pool: Array = targetable(units)
	if pool.is_empty():
		return {}
	var marked: Array = pool.filter(func(u): return has(u, "fichado"))
	if not marked.is_empty() and randf() < float(data().get("marked_target_chance", 0.7)):
		return marked[randi() % marked.size()]
	return pool[randi() % pool.size()]


## The guardian protecting `unit` (Al cuido) among `allies`, if it is still able to guard.
static func guardian_of(unit: Dictionary, allies: Array) -> Dictionary:
	if not has(unit, "cuidado"):
		return {}
	var uid: int = int(unit["statuses"]["cuidado"].get("by_uid", -1))
	for a in allies:
		if a is Dictionary and int(a.get("uid", -2)) == uid and not bool(a.get("dead", false)) and has(a, "cuidando") and not has(a, "aturdido"):
			return a
	return {}


static func clear(unit: Dictionary) -> void:
	unit.erase("statuses")
