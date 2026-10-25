class_name WeaponModelBuilder
extends RefCounted
## Modelos de armas de prueba armados con primitivas, por familia y parámetros.
## TODO-ASSET: un modelo real por arma (ver docs/ASSETS.md).
##
## Convenciones (las mismas que deben respetar los modelos reales):
##  - Metros, cañón hacia −Z, +Y arriba, eje del ánima en y = 0, origen en la empuñadura.
##  - Marcadores (Marker3D): Muzzle (boca), Sight (punto de la línea de mira; su
##    metadata "eye_relief" es la distancia ojo–mira sugerida), Ejection.
##  - Piezas animables (Node3D): Mag, Slide, Charging, Bolt, Barrels (con ShellL/ShellR).
##  - Visor: MeshInstance3D "ScopeLens" (ocular) con material de visor; metadata "lens_d".
##
## Parámetros (WeaponData.model_params), todos opcionales:
##   style: "ar" | "ak" | "battle" | "smg" | "bolt" | "dmr"
##   recv_len, recv_h, recv_w: receptor (m)
##   barrel, barrel_r: largo y radio del caño
##   hg, hg_style: guardamanos ("rail", "wood", "poly", "full_wood", "none")
##   stock: "fixed", "buffer", "folding", "wood", "none"
##   furniture: "poly", "wood", "tan"
##   mag: "straight", "curved", "helical", "short", "internal", "none"; mag_len
##   gas: tubo de gases sobre el caño
##   grip: "pistol" | "stock" (empuñadura integrada a la culata)
##   muzzle_dev: "flash", "brake", "none"
##   iron_h: altura de las miras metálicas sobre el ánima; rear_z: posición del alza

const RED_DOT_SHADER := preload("res://entities/weapons/red_dot.gdshader")
const SCOPE_SHADER := preload("res://entities/weapons/scope_lens.gdshader")

static var _mats: Dictionary = {}


static func build(data: WeaponData) -> Node3D:
	var p := data.model_params
	var root: Node3D
	match data.model:
		"pistol":
			root = _pistol(p)
		"shotgun_sxs":
			root = _shotgun_sxs(p)
		"shotgun_ou":
			root = _shotgun_ou(p)
		_:
			root = _long_gun(data.model, p, data)
	root.name = data.id
	return root


# --- Armas largas (fusiles, subfusiles, cerrojos, tiradores) --------------------

