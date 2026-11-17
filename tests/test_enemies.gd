extends SceneTree

## Sótanos enemy gimmicks (P2-04, doc 05 §2.6): pairs of rats, authored squads, Embargado,
## Rencor, riposte when marked, the Monaguillo's blessing, the Vigía's reinforcements, the
## Murciélago's light drain and the Duende's stolen colones. Bosses (P2-05, doc 05 §3): the
## Mayordomo's summons, darkness beat and anti-guard; the Cadejo as a roaming mini-boss.
##   godot --headless --path . -s tests/test_enemies.gd

var _fail: int = 0


func _check(cond: bool, what: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + what)
	if not cond:
		_fail += 1


func _initialize() -> void:
	_run.call_deferred()


## Stand-in for BattleUnit (as in tests/test_expedition_systems.gd).
class StubUnit extends RefCounted:
	const COLOR_STRESS := Color.WHITE
	var data: Dictionary

	func _init(d: Dictionary) -> void:
		data = d

	func play_action(_k: String = "") -> void:
		pass

	func play_hurt(_a: int = 0, _c: bool = false) -> void:
		pass

	func play_death(_a: int = 0, _c: bool = false) -> void:
		pass

	func play_heal(_a: int = 0, _s: int = 0) -> void:
		pass

	func float_text(_t: String = "", _c: Color = Color.WHITE) -> void:
		pass

	func refresh() -> void:
		pass

	func set_active(_on: bool = false) -> void:
		pass

	func set_targeted(_on: bool = false) -> void:
		pass

	func is_dead() -> bool:
		return bool(data.get("dead", false))

	func get_parent():
		return null


var gs
var se
var cc


func _run() -> void:
	await process_frame
	gs = root.get_node("GameState")
	se = load("res://scripts/domain/status_effects.gd")
	gs.reset_party_from_catalog()
	gs.start_mission()
	_test_squads()
	_test_embargado()
	_test_grudge()
	_test_riposte()
	await _test_monaguillo()
	_test_reinforcements()
	await _test_light_and_theft()
	await _test_stage_spawn()
	_test_mayordomo()
	await _test_cadejo()
	load("res://scripts/domain/balance.gd").reset()
	print("%d failure(s)" % _fail)
	quit(1 if _fail > 0 else 0)


## A controller with the current party and `foes` on the stage (no fight running).
func _setup(foes: Array) -> void:
	if cc != null:
		cc.queue_free()
	cc = load("res://scripts/combat/combat_controller.gd").new()
	cc.instant = true
	root.add_child(cc)
	cc.party = gs.party
	cc.enemies = foes
	cc.hero_units = gs.party.map(func(h): return StubUnit.new(h))
	cc.enemy_units = foes.map(func(e): return StubUnit.new(e))
	cc.enemy_spawner = func(e: Dictionary): return StubUnit.new(e)
	for h in gs.party:
		h["hp"] = h["hp_max"]
		h["dead"] = false
		h["statuses"] = {}


func _test_squads() -> void:
	print("Squads")
	_check(gs.expand_packs(["rata_de_troje"]) == ["rata_de_troje", "rata_de_troje"], "one rat brings its pair")
	_check(gs.expand_packs(["peon_penado", "vigia_porton", "monaguillo_porton", "rata_de_troje"]).size() == 4, "no pair when the squad is full")
	_check(gs.expand_packs(["rata_de_troje", "rata_de_troje", "espanto"]).count("rata_de_troje") == 2, "a pair already there stays a pair")
	var e: Dictionary = gs.make_enemy("peon_penado", 1)
	_check(int(e["hp_max"]) > 0 and int(e["hp"]) == int(e["hp_max"]) and not e["dead"], "make_enemy: a fresh Peón (%d PV)" % int(e["hp_max"]))
	_check(gs.make_enemy("no_existe", 1).is_empty(), "make_enemy: unknown id -> {}")
	var r: Dictionary = gs.ExpeditionLoaderScript.load_region(gs.DEFAULT_REGION_PATH)
	var squads: Array = r["generator"]["squads"]
	var used: Dictionary = {}
	for seed in 40:
		var g: Dictionary = gs.MapGeneratorScript.generate(r.duplicate(true), seed)
		for nd in g["nodes"]:
			if str(nd.get("type", "")) == "combat" and not nd.get("is_elite", false) and squads.has(nd.get("enemy_ids", [])):
				used[str(nd["enemy_ids"])] = true
	_check(used.size() >= 3, "the generator uses the authored squads (%d of %d seen in 40 maps)" % [used.size(), squads.size()])


