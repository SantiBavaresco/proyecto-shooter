class_name HitInfo
extends RefCounted
## Datos de un impacto de proyectil, para quien lo recibe.

var damage: float = 0.0
## Zona golpeada: "head", "torso", "limb", "weak_point" o "" (objeto sin zonas).
var zone: String = ""
var position: Vector3 = Vector3.ZERO
var normal: Vector3 = Vector3.UP
var direction: Vector3 = Vector3.FORWARD
var surface: String = ""
var weapon_id: String = ""
## Distancia recorrida por el proyectil hasta el impacto (m).
var distance: float = 0.0
## Cuánto cayó la bala respecto de la línea de mira original (m).
var drop: float = 0.0
## Rebotes que hizo antes de este impacto.
var ricochets: int = 0
## Quién disparó (para facciones y reputación en fases siguientes).
var source: Node = null
