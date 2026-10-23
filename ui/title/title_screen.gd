extends Control
## Pantalla de título.

const OptionsMenu := preload("res://ui/options/options_menu.gd")
const TitleBackground := preload("res://ui/title/title_background.gd")
const UiTheme := preload("res://ui/theme/ui_theme.gd")

var _menu: VBoxContainer
var _options: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	EventBus.language_changed.connect(func(_c: String) -> void: _build())
	_build()


func _build() -> void:
	for c in get_children():
		c.queue_free()
	_options = null

	var bg := Control.new()
	bg.set_script(TitleBackground)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 140)
	margin.add_theme_constant_override("margin_top", 150)
	margin.add_theme_constant_override("margin_bottom", 80)
	add_child(margin)

	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 14)
	margin.add_child(_menu)

	var title := Label.new()
	title.text = "MEDOREADOR"
	title.add_theme_font_size_override("font_size", 96)
	title.add_theme_color_override("font_color", UiTheme.TEXT)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	title.add_theme_constant_override("shadow_offset_y", 4)
	_menu.add_child(title)

	var subtitle := Label.new()
	subtitle.text = tr("title.subtitle")
	subtitle.add_theme_font_size_override("font_size", 26)
	subtitle.add_theme_color_override("font_color", UiTheme.ACCENT)
	_menu.add_child(subtitle)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 50)
	_menu.add_child(spacer)

	_add_button(tr("title.story"), Callable(), true)
	_add_button(tr("title.sandbox"), Callable(), true)
	var test_btn := _add_button(tr("title.test_track"), func() -> void: GameState.start_level(GameState.LEVEL_TEST_GREYBOX))
	_add_button(tr("menu.options"), _open_options)
	_add_button(tr("menu.quit"), GameState.quit_game)
	test_btn.grab_focus.call_deferred()

	var version := Label.new()
	version.text = "v%s" % ProjectSettings.get_setting("application/config/version")
	version.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
	version.add_theme_font_size_override("font_size", 18)
	version.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	version.offset_left = -200
	version.offset_top = -50
	version.offset_right = -30
	version.offset_bottom = -20
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(version)


func _add_button(text: String, action: Callable, coming_soon := false) -> Button:
	var b := Button.new()
	b.text = text + ("  ·  " + tr("menu.coming_soon") if coming_soon else "")
	b.custom_minimum_size = Vector2(420, 54)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.disabled = coming_soon
	if action.is_valid():
		b.pressed.connect(action)
	_menu.add_child(b)
	return b


func _open_options() -> void:
	_menu.visible = false
	_options = Control.new()
	_options.set_script(OptionsMenu)
	add_child(_options)
	_options.connect("closed", _close_options)


func _close_options() -> void:
	if _options != null:
		_options.queue_free()
		_options = null
	_menu.visible = true
