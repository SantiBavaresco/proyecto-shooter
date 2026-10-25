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
##  - Polígono de tiro detrás del spawn (+Z): dianas a 25/50/100/200 m,
##    maniquíes, placa de acero para rebotes y caja de munición

const GridShader := preload("res://world/test_greybox/grid.gdshader")
const Mannequin := preload("res://world/props/mannequin.gd")
const PaperTarget := preload("res://world/props/paper_target.gd")
const AmmoCrate := preload("res://world/props/ammo_crate.gd")
const WeaponTable := preload("res://world/props/weapon_table.gd")

## Polígono: línea de tiro y franja que ocupa (x de 18 a 42).
const RANGE_LINE_Z := 30.0
const RANGE_X_MIN := 18.0
const RANGE_X_MAX := 42.0
const RANGE_END_Z := 260.0

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
		sun.add_to_group("sun")
	_build()


func _build() -> void:
	var geo := Node3D.new()
	geo.name = "Geometry"
	add_child(geo)

	# Piso y perímetro
	_box(geo, Vector3(0, -0.5, -30), Vector3(140, 1, 140), _mat_floor)
	for side: Vector3 in [Vector3(70, 1.5, -30), Vector3(-70, 1.5, -30)]:
		_box(geo, side, Vector3(1, 3, 140), _mat_block)
	_box(geo, Vector3(0, 1.5, -100), Vector3(140, 3, 1), _mat_block)
	# Muro sur con abertura hacia el polígono
	_box(geo, Vector3((-70.0 + RANGE_X_MIN) * 0.5, 1.5, 40), Vector3(RANGE_X_MIN + 70.0, 3, 1), _mat_block)
	_box(geo, Vector3((RANGE_X_MAX + 70.0) * 0.5, 1.5, 40), Vector3(70.0 - RANGE_X_MAX, 3, 1), _mat_block)

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
		_box(geo, pos, Vector3(2, h, 2), _mat_accent if h <= 1.0 else _mat_block, true, "wood" if h <= 1.0 else "concrete")
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
		_box(geo, cbase + Vector3(l.x, CONTAINER_SIZE.y * (l.y + 0.5), l.z), CONTAINER_SIZE, mat, true, "metal")
	_sign(geo, cbase + Vector3(3.5, 7.0, 1.2), tr("greybox.containers"))

	_build_range(geo)
	_build_armory(geo)


## Armería: una mesa por arma del catálogo, en filas detrás de la línea de tiro.
func _build_armory(geo: Node3D) -> void:
	var catalog: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/weapons/catalog.json"))
	var cols := 5
	var x0 := RANGE_X_MIN + 2.6
	var dx := (RANGE_X_MAX - RANGE_X_MIN - 5.2) / float(cols - 1)
	var z0 := RANGE_LINE_Z - 4.5
	for i in catalog.size():
		var t := WeaponTable.new()
		t.name = "Table_%s" % catalog[i]
		t.weapon_path = "res://data/weapons/%s.tres" % catalog[i]
		t.position = Vector3(x0 + (i % cols) * dx, 0, z0 - (i / cols) * 2.8)
		t.rotation = Vector3(0, PI, 0)
		geo.add_child(t)
	_sign(geo, Vector3((RANGE_X_MIN + RANGE_X_MAX) * 0.5, 3.6, z0 - 14.5), tr("greybox.armory"))


