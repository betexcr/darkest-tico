extends Node

## Turn-based combat rules and flow, driven by the expedition screen (P4-09).
## Works directly on GameState.party dictionaries so HP/stress persist after the fight.
## The screen owns the stage units and reacts to the signals below.

const COLOR_MISS := Color(0.85, 0.85, 0.85)
const CombatResolverScript := preload("res://scripts/domain/combat_resolver.gd")
const StressSystemScript := preload("res://scripts/domain/stress_system.gd")
const ItemEffectsScript := preload("res://scripts/domain/item_effects.gd")
const StatusEffectsScript := preload("res://scripts/domain/status_effects.gd")
const CampingSystemScript := preload("res://scripts/domain/camping_system.gd")

## A hero is waiting for the player's choice.
signal hero_turn_started(hero: Dictionary)
## Short text for the turn indicator ("Turno: …", "Victoria").
signal actor_changed(text: String)
## One combat log line; color is a hex string without # or "".
signal logged(text: String, color: String)
signal enemy_changed
signal combat_over(victory: bool)

var party: Array = []
## Enemy squad (1-4), index-aligned with enemy_units; index 0 = front rank.
var enemies: Array = []
## Enemy the player's attacks and enemy-target items hit (click an enemy to change).
var target_enemy: Dictionary = {}
var hero_units: Array = []
var enemy_units: Array = []
var is_elite: bool = false
var is_boss: bool = false
var is_ambush: bool = false

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


## The chosen target if it can still be hit, else the front-most enemy that can
## (hidden/agazapado enemies only when nobody else is left).
func current_target() -> Dictionary:
	var open: Array = StatusEffectsScript.targetable(enemies)
	if not target_enemy.is_empty() and open.has(target_enemy):
		return target_enemy
	return open[0] if not open.is_empty() else {}


## Enemies a single-target attack may pick right now.
func targetable_enemies() -> Array:
	return StatusEffectsScript.targetable(enemies)


func set_target(e: Dictionary) -> void:
	if e.get("dead", false) or not targetable_enemies().has(e):
		return
	target_enemy = e
	_refresh_markers()


func start(p_party: Array, p_enemies: Array, p_hero_units: Array, p_enemy_units: Array, elite: bool, boss: bool, ambush: bool = false) -> void:
	party = p_party
	enemies = p_enemies
	target_enemy = {}
	hero_units = p_hero_units
	enemy_units = p_enemy_units
	is_elite = elite
	is_boss = boss
	is_ambush = ambush
	_round = 0
	_ended = false
	_busy = false
	var tier := ""
	if ambush:
		tier = "¡Emboscada nocturna! "
	elif boss:
		tier = "¡Jefe! "
	elif elite:
		tier = "Enemigo de élite. "
	var names: PackedStringArray = PackedStringArray()
	for e in enemies:
		names.append(str(e.get("name", "?")))
	_log("%s%s bloquean el paso." % [tier, ", ".join(names)] if enemies.size() > 1 else "%s%s bloquea el paso." % [tier, names[0]], "dd8866")
	# Accessories that start every fight with an effect (items.json "start_status").
	for h in party:
		if h is Dictionary and not h.get("dead", false):
			for ss in h.get("start_status", []):
				_try_apply(h, ss, false, "")
	_refresh_markers()
	_start_round()


# --- Player actions -------------------------------------------------------------

