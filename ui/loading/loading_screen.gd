extends Control
## Pantalla de carga: carga el nivel en segundo plano con progreso real.
# TODO-ASSET: loading_background (arte de fondo)

const TitleBackground := preload("res://ui/title/title_background.gd")
const UiTheme := preload("res://ui/theme/ui_theme.gd")
const MIN_TIME := 0.4
const TIP_KEYS: Array[String] = ["tip.1", "tip.2", "tip.3", "tip.4", "tip.5"]

var _bar: ProgressBar
var _elapsed: float = 0.0
var _path: String = ""
var _done: bool = false
var _progress: Array = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	_path = GameState.pending_level
	var err := ResourceLoader.load_threaded_request(_path)
	if err != OK:
		push_error("Loading: no se pudo pedir %s (error %d)" % [_path, err])
		GameState.goto_title()


func _process(delta: float) -> void:
	if _done:
		return
	_elapsed += delta
	var status := ResourceLoader.load_threaded_get_status(_path, _progress)
	if not _progress.is_empty():
		_bar.value = float(_progress[0]) * 100.0
	match status:
		ResourceLoader.THREAD_LOAD_LOADED:
			_bar.value = 100.0
			if _elapsed >= MIN_TIME:
				_done = true
				GameState.on_level_loaded(ResourceLoader.load_threaded_get(_path) as PackedScene)
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_done = true
			push_error("Loading: falló la carga de %s" % _path)
			GameState.goto_title()


func _build() -> void:
	var bg := Control.new()
	bg.set_script(TitleBackground)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.modulate = Color(0.55, 0.55, 0.55)
	add_child(bg)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	box.offset_left = -500
	box.offset_right = 500
	box.offset_top = -220
	box.offset_bottom = -90
	box.add_theme_constant_override("separation", 12)
	add_child(box)

	var title := Label.new()
	title.text = tr("loading.title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	box.add_child(title)

	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(0, 10)
	_bar.show_percentage = false
	box.add_child(_bar)

	var tip := Label.new()
	tip.text = tr(TIP_KEYS[randi() % TIP_KEYS.size()])
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
	tip.add_theme_font_size_override("font_size", 20)
	box.add_child(tip)
