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
##   --set path=value  override a data/balance.json number for this run (repeatable), as in
##                     tools/sim_combat.gd
##   --start-level N   start each campaign at a later point (P5-02f, to measure one difficulty
##   --start-ranks R   on its own): the starting heroes are resolve level N with every skill at
##   --start-gear K    Casa Comunal rank R and K pieces of equipment each (0-4: weapon, armor,
##   --start-colones C then accessories; the dearest the Pulpería sells), and the hacienda has
##                     C colones. Defaults: 0, 1, 0 and hub.start_colones.
##   --party a,b,c,d   force the class mix (hero ids from data/heroes.json): every campaign
##                     starts with exactly these four, nobody else is hired, and a hero who
##                     dies is replaced by one of the same class for its hire cost
##
## The player bot (P5-02a: it spends like a player):
##   Hub: hires up to SPARE_ROSTER living heroes (recruits are free), preferring
##        a recruit who isn't a second healer; picks the difficulty for which it can send the
##        fullest party with the fewest under-leveled heroes (_plan_party): heroes of that
##        range, the most seasoned first (those at REST_AT stress or more go last), at most
##        one dedicated healer (a class with a heal skill
##        that never stands in position 1), a hire to fill a place on the easiest difficulty,
##        under-leveled heroes last; orders them by preferred position, heals them at the EBAIS, books stressed heroes
##        left at home into the Iglesia/Cantina (≥ IGLESIA_AT or a Quebranto), buys what the region's provision kit
##        lacks (the full-exploration kit on --route full, the short one on direct),
##        tops up agua de pipa and vendas, carries one café chorreado per hero at ≥ STRESS_ITEM_AT
##        stress, then buys upgrades cheapest first until the colones run out: Casa Comunal
##        ranks, and one piece of equipment per hero a week for an empty slot (the dearest it
##        can afford). It always keeps RESERVE colones.
##   Expedition: between rooms uses healing items under half PV, stress items at ≥ 50 stress
##        and a candle below Tenue; goes home once a hero is dead or after a Retirada; eats when hungry; disarms
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
## Recruits are free (owner 2026-11-15): the bot keeps this many living heroes, two of them spares.
const SPARE_ROSTER := 6
## A hero at or above this stress stays home when a calmer one can go.
const REST_AT := 60
const IGLESIA_AT := 30
const HEAL_ITEMS := {"agua_pipa": 2, "venda_manta": 1}
const STRESS_ITEM := "cafe_chorreado"
const STRESS_ITEM_AT := 50
const EQUIP_SLOTS := ["weapon", "armor", "accessory1", "accessory2"]
## Hub spending by sink, in the order the report prints it.
const SINKS := ["provisions", "heal_items", "stress_items", "ebais", "iglesia", "ranks", "gear", "hires"]
const SINK_NAMES := {"provisions": "Provisions", "heal_items": "Healing items", "stress_items": "Stress items",
	"ebais": "EBAIS", "iglesia": "Iglesia", "ranks": "Skill ranks", "gear": "Equipment", "hires": "Hires"}

var _gs
var _loader
var _scene: PackedScene
var _opts := {"campaigns": 3, "weeks": 8, "seed": 1, "route": "full", "difficulty": "aprendiz", "set": [], "party": [],
	"start-level": 0, "start-ranks": 1, "start-gear": 0, "start-colones": -1}
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
	for kv in _opts["set"]:
		var parts: PackedStringArray = str(kv).split("=", true, 1)
		if parts.size() == 2:
			BalanceScript.override(parts[0], JSON.parse_string(parts[1]))
	_gs = root.get_node("GameState")
	for id in _opts["party"]:
		if _gs.get_hero_template(str(id)).is_empty():
			push_error("playtest_campaign: --party has no hero '%s' in data/heroes.json" % id)
			quit(1)
			return
	_loader = load("res://scripts/domain/expedition_loader.gd")
	_scene = load("res://scenes/expedition/expedition_screen.tscn")
	print("## Campaign playtest — %d campaign(s) × %d weeks, route %s, %s, seed %d%s%s\n" % [
		int(_opts["campaigns"]), int(_opts["weeks"]), _opts["route"], _opts["difficulty"], int(_opts["seed"]),
		((", party " + "/".join(PackedStringArray(_opts["party"]))) if not _opts["party"].is_empty() else "")
		+ ((", start at level %d, rank %d, %d gear" % [int(_opts["start-level"]), int(_opts["start-ranks"]), int(_opts["start-gear"])]) if int(_opts["start-level"]) > 0 or int(_opts["start-ranks"]) > 1 or int(_opts["start-gear"]) > 0 else ""),
		(", overrides " + ", ".join(PackedStringArray(_opts["set"]))) if not _opts["set"].is_empty() else ""])
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
			"--campaigns", "--weeks", "--seed", "--start-level", "--start-ranks", "--start-gear", "--start-colones":
				_opts[flag.trim_prefix("--")] = int(val)
				k += 1
			"--route", "--difficulty":
				_opts[flag.trim_prefix("--")] = val
				k += 1
			"--telemetry":
				# P5-01: write the game's telemetry log here (tools/telemetry_report.py reads it).
				var tel = root.get_node("Telemetry")
				tel.path = val
				tel.enabled = true
				k += 1
			"--set":
				_opts["set"].append(val)
				k += 1
			"--party":
				_opts["party"] = Array(val.split(",", false)).map(func(x): return str(x).strip_edges())
				k += 1
			_:
				push_warning("playtest_campaign: unknown option %s" % flag)
		k += 1


