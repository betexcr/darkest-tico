extends RefCounted

## Luz tiers (P1-17, DD torch): how bright the candle is changes enemy danger, the stress
## heroes take, loot, who gets surprised, trap disarming and the stress of walking in the
## dark. Numbers: data/balance.json "light". Pure; no nodes.

const BalanceScript := preload("res://scripts/domain/balance.gd")


## Every tier, brightest first.
static func tiers() -> Array:
	return BalanceScript.arr("light.tiers")


## The tier `light` falls in: the first (brightest) tier whose min it reaches.
static func tier(light: int) -> Dictionary:
	var all: Array = tiers()
	for t in all:
		if light >= int(BalanceScript.req(t, "min", "balance.json light.tiers")):
			return t
	return all[-1] if not all.is_empty() else {}


## A number from the tier (strict: a missing key is a push_error, never a silent default).
static func val(light: int, key: String) -> int:
	return int(BalanceScript.req(tier(light), key, "balance.json light.tiers"))


static func tier_name(light: int) -> String:
	return str(tier(light).get("name", ""))


## Low light for the camp ambush (Penumbra and darker).
static func is_low(light: int) -> bool:
	return bool(BalanceScript.req(tier(light), "low", "balance.json light.tiers"))


## Loot multiplier (fights and curios) at this light.
static func loot_mult(light: int) -> float:
	return 1.0 + val(light, "loot_pct") / 100.0


## "party" (enemies act first), "enemies" (heroes act first) or "" for a normal fight.
static func roll_surprise(light: int) -> String:
	var r: int = randi() % 100
	var party: int = val(light, "party_surprised_pct")
	if r < party:
		return "party"
	if r < party + val(light, "enemies_surprised_pct"):
		return "enemies"
	return ""


## Stress walking one room at this light: {amount, all} (all = every hero, else one at random).
static func move_stress(light: int) -> Dictionary:
	return {"amount": val(light, "move_stress"), "all": bool(BalanceScript.req(tier(light), "move_stress_all", "balance.json light.tiers"))}


## Tooltip body for the HUD (Spanish).
static func effects_text(light: int) -> String:
	var lines: PackedStringArray = PackedStringArray()
	var dmg: int = val(light, "enemy_dmg_pct")
	var crit: int = val(light, "enemy_crit")
	if dmg != 0 or crit != 0:
		lines.append("Enemigos: %+d%% daño, %+d crítico." % [dmg, crit])
	if val(light, "stress_pct") != 0:
		lines.append("La cuadrilla recibe %+d%% de estrés en combate." % val(light, "stress_pct"))
	if val(light, "loot_pct") != 0:
		lines.append("Botín: %+d%% colones." % val(light, "loot_pct"))
	lines.append("Sorpresa: %d%% que los sorprendan, %d%% de sorprenderlos." % [val(light, "party_surprised_pct"), val(light, "enemies_surprised_pct")])
	if val(light, "trap_pct") != 0:
		lines.append("Desarmar trampas: %+d%%." % val(light, "trap_pct"))
	var ms: Dictionary = move_stress(light)
	if int(ms["amount"]) > 0:
		lines.append("Caminar a oscuras: +%d estrés a %s por sala." % [int(ms["amount"]), "todos" if ms["all"] else "alguien"])
	return "\n".join(lines)
