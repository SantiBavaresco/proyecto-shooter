class_name GlbWeapon
extends RefCounted
## Armas con modelo .glb (solo el arma, sin brazos): el modelo reemplaza a la
## geometría por código pero el resto es igual que en las armas por código:
## piezas animables (Mag, Charging, Bolt, Slide, Cylinder...), marcadores (Sight,
## Muzzle, Ejection) y manos (ArmsBuilder, con la pose de la empuñadura y el
## guardamanos del arma). Así las recargas, montar, trabas y manos funcionan igual.
##
## model_params (shape = "glb"):
##  - scene: ruta del .glb.
##  - rot: giro del modelo en grados (euler) para que el caño quede hacia −Z y arriba +Y.
##  - scale: escala (metros). offset: corrimiento final (el origen va cerca de la empuñadura).
##  - hide: textos; las mallas cuyo camino (nombre de la malla, sus padres o el hueso al
##    que están pegadas) contiene alguno se descartan (cargadores de repuesto, miras...).
##  - parts: {"Mag": [textos], "Charging": [...], ...}: mallas que van a cada pieza.
##  - pivots: {"Mag": [x, y, z], ...}: origen de cada pieza (marco del arma).
##  - metas: {"Charging": {"knob": [x, y, z]}, "Bolt": {"knob": ...}, "Mag": {"grab": ...}}.
##  - sight, eye_relief, muzzle, ejection: marcadores.
##  - pose: pose de las manos (como ArmsBuilder.POSES).
##  - shift: [{"match": [textos], "by": [x, y, z]}]: corre piezas que vienen despegadas.
##  - scope_lens: {"pos", "d"}: ocular del visor. dot_lens: {"pos", "size"}: punto rojo.
##  - shells: {"L": [x, y, z], "R": ...}: cartuchos de las escopetas de quiebre (relativos
##    al grupo "Barrels", que gira sobre su origen = la bisagra).
##
## Las mallas con esqueleto (armas de juegos, con huesos por pieza) se pasan a mallas
## fijas por hueso al cargar (una vez por archivo).

static var _baked: Dictionary = {}
## Escenas cargadas (si nadie las retiene, Godot las descarga y cada arma nueva las
## volvería a leer del disco).
static var _scenes: Dictionary = {}


static func scene(path: String) -> PackedScene:
	if not _scenes.has(path):
		_scenes[path] = load(path)
	return _scenes[path]


