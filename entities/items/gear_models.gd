class_name GearModels
extends RefCounted
## Modelos por código del equipo de tela: chalecos tácticos, chalecos antibalas y
## mochilas. Acostados boca arriba (el frente hacia +Y, la parte de arriba hacia −Z),
## con piezas blandas (bordes muy redondeados), cintas, hebillas, solapas y costuras
## para que no parezcan cajas.

const FABRIC := {
	"rig_light": Color(0.52, 0.45, 0.32), "rig_medium": Color(0.3, 0.33, 0.24), "rig_assault": Color(0.23, 0.24, 0.21),
	"vest_light": Color(0.33, 0.35, 0.26), "vest_plate": Color(0.2, 0.21, 0.18),
	"backpack_small": Color(0.45, 0.4, 0.29), "backpack_medium": Color(0.3, 0.32, 0.23),
	"backpack_large": Color(0.33, 0.29, 0.21), "backpack_expedition": Color(0.24, 0.28, 0.26),
}

static var _mats: Dictionary = {}


static func _fab(c: Color, rough := 0.97) -> StandardMaterial3D:
	var key := "%s|%.2f" % [c.to_html(), rough]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = rough
		_mats[key] = m
	return _mats[key]


## Pieza blanda: caja con los bordes muy redondeados.
static func _soft(p: Node3D, size: Vector3, pos: Vector3, c: Color, rot := Vector3.ZERO, soft := 0.45) -> MeshInstance3D:
	var r := minf(size.x, size.y) * soft
	return WeaponModelBuilder.rbox(p, "Soft", size, pos, _fab(c), r, rot)


## Cinta (webbing) chata.
static func _strap(p: Node3D, size: Vector3, pos: Vector3, c: Color, rot := Vector3.ZERO) -> void:
	WeaponModelBuilder.rbox(p, "Strap", size, pos, _fab(c, 0.9), 0.001, rot)


## Hebilla de plástico (macho y hembra).
static func _buckle(p: Node3D, pos: Vector3, rot := Vector3.ZERO, s := 1.0) -> void:
	var m := _fab(Color(0.06, 0.06, 0.06), 0.6)
	var b := Basis.from_euler(rot)
	WeaponModelBuilder.rbox(p, "Buckle", Vector3(0.03, 0.01, 0.022) * s, pos, m, 0.003, rot)
	WeaponModelBuilder.rbox(p, "Buckle", Vector3(0.024, 0.008, 0.018) * s, pos + b * Vector3(0, 0, 0.02 * s), m, 0.003, rot)


## Filas de MOLLE (cintas horizontales) sobre una cara.
static func _molle(p: Node3D, width: float, z0: float, rows: int, y: float, x := 0.0, c := Color.BLACK) -> void:
	for i in rows:
		_strap(p, Vector3(width, 0.003, 0.012), Vector3(x, y, z0 + i * 0.026), c)


## Porta-cargador: bolsa con solapa, lengüeta y MOLLE.
static func _mag_pouch(p: Node3D, x: float, z: float, y0: float, w: float, c: Color) -> void:
	var h := 0.055
	_soft(p, Vector3(w, h, 0.13), Vector3(x, y0 + h * 0.5, z), c.lightened(0.03))
	# Solapa arriba, cayendo sobre el frente
	_soft(p, Vector3(w * 1.04, 0.012, 0.07), Vector3(x, y0 + h + 0.004, z - 0.04), c.darkened(0.08), Vector3(-0.08, 0, 0), 0.4)
	_strap(p, Vector3(w * 0.3, 0.004, 0.03), Vector3(x, y0 + h + 0.012, z - 0.004), Color(0.07, 0.07, 0.07))
	_molle(p, w * 1.02, z + 0.012, 2, y0 + h + 0.001, x, c.darkened(0.25))


## Bolsillo general con cierre.
static func _gp_pouch(p: Node3D, x: float, z: float, y0: float, w: float, l: float, c: Color) -> void:
	var h := 0.05
	_soft(p, Vector3(w, h, l), Vector3(x, y0 + h * 0.5, z), c.lightened(0.02))
	# Cierre (cremallera) en U y tirador
	var zip := _fab(Color(0.1, 0.1, 0.1), 0.5)
	WeaponModelBuilder.rbox(p, "Zip", Vector3(w * 0.85, 0.003, 0.006), Vector3(x, y0 + h + 0.001, z - l * 0.36), zip, 0.001)
	WeaponModelBuilder.rbox(p, "ZipPull", Vector3(0.008, 0.004, 0.022), Vector3(x + w * 0.3, y0 + h + 0.003, z - l * 0.3), zip, 0.002)
	# Parche de abrojo
	_strap(p, Vector3(w * 0.5, 0.003, l * 0.25), Vector3(x, y0 + h + 0.001, z + l * 0.1), c.darkened(0.15))


