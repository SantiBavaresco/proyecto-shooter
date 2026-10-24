class_name WeaponModelBuilder
extends RefCounted
## Modelos de armas de prueba armados con primitivas. TODO-ASSET: weapon_rifle, weapon_shotgun, weapon_pistol
##
## Convenciones (las mismas que deben respetar los modelos reales):
##  - Metros, cañón hacia −Z, +Y arriba, origen en la empuñadura.
##  - Marcadores (Marker3D): Muzzle (boca), Sight (punto de la línea de mira),
##    Ejection (ventana de expulsión).
##  - Piezas animables (Node3D): Mag (cargador), Slide (corredera), Charging
##    (manija de carga), Barrels (pivote de los caños de la escopeta) con
##    ShellL / ShellR adentro.

const RED_DOT_SHADER := preload("res://entities/weapons/red_dot.gdshader")

static var _mats: Dictionary = {}


static func build(model: String) -> Node3D:
	match model:
		"shotgun":
			return _shotgun()
		"pistol":
			return _pistol()
		_:
			return _rifle()


# --- Fusil (inspirado en un fusil de batalla clásico) ---------------------------

static func _rifle() -> Node3D:
	var root := Node3D.new()
	root.name = "Rifle"
	var metal := _mat("metal")
	var poly := _mat("polymer")
	_box(root, "Receiver", Vector3(0.05, 0.07, 0.32), Vector3(0, 0, -0.10), metal)
	_box(root, "Rail", Vector3(0.026, 0.012, 0.2), Vector3(0, 0.041, -0.09), metal)
	_cyl(root, "Barrel", 0.011, 0.44, Vector3(0, 0.012, -0.48), metal)
	_cyl(root, "FlashHider", 0.016, 0.06, Vector3(0, 0.012, -0.72), metal)
	_box(root, "FrontPost", Vector3(0.006, 0.05, 0.012), Vector3(0, 0.04, -0.62), metal)
	_box(root, "Handguard", Vector3(0.056, 0.062, 0.25), Vector3(0, -0.004, -0.38), poly)
	_box(root, "Grip", Vector3(0.034, 0.11, 0.046), Vector3(0, -0.075, 0.03), poly, Vector3(deg_to_rad(15), 0, 0))
	_box(root, "Stock", Vector3(0.044, 0.075, 0.24), Vector3(0, -0.018, 0.18), poly)
	_box(root, "Butt", Vector3(0.046, 0.13, 0.03), Vector3(0, -0.04, 0.31), poly)
	_box(root, "TriggerGuard", Vector3(0.008, 0.012, 0.06), Vector3(0, -0.045, -0.02), metal)

	var mag := _group(root, "Mag", Vector3(0, -0.035, -0.07))
	_box(mag, "MagBody", Vector3(0.03, 0.14, 0.072), Vector3(0, -0.065, 0), metal, Vector3(deg_to_rad(-8), 0, 0))
	var charging := _group(root, "Charging", Vector3(-0.031, 0.018, -0.17))
	_box(charging, "Handle", Vector3(0.02, 0.012, 0.016), Vector3(-0.008, 0, 0), metal)

	# Mira red dot: base, tubo (dos anillos) y lente con punto proyectado
	var sight_y := 0.074
	var sight_z := -0.085
	_box(root, "DotBase", Vector3(0.03, 0.016, 0.07), Vector3(0, 0.054, -0.07), metal)
	_torus(root, "DotRingRear", Vector3(0, sight_y, -0.045), metal)
	_torus(root, "DotRingFront", Vector3(0, sight_y, -0.098), metal)
	_box(root, "DotTop", Vector3(0.012, 0.006, 0.055), Vector3(0, sight_y + 0.021, -0.07), metal)
	var lens := MeshInstance3D.new()
	lens.name = "Lens"
	var q := QuadMesh.new()
	q.size = Vector2(0.032, 0.032)
	lens.mesh = q
	var lm := ShaderMaterial.new()
	lm.shader = RED_DOT_SHADER
	lens.material_override = lm
	lens.position = Vector3(0, sight_y, sight_z)
	lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(lens)

	_marker(root, "Sight", Vector3(0, sight_y, sight_z))
	_marker(root, "Muzzle", Vector3(0, 0.012, -0.76))
	_marker(root, "Ejection", Vector3(0.03, 0.02, -0.07))
	_hand(root, "HandR", Vector3(0.0, -0.065, 0.05), Vector3(0.05, 0.07, 0.1))
	_hand(root, "HandL", Vector3(0.0, -0.05, -0.40), Vector3(0.066, 0.05, 0.11))
	return root