static func build(data: WeaponData) -> Node3D:
	var p := data.model_params
	var root := Node3D.new()
	root.name = data.id
	var model := Node3D.new()
	model.name = "Model"
	var rot: Array = p.get("rot", [0, 0, 0])
	var sc := float(p.get("scale", 1.0))
	model.transform = Transform3D(Basis.from_euler(Vector3(deg_to_rad(float(rot[0])), deg_to_rad(float(rot[1])),
		deg_to_rad(float(rot[2]))), EULER_ORDER_YXZ).scaled(Vector3.ONE * sc), _v(p.get("offset", [0, 0, 0])))
	root.add_child(model)
	var inst := scene(String(p["scene"])).instantiate() as Node3D
	inst.name = "Inst"
	model.add_child(inst)
	_bake_skinned(inst, String(p["scene"]))
	# Piezas animables
	var parts: Dictionary = p.get("parts", {})
	var pivots: Dictionary = p.get("pivots", {})
	var groups := {}
	for part: String in parts:
		var g := WeaponModelBuilder.group(root, part, _v(pivots.get(part, [0, 0, 0])))
		groups[part] = g
	var hide: Array = p.get("hide", [])
	var shifts: Array = p.get("shift", [])
	for mi: MeshInstance3D in inst.find_children("*", "MeshInstance3D", true, false):
		var key := _key(mi, inst)
		if _matches(key, hide):
			mi.get_parent().remove_child(mi)
			mi.free()
			continue
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Piezas que el archivo trae despegadas (visores y rieles "explotados")
		for sh: Dictionary in shifts:
			if _matches(key, sh["match"]):
				var xf0 := _rel(mi, root)
				var par := mi.get_parent() as Node3D
				mi.transform = _rel(par, root).affine_inverse() * Transform3D(xf0.basis, xf0.origin + _v(sh["by"]))
		for part: String in parts:
			if _matches(key, parts[part]):
				var xf := _rel(mi, root)
				mi.owner = null
				mi.get_parent().remove_child(mi)
				var g: Node3D = groups[part]
				g.add_child(mi)
				mi.transform = g.transform.affine_inverse() * xf
				break
	# Escopetas de quiebre: cartuchos que se ven al recargar (en el grupo Barrels)
	if p.has("shells") and root.has_node("Barrels"):
		var shells: Dictionary = p["shells"]
		for sn: String in shells:
			ModelsShotguns._shell(root.get_node("Barrels") as Node3D, "Shell" + sn, _v(shells[sn]))
	var metas: Dictionary = p.get("metas", {})
	for part: String in metas:
		var n := root.get_node_or_null(part) as Node3D
		if n == null:
			continue
		for k: String in metas[part]:
			var val: Variant = metas[part][k]
			n.set_meta(k, _v(val) if val is Array else val)
	# Ocular del visor (la imagen con aumento) o vidrio del punto rojo
	if p.has("scope_lens"):
		var sl: Dictionary = p["scope_lens"]
		var lens := MeshInstance3D.new()
		lens.name = "ScopeLens"
		var q := QuadMesh.new()
		var d := float(sl.get("d", 0.034))
		q.size = Vector2(d, d)
		lens.mesh = q
		var sm := ShaderMaterial.new()
		sm.shader = WeaponModelBuilder.SCOPE_SHADER
		sm.set_shader_parameter("reticle", {"cross": 0, "chevron": 1, "duplex": 2}.get(data.reticle, 2))
		lens.material_override = sm
		lens.position = _v(sl["pos"])
		lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		lens.set_meta("lens_d", d)
		root.add_child(lens)
	if p.has("dot_lens"):
		var dl: Dictionary = p["dot_lens"]
		var dot := MeshInstance3D.new()
		dot.name = "Lens"
		var q2 := QuadMesh.new()
		q2.size = Vector2.ONE * float(dl.get("size", 0.03))
		dot.mesh = q2
		var lm := ShaderMaterial.new()
		lm.shader = WeaponModelBuilder.RED_DOT_SHADER
		if bool(dl.get("holo", false)):
			# Holográfica: ventana rectangular, anillo y punto
			lm.set_shader_parameter("holo", true)
			lm.set_shader_parameter("dot_radius", 0.0012)
		dot.material_override = lm
		dot.position = _v(dl["pos"])
		dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(dot)
	WeaponModelBuilder.marker(root, "Sight", _v(p.get("sight", [0, 0.05, -0.2])), float(p.get("eye_relief", 0.3)))
	WeaponModelBuilder.marker(root, "Muzzle", _v(p.get("muzzle", [0, 0, -0.5])))
	WeaponModelBuilder.marker(root, "Ejection", _v(p.get("ejection", [0.015, 0.0, -0.05])))
	return root


static func _v(a: Variant) -> Vector3:
	if a is Vector3:
		return a
	var arr: Array = a
	return Vector3(float(arr[0]), float(arr[1]), float(arr[2]))


static func _matches(key: String, rules: Array) -> bool:
	for r: String in rules:
		if key.contains(r.to_lower()):
			return true
	return false


## Camino de nombres de la malla (y del hueso si viene de una malla con esqueleto).
static func _key(mi: Node, top: Node) -> String:
	var s := String(mi.get_meta("bone", "")).to_lower()
	var n := mi
	while n != null and n != top:
		s += "/" + String(n.name).to_lower()
		n = n.get_parent()
	return s


