extends SceneTree

## Status effects (data/statuses.json, scripts/domain/status_effects.gd) and how combat uses them.
##   godot --headless --path . -s tests/test_status.gd

var _fail: int = 0


func _check(cond: bool, what: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + what)
	if not cond:
		_fail += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var se = load("res://scripts/domain/status_effects.gd")
	var ie = load("res://scripts/domain/item_effects.gd")

	# --- Damage over time: sangrado / veneno, stacking, crit duration ---
	var u := {"name": "T", "hp": 20}
	se.apply(u, "sangrado", 2, 3)
	var t1: Dictionary = se.tick(u)
	_check(int(t1["damage"]) == 3 and not t1["skip"], "bleed deals 3 on tick 1")
	var t2: Dictionary = se.tick(u)
	_check(int(t2["damage"]) == 3 and not se.has(u, "sangrado"), "bleed deals 3 on tick 2, then wears off")
	se.apply(u, "sangrado", 3, 2)
	se.apply(u, "sangrado", 1, 1)
	_check(se.stack_count(u, "sangrado") == 2 and se.total_value(u, "sangrado") == 3, "bleed stacks add up (2+1)")
	se.tick(u)
	_check(se.stack_count(u, "sangrado") == 1, "each bleed stack expires on its own")
	se.clear(u)
	se.apply(u, "veneno", 3, 2, {"crit": true})
	_check(se.turns_left(u, "veneno") == 5, "blight from a crit lasts 5 turns")
	se.clear(u)
	se.apply(u, "veneno", 0, 1)
	_check(se.turns_left(u, "veneno") == 3, "default duration is 3 turns")

	# --- Sobado heals before bleeding; susto adds stress (heroes only) ---
	se.clear(u)
	var h := {"name": "H", "hp": 10, "stress": 0}
	se.apply(h, "sobado", 3, 4)
	se.apply(h, "sangrado", 3, 2)
	se.apply(h, "susto", 3, 5)
	var tk: Dictionary = se.tick(h)
	_check(int(tk["heal"]) == 4 and int(tk["damage"]) == 2 and int(tk["stress"]) == 5, "sobado +4, sangrado -2, susto +5 stress")
	_check(String(tk["logs"][0]).contains("sobado"), "restoration is listed before the bleed")
	var e := {"name": "E", "hp": 10}
	se.apply(e, "susto", 3, 5)
	_check(int(se.tick(e)["stress"]) == 0, "susto does nothing to enemies (no stress)")

	# --- Atarantado (stun) then Espabilado (stun resist) ---
	var s := {"name": "S", "hp": 10}
	se.apply(s, "aturdido", 1, 0)
	_check(bool(se.tick(s)["skip"]) and not se.has(s, "aturdido"), "stun skips one turn")
	_check(se.has(s, "espabilado") and se.resist_chance(s, "aturdido") == 50, "after a stun: Espabilado, +50% stun resist")
	se.apply(s, "aturdido", 1, 0, {"ignore_resist": true})
	se.tick(s)
	_check(se.resist_chance(s, "aturdido") == 100, "stunned again: resist stacks to 100%")
	se.tick(s)
	_check(not se.has(s, "espabilado"), "Espabilado drops at the start of a normal turn")
	var boss := {"name": "B", "hp": 50, "status_resist": {"aturdido": 100}}
	_check(se.apply(boss, "aturdido", 1, 0).contains("resiste"), "status_resist 100 always resists")
	var marked := {"name": "M", "hp": 5, "status_resist": {"fichado": 100}}
	se.apply(marked, "fichado", 3, 0)
	_check(se.has(marked, "fichado"), "marks can't be resisted")

	# --- Salado / Chiva stat changes, Encarrerado, Al Borde / Convaleciente ---
	var b := {"name": "B", "hp": 10}
	se.apply(b, "salado", 3, 0, {"mods": {"accuracy": -5, "dmg_pct": -15}})
	se.apply(b, "chiva", 3, 0, {"mods": {"accuracy": 8}})
	_check(se.stat(b, "accuracy") == 3 and se.stat(b, "dmg_pct") == -15, "salado and chiva add up on stats")
	se.apply(b, "encarrerado", 2, 0)
	_check(se.stat(b, "dmg_pct") == 0 and se.stat(b, "crit") == 5, "crit buff: +15% damage, +5 crit")
	var dd := {"name": "D", "hp": 0, "al_borde": true}
	_check(se.stat(dd, "accuracy") == -10 and se.stat(dd, "stress_pct") == 33, "Al Borde: -10 accuracy, +33% stress")
	dd["al_borde"] = false
	dd["convaleciente"] = true
	_check(se.stat(dd, "speed") == -1, "Convaleciente: -1 speed")

	# --- Agazapado (stealth) and Fichado (mark) targeting ---
	var a1 := {"name": "a1", "hp": 5}
	var a2 := {"name": "a2", "hp": 5}
	se.apply(a1, "agazapado", 2, 0)
	_check(se.targetable([a1, a2]) == [a2], "hidden units can't be picked while others are left")
	a2["dead"] = true
	_check(se.targetable([a1, a2]) == [a1], "...but can when they are the only ones left")
	var m1 := {"name": "m1", "hp": 5}
	var m2 := {"name": "m2", "hp": 5}
	se.apply(m2, "fichado", 3, 0)
	var hits: int = 0
	for i in 200:
		if se.pick_target([m1, m2]) == m2:
			hits += 1
	_check(hits > 140, "marked units are picked most of the time (%d/200)" % hits)

	# --- Santiguado (aegis) ---
	var g := {"name": "G", "hp": 10}
	se.apply(g, "santiguado", 0, 1)
	se.apply(g, "santiguado", 0, 5)
	_check(se.total_value(g, "santiguado") == 2, "aegis blocks stack up to 2")
	_check(se.use_aegis(g) and se.use_aegis(g) and not se.use_aegis(g), "each block stops one hit")

	# --- Cures (items) ---
	var c := {"name": "C", "hp": 10, "hp_max": 20, "stress": 30}
	se.apply(c, "sangrado", 3, 2)
	ie.apply_to_hero({"effects": {"heal": 1, "cure": ["sangrado"]}}, c)
	_check(not se.has(c, "sangrado"), "venda-style cure removes bleeding")
	se.apply(c, "susto", 3, 3)
	ie.apply_to_hero(GameStateLike.item("te_de_tilo"), c)
	_check(not se.has(c, "susto"), "té de tilo removes susto")
	var dirty := {"name": "D", "hp": 10, "hp_max": 20, "stress": 40}
	for st in ["sangrado", "veneno", "salado", "fichado", "susto"]:
		se.apply(dirty, st, 3, 1, {"ignore_resist": true})
	se.apply(dirty, "aturdido", 1, 0, {"ignore_resist": true})
	se.apply(dirty, "chiva", 3, 0, {"mods": {"dodge": 5}})
	ie.apply_to_hero(GameStateLike.item("agua_de_la_negrita"), dirty)
	_check(not se.any(dirty) and se.has(dirty, "chiva"), "agua de la Negrita removes ALL debuffs and keeps buffs")
	se.apply(dirty, "fichado", 3, 0)
	se.apply(dirty, "salado", 3, 0, {"ignore_resist": true})
	ie.apply_to_hero(GameStateLike.item("sal_gruesa"), dirty)
	_check(not se.has(dirty, "fichado") and not se.has(dirty, "salado"), "sal gruesa removes Salado and Fichado")
	ie.apply_to_hero(GameStateLike.item("chilero_casero"), dirty)
	_check(se.has(dirty, "respondon"), "chilero casero makes the hero Respondón")
	var ab := {"name": "AB", "hp": 0, "hp_max": 20, "al_borde": true}
	ie.apply_to_hero({"effects": {"heal": 5}}, ab)
	_check(not ab["al_borde"] and ab.get("convaleciente", false), "healed out of Al Borde -> Convaleciente")

	# --- Combat rules ---
	var cc = load("res://scripts/combat/combat_controller.gd").new()
	var hero := {"name": "G", "hp": 20, "hp_max": 20, "guarding": true}
	cc._apply_damage_to_hero(hero, 8, false)
	_check(int(hero["hp"]) == 12, "magical damage goes through Guard")
	se.apply(hero, "santiguado", 0, 1)
	cc._apply_damage_to_hero(hero, 8, true)
	_check(int(hero["hp"]) == 12, "Santiguado blocks a direct hit")
	se.apply(hero, "santiguado", 0, 1)
	cc._apply_damage_to_hero(hero, 3, false, false)
	_check(int(hero["hp"]) == 9 and se.has(hero, "santiguado"), "...but not bleed/blight ticks")
	var atk := {"name": "A"}
	var tgt := {"name": "T"}
	se.apply(tgt, "fichado", 3, 0)
	_check(cc._scaled_damage(10, atk, tgt, {"vs_marked_pct": 50}) == 15, "+50% damage to marked targets")
	var guardian := {"name": "Guachi", "uid": 7, "hp": 20}
	var ward := {"name": "Ward", "uid": 8, "hp": 20}
	se.apply(ward, "cuidado", 2, 0, {"by_uid": 7})
	se.apply(guardian, "cuidando", 2, 0)
	_check(se.guardian_of(ward, [guardian, ward]) == guardian, "Al cuido: the guardian takes the hit")
	se.apply(guardian, "aturdido", 1, 0, {"ignore_resist": true})
	_check(se.guardian_of(ward, [guardian, ward]).is_empty(), "a stunned guardian stops guarding")
	cc.free()

	# --- Data ---
	var d: Dictionary = se.defs()
	for id in ["sangrado", "veneno", "aturdido", "espabilado", "salado", "fichado", "susto", "chiva", "encarrerado",
			"cuidado", "cuidando", "respondon", "sobado", "santiguado", "agazapado", "al_borde", "convaleciente"]:
		_check(d.has(id) and str(d[id].get("name", "")) != "", "status '%s' is defined (%s)" % [id, d.get(id, {}).get("name", "?")])
	print("%d failure(s)" % _fail)
	quit(1 if _fail > 0 else 0)


## Reads one item from data/items.json without the GameState autoload.
class GameStateLike:
	static func item(id: String) -> Dictionary:
		var f := FileAccess.open("res://data/items.json", FileAccess.READ)
		var all = JSON.parse_string(f.get_as_text())
		for it in all["items"]:
			if it["id"] == id:
				return it
		return {}
