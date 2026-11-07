extends Node

## Turn-based combat rules and flow, driven by the expedition screen (P4-09).
## Works directly on GameState.party dictionaries so HP/stress persist after the fight.
## The screen owns the stage units and reacts to the signals below.

const CombatResolverScript := preload("res://scripts/domain/combat_resolver.gd")
const StressSystemScript := preload("res://scripts/domain/stress_system.gd")
const ItemEffectsScript := preload("res://scripts/domain/item_effects.gd")

## A hero is waiting for the player's choice.
signal hero_turn_started(hero: Dictionary)
## Short text for the turn indicator ("Turno: …", "Victoria").
signal actor_changed(text: String)
## One combat log line; color is a hex string without # or "".
signal logged(text: String, color: String)
signal enemy_changed
signal combat_over(victory: bool)

var party: Array = []
var enemy: Dictionary = {}
var hero_units: Array = []
var enemy_units: Array = []
var is_elite: bool = false
var is_boss: bool = false

var _round: int = 0
var _turn_queue: Array = []
var _turn_index: int = 0
var _busy: bool = false
var _ended: bool = true
var _awaiting_hero: bool = false


func is_running() -> bool:
	return not _ended


## The hero whose turn it is, if the game is waiting for the player; else {}.
func active_hero() -> Dictionary:
	if _awaiting_hero and not _busy and _turn_index < _turn_queue.size():
		return _turn_queue[_turn_index]["actor"]
	return {}


func start(p_party: Array, p_enemy: Dictionary, p_hero_units: Array, p_enemy_units: Array, elite: bool, boss: bool) -> void:
	party = p_party
	enemy = p_enemy
	hero_units = p_hero_units
	enemy_units = p_enemy_units
	is_elite = elite
	is_boss = boss
	_round = 0
	_ended = false
	_busy = false
	var tier := ""
	if boss:
		tier = "¡Jefe! "
	elif elite:
		tier = "Enemigo de élite. "
	_log("%s%s bloquea el paso." % [tier, enemy.get("name", "Algo")], "dd8866")
	for u in enemy_units:
		u.set_targeted(true)
	_start_round()


# --- Player actions -------------------------------------------------------------

func use_skill(skill: Dictionary) -> void:
	var hero: Dictionary = active_hero()
	if hero.is_empty():
		return
	_busy = true
	_awaiting_hero = false
	var kind := str(skill.get("kind", ""))
	var enemy_hp_before: int = int(enemy.get("hp", 0))
	var party_before: Array = _party_snapshot()
	await _unit_for_hero(hero).play_action("attack" if kind == "attack" else "cast")
	match kind:
		"attack":
			_resolve_hero_attack(hero, skill)
		"heal":
			_resolve_heal(hero, skill)
		"buff":
			_resolve_buff(hero, skill)
		_:
			_resolve_hero_attack(hero, _first_skill_of_kind(hero, "attack"))
	await _after_action(enemy_hp_before, party_before)


## Item use spends the hero's turn. `ally` is the hero to treat (ally-target items).
func use_item(item_id: String, ally: Dictionary) -> void:
	var hero: Dictionary = active_hero()
	if hero.is_empty():
		return
	var item: Dictionary = GameState.get_item(item_id)
	if item.is_empty() or GameState.item_count(item_id) <= 0:
		return
	if not ItemEffectsScript.is_usable(item, true):
		_log("%s no se usa en combate." % item.get("name", item_id), "aaaaaa")
		return
	_busy = true
	_awaiting_hero = false
	GameState.remove_item(item_id, 1)
	var enemy_hp_before: int = int(enemy.get("hp", 0))
	var party_before: Array = _party_snapshot()
	await _unit_for_hero(hero).play_action("cast")
	_log("%s usa %s." % [hero.get("name", "?"), item.get("name", item_id)], "")
	match str(item.get("target", "ally")):
		"enemy":
			var dmg: int = ItemEffectsScript.damage_roll(item)
			if dmg > 0:
				_apply_damage_to_enemy(dmg)
				_log("%s recibe %d de daño." % [enemy.get("name", "?"), dmg], "ddbb55")
		"party":
			for h in party:
				if h is Dictionary and not h.get("dead", false):
					_log_all(ItemEffectsScript.apply_to_hero(item, h))
		_:
			var target: Dictionary = ally if (not ally.is_empty() and not ally.get("dead", false)) else hero
			_log_all(ItemEffectsScript.apply_to_hero(item, target))
	var light: int = ItemEffectsScript.light_amount(item)
	if light != 0:
		GameState.mission_light = clampi(GameState.mission_light + light, 0, 100)
	await _after_action(enemy_hp_before, party_before)


