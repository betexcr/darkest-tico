extends SceneTree

## Save safety (P1-19): scripts never touch the real save; writes go through a temp file and
## keep a .bak; an unreadable save is copied aside and the .bak is loaded instead.
##   godot --headless --path . -s tests/test_save.gd

var _fail: int = 0


func _check(cond: bool, what: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + what)
	if not cond:
		_fail += 1


func _initialize() -> void:
	_run.call_deferred()


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _colones_in(path: String) -> int:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return -1
	var d: Variant = JSON.parse_string(f.get_as_text())
	return int(d["colones"]) if d is Dictionary else -1


func _broken_copies(dir: String) -> int:
	var n: int = 0
	for f in DirAccess.get_files_at(dir):
		if f.contains(".broken-"):
			n += 1
	return n


func _clean(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	DirAccess.remove_absolute(dir)


func _run() -> void:
	await process_frame
	var gs = root.get_node("GameState")
	var svc = root.get_node("SaveService")

	# 1) A -s script never uses the real save.
	_check(svc.is_script_run(), "a -s run is detected")
	_check(not svc.enabled, "saving is off while a script runs")
	var dir: String = "user://test_save_%d" % OS.get_process_id()
	_clean(dir)
	DirAccess.make_dir_recursive_absolute(dir)
	var path: String = dir.path_join("save.json")
	var bak: String = svc.backup_path(path)
	svc.save_path = path
	svc.save_game()
	_check(not FileAccess.file_exists(path), "save_game() writes nothing while disabled")
	_check(not svc.load_game(), "load_game() reads nothing while disabled")

	# 2) Writes: temp file, then rename; the previous good save becomes .bak.
	gs.reset_party_from_catalog()
	gs.colones = 1111
	_check(svc.save_to(path, gs.to_save_dict()), "first save written")
	_check(_colones_in(path) == 1111 and not FileAccess.file_exists(bak), "first save: no .bak yet")
	_check(not FileAccess.file_exists(path + ".tmp"), "no temp file left behind")
	gs.colones = 2222
	svc.save_to(path, gs.to_save_dict())
	_check(_colones_in(path) == 2222 and _colones_in(bak) == 1111, "second save: the old one is the .bak")

	# 3) An unreadable save (half-written) is copied aside and the .bak loads.
	_write(path, "{\"colones\": 22")
	gs.colones = 0
	_check(svc.load_from(path), "a broken save falls back to the .bak")
	_check(gs.colones == 1111, "the .bak's campaign is loaded (colones %d)" % gs.colones)
	_check(_broken_copies(dir) == 1, "the broken file is copied aside")
	# Saving now must not turn the broken file into the backup.
	gs.colones = 3333
	svc.save_to(path, gs.to_save_dict())
	_check(_colones_in(path) == 3333 and _colones_in(bak) == 1111, "saving after a broken load keeps the good .bak")

	# 4) Both unreadable: load fails, nothing is lost.
	_write(path, "")
	_write(bak, "not json")
	_check(not svc.load_from(path), "load fails when save and .bak are both unreadable")
	_check(_broken_copies(dir) >= 1 and FileAccess.file_exists(bak), "both files are still on disk")

	# 5) A missing save is just a new game.
	_clean(dir)
	DirAccess.make_dir_recursive_absolute(dir)
	_check(not svc.load_from(path), "no save file: new game")

	_clean(dir)
	svc.save_path = svc.SAVE_PATH
	print("%d failure(s)" % _fail)
	quit(1 if _fail > 0 else 0)
