extends SceneTree

## Enemy engine for the Alpha rosters (P6-03, doc 05 §2-3): families and hero bonuses against
## them, large enemies that take two positions, phases at a PV threshold, mirror images
## (illusion punish, no drops, they fade when the real ones are gone).
##   godot --headless --path . -s tests/test_enemy_engine.gd

const FormationScript := preload("res://scripts/domain/formation.gd")

var _fail: int = 0
var gs
var cc


func _check(cond: bool, what: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + what)
	if not cond:
		_fail += 1


func _initialize() -> void:
	_run.call_deferred()


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
		h["stress"] = 0


func _run() -> void:
	await process_frame
	gs = root.get_node("GameState")
	gs.reset_party_from_catalog()
	gs.start_mission()

	print("Families")
	var all_have: bool = true
	for id in gs._enemies_by_id:
		all_have = all_have and gs.family_name(str(gs._enemies_by_id[id].get("family", ""))) != ""
	_check(all_have, "every enemy has a family with a Spanish name")
	_check(gs._enemies_by_id["rata_de_troje"]["family"] == "bestias" and gs._enemies_by_id["peon_penado"]["family"] == "penados", "families follow doc 05's table")
	_setup([gs.make_enemy("rata_de_troje", 1)])
	var rat: Dictionary = cc.enemies[0]
	var plain: int = cc._scaled_damage(10, gs.party[0], rat, {})
	var vs: int = cc._scaled_damage(10, gs.party[0], rat, {"vs_family": {"bestias": 50}})
	var other: int = cc._scaled_damage(10, gs.party[0], rat, {"vs_family": {"espantos": 50}})
	_check(vs == plain + 5 and other == plain, "vs_family: +50%% only against its family (%d / %d / %d)" % [plain, vs, other])

	print("Large enemies (size 2)")
	var big: Dictionary = gs.make_enemy("peon_penado", 1)
	big["size"] = 2
	var a: Dictionary = gs.make_enemy("espanto", 1)
	var b: Dictionary = gs.make_enemy("susurro_aljibe", 1)
	var side: Array = [a, big, b]
	_check(FormationScript.position_of(big, side) == 2 and FormationScript.positions_of(big, side) == [2, 3], "a large enemy in second place stands on positions 2 and 3")
	_check(FormationScript.position_of(b, side) == 4 and FormationScript.slots_used(side) == 4, "…so the next one is at 4 and the line is full")
	_check(FormationScript.at_positions(side, [3]) == [big], "a skill reaching position 3 can hit it")
	_check(FormationScript.at_positions(side, [4]) == [b], "position 4 is the one behind it")
	gs._enemies_by_id["peon_penado"]["size"] = 2
	var squad: Array = gs.expand_packs(["peon_penado", "peon_penado", "espanto"])
	_check(squad == ["peon_penado", "peon_penado"], "a squad fills 4 positions: two large enemies leave no room (%s)" % str(squad))
	_check(gs.expand_packs(["peon_penado", "rata_de_troje"]) == ["peon_penado", "rata_de_troje", "rata_de_troje"], "a large enemy and a pair of rats fit")
	_setup([gs.make_enemy("peon_penado", 1), gs.make_enemy("espanto", 1), gs.make_enemy("espanto", 1)])
	_check(cc.spawn_enemy("peon_penado").is_empty(), "no summon if it doesn't fit")
	gs._enemies_by_id["peon_penado"].erase("size")

	print("Phases")
	var boss: Dictionary = gs.make_enemy("mayordomo_hundido", 0)
	boss["phases"] = [{"at_hp_pct": 50, "text": "La niebla se espesa.", "prot": 20,
		"self_applies": {"status": "chiva", "turns": 3, "mods": {"dmg_pct": 10}},
		"clones": {"count": 2, "hp_pct": 10, "stress_on_hit": 6}}]
	_setup([boss])
	var prot0: int = int(boss.get("prot", 0))
	cc._apply_damage_to_enemy(boss, int(boss["hp_max"] * 0.3))
	_check(cc.enemies.size() == 1, "above 50% nothing happens")
	cc._apply_damage_to_enemy(boss, int(boss["hp_max"] * 0.25))
	var clones: Array = cc.enemies.filter(func(e): return bool(e.get("illusion", false)))
	_check(clones.size() == 2 and int(boss["prot"]) == prot0 + 20 and gs.StatusEffectsScript.has(boss, "chiva"), "at 50%: two mirror images, more protection, Chiva")
	_check(clones.all(func(c): return int(c["hp_max"]) == maxi(1, int(round(boss["hp_max"] * 0.1))) and not c.has("phases") and str(c["name"]).contains("reflejo")), "mirror images: 10% PV, no phases, named as reflections")
	cc._apply_damage_to_enemy(boss, 1)
	_check(cc.enemies.size() == 3, "a phase triggers only once")

	print("Mirror images")
	var h: Dictionary = gs.party[0]
	var mirror: Dictionary = clones[0]
	var atk: Dictionary = {}
	for sid in h["skill_ids"]:
		var sk: Dictionary = gs.hero_skill(h, str(sid))
		if str(sk.get("kind", "")) == "attack":
			atk = sk
			break
	var st0: int = int(h.get("stress", 0))
	var hit: bool = false
	for _k in 20:
		mirror["dead"] = false
		mirror["hp"] = mirror["hp_max"]
		cc._resolve_hero_attack(h, atk, mirror)
		if bool(mirror.get("dead", false)):
			hit = true
			break
	_check(hit and int(h.get("stress", 0)) > st0, "hitting a mirror image stresses the hero (%d -> %d)" % [st0, int(h.get("stress", 0))])
	boss["dead"] = true
	boss["hp"] = 0
	mirror["dead"] = true
	var drops: Dictionary = gs.roll_drops([mirror])
	_check(drops.get("got", []).is_empty(), "mirror images drop nothing")
	cc._dispel_lone_illusions()
	_check(cc.enemies.all(func(e): return bool(e.get("dead", false))), "with the real one gone, the images fade")

	print("%d failure(s)" % _fail)
	quit(1 if _fail > 0 else 0)
