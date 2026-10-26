class_name Player
extends CharacterBody3D
## Controlador del jugador en primera persona.
##
## Estructura de nodos (ver player.tscn):
##   Player (CharacterBody3D, origen en los pies)
##   ├─ Collision (cápsula; cambia de altura al agacharse)
##   └─ Head (top_level, sin interpolación: sigue al cuerpo en _process)
##      └─ Pitch (rotación vertical)
##         └─ Lean (desplazamiento y rolido al inclinarse)
##            └─ Camera3D (bamboleo al caminar)
##
## La mirada se aplica en _process (sin latencia); el movimiento en
## _physics_process con interpolación de física para que se vea fluido a
## cualquier tasa de refresco.

enum Stance { STANDING, CROUCHING, SLIDING }

const DEFAULT_CONFIG := preload("res://data/player/player_movement_default.tres")
const PITCH_LIMIT := deg_to_rad(89.0)
const LEAN_WALL_MARGIN := 0.22

@export var config: PlayerMovementConfig

var input_provider: InputProvider
var stamina: Stamina = Stamina.new()
## Estrés de combate (por ahora lo fijan las zonas de prueba).
var stress: Stress = Stress.new()
## Zonas de prueba en las que está parado (ver TestZone).
var zone_kinds: PackedStringArray = PackedStringArray()
## Deriva de la mira por estrés (rad): se suma a la mirada sin cambiar yaw/pitch.
var aim_drift: Vector2 = Vector2.ZERO
var stance: Stance = Stance.STANDING

var yaw: float = 0.0
var pitch_angle: float = 0.0
var lean_amount: float = 0.0
## Altura actual de la cápsula (cambia instantáneamente).
var capsule_height: float = 1.8
## Altura de ojos suavizada (la cámara baja/sube con transición).
var eye_height: float = 1.66
var is_sprinting: bool = false
## Armas del jugador (se crean en _ready).
var weapons: WeaponController
## Rotación de mirada aplicada en el último frame (la usa el balanceo del arma).
var last_look: Vector2 = Vector2.ZERO

# Retroceso: lo que falta aplicar de la patada, lo acumulado en la ráfaga
# y lo que la cámara recupera sola al soltar el gatillo.
var _recoil_pending: Vector2 = Vector2.ZERO
var _recoil_accum: Vector2 = Vector2.ZERO
var _recoil_recover: Vector2 = Vector2.ZERO
var _recoil_recovery_frac: float = 0.6
var _since_recoil: float = 999.0

var _coyote: float = 0.0
var _jump_buffer: float = 0.0
var _slide_time: float = 0.0
var _slide_cooldown: float = 0.0
var _slide_dir: Vector3 = Vector3.ZERO
var _was_on_floor: bool = true
var _prev_vel_y: float = 0.0
var _bob_time: float = 0.0
var _last_cmd: PlayerCommand = PlayerCommand.new()
var _stamina_emit_accum: float = 0.0

@onready var collision: CollisionShape3D = $Collision
@onready var body_shadow: MeshInstance3D = $BodyShadow
@onready var head: Node3D = $Head
@onready var pitch_node: Node3D = $Head/Pitch
@onready var lean_node: Node3D = $Head/Pitch/Lean
@onready var camera: Camera3D = $Head/Pitch/Lean/Camera3D


func _ready() -> void:
	add_to_group("player")
	if config == null:
		config = DEFAULT_CONFIG
	stamina.configure(config)
	# La forma se duplica para que cambiar su altura no afecte otras instancias.
	collision.shape = collision.shape.duplicate()
	body_shadow.mesh = body_shadow.mesh.duplicate()
	(collision.shape as CapsuleShape3D).radius = config.capsule_radius
	_set_capsule_height(config.stand_height)
	eye_height = _target_eye_height()
	yaw = rotation.y
	rotation = Vector3.ZERO
	if input_provider == null:
		var human := HumanInputProvider.new()
		human.name = "HumanInput"
		add_child(human)
		input_provider = human
	weapons = WeaponController.new()
	weapons.name = "Weapons"
	add_child(weapons)
	weapons.setup(self)
	var ov := StressOverlay.new()
	ov.name = "StressOverlay"
	ov.player = self
	add_child(ov)
	_update_head_transform()
	EventBus.player_spawned.emit(self)
	EventBus.stamina_changed.emit(stamina.current, stamina.maximum)


## Reemplaza la fuente de input (los tests usan un bot).
func set_input_provider(provider: InputProvider) -> void:
	if input_provider != null and input_provider.get_parent() == self:
		input_provider.queue_free()
	input_provider = provider
	if provider.get_parent() == null:
		add_child(provider)


