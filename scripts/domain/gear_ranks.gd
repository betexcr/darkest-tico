extends RefCounted

## Taller de Herrería y Carretas: weapon and armor ranks 1–5 (P3-05d; doc 02 §5, doc 04 §3.4),
## Darkest Dungeon's blacksmith. Each hero has a rank for their weapon slot and one for their
## armor slot; it stays with the hero when they change weapon or armor, and only counts while
## something is worn in that slot. Rank N needs resolve level skill_ranks.min_resolve[N] (as
## skill ranks do); the Taller's Forja de Machetes / Chapería de Armaduras tracks cap it.
## Numbers: data/balance.json `taller.*`. Pure; GameState owns colones and heroes.

const BalanceScript := preload("res://scripts/domain/balance.gd")
const SkillRanksScript := preload("res://scripts/domain/skill_ranks.gd")

const KINDS := ["weapon", "armor"]
const KIND_NAMES := {"weapon": "arma", "armor": "armadura"}


static func max_rank() -> int:
	return BalanceScript.int_of("taller.max_rank")


## Rank of the hero's weapon or armor slot (1 when never improved).
static func rank(hero: Dictionary, kind: String) -> int:
	var g = hero.get("gear_ranks", {})
	if not g is Dictionary:
		return 1
	return clampi(int(g.get(kind, 1)), 1, max_rank())


## Base price of rank `target` (before the Horno Eficiente discount and town events).
static func cost_for(target: int) -> int:
	var c: Array = BalanceScript.arr("taller.rank_costs")
	return int(c[target]) if target >= 0 and target < c.size() else 0


## Reliquias the rank costs on top of colones (only the last rank).
static func reliquias_for(target: int) -> int:
	return BalanceScript.int_of("taller.top_rank_reliquias") if target >= max_rank() else 0


## Stat bonus of a slot at rank `r` (nothing at rank 1): {stat: amount}.
static func bonus(kind: String, r: int) -> Dictionary:
	var n: int = maxi(r - 1, 0)
	if n == 0:
		return {}
	if kind == "weapon":
		return {"damage": n * BalanceScript.int_of("taller.weapon_damage_per_rank"),
			"accuracy": n * BalanceScript.int_of("taller.weapon_accuracy_per_rank")}
	return {"prot": n * BalanceScript.int_of("taller.armor_prot_per_rank"),
		"hp_max": n * BalanceScript.int_of("taller.armor_hp_per_rank")}


## "+2 daño, +2 precisión" for the UI.
static func bonus_text(kind: String, r: int) -> String:
	var b: Dictionary = bonus(kind, r)
	if b.is_empty():
		return "sin mejora"
	var names := {"damage": "daño", "accuracy": "precisión", "prot": "% protección", "hp_max": "PV máx."}
	var parts: PackedStringArray = PackedStringArray()
	for k in b:
		parts.append("+%d %s" % [int(b[k]), names.get(k, k)])
	return ", ".join(parts)


## "" when the next rank can be bought; otherwise why not (Spanish). `cap` = the Taller's
## current cap for this kind; `price` / `reliquias_have` are what it costs and what is in hand.
static func block_reason(hero: Dictionary, kind: String, cap: int, colones: int, price: int, reliquias_have: int) -> String:
	if bool(hero.get("dead", false)):
		return "Ya no está entre los vivos."
	var r: int = rank(hero, kind)
	if r >= max_rank():
		return "Ya está al rango máximo."
	if r >= cap:
		return "El taller todavía no trabaja %s de rango %d (mejore la %s)." % [
			"armas" if kind == "weapon" else "armaduras", r + 1,
			"Forja de Machetes" if kind == "weapon" else "Chapería de Armaduras"]
	var need: int = SkillRanksScript.min_resolve_for(r + 1)
	if int(hero.get("resolve_level", 0)) < need:
		return "Necesita resolución %d." % need
	if colones < price:
		return "No alcanza: cuesta %d ₡." % price
	if reliquias_have < reliquias_for(r + 1):
		return "Necesita %d Reliquia%s del Abuelo." % [reliquias_for(r + 1), "" if reliquias_for(r + 1) == 1 else "s"]
	return ""
