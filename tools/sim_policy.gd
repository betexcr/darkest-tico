extends RefCounted

## Hero combat policy shared by tools/sim_combat.gd and tools/playtest_campaign.gd.
## Drives a running CombatController through its public actions, the same calls the
## expedition screen's buttons make.
##   smart: heal the worst-hurt ally (Al Borde or under HEAL_BELOW of PV), calm the most
##          stressed one (CALM_AT), open with a self/party buff, else the attack with the best
##          expected damage (a likely kill first). With `use_items`, a hero who can't heal an
##          ally in trouble uses a healing item from the alforja instead.
##   basic: the first usable attack on the current target.
## Nothing to hit: smart uses any support skill that helps, then Moverse, then Guardia.

const CombatResolverScript := preload("res://scripts/domain/combat_resolver.gd")
const StatusEffectsScript := preload("res://scripts/domain/status_effects.gd")
const ItemEffectsScript := preload("res://scripts/domain/item_effects.gd")

## Smart policy: heal an ally below this share of PV (or Al Borde)…
const HEAL_BELOW := 0.4
## …and calm one at or above this stress.
const CALM_AT := 50

var cc  ## CombatController
var gs  ## GameState
var mode: String = "smart"
var use_items: bool = false
## "<class> · <skill or action>" -> times used (for reports).
var uses: Dictionary = {}


func _init(p_cc, p_gs, p_mode: String = "smart") -> void:
	cc = p_cc
	gs = p_gs
	mode = p_mode


func _count(hero: Dictionary, what: String) -> void:
	var key: String = "%s · %s" % [hero.get("class_name", "?"), what]
	uses[key] = int(uses.get(key, 0)) + 1


func act(hero: Dictionary) -> void:
	var usable: Array = []
	for sid in hero.get("skill_ids", []):
		var sk: Dictionary = gs.hero_skill(hero, str(sid))
		if not sk.is_empty() and cc.skill_usable(hero, sk):
			usable.append(sk)
	if mode == "smart" and _smart_support(hero, usable):
		return
	var best: Dictionary = {}
	var best_t: Dictionary = {}
	var best_score: float = -1.0
	for sk in usable:
		if str(sk.get("kind", "")) != "attack":
			continue
		if mode == "basic":
			best = sk
			best_t = cc.current_target(sk)
			break
		for t in cc.targets_for(sk):
			var s: float = attack_score(hero, sk, t)
			if s > best_score:
				best_score = s
				best = sk
				best_t = t
	if not best.is_empty():
		cc.target_enemy = best_t
		_count(hero, str(best.get("name", "?")))
		cc.use_skill(best)
		return
	if mode == "smart":
		# Nothing to hit: any support skill that does something beats standing still.
		for sk in usable:
			var who: Dictionary = _support_target(hero, sk)
			if not who.is_empty():
				_count(hero, str(sk.get("name", "?")))
				cc.use_skill(sk, who)
				return
	if usable.is_empty() or mode == "basic":
		var moves: Array = cc.move_options(hero)
		if not moves.is_empty():
			_count(hero, "Moverse")
			cc.move_hero(moves[0])
			return
	_count(hero, "Guardia")
	cc.guard()


