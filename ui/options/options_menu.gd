extends Control
## Menú de opciones (se usa desde el título y desde la pausa).
## Pestañas: Video, Controles, Audio, Juego. Cada cambio se guarda al instante.

signal closed

const UiTheme := preload("res://ui/theme/ui_theme.gd")

var _tabs: TabContainer
var _current_tab: int = 0
## Acción que está esperando una tecla nueva ("" = ninguna).
var _waiting_action: String = ""
var _waiting_button: Button
var _status: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.language_changed.connect(_on_language_changed)
	_build()


func _input(event: InputEvent) -> void:
	if _waiting_action == "":
		return
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		var k := event as InputEventKey
		if k.physical_keycode == KEY_ESCAPE or k.keycode == KEY_ESCAPE:
			_finish_rebind(null)
		else:
			_finish_rebind(k)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.is_pressed():
		_finish_rebind(event)
		get_viewport().set_input_as_handled()


func _on_language_changed(_code: String) -> void:
	_current_tab = _tabs.current_tab
	for c in get_children():
		c.queue_free()
	_build.call_deferred()


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var outer := VBoxContainer.new()
	outer.custom_minimum_size = Vector2(1000, 760)
	outer.add_theme_constant_override("separation", 12)
	center.add_child(outer)

	var title := Label.new()
	title.text = tr("menu.options")
	title.add_theme_font_size_override("font_size", 40)
	outer.add_child(title)

	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(_tabs)

	_tabs.add_child(_video_tab())
	_tabs.add_child(_controls_tab())
	_tabs.add_child(_audio_tab())
	_tabs.add_child(_game_tab())
	_tabs.current_tab = clampi(_current_tab, 0, _tabs.get_tab_count() - 1)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	outer.add_child(bottom)
	_status = Label.new()
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.add_theme_color_override("font_color", UiTheme.ACCENT)
	_status.add_theme_font_size_override("font_size", 20)
	bottom.add_child(_status)
	var defaults := Button.new()
	defaults.text = tr("options.defaults")
	defaults.pressed.connect(func() -> void:
		Settings.reset_to_defaults()
		_on_language_changed(""))
	bottom.add_child(defaults)
	var back := Button.new()
	back.text = tr("menu.back")
	back.custom_minimum_size = Vector2(180, 0)
	back.pressed.connect(func() -> void: closed.emit())
	bottom.add_child(back)
	back.grab_focus.call_deferred()


# --- Pestañas ---------------------------------------------------------------

func _video_tab() -> Control:
	var grid := _tab_grid(tr("options.tab_video"))
	_add_slider(grid, tr("options.fov"), "video", "fov", 1.0, "%d°")
	_add_check(grid, tr("options.fullscreen"), "video", "fullscreen")
	_add_check(grid, tr("options.vsync"), "video", "vsync")
	_add_check(grid, tr("options.show_fps"), "video", "show_fps")
	return grid.get_parent().get_parent()


func _controls_tab() -> Control:
	var grid := _tab_grid(tr("options.tab_controls"))
	_add_slider(grid, tr("options.mouse_sens"), "controls", "mouse_sensitivity", 0.05, "%.2f")
	_add_check(grid, tr("options.invert_y"), "controls", "invert_y")
	_add_check(grid, tr("options.head_bob"), "controls", "head_bob")

	var header := Label.new()
	header.text = tr("options.keybinds")
	header.add_theme_color_override("font_color", UiTheme.ACCENT)
	grid.add_child(header)
	var reset := Button.new()
	reset.text = tr("options.reset_keys")
	reset.size_flags_horizontal = Control.SIZE_SHRINK_END
	reset.pressed.connect(func() -> void:
		Settings.reset_bindings()
		_refresh_bind_buttons(grid))
	grid.add_child(reset)

	for action: String in InputActions.REBINDABLE:
		var l := Label.new()
		l.text = tr("action." + action)
		grid.add_child(l)
		var b := Button.new()
		b.custom_minimum_size = Vector2(260, 0)
		b.size_flags_horizontal = Control.SIZE_SHRINK_END
		b.set_meta("action", action)
		b.text = InputActions.event_label(InputActions.get_kbm_event(action))
		b.pressed.connect(_start_rebind.bind(action, b))
		grid.add_child(b)
	return grid.get_parent().get_parent()


