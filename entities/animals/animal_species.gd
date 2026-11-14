class_name AnimalSpecies
extends Resource
## Datos de una especie de animal (se editan en Godot: data/animals/<id>.tres). El
## comportamiento está en Animal; el cuerpo, en AnimalBody (según `shape`).

@export var id: String = "dog"
## Forma del cuerpo que arma AnimalBody: "dog", "boar" o "capy".
@export var shape: String = "dog"

@export_group("Cuerpo")
@export var hp: float = 55.0
## Ancho, alto y largo del tronco (m).
@export var size: Vector3 = Vector3(0.36, 0.42, 0.95)
## Alto de las patas (m).
@export var leg: float = 0.42
@export var mass: float = 25.0
@export var colors: Array[Color] = [Color(0.36, 0.25, 0.16)]

@export_group("Movimiento")
@export var walk: float = 1.4
@export var trot: float = 3.4
@export var run: float = 9.0
## Qué tan rápido acelera (más alto = más ágil).
@export var accel: float = 9.0

@export_group("Sentidos")
@export var sight: float = 38.0
@export var smell: float = 14.0
## Medio ángulo de visión (grados).
@export var fov: float = 120.0

@export_group("Ataque")
@export var damage: Vector2 = Vector2(7.0, 13.0)
## Alcance de la mordida/embestida (m).
@export var reach: float = 1.35
## Cuánto más alto que él puede estar el blanco para alcanzarlo (subido a algo, no).
@export var reach_up: float = 0.9
## Segundos entre mordidas.
@export var hit_gap: float = 0.75
## Mordidas por entrada (mín, máx).
@export var hits: Vector2i = Vector2i(1, 2)
## Empuje al pegar (m/s): los jabalíes te llevan puesto.
@export var push: float = 0.0
## Cuánto se aleja (m) entre entrada y entrada.
@export var retreat: Vector2 = Vector2(10.0, 20.0)

@export_group("Carácter")
## "pack" (jauría: rodea y muerde de a uno), "charge" (embiste) o "cornered" (se va;
## muerde solo si lo acorralan).
@export var attack_style: String = "pack"
## 0 cobarde – 1 no se va nunca.
@export var courage: float = 0.35
## Parte del grupo que tiene que caer para que se vayan.
@export var flee_frac: float = 0.34
## Radio de su lugar (0 = no defiende).
@export var territory: float = 0.0
## Tamaño del grupo (mín, máx).
@export var pack: Vector2i = Vector2i(3, 5)
## Si hay agua honda cerca, se esconde abajo cuando hay peligro.
@export var hides_in_water: bool = false
## Solo ataca si lo acorralan.
@export var bites_only_cornered: bool = false

static var _cache: Dictionary = {}


## La especie por id (data/animals/<id>.tres).
static func get_species(species_id: String) -> AnimalSpecies:
	if not _cache.has(species_id):
		var r := load("res://data/animals/%s.tres" % species_id) as AnimalSpecies
		_cache[species_id] = r if r != null else load("res://data/animals/dog.tres")
	return _cache[species_id]
