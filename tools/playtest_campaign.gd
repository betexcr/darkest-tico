extends SceneTree

## Headless campaign playtest (P1-09). Plays whole campaigns week by week the way a careful
## player would, through the real expedition screen, and prints a journal plus summary tables.
##
##   godot --headless --path . -s tools/playtest_campaign.gd -- [options]
##
## Options (after the "--"):
##   --campaigns N     campaigns to play (default 3)
##   --weeks W         weeks (expeditions) per campaign (default 8)
##   --seed S          RNG seed (default 1)
##   --route R         full: visit every room, the boss last | direct: straight to the boss,
##                     through the camp (default full)
##   --difficulty ID   starting difficulty: aprendiz | veterano | campeon (default aprendiz);
##                     the bot moves up when a hero refuses (too seasoned)
##
## The player bot:
##   Hub: hires up to 4 living heroes (a 5th and 6th when colones ≥ HIRE_SPARE_AT), takes the 4
##        least stressed, orders them by their class's preferred position, heals them at the
##        EBAIS, pays the Iglesia when the party's average stress ≥ IGLESIA_AT, buys the region's
##        missing provisions, tops up agua de pipa and vendas, and after a won expedition buys
##        one Casa Comunal rank. It always keeps RESERVE colones.
##   Expedition: between rooms uses healing items under half PV, stress items at ≥ 50 stress
##        and a candle below Tenue; flees when 2 heroes are down; eats when hungry; disarms
##        traps at ≥ 50% (else passes with care); uses a curio's key item, else examines it;
##        camps at the fogata (best meal that leaves a travel meal, a watch first, then the
##        most stressed or hurt ally); fights with tools/sim_policy.gd "smart" + healing items.
## Like every -s script it never touches the owner's save (SaveService is off).

const SimPolicyScript := preload("res://tools/sim_policy.gd")
const BalanceScript := preload("res://scripts/domain/balance.gd")
const CampingSystemScript := preload("res://scripts/domain/camping_system.gd")
const LightSystemScript := preload("res://scripts/domain/light_system.gd")

const MAX_STEPS := 60000
const RESERVE := 1000
const HIRE_SPARE_AT := 4000
const IGLESIA_AT := 30
const RANK_AT := 2500
const HEAL_ITEMS := {"agua_pipa": 2, "venda_manta": 1}

var _gs
var _loader
var _scene: PackedScene
var _opts := {"campaigns": 3, "weeks": 8, "seed": 1, "route": "full", "difficulty": "aprendiz"}
var _finished: String = ""
var _uses: Dictionary = {}
var _all_rows: Array = []
var _all_fights: Array = []


func _initialize() -> void:
	Engine.time_scale = 20.0
	_run.call_deferred()


func _run() -> void:
	await process_frame
	_parse_args()
	seed(int(_opts["seed"]))
	_gs = root.get_node("GameState")
	_loader = load("res://scripts/domain/expedition_loader.gd")
	_scene = load("res://scenes/expedition/expedition_screen.tscn")
	print("## Campaign playtest — %d campaign(s) × %d weeks, route %s, %s, seed %d\n" % [
		int(_opts["campaigns"]), int(_opts["weeks"]), _opts["route"], _opts["difficulty"], int(_opts["seed"])])
	var t0: int = Time.get_ticks_msec()
	for c in int(_opts["campaigns"]):
		_new_campaign()
		var rows: Array = []
		for w in int(_opts["weeks"]):
			if _living_roster().is_empty() and _cheapest_recruit() < 0:
				print("Campaign %d ends in week %d: nobody left and no money to hire.\n" % [c + 1, _gs.week])
				break
			var row: Dictionary = await _play_week()
			row["campaign"] = c + 1
			rows.append(row)
			_all_rows.append(row)
		_print_campaign(c + 1, rows)
	_print_summary()
	print("Done in %.1f s." % ((Time.get_ticks_msec() - t0) / 1000.0))
	quit(0)


func _parse_args() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	var k: int = 0
	while k < a.size():
		var flag: String = a[k]
		var val: String = a[k + 1] if k + 1 < a.size() else ""
		match flag:
			"--campaigns", "--weeks", "--seed":
				_opts[flag.trim_prefix("--")] = int(val)
				k += 1
			"--route", "--difficulty":
				_opts[flag.trim_prefix("--")] = val
				k += 1
			_:
				push_warning("playtest_campaign: unknown option %s" % flag)
		k += 1


