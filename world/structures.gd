class_name Structures
extends RefCounted
## Construcciones hechas por código para los niveles: paredes con puertas y ventanas,
## edificios, contenedores, bolsas de arena, alambrados, torres, carpas, fogones,
## tambores, autos abandonados, bloques de hormigón y vegetación.
## TODO-ASSET: reemplazar por modelos reales (ver docs/ASSETS.md).
##
## Todo lo que tiene colisión es un StaticBody3D en la capa 1 con metadata "surface"
## (para los pasos y los impactos). La vegetación que tapa la vista sin frenar balas
## ni gente va en la capa 9 (follaje).

const FOLIAGE_LAYER := 9
const WALL := 0.25

static var _mats: Dictionary = {}
static var _noise_tex: NoiseTexture2D


## Material con un poco de ruido (que no se vea liso), proyectado en el mundo.
static func mat(name: String) -> StandardMaterial3D:
	if _mats.has(name):
		return _mats[name]
	var col: Color = {
		"concrete": Color(0.58, 0.57, 0.54), "concrete_dark": Color(0.42, 0.41, 0.39), "brick": Color(0.55, 0.32, 0.24),
		"plaster": Color(0.72, 0.68, 0.6), "metal": Color(0.5, 0.52, 0.53), "rust": Color(0.45, 0.27, 0.17),
		"wood": Color(0.42, 0.31, 0.2), "wood_old": Color(0.36, 0.32, 0.27), "sandbag": Color(0.6, 0.53, 0.38),
		"tarp": Color(0.3, 0.36, 0.26), "tarp_blue": Color(0.2, 0.32, 0.45), "roof": Color(0.4, 0.42, 0.43),
		"dark": Color(0.12, 0.12, 0.12), "asphalt": Color(0.22, 0.22, 0.22), "trunk": Color(0.3, 0.24, 0.18),
		"leaves": Color(0.16, 0.24, 0.09), "leaves_dark": Color(0.11, 0.18, 0.08), "leaves_dry": Color(0.26, 0.29, 0.12), "car_red": Color(0.45, 0.14, 0.11),
		"car_white": Color(0.7, 0.7, 0.66), "car_green": Color(0.24, 0.32, 0.25), "yellow": Color(0.75, 0.62, 0.15),
		"glass": Color(0.15, 0.2, 0.22),
	}.get(name, Color(0.5, 0.5, 0.5))
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.9 if not name in ["metal", "glass"] else 0.55
	m.metallic = 0.45 if name in ["metal", "rust", "roof"] else 0.0
	if not name in ["dark", "glass", "leaves", "leaves_dark", "leaves_dry"]:
		m.albedo_texture = _noise()
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3.ONE * (0.35 if name != "sandbag" else 1.2)
	if name in ["leaves", "leaves_dark", "leaves_dry"]:
		m.albedo_texture = _noise()
		m.uv1_triplanar = true
		m.uv1_scale = Vector3.ONE * 2.0
	_mats[name] = m
	return m


static func _noise() -> NoiseTexture2D:
	if _noise_tex == null:
		var n := FastNoiseLite.new()
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n.frequency = 0.035
		n.fractal_octaves = 4
		_noise_tex = NoiseTexture2D.new()
		_noise_tex.width = 256
		_noise_tex.height = 256
		_noise_tex.seamless = true
		_noise_tex.noise = n
		var g := Gradient.new()
		g.set_color(0, Color(0.72, 0.72, 0.72))
		g.set_color(1, Color(1.08, 1.08, 1.08))
		_noise_tex.color_ramp = g
	return _noise_tex


# --- Piezas básicas ---------------------------------------------------------------

## Caja con colisión. Devuelve el cuerpo (o la malla, sin colisión).
static func box(parent: Node3D, pos: Vector3, size: Vector3, m: Material, collide := true, surface := "concrete",
		rot := Vector3.ZERO) -> Node3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	if not collide:
		mi.position = pos
		mi.rotation = rot
		parent.add_child(mi)
		return mi
	var b := StaticBody3D.new()
	b.position = pos
	b.rotation = rot
	b.set_meta("surface", surface)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	b.add_child(cs)
	b.add_child(mi)
	parent.add_child(b)
	return b