## `ally` is the hero picked on the stage, used by ally-target skills (default: the actor).
func use_skill(skill: Dictionary, ally: Dictionary = {}) -> void:
	var hero: Dictionary = active_hero()
	if hero.is_empty():
		return
	_busy = true
	_awaiting_hero = false
	var kind := str(skill.get("kind", ""))
	var enemy_before: Array = _enemy_snapshot()
	var party_before: Array = _party_snapshot()
	if kind != "attack" and StressSystemScript.refuses_support(hero):
		# Paranoia (doc 01 §3.3): refuses buffs/heals; the turn is lost.
		_log("%s (paranoia) desconfía y no usa %s." % [hero.get("name", "?"), skill.get("name", "?")], "cc7744")
		await _after_action(enemy_before, party_before)
		return
	await _unit_for_hero(hero).play_action("attack" if kind == "attack" else "cast")
	if kind == "attack":
		_resolve_hero_attack(hero, skill, current_target())
	else:
		_resolve_support(hero, skill, ally)
	await _after_action(enemy_before, party_before)


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
	var enemy_before: Array = _enemy_snapshot()
	var party_before: Array = _party_snapshot()
	await _unit_for_hero(hero).play_action("cast")
	_log("%s usa %s." % [hero.get("name", "?"), item.get("name", item_id)], "")
	match str(item.get("target", "ally")):
		"enemy":
			var tgt: Dictionary = current_target()
			var dmg: int = _elemental(ItemEffectsScript.damage_roll(item), str(item.get("effects", {}).get("element", "")), tgt)
			if dmg > 0 and not tgt.is_empty():
				_apply_damage_to_enemy(tgt, dmg)
				_log("%s recibe %d de daño." % [tgt.get("name", "?"), dmg], "ddbb55")
			var ap = item.get("effects", {}).get("applies", null)
			if ap is Dictionary and not tgt.is_empty() and not tgt.get("dead", false) and randf() < float(ap.get("chance", 0.0)):
				var msg: String = StatusEffectsScript.apply(tgt, str(ap.get("status", "")), int(ap.get("turns", 1)), int(ap.get("value", 0)))
				if msg != "":
					_log(msg, "cc9944")
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
	await _after_action(enemy_before, party_before)


## Guard: the hero takes half physical damage until their next turn (owner, 2026-11-07).
func guard() -> void:
	var hero: Dictionary = active_hero()
	if hero.is_empty():
		return
	_awaiting_hero = false
	hero["guarding"] = true
	_log("%s se pone en guardia (mitad de daño físico hasta su próximo turno)." % hero.get("name", "?"), "88aacc")
	var u = _unit_for_hero(hero)
	if u != null:
		u.refresh()
	_turn_index += 1
	_process_turn()


func pass_turn() -> void:
	var hero: Dictionary = active_hero()
	if hero.is_empty():
		return
	_awaiting_hero = false
	_log("%s espera." % hero.get("name", "?"), "")
	_turn_index += 1
	_process_turn()


# --- Flow ---------------------------------------------------------------------------

func _after_action(enemy_before: Array, party_before: Array) -> void:
	await _animate_enemy_changes(enemy_before)
	await _animate_party_changes(party_before)
	_busy = false
	_turn_index += 1
	if _check_end():
		return
	_process_turn()


func _start_round() -> void:
	_round += 1
	if _round > 1:
		# Virtudes Esperanza (calms companions) and Vigor (regains PV) at the top of each round.
		_log_all(StressSystemScript.round_start_effects(party))
	_roll_initiative_queue()
	_turn_index = 0
	_process_turn()


func _roll_initiative_queue() -> void:
	var entries: Array = []
	for h in party:
		if h is Dictionary and not h.get("dead", false):
			var hs: int = int(h.get("speed", 3)) + StatusEffectsScript.stat(h, "speed")
			var ini: int = CombatResolverScript.roll_initiative(hs, int(h.get("resolve_level", 0)))
			entries.append({"kind": "hero", "actor": h, "ini": ini, "spd": hs, "rl": int(h.get("resolve_level", 0)), "tie": randf()})
	for e in enemies:
		if not e.get("dead", false):
			var es: int = int(e.get("speed", 3)) + StatusEffectsScript.stat(e, "speed")
			var ein: int = CombatResolverScript.roll_initiative(es, 0)
			entries.append({"kind": "enemy", "actor": e, "ini": ein, "spd": es, "rl": 0, "tie": randf()})
	entries.sort_custom(_sort_initiative)
	if is_ambush and _round == 1:
		# Night ambush (doc 07 §6): the enemies get a surprise round and all act first.
		var foes: Array = entries.filter(func(x): return x["kind"] == "enemy")
		var heroes: Array = entries.filter(func(x): return x["kind"] == "hero")
		entries = foes + heroes
	_turn_queue = entries
	_log("— Ronda %d —" % _round, "888888")


