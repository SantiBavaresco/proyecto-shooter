class_name HudDamageIndicator
extends Control
## Indicador de daño: un arco rojo alrededor del centro que apunta hacia donde vino
## el tiro (se acomoda si el jugador gira) y se desvanece en un par de segundos.

const LIFE := 2.2
const RADIUS := 120.0

## [origen (mundo), tiempo que le queda]
var _marks: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	EventBus.player_hit_from.connect(func(o: Vector3) -> void:
		_marks.append([o, LIFE])
		if _marks.size() > 6:
			_marks.pop_front())


func _process(delta: float) -> void:
	for m: Array in _marks:
		m[1] = float(m[1]) - delta
	_marks = _marks.filter(func(m: Array) -> bool: return float(m[1]) > 0.0)
	queue_redraw()


func _draw() -> void:
	var p := get_tree().get_first_node_in_group("player") as Player
	if p == null or _marks.is_empty():
		return
	var c := size * 0.5
	for m: Array in _marks:
		var to: Vector3 = (m[0] as Vector3) - p.global_position
		# Ángulo relativo a la mirada: 0 = adelante, crece hacia la derecha
		var ang := atan2(to.x, -to.z) + p.yaw
		var a := clampf(float(m[1]) / LIFE, 0.0, 1.0)
		var dir := Vector2(sin(ang), -cos(ang))
		var pts := PackedVector2Array()
		for i in 13:
			var t := ang - 0.32 + 0.64 * i / 12.0
			pts.append(c + Vector2(sin(t), -cos(t)) * RADIUS)
		draw_polyline(pts, Color(0.9, 0.12, 0.08, 0.85 * a), 7.0, true)
		draw_circle(c + dir * (RADIUS + 12.0), 4.0, Color(0.9, 0.12, 0.08, 0.7 * a))