func _new_campaign() -> void:
	_gs.reset_party_from_catalog()
	_gs.reset_inventory_to_starter()
	_gs.colones = BalanceScript.int_of("hub.start_colones")
	_gs.reset_week_counters()
	_gs.week = 1
	_gs.graveyard = []
	_gs.active_event_id = ""
	_gs.event_flags = {}
	_gs.selected_difficulty_id = str(_opts["difficulty"])
	if not _opts["party"].is_empty():
		_gs.roster.clear()
		_gs.party.clear()
		for id in _opts["party"]:
			_add_forced_hero(str(id))
	# --start-level and friends: a party as it would be on reaching that difficulty.
	if int(_opts["start-colones"]) >= 0:
		_gs.colones = int(_opts["start-colones"])
	var rs = load("res://scripts/domain/resolve_system.gd")
	for h in _gs.roster:
		h["resolve_level"] = clampi(int(_opts["start-level"]), 0, rs.MAX_LEVEL)
		h["resolve_xp"] = rs.xp_for_level(int(h["resolve_level"]))
		if int(_opts["start-ranks"]) > 1:
			for sid in h.get("skill_ids", []):
				h["skill_ranks"][str(sid)] = int(_opts["start-ranks"])
		for slot in EQUIP_SLOTS.slice(0, clampi(int(_opts["start-gear"]), 0, EQUIP_SLOTS.size())):
			var worn: Array = h.get("equipment", {}).values() if h.get("equipment") is Dictionary else []
			var best: String = ""
			for id in _gs.all_item_ids():
				var sid: String = str(id)
				if _gs.is_equipment(sid) and _gs.slots_for(sid).has(slot) and not worn.has(sid) and (best == "" or _gs.item_price(sid) > _gs.item_price(best)):
					best = sid
			if best != "" and _gs.add_item(best, 1) > 0:
				_gs.equip(h, best, slot)
		_gs.recompute_stats(h)
		h["hp"] = int(h["hp_max"])


## --party: a fresh hero of that class joins the roster (no recruit pool involved).
func _add_forced_hero(hero_id: String) -> Dictionary:
	var h: Dictionary = _gs._instantiate_hero(_gs.get_hero_template(hero_id))
	h["uid"] = _gs._take_uid()
	_gs.roster.append(h)
	return h


# --- One week: hub, expedition, back ----------------------------------------------------

func _play_week() -> Dictionary:
	var row: Dictionary = {"week": _gs.week, "colones_start": _gs.colones, "event": str(_gs.active_event().get("name", "—")),
		"hunger": 0, "unfed": 0, "disarmed": 0, "careful": 0, "trap_hits": 0, "curios": 0, "camped": false,
		"items_used": 0, "fled": false}
	_hub(row)
	var lvl: Array = _gs.party.map(func(h): return int(h.get("resolve_level", 0)))
	row["party"] = "/".join(PackedStringArray(_gs.party.map(func(h): return _short(str(h.get("class_name", "?"))))))
	row["levels"] = "/".join(PackedStringArray(lvl.map(func(x): return str(x)))) + ", " + str(_gs.selected_difficulty_id)
	row["difficulty"] = str(_gs.selected_difficulty_id)
	await _expedition(row)
	# What main.gd does when the party is back.
	_gs.last_expedition_summary = {}
	_gs.end_of_expedition_week()
	_gs.draw_town_event()
	row["colones_end"] = _gs.colones
	return row