func pass_turn() -> void:
	var hero: Dictionary = active_hero()
	if hero.is_empty():
		return
	_awaiting_hero = false
	_log("%s espera." % hero.get("name", "?"), "")
	_turn_index += 1
	_process_turn()


# --- Flow ---------------------------------------------------------------------------

func _after_action(enemy_hp_before: int, party_before: Array) -> void:
	await _animate_enemy_changes(enemy_hp_before)
	await _animate_party_changes(party_before)
	_busy = false
	_turn_index += 1
	if _check_end():
		return
	_process_turn()


func _start_round() -> void:
	_round += 1
	_roll_initiative_queue()
	_turn_index = 0
	_process_turn()


func _roll_initiative_queue() -> void:
	var entries: Array = []
	for h in party:
		if h is Dictionary and not h.get("dead", false):
			var ini: int = CombatResolverScript.roll_initiative(int(h.get("speed", 3)), int(h.get("resolve_level", 0)))
			entries.append({"kind": "hero", "actor": h, "ini": ini, "spd": int(h.get("speed", 0)), "rl": int(h.get("resolve_level", 0))})
	if not enemy.get("dead", false):
		var ein: int = CombatResolverScript.roll_initiative(int(enemy.get("speed", 3)), 0)
		entries.append({"kind": "enemy", "actor": enemy, "ini": ein, "spd": int(enemy.get("speed", 0)), "rl": 0})
	entries.sort_custom(_sort_initiative)
	_turn_queue = entries
	_log("— Ronda %d —" % _round, "888888")


func _sort_initiative(a: Dictionary, b: Dictionary) -> bool:
	if int(a["ini"]) != int(b["ini"]):
		return int(a["ini"]) > int(b["ini"])
	if int(a["spd"]) != int(b["spd"]):
		return int(a["spd"]) > int(b["spd"])
	if int(a["rl"]) != int(b["rl"]):
		return int(a["rl"]) > int(b["rl"])
	return randf() < 0.5


func _process_turn() -> void:
	_refresh_units()
	if _check_end():
		return
	while _turn_index < _turn_queue.size():
		var step: Dictionary = _turn_queue[_turn_index]
		if step["kind"] == "enemy":
			if not enemy.get("dead", false):
				actor_changed.emit("Turno: %s" % enemy.get("name", "?"))
				_set_active(enemy)
				await get_tree().create_timer(0.35).timeout
				await _enemy_turn()
				_turn_index += 1
				if _check_end():
					return
			else:
				_turn_index += 1
			continue
		var hero: Dictionary = step["actor"]
		if hero.get("dead", false):
			_turn_index += 1
			continue
		_set_active(hero)
		if StressSystemScript.hero_turn_blocked(hero):
			_log("%s no actúa (quebranto)." % hero.get("name", "?"), "cc7744")
			await get_tree().create_timer(0.6).timeout
			_turn_index += 1
			if _check_end():
				return
			continue
		actor_changed.emit("Turno: %s" % str(hero.get("name", "?")))
		_awaiting_hero = true
		hero_turn_started.emit(hero)
		return
	_start_round()