func _new_campaign() -> void:
	_gs.reset_party_from_catalog()
	_gs.reset_inventory_to_starter()
	_gs.colones = BalanceScript.int_of("hub.start_colones")
	_gs.week = 1
	_gs.graveyard = []
	_gs.active_event_id = ""
	_gs.event_flags = {}
	_gs.selected_difficulty_id = str(_opts["difficulty"])


# --- One week: hub, expedition, back ----------------------------------------------------

func _play_week() -> Dictionary:
	var row: Dictionary = {"week": _gs.week, "colones_start": _gs.colones, "event": str(_gs.active_event().get("name", "—")),
		"hunger": 0, "unfed": 0, "disarmed": 0, "careful": 0, "trap_hits": 0, "curios": 0, "camped": false,
		"items_used": 0, "fled": false}
	_hub(row)
	var lvl: Array = _gs.party.map(func(h): return int(h.get("resolve_level", 0)))
	row["party"] = "/".join(PackedStringArray(_gs.party.map(func(h): return _short(str(h.get("class_name", "?"))))))
	row["levels"] = "/".join(PackedStringArray(lvl.map(func(x): return str(x)))) + ", " + str(_gs.selected_difficulty_id)
	await _expedition(row)
	# What main.gd does when the party is back.
	_gs.last_expedition_summary = {}
	_gs.end_of_expedition_week()
	_gs.draw_town_event()
	row["colones_end"] = _gs.colones
	return row


func _hub(row: Dictionary) -> void:
	var c0: int = _gs.colones
	var log: PackedStringArray = PackedStringArray()
	# Hire to 4 living heroes; spares when rich.
	while _living_roster().size() < 4 or (_living_roster().size() < 6 and _gs.colones >= HIRE_SPARE_AT):
		var idx: int = _cheapest_recruit()
		if idx < 0:
			break
		var msg: String = _gs.hire_recruit(idx)
		if not msg.contains("se une"):
			break
		log.append(msg)
	row["hired"] = log.size()
	# Party: the 4 least stressed, in their classes' preferred order.
	var pool: Array = _living_roster()
	pool.sort_custom(func(a, b): return int(a.get("stress", 0)) < int(b.get("stress", 0)))
	var chosen: Array = pool.slice(0, 4)
	chosen.sort_custom(func(a, b): return _pref_rank(a) < _pref_rank(b))
	_gs.party = chosen
	# Seasoned heroes refuse easy expeditions (doc 01 §6): take the easiest one nobody refuses.
	var diffs: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/progression.json"))["difficulties"]
	for d in diffs:
		if _gs.party_refusals(str(d["id"])).is_empty():
			_gs.selected_difficulty_id = str(d["id"])
			break
	var spent_heal: int = 0
	for h in chosen:
		var cost: int = _gs.heal_cost(h)
		if cost > 0 and _gs.colones - cost >= RESERVE:
			_gs.heal_hero(h)
			spent_heal += cost
	row["ebais"] = spent_heal
	var avg_stress: float = 0.0
	for h in chosen:
		avg_stress += int(h.get("stress", 0))
	avg_stress /= maxf(chosen.size(), 1.0)
	row["iglesia"] = 0
	if avg_stress >= IGLESIA_AT and _gs.colones - _gs.iglesia_cost() >= RESERVE:
		row["iglesia"] = _gs.iglesia_cost()
		_gs.iglesia_misa_rapida()
	var before_prov: int = _gs.colones
	if not _gs.missing_provisions().is_empty():
		_gs.buy_missing_provisions()
	row["provisions"] = before_prov - _gs.colones
	var before_items: int = _gs.colones
	for id in HEAL_ITEMS:
		while _gs.item_count(id) < int(HEAL_ITEMS[id]) and _gs.colones - _gs.item_price(id) >= RESERVE:
			var had: int = _gs.item_count(id)
			_gs.buy_item(id)
			if _gs.item_count(id) == had:
				break
	row["heal_items"] = before_items - _gs.colones
	row["rank"] = ""
	if _last_result() == "objective" and _gs.colones >= RANK_AT:
		var best_h: Dictionary = {}
		var best_s: String = ""
		var best_c: int = 0
		for h in chosen:
			for sid in h.get("skill_ids", []):
				if _gs.skill_rank_block_reason(h, str(sid)) == "":
					var c: int = _gs.skill_rank_cost(h, str(sid))
					if best_s == "" or c < best_c:
						best_h = h
						best_s = str(sid)
						best_c = c
		if best_s != "" and _gs.colones - best_c >= RESERVE:
			_gs.buy_skill_rank(best_h, best_s)
			row["rank"] = "%s %s" % [_short(str(best_h.get("class_name", ""))), _gs.get_skill(best_s).get("name", best_s)]
	row["hub_spent"] = c0 - _gs.colones


