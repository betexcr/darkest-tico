extends SceneTree

## Guard halves physical damage: godot --headless --path . -s tests/test_guard.gd

func _initialize() -> void:
	var c = load("res://scripts/combat/combat_controller.gd").new()
	var hero := {"name": "T", "hp": 20, "hp_max": 20, "guarding": true}
	c._apply_damage_to_hero(hero, 8)
	var ok1: bool = int(hero["hp"]) == 16
	hero["guarding"] = false
	c._apply_damage_to_hero(hero, 8)
	var ok2: bool = int(hero["hp"]) == 8
	hero["guarding"] = true
	c._apply_damage_to_hero(hero, 8, false)
	var ok3: bool = int(hero["hp"]) == 0
	print("guarded 8 -> 4: ", "ok" if ok1 else "FAIL")
	print("unguarded 8 -> 8: ", "ok" if ok2 else "FAIL")
	print("non-physical ignores guard: ", "ok" if ok3 else "FAIL")
	c.free()
	quit(0 if ok1 and ok2 and ok3 else 1)
