extends TestCase
## Tests de movimiento con el jugador real en la pista de pruebas,
## manejado por un bot. Correr con --fixed-fps 60 para que sean deterministas.

const LEVEL := preload("res://world/test_greybox/test_greybox.tscn")

var level: Node3D
var player: Player
var bot: BotInputProvider


func before_each() -> void:
	level = LEVEL.instantiate()
	add_child(level)
	player = level.get_node("Player")
	bot = BotInputProvider.new()
	player.set_input_provider(bot)
	await physics_frames(5)


func after_each() -> void:
	level.queue_free()
	await process_frames(1)


func _spawn(pos: Vector3, yaw := 0.0) -> void:
	player.teleport(pos, yaw)
	await physics_frames(10)  # que apoye en el piso


func _hdist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func test_walk_forward() -> void:
	await _spawn(Vector3(0, 0.05, 0))
	var start := player.global_position
	bot.move = Vector2(0, 1)
	await physics_frames(60)
	var d := _hdist(player.global_position, start)
	assert_gt(d, 3.2, "en 1 s caminando debería avanzar ~3,7 m")
	assert_lt(d, 4.2)
	assert_lt(player.global_position.z, start.z, "avanza hacia −Z (adelante)")


func test_sprint_is_faster_and_costs_stamina() -> void:
	await _spawn(Vector3(0, 0.05, 0))
	var start := player.global_position
	bot.move = Vector2(0, 1)
	bot.sprint = true
	await physics_frames(60)
	assert_true(player.is_sprinting, "debería estar corriendo")
	assert_gt(_hdist(player.global_position, start), 5.0)
	assert_lt(player.stamina.current, player.stamina.maximum - 8.0)


func test_cannot_sprint_backwards() -> void:
	await _spawn(Vector3(0, 0.05, 0))
	bot.move = Vector2(0, -1)
	bot.sprint = true
	await physics_frames(30)
	assert_false(player.is_sprinting)


func test_jump_height() -> void:
	await _spawn(Vector3(0, 0.05, 0))
	var base_y := player.global_position.y
	bot.press_jump()
	var max_y := base_y
	for i in 70:
		await physics_frames(1)
		max_y = maxf(max_y, player.global_position.y)
	var h := max_y - base_y
	assert_gt(h, 0.95, "salto mínimo para subir 1 m")
	assert_lt(h, 1.3)
	assert_true(player.is_on_floor(), "vuelve al piso")


func test_jump_costs_stamina() -> void:
	await _spawn(Vector3(0, 0.05, 0))
	bot.press_jump()
	await physics_frames(3)
	assert_near(player.stamina.current, player.stamina.maximum - player.config.jump_cost, 1.0)


func test_crouch_lowers_capsule_and_camera() -> void:
	await _spawn(Vector3(0, 0.05, 0))
	var eye_stand := player.head.global_position.y
	bot.crouch = true
	await physics_frames(40)
	assert_eq(player.stance, Player.Stance.CROUCHING)
	assert_near(player.capsule_height, player.config.crouch_height, 0.01)
	assert_lt(player.head.global_position.y, eye_stand - 0.5, "la cámara baja")
	bot.crouch = false
	await physics_frames(40)
	assert_eq(player.stance, Player.Stance.STANDING)


func test_crouch_tunnel() -> void:
	# Túnel en x = −10, de z = −4 a z = −12, techo a 1,3 m
	await _spawn(Vector3(-10, 0.05, -1.5))
	bot.move = Vector2(0, 1)
	await physics_frames(60)
	assert_gt(player.global_position.z, -4.0, "parado no debe poder entrar al túnel")

	bot.crouch = true
	await physics_frames(10)
	await physics_frames(120)
	assert_lt(player.global_position.z, -6.0, "agachado entra al túnel")

	# Soltar C adentro: no hay lugar para pararse
	bot.move = Vector2.ZERO
	bot.crouch = false
	await physics_frames(20)
	assert_eq(player.stance, Player.Stance.CROUCHING, "bajo techo sigue agachado")

	# Salir del otro lado y pararse solo
	bot.move = Vector2(0, 1)
	await physics_frames(240)
	assert_lt(player.global_position.z, -12.5, "sale del túnel")
	assert_eq(player.stance, Player.Stance.STANDING, "al salir se para")


func test_slide() -> void:
	await _spawn(Vector3(0, 0.05, 0))
	bot.move = Vector2(0, 1)
	bot.sprint = true
	await physics_frames(45)
	bot.crouch = true
	await physics_frames(3)
	assert_eq(player.stance, Player.Stance.SLIDING, "correr + C = deslizarse")
	var hspeed := Vector2(player.velocity.x, player.velocity.z).length()
	assert_gt(hspeed, player.config.sprint_speed, "el deslizamiento arranca más rápido que correr")
	await physics_frames(70)
	assert_eq(player.stance, Player.Stance.CROUCHING, "termina agachado si sigue apretando C")


func test_slide_needs_sprint() -> void:
	await _spawn(Vector3(0, 0.05, 0))
	bot.move = Vector2(0, 1)
	await physics_frames(45)
	bot.crouch = true
	await physics_frames(3)
	assert_eq(player.stance, Player.Stance.CROUCHING, "caminando + C = agacharse")


func test_lean_open_space() -> void:
	await _spawn(Vector3(0, 0.05, 0))
	bot.lean = 1.0
	await process_frames(60)
	assert_gt(player.lean_node.position.x, 0.3, "inclinación a la derecha")
	bot.lean = -1.0
	await process_frames(90)
	assert_lt(player.lean_node.position.x, -0.3, "inclinación a la izquierda")


func test_lean_blocked_by_wall() -> void:
	# Pared con cara en x = 3,75; el jugador a 0,45 m mirando −Z
	await _spawn(Vector3(3.3, 0.05, -40))
	bot.lean = 1.0
	await process_frames(60)
	assert_lt(player.lean_node.position.x, 0.28, "la pared limita la inclinación")
	var cam := player.camera.global_position
	assert_lt(cam.x, 3.75 - 0.05, "la cámara no atraviesa la pared")


func test_stamina_exhaustion_forces_walk() -> void:
	await _spawn(Vector3(-50, 0.05, 30), 0.0)
	bot.move = Vector2(0, 1)
	bot.sprint = true
	# 100 de estamina a 12/s → ~8,3 s
	await physics_frames(60 * 9)
	assert_true(player.stamina.exhausted, "se agota")
	assert_false(player.is_sprinting, "agotado no puede correr")
	var hspeed := Vector2(player.velocity.x, player.velocity.z).length()
	assert_near(hspeed, player.config.walk_speed, 0.4, "camina")


func test_gentle_ramp_climbable_steep_not() -> void:
	# Rampa de 20° en x = 14; de 55° en x = 26. Ambas suben hacia −Z desde z = −22.
	await _spawn(Vector3(14, 0.05, -20))
	bot.move = Vector2(0, 1)
	await physics_frames(150)
	assert_gt(player.global_position.y, 1.0, "sube la rampa de 20°")

	bot.move = Vector2.ZERO
	await _spawn(Vector3(26, 0.05, -20))
	bot.move = Vector2(0, 1)
	await physics_frames(150)
	assert_lt(player.global_position.y, 1.2, "no sube la rampa de 55°")


func test_stairs_climbable() -> void:
	# Escalera en x = 34: arranca en z = −18 y sube hacia −Z
	await _spawn(Vector3(34, 0.05, -15.5))
	bot.move = Vector2(0, 1)
	await physics_frames(180)
	assert_gt(player.global_position.y, 1.8, "sube la escalera")
