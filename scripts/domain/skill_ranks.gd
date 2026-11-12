extends RefCounted

## Casa Comunal de Oficios: hero skill ranks 1–5 (doc 02 §4, doc 04 §3.3, doc 01 §6.3).
## - Ranks are bought one step at a time; rank N needs resolve level min_resolve[N].
## - Each rank above 1 adds per_rank (or the skill's own rank_bonus) to the fields the
##   skill already has, so a support skill never grows damage and vice versa.
## Data: data/progression.json "skill_ranks". Pure rules; GameState owns colones and heroes.

const ResolveSystemScript := preload("res://scripts/domain/resolve_system.gd")
const StatusEffectsScript := preload("res://scripts/domain/status_effects.gd")

## Every key per_rank / rank_bonus may use (the validator checks the same list).
## status_mods (+N to each numeric mod of applies/self_applies) is meant for a skill's own
## rank_bonus only, for skills whose sole numbers are status mods (Escudo de Barrio).
const BONUS_KEYS := ["damage_min", "damage_max", "skill_accuracy", "skill_crit", "heal_min", "heal_max",
	"stress_relief", "status_chance", "status_value", "status_mods"]


static func cfg() -> Dictionary:
	return ResolveSystemScript.data().get("skill_ranks", {})


static func max_rank() -> int:
	return int(cfg().get("max_rank", 5))


## Rank of `sid` for this hero (1 when never trained).
static func rank(hero: Dictionary, sid: String) -> int:
	var ranks = hero.get("skill_ranks", {})
	if not ranks is Dictionary:
		return 1
	return clampi(int(ranks.get(sid, 1)), 1, max_rank())


static func cost_for(target_rank: int) -> int:
	var c: Array = cfg().get("costs", [])
	return int(c[target_rank]) if target_rank >= 0 and target_rank < c.size() else 0


static func min_resolve_for(target_rank: int) -> int:
	var m: Array = cfg().get("min_resolve", [])
	return int(m[target_rank]) if target_rank >= 0 and target_rank < m.size() else ResolveSystemScript.MAX_LEVEL


## Base price of the next rank (0 at max). GameState applies town-event multipliers.
static func next_cost(hero: Dictionary, sid: String) -> int:
	var r: int = rank(hero, sid)
	return 0 if r >= max_rank() else cost_for(r + 1)


## "" when the next rank can be bought for `price`; otherwise why not (Spanish, for the UI).
static func block_reason(hero: Dictionary, sid: String, colones: int, price: int) -> String:
	if not (hero.get("skill_ids", []) as Array).has(sid):
		return "No conoce esa habilidad."
	if bool(hero.get("dead", false)):
		return "Ya no está entre los vivos."
	var r: int = rank(hero, sid)
	if r >= max_rank():
		return "Rango máximo."
	var need: int = min_resolve_for(r + 1)
	if int(hero.get("resolve_level", 0)) < need:
		return "El rango %d necesita Resolución %d." % [r + 1, need]
	if colones < price:
		return "No alcanza: el rango %d cuesta %d ₡." % [r + 1, price]
	return ""


## Rank every skill starts at for a hero who arrives already seasoned (DD's experienced
## recruits come with upgraded skills): the highest rank their resolve level allows.
static func default_rank_for_level(level: int) -> int:
	var best: int = 1
	for r in range(2, max_rank() + 1):
		if level >= min_resolve_for(r):
			best = r
	return best


static func bonus_of(skill: Dictionary) -> Dictionary:
	var own = skill.get("rank_bonus", null)
	return own if own is Dictionary else cfg().get("per_rank", {})


## A copy of `skill` at `r` (rank 1 = the data as written, plus "rank": 1).
static func ranked(skill: Dictionary, r: int) -> Dictionary:
	var out: Dictionary = skill.duplicate(true)
	if out.is_empty():
		return out
	var steps: int = clampi(r, 1, max_rank()) - 1
	out["rank"] = steps + 1
	if steps <= 0:
		return out
	var b: Dictionary = bonus_of(skill)
	var attack: bool = out.has("damage_min")
	if attack:
		out["damage_min"] = int(out["damage_min"]) + int(b.get("damage_min", 0)) * steps
		out["damage_max"] = int(out.get("damage_max", out["damage_min"])) + int(b.get("damage_max", 0)) * steps
		out["skill_accuracy"] = int(out.get("skill_accuracy", 0)) + int(b.get("skill_accuracy", 0)) * steps
		out["skill_crit"] = int(out.get("skill_crit", 0)) + int(b.get("skill_crit", 0)) * steps
	if out.has("heal_min"):
		out["heal_min"] = int(out["heal_min"]) + int(b.get("heal_min", 0)) * steps
		out["heal_max"] = int(out.get("heal_max", out["heal_min"])) + int(b.get("heal_max", 0)) * steps
	for key in ["stress_relief", "self_stress_relief"]:
		if int(out.get(key, 0)) > 0:
			out[key] = int(out[key]) + int(b.get("stress_relief", 0)) * steps
	for key in ["applies", "self_applies"]:
		if out.has(key):
			out[key] = _ranked_applies(out[key], b, steps)
	return out