func _hub(row: Dictionary) -> void:
	var c0: int = _gs.colones
	for k in SINKS:
		row[k] = 0
	# Hire to 4 living heroes; spares when rich.
	var hired: int = 0
	if not _opts["party"].is_empty():
		# Forced class mix: replace the fallen with the same class, hire nobody else.
		for id in _opts["party"]:
			var want: int = _opts["party"].count(id)
			while _living_roster().filter(func(h): return str(h.get("hero_id", "")) == str(id)).size() < want:
				var cost: int = int(_gs.get_hero_template(str(id)).get("hire_cost", 0))
				if _gs.colones < cost:
					break
				_gs.colones -= cost
				_add_forced_hero(str(id))
				hired += 1
	else:
		while _living_roster().size() < SPARE_ROSTER:
			var idx: int = _pick_recruit()
			if idx < 0:
				break
			var msg: String = _gs.hire_recruit(idx)
			if not msg.contains("se une"):
				break
			hired += 1
	row["hired"] = hired
	row["hires"] = c0 - _gs.colones
	# Stress relief before picking the party (P3-03 after the 2026-11-17 merge; the group misa
	# is gone): heroes at REST_AT or with a Quebranto spend the week at the Iglesia/Cantina,
	# most stressed first, as long as 4 others can still go out (recruits are free: hire one
	# when needed). The rest of the week's bookings are made after the party is picked.
	if _opts["party"].is_empty():
		var frayed: Array = _living_roster().filter(func(h): return not _gs.hero_busy(h) \
			and (int(h.get("stress", 0)) >= REST_AT or str(h.get("affliction_id", "")) != ""))
		frayed.sort_custom(func(a, b): return int(a.get("stress", 0)) > int(b.get("stress", 0)))
		for h in frayed:
			if _living_roster().filter(func(x): return not _gs.hero_busy(x)).size() <= 4:
				var idx: int = _pick_recruit()
				if idx < 0 or not _gs.hire_recruit(idx).contains("se une"):
					break
				hired += 1
			if _book_relief(h) == "":
				break
		row["hired"] = hired
	# Difficulty and party together: for each difficulty, the best party of 4 the roster can
	# send (heroes of that range first, the most seasoned, at most one dedicated healer; then
	# under-leveled ones, the highest level first; heroes above the range refuse). On the
	# easiest difficulty a missing place can be filled by hiring. The bot takes the fullest
	# party, then the one with the fewest missing levels (a hire counts as 2), then the easier
	# expedition. So a lone veteran doesn't drag fresh recruits into an expedition above them,
	# and the bot never leaves with three heroes when it can send four.
	var diffs: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/progression.json"))["difficulties"]
	# Heroes away at the Iglesia/Cantina/Clínica this week can't go out (P3-03, P3-19).
	var pool: Array = _living_roster().filter(func(h): return not _gs.hero_busy(h))
	# A core team: the most seasoned heroes go, unless they are badly stressed (REST_AT); then
	# the calmer ones first. Spares are free, but ranks bought for six heroes are thinner.
	pool.sort_custom(func(a, b):
		var ra: bool = int(a.get("stress", 0)) >= REST_AT
		var rb: bool = int(b.get("stress", 0)) >= REST_AT
		if ra != rb:
			return rb
		if int(a.get("resolve_level", 0)) != int(b.get("resolve_level", 0)):
			return int(a.get("resolve_level", 0)) > int(b.get("resolve_level", 0))
		return int(a.get("stress", 0)) < int(b.get("stress", 0)))
	var chosen: Array = []
	if _opts["party"].is_empty():
		var best: Dictionary = {}
		for d in diffs:
			var plan: Dictionary = _plan_party(pool, _gs.selected_expedition(str(d["id"])))
			if best.is_empty() or int(plan["size"]) > int(best["size"]) or (int(plan["size"]) == int(best["size"]) and int(plan["cost"]) < int(best["cost"])):
				best = plan
		_gs.selected_difficulty_id = str(best["expedition"].get("id", _opts["difficulty"]))
		chosen = best["party"]
		for _k in int(best["hires"]):
			var idx: int = _pick_recruit()
			if idx < 0 or not _gs.hire_recruit(idx).contains("se une"):
				break
			hired += 1
			chosen.append(_gs.roster[-1])
		row["hired"] = hired
		row["hires"] = c0 - _gs.colones
		chosen.sort_custom(func(a, b): return _pref_rank(a) < _pref_rank(b))
		_gs.party = chosen
	else:
		chosen = pool.slice(0, 4)
		chosen.sort_custom(func(a, b): return _pref_rank(a) < _pref_rank(b))
		_gs.party = chosen
		# Forced class mix: the easiest expedition nobody refuses (doc 01 §6).
		for d in diffs:
			if _gs.party_refusals(str(d["id"])).is_empty():
				_gs.selected_difficulty_id = str(d["id"])
				break
	var mark: int = _gs.colones
	for h in chosen:
		var cost: int = _gs.heal_cost(h)
		if cost > 0 and _gs.colones - cost >= RESERVE:
			_gs.heal_hero(h)
	row["ebais"] = mark - _gs.colones
	var avg_stress: float = 0.0
	for h in chosen:
		avg_stress += int(h.get("stress", 0))
	avg_stress /= maxf(chosen.size(), 1.0)
	row["stress_start"] = avg_stress
	mark = _gs.colones
	# Iglesia Vieja / Cantina (P3-03; the group misa is gone, owner 2026-11-16): heroes left
	# at home with stress ≥ IGLESIA_AT or a Quebranto take the cheapest activity with a free
	# slot, keeping RESERVE (they skip this expedition anyway).
	for h in _living_roster():
		if chosen.has(h) or _gs.hero_busy(h) or (int(h.get("stress", 0)) < IGLESIA_AT and str(h.get("affliction_id", "")) == ""):
			continue
		_book_relief(h)
	row["iglesia"] = mark - _gs.colones
	mark = _gs.colones
	# The kit that fits the plan (P5-02e): every room, or straight to the boss.
	var kit: String = "full" if str(_opts["route"]) == "full" else "short"
	if not _gs.missing_provisions("", kit).is_empty():
		_gs.buy_missing_provisions("", kit)
	row["provisions"] = mark - _gs.colones
	mark = _gs.colones
	for id in HEAL_ITEMS:
		_stock(id, int(HEAL_ITEMS[id]))
	row["heal_items"] = mark - _gs.colones
	# One café per hero who leaves tense (the bot drinks it between rooms at ≥ 50 stress).
	mark = _gs.colones
	_stock(STRESS_ITEM, chosen.filter(func(h): return int(h.get("stress", 0)) >= STRESS_ITEM_AT).size())
	row["stress_items"] = mark - _gs.colones
	# Upgrades, cheapest first: the next Casa Comunal rank of any skill, or one piece of
	# equipment per hero a week (the dearest the bot can afford for the first empty slot).
	row["gear"] = 0
	row["gear_n"] = 0
	row["ranks"] = 0
	row["ranks_n"] = 0
	var geared: Array = []
	while true:
		var rank_h: Dictionary = {}
		var rank_s: String = ""
		var rank_c: int = 0
		for h in chosen:
			for sid in h.get("skill_ids", []):
				if _gs.skill_rank_block_reason(h, str(sid)) == "":
					var c: int = _gs.skill_rank_cost(h, str(sid))
					if _gs.colones - c >= RESERVE and (rank_s == "" or c < rank_c):
						rank_h = h
						rank_s = str(sid)
						rank_c = c
		var gear_h: Dictionary = {}
		var gear_id: String = ""
		var gear_slot: String = ""
		for h in chosen:
			if geared.has(h):
				continue
			var pick: Array = _gear_for(h)
			if not pick.is_empty() and (gear_id == "" or _gs.item_price(pick[0]) < _gs.item_price(gear_id)):
				gear_h = h
				gear_id = pick[0]
				gear_slot = pick[1]
		if rank_s == "" and gear_id == "":
			break
		mark = _gs.colones
		if gear_id == "" or (rank_s != "" and rank_c <= _gs.item_price(gear_id)):
			_gs.buy_skill_rank(rank_h, rank_s)
			if _gs.colones == mark:
				break
			row["ranks_n"] += 1
			row["ranks"] += mark - _gs.colones
		else:
			geared.append(gear_h)
			_gs.buy_item(gear_id)
			if _gs.colones == mark:
				continue
			if _gs.equip(gear_h, gear_id, gear_slot) != "":
				_gs.sell_item(gear_id)
				continue
			row["gear_n"] += 1
			row["gear"] += mark - _gs.colones
	row["hub_spent"] = c0 - _gs.colones


