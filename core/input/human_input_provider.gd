class_name HumanInputProvider
extends InputProvider
## Lee teclado, mouse y joystick y los convierte en PlayerCommand.

## Radianes por píxel de mouse con sensibilidad 1.0.
const MOUSE_BASE := 0.0022
## Radianes por segundo con el stick a fondo y sensibilidad 1.0.
const STICK_BASE := 3.2

const SLOT_ACTIONS: Array[String] = ["weapon_1", "weapon_2", "weapon_3", "weapon_4"]
const QUICK_ACTIONS: Array[String] = ["quick_1", "quick_2", "quick_3", "quick_4"]

var _mouse_accum: Vector2 = Vector2.ZERO
# Pulsaciones encoladas en _unhandled_input para no perderlas entre ticks de física.
var _jump_queued: bool = false
var _fire_queued: bool = false
var _reload_queued: bool = false
var _mode_queued: bool = false
var _interact_queued: bool = false
var _interact_alt_queued: bool = false
## [F] apretada: cuánto hace y si ya disparó el "mantener".
var _interact_down: bool = false
var _interact_held: float = 0.0
var _interact_hold_done: bool = false
const INTERACT_HOLD := 0.4
var _slot_queued: int = -1
var _zoom_queued: int = 0
var _quick_queued: int = -1
var _grenade_queued: bool = false
var _melee_queued: bool = false
var _aim_state: bool = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not GameState.ui_open:
			_mouse_accum += (event as InputEventMouseMotion).screen_relative
		return
	if event.is_echo():
		return
	if event.is_action_pressed("jump"):
		_jump_queued = true
	if event.is_action_pressed("fire"):
		_fire_queued = true
	if event.is_action_pressed("reload"):
		_reload_queued = true
	if event.is_action_pressed("fire_mode"):
		_mode_queued = true
	if event.is_action_pressed("interact"):
		_interact_down = true
		_interact_held = 0.0
		_interact_hold_done = false
	elif event.is_action_released("interact") and _interact_down:
		_interact_down = false
		if not _interact_hold_done:
			_interact_queued = true
	if event.is_action_pressed("grenade"):
		_grenade_queued = true
	if event.is_action_pressed("melee"):
		_melee_queued = true
	for i in SLOT_ACTIONS.size():
		if event.is_action_pressed(SLOT_ACTIONS[i]):
			_slot_queued = i + 1
	for i in QUICK_ACTIONS.size():
		if event.is_action_pressed(QUICK_ACTIONS[i]):
			_quick_queued = i
	if event.is_action_pressed("zoom_in"):
		_zoom_queued += 1
	if event.is_action_pressed("zoom_out"):
		_zoom_queued -= 1
	if event.is_action("aim"):
		var toggle: bool = Settings.get_value("controls", "aim_toggle")
		if toggle:
			if event.is_pressed():
				_aim_state = not _aim_state
		else:
			_aim_state = event.is_pressed()


func poll_command(_delta: float) -> PlayerCommand:
	var cmd := PlayerCommand.new()
	if _interact_down and not _interact_hold_done:
		_interact_held += _delta
		if _interact_held >= INTERACT_HOLD:
			_interact_hold_done = true
			_interact_alt_queued = true
	if GameState.ui_open:
		_interact_down = false
		# Con el inventario abierto el jugador no se mueve ni dispara
		_clear_queued()
		return cmd
	cmd.move = Input.get_vector("move_left", "move_right", "move_back", "move_forward")
	cmd.jump = _jump_queued
	cmd.sprint = Input.is_action_pressed("sprint")
	cmd.crouch = Input.is_action_pressed("crouch")
	cmd.lean = Input.get_action_strength("lean_right") - Input.get_action_strength("lean_left")
	cmd.fire = Input.is_action_pressed("fire")
	cmd.fire_pressed = _fire_queued
	cmd.aim = _aim_state
	cmd.reload = _reload_queued
	cmd.fire_mode = _mode_queued
	cmd.interact = _interact_queued
	cmd.interact_alt = _interact_alt_queued
	cmd.weapon_slot = _slot_queued
	cmd.zoom = _zoom_queued
	cmd.quick_slot = _quick_queued
	cmd.grenade = _grenade_queued
	cmd.melee = _melee_queued
	_clear_queued()
	return cmd


func _clear_queued() -> void:
	_quick_queued = -1
	_grenade_queued = false
	_melee_queued = false
	_zoom_queued = 0
	_jump_queued = false
	_fire_queued = false
	_reload_queued = false
	_mode_queued = false
	_interact_queued = false
	_interact_alt_queued = false
	_slot_queued = -1


func consume_look(delta: float) -> Vector2:
	var sens: float = Settings.get_value("controls", "mouse_sensitivity")
	var look := _mouse_accum * MOUSE_BASE * sens
	_mouse_accum = Vector2.ZERO
	var stick := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	look += stick * STICK_BASE * sens * delta
	if Settings.get_value("controls", "invert_y"):
		look.y = -look.y
	return look


func cancel_aim() -> void:
	_aim_state = false
