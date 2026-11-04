class_name ItemModels
extends RefCounted
## Modelos 3D por código de los ítems (en el suelo y para los íconos del inventario).
## Medidas reales aproximadas, en metros. El origen queda en la base del objeto.

## Color de la caja de munición por calibre.
const AMMO_COLORS := {
	"9×19": Color(0.55, 0.42, 0.22), "9×18": Color(0.5, 0.36, 0.2), ".45 ACP": Color(0.32, 0.38, 0.5),
	".22 LR": Color(0.7, 0.2, 0.15), "5.45×39": Color(0.3, 0.4, 0.26), "5.56×45": Color(0.26, 0.34, 0.24),
	"7.62×39": Color(0.42, 0.36, 0.2), "7.62×51": Color(0.3, 0.32, 0.22), "7.62×54R": Color(0.38, 0.3, 0.2),
	"7.65×53": Color(0.45, 0.32, 0.25), "12/70": Color(0.62, 0.15, 0.12),
}

static var _mats: Dictionary = {}


static func _m(c: Color, rough := 0.7, metal := 0.0) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f" % [c.to_html(), rough, metal]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = rough
		m.metallic = metal
		_mats[key] = m
	return _mats[key]


static func build(item: ItemData) -> Node3D:
	var root := Node3D.new()
	root.name = item.id
	match item.kind:
		"weapon":
			var w := item.weapon()
			if w != null:
				var g := display_weapon(w)
				# Acostada de costado, caño hacia +X, apoyada en el piso
				g.basis = Basis(Vector3(0, 1, 0), Vector3(0, 0, -1), Vector3(-1, 0, 0))
				root.add_child(g)
				var box := local_aabb(root)
				if box.size.z > box.size.x:
					# Modelo importado con otra orientación de reposo: lo largo, a lo ancho
					g.basis = Basis(Vector3.UP, -PI * 0.5) * g.basis
					box = local_aabb(root)
				g.position = Vector3(-box.get_center().x, -box.position.y, -box.get_center().z)
		"ammo":
			_ammo(root, item)
		"mag":
			_mag(root, item)
		"sight", "muzzle":
			var g2 := WeaponAttach.item_model(item)
			root.add_child(g2)
			var box2 := local_aabb(root)
			g2.position = Vector3(-box2.get_center().x, -box2.position.y, -box2.get_center().z)
		"rig":
			_rig(root, item)
		_ when item.model_path != "" and ResourceLoader.exists(item.model_path):
			# Modelo .glb: apoyado en el piso y centrado
			var g := (GlbWeapon.scene(item.model_path).instantiate() as Node3D)
			g.scale = Vector3.ONE * item.model_scale
			root.add_child(g)
			var box := local_aabb(root)
			g.position = Vector3(-box.get_center().x, -box.position.y, -box.get_center().z)
		_:
			match item.id:
				"knife":
					# Hoja y mango acostados, punta hacia +X
					var steel := _m(Color(0.62, 0.63, 0.65), 0.3, 0.9)
					_box(root, Vector3(0.16, 0.005, 0.03), Vector3(0.07, 0.004, 0), steel, 0.002)
					_box(root, Vector3(0.025, 0.006, 0.026), Vector3(0.16, 0.004, -0.002), steel, 0.002).rotation = Vector3(0, 0.75, 0)
					_box(root, Vector3(0.012, 0.014, 0.06), Vector3(-0.015, 0.007, 0), _m(Color(0.2, 0.2, 0.2), 0.5, 0.6), 0.002)
					_box(root, Vector3(0.12, 0.022, 0.026), Vector3(-0.085, 0.011, 0), _m(Color(0.1, 0.1, 0.09), 0.85), 0.008)
				"bandage":
					_cyl(root, 0.03, 0.055, Vector3(0, 0.03, 0), _m(Color(0.92, 0.9, 0.84), 0.95), Vector3(PI * 0.5, 0, 0))
					_cyl(root, 0.012, 0.056, Vector3(0, 0.03, 0), _m(Color(0.75, 0.72, 0.66), 0.95), Vector3(PI * 0.5, 0, 0))
				"medkit":
					_box(root, Vector3(0.16, 0.05, 0.1), Vector3(0, 0.025, 0), _m(Color(0.88, 0.88, 0.86), 0.6))
					_box(root, Vector3(0.06, 0.004, 0.018), Vector3(0, 0.051, 0), _m(Color(0.8, 0.1, 0.1), 0.5))
					_box(root, Vector3(0.018, 0.004, 0.06), Vector3(0, 0.051, 0), _m(Color(0.8, 0.1, 0.1), 0.5))
				"medkit_army":
					_box(root, Vector3(0.22, 0.08, 0.15), Vector3(0, 0.04, 0), _m(Color(0.3, 0.34, 0.22), 0.85))
					_box(root, Vector3(0.23, 0.012, 0.155), Vector3(0, 0.07, 0), _m(Color(0.24, 0.27, 0.18), 0.85))
					_box(root, Vector3(0.07, 0.004, 0.022), Vector3(0, 0.082, 0), _m(Color(0.75, 0.12, 0.1), 0.5))
					_box(root, Vector3(0.022, 0.004, 0.07), Vector3(0, 0.082, 0), _m(Color(0.75, 0.12, 0.1), 0.5))
				"energy_drink":
					_cyl(root, 0.026, 0.155, Vector3(0, 0.0775, 0), _m(Color(0.1, 0.55, 0.85), 0.3, 0.6))
					_cyl(root, 0.0262, 0.05, Vector3(0, 0.09, 0), _m(Color(0.95, 0.85, 0.1), 0.35, 0.3))
					_cyl(root, 0.02, 0.006, Vector3(0, 0.158, 0), _m(Color(0.75, 0.75, 0.78), 0.3, 0.9))
				"water":
					_cyl(root, 0.035, 0.22, Vector3(0, 0.11, 0), _m(Color(0.45, 0.65, 0.85), 0.15, 0.1))
					_cyl(root, 0.0355, 0.07, Vector3(0, 0.12, 0), _m(Color(0.9, 0.92, 0.95), 0.6))
					_cyl(root, 0.014, 0.025, Vector3(0, 0.232, 0), _m(Color(0.15, 0.35, 0.8), 0.5))
				"canned_meat":
					_cyl(root, 0.042, 0.075, Vector3(0, 0.0375, 0), _m(Color(0.6, 0.6, 0.62), 0.35, 0.8))
					_cyl(root, 0.0425, 0.05, Vector3(0, 0.0375, 0), _m(Color(0.65, 0.2, 0.12), 0.6))
				"bread":
					_box(root, Vector3(0.15, 0.055, 0.075), Vector3(0, 0.03, 0), _m(Color(0.66, 0.44, 0.22), 0.9), 0.02)
				"helmet_steel":
					var h := MeshInstance3D.new()
					var sm := SphereMesh.new()
					sm.radius = 0.13
					sm.height = 0.26
					sm.is_hemisphere = true
					h.mesh = sm
					h.material_override = _m(Color(0.27, 0.31, 0.22), 0.75, 0.3)
					h.scale = Vector3(1.0, 0.85, 1.12)
					root.add_child(h)
					_cyl(root, 0.135, 0.012, Vector3(0, 0.006, 0), _m(Color(0.22, 0.25, 0.18), 0.75, 0.3))
				"vest_light", "vest_plate":
					var c := Color(0.3, 0.33, 0.24) if item.id == "vest_light" else Color(0.18, 0.2, 0.16)
					_box(root, Vector3(0.42, 0.06, 0.5), Vector3(0, 0.03, 0), _m(c, 0.9), 0.02)
					_box(root, Vector3(0.3, 0.035, 0.34), Vector3(0, 0.075, 0.02), _m(c.darkened(0.15), 0.9), 0.015)
					for i in 3:
						_box(root, Vector3(0.09, 0.03, 0.12), Vector3(-0.11 + i * 0.11, 0.105, 0.14), _m(c.darkened(0.25), 0.9), 0.01)
				"backpack_small", "backpack_medium", "backpack_large", "backpack_expedition":
					# Más grande cuanto más grilla tiene
					var g: Array = item.grids[0] if not item.grids.is_empty() else [0, 0, 4, 5]
					var k := sqrt(float(g[2]) * float(g[3]) / 30.0)
					var c2: Color = {"backpack_small": Color(0.33, 0.32, 0.22), "backpack_medium": Color(0.28, 0.3, 0.22),
						"backpack_large": Color(0.3, 0.27, 0.2), "backpack_expedition": Color(0.22, 0.26, 0.24)}[item.id]
					var L := 0.34 * k
					var W := 0.3 * minf(k, 1.2)
					_box(root, Vector3(W, 0.16, L), Vector3(0, 0.08, 0), _m(c2, 0.95), 0.04)
					_box(root, Vector3(W * 0.8, 0.07, L * 0.4), Vector3(0, 0.19, L * 0.15), _m(c2.darkened(0.12), 0.95), 0.03)
					for sx: float in [-1.0, 1.0]:
						_box(root, Vector3(0.05, 0.03, L * 0.75), Vector3(sx * W * 0.3, 0.17, -L * 0.1), _m(Color(0.12, 0.12, 0.1), 0.9), 0.01)
					if k > 1.1:
						# Bolsillos laterales y bolsa de dormir arriba
						for sx2: float in [-1.0, 1.0]:
							_box(root, Vector3(0.06, 0.12, L * 0.45), Vector3(sx2 * (W * 0.5 + 0.03), 0.07, 0), _m(c2.darkened(0.08), 0.95), 0.02)
						_cyl(root, 0.06, W * 0.95, Vector3(0, 0.12, -L * 0.5 - 0.05), _m(Color(0.18, 0.2, 0.17), 0.95), Vector3(0, 0, PI * 0.5))
				"cash":
					for i in 3:
						_box(root, Vector3(0.156, 0.012, 0.066), Vector3(0, 0.006 + i * 0.012, 0), _m(Color(0.45, 0.55, 0.38), 0.85), 0.002)
					_box(root, Vector3(0.02, 0.038, 0.068), Vector3(0, 0.019, 0), _m(Color(0.75, 0.68, 0.45), 0.8), 0.002)
				"scrap_electronics":
					_box(root, Vector3(0.18, 0.012, 0.11), Vector3(0, 0.006, 0), _m(Color(0.15, 0.4, 0.2), 0.6))
					for i in 4:
						_box(root, Vector3(0.025, 0.012, 0.02), Vector3(-0.06 + i * 0.04, 0.018, (i % 2) * 0.03), _m(Color(0.1, 0.1, 0.1), 0.5))
				"tools_basic":
					_box(root, Vector3(0.36, 0.13, 0.17), Vector3(0, 0.065, 0), _m(Color(0.65, 0.18, 0.12), 0.6, 0.4), 0.01)
					_cyl(root, 0.012, 0.2, Vector3(0, 0.16, 0), _m(Color(0.15, 0.15, 0.15), 0.5), Vector3(0, 0, PI * 0.5))
				_:
					_box(root, Vector3(0.12, 0.08, 0.12), Vector3(0, 0.04, 0), _m(Color(0.5, 0.5, 0.45)))
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		mi.layers = 1
	return root


