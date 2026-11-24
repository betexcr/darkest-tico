extends RefCounted

## Unlockable skills (P3-17, owner 2026-11-23, Darkest Dungeon style): each class has 7 skills,
## the 4 a recruit knows (`skill_ids` in data/heroes.json, basic attack first) and 3 more
## (`extra_skill_ids`) learned once per hero at the Casa Comunal. A hero brings 4 of the skills
## they know: `hero.skill_ids` is always that loadout (combat, the bots and the UI read it),
## `hero.skill_known` every skill they have learned. Swaps are free in town, never on an
## expedition, and slot 0 (the class's basic attack) never changes.
## Pure rules; GameState owns colones, heroes and the prices.

const FormationScript := preload("res://scripts/domain/formation.gd")

## Slots in a loadout; slot 0 is the basic attack.
const LOADOUT_SIZE := 4  # structural: a hero brings 4 skills (doc 03, owner rule)


## Every skill of the class: the starter 4, then the 3 to learn.
static func class_skills(template: Dictionary) -> Array:
	var out: Array = []
	for sid in template.get("skill_ids", []) + template.get("extra_skill_ids", []):
		if not out.has(str(sid)):
			out.append(str(sid))
	return out


## Skills this hero knows (the loadout always counts, for heroes saved before P3-17).
static func known(hero: Dictionary) -> Array:
	var out: Array = []
	var raw = hero.get("skill_known", [])
	for sid in (raw if raw is Array else []) + hero.get("skill_ids", []):
		if not out.has(str(sid)):
			out.append(str(sid))
	return out


static func knows(hero: Dictionary, sid: String) -> bool:
	return known(hero).has(sid)


## Class skills the hero hasn't learned yet, in class order.
static func learnable(hero: Dictionary, template: Dictionary) -> Array:
	return class_skills(template).filter(func(sid): return not knows(hero, str(sid)))


## Known skills left at home (not in the 4 brought), in class order.
static func benched(hero: Dictionary, template: Dictionary) -> Array:
	var brought: Array = hero.get("skill_ids", [])
	return class_skills(template).filter(func(sid): return knows(hero, str(sid)) and not brought.has(sid))


## "" when the hero can learn `sid` for `price`; otherwise why not (Spanish, for the UI).
static func learn_block_reason(hero: Dictionary, template: Dictionary, sid: String, colones: int, price: int) -> String:
	if not class_skills(template).has(sid):
		return "No es una habilidad de su oficio."
	if knows(hero, sid):
		return "Ya la sabe."
	if bool(hero.get("dead", false)):
		return "Ya no está entre los vivos."
	if colones < price:
		return "No alcanza: aprenderla cuesta %d ₡." % price
	return ""


## The loadout after putting `sid` in `slot` (a skill already brought swaps places with it).
static func swapped(hero: Dictionary, slot: int, sid: String) -> Array:
	var ids: Array = (hero.get("skill_ids", []) as Array).duplicate()
	var at: int = ids.find(sid)
	if at >= 0:
		ids[at] = ids[slot]
	ids[slot] = sid
	return ids


## Whether a loadout can hit enemy position 1 from one of the class's positions (the
## validator's no-stall rule for the starter 4, checked here for every loadout).
static func reaches_front(ids: Array, template: Dictionary, skill_of: Callable) -> bool:
	var ranks: Array = template.get("ranks", [])
	for sid in ids:
		var sk: Dictionary = skill_of.call(str(sid))
		if str(sk.get("kind", "")) != "attack":
			continue
		var uses: Array = FormationScript.use_ranks(sk)
		if ranks.any(func(r): return uses.has(int(r))) and FormationScript.target_ranks(sk).has(1):
			return true
	return false


## "" when `sid` can go in `slot`; otherwise why not. `skill_of` maps a skill id to its data.
static func swap_block_reason(hero: Dictionary, template: Dictionary, slot: int, sid: String,
		on_expedition: bool, skill_of: Callable) -> String:
	var ids: Array = hero.get("skill_ids", [])
	if on_expedition:
		return "En plena expedición no se cambian las habilidades."
	if slot < 0 or slot >= mini(ids.size(), LOADOUT_SIZE):
		return "No hay ese espacio."
	if slot == 0 or (not ids.is_empty() and sid == str(ids[0])):
		return "El ataque básico del oficio siempre va primero."
	if not class_skills(template).has(sid):
		return "No es una habilidad de su oficio."
	if not knows(hero, sid):
		return "Todavía no la sabe: se aprende en la Casa Comunal."
	if str(ids[slot]) == sid:
		return "Ya la lleva ahí."
	if not reaches_front(swapped(hero, slot, sid), template, skill_of):
		return "Así no tendría con qué pegarle al enemigo de adelante."
	return ""
