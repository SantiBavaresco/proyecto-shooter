extends Node3D
## Incursión — Isla Talavera (mundo chico de la F3).
##
## Una isla del Delta de ~420 × 420 m con el riacho al este. Lugares:
##  - Puesto del Viejo (suroeste): campamento neutral, donde se empieza y adonde se
##    vuelve al morir. Tiene un alijo con equipo.
##  - Retén de la ruta: bloques de hormigón y una garita; dos Caranchos.
##  - Galpón de los Caranchos (centro): base alambrada con galpón, oficina, torre,
##    contenedores y el jefe. La base más fuerte.
##  - Estación de bombeo (este, contra el río): casa de bombas, tanques y muelle.
##  - Chacra abandonada (noroeste): casa en ruinas y galpón; un par de Caranchos.
##  - Patrullas por el camino.
## El terreno, las construcciones y la vegetación se arman por código; la malla de
## navegación se arma al cargar (sin frenar el juego).

const TERRAIN_SHADER := preload("res://world/zone_talavera/terrain.gdshader")
const SIZE := 420.0
const STEP := 2.0
const WATER_Y := -1.6
const SEED := 4417

const CAMP := Vector3(-150, 0, 150)
const CHECKPOINT := Vector3(-62, 0, 60)
const BASE_A := Vector3(35, 0, -25)
const BASE_B := Vector3(128, 0, 112)
const FARM := Vector3(-105, 0, -115)
## Campamento militar en el monte (pelea en campo abierto con árboles).
const MIL_CAMP := Vector3(92, 0, -118)
## Camino de tierra: del campamento al retén, al galpón y a la estación.
const ROAD := [Vector3(-150, 0, 140), Vector3(-110, 0, 100), Vector3(-62, 0, 60), Vector3(-20, 0, 20), Vector3(25, 0, -8),
	Vector3(70, 0, 30), Vector3(105, 0, 85), Vector3(128, 0, 100)]
## Lugares planos: [centro, radio].
const PADS := [[CAMP, 16.0], [CHECKPOINT, 10.0], [BASE_A, 40.0], [BASE_B, 20.0], [FARM, 18.0], [MIL_CAMP, 11.0]]

var _noise := FastNoiseLite.new()
var _geo: Node3D
var _rng := RandomNumberGenerator.new()
var _pad_h: Array[float] = []


func _ready() -> void:
	_rng.seed = SEED
	_noise.seed = SEED
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 0.006
	_noise.fractal_octaves = 3
	var sun := get_node_or_null("Sun") as DirectionalLight3D
	if sun != null:
		sun.rotation_degrees = Vector3(-34.0, 140.0, 0.0)
		sun.add_to_group("sun")
	_geo = Node3D.new()
	_geo.name = "Geometry"
	_geo.add_to_group(NavUtil.GROUP)
	add_child(_geo)
	for p: Array in PADS:
		_pad_h.append(maxf(_raw_height((p[0] as Vector3).x, (p[0] as Vector3).z), WATER_Y + 1.6))
	_build_terrain()
	_build_water()
	_build_bounds()
	_build_camp()
	_build_checkpoint()
	_build_base_a()
	_build_base_b()
	_build_farm()
	_build_mil_camp()
	_build_props()
	_build_vegetation()
	NavUtil.bake(self, AABB(Vector3(-SIZE * 0.5, -10, -SIZE * 0.5), Vector3(SIZE, 40, SIZE)), true, 0.3)
	_spawn_enemies()
	var player := get_node_or_null("Player") as Player
	if player != null:
		player.teleport(ground(CAMP + Vector3(2, 0, -4)) + Vector3(0, 0.1, 0), PI * 0.75)
		_camp_kit(player)


## Altura del terreno en (x, z).
## Rectángulo (x, z) que muestra el mapa.
func map_rect() -> Rect2:
	return Rect2(-SIZE * 0.5, -SIZE * 0.5, SIZE, SIZE)


func height(x: float, z: float) -> float:
	var h := _raw_height(x, z)
	# Lugares planos y el camino
	for i in PADS.size():
		var c: Vector3 = PADS[i][0]
		var r: float = PADS[i][1]
		var d := Vector2(x - c.x, z - c.z).length()
		h = lerpf(h, _pad_h[i], 1.0 - smoothstep(r, r + 18.0, d))
	# El camino no hunde los lugares planos (antes dentro del galpón el piso bajaba
	# donde pasa el camino y el alambrado y los contenedores quedaban flotando)
	var pad_w := 0.0
	for i in PADS.size():
		var c2: Vector3 = PADS[i][0]
		pad_w = maxf(pad_w, 1.0 - smoothstep(float(PADS[i][1]), float(PADS[i][1]) + 18.0, Vector2(x - c2.x, z - c2.z).length()))
	var rd := _road_dist(x, z)
	if rd < 8.0 and pad_w < 1.0:
		var road_h := lerpf(h, _raw_height(x, z) * 0.7, 1.0 - smoothstep(3.0, 8.0, rd)) - (1.0 - smoothstep(1.5, 3.5, rd)) * 0.08
		h = lerpf(road_h, h, pad_w)
	return h


