extends RefCounted

## Mental stress 0–200: resolve at 100 (Quebranto / Virtud), Colapso at 200. See docs/01-core-systems-spec.md

const CombatResolverScript := preload("res://scripts/domain/combat_resolver.gd")

const THRESHOLD_RESOLVE := 100
const THRESHOLD_COLAPSO := 200

const QUEBRANTO_CHANCE := 0.75

const AFFLICTIONS := ["paranoia", "cobardia", "ira_ciega"]
const VIRTUDES := ["serenidad", "firmeza"]


static func add_stress(hero: Dictionary, amount: int) -> PackedStringArray:
	var logs: PackedStringArray = PackedStringArray()
	if hero.get("dead", false):
		return logs
	if amount < 0:
		hero["stress"] = maxi(int(hero.get("stress", 0)) + amount, 0)
		return logs
	var mult: float = 1.0
	if str(hero.get("virtud_id", "")) == "serenidad":
		mult = 0.75
	var adj: int = int(round(amount * mult))
	var old_s: int = int(hero.get("stress", 0))
	var new_s: int = mini(old_s + adj, THRESHOLD_COLAPSO)
	hero["stress"] = new_s
	if new_s >= THRESHOLD_COLAPSO and old_s < THRESHOLD_COLAPSO:
		logs.append_array(_apply_colapso(hero))
	elif new_s >= THRESHOLD_RESOLVE and old_s < THRESHOLD_RESOLVE:
		logs.append_array(_resolve_at_100(hero))
	return logs


static func _resolve_at_100(hero: Dictionary) -> PackedStringArray:
	var logs: PackedStringArray = PackedStringArray()
	if str(hero.get("affliction_id", "")) != "" or str(hero.get("virtud_id", "")) != "":
		return logs
	if randf() < QUEBRANTO_CHANCE:
		var aff: String = AFFLICTIONS[randi() % AFFLICTIONS.size()]
		hero["affliction_id"] = aff
		hero["virtud_id"] = ""
		logs.append("%s: ¡Quebranto! (%s)" % [hero.get("name", "?"), _affliction_name(aff)])
	else:
		var v: String = VIRTUDES[randi() % VIRTUDES.size()]
		hero["virtud_id"] = v
		hero["affliction_id"] = ""
		hero["stress"] = 40
		logs.append("%s: ¡Virtud! (%s)" % [hero.get("name", "?"), _virtud_name(v)])
	return logs


static func _affliction_name(id: String) -> String:
	match id:
		"paranoia":
			return "Paranoia"
		"cobardia":
			return "Cobardía"
		"ira_ciega":
			return "Ira ciega"
		_:
			return id


static func _virtud_name(id: String) -> String:
	match id:
		"serenidad":
			return "Serenidad"
		"firmeza":
			return "Firmeza"
		_:
			return id


static func _apply_colapso(hero: Dictionary) -> PackedStringArray:
	var logs: PackedStringArray = PackedStringArray()
	hero["stress"] = THRESHOLD_COLAPSO
	logs.append("%s: ¡Colapso mental!" % hero.get("name", "?"))
	if hero.get("dead", false):
		return logs
	if not hero.get("al_borde", false):
		hero["al_borde"] = true
		hero["hp"] = 0
		logs.append("%s cae a Al Borde por el colapso." % hero.get("name", "?"))
		return logs
	hero["borde_checks"] = int(hero.get("borde_checks", 0)) + 1
	var save_bonus: float = 0.0
	if str(hero.get("virtud_id", "")) == "firmeza":
		save_bonus = 0.08
	if randf() < CombatResolverScript.DEATH_SAVE_BASE + save_bonus:
		hero["hp"] = 1
		hero["al_borde"] = false
		hero["stress"] = 80
		logs.append("%s se aferra a la vida tras el colapso." % hero.get("name", "?"))
	else:
		hero["dead"] = true
		hero["hp"] = 0
		logs.append("%s no sobrevive el colapso." % hero.get("name", "?"))
	return logs


## Before a hero acts: returns true if turn is wasted (disobey).
static func hero_turn_blocked(hero: Dictionary) -> bool:
	var aff: String = str(hero.get("affliction_id", ""))
	if aff == "paranoia" and randf() < 0.25:
		return true
	if aff == "cobardia" and randf() < 0.20:
		add_stress(hero, 5)
		return true
	return false


## If Ira ciega procs, return a random living ally to receive friendly fire, or null
static func ira_ciega_friendly_fire_target(hero: Dictionary, party: Array) -> Dictionary:
	if str(hero.get("affliction_id", "")) != "ira_ciega":
		return {}
	if randf() > 0.15:
		return {}
	var others: Array = []
	for h in party:
		if h is Dictionary and not h.get("dead", false) and h != hero:
			others.append(h)
	if others.is_empty():
		return {}
	return others[randi() % others.size()]


static func friendly_fire_damage() -> int:
	return randi_range(2, 5)
