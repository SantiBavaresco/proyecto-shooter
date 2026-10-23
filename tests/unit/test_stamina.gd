extends TestCase

var s: Stamina


func before_each() -> void:
	s = Stamina.new()
	s.configure(load("res://data/player/player_movement_default.tres"))


func test_starts_full() -> void:
	assert_eq(s.current, s.maximum)
	assert_true(s.can_sprint())


func test_drain_reduces() -> void:
	s.drain(12.0, 1.0)
	assert_near(s.current, s.maximum - 12.0, 0.001)


func test_no_regen_before_delay() -> void:
	s.drain(50.0, 1.0)
	var after := s.current
	s.tick(s.regen_delay * 0.5)
	assert_eq(s.current, after, "no debe regenerar antes del retraso")


func test_regen_after_delay() -> void:
	s.drain(50.0, 1.0)
	s.tick(s.regen_delay + 0.01)
	s.tick(1.0)
	assert_gt(s.current, 50.0)


func test_try_consume_fails_without_enough() -> void:
	s.drain(95.0, 1.0)
	assert_false(s.try_consume(10.0))
	assert_near(s.current, 5.0, 0.001, "un consumo fallido no gasta")


func test_exhaustion_and_recovery() -> void:
	s.drain(1000.0, 1.0)
	assert_true(s.exhausted)
	assert_false(s.can_sprint())
	# Regenera hasta pasar el umbral de recuperación
	s.tick(s.regen_delay + 0.01)
	for i in 200:
		s.tick(0.05)
	assert_false(s.exhausted)
	assert_true(s.can_sprint())


func test_never_exceeds_max() -> void:
	for i in 100:
		s.tick(1.0)
	assert_eq(s.current, s.maximum)
