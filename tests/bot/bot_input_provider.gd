class_name BotInputProvider
extends InputProvider
## "Jugador robot" para los tests: se le dice qué teclas mantener por código.

var move: Vector2 = Vector2.ZERO
var sprint: bool = false
var crouch: bool = false
var lean: float = 0.0
## Rotación de mirada a aplicar en el próximo frame (radianes).
var look: Vector2 = Vector2.ZERO

var _jump_pending: bool = false


## Simula una pulsación de saltar (se consume en el próximo tick).
func press_jump() -> void:
	_jump_pending = true


func release_all() -> void:
	move = Vector2.ZERO
	sprint = false
	crouch = false
	lean = 0.0
	look = Vector2.ZERO


func poll_command(_delta: float) -> PlayerCommand:
	var cmd := PlayerCommand.new()
	cmd.move = move
	cmd.sprint = sprint
	cmd.crouch = crouch
	cmd.lean = lean
	cmd.jump = _jump_pending
	_jump_pending = false
	return cmd


func consume_look(_delta: float) -> Vector2:
	var l := look
	look = Vector2.ZERO
	return l