## Polígono de tiro, detrás del punto de aparición.
func _build_range(geo: Node3D) -> void:
	var cx := (RANGE_X_MIN + RANGE_X_MAX) * 0.5
	var width := RANGE_X_MAX - RANGE_X_MIN
	var length := RANGE_END_Z - 40.0
	# Piso de tierra apisonada y muros laterales
	var dirt := _grid_material(Color(0.42, 0.36, 0.28))
	_box(geo, Vector3(cx, -0.5, 40.0 + length * 0.5), Vector3(width, 1, length), dirt, true, "dirt")
	for x: float in [RANGE_X_MIN - 0.5, RANGE_X_MAX + 0.5]:
		_box(geo, Vector3(x, 1.5, 40.0 + length * 0.5), Vector3(1, 3, length), _mat_block)
	# Talud de tierra al fondo
	_box(geo, Vector3(cx, 3.0, RANGE_END_Z - 2.0), Vector3(width, 6, 4), dirt, true, "dirt")

	# Línea de tiro, cartel y caja de munición
	_box(geo, Vector3(cx, 0.012, RANGE_LINE_Z), Vector3(width, 0.02, 0.2), _mat_accent, false)
	_sign(geo, Vector3(cx, 4.2, RANGE_LINE_Z - 1.0), tr("greybox.range"))
	_label(geo, Vector3(cx, 0.35, RANGE_LINE_Z - 0.4), tr("greybox.firing_line"), 0.5)
	var crate := AmmoCrate.new()
	crate.name = "AmmoCrate"
	crate.position = Vector3(cx - 2.0, 0, RANGE_LINE_Z - 1.6)
	geo.add_child(crate)

	# Dianas: distancia (m) → tamaño de la cara (m), cada una en su carril
	var targets: Array = [[25.0, 0.6, RANGE_X_MIN + 3.0], [50.0, 0.8, RANGE_X_MIN + 8.0],
		[100.0, 1.2, RANGE_X_MIN + 15.0], [200.0, 1.8, RANGE_X_MIN + 21.0]]
	for t: Array in targets:
		var pt := PaperTarget.new()
		pt.name = "Target%dm" % int(t[0])
		pt.face_size = t[1]
		pt.position = Vector3(t[2], 0, RANGE_LINE_Z + float(t[0]))
		pt.rotation = Vector3(0, PI, 0)
		geo.add_child(pt)
		_label(geo, Vector3(t[2], 0.4, RANGE_LINE_Z + float(t[0]) - 1.0), "%d m" % int(t[0]), 0.8)

	# Maniquíes a 10 y 15 m, y uno a 30 m detrás de un murete
	var dummies: Array = [[Vector3(cx - 5.0, 0, RANGE_LINE_Z + 10.0), "Dummy10m"],
		[Vector3(cx + 5.0, 0, RANGE_LINE_Z + 15.0), "Dummy15m"],
		[Vector3(cx, 0, RANGE_LINE_Z + 30.0), "Dummy30m"]]
	for d: Array in dummies:
		var m := Mannequin.new()
		m.name = d[1]
		m.position = d[0]
		m.rotation = Vector3(0, PI, 0)
		geo.add_child(m)
	_box(geo, Vector3(cx, 0.5, RANGE_LINE_Z + 28.8), Vector3(2.0, 1.0, 0.3), _mat_block)

	# Placa de acero inclinada: los tiros rasantes rebotan
	var plate := StaticBody3D.new()
	plate.name = "SteelPlate"
	plate.set_meta("surface", "metal")
	var pcs := CollisionShape3D.new()
	var psh := BoxShape3D.new()
	psh.size = Vector3(1.4, 1.4, 0.03)
	pcs.shape = psh
	plate.add_child(pcs)
	var pmi := MeshInstance3D.new()
	var pbm := BoxMesh.new()
	pbm.size = psh.size
	pmi.mesh = pbm
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.32, 0.33, 0.35)
	pm.metallic = 0.8
	pm.roughness = 0.35
	pmi.material_override = pm
	plate.add_child(pmi)
	plate.position = Vector3(RANGE_X_MAX - 3.0, 1.0, RANGE_LINE_Z + 12.0)
	plate.rotation = Vector3(0, deg_to_rad(70), 0)
	geo.add_child(plate)
	_sign(geo, Vector3(RANGE_X_MAX - 3.0, 2.6, RANGE_LINE_Z + 12.0), tr("greybox.steel"))


# --- Helpers ----------------------------------------------------------------

func _grid_material(color: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = GridShader
	m.set_shader_parameter("base_color", color)
	m.set_shader_parameter("line_color", color.darkened(0.35))
	m.set_shader_parameter("major_color", color.darkened(0.55))
	return m


func _box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material, with_collision := true,
		surface := "concrete") -> Node3D:
	var root: Node3D
	if with_collision:
		var body := StaticBody3D.new()
		body.set_meta("surface", surface)
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