func _last_result() -> String:
	return str(_all_rows[-1].get("result", "")) if not _all_rows.is_empty() else ""


func _living_roster() -> Array:
	return _gs.roster.filter(func(h): return not h.get("dead", false))


func _cheapest_recruit() -> int:
	var best: int = -1
	for k in _gs.recruit_pool.size():
		var c: int = _gs.hire_cost(_gs.recruit_pool[k])
		if c <= _gs.colones and (best < 0 or c < _gs.hire_cost(_gs.recruit_pool[best])):
			best = k
	return best


func _pref_rank(h: Dictionary) -> int:
	var ranks: Array = _gs.get_hero_template(str(h.get("hero_id", ""))).get("ranks", [4])
	var m: int = 4
	for r in ranks:
		m = mini(m, int(r))
	return m


func _short(class_name_: String) -> String:
	return class_name_.split(" ")[0]


# --- The expedition through the real screen ---------------------------------------------

func _expedition(row: Dictionary) -> void:
	var snap: Dictionary = {}
	for h in _gs.party:
		snap[int(h["uid"])] = str(h.get("affliction_id", "")) + "|" + str(h.get("virtud_id", ""))
	if not _gs.start_mission():
		row["result"] = "no start"
		return
	row["rooms_total"] = _gs.mission_nodes_index.size()
	_finished = ""
	var screen = _scene.instantiate()
	screen.expedition_finished.connect(func(reason: String): _finished = reason)
	root.add_child(screen)
	await process_frame
	var policy = SimPolicyScript.new(screen._combat, _gs, "smart")
	policy.use_items = true
	var fights: Array = []
	var on_over := func(v: bool):
		var ctx: Dictionary = _gs.combat_context
		var kind: String = "ambush" if bool(ctx.get("is_ambush", false)) else ("boss" if bool(ctx.get("is_boss", false)) else ("elite" if bool(ctx.get("is_elite", false)) else "combat"))
		fights.append({"kind": kind, "rounds": int(screen._combat._round), "won": v, "surprise": str(ctx.get("surprise", ""))})
	screen._combat.combat_over.connect(on_over)
	var moves: int = 0
	var steps: int = 0
	var room_done: String = ""
	while _finished == "" and steps < MAX_STEPS:
		steps += 1
		await process_frame
		match int(screen._mode):
			0:  # EXPLORE
				if room_done != _gs.current_node_id:
					room_done = _gs.current_node_id
					row["items_used"] += _use_items_between_rooms()
				if _gs.living_party_count() <= 2 and _gs.current_node_id != _gs.objective_node_id:
					row["fled"] = true
					screen._on_flee_pressed()
					continue
				var path: Array = _next_path()
				if path.size() >= 2:
					screen._on_room_clicked(str(path[1]))
					moves += 1
			1, 3:  # EVENT / ENDED
				_event_step(screen, row)
			2:  # COMBAT
				if screen._combat._awaiting_hero:
					var hero: Dictionary = screen._combat.active_hero()
					if not hero.is_empty() and screen._pending.is_empty():
						screen._clear_skills()
						_gs.equip_turn_hero = {}
						policy.act(hero)
	if _finished == "":
		_finished = "stuck"
		push_warning("playtest_campaign: expedition did not end in %d frames" % MAX_STEPS)
	for k in policy.uses:
		_uses[k] = int(_uses.get(k, 0)) + int(policy.uses[k])
	row["result"] = _finished
	row["moves"] = moves
	row["rooms_seen"] = _gs.visited_node_ids.size()
	row["fights"] = fights
	_all_fights.append_array(fights)
	row["light_end"] = _gs.mission_light
	var deaths: int = 0
	var breaks: PackedStringArray = PackedStringArray()
	var max_stress: int = 0
	for h in _gs.party:
		if h.get("dead", false):
			deaths += 1
		max_stress = maxi(max_stress, int(h.get("stress", 0)))
		var now: String = str(h.get("affliction_id", "")) + "|" + str(h.get("virtud_id", ""))
		if now != str(snap.get(int(h["uid"]), now)):
			breaks.append(str(h.get("affliction_id", "")) if str(h.get("affliction_id", "")) != "" else "+" + str(h.get("virtud_id", "")))
	row["deaths"] = deaths
	row["max_stress"] = max_stress
	row["breaks"] = ", ".join(breaks)
	row["loot"] = int(_gs.mission_ledger.get("loot_colones", 0)) + int(_gs.mission_ledger.get("objective_colones", 0))
	screen.queue_free()
	await process_frame