## Buys `id` until the alforja holds `want` of it (keeping RESERVE).
func _stock(id: String, want: int) -> void:
	while _gs.item_count(id) < want and _gs.colones - _gs.item_price(id) >= RESERVE:
		var had: int = _gs.item_count(id)
		_gs.buy_item(id)
		if _gs.item_count(id) == had:
			break


## [item id, slot]: the dearest piece of equipment the bot can afford for the hero's first
## empty slot (weapon, armor, then accessories; never the same accessory twice). [] if none.
func _gear_for(h: Dictionary) -> Array:
	var eq: Dictionary = h.get("equipment", {}) if h.get("equipment") is Dictionary else {}
	for slot in EQUIP_SLOTS:
		if str(eq.get(slot, "")) != "":
			continue
		var best: String = ""
		for id in _gs.all_item_ids():
			var sid: String = str(id)
			if not _gs.is_equipment(sid) or not _gs.slots_for(sid).has(slot) or eq.values().has(sid):
				continue
			if _gs.item_count(sid) > 0 or _gs.buy_block_reason(sid) != "" or _gs.colones - _gs.item_price(sid) < RESERVE:
				continue
			if best == "" or _gs.item_price(sid) > _gs.item_price(best):
				best = sid
		return [best, slot] if best != "" else []
	return []


