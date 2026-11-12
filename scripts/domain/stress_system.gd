extends RefCounted

## Mental stress 0–200: resolve at 100 (Quebranto / Virtud), Colapso at 200. See docs/01-core-systems-spec.md

const CombatResolverScript := preload("res://scripts/domain/combat_resolver.gd")
const StatusEffectsScript := preload("res://scripts/domain/status_effects.gd")


const THRESHOLD_RESOLVE := 100
const THRESHOLD_COLAPSO := 200
## Stress left after surviving a Colapso while Al Borde (doc 01 §3.4; moves to data in P1-06).
const COLAPSO_SURVIVE_STRESS := 170

const QUEBRANTO_CHANCE := 0.75
## Town events shift the Virtud chance for one expedition (+0.15 Fiesta patronal, -0.15 Se viene
## el temporal). GameState sets it at mission start and clears it at mission end.
static var virtue_bonus: float = 0.0

const AFFLICTIONS := ["paranoia", "cobardia", "ira_ciega", "bravata", "desesperanza", "nervios", "fatalismo"]
const VIRTUDES := ["serenidad", "firmeza", "valentia", "punteria", "esperanza", "vigor", "abnegacion"]

## Tuning knobs for affliction / virtue hooks. Stat changes (Nervios, Puntería, Valentía,
## Firmeza, Fatalismo) are data: data/statuses.json "mental_mods", read by StatusEffects.stat().
const PARANOIA_REFUSE_CHANCE := 0.35
const COBARDIA_SKIP_CHANCE := 0.20
const IRA_CIEGA_CHANCE := 0.15
const BRAVATA_CHANCE := 0.20
const BRAVATA_LIGHT_COST := 5
const DESESPERANZA_CHANCE := 0.25
const DESESPERANZA_STRESS := 3
const ESPERANZA_RELIEF := 2
const VIGOR_REGEN := 1
const ABNEGACION_CHANCE := 0.25


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
	# Under-leveled for this expedition (docs/01 §6): GameState sets the % at mission start.
	mult *= 1.0 + float(int(hero.get("underlevel_stress_pct", 0))) / 100.0
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
	if randf() < clampf(QUEBRANTO_CHANCE - virtue_bonus, 0.0, 1.0):
		var aff: String = AFFLICTIONS[randi() % AFFLICTIONS.size()]
		hero["affliction_id"] = aff
		hero["virtud_id"] = ""
		logs.append("%s: ¡Quebranto! (%s)" % [hero.get("name", "?"), affliction_name(aff)])
	else:
		var v: String = VIRTUDES[randi() % VIRTUDES.size()]
		hero["virtud_id"] = v
		hero["affliction_id"] = ""
		hero["stress"] = 40
		logs.append("%s: ¡Virtud! (%s)" % [hero.get("name", "?"), virtud_name(v)])
	return logs


static func affliction_name(id: String) -> String:
	match id:
		"paranoia":
			return "Paranoia"
		"cobardia":
			return "Cobardía"
		"ira_ciega":
			return "Ira ciega"
		"bravata":
			return "Bravata"
		"desesperanza":
			return "Desesperanza"
		"nervios":
			return "Nervios"
		"fatalismo":
			return "Fatalismo"
		_:
			return id


static func virtud_name(id: String) -> String:
	match id:
		"serenidad":
			return "Serenidad"
		"firmeza":
			return "Firmeza"
		"valentia":
			return "Valentía"
		"punteria":
			return "Puntería"
		"esperanza":
			return "Esperanza"
		"vigor":
			return "Vigor"
		"abnegacion":
			return "Abnegación"
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
	# Doc 01 §3.4: already Al Borde -> death roll with a severe penalty. Surviving keeps them
	# Al Borde at 0 PV (owner 2026-11-11) with stress just below the collapse line.
	var chance: float = CombatResolverScript.death_save_chance(hero, true)
	hero["borde_checks"] = int(hero.get("borde_checks", 0)) + 1
	if CombatResolverScript.roll_death_save(chance):
		hero["hp"] = 0
		hero["stress"] = COLAPSO_SURVIVE_STRESS
		logs.append("%s se aferra a la vida tras el colapso (%d%%)." % [hero.get("name", "?"), int(round(chance * 100))])
	else:
		hero["dead"] = true
		hero["hp"] = 0
		logs.append("%s no sobrevive el colapso." % hero.get("name", "?"))
	return logs


