extends Control
## Fondo del título dibujado por código (placeholder hasta tener arte):
## atardecer brumoso sobre el río, siluetas de islas y la central a lo lejos.
# TODO-ASSET: title_background


func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	var w := size.x
	var h := size.y
	var horizon := h * 0.62
	# Cielo: degradé de arriba (gris azulado) a horizonte (naranja apagado)
	var sky_top := Color("1d2128")
	var sky_mid := Color("4a3a33")
	var sky_low := Color("9a5a32")
	var steps := 48
	for i in steps:
		var t0 := float(i) / steps
		var t1 := float(i + 1) / steps
		var c := sky_top.lerp(sky_mid, minf(t0 * 1.6, 1.0)) if t0 < 0.62 else sky_mid.lerp(sky_low, (t0 - 0.62) / 0.38)
		draw_rect(Rect2(0, horizon * t0, w, horizon * (t1 - t0) + 1), c)
	# Sol velado
	draw_circle(Vector2(w * 0.72, horizon - h * 0.05), h * 0.05, Color(1.0, 0.72, 0.42, 0.55))
	draw_circle(Vector2(w * 0.72, horizon - h * 0.05), h * 0.09, Color(1.0, 0.6, 0.3, 0.12))
	# Central nuclear lejana: domo + chimenea + edificio
	var plant_x := w * 0.62
	var plant := Color("2a2626")
	draw_rect(Rect2(plant_x - w * 0.05, horizon - h * 0.05, w * 0.12, h * 0.05), plant)
	draw_circle(Vector2(plant_x, horizon - h * 0.05), h * 0.045, plant)
	draw_rect(Rect2(plant_x + w * 0.045, horizon - h * 0.16, w * 0.008, h * 0.11), plant)
	# Islas y vegetación: siluetas irregulares deterministas
	var rng := RandomNumberGenerator.new()
	rng.seed = 1977
	var pts := PackedVector2Array([Vector2(0, horizon)])
	var x := 0.0
	while x < w:
		var bump := rng.randf_range(4.0, 26.0) * (1.6 if (x < w * 0.35 or x > w * 0.85) else 0.6)
		pts.append(Vector2(x, horizon - bump))
		x += rng.randf_range(8.0, 22.0)
	pts.append(Vector2(w, horizon))
	pts.append(Vector2(w, horizon + 4))
	pts.append(Vector2(0, horizon + 4))
	draw_colored_polygon(pts, Color("171914"))
	# Río: bandas horizontales con reflejo
	var water_top := Color("3b2e27")
	var water_bot := Color("121411")
	for i in steps:
		var t := float(i) / steps
		var y := horizon + 4 + (h - horizon) * t
		draw_rect(Rect2(0, y, w, (h - horizon) / steps + 1), water_top.lerp(water_bot, t))
	for i in 14:
		var ry := horizon + 10 + i * i * 2.2
		var rw := 40.0 + i * 18.0
		draw_rect(Rect2(w * 0.72 - rw * 0.5, ry, rw, 2), Color(1.0, 0.65, 0.35, 0.18 - i * 0.011))
	# Viñeta
	for i in 10:
		var a := 0.05 * (10 - i) / 10.0
		draw_rect(Rect2(0, 0, w * (0.05 + i * 0.03), h), Color(0, 0, 0, a))
