class_name ModelsShotguns
extends RefCounted
## Escopetas de quiebre. El grupo "Barrels" gira sobre la bisagra (su origen) y
## lleva los cartuchos ShellL / ShellR que se ven al recargar.



static func _shell(parent: Node3D, n: String, pos: Vector3) -> void:
	var shell := WeaponModelBuilder.group(parent, n, pos)
	WeaponModelBuilder.cyl(shell, "Hull", 0.0105, 0.05, Vector3(0, 0, -0.01), WeaponModelBuilder.mat("shell_red"), 12)
	WeaponModelBuilder.lathe(shell, "Base", [0.014, 0.0, 0.014, 0.0108, 0.025, 0.0108, 0.025, 0.0116, 0.0265, 0.0116, 0.0265, 0.0], WeaponModelBuilder.mat("brass"), Vector3.ZERO, 12)
	shell.visible = false


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
	WeaponModelBuilder.prism(root, "Action", [-0.118, 0.012, 0.002, -0.118, -0.022, 0.004, -0.11, -0.036, 0.01, -0.035, -0.04, 0.01, 0.0, -0.03, 0.008,
		0.01, -0.018, 0.004, 0.012, 0.008, 0.002, -0.02, 0.014, 0.004, -0.11, 0.014, 0.002], 0.047, steel, 0.004)
	for s: float in [-1.0, 1.0]:
		WeaponModelBuilder.lathe(root, "Fence", [-0.124, 0.0, -0.124, 0.0122, -0.119, 0.0146, -0.1, 0.0146, -0.1, 0.0], steel, Vector3(s * 0.0122, 0, 0), 18)
	WeaponModelBuilder.pin(root, Vector3(0, -0.024, -0.112), 0.0058, 0.049, "steel")
	WeaponModelBuilder.rbox(root, "TopLever", Vector3(0.011, 0.005, 0.042), Vector3(0.005, 0.0165, -0.012), bl, 0.002, Vector3(0, 0.28, 0))
	WeaponModelBuilder.rbox(root, "Safety", Vector3(0.006, 0.004, 0.01), Vector3(0, 0.016, 0.028), bl, 0.0015)
	_triggers(root, [-0.052, -0.03], -0.038, bl)
	ModelsRifles._guard_u(root, -0.07, 0.03, -0.038, 0.03, bl, 0.011)
	if sawed:
		# Culata serruchada: queda la empuñadura
		WeaponModelBuilder.prism(root, "Grip", [0.008, 0.006, 0.0, 0.035, -0.014, 0.01, 0.08, -0.038, 0.015, 0.13, -0.06, 0.004, 0.126, -0.13, 0.004,
			0.09, -0.128, 0.01, 0.06, -0.08, 0.02, 0.03, -0.05, 0.01, 0.012, -0.034, 0.003], 0.04, wood, 0.009)
		WeaponModelBuilder.prism(root, "SawCut", [0.1295, -0.061, 0.0, 0.1305, -0.061, 0.0, 0.1265, -0.129, 0.0, 0.1255, -0.129, 0.0], 0.034,
			WeaponModelBuilder.mat("wood_cut"), 0.0, Vector3(0.0, 0, 0.0))
	else:
		WeaponModelBuilder.prism(root, "Stock", [0.008, 0.006, 0.0, 0.04, -0.018, 0.012, 0.12, -0.03, 0.03, 0.37, -0.056, 0.006, 0.374, -0.16, 0.006,
			0.34, -0.161, 0.012, 0.15, -0.088, 0.03, 0.06, -0.058, 0.01, 0.012, -0.034, 0.003], 0.042, wood, 0.01)
		WeaponModelBuilder.prism(root, "ButtPad", [0.37, -0.054, 0.004, 0.386, -0.054, 0.004, 0.388, -0.162, 0.004, 0.374, -0.162, 0.004], 0.044,
			WeaponModelBuilder.mat("rubber"), 0.004)
	# Caños (giran sobre la bisagra)
	var barrels := WeaponModelBuilder.group(root, "Barrels", Vector3(0, 0.0, -0.12))
	for s: float in [-1.0, 1.0]:
		var n := "L" if s < 0 else "R"
		WeaponModelBuilder.barrel(barrels, "Barrel" + n, 0.0, -blen, 0.0132, 0.0112, bl, 0.0092, Vector3(s * 0.0122, 0, 0), 0.06, 18)
		_shell(barrels, "Shell" + n, Vector3(s * 0.0122, 0, 0.025))
	WeaponModelBuilder.section(barrels, "Rib", [-0.0045, 0.0085, 0.0, 0.0045, 0.0085, 0.0, 0.0038, 0.0128, 0.0, -0.0038, 0.0128, 0.0], -blen + 0.004, -0.004, bl, 0.0006)
	WeaponModelBuilder.section(barrels, "RibLow", [-0.0045, -0.0085, 0.0, -0.0038, -0.0125, 0.0, 0.0038, -0.0125, 0.0, 0.0045, -0.0085, 0.0], -blen + 0.004, -0.06, bl, 0.0006)
	WeaponModelBuilder.rbox(barrels, "Lumps", Vector3(0.014, 0.016, 0.055), Vector3(0, -0.014, -0.03), bl, 0.003)
	var fl := minf(0.2, blen * 0.55)
	# Forend de astilla, redondeado y afinado hacia la punta
	WeaponModelBuilder.loft(barrels, "Forend", wood, -0.012, -fl, [[0.0, 0.0215, -0.033, -0.004, 2.8], [0.15, 0.022, -0.034, -0.004, 2.5],
		[0.85, 0.021, -0.031, -0.004, 2.5], [1.0, 0.017, -0.022, -0.005, 3.0]])
	WeaponModelBuilder.rbox(barrels, "ForendIron", Vector3(0.04, 0.014, 0.03), Vector3(0, -0.024, -0.03), steel, 0.004)
	WeaponModelBuilder.sphere(barrels, "Bead", 0.003, Vector3(0, 0.0155, -blen + 0.012), WeaponModelBuilder.mat("brass"), 8)
	WeaponModelBuilder.marker(root, "Sight", Vector3(0, 0.0185, -0.12 - blen + 0.012), blen + 0.12 - 0.012 + 0.155)
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
	WeaponModelBuilder.prism(root, "Action", [-0.118, 0.012, 0.002, -0.118, -0.04, 0.004, -0.108, -0.052, 0.01, -0.035, -0.056, 0.012, -0.002, -0.046, 0.01,
		0.012, -0.03, 0.004, 0.012, 0.009, 0.002, -0.02, 0.014, 0.004, -0.11, 0.014, 0.002], 0.041, silver, 0.004)
	for s: float in [-1.0, 1.0]:
		WeaponModelBuilder.cyl(root, "HingeKnob", 0.0065, 0.003, Vector3(s * 0.021, -0.032, -0.108), silver, 16, Vector3(0, PI * 0.5, 0))
	WeaponModelBuilder.rbox(root, "TopLever", Vector3(0.011, 0.005, 0.042), Vector3(0.005, 0.0165, -0.012), bl, 0.002, Vector3(0, 0.28, 0))
	WeaponModelBuilder.rbox(root, "Selector", Vector3(0.008, 0.004, 0.014), Vector3(0, 0.016, 0.028), bl, 0.0015)
	_triggers(root, [-0.04], -0.056, WeaponModelBuilder.mat("brass"))
	ModelsRifles._guard_u(root, -0.07, 0.02, -0.056, 0.028, bl, 0.011)
	# Culata con pistolete y Monte Carlo
	WeaponModelBuilder.prism(root, "Stock", [0.01, 0.006, 0.0, 0.06, -0.022, 0.015, 0.12, -0.03, 0.01, 0.25, -0.016, 0.02, 0.29, -0.03, 0.02,
		0.375, -0.03, 0.006, 0.378, -0.158, 0.006, 0.34, -0.158, 0.01, 0.15, -0.108, 0.03, 0.11, -0.112, 0.006, 0.078, -0.108, 0.008,
		0.045, -0.062, 0.015, 0.012, -0.045, 0.003], 0.042, wood, 0.01)
	WeaponModelBuilder.prism(root, "GripCap", [0.108, -0.111, 0.003, 0.08, -0.107, 0.003, 0.079, -0.113, 0.002, 0.109, -0.117, 0.002], 0.03, WeaponModelBuilder.mat("polymer"), 0.002)
	WeaponModelBuilder.prism(root, "ButtPad", [0.375, -0.028, 0.004, 0.391, -0.028, 0.004, 0.393, -0.16, 0.004, 0.378, -0.16, 0.004], 0.044, WeaponModelBuilder.mat("rubber"), 0.004)
	# Caños superpuestos con bandas laterales y banda ventilada
	var barrels := WeaponModelBuilder.group(root, "Barrels", Vector3(0, 0.0, -0.12))
	var ys := [0.0, -0.0245]
	var names := ["L", "R"]
	for i in 2:
		WeaponModelBuilder.barrel(barrels, "Barrel" + names[i], 0.0, -blen, 0.0128, 0.0112, bl, 0.0092, Vector3(0, ys[i], 0), 0.07, 18)
		_shell(barrels, "Shell" + names[i], Vector3(0, ys[i], 0.025))
	for s: float in [-1.0, 1.0]:
		WeaponModelBuilder.rbox(barrels, "SideRib", Vector3(0.002, 0.012, blen - 0.02), Vector3(s * 0.0098, -0.0122, -blen * 0.5), bl, 0.0006)
	WeaponModelBuilder.section(barrels, "VentRib", [-0.0042, 0.0145, 0.0, 0.0042, 0.0145, 0.0, 0.0042, 0.0172, 0.0005, -0.0042, 0.0172, 0.0005],
		-blen + 0.004, -0.008, bl, 0.0005)
	var z := -0.03
	while z > -blen + 0.02:
		WeaponModelBuilder.rbox(barrels, "RibPost", Vector3(0.004, 0.004, 0.005), Vector3(0, 0.0128, z), bl, 0.0005)
		z -= 0.05
	WeaponModelBuilder.rbox(barrels, "Monoblock", Vector3(0.03, 0.05, 0.03), Vector3(0, -0.012, -0.015), bl, 0.004)
	# Forend con punta "schnabel" que abraza el caño inferior
	WeaponModelBuilder.loft(barrels, "Forend", wood, -0.016, -0.25, [[0.0, 0.0215, -0.05, -0.018, 2.8], [0.15, 0.0225, -0.051, -0.018, 2.5],
		[0.82, 0.0222, -0.047, -0.018, 2.5], [0.92, 0.024, -0.043, -0.017, 2.8], [1.0, 0.019, -0.032, -0.018, 3.0]])
	WeaponModelBuilder.rbox(barrels, "ForendIron", Vector3(0.036, 0.012, 0.025), Vector3(0, -0.038, -0.03), silver, 0.004)
	WeaponModelBuilder.sphere(barrels, "Bead", 0.0028, Vector3(0, 0.0198, -blen + 0.012), WeaponModelBuilder.mat("brass"), 8)
	WeaponModelBuilder.sphere(barrels, "MidBead", 0.0016, Vector3(0, 0.0182, -blen * 0.5), silver, 6)
	WeaponModelBuilder.marker(root, "Sight", Vector3(0, 0.0222, -0.12 - blen + 0.012), blen + 0.12 - 0.012 + 0.155)
	WeaponModelBuilder.marker(root, "Muzzle", Vector3(0, -0.012, -0.12 - blen - 0.01))
	WeaponModelBuilder.marker(root, "Ejection", Vector3(0, -0.01, -0.11))
	return root