static func _long_gun(family: String, p: Dictionary, data: WeaponData) -> Node3D:
	var root := Node3D.new()
	var style: String = p.get("style", _default_style(family))
	var recv_len: float = p.get("recv_len", 0.3)
	var recv_h: float = p.get("recv_h", 0.06)
	var recv_w: float = p.get("recv_w", 0.05)
	var barrel: float = p.get("barrel", 0.4)
	var barrel_r: float = p.get("barrel_r", 0.0105)
	var hg: float = p.get("hg", 0.22)
	var furniture: String = p.get("furniture", "wood" if style in ["ak", "bolt"] else "poly")
	var fmat := _mat(furniture if furniture != "poly" else "polymer")
	var metal := _mat("metal")
	var sight_type := data.sight

	var recv_front := -recv_len + 0.06  # el receptor arranca un poco detrás del origen
	# Receptor
	var recv := _box(root, "Receiver", Vector3(recv_w, recv_h, recv_len), Vector3(0, 0.004, recv_front * 0.5 + 0.03), metal)
	if style == "ak":
		# Tapa superior redondeada del AK
		_cyl(root, "DustCover", recv_w * 0.42, recv_len * 0.85, Vector3(0, recv_h * 0.5 - 0.012, recv_front * 0.5 + 0.03), metal)
	if style in ["ar", "dmr"]:
		_box(root, "Rail", Vector3(0.024, 0.01, recv_len * 0.9), Vector3(0, recv_h * 0.5 + 0.009, recv_front * 0.5 + 0.03), metal)
		_box(root, "MagWell", Vector3(recv_w * 0.9, 0.04, 0.08), Vector3(0, -recv_h * 0.5 - 0.015, -0.07), metal)
	if style == "smg" and p.get("mag", "straight") != "helical":
		_box(root, "MagWell", Vector3(recv_w * 0.8, 0.035, 0.05), Vector3(0, -recv_h * 0.5 - 0.012, -0.09), metal)

	# Caño y boca
	var barrel_start := -recv_len + 0.03
	_cyl(root, "Barrel", barrel_r, barrel, Vector3(0, 0, barrel_start - barrel * 0.5), metal)
	var muzzle_z := barrel_start - barrel
	match p.get("muzzle_dev", "flash"):
		"flash":
			_cyl(root, "FlashHider", barrel_r * 1.5, 0.06, Vector3(0, 0, muzzle_z - 0.03), metal)
			muzzle_z -= 0.06
		"brake":
			_box(root, "Brake", Vector3(0.032, 0.026, 0.07), Vector3(0, 0, muzzle_z - 0.035), metal)
			muzzle_z -= 0.07
	if p.get("gas", style in ["ak"]):
		_cyl(root, "GasTube", barrel_r * 0.9, hg + 0.02, Vector3(0, 0.024, barrel_start - (hg + 0.02) * 0.5), metal)

	# Guardamanos
	var hg_style: String = p.get("hg_style", _default_hg(style))
	match hg_style:
		"rail":
			_box(root, "Handguard", Vector3(0.05, 0.055, hg), Vector3(0, 0.002, barrel_start - hg * 0.5), metal)
			_box(root, "HgRail", Vector3(0.022, 0.008, hg), Vector3(0, 0.032, barrel_start - hg * 0.5), metal)
		"wood", "poly":
			var hm := fmat if hg_style == "wood" else _mat("polymer")
			_box(root, "Handguard", Vector3(0.052, 0.05, hg), Vector3(0, -0.006, barrel_start - hg * 0.5), hm)
		"full_wood":
			# Caja de madera de un fusil clásico, bajo el caño
			_box(root, "Forend", Vector3(0.048, 0.04, hg), Vector3(0, -0.022, barrel_start - hg * 0.5), fmat)
		"tube":
			_cyl(root, "Handguard", 0.022, hg, Vector3(0, -0.004, barrel_start - hg * 0.5), _mat("polymer"))

	# Empuñadura, guardamonte y culata
	var grip: String = p.get("grip", "stock" if style == "bolt" else "pistol")
	_box(root, "TriggerGuard", Vector3(0.008, 0.012, 0.06), Vector3(0, -recv_h * 0.5 - 0.012, -0.015), metal)
	if grip == "pistol":
		_box(root, "Grip", Vector3(0.033, 0.11, 0.045), Vector3(0, -recv_h * 0.5 - 0.05, 0.035), _mat("polymer") if furniture != "wood" else fmat,
			Vector3(deg_to_rad(15), 0, 0))
	_build_stock(root, p.get("stock", _default_stock(style)), grip, recv_h, fmat, metal)

	# Cargador
	var mag_style: String = p.get("mag", _default_mag(style))
	var mag_len: float = p.get("mag_len", 0.13)
	if mag_style != "internal" and mag_style != "none":
		var mag := _group(root, "Mag", Vector3(0, -recv_h * 0.5 - 0.02, -0.075))
		match mag_style:
			"straight", "short":
				var ml := mag_len if mag_style == "straight" else 0.07
				_box(mag, "MagBody", Vector3(0.028, ml, 0.066), Vector3(0, -ml * 0.5, 0), metal, Vector3(deg_to_rad(-6), 0, 0))
			"curved":
				_box(mag, "MagTop", Vector3(0.03, mag_len * 0.5, 0.07), Vector3(0, -mag_len * 0.25, 0), metal, Vector3(deg_to_rad(-8), 0, 0))
				_box(mag, "MagBottom", Vector3(0.03, mag_len * 0.55, 0.07), Vector3(0, -mag_len * 0.7, -0.035), metal, Vector3(deg_to_rad(-28), 0, 0))
			"helical":
				mag.position = Vector3(0, -0.05, barrel_start - 0.02)
				_cyl(mag, "Helix", 0.03, 0.3, Vector3(0, 0, -0.1), metal)
	elif mag_style == "internal":
		_box(root, "MagBox", Vector3(0.03, 0.03, 0.08), Vector3(0, -recv_h * 0.5 - 0.012, -0.08), metal)

	# Manija de carga o cerrojo
	if style == "bolt":
		var bolt := _group(root, "Bolt", Vector3(0.0, 0.012, 0.0))
		_box(bolt, "BoltArm", Vector3(0.055, 0.008, 0.01), Vector3(0.03, 0, 0), metal)
		_sphere(bolt, "BoltKnob", 0.009, Vector3(0.058, -0.004, 0), metal)
	else:
		var ch := _group(root, "Charging", Vector3(recv_w * 0.5 + 0.004, 0.012, recv_front * 0.6))
		_box(ch, "Handle", Vector3(0.018, 0.012, 0.016), Vector3(0.006, 0, 0), metal)

	# Miras
	var sight_marker: Vector3
	var eye := 0.0
	match sight_type:
		"red_dot":
			var y := recv_h * 0.5 + 0.038
			_build_red_dot(root, y, -0.07, metal)
			sight_marker = Vector3(0, y, -0.085)
			eye = 0.24
		"scope":
			var y := recv_h * 0.5 + 0.045
			_build_scope(root, y, metal, data)
			sight_marker = Vector3(0, y, 0.04)
			eye = 0.075
		_:
			var ih: float = p.get("iron_h", 0.055 if style != "bolt" else 0.03)
			var rear_z: float = p.get("rear_z", -0.01)
			var front_z := barrel_start - barrel + 0.04
			_build_irons(root, ih, rear_z, front_z, metal, style)
			sight_marker = Vector3(0, ih, front_z)
			# Distancia ojo–guion: el ojo queda detrás del alza según el tipo de arma
			eye = -front_z + float({"ar": 0.10, "battle": 0.12, "smg": 0.16, "ak": 0.22, "bolt": 0.30}.get(style, 0.14))
	_marker(root, "Sight", sight_marker, eye)
	_marker(root, "Muzzle", Vector3(0, 0, muzzle_z))
	_marker(root, "Ejection", Vector3(recv_w * 0.5, 0.015, recv_front * 0.5))
	_hand(root, "HandR", Vector3(0.0, -recv_h * 0.5 - 0.04, 0.05), Vector3(0.05, 0.07, 0.1))
	var hand_l_z := barrel_start - hg * 0.55 if hg > 0.05 else barrel_start - 0.08
	if mag_style == "helical":
		hand_l_z = barrel_start - 0.05
	_hand(root, "HandL", Vector3(0.0, -0.05, hand_l_z), Vector3(0.066, 0.05, 0.11))
	return root


