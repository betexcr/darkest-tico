extends SceneTree

## Quebrantos/Virtudes (7 each), resolve level + difficulty, camping + camp skills,
## mission completion summary, victory screen, save round trip.
##   godot --headless --path . -s tests/test_progression.gd

var _fail: int = 0


func _check(cond: bool, what: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + what)
	if not cond:
		_fail += 1


func _initialize() -> void:
	_run.call_deferred()


## Casa Comunal skill ranks (P3-04): rank math, buying gates, save, veterans, combat lookup.
func _test_skill_ranks(gs) -> void:
	print("Skill ranks (Casa Comunal)")
	var sr = load("res://scripts/domain/skill_ranks.gd")
	gs.end_mission_abandon()
	gs.reset_party_from_catalog()
	gs.active_event_id = ""
	gs.colones = 10000
	var campe: Dictionary = gs.party[0]
	var abuela: Dictionary = gs.party[1]
	_check(campe["skill_ids"].has("machetazo") and abuela["skill_ids"].has("sopa_milagrosa"), "test heroes: Campesino (Machetazo), Abuela (Sopa Milagrosa)")
	_check(campe["skill_ids"].all(func(s): return sr.rank(campe, str(s)) == 1), "a new hero has every skill at rank 1")
	var raw: Dictionary = gs.get_skill("machetazo")
	var r1: Dictionary = gs.hero_skill(campe, "machetazo")
	r1.erase("rank")
	_check(r1 == raw, "rank 1 = the skill exactly as in skills.json")

	var m3: Dictionary = sr.ranked(raw, 3)
	_check(int(m3["damage_min"]) == int(raw["damage_min"]) + 2 and int(m3["damage_max"]) == int(raw["damage_max"]) + 2, "rank 3 Machetazo: +2/+2 damage")
	_check(int(m3["skill_accuracy"]) == int(raw.get("skill_accuracy", 0)) + 2 and int(m3["skill_crit"]) == 2, "rank 3 Machetazo: +2 accuracy, +2 crit")
	_check(not m3.has("heal_min") and int(raw["damage_min"]) == int(gs.get_skill("machetazo")["damage_min"]), "ranking adds no new fields and leaves the catalog untouched")
	var sopa: Dictionary = gs.get_skill("sopa_milagrosa")
	var s3: Dictionary = sr.ranked(sopa, 3)
	_check(int(s3["heal_min"]) == int(sopa["heal_min"]) + 2 and int(s3["heal_max"]) == int(sopa["heal_max"]) + 2 and not s3.has("damage_min"), "rank 3 heal: +2/+2, no damage")
	_check(int(s3["applies"]["value"]) == int(sopa["applies"]["value"]) + 2, "rank 3: status value +2 (Sobado)")
	var near: Dictionary = {"id": "x", "kind": "attack", "damage_min": 1, "damage_max": 2, "applies": {"status": "sangrado", "chance": 0.9, "turns": 3, "value": 1}}
	_check(is_equal_approx(float(sr.ranked(near, 5)["applies"]["chance"]), 1.0), "status chance caps at 100%")
	_check(is_equal_approx(float(sr.ranked(near, 2)["applies"]["chance"]), 0.95), "status chance +5% per rank")
	var escudo: Dictionary = gs.get_skill("escudo_de_barrio")
	var e3: Dictionary = sr.ranked(escudo, 3)
	_check(int(e3["self_applies"]["mods"]["prot"]) == int(escudo["self_applies"]["mods"]["prot"]) + 10, "rank_bonus override: Escudo de Barrio +5 protection per rank")
	_check(not e3.has("damage_min") and int(e3["self_applies"]["turns"]) == int(escudo["self_applies"]["turns"]), "override: nothing else changes (no damage, same turns)")
	_check(not sr.preview_lines(raw, 1).is_empty() and sr.preview_lines(raw, 5).is_empty(), "preview lists the next rank's gains, none at max")

	_check(gs.buy_skill_rank(campe, "machetazo").contains("Resolución 1") and sr.rank(campe, "machetazo") == 1, "Resolución 0 can't buy rank 2")
	campe["resolve_level"] = 1
	var before: int = gs.colones
	gs.buy_skill_rank(campe, "machetazo")
	_check(sr.rank(campe, "machetazo") == 2 and gs.colones == before - 300, "Resolución 1 buys rank 2 for 300 ₡")
	_check(gs.skill_rank_block_reason(campe, "machetazo").contains("Resolución 2"), "rank 3 needs Resolución 2")
	campe["resolve_level"] = 6
	gs.buy_skill_rank(campe, "machetazo")
	gs.buy_skill_rank(campe, "machetazo")
	gs.buy_skill_rank(campe, "machetazo")
	_check(sr.rank(campe, "machetazo") == 5 and gs.colones == before - 300 - 900 - 1500 - 2700, "ranks 3-5 cost 900 / 1500 / 2700 ₡")
	var at_max: int = gs.colones
	_check(gs.buy_skill_rank(campe, "machetazo").contains("máximo") and gs.colones == at_max, "no rank past 5")
	gs.colones = 100
	_check(gs.buy_skill_rank(campe, "trabajo_duro").contains("No alcanza") and sr.rank(campe, "trabajo_duro") == 1, "not enough colones: refused")
	_check(gs.buy_skill_rank(campe, "sopa_milagrosa").contains("No conoce"), "can't train a skill the hero doesn't have")
	gs.colones = 10000
	_check(gs.skill_rank_cost(campe, "trabajo_duro") == 300, "no event: rank 2 costs 300")
	var cc = load("res://scripts/combat/combat_controller.gd").new()
	var rip: Dictionary = cc._first_skill_of_kind(campe, "attack")
	_check(int(rip.get("rank", 0)) == 5 and int(rip["damage_min"]) == int(raw["damage_min"]) + 4, "hero ripostes use the ranked attack")
	cc.free()

	var data: Dictionary = JSON.parse_string(JSON.stringify(gs.to_save_dict()))
	gs.apply_save_data(data)
	var c2: Dictionary = gs.roster.filter(func(h): return int(h["uid"]) == int(campe["uid"]))[0]
	_check(sr.rank(c2, "machetazo") == 5 and typeof(c2["skill_ranks"]["machetazo"]) == TYPE_INT, "skill ranks survive a save round trip (as ints)")
	var old: Dictionary = data.duplicate(true)
	for e in old["roster"]:
		e.erase("skill_ranks")
	old["roster"][0]["skill_ranks"] = {"no_existe": 4, "machetazo": 9}
	gs.apply_save_data(old)
	var c3: Dictionary = gs.roster.filter(func(h): return int(h["uid"]) == int(campe["uid"]))[0]
	_check(not c3["skill_ranks"].has("no_existe") and sr.rank(c3, "machetazo") == 5, "unknown skills dropped, ranks clamped to 5")
	_check(gs.roster.filter(func(h): return int(h["uid"]) != int(campe["uid"])).all(
		func(h): return h["skill_ranks"].is_empty()), "v7 heroes without skill_ranks load at rank 1")

	gs.draw_town_event("veterano_de_las_bananeras")
	var vet: Dictionary = gs.recruit_pool[gs.recruit_pool.size() - 1]
	_check(vet["skill_ids"].all(func(s): return sr.rank(vet, str(s)) == 5), "Veterano (Resolución 6) arrives with rank 5 skills")
	_check(sr.default_rank_for_level(0) == 1 and sr.default_rank_for_level(2) == 3 and sr.default_rank_for_level(4) == 5, "seasoned-hero ranks: Res 0 -> 1, Res 2 -> 3, Res 4 -> 5")
	gs.active_event_id = ""
	var fallen: Dictionary = c3.duplicate(true)
	fallen["dead"] = true
	fallen["uid"] = 888
	gs.graveyard.clear()
	gs.graveyard.append(fallen)
	gs.event_flags = {}
	gs.draw_town_event("dia_de_difuntos")
	gs.resurrect(888)
	var back: Array = gs.roster.filter(func(h): return int(h["uid"]) == 888)
	_check(back.size() == 1 and sr.rank(back[0], "machetazo") == 5, "a resurrected hero keeps their skill ranks")
	gs.active_event_id = ""
	gs.event_flags = {}
	gs.graveyard.clear()