func _sort_initiative(a: Dictionary, b: Dictionary) -> bool:
	if int(a["ini"]) != int(b["ini"]):
		return int(a["ini"]) > int(b["ini"])
	if int(a["spd"]) != int(b["spd"]):
		return int(a["spd"]) > int(b["spd"])
	if int(a["rl"]) != int(b["rl"]):
		return int(a["rl"]) > int(b["rl"])
	# Random tie-break rolled once per unit per round (a comparator must be consistent).
	return float(a["tie"]) > float(b["tie"])


func _process_turn() -> void:
	_refresh_units()
	if _check_end():
		return
	while _turn_index < _turn_queue.size():
		var step: Dictionary = _turn_queue[_turn_index]
		if step["kind"] == "enemy":
			var foe: Dictionary = step["actor"]
			if not foe.get("dead", false):
				actor_changed.emit("Turno: %s" % foe.get("name", "?"))
				_set_active(foe)
				await get_tree().create_timer(0.35).timeout
				await _enemy_turn(foe)
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
		hero["guarding"] = false
		var tk: Dictionary = StatusEffectsScript.tick(hero)
		_log_all(tk["logs"])
		if int(tk["damage"]) > 0 or int(tk["heal"]) > 0 or int(tk["stress"]) > 0:
			var before: Array = _party_snapshot()
			if int(tk["heal"]) > 0:
				_heal(hero, int(tk["heal"]))
			if int(tk["damage"]) > 0:
				_apply_damage_to_hero(hero, int(tk["damage"]), false, false)
			if int(tk["stress"]) > 0 and not hero.get("dead", false):
				_log_all(StressSystemScript.add_stress(hero, _stress_after_mods(hero, int(tk["stress"]))))
			await _animate_party_changes(before)
			if _check_end():
				return
		if hero.get("dead", false) or bool(tk["skip"]):
			_refresh_units()
			await get_tree().create_timer(0.5).timeout
			_turn_index += 1
			continue
		if StressSystemScript.hero_turn_blocked(hero):
			_log("%s no actúa (cobardía)." % hero.get("name", "?"), "cc7744")
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
	if current_target().is_empty():
		_finish(true)
		return true
	if _living_heroes() <= 0:
		_finish(false)
		return true
	return false


func _finish(victory: bool) -> void:
	_ended = true
	_awaiting_hero = false
	for h in party:
		if h is Dictionary:
			h["guarding"] = false
			StatusEffectsScript.clear(h)
			# Camp buffs last a number of fights (P3-07).
			CampingSystemScript.tick_fight(h)
	for e in enemies:
		StatusEffectsScript.clear(e)
	for u in hero_units:
		u.set_active(false)
		u.refresh()
	actor_changed.emit("Victoria" if victory else "Derrota")
	if victory:
		_log("Victoria. Cae el último enemigo.", "66aa66")
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


