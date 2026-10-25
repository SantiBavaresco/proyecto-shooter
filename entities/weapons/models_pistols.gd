class_name ModelsPistols
extends RefCounted
## Pistolas. Ánima en y = 0.02; la corredera ("Slide") retrocede al disparar.

const BORE_Y := 0.02


static func _serrations(slide: Node3D, z0: float, z1: float, y: float, half_w: float, h: float) -> void:
	var z := z0
	while z <= z1:
		for s: float in [-1.0, 1.0]:
			WeaponModelBuilder.rbox(slide, "Serration", Vector3(0.0007, h, 0.0016), Vector3(s * half_w, y, z), WeaponModelBuilder.mat("dark"), 0.0002)
		z += 0.0042


static func _sights(slide: Node3D, z_front: float, z_rear: float, top: float, h: float, dots := true) -> void:
	var m := WeaponModelBuilder.mat("metal")
	WeaponModelBuilder.rbox(slide, "FrontSight", Vector3(0.0035, h - top + 0.001, 0.0055), Vector3(0, (h + top) * 0.5 - 0.0005, z_front), m, 0.0006)
	for s: float in [-1.0, 1.0]:
		WeaponModelBuilder.rbox(slide, "Rear%s" % ("L" if s < 0 else "R"), Vector3(0.0072, h - top + 0.001, 0.0065), Vector3(s * 0.0066, (h + top) * 0.5 - 0.0005, z_rear),
			m, 0.0008)
		if dots:
			WeaponModelBuilder.sphere(slide, "RearDot", 0.001, Vector3(s * 0.0066, h - 0.0035, z_rear + 0.0033), WeaponModelBuilder.mat("white"), 6)
	if dots:
		WeaponModelBuilder.sphere(slide, "FrontDot", 0.0011, Vector3(0, h - 0.003, z_front + 0.0028), WeaponModelBuilder.mat("white"), 6)


static func _mag(root: Node3D, top_back: float, angle_deg: float, base_z: float, base_y: float, m: Material, base_mat: Material) -> void:
	# Cargador dentro de la empuñadura, inclinado como ella, y su base visible
	var mg := WeaponModelBuilder.group(root, "Mag", Vector3.ZERO)
	var t := tan(deg_to_rad(angle_deg))
	var h := 0.105
	WeaponModelBuilder.prism(mg, "MagBody", [top_back - 0.032, 0.0, 0.0, top_back, 0.0, 0.0, top_back + h * t, -h, 0.0, top_back - 0.032 + h * t, -h, 0.0],
		0.021, m, 0.0015)
	WeaponModelBuilder.prism(mg, "MagBase", [base_z - 0.026, base_y, 0.002, base_z + 0.022, base_y, 0.002, base_z + 0.024, base_y - 0.008, 0.003,
		base_z - 0.025, base_y - 0.008, 0.003], 0.027, base_mat, 0.002)


