extends SceneTree

## Combat and stress rules on their own (P1-01): the combat resolver (hit band, crit cap and
## multiplier, damage floor and protection cap, the Al Borde death save) and the stress
## system (resolve check, Quebranto / Virtud and its reset, Colapso, the second Colapso's
## death roll). Every threshold is read from data/balance.json, never hard-coded.
##   godot --headless --path . -s tests/test_rules.gd

const CR := preload("res://scripts/domain/combat_resolver.gd")
const SS := preload("res://scripts/domain/stress_system.gd")
const BAL := preload("res://scripts/domain/balance.gd")

var _fail: int = 0


func _check(cond: bool, what: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + what)
	if not cond:
		_fail += 1


func _initialize() -> void:
	_run.call_deferred()


func _hero(stress: int = 0) -> Dictionary:
	return {"name": "Prueba", "hp": 20, "hp_max": 20, "stress": stress, "status_resist": {}}


func _run() -> void:
	await process_frame
	BAL.reset()
	var lo: float = BAL.num("combat.hit_min")
	var hi: float = BAL.num("combat.hit_max")
	var cap: float = BAL.num("combat.crit_cap")

	# --- Combat resolver ---------------------------------------------------------------
	_check(is_equal_approx(CR.hit_chance(0, 0, 0), BAL.num("combat.hit_base")), "even stats hit at combat.hit_base")
	_check(is_equal_approx(CR.hit_chance(1000, 0, 0), hi), "huge accuracy is clamped to combat.hit_max (%.2f)" % hi)
	_check(is_equal_approx(CR.hit_chance(0, 0, 1000), lo), "huge dodge is clamped to combat.hit_min (%.2f)" % lo)
	_check(CR.hit_chance(4, 0, 0) > CR.hit_chance(0, 0, 0) and CR.hit_chance(0, 4, 0) == CR.hit_chance(4, 0, 0), "skill accuracy counts like hero accuracy")
	_check(is_equal_approx(CR.crit_chance(1000), cap), "crit chance is capped at combat.crit_cap (%.2f)" % cap)
	_check(CR.crit_chance(5, 50) == 0.0, "crit resist above the crit floors at 0")
	_check(CR.resolve_attack_damage(10, true) == int(ceil(10 * BAL.num("combat.crit_mult"))), "a crit multiplies by combat.crit_mult, rounded up")
	_check(CR.final_damage(1, 0, 100) == 1, "anything that hits does at least 1")
	_check(CR.final_damage(0) == 0 and CR.final_damage(10, 0, 0, 0.0) == 0, "0 damage or an immune element stays 0")
	var pc: int = BAL.int_of("combat.prot_cap")
	_check(CR.final_damage(100, 0, 1000) == CR.final_damage(100, 0, pc), "protection is capped at combat.prot_cap (%d%%)" % pc)

	var base: float = CR.death_save_chance(_hero())
	_check(base > 0.0 and base < 1.0, "a fresh hero survives an Al Borde hit with some chance (%.0f%%)" % (base * 100))
	var h: Dictionary = _hero()
	h["borde_checks"] = 2
	_check(is_equal_approx(CR.death_save_chance(h), base - 2 * BAL.int_of("death.check_penalty") / 100.0), "each earlier roll this expedition costs death.check_penalty")
	var worst: int = 0
	var top: int = 0
	for pair in BAL.arr("death.stress_penalties"):
		if int(pair[0]) >= top:
			top = int(pair[0])
			worst = int(pair[1])
	_check(is_equal_approx(CR.death_save_chance(_hero(top)), base - worst / 100.0), "high stress (%d) costs its death.stress_penalties entry (%d)" % [top, worst])
	_check(is_equal_approx(CR.death_save_chance(_hero(), true), base - BAL.int_of("death.collapse_penalty") / 100.0), "a Colapso costs death.collapse_penalty")
	h["borde_checks"] = 100
	_check(CR.death_save_chance(h) == 0.0, "the chance never goes below 0")

	# --- Stress system -----------------------------------------------------------------
	var rt: int = BAL.int_of("stress.resolve_threshold")
	var col: int = BAL.int_of("stress.colapso")
	var s: Dictionary = _hero(10)
	SS.add_stress(s, -50)
	_check(int(s["stress"]) == 0, "relief never takes stress below 0")
	BAL.override("stress.quebranto_chance", 1.0)
	s = _hero(rt - 1)
	SS.add_stress(s, 1)
	_check(str(s.get("affliction_id", "")) != "" and str(s.get("virtud_id", "")) == "", "reaching resolve_threshold (%d) with quebranto_chance 1: a Quebranto" % rt)
	SS.add_stress(s, 5)
	_check(str(s.get("affliction_id", "")) != "" and int(s["stress"]) == rt + 5, "…only once: more stress just adds up")
	BAL.override("stress.quebranto_chance", 0.0)
	s = _hero(rt - 1)
	SS.add_stress(s, 1)
	_check(str(s.get("virtud_id", "")) != "" and int(s["stress"]) == BAL.int_of("stress.virtud_reset"), "with quebranto_chance 0: a Virtud, and stress resets to stress.virtud_reset (%d)" % BAL.int_of("stress.virtud_reset"))
	BAL.reset()

	s = _hero(col - 3)
	s["affliction_id"] = "nervios"
	SS.add_stress(s, 50)
	_check(int(s["stress"]) == col and bool(s.get("al_borde", false)) and int(s["hp"]) == 0 and not bool(s.get("dead", false)),
		"reaching colapso (%d): stress capped there, the hero drops to Al Borde at 0 PV" % col)
	var deaths: int = 0
	var survived: int = 0
	for k in 200:
		var t: Dictionary = _hero(col - 1)
		t["affliction_id"] = "nervios"
		t["al_borde"] = true
		t["collapsed_this_fight"] = true
		SS.add_stress(t, 5)
		if bool(t.get("dead", false)):
			deaths += 1
		elif int(t["stress"]) == BAL.int_of("stress.colapso_survive") and bool(t["al_borde"]):
			survived += 1
	_check(deaths + survived == 200 and deaths > 0, "a second Colapso in the same fight is a death roll (%d died, %d held on at stress.colapso_survive)" % [deaths, survived])

	print("%d failure(s)" % _fail)
	quit(1 if _fail > 0 else 0)
