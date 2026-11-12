extends RefCounted

## What PV damage does to a hero, in and out of combat (P1-16, doc 01 §2.4). Pure; no nodes.
## Protection, Guard and Santiguado are the combat controller's job; this is only the PV
## part: drop to 0 → Al Borde; a hit while Al Borde rolls Golpe de gracia and may kill.
## Owner 2026-11-12: traps and curios follow the same rule; hunger and fasting never kill.

const CombatResolverScript := preload("res://scripts/domain/combat_resolver.gd")


## Applies `dmg` to `hero`. `can_kill` false: the hero never drops below 1 PV (hunger,
## Ayuno, a risky drink). Returns log lines (Spanish, in-game).
static func take(hero: Dictionary, dmg: int, can_kill: bool = true) -> PackedStringArray:
	var logs: PackedStringArray = PackedStringArray()
	if hero.get("dead", false) or dmg <= 0:
		return logs
	var hp: int = int(hero.get("hp", 0))
	var nh: int = hp - dmg
	if not can_kill:
		hero["hp"] = maxi(nh, mini(hp, 1))
		return logs
	if nh > 0:
		hero["hp"] = nh
		return logs
	if not hero.get("al_borde", false):
		hero["al_borde"] = true
		hero["hp"] = 0
		logs.append("%s está Al Borde!" % hero.get("name", "?"))
		return logs
	# Doc 01 §2.4: odds drop with each earlier roll this expedition and with high stress.
	var chance: float = CombatResolverScript.death_save_chance(hero)
	hero["borde_checks"] = int(hero.get("borde_checks", 0)) + 1
	if CombatResolverScript.roll_death_save(chance):
		# Owner 2026-11-11: surviving keeps them Al Borde at 0 PV; only healing gets them out.
		logs.append("%s resiste Al Borde (%d%%)." % [hero.get("name", "?"), int(round(chance * 100))])
		hero["hp"] = 0
	else:
		hero["dead"] = true
		hero["hp"] = 0
		logs.append("%s ha caído." % hero.get("name", "?"))
	return logs
