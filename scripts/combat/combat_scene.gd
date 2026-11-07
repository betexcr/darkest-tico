extends Control

## Explicit preload so static methods resolve before global class registration (Godot 4.6+).
const CombatResolverScript := preload("res://scripts/domain/combat_resolver.gd")
const StressSystemScript := preload("res://scripts/domain/stress_system.gd")
const BattleUnitScript := preload("res://scripts/combat/battle_unit.gd")

signal combat_finished(victory: bool)

@onready var _log: RichTextLabel = $BottomPanel/Row/Center/CombatLog
@onready var _round_label: Label = $Stage/TopBar/RoundLabel
@onready var _actor_label: Label = $Stage/TopBar/ActorLabel
@onready var _light_label: Label = $Stage/TopBar/LightLabel
@onready var _bg: TextureRect = $BgTexture
@onready var _hero_row: HBoxContainer = $Stage/HeroRow
@onready var _enemy_row: HBoxContainer = $Stage/EnemyRow
@onready var _skills_box: HBoxContainer = $BottomPanel/Row/Center/Skills
@onready var _hero_portrait: TextureRect = $BottomPanel/Row/HeroCard/HeroPortrait
@onready var _hero_name: Label = $BottomPanel/Row/HeroInfo/HeroName
@onready var _hero_stats: Label = $BottomPanel/Row/HeroInfo/HeroStats
@onready var _target_portrait: TextureRect = $BottomPanel/Row/TargetCard/TargetPortrait
@onready var _target_name: Label = $BottomPanel/Row/TargetInfo/TargetName
@onready var _target_stats: Label = $BottomPanel/Row/TargetInfo/TargetStats
@onready var _hit_player: AudioStreamPlayer = $HitPlayer

var _is_elite: bool = false
var _is_boss: bool = false
var _enemy: Dictionary = {}
var _round: int = 0
var _turn_queue: Array = []
var _turn_index: int = 0
var _party: Array = []
## Stage units, index-aligned with _party / [_enemy].
var _hero_units: Array = []
var _enemy_units: Array = []
var _busy: bool = false
var _ended: bool = false


func _ready() -> void:
	_try_load_combat_bg()
	_party = GameState.party.duplicate(true)
	if GameState.mission_active and GameState.combat_context.has("enemy"):
		_enemy = (GameState.combat_context["enemy"] as Dictionary).duplicate(true)
		if not _enemy.has("hp"):
			_enemy["hp"] = int(_enemy.get("hp_max", 45))
		_enemy["dead"] = false
		_is_elite = bool(GameState.combat_context.get("is_elite", false))
		_is_boss = bool(GameState.combat_context.get("is_boss", false))
	else:
		_enemy = {
			"id": "espanto",
			"name": "Espanto del Sótano",
			"hp_max": 55,
			"hp": 55,
			"speed": 4,
			"dodge": 5,
			"accuracy": 8,
			"dead": false,
		}
	var tier := ""
	if _is_boss:
		tier = "Encuentro de jefe. "
	elif _is_elite:
		tier = "Enemigo de élite. "
	_log_line("%sCombate: derrota a %s o perece la cuadrilla." % [tier, _enemy.get("name", "el enemigo")])
	_build_stage()
	_update_target_card()
	if GameState.mission_active:
		_light_label.text = "Luz: %d" % GameState.mission_light
	_start_round()


func _try_load_combat_bg() -> void:
	var p := "res://assets/ui_bg/combat_bg.png"
	if ResourceLoader.exists(p):
		var tex := load(p) as Texture2D
		if tex != null:
			_bg.texture = tex
			_bg.visible = true
			return
	var img2 := Image.create(512, 512, false, Image.FORMAT_RGB8)
	img2.fill(Color(0.12, 0.05, 0.06))
	_bg.texture = ImageTexture.create_from_image(img2)
	_bg.visible = true


func _texture_from_res_path(res_path: String) -> Texture2D:
	if not ResourceLoader.exists(res_path):
		return null
	return load(res_path) as Texture2D