## Where to go next: the nearest room not visited yet (never through the boss), then the boss.
## Direct route: the camp first if it hasn't been used, then the boss.
func _next_path() -> Array:
	var boss: String = _gs.objective_node_id
	var start: String = _gs.current_node_id
	var want := func(id: String) -> bool:
		if id == boss:
			return false
		if str(_opts["route"]) == "direct":
			return str(_gs.mission_nodes_index[id].get("type", "")) == "camp" and _gs.camped_node_ids.is_empty() and _gs.can_camp_at(id)
		return not _gs.visited_node_ids.has(id)
	var prev: Dictionary = {start: ""}
	var queue: Array = [start]
	var found: String = ""
	while not queue.is_empty() and found == "":
		var cur: String = queue.pop_front()
		for nb in _loader.neighbors(_gs.mission_region_data, cur):
			var n: String = str(nb)
			if prev.has(n) or n == boss:
				continue
			prev[n] = cur
			if want.call(n):
				found = n
				break
			queue.append(n)
	if found == "":
		return _path_to(start, boss)
	var path: Array = [found]
	while str(prev[path[0]]) != "":
		path.push_front(prev[path[0]])
	return path


func _path_to(start: String, goal: String) -> Array:
	var prev: Dictionary = {start: ""}
	var queue: Array = [start]
	while not queue.is_empty():
		var cur: String = queue.pop_front()
		if cur == goal:
			break
		for nb in _loader.neighbors(_gs.mission_region_data, cur):
			if not prev.has(str(nb)):
				prev[str(nb)] = cur
				queue.append(str(nb))
	if not prev.has(goal):
		return []
	var path: Array = [goal]
	while str(prev[path[0]]) != "":
		path.push_front(prev[path[0]])
	return path


## Healing under half PV, calming at 50+ stress, a candle below Tenue. Returns items used.
func _use_items_between_rooms() -> int:
	var used: int = 0
	for h in _gs.party:
		if h.get("dead", false):
			continue
		if float(h["hp"]) / float(maxi(int(h["hp_max"]), 1)) < 0.5:
			used += _use_best(h, "heal", ["gallo_pinto"])
		if int(h.get("stress", 0)) >= 50:
			used += _use_best(h, "stress", [])
	if _gs.mission_light < int(LightSystemScript.tiers()[1]["min"]):
		var lead: Array = _gs.party.filter(func(x): return not x.get("dead", false))
		for id in ["candela_sebo", "caja_de_fosforos"]:
			if not lead.is_empty() and _gs.item_count(id) > 0 and _gs.item_block_reason_outside_combat(id, lead[0]) == "":
				_gs.use_item_outside_combat(id, lead[0])
				used += 1
				break
	return used


func _use_best(h: Dictionary, effect: String, skip: Array) -> int:
	var best: String = ""
	var best_v: int = 0
	for slot in _gs.inventory:
		var id: String = str(slot["id"])
		if skip.has(id) or int(slot.get("qty", 0)) <= 0 or _gs.item_block_reason_outside_combat(id, h) != "":
			continue
		var v: int = absi(int(_gs.get_item(id).get("effects", {}).get(effect, 0)))
		if v > best_v:
			best_v = v
			best = id
	if best == "":
		return 0
	_gs.use_item_outside_combat(best, h)
	return 1


func _buttons(screen) -> Array:
	return screen._event_actions.get_children().filter(func(b): return b is Button and not b.is_queued_for_deletion() and not b.disabled)