## P9 (tipo pistola austríaca de polímero, 9 mm).
static func striker(data: WeaponData) -> Node3D:
	var root := Node3D.new()
	var p := data.model_params
	var poly := WeaponModelBuilder.mat("polymer")
	var metal := WeaponModelBuilder.mat("metal")
	var slide_len: float = p.get("slide_len", 0.19)
	var front := 0.045 - slide_len
	var slide := WeaponModelBuilder.group(root, "Slide", Vector3.ZERO)
	WeaponModelBuilder.prism(slide, "SlideBody", [0.045, 0.006, 0.0, 0.045, 0.0375, 0.002, front + 0.004, 0.0375, 0.002, front, 0.032, 0.004, front, 0.006, 0.0],
		0.0255, metal, 0.0035)
	_serrations(slide, 0.01, 0.04, 0.021, 0.0128, 0.022)
	WeaponModelBuilder.rbox(slide, "Port", Vector3(0.0105, 0.0016, 0.04), Vector3(0.0018, 0.0373, -0.03), WeaponModelBuilder.mat("steel"), 0.0006)
	_sights(slide, front + 0.009, 0.036, 0.0375, 0.0445)
	WeaponModelBuilder.barrel(root, "BarrelTip", front + 0.03, front - 0.0012, 0.0068, 0.0068, WeaponModelBuilder.mat("steel"), 0.0046, Vector3(0, BORE_Y, 0))
	# Armazón de polímero
	WeaponModelBuilder.prism(root, "Frame", [front + 0.003, 0.008, 0.0, 0.045, 0.008, 0.0, 0.052, 0.002, 0.004, 0.05, -0.008, 0.006, 0.056, -0.022, 0.01,
		0.08, -0.1, 0.006, 0.076, -0.108, 0.003, 0.034, -0.11, 0.003, 0.026, -0.098, 0.004, 0.018, -0.086, 0.004, 0.021, -0.078, 0.003,
		0.013, -0.065, 0.004, 0.016, -0.057, 0.003, 0.008, -0.042, 0.004, 0.006, -0.014, 0.002, -0.064, -0.014, 0.0, -0.07, -0.006, 0.003,
		front + 0.003, -0.006, 0.003], 0.0285, poly, 0.003)
	for i in 2:
		WeaponModelBuilder.rbox(root, "RailSlot", Vector3(0.022, 0.0015, 0.003), Vector3(0, -0.0065, -0.1 - i * 0.012), WeaponModelBuilder.mat("dark"), 0.0004)
	WeaponModelBuilder.prism(root, "TriggerGuard", [-0.072, -0.012, 0.0, -0.064, -0.012, 0.0, -0.061, -0.034, 0.004, 0.0, -0.035, 0.0, 0.008, -0.03, 0.0,
		0.009, -0.038, 0.0, 0.0, -0.041, 0.002, -0.066, -0.041, 0.005], 0.0125, poly, 0.0015)
	WeaponModelBuilder.prism(root, "Trigger", [-0.034, -0.012, 0.0, -0.027, -0.012, 0.0, -0.026, -0.024, 0.003, -0.03, -0.031, 0.002, -0.035, -0.03, 0.0,
		-0.032, -0.022, 0.002], 0.006, poly, 0.001)
	WeaponModelBuilder.rbox(root, "SlideStop", Vector3(0.002, 0.004, 0.016), Vector3(-0.0148, 0.004, -0.03), metal, 0.0008)
	WeaponModelBuilder.rbox(root, "Takedown", Vector3(0.0305, 0.003, 0.006), Vector3(0, 0.003, -0.05), metal, 0.0008)
	_mag(root, 0.046, 18.0, 0.054, -0.108, metal, poly)
	WeaponModelBuilder.marker(root, "Sight", Vector3(0, 0.0445, front + 0.009), -(front + 0.009) + 0.40)
	WeaponModelBuilder.marker(root, "Muzzle", Vector3(0, BORE_Y, front - 0.004))
	WeaponModelBuilder.marker(root, "Ejection", Vector3(0.016, 0.03, -0.03))
	return root