# --- Chaleco táctico -----------------------------------------------------------------

static func rig(root: Node3D, item: ItemData) -> void:
	var c: Color = FABRIC.get(item.id, Color(0.3, 0.3, 0.24))
	var web := c.darkened(0.28)
	var mags := 0
	var big := 0
	var small := 0
	for g: Array in item.grids:
		if int(g[2]) == 1 and int(g[3]) == 2:
			mags += 1
		elif int(g[2]) == 2:
			big += 1
		else:
			small += 1
	var pw := 0.058
	# Muchos porta-cargadores: los bolsillos grandes van en una fila abajo
	var rows := 2 if mags > 4 else 1
	var width := mags * (pw + 0.006) + (big * 0.125 if rows == 1 else 0.0) + 0.04
	var depth := 0.19 if rows == 1 else 0.33
	var zc := 0.0 if rows == 1 else 0.07
	var y0 := 0.022
	# Panel del pecho (blando) con ribete
	_soft(root, Vector3(width + 0.012, 0.018, depth + 0.01), Vector3(0, 0.009, zc), web, Vector3.ZERO, 0.4)
	_soft(root, Vector3(width, y0, depth), Vector3(0, y0 * 0.5 + 0.002, zc), c)
	# Tirantes (en H, hacia arriba y atrás) con hebillas
	for sx: float in [-1.0, 1.0]:
		var x := sx * width * 0.3
		_soft(root, Vector3(0.045, 0.012, 0.11), Vector3(x + sx * 0.006, 0.006, -0.145), c.darkened(0.06), Vector3(0, sx * 0.1, 0), 0.4)
		_buckle(root, Vector3(x, 0.016, -0.115), Vector3(0, sx * 0.05, 0))
		# Cinta de la cintura hacia el costado, con hebilla
		_strap(root, Vector3(0.07, 0.006, 0.03), Vector3(sx * (width * 0.5 + 0.03), 0.006, 0.06), web)
		_buckle(root, Vector3(sx * (width * 0.5 + 0.06), 0.012, 0.06), Vector3(0, PI * 0.5, 0))
	if rows == 2:
		var xr := -width * 0.5 + 0.02
		for i in mags:
			_mag_pouch(root, xr + pw * 0.5, -0.01, y0, pw, c)
			xr += pw + 0.006
		var bw := (width - 0.04) / maxf(big, 1)
		for i in big:
			_gp_pouch(root, -width * 0.5 + 0.02 + bw * (i + 0.5), 0.165, y0, bw - 0.012, 0.12, c)
	else:
		# Bolsillos grandes a los costados de los porta-cargadores
		var x0 := -width * 0.5 + 0.02
		var bl := big / 2
		for i in bl:
			_gp_pouch(root, x0 + 0.06, 0.005, y0, 0.11, 0.15, c)
			x0 += 0.125
		for i in mags:
			_mag_pouch(root, x0 + pw * 0.5, 0.01, y0, pw, c)
			x0 += pw + 0.006
		for i in big - bl:
			_gp_pouch(root, x0 + 0.06, 0.005, y0, 0.11, 0.15, c)
			x0 += 0.125
	# Bolsillos chicos sobre las cintas de la cintura (alternando lados)
	for i in small:
		var sx2 := -1.0 if i % 2 == 0 else 1.0
		var zz := 0.03 + (i / 2) * 0.07
		_soft(root, Vector3(0.05, 0.04, 0.06), Vector3(sx2 * (width * 0.5 + 0.04), 0.024, zz), c.lightened(0.02))
		_soft(root, Vector3(0.052, 0.01, 0.03), Vector3(sx2 * (width * 0.5 + 0.04), 0.046, zz - 0.016), c.darkened(0.08), Vector3(-0.1, 0, 0), 0.4)


# --- Chaleco antibalas -----------------------------------------------------------------