# --- Escopeta de dos caños yuxtapuestos ---------------------------------------

static func _shotgun() -> Node3D:
	var root := Node3D.new()
	root.name = "Shotgun"
	var metal := _mat("metal")
	var wood := _mat("wood")
	_box(root, "Receiver", Vector3(0.046, 0.05, 0.09), Vector3(0, -0.013, -0.075), metal)
	_box(root, "Wrist", Vector3(0.036, 0.045, 0.17), Vector3(0, -0.05, 0.05), wood, Vector3(deg_to_rad(16), 0, 0))
	_box(root, "Stock", Vector3(0.042, 0.1, 0.2), Vector3(0, -0.1, 0.21), wood, Vector3(deg_to_rad(8), 0, 0))
	_box(root, "TriggerGuard", Vector3(0.008, 0.012, 0.06), Vector3(0, -0.04, -0.02), metal)
	_box(root, "TopLever", Vector3(0.012, 0.006, 0.03), Vector3(0, 0.015, -0.035), metal)

	# Los caños rotan sobre la bisagra para quebrar el arma al recargar
	var barrels := _group(root, "Barrels", Vector3(0, 0.0, -0.12))
	for side: float in [-1.0, 1.0]:
		_cyl(barrels, "Barrel%s" % ("L" if side < 0 else "R"), 0.0118, 0.62, Vector3(side * 0.0125, 0, -0.31), metal)
		var shell := _group(barrels, "Shell%s" % ("L" if side < 0 else "R"), Vector3(side * 0.0125, 0, 0.025))
		_cyl(shell, "Hull", 0.0105, 0.05, Vector3(0, 0, -0.01), _mat("shell_red"))
		_cyl(shell, "Base", 0.0112, 0.012, Vector3(0, 0, 0.02), _mat("brass"))
		shell.visible = false
	_box(barrels, "Rib", Vector3(0.009, 0.007, 0.6), Vector3(0, 0.0135, -0.31), metal)
	_box(barrels, "Forend", Vector3(0.05, 0.034, 0.2), Vector3(0, -0.026, -0.2), wood)
	_sphere(barrels, "Bead", 0.0032, Vector3(0, 0.0185, -0.605), _mat("brass"))

	_marker(root, "Sight", Vector3(0, 0.0215, -0.725))
	_marker(root, "Muzzle", Vector3(0, 0.0, -0.75))
	_marker(root, "Ejection", Vector3(0, 0.0, -0.11))
	_hand(root, "HandR", Vector3(0.0, -0.05, 0.05), Vector3(0.05, 0.07, 0.1))
	_hand(root, "HandL", Vector3(0.0, -0.055, -0.34), Vector3(0.066, 0.05, 0.11))
	return root


# --- Pistola ---------------------------------------------------------------