## Heal and/or stress relief on self, the chosen ally, or the whole party (skill "target").
func _resolve_support(hero: Dictionary, skill: Dictionary, ally: Dictionary) -> void:
	var targets: Array = []
	match str(skill.get("target", "self")):
		"party":
			for h in party:
				if h is Dictionary and not h.get("dead", false):
					targets.append(h)
		"ally":
			targets.append(ally if (not ally.is_empty() and not ally.get("dead", false)) else hero)
		_:
			targets.append(hero)
	var who: PackedStringArray = PackedStringArray()
	for t in targets:
		who.append(str(t.get("name", "?")))
	_log("%s usa %s → %s" % [hero.get("name", "?"), skill.get("name", "?"), ", ".join(who)], "88bb88")
	for t in targets:
		if skill.has("heal_min"):
			var amt: int = randi_range(int(skill["heal_min"]), int(skill.get("heal_max", skill["heal_min"])))
			_heal(t, amt)
			_log("  %s +%d PV" % [t.get("name", "?"), amt], "88bb88")
		for ap in _applies_list(skill.get("applies", null)):
			_try_apply(t, ap, false, "  ")
		if bool(skill.get("guard_ally", false)) and not is_same(t, hero):
			# Al cuido: the user takes single-target attacks aimed at the ally.
			for other in party:
				if other is Dictionary and StatusEffectsScript.has(other, "cuidado") and StatusEffectsScript.guardian_of(other, party) == hero:
					StatusEffectsScript.remove(other, "cuidado")
			StatusEffectsScript.remove(hero, "cuidando")
			var turns: int = int(skill.get("guard_turns", 2))
			StatusEffectsScript.apply(t, "cuidado", turns, 0, {"by_uid": int(hero.get("uid", -1))})
			StatusEffectsScript.apply(hero, "cuidando", turns, 0)
			_log("  %s cuida a %s (recibe sus golpes)." % [hero.get("name", "?"), t.get("name", "?")], "88aacc")
		var rel: int = int(skill.get("stress_relief", skill.get("self_stress_relief", 0)))
		if rel > 0:
			_log_all(StressSystemScript.add_stress(t, -rel))
			_log("  %s estrés -%d" % [t.get("name", "?"), rel], "88bb88")
		for st in skill.get("cure", []):
			if StatusEffectsScript.has(t, str(st)):
				StatusEffectsScript.remove(t, str(st))
				_log("  %s ya no está %s" % [t.get("name", "?"), StatusEffectsScript.display_name(str(st)).to_lower()], "88bb88")
		if bool(skill.get("cure_all", false)):
			var gone: PackedStringArray = StatusEffectsScript.remove_all_negative(t)
			if not gone.is_empty():
				_log("  %s queda limpio: %s" % [t.get("name", "?"), ", ".join(gone)], "88bb88")
		if bool(skill.get("grant_guard", false)):
			t["guarding"] = true
			_log("  %s queda en guardia" % t.get("name", "?"), "88aacc")
	for ap in _applies_list(skill.get("self_applies", null)):
		_try_apply(hero, ap, false, "  ")


func _resolve_hero_attack(hero: Dictionary, skill: Dictionary, enemy: Dictionary) -> void:
	if enemy.is_empty():
		return
	# Attacking gives away a hidden hero.
	if StatusEffectsScript.remove(hero, "agazapado"):
		_log("%s sale de su escondite." % hero.get("name", "?"), "999999")
	var ff: Dictionary = StressSystemScript.ira_ciega_friendly_fire_target(hero, party)
	if not ff.is_empty():
		var fdmg: int = StressSystemScript.friendly_fire_damage()
		_apply_damage_to_hero(ff, fdmg)
		_log("%s (ira ciega) hiere a %s por %d" % [hero.get("name", "?"), ff.get("name", "?"), fdmg], "cc7744")
		_log_all(StressSystemScript.add_stress(hero, 4))
		return
	var light_cost: int = StressSystemScript.bravata_light_cost(hero)
	if light_cost > 0:
		GameState.mission_light = maxi(GameState.mission_light - light_cost, 0)
		_log("%s (bravata) agita la candela para lucirse: Luz -%d." % [hero.get("name", "?"), light_cost], "cc7744")
	var sk_acc: int = int(skill.get("skill_accuracy", 0))
	var acc: int = int(hero.get("accuracy", 5)) + StatusEffectsScript.stat(hero, "accuracy")
	var dod: int = int(enemy.get("dodge", 5)) + StatusEffectsScript.stat(enemy, "dodge")
	var p: float = CombatResolverScript.hit_chance(acc, sk_acc, dod)
	for ap in _applies_list(skill.get("self_applies", null)):
		_try_apply(hero, ap, false, "")
	if randf() > p:
		_log("%s falla %s." % [hero.get("name", "?"), skill.get("name", "")], "")
		var mu = _unit_for_enemy(enemy)
		if mu != null:
			mu.float_text("Falla", COLOR_MISS)
		_log_all(StressSystemScript.add_stress(hero, 3))
		_enemy_riposte(enemy, hero)
		return
	var raw: int = CombatResolverScript.roll_damage(skill) + int(hero.get("dmg_bonus", 0))
	var crit: bool = CombatResolverScript.roll_crit(int(hero.get("crit", 5)) + StatusEffectsScript.stat(hero, "crit"), 0)
	var dmg: int = CombatResolverScript.resolve_attack_damage(maxi(raw, 1), crit)
	dmg = _scaled_damage(dmg, hero, enemy, skill)
	dmg = _elemental(dmg, str(hero.get("element", "")), enemy)
	if crit:
		enemy["_crit_hit"] = true
	if StatusEffectsScript.use_aegis(enemy):
		_log("¡%s se santiguó: el golpe no le hace nada!" % enemy.get("name", "?"), "e6e0c8")
		dmg = 0
	else:
		_apply_damage_to_enemy(enemy, dmg)
	if crit:
		StatusEffectsScript.apply(hero, "encarrerado", 2, 0)
	if not enemy.get("dead", false):
		for ap in _applies_list(skill.get("applies", null)):
			_try_apply(enemy, ap, crit, "")
		# Weapon effects (items.json "on_hit").
		for ap in hero.get("on_hit", []):
			_try_apply(enemy, ap, crit, "")
	_enemy_riposte(enemy, hero)
	var cost: int = int(skill.get("self_stress", 0))
	if cost > 0:
		_log_all(StressSystemScript.add_stress(hero, cost))
		_log("  %s: estrés +%d (costo)" % [hero.get("name", "?"), cost], "aa88cc")
	if crit:
		_log("%s — %s a %s ¡CRÍTICO! %d" % [hero.get("name", "?"), skill.get("name", "?"), enemy.get("name", "?"), dmg], "ddbb55")
		_log_all(StressSystemScript.add_stress(hero, 5))
	else:
		_log("%s — %s a %s: %d" % [hero.get("name", "?"), skill.get("name", "?"), enemy.get("name", "?"), dmg], "")