func _press(b: Button) -> void:
	b.pressed.emit()


func _event_step(screen, row: Dictionary) -> void:
	var bs: Array = _buttons(screen)
	if bs.is_empty():
		# Respite rows only (every skill used): sleep.
		return
	var by: Dictionary = {}
	for b in bs:
		by[b.text] = b
	var texts: Array = by.keys()
	var find := func(prefix: String):
		for t in texts:
			if str(t).begins_with(prefix):
				return by[t]
		return null
	# Hunger.
	var eat = find.call("Comer (")
	if eat != null or find.call("Aguantar el hambre") != null:
		row["hunger"] += 1
		if eat != null:
			_press(eat)
		else:
			row["unfed"] += 1
			var share = find.call("Repartir")
			_press(share if share != null else find.call("Aguantar el hambre"))
		return
	# Traps.
	var dis = find.call("Desarmar (")
	if dis != null:
		var pct: int = int(str(dis.text).get_slice("(", 1).get_slice("%", 0))
		var careful = find.call("Pasar con cuidado")
		if pct >= 50 or careful == null:
			row["disarmed"] += 1
			_press(dis)
		else:
			row["careful"] += 1
			_press(careful)
		return
	# Curios.
	if find.call("Examinar") != null:
		row["curios"] += 1
		var key = find.call("Usar ")
		_press(key if key != null else find.call("Examinar"))
		return
	# Camp.
	var camp = find.call("Acampar")
	if camp != null:
		row["camped"] = true
		_press(camp)
		return
	var meals: Array = texts.filter(func(t): return str(t).contains("gallo pinto):"))
	if not meals.is_empty():
		var food: int = _gs.item_count("gallo_pinto")
		var keep: int = _gs.living_party_count()
		var best = null
		var best_cost: int = -1
		var cheapest = null
		var cheapest_cost: int = 1 << 30
		for t in meals:
			var cost: int = int(str(t).get_slice("(", 1).get_slice(" ", 0))
			if cost < cheapest_cost:
				cheapest_cost = cost
				cheapest = by[t]
			if food - cost >= keep and cost > best_cost:
				best_cost = cost
				best = by[t]
		_press(best if best != null else cheapest)
		return
	if by.has("Dormir"):
		if not _camp_skill(screen):
			_press(by["Dormir"])
		return
	# Anything else (results, "Volver a la hacienda", "Calentarse"): the first option.
	_press(bs[0])


## Uses one respite skill (a watch first). False when nothing is left to use.
func _camp_skill(screen) -> bool:
	var living: Array = CampingSystemScript.living(_gs.party)
	var pick_user: Dictionary = {}
	var pick_sk: Dictionary = {}
	for h in living:
		for sk in CampingSystemScript.hero_skills(h):
			if not CampingSystemScript.can_use(h, sk, _gs.party, screen._camp_respite, screen._camp_used):
				continue
			if pick_sk.is_empty() or (bool(sk.get("prevent_ambush", false)) and not screen._camp_watch and not bool(pick_sk.get("prevent_ambush", false))):
				pick_user = h
				pick_sk = sk
	if pick_sk.is_empty():
		return false
	var ally: Dictionary = {}
	if str(pick_sk.get("target", "")) == "ally":
		var best: float = -1.0
		for h in living:
			if is_same(h, pick_user):
				continue
			var need: float = int(h.get("stress", 0)) + (1.0 - float(h["hp"]) / float(maxi(int(h["hp_max"]), 1))) * 100.0
			if need > best:
				best = need
				ally = h
		if ally.is_empty():
			return false
	screen._camp_use(pick_user, pick_sk, ally)
	return true


# --- Reports -----------------------------------------------------------------------------