## Teletransporta al jugador (sin interpolar el salto).
func teleport(pos: Vector3, facing_yaw: float = NAN) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	if not is_nan(facing_yaw):
		yaw = facing_yaw
	reset_physics_interpolation()
	_update_head_transform()


# --- Cada frame: mirada y cámara ------------------------------------------

func _process(delta: float) -> void:
	var look := input_provider.consume_look(delta)
	if weapons != null:
		look *= weapons.look_mult()
	last_look = look
	yaw = wrapf(yaw - look.x, -PI, PI)
	pitch_angle = clampf(pitch_angle - look.y, -PITCH_LIMIT, PITCH_LIMIT)
	_update_recoil(delta)
	aim_drift = stress.aim_drift(weapons.ads_amount if weapons != null else 0.0)
	eye_height = lerpf(eye_height, _target_eye_height(), 1.0 - exp(-config.stance_lerp_speed * delta))
	_update_lean(delta)
	_update_camera_effects(delta)
	_update_head_transform()


## Patada de retroceso: sube la mira (pitch) y la desvía (yaw), en radianes.
## `recovery` es la fracción que la cámara recupera sola al dejar de disparar.
func apply_recoil(pitch: float, yaw_kick: float, recovery: float) -> void:
	_recoil_pending += Vector2(yaw_kick, pitch)
	_recoil_recovery_frac = recovery
	_since_recoil = 0.0
	_recoil_recover = Vector2.ZERO


func _update_recoil(delta: float) -> void:
	_since_recoil += delta
	# La patada se aplica en ~50 ms para que no sea un salto seco
	if _recoil_pending.length_squared() > 0.0:
		var step := _recoil_pending * minf(1.0, delta * 28.0)
		if _recoil_pending.length() < 0.0005:
			step = _recoil_pending
		_recoil_pending -= step
		_recoil_accum += step
		yaw = wrapf(yaw - step.x, -PI, PI)
		pitch_angle = clampf(pitch_angle + step.y, -PITCH_LIMIT, PITCH_LIMIT)
	# Al dejar de disparar, la cámara vuelve una parte hacia donde apuntabas
	if _since_recoil > 0.12 and _recoil_accum.length_squared() > 0.0:
		_recoil_recover = _recoil_accum * _recoil_recovery_frac
		_recoil_accum = Vector2.ZERO
	if _recoil_recover.length_squared() > 0.0:
		var back := _recoil_recover * minf(1.0, delta * 7.0)
		if _recoil_recover.length() < 0.0003:
			back = _recoil_recover
		_recoil_recover -= back
		yaw = wrapf(yaw + back.x, -PI, PI)
		pitch_angle = clampf(pitch_angle - back.y, -PITCH_LIMIT, PITCH_LIMIT)


func _update_head_transform() -> void:
	var base := get_global_transform_interpolated().origin if is_inside_tree() else global_position
	head.global_position = base + Vector3(0.0, eye_height, 0.0)
	head.rotation = Vector3(0.0, yaw + aim_drift.x, 0.0)
	pitch_node.rotation = Vector3(pitch_angle + aim_drift.y, 0.0, 0.0)


func _update_lean(delta: float) -> void:
	var target := _last_cmd.lean
	if stance == Stance.SLIDING or is_sprinting:
		target = 0.0
	lean_amount = move_toward(lean_amount, target, config.lean_speed * delta)
	var offset := lean_amount * config.lean_offset
	if absf(offset) > 0.001:
		offset = signf(offset) * minf(absf(offset), _lean_free_space(signf(offset)))
	lean_node.position = Vector3(offset, -absf(lean_amount) * 0.06, 0.0)
	lean_node.rotation = Vector3(0.0, 0.0, -lean_amount * deg_to_rad(config.lean_angle_deg))


## Espacio libre hacia el costado para inclinarse sin meter la cámara en la pared.
func _lean_free_space(side: float) -> float:
	var space := get_world_3d().direct_space_state
	var from := head.global_position
	var right := head.global_basis.x * side
	var q := PhysicsRayQueryParameters3D.create(from, from + right * (config.lean_offset + LEAN_WALL_MARGIN))
	q.exclude = [get_rid()]
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return config.lean_offset
	return maxf(0.0, from.distance_to(hit["position"]) - LEAN_WALL_MARGIN)


