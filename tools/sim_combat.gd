extends SceneTree

## Combat Monte Carlo sim (P1-07). Plays N fights of the starting party against each kind of
## room in a region and prints win rate, rounds, stress and deaths as markdown tables.
## It runs the real combat controller (scripts/combat/combat_controller.gd) in `instant`
## mode with stub stage units, so the numbers follow the game's rules exactly and there is
## no second copy of the combat math to keep in sync.
##
##   godot --headless --path . -s tools/sim_combat.gd -- [options]
##
## Options (after the "--"):
##   --runs N            fights per room kind (default 10000)
##   --node K            combat | elite | boss | all (default all)
##   --policy P          smart (heals, calms, focuses the weakest) | basic (first usable attack)
##   --seed S            RNG seed (default 1)
##   --region PATH       region JSON (default the Sótanos)
##   --difficulty ID     aprendiz | veterano | campeon (data/progression.json; the level-0
##                       starting party counts as under-leveled above aprendiz)
##   --set PATH=VALUE    Balance override, repeatable (e.g. --set combat.hit_base=0.8)
##   --chain N           expedition mode: N normal fights, then the elite, then the boss, with
##                       nothing healed in between (see _run_chains)
##   --light N           play every fight at this Luz (default: the region's starting Luz)
##   --log               print the combat log of the first fight of each room kind / chain
##
## Without --chain, every fight starts from the fresh starting party (full PV, 0 stress, no
## items used, no camp buffs), as at the first room of a new game. Squads are drawn the way
## the map generator draws them (map_generator.gd _squad), scaled the way GameState does.
## The heroes never use items, never retreat and never camp.

## Loaded at run time: the controller names the GameState autoload, which a -s script
## cannot see while it compiles.
const CONTROLLER_PATH := "res://scripts/combat/combat_controller.gd"
const CombatResolverScript := preload("res://scripts/domain/combat_resolver.gd")
const StatusEffectsScript := preload("res://scripts/domain/status_effects.gd")
const MapGeneratorScript := preload("res://scripts/domain/map_generator.gd")
const BalanceScript := preload("res://scripts/domain/balance.gd")

## A fight still going after this many rounds counts as a loss (a stall).
const MAX_ROUNDS := 40
const SimPolicyScript := preload("res://tools/sim_policy.gd")

var _gs
var _cc
var _policy
var _gen: Dictionary = {}
var _template: Array = []
var _light0: int = 0
var _rng := RandomNumberGenerator.new()
var _opts := {"runs": 10000, "node": "all", "policy": "smart", "seed": 1, "chain": 0,
	"region": "res://data/regions/sotanos.json", "difficulty": "aprendiz", "light": -1, "set": [], "log": false}
var _log_on: bool = false