## Cargador: el del arma de referencia de su familia (los de más capacidad, más
## largos), acostado.
static var _mag_models: Dictionary = {}


## Cargadores por código (los que no salen bien del modelo del arma): [largo, ancho] (m).
const MAG_SHAPES := {"pist_9x19": [0.13, 0.033], "pist_45": [0.12, 0.034], "pist_22": [0.11, 0.028],
	"mp5": [0.2, 0.04], "sten": [0.24, 0.036], "p91": [0.22, 0.036], "vityaz": [0.21, 0.05], "stanag": [0.19, 0.062],
	"fal": [0.17, 0.07], "g3": [0.18, 0.068], "m14": [0.16, 0.07], "sr25": [0.15, 0.07], "svd": [0.12, 0.085],
	"sr22": [0.1, 0.045]}


static func _mag(root: Node3D, item: ItemData) -> void:
	var fam := item.mag_family
	if MAG_SHAPES.has(fam):
		_mag_box(root, item)
		return
	if not _mag_models.has(fam):
		var mag_node: Node3D = null
		var ref := ItemDB.family_ref(fam)
		var wd := load("res://data/weapons/%s.tres" % ref) as WeaponData if ref != "" else null
		if wd != null:
			var wm := WeaponModelBuilder.build(wd)
			var mn := wm.get_node_or_null("Mag") as Node3D
			if mn != null and not mn.find_children("*", "MeshInstance3D", true, false).is_empty():
				mag_node = Node3D.new()
				for mi: MeshInstance3D in mn.find_children("*", "MeshInstance3D", true, false):
					var copy := mi.duplicate() as MeshInstance3D
					copy.transform = GlbWeapon._rel(mi, mn)
					mag_node.add_child(copy)
			wm.free()
		_mag_models[fam] = mag_node
	var src := _mag_models[fam] as Node3D
	var g := Node3D.new()
	root.add_child(g)
	if src != null:
		var m := src.duplicate() as Node3D
		# Los de más capacidad, más largos (a lo alto del cargador)
		var std := ItemDB.get_item(String(ItemDB.family_mags(fam)[0]))
		m.scale = Vector3(1.0, pow(float(item.capacity) / float(std.capacity), 0.55), 1.0)
		g.add_child(m)
	else:
		_box(g, Vector3(0.025, 0.16, 0.06), Vector3(0, 0, 0), _m(Color(0.15, 0.15, 0.14), 0.6, 0.4), 0.004)
	# Acostado de costado, con lo largo (alto del cargador) hacia Z
	g.basis = Basis(Vector3.UP, PI * 0.5) * Basis(Vector3.BACK, PI * 0.5)
	var box := local_aabb(root)
	g.position = Vector3(-box.get_center().x, -box.position.y, -box.get_center().z)