func _raw_height(x: float, z: float) -> float:
	var h := _noise.get_noise_2d(x, z) * 3.6 + _noise.get_noise_2d(x * 3.0 + 50.0, z * 3.0) * 0.7 + 1.2
	# Riacho al este: el terreno baja hasta el agua
	h -= smoothstep(150.0, 185.0, x) * 6.0
	# Bañado al norte
	h -= smoothstep(-150.0, -195.0, z) * 3.0
	return h


func ground(p: Vector3) -> Vector3:
	return Vector3(p.x, height(p.x, p.z), p.z)


func _road_dist(x: float, z: float) -> float:
	var best := INF
	var p := Vector2(x, z)
	for i in ROAD.size() - 1:
		var a := Vector2(ROAD[i].x, ROAD[i].z)
		var b := Vector2(ROAD[i + 1].x, ROAD[i + 1].z)
		var ab := b - a
		var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		best = minf(best, p.distance_to(a + ab * t))
	return best


# --- Terreno -----------------------------------------------------------------------

func _build_terrain() -> void:
	var n := int(SIZE / STEP) + 1
	var half := SIZE * 0.5
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var norms := PackedVector3Array()
	verts.resize(n * n)
	cols.resize(n * n)
	norms.resize(n * n)
	var grass := Color(0.2, 0.26, 0.11)
	var dry := Color(0.33, 0.33, 0.18)
	var dirt := Color(0.3, 0.25, 0.18)
	var mud := Color(0.2, 0.18, 0.13)
	for iz in n:
		for ix in n:
			var x := -half + ix * STEP
			var z := -half + iz * STEP
			var h := height(x, z)
			verts[iz * n + ix] = Vector3(x, h, z)
			var c := grass.lerp(dry, clampf(_noise.get_noise_2d(x * 4.0, z * 4.0) * 0.8 + 0.4, 0.0, 1.0))
			var rd := _road_dist(x, z)
			c = c.lerp(dirt, 1.0 - smoothstep(1.5, 4.0, rd))
			for p: Array in PADS:
				var pc: Vector3 = p[0]
				c = c.lerp(dirt, (1.0 - smoothstep(float(p[1]) * 0.6, float(p[1]) + 4.0, Vector2(x - pc.x, z - pc.z).length())) * 0.6)
			if h < WATER_Y + 0.8:
				c = c.lerp(mud, clampf((WATER_Y + 0.8 - h) / 1.2, 0.0, 1.0))
			cols[iz * n + ix] = c
	for iz in n:
		for ix in n:
			var hl := verts[iz * n + maxi(ix - 1, 0)].y
			var hr := verts[iz * n + mini(ix + 1, n - 1)].y
			var hd := verts[maxi(iz - 1, 0) * n + ix].y
			var hu := verts[mini(iz + 1, n - 1) * n + ix].y
			norms[iz * n + ix] = Vector3(hl - hr, 2.0 * STEP, hd - hu).normalized()
	var idx := PackedInt32Array()
	for iz in n - 1:
		for ix in n - 1:
			var a := iz * n + ix
			idx.append_array([a, a + 1, a + n, a + 1, a + n + 1, a + n])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var m := ShaderMaterial.new()
	m.shader = TERRAIN_SHADER
	m.set_shader_parameter("detail", Structures._noise())
	var mi := MeshInstance3D.new()
	mi.name = "Terrain"
	mi.mesh = mesh
	mi.material_override = m
	var body := StaticBody3D.new()
	body.name = "TerrainBody"
	body.set_meta("surface", "dirt")
	var cs := CollisionShape3D.new()
	cs.shape = mesh.create_trimesh_shape()
	body.add_child(cs)
	body.add_child(mi)
	_geo.add_child(body)


func _build_water() -> void:
	var mi := MeshInstance3D.new()
	mi.name = "River"
	var pm := PlaneMesh.new()
	pm.size = Vector2(SIZE + 200, SIZE + 200)
	mi.mesh = pm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.32, 0.28, 0.2, 0.92)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.08
	m.metallic = 0.2
	m.albedo_texture = Structures._noise()
	m.uv1_scale = Vector3.ONE * 30.0
	mi.material_override = m
	mi.position = Vector3(0, WATER_Y, 0)
	add_child(mi)
	# Agua profunda: no se puede cruzar (pared invisible donde el terreno se hunde)
	var b := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(4, 10, SIZE)
	cs.shape = bs
	b.add_child(cs)
	b.position = Vector3(176, 0, 0)
	add_child(b)