func _update_camera_effects(delta: float) -> void:
	var base_fov: float = Settings.get_value("video", "fov")
	var target_fov := base_fov * (weapons.fov_mult() if weapons != null else 1.0)
	if stance == Stance.SLIDING:
		target_fov += config.slide_fov_bonus
	elif is_sprinting:
		target_fov += config.sprint_fov_bonus
	camera.fov = lerpf(camera.fov, target_fov, 1.0 - exp(-config.fov_lerp_speed * delta))

	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	var bob_on: bool = Settings.get_value("controls", "head_bob") and (weapons == null or weapons.ads_amount < 0.5)
	if bob_on and is_on_floor() and horizontal_speed > 0.5 and stance != Stance.SLIDING:
		_bob_time += delta * config.bob_frequency * TAU * (horizontal_speed / config.walk_speed) * 0.5
		var amp := config.bob_amplitude * clampf(horizontal_speed / config.walk_speed, 0.0, 1.6)
		camera.position = Vector3(cos(_bob_time * 0.5) * amp * 0.6, absf(sin(_bob_time)) * amp, 0.0)
	else:
		camera.position = camera.position.lerp(Vector3.ZERO, 1.0 - exp(-10.0 * delta))


## Zonas de prueba: fijan el estrés objetivo; el arma consulta "worn".
func _update_zones(delta: float) -> void:
	zone_kinds = TestZone.kinds_at(get_tree(), global_position) if is_inside_tree() else PackedStringArray()
	var lvl := 0
	if zone_kinds.has("stress_extreme"):
		lvl = 3
	elif zone_kinds.has("stress_high"):
		lvl = 2
	elif zone_kinds.has("stress_medium"):
		lvl = 1
	stress.set_level(lvl)
	stress.tick(delta)


# --- Física ---------------------------------------------------------------

func _physics_process(delta: float) -> void:
	var cmd := input_provider.poll_command(delta)
	_last_cmd = cmd
	stamina.tick(delta)
	_update_zones(delta)
	_slide_cooldown = maxf(0.0, _slide_cooldown - delta)

	var on_floor := is_on_floor()
	_coyote = config.coyote_time if on_floor else _coyote - delta
	_jump_buffer = config.jump_buffer if cmd.jump else _jump_buffer - delta

	var wish := _wish_direction(cmd)
	is_sprinting = _can_sprint(cmd, on_floor)
	_update_stance(cmd, on_floor)

	# Movimiento horizontal
	var hvel := Vector3(velocity.x, 0.0, velocity.z)
	if stance == Stance.SLIDING:
		hvel = _slide_velocity(wish, delta)
	else:
		var target_speed := _target_speed()
		var target := wish * target_speed
		if on_floor:
			# Aceleración en m/s²: da sensación de peso sin volverse lento.
			var rate := config.ground_accel if wish.length() > 0.01 else config.ground_decel
			hvel = hvel.move_toward(target, rate * delta)
		elif wish.length() > 0.01:
			# En el aire se conserva el impulso; solo hay un poco de control.
			hvel = hvel.move_toward(target, config.ground_accel * config.air_control * delta)
	if is_sprinting and wish.length() > 0.1 and on_floor:
		stamina.drain(config.sprint_cost_per_sec, delta)

	# Vertical: gravedad y salto
	var vy := velocity.y
	if not on_floor:
		var mult := config.gravity_up_mult if vy > 0.0 else config.gravity_down_mult
		vy = maxf(vy - _gravity() * mult * delta, -config.max_fall_speed)
	if _jump_buffer > 0.0 and _coyote > 0.0 and _try_jump():
		vy = config.jump_velocity
		_jump_buffer = 0.0
		_coyote = 0.0

	velocity = Vector3(hvel.x, vy, hvel.z)
	_prev_vel_y = velocity.y
	move_and_slide()

	var now_on_floor := is_on_floor()
	if now_on_floor and not _was_on_floor:
		EventBus.player_landed.emit(-_prev_vel_y)
	_was_on_floor = now_on_floor

	if weapons != null:
		weapons.physics_tick(cmd, delta)

	_stamina_emit_accum += delta
	if _stamina_emit_accum >= 0.05:
		_stamina_emit_accum = 0.0
		EventBus.stamina_changed.emit(stamina.current, stamina.maximum)


func _wish_direction(cmd: PlayerCommand) -> Vector3:
	var m := cmd.move.limit_length(1.0)
	var basis := Basis(Vector3.UP, yaw)
	return basis * Vector3(m.x, 0.0, -m.y)


func _can_sprint(cmd: PlayerCommand, on_floor: bool) -> bool:
	return cmd.sprint and stance == Stance.STANDING and on_floor \
		and cmd.move.y > 0.3 and stamina.can_sprint() and absf(lean_amount) < 0.2
	# Correr cancela el apuntado (lo resuelve WeaponController).


func _target_speed() -> float:
	match stance:
		Stance.CROUCHING:
			return config.crouch_speed * (weapons.move_speed_mult() if weapons != null else 1.0)
		_:
			var base := config.sprint_speed if is_sprinting else config.walk_speed
			return base * (weapons.move_speed_mult() if weapons != null and not is_sprinting else 1.0)


