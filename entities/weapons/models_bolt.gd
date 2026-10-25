class_name ModelsBolt
extends RefCounted
## Rifles de cerrojo. El grupo "Bolt" tiene su origen sobre el eje del cerrojo:
## el controlador lo gira (levantar la manija) y lo lleva hacia atrás.



static func _bolt_group(root: Node3D, z: float, handle_len: float, drop: float, sweep: float, knob_r: float,
		m: Material, shroud: bool) -> void:
	var b := WeaponModelBuilder.group(root, "Bolt", Vector3(0, 0, z))
	WeaponModelBuilder.cyl(b, "BoltBody", 0.0092, 0.11, Vector3(0, 0, -0.05), WeaponModelBuilder.mat("steel"), 14)
	var end := Vector3(0.012 + handle_len, -drop, sweep)
	var mid := (Vector3(0.008, 0, 0) + end) * 0.5
	var dir := end - Vector3(0.008, 0, 0)
	var arm := WeaponModelBuilder.rbox(b, "BoltArm", Vector3(dir.length(), 0.0075, 0.0085), mid, m, 0.0025)
	arm.rotation = Vector3(0, -atan2(dir.z, dir.x), atan2(dir.y, Vector2(dir.x, dir.z).length()))
	WeaponModelBuilder.sphere(b, "BoltKnob", knob_r, end + Vector3(0.003, -0.002, 0), m, 12)
	b.set_meta("knob", end + Vector3(0.003, -0.002, 0))
	if shroud:
		WeaponModelBuilder.lathe(b, "Shroud", [0.0, 0.0, 0.0, 0.0118, 0.026, 0.0108, 0.034, 0.0068, 0.036, 0.0], m, Vector3(0, 0, 0.012), 16)


## R-700 (tipo Remington 700 con culata táctica y visor variable).
static func rem700(data: WeaponData) -> Node3D:
	var root := Node3D.new()
	var bl := WeaponModelBuilder.mat("blued")
	var poly := WeaponModelBuilder.mat("polymer")
	var rf := -0.085
	WeaponModelBuilder.lathe(root, "Receiver", [rf, 0.0, rf, 0.0172, 0.07, 0.0172, 0.075, 0.0155, 0.075, 0.0], bl, Vector3.ZERO, 22)
	WeaponModelBuilder.rbox(root, "Port", Vector3(0.003, 0.013, 0.052), Vector3(0.0158, 0.006, -0.008), WeaponModelBuilder.mat("dark"), 0.003)
	WeaponModelBuilder.rbox(root, "RecoilLug", Vector3(0.03, 0.03, 0.006), Vector3(0, -0.006, rf + 0.004), bl, 0.003)
	WeaponModelBuilder.rail(root, "ScopeBase", rf + 0.004, 0.07, 0.0168, WeaponModelBuilder.mat("anodized"))
	_bolt_group(root, 0.05, 0.034, 0.016, 0.012, 0.0098, bl, true)
	# Caño pesado
	var bz := rf - float(data.model_params.get("barrel", 0.6))
	WeaponModelBuilder.barrel(root, "Barrel", rf, bz, 0.0155, 0.0118, bl, 0.0045, Vector3.ZERO, 0.05)
	# Culata táctica de polímero con empuñadura casi vertical
	WeaponModelBuilder.prism(root, "Stock", [-0.46, -0.006, 0.006, -0.46, -0.04, 0.014, -0.3, -0.05, 0.04, -0.09, -0.055, 0.01, 0.03, -0.058, 0.008,
		0.045, -0.064, 0.012, 0.075, -0.128, 0.012, 0.106, -0.136, 0.008, 0.104, -0.1, 0.02, 0.135, -0.075, 0.03, 0.25, -0.1, 0.05,
		0.372, -0.13, 0.006, 0.374, -0.008, 0.006, 0.26, 0.004, 0.03, 0.15, 0.002, 0.03, 0.1, -0.012, 0.012, 0.08, -0.01, 0.0,
		-0.09, -0.008, 0.0], 0.048, poly, 0.011)
	WeaponModelBuilder.prism(root, "ButtPad", [0.372, -0.006, 0.004, 0.392, -0.006, 0.004, 0.392, -0.132, 0.004, 0.372, -0.132, 0.004], 0.05,
		WeaponModelBuilder.mat("rubber"), 0.004)
	WeaponModelBuilder.rbox(root, "Floorplate", Vector3(0.03, 0.004, 0.07), Vector3(0, -0.057, -0.045), bl, 0.0015)
	_guard(root, -0.012, 0.046, -0.057, 0.025, bl)
	_trigger(root, 0.012, -0.057, bl)
	for z: float in [-0.4, 0.33]:
		WeaponModelBuilder.cyl(root, "SlingStud", 0.004, 0.012, Vector3(0, -0.05 if z < 0 else -0.122, z), WeaponModelBuilder.mat("steel"), 10, Vector3(-PI * 0.5, 0, 0))
	var sight := WeaponModelBuilder.scope(root, data, 0.06, 0.0263, "tactical")
	WeaponModelBuilder.marker(root, "Sight", sight, 0.075)
	WeaponModelBuilder.marker(root, "Muzzle", Vector3(0, 0, bz))
	WeaponModelBuilder.marker(root, "Ejection", Vector3(0.016, 0.008, -0.01))
	return root