func _build_stage() -> void:
	# Party order = ranks 1..4. Rank 1 stands nearest the middle, so add rank 4 first.
	_hero_units.clear()
	for h in _party:
		var u = BattleUnitScript.new()
		u.setup(h, true, "res://assets/portraits/%s.png" % str(h.get("hero_id", "")))
		_hero_units.append(u)
	for k in range(_hero_units.size() - 1, -1, -1):
		_hero_row.add_child(_hero_units[k])
	_enemy_units.clear()
	var eu = BattleUnitScript.new()
	eu.setup(_enemy, false, "res://assets/enemies/%s.png" % str(_enemy.get("id", "")))
	_enemy_units.append(eu)
	_enemy_row.add_child(eu)
	eu.set_targeted(true)


func _unit_for_hero(hero: Dictionary):
	for k in _party.size():
		if is_same(_party[k], hero):
			return _hero_units[k]
	return null


func _refresh_units() -> void:
	for u in _hero_units:
		u.refresh()
	for u in _enemy_units:
		u.refresh()


func _set_active(actor: Dictionary) -> void:
	for k in _party.size():
		_hero_units[k].set_active(is_same(_party[k], actor))
	for u in _enemy_units:
		if is_same(u.data, actor):
			u.set_active(true)
		else:
			u.set_targeted(not u.is_dead())


func _show_hero_card(hero: Dictionary) -> void:
	_hero_portrait.texture = _texture_from_res_path("res://assets/portraits/%s.png" % str(hero.get("hero_id", "")))
	_hero_name.text = str(hero.get("name", "?"))
	var lines: PackedStringArray = PackedStringArray()
	lines.append("PV %d/%d" % [int(hero.get("hp", 0)), int(hero.get("hp_max", 0))])
	lines.append("Estrés %d/200" % int(hero.get("stress", 0)))
	lines.append("Precisión %d · Crítico %d%%" % [int(hero.get("accuracy", 0)), int(hero.get("crit", 0))])
	lines.append("Esquiva %d · Velocidad %d" % [int(hero.get("dodge", 0)), int(hero.get("speed", 0))])
	var aff: String = str(hero.get("affliction_id", ""))
	if aff != "":
		lines.append("Quebranto: %s" % aff.capitalize())
	_hero_stats.text = "\n".join(lines)


func _update_target_card() -> void:
	_target_portrait.texture = _texture_from_res_path("res://assets/enemies/%s.png" % str(_enemy.get("id", "")))
	var tag := ""
	if _is_boss:
		tag = "JEFE"
	elif _is_elite:
		tag = "ÉLITE"
	_target_name.text = str(_enemy.get("name", "?"))
	var lines: PackedStringArray = PackedStringArray()
	if tag != "":
		lines.append(tag)
	lines.append("PV %d/%d" % [int(_enemy.get("hp", 0)), int(_enemy.get("hp_max", 0))])
	lines.append("Esquiva %d · Velocidad %d" % [int(_enemy.get("dodge", 0)), int(_enemy.get("speed", 0))])
	_target_stats.text = "\n".join(lines)


func _party_snapshot() -> Array:
	var out: Array = []
	for h in _party:
		out.append({"hp": int(h.get("hp", 0)), "dead": bool(h.get("dead", false)), "borde": bool(h.get("al_borde", false))})
	return out


## Play hurt/death on every hero whose HP dropped (or who fell) since `before`.
func _animate_party_changes(before: Array) -> void:
	for k in _party.size():
		var h: Dictionary = _party[k]
		var b: Dictionary = before[k]
		if bool(h.get("dead", false)) and not bool(b["dead"]):
			await _hero_units[k].play_death()
		elif int(h.get("hp", 0)) < int(b["hp"]) or (bool(h.get("al_borde", false)) and not bool(b["borde"])):
			await _hero_units[k].play_hurt()
		elif int(h.get("hp", 0)) > int(b["hp"]):
			await _hero_units[k].play_heal()
		else:
			_hero_units[k].refresh()


