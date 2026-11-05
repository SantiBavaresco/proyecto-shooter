extends OmniLight3D
## Luz de fuego que titila.

var _base: float = 1.0
var _t: float = 0.0


func _ready() -> void:
	_base = light_energy
	_t = randf() * 10.0


func _process(delta: float) -> void:
	_t += delta
	light_energy = _base * (0.82 + 0.12 * sin(_t * 9.0) + 0.08 * sin(_t * 23.0 + 1.3))
