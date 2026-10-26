class_name TestZone
extends Node3D
## Zona de prueba: rectángulo pintado en el piso. Mientras el jugador está dentro
## se aplica su efecto (lo consulta el jugador cada tick; no usa física).
##  - "stress_medium" / "stress_high": estrés de combate.
##  - "worn": el arma en la mano se comporta como muy gastada (fallas frecuentes).

@export var kind: String = "stress_medium"
## Tamaño en el piso (x, z) en metros.
@export var size: Vector2 = Vector2(3.0, 3.0)
@export var color: Color = Color(0.8, 0.6, 0.1)
@export var title: String = ""


func _ready() -> void:
	add_to_group("test_zones")
	# Piso pintado con borde
	var fill := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = size
	fill.mesh = pm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color, 0.28)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fill.material_override = m
	fill.position.y = 0.015
	add_child(fill)
	var edge := StandardMaterial3D.new()
	edge.albedo_color = color
	edge.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in 4:
		var b := MeshInstance3D.new()
		var bm := BoxMesh.new()
		var horiz := i < 2
		bm.size = Vector3(size.x if horiz else 0.08, 0.02, 0.08 if horiz else size.y)
		b.mesh = bm
		b.material_override = edge
		var sgn := -1.0 if i % 2 == 0 else 1.0
		b.position = Vector3(0, 0.02, sgn * size.y * 0.5) if horiz else Vector3(sgn * size.x * 0.5, 0.02, 0)
		add_child(b)
	if title != "":
		var l := Label3D.new()
		l.text = title
		l.pixel_size = 0.006
		l.font_size = 48
		l.outline_size = 8
		l.modulate = color.lightened(0.3)
		l.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		l.position = Vector3(0, 2.4, 0)
		add_child(l)
		# Texto pintado en el piso
		var f := Label3D.new()
		f.text = title
		f.pixel_size = 0.005
		f.font_size = 48
		f.modulate = Color(color, 0.85)
		f.rotation = Vector3(-PI * 0.5, PI, 0)
		f.position = Vector3(0, 0.03, size.y * 0.3)
		add_child(f)


## ¿El punto (en el mundo) está dentro de la zona?
func contains(p: Vector3) -> bool:
	var l := global_transform.affine_inverse() * p
	return absf(l.x) <= size.x * 0.5 and absf(l.z) <= size.y * 0.5 and l.y > -1.0 and l.y < 3.0


## Tipos de zona en los que está el punto.
static func kinds_at(tree: SceneTree, p: Vector3) -> PackedStringArray:
	var out := PackedStringArray()
	for n in tree.get_nodes_in_group("test_zones"):
		var z := n as TestZone
		if z != null and z.contains(p):
			out.append(z.kind)
	return out
