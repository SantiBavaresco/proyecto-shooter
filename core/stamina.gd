class_name Stamina
extends RefCounted
## Modelo de estamina, sin dependencias de escena (testeable).
##
## - Correr la drena por segundo; saltar y deslizarse cuestan un monto fijo.
## - Se regenera después de un retraso sin gastar.
## - Si llega a 0 queda "agotada": no se puede correr hasta recuperar
##   el umbral `recover_threshold`.

var maximum: float = 100.0
var current: float = 100.0
var regen_rate: float = 18.0
var regen_delay: float = 1.0
var recover_threshold: float = 25.0

var exhausted: bool = false
## Multiplicadores: regeneración (energizante) y costo de todo gasto (sobrepeso).
var regen_mult: float = 1.0
var cost_mult: float = 1.0
var _since_spent: float = 999.0


func configure(cfg: PlayerMovementConfig) -> void:
	maximum = cfg.stamina_max
	current = cfg.stamina_max
	regen_rate = cfg.stamina_regen
	regen_delay = cfg.stamina_regen_delay
	recover_threshold = cfg.stamina_recover_threshold
	exhausted = false


## Avanza el tiempo: regeneración.
func tick(delta: float) -> void:
	_since_spent += delta
	if _since_spent >= regen_delay and current < maximum:
		current = minf(maximum, current + regen_rate * regen_mult * delta)
	if exhausted and current >= recover_threshold:
		exhausted = false


## Gasto continuo (ej. correr): amount_per_sec * delta.
func drain(amount_per_sec: float, delta: float) -> void:
	_spend(amount_per_sec * delta)


## Gasto puntual. Devuelve false (y no gasta) si no alcanza.
func try_consume(amount: float) -> bool:
	if current < amount * cost_mult:
		return false
	_spend(amount)
	return true


## Recupera estamina de golpe (energizante, agua).
func restore(amount: float) -> void:
	current = minf(maximum, current + amount)
	if exhausted and current >= recover_threshold:
		exhausted = false


func can_sprint() -> bool:
	return not exhausted and current > 0.0


func ratio() -> float:
	return current / maximum if maximum > 0.0 else 0.0


func _spend(amount: float) -> void:
	current = maxf(0.0, current - amount * cost_mult)
	_since_spent = 0.0
	if current <= 0.0:
		exhausted = true