## The best party of up to 4 for this expedition from `pool` (sorted, best pick first):
## {expedition, party, size, hires, cost}. `hires` = recruits to take on to reach 4 (only on
## an expedition that accepts level 0, and only as many as the colones and the beds allow);
## `size` counts them. `cost` = levels the under-leveled heroes are short, plus 2 per hire.
func _plan_party(pool: Array, expedition: Dictionary) -> Dictionary:
	var party: Array = []
	var has_healer: bool = false
	for h in pool:
		if party.size() >= 4:
			break
		if not _in_range(h, expedition):
			continue
		if _is_healer(h):
			if has_healer:
				continue
			has_healer = true
		party.append(h)
	var hires: int = 0
	if party.size() < 4 and int(expedition.get("min_level", 0)) <= 0:
		var prices: Array = _gs.recruit_pool.map(func(r): return _gs.hire_cost(r))
		prices.sort()
		var left: int = _gs.colones
		var beds: int = _gs.roster_cap() - _gs.roster.size()
		for c in prices:
			if party.size() + hires >= 4 or hires >= beds or int(c) > left:
				break
			left -= int(c)
			hires += 1
	var short: int = 0
	if party.size() + hires < 4:
		# A second healer or an under-leveled hero is better than an empty place.
		var rest: Array = pool.filter(func(h): return not party.has(h) and int(h.get("resolve_level", 0)) <= int(expedition.get("max_level", 6)))
		rest.sort_custom(func(a, b): return int(a.get("resolve_level", 0)) > int(b.get("resolve_level", 0)))
		for h in rest:
			if party.size() + hires >= 4:
				break
			party.append(h)
			short += maxi(int(expedition.get("min_level", 0)) - int(h.get("resolve_level", 0)), 0)
	return {"expedition": expedition, "party": party, "size": party.size() + hires, "hires": hires, "cost": short + 2 * hires}


## The hero's level is inside the expedition's range (neither refuses nor is under-leveled).
func _in_range(h: Dictionary, expedition: Dictionary) -> bool:
	var lvl: int = int(h.get("resolve_level", 0))
	return lvl >= int(expedition.get("min_level", 0)) and lvl <= int(expedition.get("max_level", 6))


## A dedicated healer: the class has a heal skill and never stands in position 1.
func _is_healer(h: Dictionary) -> bool:
	if _pref_rank(h) <= 1:
		return false
	for sid in h.get("skill_ids", []):
		if str(_gs.get_skill(str(sid)).get("kind", "")) == "heal":
			return true
	return false