func _print_campaign(c: int, rows: Array) -> void:
	print("### Campaign %d\n" % c)
	print("| Wk | Party (levels, difficulty) | Town event | Hub ₡ (prov / EBAIS / Iglesia) | Result | Rooms | Moves | Fights (rounds) | Deaths | Top stress | Breaks | Hunger (short) | Traps D/C | Loot ₡ | ₡ after |")
	print("|---:|---|---|---|---|---:|---:|---|---:|---:|---|---|---|---:|---:|")
	for r in rows:
		var f: Array = r.get("fights", [])
		var fr: PackedStringArray = PackedStringArray(f.map(func(x): return "%s%d%s" % [str(x["kind"])[0].to_upper() if x["kind"] != "combat" else "", int(x["rounds"]), "" if x["won"] else "✗"]))
		print("| %d | %s (%s) | %s | %d (%d / %d / %d)%s | %s%s | %d/%d | %d | %s | %d | %d | %s | %d (%d) | %d/%d | %d | %d |" % [
			int(r["week"]), r.get("party", ""), r.get("levels", ""), r.get("event", ""), int(r.get("hub_spent", 0)),
			int(r.get("provisions", 0)), int(r.get("ebais", 0)), int(r.get("iglesia", 0)),
			((" + hired %d" % int(r["hired"])) if int(r.get("hired", 0)) > 0 else "") + ((" + rank " + str(r["rank"])) if str(r.get("rank", "")) != "" else ""),
			r.get("result", "?"), " (camped)" if r.get("camped", false) else "",
			int(r.get("rooms_seen", 0)), int(r.get("rooms_total", 0)), int(r.get("moves", 0)),
			" ".join(fr), int(r.get("deaths", 0)), int(r.get("max_stress", 0)), r.get("breaks", ""),
			int(r.get("hunger", 0)), int(r.get("unfed", 0)), int(r.get("disarmed", 0)), int(r.get("careful", 0)),
			int(r.get("loot", 0)), int(r.get("colones_end", 0))])
	print("")


func _print_summary() -> void:
	var n: int = maxi(_all_rows.size(), 1)
	var res: Dictionary = {}
	var deaths: int = 0
	var breaks: int = 0
	var moves: int = 0
	var camped: int = 0
	for r in _all_rows:
		res[r["result"]] = int(res.get(r["result"], 0)) + 1
		deaths += int(r.get("deaths", 0))
		breaks += 0 if str(r.get("breaks", "")) == "" else str(r["breaks"]).split(", ").size()
		moves += int(r.get("moves", 0))
		camped += 1 if r.get("camped", false) else 0
	print("### Summary (%d expeditions)\n" % _all_rows.size())
	print("- Results: %s" % ", ".join(PackedStringArray(res.keys().map(func(k): return "%s %d" % [k, res[k]]))))
	print("- Deaths per expedition: %.2f. Quebrantos/Virtudes per expedition: %.2f. Moves per expedition: %.1f. Camped in %d." % [
		float(deaths) / n, float(breaks) / n, float(moves) / n, camped])
	var kinds: Dictionary = {}
	for f in _all_fights:
		var k: String = str(f["kind"])
		if not kinds.has(k):
			kinds[k] = {"n": 0, "won": 0, "rounds": 0, "long": 0, "max": 0}
		kinds[k]["n"] += 1
		kinds[k]["won"] += 1 if f["won"] else 0
		kinds[k]["rounds"] += int(f["rounds"])
		kinds[k]["long"] += 1 if int(f["rounds"]) > 8 else 0
		kinds[k]["max"] = maxi(int(kinds[k]["max"]), int(f["rounds"]))
	print("\n| Fight | Count | Won | Avg rounds | Over 8 rounds | Longest |")
	print("|---|---:|---:|---:|---:|---:|")
	for k in kinds:
		var s: Dictionary = kinds[k]
		print("| %s | %d | %.0f%% | %.1f | %d | %d |" % [k, s["n"], 100.0 * s["won"] / maxi(s["n"], 1), float(s["rounds"]) / maxi(s["n"], 1), s["long"], s["max"]])
	print("\nActions by class (top 3 each):\n")
	var by_class: Dictionary = {}
	for key in _uses:
		var cls: String = str(key).get_slice(" · ", 0)
		if not by_class.has(cls):
			by_class[cls] = []
		by_class[cls].append([str(key).get_slice(" · ", 1), int(_uses[key])])
	for cls in by_class:
		var arr: Array = by_class[cls]
		arr.sort_custom(func(a, b): return a[1] > b[1])
		var total: int = 0
		for e in arr:
			total += int(e[1])
		print("- %s (%d actions): %s" % [cls, total, ", ".join(PackedStringArray(arr.slice(0, 3).map(func(e): return "%s %d%%" % [e[0], roundi(100.0 * e[1] / maxi(total, 1))])))])
	print("")
