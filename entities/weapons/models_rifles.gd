class_name ModelsRifles
extends RefCounted
## Fusiles y subfusiles. Medidas en metros tomadas de las armas reales en las que
## se basa cada uno. Ánima en y = 0; el receptor termina adelante en "rf".


## Ojo detrás del origen (z absoluto) para miras metálicas, según el arma.
const EYE_Z := {"ar15": 0.1, "sr22": 0.1, "ak74": 0.11, "akm": 0.11, "pp19": 0.14, "mp5": 0.15,
	"g3": 0.1, "sks": 0.12, "rifle": 0.1}


static func _eye_irons(id: String, sight_z: float) -> float:
	return float(EYE_Z.get(id, 0.1)) - sight_z


static func _muzzle_device(root: Node3D, kind: String, z: float, m: Material) -> float:
	## Devuelve la z de la boca después del dispositivo.
	match kind:
		"a2":  # apagallamas de jaula
			var f := z - 0.055
			WeaponModelBuilder.lathe(root, "FlashHider", [f + 0.02, 0.0, f + 0.02, 0.0045, f, 0.0045, f, 0.0102, f + 0.004, 0.0108,
				f + 0.044, 0.0108, f + 0.05, 0.0092, z, 0.0092, z, 0.0], m, Vector3.ZERO, 16)
			for a: float in [0.6, PI * 0.5, PI - 0.6]:
				WeaponModelBuilder.rbox(root, "Slot", Vector3(0.0028, 0.0012, 0.026), Vector3(cos(a) * 0.0104, sin(a) * 0.0104, f + 0.022),
					WeaponModelBuilder.mat("dark"), 0.0005, Vector3(0, 0, a - PI * 0.5))
			return f
		"brake":
			var f := z - 0.068
			var pts := [f + 0.02, 0.0, f + 0.02, 0.0052, f, 0.0052, f, 0.0125, f + 0.004, 0.0136]
			for i in 3:
				var g := f + 0.012 + i * 0.014
				pts.append_array([g, 0.0136, g, 0.0098, g + 0.008, 0.0098, g + 0.008, 0.0136])
			pts.append_array([z - 0.004, 0.0136, z, 0.0112, z, 0.0])
			WeaponModelBuilder.lathe(root, "Brake", pts, m, Vector3.ZERO, 18)
			return f
		"ak74":  # freno de boca del AK-74, con cámara y ventanas
			var f := z - 0.082
			WeaponModelBuilder.lathe(root, "Brake", [f + 0.02, 0.0, f + 0.02, 0.0052, f, 0.0052, f, 0.0112, f + 0.004, 0.0124,
				f + 0.03, 0.0124, f + 0.034, 0.0106, f + 0.042, 0.0106, f + 0.045, 0.0124, f + 0.07, 0.0124,
				f + 0.076, 0.0104, z, 0.0104, z, 0.0], m, Vector3.ZERO, 18)
			for s: float in [-1.0, 1.0]:
				WeaponModelBuilder.rbox(root, "Port", Vector3(0.0012, 0.0065, 0.013), Vector3(s * 0.0122, 0.0, f + 0.016), WeaponModelBuilder.mat("dark"), 0.0005)
			WeaponModelBuilder.rbox(root, "PortTop", Vector3(0.007, 0.0012, 0.012), Vector3(0, 0.0122, f + 0.016), WeaponModelBuilder.mat("dark"), 0.0005)
			return f
		"akm":  # compensador en pico de flauta
			var f := z - 0.035
			WeaponModelBuilder.lathe(root, "Compensator", [f + 0.018, 0.0, f + 0.018, 0.0055, f, 0.0055, f, 0.011, z - 0.004, 0.0118,
				z, 0.0105, z, 0.0], m, Vector3.ZERO, 16)
			WeaponModelBuilder.rbox(root, "CompCut", Vector3(0.016, 0.006, 0.012), Vector3(-0.004, 0.0085, f + 0.004), WeaponModelBuilder.mat("dark"), 0.001,
				Vector3(0.5, 0, 0.3))
			return f
		"fal", "svd", "g3":
			var length := {"fal": 0.068, "svd": 0.085, "g3": 0.052}[kind] as float
			var rr := {"fal": 0.0118, "svd": 0.0125, "g3": 0.012}[kind] as float
			var f := z - length
			WeaponModelBuilder.lathe(root, "FlashHider", [f + 0.02, 0.0, f + 0.02, 0.0058, f, 0.0058, f, rr * 0.92, f + 0.003, rr,
				z - 0.006, rr, z - 0.003, rr * 0.85, z, rr * 0.85, z, 0.0], m, Vector3.ZERO, 18)
			var slots := 4 if kind != "svd" else 5
			for i in slots:
				var a := TAU * i / slots + 0.3
				WeaponModelBuilder.rbox(root, "Slot", Vector3(0.0028, 0.0012, length * 0.6), Vector3(cos(a) * rr, sin(a) * rr, f + length * 0.4),
					WeaponModelBuilder.mat("dark"), 0.0005, Vector3(0, 0, a - PI * 0.5))
			return f
		"thread":
			var f := z - 0.012
			WeaponModelBuilder.lathe(root, "ThreadCap", [f, 0.0, f, 0.0085, z, 0.0085, z, 0.0], m, Vector3.ZERO, 14)
			return f
		_:
			return z


static func _grip_ar(root: Node3D, y_top: float, m: Material) -> void:
	# Empuñadura tipo A2 (inclinada, con resalto para el dedo mayor)
	WeaponModelBuilder.prism(root, "Grip", [-0.004, y_top, 0.0, 0.034, y_top, 0.0, 0.038, y_top - 0.012, 0.008, 0.07, y_top - 0.082, 0.012,
		0.066, y_top - 0.094, 0.006, 0.032, y_top - 0.094, 0.006, 0.021, y_top - 0.066, 0.008, 0.008, y_top - 0.048, 0.004,
		0.014, y_top - 0.038, 0.005, 0.0, y_top - 0.012, 0.006], 0.026, m, 0.004)


static func _guard_u(root: Node3D, z_front: float, z_back: float, y_top: float, depth: float, m: Material, width := 0.012) -> void:
	# Guardamonte en U (abierto arriba), de z_front a z_back
	var t := 0.0065
	WeaponModelBuilder.prism(root, "TriggerGuard", [z_front, y_top, 0.0, z_front + t, y_top, 0.0, z_front + t + 0.002, y_top - depth + t, 0.004,
		z_back - t, y_top - depth + t, 0.0, z_back - t, y_top, 0.0, z_back, y_top, 0.0, z_back, y_top - depth + 0.002, 0.003,
		z_back - 0.006, y_top - depth, 0.002, z_front + 0.005, y_top - depth, 0.005], width, m, 0.0015)


static func _trigger(root: Node3D, z: float, y_top: float, m: Material) -> void:
	WeaponModelBuilder.prism(root, "Trigger", [z - 0.004, y_top, 0.0, z + 0.003, y_top, 0.0, z + 0.004, y_top - 0.01, 0.003,
		z + 0.0, y_top - 0.018, 0.002, z - 0.005, y_top - 0.017, 0.0, z - 0.002, y_top - 0.009, 0.002], 0.0055, m, 0.001)


static func _buffer_stock(root: Node3D, m: Material, cheek := false) -> void:
	# Tubo de la culata retráctil y culata tipo M4
	var al := WeaponModelBuilder.mat("anodized")
	WeaponModelBuilder.lathe(root, "BufferTube", [0.07, 0.0, 0.07, 0.0145, 0.292, 0.0145, 0.296, 0.012, 0.296, 0.0], al, Vector3(0, -0.002, 0), 18)
	WeaponModelBuilder.tube(root, "CastleNut", 0.0146, 0.0175, 0.008, Vector3(0, -0.002, 0.082), al, 18)
	WeaponModelBuilder.prism(root, "Stock", [0.165, 0.019, 0.004, 0.302, 0.019, 0.006, 0.305, -0.094, 0.006, 0.288, -0.1, 0.006,
		0.232, -0.04, 0.012, 0.19, -0.027, 0.006, 0.165, -0.022, 0.004], 0.042, m, 0.005)
	WeaponModelBuilder.prism(root, "ButtPad", [0.302, 0.021, 0.003, 0.317, 0.021, 0.004, 0.319, -0.101, 0.004, 0.304, -0.101, 0.003],
		0.045, WeaponModelBuilder.mat("rubber"), 0.003)
	WeaponModelBuilder.rbox(root, "StockLever", Vector3(0.012, 0.006, 0.05), Vector3(0, -0.02, 0.2), m, 0.002)
	if cheek:
		WeaponModelBuilder.prism(root, "CheekRiser", [0.17, 0.018, 0.0, 0.29, 0.018, 0.0, 0.29, 0.036, 0.006, 0.19, 0.036, 0.008], 0.038, m, 0.004)


static func _fixed_stock(root: Node3D, m: Material, y_top := 0.017) -> void:
	# Culata fija tipo A2 / G3 / FAL
	WeaponModelBuilder.prism(root, "Stock", [0.07, y_top, 0.003, 0.335, y_top - 0.005, 0.006, 0.338, -0.112, 0.006, 0.31, -0.115, 0.01,
		0.23, -0.072, 0.03, 0.15, -0.05, 0.03, 0.075, -0.034, 0.004], 0.04, m, 0.006)
	WeaponModelBuilder.prism(root, "ButtPlate", [0.335, y_top - 0.004, 0.003, 0.347, y_top - 0.004, 0.004, 0.349, -0.113, 0.004,
		0.339, -0.114, 0.003], 0.042, WeaponModelBuilder.mat("rubber"), 0.003)


static func _irons_flip(root: Node3D, z_rear: float, z_front: float, rail_top: float, h: float) -> void:
	# Miras plegables sobre riel (alza de anillo y guion)
	var m := WeaponModelBuilder.mat("anodized")
	WeaponModelBuilder.rbox(root, "FlipRearBase", Vector3(0.022, 0.009, 0.03), Vector3(0, rail_top + 0.0045, z_rear), m, 0.002)
	WeaponModelBuilder.prism(root, "FlipRearTower", [z_rear + 0.007, rail_top + 0.008, 0.0, z_rear - 0.009, rail_top + 0.008, 0.0,
		z_rear - 0.006, h - 0.006, 0.002, z_rear + 0.005, h - 0.006, 0.002], 0.016, m, 0.001)
	WeaponModelBuilder.rear_aperture(root, z_rear - 0.002, h, m)
	WeaponModelBuilder.rbox(root, "FlipFrontBase", Vector3(0.02, 0.009, 0.026), Vector3(0, rail_top + 0.0045, z_front), m, 0.002)
	WeaponModelBuilder.front_post(root, z_front, rail_top + 0.008, h, m, true, false, 0.012, 0.018)


# --- Familia AR (AR-C, K416, R-22S, KR-25) ----------------------------------------

