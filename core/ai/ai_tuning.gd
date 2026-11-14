class_name AiTuning
extends Resource
## Ajustes de la IA de los enemigos humanos (data/ai/ai_tuning.tres, se editan en
## Godot). Lo que depende de la dificultad está en Difficulty; lo de cada equipo
## (armas, blindaje) en NpcLoadouts. Acá, el comportamiento en general.

@export_group("Movimiento")
## En combate, los tramos más largos que sprint_min (m) los hace corriendo (m/s).
@export var sprint_speed: float = 6.2
@export var sprint_min: float = 5.0

@export_group("Oído")
## Tiroteo de un compañero: a menos de esto se suma; hasta ally_check va a ver (m).
@export var ally_join: float = 45.0
@export var ally_check: float = 80.0
## Un disparo o explosión más lejos que esto: solo alerta (m).
@export var far_shot: float = 95.0

@export_group("Arbustos")
## Escondido en un arbusto: a menos de esto te ven igual (alerta / tranquilo), m.
@export var bush_seen_alert: float = 6.0
@export var bush_seen_calm: float = 3.5
## Segundos que le tiran al arbusto donde te perdieron.
@export var bush_fire_time: float = 7.0

@export_group("Combate")
## A ciegas, tira como mucho esto (s) después de perderte.
@export var suppress_max_time: float = 10.0
## Cuántos de una escuadra tiran a ciegas a la vez.
@export var suppress_max_shooters: int = 2
## Culatazo a esta distancia (m).
@export var melee_range: float = 1.8
@export var melee_damage: Vector2 = Vector2(8.0, 15.0)
## Probabilidad de que el culatazo te tire al piso.
@export var melee_knockdown: float = 0.3
## Después de tantos tiros se porta como con poca munición.
@export var low_ammo_after: int = 150
## Cada cuánto (s) una escuadra que te perdió manda a alguien a flanquear.
@export var flank_cooldown: float = 16.0

@export_group("Animales")
## Los ven recién a esta distancia (m).
@export var animal_sight: float = 15.0

@export_group("Muerte")
## Agonía (sin tiro a la cabeza), segundos.
@export var agony_time: Vector2 = Vector2(20.0, 30.0)

static var _default: AiTuning


static func get_default() -> AiTuning:
	if _default == null:
		_default = load("res://data/ai/ai_tuning.tres") as AiTuning
		if _default == null:
			_default = AiTuning.new()
	return _default