func _build_bounds() -> void:
	var half := SIZE * 0.5 - 2.0
	for d: Array in [[Vector3(0, 5, -half), Vector3(SIZE, 20, 2)], [Vector3(0, 5, half), Vector3(SIZE, 20, 2)],
			[Vector3(-half, 5, 0), Vector3(2, 20, SIZE)], [Vector3(half, 5, 0), Vector3(2, 20, SIZE)]]:
		var b := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = d[1]
		cs.shape = bs
		b.add_child(cs)
		b.position = d[0]
		add_child(b)


# --- Lugares -----------------------------------------------------------------------

func _at(p: Vector3) -> Vector3:
	return ground(p)


## Puesto del Viejo: campamento neutral con alijo.
func _build_camp() -> void:
	var c := _at(CAMP)
	Structures.tent(_geo, c + Vector3(-5, 0, -3), 0.3, Vector3(3.2, 2.1, 4.2))
	Structures.tent(_geo, c + Vector3(4, 0, -6), -0.5, Vector3(2.6, 1.8, 3.4), Structures.mat("tarp_blue"))
	Structures.campfire(_geo, c)
	for a: float in [0.0, 2.1, 4.2]:
		Structures.cyl(_geo, c + Vector3(cos(a) * 2.4, 0.25, sin(a) * 2.4), 0.22, 0.5, Structures.mat("trunk"), true, "wood",
			Vector3(0, 0, PI * 0.5) if a > 1.0 else Vector3.ZERO, 8)
	Structures.sandbags(_geo, c + Vector3(0, 0, -11), 0.0, 6.0)
	Structures.sandbags(_geo, c + Vector3(9, 0, 2), PI * 0.5, 5.0)
	Structures.crates(_geo, c + Vector3(-7, 0, 3), 0.4, 3)
	Structures.sign_post(_geo, c + Vector3(6, 0, -12), 0.6, tr("zone.camp_sign"))
	var mk := CompassMarker.new()
	mk.name = "CampMarker"
	mk.label_key = "compass.camp"
	mk.position = c
	add_child(mk)
	var stash := LootContainer.new()
	stash.name = "CampStash"
	stash.kind = "stash"
	stash.contents = [["w_ak74", 1], [ItemDB.standard_mag("ak74"), 3], ["ammo_545x39", 90], ["vest_light", 1], ["helmet_steel", 1],
		["rig_medium", 1], ["backpack_small", 1], ["medkit", 2], ["bandage", 4], ["grenade_rg5", 2], ["water", 2], ["canned_meat", 2]]
	stash.position = c + Vector3(-3.5, 0, 1.5)
	stash.rotation = Vector3(0, 1.2, 0)
	_geo.add_child(stash)
	_fill_mags(stash)


## Los cargadores del contenido fijo vienen llenos.
func _fill_mags(box: LootContainer) -> void:
	box.ensure_filled()
	for s in box.inventory.stacks:
		if s.item.kind == "mag":
			s.state["rounds"] = s.item.capacity


func _build_checkpoint() -> void:
	var c := _at(CHECKPOINT)
	var dir := (ROAD[3] - ROAD[1]).normalized()
	var yaw := atan2(-dir.z, dir.x)
	Structures.jersey(_geo, c + Vector3(-4, 0, 3), yaw + 0.3)
	Structures.jersey(_geo, c + Vector3(4, 0, -3), yaw - 0.2)
	Structures.jersey(_geo, c + Vector3(6, 0, 4), yaw + PI * 0.5)
	Structures.building(_geo, c + Vector3(-7, 0, -6), Vector3(3, 2.6, 3), yaw, {"s": [[0.0, 0.9, 2.0, 0.0]], "e": [[0.0, 1.0, 1.9, 1.0]],
		"o": [[0.0, 1.0, 1.9, 1.0]]}, Structures.mat("plaster"), "flat", Structures.mat("concrete_dark"))
	# Barrera
	Structures.cyl(_geo, c + Vector3(1, 0.5, 0), 0.08, 1.0, Structures.mat("concrete"), true, "concrete", Vector3.ZERO, 8)
	Structures.box(_geo, c + Vector3(-1.5, 1.0, 0), Vector3(5, 0.12, 0.12), Structures.mat("yellow"), false)
	Structures.car_wreck(_geo, c + Vector3(10, 0, 8), 2.4, "car_red")
	Structures.sandbags(_geo, c + Vector3(-2, 0, -9), yaw, 4.0, 1.1, true)
	var crate := LootContainer.new()
	crate.name = "CheckpointCrate"
	crate.kind = "crate"
	crate.loot_seed = 31
	crate.position = c + Vector3(-7, 0.1, -6)
	_geo.add_child(crate)