## Stand-in for BattleUnit: same calls, no drawing, returns at once.
class SimUnit extends RefCounted:
	const COLOR_STRESS := Color.WHITE
	var data: Dictionary

	func _init(d: Dictionary) -> void:
		data = d

	func play_action(_kind: String = "") -> void:
		pass

	func play_hurt(_amount: int = 0, _crit: bool = false) -> void:
		pass

	func play_death(_amount: int = 0, _crit: bool = false) -> void:
		pass

	func play_heal(_hp: int = 0, _stress: int = 0) -> void:
		pass

	func float_text(_text: String = "", _color: Color = Color.WHITE) -> void:
		pass

	func refresh() -> void:
		pass

	func set_active(_on: bool = false) -> void:
		pass

	func set_targeted(_on: bool = false) -> void:
		pass

	func is_dead() -> bool:
		return bool(data.get("dead", false))

	func get_parent():
		return null


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	_parse_args()
	seed(int(_opts["seed"]))
	_rng.seed = int(_opts["seed"])
	for kv in _opts["set"]:
		var parts: PackedStringArray = str(kv).split("=", true, 1)
		if parts.size() == 2:
			BalanceScript.override(parts[0], JSON.parse_string(parts[1]))
	_gs = root.get_node("GameState")
	_gs.reset_party_from_catalog()
	_gs.selected_difficulty_id = str(_opts["difficulty"])
	if not _gs.start_mission(str(_opts["region"])):
		push_error("sim_combat: could not start a mission in %s" % _opts["region"])
		quit(1)
		return
	_gen = _gs.mission_region_data.get("generator", {})
	if _gen.is_empty():
		push_error("sim_combat: %s has no generator block" % _opts["region"])
		quit(1)
		return
	_template = _gs.party.duplicate(true)
	_light0 = int(_gs.mission_light) if int(_opts["light"]) < 0 else int(_opts["light"])
	_cc = load(CONTROLLER_PATH).new()
	_cc.instant = true
	root.add_child(_cc)
	_cc.logged.connect(func(t, _c): if _log_on: print("    " + str(t)))
	# Hero choices: tools/sim_policy.gd (shared with tools/playtest_campaign.gd).
	_policy = SimPolicyScript.new(_cc, _gs, str(_opts["policy"]))

	var chain: int = int(_opts["chain"])
	print("## Combat sim — %s, %d %s, policy %s, seed %d%s\n" % [
		_gs.mission_region_data.get("name", "?"), int(_opts["runs"]),
		("chains of %d fights + elite + boss" % chain) if chain > 0 else "fights per room kind",
		_opts["policy"], int(_opts["seed"]),
		(", overrides " + ", ".join(PackedStringArray(_opts["set"]))) if not _opts["set"].is_empty() else ""])
	print("Party (formation order): %s. Difficulty: %s. Luz %d (%s).\n" % [
		", ".join(PackedStringArray(_template.map(func(h): return str(h.get("class_name", "?"))))), _gs.selected_difficulty_id,
		_light0, load("res://scripts/domain/light_system.gd").tier_name(_light0)])
	var t0: int = Time.get_ticks_msec()
	if chain > 0:
		_run_chains(chain)
	else:
		_run_fresh()
	print("Done in %.1f s." % ((Time.get_ticks_msec() - t0) / 1000.0))
	BalanceScript.reset()
	quit(0)


## Every fight from the fresh starting party.
func _run_fresh() -> void:
	var kinds: Array = ["combat", "elite", "boss"] if _opts["node"] == "all" else [_opts["node"]]
	var rows: Array = []
	var by_leader: Dictionary = {}
	for kind in kinds:
		var total := _new_stats(kind)
		for i in int(_opts["runs"]):
			_log_on = bool(_opts["log"]) and i == 0
			if _log_on:
				print("### First %s fight\n" % kind)
			var r: Dictionary = _fight(kind, _template.duplicate(true))
			_add(total, r)
			var key: String = "%s: %s" % [kind, r["leader"]]
			if kind != "boss":
				if not by_leader.has(key):
					by_leader[key] = _new_stats(key)
				_add(by_leader[key], r)
			if _log_on:
				print("")
		rows.append(total)
	_print_table("Per room kind", rows)
	if not by_leader.is_empty():
		var keys: Array = by_leader.keys()
		keys.sort()
		_print_table("By room leader (the room's enemy; the rest of the squad is random)", keys.map(func(k): return by_leader[k]))


