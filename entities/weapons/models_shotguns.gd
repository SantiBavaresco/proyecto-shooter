class_name ModelsShotguns
extends RefCounted
## Escopetas de quiebre. El grupo "Barrels" gira sobre la bisagra (su origen) y
## lleva los cartuchos ShellL / ShellR que se ven al recargar.



static func _shell(parent: Node3D, n: String, pos: Vector3) -> void:
	var shell := WeaponModelBuilder.group(parent, n, pos)
	WeaponModelBuilder.cyl(shell, "Hull", 0.0105, 0.05, Vector3(0, 0, -0.01), WeaponModelBuilder.mat("shell_red"), 12)
	WeaponModelBuilder.lathe(shell, "Base", [0.014, 0.0, 0.014, 0.0108, 0.025, 0.0108, 0.025, 0.0116, 0.0265, 0.0116, 0.0265, 0.0], WeaponModelBuilder.mat("brass"), Vector3.ZERO, 12)
	shell.visible = false


## Claves de loft a partir de estaciones [z, semiancho, y_abajo, y_arriba, exponente].
static func _keys(z_rear: float, z_front: float, st: Array) -> Array:
	var out: Array = []
	for e: Array in st:
		out.append([(z_rear - float(e[0])) / (z_rear - z_front), e[1], e[2], e[3], e[4]])
	return out


static func _triggers(root: Node3D, zs: Array, y_top: float, m: Material) -> void:
	for z: float in zs:
		ModelsRifles._trigger(root, z, y_top, m)