static func ar(data: WeaponData) -> Node3D:
	var root := Node3D.new()
	var p := data.model_params
	var id := data.id
	var al := WeaponModelBuilder.mat("anodized")
	var steel := WeaponModelBuilder.mat("metal")
	var poly := WeaponModelBuilder.mat("polymer")
	var rf := -0.185
	var barrel_len: float = p.get("barrel", 0.4)
	var hg: float = p.get("hg", 0.3)
	var heavy := id == "sr25"
	var carry := id == "ar15"
	if heavy:
		# KR-25: tirador con cajón y muebles color arena (no se confunde con el M-14E negro)
		al = WeaponModelBuilder.mat("tan")
		poly = WeaponModelBuilder.mat("tan")

	# Receptor superior (con el riel o la manija de transporte)
	WeaponModelBuilder.section(root, "Upper", [-0.0135, -0.017, 0.0, 0.0135, -0.017, 0.0, 0.0135, 0.011, 0.002, 0.0105, 0.0215, 0.002,
		-0.0105, 0.0215, 0.002, -0.0135, 0.011, 0.002], rf, 0.075, al, 0.0015)
	WeaponModelBuilder.rbox(root, "PortCover", Vector3(0.0012, 0.016, 0.062), Vector3(0.0138, 0.002, -0.07), al, 0.0005)
	WeaponModelBuilder.rbox(root, "Deflector", Vector3(0.005, 0.012, 0.014), Vector3(0.0155, 0.011, -0.01), al, 0.002)
	WeaponModelBuilder.cyl(root, "ForwardAssist", 0.0055, 0.03, Vector3(0.0158, 0.008, 0.03), al, 12, Vector3.ZERO, 0.002)
	WeaponModelBuilder.cyl(root, "FAButton", 0.0068, 0.008, Vector3(0.0158, 0.008, 0.048), steel, 14, Vector3.ZERO, 0.002)
	if not carry:
		WeaponModelBuilder.rail(root, "TopRail", rf, 0.072, 0.0215, al)
	# Receptor inferior con brocal, guardamonte y gatillo
	WeaponModelBuilder.prism(root, "Lower", [0.075, -0.017, 0.0, rf, -0.017, 0.0, rf, -0.032, 0.003, rf + 0.007, -0.05, 0.002,
		-0.098, -0.05, 0.0, -0.097, -0.046, 0.004, 0.04, -0.046, 0.0, 0.062, -0.04, 0.004, 0.075, -0.028, 0.004],
		0.03, al, 0.0018)
	WeaponModelBuilder.prism(root, "MagWell", [rf + 0.007, -0.048, 0.0, -0.098, -0.048, 0.0, -0.1, -0.089, 0.002, rf + 0.009, -0.089, 0.002],
		0.034, al, 0.002)
	WeaponModelBuilder.rbox(root, "MagRelease", Vector3(0.004, 0.009, 0.009), Vector3(0.0175, -0.056, -0.094), steel, 0.002)
	WeaponModelBuilder.prism(root, "BoltCatch", [-0.08, -0.018, 0.0, -0.1, -0.02, 0.002, -0.1, -0.034, 0.002, -0.088, -0.03, 0.0], 0.002,
		steel, 0.0005, Vector3(-0.0158, 0, 0))
	WeaponModelBuilder.cyl(root, "Selector", 0.0055, 0.004, Vector3(-0.0162, -0.031, 0.012), steel, 12, Vector3(0, PI * 0.5, 0))
	WeaponModelBuilder.pin(root, Vector3(0, -0.026, rf + 0.012), 0.0025, 0.033)
	WeaponModelBuilder.pin(root, Vector3(0, -0.026, 0.062), 0.0025, 0.033)
	_guard_u(root, -0.098, 0.006, -0.046, 0.027, al)
	_trigger(root, -0.045, -0.046, steel)
	_grip_ar(root, -0.046, poly)
	# Manija de carga en T (atrás arriba)
	var ch := WeaponModelBuilder.group(root, "Charging", Vector3(0, 0.017, 0.075))
	ch.set_meta("knob", Vector3(-0.014, 0.002, 0.016))
	WeaponModelBuilder.rbox(ch, "ChShaft", Vector3(0.008, 0.005, 0.02), Vector3(0, 0, 0.004), al, 0.001)
	WeaponModelBuilder.rbox(ch, "ChLatch", Vector3(0.036, 0.0065, 0.008), Vector3(0, 0, 0.016), al, 0.002)

	# Culata
	match id:
		"sr25":
			_fixed_stock(root, poly)
		_:
			_buffer_stock(root, poly, false)

	# Guardamanos
	var hz := rf - 0.004
	var hf := hz - hg
	match id:
		"ar15":
			WeaponModelBuilder.lathe(root, "DeltaRing", [hz - 0.012, 0.0, hz - 0.012, 0.03, hz, 0.031, hz, 0.0], al, Vector3.ZERO, 24)
			# Guardamanos redondo con estrías (dos mitades, con la junta a los costados)
			var fl: Array = []
			var nr := 26
			for i in nr * 2:
				var ang := PI * i / nr
				var rr := 0.0272 if i % 2 == 0 else 0.0258
				fl.append_array([cos(ang) * rr, sin(ang) * rr, 0.0006])
			WeaponModelBuilder.section(root, "Handguard", fl, hf, hz - 0.012, poly, 0.002)
			for s: float in [-1.0, 1.0]:
				WeaponModelBuilder.rbox(root, "HgSeam", Vector3(0.0022, 0.003, hg - 0.016), Vector3(s * 0.0271, 0.0, (hf + hz - 0.012) * 0.5),
					WeaponModelBuilder.mat("dark"), 0.0008)
			WeaponModelBuilder.lathe(root, "HgCap", [hf - 0.008, 0.0, hf - 0.008, 0.0215, hf - 0.002, 0.0232, hf, 0.0262, hf + 0.002, 0.0262,
				hf + 0.002, 0.0], al, Vector3.ZERO, 22)
		"hk416":
			WeaponModelBuilder.section(root, "Handguard", [-0.0235, -0.0245, 0.006, 0.0235, -0.0245, 0.006, 0.0235, 0.0215, 0.003,
				-0.0235, 0.0215, 0.003], hf, hz, al, 0.002)
			WeaponModelBuilder.rail(root, "HgRailTop", hf + 0.004, hz, 0.0215, al)
			for s: float in [-1.0, 1.0]:
				var t := Transform3D(Basis(Vector3(0, 0, 1), -s * PI * 0.5), Vector3(s * 0.0235, -0.0015, 0))
				WeaponModelBuilder.rail(root, "HgRailSide", hf + 0.006, hz - 0.004, 0.0, al, t)
			WeaponModelBuilder.rail(root, "HgRailBottom", hf + 0.006, hz - 0.004, 0.0, al, Transform3D(Basis(Vector3(0, 0, 1), PI), Vector3(0, -0.0245, 0)))
			# Cubiertas de riel estriadas (izquierda y abajo, mitad delantera)
			var cz := hf + 0.012
			var cl := hg * 0.5
			var cover := MeshKit.new()
			cover.box(Vector3(-0.0285, -0.0015, cz + cl * 0.5), Vector3(0.006, 0.02, cl), 0.002)
			cover.box(Vector3(0, -0.0295, cz + cl * 0.5), Vector3(0.02, 0.006, cl), 0.002)
			var zz := cz + 0.006
			while zz < cz + cl - 0.006:
				cover.box(Vector3(-0.0315, -0.0015, zz), Vector3(0.0018, 0.018, 0.004), 0.0006)
				cover.box(Vector3(0, -0.0325, zz), Vector3(0.018, 0.0018, 0.004), 0.0006)
				zz += 0.01
			WeaponModelBuilder.put(root, "RailCovers", cover, poly)
		_:
			# Tubo libre tipo M-LOK
			WeaponModelBuilder.section(root, "Handguard", [-0.025, -0.016, 0.009, -0.016, -0.025, 0.004, 0.016, -0.025, 0.004, 0.025, -0.016, 0.009,
				0.025, 0.012, 0.004, 0.016, 0.0215, 0.002, -0.016, 0.0215, 0.002, -0.025, 0.012, 0.004], hf, hz, al, 0.002)
			WeaponModelBuilder.rail(root, "HgRailTop", hf + 0.004, hz, 0.0215, al)
			var n := int(hg / 0.045)
			for s: float in [-1.0, 1.0]:
				for i in n:
					WeaponModelBuilder.rbox(root, "MlokSlot", Vector3(0.0012, 0.0062, 0.026), Vector3(s * 0.0252, -0.002, hf + 0.03 + i * 0.045),
						WeaponModelBuilder.mat("dark"), 0.002)

	if heavy:
		# Bípode plegado bajo el guardamanos
		var bpz := hf + 0.03
		WeaponModelBuilder.rbox(root, "BipodMount", Vector3(0.03, 0.012, 0.03), Vector3(0, -0.031, bpz), steel, 0.003)
		for sx: float in [-1.0, 1.0]:
			WeaponModelBuilder.cyl(root, "BipodLeg", 0.0042, 0.16, Vector3(sx * 0.011, -0.036, bpz + 0.085), steel, 10, Vector3.ZERO, 0.0015)
			WeaponModelBuilder.sphere(root, "BipodFoot", 0.006, Vector3(sx * 0.011, -0.036, bpz + 0.165), WeaponModelBuilder.mat("rubber"), 8)

	# Caño, dispositivo de boca
	var bz := rf - barrel_len
	WeaponModelBuilder.barrel(root, "Barrel", rf, bz, 0.0118 if not heavy else 0.0135, (0.0092 if not heavy else 0.0118), steel, 0.0045)
	var muzzle := _muzzle_device(root, {"ar15": "a2", "hk416": "a2", "sr22": "thread", "sr25": "brake"}.get(id, "a2"), bz, steel)

	# Miras
	var sight: Vector3
	var eye := 0.0
	match data.sight:
		"red_dot":
			sight = WeaponModelBuilder.red_dot(root, 0.031, -0.07)
			eye = 0.24
		"scope":
			sight = WeaponModelBuilder.scope(root, data, 0.068, 0.031, "hunting")
			eye = 0.075
		_:
			var ih: float = p.get("iron_h", 0.062)
			if carry:
				var zf := hf - 0.03
				WeaponModelBuilder.lathe(root, "FsbCollar", [zf - 0.012, 0.0, zf - 0.012, 0.0122, zf + 0.012, 0.0122, zf + 0.012, 0.0], steel, Vector3.ZERO, 16)
				WeaponModelBuilder.front_post(root, zf, 0.008, ih, steel, true, false, 0.014, 0.034)
				WeaponModelBuilder.rbox(root, "BayonetLug", Vector3(0.008, 0.012, 0.02), Vector3(0, -0.016, zf), steel, 0.002)
				# Manija de transporte con el alza de anillo atrás
				WeaponModelBuilder.prism(root, "CarryRear", [0.07, 0.0215, 0.0, 0.07, ih - 0.006, 0.002, 0.026, ih - 0.006, 0.002, 0.02, 0.0215, 0.0],
					0.022, al, 0.002)
				WeaponModelBuilder.prism(root, "CarryTop", [0.026, ih - 0.006, 0.0, -0.115, ih - 0.006, 0.004, -0.118, ih - 0.016, 0.003, 0.02, ih - 0.016, 0.0],
					0.016, al, 0.002)
				WeaponModelBuilder.prism(root, "CarryLeg", [-0.098, ih - 0.016, 0.0, -0.118, ih - 0.016, 0.0, -0.15, 0.0215, 0.003, -0.1, 0.0215, 0.003],
					0.018, al, 0.002)
				WeaponModelBuilder.rear_aperture(root, 0.045, ih, al)
				WeaponModelBuilder.cyl(root, "WindageKnob", 0.0062, 0.006, Vector3(0.014, ih - 0.011, 0.04), al, 14, Vector3(0, PI * 0.5, 0), 0.0015)
				sight = Vector3(0, ih, zf)
			else:
				var zf := hf + 0.015
				_irons_flip(root, 0.045, zf, 0.031, ih)
				sight = Vector3(0, ih, zf)
			eye = _eye_irons(id, sight.z)

	# Cargador (STANAG levemente curvo, o corto de .22)
	var mag := WeaponModelBuilder.group(root, "Mag", Vector3(0, -0.07, rf + 0.051))
	var mag_len: float = p.get("mag_len", 0.15)
	if p.get("mag", "straight") == "short":
		WeaponModelBuilder.curved_mag(mag, 0.025, 0.1, 0.06, 0.062, 2.0, 0.023, al, poly)
	else:
		WeaponModelBuilder.curved_mag(mag, 0.025, mag_len + 0.025, 0.06, 0.064, 0.95 if not heavy else 2.5, 0.024, al, poly)

	WeaponModelBuilder.marker(root, "Sight", sight, eye)
	WeaponModelBuilder.marker(root, "Muzzle", Vector3(0, 0, muzzle))
	WeaponModelBuilder.marker(root, "Ejection", Vector3(0.0135, 0.005, -0.07))
	return root