static func cyl(parent: Node3D, pos: Vector3, r: float, h: float, m: Material, collide := true, surface := "metal",
		rot := Vector3.ZERO, segs := 16) -> Node3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = segs
	mi.mesh = cm
	mi.material_override = m
	if not collide:
		mi.position = pos
		mi.rotation = rot
		parent.add_child(mi)
		return mi
	var b := StaticBody3D.new()
	b.position = pos
	b.rotation = rot
	b.set_meta("surface", surface)
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = r
	sh.height = h
	cs.shape = sh
	b.add_child(cs)
	b.add_child(mi)
	parent.add_child(b)
	return b


## Pared de largo `length` a lo largo de X local, con huecos. holes: [[centro x,
## ancho, alto desde el piso hasta arriba del hueco, alto del alféizar]] (puerta:
## alféizar 0).
static func wall(parent: Node3D, xf: Transform3D, length: float, height: float, holes: Array, m: Material,
		surface := "concrete", thick := WALL) -> void:
	var node := Node3D.new()
	node.transform = xf
	parent.add_child(node)
	holes.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var x := -length * 0.5
	for h: Array in holes:
		var hx := float(h[0])
		var hw := float(h[1])
		var top := float(h[2])
		var sill := float(h[3])
		var x0 := hx - hw * 0.5
		if x0 - x > 0.01:
			box(node, Vector3((x + x0) * 0.5, height * 0.5, 0), Vector3(x0 - x, height, thick), m, true, surface)
		# Arriba del hueco (dintel) y abajo (antepecho)
		if height - top > 0.01:
			box(node, Vector3(hx, (top + height) * 0.5, 0), Vector3(hw, height - top, thick), m, true, surface)
		if sill > 0.01:
			box(node, Vector3(hx, sill * 0.5, 0), Vector3(hw, sill, thick), m, true, surface)
		x = hx + hw * 0.5
	if length * 0.5 - x > 0.01:
		box(node, Vector3((x + length * 0.5) * 0.5, height * 0.5, 0), Vector3(length * 0.5 - x, height, thick), m, true, surface)


## Edificio rectangular: cuatro paredes con aberturas, piso y techo. openings: por
## lado ("n", "s", "e", "o"): [[centro, ancho, alto, alféizar], ...] (centro medido
## desde el centro de la pared). roof: "flat", "shed" (una caída) o "none" (en ruinas).
static func building(parent: Node3D, pos: Vector3, size: Vector3, yaw: float, openings: Dictionary, wall_mat: Material,
		roof := "flat", roof_mat: Material = null, light := true) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	root.rotation = Vector3(0, yaw, 0)
	parent.add_child(root)
	var w := size.x
	var d := size.z
	var h := size.y
	var surf := "concrete"
	# Piso
	box(root, Vector3(0, 0.05, 0), Vector3(w, 0.1, d), mat("concrete_dark"), true, "concrete")
	# Paredes: norte (−Z), sur (+Z), este (+X), oeste (−X)
	wall(root, Transform3D(Basis(), Vector3(0, 0, -d * 0.5 + WALL * 0.5)), w, h, openings.get("n", []).duplicate(true), wall_mat, surf)
	wall(root, Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, d * 0.5 - WALL * 0.5)), w, h, openings.get("s", []).duplicate(true), wall_mat, surf)
	wall(root, Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(w * 0.5 - WALL * 0.5, 0, 0)), d - WALL * 2.0, h,
		openings.get("e", []).duplicate(true), wall_mat, surf)
	wall(root, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(-w * 0.5 + WALL * 0.5, 0, 0)), d - WALL * 2.0, h,
		openings.get("o", []).duplicate(true), wall_mat, surf)
	var rm := roof_mat if roof_mat != null else mat("concrete")
	match roof:
		"flat":
			box(root, Vector3(0, h + 0.1, 0), Vector3(w + 0.3, 0.2, d + 0.3), rm, true, "concrete")
		"shed":
			var ang := atan2(1.0, d)
			box(root, Vector3(0, h + 0.55, 0), Vector3(w + 0.5, 0.08, d / cos(ang) + 0.5), rm, true, "metal", Vector3(ang, 0, 0))
			# Cierre de los triángulos de los costados
			for sx: float in [-1.0, 1.0]:
				box(root, Vector3(sx * (w * 0.5 - WALL * 0.5), h + 0.5, 0), Vector3(WALL, 1.0, d), wall_mat, true, surf)
	if light and roof != "none":
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.85, 0.65)
		l.light_energy = 0.6
		l.omni_range = maxf(w, d) * 0.8
		l.position = Vector3(0, h - 0.5, 0)
		l.shadow_enabled = false
		root.add_child(l)
	return root