func _apply_damage_to_enemy(enemy: Dictionary, dmg: int) -> void:
	enemy["hp"] = int(enemy["hp"]) - dmg
	if int(enemy["hp"]) <= 0:
		enemy["hp"] = 0
		enemy["dead"] = true


## Elemental multiplier from the target's "elements" (enemies) or "resist" (heroes).
func _elemental(dmg: int, element: String, target: Dictionary) -> int:
	if element == "" or dmg <= 0:
		return dmg
	var table = target.get("elements", target.get("resist", {}))
	var mult: float = float(table.get(element, 1.0)) if table is Dictionary else 1.0
	var elname: String = str(GameState.ELEMENT_NAMES.get(element, element))
	if mult == 0.0:
		_log("  %s es inmune a %s." % [target.get("name", "?"), elname], "999999")
	elif mult > 1.0:
		_log("  ¡%s es débil a %s!" % [target.get("name", "?"), elname], "ffcc55")
	elif mult < 1.0:
		_log("  %s resiste %s." % [target.get("name", "?"), elname], "999999")
	return int(round(dmg * mult))


## Basic attack or a special, chosen by "weight" (data/enemies.json).
func _pick_enemy_skill(enemy: Dictionary) -> Dictionary:
	var list: Array = enemy.get("skills", [])
	if list.is_empty():
		return {"name": "Zarpazo", "type": "physical", "damage": [4, 9], "target": "single", "stress": 5}
	var total: float = 0.0
	for s in list:
		total += float(s.get("weight", 20))
	var roll: float = randf() * total
	for s in list:
		roll -= float(s.get("weight", 20))
		if roll <= 0.0:
			return s
	return list[0]