func _audio_tab() -> Control:
	var grid := _tab_grid(tr("options.tab_audio"))
	_add_slider(grid, tr("options.vol_master"), "audio", "master", 0.05, "%d%%", 100.0)
	_add_slider(grid, tr("options.vol_music"), "audio", "music", 0.05, "%d%%", 100.0)
	_add_slider(grid, tr("options.vol_sfx"), "audio", "sfx", 0.05, "%d%%", 100.0)
	_add_slider(grid, tr("options.vol_ui"), "audio", "ui", 0.05, "%d%%", 100.0)
	return grid.get_parent().get_parent()


func _game_tab() -> Control:
	var grid := _tab_grid(tr("options.tab_game"))
	var l := Label.new()
	l.text = tr("options.language")
	grid.add_child(l)
	var opt := OptionButton.new()
	opt.custom_minimum_size = Vector2(260, 0)
	opt.size_flags_horizontal = Control.SIZE_SHRINK_END
	var langs := Loc.available_languages()
	for i in langs.size():
		opt.add_item(Loc.language_name(langs[i]), i)
		if langs[i] == Settings.get_value("game", "language"):
			opt.select(i)
	opt.item_selected.connect(func(idx: int) -> void:
		Settings.set_value("game", "language", langs[idx]))
	grid.add_child(opt)
	return grid.get_parent().get_parent()


# --- Helpers de UI ------------------------------------------------------------

## Crea Scroll > Margin > Grid de 2 columnas; devuelve el Grid.
func _tab_grid(tab_name: String) -> GridContainer:
	var scroll := ScrollContainer.new()
	scroll.name = tab_name
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 10)
	scroll.add_child(margin)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 30)
	grid.add_theme_constant_override("v_separation", 14)
	margin.add_child(grid)
	return grid


func _add_slider(grid: GridContainer, label: String, section: String, key: String,
		step: float, fmt: String, display_mult := 1.0) -> void:
	var l := Label.new()
	l.text = label
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(l)
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_SHRINK_END
	var s := HSlider.new()
	s.custom_minimum_size = Vector2(320, 30)
	var r: Vector2 = Settings.RANGES["%s/%s" % [section, key]]
	s.min_value = r.x
	s.max_value = r.y
	s.step = step
	s.value = Settings.get_value(section, key)
	var val := Label.new()
	val.custom_minimum_size = Vector2(90, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.text = fmt % (s.value * display_mult)
	s.value_changed.connect(func(v: float) -> void:
		val.text = fmt % (v * display_mult)
		Settings.set_value(section, key, v))
	row.add_child(s)
	row.add_child(val)
	grid.add_child(row)


func _add_check(grid: GridContainer, label: String, section: String, key: String) -> void:
	var l := Label.new()
	l.text = label
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(l)
	var c := CheckBox.new()
	c.size_flags_horizontal = Control.SIZE_SHRINK_END
	c.button_pressed = Settings.get_value(section, key)
	c.toggled.connect(func(on: bool) -> void:
		Settings.set_value(section, key, on)
		if section == "video" and key == "show_fps" and DebugTools.overlay_visible != on:
			DebugTools.toggle_overlay())
	grid.add_child(c)


# --- Remapeo ----------------------------------------------------------------

func _start_rebind(action: String, button: Button) -> void:
	if _waiting_button != null:
		_waiting_button.text = InputActions.event_label(InputActions.get_kbm_event(_waiting_action))
	_waiting_action = action
	_waiting_button = button
	button.text = tr("options.press_key")
	_status.text = tr("options.press_key_hint")


func _finish_rebind(event: InputEvent) -> void:
	var action := _waiting_action
	var button := _waiting_button
	_waiting_action = ""
	_waiting_button = null
	_status.text = ""
	if event != null:
		var conflict := Settings.rebind(action, event)
		if conflict != "":
			_status.text = tr("options.key_conflict") % tr("action." + conflict)
	button.text = InputActions.event_label(InputActions.get_kbm_event(action))
	_refresh_bind_buttons(button.get_parent() as GridContainer)


func _refresh_bind_buttons(grid: GridContainer) -> void:
	for c in grid.get_children():
		if c is Button and c.has_meta("action"):
			(c as Button).text = InputActions.event_label(InputActions.get_kbm_event(c.get_meta("action")))