## Tala T9 (tipo pistola argentina de aleación, 9 mm, con martillo).
static func bersa(data: WeaponData) -> Node3D:
	var root := Node3D.new()
	var p := data.model_params
	var metal := WeaponModelBuilder.mat("metal")
	var alloy := WeaponModelBuilder.mat("alloy")
	var poly := WeaponModelBuilder.mat("polymer")
	var slide_len: float = p.get("slide_len", 0.175)
	var front := 0.045 - slide_len
	var slide := WeaponModelBuilder.group(root, "Slide", Vector3.ZERO)
	WeaponModelBuilder.section(slide, "SlideBody", [-0.0125, 0.006, 0.0, 0.0125, 0.006, 0.0, 0.0125, 0.029, 0.004, 0.0065, 0.0375, 0.006,
		-0.0065, 0.0375, 0.006, -0.0125, 0.029, 0.004], front, 0.045, metal, 0.003)
	_serrations(slide, 0.012, 0.04, 0.019, 0.0126, 0.018)
	WeaponModelBuilder.rbox(slide, "Port", Vector3(0.0012, 0.012, 0.032), Vector3(0.0126, 0.026, -0.028), WeaponModelBuilder.mat("dark"), 0.002)
	for s: float in [-1.0, 1.0]:
		WeaponModelBuilder.cyl(slide, "Decocker", 0.0045, 0.003, Vector3(s * 0.0135, 0.028, 0.03), metal, 12, Vector3(0, PI * 0.5, 0))
	_sights(slide, front + 0.009, 0.036, 0.0372, 0.0445)
	WeaponModelBuilder.barrel(root, "BarrelTip", front + 0.03, front - 0.0012, 0.0068, 0.0068, WeaponModelBuilder.mat("steel"), 0.0046, Vector3(0, BORE_Y, 0))
	WeaponModelBuilder.prism(root, "Hammer", [0.04, 0.012, 0.0, 0.05, 0.014, 0.002, 0.058, 0.028, 0.003, 0.054, 0.032, 0.002, 0.046, 0.026, 0.0, 0.04, 0.022, 0.0],
		0.007, metal, 0.001)
	WeaponModelBuilder.prism(root, "Frame", [front + 0.002, 0.008, 0.0, 0.047, 0.008, 0.0, 0.05, -0.006, 0.004, 0.058, -0.02, 0.004, 0.078, -0.098, 0.006,
		0.07, -0.106, 0.002, 0.03, -0.106, 0.003, 0.012, -0.04, 0.006, 0.006, -0.014, 0.002, -0.06, -0.014, 0.0, -0.066, -0.006, 0.003,
		front + 0.002, -0.006, 0.003], 0.0272, alloy, 0.0025)
	WeaponModelBuilder.prism(root, "GripPanel", [0.016, -0.03, 0.004, 0.052, -0.022, 0.004, 0.072, -0.094, 0.006, 0.034, -0.1, 0.006], 0.032, poly, 0.003)
	WeaponModelBuilder.prism(root, "TriggerGuard", [-0.068, -0.012, 0.0, -0.061, -0.012, 0.0, -0.058, -0.03, 0.008, -0.003, -0.034, 0.0, 0.006, -0.026, 0.0,
		0.009, -0.034, 0.0, 0.0, -0.041, 0.004, -0.062, -0.041, 0.012], 0.0118, alloy, 0.0015)
	ModelsRifles._trigger(root, -0.032, -0.014, metal)
	WeaponModelBuilder.rbox(root, "SlideStop", Vector3(0.002, 0.004, 0.018), Vector3(-0.0142, 0.003, -0.028), metal, 0.0008)
	_mag(root, 0.047, 16.0, 0.052, -0.106, metal, poly)
	WeaponModelBuilder.marker(root, "Sight", Vector3(0, 0.0445, front + 0.009), -(front + 0.009) + 0.40)
	WeaponModelBuilder.marker(root, "Muzzle", Vector3(0, BORE_Y, front - 0.004))
	WeaponModelBuilder.marker(root, "Ejection", Vector3(0.016, 0.03, -0.03))
	return root