## `n` normal fights, then the elite, then the boss, with PV, stress, deaths and Al Borde
## rolls carried over and no recovery between fights (no camp, items, curios or retreat).
## A chain ends at the first lost fight. Each row counts the chains that reached that fight.
func _run_chains(n: int) -> void:
	var steps: Array = []
	for k in n:
		steps.append("combat")
	steps.append_array(["elite", "boss"])
	var rows: Array = []
	for k in steps.size():
		rows.append(_new_stats("%d. %s" % [k + 1, steps[k]]))
	var cleared: int = 0
	var deaths_on_clear: int = 0
	for i in int(_opts["runs"]):
		var party: Array = _template.duplicate(true)
		var won_all: bool = true
		for k in steps.size():
			_log_on = bool(_opts["log"]) and i == 0
			if _log_on:
				print("### First chain, fight %d (%s)\n" % [k + 1, steps[k]])
			var r: Dictionary = _fight(steps[k], party)
			_add(rows[k], r)
			if not r["won"]:
				won_all = false
				break
		if won_all:
			cleared += 1
			deaths_on_clear += party.filter(func(h): return h.get("dead", false)).size()
	_print_table("Fight by fight (carried over; deaths and stress are per fight)", rows)
	var runs: float = float(maxi(int(_opts["runs"]), 1))
	print("**Cleared the boss: %.1f%%** of %d chains (heroes lost on a clear: %.2f).\n" % [
		100.0 * cleared / runs, int(_opts["runs"]), float(deaths_on_clear) / float(maxi(cleared, 1))])


func _parse_args() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	var k: int = 0
	while k < a.size():
		var flag: String = a[k]
		var val: String = a[k + 1] if k + 1 < a.size() else ""
		match flag:
			"--runs", "--seed", "--chain", "--light":
				_opts[flag.trim_prefix("--")] = int(val)
				k += 1
			"--node", "--policy", "--region", "--difficulty":
				_opts[flag.trim_prefix("--")] = val
				k += 1
			"--set":
				_opts["set"].append(val)
				k += 1
			"--log":
				_opts["log"] = true
			_:
				push_warning("sim_combat: unknown option %s" % flag)
		k += 1


# --- One fight --------------------------------------------------------------------------

func _squad_for(kind: String) -> Dictionary:
	match kind:
		"boss":
			var boss: String = str(_gen.get("boss_enemy_id", ""))
			return {"enemy_ids": [boss] + Array(_gen.get("boss_escort", [])), "is_boss": true}
		"elite":
			var lead: String = MapGeneratorScript._pick(_gen.get("elite_pool", []), _rng)
			return {"enemy_ids": MapGeneratorScript._squad(lead, _gen, _rng), "is_elite": true}
		_:
			var lead2: String = MapGeneratorScript._pick(_gen.get("enemy_pool", []), _rng)
			return {"enemy_ids": MapGeneratorScript._squad(lead2, _gen, _rng)}


func _fight(kind: String, party: Array) -> Dictionary:
	_gs.party = party
	_gs.mission_light = _light0
	var nd: Dictionary = _squad_for(kind)
	nd["type"] = "combat"
	_gs.mission_nodes_index["sim"] = nd
	_gs.build_combat_context_for_node("sim")
	var squad: Array = _gs.combat_context["enemies"]
	# Per-hero state before the fight (chains carry it over), keyed by uid.
	var before: Dictionary = {}
	var stress0: int = 0
	var hp0: int = 0
	var hpmax: int = 0
	for h in party:
		before[int(h["uid"])] = {"dead": bool(h.get("dead", false)), "borde": bool(h.get("al_borde", false)),
			"broke": str(h.get("affliction_id", "")) + str(h.get("virtud_id", "")) != ""}
		stress0 += int(h.get("stress", 0))
		hp0 += int(h.get("hp", 0))
		hpmax += int(h.get("hp_max", 1))
	var won: Array = [false]
	var on_over := func(v: bool): won[0] = v
	_cc.combat_over.connect(on_over)
	# Luz tiers (P1-17): the same surprise roll the game makes when a fight starts.
	var surprise: String = str(_gs.combat_context.get("surprise", ""))
	_cc.start(party, squad, party.map(func(h): return SimUnit.new(h)), squad.map(func(e): return SimUnit.new(e)),
		bool(nd.get("is_elite", false)), bool(nd.get("is_boss", false)), surprise == "party", surprise == "enemies")
	var went_borde: Dictionary = {}
	_note_borde(party, before, went_borde)
	var actions: int = 0
	var stalled: bool = false
	while _cc.is_running():
		var hero: Dictionary = _cc.active_hero()
		if hero.is_empty():
			push_error("sim_combat: the fight is running but no hero is up")
			break
		if int(_cc._round) > MAX_ROUNDS:
			stalled = true
			break
		_act(hero)
		actions += 1
		_note_borde(party, before, went_borde)
	_cc.combat_over.disconnect(on_over)
	if stalled:
		_cc._ended = true
	var r := {"leader": str(nd["enemy_ids"][0]), "won": won[0] and not stalled, "stalled": stalled,
		"rounds": int(_cc._round), "actions": actions, "stress": 0, "max_stress": 0, "deaths": 0,
		"borde": went_borde.size(), "breaks": 0, "hp_lost": 0.0}
	var stress1: int = 0
	var hp1: int = 0
	for h in party:
		stress1 += int(h.get("stress", 0))
		hp1 += int(h.get("hp", 0))
		r["max_stress"] = maxi(int(r["max_stress"]), int(h.get("stress", 0)))
		if bool(h.get("dead", false)) and not before[int(h["uid"])]["dead"]:
			r["deaths"] += 1
		if str(h.get("affliction_id", "")) + str(h.get("virtud_id", "")) != "" and not before[int(h["uid"])]["broke"]:
			r["breaks"] += 1
	r["stress"] = stress1 - stress0
	r["hp_lost"] = float(hp0 - hp1) / float(maxi(hpmax, 1))
	return r