static func _aff(hero: Dictionary) -> String:
	return str(hero.get("affliction_id", ""))


static func _vir(hero: Dictionary) -> String:
	return str(hero.get("virtud_id", ""))


static func _living_others(hero: Dictionary, party: Array) -> Array:
	var others: Array = []
	for h in party:
		if h is Dictionary and not h.get("dead", false) and not is_same(h, hero):
			others.append(h)
	return others


## Before a hero acts: returns true if turn is wasted (Cobardía).
static func hero_turn_blocked(hero: Dictionary) -> bool:
	if _aff(hero) == "cobardia" and randf() < COBARDIA_SKIP_CHANCE:
		add_stress(hero, 5)
		return true
	return false


## Paranoia: hero may refuse a heal/buff skill (turn is lost).
static func refuses_support(hero: Dictionary) -> bool:
	return _aff(hero) == "paranoia" and randf() < PARANOIA_REFUSE_CHANCE


## If Ira ciega procs, return a random living ally to receive friendly fire, or {}
static func ira_ciega_friendly_fire_target(hero: Dictionary, party: Array) -> Dictionary:
	if _aff(hero) != "ira_ciega":
		return {}
	if randf() > IRA_CIEGA_CHANCE:
		return {}
	var others: Array = _living_others(hero, party)
	if others.is_empty():
		return {}
	return others[randi() % others.size()]


static func friendly_fire_damage() -> int:
	return randi_range(2, 5)


## Bravata: on attack, chance to waste Luz showing off. Returns light to subtract (0 if no proc).
static func bravata_light_cost(hero: Dictionary) -> int:
	if _aff(hero) == "bravata" and randf() < BRAVATA_CHANCE:
		return BRAVATA_LIGHT_COST
	return 0


## Desesperanza: after taking a hit, chance to spread stress to the rest of the party.
static func spread_despair(hero: Dictionary, party: Array) -> PackedStringArray:
	var logs: PackedStringArray = PackedStringArray()
	if hero.get("dead", false) or _aff(hero) != "desesperanza" or randf() >= DESESPERANZA_CHANCE:
		return logs
	logs.append("%s (desesperanza): «¡Aquí nos morimos todos!»" % hero.get("name", "?"))
	for h in _living_others(hero, party):
		logs.append_array(add_stress(h, DESESPERANZA_STRESS))
	return logs


## Abnegación: a living ally may step in front of an attack aimed at target. Returns protector or {}.
static func find_protector(target: Dictionary, party: Array) -> Dictionary:
	for h in _living_others(target, party):
		if _vir(h) == "abnegacion" and not h.get("al_borde", false) and randf() < ABNEGACION_CHANCE:
			return h
	return {}


## Start of each combat round: Esperanza calms allies, Vigor regenerates HP.
static func round_start_effects(party: Array) -> PackedStringArray:
	var logs: PackedStringArray = PackedStringArray()
	for h in party:
		if not (h is Dictionary) or h.get("dead", false):
			continue
		match _vir(h):
			"esperanza":
				var others: Array = _living_others(h, party)
				if not others.is_empty():
					logs.append("%s (esperanza) anima a la cuadrilla: -%d estrés." % [h.get("name", "?"), ESPERANZA_RELIEF])
					for o in others:
						logs.append_array(add_stress(o, -ESPERANZA_RELIEF))
			"vigor":
				if not h.get("al_borde", false) and int(h.get("hp", 0)) < int(h.get("hp_max", 0)):
					h["hp"] = mini(int(h["hp"]) + VIGOR_REGEN, int(h["hp_max"]))
					logs.append("%s (vigor) recupera %d HP." % [h.get("name", "?"), VIGOR_REGEN])
	return logs
