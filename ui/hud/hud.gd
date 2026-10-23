extends CanvasLayer
## HUD minimalista. En F0: punto central y barra de estamina (se oculta llena).
## La brújula y el resto del HUD llegan en F3.

const UiTheme := preload("res://ui/theme/ui_theme.gd")
const FADE_SPEED := 2.5

var _stamina_bar: ProgressBar
var _stamina_root: Control
var _target_alpha: float = 0.0


func _ready() -> void:
	layer = 10
	_build()
	EventBus.stamina_changed.connect(_on_stamina_changed)


func _process(delta: float) -> void:
	_stamina_root.modulate.a = move_toward(_stamina_root.modulate.a, _target_alpha, FADE_SPEED * delta)


func _on_stamina_changed(current: float, maximum: float) -> void:
	var r := current / maximum if maximum > 0.0 else 0.0
	_stamina_bar.value = r * 100.0
	_target_alpha = 0.0 if r >= 0.999 else 1.0
	var fill := _stamina_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill != null:
		fill.bg_color = UiTheme.ALERT if r < 0.25 else UiTheme.TEXT.darkened(0.15)


func _build() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var dot := ColorRect.new()
	dot.color = Color(1, 1, 1, 0.75)
	dot.size = Vector2(4, 4)
	dot.set_anchors_preset(Control.PRESET_CENTER)
	dot.offset_left = -2
	dot.offset_top = -2
	dot.offset_right = 2
	dot.offset_bottom = 2
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dot)

	_stamina_root = Control.new()
	_stamina_root.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_stamina_root.offset_left = -160
	_stamina_root.offset_right = 160
	_stamina_root.offset_top = -70
	_stamina_root.offset_bottom = -64
	_stamina_root.modulate.a = 0.0
	_stamina_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_stamina_root)

	_stamina_bar = ProgressBar.new()
	_stamina_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stamina_bar.show_percentage = false
	_stamina_bar.value = 100.0
	_stamina_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Stylebox propio para poder cambiarle el color sin afectar otras barras.
	var fill := StyleBoxFlat.new()
	fill.bg_color = UiTheme.TEXT.darkened(0.15)
	fill.set_corner_radius_all(2)
	_stamina_bar.add_theme_stylebox_override("fill", fill)
	_stamina_root.add_child(_stamina_bar)