## Contenedor marítimo de 20 pies (abierto en una punta si open_end).
static func container(parent: Node3D, pos: Vector3, yaw: float, color: Color, open_end := false) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.75
	m.metallic = 0.3
	m.albedo_texture = _noise()
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * 0.5
	var size := Vector3(6.06, 2.59, 2.44)
	if not open_end:
		box(parent, pos + Vector3(0, size.y * 0.5, 0), size, m, true, "metal", Vector3(0, yaw, 0))
		# Nervaduras
		var root := Node3D.new()
		root.position = pos
		root.rotation = Vector3(0, yaw, 0)
		parent.add_child(root)
		for i in 9:
			for s: float in [-1.0, 1.0]:
				box(root, Vector3(-2.7 + i * 0.67, size.y * 0.5, s * (size.z * 0.5 + 0.02)), Vector3(0.1, size.y - 0.2, 0.04), m, false)
		return
	var r := Node3D.new()
	r.position = pos
	r.rotation = Vector3(0, yaw, 0)
	parent.add_child(r)
	box(r, Vector3(0, 0.05, 0), Vector3(size.x, 0.1, size.z), m, true, "metal")
	box(r, Vector3(0, size.y - 0.05, 0), Vector3(size.x, 0.1, size.z), m, true, "metal")
	for s: float in [-1.0, 1.0]:
		box(r, Vector3(0, size.y * 0.5, s * (size.z * 0.5 - 0.05)), Vector3(size.x, size.y, 0.1), m, true, "metal")
	box(r, Vector3(-size.x * 0.5 + 0.05, size.y * 0.5, 0), Vector3(0.1, size.y, size.z), m, true, "metal")
	# Puerta abierta
	box(r, Vector3(size.x * 0.5 + 0.55, size.y * 0.5, size.z * 0.5 + 0.55), Vector3(0.08, size.y - 0.1, size.z * 0.5),
		m, true, "metal", Vector3(0, -1.2, 0))


## Pared de bolsas de arena (en forma de U si u_shape).
static func sandbags(parent: Node3D, pos: Vector3, yaw: float, length: float, height := 1.1, u_shape := false) -> void:
	var r := Node3D.new()
	r.position = pos
	r.rotation = Vector3(0, yaw, 0)
	parent.add_child(r)
	var m := mat("sandbag")
	_bag_row(r, Vector3.ZERO, length, height, m)
	if u_shape:
		for s: float in [-1.0, 1.0]:
			var side := Node3D.new()
			side.position = Vector3(s * length * 0.5, 0, 0.9)
			side.rotation = Vector3(0, PI * 0.5, 0)
			r.add_child(side)
			_bag_row(side, Vector3.ZERO, 1.8, height, m)


static func _bag_row(parent: Node3D, pos: Vector3, length: float, height: float, m: Material) -> void:
	box(parent, pos + Vector3(0, height * 0.5, 0), Vector3(length, height, 0.55), m, true, "dirt")
	# Bolsas a la vista (bultos redondeados por fila)
	var rows := int(height / 0.18)
	for row in rows:
		var n := int(length / 0.55)
		for i in n:
			var mi := MeshInstance3D.new()
			var cm := CapsuleMesh.new()
			cm.radius = 0.13
			cm.height = 0.6
			cm.radial_segments = 8
			cm.rings = 2
			mi.mesh = cm
			mi.material_override = m
			mi.rotation = Vector3(0, 0, PI * 0.5)
			mi.scale = Vector3(0.75, 1.0, 1.15)
			mi.position = pos + Vector3(-length * 0.5 + (i + 0.5 + (0.5 if row % 2 == 1 else 0.0)) * (length / n) * (1.0 if i < n - 1 or row % 2 == 0 else 0.0),
				0.09 + row * 0.18, 0)
			if row % 2 == 1 and i == n - 1:
				continue
			parent.add_child(mi)


