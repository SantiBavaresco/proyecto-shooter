class_name InputActions
extends RefCounted
## Definición central de todas las acciones de input del juego.
##
## Las acciones se registran en runtime (no en project.godot) para que:
##  - haya una sola fuente de verdad legible,
##  - el remapeo desde Opciones sea simple (se guarda en user://settings.cfg),
##  - los tests puedan verificar que todo existe.
##
## Formato de cada evento por defecto:
##   {"key": KEY_W}                         tecla física (independiente del layout)
##   {"mouse": MOUSE_BUTTON_LEFT}           botón de mouse
##   {"joy_button": JOY_BUTTON_A}           botón de joystick
##   {"joy_axis": JOY_AXIS_LEFT_Y, "dir": -1.0}  eje de joystick (dirección)

const DEADZONE := 0.2

## Acción → lista de eventos por defecto.
const DEFAULTS: Dictionary = {
	# Movimiento
	"move_forward": [{"key": KEY_W}, {"joy_axis": JOY_AXIS_LEFT_Y, "dir": -1.0}],
	"move_back": [{"key": KEY_S}, {"joy_axis": JOY_AXIS_LEFT_Y, "dir": 1.0}],
	"move_left": [{"key": KEY_A}, {"joy_axis": JOY_AXIS_LEFT_X, "dir": -1.0}],
	"move_right": [{"key": KEY_D}, {"joy_axis": JOY_AXIS_LEFT_X, "dir": 1.0}],
	"jump": [{"key": KEY_SPACE}, {"joy_button": JOY_BUTTON_A}],
	"sprint": [{"key": KEY_SHIFT}, {"joy_button": JOY_BUTTON_LEFT_STICK}],
	"crouch": [{"key": KEY_C}, {"joy_button": JOY_BUTTON_B}],
	"lean_left": [{"key": KEY_Q}, {"joy_button": JOY_BUTTON_DPAD_LEFT}],
	"lean_right": [{"key": KEY_E}, {"joy_button": JOY_BUTTON_DPAD_RIGHT}],
	# Mirada con joystick (el mouse se lee como movimiento relativo)
	"look_left": [{"joy_axis": JOY_AXIS_RIGHT_X, "dir": -1.0}],
	"look_right": [{"joy_axis": JOY_AXIS_RIGHT_X, "dir": 1.0}],
	"look_up": [{"joy_axis": JOY_AXIS_RIGHT_Y, "dir": -1.0}],
	"look_down": [{"joy_axis": JOY_AXIS_RIGHT_Y, "dir": 1.0}],
	# Combate (se usan desde F1; ya quedan registradas)
	"fire": [{"mouse": MOUSE_BUTTON_LEFT}, {"joy_axis": JOY_AXIS_TRIGGER_RIGHT, "dir": 1.0}],
	"aim": [{"mouse": MOUSE_BUTTON_RIGHT}, {"joy_axis": JOY_AXIS_TRIGGER_LEFT, "dir": 1.0}],
	"reload": [{"key": KEY_R}, {"joy_button": JOY_BUTTON_X}],
	"interact": [{"key": KEY_F}, {"joy_button": JOY_BUTTON_X}],
	"weapon_1": [{"key": KEY_1}],
	"weapon_2": [{"key": KEY_2}],
	"weapon_3": [{"key": KEY_3}],
	"weapon_4": [{"key": KEY_4}],
	"weapon_cycle": [{"joy_button": JOY_BUTTON_Y}],
	"grenade": [{"key": KEY_G}, {"joy_button": JOY_BUTTON_RIGHT_SHOULDER}],
	"melee": [{"key": KEY_V}, {"joy_button": JOY_BUTTON_RIGHT_STICK}],
	"quick_1": [{"key": KEY_5}],
	"quick_2": [{"key": KEY_6}],
	"quick_3": [{"key": KEY_7}],
	"quick_4": [{"key": KEY_8}],
	# Interfaz
	"inventory": [{"key": KEY_TAB}, {"joy_button": JOY_BUTTON_BACK}],
	"pda": [{"key": KEY_M}],
	"flashlight": [{"key": KEY_L}, {"joy_button": JOY_BUTTON_DPAD_UP}],
	"detector": [{"key": KEY_O}, {"joy_button": JOY_BUTTON_DPAD_DOWN}],
	"pause": [{"key": KEY_ESCAPE}, {"joy_button": JOY_BUTTON_START}],
	# Desarrollo
	"debug_overlay": [{"key": KEY_F1}],
	"bug_report": [{"key": KEY_F12}],
}

