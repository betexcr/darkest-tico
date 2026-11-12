extends RefCounted

## Camping (Fogata de Trocha): meal -> respite (camp skills) -> night ambush roll.
## Data: data/camp_skills.json. Spec: docs/01 §4.4, doc 07 §6.
## Camp buffs live on hero["camp_buffs"] = [{source, name, mods, fights}] and are read by
## StatusEffects.stat(); they count down once per fight (tick_fight) and end with the mission.

const StressSystemScript := preload("res://scripts/domain/stress_system.gd")
const StatusEffectsScript := preload("res://scripts/domain/status_effects.gd")

const DATA_PATH := "res://data/camp_skills.json"
const BalanceScript := preload("res://scripts/domain/balance.gd")
const LightSystemScript := preload("res://scripts/domain/light_system.gd")

static var _data: Dictionary = {}
static var _by_id: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open(DATA_PATH, FileAccess.READ)
		if f != null:
			var parsed = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				_data = parsed
				for sk in _data.get("skills", []):
					if sk is Dictionary:
						_by_id[str(sk.get("id", ""))] = sk
	return _data


static func skill(id: String) -> Dictionary:
	data()
	return _by_id.get(id, {})


static func respite_points() -> int:
	return int(BalanceScript.req(data(), "respite_points", "camp_skills.json"))


static func meals() -> Array:
	return data().get("meals", [])


static func living(party: Array) -> Array:
	return party.filter(func(h): return h is Dictionary and not h.get("dead", false))


# --- Meal ---------------------------------------------------------------------------

## Food listed is for 4 heroes; it shrinks with fewer living heroes (rounded up).
static func meal_cost(meal: Dictionary, party: Array) -> int:
	return int(ceil(float(meal.get("food", 0)) * float(living(party).size()) / 4.0))  # structural: meal food is written for a party of 4