## Galpón de los Caranchos: la base grande.
func _build_base_a() -> void:
	var c := _at(BASE_A)
	var half := Vector2(30, 23)
	# Alambrado con portón al suroeste (del lado del camino)
	var corners := [c + Vector3(-half.x, 0, -half.y), c + Vector3(half.x, 0, -half.y), c + Vector3(half.x, 0, half.y), c + Vector3(-half.x, 0, half.y)]
	Structures.fence(_geo, corners[0], corners[1])
	Structures.fence(_geo, corners[1], corners[2])
	Structures.fence(_geo, corners[2], corners[3], 2.4, [[42.0, 7.0]])
	Structures.fence(_geo, corners[3], corners[0], 2.4, [[14.0, 6.0]])
	# Galpón grande con portón y puerta lateral
	Structures.building(_geo, c + Vector3(6, 0, -8), Vector3(26, 7, 14), 0.0, {
		"s": [[-4.0, 6.0, 5.0, 0.0], [8.0, 1.2, 2.2, 0.0]], "n": [[9.0, 1.2, 2.2, 0.0]],
		"e": [[0.0, 2.0, 4.0, 2.0]], "o": [[-2.0, 1.2, 2.2, 0.0], [3.0, 2.0, 4.0, 2.0]]},
		Structures.mat("rust"), "shed", Structures.mat("roof"))
	# Adentro: cajones, tambores, estanterías
	Structures.crates(_geo, c + Vector3(-2, 0, -12), 0.0, 4)
	Structures.crates(_geo, c + Vector3(14, 0, -5), 0.3, 3)
	for i in 4:
		Structures.barrel(_geo, c + Vector3(10 + i * 0.7, 0, -13.2))
	for k in 2:
		var sx := 2.0 + k * 6.0
		Structures.box(_geo, c + Vector3(sx, 1.0, -10.5), Vector3(4.0, 2.0, 0.6), Structures.mat("metal"), true, "metal")
	var wc := LootContainer.new()
	wc.name = "BaseA_Weapons"
	wc.kind = "weapons"
	wc.loot_seed = 401
	wc.position = c + Vector3(16, 0.1, -12)
	_geo.add_child(wc)
	var crate := LootContainer.new()
	crate.name = "BaseA_Crate"
	crate.kind = "crate"
	crate.loot_seed = 402
	crate.position = c + Vector3(-4, 0.1, -5)
	_geo.add_child(crate)
	# Oficina del jefe
	Structures.building(_geo, c + Vector3(-18, 0, -12), Vector3(8, 3.0, 6), 0.0, {
		"s": [[1.5, 1.0, 2.1, 0.0], [-2.0, 1.4, 2.0, 1.0]], "e": [[0.0, 1.4, 2.0, 1.0]]},
		Structures.mat("plaster"), "flat", Structures.mat("concrete_dark"))
	var office := LootContainer.new()
	office.name = "BaseA_Office"
	office.kind = "metal"
	office.contents = [["medkit_army", 1], ["cash", 1200], ["optic_acog", 1], ["ammo_556x45", 60], ["grenade_f1", 1]]
	office.position = c + Vector3(-20.5, 0.1, -13.8)
	_geo.add_child(office)
	Structures.box(_geo, c + Vector3(-17, 0.4, -11.5), Vector3(1.6, 0.8, 0.8), Structures.mat("wood"), true, "wood")
	# Contenedores, uno abierto con un alijo adentro
	Structures.container(_geo, c + Vector3(-18, 0, 8), 0.0, Color("7a3b28"))
	Structures.container(_geo, c + Vector3(-18, 0, 12), 0.0, Color("2f4a63"), true)
	Structures.container(_geo, c + Vector3(-10, 0, 16), PI * 0.5, Color("3f5a36"))
	var cstash := LootContainer.new()
	cstash.name = "BaseA_ContainerStash"
	cstash.kind = "stash"
	cstash.loot_seed = 403
	cstash.position = c + Vector3(-19.5, 0.15, 12)
	cstash.rotation = Vector3(0, PI * 0.5, 0)
	_geo.add_child(cstash)
	# Torre de vigilancia en la esquina noreste
	Structures.watchtower(_geo, c + Vector3(24, 0, -18), PI)
	# Puestos de bolsas de arena en el portón y adentro
	Structures.sandbags(_geo, c + Vector3(-22, 0, 20), 0.6, 4.0, 1.1, true)
	Structures.sandbags(_geo, c + Vector3(8, 0, 8), 0.0, 5.0)
	Structures.sandbags(_geo, c + Vector3(20, 0, 10), -0.4, 4.0)
	Structures.car_wreck(_geo, c + Vector3(0, 0, 14), 0.8, "car_green")
	Structures.campfire(_geo, c + Vector3(14, 0, 14))
	for i in 3:
		Structures.barrel(_geo, c + Vector3(-6 + i * 0.7, 0, 6))
	Structures.sign_post(_geo, c + Vector3(-34, 0, 26), 2.3, tr("zone.base_a_sign"))
	# Más cosas en el patio para moverse cubierto: autos, bloques, cajones, tambores
	Structures.car_wreck(_geo, c + Vector3(-4, 0, 20), 2.2, "car_white")
	Structures.car_wreck(_geo, c + Vector3(26, 0, 4), 0.3, "car_red")
	Structures.car_wreck(_geo, c + Vector3(-26, 0, -6), 1.6)
	Structures.car_wreck(_geo, c + Vector3(-22, 0, 1), 2.9, "car_green")
	Structures.container(_geo, c + Vector3(26, 0, -6), PI * 0.5, Color("5a4a2e"))
	for jp: Array in [[Vector3(2, 0, 3), 0.1], [Vector3(-12, 0, 4), -0.3], [Vector3(9, 0, 20), 0.0], [Vector3(-8, 0, -20), 0.0],
			[Vector3(24, 0, 16), 1.3]]:
		Structures.jersey(_geo, c + jp[0], jp[1])
	Structures.crates(_geo, c + Vector3(-26, 0, -14), 0.2, 3)
	Structures.crates(_geo, c + Vector3(6, 0, 12), 0.4, 2)
	Structures.crates(_geo, c + Vector3(-14, 0, 18), -0.5, 2)
	for i in 3:
		Structures.barrel(_geo, c + Vector3(17 + i * 0.7, 0, 20))
	Structures.barrel(_geo, c + Vector3(-24, 0, -10))
	Structures.sandbags(_geo, c + Vector3(-2, 0, -20), 0.0, 4.0)