## Liberty .45 (tipo 1911) y Ballestero .45 (tipo Ballester-Molina, sin seguro de empuñadura).
static func m1911(data: WeaponData, ballester: bool) -> Node3D:
	var root := Node3D.new()
	var p := data.model_params
	var steel := WeaponModelBuilder.mat("steel")
	var metal := WeaponModelBuilder.mat("metal")
	var wood := WeaponModelBuilder.mat("wood")
	var slide_len: float = p.get("slide_len", 0.21)
	var front := 0.045 - slide_len
	var slide := WeaponModelBuilder.group(root, "Slide", Vector3.ZERO)
	WeaponModelBuilder.section(slide, "SlideBody", [-0.0118, 0.007, 0.0, 0.0118, 0.007, 0.0, 0.0118, 0.03, 0.003, 0.009, 0.036, 0.006,
		-0.009, 0.036, 0.006, -0.0118, 0.03, 0.003], front, 0.045, steel, 0.002)
	_serrations(slide, 0.008, 0.04, 0.02, 0.0119, 0.02)
	WeaponModelBuilder.rbox(slide, "Port", Vector3(0.0012, 0.011, 0.03), Vector3(0.0119, 0.024, -0.03), WeaponModelBuilder.mat("dark"), 0.002)
	WeaponModelBuilder.tube(slide, "Bushing", 0.0062, 0.0098, 0.008, Vector3(0, BORE_Y, front + 0.003), steel, 20)
	_sights(slide, front + 0.012, 0.036, 0.036, 0.0435, false)
	WeaponModelBuilder.barrel(root, "BarrelTip", front + 0.03, front + 0.0005, 0.0062, 0.0062, steel, 0.0058, Vector3(0, BORE_Y, 0))
	WeaponModelBuilder.prism(root, "Frame", [front + 0.002, 0.007, 0.0, 0.047, 0.007, 0.0, 0.05, 0.0, 0.002, 0.052, -0.012, 0.0, 0.07, -0.1, 0.003,
		0.067, -0.106, 0.002, 0.024, -0.108, 0.002, 0.008, -0.04, 0.006, 0.004, -0.014, 0.002, -0.062, -0.014, 0.0, -0.068, -0.006, 0.004,
		front + 0.002, -0.006, 0.006], 0.0255, steel, 0.0022)
	if ballester:
		WeaponModelBuilder.prism(root, "GripPanel", [0.01, -0.03, 0.004, 0.054, -0.02, 0.004, 0.072, -0.1, 0.006, 0.024, -0.104, 0.006], 0.031, wood, 0.004)
		WeaponModelBuilder.prism(root, "Tang", [0.044, 0.008, 0.0, 0.058, 0.007, 0.003, 0.06, 0.0, 0.002, 0.052, -0.012, 0.0], 0.02, steel, 0.0015)
	else:
		WeaponModelBuilder.prism(root, "GripPanel", [0.012, -0.032, 0.004, 0.05, -0.026, 0.004, 0.066, -0.098, 0.004, 0.026, -0.102, 0.004], 0.0305, wood, 0.003)
		WeaponModelBuilder.prism(root, "GripSafety", [0.044, 0.008, 0.0, 0.062, 0.009, 0.004, 0.068, 0.004, 0.003, 0.06, 0.0, 0.002, 0.056, -0.03, 0.004,
			0.05, -0.03, 0.0], 0.02, steel, 0.0015)
	for s: float in [-1.0, 1.0]:
		for z: float in [0.02, 0.045]:
			WeaponModelBuilder.sphere(root, "GripScrew", 0.002, Vector3(s * 0.0153, -0.04 - (z - 0.02) * 2.2, z), metal, 8)
	WeaponModelBuilder.prism(root, "Hammer", [0.042, 0.012, 0.0, 0.05, 0.012, 0.0, 0.058, 0.026, 0.002, 0.066, 0.03, 0.002, 0.064, 0.034, 0.002, 0.054, 0.032, 0.002,
		0.044, 0.024, 0.0], 0.0075, metal, 0.001)
	WeaponModelBuilder.prism(root, "ThumbSafety", [0.04, 0.01, 0.0, 0.025, 0.012, 0.002, 0.02, 0.006, 0.002, 0.04, 0.0, 0.0], 0.002, metal, 0.0005,
		Vector3(-0.0135, 0, 0))
	WeaponModelBuilder.rbox(root, "SlideStop", Vector3(0.002, 0.006, 0.022), Vector3(-0.0133, 0.002, -0.035), metal, 0.001)
	WeaponModelBuilder.prism(root, "TriggerGuard", [-0.07, -0.012, 0.0, -0.063, -0.012, 0.0, -0.06, -0.03, 0.008, -0.003, -0.033, 0.0, 0.006, -0.026, 0.0,
		0.009, -0.034, 0.0, 0.0, -0.04, 0.004, -0.064, -0.04, 0.012], 0.011, steel, 0.0015)
	WeaponModelBuilder.rbox(root, "Trigger", Vector3(0.0065, 0.012, 0.006), Vector3(0, -0.021, -0.03), metal, 0.0015)
	_mag(root, 0.045, 13.0, 0.046, -0.108, metal, metal)
	WeaponModelBuilder.marker(root, "Sight", Vector3(0, 0.0435, front + 0.012), -(front + 0.012) + 0.40)
	WeaponModelBuilder.marker(root, "Muzzle", Vector3(0, BORE_Y, front - 0.003))
	WeaponModelBuilder.marker(root, "Ejection", Vector3(0.016, 0.03, -0.03))
	return root


