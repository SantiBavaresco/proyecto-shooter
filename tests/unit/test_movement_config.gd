extends TestCase


func test_default_config_is_coherent() -> void:
	var c := load("res://data/player/player_movement_default.tres") as PlayerMovementConfig
	assert_true(c != null, "no cargó el recurso de movimiento")
	assert_gt(c.sprint_speed, c.walk_speed, "correr > caminar")
	assert_gt(c.walk_speed, c.crouch_speed, "caminar > agachado")
	assert_gt(c.slide_start_speed, c.sprint_speed, "deslizarse arranca más rápido que correr")
	assert_lt(c.slide_min_entry_speed, c.sprint_speed, "se puede entrar al deslizamiento corriendo")
	assert_lt(c.crouch_height, c.stand_height)
	assert_gt(c.crouch_height, c.capsule_radius * 2.0, "la cápsula agachada debe ser válida")
	# Altura del salto: v² / 2g
	var apex := c.jump_velocity * c.jump_velocity / (2.0 * 9.8)
	assert_gt(apex, 0.9, "tiene que poder subir a una caja de 1 m (con impulso)")
	assert_lt(apex, 1.4, "no debe saltar como superhéroe")
