extends RefCounted

## Pure item rules shared by exploration and combat (data/items.json, P3-09).

const StressSystemScript := preload("res://scripts/domain/stress_system.gd")
const StatusEffectsScript := preload("res://scripts/domain/status_effects.gd")


static func is_usable(item: Dictionary, in_combat: bool) -> bool:
	var u: String = str(item.get("usable", "both"))
	if u == "both":
		return true
	return u == ("combat" if in_combat else "explore")


static func light_amount(item: Dictionary) -> int:
	return int(item.get("effects", {}).get("light", 0))


static func damage_roll(item: Dictionary) -> int:
	var d = item.get("effects", {}).get("damage", null)
	if d is Array and d.size() >= 2:
		return randi_range(int(d[0]), int(d[1]))
	return 0


## Applies heal / stress / hp_risk to one hero. Returns log lines (Spanish, in-game).
static func apply_to_hero(item: Dictionary, hero: Dictionary) -> PackedStringArray:
	var logs: PackedStringArray = PackedStringArray()
	if bool(hero.get("dead", false)):
		return logs
	var fx: Dictionary = item.get("effects", {})
	var who: String = str(hero.get("name", "?"))
	if fx.has("heal"):
		var before: int = int(hero.get("hp", 0))
		hero["hp"] = mini(before + int(fx["heal"]), int(hero.get("hp_max", 1)))
		if int(hero["hp"]) > 0:
			hero["al_borde"] = false
		logs.append("%s recupera %d PV." % [who, int(hero["hp"]) - before])
	if fx.has("stress"):
		var delta: int = int(fx["stress"])
		logs.append_array(StressSystemScript.add_stress(hero, delta))
		logs.append("%s: estrés %+d." % [who, delta])
	for status in fx.get("cure", []):
		if StatusEffectsScript.has(hero, str(status)):
			hero["statuses"].erase(str(status))
			logs.append("%s ya no está %s." % [who, StatusEffectsScript.NAMES.get(str(status), status).to_lower()])
	var risk = fx.get("hp_risk", null)
	if risk is Dictionary and randf() < float(risk.get("chance", 0.0)):
		var hp: int = int(hero.get("hp", 0))
		hero["hp"] = maxi(hp - int(risk.get("amount", 0)), mini(hp, 1))
		logs.append("%s sufre la goma (-%d PV)." % [who, hp - int(hero["hp"])])
	return logs
