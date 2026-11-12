extends RefCounted

## Town events (Darkest Dungeon "Town Events", Tico versions). Data: data/town_events.json.
## Spec: docs/02 §12. Pure rules: drawing from the deck, eligibility, price/service/mission
## modifiers. GameState owns the state (active event, deck, graveyard…) and applies effects.

const DATA_PATH := "res://data/town_events.json"
const BalanceScript := preload("res://scripts/domain/balance.gd")

static var _data: Dictionary = {}
static var _by_id: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open(DATA_PATH, FileAccess.READ)
		if f != null:
			var parsed = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				_data = parsed
				for e in _data.get("events", []):
					if e is Dictionary:
						_by_id[str(e.get("id", ""))] = e
	return _data


static func all() -> Array:
	return data().get("events", [])


static func get_event(id: String) -> Dictionary:
	data()
	return _by_id.get(id, {})


static func chance_pct() -> int:
	return int(BalanceScript.req(data(), "chance_pct", "town_events.json"))


static func effects(ev: Dictionary) -> Dictionary:
	return ev.get("effects", {})


## ctx: {"week", "done_once": Array, "graveyard": int, "inventory": int,
##       "quebrantos": int, "quebrantos_in_party": int}
static func eligible(ev: Dictionary, ctx: Dictionary) -> bool:
	var week: int = int(ctx.get("week", 1))
	if ev.has("min_week") and week < int(ev["min_week"]):
		return false
	if ev.has("max_week") and week > int(ev["max_week"]):
		return false
	if bool(ev.get("once", false)) and ctx.get("done_once", []).has(str(ev.get("id", ""))):
		return false
	var req: Dictionary = ev.get("requires", {})
	for k in req:
		if int(ctx.get(k, 0)) < int(req[k]):
			return false
	return true


## Draws the next eligible event from the deck (a shuffled list of ids, consumed from the
## front and refilled when empty). Returns "" when no event happens this week.
## `deck` is modified in place. `roll` (0-99) decides whether an event happens at all.
static func draw(deck: Array, ctx: Dictionary, roll: int) -> String:
	if roll >= chance_pct():
		return ""
	for _pass in 2:
		if deck.is_empty():
			for e in all():
				deck.append(str(e.get("id", "")))
			deck.shuffle()
		while not deck.is_empty():
			var id: String = str(deck.pop_front())
			if eligible(get_event(id), ctx):
				return id
	return ""


# --- Modifiers while an event is active -------------------------------------------------

## Shop category of an item for price rules: weapon / armor / accessory, else consumable.
static func item_category(item: Dictionary) -> String:
	if str(item.get("usable", "")) == "equip":
		return str(item.get("slot", ""))
	return "consumable"


## Consumables that heal PV or cure ailments (the "healing" price group).
static func is_healing(item: Dictionary) -> bool:
	var fx: Dictionary = item.get("effects", {})
	return item_category(item) == "consumable" and (fx.has("heal") or fx.has("cure") or fx.has("cure_all"))


## Price change in % for this item (sum of matching groups).
static func price_pct(ev: Dictionary, item: Dictionary) -> int:
	var pp: Dictionary = effects(ev).get("price_pct", {})
	var pct: int = int(pp.get(item_category(item), 0))
	if is_healing(item):
		pct += int(pp.get("healing", 0))
	return pct


static func first_buy_pct(ev: Dictionary, item: Dictionary) -> int:
	return int(effects(ev).get("first_buy_pct", {}).get(item_category(item), 0))


## Sell rate override for this item's category, or -1.
static func sell_rate(ev: Dictionary, item: Dictionary) -> float:
	var sr: Dictionary = effects(ev).get("sell_rate", {})
	return float(sr.get(item_category(item), -1.0))


static func is_blocked(ev: Dictionary, item_id: String) -> bool:
	return effects(ev).get("blocked_items", []).has(item_id)


## service: iglesia | ebais | terminal | pulperia_compra | pulperia_venta | casa_comunal
static func is_closed(ev: Dictionary, service: String) -> bool:
	return effects(ev).get("closed", []).has(service)


## Price multiplier for a hub service (iglesia, ebais, casa_comunal).
static func service_mult(ev: Dictionary, service: String) -> float:
	return maxf(1.0 + float(effects(ev).get("service_pct", {}).get(service, 0)) / 100.0, 0.0)


## Multiplier on Iglesia stress relief.
static func relief_mult(ev: Dictionary) -> float:
	return maxf(1.0 + float(effects(ev).get("relief_pct", 0)) / 100.0, 0.0)


## Mission modifiers for an expedition in `region_id` ({} if none apply).
static func mission_mods(ev: Dictionary, region_id: String) -> Dictionary:
	var m: Dictionary = effects(ev).get("mission", {})
	if m.is_empty():
		return {}
	if m.has("region") and str(m["region"]) != region_id:
		return {}
	return m.duplicate(true)


static func removes_level_limits(ev: Dictionary) -> bool:
	return bool(effects(ev).get("mission", {}).get("no_level_limits", false))


## One line summarizing the event's effects for the hub card.
static func kind_label(ev: Dictionary) -> String:
	match str(ev.get("kind", "")):
		"positive":
			return "Buena noticia"
		"negative":
			return "Mala noticia"
	return "Suceso"


const CATEGORY_NAMES := {"consumable": "consumibles", "healing": "remedios y vendas", "weapon": "armas", "armor": "armaduras", "accessory": "accesorios"}
const SERVICE_NAMES := {"iglesia": "Iglesia Vieja", "ebais": "EBAIS", "terminal": "Terminal de Buses",
	"pulperia_compra": "Pulpería (comprar)", "pulperia_venta": "Pulpería (vender)", "casa_comunal": "Casa Comunal"}