## Pampa .22 (tipo pistola de tiro .22 con receptor tubular y caño pesado).
static func target22(_data: WeaponData) -> Node3D:
	var root := Node3D.new()
	var steel := WeaponModelBuilder.mat("blued")
	var metal := WeaponModelBuilder.mat("metal")
	var poly := WeaponModelBuilder.mat("polymer")
	WeaponModelBuilder.lathe(root, "Receiver", [-0.085, 0.0, -0.085, 0.0135, 0.04, 0.0135, 0.045, 0.012, 0.045, 0.0], steel, Vector3(0, BORE_Y, 0), 20)
	WeaponModelBuilder.rbox(root, "Port", Vector3(0.003, 0.009, 0.03), Vector3(0.0122, BORE_Y + 0.004, -0.02), WeaponModelBuilder.mat("dark"), 0.002)
	WeaponModelBuilder.barrel(root, "Barrel", -0.085, -0.235, 0.0108, 0.0094, steel, 0.0028, Vector3(0, BORE_Y, 0))
	var bolt := WeaponModelBuilder.group(root, "Slide", Vector3(0, BORE_Y, 0.045))
	WeaponModelBuilder.cyl(bolt, "BoltEars", 0.0042, 0.034, Vector3(0, 0.0, 0.004), metal, 12, Vector3(0, PI * 0.5, 0), 0.0015)
	WeaponModelBuilder.prism(root, "FrontBlade", [-0.218, BORE_Y + 0.0085, 0.0, -0.232, BORE_Y + 0.0085, 0.0, -0.23, 0.0425, 0.001, -0.222, 0.0425, 0.001],
		0.0035, steel, 0.0006)
	WeaponModelBuilder.rbox(root, "RearBase", Vector3(0.018, 0.005, 0.018), Vector3(0, BORE_Y + 0.0155, 0.03), steel, 0.0015)
	for s: float in [-1.0, 1.0]:
		WeaponModelBuilder.rbox(root, "Rear%s" % ("L" if s < 0 else "R"), Vector3(0.0072, 0.006, 0.006), Vector3(s * 0.0066, 0.0395, 0.034), steel, 0.0008)
	WeaponModelBuilder.prism(root, "Frame", [-0.08, 0.008, 0.0, 0.038, 0.008, 0.0, 0.045, 0.002, 0.004, 0.08, -0.09, 0.006, 0.074, -0.098, 0.002,
		0.036, -0.098, 0.002, 0.018, -0.05, 0.006, 0.008, -0.015, 0.002, -0.06, -0.015, 0.0, -0.07, -0.004, 0.004, -0.08, 0.002, 0.003],
		0.026, steel, 0.0022)
	WeaponModelBuilder.prism(root, "GripPanel", [0.022, -0.03, 0.004, 0.05, -0.02, 0.004, 0.074, -0.088, 0.004, 0.04, -0.092, 0.004], 0.03, poly, 0.003)
	WeaponModelBuilder.prism(root, "TriggerGuard", [-0.066, -0.013, 0.0, -0.059, -0.013, 0.0, -0.056, -0.03, 0.008, -0.002, -0.033, 0.0, 0.007, -0.024, 0.0,
		0.01, -0.032, 0.0, 0.0, -0.04, 0.004, -0.06, -0.04, 0.012], 0.011, steel, 0.0015)
	ModelsRifles._trigger(root, -0.03, -0.015, metal)
	_mag(root, 0.044, 21.0, 0.055, -0.098, metal, metal)
	WeaponModelBuilder.marker(root, "Sight", Vector3(0, 0.0425, -0.225), 0.225 + 0.40)
	WeaponModelBuilder.marker(root, "Muzzle", Vector3(0, BORE_Y, -0.237))
	WeaponModelBuilder.marker(root, "Ejection", Vector3(0.016, 0.03, -0.02))
	return root