func _animate_enemy_changes(hp_before: int) -> void:
	var eu = _enemy_units[0]
	if bool(_enemy.get("dead", false)) and hp_before > 0:
		await eu.play_death()
	elif int(_enemy.get("hp", 0)) < hp_before:
		await eu.play_hurt()
	_update_target_card()


func _try_play_hit_sound() -> void:
	for ext in [".ogg", ".wav"]:
		var p: String = "res://assets/audio/hit%s" % ext
		if ResourceLoader.exists(p):
			var st: Variant = load(p)
			if st is AudioStream:
				_hit_player.stream = st
				_hit_player.play()
			return


func _log_line(s: String) -> void:
	_log.append_text(s + "\n")


func _log_line_color(hex_no_hash: String, s: String) -> void:
	_log.append_text("[color=#%s]%s[/color]\n" % [hex_no_hash, s])


func _start_round() -> void:
	_round += 1
	_round_label.text = "Ronda: %d" % _round
	_roll_initiative_queue()
	_turn_index = 0
	_process_turn()


func _roll_initiative_queue() -> void:
	var entries: Array = []
	for h in _party:
		if h is Dictionary and not h.get("dead", false):
			var ini: int = CombatResolverScript.roll_initiative(int(h.get("speed", 3)), int(h.get("resolve_level", 0)))
			entries.append({"kind": "hero", "actor": h, "ini": ini, "spd": int(h.get("speed", 0)), "rl": int(h.get("resolve_level", 0))})
	if not _enemy.get("dead", false):
		var ein: int = CombatResolverScript.roll_initiative(int(_enemy.get("speed", 3)), 0)
		entries.append({"kind": "enemy", "actor": _enemy, "ini": ein, "spd": int(_enemy.get("speed", 0)), "rl": 0})
	entries.sort_custom(_sort_initiative)
	_turn_queue = entries
	_log_line("--- Iniciativa: " + ", ".join(_format_queue_names()))


func _sort_initiative(a: Dictionary, b: Dictionary) -> bool:
	if int(a["ini"]) != int(b["ini"]):
		return int(a["ini"]) > int(b["ini"])
	if int(a["spd"]) != int(b["spd"]):
		return int(a["spd"]) > int(b["spd"])
	if int(a["rl"]) != int(b["rl"]):
		return int(a["rl"]) > int(b["rl"])
	return randf() < 0.5


func _format_queue_names() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for e in _turn_queue:
		if e["kind"] == "enemy":
			out.append("%s(%d)" % [_enemy["name"], e["ini"]])
		else:
			var h: Dictionary = e["actor"]
			out.append("%s(%d)" % [h.get("name", "?"), e["ini"]])
	return out


func _process_turn() -> void:
	_refresh_units()
	_hide_actions()
	if _check_end():
		return
	while _turn_index < _turn_queue.size():
		var step: Dictionary = _turn_queue[_turn_index]
		if step["kind"] == "enemy":
			if not _enemy.get("dead", false):
				_actor_label.text = "Turno: %s" % _enemy["name"]
				_set_active(_enemy)
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
		_show_hero_card(hero)
		if StressSystemScript.hero_turn_blocked(hero):
			_log_line("%s no actúa (quebranto)." % hero.get("name", "?"))
			await get_tree().create_timer(0.6).timeout
			_turn_index += 1
			if _check_end():
				return
			continue
		_actor_label.text = "Turno: %s" % str(hero.get("name", "?"))
		_show_hero_actions(hero)
		return
	_start_round()


func _show_hero_actions(hero: Dictionary) -> void:
	_clear_skill_buttons()
	var shown := 0
	for sid in hero.get("skill_ids", []):
		var sk: Dictionary = GameState.get_skill(str(sid))
		if sk.is_empty():
			continue
		var b := Button.new()
		b.text = str(sk.get("name", sid))
		b.tooltip_text = _skill_tooltip(sk)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_on_skill_pressed.bind(sk))
		_skills_box.add_child(b)
		shown += 1
		if shown >= 4:
			break
	var pass_btn := Button.new()
	pass_btn.text = "Pasar"
	pass_btn.tooltip_text = "Termina el turno sin actuar."
	pass_btn.pressed.connect(_on_pass_pressed)
	_skills_box.add_child(pass_btn)