## Estación de bombeo contra el río.
func _build_base_b() -> void:
	var c := _at(BASE_B)
	Structures.building(_geo, c, Vector3(12, 5.5, 9), 0.25, {
		"s": [[-3.0, 1.2, 2.2, 0.0], [2.5, 1.6, 2.4, 1.2]], "o": [[0.0, 1.2, 2.2, 0.0]], "e": [[1.5, 1.6, 2.4, 1.2]],
		"n": [[3.0, 1.6, 2.4, 1.2]]}, Structures.mat("brick"), "flat")
	# Pared interior que divide en dos ambientes
	Structures.wall(_geo, Transform3D(Basis(Vector3.UP, 0.25 + PI * 0.5), c + Vector3(0, 0, 0).rotated(Vector3.UP, 0.25)), 8.5, 5.5,
		[[1.5, 1.1, 2.2, 0.0]], Structures.mat("brick"), "concrete")
	# Tanques y caños
	for i in 2:
		var tp := c + Vector3(-12 + i * 6, 0, -9).rotated(Vector3.UP, 0.25)
		Structures.cyl(_geo, tp + Vector3(0, 2.5, 0), 2.2, 5.0, Structures.mat("rust"), true, "metal", Vector3.ZERO, 20)
	Structures.cyl(_geo, c + Vector3(8, 0.6, -2).rotated(Vector3.UP, 0.25), 0.35, 14.0, Structures.mat("rust"), true, "metal",
		Vector3(0, 0.25, PI * 0.5), 12)
	# Muelle de madera hacia el agua
	var dock := c + Vector3(26, 0, 4)
	Structures.box(_geo, Vector3(dock.x, WATER_Y + 0.6, dock.z), Vector3(14, 0.2, 3), Structures.mat("wood_old"), true, "wood")
	for i in 5:
		Structures.cyl(_geo, Vector3(dock.x - 6 + i * 3, WATER_Y - 0.5, dock.z - 1.4), 0.12, 2.6, Structures.mat("wood_old"), false)
	# Ruinas de un muro perimetral
	Structures.box(_geo, c + Vector3(-14, 0.9, 10), Vector3(9, 1.8, 0.4), Structures.mat("concrete"), true, "concrete", Vector3(0, 0.25, 0))
	Structures.box(_geo, c + Vector3(-4, 0.6, 14), Vector3(6, 1.2, 0.4), Structures.mat("concrete"), true, "concrete", Vector3(0, 0.25, 0))
	Structures.sandbags(_geo, c + Vector3(6, 0, 9), 0.25, 4.0, 1.1, true)
	Structures.car_wreck(_geo, c + Vector3(-10, 0, 3), 1.2)
	Structures.crates(_geo, c + Vector3(-2, 0, -2).rotated(Vector3.UP, 0.25), 0.25, 2)
	var box := LootContainer.new()
	box.name = "BaseB_Metal"
	box.kind = "metal"
	box.loot_seed = 501
	box.position = c + Vector3(3, 0.1, -2.5).rotated(Vector3.UP, 0.25)
	box.rotation = Vector3(0, 0.25, 0)
	_geo.add_child(box)
	var wbox := LootContainer.new()
	wbox.name = "BaseB_Weapons"
	wbox.kind = "weapons"
	wbox.loot_seed = 502
	wbox.position = c + Vector3(-3.5, 0.1, 2.5).rotated(Vector3.UP, 0.25)
	wbox.rotation = Vector3(0, 0.25, 0)
	_geo.add_child(wbox)
	Structures.sign_post(_geo, c + Vector3(-16, 0, -6), 0.9, tr("zone.base_b_sign"))