func _test_embargado() -> void:
	print("Embargado (Mandador en pena)")
	_setup([gs.make_enemy("mandador_en_pena", 1)])
	var h: Dictionary = gs.party[0]
	h["hp"] = 5
	se.apply(h, "embargado", 3, 0)
	_check(not cc._heal(h, 10) and int(h["hp"]) == 5, "a heal does nothing to an Embargado hero")
	gs.ItemEffectsScript.apply_to_hero({"effects": {"heal": 10}}, h)
	_check(int(h["hp"]) == 5, "healing items don't work either")
	se.remove(h, "embargado")
	_check(cc._heal(h, 10) and int(h["hp"]) == 15, "without it the heal works")
	var emb: Array = gs.make_enemy("mandador_en_pena", 1)["skills"].filter(func(s): return str(s.get("applies", {}).get("status", "")) == "embargado")
	_check(emb.size() == 1, "the Mandador has Embargo")


func _test_grudge() -> void:
	print("Rencor (Peón penado)")
	var peon: Dictionary = gs.make_enemy("peon_penado", 1)
	_setup([peon])
	var healer: Dictionary = gs.party[1]
	var other: Dictionary = gs.party[0]
	for _k in 5:
		cc._on_hero_healed(healer)
	_check(int(peon["grudge_stacks"]) == int(peon["grudge"]["max"]) and int(peon["grudge_uid"]) == int(healer["uid"]), "every heal adds a stack, up to %d" % int(peon["grudge"]["max"]))
	var basic: Dictionary = peon["skills"][0]
	var vs_healer: int = cc._scaled_damage(20, peon, healer, basic)
	var vs_other: int = cc._scaled_damage(20, peon, other, basic)
	_check(vs_healer > vs_other and vs_other == 20, "more damage against the healer (%d vs %d)" % [vs_healer, vs_other])
	cc._on_hero_healed(other)
	_check(int(peon["grudge_uid"]) == int(other["uid"]) and int(peon["grudge_stacks"]) == 1, "a new healer resets the grudge onto them")


func _test_riposte() -> void:
	print("Sombra de cuadrilla: riposte when marked")
	var sombra: Dictionary = gs.make_enemy("sombra_cuadrilla", 1)
	_setup([sombra])
	var h: Dictionary = gs.party[0]
	var hp0: int = int(h["hp"])
	cc._enemy_riposte(sombra, h)
	_check(int(h["hp"]) == hp0, "unmarked: no riposte")
	se.apply(sombra, "fichado", 3, 0)
	cc._enemy_riposte(sombra, h)
	_check(int(h["hp"]) < hp0, "marked: it hits back (%d -> %d)" % [hp0, int(h["hp"])])


func _test_monaguillo() -> void:
	print("Monaguillo: Bendición torcida")
	var peon: Dictionary = gs.make_enemy("peon_penado", 3)
	var vigia: Dictionary = gs.make_enemy("vigia_porton", 3)
	var mona: Dictionary = gs.make_enemy("monaguillo_porton", 3)
	_setup([peon, vigia, mona])
	var bless: Dictionary = mona["skills"].filter(func(s): return str(s.get("target", "")) == "allies")[0]
	var t: Array = cc._ally_targets(mona, bless)
	_check(t.size() == 2 and t.has(peon) and t.has(vigia), "it blesses the two in front")
	await cc._enemy_support(mona, bless)
	_check(se.has(peon, "chiva") and se.has(vigia, "chiva") and not se.has(mona, "chiva"), "both get Chiva, not the Monaguillo")
	_check(cc._ally_targets(mona, bless).is_empty(), "no second blessing while they still have it")
	var picks: Dictionary = {}
	for _k in 60:
		picks[str(cc._pick_enemy_skill(mona).get("id", ""))] = true
	_check(not picks.has(str(bless["id"])), "the AI doesn't pick the blessing when nobody needs it")


