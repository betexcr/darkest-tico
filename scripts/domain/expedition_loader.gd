extends RefCounted
class_name ExpeditionLoader

const DataLoaderScript := preload("res://scripts/data/data_loader.gd")

## Loads region JSON from res://data/regions/

static func load_region(path: String) -> Dictionary:
	var parsed: Variant = DataLoaderScript.load_json(path)
	if parsed is Dictionary:
		return parsed
	return {}


static func node_by_id(region: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for n in region.get("nodes", []):
		if n is Dictionary and n.has("id"):
			out[str(n["id"])] = n
	return out


static func neighbors(region: Dictionary, node_id: String) -> Array:
	var edges: Array = region.get("edges", [])
	var nexts: Array = []
	for e in edges:
		if e is Dictionary and str(e.get("from", "")) == node_id:
			nexts.append(str(e.get("to", "")))
	return nexts