## Escopeta de dos caños yuxtapuestos (larga con culata, o recortada).
static func sxs(data: WeaponData) -> Node3D:
	var root := Node3D.new()
	var p := data.model_params
	var bl := WeaponModelBuilder.mat("blued")
	var steel := WeaponModelBuilder.mat("steel")
	var wood := WeaponModelBuilder.mat("wood")
	var blen: float = p.get("barrel", 0.62)
	var sawed: bool = p.get("stock", "full") != "full"
	# Báscula con "fences" redondeadas sobre cada caño
	# Báscula redondeada: se afina hacia la cola (tang) y redondea el frente de abajo
	WeaponModelBuilder.loft(root, "Action", steel, 0.016, -0.118, _keys(0.016, -0.118, [[0.016, 0.008, -0.019, 0.009, 2.6],
		[0.0, 0.0168, -0.03, 0.013, 3.0], [-0.02, 0.0232, -0.038, 0.0135, 2.9], [-0.06, 0.0236, -0.04, 0.0135, 3.6],
		[-0.1, 0.0236, -0.036, 0.0135, 3.0], [-0.118, 0.0228, -0.026, 0.013, 3.2]]), 30, 32)
	for s: float in [-1.0, 1.0]:
		WeaponModelBuilder.lathe(root, "Fence", [-0.124, 0.0, -0.124, 0.0122, -0.119, 0.0146, -0.1, 0.0146, -0.1, 0.0], steel, Vector3(s * 0.0122, 0, 0), 18)
	WeaponModelBuilder.pin(root, Vector3(0, -0.024, -0.112), 0.0058, 0.049, "steel")
	# Palanca de apertura baja, por debajo de la línea de mira
	WeaponModelBuilder.rbox(root, "TopLever", Vector3(0.011, 0.004, 0.042), Vector3(0.005, 0.0142, -0.012), bl, 0.0016, Vector3(0, 0.28, 0))
	WeaponModelBuilder.rbox(root, "Safety", Vector3(0.006, 0.004, 0.01), Vector3(0, 0.016, 0.028), bl, 0.0015)
	_triggers(root, [-0.052, -0.03], -0.038, bl)
	ModelsRifles._guard_u(root, -0.07, 0.03, -0.038, 0.03, bl, 0.011)
	if sawed:
		# Culata serruchada: queda la empuñadura
		WeaponModelBuilder.loft(root, "Grip", wood, 0.13, 0.006, _keys(0.13, 0.006, [[0.13, 0.017, -0.13, -0.06, 2.4],
			[0.1, 0.0175, -0.13, -0.045, 2.3], [0.07, 0.017, -0.1, -0.031, 2.3], [0.04, 0.016, -0.06, -0.016, 2.3],
			[0.006, 0.018, -0.034, 0.008, 2.6]]))
		WeaponModelBuilder.loft(root, "SawCut", WeaponModelBuilder.mat("wood_cut"), 0.1312, 0.1296, [[0.0, 0.0168, -0.129, -0.061, 2.4],
			[1.0, 0.0168, -0.129, -0.061, 2.4]], 1)
	else:
		# Culata de garganta fina que se ensancha hacia la cantonera (sección ovalada)
		WeaponModelBuilder.loft(root, "Stock", wood, 0.372, 0.006, _keys(0.372, 0.006, [[0.372, 0.021, -0.16, -0.056, 2.4],
			[0.3, 0.0205, -0.145, -0.051, 2.3], [0.2, 0.019, -0.115, -0.043, 2.2], [0.12, 0.0165, -0.083, -0.03, 2.2],
			[0.06, 0.0152, -0.06, -0.02, 2.2], [0.03, 0.0165, -0.045, -0.006, 2.4], [0.006, 0.018, -0.034, 0.008, 2.8]]), 34, 30)
		WeaponModelBuilder.loft(root, "ButtPad", WeaponModelBuilder.mat("rubber"), 0.388, 0.371, [[0.0, 0.02, -0.158, -0.058, 2.6],
			[0.4, 0.0215, -0.162, -0.055, 2.5], [1.0, 0.0212, -0.161, -0.056, 2.4]], 4)
	# Caños (giran sobre la bisagra)
	var barrels := WeaponModelBuilder.group(root, "Barrels", Vector3(0, 0.0, -0.12))
	for s: float in [-1.0, 1.0]:
		var n := "L" if s < 0 else "R"
		WeaponModelBuilder.barrel(barrels, "Barrel" + n, 0.0, -blen, 0.0132, 0.0112, bl, 0.0092, Vector3(s * 0.0122, 0, 0), 0.06, 18, 0.0109)
		_shell(barrels, "Shell" + n, Vector3(s * 0.0122, 0, 0.025))
	WeaponModelBuilder.section(barrels, "Rib", [-0.0045, 0.0085, 0.0, 0.0045, 0.0085, 0.0, 0.0038, 0.0128, 0.0, -0.0038, 0.0128, 0.0], -blen + 0.004, -0.004, bl, 0.0006)
	WeaponModelBuilder.section(barrels, "RibLow", [-0.0045, -0.0085, 0.0, -0.0038, -0.0125, 0.0, 0.0038, -0.0125, 0.0, 0.0045, -0.0085, 0.0], -blen + 0.004, -0.06, bl, 0.0006)
	WeaponModelBuilder.rbox(barrels, "Lumps", Vector3(0.014, 0.016, 0.055), Vector3(0, -0.026, -0.03), bl, 0.003)
	var fl := minf(0.2, blen * 0.55)
	# Forend de astilla, redondeado y afinado hacia la punta
	# (arranca adelante de las recámaras, que son huecas)
	WeaponModelBuilder.loft(barrels, "Forend", wood, -0.072, -fl - 0.04, [[0.0, 0.0215, -0.033, -0.004, 2.8], [0.15, 0.022, -0.034, -0.004, 2.5],
		[0.85, 0.021, -0.031, -0.004, 2.5], [1.0, 0.017, -0.022, -0.005, 3.0]])
	WeaponModelBuilder.rbox(barrels, "ForendIron", Vector3(0.04, 0.014, 0.03), Vector3(0, -0.024, -0.09), steel, 0.004)
	# Guion alto sobre la banda: se ve por encima de la báscula al apuntar
	WeaponModelBuilder.rbox(barrels, "BeadPost", Vector3(0.002, 0.004, 0.003), Vector3(0, 0.0145, -blen + 0.012), bl, 0.0005)
	WeaponModelBuilder.sphere(barrels, "Bead", 0.003, Vector3(0, 0.0185, -blen + 0.012), WeaponModelBuilder.mat("brass"), 8)
	WeaponModelBuilder.marker(root, "Sight", Vector3(0, 0.0215, -0.12 - blen + 0.012), blen + 0.12 - 0.012 + 0.155)
	WeaponModelBuilder.marker(root, "Muzzle", Vector3(0, 0.0, -0.12 - blen - 0.01))
	WeaponModelBuilder.marker(root, "Ejection", Vector3(0, 0.0, -0.11))
	return root