func _test_reinforcements() -> void:
	print("Vigía del Portón: reinforcements")
	var vigia: Dictionary = gs.make_enemy("vigia_porton", 2)
	var rata: Dictionary = gs.make_enemy("rata_de_troje", 2)
	_setup([rata, vigia])
	cc._round = 2
	cc._call_reinforcements()
	_check(cc.enemies.size() == 2, "round 2: no help yet")
	cc._round = 3
	cc._call_reinforcements()
	var newcomer: Dictionary = cc.enemies.back()
	_check(cc.enemies.size() == 3, "round 3 with the Vigía alive: one enemy joins")
	_check(vigia["reinforce"]["ids"].has(str(newcomer["id"])) and int(newcomer["hp"]) > 0, "it is one of the Vigía's (%s)" % newcomer.get("name", "?"))
	var aligned: bool = cc.enemy_units.size() == cc.enemies.size()
	for k in cc.enemies.size():
		aligned = aligned and is_same(cc.enemy_units[k].data, cc.enemies[k])
	_check(aligned, "enemy units stay lined up with the enemies")
	cc._round = 4
	cc._call_reinforcements()
	_check(cc.enemies.size() == 3, "only once per Vigía")
	var v2: Dictionary = gs.make_enemy("vigia_porton", 4)
	_setup([gs.make_enemy("peon_penado", 4), gs.make_enemy("peon_penado", 4), gs.make_enemy("rata_de_troje", 4), v2])
	cc._round = 3
	cc._call_reinforcements()
	_check(cc.enemies.size() == 4, "a full side gets no help")
	var v3: Dictionary = gs.make_enemy("vigia_porton", 1)
	v3["dead"] = true
	_setup([gs.make_enemy("espanto", 1), v3])
	cc._round = 3
	cc._call_reinforcements()
	_check(cc.enemies.size() == 2, "a dead Vigía calls nobody")


func _test_light_and_theft() -> void:
	print("Murciélago and Duende")
	var bal = load("res://scripts/domain/balance.gd")
	bal.override("combat.hit_min", 1.0)
	bal.override("combat.hit_max", 1.0)
	var bat: Dictionary = gs.make_enemy("murcielago_bodega", 1)
	bat["skills"] = bat["skills"].filter(func(s): return bool(s.get("basic", false)))
	_setup([bat])
	gs.mission_light = 80
	await cc._enemy_turn(bat)
	_check(gs.mission_light == 80 + int(bat["on_hit_light"]), "a bat bite takes %d Luz (80 -> %d)" % [int(bat["on_hit_light"]), gs.mission_light])
	bal.reset()
	gs.mission_light = 100
	var duende: Dictionary = gs.make_enemy("duende_sotano", 1)
	_setup([duende])
	gs.colones = 500
	duende["skills"] = duende["skills"].filter(func(s): return int(s.get("steal_colones", 0)) > 0)
	bal.override("combat.hit_min", 1.0)
	bal.override("combat.hit_max", 1.0)
	await cc._enemy_turn(duende)
	bal.reset()
	var stolen: int = int(duende.get("stolen", 0))
	_check(stolen > 0 and gs.colones == 500 - stolen, "the Duende steals %d colones" % stolen)
	cc._apply_damage_to_enemy(duende, 999)
	_check(gs.colones == 500 and int(duende.get("stolen", 0)) == 0, "killing it gets them back")
	cc.queue_free()
	cc = null


