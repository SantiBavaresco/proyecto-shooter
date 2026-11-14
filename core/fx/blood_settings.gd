class_name BloodSettings
extends Resource
## Ajustes de la sangre (data/fx/blood.tres, se editan en Godot). Los usa Blood.

@export_group("General")
## Máximo de manchas en el mundo (las más viejas se van).
@export var max_decals: int = 260
## Alfa de las manchas (1 = como la textura).
@export var opacity: float = 1.0

@export_group("Impacto en el cuerpo")
## Gotas por tiro al cuerpo.
@export var hit_drops: int = 22
@export var hit_speed: float = 3.5
## Hasta dónde llega la salpicadura detrás (pared o piso), m.
@export var splatter_range: float = 3.0
## Tamaño de la salpicadura en la pared/piso (mín, máx), m.
@export var splatter_size: Vector2 = Vector2(0.7, 1.3)
## Cuerpo en el piso: mancha debajo por cada tiro (mín, máx), m.
@export var corpse_splat_size: Vector2 = Vector2(0.3, 0.6)

@export_group("Tiro a la cabeza")
@export var head_drops: int = 150
@export var head_speed: float = 7.5
## Rayos de salpicadura en abanico detrás de la cabeza.
@export var head_splatters: int = 6
@export var head_cone_deg: float = 22.0

@export_group("Charco")
## El charco: crece hasta el tamaño pedido × esto.
@export var pool_size_mult: float = 1.25
## Manchas extra alrededor (que no quede redondo).
@export var pool_satellites: Vector2i = Vector2i(2, 4)
## En pendiente corre: "río" de este largo (mín, máx), m, en tantas manchas.
@export var flow_length: Vector2 = Vector2(1.2, 3.2)
@export var flow_steps: int = 6
## Pendiente mínima (1 - normal.y) para que corra.
@export var flow_min_slope: float = 0.004

@export_group("Arrastre")
## Ancho y largo de cada trazo de arrastre (m).
@export var smear_width: Vector2 = Vector2(0.28, 0.45)
@export var smear_length: Vector2 = Vector2(0.6, 1.1)

static var _default: BloodSettings


static func get_default() -> BloodSettings:
	if _default == null:
		_default = load("res://data/fx/blood.tres") as BloodSettings
		if _default == null:
			_default = BloodSettings.new()
	return _default