## Alambrado: postes y tejido (el tejido tapa el paso pero no la vista ni las balas).
static func fence(parent: Node3D, a: Vector3, b: Vector3, height := 2.4, gaps: Array = []) -> void:
	var d := b - a
	var length := Vector3(d.x, 0, d.z).length()
	var yaw := atan2(-d.z, d.x)
	var r := Node3D.new()
	r.position = a
	r.rotation = Vector3(0, yaw, 0)
	parent.add_child(r)
	var post := mat("metal")
	var n := int(length / 3.0)
	for i in n + 1:
		cyl(r, Vector3(i * length / maxf(n, 1), height * 0.5, 0), 0.04, height, post, false)
	var mesh_mat := StandardMaterial3D.new()
	mesh_mat.albedo_color = Color(0.45, 0.47, 0.47, 0.45)
	mesh_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_mat.metallic = 0.6
	var segs: Array = [[0.0, length]]
	for g: Array in gaps:
		var out: Array = []
		for sg: Array in segs:
			var g0 := float(g[0]) - float(g[1]) * 0.5
			var g1 := float(g[0]) + float(g[1]) * 0.5
			if g1 <= float(sg[0]) or g0 >= float(sg[1]):
				out.append(sg)
			else:
				if g0 > float(sg[0]):
					out.append([sg[0], g0])
				if g1 < float(sg[1]):
					out.append([g1, sg[1]])
		segs = out
	for sg: Array in segs:
		var l := float(sg[1]) - float(sg[0])
		if l < 0.2:
			continue
		var c := (float(sg[0]) + float(sg[1])) * 0.5
		# Colisión fina en la capa del mundo (frena gente; las balas igual pasan porque
		# el tejido es "malla": se marca para que no la cuenten como cobertura)
		var bdy := StaticBody3D.new()
		bdy.position = Vector3(c, height * 0.5, 0)
		bdy.collision_layer = 1 << 9  # capa 10: solo movimiento (ni balas ni vista)
		bdy.collision_mask = 0
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3(l, height, 0.08)
		cs.shape = sh
		bdy.add_child(cs)
		r.add_child(bdy)
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(l, height - 0.1)
		q.mesh = qm
		q.material_override = mesh_mat
		q.position = Vector3(c, height * 0.5, 0)
		r.add_child(q)
		# Alambre de púas arriba
		cyl(r, Vector3(c, height + 0.05, 0), 0.012, l, post, false, "metal", Vector3(0, 0, PI * 0.5), 6)


