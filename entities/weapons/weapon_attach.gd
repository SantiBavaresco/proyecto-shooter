class_name WeaponAttach
extends RefCounted
## Accesorios de las armas: miras (sobre el riel o montaje del arma) y silenciadores
## (en la boca). Las definiciones están en data/items/attachments.json.
##
##  - apply_data(): copia de los datos del arma con la mira puesta (tipo de mira,
##    aumento, distancia al ojo).
##  - apply_model(): agrega al modelo la mira (con su soporte, vidrio y la línea de
##    mira en el marcador "Sight") y el silenciador (hijo del marcador "Muzzle").


## Mira y silenciador que tiene un arma según su estado (si el estado no dice nada,
## la mira de fábrica).
static func sight_of(w: WeaponData, st: Dictionary) -> String:
	if st.has("sight"):
		return String(st["sight"])
	return String(ItemDB.mount(w.id).get("default", ""))


static func muzzle_of(st: Dictionary) -> String:
	return String(st.get("muzzle", ""))


## Datos con los que se arma el modelo: con mira montada, las armas que lo piden
## ("no_rear" en el montaje) se arman sin el alza (si no, tapa la mira o la obliga
## a ir muy alta).
## Las que tienen miras plegables ("fold_irons") las pliegan sobre el riel.
static func model_data(base: WeaponData, sight_id: String) -> WeaponData:
	var mt := ItemDB.mount(base.id)
	var no_rear := bool(mt.get("no_rear", false))
	var fold := bool(mt.get("fold_irons", false))
	if sight_id == "" or not (no_rear or fold):
		return base
	var d := base.duplicate() as WeaponData
	d.model_params = base.model_params.duplicate(true)
	if no_rear:
		d.model_params["no_rear"] = true
	if fold:
		d.model_params["irons_folded"] = true
	return d


## Datos del arma con la mira puesta.
static func apply_data(base: WeaponData, sight_id: String) -> WeaponData:
	var it := ItemDB.get_item(sight_id) if sight_id != "" else null
	if it == null or ItemDB.mount(base.id).is_empty():
		return base
	var a := it.attach
	var d := base.duplicate() as WeaponData
	d.sight = String(a.get("type", "red_dot"))
	d.eye_relief = float(a.get("eye_relief", 0.25))
	if d.sight == "scope":
		d.scope_mag = float(a.get("mag", 4.0))
		d.scope_mag_max = 0.0
		d.reticle = String(a.get("reticle", "duplex"))
		d.ads_fov_mult = 1.0
	else:
		d.scope_mag = 0.0
		d.scope_mag_max = 0.0
	return d


## Agrega la mira y el silenciador al modelo del arma.
static func apply_model(root: Node3D, base: WeaponData, sight_id: String, muzzle_id: String) -> void:
	var mt := ItemDB.mount(base.id)
	var opt := ItemDB.get_item(sight_id) if sight_id != "" else null
	if opt != null and not mt.is_empty():
		var a := opt.attach
		var rail := GlbWeapon._v(mt["rail"])
		# En su arma de origen la mira queda con el tono original (combina con esa arma)
		var node := optic_node(sight_id, String(a.get("source", "")) != base.id)
		node.position = rail
		root.add_child(node)
		# Soporte entre el cajón y la mira
		var riser := float(mt.get("riser", 0.0))
		if riser > 0.001:
			WeaponModelBuilder.rbox(root, "OpticMount", Vector3(0.024, riser, 0.06),
				rail + Vector3(0, -riser * 0.5, 0), WeaponModelBuilder.mat("anodized"), 0.002)
		# Línea de mira: el marcador pasa a la mira
		var sight := root.get_node_or_null("Sight") as Node3D
		if sight != null:
			sight.position = rail + GlbWeapon._v(a.get("sight", [0, 0.03, 0]))
			sight.set_meta("eye_relief", float(a.get("eye_relief", 0.25)))
		# El vidrio queda en la raíz del modelo (el visor lo busca por nombre)
		for n: String in ["Lens", "ScopeLens"]:
			var l := node.find_child(n, true, false) as Node3D
			if l != null and root.get_node_or_null(n) == null:
				var xf := GlbWeapon._rel(l, root)
				l.get_parent().remove_child(l)
				l.transform = xf
				root.add_child(l)
	var sup := ItemDB.get_item(muzzle_id) if muzzle_id != "" else null
	if sup != null and ItemDB.thread_of(base) == String(sup.attach.get("thread", "")):
		var mz := root.get_node_or_null("Muzzle") as Node3D
		if mz != null:
			mz.add_child(suppressor_node(muzzle_id))