# --- SC-L (tipo SCAR-L) ---------------------------------------------------------

static func scar(data: WeaponData) -> Node3D:
	var root := Node3D.new()
	var al := WeaponModelBuilder.mat("anodized")
	var tan := WeaponModelBuilder.mat("tan")
	var steel := WeaponModelBuilder.mat("metal")
	var rf := -0.33
	# Receptor superior monolítico de aluminio, con riel completo y rieles laterales
	WeaponModelBuilder.section(root, "Upper", [-0.0185, -0.016, 0.002, 0.0185, -0.016, 0.002, 0.0185, 0.018, 0.003, 0.014, 0.0245, 0.002,
		-0.014, 0.0245, 0.002, -0.0185, 0.018, 0.003], rf, 0.07, tan, 0.002)
	WeaponModelBuilder.rail(root, "TopRail", rf + 0.002, 0.068, 0.0245, al)
	for s: float in [-1.0, 1.0]:
		WeaponModelBuilder.rail(root, "SideRail", rf + 0.004, rf + 0.1, 0.0, al, Transform3D(Basis(Vector3(0, 0, 1), -s * PI * 0.5), Vector3(s * 0.0185, 0.002, 0)))
	WeaponModelBuilder.rail(root, "BottomRail", rf + 0.004, rf + 0.11, 0.0, al, Transform3D(Basis(Vector3(0, 0, 1), PI), Vector3(0, -0.016, 0)))
	WeaponModelBuilder.rbox(root, "Port", Vector3(0.0012, 0.013, 0.05), Vector3(0.0188, 0.004, -0.06), WeaponModelBuilder.mat("dark"), 0.002)
	# Inferior de polímero: brocal, guardamonte integrado y empuñadura
	WeaponModelBuilder.prism(root, "Lower", [0.068, -0.016, 0.0, -0.2, -0.016, 0.0, -0.205, -0.03, 0.006, -0.18, -0.052, 0.004,
		-0.1, -0.052, 0.0, -0.098, -0.048, 0.004, 0.04, -0.046, 0.0, 0.06, -0.04, 0.004, 0.068, -0.028, 0.004], 0.036, tan, 0.003)
	WeaponModelBuilder.prism(root, "MagWell", [-0.18, -0.05, 0.0, -0.1, -0.05, 0.0, -0.103, -0.09, 0.003, -0.178, -0.09, 0.003], 0.036, tan, 0.003)
	_guard_u(root, -0.098, 0.006, -0.046, 0.027, tan, 0.014)
	_trigger(root, -0.045, -0.046, steel)
	WeaponModelBuilder.prism(root, "Grip", [-0.004, -0.046, 0.0, 0.036, -0.046, 0.0, 0.04, -0.058, 0.008, 0.072, -0.128, 0.012, 0.068, -0.14, 0.006,
		0.032, -0.14, 0.006, 0.02, -0.112, 0.01, 0.002, -0.06, 0.006], 0.028, tan, 0.005)
	# Culata plegable con carrillera
	WeaponModelBuilder.rbox(root, "StockHinge", Vector3(0.032, 0.04, 0.03), Vector3(0, 0.0, 0.085), WeaponModelBuilder.mat("polymer"), 0.006)
	WeaponModelBuilder.prism(root, "Stock", [0.1, 0.022, 0.004, 0.29, 0.022, 0.008, 0.3, 0.004, 0.004, 0.302, -0.098, 0.006, 0.282, -0.102, 0.006,
		0.22, -0.05, 0.02, 0.14, -0.03, 0.01, 0.1, -0.022, 0.004], 0.036, tan, 0.005)
	WeaponModelBuilder.prism(root, "Cheek", [0.16, 0.022, 0.0, 0.27, 0.022, 0.0, 0.27, 0.034, 0.006, 0.18, 0.034, 0.008], 0.03, WeaponModelBuilder.mat("polymer"), 0.003)
	WeaponModelBuilder.prism(root, "ButtPad", [0.3, 0.006, 0.003, 0.314, 0.006, 0.003, 0.316, -0.102, 0.004, 0.302, -0.102, 0.003], 0.04, WeaponModelBuilder.mat("rubber"), 0.003)
	# Manija de carga lateral izquierda, adelante
	var ch := WeaponModelBuilder.group(root, "Charging", Vector3(-0.019, 0.006, -0.15))
	ch.set_meta("knob", Vector3(-0.014, 0, 0))
	WeaponModelBuilder.rbox(ch, "ChHandle", Vector3(0.018, 0.009, 0.014), Vector3(-0.009, 0, 0), steel, 0.003)
	# Caño y boca
	var bz := rf - 0.1
	WeaponModelBuilder.barrel(root, "Barrel", rf + 0.01, bz, 0.0115, 0.0092, steel, 0.0045)
	var muzzle := _muzzle_device(root, "a2", bz, steel)
	var sight := WeaponModelBuilder.red_dot(root, 0.034, -0.07)
	var mag := WeaponModelBuilder.group(root, "Mag", Vector3(0, -0.07, -0.14))
	WeaponModelBuilder.curved_mag(mag, 0.025, 0.175, 0.06, 0.064, 0.95, 0.024, WeaponModelBuilder.mat("tan"), WeaponModelBuilder.mat("polymer"))
	WeaponModelBuilder.marker(root, "Sight", sight, 0.24)
	WeaponModelBuilder.marker(root, "Muzzle", Vector3(0, 0, muzzle))
	WeaponModelBuilder.marker(root, "Ejection", Vector3(0.0185, 0.005, -0.06))
	return root


# --- Familia AK ------------------------------------------------------------------

## Receptor estampado, tapa, guardamonte, selector, manija y empuñadura del AK.
static func _ak_receiver(root: Node3D, rr: float, rf: float, grip_mat: Material, cover_front: float) -> void:
	var m := WeaponModelBuilder.mat("metal")
	WeaponModelBuilder.prism(root, "Receiver", [rr, 0.013, 0.0, rf, 0.013, 0.0, rf, -0.032, 0.003, rf + 0.008, -0.04, 0.002, 0.058, -0.04, 0.0,
		rr, -0.026, 0.003], 0.031, m, 0.0015)
	WeaponModelBuilder.section(root, "DustCover", [-0.0158, 0.011, 0.0, 0.0158, 0.011, 0.0, 0.0158, 0.019, 0.004, 0.009, 0.0285, 0.006,
		-0.009, 0.0285, 0.006, -0.0158, 0.019, 0.004], cover_front, rr + 0.002, m, 0.002)
	for i in 3:
		WeaponModelBuilder.section(root, "CoverRib", [-0.0161, 0.011, 0.0, 0.0161, 0.011, 0.0, 0.0161, 0.019, 0.004, 0.0092, 0.0289, 0.006,
			-0.0092, 0.0289, 0.006, -0.0161, 0.019, 0.004], cover_front + 0.05 + i * 0.05, cover_front + 0.056 + i * 0.05, m, 0.001)
	WeaponModelBuilder.cyl(root, "CoverButton", 0.0042, 0.008, Vector3(0, 0.016, rr + 0.005), m, 12, Vector3.ZERO, 0.0015)
	# Remaches
	for z: float in [rf + 0.012, rf + 0.024, 0.055, 0.04]:
		for s: float in [-1.0, 1.0]:
			WeaponModelBuilder.sphere(root, "Rivet", 0.0019, Vector3(s * 0.0156, -0.028, z), m, 8)
	# Retén del cargador, guardamonte, gatillo
	WeaponModelBuilder.prism(root, "MagCatch", [-0.098, -0.04, 0.0, -0.089, -0.04, 0.0, -0.088, -0.056, 0.002, -0.097, -0.057, 0.002], 0.013, m, 0.001)
	_guard_u(root, -0.088, 0.02, -0.04, 0.028, m, 0.012)
	_trigger(root, -0.04, -0.04, m)
	# Palanca selectora (lado derecho)
	WeaponModelBuilder.prism(root, "Selector", [0.03, 0.01, 0.002, -0.125, 0.01, 0.002, -0.128, 0.001, 0.002, -0.115, -0.001, 0.001, 0.0, 0.0, 0.002,
		0.022, -0.012, 0.003, 0.032, -0.006, 0.002], 0.002, m, 0.0005, Vector3(0.0165, 0, 0))
	# Empuñadura
	WeaponModelBuilder.prism(root, "Grip", [0.01, -0.04, 0.0, 0.05, -0.04, 0.0, 0.052, -0.05, 0.006, 0.078, -0.123, 0.01, 0.072, -0.135, 0.006,
		0.042, -0.137, 0.006, 0.034, -0.126, 0.006, 0.02, -0.085, 0.012, 0.012, -0.05, 0.004], 0.028, grip_mat, 0.005)


## Manija de carga del AK (lado derecho, adelante de la ventana).
static func _ak_charging(root: Node3D, z: float) -> void:
	var ch := WeaponModelBuilder.group(root, "Charging", Vector3(0.0158, 0.004, z))
	ch.set_meta("knob", Vector3(0.018, 0, 0))
	WeaponModelBuilder.cyl(ch, "ChStem", 0.0034, 0.016, Vector3(0.007, 0, 0), WeaponModelBuilder.mat("metal"), 10, Vector3(0, PI * 0.5, 0))
	WeaponModelBuilder.cyl(ch, "ChKnob", 0.0062, 0.01, Vector3(0.018, 0, 0), WeaponModelBuilder.mat("metal"), 14, Vector3(0, PI * 0.5, 0), 0.0025)