## Torre de vigilancia de madera: cuatro patas, plataforma a `h` m con baranda y techo.
## Se sube por una rampa. Devuelve la posición de la plataforma.
static func watchtower(parent: Node3D, pos: Vector3, yaw: float, h := 4.5) -> Vector3:
	var r := Node3D.new()
	r.position = pos
	r.rotation = Vector3(0, yaw, 0)
	parent.add_child(r)
	var wd := mat("wood")
	for sx: float in [-1.4, 1.4]:
		for sz: float in [-1.4, 1.4]:
			box(r, Vector3(sx, h * 0.5, sz), Vector3(0.22, h, 0.22), wd, true, "wood")
	box(r, Vector3(0, h, 0), Vector3(3.4, 0.15, 3.4), wd, true, "wood")
	for s: float in [-1.0, 1.0]:
		box(r, Vector3(s * 1.65, h + 0.55, 0), Vector3(0.1, 1.0, 3.4), wd, true, "wood")
		box(r, Vector3(0, h + 0.55, s * 1.65), Vector3(3.4, 1.0, 0.1), wd, true, "wood")
	for sx: float in [-1.6, 1.6]:
		for sz: float in [-1.6, 1.6]:
			box(r, Vector3(sx, h + 1.4, sz), Vector3(0.12, 1.8, 0.12), wd, false)
	box(r, Vector3(0, h + 2.35, 0), Vector3(4.0, 0.1, 4.0), mat("roof"), true, "metal")
	# Escalera (rampa con escalones a la vista)
	var len := h / sin(deg_to_rad(40.0))
	var ramp := Node3D.new()
	ramp.position = Vector3(0, h * 0.5, 1.7 + cos(deg_to_rad(40.0)) * len * 0.5)
	ramp.rotation = Vector3(deg_to_rad(40.0), 0, 0)
	r.add_child(ramp)
	box(ramp, Vector3.ZERO, Vector3(0.9, 0.08, len), wd, true, "wood")
	for i in int(len / 0.3):
		box(ramp, Vector3(0, 0.06, -len * 0.5 + i * 0.3 + 0.15), Vector3(0.9, 0.05, 0.08), wd, false)
	return r.global_transform * Vector3(0, h + 0.1, 0) if r.is_inside_tree() else pos + Vector3(0, h + 0.1, 0)


## Carpa de lona (dos aguas).
static func tent(parent: Node3D, pos: Vector3, yaw: float, size := Vector3(3.0, 2.0, 4.0), m: Material = null) -> void:
	var r := Node3D.new()
	r.position = pos
	r.rotation = Vector3(0, yaw, 0)
	parent.add_child(r)
	var tm := (m if m != null else mat("tarp")).duplicate() as StandardMaterial3D
	tm.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = size
	mi.mesh = pm
	mi.material_override = tm
	mi.position = Vector3(0, size.y * 0.5, 0)
	r.add_child(mi)
	# Palos y cumbrera, vientos
	for sz: float in [-1.0, 1.0]:
		cyl(r, Vector3(0, size.y * 0.5, sz * (size.z * 0.5 + 0.05)), 0.03, size.y, mat("wood"), false, "wood", Vector3.ZERO, 6)
	cyl(r, Vector3(0, size.y + 0.02, 0), 0.025, size.z + 0.3, mat("wood"), false, "wood", Vector3(PI * 0.5, 0, 0), 6)
	var b := StaticBody3D.new()
	b.set_meta("surface", "dirt")
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(size.x * 0.7, size.y * 0.8, size.z)
	cs.shape = sh
	cs.position = Vector3(0, size.y * 0.4, 0)
	b.add_child(cs)
	r.add_child(b)


## Fogón con troncos, brasas, luz que titila y humito.
static func campfire(parent: Node3D, pos: Vector3) -> void:
	var r := Node3D.new()
	r.position = pos
	parent.add_child(r)
	for i in 6:
		var a := TAU * i / 6.0
		cyl(r, Vector3(cos(a) * 0.45, 0.08, sin(a) * 0.45), 0.09, 0.2, mat("concrete_dark"), false, "concrete", Vector3.ZERO, 8)
	for i in 4:
		var a := TAU * i / 4.0 + 0.4
		cyl(r, Vector3(cos(a) * 0.12, 0.12, sin(a) * 0.12), 0.05, 0.6, mat("trunk"), false, "wood", Vector3(0.5, a, 1.2), 8)
	var ember := StandardMaterial3D.new()
	ember.albedo_color = Color(1.0, 0.45, 0.1)
	ember.emission_enabled = true
	ember.emission = Color(1.0, 0.4, 0.08)
	ember.emission_energy_multiplier = 2.5
	cyl(r, Vector3(0, 0.05, 0), 0.25, 0.06, ember, false, "", Vector3.ZERO, 10)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.6, 0.3)
	l.light_energy = 1.6
	l.omni_range = 9.0
	l.position = Vector3(0, 0.6, 0)
	l.set_script(load("res://world/props/flicker_light.gd"))
	r.add_child(l)
	var smoke := CPUParticles3D.new()
	smoke.amount = 14
	smoke.lifetime = 4.0
	smoke.direction = Vector3.UP
	smoke.spread = 12.0
	smoke.initial_velocity_min = 0.4
	smoke.initial_velocity_max = 0.8
	smoke.gravity = Vector3(0.15, 0.25, 0)
	smoke.scale_amount_min = 0.6
	smoke.scale_amount_max = 1.6
	var sm := SphereMesh.new()
	sm.radius = 0.3
	sm.height = 0.6
	sm.radial_segments = 6
	sm.rings = 3
	var smm := StandardMaterial3D.new()
	smm.albedo_color = Color(0.5, 0.5, 0.5, 0.25)
	smm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.material = smm
	smoke.mesh = sm
	smoke.position = Vector3(0, 0.4, 0)
	r.add_child(smoke)


