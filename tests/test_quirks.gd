extends SceneTree

## Quirks, diseases and the Clínica de Espantos (P3-06, doc 02 §6, doc 04 §3.5).
##   godot --headless --path . -s tests/test_quirks.gd

const QuirksScript := preload("res://scripts/domain/quirks.gd")
const StatusEffectsScript := preload("res://scripts/domain/status_effects.gd")

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
	var bal = load("res://scripts/domain/balance.gd")
	gs.reset_party_from_catalog()
	gs.active_event_id = ""
	var h: Dictionary = gs.party[0]
	h["quirks"] = []

	print("Catalog and stats")
	_check(QuirksScript.all_of("positive").size() >= 5 and QuirksScript.all_of("negative").size() >= 5 and QuirksScript.all_of("disease").size() >= 2, "positive, negative and disease quirks in data")
	var spd0: int = StatusEffectsScript.stat(h, "speed")
	QuirksScript.add(h, "madrugador")
	QuirksScript.add(h, "dengue")
	_check(StatusEffectsScript.stat(h, "speed") == spd0 + 2 - 2 and StatusEffectsScript.stat(h, "dmg_pct") == -10, "quirk and disease mods count in combat stats")
	QuirksScript.add(h, "madrugador")
	_check(QuirksScript.ids_of(h).count("madrugador") == 1, "no duplicates")

	print("Gaining")
	h["quirks"] = []
	for _k in 12:
		QuirksScript.gain(h, "positive")
	_check(QuirksScript.ids_of(h, "positive").size() == bal.int_of("quirks.max_positive"), "never more than %d positive quirks" % bal.int_of("quirks.max_positive"))
	var keep: String = str(QuirksScript.ids_of(h, "positive")[0])
	QuirksScript.set_locked(h, keep, true)
	for _k in 30:
		QuirksScript.gain(h, "positive")
	_check(QuirksScript.has(h, keep), "a locked quirk is never replaced")
	for id in QuirksScript.ids_of(h, "positive"):
		QuirksScript.set_locked(h, str(id), true)
	var before: Array = QuirksScript.ids_of(h, "positive")
	_check(QuirksScript.gain(h, "positive") == "" and QuirksScript.ids_of(h, "positive") == before, "all locked: nothing new")
	# After an expedition: everyone who went rolls (forced to 100%).
	h["quirks"] = []
	bal.override("quirks.positive_chance", 1.0)
	bal.override("quirks.negative_chance", 1.0)
	bal.override("quirks.disease_chance", 1.0)
	gs.end_of_expedition_week()
	var one_each: bool = gs.party.all(func(p): return QuirksScript.of(p).size() == 1)
	_check(one_each, "after an expedition each hero picks up exactly one quirk at 100% (never more)")
	_check(gs.last_week_report.contains(str(gs.party[0]["name"])), "the week report says who got what")
	bal.reset()
	gs.refresh_recruits()
	bal.override("quirks.recruit_positive_chance", 1.0)
	gs.refresh_recruits()
	_check(gs.recruit_pool.all(func(r): return not QuirksScript.ids_of(r, "positive").is_empty()), "recruits may arrive with quirks")
	bal.reset()

	print("Refusals")
	h["quirks"] = []
	h["stress"] = 60
	QuirksScript.add(h, "descreido")
	gs.colones = 20000
	_check(gs.activity_block_reason(h, "iglesia", "rezo").contains("no pone un pie"), "a Descreído won't go to the Iglesia")
	_check(not gs.activity_block_reason(h, "cantina", "guaro_conversa").contains("no pone un pie"), "…but the Cantina is fine")

	print("Clínica")
	h["quirks"] = []
	h["resolve_level"] = 0
	h.erase("clinic")
	QuirksScript.add(h, "mano_de_piedra")
	QuirksScript.add(h, "pachorra")
	QuirksScript.add(h, "pura_vida")
	QuirksScript.add(h, "tos_de_perro")
	gs.set_in_party(h, true)
	var c0: int = gs.colones
	var msg: String = gs.clinic_treat(h, "mano_de_piedra", "remove")
	var neg_cost: int = int(bal.arr("quirks.remove_negative_cost")[0])
	_check(not QuirksScript.has(h, "mano_de_piedra") and gs.colones == c0 - neg_cost, "removing a bad quirk costs %d ₡ at resolve 0 (%s)" % [neg_cost, msg])
	_check(gs.clinic_treat(h, "pachorra", "remove").contains("esta semana") and QuirksScript.has(h, "pachorra"), "one bad-quirk treatment per week")
	# P3-19 (owner 2026-11-17): the treatment keeps them home for the week.
	_check(gs.in_clinic(h) and not gs.is_in_party(h) and gs.set_in_party(h, true) != "", "treated: out of the cuadrilla and can't rejoin this week")
	_check(gs.activity_block_reason(h, "cantina", "guaro_conversa").contains("Clínica"), "…nor book the Iglesia/Cantina")
	var other: Dictionary = gs.party[0]
	other["stress"] = 50
	gs.send_to_activity(other, "cantina", "guaro_conversa")
	QuirksScript.add(other, "pachorra")
	_check(gs.clinic_options(other)[0]["actions"].all(func(a): return not a["enabled"] and str(a["reason"]).contains("Cantina")), "a hero booked at the Cantina can't be treated")
	gs.cancel_activity(other)
	c0 = gs.colones
	gs.clinic_treat(h, "tos_de_perro", "remove")
	_check(not QuirksScript.has(h, "tos_de_perro") and gs.colones == c0 - int(bal.arr("quirks.disease_cost")[0]), "diseases are cured any time")
	gs.clinic_treat(h, "pura_vida", "lock")
	_check(QuirksScript.is_locked(h, "pura_vida"), "a good quirk can be locked")
	_check(not gs.clinic_options(h).filter(func(o): return o["id"] == "pura_vida")[0]["actions"].any(func(a): return a["enabled"]), "…then it can't be removed (and the weekly good-quirk treatment is used)")
	gs.week += 1
	_check(not gs.in_clinic(h) and gs.set_in_party(h, true) == "", "next week they are free to go out")
	_check(gs.clinic_treat(h, "pachorra", "remove").begins_with("En la Clínica"), "next week the bad-quirk treatment is available again")
	# The last free hero can't be treated (someone has to go out).
	for r in gs.roster:
		if not is_same(r, h):
			r["clinic"] = {"week": gs.week, "stay": true}
	gs.week += 1
	for r in gs.roster:
		if not is_same(r, h):
			r["clinic"] = {"week": gs.week, "stay": true}
	QuirksScript.add(h, "tos_de_perro")
	_check(gs.clinic_options(h).filter(func(o): return o["id"] == "tos_de_perro")[0]["actions"][0]["reason"].contains("único libre"), "the last free hero can't be treated")
	for r in gs.roster:
		r.erase("clinic")
	h["resolve_level"] = 5
	_check(QuirksScript.cost("remove_negative", h) == int(bal.arr("quirks.remove_negative_cost")[2]), "prices go up with resolve (tier 3 at level 5)")
	gs.colones = 0
	QuirksScript.add(h, "dengue")
	_check(not gs.clinic_options(h).filter(func(o): return o["id"] == "dengue")[0]["actions"][0]["enabled"], "no money, no treatment")

	print("Save")
	gs.colones = 1000
	var data: Dictionary = JSON.parse_string(JSON.stringify(gs.to_save_dict()))
	gs.apply_save_data(data)
	var back: Dictionary = gs.roster.filter(func(r): return int(r["uid"]) == int(h["uid"]))[0]
	_check(QuirksScript.has(back, "pura_vida") and QuirksScript.is_locked(back, "pura_vida") and QuirksScript.has(back, "dengue"), "quirks and locks survive a save")
	var raw: Dictionary = data.duplicate(true)
	raw["roster"][0]["quirks"] = [{"id": "no_existe", "locked": true}, {"id": "madrugador"}]
	gs.apply_save_data(raw)
	_check(QuirksScript.ids_of(gs.roster[0]) == ["madrugador"], "unknown quirks are dropped on load")

	print("Hub")
	var hub = load("res://scenes/hacienda/hacienda_hub.tscn").instantiate()
	root.add_child(hub)
	await process_frame
	var clinic: Array = hub._clinic_box.get_children().filter(func(c): return c.has_meta("treat") and str(c.get_meta("treat").text).begins_with("Tratar"))
	_check(clinic.size() == gs.roster.size(), "the Clínica window has a card row with a Tratar button for every hero")
	var tip: String = load("res://scripts/ui/hero_card.gd").quirk_tooltip("pura_vida")
	_check(tip.begins_with("Pura vida — Rasgo bueno") and tip.contains("estrés"), "a quirk badge's tooltip has its name, kind, flavour and effect")
	var pc: Array = []
	for row in clinic:
		var stack: Array = [row]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			stack.append_array(n.get_children())
			if n is Control and str(n.tooltip_text).contains("Rasgo") or (n is Control and str(n.tooltip_text).contains("Enfermedad")):
				pc.append(n)
	var with_q: int = gs.roster.filter(func(h): return not QuirksScript.of(h).is_empty()).size()
	_check(with_q == 0 or not pc.is_empty(), "the Clínica rows list each hero's quirk badges, with tooltips")
	hub._show_clinic(gs.roster[0])
	await process_frame
	var dlg: Array = hub.get_children().filter(func(c): return c is AcceptDialog)
	_check(not dlg.is_empty() and dlg[0].title.begins_with("Clínica de Espantos"), "it opens the Clínica card")
	hub.queue_free()
	await process_frame

	print("%d failure(s)" % _fail)
	quit(1 if _fail > 0 else 0)