static func _build_stock(root: Node3D, stock: String, grip: String, recv_h: float, fmat: Material, metal: Material) -> void:
	match stock:
		"fixed":
			_box(root, "Stock", Vector3(0.044, 0.075, 0.24), Vector3(0, -0.018, 0.18), fmat)
			_box(root, "Butt", Vector3(0.046, 0.13, 0.03), Vector3(0, -0.04, 0.31), fmat)
		"buffer":
			_cyl(root, "Buffer", 0.016, 0.2, Vector3(0, -0.004, 0.14), metal)
			_box(root, "Stock", Vector3(0.042, 0.07, 0.12), Vector3(0, -0.025, 0.23), _mat("polymer"))
		"folding":
			_box(root, "StockTop", Vector3(0.012, 0.012, 0.24), Vector3(0, -0.005, 0.15), metal)
			_box(root, "StockBottom", Vector3(0.012, 0.012, 0.22), Vector3(0, -0.06, 0.14), metal, Vector3(deg_to_rad(-12), 0, 0))
			_box(root, "Butt", Vector3(0.03, 0.1, 0.015), Vector3(0, -0.035, 0.27), metal)
		"wood":
			if grip == "stock":
				_box(root, "Wrist", Vector3(0.038, 0.05, 0.14), Vector3(0, -recv_h * 0.5 - 0.012, 0.08), fmat, Vector3(deg_to_rad(12), 0, 0))
			_box(root, "Stock", Vector3(0.044, 0.11, 0.22), Vector3(0, -0.055, 0.24), fmat, Vector3(deg_to_rad(5), 0, 0))
			_box(root, "Butt", Vector3(0.046, 0.13, 0.015), Vector3(0, -0.065, 0.355), _mat("polymer"))