## Modelo de una mira, con la base en el origen. Se arma cada vez (duplicar un nodo
## que viene de un .glb lo vuelve a instanciar entero, con las piezas que se sacaron);
## lo caro (pasar las mallas con huesos a mallas fijas) ya queda guardado.
static func optic_node(id: String, tinted := true) -> Node3D:
	var n := _build_optic(id, tinted)
	n.name = "Optic"
	return n


static func _build_optic(id: String, tinted := true) -> Node3D:
	var it := ItemDB.get_item(id)
	var a := it.attach
	var root := Node3D.new()
	root.name = "Optic"
	var scene := String(a.get("scene", "code"))
	var base := GlbWeapon._v(a.get("base", [0, 0, 0]))
	if scene == "code":
		WeaponModelBuilder.red_dot(root, 0.0, 0.0)
	elif scene == "code_acog":
		_acog(root)
	elif scene == "code_elcan":
		_elcan(root)
	elif scene == "code_pso":
		# Visor del DR-1 con su montura lateral (va solo en esa arma, en sus coordenadas)
		var d := WeaponData.new()
		d.reticle = String(a.get("reticle", "chevron"))
		d.scope_mag = float(a.get("mag", 4.0))
		ModelsRifles.pso(root, d)
	else:
		# Las piezas "keep" del .glb, alineadas como en su arma
		var model := Node3D.new()
		var rot: Array = a.get("rot", [0, 0, 0])
		model.transform = Transform3D(Basis.from_euler(Vector3(deg_to_rad(float(rot[0])), deg_to_rad(float(rot[1])),
			deg_to_rad(float(rot[2]))), EULER_ORDER_YXZ).scaled(Vector3.ONE * float(a.get("scale", 1.0))),
			GlbWeapon._v(a.get("offset", [0, 0, 0])) - base)
		root.add_child(model)
		var inst := GlbWeapon.scene(scene).instantiate() as Node3D
		model.add_child(inst)
		GlbWeapon._bake_skinned(inst, scene)
		var keep: Array = a.get("keep", [])
		for mi: MeshInstance3D in inst.find_children("*", "MeshInstance3D", true, false):
			if not GlbWeapon._matches(GlbWeapon._key(mi, inst), keep):
				mi.get_parent().remove_child(mi)
				mi.free()
			else:
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				if tinted:
					_tint(mi, float(a.get("tint", 1.0)), float(a.get("rough", 1.0)))
		for n in inst.find_children("*", "Skeleton3D", true, false):
			if n.find_children("*", "MeshInstance3D", true, false).is_empty():
				n.get_parent().remove_child(n)
				n.free()
	if a.has("lens"):
		var dl: Dictionary = a["lens"]
		var dot := MeshInstance3D.new()
		dot.name = "Lens"
		var q := QuadMesh.new()
		q.size = Vector2.ONE * float(dl.get("size", 0.03))
		dot.mesh = q
		var lm := ShaderMaterial.new()
		lm.shader = WeaponModelBuilder.RED_DOT_SHADER
		if bool(dl.get("holo", false)):
			lm.set_shader_parameter("holo", true)
			lm.set_shader_parameter("dot_radius", 0.0012)
		dot.material_override = lm
		dot.position = GlbWeapon._v(dl["pos"])
		dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(dot)
	if a.has("scope_lens"):
		var sl: Dictionary = a["scope_lens"]
		var lens := MeshInstance3D.new()
		lens.name = "ScopeLens"
		var d := float(sl.get("d", 0.034))
		var q2 := QuadMesh.new()
		q2.size = Vector2(d, d)
		lens.mesh = q2
		var sm := ShaderMaterial.new()
		sm.shader = WeaponModelBuilder.SCOPE_SHADER
		sm.set_shader_parameter("reticle", {"cross": 0, "chevron": 1, "duplex": 2}.get(String(a.get("reticle", "duplex")), 2))
		lens.material_override = sm
		lens.position = GlbWeapon._v(sl["pos"])
		lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		lens.set_meta("lens_d", d)
		root.add_child(lens)
	return root


