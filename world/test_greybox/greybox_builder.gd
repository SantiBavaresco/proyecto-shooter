extends Node3D
## Pista de pruebas de movimiento ("greybox").
## La geometría se arma por código para poder ajustarla rápido y testearla.
##
## Estaciones (el jugador aparece en el origen mirando hacia −Z):
##  - Carril de carrera con marcas cada 10 m (adelante)
##  - Cajas de 0,5 / 1 / 1,5 / 2 m para probar saltos (derecha)
##  - Túnel bajo de 1,3 m: solo se pasa agachado (izquierda)
##  - Rampas de 20°, 40° y 55° (la última no se puede subir)
##  - Escalera (colisión de rampa invisible; subir escalones real llega más adelante)
##  - Plataformas con huecos de 2, 3 y 4 m
##  - Esquina para practicar inclinarse, con postes detrás
##  - Pila de contenedores marítimos (medidas reales de 20 pies)

const GridShader := preload("res://world/test_greybox/grid.gdshader")

## Colores de los contenedores (óxido, azul, verde gastados).
const CONTAINER_COLORS: Array[Color] = [Color("7a3b28"), Color("2f4a63"), Color("3f5a36"), Color("8a6b2a")]
const CONTAINER_SIZE := Vector3(6.06, 2.59, 2.44)

var _mat_floor: ShaderMaterial
var _mat_block: ShaderMaterial
var _mat_accent: ShaderMaterial


func _ready() -> void:
	_mat_floor = _grid_material(Color(0.40, 0.41, 0.38))
	_mat_block = _grid_material(Color(0.55, 0.55, 0.52))
	_mat_accent = _grid_material(Color(0.62, 0.52, 0.30))
	var sun := get_node_or_null("Sun") as DirectionalLight3D
	if sun != null:
		# Sol de tarde, bajo y cálido, adelante a la derecha del spawn
		# (la sombra del cuerpo cae hacia atrás y no tapa la vista).
		sun.rotation_degrees = Vector3(-28.0, 150.0, 0.0)
	_build()


