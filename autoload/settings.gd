extends Node
## Opciones del jugador, persistidas en user://settings.cfg.
## También registra las acciones de input y aplica el remapeo guardado.

const DEFAULT_PATH := "user://settings.cfg"

## Valores por defecto. Sección → clave → valor.
const DEFAULTS: Dictionary = {
	"video": {
		"fov": 90.0,
		"fullscreen": false,
		"vsync": true,
		"show_fps": false,
		"show_hud": true,
	},
	"controls": {
		"mouse_sensitivity": 1.0,
		"invert_y": false,
		"head_bob": true,
		"aim_toggle": true,
	},
	"audio": {
		"master": 1.0,
		"music": 0.8,
		"sfx": 1.0,
		"ui": 0.8,
	},
	"game": {
		"language": "es",
	},
}

## Rango permitido de opciones numéricas (para validar y para los sliders).
const RANGES: Dictionary = {
	"video/fov": Vector2(70.0, 110.0),
	"controls/mouse_sensitivity": Vector2(0.1, 3.0),
	"audio/master": Vector2(0.0, 1.0),
	"audio/music": Vector2(0.0, 1.0),
	"audio/sfx": Vector2(0.0, 1.0),
	"audio/ui": Vector2(0.0, 1.0),
}

var path: String = DEFAULT_PATH
var _cfg: ConfigFile = ConfigFile.new()


func _ready() -> void:
	InputActions.register_defaults()
	load_settings()
	apply_all()


func get_value(section: String, key: String) -> Variant:
	var fallback: Variant = DEFAULTS.get(section, {}).get(key)
	return _cfg.get_value(section, key, fallback)


func set_value(section: String, key: String, value: Variant, save := true) -> void:
	var range_key := "%s/%s" % [section, key]
	if RANGES.has(range_key) and (value is float or value is int):
		var r: Vector2 = RANGES[range_key]
		value = clampf(float(value), r.x, r.y)
	_cfg.set_value(section, key, value)
	_apply_one(section, key)
	if save:
		save_settings()
	EventBus.settings_changed.emit()


func load_settings() -> void:
	_cfg = ConfigFile.new()
	if FileAccess.file_exists(path):
		var err := _cfg.load(path)
		if err != OK:
			push_warning("Settings: no se pudo leer %s (error %d), uso valores por defecto" % [path, err])
			_cfg = ConfigFile.new()
	_load_bindings()


func save_settings() -> void:
	var err := _cfg.save(path)
	if err != OK:
		push_error("Settings: no se pudo guardar %s (error %d)" % [path, err])


func reset_to_defaults() -> void:
	_cfg = ConfigFile.new()
	InputActions.register_defaults()
	save_settings()
	apply_all()
	EventBus.settings_changed.emit()


# --- Remapeo de teclas -------------------------------------------------------

## Asigna un evento de teclado/mouse a una acción. Si otra acción lo usaba,
## esa queda sin tecla (se devuelve su nombre para avisar en la UI).
func rebind(action: String, event: InputEvent) -> String:
	var conflict := InputActions.find_conflict(action, event)
	if conflict != "":
		InputActions.set_kbm_event(conflict, null)
		_cfg.set_value("bindings", conflict, {})
	InputActions.set_kbm_event(action, event)
	_cfg.set_value("bindings", action, InputActions.event_to_dict(event))
	save_settings()
	EventBus.settings_changed.emit()
	return conflict


func reset_bindings() -> void:
	if _cfg.has_section("bindings"):
		_cfg.erase_section("bindings")
	InputActions.register_defaults()
	save_settings()
	EventBus.settings_changed.emit()


func _load_bindings() -> void:
	if not _cfg.has_section("bindings"):
		return
	for action: String in _cfg.get_section_keys("bindings"):
		if not InputMap.has_action(action):
			continue
		var desc: Dictionary = _cfg.get_value("bindings", action, {})
		var ev: InputEvent = InputActions.event_from_dict(desc) if not desc.is_empty() else null
		InputActions.set_kbm_event(action, ev)


# --- Aplicación ----------------------------------------------------------------

func apply_all() -> void:
	for section: String in DEFAULTS:
		for key: String in DEFAULTS[section]:
			_apply_one(section, key)


func _apply_one(section: String, key: String) -> void:
	match "%s/%s" % [section, key]:
		"video/fullscreen":
			if DisplayServer.get_name() == "headless":
				return
			var fs: bool = get_value("video", "fullscreen")
			DisplayServer.window_set_mode(
				DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN if fs else DisplayServer.WINDOW_MODE_WINDOWED)
		"video/vsync":
			if DisplayServer.get_name() == "headless":
				return
			var vs: bool = get_value("video", "vsync")
			DisplayServer.window_set_vsync_mode(
				DisplayServer.VSYNC_ENABLED if vs else DisplayServer.VSYNC_DISABLED)
		"game/language":
			# Loc puede no estar listo todavía al arrancar; aplica él mismo en su _ready.
			if is_instance_valid(Loc) and Loc.is_node_ready():
				Loc.set_language(get_value("game", "language"))
		"audio/master", "audio/music", "audio/sfx", "audio/ui":
			if is_instance_valid(AudioManager) and AudioManager.is_node_ready():
				AudioManager.apply_volumes()
		_:
			pass  # El resto lo leen los sistemas cuando lo necesitan (FOV, sensibilidad…).
