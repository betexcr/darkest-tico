extends RefCounted

## Battlefield formation (P1-03a, doc 01 §2.1). Pure rules, no nodes.
## - Each side is an Array of unit Dictionaries in formation order (index 0 = front).
## - A unit's position is 1 + the number of LIVING units ahead of it, so the dead never
##   hold a slot; CombatController also moves them to the back (collapse_order).
## - Skills: use_ranks = positions the user may act from (default: any); target_ranks =
##   positions on the other side it can reach (default: any). Data: skills.json /
##   enemies.json; classes and enemies have preferred "ranks".
## In-game text calls this "posición" ("rango" is the Casa Comunal skill level).

const StatusEffectsScript := preload("res://scripts/domain/status_effects.gd")

const ALL := [1, 2, 3, 4]


static func is_alive(u) -> bool:
	return u is Dictionary and not bool(u.get("dead", false))


static func living(side: Array) -> Array:
	return side.filter(func(u): return is_alive(u))


## 1..4 for a living unit, 0 for a dead or missing one.
static func position_of(unit: Dictionary, side: Array) -> int:
	if not is_alive(unit):
		return 0
	var pos: int = 0
	for u in side:
		if is_alive(u):
			pos += 1
			if is_same(u, unit):
				return pos
	return 0


## Living units standing on any of `ranks`, front first.
static func at_positions(side: Array, ranks: Array) -> Array:
	var want: Array = _ints(ranks)
	var out: Array = []
	var pos: int = 0
	for u in side:
		if is_alive(u):
			pos += 1
			if want.has(pos):
				out.append(u)
	return out


## Positions as ints (JSON numbers load as floats, and [1.0].has(1) is false).
static func use_ranks(skill: Dictionary) -> Array:
	var r = skill.get("use_ranks", null)
	return _ints(r) if r is Array and not r.is_empty() else ALL.duplicate()


static func target_ranks(skill: Dictionary) -> Array:
	var r = skill.get("target_ranks", null)
	return _ints(r) if r is Array and not r.is_empty() else ALL.duplicate()


static func _ints(a: Array) -> Array:
	return a.map(func(x): return int(x))


## Units on the other side this skill may hit: in reach, alive, and not hidden
## (Agazapado), unless everyone in reach is hidden (StatusEffects.targetable's fallback).
static func valid_targets(skill: Dictionary, other_side: Array) -> Array:
	return StatusEffectsScript.targetable(at_positions(other_side, target_ranks(skill)))


## Whether `user` can use `skill` right now. `hits_other_side`: the skill picks one unit on
## the other side (hero attacks, enemy single-target skills); it then needs a valid target.
static func can_use(skill: Dictionary, user: Dictionary, own_side: Array, other_side: Array, hits_other_side: bool) -> bool:
	var pos: int = position_of(user, own_side)
	if pos == 0 or not use_ranks(skill).has(pos):
		return false
	return not hits_other_side or not valid_targets(skill, other_side).is_empty()


## Living units right before and after `unit` (the ones it can swap places with).
static func neighbours(unit: Dictionary, side: Array) -> Array:
	var alive: Array = living(side)
	var k: int = -1
	for i in alive.size():
		if is_same(alive[i], unit):
			k = i
	if k < 0:
		return []
	var out: Array = []
	if k > 0:
		out.append(alive[k - 1])
	if k < alive.size() - 1:
		out.append(alive[k + 1])
	return out


## The neighbour to swap with to get one step closer to `preferred` positions ({} if
## already there or there is nobody to swap with).
static func step_toward(unit: Dictionary, side: Array, preferred: Array) -> Dictionary:
	var pos: int = position_of(unit, side)
	if pos == 0 or preferred.is_empty() or _ints(preferred).has(pos):
		return {}
	var lo: int = int(preferred.min())
	var want: int = pos + 1 if pos < lo else pos - 1
	for n in neighbours(unit, side):
		if position_of(n, side) == want:
			return n
	return {}


## Whether a unit can change position at all (alive and not Amarrado).
static func can_move(unit: Dictionary) -> bool:
	return is_alive(unit) and not StatusEffectsScript.has(unit, "amarrado")


## New order of `side` after `unit` moves `delta` positions (negative = toward the front,
## positive = toward the back), clamped to the living positions. The others shift to make
## room (Darkest Dungeon style: insert, not swap). The dead stay at the back.
static func move_by(side: Array, unit: Dictionary, delta: int) -> Array:
	var p: int = position_of(unit, side)
	if p == 0:
		return side.duplicate()
	return move_to(side, unit, p + delta)


## New order of `side` with `unit` at position `pos` (clamped to 1..living count).
static func move_to(side: Array, unit: Dictionary, pos: int) -> Array:
	var alive: Array = living(side)
	var dead: Array = side.filter(func(u): return not is_alive(u))
	var k: int = _index_of(alive, unit)
	if k < 0:
		return side.duplicate()
	alive.remove_at(k)
	alive.insert(clampi(pos, 1, alive.size() + 1) - 1, unit)
	return alive + dead


## Swap two units in `side` (same Array object, in place). Returns false if either is missing.
static func swap(side: Array, a: Dictionary, b: Dictionary) -> bool:
	var ia: int = _index_of(side, a)
	var ib: int = _index_of(side, b)
	if ia < 0 or ib < 0:
		return false
	side[ia] = b
	side[ib] = a
	return true


## Index permutation that puts the living first and the dead last, keeping order (stable).
static func collapse_order(side: Array) -> Array:
	var alive: Array = []
	var dead: Array = []
	for i in side.size():
		if is_alive(side[i]):
			alive.append(i)
		else:
			dead.append(i)
	return alive + dead


## Squad sorted by each enemy's preferred front-most position (min of "ranks"); ties keep
## the generator's order, so the leader/boss stays ahead of escorts with the same ranks.
static func sort_squad(squad: Array) -> Array:
	var keyed: Array = []
	for i in squad.size():
		var r = squad[i].get("ranks", ALL) if squad[i] is Dictionary else ALL
		var front: int = int((r as Array).min()) if r is Array and not r.is_empty() else 1
		keyed.append([front, i, squad[i]])
	keyed.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	return keyed.map(func(k): return k[2])


## "1–2", "2–4", "1, 3" for UI text.
static func ranks_text(ranks: Array) -> String:
	var r: Array = _ints(ranks)
	r.sort()
	if r.is_empty():
		return "—"
	if r.size() > 1 and int(r[-1]) - int(r[0]) == r.size() - 1:
		return "%d–%d" % [int(r[0]), int(r[-1])]
	return ", ".join(r.map(func(x): return str(x)))


static func _index_of(side: Array, u: Dictionary) -> int:
	for i in side.size():
		if is_same(side[i], u):
			return i
	return -1
