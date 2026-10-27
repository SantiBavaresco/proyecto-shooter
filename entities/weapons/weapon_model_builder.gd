class_name WeaponModelBuilder
extends RefCounted
## Modelos de armas hechos por código, uno por arma, con la silueta del arma real
## en la que se basa cada una (perfiles extruidos con bordes redondeados, piezas
## torneadas, rieles con dientes, miras y visores con su forma).
## TODO-ASSET: un modelo real por arma (ver docs/ASSETS.md).
##
## Convenciones (las mismas que deben respetar los modelos reales):
##  - Metros, cañón hacia −Z, +Y arriba, origen cerca de la empuñadura.
##  - Marcadores (Marker3D): Muzzle (boca), Sight (punto de la línea de mira; su
##    metadata "eye_relief" es la distancia ojo–mira sugerida), Ejection.
##  - Piezas animables (Node3D): Mag, Slide, Charging, Bolt, Barrels (con ShellL/ShellR).
##  - Visor: MeshInstance3D "ScopeLens" (ocular) con material de visor; metadata "lens_d".
##  - Punto rojo: MeshInstance3D "Lens".
##  - Brazos: nodos "HandR" / "HandL" (ArmsBuilder); HandL puede ir dentro de "Barrels".
##
## Cada familia está en su archivo: models_rifles.gd, models_bolt.gd,
## models_pistols.gd y models_shotguns.gd. Al final todas las mallas fijas de
## un mismo material se funden en una sola (menos llamadas de dibujo).

const RED_DOT_SHADER := preload("res://entities/weapons/red_dot.gdshader")
const SCOPE_SHADER := preload("res://entities/weapons/scope_lens.gdshader")
## Piezas que se animan por separado (se funden por dentro, no con el resto).
const GROUPS: Array[String] = ["Mag", "Slide", "Charging", "Bolt", "Barrels", "ShellL", "ShellR"]
## Mallas que nunca se funden.
const KEEP: Array[String] = ["ScopeLens", "Lens", "HandR", "HandL", "HookR", "HookL", "HookP", "StuckCase", "Loader"]

static var _mats: Dictionary = {}


static func build(data: WeaponData) -> Node3D:
	var shape: String = data.model_params.get("shape", data.id)
	if shape == "imported":
		return ImportedWeapon.build(data)
	var root: Node3D
	match shape:
		"pistol":
			root = ModelsPistols.striker(data)
		"bersa9":
			root = ModelsPistols.bersa(data)
		"ballester45":
			root = ModelsPistols.m1911(data, true)
		"m1911":
			root = ModelsPistols.m1911(data, false)
		"p22":
			root = ModelsPistols.target22(data)
		"ar15", "hk416", "sr22", "sr25":
			root = ModelsRifles.ar(data)
		"scarl":
			root = ModelsRifles.scar(data)
		"ak74", "akm":
			root = ModelsRifles.ak(data)
		"svd":
			root = ModelsRifles.svd(data)
		"pp19":
			root = ModelsRifles.bizon(data)
		"mp5":
			root = ModelsRifles.mp5(data)
		"rifle":
			root = ModelsRifles.fal(data)
		"g3":
			root = ModelsRifles.g3(data)
		"sks":
			root = ModelsRifles.sks(data)
		"m14ebr":
			root = ModelsRifles.ebr(data)
		"rem700":
			root = ModelsBolt.rem700(data)
		"mauser1909":
			root = ModelsBolt.mauser(data)
		"bolt22":
			root = ModelsBolt.rimfire(data)
		"shotgun", "sawedoff":
			root = ModelsShotguns.sxs(data)
		"ou_hunt":
			root = ModelsShotguns.over_under(data)
		_:
			root = _fallback(data)
	root.name = data.id
	ArmsBuilder.add_arms(root, data)
	merge(root)
	return root


## Armas nuevas sin modelo propio: el modelo más parecido de su familia.
static func _fallback(data: WeaponData) -> Node3D:
	match data.model:
		"pistol":
			return ModelsPistols.striker(data)
		"smg":
			return ModelsRifles.mp5(data)
		"rifle_ar":
			return ModelsRifles.ar(data)
		"rifle_ak":
			return ModelsRifles.ak(data)
		"bolt":
			return ModelsBolt.rimfire(data)
		"shotgun_sxs":
			return ModelsShotguns.sxs(data)
		"shotgun_ou":
			return ModelsShotguns.over_under(data)
		_:
			return ModelsRifles.fal(data)