## Chacra abandonada: casa sin techo y un galpón.
func _build_farm() -> void:
	var c := _at(FARM)
	Structures.building(_geo, c, Vector3(10, 3.0, 7), -0.4, {
		"s": [[0.0, 1.0, 2.1, 0.0], [-3.0, 1.4, 2.0, 1.0]], "n": [[2.0, 3.0, 3.0, 0.0]], "e": [[0.0, 1.4, 2.0, 1.0]],
		"o": [[0.0, 2.5, 3.0, 0.6]]}, Structures.mat("plaster"), "none")
	Structures.building(_geo, c + Vector3(12, 0, 8), Vector3(7, 4, 6), -0.4, {
		"o": [[0.0, 4.0, 3.6, 0.0]]}, Structures.mat("wood_old"), "shed", Structures.mat("rust"), false)
	Structures.campfire(_geo, c + Vector3(-7, 0, 6))
	Structures.car_wreck(_geo, c + Vector3(-10, 0, -6), 0.4, "car_white")
	Structures.crates(_geo, c + Vector3(13, 0, 9), 0.0, 2)
	var crate := LootContainer.new()
	crate.name = "Farm_Crate"
	crate.kind = "crate"
	crate.loot_seed = 601
	crate.position = c + Vector3(1.5, 0.1, 1.0)
	_geo.add_child(crate)
	var stash := LootContainer.new()
	stash.name = "Farm_Stash"
	stash.kind = "stash"
	stash.loot_seed = 602
	stash.position = c + Vector3(13, 0.1, 6.5)
	_geo.add_child(stash)


## Campamento militar: dos carpas, fogón, cajones y un cajón de armas, en un claro chico
## del monte (los árboles quedan cerca: pelea en campo abierto pero con troncos).
func _build_mil_camp() -> void:
	var c := _at(MIL_CAMP)
	Structures.tent(_geo, c + Vector3(-4, 0, -3), 0.3, Vector3(3.2, 2.0, 4.2), Structures.mat("tarp"))
	Structures.tent(_geo, c + Vector3(4.5, 0, -2), -0.4, Vector3(3.2, 2.0, 4.2))
	Structures.campfire(_geo, c + Vector3(0, 0, 2))
	Structures.crates(_geo, c + Vector3(-5, 0, 4), 0.2, 3)
	Structures.sandbags(_geo, c + Vector3(6, 0, 5), -0.6, 3.0, 1.0)
	var wc := LootContainer.new()
	wc.name = "MilCamp_Weapons"
	wc.kind = "weapons"
	wc.loot_seed = 701
	wc.position = c + Vector3(-1.5, 0.1, -4.5)
	_geo.add_child(wc)
	var crate := LootContainer.new()
	crate.name = "MilCamp_Crate"
	crate.kind = "crate"
	crate.loot_seed = 702
	crate.contents = [["grenade_smoke", 2], ["medkit", 1], ["bandage", 3], ["ammo_556x45", 90]]
	crate.position = c + Vector3(-5.5, 0.1, 2.0)
	_geo.add_child(crate)
	Structures.sign_post(_geo, c + Vector3(0, 0, 9), PI, tr("zone.mil_camp"))


## Cosas sueltas por el mapa: autos, tambores, cajones.
func _build_props() -> void:
	var spots := [[Vector3(-128, 0, 118), 0.4, "car_red"], [Vector3(-35, 0, 36), 2.0, "car_white"], [Vector3(55, 0, 15), -0.8, "car_green"],
		[Vector3(92, 0, 66), 1.4, "car_white"], [Vector3(-80, 0, -20), 0.3, "car_red"]]
	for s: Array in spots:
		Structures.car_wreck(_geo, _at(s[0]), s[1], s[2])
	for p: Vector3 in [Vector3(-95, 0, 82), Vector3(5, 0, 5), Vector3(80, 0, 50), Vector3(-40, 0, -60)]:
		Structures.crates(_geo, _at(p), _rng.randf() * TAU, 2)
		Structures.barrel(_geo, _at(p + Vector3(1.8, 0, 0.5)))
	var hidden := LootContainer.new()
	hidden.name = "Hidden_Stash"
	hidden.kind = "stash"
	hidden.loot_seed = 701
	hidden.position = _at(Vector3(-40, 0, -61.5)) + Vector3(0, 0.1, 0)
	_geo.add_child(hidden)