static func _build_irons(root: Node3D, h: float, rear_z: float, front_z: float, metal: Material, style: String) -> void:
	# Alza: base angosta y dos hojas finas con la muesca en el medio, a la altura
	# exacta de la línea de mira
	var base_top := h - 0.01
	_box(root, "RearBase", Vector3(0.014, maxf(base_top - 0.02, 0.004), 0.016), Vector3(0, 0.02 + (base_top - 0.02) * 0.5, rear_z), metal)
	for side: float in [-1.0, 1.0]:
		_box(root, "Rear%s" % ("L" if side < 0 else "R"), Vector3(0.004, 0.012, 0.008), Vector3(side * 0.0042, h - 0.005, rear_z), metal)
	# Guion con base y "orejas" protectoras (AR/AK/batalla)
	_box(root, "FrontBase", Vector3(0.014, h - 0.012, 0.016), Vector3(0, (h - 0.012) * 0.5 - 0.004, front_z), metal)
	_box(root, "FrontPost", Vector3(0.004, 0.012, 0.006), Vector3(0, h - 0.006, front_z), metal)
	if style != "bolt":
		for side: float in [-1.0, 1.0]:
			_box(root, "Ear%s" % ("L" if side < 0 else "R"), Vector3(0.004, 0.022, 0.012), Vector3(side * 0.011, h - 0.006, front_z), metal)


static func _build_red_dot(root: Node3D, y: float, z: float, metal: Material) -> void:
	_box(root, "DotBase", Vector3(0.03, 0.016, 0.07), Vector3(0, y - 0.02, z), metal)
	_torus(root, "DotRingRear", Vector3(0, y, z + 0.025), metal)
	_torus(root, "DotRingFront", Vector3(0, y, z - 0.028), metal)
	_box(root, "DotTop", Vector3(0.012, 0.006, 0.055), Vector3(0, y + 0.021, z), metal)
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
	root.add_child(lens)


## Visor con aumento: tubo, campanas, anillas y ocular que muestra la imagen aumentada.
static func _build_scope(root: Node3D, y: float, metal: Material, data: WeaponData) -> void:
	var dark := _mat("scope")
	var length := 0.30
	_cyl(root, "ScopeTube", 0.0135, length, Vector3(0, y, -length * 0.5 + 0.02), dark)
	_cyl(root, "ScopeObjective", 0.022, 0.07, Vector3(0, y, -length + 0.02), dark)
	_cyl(root, "ScopeEyepiece", 0.019, 0.06, Vector3(0, y, 0.01), dark)
	_box(root, "Turret", Vector3(0.016, 0.022, 0.018), Vector3(0, y + 0.02, -0.12), dark)
	for z: float in [-0.04, -0.2]:
		_box(root, "Ring", Vector3(0.032, 0.03, 0.016), Vector3(0, y - 0.02, z), metal)
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
	root.add_child(lens)


# --- Pistolas ---------------------------------------------------------------
##  style: "poly" (polímero, tipo austríaca), "steel" (acero, tipo .45), "alloy"
##  (aleación, tipo argentina 9 mm), "target22" (cañón largo y fino, .22)

