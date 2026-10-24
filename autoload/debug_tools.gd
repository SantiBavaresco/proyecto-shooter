extends CanvasLayer
## Herramientas de diagnóstico.
##  F1  → overlay con FPS, memoria, draw calls, estado y datos del jugador.
##  F12 → guarda un reporte de bug en user://bug_reports/ y lo copia al portapapeles.

const REPORT_DIR := "user://bug_reports/"
const LOG_TAIL_LINES := 80

var overlay_visible: bool = false
## Laboratorio: dibujar trayectorias de los proyectiles (F3).
var show_trajectories: bool = false
## Laboratorio: munición infinita (F4).
var infinite_ammo: bool = false

var _panel: PanelContainer
var _label: Label
var _toast: Label
var _toast_time: float = 0.0
var _refresh: float = 0.0


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	overlay_visible = Settings.get_value("video", "show_fps")
	_panel.visible = overlay_visible
	_ready_toast_hook()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_overlay"):
		toggle_overlay()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("bug_report"):
		save_bug_report()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("debug_trajectories"):
		show_trajectories = not show_trajectories
		_show_toast(tr("lab.trajectories") % _on_off(show_trajectories))
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("debug_infinite_ammo"):
		infinite_ammo = not infinite_ammo
		_show_toast(tr("lab.infinite_ammo") % _on_off(infinite_ammo))
		get_viewport().set_input_as_handled()


func _on_off(v: bool) -> String:
	return tr("lab.on") if v else tr("lab.off")


func _process(delta: float) -> void:
	if _toast_time > 0.0:
		_toast_time -= delta
		_toast.visible = _toast_time > 0.0
	if not overlay_visible:
		return
	_refresh -= delta
	if _refresh <= 0.0:
		_refresh = 0.25
		_label.text = build_overlay_text()


func toggle_overlay() -> void:
	overlay_visible = not overlay_visible
	_panel.visible = overlay_visible
	_label.text = build_overlay_text()


func build_overlay_text() -> String:
	var lines: PackedStringArray = []
	lines.append("FPS %d  (%.1f ms)" % [Engine.get_frames_per_second(), 1000.0 / maxf(Engine.get_frames_per_second(), 1.0)])
	lines.append("Draw calls %d  ·  Primitivas %d" % [
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])
	lines.append("VRAM %.0f MB  ·  RAM %.0f MB" % [
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0])
	lines.append("Estado %s" % GameState.state_name())
	lines.append(tr("lab.trajectories") % _on_off(show_trajectories))
	lines.append(tr("lab.infinite_ammo") % _on_off(infinite_ammo))
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("get_debug_info"):
		var info: Dictionary = player.get_debug_info()
		for k: String in info:
			lines.append("%s %s" % [k, info[k]])
	return "\n".join(lines)


func save_bug_report() -> String:
	DirAccess.make_dir_recursive_absolute(REPORT_DIR)
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var file_path := REPORT_DIR + "reporte_%s.txt" % stamp
	var text := build_bug_report()
	var f := FileAccess.open(file_path, FileAccess.WRITE)
	if f == null:
		push_error("DebugTools: no se pudo escribir %s" % file_path)
		return ""
	f.store_string(text)
	f.close()
	if DisplayServer.get_name() != "headless":
		DisplayServer.clipboard_set(text)
	var abs_path := ProjectSettings.globalize_path(file_path)
	_show_toast(tr("debug.report_saved") % abs_path)
	EventBus.bug_report_saved.emit(abs_path)
	return abs_path


func build_bug_report() -> String:
	var lines: PackedStringArray = []
	lines.append("=== REPORTE DE BUG — MEDOREADOR ===")
	lines.append("Versión: %s" % ProjectSettings.get_setting("application/config/version"))
	lines.append("Godot: %s" % Engine.get_version_info().string)
	lines.append("Fecha: %s" % Time.get_datetime_string_from_system())
	lines.append("SO: %s %s" % [OS.get_name(), OS.get_version()])
	lines.append("GPU: %s (%s)" % [RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_api_version()])
	lines.append("CPU: %s (%d hilos)" % [OS.get_processor_name(), OS.get_processor_count()])
	lines.append("")
	lines.append("--- Estado ---")
	lines.append(build_overlay_text())
	lines.append("Escena: %s" % (get_tree().current_scene.scene_file_path if get_tree().current_scene else "-"))
	lines.append("")
	lines.append("--- Opciones ---")
	for section: String in Settings.DEFAULTS:
		for key: String in Settings.DEFAULTS[section]:
			lines.append("%s/%s = %s" % [section, key, Settings.get_value(section, key)])
	lines.append("")
	lines.append("--- Últimas líneas del log ---")
	lines.append(_log_tail())
	return "\n".join(lines)


func _log_tail() -> String:
	var log_path := "user://logs/godot.log"
	if not FileAccess.file_exists(log_path):
		return "(sin log)"
	var all_lines := FileAccess.get_file_as_string(log_path).split("\n")
	var start := maxi(0, all_lines.size() - LOG_TAIL_LINES)
	return "\n".join(all_lines.slice(start))


func _ready_toast_hook() -> void:
	EventBus.toast.connect(_show_toast)


func _show_toast(text: String) -> void:
	_toast.text = text
	_toast.visible = true
	_toast_time = 4.0


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.position = Vector2(16, 16)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.6)
	sb.set_content_margin_all(10)
	sb.set_corner_radius_all(4)
	_panel.add_theme_stylebox_override("panel", sb)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 18)
	_label.add_theme_color_override("font_color", Color(0.75, 1.0, 0.75))
	_panel.add_child(_label)
	add_child(_panel)

	_toast = Label.new()
	_toast.anchor_left = 0.5
	_toast.anchor_right = 0.5
	_toast.anchor_top = 1.0
	_toast.anchor_bottom = 1.0
	_toast.offset_top = -120
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_font_size_override("font_size", 20)
	_toast.visible = false
	add_child(_toast)
