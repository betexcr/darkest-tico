extends RefCounted
class_name CombatResolver

## Pure rules aligned with docs/01-core-systems-spec.md (initiative, hit, damage, Al Borde).

const INITIATIVE_JITTER := 2
const HIT_MIN := 0.05
const HIT_MAX := 0.95
const DEATH_SAVE_BASE := 0.67


static func roll_initiative(speed: int, resolve_level: int = 0) -> int:
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


static func roll_crit(attacker_crit: int, _target_crit_resist: int) -> bool:
	var p: float = clampf(float(attacker_crit) / 100.0, 0.0, 0.5)
	return randf() < p


static func resolve_attack_damage(raw: int, crit: bool) -> int:
	if crit:
		return int(ceil(raw * 1.5))
	return raw


static func roll_death_save() -> bool:
	return randf() < DEATH_SAVE_BASE