## Alza de hoja del AK con la muesca en z_notch y el puente de mira.
static func _ak_rear_sight(root: Node3D, z0: float, z1: float, z_notch: float, h: float) -> void:
	var m := WeaponModelBuilder.mat("metal")
	WeaponModelBuilder.prism(root, "RearBlock", [z0, 0.013, 0.0, z1, 0.013, 0.0, z1, 0.022, 0.002, z1 + 0.01, 0.031, 0.003, z0 - 0.005, 0.031, 0.003,
		z0, 0.026, 0.002], 0.03, m, 0.002)
	WeaponModelBuilder.prism(root, "RearLeaf", [z0 - 0.004, 0.031, 0.0, z0 - 0.008, 0.0335, 0.001, z_notch + 0.002, h - 0.009, 0.001,
		z_notch - 0.002, h - 0.012, 0.0, z_notch + 0.004, 0.031, 0.0], 0.024, m, 0.0008)
	WeaponModelBuilder.rbox(root, "RearSlider", Vector3(0.028, 0.006, 0.01), Vector3(0, lerpf(0.034, h - 0.01, 0.4) + 0.002, lerpf(z0 - 0.006, z_notch, 0.4)), m, 0.0015)
	WeaponModelBuilder.rear_notch(root, z_notch, h, m, 0.0042, h - 0.012)


static func _ak_stock(root: Node3D, m: Material) -> void:
	WeaponModelBuilder.prism(root, "Stock", [0.073, 0.012, 0.002, 0.34, -0.014, 0.006, 0.342, -0.14, 0.004, 0.32, -0.143, 0.006, 0.2, -0.088, 0.035,
		0.11, -0.05, 0.015, 0.073, -0.034, 0.003], 0.038, m, 0.007)
	WeaponModelBuilder.prism(root, "ButtPlate", [0.338, -0.012, 0.003, 0.35, -0.012, 0.004, 0.352, -0.141, 0.004, 0.34, -0.142, 0.003], 0.04,
		WeaponModelBuilder.mat("metal"), 0.003)


## AR-74 (AK-74M) y AR-M (AKM).
static func ak(data: WeaponData) -> Node3D:
	var root := Node3D.new()
	var p := data.model_params
	var m := WeaponModelBuilder.mat("metal")
	var is74 := data.id == "ak74"
	var furn := WeaponModelBuilder.mat("polymer") if is74 else WeaponModelBuilder.mat("wood_ak")
	var grip_mat := WeaponModelBuilder.mat("polymer") if is74 else WeaponModelBuilder.mat("bakelite")
	var rf := -0.205
	var ih: float = p.get("iron_h", 0.05)
	_ak_receiver(root, 0.075, rf, grip_mat, -0.13)
	_ak_rear_sight(root, -0.13, -0.205, -0.188, ih)
	_ak_charging(root, -0.112)
	_ak_stock(root, furn)
	# Caño, tubo de gases, guardamanos
	var barrel_len: float = p.get("barrel", 0.415)
	var bz := rf - barrel_len
	WeaponModelBuilder.barrel(root, "Barrel", rf, bz, 0.0118, 0.0092, m, 0.0045)
	var hg: float = p.get("hg", 0.22)
	var hf := rf - hg
	var z_gb := hf - 0.004
	WeaponModelBuilder.lathe(root, "GasTube", [z_gb - 0.01, 0.0, z_gb - 0.01, 0.0102, rf, 0.0102, rf, 0.0], m, Vector3(0, 0.027, 0), 14)
	# Guardamanos superior (sobre el tubo de gases) e inferior con ensanche para la palma
	WeaponModelBuilder.loft(root, "UpperHandguard", furn, rf - 0.008, rf - 0.165, [[0.0, 0.0162, 0.013, 0.039, 2.3], [0.8, 0.0162, 0.013, 0.0385, 2.3],
		[1.0, 0.0142, 0.015, 0.034, 2.6]])
	WeaponModelBuilder.loft(root, "Handguard", furn, rf - 0.004, hf, [[0.0, 0.0235, -0.039, 0.012, 3.2], [0.12, 0.0245, -0.035, 0.012, 2.6],
		[0.45, 0.0268, -0.0335, 0.012, 2.4], [0.85, 0.0245, -0.029, 0.012, 2.6], [1.0, 0.0215, -0.021, 0.011, 3.2]])
	if is74:
		# Nervios longitudinales del guardamanos de polímero
		for s: float in [-1.0, 1.0]:
			for k in 2:
				WeaponModelBuilder.rbox(root, "HgRib", Vector3(0.002, 0.0035, hg * 0.6), Vector3(s * (0.0235 - k * 0.006), -0.026 - k * 0.0045, rf - hg * 0.5),
					furn, 0.001)
	WeaponModelBuilder.loft(root, "HgRetainer", m, rf + 0.004, rf - 0.006, [[0.0, 0.025, -0.041, 0.016, 3.0], [1.0, 0.025, -0.041, 0.016, 3.0]], 2)
	WeaponModelBuilder.loft(root, "HgFrontCap", m, hf + 0.004, hf - 0.004, [[0.0, 0.0225, -0.024, 0.013, 3.2], [1.0, 0.0215, -0.022, 0.013, 3.2]], 2)
	# Bloque de gases a 45°, varilla de limpieza
	WeaponModelBuilder.prism(root, "GasBlock", [z_gb + 0.004, 0.038, 0.002, z_gb - 0.018, 0.038, 0.003, z_gb - 0.042, -0.012, 0.003,
		z_gb + 0.004, -0.012, 0.002], 0.026, m, 0.002)
	# Guion con orejas cerca de la boca
	var z_fs := bz + 0.04
	WeaponModelBuilder.lathe(root, "FsCollar", [z_fs - 0.018, 0.0, z_fs - 0.018, 0.0125, z_fs + 0.022, 0.0125, z_fs + 0.022, 0.0], m, Vector3.ZERO, 16)
	WeaponModelBuilder.front_post(root, z_fs, 0.006, ih, m, true, false, 0.016, 0.032)
	WeaponModelBuilder.rbox(root, "BayonetLug", Vector3(0.008, 0.014, 0.024), Vector3(0, -0.017, z_fs + 0.004), m, 0.002)
	WeaponModelBuilder.cyl(root, "CleaningRod", 0.003, z_fs - rf + 0.01, Vector3(0, -0.017, (z_fs + rf) * 0.5), m, 8)
	var muzzle := _muzzle_device(root, "ak74" if is74 else "akm", bz, m)
	# Cargador curvo
	var mag := WeaponModelBuilder.group(root, "Mag", Vector3(0, -0.04, -0.137))
	var mag_len: float = p.get("mag_len", 0.17)
	WeaponModelBuilder.curved_mag(mag, 0.022, mag_len + 0.03, 0.06, 0.076, 0.3 if not is74 else 0.36, 0.026,
		WeaponModelBuilder.mat("plum") if is74 else m, WeaponModelBuilder.mat("plum") if is74 else m)
	WeaponModelBuilder.marker(root, "Sight", Vector3(0, ih, z_fs), _eye_irons(data.id, z_fs))
	WeaponModelBuilder.marker(root, "Muzzle", Vector3(0, 0, muzzle))
	WeaponModelBuilder.marker(root, "Ejection", Vector3(0.0156, 0.006, -0.07))
	return root


## DR-1 (tipo SVD Dragunov): culata esqueletizada, visor PSO.
static func svd(data: WeaponData) -> Node3D:
	var root := Node3D.new()
	var m := WeaponModelBuilder.mat("metal")
	var wood := WeaponModelBuilder.mat("wood_ak")
	var rf := -0.24
	_ak_receiver(root, 0.075, rf, wood, -0.16)
	_ak_charging(root, -0.13)
	WeaponModelBuilder.rbox(root, "ScopeMountRail", Vector3(0.006, 0.026, 0.13), Vector3(-0.0185, -0.004, -0.07), m, 0.002)
	# Culata de madera con agujero para el pulgar (cuatro piezas)
	WeaponModelBuilder.prism(root, "StockComb", [0.073, 0.012, 0.002, 0.3, 0.016, 0.008, 0.34, 0.012, 0.006, 0.36, 0.005, 0.004, 0.362, -0.03, 0.004,
		0.33, -0.032, 0.004, 0.2, -0.026, 0.006, 0.09, -0.02, 0.004, 0.073, -0.01, 0.002], 0.036, wood, 0.006)
	WeaponModelBuilder.prism(root, "CheekPad", [0.14, 0.014, 0.006, 0.28, 0.02, 0.008, 0.29, 0.004, 0.004, 0.13, 0.002, 0.004], 0.04, WeaponModelBuilder.mat("polymer"), 0.005)
	WeaponModelBuilder.prism(root, "StockButt", [0.326, -0.028, 0.004, 0.362, -0.028, 0.004, 0.364, -0.15, 0.006, 0.33, -0.152, 0.006,
		0.322, -0.12, 0.004, 0.33, -0.06, 0.004], 0.036, wood, 0.006)
	WeaponModelBuilder.prism(root, "StockBottom", [0.33, -0.13, 0.004, 0.33, -0.152, 0.006, 0.12, -0.148, 0.01, 0.11, -0.128, 0.01], 0.03, wood, 0.006)
	WeaponModelBuilder.prism(root, "ButtPlate", [0.362, -0.026, 0.003, 0.372, -0.026, 0.003, 0.374, -0.152, 0.004, 0.364, -0.152, 0.003], 0.038,
		WeaponModelBuilder.mat("rubber"), 0.003)
	# La empuñadura del AK queda al frente del agujero; se completa hacia la base
	WeaponModelBuilder.prism(root, "GripLow", [0.07, -0.12, 0.004, 0.11, -0.128, 0.006, 0.122, -0.15, 0.006, 0.072, -0.14, 0.006], 0.028, wood, 0.004)
	# Caño largo, guardamanos con ventilaciones, gases y guion con capucha
	var bz := rf - 0.58
	WeaponModelBuilder.barrel(root, "Barrel", rf, bz, 0.012, 0.0095, m, 0.0045, Vector3.ZERO, 0.06)
	var hf := rf - 0.27
	WeaponModelBuilder.lathe(root, "GasTube", [hf - 0.03, 0.0, hf - 0.03, 0.0105, rf, 0.0105, rf, 0.0], m, Vector3(0, 0.027, 0), 14)
	WeaponModelBuilder.loft(root, "UpperHandguard", wood, rf - 0.006, hf + 0.004, [[0.0, 0.0168, 0.014, 0.039, 2.3], [0.9, 0.0165, 0.014, 0.038, 2.3],
		[1.0, 0.015, 0.015, 0.035, 2.6]])
	WeaponModelBuilder.loft(root, "Handguard", wood, rf, hf, [[0.0, 0.0245, -0.031, 0.013, 3.0], [0.5, 0.0255, -0.031, 0.013, 2.7],
		[1.0, 0.0235, -0.024, 0.013, 3.0]])
	for s: float in [-1.0, 1.0]:
		for i in 3:
			WeaponModelBuilder.rbox(root, "Vent", Vector3(0.0016, 0.009, 0.03), Vector3(s * 0.0252, -0.008, rf - 0.06 - i * 0.075), WeaponModelBuilder.mat("dark"), 0.0042)
			WeaponModelBuilder.rbox(root, "VentTop", Vector3(0.0016, 0.006, 0.022), Vector3(s * 0.0164, 0.027, rf - 0.04 - i * 0.06), WeaponModelBuilder.mat("dark"), 0.0028)
	WeaponModelBuilder.rbox(root, "HgRing", Vector3(0.053, 0.072, 0.012), Vector3(0, 0.002, hf - 0.004), m, 0.008)
	WeaponModelBuilder.prism(root, "GasBlock", [hf - 0.012, 0.039, 0.003, hf - 0.06, 0.039, 0.003, hf - 0.07, -0.012, 0.003, hf - 0.012, -0.012, 0.003],
		0.026, m, 0.002)
	var z_fs := bz + 0.03
	WeaponModelBuilder.lathe(root, "FsCollar", [z_fs - 0.016, 0.0, z_fs - 0.016, 0.0122, z_fs + 0.016, 0.0122, z_fs + 0.016, 0.0], m, Vector3.ZERO, 16)
	WeaponModelBuilder.front_post(root, z_fs, 0.006, 0.042, m, false, true, 0.014, 0.026)
	var muzzle := _muzzle_device(root, "svd", bz, m)
	# Visor PSO
	var sight := WeaponModelBuilder.scope(root, data, 0.074, 0.03, "pso")
	WeaponModelBuilder.rbox(root, "PsoMount", Vector3(0.012, 0.05, 0.11), Vector3(-0.016, 0.03, -0.075), m, 0.003)
	# Cargador de 10
	var mag := WeaponModelBuilder.group(root, "Mag", Vector3(0, -0.04, -0.137))
	WeaponModelBuilder.curved_mag(mag, 0.022, 0.15, 0.068, 0.074, 1.1, 0.025, m, m)
	WeaponModelBuilder.marker(root, "Sight", sight, 0.075)
	WeaponModelBuilder.marker(root, "Muzzle", Vector3(0, 0, muzzle))
	WeaponModelBuilder.marker(root, "Ejection", Vector3(0.0156, 0.006, -0.08))
	return root


