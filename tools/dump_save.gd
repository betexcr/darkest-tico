extends SceneTree

## P3-08 fixture maker: run inside an OLD checkout of the game. Plays nothing; sets a campaign
## with some progress through whatever API that version has, then writes to_save_dict() as JSON.
##   godot --headless --path <old checkout> -s dump_save.gd -- <out.json>

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var out: String = OS.get_cmdline_user_args()[0]
	var gs = root.get_node_or_null("GameState")
	if gs == null:
		print("no GameState")
		quit(2)
		return
	if gs.has_method("reset_party_from_catalog"):
		gs.reset_party_from_catalog()
	if "colones" in gs:
		gs.colones = 4321
	if "week" in gs:
		gs.week = 6
	if gs.has_method("add_item"):
		gs.add_item("gallo_pinto", 3)
		gs.add_item("venda", 2)
	var heroes: Array = gs.get("roster") if "roster" in gs else gs.get("party")
	if heroes is Array and not heroes.is_empty():
		var h: Dictionary = heroes[0]
		h["stress"] = 37
		h["hp"] = maxi(1, int(h.get("hp", 10)) - 3)
		if h.has("resolve_xp") or "resolve_level" in h:
			h["resolve_level"] = 2
		if gs.has_method("add_item") and gs.has_method("equip"):
			gs.add_item("machete_cartago", 1)
			gs.equip(h, "machete_cartago")
	var d: Dictionary = gs.to_save_dict()
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string(JSON.stringify(d, "  "))
	f.close()
	print("wrote v%s with %d keys" % [str(d.get("version", "?")), d.size()])
	quit(0)