func _build_vegetation() -> void:
	var trees: Array = []
	var bushes: Array = []
	var half := SIZE * 0.5 - 6.0
	var tries := 0
	while trees.size() < 620 and tries < 16000:
		tries += 1
		var x := _rng.randf_range(-half, half)
		var z := _rng.randf_range(-half, half)
		if not _free_spot(x, z, 6.0):
			continue
		# Más espeso en los bordes y en el bañado
		var edge := maxf(absf(x), absf(z)) / half
		if _rng.randf() > 0.5 + edge * 0.5 and _noise.get_noise_2d(x * 2.0, z * 2.0) < 0.05:
			continue
		var h := ground(Vector3(x, 0, z))
		if h.y < WATER_Y + 0.2:
			continue
		var kind := _rng.randi() % 3
		if h.y < WATER_Y + 1.5:
			kind = 0  # sauces cerca del agua
		trees.append([h - Vector3(0, 0.2, 0), _rng.randf_range(6.0, 13.0) * (1.4 if kind == 1 else 1.0), kind])
	tries = 0
	while bushes.size() < 1150 and tries < 16000:
		tries += 1
		var x := _rng.randf_range(-half, half)
		var z := _rng.randf_range(-half, half)
		if not _free_spot(x, z, 3.0):
			continue
		var h := ground(Vector3(x, 0, z))
		if h.y < WATER_Y + 0.1:
			continue
		bushes.append([h - Vector3(0, 0.15, 0), _rng.randf_range(0.6, 1.4)])
		# A veces en matorral (2–3 juntos): da para esconderse y moverse tapado
		if _rng.randf() < 0.3:
			for k in _rng.randi_range(1, 2):
				var o := Vector3(_rng.randf_range(-2.2, 2.2), 0, _rng.randf_range(-2.2, 2.2))
				if _free_spot(x + o.x, z + o.z, 2.0):
					var h2 := ground(Vector3(x + o.x, 0, z + o.z))
					if h2.y >= WATER_Y + 0.1:
						bushes.append([h2 - Vector3(0, 0.15, 0), _rng.randf_range(0.7, 1.3)])
	var veg := Node3D.new()
	veg.name = "Vegetation"
	_geo.add_child(veg)
	Structures.vegetation(veg, trees, bushes, SEED)
	# Pasto: matas por todos lados menos en el camino, los lugares armados y el agua
	var tufts: Array = []
	tries = 0
	while tufts.size() < 26000 and tries < 60000:
		tries += 1
		var x := _rng.randf_range(-half, half)
		var z := _rng.randf_range(-half, half)
		if _road_dist(x, z) < 2.5:
			continue
		var inside := false
		for p: Array in PADS:
			var c: Vector3 = p[0]
			if Vector2(x - c.x, z - c.z).length() < float(p[1]) * 0.75:
				inside = true
				break
		if inside:
			continue
		var g := ground(Vector3(x, 0, z))
		if g.y < WATER_Y + 0.15:
			continue
		tufts.append(g)
	var grass := Node3D.new()
	grass.name = "Grass"
	add_child(grass)
	Structures.grass(grass, tufts)


## Lejos de los lugares armados y del camino.
func _free_spot(x: float, z: float, margin: float) -> bool:
	if _road_dist(x, z) < 6.0 + margin * 0.3:
		return false
	for p: Array in PADS:
		var c: Vector3 = p[0]
		if Vector2(x - c.x, z - c.z).length() < float(p[1]) + margin:
			return false
	return true


# --- Enemigos ----------------------------------------------------------------------