func _check_end() -> bool:
	if _ended:
		return true
	if enemy.get("dead", false):
		_finish(true)
		return true
	if _living_heroes() <= 0:
		_finish(false)
		return true
	return false


func _finish(victory: bool) -> void:
	_ended = true
	_awaiting_hero = false
	for u in hero_units:
		u.set_active(false)
	actor_changed.emit("Victoria" if victory else "Derrota")
	if victory:
		_log("Victoria. %s cae." % enemy.get("name", "El enemigo"), "66aa66")
	else:
		_log("Derrota. La hacienda guarda silencio.", "aa4444")
	await get_tree().create_timer(1.0).timeout
	combat_over.emit(victory)


# --- Rules (unchanged from the slice) ---------------------------------------------

func _first_skill_of_kind(hero: Dictionary, kind: String) -> Dictionary:
	for sid in hero.get("skill_ids", []):
		var sk: Dictionary = GameState.get_skill(str(sid))
		if sk.get("kind", "") == kind:
			return sk
	return {}


func _resolve_heal(hero: Dictionary, skill: Dictionary) -> void:
	var mn: int = int(skill.get("heal_min", 2))
	var mx: int = int(skill.get("heal_max", mn))
	var amt: int = randi_range(mn, mx)
	hero["hp"] = mini(int(hero["hp"]) + amt, int(hero["hp_max"]))
	if int(hero["hp"]) > 0:
		hero["al_borde"] = false
	_log("%s usa %s (+%d PV)" % [hero.get("name", "?"), skill.get("name", "?"), amt], "")


func _resolve_buff(hero: Dictionary, skill: Dictionary) -> void:
	var rel: int = int(skill.get("self_stress_relief", 5))
	_log_all(StressSystemScript.add_stress(hero, -rel))
	_log("%s usa %s (estrés -%d)" % [hero.get("name", "?"), skill.get("name", "?"), rel], "")


func _resolve_hero_attack(hero: Dictionary, skill: Dictionary) -> void:
	var ff: Dictionary = StressSystemScript.ira_ciega_friendly_fire_target(hero, party)
	if not ff.is_empty():
		var fdmg: int = StressSystemScript.friendly_fire_damage()
		_apply_damage_to_hero(ff, fdmg)
		_log("%s (ira ciega) hiere a %s por %d" % [hero.get("name", "?"), ff.get("name", "?"), fdmg], "cc7744")
		_log_all(StressSystemScript.add_stress(hero, 4))
		return
	var sk_acc: int = int(skill.get("skill_accuracy", 0))
	var p: float = CombatResolverScript.hit_chance(int(hero.get("accuracy", 5)), sk_acc, int(enemy.get("dodge", 5)))
	if randf() > p:
		_log("%s falla %s." % [hero.get("name", "?"), skill.get("name", "")], "")
		_log_all(StressSystemScript.add_stress(hero, 3))
		return
	var raw: int = CombatResolverScript.roll_damage(skill)
	var crit: bool = CombatResolverScript.roll_crit(int(hero.get("crit", 5)), 0)
	var dmg: int = CombatResolverScript.resolve_attack_damage(raw, crit)
	_apply_damage_to_enemy(dmg)
	if crit:
		_log("%s — %s ¡CRÍTICO! %d" % [hero.get("name", "?"), skill.get("name", "?"), dmg], "ddbb55")
		_log_all(StressSystemScript.add_stress(hero, 5))
	else:
		_log("%s — %s: %d" % [hero.get("name", "?"), skill.get("name", "?"), dmg], "")


func _apply_damage_to_enemy(dmg: int) -> void:
	enemy["hp"] = int(enemy["hp"]) - dmg
	if int(enemy["hp"]) <= 0:
		enemy["hp"] = 0
		enemy["dead"] = true


