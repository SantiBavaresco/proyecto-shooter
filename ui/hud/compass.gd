class_name HudCompass
extends Control
## Brújula de la parte de arriba: franja con los puntos cardinales y marcas cada 15°,
## que se corre según hacia dónde mira el jugador (el norte es −Z del mundo).

const SPAN_DEG := 150.0
const WIDTH := 560.0
const HEIGHT := 34.0
const LABELS := {0: "N", 45: "NE", 90: "E", 135: "SE", 180: "S", 225: "SO", 270: "O", 315: "NO"}

var heading_deg: float = 0.0
var _font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(WIDTH, HEIGHT)
	set_anchors_preset(Control.PRESET_CENTER_TOP)
	offset_left = -WIDTH * 0.5
	offset_right = WIDTH * 0.5
	offset_top = 14.0
	offset_bottom = 14.0 + HEIGHT
	_font = get_theme_default_font()


## Marcas en la franja: [rumbo (grados), texto].
var _marks: Array = []


func _process(_delta: float) -> void:
	var p := get_tree().get_first_node_in_group("player") as Player
	if p == null:
		return
	# yaw 0 = mirando a −Z (norte); girar a la derecha baja el yaw → rumbo sube
	heading_deg = fposmod(-rad_to_deg(p.yaw), 360.0)
	_marks.clear()
	for n in get_tree().get_nodes_in_group("compass_marker"):
		var m := n as Node3D
		if m == null or not m.has_method("compass_label"):
			continue
		var label := String(m.call("compass_label"))
		if label == "":
			continue
		var to := m.global_position - p.global_position
		var brg := fposmod(rad_to_deg(atan2(to.x, -to.z)), 360.0)
		_marks.append([brg, "%s %dm" % [label, roundi(Vector2(to.x, to.z).length())]])
	queue_redraw()


func _draw() -> void:
	var c := Color(0.92, 0.9, 0.84)
	var mid := WIDTH * 0.5
	# Fondo suave que se desvanece en los bordes
	for i in 24:
		var a := 0.28 * sin(PI * (i + 0.5) / 24.0)
		draw_rect(Rect2(WIDTH * i / 24.0, 4, WIDTH / 24.0 + 1, HEIGHT - 8), Color(0, 0, 0, a))
	var start := int(floor((heading_deg - SPAN_DEG * 0.5) / 15.0)) * 15
	var deg := start
	while deg <= heading_deg + SPAN_DEG * 0.5:
		var off := (deg - heading_deg) / (SPAN_DEG * 0.5)
		var x := mid + off * mid
		var fade := clampf(1.0 - absf(off) ** 2, 0.0, 1.0)
		var key := posmod(deg, 360)
		if LABELS.has(key):
			var txt: String = LABELS[key]
			var fs := 18 if txt.length() == 1 else 14
			var sz := _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
			var col := Color(1.0, 0.78, 0.35, fade) if txt == "N" else Color(c.r, c.g, c.b, fade)
			draw_string(_font, Vector2(x - sz.x * 0.5, HEIGHT * 0.5 + 6), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
		else:
			draw_line(Vector2(x, HEIGHT * 0.5 - 4), Vector2(x, HEIGHT * 0.5 + 4), Color(c.r, c.g, c.b, fade * 0.7), 1.5)
		deg += 15
	for mk: Array in _marks:
		var dd := wrapf(float(mk[0]) - heading_deg, -180.0, 180.0)
		var off2 := clampf(dd / (SPAN_DEG * 0.5), -1.0, 1.0)
		var mx := mid + off2 * mid
		var mc := Color(0.95, 0.75, 0.3, 0.95)
		draw_colored_polygon(PackedVector2Array([Vector2(mx, 0), Vector2(mx - 5, 6), Vector2(mx, 12), Vector2(mx + 5, 6)]), mc)
		if absf(dd) < SPAN_DEG * 0.5:
			var ts := _font.get_string_size(String(mk[1]), HORIZONTAL_ALIGNMENT_CENTER, -1, 12)
			draw_string(_font, Vector2(mx - ts.x * 0.5, HEIGHT + 30), String(mk[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, mc)
	# Marca del centro y rumbo en grados
	draw_line(Vector2(mid, 0), Vector2(mid, 6), Color(1, 1, 1, 0.9), 2.0)
	var hs := "%03d" % roundi(heading_deg) if roundi(heading_deg) < 360 else "000"
	var s2 := _font.get_string_size(hs, HORIZONTAL_ALIGNMENT_CENTER, -1, 12)
	draw_string(_font, Vector2(mid - s2.x * 0.5, HEIGHT + 12), hs, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(c.r, c.g, c.b, 0.7))
