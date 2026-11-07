extends RefCounted

## Combat ailments (minimal P1-04). Stored on a unit dictionary as
## unit["statuses"] = {"sangrado": {"turns": 3, "value": 2}, ...}.
##   sangrado / veneno: lose `value` HP at the start of each of the unit's turns.
##   aturdido: skips its next turn, then wears off.
## Cleared when a fight ends.

const NAMES := {"sangrado": "Sangrado", "veneno": "Envenenado", "aturdido": "Aturdido"}


static func apply(unit: Dictionary, status: String, turns: int, value: int) -> String:
	if not NAMES.has(status) or bool(unit.get("dead", false)):
		return ""
	if not unit.get("statuses") is Dictionary:
		unit["statuses"] = {}
	var cur: Dictionary = unit["statuses"].get(status, {"turns": 0, "value": 0})
	unit["statuses"][status] = {"turns": maxi(int(cur["turns"]), turns), "value": maxi(int(cur["value"]), value)}
	return "%s: %s." % [unit.get("name", "?"), NAMES[status]]


static func has(unit: Dictionary, status: String) -> bool:
	var st = unit.get("statuses", {})
	return st is Dictionary and st.has(status)


static func any(unit: Dictionary) -> bool:
	var st = unit.get("statuses", {})
	return st is Dictionary and not st.is_empty()


static func labels(unit: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var st = unit.get("statuses", {})
	if st is Dictionary:
		for k in st:
			out.append(NAMES.get(k, str(k)))
	return out


## Start of the unit's turn. Returns {"damage": int, "skip": bool, "logs": PackedStringArray}.
## Damage is returned, not applied, so the caller can run Al Borde / death rules.
static func tick(unit: Dictionary) -> Dictionary:
	var res: Dictionary = {"damage": 0, "skip": false, "logs": PackedStringArray()}
	var st = unit.get("statuses", {})
	if not st is Dictionary or st.is_empty():
		return res
	var who: String = str(unit.get("name", "?"))
	for k in st.keys():
		var e: Dictionary = st[k]
		match str(k):
			"sangrado", "veneno":
				res["damage"] = int(res["damage"]) + int(e.get("value", 1))
				res["logs"].append("%s pierde %d PV (%s)." % [who, int(e.get("value", 1)), NAMES[k].to_lower()])
			"aturdido":
				res["skip"] = true
				res["logs"].append("%s está aturdido y pierde el turno." % who)
		e["turns"] = int(e.get("turns", 1)) - 1
		if int(e["turns"]) <= 0:
			st.erase(k)
	return res


static func clear(unit: Dictionary) -> void:
	unit.erase("statuses")