func _build() -> void:
	var geo := Node3D.new()
	geo.name = "Geometry"
	add_child(geo)

	# Piso y perímetro
	_box(geo, Vector3(0, -0.5, -30), Vector3(140, 1, 140), _mat_floor)
	for side: Vector3 in [Vector3(70, 1.5, -30), Vector3(-70, 1.5, -30)]:
		_box(geo, side, Vector3(1, 3, 140), _mat_block)
	for side: Vector3 in [Vector3(0, 1.5, 40), Vector3(0, 1.5, -100)]:
		_box(geo, side, Vector3(140, 3, 1), _mat_block)

	# Carril de carrera con marcas cada 10 m
	for i in range(1, 7):
		var z := -10.0 * i
		_box(geo, Vector3(-2.5, 0.01, z), Vector3(5, 0.02, 0.15), _mat_accent, false)
		_label(geo, Vector3(-2.5, 0.4, z), "%d m" % (i * 10), 0.6)
	_sign(geo, Vector3(-2.5, 3.4, -3), tr("greybox.sprint_lane"))

	# Cajas de salto
	var heights: Array[float] = [0.5, 1.0, 1.5, 2.0]
	for i in heights.size():
		var h := heights[i]
		var pos := Vector3(8 + i * 3.0, h * 0.5, -8)
		_box(geo, pos, Vector3(2, h, 2), _mat_accent if h <= 1.0 else _mat_block)
		_label(geo, Vector3(pos.x, h + 0.35, pos.z + 1.05), "%.1f m" % h, 0.5)
	_sign(geo, Vector3(12.5, 3.3, -8), tr("greybox.jump_boxes"))

	# Túnel bajo (solo agachado)
	var tunnel_x := -10.0
	var tunnel_len := 8.0
	var tunnel_h := 1.3
	_box(geo, Vector3(tunnel_x - 1.1, tunnel_h * 0.5, -8), Vector3(0.4, tunnel_h, tunnel_len), _mat_block)
	_box(geo, Vector3(tunnel_x + 1.1, tunnel_h * 0.5, -8), Vector3(0.4, tunnel_h, tunnel_len), _mat_block)
	_box(geo, Vector3(tunnel_x, tunnel_h + 0.25, -8), Vector3(2.6, 0.5, tunnel_len), _mat_accent)
	_sign(geo, Vector3(tunnel_x, 2.1, -3.6), tr("greybox.crouch_tunnel"))

	# Rampas
	var angles: Array[float] = [20.0, 40.0, 55.0]
	for i in angles.size():
		_ramp(geo, Vector3(14 + i * 6.0, 0, -22), angles[i], 8.0, 4.0)
		_label(geo, Vector3(14 + i * 6.0, 0.4, -17.5), "%d°" % int(angles[i]), 0.6)
	_sign(geo, Vector3(20, 3.0, -17), tr("greybox.ramps"))

	# Escalera: escalones visuales + rampa invisible para colisión
	var steps := 10
	var step_h := 0.2
	var step_d := 0.3
	var stair_origin := Vector3(34, 0, -18)
	for s in steps:
		var top := step_h * (s + 1)
		_box(geo, stair_origin + Vector3(0, top * 0.5, -step_d * s - step_d * 0.5),
			Vector3(3, top, step_d), _mat_block, false)
	var stair_len := steps * step_d
	var stair_h := steps * step_h
	var slope_len := sqrt(stair_len * stair_len + stair_h * stair_h)
	var slope_ang := atan2(stair_h, stair_len)
	var col := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(3, 0.1, slope_len)
	shape.shape = bs
	col.add_child(shape)
	col.position = stair_origin + Vector3(0, stair_h * 0.5, -stair_len * 0.5)
	col.rotation = Vector3(slope_ang, 0, 0)
	geo.add_child(col)
	_box(geo, stair_origin + Vector3(0, stair_h * 0.5, -stair_len - 2.0), Vector3(3, stair_h, 4), _mat_block)
	_sign(geo, stair_origin + Vector3(0, 2.6, 1.0), tr("greybox.stairs"))

	# Plataformas con huecos
	var px := -24.0
	var pz := -14.0
	var gaps: Array[float] = [2.0, 3.0, 4.0]
	var plat_len := 3.0
	_box(geo, Vector3(px, 0.25, pz), Vector3(3, 0.5, plat_len), _mat_block)
	for g in gaps:
		pz -= plat_len + g
		_box(geo, Vector3(px, 0.25, pz), Vector3(3, 0.5, plat_len), _mat_accent)
		_label(geo, Vector3(px + 1.6, 0.9, pz + plat_len * 0.5 + g * 0.5), "%d m" % int(g), 0.5)
	_sign(geo, Vector3(px, 2.6, -11), tr("greybox.gaps"))

	# Esquina para inclinarse, con postes detrás
	_box(geo, Vector3(4, 1.5, -40), Vector3(0.5, 3, 8), _mat_block)
	_box(geo, Vector3(1.0, 1.5, -36.25), Vector3(6.5, 3, 0.5), _mat_block)
	for i in 4:
		_box(geo, Vector3(8 + i * 2.0, 1.0, -44 - i * 1.5), Vector3(0.3, 2, 0.3), _mat_accent)
	_sign(geo, Vector3(1.0, 3.6, -36), tr("greybox.lean_corner"))

	# Contenedores apilados
	var cbase := Vector3(-22, 0, -42)
	var layout: Array[Vector3] = [
		Vector3(0, 0, 0), Vector3(0, 0, 2.5), Vector3(0, 1, 0), Vector3(7, 0, 0),
		Vector3(7, 0, 2.5), Vector3(7, 1, 2.5), Vector3(3.5, 0, 6.5),
	]
	for i in layout.size():
		var l := layout[i]
		var mat := StandardMaterial3D.new()
		mat.albedo_color = CONTAINER_COLORS[i % CONTAINER_COLORS.size()]
		mat.roughness = 0.75
		_box(geo, cbase + Vector3(l.x, CONTAINER_SIZE.y * (l.y + 0.5), l.z), CONTAINER_SIZE, mat)
	_sign(geo, cbase + Vector3(3.5, 7.0, 1.2), tr("greybox.containers"))


# --- Helpers ----------------------------------------------------------------

func _grid_material(color: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = GridShader
	m.set_shader_parameter("base_color", color)
	m.set_shader_parameter("line_color", color.darkened(0.35))
	m.set_shader_parameter("major_color", color.darkened(0.55))
	return m


func _box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material, with_collision := true) -> Node3D:
	var root: Node3D
	if with_collision:
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		cs.shape = shape
		body.add_child(cs)
		root = body
	else:
		root = Node3D.new()
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	root.add_child(mi)
	root.position = pos
	parent.add_child(root)
	return root


## Rampa: caja inclinada cuyo borde bajo apoya en el piso.
func _ramp(parent: Node3D, base: Vector3, angle_deg: float, length: float, width: float) -> void:
	var a := deg_to_rad(angle_deg)
	var thick := 0.4
	var body := _box(parent, Vector3.ZERO, Vector3(width, thick, length), _mat_block)
	# Centro de la losa para que el borde inferior quede en base y suba hacia −Z.
	var half := length * 0.5
	body.position = base + Vector3(0, sin(a) * half - cos(a) * thick * 0.5, -cos(a) * half)
	body.rotation = Vector3(a, 0, 0)


func _label(parent: Node3D, pos: Vector3, text: String, px_size: float) -> void:
	var l := Label3D.new()
	l.text = text
	l.position = pos
	l.pixel_size = px_size * 0.01
	l.font_size = 48
	l.outline_size = 8
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.modulate = Color(0.95, 0.93, 0.85)
	parent.add_child(l)


func _sign(parent: Node3D, pos: Vector3, text: String) -> void:
	var l := Label3D.new()
	l.text = text
	l.position = pos
	l.pixel_size = 0.009
	l.font_size = 64
	l.outline_size = 10
	l.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	l.modulate = Color(0.79, 0.64, 0.15)
	parent.add_child(l)