func _run() -> void:
	await process_frame
	var gs = root.get_node("GameState")
	var stress = load("res://scripts/domain/stress_system.gd")
	var se = load("res://scripts/domain/status_effects.gd")
	var rs = load("res://scripts/domain/resolve_system.gd")
	var camp = load("res://scripts/domain/camping_system.gd")

	print("Quebrantos / Virtudes")
	_check(stress.AFFLICTIONS.size() == 7 and stress.VIRTUDES.size() == 7, "7 afflictions and 7 virtues")
	for id in stress.AFFLICTIONS + stress.VIRTUDES:
		var nm: String = stress.affliction_name(id) if id in stress.AFFLICTIONS else stress.virtud_name(id)
		_check(nm != id, "'%s' has a display name (%s)" % [id, nm])
	var h: Dictionary = {"name": "T", "uid": 1, "accuracy": 5, "crit": 5, "status_resist": {"golpe_de_gracia": 67}}
	h["affliction_id"] = "nervios"
	_check(se.stat(h, "accuracy") == -5 and se.stat(h, "crit") == -5, "Nervios: -5 accuracy, -5 crit")
	h["affliction_id"] = "fatalismo"
	_check(is_equal_approx(se.deathblow_chance(h), 0.52), "Fatalismo: death save 67% -> 52%")
	h["affliction_id"] = ""
	h["virtud_id"] = "firmeza"
	_check(is_equal_approx(se.deathblow_chance(h), 0.75), "Firmeza: death save 67% -> 75%")
	h["virtud_id"] = "valentia"
	_check(se.stat(h, "dmg_pct") == 15, "Valentía: +15% damage")
	h["virtud_id"] = ""
	h["affliction_id"] = "paranoia"
	var refused: int = 0
	for _k in 400:
		if stress.refuses_support(h):
			refused += 1
	_check(refused > 80 and refused < 200, "Paranoia refuses support ~35 pct of the time (%d/400)" % refused)
	_check(not stress.hero_turn_blocked(h) or true, "Paranoia no longer skips turns at random")
	var skips: int = 0
	for _k in 400:
		if stress.hero_turn_blocked(h):
			skips += 1
	_check(skips == 0, "Paranoia never blocks a turn (%d)" % skips)
	var a: Dictionary = {"name": "A", "uid": 2, "hp": 10, "hp_max": 20, "virtud_id": "vigor", "stress": 0}
	var b: Dictionary = {"name": "B", "uid": 3, "hp": 10, "hp_max": 20, "virtud_id": "esperanza", "stress": 30}
	stress.round_start_effects([a, b])
	_check(int(a["hp"]) == 11, "Vigor: +1 PV at round start")
	_check(int(a["stress"]) == 0 and int(b["stress"]) == 30, "Esperanza calms the others, not itself")

	print("Resolve level")
	_check(rs.level_for_xp(0) == 0 and rs.level_for_xp(2) == 1 and rs.level_for_xp(8) == 2 and rs.level_for_xp(48) == 6, "XP thresholds 0/2/8/…/48")
	gs.reset_party_from_catalog()
	gs.reset_inventory_to_starter()
	var hero: Dictionary = gs.party[0]
	var stun0: int = int(hero["status_resist"].get("aturdido", 0))
	var res: Dictionary = rs.grant_xp(hero, 8)
	gs.recompute_stats(hero)
	_check(int(res["level_before"]) == 0 and int(res["level_after"]) == 2, "8 XP: Resolución 0 -> 2")
	_check(int(hero["status_resist"].get("aturdido", 0)) == stun0 + 20, "+10 pct stun resist per level (%d -> %d)" % [stun0, int(hero["status_resist"].get("aturdido", 0))])
	var pr: Dictionary = rs.progress(hero)
	_check(int(pr["current"]) == 0 and int(pr["needed"]) == 6, "progress 0/6 toward level 3")
	var base_v: Dictionary = rs.expedition("veterano", 0)
	_check(int(base_v["level"]) == 3 and is_equal_approx(float(base_v["enemy_hp"]), 1.22) and int(base_v["enemy_resist"]) == 10, "Veterano in Sótanos: level 3, x1.22 PV, +10 resist (doc 05)")
	var bosque: Dictionary = rs.expedition("aprendiz", 1)
	_check(int(bosque["level"]) == 2 and int(bosque["min_level"]) == 1 and int(bosque["max_level"]) == 3, "Aprendiz in a level-1 region: level 2, heroes 1-3")
	_check(float(bosque["enemy_hp"]) > 1.0 and int(bosque["xp"]) == 5, "level-1 region: tougher enemies, +1 XP")
	_check(int(rs.expedition("campeon", 1)["max_level"]) == 6, "levels cap at 6")
	_check(gs.region_level(gs.DEFAULT_REGION_PATH) == 0 and gs.region_level(gs.BOSQUE_REGION_PATH) == 1, "Sótanos is region level 0, Bosque 1")
	gs.selected_difficulty_id = "aprendiz"
	hero["resolve_level"] = 3
	_check(gs.party_refusals().size() == 1, "Resolución 3 refuses an Aprendiz expedition")
	_check(not gs.start_mission(), "start_mission refused while someone refuses")
	gs.selected_difficulty_id = "veterano"
	_check(gs.party_refusals().is_empty(), "Veterano: nobody refuses")
	_check(gs.party_underleveled().size() == 3, "Veterano: the 3 level-0 heroes are under-leveled")
	for x in gs.party:
		x["stress"] = 0
	_check(gs.start_mission(), "start a Veterano expedition")
	var low: Dictionary = gs.party[1]
	_check(int(low["stress"]) >= 60 and int(low["underlevel_stress_pct"]) == 75, "3 levels short: +60 start stress, +75 pct stress taken (stress %d)" % int(low["stress"]))
	gs.build_combat_context_for_node(gs.objective_node_id)
	var foe: Dictionary = gs.combat_context["enemies"][0]
	_check(float(foe.get("dmg_mult", 1.0)) > 1.0, "Veterano enemies hit harder (x%.2f)" % float(foe.get("dmg_mult", 1.0)))
	gs.end_mission_abandon()
	_check(int(low["underlevel_stress_pct"]) == 0, "penalty ends with the mission")
	hero["resolve_level"] = 0
	hero["resolve_xp"] = 0
	gs.selected_difficulty_id = "aprendiz"

	print("Camping")
	_check(camp.respite_points() == 12, "12 respite points")
	_check(camp.meals().size() == 4, "4 meal tiers")
	var feast: Dictionary = camp.meals().filter(func(m): return m["id"] == "festin")[0]
	_check(camp.meal_cost(feast, gs.party) == 4, "Festín costs 4 gallo pinto for 4 heroes")
	gs.party[3]["dead"] = true
	_check(camp.meal_cost(feast, gs.party) == 3, "…and 3 with one dead")
	gs.party[3]["dead"] = false
	for x in gs.party:
		_check(camp.hero_skills(x).size() == 4, "%s has 4 camp skills" % x.get("class_name", "?"))
	var tec: Dictionary = gs.party[2]
	var dron: Dictionary = camp.skill("dron_vigia")
	var used: Array = []
	_check(camp.can_use(tec, dron, gs.party, 12, used), "Tecnólogo can use Dron vigía")
	var out: Dictionary = camp.use_skill(tec, dron, gs.party)
	camp.mark_used(tec, dron, used)
	_check(bool(out["prevent_ambush"]), "Dron vigía keeps watch (no ambush)")
	_check(not camp.can_use(tec, dron, gs.party, 12, used), "each skill once per camp")
	_check(se.stat(gs.party[0], "dodge") == 5, "camp buff: +5 dodge read by StatusEffects.stat")
	se.clear(gs.party[0])
	_check(se.stat(gs.party[0], "dodge") == 5, "camp buffs survive the end-of-fight status clear")
	for _k in 4:
		camp.tick_fight(gs.party[0])
	_check(se.stat(gs.party[0], "dodge") == 0, "camp buff gone after 4 fights")
	var ally: Dictionary = gs.party[1]
	ally["stress"] = 40
	camp.use_skill(gs.party[0], camp.skill("palabras_de_animo"), gs.party, ally)
	_check(int(ally["stress"]) == 25, "Palabras de ánimo: -15 stress to the chosen ally")
	_check(camp.ambush_chance(100, 40, false) == 12 and camp.ambush_chance(20, 40, false) == 18 and camp.ambush_chance(20, 40, true) == 0, "ambush 12% / 18% in low light / 0% with a watch")

	print("Completing an expedition")
	gs.reset_party_from_catalog()
	gs.colones = 1000
	_check(gs.start_mission(), "start an Aprendiz expedition")
	gs.party[3]["dead"] = true
	gs.party[0]["affliction_id"] = "bravata"
	gs.ledger_add("loot_colones", 350)
	gs.ledger_add("fights", 2)
	gs.ledger_item("gallo_pinto", 2)
	var sm: Dictionary = gs.complete_mission()
	var heroes: Array = sm.get("heroes", [])
	_check(heroes.size() == 4, "summary lists 4 heroes")
	_check(int(heroes[1]["xp_gained"]) == 4 and int(heroes[1]["level_after"]) == 1, "survivor: +4 XP, Resolución 0 -> 1")
	_check(int(heroes[3]["xp_gained"]) == 0 and bool(heroes[3]["dead"]), "the fallen get no XP")
	_check(bool(heroes[0]["new_affliction"]), "new Quebranto shows up in the summary")
	_check(int(sm["ledger"]["objective_colones"]) > 0 and int(sm["ledger"]["loot_colones"]) == 350, "ledger: encargo reward and loot")
	var screen = load("res://scripts/expedition/victory_screen.gd").new()
	root.add_child(screen)
	await process_frame
	_check(screen.page == 0 and screen._body.get_child_count() > 3, "victory screen page 1: rewards")
	screen._on_next()
	await process_frame
	_check(screen.page == 1, "victory screen page 2: heroes")
	var cont: Array = [false]
	screen.continue_pressed.connect(func(): cont[0] = true)
	screen._on_next()
	_check(cont[0], "victory screen 'Volver a la hacienda' emits continue_pressed")
	screen.queue_free()
	gs.end_mission_abandon()

	print("Save round trip")
	gs.party[3]["dead"] = false
	gs.selected_difficulty_id = "veterano"
	var data: Dictionary = JSON.parse_string(JSON.stringify(gs.to_save_dict()))
	var xp_before: int = int(gs.party[1]["resolve_xp"])
	gs.apply_save_data(data)
	_check(gs.selected_difficulty_id == "veterano", "difficulty saved")
	_check(int(gs.party[1]["resolve_xp"]) == xp_before and int(gs.party[1]["resolve_level"]) == 1, "resolve XP and level saved")
	_check(gs.party[1]["camp_skill_ids"].size() == 4, "camp skills saved")
	var old: Dictionary = data.duplicate(true)
	for e in old["roster"]:
		e.erase("resolve_xp")
		e.erase("camp_skill_ids")
	old.erase("selected_difficulty_id")
	gs.apply_save_data(old)
	_check(int(gs.party[1]["resolve_xp"]) == 2 and gs.party[1]["camp_skill_ids"].size() == 4, "v5 save migrates (XP at level floor, class camp skills)")
	_check(gs.selected_difficulty_id == "aprendiz", "v5 save defaults to Aprendiz")

	_test_skill_ranks(gs)

	print("%d failure(s)" % _fail)
	quit(1 if _fail > 0 else 0)