static func _pistol() -> Node3D:
	var root := Node3D.new()
	root.name = "Pistol"
	var metal := _mat("metal")
	var poly := _mat("polymer")
	_box(root, "Frame", Vector3(0.03, 0.026, 0.165), Vector3(0, -0.006, -0.06), poly)
	_box(root, "Grip", Vector3(0.031, 0.11, 0.047), Vector3(0, -0.062, 0.012), poly, Vector3(deg_to_rad(12), 0, 0))
	_box(root, "TriggerGuard", Vector3(0.008, 0.01, 0.05), Vector3(0, -0.03, -0.035), poly)
	_cyl(root, "BarrelTip", 0.0065, 0.02, Vector3(0, 0.02, -0.152), metal)

	var slide := _group(root, "Slide", Vector3.ZERO)
	_box(slide, "SlideBody", Vector3(0.028, 0.03, 0.19), Vector3(0, 0.022, -0.058), metal)
	_box(slide, "FrontSight", Vector3(0.0045, 0.008, 0.005), Vector3(0, 0.0405, -0.145), metal)
	for side: float in [-1.0, 1.0]:
		_box(slide, "Rear%s" % ("L" if side < 0 else "R"), Vector3(0.0075, 0.008, 0.007), Vector3(side * 0.0066, 0.0405, 0.026), metal)
	_box(slide, "Serrations", Vector3(0.029, 0.02, 0.03), Vector3(0, 0.022, 0.01), _mat("polymer"))

	var mag := _group(root, "Mag", Vector3(0, -0.02, 0.012))
	_box(mag, "MagBody", Vector3(0.024, 0.1, 0.034), Vector3(0, -0.045, 0), metal, Vector3(deg_to_rad(12), 0, 0))

	_marker(root, "Sight", Vector3(0, 0.0445, -0.145))
	_marker(root, "Muzzle", Vector3(0, 0.02, -0.165))
	_marker(root, "Ejection", Vector3(0.016, 0.03, -0.03))
	_hand(root, "HandR", Vector3(0.0, -0.065, 0.025), Vector3(0.052, 0.085, 0.065))
	_hand(root, "HandL", Vector3(-0.022, -0.075, 0.012), Vector3(0.04, 0.075, 0.06))
	return root


# --- Primitivas -------------------------------------------------------------

static func _group(parent: Node3D, n: String, pos: Vector3) -> Node3D:
	var g := Node3D.new()
	g.name = n
	g.position = pos
	parent.add_child(g)
	return g


static func _box(parent: Node3D, n: String, size: Vector3, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	var m := BoxMesh.new()
	m.size = size
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


## Cilindro a lo largo del eje Z.
static func _cyl(parent: Node3D, n: String, radius: float, length: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	var m := CylinderMesh.new()
	m.top_radius = radius
	m.bottom_radius = radius
	m.height = length
	m.radial_segments = 12
	m.rings = 1
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	mi.rotation = Vector3(deg_to_rad(90), 0, 0)
	parent.add_child(mi)
	return mi


static func _torus(parent: Node3D, n: String, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	var m := TorusMesh.new()
	m.inner_radius = 0.0165
	m.outer_radius = 0.022
	m.rings = 16
	m.ring_segments = 8
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	mi.rotation = Vector3(deg_to_rad(90), 0, 0)
	parent.add_child(mi)
	return mi


static func _sphere(parent: Node3D, n: String, radius: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = 8
	m.rings = 4
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


static func _marker(parent: Node3D, n: String, pos: Vector3) -> void:
	var m := Marker3D.new()
	m.name = n
	m.position = pos
	parent.add_child(m)


## Mano de guante simple (placeholder de los brazos). TODO-ASSET: fps_arms
static func _hand(parent: Node3D, n: String, pos: Vector3, size: Vector3) -> void:
	var h := _box(parent, n, size, pos, _mat("glove"))
	# Antebrazo hacia atrás y abajo
	var arm := _box(h, "Forearm", Vector3(size.x * 0.85, size.y * 0.8, 0.3), Vector3(0, -0.04, 0.18), _mat("sleeve"),
		Vector3(deg_to_rad(-18), 0, 0))
	arm.name = "Forearm"


static func _mat(kind: String) -> StandardMaterial3D:
	if _mats.has(kind):
		return _mats[kind]
	var m := StandardMaterial3D.new()
	match kind:
		"metal":
			m.albedo_color = Color(0.13, 0.135, 0.14)
			m.metallic = 0.65
			m.roughness = 0.42
		"polymer":
			m.albedo_color = Color(0.085, 0.085, 0.08)
			m.roughness = 0.75
		"wood":
			m.albedo_color = Color(0.36, 0.21, 0.1)
			m.roughness = 0.55
		"brass":
			m.albedo_color = Color(0.8, 0.6, 0.25)
			m.metallic = 0.9
			m.roughness = 0.3
		"shell_red":
			m.albedo_color = Color(0.55, 0.08, 0.06)
			m.roughness = 0.5
		"glove":
			m.albedo_color = Color(0.16, 0.15, 0.13)
			m.roughness = 0.9
		"sleeve":
			m.albedo_color = Color(0.24, 0.26, 0.19)
			m.roughness = 0.95
	_mats[kind] = m
	return m