## Cargador recto acostado: cuerpo, base y los labios con un cartucho asomando.
static func _mag_box(root: Node3D, item: ItemData) -> void:
	var sh: Array = MAG_SHAPES[item.mag_family]
	var std := ItemDB.get_item(String(ItemDB.family_mags(item.mag_family)[0]))
	var length := float(sh[0]) * pow(float(item.capacity) / float(std.capacity), 0.55)
	var width := float(sh[1])
	var col := Color(0.2, 0.21, 0.22) if item.mag_family in ["stanag", "sr25", "sr22"] else Color(0.1, 0.105, 0.11)
	var t := 0.026 if not item.mag_family.begins_with("pist") else 0.02
	# Acostado con lo largo hacia Z (en el ícono queda parado, como su casilla)
	_box(root, Vector3(width, t, length), Vector3(0, t * 0.5, 0), _m(col, 0.55, 0.5), 0.003)
	_box(root, Vector3(width + 0.006, t + 0.004, 0.012), Vector3(0, t * 0.5, length * 0.5 + 0.004), _m(col.darkened(0.3), 0.6, 0.4), 0.002)
	_cyl(root, 0.0045, 0.03, Vector3(-width * 0.15, t * 0.6, -length * 0.5 - 0.004), _m(Color(0.78, 0.6, 0.28), 0.35, 0.85),
		Vector3(PI * 0.5, 0, 0))