## Argentino 1909 (tipo Mauser 1909): caja larga, guardamanos, abrazaderas y bayoneta.
static func mauser(data: WeaponData) -> Node3D:
	var root := Node3D.new()
	var p := data.model_params
	var bl := WeaponModelBuilder.mat("blued")
	var wood := WeaponModelBuilder.mat("wood")
	var ih: float = p.get("iron_h", 0.032)
	var rf := -0.08
	# Cajón: anillo delantero, cuerpo, puente trasero con guías del peine
	WeaponModelBuilder.lathe(root, "Receiver", [rf, 0.0, rf, 0.0178, -0.03, 0.0178, -0.026, 0.0156, 0.04, 0.0156, 0.044, 0.0166, 0.07, 0.0166,
		0.074, 0.014, 0.074, 0.0], bl, Vector3.ZERO, 20)
	for s: float in [-1.0, 1.0]:
		WeaponModelBuilder.rbox(root, "ClipGuide", Vector3(0.004, 0.008, 0.012), Vector3(s * 0.0075, 0.019, 0.056), bl, 0.001)
	WeaponModelBuilder.rbox(root, "Tang", Vector3(0.012, 0.004, 0.06), Vector3(0, -0.004, 0.1), bl, 0.002)
	_bolt_group(root, 0.045, 0.045, 0.002, 0.0, 0.0092, bl, true)
	WeaponModelBuilder.prism(root, "SafetyFlag", [0.072, 0.012, 0.0, 0.082, 0.012, 0.0, 0.086, 0.022, 0.002, 0.076, 0.024, 0.002], 0.004, bl, 0.0008)
	# Caño escalonado
	var bz := rf - float(p.get("barrel", 0.74))
	WeaponModelBuilder.lathe(root, "Barrel", [bz + 0.02, 0.0, bz + 0.02, 0.0042, bz, 0.0042, bz, 0.0088, bz + 0.002, 0.0094, -0.4, 0.0108, -0.395, 0.0118,
		-0.2, 0.0128, -0.195, 0.0138, rf, 0.0146, rf, 0.0], bl, Vector3.ZERO, 16)
	# Alza de hoja y guion de grano de cebada
	var z_rear := -0.098
	WeaponModelBuilder.prism(root, "RearBase", [-0.088, 0.0125, 0.002, -0.158, 0.0125, 0.002, -0.162, 0.018, 0.002, -0.088, 0.02, 0.002], 0.026, bl, 0.0015)
	WeaponModelBuilder.prism(root, "RearLeaf", [-0.156, 0.02, 0.0, -0.152, 0.022, 0.001, z_rear - 0.002, ih - 0.008, 0.001, z_rear + 0.002, ih - 0.01, 0.0,
		-0.1, 0.02, 0.0], 0.02, bl, 0.0008)
	WeaponModelBuilder.rear_notch(root, z_rear, ih, bl, 0.004, ih - 0.011)
	var z_fs := bz + 0.02
	WeaponModelBuilder.lathe(root, "FsBase", [z_fs - 0.012, 0.0, z_fs - 0.012, 0.0112, z_fs + 0.014, 0.0112, z_fs + 0.014, 0.0], bl, Vector3.ZERO, 14)
	WeaponModelBuilder.prism(root, "FrontBlade", [z_fs + 0.009, 0.01, 0.0, z_fs - 0.007, 0.01, 0.0, z_fs - 0.0018, ih, 0.0, z_fs + 0.0018, ih, 0.0],
		0.0028, bl, 0.0005)
	# Caja de nogal y guardamanos superior
	WeaponModelBuilder.prism(root, "Stock", [-0.66, 0.002, 0.004, -0.66, -0.024, 0.008, -0.3, -0.032, 0.02, -0.105, -0.034, 0.0, -0.1, -0.052, 0.005,
		0.0, -0.052, 0.01, 0.05, -0.05, 0.02, 0.14, -0.07, 0.04, 0.38, -0.14, 0.008, 0.39, -0.14, 0.0, 0.39, -0.02, 0.006,
		0.25, -0.01, 0.03, 0.12, -0.012, 0.03, 0.074, -0.004, 0.008, 0.074, 0.0, 0.0], 0.04, wood, 0.009)
	WeaponModelBuilder.loft(root, "UpperHandguard", wood, -0.17, -0.6, [[0.0, 0.0138, -0.002, 0.0158, 2.2], [1.0, 0.0126, -0.002, 0.015, 2.2]])
	WeaponModelBuilder.prism(root, "ButtPlate", [0.388, -0.019, 0.003, 0.398, -0.019, 0.003, 0.398, -0.141, 0.003, 0.388, -0.141, 0.003], 0.042, bl, 0.002)
	# Abrazadera intermedia y punta de caja con tetón de bayoneta
	WeaponModelBuilder.rbox(root, "Band", Vector3(0.044, 0.05, 0.014), Vector3(0, -0.009, -0.4), bl, 0.007)
	WeaponModelBuilder.rbox(root, "NoseCap", Vector3(0.042, 0.044, 0.03), Vector3(0, -0.009, -0.665), bl, 0.006)
	WeaponModelBuilder.rbox(root, "BayonetLug", Vector3(0.008, 0.012, 0.03), Vector3(0, -0.033, -0.665), bl, 0.002)
	WeaponModelBuilder.cyl(root, "CleaningRod", 0.0034, 0.07, Vector3(0, -0.019, -0.7), WeaponModelBuilder.mat("steel"), 8)
	WeaponModelBuilder.sphere(root, "RodKnob", 0.0048, Vector3(0, -0.019, -0.736), WeaponModelBuilder.mat("steel"), 8)
	# Guardamonte y chapa del cargador interno
	WeaponModelBuilder.rbox(root, "Floorplate", Vector3(0.026, 0.004, 0.08), Vector3(0, -0.052, -0.055), bl, 0.0015)
	_guard(root, -0.014, 0.04, -0.052, 0.024, bl)
	_trigger(root, 0.008, -0.052, bl)
	WeaponModelBuilder.marker(root, "Sight", Vector3(0, ih, z_fs), 0.30 - z_fs)
	WeaponModelBuilder.marker(root, "Muzzle", Vector3(0, 0, bz))
	WeaponModelBuilder.marker(root, "Ejection", Vector3(0.016, 0.008, 0.0))
	return root


