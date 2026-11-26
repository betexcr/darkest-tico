extends RefCounted

## Region hazards (P6-02, doc 05 §1): dangers a whole region has, not one room. Data: the
## region file's `hazards`, each
##   {id, name, text, trigger, chance_pct, min_light?, max_light?, outcome?, enemy_applies?, ambush_pct?}
## trigger "move": rolled on every room move; `outcome` is an event outcome (GameState.apply_event_outcome).
## trigger "fight_start": rolled when a fight starts; `outcome` on the party, `enemy_applies` on every enemy.
## trigger "camp": `ambush_pct` is added to the night-ambush chance at a fogata.
## A hazard counts only while the Luz is within [min_light, max_light] (both optional).
## Pure rules; GameState and the combat controller apply the results.

const TRIGGERS := ["move", "fight_start", "camp"]


static func all(region: Dictionary) -> Array:
	var h = region.get("hazards", [])
	return h if h is Array else []


static func in_light(h: Dictionary, light: int) -> bool:
	if h.has("min_light") and light < int(h["min_light"]):
		return false
	if h.has("max_light") and light > int(h["max_light"]):
		return false
	return true


## The region's hazards for `trigger` that count at this Luz.
static func for_trigger(region: Dictionary, trigger: String, light: int) -> Array:
	return all(region).filter(func(h): return h is Dictionary and str(h.get("trigger", "")) == trigger and in_light(h, light))


## Whether a hazard fires, given a roll in [0, 1).
static func fires(h: Dictionary, roll: float) -> bool:
	return roll * 100.0 < float(h.get("chance_pct", 0))


## Extra night-ambush chance (percentage points) from the region's camp hazards at this Luz.
static func ambush_bonus(region: Dictionary, light: int) -> int:
	var n: int = 0
	for h in for_trigger(region, "camp", light):
		n += int(h.get("ambush_pct", 0))
	return n


## Spanish lines for the hub and the start of an expedition: "Nombre: texto".
static func describe(region: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for h in all(region):
		if h is Dictionary:
			out.append("%s: %s" % [h.get("name", "?"), h.get("text", "")])
	return out
