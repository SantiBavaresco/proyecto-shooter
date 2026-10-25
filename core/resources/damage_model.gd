class_name DamageModel
extends Resource
## Multiplicadores de daño por zona del cuerpo. Archivo: res://data/combat/damage_model.tres
##
## La cabeza tiene dos zonas: "head_core" (cerebro, tronco, centro de la cara) es
## letal con cualquier arma; "head" (periferia: pómulo, mandíbula, oreja, roce del
## cráneo) hace mucho daño pero no siempre mata.

@export var head_core_lethal: bool = true
## Daño que se aplica en un impacto letal (supera cualquier vida).
@export var lethal_damage: float = 1000.0
@export var head: float = 3.0
@export var torso: float = 1.0
@export var limb: float = 0.6
## Puntos débiles expuestos (exoesqueletos, más adelante).
@export var weak_point: float = 2.0


func multiplier(zone: String) -> float:
	match zone:
		"head_core":
			return head * 2.0
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


func is_lethal(zone: String) -> bool:
	return zone == "head_core" and head_core_lethal


static func is_head(zone: String) -> bool:
	return zone.begins_with("head")
