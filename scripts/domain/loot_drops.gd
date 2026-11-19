extends RefCounted

## Enemy drops (P5-10, owner 2026-11-19): each enemy lists 3 items with a chance each
## (data/enemies.json `drops`). When it dies, one roll decides whether it drops one of them
## (never more than one); most kills drop nothing. Chances grow with the difficulty and the
## Luz/event loot multiplier (`mult`), and the three together never pass
## balance drops.max_total_chance.

const BalanceScript := preload("res://scripts/domain/balance.gd")


## The item id this roll gives ("" = nothing). `r` is a random number in [0, 1).
static func roll(drops: Array, mult: float, r: float) -> String:
	var total: float = 0.0
	for d in drops:
		total += float(d["chance"])
	if total <= 0.0:
		return ""
	var scale: float = minf(mult, BalanceScript.num("drops.max_total_chance") / total)
	var acc: float = 0.0
	for d in drops:
		acc += float(d["chance"]) * scale
		if r < acc:
			return str(d["item"])
	return ""


## The chance multiplier for a difficulty id (aprendiz / veterano / campeon).
static func difficulty_mult(diff_id: String) -> float:
	return BalanceScript.num("drops.chance_mult.%s" % diff_id)