static func meal_summary(meal: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	var hp: int = int(meal.get("heal_pct", 0))
	if hp != 0:
		parts.append("%+d%% PV" % hp)
	var st: int = int(meal.get("stress", 0))
	if st != 0:
		parts.append("%+d estrés" % st)
	return ", ".join(parts) if not parts.is_empty() else "sin efecto"


static func apply_meal(meal: Dictionary, party: Array) -> PackedStringArray:
	var logs: PackedStringArray = PackedStringArray()
	for h in living(party):
		_heal_pct(h, int(meal.get("heal_pct", 0)))
		if int(meal.get("stress", 0)) != 0:
			logs.append_array(StressSystemScript.add_stress(h, int(meal["stress"])))
	return logs


## +pct of max PV (at least 1); negative hurts but hunger never kills or knocks to Al Borde.
static func _heal_pct(hero: Dictionary, pct: int) -> int:
	if pct == 0 or hero.get("dead", false):
		return 0
	var hm: int = int(hero.get("hp_max", 1))
	var before: int = int(hero.get("hp", 0))
	if pct > 0:
		hero["hp"] = mini(before + maxi(int(round(hm * pct / 100.0)), 1), hm)
		if bool(hero.get("al_borde", false)):
			hero["al_borde"] = false
			hero["convaleciente"] = true
	else:
		hero["hp"] = maxi(before - int(round(hm * -pct / 100.0)), mini(before, 1))
	return int(hero["hp"]) - before


# --- Respite (camp skills) ------------------------------------------------------------

static func hero_skills(hero: Dictionary) -> Array:
	var out: Array = []
	for sid in hero.get("camp_skill_ids", []):
		var sk: Dictionary = skill(str(sid))
		if not sk.is_empty():
			out.append(sk)
	return out


static func _use_key(user: Dictionary, sk: Dictionary) -> String:
	return "%d:%s" % [int(user.get("uid", 0)), str(sk.get("id", ""))]


## Each hero may use each of their camp skills once per camp.
static func can_use(user: Dictionary, sk: Dictionary, party: Array, respite_left: int, used: Array) -> bool:
	if user.get("dead", false) or used.has(_use_key(user, sk)):
		return false
	if int(sk.get("cost", 0)) > respite_left:
		return false
	if str(sk.get("target", "self")) in ["ally", "others"]:
		return living(party).size() > 1
	return true


static func mark_used(user: Dictionary, sk: Dictionary, used: Array) -> void:
	used.append(_use_key(user, sk))


static func targets(user: Dictionary, sk: Dictionary, party: Array, ally: Dictionary = {}) -> Array:
	match str(sk.get("target", "self")):
		"ally":
			return [ally] if not ally.is_empty() and not is_same(ally, user) else []
		"others":
			return living(party).filter(func(h): return not is_same(h, user))
		"party":
			return living(party)
	return [user]


## Applies a camp skill. Returns {"logs": PackedStringArray, "prevent_ambush": bool}.
static func use_skill(user: Dictionary, sk: Dictionary, party: Array, ally: Dictionary = {}) -> Dictionary:
	var logs: PackedStringArray = PackedStringArray()
	logs.append("%s usa %s." % [user.get("name", "?"), sk.get("name", "?")])
	for t in targets(user, sk, party, ally):
		# Paranoia (doc 01 §3.3): may refuse a companion's care.
		if not is_same(t, user) and StressSystemScript.refuses_support(t):
			logs.append("  %s (paranoia) no se deja ayudar." % t.get("name", "?"))
			continue
		logs.append_array(_apply_effects(t, sk.get("effects", {}), sk))
	var se = sk.get("self_effects", {})
	if se is Dictionary and not se.is_empty():
		logs.append_array(_apply_effects(user, se, sk))
	return {"logs": logs, "prevent_ambush": bool(sk.get("prevent_ambush", false))}


static func _apply_effects(hero: Dictionary, eff: Dictionary, sk: Dictionary) -> PackedStringArray:
	var logs: PackedStringArray = PackedStringArray()
	var who: String = str(hero.get("name", "?"))
	if eff.has("heal_pct"):
		logs.append("  %s %+d PV." % [who, _heal_pct(hero, int(eff["heal_pct"]))])
	for st in eff.get("cure", []):
		if str(st) == "all_negative":
			var gone: PackedStringArray = StatusEffectsScript.remove_all_negative(hero)
			if not gone.is_empty():
				logs.append("  %s queda limpio: %s." % [who, ", ".join(gone)])
		elif StatusEffectsScript.remove(hero, str(st)):
			logs.append("  %s ya no está %s." % [who, StatusEffectsScript.display_name(str(st)).to_lower()])
	if eff.has("stress"):
		logs.append("  %s %+d estrés." % [who, int(eff["stress"])])
		logs.append_array(StressSystemScript.add_stress(hero, int(eff["stress"])))
	var b = eff.get("buff", null)
	if b is Dictionary:
		add_buff(hero, str(sk.get("id", "")), str(sk.get("name", "")), b.get("mods", {}), int(BalanceScript.req(b, "fights", "camp_skills.json buff")))
		logs.append("  %s: %s por %d peleas." % [who, mods_text(b.get("mods", {})), int(BalanceScript.req(b, "fights", "camp_skills.json buff"))])
	return logs


# --- Camp buffs -------------------------------------------------------------------------

static func add_buff(hero: Dictionary, source: String, name: String, mods: Dictionary, fights: int) -> void:
	if not hero.get("camp_buffs", null) is Array:
		hero["camp_buffs"] = []
	hero["camp_buffs"].append({"source": source, "name": name, "mods": mods.duplicate(), "fights": fights})


## One fight is over: every camp buff loses a fight; spent ones are removed.
static func tick_fight(hero: Dictionary) -> void:
	var kept: Array = []
	for b in hero.get("camp_buffs", []):
		if b is Dictionary and int(b.get("fights", 0)) > 1:
			var nb: Dictionary = b.duplicate(true)
			nb["fights"] = int(b["fights"]) - 1
			kept.append(nb)
	hero["camp_buffs"] = kept


const MOD_LABELS := {
	"accuracy": "precisión", "dodge": "esquiva", "speed": "velocidad", "crit": "crítico",
	"prot": "% protección", "dmg_pct": "% daño", "stress_pct": "% estrés recibido",
}


static func mods_text(mods: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for k in mods:
		parts.append("%+d %s" % [int(mods[k]), MOD_LABELS.get(str(k), str(k))])
	return ", ".join(parts)


# --- Night ambush -------------------------------------------------------------------------

## Chance in % (doc 07 §6): base, + low_light_pct in low light (Luz tier Penumbra or
## darker), + exhausted_pct when the living party's average stress reaches exhausted_stress;
## 0 if a camp skill keeps watch.
static func ambush_chance(light: int, prevented: bool, party: Array = []) -> int:
	if prevented:
		return 0
	var a: Dictionary = data().get("ambush", {})
	var c: int = int(BalanceScript.req(a, "base_pct", "camp_skills.json ambush"))
	if LightSystemScript.is_low(light):
		c += int(BalanceScript.req(a, "low_light_pct", "camp_skills.json ambush"))
	var alive: Array = living(party)
	if not alive.is_empty():
		var total: int = 0
		for h in alive:
			total += int(h.get("stress", 0))
		if total >= int(BalanceScript.req(a, "exhausted_stress", "camp_skills.json ambush")) * alive.size():
			c += int(BalanceScript.req(a, "exhausted_pct", "camp_skills.json ambush"))
	return c