## Transformación de un nodo respecto de un ancestro (sin estar en el árbol).
static func _rel(n: Node3D, top: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var c: Node = n
	while c != null and c != top:
		if c is Node3D:
			xf = (c as Node3D).transform * xf
		c = c.get_parent()
	return xf


## Mallas con esqueleto → mallas fijas, una por hueso (en la pose de reposo).
static func _bake_skinned(inst: Node3D, cache_key: String) -> void:
	var skinned: Array[MeshInstance3D] = []
	for mi: MeshInstance3D in inst.find_children("*", "MeshInstance3D", true, false):
		if mi.skin != null and mi.mesh != null:
			skinned.append(mi)
	if skinned.is_empty():
		return
	if not _baked.has(cache_key):
		var pieces: Array = []
		for mi in skinned:
			var sk := mi.get_node_or_null(mi.skeleton) as Skeleton3D
			if sk == null:
				sk = mi.get_parent() as Skeleton3D
			if sk == null:
				continue
			var to_inst := _rel(sk, inst)
			var by_bone := {}  # hueso → {material → SurfaceTool}
			for s in mi.mesh.get_surface_count():
				var arr := mi.mesh.surface_get_arrays(s)
				var mat := mi.get_surface_override_material(s)
				if mat == null:
					mat = mi.mesh.surface_get_material(s)
				var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
				var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL] if arr[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
				var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV] if arr[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
				var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
				var weights: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
				var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
				var per := bones.size() / maxi(verts.size(), 1)
				# Hueso dominante y transformación de cada vértice
				var vb := PackedInt32Array()
				vb.resize(verts.size())
				var xfs := {}
				for i in verts.size():
					var best := 0
					for k in range(1, per):
						if weights[i * per + k] > weights[i * per + best]:
							best = k
					var b := bones[i * per + best]
					vb[i] = b
					if not xfs.has(b):
						var bi := mi.skin.get_bind_bone(b)
						if bi < 0:
							bi = sk.find_bone(mi.skin.get_bind_name(b))
						xfs[b] = to_inst * sk.get_bone_global_pose(bi) * mi.skin.get_bind_pose(b)
				if idx.is_empty():
					idx.resize(verts.size())
					for i in verts.size():
						idx[i] = i
				for t in range(0, idx.size(), 3):
					var b0 := vb[idx[t]]
					if not by_bone.has(b0):
						by_bone[b0] = {}
					var mats: Dictionary = by_bone[b0]
					if not mats.has(mat):
						var st := SurfaceTool.new()
						st.begin(Mesh.PRIMITIVE_TRIANGLES)
						mats[mat] = st
					var st2: SurfaceTool = mats[mat]
					for k in 3:
						var i := idx[t + k]
						var xf: Transform3D = xfs[vb[i]]
						if not norms.is_empty():
							st2.set_normal((xf.basis * norms[i]).normalized())
						if not uvs.is_empty():
							st2.set_uv(uvs[i])
						st2.add_vertex(xf * verts[i])
			for b: int in by_bone:
				var bi2 := mi.skin.get_bind_bone(b)
				var bname: String = sk.get_bone_name(bi2) if bi2 >= 0 else String(mi.skin.get_bind_name(b))
				var am := ArrayMesh.new()
				var mats2: Dictionary = by_bone[b]
				for m: Material in mats2:
					var st3: SurfaceTool = mats2[m]
					st3.generate_tangents()
					st3.commit(am)
					am.surface_set_material(am.get_surface_count() - 1, m)
				pieces.append([bname, String(mi.name), am])
		_baked[cache_key] = pieces
	for mi in skinned:
		mi.get_parent().remove_child(mi)
		mi.free()
	for piece: Array in _baked[cache_key]:
		var nm := MeshInstance3D.new()
		nm.name = "%s_%s" % [piece[1], piece[0]]
		nm.mesh = piece[2]
		nm.set_meta("bone", piece[0])
		inst.add_child(nm)
