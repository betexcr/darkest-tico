extends RefCounted

## Feria Nocturna (P3-05a, doc 02 §8; owner 2026-11-20): the accessory stall of the
## hacienda, Darkest Dungeon's Nomad Wagon. Each week it brings a few different
## accessories, one of each; buying one takes it off the stall until the next week. The
## dearer ones are rarer early in the campaign. Numbers: data/balance.json `feria.*`.
## Pure; no nodes.

const BalanceScript := preload("res://scripts/domain/balance.gd")


## Draw weight of an accessory in `week`: 1 for the cheap ones; the dearer ones start at
## feria.pricey_min_weight and reach 1 by feria.full_stock_week.
static func weight(item: Dictionary, week: int) -> float:
	if int(item.get("price", 0)) <= BalanceScript.int_of("feria.cheap_price"):
		return 1.0
	var lo: float = BalanceScript.num("feria.pricey_min_weight")
	var full: float = maxf(BalanceScript.num("feria.full_stock_week") - 1.0, 1.0)
	return lerpf(lo, 1.0, clampf((week - 1) / full, 0.0, 1.0))


## This week's stall: up to feria.stock_size different ids from `items` (accessory
## dictionaries), drawn by weight without repeats, in the order of `items`.
static func roll_stock(items: Array, week: int, rng: RandomNumberGenerator) -> Array:
	var pool: Array = items.filter(func(it): return it is Dictionary and str(it.get("id", "")) != "")
	var picked: Dictionary = {}
	var want: int = mini(BalanceScript.int_of("feria.stock_size"), pool.size())
	while picked.size() < want:
		var total: float = 0.0
		for it in pool:
			if not picked.has(str(it["id"])):
				total += weight(it, week)
		var roll: float = rng.randf() * total
		for it in pool:
			if picked.has(str(it["id"])):
				continue
			roll -= weight(it, week)
			if roll <= 0.0:
				picked[str(it["id"])] = true
				break
		if total <= 0.0:
			break
	var out: Array = []
	for it in pool:
		if picked.has(str(it["id"])):
			out.append(str(it["id"]))
	return out