func _enemy_turn(enemy: Dictionary) -> void:
	# Ailments tick first; a stunned enemy loses its turn.
	var tk: Dictionary = StatusEffectsScript.tick(enemy)
	_log_all(tk["logs"])
	if int(tk["heal"]) > 0:
		enemy["hp"] = mini(int(enemy["hp"]) + int(tk["heal"]), int(enemy.get("hp_max", enemy["hp"])))
		var hu = _unit_for_enemy(enemy)
		if hu != null:
			hu.play_heal(int(tk["heal"]), 0)
	if int(tk["damage"]) > 0:
		var before: Array = _enemy_snapshot()
		_apply_damage_to_enemy(enemy, int(tk["damage"]))
		await _animate_enemy_changes(before)
	if enemy.get("dead", false) or bool(tk["skip"]):
		return
	var living: Array = []
	for h in party:
		if h is Dictionary and not h.get("dead", false):
			living.append(h)
	if living.is_empty():
		return
	var skill: Dictionary = _pick_enemy_skill(enemy)
	var magical: bool = str(skill.get("type", "physical")) == "magical"
	var single: bool = str(skill.get("target", "single")) != "party"
	var targets: Array = living
	if single:
		var pick: Dictionary = StatusEffectsScript.pick_target(living)
		# Al cuido: the guardian steps in front of single-target attacks.
		var guard: Dictionary = StatusEffectsScript.guardian_of(pick, party)
		if not guard.is_empty():
			_log("%s se interpone y recibe el golpe dirigido a %s." % [guard.get("name", "?"), pick.get("name", "?")], "88aacc")
			pick = guard
		else:
			# Virtud Abnegación: a companion may step in on their own.
			var hero_shield: Dictionary = StressSystemScript.find_protector(pick, party)
			if not hero_shield.is_empty():
				_log("%s (abnegación) se interpone por %s." % [hero_shield.get("name", "?"), pick.get("name", "?")], "88bb88")
				pick = hero_shield
		targets = [pick]
	# Attacking gives away a hidden enemy (unless this skill is the one that hides it).
	var hides: bool = false
	for ap in _applies_list(skill.get("self_applies", null)):
		hides = hides or str(ap.get("status", "")) == "agazapado"
	if not hides and StatusEffectsScript.remove(enemy, "agazapado"):
		_log("%s sale de las sombras." % enemy.get("name", "?"), "999999")
	var party_before: Array = _party_snapshot()
	var eu = _unit_for_enemy(enemy)
	if eu != null:
		await eu.play_action("cast" if magical else "attack")
	_log("%s usa %s%s." % [enemy.get("name", "?"), skill.get("name", "?"), " (mágico)" if magical else ""], "cc6655")
	var dmg_range: Array = skill.get("damage", [4, 9])
	var physical: bool = not magical and not bool(skill.get("ignores_guard", false))
	for t in targets:
		var acc: int = int(enemy.get("accuracy", 8)) + StatusEffectsScript.stat(enemy, "accuracy")
		var dod: int = int(t.get("dodge", 5)) + StatusEffectsScript.stat(t, "dodge")
		var p: float = CombatResolverScript.hit_chance(acc, int(skill.get("accuracy", 0)), dod)
		if randf() > p:
			_log("  %s esquiva." % t.get("name", "?"), "")
			var du = _unit_for_hero(t)
			if du != null:
				du.float_text("Esquiva", COLOR_MISS)
			if single:
				await _hero_riposte(t, enemy)
			continue
		var dmg: int = randi_range(int(dmg_range[0]), int(dmg_range[1]))
		# Expedition difficulty (data/progression.json enemy_dmg).
		dmg = int(round(dmg * float(enemy.get("dmg_mult", 1.0))))
		dmg = _scaled_damage(dmg, enemy, t, skill)
		dmg = _elemental(dmg, str(skill.get("element", "")), t)
		if dmg > 0:
			_log("  %s recibe %d." % [t.get("name", "?"), dmg], "cc6655")
			_apply_damage_to_hero(t, dmg, physical)
		var stress: int = int(round(int(skill.get("stress", 0)) * (1.0 - int(t.get("stress_resist", 0)) / 100.0)))
		stress = _stress_after_mods(t, stress)
		if stress > 0 and not t.get("dead", false):
			_log_all(StressSystemScript.add_stress(t, stress))
			_log("  %s: estrés +%d" % [t.get("name", "?"), stress], "aa88cc")
		if dmg > 0:
			_log_all(StressSystemScript.spread_despair(t, party))
		if not t.get("dead", false):
			for ap in _applies_list(skill.get("applies", null)):
				_try_apply(t, ap, false, "  ")
		if single:
			await _hero_riposte(t, enemy)
	for ap in _applies_list(skill.get("self_applies", null)):
		_try_apply(enemy, ap, false, "")
	var light: int = int(skill.get("light", 0))
	if light != 0:
		GameState.mission_light = clampi(GameState.mission_light + light, 0, 100)
		_log("La luz baja a %d." % GameState.mission_light, "aa8866")
	var steal: int = int(skill.get("steal_colones", 0))
	if steal > 0:
		var taken: int = mini(steal, GameState.colones)
		GameState.colones -= taken
		_log("Se llevó %d colones." % taken, "aa8866")
	await _animate_party_changes(party_before)