static func _pct_text(pct: int) -> String:
	if pct <= -100:
		return "gratis"
	return "%+d%%" % pct


## Plain-language lines describing what the event changes (for the hub card). With
## `immediate`, also the one-off effects applied when it was drawn (gifts, recruits…).
static func effect_lines(ev: Dictionary, immediate: bool = true) -> PackedStringArray:
	var fx: Dictionary = effects(ev)
	var out: PackedStringArray = PackedStringArray()
	if immediate:
		if fx.has("gift_colones"):
			out.append("+%d ₡ para la hacienda" % int(fx["gift_colones"]))
		if fx.has("gift_item"):
			out.append("Regalo: una pieza de %s" % CATEGORY_NAMES.get(str(fx["gift_item"]), fx["gift_item"]))
		if fx.has("idle_stress"):
			out.append("Héroes que se quedaron: %+d estrés" % int(fx["idle_stress"]))
		if bool(fx.get("idle_cure_quebranto", false)):
			out.append("Héroes que se quedaron: salen del quebranto")
		if bool(fx.get("all_cure_quebranto", false)):
			out.append("Todos los héroes salen del quebranto")
		if fx.has("idle_class_level"):
			out.append("Héroes que se quedaron, clase %s: +1 de resolución" % str(fx["idle_class_level"]).replace("_", " "))
		if fx.get("add_recruits", null) is Dictionary:
			out.append("+%d candidatos de clase %s en la terminal" % [int(fx["add_recruits"].get("count", 1)), str(fx["add_recruits"].get("class", "")).replace("_", " ")])
		if fx.has("extra_recruits"):
			out.append("+%d candidatos en la terminal" % int(fx["extra_recruits"]))
		if fx.has("add_roster_free"):
			out.append("Un héroe se une gratis a la hacienda")
	for k in fx.get("price_pct", {}):
		out.append("Pulpería, %s: %s" % [CATEGORY_NAMES.get(k, k), _pct_text(int(fx["price_pct"][k]))])
	for k in fx.get("first_buy_pct", {}):
		out.append("Primer %s de la semana: %s" % [str(CATEGORY_NAMES.get(k, k)).trim_suffix("s"), _pct_text(int(fx["first_buy_pct"][k]))])
	for k in fx.get("sell_rate", {}):
		out.append("La pulpería compra %s al %d%% del precio" % [CATEGORY_NAMES.get(k, k), int(round(float(fx["sell_rate"][k]) * 100))])
	for c in fx.get("closed", []):
		out.append("Cerrado: %s" % SERVICE_NAMES.get(c, c))
	for k in fx.get("service_pct", {}):
		out.append("%s: %s" % [SERVICE_NAMES.get(k, k), _pct_text(int(fx["service_pct"][k]))])
	if fx.has("blocked_items"):
		out.append("Artículos que no se venden: %d" % fx["blocked_items"].size())
	if fx.has("relief_pct"):
		out.append("La misa alivia %+d%% de estrés" % int(fx["relief_pct"]))
	var m: Dictionary = fx.get("mission", {})
	var where: String = " (solo %s)" % m["region"] if m.has("region") else ""
	if m.has("xp_pct"):
		out.append("Próxima expedición%s: %+d%% XP de resolución" % [where, int(m["xp_pct"])])
	if m.has("dmg_pct"):
		out.append("Próxima expedición%s: %+d%% de daño" % [where, int(m["dmg_pct"])])
	if m.has("virtue_pct"):
		out.append("Próxima expedición: %+d%% de probabilidad de Virtud" % int(m["virtue_pct"]))
	if m.has("light_decay_pct"):
		out.append("Próxima expedición: la Luz baja %+d%%" % int(m["light_decay_pct"]))
	if m.has("loot_pct"):
		out.append("Próxima expedición: colones encontrados %+d%%" % int(m["loot_pct"]))
	if m.has("items_pct"):
		out.append("Próxima expedición: artículos encontrados %+d%%" % int(m["items_pct"]))
	if m.has("firewood"):
		out.append("Próxima expedición: +%d leña" % int(m["firewood"]))
	if bool(m.get("no_level_limits", false)):
		out.append("Ningún héroe rechaza una expedición por su resolución")
	if m.get("tough", null) is Dictionary:
		var t: Dictionary = m["tough"]
		out.append("Próxima expedición: enemigos x%.2f PV y x%.2f daño; paga x%.1f y XP x%.1f" % [
			float(t.get("enemy_hp", 1)), float(t.get("enemy_dmg", 1)), float(t.get("reward", 1)), float(t.get("xp", 1))])
	if m.has("treasure"):
		out.append("Al completar la próxima expedición: %d–%d ₡ extra" % [int(m["treasure"][0]), int(m["treasure"][1])])
	if m.has("quebranto_start_stress"):
		out.append("Próxima expedición: los quebrantados empiezan con +%d estrés" % int(m["quebranto_start_stress"]))
	if fx.has("hire_veteran"):
		out.append("En la terminal: un héroe de Resolución %d por %d ₡" % [int(BalanceScript.req(fx["hire_veteran"], "level", "town_events.json hire_veteran")), int(fx["hire_veteran"].get("price", 0))])
	if fx.has("resurrect"):
		out.append("Escoja a un caído para que vuelva")
	if fx.has("steal_items"):
		out.append("Lo robado aparece al completar la próxima expedición")
	if fx.get("offer", null) is Dictionary:
		out.append("Oferta: %s (%d ₡)" % [fx["offer"].get("label", ""), int(fx["offer"].get("cost", 0))])
	return out