## The cheapest recruit the bot can pay for; one who isn't a second healer when there is a choice.
## Books the cheapest Iglesia/Cantina activity with a free slot for `h`, keeping RESERVE.
## Returns the activity id, or "" if none could be booked.
func _book_relief(h: Dictionary) -> String:
	var best_act: Array = []
	for b in ["iglesia", "cantina"]:
		for a in ["meditacion", "rezo", "penitencia", "guaro_conversa", "juegos_de_azar", "noche_de_fiesta"]:
			if _gs.activity_block_reason(h, b, a) == "" and (best_act.is_empty() or _gs.activity_cost(b, a) < int(best_act[2])):
				best_act = [b, a, _gs.activity_cost(b, a)]
	if best_act.is_empty() or _gs.colones - int(best_act[2]) < RESERVE:
		return ""
	_gs.send_to_activity(h, str(best_act[0]), str(best_act[1]))
	return str(best_act[1])


func _pick_recruit() -> int:
	var has_healer: bool = _living_roster().any(func(h): return _is_healer(h))
	var best: int = -1
	var best_key: Array = []
	for k in _gs.recruit_pool.size():
		var r: Dictionary = _gs.recruit_pool[k]
		var c: int = _gs.hire_cost(r)
		if c > _gs.colones:
			continue
		var key: Array = [1 if (has_healer and _is_healer(r)) else 0, c]
		if best < 0 or key < best_key:
			best = k
			best_key = key
	return best


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
		var kind: String = _fight_kind(ctx)
		var f: Dictionary = {"kind": kind, "rounds": int(screen._combat._round), "won": v, "surprise": str(ctx.get("surprise", ""))}
		if kind == "roaming" and v:
			# The roaming mini-boss (P2-05): hunted, or it ran off after flee_after rounds.
			f["escaped"] = ctx.get("enemies", []).any(func(e): return bool(e.get("fled", false)))
		fights.append(f)
	screen._combat.combat_over.connect(on_over)
	var left_fight: Array = [false]
	screen._combat.combat_fled.connect(func():
		left_fight[0] = true
		var ctx: Dictionary = _gs.combat_context
		fights.append({"kind": _fight_kind(ctx),
			"rounds": int(screen._combat._round), "won": false, "fled": true, "surprise": str(ctx.get("surprise", ""))}))
	var moves: int = 0
	var steps: int = 0
	var started_with: int = _gs.living_party_count()
	var room_done: String = ""
	while _finished == "" and steps < MAX_STEPS:
		steps += 1
		await process_frame
		match int(screen._mode):
			0:  # EXPLORE
				if room_done != _gs.current_node_id:
					room_done = _gs.current_node_id
					row["items_used"] += _use_items_between_rooms()
				# Go home after leaving a fight, or once a hero is dead (P5-05): the loot found so
				# far is kept, and a hero is worth more than the rest of the expedition.
				if left_fight[0] or (_gs.living_party_count() <= started_with - 1 and _gs.current_node_id != _gs.objective_node_id):
					row["fled"] = true
					row["fled_fight"] = left_fight[0]
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
	var sum_stress: int = 0
	for h in _gs.party:
		if h.get("dead", false):
			deaths += 1
		else:
			sum_stress += int(h.get("stress", 0))
		max_stress = maxi(max_stress, int(h.get("stress", 0)))
		var now: String = str(h.get("affliction_id", "")) + "|" + str(h.get("virtud_id", ""))
		if now != str(snap.get(int(h["uid"]), now)):
			breaks.append(str(h.get("affliction_id", "")) if str(h.get("affliction_id", "")) != "" else "+" + str(h.get("virtud_id", "")))
	# Stress the survivors bring back to the hub.
	row["stress_end"] = float(sum_stress) / maxf(_gs.party.size() - deaths, 1.0)
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
	print("| Wk | Party (levels, difficulty) | Town event | Hub ₡ (prov / items / EBAIS / Iglesia / ranks / gear / hires) | Result | Rooms | Moves | Fights (rounds) | Deaths | Stress avg / top | Breaks | Hunger (short) | Traps D/C | Loot ₡ | ₡ after |")
	print("|---:|---|---|---|---|---:|---:|---|---:|---:|---|---|---|---:|---:|")
	for r in rows:
		var f: Array = r.get("fights", [])
		var fr: PackedStringArray = PackedStringArray(f.map(func(x): return "%s%d%s" % [str(x["kind"])[0].to_upper() if x["kind"] != "combat" else "", int(x["rounds"]), "" if x["won"] else ("↩" if x.get("fled", false) else "✗")]))
		var bought: PackedStringArray = PackedStringArray()
		if int(r.get("hired", 0)) > 0:
			bought.append("hired %d" % int(r["hired"]))
		if int(r.get("ranks_n", 0)) > 0:
			bought.append("%d rank(s)" % int(r["ranks_n"]))
		if int(r.get("gear_n", 0)) > 0:
			bought.append("%d gear" % int(r["gear_n"]))
		print("| %d | %s (%s) | %s | %d (%d / %d / %d / %d / %d / %d / %d)%s | %s%s | %d/%d | %d | %s | %d | %.0f / %d | %s | %d (%d) | %d/%d | %d | %d |" % [
			int(r["week"]), r.get("party", ""), r.get("levels", ""), r.get("event", ""), int(r.get("hub_spent", 0)),
			int(r.get("provisions", 0)), int(r.get("heal_items", 0)) + int(r.get("stress_items", 0)), int(r.get("ebais", 0)),
			int(r.get("iglesia", 0)), int(r.get("ranks", 0)), int(r.get("gear", 0)), int(r.get("hires", 0)),
			(": " + ", ".join(bought)) if not bought.is_empty() else "",
			r.get("result", "?"), " (camped)" if r.get("camped", false) else "",
			int(r.get("rooms_seen", 0)), int(r.get("rooms_total", 0)), int(r.get("moves", 0)),
			" ".join(fr), int(r.get("deaths", 0)), float(r.get("stress_end", 0.0)), int(r.get("max_stress", 0)), r.get("breaks", ""),
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
	# Retreats (P5-04): an expedition abandoned, on the map or after leaving a fight (↩ in the rows).
	var went_home: Array = _all_rows.filter(func(r): return str(r.get("result", "")) == "flee")
	var kept: int = 0
	for r in went_home:
		kept += int(r.get("loot", 0))
	print("- Retreats: %d expedition(s) abandoned, %d of them after a Retirada from a fight; they kept %.0f ₡ of loot on average." % [
		went_home.size(), went_home.filter(func(r): return bool(r.get("fled_fight", false))).size(), float(kept) / maxf(went_home.size(), 1.0)])
	_print_difficulty_table()
	_print_stress_and_food()
	_print_economy()
	_print_roaming()
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


## Clear rate per difficulty (the owner's bands, P5-02) and when each campaign first moved up.
func _print_difficulty_table() -> void:
	var by: Dictionary = {}
	var first: Dictionary = {}
	for r in _all_rows:
		var d: String = str(r.get("difficulty", "?"))
		if not by.has(d):
			by[d] = {"n": 0, "won": 0, "deaths": 0, "breaks": 0, "top": 0}
			first[d] = {}
		by[d]["n"] += 1
		by[d]["won"] += 1 if str(r.get("result", "")) == "objective" else 0
		by[d]["deaths"] += int(r.get("deaths", 0))
		by[d]["breaks"] += 0 if str(r.get("breaks", "")) == "" else str(r["breaks"]).split(", ").size()
		by[d]["top"] += int(r.get("max_stress", 0))
		if not first[d].has(r["campaign"]):
			first[d][r["campaign"]] = int(r["week"])
	print("\n| Difficulty | Expeditions | Cleared | Deaths / exp. | Quebrantos+Virtudes / exp. | Avg top stress | First week (per campaign) |")
	print("|---|---:|---:|---:|---:|---:|---|")
	for d in by:
		var s: Dictionary = by[d]
		var m: float = maxf(s["n"], 1.0)
		print("| %s | %d | %.0f%% | %.2f | %.2f | %.0f | %s |" % [d, s["n"], 100.0 * s["won"] / m, s["deaths"] / m, s["breaks"] / m, s["top"] / m,
			", ".join(PackedStringArray(first[d].values().map(func(w): return str(w))))])


func _print_stress_and_food() -> void:
	var n: float = maxf(_all_rows.size(), 1.0)
	var avg_end: float = 0.0
	var top: float = 0.0
	var start: float = 0.0
	var over: int = 0
	var hunger: int = 0
	var unfed: int = 0
	var short_runs: int = 0
	for r in _all_rows:
		avg_end += float(r.get("stress_end", 0.0))
		top += int(r.get("max_stress", 0))
		start += float(r.get("stress_start", 0.0))
		# A Virtud drops stress back to 40, so count the breaks too, not only the stress at the end.
		over += 1 if int(r.get("max_stress", 0)) >= BalanceScript.int_of("stress.resolve_threshold") or str(r.get("breaks", "")) != "" else 0
		hunger += int(r.get("hunger", 0))
		unfed += int(r.get("unfed", 0))
		short_runs += 1 if int(r.get("unfed", 0)) > 0 else 0
	print("\n- Stress: the party leaves the hub at %.0f on average and comes back at %.0f (top hero %.0f). Expeditions where someone reached %d: %d of %d." % [
		start / n, avg_end / n, top / n, BalanceScript.int_of("stress.resolve_threshold"), over, _all_rows.size()])
	print("- Food: %d hunger stops, %d of them short of gallo pinto (%.0f%%), in %d of %d expeditions." % [
		hunger, unfed, 100.0 * unfed / maxf(hunger, 1.0), short_runs, _all_rows.size()])


## Colones in and out per week, by sink, and what each campaign had in the bank.
func _print_economy() -> void:
	var n: float = maxf(_all_rows.size(), 1.0)
	var loot: int = 0
	var spent: int = 0
	var sink: Dictionary = {}
	for r in _all_rows:
		loot += int(r.get("loot", 0))
		spent += int(r.get("hub_spent", 0))
		for k in SINKS:
			sink[k] = int(sink.get(k, 0)) + int(r.get(k, 0))
	print("\n| Colones per week | Avg ₡ | Share of spending |")
	print("|---|---:|---:|")
	print("| Loot (fights, curios, objective) | %.0f | |" % (loot / n))
	for k in SINKS:
		print("| %s | %.0f | %.0f%% |" % [SINK_NAMES[k], sink[k] / n, 100.0 * sink[k] / maxf(spent, 1.0)])
	print("| **All hub spending** | %.0f | %.0f%% of loot |" % [spent / n, 100.0 * spent / maxf(loot, 1.0)])
	var bank: Dictionary = {}
	for r in _all_rows:
		if not bank.has(r["campaign"]):
			bank[r["campaign"]] = {}
		bank[r["campaign"]][int(r["week"])] = int(r.get("colones_end", 0))
	var lines: PackedStringArray = PackedStringArray()
	for c in bank:
		var weeks: Array = bank[c].keys()
		weeks.sort()
		var marks: PackedStringArray = PackedStringArray()
		for w in [4, 8, 12, 16, 24, 32]:
			if bank[c].has(w):
				marks.append("wk %d: %d" % [w, bank[c][w]])
		if not weeks.is_empty() and not [4, 8, 12, 16, 24, 32].has(weeks[-1]):
			marks.append("wk %d: %d" % [weeks[-1], bank[c][weeks[-1]]])
		lines.append("campaign %d — %s" % [c, ", ".join(marks)])
	print("\n- Colones in the bank: %s." % "; ".join(lines))


## Fight kind for the report: roaming (the mini-boss, P2-05) | ambush | boss | elite | combat.
static func _fight_kind(ctx: Dictionary) -> String:
	if bool(ctx.get("is_roaming", false)):
		return "roaming"
	if bool(ctx.get("is_ambush", false)):
		return "ambush"
	if bool(ctx.get("is_boss", false)):
		return "boss"
	return "elite" if bool(ctx.get("is_elite", false)) else "combat"


## The roaming mini-boss: how its fights ended (killed, escaped after flee_after rounds, the
## party retreated, the party fell).
func _print_roaming() -> void:
	var r: Array = _all_fights.filter(func(f): return str(f["kind"]) == "roaming")
	if r.is_empty():
		print("- Roaming mini-boss: never met.")
		return
	var killed: int = r.filter(func(f): return f["won"] and not bool(f.get("escaped", false))).size()
	var escaped: int = r.filter(func(f): return f["won"] and bool(f.get("escaped", false))).size()
	var retreated: int = r.filter(func(f): return bool(f.get("fled", false))).size()
	var lost: int = r.size() - killed - escaped - retreated
	var rounds: int = 0
	for f in r:
		rounds += int(f["rounds"])
	print("- Roaming mini-boss: met %d time(s) — killed %d, it escaped %d, the party retreated %d, the party fell %d; %.1f rounds on average." % [
		r.size(), killed, escaped, retreated, lost, float(rounds) / r.size()])

