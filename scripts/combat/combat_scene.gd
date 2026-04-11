extends Control

## Explicit preload so static methods resolve before global class registration (Godot 4.6+).
const CombatResolverScript := preload("res://scripts/domain/combat_resolver.gd")
const StressSystemScript := preload("res://scripts/domain/stress_system.gd")

signal combat_finished(victory: bool)

@onready var _log: RichTextLabel = $VBox/CombatLog
@onready var _enemy_label: Label = $VBox/EnemyLabel
@onready var _round_label: Label = $VBox/RoundLabel
@onready var _actor_label: Label = $VBox/ActorLabel
@onready var _btn_attack: Button = $VBox/Actions/BtnAttack
@onready var _btn_skill2: Button = $VBox/Actions/BtnSkill2
@onready var _bg: TextureRect = $BgTexture
@onready var _enemy_portrait: TextureRect = $VBox/PortraitRow/EnemyPortrait
@onready var _hero_portrait: TextureRect = $VBox/PortraitRow/HeroPortrait
@onready var _hit_player: AudioStreamPlayer = $HitPlayer

var _is_elite: bool = false
var _is_boss: bool = false
var _enemy: Dictionary = {}
var _round: int = 0
var _turn_queue: Array = []
var _turn_index: int = 0
var _party: Array = []


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
	_btn_attack.pressed.connect(_on_attack_pressed)
	_btn_skill2.pressed.connect(_on_skill2_pressed)
	var tier := ""
	if _is_boss:
		tier = "Encuentro de jefe. "
	elif _is_elite:
		tier = "Enemigo de élite. "
	_log_line("%sCombate: derrota a %s o perece la cuadrilla." % [tier, _enemy.get("name", "el enemigo")])
	_refresh_enemy_portrait()
	_hero_portrait.visible = false
	_start_round()


func _try_load_combat_bg() -> void:
	var p := "res://assets/ui_bg/combat_bg.png"
	if FileAccess.file_exists(p):
		var img := Image.new()
		if img.load(p) == OK:
			_bg.texture = ImageTexture.create_from_image(img)
			_bg.visible = true
			return
	var img2 := Image.create(512, 512, false, Image.FORMAT_RGB8)
	img2.fill(Color(0.12, 0.05, 0.06))
	_bg.texture = ImageTexture.create_from_image(img2)
	_bg.visible = true


func _texture_from_res_path(res_path: String) -> Texture2D:
	if not FileAccess.file_exists(res_path):
		return null
	var img := Image.new()
	if img.load(res_path) != OK:
		return null
	return ImageTexture.create_from_image(img)


func _set_rect_texture(rect: TextureRect, res_path: String) -> void:
	var tex: Texture2D = _texture_from_res_path(res_path)
	rect.texture = tex
	rect.visible = tex != null


func _refresh_enemy_portrait() -> void:
	var eid: String = str(_enemy.get("id", "espanto"))
	_set_rect_texture(_enemy_portrait, "res://assets/enemies/%s.png" % eid)


func _refresh_hero_portrait(hero: Dictionary) -> void:
	var hid: String = str(hero.get("hero_id", ""))
	if hid.is_empty():
		_hero_portrait.visible = false
		return
	_set_rect_texture(_hero_portrait, "res://assets/portraits/%s.png" % hid)


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
	_update_enemy_ui()
	_hide_actions()
	if _check_end():
		return
	while _turn_index < _turn_queue.size():
		var step: Dictionary = _turn_queue[_turn_index]
		if step["kind"] == "enemy":
			if not _enemy.get("dead", false):
				_actor_label.text = "Turno: %s" % _enemy["name"]
				_hero_portrait.visible = false
				_enemy_turn()
				_turn_index += 1
				if _check_end():
					return
				continue
			else:
				_turn_index += 1
				continue
		else:
			var hero: Dictionary = step["actor"]
			if hero.get("dead", false):
				_turn_index += 1
				continue
			if StressSystemScript.hero_turn_blocked(hero):
				_log_line("%s no actúa (quebranto)." % hero.get("name", "?"))
				_refresh_hero_portrait(hero)
				_turn_index += 1
				if _check_end():
					return
				continue
			_actor_label.text = "Turno: %s" % str(hero.get("name", "?"))
			_refresh_hero_portrait(hero)
			_show_hero_actions(hero)
			return
	_start_round()


func _show_hero_actions(hero: Dictionary) -> void:
	var atk := _first_skill_of_kind(hero, "attack")
	var atk2 := _second_skill(hero, atk)
	_btn_attack.text = atk.get("name", "Atacar") if not atk.is_empty() else "Atacar"
	_btn_attack.disabled = atk.is_empty()
	if not atk2.is_empty():
		_btn_skill2.text = atk2.get("name", "—")
		_btn_skill2.visible = true
		_btn_skill2.disabled = false
	else:
		_btn_skill2.visible = false


func _hide_actions() -> void:
	_btn_attack.disabled = true
	_btn_skill2.visible = false


func _first_skill_of_kind(hero: Dictionary, kind: String) -> Dictionary:
	for sid in hero.get("skill_ids", []):
		var sk: Dictionary = GameState.get_skill(str(sid))
		if sk.get("kind", "") == kind:
			return sk
	return {}


func _second_skill(hero: Dictionary, first: Dictionary) -> Dictionary:
	var seen_first := false
	for sid in hero.get("skill_ids", []):
		var sk: Dictionary = GameState.get_skill(str(sid))
		if sk.is_empty():
			continue
		if not seen_first:
			seen_first = true
			continue
		return sk
	return {}


func _on_attack_pressed() -> void:
	var step: Dictionary = _turn_queue[_turn_index]
	var hero: Dictionary = step["actor"]
	var skill: Dictionary = _first_skill_of_kind(hero, "attack")
	if skill.is_empty():
		return
	_resolve_hero_attack(hero, skill)
	_turn_index += 1
	if _check_end():
		return
	await get_tree().process_frame
	_process_turn()


func _on_skill2_pressed() -> void:
	var step: Dictionary = _turn_queue[_turn_index]
	var hero: Dictionary = step["actor"]
	var first: Dictionary = _first_skill_of_kind(hero, "attack")
	var sk2: Dictionary = _second_skill(hero, first)
	if sk2.is_empty():
		return
	var k := str(sk2.get("kind", ""))
	if k == "attack":
		_resolve_hero_attack(hero, sk2)
	elif k == "heal":
		_resolve_heal(hero, sk2)
	elif k == "buff":
		_resolve_buff(hero, sk2)
	else:
		_resolve_hero_attack(hero, _first_skill_of_kind(hero, "attack"))
	_turn_index += 1
	if _check_end():
		return
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
	if _living_heroes() <= 0:
		_check_end()


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


func _update_enemy_ui() -> void:
	var tag := ""
	if _is_boss:
		tag = " [JEFE]"
	elif _is_elite:
		tag = " [ÉLITE]"
	_enemy_label.text = "%s%s — HP %d/%d" % [_enemy["name"], tag, _enemy["hp"], _enemy["hp_max"]]


func _living_heroes() -> int:
	var n := 0
	for h in _party:
		if h is Dictionary and not h.get("dead", false):
			n += 1
	return n


func _check_end() -> bool:
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
