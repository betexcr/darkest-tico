extends SceneTree

## Renders the hub's Pulpería (icon tiles) and the item tooltip card, for review.
##   xvfb-run -a godot --path . --rendering-driver opengl3 -s tools/screens/shop_screenshot.gd -- <out_dir>
## Saves shop.png (hub), shop_tooltip.png (hovering a tile) and item_cards.png (a few cards side by side).

func _initialize() -> void:
	_run.call_deferred()


func _snap(out_dir: String, file: String) -> void:
	for i in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out_dir.path_join(file))


func _run() -> void:
	var out_dir: String = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "user://"
	await process_frame
	root.size = Vector2i(1280, 720)
	var gs = root.get_node("GameState")
	gs.reset_party_from_catalog()
	gs.reset_inventory_to_starter()
	gs.colones = 1500
	var hub = load("res://scenes/hacienda/hacienda_hub.tscn").instantiate()
	root.add_child(hub)
	await _snap(out_dir, "shop.png")
	# Hover a tile and wait for Godot's tooltip delay.
	var tile: Control = hub._shop_grid.get_child(8)
	var ev := InputEventMouseMotion.new()
	ev.position = tile.get_global_rect().get_center()
	ev.global_position = ev.position
	root.push_input(ev)
	await create_timer(1.2).timeout
	await _snap(out_dir, "shop_tooltip.png")
	hub.queue_free()
	# The cards themselves, over a bright background to show they are opaque.
	var bg := ColorRect.new()
	bg.color = Color(0.75, 0.7, 0.6)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var row := HBoxContainer.new()
	row.position = Vector2(20, 20)
	row.add_theme_constant_override("separation", 14)
	bg.add_child(row)
	# Loaded here, not preloaded: a -s script compiles before the autoloads exist.
	var ItemTooltipScript = load("res://scripts/ui/item_tooltip.gd")
	var ids: Array = ["gallo_pinto", "machete_cartago", "cotona_de_cuero", "termo_de_cafe"]
	for i in ids.size():
		var card: Control = ItemTooltipScript.build(str(ids[i]), "Clic para comprar." if i < 3 else "", "" if i < 3 else "No alcanza la plata.")
		card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(card)
	await _snap(out_dir, "item_cards.png")
	print("saved to ", out_dir)
	quit(0)