static func _pistol(p: Dictionary) -> Node3D:
	var root := Node3D.new()
	var style: String = p.get("style", "poly")
	var metal := _mat("metal")
	var frame_mat := _mat("polymer") if style == "poly" else (_mat("steel") if style in ["steel", "target22"] else _mat("alloy"))
	var slide_mat := _mat("steel") if style == "steel" else metal
	var grip_mat := _mat("wood") if style == "steel" else frame_mat
	var slide_len: float = p.get("slide_len", 0.19)
	var front := -slide_len + 0.045

	_box(root, "Frame", Vector3(0.03, 0.026, slide_len - 0.025), Vector3(0, -0.006, front * 0.5 + 0.0), frame_mat)
	_box(root, "Grip", Vector3(0.031, 0.11, 0.047), Vector3(0, -0.062, 0.012), grip_mat, Vector3(deg_to_rad(p.get("grip_angle", 12.0)), 0, 0))
	_box(root, "TriggerGuard", Vector3(0.008, 0.01, 0.05), Vector3(0, -0.03, -0.035), frame_mat)

	var sight_h := 0.0445
	var sight_z := front + 0.008
	if style == "target22":
		# Pistola de tiro .22: receptor tubular y caño largo y fino, sin corredera
		_box(root, "Receiver", Vector3(0.026, 0.028, 0.12), Vector3(0, 0.022, -0.02), metal)
		_cyl(root, "Barrel", 0.009, 0.15, Vector3(0, 0.02, -0.155), metal)
		var bolt := _group(root, "Slide", Vector3.ZERO)
		_box(bolt, "BoltEars", Vector3(0.03, 0.008, 0.012), Vector3(0, 0.032, 0.03), metal)
		_box(root, "FrontSight", Vector3(0.0045, 0.014, 0.005), Vector3(0, 0.035, -0.225), metal)
		for side: float in [-1.0, 1.0]:
			_box(root, "Rear%s" % ("L" if side < 0 else "R"), Vector3(0.0075, 0.008, 0.007), Vector3(side * 0.0066, 0.0385, 0.02), metal)
		sight_h = 0.0425
		sight_z = -0.225
		_marker(root, "Muzzle", Vector3(0, 0.02, -0.235))
	else:
		_cyl(root, "BarrelTip", 0.0065, 0.02, Vector3(0, 0.02, front - 0.008), metal)
		var slide := _group(root, "Slide", Vector3.ZERO)
		_box(slide, "SlideBody", Vector3(0.028, 0.03, slide_len), Vector3(0, 0.022, front * 0.5 + 0.035), slide_mat)
		_box(slide, "FrontSight", Vector3(0.0045, 0.008, 0.005), Vector3(0, 0.0405, sight_z), metal)
		for side: float in [-1.0, 1.0]:
			_box(slide, "Rear%s" % ("L" if side < 0 else "R"), Vector3(0.0075, 0.008, 0.007), Vector3(side * 0.0066, 0.0405, 0.026), metal)
		if style == "steel":
			_box(slide, "Hammer", Vector3(0.008, 0.016, 0.012), Vector3(0, 0.03, 0.05), metal)
		_marker(root, "Muzzle", Vector3(0, 0.02, front - 0.02))

	var mag := _group(root, "Mag", Vector3(0, -0.02, 0.012))
	_box(mag, "MagBody", Vector3(0.024, 0.1, 0.034), Vector3(0, -0.045, 0), metal, Vector3(deg_to_rad(12), 0, 0))
	_marker(root, "Sight", Vector3(0, sight_h, sight_z), -sight_z + 0.40)
	_marker(root, "Ejection", Vector3(0.016, 0.03, -0.03))
	_hand(root, "HandR", Vector3(0.0, -0.065, 0.025), Vector3(0.052, 0.085, 0.065))
	_hand(root, "HandL", Vector3(-0.022, -0.075, 0.012), Vector3(0.04, 0.075, 0.06))
	return root


# --- Escopetas ---------------------------------------------------------------