## PP-B (tipo PP-19 Bizon): cargador helicoidal bajo el caño, culata plegable de tubo.
static func bizon(data: WeaponData) -> Node3D:
	var root := Node3D.new()
	var p := data.model_params
	var m := WeaponModelBuilder.mat("metal")
	var poly := WeaponModelBuilder.mat("polymer")
	var rf := -0.17
	var ih: float = p.get("iron_h", 0.05)
	_ak_receiver(root, 0.075, rf, poly, rf + 0.005)
	_ak_charging(root, -0.09)
	# Alza atrás sobre la tapa
	WeaponModelBuilder.rbox(root, "RearBase", Vector3(0.02, ih - 0.034, 0.02), Vector3(0, (ih - 0.024 + 0.026) * 0.5, -0.045), m, 0.002)
	WeaponModelBuilder.rear_notch(root, -0.05, ih, m, 0.0042, ih - 0.012)
	# Culata plegable de chapa (abierta)
	WeaponModelBuilder.rbox(root, "StockHinge", Vector3(0.03, 0.04, 0.02), Vector3(0, -0.012, 0.085), m, 0.004)
	WeaponModelBuilder.prism(root, "StockTop", [0.09, 0.006, 0.0, 0.285, 0.006, 0.002, 0.285, -0.008, 0.002, 0.09, -0.008, 0.0], 0.012, m, 0.002)
	WeaponModelBuilder.prism(root, "StockBottom", [0.09, -0.024, 0.0, 0.094, -0.036, 0.0, 0.28, -0.098, 0.002, 0.28, -0.086, 0.002], 0.012, m, 0.002)
	WeaponModelBuilder.prism(root, "ButtPlate", [0.276, 0.012, 0.003, 0.294, 0.012, 0.003, 0.296, -0.106, 0.004, 0.278, -0.106, 0.004], 0.036, m, 0.003)
	# Tapa sobre el caño, caño, guion
	WeaponModelBuilder.section(root, "BarrelCover", [-0.014, 0.004, 0.0, 0.014, 0.004, 0.0, 0.014, 0.014, 0.005, 0.008, 0.022, 0.006,
		-0.008, 0.022, 0.006, -0.014, 0.014, 0.005], rf - 0.13, rf, poly, 0.003)
	var bz := rf - 0.225
	WeaponModelBuilder.barrel(root, "Barrel", rf, bz, 0.0105, 0.009, m, 0.0045)
	var z_fs := bz + 0.025
	WeaponModelBuilder.lathe(root, "FsCollar", [z_fs - 0.018, 0.0, z_fs - 0.018, 0.0118, z_fs + 0.018, 0.0118, z_fs + 0.018, 0.0], m, Vector3.ZERO, 16)
	WeaponModelBuilder.front_post(root, z_fs, 0.006, ih, m, true, false, 0.016, 0.03)
	WeaponModelBuilder.lathe(root, "MuzzleNut", [bz - 0.012, 0.0, bz - 0.012, 0.0102, bz, 0.0102, bz, 0.0], m, Vector3.ZERO, 14)
	# Cargador helicoidal con estrías
	var mag := WeaponModelBuilder.group(root, "Mag", Vector3(0, -0.034, -0.085))
	mag.set_meta("grab", Vector3(0, -0.02, -0.13))
	var pts := [-0.28, 0.0, -0.28, 0.022, -0.276, 0.0285, -0.268, 0.031]
	var z := -0.25
	while z < -0.02:
		pts.append_array([z, 0.031, z, 0.0292, z + 0.006, 0.0292, z + 0.006, 0.031])
		z += 0.035
	pts.append_array([0.0, 0.031, 0.004, 0.026, 0.004, 0.0])
	WeaponModelBuilder.lathe(mag, "MagBody", pts, poly, Vector3.ZERO, 22)
	WeaponModelBuilder.rbox(mag, "MagLatch", Vector3(0.016, 0.012, 0.02), Vector3(0, 0.028, -0.27), poly, 0.003)
	WeaponModelBuilder.marker(root, "Sight", Vector3(0, ih, z_fs), _eye_irons(data.id, z_fs))
	WeaponModelBuilder.marker(root, "Muzzle", Vector3(0, 0, bz - 0.012))
	WeaponModelBuilder.marker(root, "Ejection", Vector3(0.0156, 0.006, -0.05))
	return root


## VK-19 (tipo PP-19-01 Vityaz): cajón de AK-74, 9×19 con cargador recto, culata
## tubular plegable (abierta), riel sobre la tapa y mira holográfica.
static func vityaz(data: WeaponData) -> Node3D:
	var root := Node3D.new()
	var p := data.model_params
	var m := WeaponModelBuilder.mat("metal")
	var poly := WeaponModelBuilder.mat("polymer")
	var rf := -0.205
	_ak_receiver(root, 0.075, rf, poly, -0.13)
	_ak_charging(root, -0.1)
	_ak_rear_sight(root, -0.13, -0.205, -0.188, 0.045)
	# Riel sobre la tapa (montura de la tapa trabada atrás)
	WeaponModelBuilder.rbox(root, "RailBase", Vector3(0.022, 0.004, 0.17), Vector3(0, 0.0295, -0.04), m, 0.0015)
	WeaponModelBuilder.rail(root, "TopRail", -0.125, 0.045, 0.0315, m)
	# Culata tubular plegable al costado (abierta) con tope de goma
	WeaponModelBuilder.rbox(root, "StockHinge", Vector3(0.034, 0.05, 0.026), Vector3(0, -0.01, 0.087), m, 0.005)
	WeaponModelBuilder.cyl(root, "StockHingePin", 0.006, 0.042, Vector3(0.0, -0.01, 0.092), m, 12, Vector3(PI * 0.5, 0, 0), 0.0015)
	WeaponModelBuilder.cyl(root, "StockTube", 0.0085, 0.2, Vector3(0, 0.0, 0.19), m, 14, Vector3.ZERO, 0.002)
	var a := atan2(0.062, 0.19)
	var lo := Vector3(0, -0.03, 0.1)
	var hi := Vector3(0, -0.092, 0.29)
	WeaponModelBuilder.cyl(root, "StockStrut", 0.0075, lo.distance_to(hi), (lo + hi) * 0.5, m, 12, Vector3(a, 0, 0), 0.002)
	WeaponModelBuilder.prism(root, "StockCheek", [0.13, 0.009, 0.002, 0.24, 0.009, 0.002, 0.24, -0.009, 0.002, 0.13, -0.009, 0.002], 0.022,
		poly, 0.003)
	WeaponModelBuilder.prism(root, "ButtFrame", [0.284, 0.014, 0.003, 0.3, 0.014, 0.003, 0.302, -0.112, 0.004, 0.286, -0.112, 0.004], 0.032, m, 0.003)
	WeaponModelBuilder.prism(root, "ButtPad", [0.3, 0.016, 0.004, 0.316, 0.014, 0.005, 0.318, -0.112, 0.005, 0.302, -0.115, 0.004], 0.036,
		WeaponModelBuilder.mat("rubber"), 0.005)
	# Caño de 237 mm, guardamanos de polímero corto con rieles a los costados
	var bz := rf - float(p.get("barrel", 0.237))
	WeaponModelBuilder.barrel(root, "Barrel", rf, bz, 0.0112, 0.0092, m, 0.0045)
	var hg: float = p.get("hg", 0.15)
	var hf := rf - hg
	WeaponModelBuilder.loft(root, "UpperHandguard", poly, rf - 0.006, hf + 0.012, [[0.0, 0.0158, 0.012, 0.03, 2.3], [1.0, 0.0145, 0.012, 0.028, 2.5]])
	WeaponModelBuilder.loft(root, "Handguard", poly, rf - 0.004, hf, [[0.0, 0.0235, -0.038, 0.012, 3.2], [0.15, 0.0248, -0.035, 0.012, 2.6],
		[0.55, 0.0262, -0.033, 0.012, 2.5], [0.9, 0.0245, -0.029, 0.012, 2.7], [1.0, 0.022, -0.022, 0.011, 3.2]])
	for s: float in [-1.0, 1.0]:
		WeaponModelBuilder.rail(root, "SideRail", rf - 0.04, hf + 0.01, 0.0, poly, Transform3D(Basis(Vector3.BACK, s * PI * 0.5),
			Vector3(s * 0.024, -0.008, 0)))
	WeaponModelBuilder.loft(root, "HgRetainer", m, rf + 0.004, rf - 0.006, [[0.0, 0.025, -0.041, 0.016, 3.0], [1.0, 0.025, -0.041, 0.016, 3.0]], 2)
	WeaponModelBuilder.loft(root, "HgFrontCap", m, hf + 0.004, hf - 0.004, [[0.0, 0.0225, -0.024, 0.013, 3.2], [1.0, 0.0215, -0.022, 0.013, 3.2]], 2)
	# Bloque de guion (sin toma de gases: es de retroceso directo)
	var z_fs := bz + 0.05
	WeaponModelBuilder.lathe(root, "FsCollar", [z_fs - 0.016, 0.0, z_fs - 0.016, 0.0122, z_fs + 0.02, 0.0122, z_fs + 0.02, 0.0], m, Vector3.ZERO, 16)
	WeaponModelBuilder.front_post(root, z_fs, 0.006, 0.045, m, true, false, 0.016, 0.03)
	var muzzle := _muzzle_device(root, "g3", bz, m)
	# Cargador recto de 30 (9×19, levemente curvo)
	var mag := WeaponModelBuilder.group(root, "Mag", Vector3(0, -0.04, -0.14))
	WeaponModelBuilder.curved_mag(mag, 0.022, float(p.get("mag_len", 0.19)), 0.042, 0.046, 1.4, 0.024, poly, poly)
	for i in 3:
		WeaponModelBuilder.rbox(mag, "MagRib", Vector3(0.0255, 0.003, 0.03), Vector3(0, -0.04 - i * 0.035, -0.005 - i * 0.0045), poly, 0.001)
	var sight := WeaponModelBuilder.holo(root, 0.041, -0.045)
	WeaponModelBuilder.marker(root, "Sight", sight, 0.24)
	WeaponModelBuilder.marker(root, "Muzzle", Vector3(0, 0, muzzle))
	WeaponModelBuilder.marker(root, "Ejection", Vector3(0.0156, 0.006, -0.07))
	return root


