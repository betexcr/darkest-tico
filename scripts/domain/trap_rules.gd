extends RefCounted

## Trap rooms (doc 07 §4, P2-01): data in data/traps.json. Pure; no nodes.
## Desarmar (DD trap disarm): chance = the party's best "trampa" value (each class's trap
## skill, heroes.json status_resist) + the Luz tier's trap_pct − the trap's difficulty
## (clamped). Pasar con cuidado: costs Luz, then the trap may still spring.

const BalanceScript := preload("res://scripts/domain/balance.gd")
const LightSystemScript := preload("res://scripts/domain/light_system.gd")
const StatusEffectsScript := preload("res://scripts/domain/status_effects.gd")
const DATA_PATH := "res://data/traps.json"

static var _data: Dictionary = {}
static var _by_id: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open(DATA_PATH, FileAccess.READ)
		if f != null:
			var parsed = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				_data = parsed
				for t in _data.get("traps", []):
					if t is Dictionary:
						_by_id[str(t.get("id", ""))] = t
	return _data


static func get_trap(id: String) -> Dictionary:
	data()
	return _by_id.get(id, {})


## A number from the top of traps.json (strict).
static func num(key: String) -> int:
	return int(BalanceScript.req(data(), key, "traps.json"))


## The living hero best at spotting traps (highest "trampa" resist); {} if none is alive.
static func spotter(party: Array) -> Dictionary:
	var best: Dictionary = {}
	for h in party:
		if h is Dictionary and not h.get("dead", false):
			if best.is_empty() or StatusEffectsScript.resist_value(h, "trampa") > StatusEffectsScript.resist_value(best, "trampa"):
				best = h
	return best


## Chance in % that Desarmar works.
static func disarm_chance(trap: Dictionary, party: Array, light: int) -> int:
	var who: Dictionary = spotter(party)
	var sense: int = StatusEffectsScript.resist_value(who, "trampa") if not who.is_empty() else 0
	var c: int = sense + LightSystemScript.val(light, "trap_pct") - int(BalanceScript.req(trap, "difficulty", "traps.json trap"))
	return clampi(c, num("disarm_min"), num("disarm_max"))