static func barrel(parent: Node3D, pos: Vector3, rusty := true) -> void:
	cyl(parent, pos + Vector3(0, 0.45, 0), 0.29, 0.9, mat("rust" if rusty else "metal"), true, "metal", Vector3.ZERO, 14)


## Auto abandonado (carrocería, cabina y ruedas), como cobertura.
static func car_wreck(parent: Node3D, pos: Vector3, yaw: float, color := "car_white") -> void:
	var r := Node3D.new()
	r.position = pos
	r.rotation = Vector3(0, yaw, 0)
	parent.add_child(r)
	var m := mat(color)
	box(r, Vector3(0, 0.7, 0), Vector3(1.75, 0.75, 4.2), m, true, "metal")
	box(r, Vector3(0, 1.3, 0.2), Vector3(1.6, 0.6, 2.1), m, true, "metal")
	box(r, Vector3(0, 1.3, -0.86), Vector3(1.5, 0.5, 0.05), mat("glass"), false, "", Vector3(0.5, 0, 0))
	for sx: float in [-0.85, 0.85]:
		for sz: float in [-1.35, 1.35]:
			cyl(r, Vector3(sx, 0.32, sz), 0.32, 0.22, mat("dark"), false, "metal", Vector3(0, 0, PI * 0.5), 12)


## Bloque de hormigón tipo New Jersey.
static func jersey(parent: Node3D, pos: Vector3, yaw: float) -> void:
	var r := Node3D.new()
	r.position = pos
	r.rotation = Vector3(0, yaw, 0)
	parent.add_child(r)
	box(r, Vector3(0, 0.25, 0), Vector3(3.0, 0.5, 0.6), mat("concrete"), true, "concrete")
	box(r, Vector3(0, 0.62, 0), Vector3(3.0, 0.25, 0.35), mat("concrete"), true, "concrete")
	box(r, Vector3(0, 0.88, 0), Vector3(3.0, 0.3, 0.22), mat("concrete"), true, "concrete")


## Pila de cajones de madera (decoración y cobertura).
static func crates(parent: Node3D, pos: Vector3, yaw: float, n := 3) -> void:
	var r := Node3D.new()
	r.position = pos
	r.rotation = Vector3(0, yaw, 0)
	parent.add_child(r)
	for i in n:
		var x := (i % 2) * 1.05 - 0.5
		var y := float(i / 2) * 0.9
		box(r, Vector3(x, y + 0.45, 0), Vector3(0.95, 0.9, 0.95), mat("wood"), true, "wood", Vector3(0, (i % 3) * 0.1, 0))