# --- MK5 (tipo MP5) -----------------------------------------------------------

static func mp5(data: WeaponData) -> Node3D:
	var root := Node3D.new()
	var p := data.model_params
	var m := WeaponModelBuilder.mat("metal")
	var poly := WeaponModelBuilder.mat("polymer")
	var ih: float = p.get("iron_h", 0.06)
	var rf := -0.175
	# Receptor tubular estampado con nervios laterales
	WeaponModelBuilder.section(root, "Receiver", [-0.0165, -0.022, 0.002, 0.0165, -0.022, 0.002, 0.0165, 0.012, 0.004, 0.011, 0.024, 0.008,
		-0.011, 0.024, 0.008, -0.0165, 0.012, 0.004], rf, 0.07, m, 0.002)
	for s: float in [-1.0, 1.0]:
		WeaponModelBuilder.rbox(root, "Rib", Vector3(0.0015, 0.004, 0.2), Vector3(s * 0.0168, -0.004, -0.06), m, 0.001)
	WeaponModelBuilder.rbox(root, "EndCap", Vector3(0.035, 0.05, 0.012), Vector3(0, 0.0, 0.074), m, 0.004)
	# Tubo de amartillar sobre el caño y manija adelante a la izquierda
	WeaponModelBuilder.lathe(root, "CockingTube", [-0.335, 0.0, -0.335, 0.0105, rf, 0.0105, rf, 0.0], m, Vector3(0, 0.018, 0), 16)
	var ch := WeaponModelBuilder.group(root, "Charging", Vector3(-0.009, 0.024, -0.285))
	ch.set_meta("knob", Vector3(-0.022, 0.013, 0))
	WeaponModelBuilder.rbox(ch, "ChLever", Vector3(0.026, 0.006, 0.01), Vector3(-0.011, 0.006, 0), m, 0.002, Vector3(0, 0, -0.6))
	WeaponModelBuilder.cyl(ch, "ChKnob", 0.0045, 0.012, Vector3(-0.022, 0.013, 0.0), m, 10, Vector3.ZERO, 0.002)
	# Guion con capucha y alza de tambor
	var z_fs := -0.335
	WeaponModelBuilder.prism(root, "FrontTower", [z_fs + 0.012, 0.022, 0.002, z_fs - 0.012, 0.022, 0.002, z_fs - 0.006, ih - 0.007, 0.0,
		z_fs + 0.006, ih - 0.007, 0.0], 0.012, m, 0.0015)
	WeaponModelBuilder.tube(root, "FrontHood", 0.0078, 0.0098, 0.014, Vector3(0, ih, z_fs), m, 20)
	WeaponModelBuilder.rbox(root, "FrontPost", Vector3(0.0028, 0.0085, 0.003), Vector3(0, ih - 0.004, z_fs), m, 0.0005)
	WeaponModelBuilder.cyl(root, "RearDrum", 0.0085, 0.02, Vector3(0, ih - 0.0145, 0.04), m, 16, Vector3(0, PI * 0.5, 0), 0.002)
	WeaponModelBuilder.rbox(root, "RearDrumBase", Vector3(0.02, ih - 0.03, 0.02), Vector3(0, (ih - 0.03) * 0.5 + 0.022, 0.04), m, 0.002)
	WeaponModelBuilder.rear_aperture(root, 0.04, ih, m)
	# Guardamanos delgado
	# Guardamanos delgado: se afina hacia adelante y termina en un tope para la mano
	WeaponModelBuilder.loft(root, "Handguard", poly, rf, -0.33, [[0.0, 0.0232, -0.036, 0.0065, 2.7], [0.2, 0.0228, -0.034, 0.0065, 2.4],
		[0.78, 0.0202, -0.028, 0.0055, 2.4], [0.88, 0.0222, -0.036, 0.0055, 2.6], [1.0, 0.0185, -0.016, 0.004, 3.0]])
	for s: float in [-1.0, 1.0]:
		WeaponModelBuilder.rbox(root, "HgGroove", Vector3(0.0016, 0.004, 0.08), Vector3(s * 0.0214, -0.014, -0.235), WeaponModelBuilder.mat("dark"), 0.0015)
	# Caño con los tres tetones
	var bz := rf - 0.2
	WeaponModelBuilder.barrel(root, "Barrel", rf, bz, 0.0098, 0.0092, m, 0.0045)
	WeaponModelBuilder.lathe(root, "TriLug", [bz - 0.004, 0.0, bz - 0.004, 0.0108, bz + 0.012, 0.0108, bz + 0.016, 0.0094, bz + 0.016, 0.0], m, Vector3.ZERO, 6)
	# Brocal y retén de paleta
	WeaponModelBuilder.prism(root, "MagWell", [-0.135, -0.022, 0.0, -0.09, -0.022, 0.0, -0.092, -0.046, 0.002, -0.133, -0.046, 0.002], 0.028, m, 0.0015)
	WeaponModelBuilder.prism(root, "Paddle", [-0.09, -0.04, 0.0, -0.084, -0.04, 0.0, -0.08, -0.054, 0.002, -0.088, -0.054, 0.002], 0.016, m, 0.001)
	# Grupo del disparador de polímero, guardamonte y empuñadura
	WeaponModelBuilder.prism(root, "TriggerHousing", [0.068, -0.022, 0.0, -0.082, -0.022, 0.0, -0.082, -0.034, 0.003, 0.068, -0.034, 0.003], 0.03, poly, 0.002)
	_guard_u(root, -0.082, 0.004, -0.034, 0.03, poly, 0.014)
	_trigger(root, -0.04, -0.034, m)
	WeaponModelBuilder.prism(root, "Grip", [0.0, -0.034, 0.0, 0.052, -0.034, 0.0, 0.058, -0.048, 0.006, 0.07, -0.122, 0.01, 0.062, -0.132, 0.006,
		0.034, -0.132, 0.006, 0.026, -0.118, 0.004, 0.014, -0.075, 0.012, 0.004, -0.05, 0.004], 0.03, poly, 0.005)
	WeaponModelBuilder.cyl(root, "SelectorL", 0.007, 0.004, Vector3(-0.0165, -0.028, 0.02), poly, 14, Vector3(0, PI * 0.5, 0))
	# Culata retráctil de dos varillas
	for s: float in [-1.0, 1.0]:
		WeaponModelBuilder.rbox(root, "StockStrut", Vector3(0.006, 0.008, 0.2), Vector3(s * 0.0145, -0.012, 0.17), m, 0.0025)
	WeaponModelBuilder.prism(root, "StockButt", [0.25, 0.014, 0.005, 0.27, 0.014, 0.004, 0.275, -0.075, 0.006, 0.255, -0.08, 0.006, 0.246, -0.02, 0.004],
		0.044, m, 0.004)
	WeaponModelBuilder.prism(root, "ButtPad", [0.268, 0.014, 0.003, 0.28, 0.014, 0.003, 0.284, -0.076, 0.004, 0.272, -0.078, 0.003], 0.046, WeaponModelBuilder.mat("rubber"), 0.003)
	# Cargador curvo de 9 mm
	var mag := WeaponModelBuilder.group(root, "Mag", Vector3(0, -0.045, -0.112))
	var mag_len: float = p.get("mag_len", 0.2)
	WeaponModelBuilder.curved_mag(mag, 0.022, mag_len, 0.036, 0.04, 0.55, 0.022, m, m)
	WeaponModelBuilder.marker(root, "Sight", Vector3(0, ih, z_fs), _eye_irons(data.id, z_fs))
	WeaponModelBuilder.marker(root, "Muzzle", Vector3(0, 0, bz - 0.004))
	WeaponModelBuilder.marker(root, "Ejection", Vector3(0.0165, 0.006, -0.06))
	return root


# --- FMR (tipo FAL argentino) ------------------------------------------------------

