class_name BotInputProvider
extends InputProvider
## "Jugador robot" para los tests: se le dice qué teclas mantener por código.

var move: Vector2 = Vector2.ZERO
var sprint: bool = false
var crouch: bool = false
var lean: float = 0.0
var fire: bool = false
var aim: bool = false
## Rotación de mirada a aplicar en el próximo frame (radianes).
var look: Vector2 = Vector2.ZERO

var _jump_pending: bool = false
var _fire_pending: bool = false
var _reload_pending: bool = false
var _mode_pending: bool = false
var _interact_pending: bool = false
var _slot_pending: int = -1
var _zoom_pending: int = 0
var _prev_fire: bool = false


## Simula una pulsación de saltar (se consume en el próximo tick).
func press_jump() -> void:
	_jump_pending = true


## Un disparo: aprieta el gatillo un tick.
func press_fire() -> void:
	_fire_pending = true


func press_reload() -> void:
	_reload_pending = true


func press_fire_mode() -> void:
	_mode_pending = true


func press_interact() -> void:
	_interact_pending = true


func select_slot(slot: int) -> void:
	_slot_pending = slot


## Muescas de la rueda (+ acercar, − alejar).
func press_zoom(notches: int) -> void:
	_zoom_pending += notches


func release_all() -> void:
	move = Vector2.ZERO
	sprint = false
	crouch = false
	lean = 0.0
	fire = false
	aim = false
	look = Vector2.ZERO


func poll_command(_delta: float) -> PlayerCommand:
	var cmd := PlayerCommand.new()
	cmd.move = move
	cmd.sprint = sprint
	cmd.crouch = crouch
	cmd.lean = lean
	cmd.jump = _jump_pending
	cmd.fire = fire or _fire_pending
	# Igual que el teclado: "recién apretado" solo en el primer tick.
	cmd.fire_pressed = _fire_pending or (fire and not _prev_fire)
	_prev_fire = fire
	cmd.aim = aim
	cmd.reload = _reload_pending
	cmd.fire_mode = _mode_pending
	cmd.interact = _interact_pending
	cmd.weapon_slot = _slot_pending
	cmd.zoom = _zoom_pending
	_zoom_pending = 0
	_jump_pending = false
	_fire_pending = false
	_reload_pending = false
	_mode_pending = false
	_interact_pending = false
	_slot_pending = -1
	return cmd


func consume_look(_delta: float) -> Vector2:
	var l := look
	look = Vector2.ZERO
	return l


func cancel_aim() -> void:
	aim = false