# --- Piezas: instancias de malla --------------------------------------------

static func put(parent: Node3D, n: String, kit: MeshKit, mat: Material, pos := Vector3.ZERO, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	mi.mesh = kit.commit()
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


## Perfil lateral (z, y, r) extruido a lo ancho, centrado en x = pos.x.
static func prism(parent: Node3D, n: String, pts: Array, width: float, mat: Material, bevel := 0.002,
		pos := Vector3.ZERO, rot := Vector3.ZERO) -> MeshInstance3D:
	return put(parent, n, MeshKit.new().prism(pts, width, bevel), mat, pos, rot)


## Sección (x, y, r) extruida entre z0 y z1.
static func section(parent: Node3D, n: String, pts: Array, z0: float, z1: float, mat: Material,
		bevel := 0.002, pos := Vector3.ZERO) -> MeshInstance3D:
	return put(parent, n, MeshKit.new().section(pts, z0, z1, bevel), mat, pos)


## Torno alrededor de Z: [z, r, …] por afuera, de adelante hacia atrás.
static func lathe(parent: Node3D, n: String, pts: Array, mat: Material, pos := Vector3.ZERO,
		seg := 16, rot := Vector3.ZERO) -> MeshInstance3D:
	return put(parent, n, MeshKit.new().lathe(pts, seg), mat, pos, rot)


## Pieza con forma variable a lo largo (guardamanos, cajas): claves [t, semiancho,
## y_abajo, y_arriba, exponente], con t = 0 atrás (z_rear) y t = 1 adelante (z_front).
static func loft(parent: Node3D, n: String, mat: Material, z_rear: float, z_front: float, keys: Array,
		stations := 26, ring_n := 30, x := 0.0) -> MeshInstance3D:
	var st: Array = []
	for i in stations + 1:
		var t := float(i) / stations
		var a: Array = keys[0]
		var b: Array = keys[keys.size() - 1]
		for j in keys.size() - 1:
			if t >= float(keys[j][0]) and t <= float(keys[j + 1][0]):
				a = keys[j]
				b = keys[j + 1]
				break
		var f := 0.0 if is_equal_approx(b[0], a[0]) else clampf((t - float(a[0])) / (float(b[0]) - float(a[0])), 0.0, 1.0)
		f = f * f * (3.0 - 2.0 * f)
		var ring := MeshKit.ring(lerpf(a[1], b[1], f), lerpf(a[2], b[2], f), lerpf(a[3], b[3], f), lerpf(a[4], b[4], f), ring_n, x)
		st.append([lerpf(z_rear, z_front, t), ring])
	return put(parent, n, MeshKit.new().loft(st), mat)


## Caja con aristas redondeadas.
static func rbox(parent: Node3D, n: String, size: Vector3, pos: Vector3, mat: Material, r := 0.0015,
		rot := Vector3.ZERO) -> MeshInstance3D:
	return put(parent, n, MeshKit.new().box(Vector3.ZERO, size, r), mat, pos, rot)


## Cilindro a lo largo de Z (con "rot" se orienta: (0, PI/2, 0) → eje X; (−PI/2, 0, 0) → eje Y).
static func cyl(parent: Node3D, n: String, r: float, length: float, pos: Vector3, mat: Material,
		seg := 14, rot := Vector3.ZERO, edge := 0.0) -> MeshInstance3D:
	var h := length * 0.5
	var e := minf(edge, minf(r * 0.5, h * 0.5))
	var pts := [-h, 0.0, -h, r - e, -h + e, r, h - e, r, h, r - e, h, 0.0] if e > 0.0 else [-h, 0.0, -h, r, h, r, h, 0.0]
	return lathe(parent, n, pts, mat, pos, seg, rot)


## Tubo hueco a lo largo de Z.
static func tube(parent: Node3D, n: String, r_in: float, r_out: float, length: float, pos: Vector3,
		mat: Material, seg := 18, rot := Vector3.ZERO) -> MeshInstance3D:
	var h := length * 0.5
	return lathe(parent, n, [-h, r_in, -h, r_out, h, r_out, h, r_in, -h, r_in], mat, pos, seg, rot)


static func sphere(parent: Node3D, n: String, r: float, pos: Vector3, mat: Material, seg := 10) -> MeshInstance3D:
	var pts := [-r, 0.0]
	for i in range(1, 6):
		var a := PI * i / 6.0
		pts.append_array([-r * cos(a), r * sin(a)])
	pts.append_array([r, 0.0])
	return lathe(parent, n, pts, mat, pos, seg)


## Caño con ánima hueca en la boca. z_rear > z_front (el frente es más negativo).
## "shank": tramo trasero recto y más grueso (recámara).
static func barrel(parent: Node3D, n: String, z_rear: float, z_front: float, r_rear: float, r_front: float,
		mat: Material, bore := -1.0, pos := Vector3.ZERO, shank := 0.0, seg := 16, chamber := 0.0, chamber_depth := 0.07) -> MeshInstance3D:
	var b := bore if bore >= 0.0 else r_front * 0.42
	var pts := [z_front + 0.02, 0.0, z_front + 0.02, b, z_front, b, z_front, r_front * 0.9, z_front + 0.0015, r_front]
	if shank > 0.0:
		pts.append_array([z_rear - shank, r_rear * 0.9, z_rear - shank + 0.012, r_rear])
	if chamber > 0.0:
		# Recámara hueca (escopetas): boca achaflanada y fondo oscuro donde sigue el ánima
		pts.append_array([z_rear - 0.0012, r_rear, z_rear, r_rear - 0.0012, z_rear, chamber + 0.0012, z_rear - 0.0012, chamber,
			z_rear - chamber_depth, chamber, z_rear - chamber_depth, 0.0])
		cyl(parent, n + "Bore", chamber * 0.98, 0.004, pos + Vector3(0, 0, z_rear - chamber_depth + 0.002), WeaponModelBuilder.mat("dark"), seg)
	else:
		pts.append_array([z_rear, r_rear, z_rear, 0.0])
	return lathe(parent, n, pts, mat, pos, seg)


static func group(parent: Node3D, n: String, pos := Vector3.ZERO) -> Node3D:
	var g := Node3D.new()
	g.name = n
	g.position = pos
	parent.add_child(g)
	return g


static func marker(parent: Node3D, n: String, pos: Vector3, eye_relief := 0.0) -> void:
	var m := Marker3D.new()
	m.name = n
	m.position = pos
	if eye_relief > 0.0:
		m.set_meta("eye_relief", eye_relief)
	parent.add_child(m)


## Perno transversal (a lo ancho del arma).
static func pin(parent: Node3D, pos: Vector3, r := 0.0028, length := 0.032, mat_kind := "steel") -> void:
	cyl(parent, "Pin", r, length, pos, mat(mat_kind), 10, Vector3(0, PI * 0.5, 0))


# --- Piezas compartidas --------------------------------------------------------

## Riel Picatinny a lo largo de Z, con la base en "y" (en el espacio de xf).
static func rail(parent: Node3D, n: String, z0: float, z1: float, y: float, m: Material,
		xf := Transform3D.IDENTITY) -> void:
	var k := MeshKit.new()
	var t := xf * Transform3D(Basis.IDENTITY, Vector3(0, y, 0))
	var zmin := minf(z0, z1)
	var zmax := maxf(z0, z1)
	k.section([-0.0105, 0.0, 0.0, 0.0105, 0.0, 0.0, 0.0105, 0.0035, 0.0004, 0.0078, 0.0048, 0.0,
		-0.0078, 0.0048, 0.0, -0.0105, 0.0035, 0.0004], zmin, zmax, 0.0006, t)
	var crown := [-0.0085, 0.0044, 0.0, 0.0085, 0.0044, 0.0, 0.0085, 0.0072, 0.0005, 0.0064, 0.0095, 0.0005,
		-0.0064, 0.0095, 0.0005, -0.0085, 0.0072, 0.0005]
	var z := zmin + 0.003
	while z + 0.0052 <= zmax - 0.002:
		k.section(crown, z, z + 0.0052, 0.0006, t)
		z += 0.01
	put(parent, n, k, m)


## Guion de mira: torre desde "base_y" hasta la línea de mira "h", orejas y poste.
## El poste termina exactamente en "h".
static func front_post(parent: Node3D, z: float, base_y: float, h: float, m: Material, ears := true,
		hood := false, tower_w := 0.014, depth := 0.024) -> void:
	var d := depth * 0.5
	prism(parent, "FrontTower", [z + d, base_y, 0.002, z - d, base_y, 0.002, z - d * 0.45, h - 0.014, 0.002,
		z + d * 0.45, h - 0.014, 0.002], tower_w, m, 0.0015)
	rbox(parent, "FrontPost", Vector3(0.0032, 0.0135, 0.0034), Vector3(0, h - 0.00675, z), m, 0.0005)
	if hood:
		tube(parent, "FrontHood", 0.0078, 0.0098, 0.014, Vector3(0, h, z), m, 20)
	elif ears:
		for s: float in [-1.0, 1.0]:
			prism(parent, "Ear", [z + 0.006, h - 0.02, 0.0, z - 0.006, h - 0.02, 0.0, z - 0.0045, h + 0.004, 0.0015,
				z + 0.0045, h + 0.004, 0.0015], 0.003, m, 0.0006, Vector3(s * 0.0085, 0, 0))


## Alza de muesca: dos hojas a los lados de la línea de mira y un puente debajo.
static func rear_notch(parent: Node3D, z: float, h: float, m: Material, gap := 0.0045, base_y := -1.0) -> void:
	for s: float in [-1.0, 1.0]:
		rbox(parent, "RearBlade", Vector3(0.0042, 0.0085, 0.0045), Vector3(s * (gap + 0.0021), h - 0.0018, z), m, 0.0006)
	var by := base_y if base_y >= 0.0 else h - 0.012
	rbox(parent, "RearBridge", Vector3(gap * 2.0 + 0.0084, maxf(h - 0.0055 - by, 0.003), 0.0045),
		Vector3(0, (h - 0.0055 + by) * 0.5, z), m, 0.0006)


## Alza de anillo (diópter): anillo alrededor de la línea de mira y orejas.
static func rear_aperture(parent: Node3D, z: float, h: float, m: Material, ears := true) -> void:
	tube(parent, "Aperture", 0.0022, 0.0058, 0.004, Vector3(0, h, z), m, 18)
	if ears:
		for s: float in [-1.0, 1.0]:
			prism(parent, "RearEar", [z + 0.008, h - 0.009, 0.0, z - 0.008, h - 0.009, 0.0, z - 0.006, h + 0.006, 0.002,
				z + 0.006, h + 0.006, 0.002], 0.003, m, 0.0006, Vector3(s * 0.0085, 0, 0))


## Punto rojo tipo tubo sobre un riel. Devuelve la posición del marcador Sight.
static func red_dot(parent: Node3D, y_rail_top: float, z: float) -> Vector3:
	var m := mat("anodized")
	var y := y_rail_top + 0.031
	lathe(parent, "DotTube", [z - 0.032, 0.0158, z - 0.032, 0.0198, z - 0.026, 0.0206, z + 0.02, 0.0196, z + 0.03, 0.0196,
		z + 0.03, 0.0158, z - 0.032, 0.0158], m, Vector3(0, y, 0), 24)
	cyl(parent, "DotTurretTop", 0.0075, 0.012, Vector3(0, y + 0.024, z - 0.002), m, 14, Vector3(-PI * 0.5, 0, 0), 0.0015)
	cyl(parent, "DotTurretSide", 0.0075, 0.012, Vector3(0.024, y, z - 0.002), m, 14, Vector3(0, PI * 0.5, 0), 0.0015)
	var base_h := y - 0.0175 - y_rail_top
	rbox(parent, "DotMount", Vector3(0.026, base_h, 0.034), Vector3(0, y_rail_top + base_h * 0.5, z), m, 0.002)
	cyl(parent, "DotClamp", 0.005, 0.01, Vector3(0.016, y_rail_top + 0.004, z), m, 12, Vector3(0, PI * 0.5, 0))
	var lens := MeshInstance3D.new()
	lens.name = "Lens"
	var q := QuadMesh.new()
	q.size = Vector2(0.032, 0.032)
	lens.mesh = q
	var lm := ShaderMaterial.new()
	lm.shader = RED_DOT_SHADER
	lens.material_override = lm
	lens.position = Vector3(0, y, z - 0.015)
	lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(lens)
	return Vector3(0, y, z - 0.015)


## Visor con aumento. style: "hunting", "tactical", "pso". Montado con anillas sobre
## un riel cuya cara superior está en y_rail_top. El ocular termina en z = 0.041.
## Devuelve la posición del marcador Sight.
static func scope(parent: Node3D, data: WeaponData, y: float, y_rail_top: float, style := "hunting") -> Vector3:
	var m := mat("scope")
	var length := 0.30
	var tube_r := 0.0135
	var obj_r := 0.0215
	var eye_r := 0.0192
	var obj_len := 0.055
	var eye_len := 0.075
	var turret_r := 0.0085
	var turret_h := 0.012
	match style:
		"tactical":
			length = 0.37
			tube_r = 0.017
			obj_r = 0.0305
			eye_r = 0.0215
			obj_len = 0.075
			eye_len = 0.095
			turret_r = 0.0125
			turret_h = 0.02
		"pso":
			length = 0.33
			tube_r = 0.0128
			obj_r = 0.0165
			eye_r = 0.019
			obj_len = 0.07
			eye_len = 0.07
			turret_r = 0.011
			turret_h = 0.015
	var ze := 0.04
	var zf := ze - length
	lathe(parent, "ScopeBody", [zf, 0.0, zf, obj_r * 0.86, zf + 0.0025, obj_r, zf + obj_len, obj_r,
		zf + obj_len + 0.045, tube_r, ze - eye_len, tube_r, ze - eye_len + 0.022, eye_r * 0.94,
		ze - eye_len + 0.03, eye_r, ze - 0.004, eye_r, ze, eye_r * 0.93, ze, 0.0], m, Vector3(0, y, 0), 28)
	# Vidrio del objetivo
	lathe(parent, "ObjectiveGlass", [zf - 0.0012, 0.0, zf - 0.0012, obj_r * 0.82, zf + 0.001, obj_r * 0.82, zf + 0.001, 0.0],
		mat("glass"), Vector3(0, y, 0), 24)
	# Anillo de aumentos con estrías
	var zr := ze - eye_len + 0.034
	for i in 4:
		tube(parent, "PowerRing", eye_r - 0.002, eye_r + 0.0012, 0.003, Vector3(0, y, zr + i * 0.0065), m, 24)
	if data.scope_mag_max > data.scope_mag:
		rbox(parent, "ThrowLever", Vector3(0.004, 0.009, 0.006), Vector3(eye_r * 0.7, y + eye_r * 0.85, zr + 0.01), m, 0.001)
	# Torretas: elevación arriba, deriva a la derecha, paralaje a la izquierda (táctico)
	var zt := zf + obj_len + 0.045 + (ze - eye_len - (zf + obj_len + 0.045)) * 0.45
	rbox(parent, "Saddle", Vector3(tube_r * 2.0 + 0.006, tube_r * 2.0 + 0.006, 0.042), Vector3(0, y, zt), m, tube_r * 0.7)
	var cap := [tube_r - 0.002, 0.0, tube_r - 0.002, turret_r, tube_r + turret_h - 0.003, turret_r,
		tube_r + turret_h, turret_r - 0.002, tube_r + turret_h, 0.0]
	lathe(parent, "TurretElev", cap, m, Vector3(0, y, zt), 18, Vector3(-PI * 0.5, 0, 0))
	lathe(parent, "TurretWind", cap, m, Vector3(0, y, zt), 18, Vector3(0, PI * 0.5, 0))
	if style == "tactical":
		lathe(parent, "TurretParallax", cap, m, Vector3(0, y, zt), 18, Vector3(0, -PI * 0.5, 0))
	if style == "pso":
		# Tambor del telémetro y parasol extendido
		cyl(parent, "PsoLamp", 0.006, 0.02, Vector3(-tube_r - 0.008, y - 0.006, zt + 0.03), m, 12, Vector3(0, PI * 0.5, 0))
		lathe(parent, "Eyecup", [ze - 0.002, eye_r - 0.001, ze - 0.002, eye_r + 0.003, ze + 0.008, eye_r + 0.0045, ze + 0.012, eye_r + 0.002,
			ze + 0.012, eye_r - 0.0005, ze - 0.002, eye_r - 0.001], mat("rubber"), Vector3(0, y, 0), 22)
	# Anillas y bases al riel
	for zz: float in [ze - eye_len - 0.03, zf + obj_len + 0.06]:
		tube(parent, "Ring", tube_r - 0.0002, tube_r + 0.004, 0.017, Vector3(0, y, zz), mat("anodized"), 24)
		var h := (y - tube_r) - y_rail_top
		if h > 0.002:
			rbox(parent, "RingBase", Vector3(0.022, h + 0.004, 0.017), Vector3(0, y_rail_top + h * 0.5, zz), mat("anodized"), 0.002)
			cyl(parent, "RingNut", 0.0045, 0.008, Vector3(0.014, y_rail_top + 0.004, zz), mat("anodized"), 10,
				Vector3(0, PI * 0.5, 0))
	var lens := MeshInstance3D.new()
	lens.name = "ScopeLens"
	var q := QuadMesh.new()
	var d := 0.034
	q.size = Vector2(d, d)
	lens.mesh = q
	var sm := ShaderMaterial.new()
	sm.shader = SCOPE_SHADER
	sm.set_shader_parameter("reticle", {"cross": 0, "chevron": 1, "duplex": 2}.get(data.reticle, 2))
	lens.material_override = sm
	lens.position = Vector3(0, y, 0.041)
	lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lens.set_meta("lens_d", d)
	parent.add_child(lens)
	return Vector3(0, y, 0.04)


## Perfil de un cargador curvo: arco de radio "radius" que baja y va hacia adelante.
## El borde superior queda en y = top_y (adentro del brocal). Devuelve [perfil, centro
## de la base, ángulo de la base].
static func curved_mag_profile(top_y: float, length: float, depth_top: float, depth_bot: float, radius: float) -> Array:
	var steps := 8
	var theta := length / radius
	var back: Array = []
	var front: Array = []
	var bottom := Vector2.ZERO
	for i in steps + 1:
		var s := float(i) / steps
		var a := theta * s
		var c := Vector2(-radius * (1.0 - cos(a)), top_y - radius * sin(a))
		var nb := Vector2(cos(a), -sin(a))
		var dep := lerpf(depth_top, depth_bot, s) * 0.5
		var r := 0.002 if i == 0 or i == steps else 0.0
		back.append([c.x + nb.x * dep, c.y + nb.y * dep, r])
		front.append([c.x - nb.x * dep, c.y - nb.y * dep, r])
		bottom = c
	var pts: Array = []
	for b: Array in back:
		pts.append_array(b)
	front.reverse()
	for f: Array in front:
		pts.append_array(f)
	return [pts, bottom, theta]


## Cargador curvo con base.
static func curved_mag(parent: Node3D, top_y: float, length: float, depth_top: float, depth_bot: float,
		radius: float, width: float, m: Material, floor_mat: Material = null) -> void:
	var r := curved_mag_profile(top_y, length, depth_top, depth_bot, radius)
	prism(parent, "MagBody", r[0], width, m, 0.003)
	var bot: Vector2 = r[1]
	var ang: float = r[2]
	var fm := floor_mat if floor_mat != null else m
	rbox(parent, "MagFloor", Vector3(width + 0.004, 0.009, depth_bot + 0.006),
		Vector3(0, bot.y - 0.0025 * cos(ang), bot.x - 0.0025 * sin(ang)), fm, 0.002, Vector3(ang, 0, 0))


# --- Fusión de mallas -------------------------------------------------------------

## Funde las mallas fijas por material (y dentro de cada pieza animable).
static func merge(container: Node3D) -> void:
	var by_mat: Dictionary = {}
	var victims: Array[Node] = []
	var subgroups: Array[Node3D] = []
	_collect(container, Transform3D.IDENTITY, by_mat, victims, subgroups)
	var i := 0
	for m: Material in by_mat:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for pair: Array in by_mat[m]:
			st.append_from(pair[0], 0, pair[1])
		var mi := MeshInstance3D.new()
		mi.name = "Body%d" % i
		mi.mesh = st.commit()
		mi.material_override = m
		container.add_child(mi)
		i += 1
	for v in victims:
		v.get_parent().remove_child(v)
		v.free()
	for g in subgroups:
		merge(g)


static func _collect(node: Node, xf: Transform3D, by_mat: Dictionary, victims: Array[Node], subgroups: Array[Node3D]) -> void:
	for c in node.get_children():
		if String(c.name) in KEEP:
			continue
		if String(c.name) in GROUPS:
			subgroups.append(c as Node3D)
			continue
		if c is MeshInstance3D and c.get_child_count() == 0:
			var mi := c as MeshInstance3D
			if mi.mesh == null or mi.mesh.get_surface_count() == 0:
				victims.append(mi)
				continue
			var m := mi.material_override
			if not by_mat.has(m):
				by_mat[m] = []
			by_mat[m].append([mi.mesh, xf * mi.transform])
			victims.append(mi)
		elif c is Node3D and not (c is Marker3D):
			_collect(c, xf * (c as Node3D).transform, by_mat, victims, subgroups)


# --- Materiales -----------------------------------------------------------------

static func mat(kind: String) -> StandardMaterial3D:
	if _mats.has(kind):
		return _mats[kind]
	var m := StandardMaterial3D.new()
	match kind:
		"metal":  # acero fosfatado / pavonado mate
			m.albedo_color = Color(0.12, 0.125, 0.13)
			m.metallic = 0.6
			m.roughness = 0.5
		"steel":
			m.albedo_color = Color(0.2, 0.2, 0.21)
			m.metallic = 0.85
			m.roughness = 0.32
		"blued":
			m.albedo_color = Color(0.07, 0.08, 0.1)
			m.metallic = 0.9
			m.roughness = 0.24
		"steel_bright":  # cajón plateado de escopeta fina
			m.albedo_color = Color(0.58, 0.58, 0.6)
			m.metallic = 1.0
			m.roughness = 0.28
		"alloy":
			m.albedo_color = Color(0.15, 0.15, 0.16)
			m.metallic = 0.55
			m.roughness = 0.5
		"anodized":  # aluminio anodizado negro
			m.albedo_color = Color(0.085, 0.088, 0.092)
			m.metallic = 0.45
			m.roughness = 0.55
		"scope":
			m.albedo_color = Color(0.05, 0.05, 0.055)
			m.metallic = 0.35
			m.roughness = 0.5
		"glass":
			m.albedo_color = Color(0.05, 0.08, 0.12)
			m.metallic = 1.0
			m.roughness = 0.05
		"polymer":
			m.albedo_color = Color(0.075, 0.075, 0.072)
			m.roughness = 0.78
		"tan", "polymer_tan":
			m.albedo_color = Color(0.52, 0.45, 0.33)
			m.roughness = 0.75
		"plum":  # polímero ciruela de los cargadores soviéticos
			m.albedo_color = Color(0.3, 0.1, 0.07)
			m.roughness = 0.6
		"bakelite":
			m.albedo_color = Color(0.28, 0.1, 0.05)
			m.roughness = 0.45
		"rubber":
			m.albedo_color = Color(0.045, 0.045, 0.045)
			m.roughness = 0.95
		"dark":  # huecos, ventilaciones, ranuras
			m.albedo_color = Color(0.015, 0.015, 0.015)
			m.roughness = 1.0
		"white":
			m.albedo_color = Color(0.9, 0.9, 0.86)
			m.roughness = 0.5
		"wood":  # nogal
			_wood(m, Color(0.2, 0.1, 0.045), Color(0.42, 0.24, 0.11), 0.5)
		"wood_light":  # haya clara
			_wood(m, Color(0.36, 0.2, 0.09), Color(0.62, 0.4, 0.2), 0.42)
		"wood_ak":  # laminado rojizo
			_wood(m, Color(0.26, 0.08, 0.03), Color(0.46, 0.18, 0.07), 0.38)
		"wood_cut":  # madera recién serruchada
			_wood(m, Color(0.55, 0.4, 0.24), Color(0.72, 0.56, 0.36), 0.8)
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
		_:
			m.albedo_color = Color(1, 0, 1)
	_mats[kind] = m
	return m


## Madera con veta: ruido estirado a lo largo del arma, proyectado en 3 planos.
static func _wood(m: StandardMaterial3D, dark: Color, light: Color, rough: float) -> void:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.035
	noise.fractal_octaves = 3
	noise.seed = 7
	var g := Gradient.new()
	g.set_color(0, dark)
	g.set_color(1, light)
	var tex := NoiseTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	tex.noise = noise
	tex.color_ramp = g
	m.albedo_texture = tex
	m.albedo_color = Color.WHITE
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(9.0, 9.0, 0.8)
	m.roughness = rough