## Heal the worst-hurt ally, calm the most stressed one, or open with a buff. True if acted.
func _smart_support(hero: Dictionary, usable: Array) -> bool:
	var living: Array = cc.party.filter(func(h): return not h.get("dead", false))
	var hurt: Dictionary = {}
	for h in living:
		if hurt.is_empty() or _hurt_key(h) < _hurt_key(hurt):
			hurt = h
	if not hurt.is_empty() and (bool(hurt.get("al_borde", false)) or float(hurt["hp"]) / float(hurt["hp_max"]) < HEAL_BELOW):
		for sk in usable:
			if int(sk.get("heal_min", 0)) > 0 and _reaches(sk, hero, hurt):
				_count(hero, str(sk.get("name", "?")))
				cc.use_skill(sk, hurt)
				return true
		if use_items and bool(hurt.get("al_borde", false)):
			var item: String = _heal_item()
			if item != "":
				_count(hero, "Alforja: %s" % gs.get_item(item).get("name", item))
				cc.use_item(item, hurt)
				return true
	var tense: Dictionary = {}
	for h in living:
		if tense.is_empty() or int(h.get("stress", 0)) > int(tense.get("stress", 0)):
			tense = h
	if not tense.is_empty() and int(tense.get("stress", 0)) >= CALM_AT:
		for sk in usable:
			if str(sk.get("kind", "")) != "attack" and int(sk.get("stress_relief", 0)) > 0 and _reaches(sk, hero, tense):
				_count(hero, str(sk.get("name", "?")))
				cc.use_skill(sk, tense)
				return true
	if int(cc._round) == 1:
		for sk in usable:
			if str(sk.get("kind", "")) == "buff" and str(sk.get("target", "self")) in ["self", "party"]:
				var ap = sk.get("self_applies", sk.get("applies", null))
				if ap is Dictionary and not StatusEffectsScript.has(hero, str(ap.get("status", ""))):
					_count(hero, str(sk.get("name", "?")))
					cc.use_skill(sk, hero)
					return true
	return false


## The biggest heal in the alforja that works in combat on an ally ("" if none).
func _heal_item() -> String:
	var best: String = ""
	var best_heal: int = 0
	for slot in gs.inventory:
		var it: Dictionary = gs.get_item(str(slot["id"]))
		if int(slot.get("qty", 0)) <= 0 or not ItemEffectsScript.is_usable(it, true) or str(it.get("target", "")) != "ally":
			continue
		var heal: int = int(it.get("effects", {}).get("heal", 0))
		if heal > best_heal:
			best_heal = heal
			best = str(slot["id"])
	return best


## Al Borde first, then the lowest share of PV.
func _hurt_key(h: Dictionary) -> float:
	return -1.0 if bool(h.get("al_borde", false)) else float(h["hp"]) / float(maxi(int(h["hp_max"]), 1))


func _reaches(sk: Dictionary, hero: Dictionary, ally: Dictionary) -> bool:
	match str(sk.get("target", "self")):
		"party", "ally":
			return true
		_:
			return is_same(hero, ally)


## Who a support skill would help right now ({} if nobody needs it).
func _support_target(hero: Dictionary, sk: Dictionary) -> Dictionary:
	if str(sk.get("kind", "")) == "attack":
		return {}
	for h in cc.party:
		if h.get("dead", false) or not _reaches(sk, hero, h):
			continue
		if int(sk.get("heal_min", 0)) > 0 and int(h["hp"]) < int(h["hp_max"]):
			return h
		if int(sk.get("stress_relief", 0)) > 0 and int(h.get("stress", 0)) > 0:
			return h
	return {}


## Expected damage of `sk` on `t`; a likely kill is worth more, then the weaker target.
func attack_score(hero: Dictionary, sk: Dictionary, t: Dictionary) -> float:
	var avg: float = (int(sk.get("damage_min", 1)) + int(sk.get("damage_max", sk.get("damage_min", 1)))) / 2.0 + int(hero.get("dmg_bonus", 0))
	if StatusEffectsScript.has(t, "fichado"):
		avg *= 1.0 + int(sk.get("vs_marked_pct", 0)) / 100.0
	var el: String = str(hero.get("element", ""))
	if el != "" and t.get("elements", null) is Dictionary:
		avg *= float(t["elements"].get(el, 1.0))
	var acc: int = int(hero.get("accuracy", 0)) + StatusEffectsScript.stat(hero, "accuracy") + load("res://scripts/domain/light_system.gd").val(gs.mission_light, "hero_accuracy")
	var dod: int = int(t.get("dodge", 0)) + StatusEffectsScript.stat(t, "dodge")
	var exp_dmg: float = avg * CombatResolverScript.hit_chance(acc, int(sk.get("skill_accuracy", 0)), dod)
	var kill: float = 100.0 if avg >= float(t.get("hp", 0)) else 0.0
	return exp_dmg + kill - float(t.get("hp", 0)) * 0.01
