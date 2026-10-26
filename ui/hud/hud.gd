extends CanvasLayer
## HUD minimalista.
##  - Punto central (se oculta al apuntar).
##  - Marcador de impacto (blanco; rojo en la cabeza o al derribar).
##  - Munición del arma actual (siempre visible), modo de disparo y recarga.
##  - Barra de estamina (solo cuando no está llena).
##  - Texto de interacción.
## Todo se oculta con Opciones → Video → Mostrar interfaz.
## La brújula llega en F3.

const UiTheme := preload("res://ui/theme/ui_theme.gd")
const FADE_SPEED := 2.5

var _root: Control
var _dot: ColorRect
var _hitmarker: Control
var _hit_time: float = 0.0
var _stamina_bar: ProgressBar
var _stamina_root: Control
var _target_alpha: float = 0.0
var _ammo_label: Label
var _reserve_label: Label
var _weapon_label: Label
var _mode_label: Label
var _hint_label: Label
var _status_label: Label
var _fault_label: Label
var _player: Player


func _ready() -> void:
	layer = 10
	_build()
	EventBus.stamina_changed.connect(_on_stamina_changed)
	EventBus.weapon_state_changed.connect(_on_weapon_state)
	EventBus.aim_changed.connect(func(aiming: bool) -> void: _dot.visible = not aiming)
	EventBus.hit_confirmed.connect(_on_hit)
	EventBus.interact_hint_changed.connect(func(t: String) -> void: _hint_label.text = t)
	EventBus.settings_changed.connect(_apply_visibility)
	_apply_visibility()
	var p := get_tree().get_first_node_in_group("player") as Player
	if p != null and p.weapons != null:
		_on_weapon_state(p.weapons.get_state_dict())


func _apply_visibility() -> void:
	_root.visible = Settings.get_value("video", "show_hud")


func _process(delta: float) -> void:
	_stamina_root.modulate.a = move_toward(_stamina_root.modulate.a, _target_alpha, FADE_SPEED * delta)
	_update_status()
	if _hit_time > 0.0:
		_hit_time -= delta
		_hitmarker.modulate.a = clampf(_hit_time / 0.18, 0.0, 1.0)
		_hitmarker.visible = _hit_time > 0.0


func _on_stamina_changed(current: float, maximum: float) -> void:
	var r := current / maximum if maximum > 0.0 else 0.0
	_stamina_bar.value = r * 100.0
	_target_alpha = 0.0 if r >= 0.999 else 1.0
	var fill := _stamina_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill != null:
		fill.bg_color = UiTheme.ALERT if r < 0.25 else UiTheme.TEXT.darkened(0.15)


func _on_weapon_state(s: Dictionary) -> void:
	if s.is_empty():
		return
	_ammo_label.text = "%d" % s["mag"]
	_reserve_label.text = "∞" if s["infinite"] else "/ %d" % s["reserve"]
	var low: bool = s["mag"] <= maxi(1, int(s["mag_size"] * 0.2))
	_ammo_label.add_theme_color_override("font_color", UiTheme.ALERT if low else UiTheme.TEXT)
	_weapon_label.text = "%s · %s" % [tr(s["name_key"]), s.get("caliber", "")] if s.get("caliber", "") != "" else tr(s["name_key"])
	var fault: String = s.get("fault", "")
	_fault_label.text = tr("weapon.fault_" + fault) if fault != "" and not s.get("clearing", false) else ""
	if s.get("clearing", false):
		_mode_label.text = tr("weapon.racking") if fault == "unchambered" else tr("weapon.clearing")
	elif s["reloading"]:
		_mode_label.text = tr("weapon.reloading")
	elif s.get("zoom_variable", false):
		_mode_label.text = "%s×" % String.num(s["zoom"], 1).trim_suffix(".0")
	elif s["has_modes"]:
		_mode_label.text = tr("weapon.mode_auto") if s["mode"] == "auto" else tr("weapon.mode_semi")
	else:
		_mode_label.text = ""