static func _ranked_applies(v, b: Dictionary, steps: int):
	if v is Array:
		return v.map(func(ap): return _ranked_apply(ap, b, steps) if ap is Dictionary else ap)
	if v is Dictionary:
		return _ranked_apply(v, b, steps)
	return v


static func _ranked_apply(ap: Dictionary, b: Dictionary, steps: int) -> Dictionary:
	var out: Dictionary = ap.duplicate(true)
	if out.has("chance") and float(out["chance"]) < 1.0:
		out["chance"] = minf(float(out["chance"]) + float(b.get("status_chance", 0.0)) * steps, 1.0)
	if int(out.get("value", 0)) > 0:
		out["value"] = int(out["value"]) + int(b.get("status_value", 0)) * steps
	var add_mod: int = int(b.get("status_mods", 0)) * steps
	if add_mod != 0 and out.get("mods") is Dictionary:
		for m in out["mods"]:
			if out["mods"][m] is float or out["mods"][m] is int:
				out["mods"][m] = int(out["mods"][m]) + add_mod
	return out


## What going from `from_rank` to the next rank changes, one short Spanish line each.
static func preview_lines(skill: Dictionary, from_rank: int) -> PackedStringArray:
	var lines := PackedStringArray()
	if from_rank >= max_rank() or skill.is_empty():
		return lines
	var a: Dictionary = ranked(skill, from_rank)
	var z: Dictionary = ranked(skill, from_rank + 1)
	if a.has("damage_min"):
		_diff_line(lines, int(a["damage_min"]), int(z["damage_min"]), "de daño mínimo")
		_diff_line(lines, int(a["damage_max"]), int(z["damage_max"]), "de daño máximo")
		_diff_line(lines, int(a.get("skill_accuracy", 0)), int(z.get("skill_accuracy", 0)), "de precisión")
		_diff_line(lines, int(a.get("skill_crit", 0)), int(z.get("skill_crit", 0)), "%% de crítico")
	if a.has("heal_min"):
		_diff_line(lines, int(a["heal_min"]), int(z["heal_min"]), "de curación mínima")
		_diff_line(lines, int(a["heal_max"]), int(z["heal_max"]), "de curación máxima")
	for key in ["stress_relief", "self_stress_relief"]:
		_diff_line(lines, int(a.get(key, 0)), int(z.get(key, 0)), "de estrés aliviado")
	for key in ["applies", "self_applies"]:
		var la: Array = as_list(a.get(key, null))
		var lz: Array = as_list(z.get(key, null))
		for k in mini(la.size(), lz.size()):
			var nm: String = StatusEffectsScript.display_name(str(la[k].get("status", "")))
			var ca: int = int(round(float(la[k].get("chance", 1.0)) * 100.0))
			var cz: int = int(round(float(lz[k].get("chance", 1.0)) * 100.0))
			if cz > ca:
				lines.append("+%d%% de probabilidad de %s" % [cz - ca, nm])
			var va: int = int(la[k].get("value", 0))
			var vz: int = int(lz[k].get("value", 0))
			if vz > va:
				lines.append("+%d a %s" % [vz - va, nm])
			var ma = la[k].get("mods", {})
			var mz = lz[k].get("mods", {})
			if ma is Dictionary and mz is Dictionary:
				for m in mz:
					var d: int = int(mz[m]) - int(ma.get(m, 0))
					if d > 0:
						lines.append("+%d %s con %s" % [d, MOD_NAMES.get(str(m), str(m)), nm])
	return lines


## Display names of status mods (statuses.json "mods" keys) for the rank preview.
const MOD_NAMES := {"prot": "de protección", "dmg_pct": "% de daño", "accuracy": "de precisión", "dodge": "de esquiva",
	"crit": "% de crítico", "speed": "de velocidad", "stress_pct": "% de estrés"}


static func _diff_line(lines: PackedStringArray, before: int, after: int, what: String) -> void:
	if after > before:
		lines.append(("+%d " + what) % (after - before))


static func as_list(v) -> Array:
	if v is Array:
		return v.filter(func(x): return x is Dictionary)
	if v is Dictionary:
		return [v]
	return []