## Arboles y arbustos con MultiMesh (una llamada de dibujo por pieza). trees: lista de
## [posición, altura, tipo] (0 sauce: copa ancha y caída; 1 eucalipto: alto y angosto;
## 2 ceibo: chico y tupido). Los troncos frenan todo; las copas y los arbustos solo
## tapan la vista (capa de follaje).
static func vegetation(parent: Node3D, trees: Array, bushes: Array, seed_v := 1) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var trunk_mm := _mm(_cyl_mesh(0.18, 1.0, 7), trees.size())
	var crowns_a: Array[Transform3D] = []
	var crowns_b: Array[Transform3D] = []
	var solid := StaticBody3D.new()
	solid.name = "TreeTrunks"
	solid.set_meta("surface", "wood")
	parent.add_child(solid)
	var foliage := StaticBody3D.new()
	foliage.name = "Foliage"
	foliage.collision_layer = 1 << (FOLIAGE_LAYER - 1)
	foliage.collision_mask = 0
	parent.add_child(foliage)
	for i in trees.size():
		var t: Array = trees[i]
		var p: Vector3 = t[0]
		var h := float(t[1])
		var kind := int(t[2])
		var lean := Vector3(rng.randf_range(-0.08, 0.08), 0, rng.randf_range(-0.08, 0.08))
		var th := h * (0.6 if kind == 0 else (0.85 if kind == 1 else 0.5))
		var tw := 1.0 + h * (0.04 if kind != 1 else 0.02)
		var tb := Basis(Vector3(lean.z, 0, -lean.x).normalized() if lean.length() > 0.01 else Vector3.RIGHT, lean.length())
		trunk_mm.set_instance_transform(i, Transform3D(tb * Basis().scaled(Vector3(tw, th, tw)), p + Vector3(0, th * 0.5, 0)))
		var cs := CollisionShape3D.new()
		var sh := CylinderShape3D.new()
		sh.radius = 0.18 * tw + 0.02
		sh.height = th
		cs.shape = sh
		cs.position = p + Vector3(0, th * 0.5, 0)
		solid.add_child(cs)
		var top := p + tb * Vector3(0, th, 0)
		var blobs := 4 if kind == 0 else (3 if kind == 1 else 3)
		var cr := h * (0.3 if kind == 0 else (0.17 if kind == 1 else 0.3))
		for k in blobs:
			var off := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.3, 0.6), rng.randf_range(-1, 1)) * cr * 0.6
			var sc := Vector3.ONE * cr * rng.randf_range(0.7, 1.0)
			if kind == 0:
				sc.y *= 0.7  # sauce: achatado y ancho
				off.y -= cr * 0.15
			elif kind == 1:
				sc.y *= 1.6
				off.y += cr * (0.5 + k * 0.4)
			var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(sc), top + off)
			if (i + k) % 3 == 0:
				crowns_b.append(xf)
			else:
				crowns_a.append(xf)
		var fs := CollisionShape3D.new()
		var fsh := SphereShape3D.new()
		fsh.radius = cr * 1.05
		fs.shape = fsh
		fs.position = top + Vector3(0, cr * 0.2, 0)
		foliage.add_child(fs)
	var trunks := MultiMeshInstance3D.new()
	trunks.multimesh = trunk_mm
	trunks.material_override = mat("trunk")
	parent.add_child(trunks)
	for pair: Array in [[crowns_a, "leaves"], [crowns_b, "leaves_dark"]]:
		var list: Array[Transform3D] = pair[0]
		var mm := _mm(_blob_mesh(), list.size())
		for j in list.size():
			mm.set_instance_transform(j, list[j])
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.material_override = mat(pair[1])
		parent.add_child(mi)
	var bush_mm := _mm(_blob_mesh(), bushes.size() * 2)
	for i in bushes.size():
		var bsh: Array = bushes[i]
		var bp: Vector3 = bsh[0]
		var br := float(bsh[1])
		for k in 2:
			var o := Vector3(rng.randf_range(-0.5, 0.5), 0, rng.randf_range(-0.5, 0.5)) * br
			bush_mm.set_instance_transform(i * 2 + k, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(
				Vector3(br * rng.randf_range(0.8, 1.2), br * 0.7, br * rng.randf_range(0.8, 1.1))), bp + o + Vector3(0, br * 0.45, 0)))
		var bcs := CollisionShape3D.new()
		var bs := SphereShape3D.new()
		bs.radius = br * 0.95
		bcs.shape = bs
		bcs.position = bp + Vector3(0, br * 0.55, 0)
		foliage.add_child(bcs)
	var bmi := MultiMeshInstance3D.new()
	bmi.multimesh = bush_mm
	bmi.material_override = mat("leaves_dry")
	parent.add_child(bmi)


