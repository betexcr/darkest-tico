extends SceneTree

## Sound effects and UI sounds (P4-04a): every id loads, unknown ids are silent, buttons
## click, repeats are throttled, the "Efectos" volume and mute drive the SFX and UI buses,
## and the volume card works.
##   godot --headless --path . -s tests/test_sfx.gd

var _fail: int = 0


func _check(cond: bool, what: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + what)
	if not cond:
		_fail += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var sfx = root.get_node("Sfx")
	var heard: Array = []
	sfx.played.connect(func(id): heard.append(id))

	print("Buses and data")
	for b in ["SFX", "UI", "Music", "Voice"]:
		_check(AudioServer.get_bus_index(b) >= 0, "bus %s exists" % b)
	_check(sfx.ids().size() >= 40, "%d sounds in data/sfx.json" % sfx.ids().size())
	var bad: Array = []
	for id in sfx.ids():
		for f in sfx._sounds[id]["files"]:
			if sfx._stream(str(f)) == null:
				bad.append(str(f))
	_check(bad.is_empty(), "every file loads as a stream (%s)" % ", ".join(bad))

	print("Playing")
	_check(not sfx.play("no_such_sound"), "an unknown id is silent")
	_check(sfx.play("hit") and heard.has("hit"), "a known id plays")
	_check(not sfx.play("hit"), "the same id right away is throttled")
	OS.delay_msec(sfx.COOLDOWN_MS + 20)  # real time: headless timers don't wait for the clock
	_check(sfx.play("hit"), "…and plays again a moment later")

	print("Buttons")
	heard.clear()
	var b := Button.new()
	root.add_child(b)
	await process_frame
	b.pressed.emit()
	_check(heard.has("ui_click"), "every button clicks")
	var quiet := Button.new()
	quiet.set_meta("no_ui_sfx", true)
	root.add_child(quiet)
	await process_frame
	heard.clear()
	quiet.pressed.emit()
	_check(heard.is_empty(), "…unless it opts out")

	print("Volume")
	var sfx_bus: int = AudioServer.get_bus_index("SFX")
	var ui_bus: int = AudioServer.get_bus_index("UI")
	sfx.set_volume(0.5, false)
	_check(absf(AudioServer.get_bus_volume_db(sfx_bus) - linear_to_db(0.5)) < 0.01 and not AudioServer.is_bus_mute(sfx_bus)
		and absf(AudioServer.get_bus_volume_db(ui_bus) - linear_to_db(0.5)) < 0.01, "the Efectos volume drives SFX and UI")
	sfx.set_volume(0.5, true)
	_check(AudioServer.is_bus_mute(sfx_bus) and AudioServer.is_bus_mute(ui_bus), "mute silences both")
	sfx.set_volume(0.0, false)
	_check(AudioServer.is_bus_mute(sfx_bus), "volume 0 is silent too")
	_check(not FileAccess.file_exists(sfx.SETTINGS_PATH) or not sfx._settings_on, "a -s run never writes user://settings.cfg")

	print("Volume card")
	sfx.set_volume(0.8, false)
	var vb = load("res://scripts/ui/volume_button.gd").new()
	root.add_child(vb)
	await process_frame
	vb.pressed.emit()
	await process_frame
	_check(vb.slider != null and int(vb.slider.value) == 80 and not vb.mute_box.button_pressed, "the card shows the current volume")
	vb.slider.value = 30
	_check(absf(sfx.volume - 0.3) < 0.001, "moving the slider sets the volume")
	vb.mute_box.button_pressed = true
	_check(sfx.muted, "the box mutes")

	print("%d failure(s)" % _fail)
	quit(1 if _fail > 0 else 0)
