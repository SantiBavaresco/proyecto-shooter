extends TestCase
## Usa un archivo temporal para no tocar las opciones reales del jugador.

const TMP := "user://test_settings.cfg"
var _orig_path: String


func before_each() -> void:
	_orig_path = Settings.path
	Settings.path = TMP
	if FileAccess.file_exists(TMP):
		DirAccess.remove_absolute(TMP)
	Settings.load_settings()


func after_each() -> void:
	if FileAccess.file_exists(TMP):
		DirAccess.remove_absolute(TMP)
	Settings.path = _orig_path
	InputActions.register_defaults()
	Settings.load_settings()
	Settings.apply_all()


func test_defaults() -> void:
	assert_eq(Settings.get_value("video", "fov"), 90.0)
	assert_eq(Settings.get_value("game", "language"), "es")


func test_set_and_reload() -> void:
	Settings.set_value("video", "fov", 100.0)
	Settings.load_settings()
	assert_eq(Settings.get_value("video", "fov"), 100.0)


func test_values_are_clamped() -> void:
	Settings.set_value("video", "fov", 300.0)
	assert_eq(Settings.get_value("video", "fov"), 110.0)
	Settings.set_value("controls", "mouse_sensitivity", -5.0)
	assert_near(Settings.get_value("controls", "mouse_sensitivity"), 0.1, 0.0001)


func test_rebind_persists_and_resolves_conflict() -> void:
	var conflict := Settings.rebind("jump", InputActions.event_from_dict({"key": KEY_W}))
	assert_eq(conflict, "move_forward")
	assert_true(InputActions.get_kbm_event("move_forward") == null, "la acción en conflicto queda sin tecla")
	# Recargar desde disco mantiene el remapeo
	InputActions.register_defaults()
	Settings.load_settings()
	assert_eq(InputActions.event_to_dict(InputActions.get_kbm_event("jump")), {"key": KEY_W})
	assert_true(InputActions.get_kbm_event("move_forward") == null)