## `physical`: protection and Guard apply. `direct`: a hit from an attack (Santiguado can
## block it); bleed/blight ticks pass direct = false.
func _apply_damage_to_hero(hero: Dictionary, dmg: int, physical: bool = true, direct: bool = true) -> void:
	if hero.get("dead", false):
		return
	if direct and StatusEffectsScript.use_aegis(hero):
		_log("¡%s estaba santiguado: el golpe no le hace nada!" % hero.get("name", "?"), "e6e0c8")
		return
	var prot: int = clampi(int(hero.get("prot", 0)) + StatusEffectsScript.stat(hero, "prot"), 0, 80)
	if physical and prot > 0:
		dmg = maxi(int(round(dmg * (1.0 - prot / 100.0))), 1)
	if physical and bool(hero.get("guarding", false)):
		dmg = maxi(int(ceil(dmg / 2.0)), 1)
		_log("%s bloquea con su guardia: daño reducido a %d." % [hero.get("name", "?"), dmg], "88aacc")
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
	if CombatResolverScript.roll_death_save(StatusEffectsScript.deathblow_chance(hero)):
		_log("%s resiste Al Borde." % hero.get("name", "?"), "")
		hero["hp"] = 1
		hero["al_borde"] = false
		hero["convaleciente"] = true
	else:
		hero["dead"] = true
		hero["hp"] = 0
		_log("%s ha caído." % hero.get("name", "?"), "cc4444")


## Heal a hero; coming back from Al Borde leaves them Convaleciente for the expedition.
func _heal(hero: Dictionary, amount: int) -> void:
	if hero.get("dead", false) or amount <= 0:
		return
	hero["hp"] = mini(int(hero["hp"]) + amount, int(hero["hp_max"]))
	if int(hero["hp"]) > 0 and bool(hero.get("al_borde", false)):
		hero["al_borde"] = false
		hero["convaleciente"] = true
		_log("%s sale de Al Borde, pero queda convaleciente." % hero.get("name", "?"), "c09090")


## Damage after buffs/debuffs (dmg_pct) and the mark bonus (skill "vs_marked_pct").
func _scaled_damage(dmg: int, attacker: Dictionary, target: Dictionary, skill: Dictionary) -> int:
	var pct: int = StatusEffectsScript.stat(attacker, "dmg_pct")
	if StatusEffectsScript.has(target, "fichado"):
		pct += int(skill.get("vs_marked_pct", 0))
	return maxi(int(round(dmg * (1.0 + pct / 100.0))), 1) if dmg > 0 else dmg


func _stress_after_mods(hero: Dictionary, stress: int) -> int:
	if stress <= 0:
		return stress
	return int(round(stress * (1.0 + StatusEffectsScript.stat(hero, "stress_pct") / 100.0)))


## "applies" may be one entry or a list: {status, chance, turns, value, mods}.
func _applies_list(v) -> Array:
	if v is Dictionary:
		return [v]
	if v is Array:
		return v
	return []


func _try_apply(unit: Dictionary, ap: Dictionary, crit: bool, indent: String) -> void:
	if unit.get("dead", false) or randf() >= float(ap.get("chance", 1.0)):
		return
	var opts: Dictionary = {"crit": crit}
	if ap.has("mods"):
		opts["mods"] = ap["mods"]
	var msg: String = StatusEffectsScript.apply(unit, str(ap.get("status", "")), int(ap.get("turns", 0)), int(ap.get("value", 0)), opts)
	if msg != "":
		_log(indent + msg, "cc9944" if StatusEffectsScript.is_negative(str(ap.get("status", ""))) else "88bbdd")


## Respondón (riposte) on an enemy: it hits back the hero that attacked it.
func _enemy_riposte(enemy: Dictionary, hero: Dictionary) -> void:
	if enemy.get("dead", false) or hero.get("dead", false) or not StatusEffectsScript.has(enemy, "respondon"):
		return
	var basic: Dictionary = {}
	for s in enemy.get("skills", []):
		if bool(s.get("basic", false)):
			basic = s
	var dr: Array = basic.get("damage", [3, 6])
	var dmg: int = _scaled_damage(randi_range(int(dr[0]), int(dr[1])), enemy, hero, basic)
	_log("%s responde el golpe: %d a %s." % [enemy.get("name", "?"), dmg, hero.get("name", "?")], "cc6655")
	_apply_damage_to_hero(hero, dmg, true)