func _enemy_turn() -> void:
	var living: Array = []
	for h in party:
		if h is Dictionary and not h.get("dead", false):
			living.append(h)
	if living.is_empty():
		return
	var target: Dictionary = living[randi() % living.size()]
	var skill: Dictionary = {"damage_min": 4, "damage_max": 9, "skill_accuracy": 0}
	var party_before: Array = _party_snapshot()
	if not enemy_units.is_empty():
		await enemy_units[0].play_action("attack")
	var p: float = CombatResolverScript.hit_chance(int(enemy.get("accuracy", 8)), int(skill.get("skill_accuracy", 0)), int(target.get("dodge", 5)))
	if randf() > p:
		_log("%s falla el zarpazo." % enemy.get("name", "?"), "")
		return
	var dmg: int = CombatResolverScript.roll_damage(skill)
	_apply_damage_to_hero(target, dmg)
	_log("%s golpea a %s por %d" % [enemy.get("name", "?"), target.get("name", "?"), dmg], "cc6655")
	_log_all(StressSystemScript.add_stress(target, 5))
	await _animate_party_changes(party_before)


func _apply_damage_to_hero(hero: Dictionary, dmg: int) -> void:
	if hero.get("dead", false):
		return
	var nh: int = int(hero["hp"]) - dmg
	if nh > 0:
		hero["hp"] = nh
		return
	if not hero.get("al_borde", false):
		hero["al_borde"] = true
		hero["hp"] = 0
		_log("%s está Al Borde!" % hero.get("name", "?"), "dd8844")
		return
	hero["borde_checks"] = int(hero.get("borde_checks", 0)) + 1
	if CombatResolverScript.roll_death_save():
		_log("%s resiste Al Borde." % hero.get("name", "?"), "")
		hero["hp"] = 1
		hero["al_borde"] = false
	else:
		hero["dead"] = true
		hero["hp"] = 0
		_log("%s ha caído." % hero.get("name", "?"), "cc4444")


func _living_heroes() -> int:
	var n := 0
	for h in party:
		if h is Dictionary and not h.get("dead", false):
			n += 1
	return n


# --- Stage helpers ----------------------------------------------------------------

func _unit_for_hero(hero: Dictionary):
	for k in party.size():
		if is_same(party[k], hero):
			return hero_units[k]
	return null


func _refresh_units() -> void:
	for u in hero_units:
		u.refresh()
	for u in enemy_units:
		u.refresh()


func _set_active(actor: Dictionary) -> void:
	for k in party.size():
		hero_units[k].set_active(is_same(party[k], actor))
	for u in enemy_units:
		if is_same(u.data, actor):
			u.set_active(true)
		else:
			u.set_targeted(not u.is_dead())


func _party_snapshot() -> Array:
	var out: Array = []
	for h in party:
		out.append({"hp": int(h.get("hp", 0)), "dead": bool(h.get("dead", false)), "borde": bool(h.get("al_borde", false))})
	return out


func _animate_party_changes(before: Array) -> void:
	for k in party.size():
		var h: Dictionary = party[k]
		var b: Dictionary = before[k]
		if bool(h.get("dead", false)) and not bool(b["dead"]):
			await hero_units[k].play_death()
		elif int(h.get("hp", 0)) < int(b["hp"]) or (bool(h.get("al_borde", false)) and not bool(b["borde"])):
			await hero_units[k].play_hurt()
		elif int(h.get("hp", 0)) > int(b["hp"]):
			await hero_units[k].play_heal()
		else:
			hero_units[k].refresh()


func _animate_enemy_changes(hp_before: int) -> void:
	if enemy_units.is_empty():
		return
	var eu = enemy_units[0]
	if bool(enemy.get("dead", false)) and hp_before > 0:
		await eu.play_death()
	elif int(enemy.get("hp", 0)) < hp_before:
		await eu.play_hurt()
	enemy_changed.emit()


func _log(text: String, color: String) -> void:
	logged.emit(text, color)


func _log_all(lines: PackedStringArray) -> void:
	for l in lines:
		_log(l, "")