## Heroes who fell Al Borde (or died) during this fight; not those already Al Borde.
func _note_borde(party: Array, before: Dictionary, seen: Dictionary) -> void:
	for h in party:
		if before[int(h["uid"])]["borde"] or before[int(h["uid"])]["dead"]:
			continue
		if bool(h.get("al_borde", false)) or bool(h.get("dead", false)):
			seen[int(h["uid"])] = true


# --- Hero policy ----------------------------------------------------------------------

func _act(hero: Dictionary) -> void:
	_policy.act(hero)


# --- Stats ------------------------------------------------------------------------------

func _new_stats(label: String) -> Dictionary:
	return {"label": label, "n": 0, "wins": 0, "stalls": 0, "rounds": 0, "actions": 0, "stress": 0,
		"max_stress": 0, "deaths": 0, "death_fights": 0, "borde": 0, "breaks": 0, "hp_lost": 0.0}


func _add(s: Dictionary, r: Dictionary) -> void:
	s["n"] += 1
	s["wins"] += 1 if r["won"] else 0
	s["stalls"] += 1 if r["stalled"] else 0
	s["rounds"] += r["rounds"]
	s["actions"] += r["actions"]
	s["stress"] += r["stress"]
	s["max_stress"] += r["max_stress"]
	s["deaths"] += r["deaths"]
	s["death_fights"] += 1 if r["deaths"] > 0 else 0
	s["borde"] += r["borde"]
	s["breaks"] += r["breaks"]
	s["hp_lost"] += r["hp_lost"]


func _print_table(title: String, rows: Array) -> void:
	print("### %s\n" % title)
	print("| Room | Fights | Win % | Rounds | Hero actions | Party stress + | Top hero stress (end) | Deaths | Fights with a death % | Fell Al Borde | Quebranto/Virtud | PV lost % |")
	print("|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|")
	for s in rows:
		var n: float = float(maxi(int(s["n"]), 1))
		print("| %s | %d | %.1f | %.1f | %.1f | %.1f | %.1f | %.2f | %.1f | %.2f | %.2f | %.0f |" % [
			s["label"], s["n"], 100.0 * s["wins"] / n, s["rounds"] / n, s["actions"] / n, s["stress"] / n,
			s["max_stress"] / n, s["deaths"] / n, 100.0 * s["death_fights"] / n, s["borde"] / n,
			s["breaks"] / n, 100.0 * s["hp_lost"] / n])
	print("\nStalls (over %d rounds, counted as losses): %d.\n" % [MAX_ROUNDS, rows.reduce(func(acc, s): return acc + int(s["stalls"]), 0)])
