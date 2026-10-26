class_name Stress
extends RefCounted
## Estrés de combate, sin dependencias de escena (testeable).
##
## "value" va de 0 (calma) a 1 (estrés alto) y sigue a "target" de a poco: sube
## rápido y baja lento. Por ahora lo fijan las zonas de prueba; más adelante lo
## alimentan la supresión (balas que pasan cerca), el daño y el combate.
##
## Niveles: 0 calma · 1 medio · 2 alto. Los efectos (visión, puntería, temblor) son
## continuos; la recarga elige su plan según el nivel.

const MEDIUM := 0.3
const HIGH := 0.75
## Valor objetivo de cada nivel.
const LEVEL_VALUE: Array[float] = [0.0, 0.5, 1.0]

var value: float = 0.0
var target: float = 0.0
## Segundos de 0 a 1 subiendo y de 1 a 0 bajando.
var rise_time: float = 1.5
var fall_time: float = 5.0

var _time: float = 0.0
var _beat: float = 0.0


func tick(delta: float) -> void:
	_time += delta
	var rate := 1.0 / (rise_time if target > value else fall_time)
	value = move_toward(value, target, rate * delta)
	# Pulso: de ~70 a ~150 latidos por minuto
	_beat = fmod(_beat + delta * lerpf(70.0, 150.0, value) / 60.0, 1.0)


func level() -> int:
	if value >= HIGH:
		return 2
	if value >= MEDIUM:
		return 1
	return 0


## Latido (0..1): dos golpes cortos por ciclo ("lub-dub").
func pulse() -> float:
	var a := exp(-pow((_beat - 0.08) / 0.045, 2.0))
	var b := 0.6 * exp(-pow((_beat - 0.3) / 0.05, 2.0))
	return clampf(a + b, 0.0, 1.0)


## Deriva de la mira (radianes, x = yaw, y = pitch). Lenta y errática; menor
## apuntando ("apenas se mueve la mira"), mayor desde la cadera.
func aim_drift(ads: float) -> Vector2:
	var amp := deg_to_rad(lerpf(0.4, 0.2, ads)) * pow(value, 1.3)
	var t := _time
	var x := sin(t * 1.31) * 0.55 + sin(t * 2.71 + 1.3) * 0.3 + sin(t * 5.3 + 0.4) * 0.15
	var y := sin(t * 1.07 + 2.1) * 0.5 + sin(t * 2.33 + 0.2) * 0.32 + sin(t * 4.9 + 1.7) * 0.18
	# Cada latido empuja un poco la mira
	y += pulse() * 0.25
	return Vector2(x, y) * amp


## Temblor rápido de las manos (−1..1 por eje), para el arma y las manos.
func tremor() -> Vector3:
	var t := _time
	return Vector3(sin(t * 47.0) * 0.5 + sin(t * 71.0 + 1.0) * 0.5, sin(t * 53.0 + 2.0) * 0.5 + sin(t * 89.0) * 0.5,
		sin(t * 61.0 + 0.5) * 0.5 + sin(t * 37.0 + 2.5) * 0.5)


## Multiplicador de la dispersión desde la cadera.
func hip_spread_mult() -> float:
	return 1.0 + value * 1.1