## Oscurece la textura de una mira para que el negro combine con el pavonado de las
## armas (las texturas de los modelos vienen con negros más grises y mates).
static var _tinted: Dictionary = {}


static func _tint(mi: MeshInstance3D, k: float, rough: float) -> void:
	if is_equal_approx(k, 1.0) and rough >= 1.0:
		return
	for i in mi.mesh.get_surface_count():
		var mat := mi.get_active_material(i) as BaseMaterial3D
		if mat == null:
			continue
		var key := "%d|%.2f|%.2f" % [mat.get_instance_id(), k, rough]
		if not _tinted.has(key):
			var m2 := mat.duplicate() as BaseMaterial3D
			m2.albedo_color = Color(m2.albedo_color.r * k, m2.albedo_color.g * k, m2.albedo_color.b * k, m2.albedo_color.a)
			m2.roughness = minf(m2.roughness, rough)
			m2.metallic = maxf(m2.metallic, 0.3)
			_tinted[key] = m2
		mi.set_surface_override_material(i, _tinted[key])


## Visor compacto tipo ACOG: tubo que se ensancha hacia adelante, carcasa arriba con
## la fibra óptica verde, torretas y montura con tuerca.
static func _acog(root: Node3D) -> void:
	var m := WeaponModelBuilder.mat("anodized")
	var y := 0.032
	WeaponModelBuilder.rbox(root, "AcogMount", Vector3(0.026, 0.012, 0.05), Vector3(0, 0.006, 0.005), m, 0.002)
	WeaponModelBuilder.cyl(root, "AcogNut", 0.006, 0.01, Vector3(0.018, 0.007, 0.005), m, 12, Vector3(0, PI * 0.5, 0), 0.002)
	WeaponModelBuilder.rbox(root, "AcogNeck", Vector3(0.022, 0.02, 0.07), Vector3(0, 0.018, 0.0), m, 0.004)
	WeaponModelBuilder.lathe(root, "AcogBody", [0.058, 0.0, 0.058, 0.0155, 0.05, 0.0165, 0.035, 0.016, 0.0, 0.0175,
		-0.04, 0.0195, -0.058, 0.021, -0.062, 0.021, -0.062, 0.0], m, Vector3(0, y, 0), 24)
	WeaponModelBuilder.rbox(root, "AcogTop", Vector3(0.03, 0.016, 0.075), Vector3(0, y + 0.013, -0.002), m, 0.006)
	var fiber := StandardMaterial3D.new()
	fiber.albedo_color = Color(0.2, 0.7, 0.2)
	fiber.emission_enabled = true
	fiber.emission = Color(0.15, 0.6, 0.1)
	WeaponModelBuilder.cyl(root, "AcogFiber", 0.0035, 0.065, Vector3(0, y + 0.023, -0.005), fiber, 10)
	for sx: float in [-1.0, 1.0]:
		WeaponModelBuilder.cyl(root, "AcogTurret", 0.006, 0.008, Vector3(sx * 0.02, y, 0.0), m, 12, Vector3(0, PI * 0.5, 0), 0.0015)