## Matas de pasto: cada una son unas hojas finas (triángulos, sin transparencias),
## en parches que se dejan de dibujar de lejos.
static func grass(parent: Node3D, points: Array, chunk := 40.0, view := 70.0, seed_v := 3) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var buckets := {}
	for p: Vector3 in points:
		var key := Vector2i(floori(p.x / chunk), floori(p.z / chunk))
		if not buckets.has(key):
			buckets[key] = []
		(buckets[key] as Array).append(p)
	var mesh := _grass_mesh()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 1.0
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	for key: Vector2i in buckets:
		var list: Array = buckets[key]
		var mm := _mm(mesh, list.size())
		for j in list.size():
			var sc := rng.randf_range(0.7, 1.3)
			mm.set_instance_transform(j, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc * rng.randf_range(0.8, 1.3), sc)),
				list[j]))
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = view
		mi.visibility_range_end_margin = 10.0
		mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		parent.add_child(mi)


static var _grass_cache: ArrayMesh
static var _blob_cache: Mesh


static func _grass_mesh() -> ArrayMesh:
	if _grass_cache != null:
		return _grass_cache
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 7:
		var a := rng.randf() * TAU
		var base := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.0, 0.12)
		var tilt := Vector3(cos(a + 0.6), 0, sin(a + 0.6)) * rng.randf_range(0.05, 0.18)
		var h := rng.randf_range(0.3, 0.55)
		var side := Vector3(-sin(a), 0, cos(a)) * 0.025
		var c0 := Color(0.12, 0.16, 0.06)
		var c1 := Color(0.32, 0.38, 0.16).lerp(Color(0.42, 0.4, 0.22), rng.randf())
		st.set_normal(Vector3.UP)
		st.set_color(c0)
		st.add_vertex(base - side)
		st.set_color(c0)
		st.add_vertex(base + side)
		st.set_color(c1)
		st.add_vertex(base + tilt + Vector3(0, h, 0))
	_grass_cache = st.commit()
	return _grass_cache


## Bulto de follaje: esfera deformada (no se ve como una pelota perfecta).
static func _blob_mesh() -> Mesh:
	if _blob_cache != null:
		return _blob_cache
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 9
	sm.rings = 5
	var arr := sm.get_mesh_arrays()
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var n := FastNoiseLite.new()
	n.frequency = 1.3
	for i in verts.size():
		var v := verts[i]
		verts[i] = v * (1.0 + n.get_noise_3dv(v * 1.5) * 0.35)
	arr[Mesh.ARRAY_VERTEX] = verts
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	_blob_cache = am
	return am


static func _mm(mesh: Mesh, count: int) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = count
	return mm


static func _cyl_mesh(r: float, h: float, segs: int) -> Mesh:
	var cm := CylinderMesh.new()
	cm.top_radius = r * 0.7
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = segs
	cm.rings = 1
	return cm


static func _sphere_mesh(r: float, segs: int, rings: int) -> Mesh:
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = segs
	sm.rings = rings
	return sm


## Cartel de madera con texto.
static func sign_post(parent: Node3D, pos: Vector3, yaw: float, text: String) -> void:
	var r := Node3D.new()
	r.position = pos
	r.rotation = Vector3(0, yaw, 0)
	parent.add_child(r)
	box(r, Vector3(-0.8, 1.0, 0), Vector3(0.1, 2.0, 0.1), mat("wood"), false)
	box(r, Vector3(0.8, 1.0, 0), Vector3(0.1, 2.0, 0.1), mat("wood"), false)
	box(r, Vector3(0, 1.75, 0), Vector3(2.0, 0.55, 0.05), mat("wood_old"), false)
	var l := Label3D.new()
	l.text = text
	l.font_size = 64
	l.pixel_size = 0.0045
	l.outline_size = 0
	l.modulate = Color(0.12, 0.1, 0.08)
	l.position = Vector3(0, 1.75, 0.03)
	r.add_child(l)
	var l2 := l.duplicate() as Label3D
	l2.position = Vector3(0, 1.75, -0.03)
	l2.rotation = Vector3(0, PI, 0)
	r.add_child(l2)