## Respondón on a hero: hits back the enemy that attacked them, with their first attack skill.
func _hero_riposte(hero: Dictionary, enemy: Dictionary) -> void:
	if hero.get("dead", false) or enemy.get("dead", false) or not StatusEffectsScript.has(hero, "respondon"):
		return
	var sk: Dictionary = _first_skill_of_kind(hero, "attack")
	if sk.is_empty():
		return
	var before: Array = _enemy_snapshot()
	var dmg: int = _scaled_damage(CombatResolverScript.roll_damage(sk) + int(hero.get("dmg_bonus", 0)), hero, enemy, sk)
	dmg = _elemental(dmg, str(hero.get("element", "")), enemy)
	if StatusEffectsScript.use_aegis(enemy):
		dmg = 0
	_apply_damage_to_enemy(enemy, dmg)
	_log("%s responde el golpe: %d a %s." % [hero.get("name", "?"), dmg, enemy.get("name", "?")], "ddbb55")
	await _animate_enemy_changes(before)


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


func _unit_for_enemy(e: Dictionary):
	for k in enemies.size():
		if is_same(enemies[k], e) and k < enemy_units.size():
			return enemy_units[k]
	return null


var _active_actor: Dictionary = {}


func _set_active(actor: Dictionary) -> void:
	_active_actor = actor
	for k in party.size():
		hero_units[k].set_active(is_same(party[k], actor))
	_refresh_markers()


## Gold marker on the acting enemy, red on the player's target, none on the rest.
func _refresh_markers() -> void:
	var tgt: Dictionary = current_target()
	for u in enemy_units:
		if is_same(u.data, _active_actor):
			u.set_active(true)
		else:
			u.set_targeted(not u.is_dead() and is_same(u.data, tgt))


func _party_snapshot() -> Array:
	var out: Array = []
	for h in party:
		out.append({"hp": int(h.get("hp", 0)), "stress": int(h.get("stress", 0)), "dead": bool(h.get("dead", false)), "borde": bool(h.get("al_borde", false))})
	return out


func _animate_party_changes(before: Array) -> void:
	for k in party.size():
		var h: Dictionary = party[k]
		var b: Dictionary = before[k]
		var lost: int = int(b["hp"]) - int(h.get("hp", 0))
		var stress_up: int = int(h.get("stress", 0)) - int(b["stress"])
		if stress_up > 0:
			hero_units[k].float_text("+%d estrés" % stress_up, hero_units[k].COLOR_STRESS)
		if bool(h.get("dead", false)) and not bool(b["dead"]):
			await hero_units[k].play_death(maxi(lost, 0))
		elif lost > 0 or (bool(h.get("al_borde", false)) and not bool(b["borde"])):
			await hero_units[k].play_hurt(maxi(lost, 0))
		elif lost < 0 or stress_up < 0:
			await hero_units[k].play_heal(maxi(-lost, 0), maxi(-stress_up, 0))
		else:
			hero_units[k].refresh()


func _enemy_snapshot() -> Array:
	return enemies.map(func(e): return int(e.get("hp", 0)))


func _animate_enemy_changes(before: Array) -> void:
	for k in mini(enemies.size(), enemy_units.size()):
		var e: Dictionary = enemies[k]
		var lost: int = int(before[k]) - int(e.get("hp", 0))
		var crit: bool = bool(e.get("_crit_hit", false))
		e.erase("_crit_hit")
		if bool(e.get("dead", false)) and int(before[k]) > 0:
			await enemy_units[k].play_death(lost, crit)
		elif lost > 0:
			await enemy_units[k].play_hurt(lost, crit)
	_refresh_markers()
	enemy_changed.emit()


func _log(text: String, color: String) -> void:
	logged.emit(text, color)


func _log_all(lines: PackedStringArray) -> void:
	for l in lines:
		_log(l, "")
