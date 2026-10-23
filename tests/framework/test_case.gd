class_name TestCase
extends Node
## Base de los tests. Cada método que empieza con "test_" es un caso.
## Los casos pueden ser asíncronos (usar await).
##
## Se ejecutan con tests/test_runner.tscn (ver docs/HOW_TO_TEST.md).

var failures: PackedStringArray = []
var _current: String = ""


## Se llama antes/después de cada caso. Sobrescribir si hace falta.
func before_each() -> void:
	pass


func after_each() -> void:
	pass


func assert_true(cond: bool, msg := "") -> void:
	if not cond:
		_fail("se esperaba verdadero. " + msg)


func assert_false(cond: bool, msg := "") -> void:
	if cond:
		_fail("se esperaba falso. " + msg)


func assert_eq(actual: Variant, expected: Variant, msg := "") -> void:
	if actual != expected:
		_fail("esperado %s, obtenido %s. %s" % [expected, actual, msg])


func assert_near(actual: float, expected: float, tolerance: float, msg := "") -> void:
	if absf(actual - expected) > tolerance:
		_fail("esperado %.3f ± %.3f, obtenido %.3f. %s" % [expected, tolerance, actual, msg])


func assert_gt(actual: float, limit: float, msg := "") -> void:
	if not actual > limit:
		_fail("se esperaba > %.3f, obtenido %.3f. %s" % [limit, actual, msg])


func assert_lt(actual: float, limit: float, msg := "") -> void:
	if not actual < limit:
		_fail("se esperaba < %.3f, obtenido %.3f. %s" % [limit, actual, msg])


## Espera N ticks de física.
func physics_frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## Espera N frames de proceso.
func process_frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _fail(msg: String) -> void:
	failures.append("%s: %s" % [_current, msg])