## Dos caños yuxtapuestos. barrel: largo; stock: "full" o "pistol" (recortada).
static func _shotgun_sxs(p: Dictionary) -> Node3D:
	var root := Node3D.new()
	var metal := _mat("metal")
	var wood := _mat("wood")
	var blen: float = p.get("barrel", 0.62)
	_box(root, "Receiver", Vector3(0.046, 0.05, 0.09), Vector3(0, -0.013, -0.075), metal)
	_box(root, "TriggerGuard", Vector3(0.008, 0.012, 0.06), Vector3(0, -0.04, -0.02), metal)
	_box(root, "TopLever", Vector3(0.012, 0.006, 0.03), Vector3(0, 0.015, -0.035), metal)
	if p.get("stock", "full") == "full":
		_box(root, "Wrist", Vector3(0.036, 0.045, 0.17), Vector3(0, -0.05, 0.05), wood, Vector3(deg_to_rad(16), 0, 0))
		_box(root, "Stock", Vector3(0.042, 0.1, 0.2), Vector3(0, -0.1, 0.21), wood, Vector3(deg_to_rad(8), 0, 0))
	else:
		# Culata recortada: empuñadura de pistola
		_box(root, "Grip", Vector3(0.036, 0.1, 0.05), Vector3(0, -0.07, 0.03), wood, Vector3(deg_to_rad(25), 0, 0))
	var barrels := _group(root, "Barrels", Vector3(0, 0.0, -0.12))
	for side: float in [-1.0, 1.0]:
		var n := "L" if side < 0 else "R"
		_cyl(barrels, "Barrel" + n, 0.0118, blen, Vector3(side * 0.0125, 0, -blen * 0.5), metal)
		_shell(barrels, "Shell" + n, Vector3(side * 0.0125, 0, 0.025))
	_box(barrels, "Rib", Vector3(0.009, 0.007, blen - 0.02), Vector3(0, 0.0135, -blen * 0.5), metal)
	_box(barrels, "Forend", Vector3(0.05, 0.034, minf(0.2, blen * 0.5)), Vector3(0, -0.026, -minf(0.2, blen * 0.5) * 0.5 - 0.1), wood)
	_sphere(barrels, "Bead", 0.0032, Vector3(0, 0.0185, -blen + 0.015), _mat("brass"))
	_marker(root, "Sight", Vector3(0, 0.0215, -0.12 - blen + 0.015), blen + 0.12 - 0.015 + 0.155)
	_marker(root, "Muzzle", Vector3(0, 0.0, -0.12 - blen - 0.01))
	_marker(root, "Ejection", Vector3(0, 0.0, -0.11))
	_hand(root, "HandR", Vector3(0.0, -0.05, 0.05), Vector3(0.05, 0.07, 0.1))
	_hand(root, "HandL", Vector3(0.0, -0.055, -0.12 - minf(0.2, blen * 0.5) * 0.6), Vector3(0.066, 0.05, 0.11))
	return root


## Dos caños superpuestos (escopeta de caza).
static func _shotgun_ou(p: Dictionary) -> Node3D:
	var root := Node3D.new()
	var metal := _mat("steel")
	var wood := _mat("wood_light")
	var blen: float = p.get("barrel", 0.76)
	_box(root, "Receiver", Vector3(0.04, 0.066, 0.09), Vector3(0, -0.026, -0.075), metal)
	_box(root, "TriggerGuard", Vector3(0.008, 0.012, 0.06), Vector3(0, -0.06, -0.02), metal)
	_box(root, "TopLever", Vector3(0.012, 0.006, 0.03), Vector3(0, 0.017, -0.035), metal)
	_box(root, "Wrist", Vector3(0.034, 0.045, 0.17), Vector3(0, -0.06, 0.05), wood, Vector3(deg_to_rad(16), 0, 0))
	_box(root, "Stock", Vector3(0.04, 0.11, 0.22), Vector3(0, -0.115, 0.22), wood, Vector3(deg_to_rad(8), 0, 0))
	var barrels := _group(root, "Barrels", Vector3(0, 0.0, -0.12))
	# Caño superior en y = 0 (el ánima de referencia), inferior debajo
	var names := ["L", "R"]
	var ys := [0.0, -0.025]
	for i in 2:
		_cyl(barrels, "Barrel" + names[i], 0.0118, blen, Vector3(0, ys[i], -blen * 0.5), metal)
		_shell(barrels, "Shell" + names[i], Vector3(0, ys[i], 0.025))
	_box(barrels, "Rib", Vector3(0.008, 0.005, blen - 0.02), Vector3(0, 0.0145, -blen * 0.5), metal)
	_box(barrels, "Forend", Vector3(0.044, 0.03, 0.22), Vector3(0, -0.045, -0.2), wood)
	_sphere(barrels, "Bead", 0.003, Vector3(0, 0.019, -blen + 0.015), _mat("brass"))
	_marker(root, "Sight", Vector3(0, 0.022, -0.12 - blen + 0.015), blen + 0.12 - 0.015 + 0.155)
	_marker(root, "Muzzle", Vector3(0, -0.012, -0.12 - blen - 0.01))
	_marker(root, "Ejection", Vector3(0, -0.01, -0.11))
	_hand(root, "HandR", Vector3(0.0, -0.06, 0.05), Vector3(0.05, 0.07, 0.1))
	_hand(root, "HandL", Vector3(0.0, -0.07, -0.33), Vector3(0.066, 0.05, 0.11))
	return root


# --- Defaults por familia ------------------------------------------------------

static func _default_style(family: String) -> String:
	match family:
		"rifle_ar":
			return "ar"
		"rifle_ak":
			return "ak"
		"smg":
			return "smg"
		"bolt":
			return "bolt"
		_:
			return "battle"


