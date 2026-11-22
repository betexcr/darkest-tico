extends RefCounted

## Feria Nocturna (P3-05a, doc 02 §8; owner 2026-11-20): the accessory stall of the
## hacienda, Darkest Dungeon's Nomad Wagon. Each week it brings a few different
## accessories, one of each; buying one takes it off the stall until the next week. The
## dearer ones are rarer early in the campaign. Numbers: data/balance.json `feria.*`; the
## stall size and the cursed trinket on top are decided in GameState.refresh_feria (P3-05b).
## The Taller uses the same draw for its weekly weapons and armor (P3-05e, owner
## 2026-11-22), with its own numbers under data/balance.json `taller.*` (`section`).
## Pure; no nodes.

const BalanceScript := preload("res://scripts/domain/balance.gd")


## Draw weight of an item in `week`: 1 for the cheap ones; the dearer ones start at
## <section>.pricey_min_weight and reach 1 by <section>.full_stock_week.
static func weight(item: Dictionary, week: int, section: String = "feria") -> float:
	if int(item.get("price", 0)) <= BalanceScript.int_of(section + ".cheap_price"):
		return 1.0
	var lo: float = BalanceScript.num(section + ".pricey_min_weight")
	var full: float = maxf(BalanceScript.num(section + ".full_stock_week") - 1.0, 1.0)
	return lerpf(lo, 1.0, clampf((week - 1) / full, 0.0, 1.0))


## This week's stall: up to `count` different ids from `items` (item dictionaries),
## drawn by weight without repeats, in the order of `items`.
static func roll_stock(items: Array, week: int, rng: RandomNumberGenerator, count: int, section: String = "feria") -> Array:
	var pool: Array = items.filter(func(it): return it is Dictionary and str(it.get("id", "")) != "")
	var picked: Dictionary = {}
	var want: int = mini(count, pool.size())
	while picked.size() < want:
		var total: float = 0.0
		for it in pool:
			if not picked.has(str(it["id"])):
				total += weight(it, week, section)
		var roll: float = rng.randf() * total
		for it in pool:
			if picked.has(str(it["id"])):
				continue
			roll -= weight(it, week, section)
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