## Chaleco táctico: el chaleco con un porta-cargador por grilla de 1×2 y bolsillos.
static func _rig(root: Node3D, item: ItemData) -> void:
	var c: Color = {"rig_light": Color(0.36, 0.35, 0.25), "rig_medium": Color(0.27, 0.3, 0.22),
		"rig_assault": Color(0.2, 0.22, 0.18)}.get(item.id, Color(0.3, 0.3, 0.24))
	_box(root, Vector3(0.4, 0.04, 0.46), Vector3(0, 0.02, 0), _m(c, 0.95), 0.015)
	var mags := 0
	var pockets := 0
	for g: Array in item.grids:
		if int(g[2]) == 1 and int(g[3]) == 2:
			mags += 1
		else:
			pockets += 1
	var w := 0.36 / maxf(mags, 1)
	for i in mags:
		var x := -0.18 + w * (i + 0.5)
		_box(root, Vector3(w * 0.85, 0.06, 0.15), Vector3(x, 0.07, 0.1), _m(c.darkened(0.15), 0.95), 0.008)
		_box(root, Vector3(w * 0.85, 0.012, 0.05), Vector3(x, 0.105, 0.05), _m(c.darkened(0.3), 0.95), 0.004)
	var pw := 0.36 / maxf(pockets, 1)
	for i in pockets:
		_box(root, Vector3(pw * 0.8, 0.05, 0.11), Vector3(-0.18 + pw * (i + 0.5), 0.06, -0.12), _m(c.darkened(0.22), 0.95), 0.01)