static func _default_hg(style: String) -> String:
	match style:
		"ar", "dmr":
			return "rail"
		"ak":
			return "wood"
		"bolt":
			return "full_wood"
		"smg":
			return "tube"
		_:
			return "poly"


static func _default_stock(style: String) -> String:
	match style:
		"ar", "dmr", "smg":
			return "buffer"
		"ak", "bolt":
			return "wood"
		_:
			return "fixed"


static func _default_mag(style: String) -> String:
	match style:
		"ak":
			return "curved"
		"bolt":
			return "internal"
		_:
			return "straight"


# --- Primitivas -------------------------------------------------------------

static func _group(parent: Node3D, n: String, pos: Vector3) -> Node3D:
	var g := Node3D.new()
	g.name = n
	g.position = pos
	parent.add_child(g)
	return g


static func _box(parent: Node3D, n: String, size: Vector3, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	var m := BoxMesh.new()
	m.size = size
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


## Cilindro a lo largo del eje Z.
static func _cyl(parent: Node3D, n: String, radius: float, length: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	var m := CylinderMesh.new()
	m.top_radius = radius
	m.bottom_radius = radius
	m.height = length
	m.radial_segments = 12
	m.rings = 1
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	mi.rotation = Vector3(deg_to_rad(90), 0, 0)
	parent.add_child(mi)
	return mi


static func _torus(parent: Node3D, n: String, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	var m := TorusMesh.new()
	m.inner_radius = 0.0165
	m.outer_radius = 0.022
	m.rings = 16
	m.ring_segments = 8
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	mi.rotation = Vector3(deg_to_rad(90), 0, 0)
	parent.add_child(mi)
	return mi


static func _sphere(parent: Node3D, n: String, radius: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = 8
	m.rings = 4
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


static func _shell(parent: Node3D, n: String, pos: Vector3) -> void:
	var shell := _group(parent, n, pos)
	_cyl(shell, "Hull", 0.0105, 0.05, Vector3(0, 0, -0.01), _mat("shell_red"))
	_cyl(shell, "Base", 0.0112, 0.012, Vector3(0, 0, 0.02), _mat("brass"))
	shell.visible = false


static func _marker(parent: Node3D, n: String, pos: Vector3, eye_relief := 0.0) -> void:
	var m := Marker3D.new()
	m.name = n
	m.position = pos
	if eye_relief > 0.0:
		m.set_meta("eye_relief", eye_relief)
	parent.add_child(m)


## Mano de guante simple (placeholder de los brazos). TODO-ASSET: fps_arms
static func _hand(parent: Node3D, n: String, pos: Vector3, size: Vector3) -> void:
	var h := _box(parent, n, size, pos, _mat("glove"))
	_box(h, "Forearm", Vector3(size.x * 0.85, size.y * 0.8, 0.3), Vector3(0, -0.04, 0.18), _mat("sleeve"),
		Vector3(deg_to_rad(-18), 0, 0))


static func _mat(kind: String) -> StandardMaterial3D:
	if _mats.has(kind):
		return _mats[kind]
	var m := StandardMaterial3D.new()
	match kind:
		"metal":
			m.albedo_color = Color(0.13, 0.135, 0.14)
			m.metallic = 0.65
			m.roughness = 0.42
		"steel":
			m.albedo_color = Color(0.2, 0.2, 0.21)
			m.metallic = 0.85
			m.roughness = 0.3
		"alloy":
			m.albedo_color = Color(0.17, 0.17, 0.18)
			m.metallic = 0.6
			m.roughness = 0.5
		"scope":
			m.albedo_color = Color(0.06, 0.06, 0.065)
			m.metallic = 0.3
			m.roughness = 0.55
		"polymer":
			m.albedo_color = Color(0.085, 0.085, 0.08)
			m.roughness = 0.75
		"tan":
			m.albedo_color = Color(0.55, 0.47, 0.34)
			m.roughness = 0.7
		"wood":
			m.albedo_color = Color(0.36, 0.21, 0.1)
			m.roughness = 0.55
		"wood_light":
			m.albedo_color = Color(0.5, 0.32, 0.16)
			m.roughness = 0.45
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
	_mats[kind] = m
	return m
