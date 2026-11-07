extends SceneTree

## Ailments and enemy abilities: godot --headless --path . -s tests/test_status.gd

var _fail: int = 0


func _check(cond: bool, what: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + what)
	if not cond:
		_fail += 1


func _initialize() -> void:
	var se = load("res://scripts/domain/status_effects.gd")
	var u := {"name": "T", "hp": 20}
	se.apply(u, "sangrado", 2, 3)
	var t1: Dictionary = se.tick(u)
	_check(int(t1["damage"]) == 3 and not t1["skip"], "bleed deals 3 on tick 1")
	var t2: Dictionary = se.tick(u)
	_check(int(t2["damage"]) == 3 and not se.any(u), "bleed deals 3 on tick 2, then wears off")
	se.apply(u, "aturdido", 1, 0)
	_check(bool(se.tick(u)["skip"]) and not se.any(u), "stun skips one turn")
	var ie = load("res://scripts/domain/item_effects.gd")
	se.apply(u, "sangrado", 3, 2)
	ie.apply_to_hero({"effects": {"heal": 1, "cure": ["sangrado"]}}, u)
	_check(not se.has(u, "sangrado"), "venda-style cure removes bleeding")
	var c = load("res://scripts/combat/combat_controller.gd").new()
	var hero := {"name": "G", "hp": 20, "hp_max": 20, "guarding": true}
	c._apply_damage_to_hero(hero, 8, false)
	_check(int(hero["hp"]) == 12, "magical damage goes through Guard")
	c.free()
	print("%d failure(s)" % _fail)
	quit(1 if _fail > 0 else 0)
