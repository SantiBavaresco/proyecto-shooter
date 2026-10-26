class_name Stress
extends RefCounted
## Estrés de combate, sin dependencias de escena (testeable).
##
## "value" va de 0 (calma) a 1 (estrés alto) y "extreme" de 0 a 1 por encima de eso
## (estrés extremo, para casos puntuales). Los dos siguen a su objetivo de a poco:
## suben rápido y bajan lento. Por ahora los fijan las zonas de prueba; más adelante
## lo alimentan la supresión (balas que pasan cerca), el daño y el combate.
##
## Niveles: 0 calma · 1 medio · 2 alto · 3 extremo. Los efectos (visión, puntería,
## pulso inestable) son continuos; la recarga elige su plan según el nivel.

const MEDIUM := 0.3
const HIGH := 0.75
## Objetivos [value, extreme] de cada nivel.
const LEVEL_TARGET: Array = [[0.0, 0.0], [0.5, 0.0], [1.0, 0.0], [1.0, 1.0]]

var value: float = 0.0
var target: float = 0.0
var extreme: float = 0.0
var extreme_target: float = 0.0
## Segundos de 0 a 1 subiendo y de 1 a 0 bajando.
var rise_time: float = 1.5
var fall_time: float = 5.0

var _time: float = 0.0
var _beat: float = 0.0


func set_level(lvl: int) -> void:
	var t: Array = LEVEL_TARGET[clampi(lvl, 0, 3)]
	target = t[0]
	extreme_target = t[1]


func tick(delta: float) -> void:
	_time += delta
	var rate := 1.0 / (rise_time if target > value else fall_time)
	value = move_toward(value, target, rate * delta)
	rate = 1.0 / (rise_time if extreme_target > extreme else fall_time)
	extreme = move_toward(extreme, extreme_target, rate * delta)
	# Pulso: de ~70 a ~150 latidos por minuto (hasta ~175 en extremo)
	_beat = fmod(_beat + delta * (lerpf(70.0, 150.0, value) + 25.0 * extreme) / 60.0, 1.0)


func level() -> int:
	if extreme >= 0.5:
		return 3
	if value >= HIGH:
		return 2
	if value >= MEDIUM:
		return 1
	return 0


## Latido (0..1): dos golpes cortos por ciclo ("lub-dub"). Para la imagen.
func pulse() -> float:
	var a := exp(-pow((_beat - 0.08) / 0.045, 2.0))
	var b := 0.6 * exp(-pow((_beat - 0.3) / 0.05, 2.0))
	return clampf(a + b, 0.0, 1.0)


## Latido redondeado, para el movimiento (sin golpes secos que se vean como vibración).
func pulse_soft() -> float:
	var a := exp(-pow((_beat - 0.12) / 0.13, 2.0))
	var b := 0.5 * exp(-pow((_beat - 0.4) / 0.13, 2.0))
	return clampf(a + b, 0.0, 1.0)


## Desenfoque extra (0..1): en alto apenas un poco más que el base, en extremo todo.
func blur_extra() -> float:
	return pow(value, 3.0) * 0.15 + extreme * 0.85


## Visión de túnel (0..1): nada en medio, suave en alto, completa en extremo.
func tunnel() -> float:
	return smoothstep(0.75, 1.0, value) * 0.45 + extreme * 0.55


## Deriva de la mira (radianes, x = yaw, y = pitch). Lenta y errática; menor
## apuntando ("apenas se mueve la mira"), mayor desde la cadera y en extremo.
func aim_drift(ads: float) -> Vector2:
	var amp := deg_to_rad(lerpf(0.4, 0.2, ads)) * pow(value, 1.3) * (1.0 + extreme * 1.6)
	var t := _time
	var x := sin(t * 1.31) * 0.55 + sin(t * 2.71 + 1.3) * 0.3 + sin(t * 4.1 + 0.4) * 0.15
	var y := sin(t * 1.07 + 2.1) * 0.5 + sin(t * 2.33 + 0.2) * 0.32 + sin(t * 3.9 + 1.7) * 0.18
	# Cada latido empuja un poco la mira
	y += pulse_soft() * 0.25
	# Extremo: la mira también sube y baja bastante
	y *= 1.0 + extreme * 1.3
	return Vector2(x, y) * amp


## Pulso inestable de las manos (−1..1 por eje, más en extremo): balanceo lento e
## irregular, sin vibrar (varias ondas lentas que no se repiten), con un tirón suave
## en cada latido.
func tremor() -> Vector3:
	var v := tremor_base()
	# Extremo: además sube y baja con fuerza (respiración agitada), no solo de costado
	var t := _time
	v.y += (sin(t * 2.6 + 0.9) * 0.7 + sin(t * 3.9 + 2.2) * 0.3) * extreme * 1.4
	return v * (1.0 + extreme * 2.8)


## Balanceo base (−1..1), sin la amplificación del extremo: para las manos al
## manipular, que se mueven respecto del arma (el hombro no puede viajar).
func tremor_base() -> Vector3:
	var t := _time
	var p := pulse_soft() * 0.3
	var v := Vector3(
		sin(t * 1.7) * 0.5 + sin(t * 2.9 + 1.1) * 0.3 + sin(t * 4.3 + 2.0) * 0.2,
		sin(t * 1.4 + 0.7) * 0.45 + sin(t * 3.1 + 2.4) * 0.3 + sin(t * 4.1 + 0.3) * 0.25 - p,
		sin(t * 2.1 + 1.6) * 0.5 + sin(t * 3.4 + 0.2) * 0.3 + sin(t * 4.7 + 1.0) * 0.2)
	return v


## Multiplicador de la dispersión desde la cadera.
func hip_spread_mult() -> float:
	return 1.0 + value * 1.1 + extreme * 0.7
