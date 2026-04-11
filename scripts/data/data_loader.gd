extends RefCounted
class_name DataLoader

## Loads JSON registries from res://data/

static func load_json(path: String) -> Variant:
	var abs_path: String = path
	if not abs_path.begins_with("res://"):
		abs_path = "res://" + abs_path.trim_prefix("/")
	var f := FileAccess.open(abs_path, FileAccess.READ)
	if f == null:
		push_error("DataLoader: cannot open %s" % abs_path)
		return null
	var txt := f.get_as_text()
	var parsed: Variant = JSON.parse_string(txt)
	if parsed == null:
		push_error("DataLoader: invalid JSON %s" % abs_path)
	return parsed

static func heroes_catalog(parsed: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for h in parsed.get("heroes", []):
		if h is Dictionary and h.has("id"):
			out[h["id"]] = h
	return out

static func skills_catalog(parsed: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for s in parsed.get("skills", []):
		if s is Dictionary and s.has("id"):
			out[s["id"]] = s
	return out
