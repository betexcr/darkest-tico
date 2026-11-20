extends SceneTree

## Building upgrades + Reliquias del Abuelo + level-tiered prices (P3-14 / P3-16 / P3-18 /
## P3-21): buying and refusing, every track's effect, tier prices, Reliquia sources, saves.
##   godot --headless --path . -s tests/test_upgrades.gd

const UpgradesScript := preload("res://scripts/domain/building_upgrades.gd")
const CampingSystemScript := preload("res://scripts/domain/camping_system.gd")
const HubActivitiesScript := preload("res://scripts/domain/hub_activities.gd")
const BalanceScript := preload("res://scripts/domain/balance.gd")

var _fail: int = 0


func _check(cond: bool, what: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + what)
	if not cond:
		_fail += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var gs = root.get_node("GameState")
	gs.reset_party_from_catalog()
	gs.active_event_id = ""
	gs.building_levels = {}
	gs.reliquias = 0
	gs.colones = 50000

	# Data: every service building has tracks; a new campaign starts at the base values.
	for bid in ["casa_comunal", "iglesia", "cantina", "guardabosques"]:
		_check(not UpgradesScript.tracks(bid).is_empty(), "%s has upgrade tracks" % bid)
	_check(gs.skill_rank_cap() == 3, "a new campaign teaches up to rank 3")
	_check(gs.camp_class_skills_per_camp() == CampingSystemScript.class_skills_per_camp(), "no extra fogata skills yet")

	# Buying: Reliquias and colones both needed, levels in order, max level refused.
	_check(gs.buy_upgrade("casa_comunal", "maestria_oficio").contains("Reliquias"), "no Reliquias: refused")
	gs.reliquias = 20
	gs.colones = 100
	_check(gs.buy_upgrade("casa_comunal", "maestria_oficio").contains("No alcanza"), "no colones: refused")
	gs.colones = 50000
	var c0: int = gs.colones
	var cost: Dictionary = UpgradesScript.next_cost(gs.building_levels, "casa_comunal", "maestria_oficio")
	gs.buy_upgrade("casa_comunal", "maestria_oficio")
	_check(gs.upgrade_level("casa_comunal", "maestria_oficio") == 1 and gs.reliquias == 20 - int(cost["reliquias"]) \
		and gs.colones == c0 - int(cost["colones"]), "a level costs its Reliquias and colones")
	_check(gs.skill_rank_cap() == 4, "Maestría 1: rank cap 4")
	gs.buy_upgrade("casa_comunal", "maestria_oficio")
	_check(gs.skill_rank_cap() == 5, "Maestría 2: rank cap 5")
	_check(gs.buy_upgrade("casa_comunal", "maestria_oficio").contains("máximo"), "max level: refused")

	# A town event that closes the building blocks its upgrades too.
	gs.active_event_id = _closing_event(gs, "iglesia")
	if gs.active_event_id != "":
		_check(gs.upgrade_block_reason("iglesia", "iglesia_limosna").contains("cerrado"), "closed building: no upgrades this week")
	gs.active_event_id = ""

	# Plan de Formación: rank prices down.
	var hero: Dictionary = gs.party[0]
	hero["resolve_level"] = 6
	var sid: String = str(hero["skill_ids"][0])
	var full: int = gs.skill_rank_cost(hero, sid)
	gs.building_levels["casa_comunal"]["plan_formacion"] = 3
	_check(gs.skill_rank_cost(hero, sid) == int(round(full * 0.5)), "Plan de Formación 3: ranks at half price (%d → %d)" % [full, gs.skill_rank_cost(hero, sid)])

	# P3-14: Iglesia / Cantina / EBAIS prices by resolve tier.
	var low: Dictionary = gs.party[1]
	var high: Dictionary = gs.party[2]
	low["resolve_level"] = 0
	high["resolve_level"] = 5
	var m: Array = BalanceScript.arr("hub.tier_price_mult")
	var base: int = gs.activity_cost("iglesia", "rezo")
	_check(gs.activity_cost("iglesia", "rezo", low) == base, "level 0 pays the base Iglesia price")
	_check(gs.activity_cost("iglesia", "rezo", high) == int(round(base * float(m[2]))), "level 5 pays ×%s" % m[2])
	low["hp"] = int(low["hp_max"]) - 10
	high["hp"] = int(high["hp_max"]) - 10
	_check(gs.heal_cost(high) == int(round(gs.heal_cost(low) * float(m[2]))), "EBAIS: the same wound costs ×%s at level 5" % m[2])

	# P3-18: cheaper, more relief, more slots.
	var base_slots: int = gs.activity_slots("cantina", "juegos_de_azar")
	var base_rel: Array = gs.activity_relief_range("cantina", "juegos_de_azar")
	gs.building_levels["cantina"] = {"cantina_fiado": 3, "cantina_alivio": 3, "cantina_corredor": 2}
	_check(gs.activity_cost("cantina", "juegos_de_azar", low) == int(round(HubActivitiesScript.activity("cantina", "juegos_de_azar")["cost"] * 0.7)), "Cuenta al Fiado 3: -30% at the Cantina")
	_check(gs.activity_slots("cantina", "juegos_de_azar") == base_slots + 2, "Corredor Techado 2: +2 slots")
	var rel: Array = gs.activity_relief_range("cantina", "juegos_de_azar")
	_check(int(rel[1]) > int(base_rel[1]), "Marimba de Planta 3: more relief (%s → %s)" % [base_rel, rel])
	_check(gs.activity_cost("iglesia", "rezo", low) == base, "Cantina upgrades don't touch the Iglesia")

	# P3-21: Guardabosques.
	var learn: int = gs.camp_price("learn")
	var swap: int = gs.camp_price("shared_swap")
	gs.building_levels["guardabosques"] = {"guia_supervivencia": 1, "entrenamiento_patrulla": 2}
	_check(gs.camp_price("learn") == int(round(learn * 0.5)) and gs.camp_price("shared_swap") == swap, "Patrulla 2: lessons half price, the shared swap unchanged")
	_check(gs.camp_class_skills_per_camp() == CampingSystemScript.class_skills_per_camp() + 1, "Guía: one more class skill per fogata")
	var camper: Dictionary = gs.party[3]
	camper["camp_known"] = CampingSystemScript.class_pool(camper).map(func(sk): return str(sk["id"]))
	camper["camp_fixed"] = ""
	_check(CampingSystemScript.deal_hand(camper, gs.camp_extra_class_skills()).size() == CampingSystemScript.deal_hand(camper).size() + 1, "the fogata hand grows by one")

	# Reliquias: objective by difficulty, curio outcome, elite chance.
	gs.reliquias = 0
	gs.selected_difficulty_id = "veterano"
	for h in gs.party:
		h["resolve_level"] = 3
	_check(gs.start_mission(), "a Veterano expedition starts")
	gs.apply_objective_rewards()
	_check(gs.reliquias == 2 and int(gs.mission_ledger.get("reliquias", 0)) == 2, "Veterano objective: +2 Reliquias (in the ledger)")
	gs.apply_event_outcome({"reliquias": 1})
	_check(gs.reliquias == 3, "a curio outcome gives a Reliquia")
	BalanceScript.override("upgrades.elite_reliquia_chance", 1.0)
	_check(gs.roll_elite_reliquia() != "" and gs.reliquias == 4, "elite win at chance 1: +1 Reliquia")
	BalanceScript.override("upgrades.elite_reliquia_chance", 0.0)
	_check(gs.roll_elite_reliquia() == "" and gs.reliquias == 4, "…at chance 0: none")
	BalanceScript.reset()
	gs.end_mission_abandon()
	gs.selected_difficulty_id = "aprendiz"

	# Save round trip, and v14 saves: Maestría from the best rank already bought.
	var d: Dictionary = gs.to_save_dict()
	var lv_before: Dictionary = gs.building_levels.duplicate(true)
	gs.building_levels = {}
	gs.reliquias = 0
	gs.apply_save_data(JSON.parse_string(JSON.stringify(d)))
	_check(gs.reliquias == 4 and gs.building_levels == lv_before, "Reliquias and upgrade levels survive a save")
	var old: Dictionary = JSON.parse_string(JSON.stringify(d))
	old.erase("reliquias")
	old.erase("building_levels")
	old["version"] = 14
	old["roster"][0]["skill_ranks"] = {str(old["roster"][0]["skill_ids"][0]): 5}
	gs.apply_save_data(old)
	_check(gs.skill_rank_cap() == 5 and gs.reliquias == 0, "v14 save with a rank-5 skill: Maestría maxed, no Reliquias")
	old["roster"][0]["skill_ranks"] = {}
	gs.apply_save_data(old)
	_check(gs.skill_rank_cap() == 3, "v14 save without high ranks: cap 3")

	print("%d failure(s)" % _fail)
	quit(1 if _fail > 0 else 0)


## A town event id that closes `building` (or "" if none does).
func _closing_event(gs, building: String) -> String:
	for e in gs.TownEventsScript.data().get("events", []):
		if (e.get("effects", {}).get("closed", []) as Array).has(building):
			return str(e["id"])
	return ""