func _skill_tooltip(sk: Dictionary) -> String:
	match str(sk.get("kind", "")):
		"attack":
			return "Ataque: %d–%d daño" % [int(sk.get("damage_min", 0)), int(sk.get("damage_max", 0))]
		"heal":
			return "Curación: %d–%d PV" % [int(sk.get("heal_min", 0)), int(sk.get("heal_max", 0))]
		"buff":
			return "Alivia %d de estrés" % int(sk.get("self_stress_relief", 0))
	return ""


func _clear_skill_buttons() -> void:
	for c in _skills_box.get_children():
		c.queue_free()


func _hide_actions() -> void:
	_clear_skill_buttons()


func _first_skill_of_kind(hero: Dictionary, kind: String) -> Dictionary:
	for sid in hero.get("skill_ids", []):
		var sk: Dictionary = GameState.get_skill(str(sid))
		if sk.get("kind", "") == kind:
			return sk
	return {}


func _on_skill_pressed(skill: Dictionary) -> void:
	if _busy or _ended:
		return
	_busy = true
	_hide_actions()
	var hero: Dictionary = _turn_queue[_turn_index]["actor"]
	var hu = _unit_for_hero(hero)
	var kind := str(skill.get("kind", ""))
	var enemy_hp_before: int = int(_enemy.get("hp", 0))
	var party_before: Array = _party_snapshot()
	await hu.play_action("attack" if kind == "attack" else "cast")
	match kind:
		"attack":
			_resolve_hero_attack(hero, skill)
		"heal":
			_resolve_heal(hero, skill)
		"buff":
			_resolve_buff(hero, skill)
		_:
			_resolve_hero_attack(hero, _first_skill_of_kind(hero, "attack"))
	await _animate_enemy_changes(enemy_hp_before)
	await _animate_party_changes(party_before)
	_busy = false
	_turn_index += 1
	if _check_end():
		return
	_process_turn()


func _on_pass_pressed() -> void:
	if _busy or _ended:
		return
	var hero: Dictionary = _turn_queue[_turn_index]["actor"]
	_log_line("%s espera." % hero.get("name", "?"))
	_turn_index += 1
	_process_turn()


func _resolve_heal(hero: Dictionary, skill: Dictionary) -> void:
	var mn: int = int(skill.get("heal_min", 2))
	var mx: int = int(skill.get("heal_max", mn))
	var amt: int = randi_range(mn, mx)
	hero["hp"] = mini(int(hero["hp"]) + amt, int(hero["hp_max"]))
	_log_line("%s usa %s (+ %d HP)" % [hero.get("name", "?"), skill.get("name", "?"), amt])


func _resolve_buff(hero: Dictionary, skill: Dictionary) -> void:
	var rel: int = int(skill.get("self_stress_relief", 5))
	for x in StressSystemScript.add_stress(hero, -rel):
		_log_line(x)
	_log_line("%s usa %s (estrés -%d)" % [hero.get("name", "?"), skill.get("name", "?"), rel])


func _resolve_hero_attack(hero: Dictionary, skill: Dictionary) -> void:
	var ff: Dictionary = StressSystemScript.ira_ciega_friendly_fire_target(hero, _party)
	if not ff.is_empty():
		var fdmg: int = StressSystemScript.friendly_fire_damage()
		_apply_damage_to_hero(ff, fdmg)
		_log_line_color("cc7744", "%s (ira ciega) hiere a %s por %d" % [hero.get("name", "?"), ff.get("name", "?"), fdmg])
		for x in StressSystemScript.add_stress(hero, 4):
			_log_line(x)
		return
	var sk_acc: int = int(skill.get("skill_accuracy", 0))
	var p: float = CombatResolverScript.hit_chance(int(hero.get("accuracy", 5)), sk_acc, int(_enemy.get("dodge", 5)))
	if randf() > p:
		_log_line("%s falla %s." % [hero.get("name", "?"), skill.get("name", "")])
		for x in StressSystemScript.add_stress(hero, 3):
			_log_line(x)
		return
	var raw: int = CombatResolverScript.roll_damage(skill)
	var crit: bool = CombatResolverScript.roll_crit(int(hero.get("crit", 5)), 0)
	var dmg: int = CombatResolverScript.resolve_attack_damage(raw, crit)
	_apply_damage_to_enemy(dmg, crit)
	_try_play_hit_sound()
	if crit:
		_log_line_color("ddbb55", "%s — %s CRÍTICO por %d" % [hero.get("name", "?"), skill.get("name", "?"), dmg])
		for x in StressSystemScript.add_stress(hero, 5):
			_log_line(x)
	else:
		_log_line("%s — %s por %d" % [hero.get("name", "?"), skill.get("name", "?"), dmg])


