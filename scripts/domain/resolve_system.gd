extends RefCounted

## Hero resolve level 0–6 (experience). Data: data/progression.json. Spec: docs/01 §6.
## - Resolve XP is earned only by completing an expedition (fleeing or dying earns none).
## - Each level adds status resistances (resist_per_level).
## - Expedition difficulty gates who goes: heroes above max_level refuse; heroes below
##   min_level are under-leveled (start stress + extra stress taken for the whole mission).

const DATA_PATH := "res://data/progression.json"
const MAX_LEVEL := 6

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open(DATA_PATH, FileAccess.READ)
		if f != null:
			var parsed = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				_data = parsed
	return _data


static func cfg() -> Dictionary:
	return data().get("resolve", {})


static func thresholds() -> Array:
	return cfg().get("xp_thresholds", [0, 2, 8, 14, 24, 36, 48])


static func level_name(level: int) -> String:
	var names: Array = cfg().get("level_names", [])
	var l: int = clampi(level, 0, MAX_LEVEL)
	return str(names[l]) if l < names.size() else "Nivel %d" % l


static func xp_for_level(level: int) -> int:
	var t: Array = thresholds()
	return int(t[clampi(level, 0, t.size() - 1)])


static func level_for_xp(xp: int) -> int:
	var lvl: int = 0
	var t: Array = thresholds()
	for i in t.size():
		if xp >= int(t[i]):
			lvl = i
	return mini(lvl, MAX_LEVEL)


## {"current", "needed"}: XP inside the current level and the size of that level (both 1 at max).
static func progress(hero: Dictionary) -> Dictionary:
	var lvl: int = int(hero.get("resolve_level", 0))
	if lvl >= MAX_LEVEL:
		return {"current": 1, "needed": 1}
	var floor_xp: int = xp_for_level(lvl)
	return {"current": int(hero.get("resolve_xp", 0)) - floor_xp, "needed": xp_for_level(lvl + 1) - floor_xp}


## Status resistance points this hero's level adds to one category.
static func resist_bonus(level: int, category: String) -> int:
	return int(cfg().get("resist_per_level", {}).get(category, 0)) * clampi(level, 0, MAX_LEVEL)


## Adds XP, levels up if a threshold is crossed. Returns {xp_gained, level_before, level_after}.
## Stats from the level (resistances) are applied by GameState.recompute_stats.
static func grant_xp(hero: Dictionary, amount: int) -> Dictionary:
	var before: int = int(hero.get("resolve_level", 0))
	var cap: int = xp_for_level(MAX_LEVEL)
	hero["resolve_xp"] = mini(int(hero.get("resolve_xp", 0)) + maxi(amount, 0), cap)
	var after: int = maxi(level_for_xp(int(hero["resolve_xp"])), before)
	hero["resolve_level"] = after
	return {"xp_gained": amount, "level_before": before, "level_after": after}


# --- Expedition difficulty --------------------------------------------------------

static func difficulties() -> Array:
	return data().get("difficulties", [])


static func difficulty(id: String) -> Dictionary:
	for d in difficulties():
		if str(d.get("id", "")) == id:
			return d
	var all: Array = difficulties()
	return all[0] if not all.is_empty() else {"id": "aprendiz", "name": "Aprendiz", "level": 1, "min_level": 0, "max_level": 2, "xp": 4}


## True if the hero is too seasoned for this difficulty and refuses to go.
static func refuses(hero: Dictionary, diff: Dictionary) -> bool:
	return int(hero.get("resolve_level", 0)) > int(diff.get("max_level", MAX_LEVEL))


## Levels the hero is short of the difficulty's min_level (0 = fine).
static func underlevel(hero: Dictionary, diff: Dictionary) -> int:
	return maxi(int(diff.get("min_level", 0)) - int(hero.get("resolve_level", 0)), 0)


static func underlevel_start_stress(levels: int) -> int:
	return int(cfg().get("underlevel_start_stress", 20)) * levels


static func underlevel_stress_pct(levels: int) -> int:
	return int(cfg().get("underlevel_stress_pct", 25)) * levels
