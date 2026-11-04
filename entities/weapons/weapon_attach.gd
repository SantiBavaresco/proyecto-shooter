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
static func model_data(base: WeaponData, sight_id: String) -> WeaponData:
	var mt := ItemDB.mount(base.id)
	if sight_id == "" or not bool(mt.get("no_rear", false)):
		return base
	var d := base.duplicate() as WeaponData
	d.model_params = base.model_params.duplicate(true)
	d.model_params["no_rear"] = true
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


## Silenciador: cilindro con anillos, desde la boca hacia adelante (−Z).
static func suppressor_node(id: String) -> Node3D:
	var a := ItemDB.get_item(id).attach
	var r := float(a.get("radius", 0.018))
	var length := float(a.get("length", 0.17))
	var root := Node3D.new()
	root.name = "Suppressor"
	var m := WeaponModelBuilder.mat("anodized")
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
