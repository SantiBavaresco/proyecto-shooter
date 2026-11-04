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
				"backpack_small", "backpack_large":
					var big := item.id == "backpack_large"
					var c2 := Color(0.33, 0.32, 0.22)
					_box(root, Vector3(0.3, 0.16, 0.4 if big else 0.32), Vector3(0, 0.08, 0), _m(c2, 0.95), 0.04)
					_box(root, Vector3(0.24, 0.07, 0.16), Vector3(0, 0.19, 0.06), _m(c2.darkened(0.12), 0.95), 0.03)
					_box(root, Vector3(0.05, 0.03, 0.3 if big else 0.24), Vector3(-0.09, 0.17, -0.04), _m(Color(0.12, 0.12, 0.1), 0.9), 0.01)
					_box(root, Vector3(0.05, 0.03, 0.3 if big else 0.24), Vector3(0.09, 0.17, -0.04), _m(Color(0.12, 0.12, 0.1), 0.9), 0.01)
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