static func fal(data: WeaponData) -> Node3D:
	var root := Node3D.new()
	var p := data.model_params
	var m := WeaponModelBuilder.mat("metal")
	var poly := WeaponModelBuilder.mat("polymer")
	var rf := -0.205
	# Receptor superior fresado y tapa
	WeaponModelBuilder.prism(root, "Upper", [0.07, -0.012, 0.0, rf, -0.012, 0.0, rf, 0.022, 0.003, rf + 0.015, 0.026, 0.002, 0.05, 0.026, 0.002,
		0.07, 0.014, 0.006], 0.03, m, 0.0015)
	WeaponModelBuilder.section(root, "TopCover", [-0.0135, 0.022, 0.0, 0.0135, 0.022, 0.0, 0.0135, 0.027, 0.003, -0.0135, 0.027, 0.003], -0.16, 0.06, m, 0.0015)
	WeaponModelBuilder.rail(root, "TopRail", -0.15, 0.04, 0.027, WeaponModelBuilder.mat("anodized"))
	WeaponModelBuilder.rbox(root, "Port", Vector3(0.0012, 0.016, 0.06), Vector3(0.0152, 0.006, -0.07), WeaponModelBuilder.mat("dark"), 0.002)
	# Receptor inferior con brocal
	WeaponModelBuilder.prism(root, "Lower", [0.075, -0.012, 0.0, -0.2, -0.012, 0.0, -0.2, -0.025, 0.003, -0.185, -0.075, 0.003, -0.105, -0.075, 0.003,
		-0.1, -0.045, 0.004, 0.06, -0.045, 0.0, 0.075, -0.03, 0.004], 0.034, WeaponModelBuilder.mat("alloy"), 0.002)
	WeaponModelBuilder.pin(root, Vector3(0, -0.02, 0.06), 0.003, 0.038)
	_guard_u(root, -0.1, 0.004, -0.045, 0.027, WeaponModelBuilder.mat("alloy"))
	_trigger(root, -0.045, -0.045, m)
	WeaponModelBuilder.prism(root, "Grip", [-0.002, -0.045, 0.0, 0.036, -0.045, 0.0, 0.04, -0.056, 0.006, 0.066, -0.128, 0.01, 0.06, -0.138, 0.006,
		0.03, -0.138, 0.006, 0.022, -0.12, 0.004, 0.008, -0.07, 0.012, 0.0, -0.05, 0.004], 0.028, poly, 0.005)
	WeaponModelBuilder.prism(root, "Selector", [0.02, -0.02, 0.003, -0.01, -0.02, 0.002, -0.015, -0.03, 0.002, 0.01, -0.03, 0.003], 0.003, m, 0.0008,
		Vector3(-0.0178, 0, 0))
	# Culata fija de polímero
	WeaponModelBuilder.prism(root, "Stock", [0.07, 0.02, 0.003, 0.33, 0.006, 0.006, 0.333, -0.128, 0.006, 0.305, -0.13, 0.01, 0.23, -0.082, 0.03,
		0.15, -0.054, 0.03, 0.075, -0.036, 0.004], 0.038, poly, 0.006)
	WeaponModelBuilder.prism(root, "ButtPlate", [0.33, 0.007, 0.003, 0.342, 0.007, 0.004, 0.344, -0.129, 0.004, 0.334, -0.13, 0.003], 0.042, m, 0.003)
	# Manija de carga plegable a la izquierda
	var ch := WeaponModelBuilder.group(root, "Charging", Vector3(-0.0155, 0.008, -0.17))
	ch.set_meta("knob", Vector3(-0.012, 0, 0))
	WeaponModelBuilder.rbox(ch, "ChHandle", Vector3(0.016, 0.01, 0.012), Vector3(-0.008, 0, 0), m, 0.003)
	# Guardamanos con ventilaciones, bloque de gases con regulador
	var hg: float = p.get("hg", 0.25)
	var hf := rf - hg
	WeaponModelBuilder.loft(root, "Handguard", poly, rf, hf, [[0.0, 0.026, -0.035, 0.018, 3.4], [0.12, 0.0272, -0.034, 0.018, 2.8],
		[0.82, 0.0265, -0.03, 0.018, 2.8], [1.0, 0.022, -0.019, 0.016, 3.2]])
	for s: float in [-1.0, 1.0]:
		for i in 5:
			for row in 2:
				WeaponModelBuilder.rbox(root, "Vent", Vector3(0.0016, 0.0065, 0.016), Vector3(s * 0.0268, 0.005 - row * 0.016, rf - 0.045 - i * (hg - 0.08) / 4.0),
					WeaponModelBuilder.mat("dark"), 0.0031)
	var z_gb := hf - 0.005
	WeaponModelBuilder.prism(root, "GasBlock", [z_gb, 0.034, 0.003, z_gb - 0.04, 0.034, 0.003, z_gb - 0.044, -0.012, 0.003, z_gb, -0.012, 0.003], 0.026, m, 0.002)
	WeaponModelBuilder.cyl(root, "Regulator", 0.0078, 0.016, Vector3(0, 0.022, z_gb - 0.05), m, 14, Vector3.ZERO, 0.002)
	WeaponModelBuilder.front_post(root, z_gb - 0.03, 0.03, 0.05, m, true, false, 0.012, 0.016)
	var bz := rf - float(p.get("barrel", 0.44))
	WeaponModelBuilder.barrel(root, "Barrel", rf, bz, 0.0125, 0.0098, m, 0.0045)
	var muzzle := _muzzle_device(root, "fal", bz, m)
	var sight := WeaponModelBuilder.red_dot(root, 0.0365, -0.07)
	# Cargador recto de 20
	var mag := WeaponModelBuilder.group(root, "Mag", Vector3(0, -0.075, -0.145))
	WeaponModelBuilder.curved_mag(mag, 0.025, float(p.get("mag_len", 0.14)) + 0.02, 0.066, 0.07, 1.6, 0.026, m, m)
	WeaponModelBuilder.marker(root, "Sight", sight, 0.24)
	WeaponModelBuilder.marker(root, "Muzzle", Vector3(0, 0, muzzle))
	WeaponModelBuilder.marker(root, "Ejection", Vector3(0.0152, 0.006, -0.07))
	return root


# --- G-3A (tipo G3) -----------------------------------------------------------

static func g3(data: WeaponData) -> Node3D:
	var root := Node3D.new()
	var p := data.model_params
	var m := WeaponModelBuilder.mat("metal")
	var poly := WeaponModelBuilder.mat("polymer")
	var ih: float = p.get("iron_h", 0.06)
	var rf := -0.205
	WeaponModelBuilder.section(root, "Receiver", [-0.0175, -0.024, 0.002, 0.0175, -0.024, 0.002, 0.0175, 0.012, 0.004, 0.012, 0.023, 0.008,
		-0.012, 0.023, 0.008, -0.0175, 0.012, 0.004], rf, 0.07, m, 0.002)
	for s: float in [-1.0, 1.0]:
		WeaponModelBuilder.rbox(root, "Rib", Vector3(0.0015, 0.004, 0.24), Vector3(s * 0.0177, 0.003, -0.07), m, 0.001)
		WeaponModelBuilder.rbox(root, "RibLow", Vector3(0.0015, 0.003, 0.24), Vector3(s * 0.0177, -0.014, -0.07), m, 0.001)
	WeaponModelBuilder.rbox(root, "Port", Vector3(0.0012, 0.014, 0.05), Vector3(0.0178, 0.004, -0.06), WeaponModelBuilder.mat("dark"), 0.002)
	WeaponModelBuilder.prism(root, "MagWell", [-0.175, -0.024, 0.0, -0.1, -0.024, 0.0, -0.102, -0.068, 0.002, -0.172, -0.068, 0.002], 0.03, m, 0.0015)
	WeaponModelBuilder.prism(root, "Paddle", [-0.1, -0.06, 0.0, -0.092, -0.06, 0.0, -0.088, -0.074, 0.002, -0.098, -0.074, 0.002], 0.016, m, 0.001)
	# Tubo de amartillar sobre el caño, manija adelante a la izquierda
	var z_fs := -0.47
	WeaponModelBuilder.lathe(root, "CockingTube", [z_fs, 0.0, z_fs, 0.0125, rf, 0.0125, rf, 0.0], m, Vector3(0, 0.026, 0), 18)
	var ch := WeaponModelBuilder.group(root, "Charging", Vector3(-0.012, 0.03, -0.3))
	ch.set_meta("knob", Vector3(-0.019, 0.012, 0))
	WeaponModelBuilder.rbox(ch, "ChLever", Vector3(0.024, 0.007, 0.011), Vector3(-0.01, 0.006, 0), m, 0.002, Vector3(0, 0, -0.6))
	# Guion con capucha y alza de tambor
	WeaponModelBuilder.prism(root, "FrontBlock", [z_fs + 0.016, 0.04, 0.003, z_fs - 0.014, 0.04, 0.003, z_fs - 0.014, -0.012, 0.003, z_fs + 0.016, -0.012, 0.003],
		0.026, m, 0.002)
	WeaponModelBuilder.prism(root, "FrontTower", [z_fs + 0.01, 0.038, 0.0, z_fs - 0.01, 0.038, 0.0, z_fs - 0.006, ih - 0.008, 0.0, z_fs + 0.006, ih - 0.008, 0.0],
		0.012, m, 0.0015)
	WeaponModelBuilder.tube(root, "FrontHood", 0.0078, 0.0098, 0.014, Vector3(0, ih, z_fs), m, 20)
	WeaponModelBuilder.rbox(root, "FrontPost", Vector3(0.0028, 0.0085, 0.003), Vector3(0, ih - 0.004, z_fs), m, 0.0005)
	WeaponModelBuilder.prism(root, "RearBase", [0.02, 0.022, 0.0, -0.02, 0.022, 0.0, -0.016, ih - 0.022, 0.003, 0.016, ih - 0.022, 0.003], 0.026, m, 0.002)
	WeaponModelBuilder.cyl(root, "RearDrum", 0.0095, 0.022, Vector3(0, ih - 0.016, 0.0), m, 16, Vector3(0, PI * 0.5, 0), 0.002)
	WeaponModelBuilder.rear_aperture(root, 0.004, ih, m)
	# Guardamanos delgado, grupo del disparador y empuñadura
	var hf := -0.445
	WeaponModelBuilder.loft(root, "Handguard", poly, rf, hf, [[0.0, 0.0245, -0.038, 0.014, 3.2], [0.1, 0.025, -0.035, 0.014, 2.7],
		[0.88, 0.0238, -0.031, 0.014, 2.7], [1.0, 0.02, -0.014, 0.012, 3.2]])
	for s: float in [-1.0, 1.0]:
		for i in 4:
			for row in 2:
				WeaponModelBuilder.cyl(root, "Vent", 0.0034, 0.003, Vector3(s * 0.0245, 0.002 - row * 0.015, rf - 0.035 - i * 0.05 - row * 0.025),
					WeaponModelBuilder.mat("dark"), 12, Vector3(0, PI * 0.5, 0))
	WeaponModelBuilder.prism(root, "TriggerHousing", [0.065, -0.024, 0.0, -0.098, -0.024, 0.0, -0.098, -0.036, 0.003, 0.065, -0.036, 0.003], 0.032, poly, 0.002)
	_guard_u(root, -0.098, 0.006, -0.036, 0.032, poly, 0.014)
	_trigger(root, -0.05, -0.036, m)
	WeaponModelBuilder.prism(root, "Grip", [-0.002, -0.036, 0.0, 0.05, -0.036, 0.0, 0.056, -0.05, 0.006, 0.07, -0.125, 0.01, 0.062, -0.136, 0.006,
		0.032, -0.136, 0.006, 0.024, -0.12, 0.004, 0.012, -0.078, 0.012, 0.002, -0.052, 0.004], 0.03, poly, 0.005)
	WeaponModelBuilder.pin(root, Vector3(0, -0.03, 0.055), 0.0028, 0.036)
	WeaponModelBuilder.pin(root, Vector3(0, -0.03, -0.09), 0.0028, 0.036)
	_fixed_stock(root, poly, 0.02)
	var bz := rf - float(p.get("barrel", 0.42))
	WeaponModelBuilder.barrel(root, "Barrel", rf, bz, 0.0118, 0.0095, m, 0.0045)
	var muzzle := _muzzle_device(root, "g3", bz, m)
	var mag := WeaponModelBuilder.group(root, "Mag", Vector3(0, -0.068, -0.137))
	WeaponModelBuilder.curved_mag(mag, 0.025, float(p.get("mag_len", 0.15)) + 0.02, 0.066, 0.07, 0.9, 0.026, m, m)
	WeaponModelBuilder.marker(root, "Sight", Vector3(0, ih, z_fs), _eye_irons(data.id, z_fs))
	WeaponModelBuilder.marker(root, "Muzzle", Vector3(0, 0, muzzle))
	WeaponModelBuilder.marker(root, "Ejection", Vector3(0.0178, 0.005, -0.06))
	return root


