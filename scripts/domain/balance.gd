extends RefCounted

## Balance numbers (P1-06): data/balance.json, read by dot path ("combat.crit_mult").
## Getters are strict: a missing key is a push_error (and 0), never a silent default, so
## tools/validate_data.py and the tests catch typos. Pure; no nodes.

const DATA_PATH := "res://data/balance.json"

static var _data: Dictionary = {}
## Test-only overrides by path (override / reset).
static var _overrides: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open(DATA_PATH, FileAccess.READ)
		if f != null:
			var parsed = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				_data = parsed
	return _data


## Raw value at `path`; push_error + null when missing.
static func value(path: String):
	if _overrides.has(path):
		return _overrides[path]
	var node = data()
	for part in path.split("."):
		if not node is Dictionary or not (node as Dictionary).has(part):
			push_error("balance.json: missing '%s'" % path)
			return null
		node = node[part]
	return node


static func num(path: String) -> float:
	var v = value(path)
	return float(v) if v is float or v is int else 0.0


static func int_of(path: String) -> int:
	var v = value(path)
	return int(v) if v is float or v is int else 0


static func arr(path: String) -> Array:
	var v = value(path)
	return v if v is Array else []


## A required key from another data file (statuses.json, camp_skills.json, …): push_error
## instead of a duplicated numeric fallback when the validator-guaranteed key is missing.
static func req(dict: Dictionary, key: String, where: String = ""):
	if dict.has(key):
		return dict[key]
	push_error("%s: missing '%s'" % [where if where != "" else "data", key])
	return 0


static func override(path: String, v) -> void:
	_overrides[path] = v


static func reset() -> void:
	_overrides.clear()