func _try_jump() -> bool:
	if stance != Stance.STANDING:
		# Saltar desde agachado/deslizando primero intenta pararse.
		if not _has_headroom():
			return false
		_end_slide_or_crouch(Stance.STANDING)
	return stamina.try_consume(config.jump_cost)


func _gravity() -> float:
	return ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)


# --- Posturas ---------------------------------------------------------------

func _update_stance(cmd: PlayerCommand, on_floor: bool) -> void:
	match stance:
		Stance.STANDING:
			if cmd.crouch:
				var hspeed := Vector2(velocity.x, velocity.z).length()
				if on_floor and _last_was_sprinting() and hspeed >= config.slide_min_entry_speed \
						and _slide_cooldown <= 0.0 and stamina.try_consume(config.slide_cost):
					_start_slide()
				else:
					_set_stance(Stance.CROUCHING)
		Stance.CROUCHING:
			if not cmd.crouch and _has_headroom():
				_set_stance(Stance.STANDING)
		Stance.SLIDING:
			_slide_time += get_physics_process_delta_time()
			var hspeed := Vector2(velocity.x, velocity.z).length()
			var finished := _slide_time >= config.slide_duration or hspeed < config.crouch_speed + 0.3
			if not cmd.crouch or finished or not on_floor:
				var next := Stance.CROUCHING
				if not cmd.crouch and _has_headroom():
					next = Stance.STANDING
				_end_slide_or_crouch(next)


## is_sprinting ya se calculó este tick con la postura anterior (de pie).
func _last_was_sprinting() -> bool:
	return is_sprinting


func _start_slide() -> void:
	var h := Vector3(velocity.x, 0.0, velocity.z)
	_slide_dir = h.normalized() if h.length() > 0.1 else -head.global_basis.z
	_slide_time = 0.0
	_set_stance(Stance.SLIDING)


func _slide_velocity(wish: Vector3, delta: float) -> Vector3:
	# Leve control de dirección durante el deslizamiento.
	if wish.length() > 0.1:
		_slide_dir = _slide_dir.slerp(wish.normalized(), clampf(config.slide_steer * delta, 0.0, 1.0)).normalized()
	var t := clampf(_slide_time / config.slide_duration, 0.0, 1.0)
	var speed := lerpf(config.slide_start_speed, config.crouch_speed, t * t)
	return _slide_dir * speed


func _end_slide_or_crouch(next: Stance) -> void:
	if stance == Stance.SLIDING:
		_slide_cooldown = config.slide_cooldown
	_set_stance(next)


func _set_stance(next: Stance) -> void:
	if next == stance:
		return
	stance = next
	_set_capsule_height(config.stand_height if next == Stance.STANDING else config.crouch_height)
	EventBus.player_stance_changed.emit(next)


func _set_capsule_height(h: float) -> void:
	capsule_height = h
	var cap := collision.shape as CapsuleShape3D
	cap.height = h
	collision.position = Vector3(0.0, h * 0.5, 0.0)
	# Sombra del cuerpo (placeholder hasta tener el modelo con animación).
	# TODO-ASSET: player_body
	if body_shadow != null:
		(body_shadow.mesh as CapsuleMesh).height = h
		body_shadow.position = Vector3(0.0, h * 0.5, 0.0)


func _target_eye_height() -> float:
	return capsule_height - config.eye_from_top


## ¿Hay lugar para pararse? Prueba mover la cápsula hacia arriba.
func _has_headroom() -> bool:
	var needed := config.stand_height - capsule_height
	if needed <= 0.001:
		return true
	return not test_move(global_transform, Vector3(0.0, needed, 0.0))


# --- Diagnóstico --------------------------------------------------------------

func get_debug_info() -> Dictionary:
	var hspeed := Vector2(velocity.x, velocity.z).length()
	return {
		"Posición": "(%.1f, %.1f, %.1f)" % [global_position.x, global_position.y, global_position.z],
		"Velocidad": "%.2f m/s (vertical %.2f)" % [hspeed, velocity.y],
		"Postura": Stance.keys()[stance] + (" · corriendo" if is_sprinting else ""),
		"Estamina": "%.0f / %.0f%s" % [stamina.current, stamina.maximum, " (agotado)" if stamina.exhausted else ""],
		"En el piso": is_on_floor(),
		"Inclinación": "%.2f" % lean_amount,
		"Arma": "%s · %s" % [tr(weapons.current_data().name_key), WeaponController.State.keys()[weapons.state]] if weapons != null else "-",
		"Apuntado": "%.2f" % (weapons.ads_amount if weapons != null else 0.0),
	}