func _apply_damage_to_enemy(dmg: int, _crit: bool) -> void:
	_enemy["hp"] = int(_enemy["hp"]) - dmg
	if int(_enemy["hp"]) <= 0:
		_enemy["hp"] = 0
		_enemy["dead"] = true


func _enemy_turn() -> void:
	var living: Array = []
	for h in _party:
		if h is Dictionary and not h.get("dead", false):
			living.append(h)
	if living.is_empty():
		return
	var target: Dictionary = living[randi() % living.size()]
	var skill: Dictionary = {"damage_min": 4, "damage_max": 9, "skill_accuracy": 0}
	var party_before: Array = _party_snapshot()
	await _enemy_units[0].play_action("attack")
	var p: float = CombatResolverScript.hit_chance(int(_enemy.get("accuracy", 8)), int(skill.get("skill_accuracy", 0)), int(target.get("dodge", 5)))
	if randf() > p:
		_log_line("%s falla el zarpazo." % _enemy["name"])
		return
	var raw: int = CombatResolverScript.roll_damage(skill)
	var dmg: int = raw
	_apply_damage_to_hero(target, dmg)
	_try_play_hit_sound()
	_log_line("%s golpea a %s por %d" % [_enemy["name"], target.get("name", "?"), dmg])
	for x in StressSystemScript.add_stress(target, 5):
		_log_line(x)
	await _animate_party_changes(party_before)


func _apply_damage_to_hero(hero: Dictionary, dmg: int) -> void:
	if hero.get("dead", false):
		return
	var cur: int = int(hero["hp"])
	var nh: int = cur - dmg
	if nh > 0:
		hero["hp"] = nh
		return
	if not hero.get("al_borde", false):
		hero["al_borde"] = true
		hero["hp"] = 0
		_log_line_color("dd8844", "%s está en Al Borde!" % hero.get("name", "?"))
		return
	hero["borde_checks"] = int(hero.get("borde_checks", 0)) + 1
	if CombatResolverScript.roll_death_save():
		_log_line("%s resiste en Al Borde." % hero.get("name", "?"))
		hero["hp"] = 1
		hero["al_borde"] = false
	else:
		hero["dead"] = true
		hero["hp"] = 0
		_log_line_color("cc4444", "%s ha caído." % hero.get("name", "?"))


func _living_heroes() -> int:
	var n := 0
	for h in _party:
		if h is Dictionary and not h.get("dead", false):
			n += 1
	return n


func _check_end() -> bool:
	if _ended:
		return true
	if _enemy.get("dead", false):
		_log_line_color("66aa66", "Victoria. El espanto se disuelve.")
		_finish_mission(true)
		return true
	if _living_heroes() <= 0:
		_log_line_color("aa4444", "Derrota. La hacienda guarda silencio.")
		_finish_mission(false)
		return true
	return false


func _finish_mission(victory: bool) -> void:
	_ended = true
	_hide_actions()
	_actor_label.text = "Victoria" if victory else "Derrota"
	await get_tree().create_timer(1.2).timeout
	if GameState.mission_active:
		GameState.combat_return_victory = victory
		GameState.combat_return_node_id = str(GameState.combat_context.get("node_id", ""))
	else:
		if victory:
			GameState.colones += 1200
			GameState.week += 1
	GameState.party = _party.duplicate(true)
	combat_finished.emit(victory)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		pass