## Escopeta de dos caños superpuestos de caza: báscula plateada, banda ventilada.
static func over_under(data: WeaponData) -> Node3D:
	var root := Node3D.new()
	var p := data.model_params
	var bl := WeaponModelBuilder.mat("blued")
	var silver := WeaponModelBuilder.mat("steel_bright")
	var wood := WeaponModelBuilder.mat("wood_light")
	var blen: float = p.get("barrel", 0.76)
	WeaponModelBuilder.loft(root, "Action", silver, 0.016, -0.118, _keys(0.016, -0.118, [[0.016, 0.008, -0.026, 0.009, 2.6],
		[0.0, 0.015, -0.042, 0.013, 3.0], [-0.02, 0.0202, -0.052, 0.0135, 2.9], [-0.06, 0.0205, -0.056, 0.0135, 3.6],
		[-0.1, 0.0205, -0.052, 0.0135, 3.0], [-0.118, 0.02, -0.04, 0.013, 3.2]]), 30, 32)
	for s: float in [-1.0, 1.0]:
		WeaponModelBuilder.cyl(root, "HingeKnob", 0.0065, 0.003, Vector3(s * 0.021, -0.032, -0.108), silver, 16, Vector3(0, PI * 0.5, 0))
	WeaponModelBuilder.rbox(root, "TopLever", Vector3(0.011, 0.005, 0.042), Vector3(0.005, 0.0165, -0.012), bl, 0.002, Vector3(0, 0.28, 0))
	WeaponModelBuilder.rbox(root, "Selector", Vector3(0.008, 0.004, 0.014), Vector3(0, 0.016, 0.028), bl, 0.0015)
	_triggers(root, [-0.04], -0.056, WeaponModelBuilder.mat("brass"))
	ModelsRifles._guard_u(root, -0.07, 0.02, -0.056, 0.028, bl, 0.011)
	# Culata con pistolete y Monte Carlo
	# Culata con pistolete y Monte Carlo, sección ovalada
	WeaponModelBuilder.loft(root, "Stock", wood, 0.376, 0.008, _keys(0.376, 0.008, [[0.376, 0.021, -0.158, -0.03, 2.4],
		[0.29, 0.0205, -0.14, -0.03, 2.3], [0.25, 0.02, -0.13, -0.016, 2.3], [0.15, 0.018, -0.108, -0.022, 2.2],
		[0.11, 0.0165, -0.116, -0.028, 2.3], [0.078, 0.016, -0.108, -0.024, 2.3], [0.045, 0.0165, -0.062, -0.012, 2.3],
		[0.008, 0.018, -0.045, 0.008, 2.8]]), 40, 30)
	WeaponModelBuilder.loft(root, "ButtPad", WeaponModelBuilder.mat("rubber"), 0.392, 0.375, [[0.0, 0.02, -0.156, -0.032, 2.6],
		[0.4, 0.0215, -0.16, -0.029, 2.5], [1.0, 0.0212, -0.159, -0.03, 2.4]], 4)
	# Caños superpuestos con bandas laterales y banda ventilada
	var barrels := WeaponModelBuilder.group(root, "Barrels", Vector3(0, 0.0, -0.12))
	var ys := [0.0, -0.0245]
	var names := ["L", "R"]
	for i in 2:
		WeaponModelBuilder.barrel(barrels, "Barrel" + names[i], 0.0, -blen, 0.0128, 0.0112, bl, 0.0092, Vector3(0, ys[i], 0), 0.07, 18, 0.0109)
		_shell(barrels, "Shell" + names[i], Vector3(0, ys[i], 0.025))
	for s: float in [-1.0, 1.0]:
		WeaponModelBuilder.rbox(barrels, "SideRib", Vector3(0.002, 0.012, blen - 0.02), Vector3(s * 0.0098, -0.0122, -blen * 0.5), bl, 0.0006)
	WeaponModelBuilder.section(barrels, "VentRib", [-0.0042, 0.0145, 0.0, 0.0042, 0.0145, 0.0, 0.0042, 0.0172, 0.0005, -0.0042, 0.0172, 0.0005],
		-blen + 0.004, -0.008, bl, 0.0005)
	var z := -0.03
	while z > -blen + 0.02:
		WeaponModelBuilder.rbox(barrels, "RibPost", Vector3(0.004, 0.004, 0.005), Vector3(0, 0.0128, z), bl, 0.0005)
		z -= 0.05
	# Monoblock: mejillas a los costados y talón abajo, dejando libres las bocas de las recámaras
	for s: float in [-1.0, 1.0]:
		WeaponModelBuilder.rbox(barrels, "Monoblock", Vector3(0.005, 0.05, 0.03), Vector3(s * 0.0128, -0.012, -0.015), bl, 0.002)
	WeaponModelBuilder.rbox(barrels, "MonoLug", Vector3(0.022, 0.01, 0.03), Vector3(0, -0.04, -0.015), bl, 0.003)
	# Forend con punta "schnabel" que abraza el caño inferior
	WeaponModelBuilder.loft(barrels, "Forend", wood, -0.072, -0.28, [[0.0, 0.0215, -0.05, -0.018, 2.8], [0.15, 0.0225, -0.051, -0.018, 2.5],
		[0.82, 0.0222, -0.047, -0.018, 2.5], [0.92, 0.024, -0.043, -0.017, 2.8], [1.0, 0.019, -0.032, -0.018, 3.0]])
	WeaponModelBuilder.rbox(barrels, "ForendIron", Vector3(0.036, 0.012, 0.025), Vector3(0, -0.038, -0.09), silver, 0.004)
	WeaponModelBuilder.sphere(barrels, "Bead", 0.0028, Vector3(0, 0.0198, -blen + 0.012), WeaponModelBuilder.mat("brass"), 8)
	WeaponModelBuilder.sphere(barrels, "MidBead", 0.0016, Vector3(0, 0.0182, -blen * 0.5), silver, 6)
	WeaponModelBuilder.marker(root, "Sight", Vector3(0, 0.0222, -0.12 - blen + 0.012), blen + 0.12 - 0.012 + 0.155)
	WeaponModelBuilder.marker(root, "Muzzle", Vector3(0, -0.012, -0.12 - blen - 0.01))
	WeaponModelBuilder.marker(root, "Ejection", Vector3(0, -0.01, -0.11))
	return root
