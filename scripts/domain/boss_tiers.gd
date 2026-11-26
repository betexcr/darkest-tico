extends RefCounted

## Boss ladder (P6-06, doc 05 §3): a boss fights differently at Veterano and Campeón, not only
## with bigger numbers. Data: `tiers` on an enemy in data/enemies.json:
##   {"veterano": {...}, "campeon": {...}}; Campeón applies the Veterano block, then its own.
## Block keys: text (logged when the fight starts), add_skills (appended), replace_skills
## ({skill id: new skill}, so a boss keeps 1-3 specials), phases (appended),
## summon / cycle (keys given override), status_resist (added), prot (added).
## Pure rules; GameState.make_enemy calls apply() before the difficulty multipliers.

const ORDER := ["veterano", "campeon"]  # structural: the tiers above Aprendiz, in order
const LABELS := {"veterano": "Veterano", "campeon": "Campeón"}
const KEYS := ["text", "add_skills", "replace_skills", "phases", "summon", "cycle", "status_resist", "prot"]


## The tier blocks that apply at `difficulty_id`, lowest first.
static func blocks_for(enemy: Dictionary, difficulty_id: String) -> Array:
	var tiers = enemy.get("tiers", null)
	var upto: int = ORDER.find(difficulty_id)
	if not tiers is Dictionary or upto < 0:
		return []
	var out: Array = []
	for k in upto + 1:
		var b = tiers.get(ORDER[k], null)
		if b is Dictionary:
			out.append(b)
	return out


## `enemy` with its tier blocks merged in (a copy). Sets tier_label and tier_text when a block
## applied; drops `tiers` either way.
static func apply(enemy: Dictionary, difficulty_id: String) -> Dictionary:
	var en: Dictionary = enemy.duplicate(true)
	var blocks: Array = blocks_for(enemy, difficulty_id)
	en.erase("tiers")
	if blocks.is_empty():
		return en
	var texts: PackedStringArray = PackedStringArray()
	for b in blocks:
		if str(b.get("text", "")) != "":
			texts.append(str(b["text"]))
		for sk in b.get("add_skills", []):
			(en["skills"] as Array).append((sk as Dictionary).duplicate(true))
		var rep = b.get("replace_skills", null)
		if rep is Dictionary:
			var list: Array = en["skills"]
			for i in list.size():
				var sid: String = str(list[i].get("id", ""))
				if rep.has(sid):
					list[i] = (rep[sid] as Dictionary).duplicate(true)
		if b.get("phases", null) is Array:
			var ph: Array = en.get("phases", []) if en.get("phases", null) is Array else []
			for p in b["phases"]:
				ph.append((p as Dictionary).duplicate(true))
			en["phases"] = ph
		for key in ["summon", "cycle"]:
			if b.get(key, null) is Dictionary:
				var cur: Dictionary = en.get(key, {}) if en.get(key, null) is Dictionary else {}
				cur.merge(b[key], true)
				en[key] = cur
		if b.get("status_resist", null) is Dictionary:
			var sr: Dictionary = en.get("status_resist", {}) if en.get("status_resist", null) is Dictionary else {}
			for k in b["status_resist"]:
				sr[k] = int(sr.get(k, 0)) + int(b["status_resist"][k])
			en["status_resist"] = sr
		if b.has("prot"):
			en["prot"] = int(en.get("prot", 0)) + int(b["prot"])
	en["tier_label"] = str(LABELS.get(difficulty_id, difficulty_id))
	en["tier_text"] = " ".join(texts)
	return en