## Caja de cartuchos con una banda de color y algunos cartuchos encima.
static func _ammo(root: Node3D, item: ItemData) -> void:
	var c: Color = AMMO_COLORS.get(item.caliber, Color(0.4, 0.35, 0.25))
	var shot := item.caliber == "12/70"
	var size := Vector3(0.11, 0.06, 0.075) if not shot else Vector3(0.12, 0.075, 0.09)
	_box(root, size, Vector3(0, size.y * 0.5, 0), _m(Color(0.72, 0.64, 0.48), 0.9), 0.003)
	_box(root, Vector3(size.x + 0.002, size.y * 0.4, size.z + 0.002), Vector3(0, size.y * 0.5, 0), _m(c, 0.8), 0.002)
	# Cartuchos sueltos encima
	var brass := _m(Color(0.78, 0.6, 0.28), 0.35, 0.85)
	var hull := _m(Color(0.7, 0.12, 0.1), 0.6)
	for i in 3:
		var x := -0.03 + i * 0.03
		if shot:
			_cyl(root, 0.0105, 0.07, Vector3(x, size.y + 0.0105, 0), hull, Vector3(0, 0, PI * 0.5))
			_cyl(root, 0.0108, 0.016, Vector3(x - 0.027, size.y + 0.0105, 0), brass, Vector3(0, 0, PI * 0.5))
		else:
			_cyl(root, 0.0055, 0.04, Vector3(x, size.y + 0.0055, 0), brass, Vector3(PI * 0.5, 0, 0))


static func _box(parent: Node3D, size: Vector3, pos: Vector3, m: Material, r := 0.0) -> MeshInstance3D:
	if r > 0.0:
		return WeaponModelBuilder.rbox(parent, "Box", size, pos, m, r)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi


static func _cyl(parent: Node3D, r: float, h: float, pos: Vector3, m: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 20
	mi.mesh = cm
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


## Arma para mostrar (sin brazos ni manos, visor sin imagen).
static func display_weapon(data: WeaponData) -> Node3D:
	if String(data.model_params.get("shape", "")) == "imported":
		# El .glb importado solo se ve bien animado (brazos y arma en un esqueleto):
		# para mostrarlo quieto se usa el AR-74 por código acortado (tipo AKS-74U)
		var d2 := (load("res://data/weapons/ak74.tres") as WeaponData).duplicate() as WeaponData
		d2.model_params = d2.model_params.duplicate()
		d2.model_params["barrel"] = 0.21
		d2.model_params["hg"] = 0.12
		data = d2
	var m := WeaponModelBuilder.build(data)
	# Con la mira de fábrica (si es un accesorio)
	WeaponAttach.apply_model(m, data, WeaponAttach.sight_of(data, {}), "")
	for n in ["HandR", "HandL", "HookR", "HookL", "HookP", "Arms", "SkinnedArms"]:
		var h := m.find_child(n, true, false)
		if h != null:
			h.get_parent().remove_child(h)
			h.free()
	var lens := m.get_node_or_null("ScopeLens") as MeshInstance3D
	if lens != null and lens.material_override is ShaderMaterial:
		var mat := (lens.material_override as ShaderMaterial).duplicate() as ShaderMaterial
		mat.set_shader_parameter("active", 0.0)
		lens.material_override = mat
	return m


## Caja que envuelve las mallas, en coordenadas del nodo "top".
static func local_aabb(top: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for c in top.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		if not mi.visible or mi.mesh == null:
			continue
		var xf := Transform3D.IDENTITY
		var n: Node = mi
		while n != top and n != null:
			xf = (n as Node3D).transform * xf
			n = n.get_parent()
		var b := xf * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box
