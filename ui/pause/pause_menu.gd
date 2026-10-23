extends CanvasLayer
## Menú de pausa. Lo crea GameState al pausar; funciona con el árbol pausado.

const OptionsMenu := preload("res://ui/options/options_menu.gd")

var _root: Control
var _menu: VBoxContainer
var _options: Control


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()


## true si está en el menú principal de pausa (no en Opciones).
func is_at_root() -> bool:
	return _options == null


func _unhandled_input(event: InputEvent) -> void:
	if _options != null and event.is_action_pressed("pause"):
		_close_options()
		get_viewport().set_input_as_handled()


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	var panel := PanelContainer.new()
	center.add_child(panel)
	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 12)
	_menu.custom_minimum_size = Vector2(420, 0)
	panel.add_child(_menu)

	var title := Label.new()
	title.text = tr("pause.title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	_menu.add_child(title)

	var resume := _add(tr("pause.resume"), func() -> void: GameState.set_paused(false))
	_add(tr("menu.options"), _open_options)
	_add(tr("pause.to_title"), GameState.goto_title)
	_add(tr("menu.quit"), GameState.quit_game)
	resume.grab_focus.call_deferred()


func _add(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 52)
	b.pressed.connect(action)
	_menu.add_child(b)
	return b


func _open_options() -> void:
	_root.visible = false
	_options = Control.new()
	_options.set_script(OptionsMenu)
	add_child(_options)
	_options.connect("closed", _close_options)


func _close_options() -> void:
	if _options != null:
		_options.queue_free()
		_options = null
	_root.visible = true
