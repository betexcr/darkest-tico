extends RefCounted
class_name CombatResolver

## Pure rules aligned with docs/01-core-systems-spec.md (initiative, hit, damage, crits, Al Borde).
## Balance numbers below move to data/balance.json in P1-06.

const StatusEffectsScript := preload("res://scripts/domain/status_effects.gd")

const INITIATIVE_JITTER := 2
const HIT_MIN := 0.05
const HIT_MAX := 0.95
const DEATH_SAVE_BASE := 0.67
const CRIT_CAP := 0.5
const CRIT_MULT := 1.5
## Doc 01 §2.4: the death roll gets harder for each earlier roll this expedition…
const BORDE_CHECK_PENALTY := 8
## …and with high stress ({stress threshold: points off}, the highest one that applies).
const STRESS_PENALTY := {100: 10, 150: 20}
## Doc 01 §3.4: a Colapso (stress 200) while already Al Borde rolls with a severe penalty.
const COLLAPSE_PENALTY := 30
## Doc 01 §2.3 "stress shock" (owner 2026-11-11, DD-style): a hero's crit calms the party…
const CRIT_PARTY_RELIEF := 3
## …and an enemy's crit shakes the hero it hits.
const ENEMY_CRIT_STRESS := 10
## Enemies without a "crit" in enemies.json.
const ENEMY_BASE_CRIT := 5


static func roll_initiative(speed: int, _resolve_level: int = 0) -> int:
	var jitter: int = randi_range(-INITIATIVE_JITTER, INITIATIVE_JITTER)
	return speed + jitter


static func hit_chance(attacker_accuracy: int, skill_accuracy: int, target_dodge: int) -> float:
	# Small stats (0–20) mapped to a playable hit band; tune with docs.
	var p: float = 0.70 + float(attacker_accuracy + skill_accuracy - target_dodge) * 0.02
	return clampf(p, HIT_MIN, HIT_MAX)


static func roll_damage(skill: Dictionary) -> int:
	var mn: int = int(skill.get("damage_min", 1))
	var mx: int = int(skill.get("damage_max", mn))
	if mx < mn:
		mx = mn
	return randi_range(mn, mx)


## Doc 01 §2.3: critChance = attacker crit (base + skill + buffs) − target crit resist, capped.
static func crit_chance(attacker_crit: int, target_crit_resist: int = 0) -> float:
	return clampf(float(attacker_crit - target_crit_resist) / 100.0, 0.0, CRIT_CAP)


static func roll_crit(attacker_crit: int, target_crit_resist: int = 0) -> bool:
	return randf() < crit_chance(attacker_crit, target_crit_resist)


static func resolve_attack_damage(raw: int, crit: bool) -> int:
	if crit:
		return int(ceil(raw * CRIT_MULT))
	return raw


## Doc 01 §2.3 damage: raw × crit × (1 + atkMods) × (1 − protection) × element multiplier.
## atk_pct and prot_pct are percent points; prot is capped at 80. 0 damage stays 0 (aegis,
## immunity); anything that hits for more than 0 does at least 1.
static func final_damage(raw: int, atk_pct: int = 0, prot_pct: int = 0, elem_mult: float = 1.0, crit: bool = false) -> int:
	if raw <= 0:
		return 0
	var d: float = float(resolve_attack_damage(raw, crit))
	d *= 1.0 + atk_pct / 100.0
	d *= 1.0 - clampi(prot_pct, 0, 80) / 100.0
	d *= elem_mult
	if elem_mult <= 0.0:
		return 0
	return maxi(int(round(d)), 1)


## Doc 01 §2.4: chance 0-1 to survive a hit while Al Borde. Starts from the hero's
## "golpe_de_gracia" resist (67 base, Quebranto/Virtud mods, cap 87) and drops for each
## earlier roll this expedition (borde_checks), for high stress, and for a Colapso.
static func death_save_chance(hero: Dictionary, collapse: bool = false) -> float:
	var pts: int = int(round(StatusEffectsScript.deathblow_chance(hero) * 100.0))
	pts -= BORDE_CHECK_PENALTY * int(hero.get("borde_checks", 0))
	var stress: int = int(hero.get("stress", 0))
	var worst: int = 0
	for threshold in STRESS_PENALTY:
		if stress >= int(threshold):
			worst = maxi(worst, int(STRESS_PENALTY[threshold]))
	pts -= worst
	if collapse:
		pts -= COLLAPSE_PENALTY
	return clampi(pts, 0, 100) / 100.0


static func roll_death_save(chance: float = DEATH_SAVE_BASE) -> bool:
	return randf() < chance
