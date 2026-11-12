extends RefCounted
class_name CombatResolver

## Pure rules aligned with docs/01-core-systems-spec.md (initiative, hit, damage, crits, Al Borde).
## Every number comes from data/balance.json (P1-06) through Balance.

const StatusEffectsScript := preload("res://scripts/domain/status_effects.gd")
const BalanceScript := preload("res://scripts/domain/balance.gd")


static func roll_initiative(speed: int, _resolve_level: int = 0) -> int:
	var j: int = BalanceScript.int_of("combat.initiative_jitter")
	return speed + randi_range(-j, j)


## Doc 01 §2.3: hit = base + (accuracy + skill accuracy − dodge) × per point, clamped.
static func hit_chance(attacker_accuracy: int, skill_accuracy: int, target_dodge: int) -> float:
	var p: float = BalanceScript.num("combat.hit_base") + float(attacker_accuracy + skill_accuracy - target_dodge) * BalanceScript.num("combat.hit_per_point")
	return clampf(p, BalanceScript.num("combat.hit_min"), BalanceScript.num("combat.hit_max"))


static func roll_damage(skill: Dictionary) -> int:
	var mn: int = int(skill.get("damage_min", 1))  # structural: a skill without damage hits for 1
	var mx: int = int(skill.get("damage_max", mn))
	if mx < mn:
		mx = mn
	return randi_range(mn, mx)


## Doc 01 §2.3: critChance = attacker crit (base + skill + buffs) − target crit resist, capped.
static func crit_chance(attacker_crit: int, target_crit_resist: int = 0) -> float:
	return clampf(float(attacker_crit - target_crit_resist) / 100.0, 0.0, BalanceScript.num("combat.crit_cap"))


static func roll_crit(attacker_crit: int, target_crit_resist: int = 0) -> bool:
	return randf() < crit_chance(attacker_crit, target_crit_resist)


static func resolve_attack_damage(raw: int, crit: bool) -> int:
	if crit:
		return int(ceil(raw * BalanceScript.num("combat.crit_mult")))
	return raw


static func prot_cap() -> int:
	return BalanceScript.int_of("combat.prot_cap")


## Doc 01 §2.3 damage: raw × crit × (1 + atkMods) × (1 − protection) × element multiplier.
## atk_pct and prot_pct are percent points; prot is capped (combat.prot_cap). 0 damage stays 0
## (aegis, immunity); anything that hits for more than 0 does at least 1.
static func final_damage(raw: int, atk_pct: int = 0, prot_pct: int = 0, elem_mult: float = 1.0, crit: bool = false) -> int:
	if raw <= 0 or elem_mult <= 0.0:
		return 0
	var d: float = float(resolve_attack_damage(raw, crit))
	d *= 1.0 + atk_pct / 100.0
	d *= 1.0 - clampi(prot_pct, 0, prot_cap()) / 100.0
	d *= elem_mult
	return maxi(int(round(d)), 1)


## Doc 01 §2.4: chance 0-1 to survive a hit while Al Borde. Starts from the hero's
## "golpe_de_gracia" resist (death.base by default, Quebranto/Virtud mods, statuses.json
## cap) and drops per earlier roll this expedition, for high stress, and on a Colapso.
static func death_save_chance(hero: Dictionary, collapse: bool = false) -> float:
	var pts: int = int(round(StatusEffectsScript.deathblow_chance(hero) * 100.0))
	pts -= BalanceScript.int_of("death.check_penalty") * int(hero.get("borde_checks", 0))
	var stress: int = int(hero.get("stress", 0))
	var worst: int = 0
	for pair in BalanceScript.arr("death.stress_penalties"):
		if stress >= int(pair[0]):
			worst = maxi(worst, int(pair[1]))
	pts -= worst
	if collapse:
		pts -= BalanceScript.int_of("death.collapse_penalty")
	return clampi(pts, 0, 100) / 100.0


static func roll_death_save(chance: float) -> bool:
	return randf() < chance
