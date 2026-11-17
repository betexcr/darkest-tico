extends SceneTree

## Iglesia Vieja + Cantina del Centro activities (doc 02 §7, P3-03): booking, slots, busy for
## the week, relief + Quebranto cure at week end, side effects, extra week, save round trip.
##   godot --headless --path . -s tests/test_hub_activities.gd

const HubActivitiesScript := preload("res://scripts/domain/hub_activities.gd")

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
	gs.colones = 20000
	gs.active_event_id = ""

	# Data: two buildings, three activities each.
	_check(HubActivitiesScript.buildings().size() == 2, "two buildings (Iglesia, Cantina)")
	for b in HubActivitiesScript.buildings():
		_check(b.get("activities", []).size() == 3, "%s has 3 activities" % b.get("name", "?"))

	var a: Dictionary = gs.roster[0]
	var b: Dictionary = gs.roster[1]
	var c: Dictionary = gs.roster[2]
	var d: Dictionary = gs.roster[3]
	for h in gs.roster:
		h["stress"] = 80
	# Booking: pays, leaves the party, can't rejoin.
	var price: int = gs.activity_cost("iglesia", "meditacion")
	var c0: int = gs.colones
	var msg: String = gs.send_to_activity(a, "iglesia", "meditacion")
	_check(gs.colones == c0 - price, "booking pays %d ₡ (%s)" % [price, msg])
	_check(not gs.is_in_party(a) and HubActivitiesScript.is_pending(a), "booked hero leaves the cuadrilla")
	_check(gs.set_in_party(a, true) != "" and not gs.is_in_party(a), "a busy hero can't rejoin the cuadrilla")
	_check(gs.send_to_activity(a, "cantina", "guaro_conversa") != "", "a busy hero can't be booked twice")
	# Slots: Meditación has 1.
	_check(gs.activity_block_reason(b, "iglesia", "meditacion").contains("cupos"), "a full activity refuses more heroes")
	# Cancel refunds.
	c0 = gs.colones
	gs.cancel_activity(a)
	_check(gs.colones == c0 + price and not HubActivitiesScript.is_busy(a), "cancelling refunds and frees the hero")
	# Stress 0: nothing to relieve.
	a["stress"] = 0
	_check(gs.activity_block_reason(a, "cantina", "guaro_conversa") != "", "a hero with no stress is refused")
	a["stress"] = 80
	# Never every hero: someone must go out.
	_check(gs.send_to_activity(a, "cantina", "noche_de_fiesta") != "" and HubActivitiesScript.is_busy(a), "book A")
	gs.send_to_activity(b, "cantina", "noche_de_fiesta")
	gs.send_to_activity(c, "iglesia", "rezo")
	_check(HubActivitiesScript.is_busy(b) and HubActivitiesScript.is_busy(c), "book B and C")
	_check(gs.activity_block_reason(d, "iglesia", "rezo").contains("único libre"), "the last free hero can't be booked")
	# Town events: closed building, service price.
	var closed_id: String = ""
	for ev in gs.TownEventsScript.all():
		if gs.TownEventsScript.is_closed(ev, "iglesia"):
			closed_id = str(ev.get("id", ""))
			break
	gs.active_event_id = closed_id
	_check(closed_id != "" and gs.activity_block_reason(d, "iglesia", "penitencia").contains("cerrada"), "a closed Iglesia refuses bookings (%s)" % closed_id)
	gs.active_event_id = ""

	# Week end: relief, Quebranto cured, hero free again (no side effects: chance 0).
	for bld in HubActivitiesScript.buildings():
		for act in bld["activities"]:
			act["side_chance"] = 0.0
	c["affliction_id"] = "paranoia"
	var rel: Array = gs.activity_relief_range("iglesia", "rezo")
	gs.end_of_expedition_week()
	var cs: int = int(c["stress"])
	_check(cs <= 80 - int(rel[0]) and cs >= 80 - int(rel[1]), "Rezo relieves %d–%d stress (80 -> %d)" % [rel[0], rel[1], cs])
	_check(str(c["affliction_id"]) == "", "the activity clears the Quebranto")
	_check(not HubActivitiesScript.is_busy(a) and not HubActivitiesScript.is_busy(c), "heroes are free the next week")
	_check(gs.last_week_report.contains(str(c["name"])), "week report lists the activity")

	# Side effects, forced one kind at a time.
	var fiesta: Dictionary = HubActivitiesScript.activity("cantina", "noche_de_fiesta")
	var saved_fx: Array = fiesta["side_effects"]
	fiesta["side_chance"] = 1.0
	# Extra week.
	fiesta["side_effects"] = [{"kind": "extra_week", "weight": 1, "text": "%s sigue de fiesta."}]
	a["stress"] = 80
	gs.send_to_activity(a, "cantina", "noche_de_fiesta")
	gs.end_of_expedition_week()
	_check(HubActivitiesScript.is_busy(a) and not HubActivitiesScript.is_pending(a), "extra week: still busy, no slot held")
	_check(gs.set_in_party(a, true) != "", "extra week: still out of the cuadrilla")
	# Save round trip keeps the booking.
	var data: Dictionary = JSON.parse_string(JSON.stringify(gs.to_save_dict()))
	gs.apply_save_data(data)
	a = gs.roster.filter(func(h): return int(h["uid"]) == int(a["uid"]))[0]
	_check(HubActivitiesScript.is_busy(a) and int(a["busy"]["weeks_left"]) == 1, "save round trip keeps the booking")
	gs.end_of_expedition_week()
	_check(not HubActivitiesScript.is_busy(a), "free after the extra week")
	# Debuff: waits for the next expedition, then becomes a camp-style buff.
	fiesta["side_effects"] = [{"kind": "debuff", "weight": 1, "name": "Goma", "text": "%s con goma.", "mods": {"accuracy": -5}, "fights": 2}]
	a["stress"] = 80
	gs.send_to_activity(a, "cantina", "noche_de_fiesta")
	gs.end_of_expedition_week()
	_check(a.get("town_buffs", []).size() == 1, "debuff waits for the next expedition")
	gs.set_in_party(a, true)
	gs._prepare_party_for_mission()
	_check(a.get("camp_buffs", []).size() == 1 and gs.StatusEffectsScript.stat(a, "accuracy") == -5 and not a.has("town_buffs"),
		"at mission start it applies like a camp buff (-5 precisión)")
	# Lose colones never below 0; gain colones.
	fiesta["side_effects"] = [{"kind": "lose_colones", "weight": 1, "amount": [500, 500], "text": "%s pierde %d."}]
	a["stress"] = 80
	gs.send_to_activity(a, "cantina", "noche_de_fiesta")
	gs.colones = 300
	gs.end_of_expedition_week()
	_check(gs.colones == 0, "lost colones stop at 0")
	gs.colones = 20000
	fiesta["side_effects"] = [{"kind": "gain_colones", "weight": 1, "amount": [400, 400], "text": "%s gana %d."}]
	a["stress"] = 80
	gs.send_to_activity(a, "cantina", "noche_de_fiesta")
	c0 = gs.colones
	gs.end_of_expedition_week()
	_check(gs.colones == c0 + 400, "won colones go to the hacienda")
	# Lose item: one consumable from the alforja.
	fiesta["side_effects"] = [{"kind": "lose_item", "weight": 1, "text": "%s empeña %s."}]
	gs.inventory.clear()
	gs.add_item("gallo_pinto", 3)
	a["stress"] = 80
	gs.send_to_activity(a, "cantina", "noche_de_fiesta")
	gs.end_of_expedition_week()
	_check(gs.item_count("gallo_pinto") == 2, "lose_item takes one consumable")
	fiesta["side_effects"] = saved_fx

	# Safety: if the only free hero dies, busy heroes come back.
	var party_ids: Array = gs.roster.map(func(h): return h)
	for h in party_ids:
		h["stress"] = 80
		h.erase("busy")
	fiesta["side_effects"] = [{"kind": "extra_week", "weight": 1, "text": "%s sigue."}]
	var r: Array = gs.roster.duplicate()
	gs.send_to_activity(r[0], "cantina", "noche_de_fiesta")
	gs.send_to_activity(r[1], "cantina", "noche_de_fiesta")
	gs.send_to_activity(r[2], "iglesia", "rezo")
	gs.activity_block_reason(r[3], "iglesia", "meditacion")
	HubActivitiesScript.activity("iglesia", "rezo")["side_chance"] = 1.0
	HubActivitiesScript.activity("iglesia", "rezo")["side_effects"] = [{"kind": "extra_week", "weight": 1, "text": "%s sigue."}]
	r[3]["dead"] = true
	gs.end_of_expedition_week()
	var free: Array = gs.roster.filter(func(h): return not HubActivitiesScript.is_busy(h))
	_check(gs.roster.size() == 3 and free.size() == 3, "nobody left free: busy heroes come back early")

	# Hub scene shows the panel.
	gs.reset_party_from_catalog()
	var hub = load("res://scenes/hacienda/hacienda_hub.tscn").instantiate()
	root.add_child(hub)
	await process_frame
	_check(hub._relief_boxes.size() == 2 and hub._relief_boxes.values().all(func(bx): return bx.get_child_count() == 4),
		"the Iglesia and Cantina windows each list their 3 activities under a header (P4-17)")
	hub.queue_free()

	print("%d failure(s)" % _fail)
	quit(1 if _fail > 0 else 0)