## Acciones que el jugador puede remapear desde Opciones (teclado/mouse),
## en el orden en que se muestran.
const REBINDABLE: Array[String] = [
	"move_forward", "move_back", "move_left", "move_right",
	"jump", "sprint", "crouch", "lean_left", "lean_right",
	"fire", "aim", "reload", "interact",
	"weapon_1", "weapon_2", "weapon_3", "weapon_4",
	"grenade", "melee", "quick_1", "quick_2", "quick_3", "quick_4",
	"inventory", "pda", "flashlight", "detector",
]


## Registra todas las acciones con sus eventos por defecto.
## Si una acción ya existe, se reemplazan sus eventos.
static func register_defaults() -> void:
	for action: String in DEFAULTS:
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
		else:
			InputMap.add_action(action, DEADZONE)
		for desc: Dictionary in DEFAULTS[action]:
			InputMap.action_add_event(action, event_from_dict(desc))


## Convierte un descriptor (ver arriba) en un InputEvent.
static func event_from_dict(desc: Dictionary) -> InputEvent:
	if desc.has("key"):
		var k := InputEventKey.new()
		k.physical_keycode = int(desc["key"]) as Key
		return k
	if desc.has("mouse"):
		var m := InputEventMouseButton.new()
		m.button_index = int(desc["mouse"]) as MouseButton
		return m
	if desc.has("joy_button"):
		var b := InputEventJoypadButton.new()
		b.button_index = int(desc["joy_button"]) as JoyButton
		return b
	if desc.has("joy_axis"):
		var a := InputEventJoypadMotion.new()
		a.axis = int(desc["joy_axis"]) as JoyAxis
		a.axis_value = float(desc.get("dir", 1.0))
		return a
	push_error("InputActions: descriptor inválido %s" % desc)
	return null


## Serializa un evento de teclado o mouse para guardarlo en settings.
## Devuelve {} si el evento no es remapeable.
static func event_to_dict(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		var k := event as InputEventKey
		var code: int = k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
		return {"key": code}
	if event is InputEventMouseButton:
		return {"mouse": (event as InputEventMouseButton).button_index}
	return {}


## Es un evento de teclado/mouse (los que maneja el remapeo)?
static func is_kbm_event(event: InputEvent) -> bool:
	return event is InputEventKey or event is InputEventMouseButton


## Primer evento de teclado/mouse de una acción (o null).
static func get_kbm_event(action: String) -> InputEvent:
	for e: InputEvent in InputMap.action_get_events(action):
		if is_kbm_event(e):
			return e
	return null


## Reemplaza el evento de teclado/mouse de una acción, conservando los de joystick.
static func set_kbm_event(action: String, event: InputEvent) -> void:
	for e: InputEvent in InputMap.action_get_events(action):
		if is_kbm_event(e):
			InputMap.action_erase_event(action, e)
	if event != null:
		InputMap.action_add_event(action, event)


## Texto legible para mostrar el evento en la UI.
static func event_label(event: InputEvent) -> String:
	if event == null:
		return "—"
	if event is InputEventKey:
		var k := event as InputEventKey
		var code: Key = k.keycode
		if k.physical_keycode != KEY_NONE:
			# Traduce la tecla física al layout del teclado del jugador
			# (no disponible sin pantalla, ej. en los tests).
			code = k.physical_keycode
			if DisplayServer.get_name() != "headless":
				code = DisplayServer.keyboard_get_keycode_from_physical(k.physical_keycode)
		return OS.get_keycode_string(code)
	if event is InputEventMouseButton:
		match (event as InputEventMouseButton).button_index:
			MOUSE_BUTTON_LEFT:
				return _t("input.mouse_left")
			MOUSE_BUTTON_RIGHT:
				return _t("input.mouse_right")
			MOUSE_BUTTON_MIDDLE:
				return _t("input.mouse_middle")
			MOUSE_BUTTON_XBUTTON1:
				return _t("input.mouse_x1")
			MOUSE_BUTTON_XBUTTON2:
				return _t("input.mouse_x2")
			var other:
				return _t("input.mouse_n") % other
	return event.as_text()


## Busca otra acción remapeable que ya use este mismo evento.
static func find_conflict(action: String, event: InputEvent) -> String:
	var wanted := event_to_dict(event)
	for other: String in REBINDABLE:
		if other == action:
			continue
		var e := get_kbm_event(other)
		if e != null and event_to_dict(e) == wanted:
			return other
	return ""


## Traducción en contexto estático.
static func _t(key: String) -> String:
	return TranslationServer.translate(key)
