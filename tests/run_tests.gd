extends SceneTree

## Runs every test (P1-01): tests/smoke_expedition.gd and each tests/test_*.gd, one Godot
## process each (every test is its own SceneTree script that quits with 0 or 1), and exits 1
## if any of them failed: a non-zero exit, a "SCRIPT ERROR" in its output, or no exit at all
## within the time limit. New test files join automatically.
##   godot --headless --path . -s tests/run_tests.gd
##   godot --headless --path . -s tests/run_tests.gd -- --only test_hub,test_ui
##   godot --headless --path . -s tests/run_tests.gd -- --skip smoke_expedition --verbose
## --verbose prints each test's own output; otherwise only the failing ones' lines are shown.

const TEST_DIR := "res://tests"


func _initialize() -> void:
	_run.call_deferred()


func _names() -> Array:
	var out: Array = []
	for f in DirAccess.get_files_at(TEST_DIR):
		if f.ends_with(".gd") and (f.begins_with("test_") or f == "smoke_expedition.gd"):
			out.append(f.get_basename())
	out.sort()
	# The smoke test plays whole expeditions: run it first, as AGENTS.md lists it.
	if out.has("smoke_expedition"):
		out.erase("smoke_expedition")
		out.push_front("smoke_expedition")
	return out


func _list_arg(args: PackedStringArray, flag: String) -> Array:
	var k: int = args.find(flag)
	if k < 0 or k + 1 >= args.size():
		return []
	return Array(args[k + 1].split(",", false)).map(func(x): return str(x).strip_edges().trim_suffix(".gd"))


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var only: Array = _list_arg(args, "--only")
	var skip: Array = _list_arg(args, "--skip")
	var verbose: bool = args.has("--verbose")
	var names: Array = _names().filter(func(n): return (only.is_empty() or only.has(n)) and not skip.has(n))
	if names.is_empty():
		print("run_tests: no test matches")
		quit(1)
		return
	var exe: String = OS.get_executable_path()
	var project: String = ProjectSettings.globalize_path("res://")
	var failed: Array = []
	var t_all: int = Time.get_ticks_msec()
	print("Running %d test(s)" % names.size())
	for n in names:
		var t0: int = Time.get_ticks_msec()
		var output: Array = []
		var code: int = OS.execute(exe, ["--headless", "--path", project, "-s", "%s/%s.gd" % [TEST_DIR, n]], output, true)
		var text: String = "\n".join(output.map(func(x): return str(x)))
		var errors: int = text.count("SCRIPT ERROR")
		var m := RegEx.create_from_string("(\\d+) failure\\(s\\)").search(text)
		var summary: String = ("%s failure(s)" % m.get_string(1)) if m != null else ("exit %d" % code)
		var ok: bool = code == 0 and errors == 0
		print("%s  %-26s %6.1f s  %s%s" % ["ok  " if ok else "FAIL", n, (Time.get_ticks_msec() - t0) / 1000.0, summary,
			("  %d SCRIPT ERROR" % errors) if errors > 0 else ""])
		if verbose or not ok:
			for line in text.split("\n"):
				if verbose or line.contains("FAIL") or line.contains("SCRIPT ERROR") or line.strip_edges().begins_with("at: res://"):
					print("      " + line)
		if not ok:
			failed.append(n)
	print("%d of %d passed in %.0f s%s" % [names.size() - failed.size(), names.size(), (Time.get_ticks_msec() - t_all) / 1000.0,
		("; failed: " + ", ".join(failed)) if not failed.is_empty() else ""])
	quit(1 if not failed.is_empty() else 0)
