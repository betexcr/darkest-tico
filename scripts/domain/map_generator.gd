extends RefCounted
const BalanceScript := preload("res://scripts/domain/balance.gd")

## Random grid dungeon (docs/12-phase-plan.md P2-06).
## Rooms sit on integer grid cells; corridors join orthogonal neighbors, so every move is
## up/down/left/right. The room farthest from the entrance (a dead end) is the boss room.
## Output uses the region JSON shape (nodes, edges, start_node, objective_node) plus
## "pos": [x, y] on each node and "undirected": true.

const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


static func generate(region: Dictionary, seed_value: int) -> Dictionary:
	# Retry with the next seed until the boss is far enough from the entrance.
	var gen: Dictionary = region.get("generator", {})
	var min_boss: int = int(BalanceScript.req(gen, "min_boss_distance", "region generator"))
	var out: Dictionary = {}
	for attempt in 30:  # structural: retry guard
		out = _generate_once(gen, seed_value + attempt)
		if int(out.get("boss_distance", 0)) >= min_boss:
			return out
	return out


static func _generate_once(gen: Dictionary, seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value

	var rooms_range: Array = BalanceScript.req(gen, "rooms", "region generator")
	var target: int = rng.randi_range(int(rooms_range[0]), int(rooms_range[1]))
	var cells: Array = [Vector2i.ZERO]
	var cell_index: Dictionary = {Vector2i.ZERO: 0}
	var adj: Array = [[]]
	var guard: int = 0
	while cells.size() < target and guard < 5000:  # structural: loop guard
		guard += 1
		var from: int = _pick_growth_room(cells, adj, rng, gen)
		var free_dirs: Array = []
		for d in DIRS:
			if not cell_index.has(cells[from] + d):
				free_dirs.append(d)
		if free_dirs.is_empty():
			continue
		var step: Vector2i = free_dirs[rng.randi() % free_dirs.size()]
		var cell: Vector2i = cells[from] + step
		var idx: int = cells.size()
		cells.append(cell)
		cell_index[cell] = idx
		adj.append([])
		adj[from].append(idx)
		adj[idx].append(from)

	# Boss: the dead end farthest from the entrance.
	var dist: Array = _bfs(adj, 0)
	var boss: int = -1
	for k in range(1, cells.size()):
		if adj[k].size() == 1 and (boss < 0 or int(dist[k]) > int(dist[boss])):
			boss = k
	if boss < 0:
		boss = cells.size() - 1

	# A few extra corridors make loops, never touching the entrance or the boss room,
	# and never shortening the way to the boss.
	var boss_dist: int = int(dist[boss])
	var links: int = int(gen.get("extra_links", 1))
	var tries: int = 0
	while links > 0 and tries < 200:  # structural: loop guard
		tries += 1
		var a: int = rng.randi_range(1, cells.size() - 1)
		if a == boss:
			continue
		var d2: Vector2i = DIRS[rng.randi() % DIRS.size()]
		var other = cell_index.get(cells[a] + d2, -1)
		if other is int and other > 0 and other != boss and not adj[a].has(other):
			adj[a].append(other)
			adj[other].append(a)
			if int(_bfs(adj, 0)[boss]) < boss_dist:
				adj[a].erase(other)
				adj[other].erase(a)
			else:
				links -= 1
	dist = _bfs(adj, 0)
	var max_d: int = int(dist[boss])
	var half: int = int(max_d / 2.0)

	# Room types.
	var types: Array = []
	types.resize(cells.size())
	types.fill("")
	types[0] = "safe"
	types[boss] = "boss"
	var pool: Array = []
	for k in cells.size():
		if types[k] == "":
			pool.append(k)
	var camps: int = int(gen.get("camps", 1))
	for _c in camps:
		var best: int = -1
		for k in pool:
			if types[k] == "" and (best < 0 or absi(int(dist[k]) - half) < absi(int(dist[best]) - half)):
				best = k
		if best >= 0:
			types[best] = "camp"
	var elites: int = int(gen.get("elites", 1))
	var far: Array = []
	for k in pool:
		if types[k] == "" and int(dist[k]) * 2 >= max_d:
			far.append(k)
	for _e in elites:
		if far.is_empty():
			break
		var pick: int = far.pop_at(rng.randi() % far.size())
		types[pick] = "elite"
	var weights: Dictionary = gen.get("weights", {"combat": 40, "trap": 15, "curio": 25, "empty": 20})
	for k in pool:
		if types[k] == "":
			types[k] = _weighted(weights, rng)
	var min_combat: int = int(BalanceScript.req(gen, "min_combat", "region generator"))
	var n_combat: int = types.count("combat") + types.count("elite")
	for k in pool:
		if n_combat >= min_combat:
			break
		if types[k] == "empty" or types[k] == "curio" or types[k] == "trap":
			types[k] = "combat"
			n_combat += 1

	# Build nodes, normalizing positions so the smallest x/y is 0.
	var min_x: int = 0
	var min_y: int = 0
	for c in cells:
		min_x = mini(min_x, c.x)
		min_y = mini(min_y, c.y)
	var labels: Dictionary = gen.get("labels", {})
	var nodes: Array = []
	for k in cells.size():
		var t: String = types[k]
		var nd: Dictionary = {
			"id": "r%d" % k,
			"pos": [cells[k].x - min_x, cells[k].y - min_y],
			"type": t,
			"label": _pick_label(labels, t, rng),
		}
		match t:
			"combat":
				nd["enemy_id"] = _pick(gen.get("enemy_pool", ["espanto"]), rng)
				nd["enemy_ids"] = _squad(nd["enemy_id"], gen, rng)
				nd["reward_colones"] = _range(BalanceScript.req(gen, "reward_colones", "region generator"), rng)
			"elite":
				nd["type"] = "combat"
				nd["is_elite"] = true
				nd["enemy_id"] = _pick(gen.get("elite_pool", gen.get("enemy_pool", ["espanto"])), rng)
				nd["enemy_ids"] = _squad(nd["enemy_id"], gen, rng)
				nd["reward_colones"] = _range(BalanceScript.req(gen, "elite_reward_colones", "region generator"), rng)
			"curio":
				nd["curio_id"] = _pick(gen.get("curios", []), rng)
			"trap":
				if not Array(gen.get("traps", [])).is_empty():
					nd["trap_id"] = _pick(gen.get("traps", []), rng)
			"boss":
				nd["is_boss"] = true
				nd["enemy_id"] = str(gen.get("boss_enemy_id", "espanto"))
				nd["enemy_ids"] = [nd["enemy_id"]] + Array(gen.get("boss_escort", []))
				nd["reward_colones"] = int(BalanceScript.req(gen, "boss_reward_colones", "region generator"))
		nodes.append(nd)
	var edges: Array = []
	for a in adj.size():
		for b in adj[a]:
			if a < int(b):
				edges.append({"from": "r%d" % a, "to": "r%d" % int(b)})
	return {
		"nodes": nodes,
		"edges": edges,
		"start_node": "r0",
		"objective_node": "r%d" % boss,
		"undirected": true,
		"seed": seed_value,
		"boss_distance": max_d,
	}


## Leader first (front rank), then 0..n extra members from the normal pool (P1-02).
static func _squad(leader: String, gen: Dictionary, rng: RandomNumberGenerator) -> Array:
	var size_range: Array = BalanceScript.req(gen, "squad_size", "region generator")
	var n: int = rng.randi_range(int(size_range[0]), int(size_range[1]))
	var out: Array = [leader]
	for _k in n - 1:
		out.append(_pick(gen.get("enemy_pool", [leader]), rng))
	return out


## Mostly extend the newest room (long corridors; generator branch_newest_chance), sometimes
## branch from any room with fewer than generator max_exits exits.
static func _pick_growth_room(cells: Array, adj: Array, rng: RandomNumberGenerator, gen: Dictionary) -> int:
	if rng.randf() < float(BalanceScript.req(gen, "branch_newest_chance", "region generator")):
		return cells.size() - 1
	var options: Array = []
	for k in cells.size():
		if adj[k].size() < int(BalanceScript.req(gen, "max_exits", "region generator")):
			options.append(k)
	if options.is_empty():
		return rng.randi() % cells.size()
	return options[rng.randi() % options.size()]


static func _bfs(adj: Array, start: int) -> Array:
	var dist: Array = []
	dist.resize(adj.size())
	dist.fill(-1)
	dist[start] = 0
	var queue: Array = [start]
	while not queue.is_empty():
		var cur: int = queue.pop_front()
		for nxt in adj[cur]:
			if int(dist[nxt]) < 0:
				dist[nxt] = int(dist[cur]) + 1
				queue.append(nxt)
	return dist


static func _weighted(weights: Dictionary, rng: RandomNumberGenerator) -> String:
	var total: float = 0.0
	for k in weights:
		total += float(weights[k])
	var roll: float = rng.randf() * total
	for k in weights:
		roll -= float(weights[k])
		if roll <= 0.0:
			return str(k)
	return str(weights.keys()[0])


static func _pick(arr: Array, rng: RandomNumberGenerator) -> String:
	if arr.is_empty():
		return ""
	return str(arr[rng.randi() % arr.size()])


static func _range(r, rng: RandomNumberGenerator) -> int:
	if r is Array and r.size() >= 2:
		return rng.randi_range(int(r[0]), int(r[1]))
	return int(r)


static func _pick_label(labels: Dictionary, t: String, rng: RandomNumberGenerator) -> String:
	var arr: Array = labels.get(t, [])
	if arr.is_empty():
		return t.capitalize()
	return str(arr[rng.randi() % arr.size()])