## On the real expedition screen, a reinforcement gets its own unit in the enemy row.
func _test_stage_spawn() -> void:
	print("Reinforcements on the stage")
	gs.reset_party_from_catalog()
	gs.start_mission()
	var node_id: String = ""
	for id in gs.mission_nodes_index:
		if str(gs.mission_nodes_index[id].get("type", "")) == "combat":
			node_id = str(id)
			break
	var nd: Dictionary = gs.mission_nodes_index[node_id]
	nd["enemy_ids"] = ["vigia_porton", "espanto"]
	nd.erase("is_elite")
	nd.erase("is_boss")
	var screen = load("res://scenes/expedition/expedition_screen.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	screen._start_combat(node_id)
	var combat = screen._combat
	var rows0: int = screen._enemy_row.get_child_count()
	combat._round = 3
	combat._call_reinforcements()
	await process_frame
	_check(screen._enemy_row.get_child_count() == rows0 + 1 and screen._enemy_units.size() == combat.enemies.size(), "the newcomer has a unit in the enemy row (%d -> %d)" % [rows0, screen._enemy_row.get_child_count()])
	var ok: bool = true
	for k in combat.enemies.size():
		ok = ok and is_same(screen._enemy_units[k].data, combat.enemies[k]) and screen._enemy_units[k].get_index() == combat.enemies.size() - 1 - k
	_check(ok, "stage row order matches the formation")
	combat._ended = true
	screen.queue_free()
	for i in 5:
		await process_frame


func _test_mayordomo() -> void:
	print("El Mayordomo Hundido (P2-05)")
	var gen: Dictionary = gs.ExpeditionLoaderScript.load_region(gs.DEFAULT_REGION_PATH)["generator"]
	_check(str(gen["boss_enemy_id"]) == "mayordomo_hundido", "the Mayordomo is the Sótanos boss (last room)")
	var boss: Dictionary = gs.make_enemy("mayordomo_hundido", 0)
	_setup([boss])
	# Summons: every 3 rounds from round 4, while fewer than 2 servants stand, at most 2 per fight.
	var sm: Dictionary = boss["summon"]
	var counts: Array = []
	for r in range(1, 9):
		cc._round = r
		cc._boss_round_start()
		counts.append(cc.enemies.filter(func(e): return str(e["id"]) == "sirviente_ahogado" and not e["dead"]).size())
	_check(counts == [0, 0, 0, 1, 1, 1, 2, 2], "servants arrive on rounds 4 and 7 (%s)" % str(counts))
	for e in cc.enemies:
		if str(e["id"]) == "sirviente_ahogado":
			e["dead"] = true
	for r in range(9, 20):
		cc._round = r
		cc._boss_round_start()
	_check(int(boss.get("summoned", 0)) == int(sm["max_total"]) and cc.enemies.filter(func(e): return not e["dead"] and str(e["id"]) == "sirviente_ahogado").is_empty(),
		"no more than %d per fight: killing them ends it" % int(sm["max_total"]))
	# Darkness beat: every 3rd round the pulse, whatever the dice say.
	var beat: bool = true
	for r in [4, 8, 12]:
		cc._round = r
		for _k in 10:
			beat = beat and str(cc._pick_enemy_skill(boss).get("id", "")) == "pulso_de_oscuridad"
	_check(beat, "rounds 4, 8, 12: always Pulso de oscuridad")
	cc._round = 5
	var other: bool = false
	for _k in 40:
		other = other or str(cc._pick_enemy_skill(boss).get("id", "")) != "pulso_de_oscuridad"
	_check(other, "other rounds: the usual mix")
	# Anti-guard: more damage against a guarding hero.
	var golpe: Dictionary = boss["skills"].filter(func(x): return str(x["id"]) == "golpe_al_escudo")[0]
	var h: Dictionary = gs.party[0]
	h["guarding"] = false
	var plain: int = cc._scaled_damage(20, boss, h, golpe)
	h["guarding"] = true
	var vs_guard: int = cc._scaled_damage(20, boss, h, golpe)
	h["guarding"] = false
	_check(vs_guard == 30 and plain == 20, "Golpe al escudo: +50%% against a guarding hero (%d vs %d)" % [vs_guard, plain])


func _test_cadejo() -> void:
	print("Cadejo Negro, roaming mini-boss (P2-05)")
	gs.reset_party_from_catalog()
	var gen: Dictionary = gs.ExpeditionLoaderScript.load_region(gs.DEFAULT_REGION_PATH)["generator"]
	_check(not gen["elite_pool"].has("cadejo_negro"), "the Cadejo is no longer a plain elite")
	gs.selected_difficulty_id = "aprendiz"
	var seen: int = 0
	for _k in 20:
		gs.start_mission()
		seen += 1 if not gs.mission_roaming.is_empty() else 0
	_check(seen == 0, "never in an Aprendiz expedition")
	gs.selected_difficulty_id = "campeon"
	seen = 0
	for _k in 40:
		gs.start_mission()
		if not gs.mission_roaming.is_empty():
			seen += 1
	_check(seen > 10 and seen < 40, "sometimes in a Campeón expedition (%d of 40)" % seen)
	while gs.mission_roaming.is_empty():
		gs.start_mission()
	var room: String = gs.roaming_node()
	var nd: Dictionary = gs.mission_nodes_index[room]
	_check(["combat", "empty", "curio", "trap"].has(str(nd["type"])) and room != gs.current_node_id and not gs.mission_neighbors().has(room), "it waits in a fight, empty, curio or trap room away from the entrance (%s, %s)" % [room, nd["type"]])
	# It prowls: every move_every party moves it changes room, never into the party's.
	var ok_rooms: Array = gs._roaming_rooms()
	var from: String = ""
	for id in ok_rooms:
		var nb: Array = gs.ExpeditionLoaderScript.neighbors(gs.mission_region_data, str(id)).filter(func(n): return ok_rooms.has(str(n)))
		if nb.size() >= 2:
			from = str(id)
			break
	if from != "":
		var every: int = int(gen["roaming"]["move_every"])
		gs.mission_roaming = {"node": from, "moves": 0}
		gs.current_node_id = str(gs.ExpeditionLoaderScript.neighbors(gs.mission_region_data, from).filter(func(n): return ok_rooms.has(str(n)))[0])
		for _k in every - 1:
			gs.roaming_tick()
		_check(gs.roaming_node() == from, "it stays put for %d moves" % (every - 1))
		gs.roaming_tick()
		var now: String = gs.roaming_node()
		_check(now != from and ok_rooms.has(now) and now != gs.current_node_id, "then it moves to another room, not the party's (%s -> %s)" % [from, now])
	else:
		_check(true, "(no room with two roaming neighbours on this map; movement not tested)")
	gs.current_node_id = str(gs.mission_region_data["start_node"])
	gs.mission_roaming = {"node": room, "moves": 0}
	# Meeting it: an elite fight led by the Cadejo with its rats; the room reward is 0.
	gs.current_node_id = gs.roaming_node()
	_check(gs.roaming_here(), "walking into its room meets it")
	var room_before: Dictionary = gs.mission_nodes_index[gs.current_node_id].duplicate(true)
	gs.build_roaming_context(gs.current_node_id)
	var ids: Array = gs.combat_context["enemies"].map(func(e): return str(e["id"]))
	_check(ids.has("cadejo_negro") and ids.count("rata_de_troje") == 2 and bool(gs.combat_context["is_roaming"]), "the fight: Cadejo + a pair of rats (%s)" % str(ids))
	_check(gs.mission_nodes_index[gs.current_node_id] == room_before, "the room's own data is left as it was")
	# It flees after 4 rounds.
	var cad: Dictionary = gs.combat_context["enemies"].filter(func(e): return str(e["id"]) == "cadejo_negro")[0]
	_setup(gs.combat_context["enemies"])
	for r in range(1, 6):
		cc._round = r
		cc._boss_round_start()
		if r == 4:
			_check(not cad["dead"], "still there at round 4")
	_check(cad["dead"] and bool(cad.get("fled", false)), "round 5: it has fled")
	# Bounty only if killed; either way it is gone.
	var c0: int = gs.colones
	gs.finish_roaming(false)
	_check(gs.colones == c0 and gs.mission_roaming.is_empty(), "fled: no bounty, gone for the expedition")
	gs.mission_roaming = {"node": gs.current_node_id, "moves": 0}
	gs.inventory.clear()
	gs.finish_roaming(true)
	var b: Array = gen["roaming"]["bounty_colones"]
	_check(gs.colones - c0 >= int(b[0]) and gs.inventory.any(func(e): return gs.is_equipment(str(e["id"]))), "killed: a bounty (+%d ₡) and a piece of equipment" % (gs.colones - c0))
	# On the real screen: entering its room starts the fight; winning pays the bounty.
	gs.mission_roaming = {"node": gs.current_node_id, "moves": 0}
	var screen = load("res://scenes/expedition/expedition_screen.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	screen._resolve_room()
	_check(int(screen._mode) == 2 and bool(gs.combat_context.get("is_roaming", false)), "the screen opens the Cadejo fight")
	screen._combat._ended = true
	for e in screen._combat.enemies:
		e["dead"] = true
	var c1: int = gs.colones
	await screen._on_combat_over(true)
	_check(gs.colones > c1 and gs.mission_roaming.is_empty() and gs.is_node_cleared(gs.current_node_id) == gs.roaming_clears_room(gs.current_node_id), "after the win: bounty paid, Cadejo gone; the room is cleared only if it was a fight or empty")
	screen.queue_free()
	for i in 5:
		await process_frame
	gs.end_mission_abandon()
	gs.selected_difficulty_id = "aprendiz"
	if cc != null:
		cc.queue_free()
		cc = null
