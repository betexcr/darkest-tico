extends RefCounted

## Region progression (P6-01, doc 05 §4): which regions exist, in campaign order, and which
## are open. Data: data/regions.json (id, path, unlock, wip). A region is "cleared" once its
## boss is beaten at any difficulty (GameState.regions_cleared: id -> {difficulty: count}).
## Pure rules; GameState owns the clears and the selected region.

const DATA_PATH := "res://data/regions.json"

static var _cache: Dictionary = {}


static func data() -> Dictionary:
	if _cache.is_empty():
		var f := FileAccess.open(DATA_PATH, FileAccess.READ)
		var d = JSON.parse_string(f.get_as_text()) if f != null else null
		_cache = d if d is Dictionary else {"regions": []}
	return _cache


## Every region row, in campaign order.
static func entries() -> Array:
	return data().get("regions", [])


static func entry_by_path(path: String) -> Dictionary:
	for e in entries():
		if str(e.get("path", "")) == path:
			return e
	return {}


static func entry_by_id(id: String) -> Dictionary:
	for e in entries():
		if str(e.get("id", "")) == id:
			return e
	return {}


## Regions the hub lists: everything but regions still being built, which only debug builds show.
static func visible(e: Dictionary, debug: bool) -> bool:
	return debug or not bool(e.get("wip", false))


static func is_cleared(cleared: Dictionary, id: String) -> bool:
	var c = cleared.get(id, {})
	if not c is Dictionary:
		return false
	for k in c:
		if int(c[k]) > 0:
			return true
	return false


static func cleared_count(cleared: Dictionary) -> int:
	var n: int = 0
	for id in cleared:
		if is_cleared(cleared, str(id)):
			n += 1
	return n


static func is_unlocked(e: Dictionary, cleared: Dictionary) -> bool:
	var u = e.get("unlock", {})
	if not u is Dictionary or u.is_empty():
		return true
	for id in u.get("cleared", []):
		if not is_cleared(cleared, str(id)):
			return false
	var any: Array = u.get("cleared_any", [])
	if not any.is_empty() and not any.any(func(id): return is_cleared(cleared, str(id))):
		return false
	if cleared_count(cleared) < int(u.get("cleared_count", 0)):
		return false
	return true


## Why a region is still closed (Spanish, for the hub); "" when it is open.
## `boss_of` maps a region id to its boss's name, `name_of` to the region's name.
static func lock_reason(e: Dictionary, cleared: Dictionary, name_of: Callable, boss_of: Callable) -> String:
	if is_unlocked(e, cleared):
		return ""
	var u: Dictionary = e.get("unlock", {})
	var parts: PackedStringArray = PackedStringArray()
	for id in u.get("cleared", []):
		if not is_cleared(cleared, str(id)):
			parts.append("vencer %s (%s)" % [_a(str(boss_of.call(str(id)))), name_of.call(str(id))])
	var any: Array = u.get("cleared_any", [])
	if not any.is_empty() and not any.any(func(id): return is_cleared(cleared, str(id))):
		parts.append("vencer al jefe de " + " o de ".join(PackedStringArray(any.map(func(id): return str(name_of.call(str(id)))))))
	var need: int = int(u.get("cleared_count", 0))
	if cleared_count(cleared) < need:
		parts.append("vencer a los jefes de %d regiones (van %d)" % [need, cleared_count(cleared)])
	return "Se abre al " + " y ".join(parts) + "."


## "a" + a name, with Spanish contraction: "El Mayordomo" -> "al Mayordomo".
static func _a(name: String) -> String:
	return "al " + name.substr(3) if name.begins_with("El ") else "a " + name
