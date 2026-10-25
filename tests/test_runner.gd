extends Node
## Ejecuta todos los tests y termina con código 0 (todo OK) o 1 (fallas).
##
## Uso (desde la carpeta del proyecto):
##   godot --headless --fixed-fps 60 res://tests/test_runner.tscn
## Para correr solo un archivo:  ... -- --only=test_stamina

const SUITES: Array[String] = [
	"res://tests/unit/test_stamina.gd",
	"res://tests/unit/test_localization.gd",
	"res://tests/unit/test_input_actions.gd",
	"res://tests/unit/test_settings.gd",
	"res://tests/unit/test_movement_config.gd",
	"res://tests/gameplay/test_player_movement.gd",
	"res://tests/gameplay/test_game_flow.gd",
	"res://tests/unit/test_ballistics.gd",
	"res://tests/gameplay/test_weapons.gd",
	"res://tests/gameplay/test_armory.gd",
]

var _passed: int = 0
var _failed: int = 0
var _report: PackedStringArray = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	var only := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.trim_prefix("--only=")
	var t0 := Time.get_ticks_msec()
	for path in SUITES:
		if only != "" and not path.contains(only):
			continue
		await _run_suite(path)
	var secs := (Time.get_ticks_msec() - t0) / 1000.0
	print("")
	print("==================================================")
	print("RESULTADO: %d OK, %d FALLARON  (%.1f s)" % [_passed, _failed, secs])
	for line in _report:
		print("  ✗ " + line)
	print("==================================================")
	get_tree().quit(0 if _failed == 0 else 1)


func _run_suite(path: String) -> void:
	var script := load(path) as GDScript
	if script == null:
		_failed += 1
		_report.append("%s: no se pudo cargar" % path)
		return
	print("\n▶ %s" % path.get_file())
	for m in script.get_script_method_list():
		var name: String = m["name"]
		if not name.begins_with("test_"):
			continue
		var suite := script.new() as TestCase
		suite.name = "Suite"
		add_child(suite)
		suite._current = name
		await suite.before_each()
		await suite.call(name)
		await suite.after_each()
		if suite.failures.is_empty():
			_passed += 1
			print("  ✓ %s" % name)
		else:
			_failed += 1
			for f in suite.failures:
				print("  ✗ %s" % f)
				_report.append("%s › %s" % [path.get_file(), f])
		suite.queue_free()
		await get_tree().process_frame