func _spawn_enemies() -> void:
	var a := BASE_A
	# Galpón: jefe en la oficina, tirador en la torre, guardias en el portón, patrullas
	_npc("Jefe", "bandit_boss", a + Vector3(-17, 0, -12), PI, "galpon")
	_npc("Torre", "bandit_marksman", a + Vector3(24, 4.6, -18), PI * 0.75, "galpon", [], true)
	_npc("Porton1", "bandit_rifle", a + Vector3(-21, 0, 18.5), PI * 0.8, "galpon")
	_npc("Porton2", "bandit_shotgun", a + Vector3(-25, 0, 15), PI * 0.6, "galpon")
	_npc("Galpon", "bandit_rifle", a + Vector3(2, 0, -6), PI, "galpon")
	# Trabajo en conjunto: los militares mandan a los bandidos del galpón
	_npc("MilJefe", "mil_leader", a + Vector3(-12, 0, -4), PI * 0.8, "galpon")
	_npc("MilTirador", "mil_marksman", a + Vector3(20, 0, 14), PI * 0.7, "galpon")
	_npc("Mil1", "mil_rifle", a + Vector3(-6, 0, 12), PI * 0.9, "galpon")
	_npc("Mil2", "mil_rifle", a + Vector3(14, 0, 2), PI * 0.6, "galpon")
	# Ronda: dos militares que dan vueltas por afuera del alambrado (en formación)
	var ronda := [a + Vector3(-36, 0, 30), a + Vector3(36, 0, 30), a + Vector3(36, 0, -30), a + Vector3(-36, 0, -30)]
	_npc("RondaA", "mil_rifle", a + Vector3(-36, 0, 30), 0.0, "ronda", ronda)
	_npc("RondaB", "mil_rifle", a + Vector3(-38, 0, 34), 0.0, "ronda")
	# Campamento militar en el monte: 4
	var m := MIL_CAMP
	_npc("CampLider", "mil_leader", m + Vector3(-1.5, 0, 3.5), PI * 0.2, "monte")
	_npc("Camp1", "mil_rifle", m + Vector3(2.0, 0, 3.0), -PI * 0.3, "monte")
	_npc("Camp2", "mil_marksman", m + Vector3(6.5, 0, 6.5), PI, "monte")
	_npc("Camp3", "mil_rifle", m + Vector3(-8, 0, -6), 0.0, "monte",
		[m + Vector3(-8, 0, -6), m + Vector3(10, 0, -10), m + Vector3(12, 0, 10), m + Vector3(-10, 0, 12)])
	# Estación de bombeo
	var b := BASE_B
	_npc("Bombas1", "bandit_smg", b + Vector3(-2, 0, 1), PI * 0.6, "bombas")
	_npc("Bombas2", "bandit_shotgun", b + Vector3(3, 0, -1), PI * 1.2, "bombas")
	_npc("Bombas3", "bandit_rifle", b + Vector3(5, 0, 10), PI * 0.9, "bombas")
	_npc("Muelle", "bandit_pistol", b + Vector3(22, 0, 3), -PI * 0.5, "bombas",
		[b + Vector3(20, 0, 2), b + Vector3(8, 0, 12), b + Vector3(-6, 0, 8)])
	# Retén
	var k := CHECKPOINT
	_npc("Reten1", "bandit_rifle", k + Vector3(-3, 0, -8), PI * 0.85, "reten")
	_npc("Reten2", "bandit_pistol", k + Vector3(3, 0, 1), -PI * 0.3, "reten")
	# Chacra
	var f := FARM
	_npc("Chacra1", "bandit_rifle", f + Vector3(-6, 0, 4), PI * 0.4, "chacra")
	_npc("Chacra2", "bandit_smg", f + Vector3(-8, 0, 8), PI * 1.1, "chacra")
	# Patrulla del camino (entre el retén y el galpón)
	_npc("Ruta1", "bandit_rifle", Vector3(-20, 0, 20), 0.0, "ruta", [Vector3(-55, 0, 54), Vector3(-20, 0, 20), Vector3(20, 0, -4)])
	_npc("Ruta2", "bandit_smg", Vector3(-23, 0, 23), 0.0, "ruta", [Vector3(-58, 0, 57), Vector3(-23, 0, 23), Vector3(17, 0, -1)])


func _npc(nm: String, loadout: String, pos: Vector3, yaw: float, squad: String, patrol: Array = [], raw_y := false) -> HumanNpc:
	var n := HumanNpc.new()
	n.name = "Npc_" + nm
	n.loadout_id = loadout
	n.squad = squad
	n.seed_value = hash(nm) % 100000 + 1
	var pts := PackedVector3Array()
	for p: Vector3 in patrol:
		pts.append(ground(p))
	n.patrol = pts
	var gp := ground(pos)
	n.position = Vector3(pos.x, pos.y + (height(pos.x, pos.z) if raw_y else gp.y) + 0.05, pos.z) if raw_y else gp + Vector3(0, 0.05, 0)
	n.rotation = Vector3(0, yaw, 0)
	add_child(n)
	return n


# --- Jugador ------------------------------------------------------------------------

## Lo que tiene al empezar la incursión: ropa, cuchillo, pistola y un poco de comida.
func _camp_kit(p: Player) -> void:
	p.inventory.strip_all()
	p.inventory.give_respawn_kit()
	p.inventory.receive(ItemStack.make("water", 1))
	p.inventory.money = 300
	p.inventory.changed.emit()


## Muerte: el cuerpo queda con todo; se vuelve al campamento con lo mínimo (el resto
## está en el alijo, si no se lo llevó antes).
func on_player_died(p: Player) -> void:
	PlayerCorpse.leave(p)
	p.inventory.give_respawn_kit()
	p.respawn_at(ground(CAMP + Vector3(2, 0, -4)) + Vector3(0, 0.1, 0), PI * 0.75)
	EventBus.player_respawned.emit(p)
	EventBus.toast.emit(tr("zone.respawned"))
