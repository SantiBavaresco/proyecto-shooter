class_name DamageModel
extends Resource
## Multiplicadores de daño por zona del cuerpo. Archivo: res://data/combat/damage_model.tres

@export var head: float = 2.5
@export var torso: float = 1.0
@export var limb: float = 0.6
## Puntos débiles expuestos (exoesqueletos, más adelante).
@export var weak_point: float = 2.0


func multiplier(zone: String) -> float:
	match zone:
		"head":
			return head
		"torso":
			return torso
		"limb":
			return limb
		"weak_point":
			return weak_point
		_:
			return 1.0