## Visor tipo Elcan Specter: objetivo grande, tapa plana arriba con alza y guion de
## respaldo, palanca de aumento al costado y base larga.
static func _elcan(root: Node3D) -> void:
	var m := WeaponModelBuilder.mat("anodized")
	var y := 0.035
	WeaponModelBuilder.rbox(root, "ElcanBase", Vector3(0.032, 0.014, 0.08), Vector3(0, 0.007, 0.0), m, 0.003)
	WeaponModelBuilder.rbox(root, "ElcanNeck", Vector3(0.024, 0.02, 0.09), Vector3(0, 0.02, 0.0), m, 0.004)
	WeaponModelBuilder.lathe(root, "ElcanBody", [0.07, 0.0, 0.07, 0.019, 0.055, 0.02, 0.0, 0.02, -0.05, 0.021,
		-0.065, 0.026, -0.08, 0.026, -0.08, 0.0], m, Vector3(0, y, 0), 24)
	WeaponModelBuilder.rbox(root, "ElcanTop", Vector3(0.032, 0.01, 0.1), Vector3(0, y + 0.022, -0.005), m, 0.003)
	WeaponModelBuilder.rbox(root, "ElcanPost", Vector3(0.004, 0.012, 0.004), Vector3(0, y + 0.033, -0.048), m, 0.001)
	WeaponModelBuilder.rbox(root, "ElcanRear", Vector3(0.014, 0.01, 0.005), Vector3(0, y + 0.032, 0.04), m, 0.0015)
	WeaponModelBuilder.rbox(root, "ElcanLever", Vector3(0.005, 0.012, 0.035), Vector3(0.023, y - 0.004, 0.01), m, 0.002,
		Vector3(0, 0, 0.3))


## Silenciador: cilindro con anillos, desde la boca hacia adelante (−Z).
static func suppressor_node(id: String) -> Node3D:
	var a := ItemDB.get_item(id).attach
	var r := float(a.get("radius", 0.018))
	var length := float(a.get("length", 0.17))
	var root := Node3D.new()
	root.name = "Suppressor"
	var m := WeaponModelBuilder.mat("anodized")
	if String(a.get("shape", "")) == "osprey":
		# Tipo Osprey: sección rectangular con bordes muy redondeados y el caño arriba
		# (el cuerpo baja, así no tapa las miras)
		var w := r * 2.1
		var h := r * 2.7
		WeaponModelBuilder.rbox(root, "SupBody", Vector3(w, h, length), Vector3(0, -h * 0.5 + r * 1.05, -length * 0.5 + 0.004),
			m, w * 0.42)
		WeaponModelBuilder.rbox(root, "SupCap", Vector3(w + 0.002, h + 0.002, 0.012), Vector3(0, -h * 0.5 + r * 1.05, -length + 0.01),
			WeaponModelBuilder.mat("metal"), w * 0.42)
		WeaponModelBuilder.cyl(root, "SupMount", r * 0.75, 0.02, Vector3(0, 0, 0.004), WeaponModelBuilder.mat("metal"), 14)
		return root
	WeaponModelBuilder.cyl(root, "SupBody", r, length, Vector3(0, 0, -length * 0.5 + 0.004), m, 18, Vector3.ZERO, r * 0.25)
	for z: float in [-0.012, -length + 0.02]:
		WeaponModelBuilder.cyl(root, "SupRing", r + 0.0012, 0.008, Vector3(0, 0, z), WeaponModelBuilder.mat("metal"), 18)
	return root


## Modelo suelto de un accesorio (para el piso y los íconos): apoyado en el piso,
## a lo largo de X.
static func item_model(it: ItemData) -> Node3D:
	var n := optic_node(it.id) if it.kind == "sight" else suppressor_node(it.id)
	for l: String in ["Lens", "ScopeLens"]:
		var x := n.find_child(l, true, false)
		if x != null:
			x.get_parent().remove_child(x)
			x.free()
	var g := Node3D.new()
	g.add_child(n)
	n.rotation = Vector3(0, PI * 0.5, 0)
	return g
