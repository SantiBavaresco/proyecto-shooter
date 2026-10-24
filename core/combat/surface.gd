class_name Surface
extends RefCounted
## Tipos de superficie y cómo reaccionan a un impacto.
##
## Cada cuerpo físico declara su material con metadata:  body.set_meta("surface", "metal")
## Si no declara nada se asume "concrete".
##
## ricochet_angle: ángulo máximo (en grados, medido desde la superficie) por
##   debajo del cual la bala puede rebotar. Un tiro rasante rebota; uno de frente no.
## ricochet_chance: probabilidad de rebote a ángulo 0; baja linealmente hasta 0
##   al llegar a ricochet_angle.
## ricochet_energy: fracción de la velocidad que conserva al rebotar.

const DEFAULT := "concrete"

const TABLE: Dictionary = {
	"concrete": {"ricochet_angle": 22.0, "ricochet_chance": 0.7, "ricochet_energy": 0.45,
		"decal": Color(0.12, 0.12, 0.11), "particle": Color(0.62, 0.6, 0.55), "sparks": false, "decals": true},
	"metal": {"ricochet_angle": 32.0, "ricochet_chance": 0.9, "ricochet_energy": 0.6,
		"decal": Color(0.25, 0.24, 0.22), "particle": Color(1.0, 0.72, 0.3), "sparks": true, "decals": true},
	"wood": {"ricochet_angle": 10.0, "ricochet_chance": 0.25, "ricochet_energy": 0.3,
		"decal": Color(0.18, 0.11, 0.05), "particle": Color(0.55, 0.4, 0.22), "sparks": false, "decals": true},
	"dirt": {"ricochet_angle": 7.0, "ricochet_chance": 0.15, "ricochet_energy": 0.2,
		"decal": Color(0.14, 0.1, 0.07), "particle": Color(0.42, 0.33, 0.24), "sparks": false, "decals": true},
	"water": {"ricochet_angle": 9.0, "ricochet_chance": 0.5, "ricochet_energy": 0.3,
		"decal": Color(0, 0, 0, 0), "particle": Color(0.7, 0.75, 0.8), "sparks": false, "decals": false},
	"flesh": {"ricochet_angle": 0.0, "ricochet_chance": 0.0, "ricochet_energy": 0.0,
		"decal": Color(0, 0, 0, 0), "particle": Color(0.75, 0.62, 0.48), "sparks": false, "decals": false},
	"paper": {"ricochet_angle": 0.0, "ricochet_chance": 0.0, "ricochet_energy": 0.0,
		"decal": Color(0.05, 0.05, 0.05), "particle": Color(0.9, 0.88, 0.8), "sparks": false, "decals": true},
}


## Material del objeto golpeado (busca la metadata subiendo hasta 3 padres).
static func of(collider: Object) -> String:
	var n := collider as Node
	for i in 4:
		if n == null:
			break
		if n.has_meta("surface"):
			var s: String = n.get_meta("surface")
			return s if TABLE.has(s) else DEFAULT
		n = n.get_parent()
	return DEFAULT


static func data(surface: String) -> Dictionary:
	return TABLE.get(surface, TABLE[DEFAULT])


## Ángulo entre la trayectoria y la superficie, en grados (0 = rasante, 90 = de frente).
static func grazing_angle(direction: Vector3, normal: Vector3) -> float:
	var d := direction.normalized()
	return rad_to_deg(asin(clampf(absf(d.dot(normal.normalized())), 0.0, 1.0)))


## Probabilidad de rebote para un ángulo dado.
static func ricochet_probability(surface: String, angle_deg: float) -> float:
	var s := data(surface)
	var max_a: float = s["ricochet_angle"]
	if max_a <= 0.0 or angle_deg >= max_a:
		return 0.0
	return float(s["ricochet_chance"]) * (1.0 - angle_deg / max_a)
