class_name HumanInputProvider
extends InputProvider
## Lee teclado, mouse y joystick y los convierte en PlayerCommand.

## Radianes por píxel de mouse con sensibilidad 1.0.
const MOUSE_BASE := 0.0022
## Radianes por segundo con el stick a fondo y sensibilidad 1.0.
const STICK_BASE := 3.2

var _mouse_accum: Vector2 = Vector2.ZERO
var _jump_queued: bool = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_mouse_accum += (event as InputEventMouseMotion).screen_relative
	elif event.is_action_pressed("jump"):
		# Se encola acá para no perder pulsaciones entre ticks de física.
		_jump_queued = true


func poll_command(_delta: float) -> PlayerCommand:
	var cmd := PlayerCommand.new()
	cmd.move = Input.get_vector("move_left", "move_right", "move_back", "move_forward")
	cmd.jump = _jump_queued
	_jump_queued = false
	cmd.sprint = Input.is_action_pressed("sprint")
	cmd.crouch = Input.is_action_pressed("crouch")
	cmd.lean = Input.get_action_strength("lean_right") - Input.get_action_strength("lean_left")
	return cmd


func consume_look(delta: float) -> Vector2:
	var sens: float = Settings.get_value("controls", "mouse_sensitivity")
	var look := _mouse_accum * MOUSE_BASE * sens
	_mouse_accum = Vector2.ZERO
	var stick := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	look += stick * STICK_BASE * sens * delta
	if Settings.get_value("controls", "invert_y"):
		look.y = -look.y
	return look