## Rifle de cerrojo .22 de caza: caja deportiva de haya, cargador corto desmontable.
static func rimfire(data: WeaponData) -> Node3D:
	var root := Node3D.new()
	var p := data.model_params
	var bl := WeaponModelBuilder.mat("blued")
	var wood := WeaponModelBuilder.mat("wood_light")
	var ih: float = p.get("iron_h", 0.03)
	var rf := -0.07
	WeaponModelBuilder.lathe(root, "Receiver", [rf, 0.0, rf, 0.0135, 0.058, 0.0135, 0.062, 0.012, 0.062, 0.0], bl, Vector3.ZERO, 20)
	WeaponModelBuilder.rbox(root, "Port", Vector3(0.003, 0.01, 0.04), Vector3(0.0124, 0.005, -0.005), WeaponModelBuilder.mat("dark"), 0.002)
	for i in 2:
		WeaponModelBuilder.rbox(root, "Dovetail", Vector3(0.012, 0.0025, 0.1), Vector3((i * 2 - 1) * 0.0045, 0.0135, -0.005), bl, 0.0006)
	_bolt_group(root, 0.035, 0.032, 0.012, 0.01, 0.0078, bl, true)
	var bz := rf - float(p.get("barrel", 0.5))
	WeaponModelBuilder.barrel(root, "Barrel", rf, bz, 0.0102, 0.0082, bl, 0.0028, Vector3.ZERO, 0.03)
	# Alza de hoja sobre el caño y guion en rampa
	var z_rear := -0.2
	WeaponModelBuilder.prism(root, "RearBase", [z_rear + 0.02, 0.008, 0.002, z_rear - 0.02, 0.008, 0.002, z_rear - 0.016, 0.014, 0.002, z_rear + 0.016, 0.014, 0.002],
		0.014, bl, 0.001)
	WeaponModelBuilder.rear_notch(root, z_rear, ih, bl, 0.004, 0.012)
	var z_fs := bz + 0.025
	WeaponModelBuilder.prism(root, "FrontRamp", [z_fs + 0.03, 0.006, 0.0, z_fs - 0.006, 0.006, 0.0, z_fs - 0.004, ih - 0.007, 0.002, z_fs + 0.004, ih - 0.007, 0.002],
		0.008, bl, 0.001)
	WeaponModelBuilder.rbox(root, "FrontPost", Vector3(0.0028, 0.008, 0.003), Vector3(0, ih - 0.004, z_fs), bl, 0.0005)
	WeaponModelBuilder.sphere(root, "FrontBead", 0.0016, Vector3(0, ih - 0.0016, z_fs + 0.0015), WeaponModelBuilder.mat("brass"), 8)
	# Caja deportiva con Monte Carlo y punta schnabel
	WeaponModelBuilder.prism(root, "Stock", [-0.33, -0.004, 0.004, -0.342, -0.018, 0.004, -0.33, -0.034, 0.008, -0.15, -0.042, 0.03, -0.06, -0.046, 0.006,
		0.03, -0.048, 0.006, 0.05, -0.056, 0.012, 0.085, -0.112, 0.012, 0.11, -0.114, 0.01, 0.106, -0.085, 0.02, 0.14, -0.07, 0.04,
		0.35, -0.115, 0.006, 0.352, -0.004, 0.006, 0.24, 0.006, 0.03, 0.16, 0.0, 0.02, 0.09, -0.008, 0.012, 0.06, -0.006, 0.0], 0.04, wood, 0.009)
	WeaponModelBuilder.prism(root, "ButtPad", [0.35, -0.003, 0.003, 0.362, -0.003, 0.003, 0.362, -0.116, 0.003, 0.35, -0.116, 0.003], 0.042, WeaponModelBuilder.mat("rubber"), 0.003)
	WeaponModelBuilder.prism(root, "GripCap", [0.084, -0.11, 0.003, 0.11, -0.112, 0.003, 0.111, -0.117, 0.002, 0.086, -0.116, 0.002], 0.03, WeaponModelBuilder.mat("polymer"), 0.002)
	var mag := WeaponModelBuilder.group(root, "Mag", Vector3(0, -0.047, -0.025))
	WeaponModelBuilder.rbox(mag, "MagBody", Vector3(0.02, 0.03, 0.04), Vector3(0, 0.006, 0), WeaponModelBuilder.mat("polymer"), 0.002)
	WeaponModelBuilder.rbox(mag, "MagFloor", Vector3(0.024, 0.006, 0.046), Vector3(0, -0.01, 0), WeaponModelBuilder.mat("polymer"), 0.002)
	_guard(root, 0.004, 0.05, -0.048, 0.022, bl)
	_trigger(root, 0.026, -0.048, bl)
	WeaponModelBuilder.marker(root, "Sight", Vector3(0, ih, z_fs), 0.30 - z_fs)
	WeaponModelBuilder.marker(root, "Muzzle", Vector3(0, 0, bz))
	WeaponModelBuilder.marker(root, "Ejection", Vector3(0.0124, 0.006, -0.005))
	return root


static func _guard(root: Node3D, z_front: float, z_back: float, y_top: float, depth: float, m: Material) -> void:
	ModelsRifles._guard_u(root, z_front, z_back, y_top, depth, m, 0.011)


static func _trigger(root: Node3D, z: float, y_top: float, m: Material) -> void:
	ModelsRifles._trigger(root, z, y_top, m)