# --- SK-45 (tipo SKS) -----------------------------------------------------------

static func sks(data: WeaponData) -> Node3D:
	var root := Node3D.new()
	var p := data.model_params
	var m := WeaponModelBuilder.mat("metal")
	var wood := WeaponModelBuilder.mat("wood")
	var ih: float = p.get("iron_h", 0.045)
	var rf := -0.155
	# Caja de madera completa con garganta recta
	WeaponModelBuilder.prism(root, "Stock", [-0.42, 0.002, 0.004, -0.16, 0.002, 0.0, -0.15, -0.008, 0.0, 0.065, -0.008, 0.0, 0.075, 0.006, 0.004,
		0.36, -0.02, 0.004, 0.364, -0.148, 0.004, 0.33, -0.147, 0.01, 0.16, -0.09, 0.03, 0.09, -0.072, 0.02, 0.045, -0.054, 0.006,
		-0.06, -0.04, 0.0, -0.17, -0.04, 0.0, -0.42, -0.028, 0.008], 0.042, wood, 0.009)
	WeaponModelBuilder.prism(root, "ButtPlate", [0.358, -0.019, 0.003, 0.37, -0.019, 0.003, 0.374, -0.149, 0.004, 0.362, -0.149, 0.003], 0.044, m, 0.003)
	# Cajón y tapa
	WeaponModelBuilder.prism(root, "Receiver", [0.07, -0.008, 0.0, rf, -0.008, 0.0, rf, 0.016, 0.002, rf + 0.015, 0.02, 0.002, 0.06, 0.02, 0.003,
		0.07, 0.01, 0.004], 0.03, m, 0.0015)
	WeaponModelBuilder.section(root, "Cover", [-0.014, 0.014, 0.0, 0.014, 0.014, 0.0, 0.014, 0.02, 0.003, 0.009, 0.027, 0.005, -0.009, 0.027, 0.005,
		-0.014, 0.02, 0.003], -0.06, 0.078, m, 0.002)
	# Alza tangente
	WeaponModelBuilder.prism(root, "RearBase", [-0.1, 0.02, 0.0, rf, 0.02, 0.0, rf - 0.003, 0.028, 0.002, -0.1, 0.028, 0.002], 0.026, m, 0.0015)
	WeaponModelBuilder.prism(root, "RearLeaf", [rf + 0.003, 0.028, 0.0, rf + 0.007, 0.031, 0.001, -0.121, ih - 0.007, 0.001, -0.117, ih - 0.009, 0.0,
		-0.121, 0.028, 0.0], 0.022, m, 0.0008)
	WeaponModelBuilder.rear_notch(root, -0.12, ih, m, 0.0042, ih - 0.012)
	var ch := WeaponModelBuilder.group(root, "Charging", Vector3(0.015, 0.012, -0.03))
	ch.set_meta("knob", Vector3(0.016, 0, 0))
	WeaponModelBuilder.cyl(ch, "ChStem", 0.0034, 0.014, Vector3(0.006, 0, 0), m, 10, Vector3(0, PI * 0.5, 0))
	WeaponModelBuilder.cyl(ch, "ChKnob", 0.0065, 0.01, Vector3(0.016, 0, 0), m, 14, Vector3(0, PI * 0.5, 0), 0.0025)
	# Tubo de gases con guardamanos superior, bloque de gases, abrazadera
	var z_gb := -0.43
	WeaponModelBuilder.lathe(root, "GasTube", [z_gb, 0.0, z_gb, 0.0095, rf, 0.0095, rf, 0.0], m, Vector3(0, 0.023, 0), 14)
	WeaponModelBuilder.loft(root, "UpperHandguard", wood, rf - 0.008, -0.39, [[0.0, 0.0155, 0.012, 0.037, 2.3], [0.88, 0.0152, 0.012, 0.036, 2.3],
		[1.0, 0.0135, 0.013, 0.032, 2.6]])
	WeaponModelBuilder.prism(root, "GasBlock", [z_gb + 0.005, 0.033, 0.003, z_gb - 0.03, 0.033, 0.003, z_gb - 0.032, -0.012, 0.003, z_gb + 0.005, -0.012, 0.003],
		0.024, m, 0.002)
	WeaponModelBuilder.rbox(root, "Band", Vector3(0.046, 0.04, 0.012), Vector3(0, -0.012, -0.405), m, 0.006)
	# Caño, bayoneta plegada, guion con capucha
	var bz := rf - float(p.get("barrel", 0.48))
	WeaponModelBuilder.barrel(root, "Barrel", rf, bz, 0.0118, 0.0095, m, 0.0045)
	WeaponModelBuilder.prism(root, "Bayonet", [bz + 0.015, -0.014, 0.002, -0.385, -0.016, 0.001, -0.38, -0.02, 0.0, -0.385, -0.024, 0.002, bz + 0.035, -0.026, 0.002,
		bz + 0.015, -0.022, 0.002], 0.004, WeaponModelBuilder.mat("steel"), 0.0008)
	WeaponModelBuilder.rbox(root, "BayonetHinge", Vector3(0.02, 0.022, 0.03), Vector3(0, -0.016, bz + 0.03), m, 0.004)
	var z_fs := bz + 0.012
	WeaponModelBuilder.prism(root, "FrontTower", [z_fs + 0.016, -0.012, 0.002, z_fs - 0.012, -0.012, 0.002, z_fs - 0.006, ih - 0.008, 0.002,
		z_fs + 0.008, ih - 0.008, 0.002], 0.016, m, 0.0015)
	WeaponModelBuilder.tube(root, "FrontHood", 0.0078, 0.0098, 0.014, Vector3(0, ih, z_fs), m, 20)
	WeaponModelBuilder.rbox(root, "FrontPost", Vector3(0.0028, 0.0085, 0.003), Vector3(0, ih - 0.004, z_fs), m, 0.0005)
	# Cargador fijo y guardamonte
	WeaponModelBuilder.prism(root, "MagBox", [-0.155, -0.035, 0.0, -0.06, -0.035, 0.0, -0.062, -0.06, 0.006, -0.08, -0.07, 0.008, -0.15, -0.068, 0.008],
		0.03, m, 0.002)
	_guard_u(root, -0.058, 0.042, -0.042, 0.03, m)
	_trigger(root, -0.02, -0.042, m)
	WeaponModelBuilder.marker(root, "Sight", Vector3(0, ih, z_fs), _eye_irons(data.id, z_fs))
	WeaponModelBuilder.marker(root, "Muzzle", Vector3(0, 0, bz - 0.002))
	WeaponModelBuilder.marker(root, "Ejection", Vector3(0.015, 0.012, -0.04))
	return root


# --- M-14E (tipo M14 EBR) -------------------------------------------------------

static func ebr(data: WeaponData) -> Node3D:
	var root := Node3D.new()
	var p := data.model_params
	var m := WeaponModelBuilder.mat("metal")
	var al := WeaponModelBuilder.mat("anodized")
	var poly := WeaponModelBuilder.mat("polymer")
	var rf := -0.2
	# Chasis de aluminio con rieles
	WeaponModelBuilder.prism(root, "Chassis", [0.065, 0.008, 0.0, -0.47, 0.008, 0.004, -0.47, -0.034, 0.006, -0.18, -0.034, 0.0, -0.18, -0.04, 0.0,
		-0.095, -0.04, 0.0, -0.095, -0.034, 0.0, 0.065, -0.034, 0.004], 0.054, al, 0.003)
	for s: float in [-1.0, 1.0]:
		WeaponModelBuilder.rail(root, "SideRail", -0.46, -0.3, 0.0, al, Transform3D(Basis(Vector3(0, 0, 1), -s * PI * 0.5), Vector3(s * 0.027, -0.013, 0)))
		for i in 3:
			WeaponModelBuilder.rbox(root, "Cut", Vector3(0.0012, 0.012, 0.03), Vector3(s * 0.0272, -0.013, -0.27 + i * 0.045), WeaponModelBuilder.mat("dark"), 0.004)
	WeaponModelBuilder.rail(root, "BottomRail", -0.46, -0.24, 0.0, al, Transform3D(Basis(Vector3(0, 0, 1), PI), Vector3(0, -0.034, 0)))
	# Cajón del M14 y riel alto para el visor
	WeaponModelBuilder.section(root, "Receiver", [-0.015, 0.008, 0.0, 0.015, 0.008, 0.0, 0.015, 0.024, 0.004, 0.009, 0.032, 0.006, -0.009, 0.032, 0.006,
		-0.015, 0.024, 0.004], rf, 0.06, m, 0.002)
	for z: float in [-0.15, 0.02]:
		WeaponModelBuilder.rbox(root, "RailPost", Vector3(0.024, 0.012, 0.02), Vector3(0, 0.036, z), al, 0.002)
	WeaponModelBuilder.rail(root, "TopRail", -0.17, 0.055, 0.04, al)
	var ch := WeaponModelBuilder.group(root, "Charging", Vector3(0.016, 0.014, -0.11))
	ch.set_meta("knob", Vector3(0.014, 0, 0))
	WeaponModelBuilder.prism(ch, "OpRod", [0.012, 0.004, 0.002, -0.012, 0.004, 0.002, -0.014, -0.006, 0.002, 0.008, -0.006, 0.003, 0.012, 0.0, 0.002],
		0.012, m, 0.0015, Vector3(0.006, 0, 0))
	# Empuñadura, guardamonte, culata retráctil con carrillera
	_guard_u(root, -0.09, 0.006, -0.034, 0.03, al)
	_trigger(root, -0.045, -0.034, m)
	_grip_ar(root, -0.034, poly)
	_buffer_stock(root, poly, true)
	# Caño y freno
	var bz := rf - float(p.get("barrel", 0.48))
	WeaponModelBuilder.barrel(root, "Barrel", rf, bz, 0.0128, 0.0102, m, 0.0045)
	var muzzle := _muzzle_device(root, "brake", bz, m)
	var sight := WeaponModelBuilder.scope(root, data, 0.0755, 0.0495, "hunting")
	var mag := WeaponModelBuilder.group(root, "Mag", Vector3(0, -0.04, -0.137))
	WeaponModelBuilder.curved_mag(mag, 0.025, float(p.get("mag_len", 0.12)) + 0.02, 0.074, 0.078, 2.2, 0.027, m, m)
	WeaponModelBuilder.marker(root, "Sight", sight, 0.075)
	WeaponModelBuilder.marker(root, "Muzzle", Vector3(0, 0, muzzle))
	WeaponModelBuilder.marker(root, "Ejection", Vector3(0.015, 0.02, -0.06))
	return root