## Estrés y estado del arma (chico, arriba del nombre del arma).
func _update_status() -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player
		if _player == null:
			return
	var parts: PackedStringArray = []
	var lvl := _player.stress.level()
	if lvl > 0:
		parts.append([tr("stress.medium"), tr("stress.high"), tr("stress.extreme")][lvl - 1])
	var w := _player.weapons
	if w != null and w.current() != null:
		var cond := w.effective_condition(w.current())
		if cond < 0.995:
			parts.append(tr("weapon.condition") % int(round(cond * 100.0)))
	_status_label.text = "  ·  ".join(parts)
	_status_label.add_theme_color_override("font_color", UiTheme.ALERT if lvl >= 2 else UiTheme.TEXT_DIM)


func _on_hit(info: HitInfo, killed: bool) -> void:
	_hit_time = 0.18 if not killed else 0.35
	var c := Color(1, 0.3, 0.25) if (killed or DamageModel.is_head(info.zone)) else Color(1, 1, 1)
	for line in _hitmarker.get_children():
		(line as ColorRect).color = c
	_hitmarker.visible = true


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_dot = ColorRect.new()
	_dot.color = Color(1, 1, 1, 0.75)
	_dot.set_anchors_preset(Control.PRESET_CENTER)
	_dot.offset_left = -2
	_dot.offset_top = -2
	_dot.offset_right = 2
	_dot.offset_bottom = 2
	_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_dot)

	# Marcador de impacto: cuatro trazos en diagonal alrededor del centro
	_hitmarker = Control.new()
	_hitmarker.set_anchors_preset(Control.PRESET_CENTER)
	_hitmarker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hitmarker.visible = false
	_root.add_child(_hitmarker)
	for i in 4:
		var line := ColorRect.new()
		line.size = Vector2(10, 2)
		line.pivot_offset = Vector2(5, 1)
		var ang := PI * 0.25 + i * PI * 0.5
		line.position = Vector2(cos(ang), sin(ang)) * 12.0 - Vector2(5, 1)
		line.rotation = ang
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hitmarker.add_child(line)

	_stamina_root = Control.new()
	_stamina_root.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_stamina_root.offset_left = -160
	_stamina_root.offset_right = 160
	_stamina_root.offset_top = -70
	_stamina_root.offset_bottom = -64
	_stamina_root.modulate.a = 0.0
	_stamina_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_stamina_root)
	_stamina_bar = ProgressBar.new()
	_stamina_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stamina_bar.show_percentage = false
	_stamina_bar.value = 100.0
	_stamina_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = UiTheme.TEXT.darkened(0.15)
	fill.set_corner_radius_all(2)
	_stamina_bar.add_theme_stylebox_override("fill", fill)
	_stamina_root.add_child(_stamina_bar)

	# Munición abajo a la derecha
	var ammo_box := VBoxContainer.new()
	ammo_box.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ammo_box.offset_left = -360
	ammo_box.offset_right = -48
	ammo_box.offset_top = -175
	ammo_box.offset_bottom = -40
	ammo_box.alignment = BoxContainer.ALIGNMENT_END
	ammo_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(ammo_box)
	_status_label = _label(16, UiTheme.TEXT_DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	ammo_box.add_child(_status_label)
	_weapon_label = _label(20, UiTheme.TEXT_DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	ammo_box.add_child(_weapon_label)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 10)
	ammo_box.add_child(row)
	_ammo_label = _label(52, UiTheme.TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
	_reserve_label = _label(26, UiTheme.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT)
	_reserve_label.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(_ammo_label)
	row.add_child(_reserve_label)
	_mode_label = _label(18, UiTheme.ACCENT, HORIZONTAL_ALIGNMENT_RIGHT)
	ammo_box.add_child(_mode_label)

	_hint_label = _label(22, UiTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_hint_label.set_anchors_preset(Control.PRESET_CENTER)
	_hint_label.offset_left = -300
	_hint_label.offset_right = 300
	_hint_label.offset_top = 60
	_hint_label.offset_bottom = 100
	_root.add_child(_hint_label)

	# Falla del arma: debajo del centro, en rojo
	_fault_label = _label(22, UiTheme.ALERT, HORIZONTAL_ALIGNMENT_CENTER)
	_fault_label.set_anchors_preset(Control.PRESET_CENTER)
	_fault_label.offset_left = -360
	_fault_label.offset_right = 360
	_fault_label.offset_top = 110
	_fault_label.offset_bottom = 150
	_root.add_child(_fault_label)


func _label(font_size: int, color: Color, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