static func vest(root: Node3D, item: ItemData) -> void:
	var c: Color = FABRIC.get(item.id, Color(0.3, 0.3, 0.24))
	var heavy := item.id == "vest_plate"
	var web := c.darkened(0.28)
	var w := 0.3
	var l := 0.36
	# Faldones laterales (cummerbund) con MOLLE
	for sx: float in [-1.0, 1.0]:
		_soft(root, Vector3(0.14, 0.02, 0.2), Vector3(sx * (w * 0.5 + 0.06), 0.012, 0.05), c.darkened(0.05), Vector3(0, -sx * 0.18, 0), 0.4)
		_molle(root, 0.12, -0.02, 4, 0.023, sx * (w * 0.5 + 0.06), web)
	# Panel delantero y la placa (bulto)
	_soft(root, Vector3(w, 0.035, l), Vector3(0, 0.0175, 0), c, Vector3.ZERO, 0.45)
	var plate_t := 0.035 if heavy else 0.02
	_soft(root, Vector3(w * 0.86, plate_t, l * 0.8), Vector3(0, 0.035 + plate_t * 0.5 - 0.004, -0.01), c.lightened(0.03), Vector3.ZERO, 0.5)
	var top := 0.035 + plate_t
	# Hombreras acolchadas y asa de arrastre
	for sx: float in [-1.0, 1.0]:
		_soft(root, Vector3(0.06, 0.025, 0.14), Vector3(sx * w * 0.32, 0.02, -l * 0.5 - 0.05), c.darkened(0.04), Vector3(0, sx * 0.08, 0), 0.45)
	_strap(root, Vector3(0.09, 0.012, 0.02), Vector3(0, top + 0.004, -l * 0.42), web)
	# Abrojo para parches y MOLLE abajo
	_strap(root, Vector3(w * 0.5, 0.003, 0.07), Vector3(0, top + 0.001, -l * 0.22), c.darkened(0.15))
	_molle(root, w * 0.8, l * 0.02, 4 if heavy else 3, top + 0.001, 0.0, web)
	if not heavy:
		# Chaleco liviano: tres porta-cargadores al frente
		for i in 3:
			_mag_pouch(root, -0.065 + i * 0.065, l * 0.18, top, 0.058, c)
	else:
		# Con placas: bolsillo canguro y bolsillo administrativo
		_gp_pouch(root, 0.0, l * 0.22, top, 0.2, 0.12, c)
		_gp_pouch(root, 0.0, -l * 0.06, top, 0.12, 0.08, c.darkened(0.04))


# --- Mochilas --------------------------------------------------------------------------

static func backpack(root: Node3D, item: ItemData) -> void:
	var c: Color = FABRIC.get(item.id, Color(0.3, 0.3, 0.24))
	var g: Array = item.grids[0] if not item.grids.is_empty() else [0, 0, 4, 5]
	var k := sqrt(float(g[2]) * float(g[3]) / 30.0)
	var web := c.darkened(0.3)
	var W := 0.3 * minf(k, 1.15)
	var L := 0.38 * k
	var D := 0.15 * minf(k, 1.3)
	# Cuerpo blando, acostado sobre la espalda
	_soft(root, Vector3(W, D, L), Vector3(0, D * 0.5, 0), c, Vector3.ZERO, 0.42)
	# Tapa arriba que cae sobre el frente
	_soft(root, Vector3(W * 0.96, 0.03, L * 0.32), Vector3(0, D + 0.006, -L * 0.36), c.darkened(0.07), Vector3(-0.12, 0, 0), 0.45)
	# Bolsillo delantero con cierre
	_gp_pouch(root, 0.0, L * 0.18, D - 0.01, W * 0.68, L * 0.38, c)
	# Cintas de compresión sobre la tapa, con hebillas
	for sx: float in [-1.0, 1.0]:
		_strap(root, Vector3(0.022, 0.006, L * 0.5), Vector3(sx * W * 0.22, D + 0.024, -L * 0.18), web)
		_buckle(root, Vector3(sx * W * 0.22, D + 0.03, -L * 0.02), Vector3.ZERO, 0.9)
		# Cintas laterales
		_strap(root, Vector3(0.006, D * 0.6, 0.02), Vector3(sx * (W * 0.5 + 0.002), D * 0.5, L * 0.1), web)
	# Manija arriba
	_strap(root, Vector3(0.05, 0.012, 0.025), Vector3(0, D * 0.7, -L * 0.5 - 0.008), web)
	if k > 1.1:
		# Bolsillos laterales grandes
		for sx2: float in [-1.0, 1.0]:
			_soft(root, Vector3(0.06, D * 0.7, L * 0.4), Vector3(sx2 * (W * 0.5 + 0.026), D * 0.38, L * 0.05), c.darkened(0.04), Vector3.ZERO, 0.45)
	if k > 1.35:
		# Bolsa de dormir arriba
		var roll := WeaponModelBuilder.cyl(root, "Roll", 0.058, W * 0.95, Vector3(0, 0.075, -L * 0.5 - 0.06),
			_fab(Color(0.16, 0.19, 0.16)), 18, Vector3(0, PI * 0.5, 0), 0.025)
		roll.name = "Roll"
		for sx3: float in [-1.0, 1.0]:
			WeaponModelBuilder.cyl(root, "RollStrap", 0.0605, 0.02, Vector3(sx3 * W * 0.25, 0.075, -L * 0.5 - 0.06),
				_fab(web, 0.9), 18, Vector3(0, PI * 0.5, 0))
