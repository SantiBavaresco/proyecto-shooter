class_name ArmsBuilder
extends RefCounted
## Brazos en primera persona hechos por código: guante con palma, dedos de tres
## falanges que se cierran alrededor de lo que agarran, pulgar, muñeca, antebrazo
## con manga, codo y arranque del brazo. TODO-ASSET: fps_arms (modelo con huesos).
##
## Cada arma define en POSES dónde va cada mano (en coordenadas del arma):
##  - right: empuñadura (de "top" a "bottom", radio "r") y cola del disparador "trigger".
##  - left: "forend" (guardamanos: centro, radio; el eje es el del caño) o
##    "pistol" (mano de apoyo sobre la empuñadura de la pistola).
##  - left_in: nodo donde va la mano izquierda (ej. "Barrels" en las escopetas,
##    para que acompañe a los caños al quebrarlas).

const FOREARM := 0.27
const POSES := {
	# Familia AR y similares
	"ar15": {"top": Vector3(0, -0.05, 0.016), "bottom": Vector3(0, -0.13, 0.05), "r": 0.016, "trigger": Vector3(0, -0.058, -0.043),
		"left": "forend", "lc": Vector3(0, -0.002, -0.35), "lr": 0.028},
	"hk416": {"top": Vector3(0, -0.05, 0.016), "bottom": Vector3(0, -0.13, 0.05), "r": 0.016, "trigger": Vector3(0, -0.058, -0.043),
		"left": "forend", "lc": Vector3(0, -0.002, -0.35), "lr": 0.03},
	"sr22": {"top": Vector3(0, -0.05, 0.016), "bottom": Vector3(0, -0.13, 0.05), "r": 0.016, "trigger": Vector3(0, -0.058, -0.043),
		"left": "forend", "lc": Vector3(0, -0.002, -0.33), "lr": 0.027},
	"sr25": {"top": Vector3(0, -0.05, 0.016), "bottom": Vector3(0, -0.13, 0.05), "r": 0.016, "trigger": Vector3(0, -0.058, -0.043),
		"left": "forend", "lc": Vector3(0, -0.002, -0.37), "lr": 0.027},
	"scarl": {"top": Vector3(0, -0.05, 0.018), "bottom": Vector3(0, -0.132, 0.052), "r": 0.017, "trigger": Vector3(0, -0.058, -0.043),
		"left": "forend", "lc": Vector3(0, 0.002, -0.27), "lr": 0.026},
	"m14ebr": {"top": Vector3(0, -0.038, 0.016), "bottom": Vector3(0, -0.12, 0.05), "r": 0.016, "trigger": Vector3(0, -0.046, -0.043),
		"left": "forend", "lc": Vector3(0, -0.013, -0.36), "lr": 0.032},
	# Familia AK
	"ak74": {"top": Vector3(0, -0.045, 0.03), "bottom": Vector3(0, -0.128, 0.058), "r": 0.016, "trigger": Vector3(0, -0.05, -0.038),
		"left": "forend", "lc": Vector3(0, -0.004, -0.32), "lr": 0.031},
	"akm": {"top": Vector3(0, -0.045, 0.03), "bottom": Vector3(0, -0.128, 0.058), "r": 0.016, "trigger": Vector3(0, -0.05, -0.038),
		"left": "forend", "lc": Vector3(0, -0.004, -0.32), "lr": 0.031},
	"svd": {"top": Vector3(0, -0.048, 0.05), "bottom": Vector3(0, -0.135, 0.1), "r": 0.016, "trigger": Vector3(0, -0.05, -0.038),
		"left": "forend", "lc": Vector3(0, -0.004, -0.4), "lr": 0.03},
	"pp19": {"top": Vector3(0, -0.045, 0.03), "bottom": Vector3(0, -0.128, 0.058), "r": 0.016, "trigger": Vector3(0, -0.05, -0.038),
		"left": "forend", "lc": Vector3(0, -0.034, -0.25), "lr": 0.035},
	# Otros fusiles y subfusiles
	"mp5": {"top": Vector3(0, -0.04, 0.028), "bottom": Vector3(0, -0.126, 0.062), "r": 0.016, "trigger": Vector3(0, -0.042, -0.04),
		"left": "forend", "lc": Vector3(0, -0.014, -0.27), "lr": 0.026},
	"rifle": {"top": Vector3(0, -0.05, 0.018), "bottom": Vector3(0, -0.132, 0.048), "r": 0.016, "trigger": Vector3(0, -0.055, -0.045),
		"left": "forend", "lc": Vector3(0, -0.008, -0.34), "lr": 0.03},
	"g3": {"top": Vector3(0, -0.04, 0.026), "bottom": Vector3(0, -0.13, 0.06), "r": 0.017, "trigger": Vector3(0, -0.046, -0.05),
		"left": "forend", "lc": Vector3(0, -0.012, -0.33), "lr": 0.028},
	"sks": {"top": Vector3(0, -0.028, 0.06), "bottom": Vector3(0, -0.062, 0.135), "r": 0.022, "trigger": Vector3(0, -0.048, -0.02),
		"left": "forend", "lc": Vector3(0, -0.016, -0.3), "lr": 0.029},
	# Cerrojos
	"rem700": {"top": Vector3(0, -0.062, 0.068), "bottom": Vector3(0, -0.124, 0.094), "r": 0.019, "trigger": Vector3(0, -0.064, 0.012),
		"left": "forend", "lc": Vector3(0, -0.028, -0.28), "lr": 0.028},
	"mauser1909": {"top": Vector3(0, -0.032, 0.06), "bottom": Vector3(0, -0.064, 0.135), "r": 0.021, "trigger": Vector3(0, -0.058, 0.008),
		"left": "forend", "lc": Vector3(0, -0.012, -0.3), "lr": 0.026},
	"bolt22": {"top": Vector3(0, -0.05, 0.062), "bottom": Vector3(0, -0.104, 0.096), "r": 0.019, "trigger": Vector3(0, -0.055, 0.026),
		"left": "forend", "lc": Vector3(0, -0.022, -0.24), "lr": 0.025},
	# Escopetas (la mano izquierda va con los caños)
	"shotgun": {"top": Vector3(0, -0.034, 0.05), "bottom": Vector3(0, -0.066, 0.125), "r": 0.021, "trigger": Vector3(0, -0.044, -0.04),
		"left": "forend", "left_in": "Barrels", "lc": Vector3(0, -0.014, -0.13), "lr": 0.03},
	"sawedoff": {"top": Vector3(0, -0.028, 0.045), "bottom": Vector3(0, -0.108, 0.1), "r": 0.018, "trigger": Vector3(0, -0.044, -0.04),
		"left": "forend", "left_in": "Barrels", "lc": Vector3(0, -0.014, -0.1), "lr": 0.028},
	"ou_hunt": {"top": Vector3(0, -0.048, 0.05), "bottom": Vector3(0, -0.102, 0.092), "r": 0.019, "trigger": Vector3(0, -0.062, -0.04),
		"left": "forend", "left_in": "Barrels", "lc": Vector3(0, -0.028, -0.15), "lr": 0.032},
	# Pistolas (con la mano de apoyo)
	"pistol": {"top": Vector3(0, -0.024, 0.03), "bottom": Vector3(0, -0.1, 0.056), "r": 0.016, "trigger": Vector3(0, -0.024, -0.03), "left": "pistol"},
	"bersa9": {"top": Vector3(0, -0.024, 0.032), "bottom": Vector3(0, -0.1, 0.054), "r": 0.016, "trigger": Vector3(0, -0.022, -0.032), "left": "pistol"},
	"ballester45": {"top": Vector3(0, -0.024, 0.03), "bottom": Vector3(0, -0.1, 0.048), "r": 0.016, "trigger": Vector3(0, -0.021, -0.03), "left": "pistol"},
	"m1911": {"top": Vector3(0, -0.024, 0.03), "bottom": Vector3(0, -0.1, 0.048), "r": 0.016, "trigger": Vector3(0, -0.021, -0.03), "left": "pistol"},
	"p22": {"top": Vector3(0, -0.02, 0.032), "bottom": Vector3(0, -0.09, 0.062), "r": 0.016, "trigger": Vector3(0, -0.026, -0.03), "left": "pistol"},
}
## Por familia, para armas sin pose propia.
const FAMILY_POSE := {"pistol": "pistol", "smg": "mp5", "rifle_ar": "ar15", "rifle_ak": "akm", "rifle_battle": "rifle",
	"bolt": "bolt22", "shotgun_sxs": "shotgun", "shotgun_ou": "ou_hunt"}

# Falanges: largos y radios (proximal, media, distal) de índice, mayor, anular, meñique
const FINGER_LEN := [[0.042, 0.025, 0.021], [0.046, 0.029, 0.022], [0.043, 0.027, 0.021], [0.034, 0.02, 0.019]]
const FINGER_R := [[0.0098, 0.0088, 0.008], [0.0102, 0.0091, 0.0082], [0.0097, 0.0087, 0.0079], [0.0088, 0.008, 0.0072]]
const THUMB_LEN := [0.036, 0.03, 0.026]
const THUMB_R := [0.0125, 0.0108, 0.0096]


## Pone los dos brazos en el modelo según su pose.
static func add_arms(root: Node3D, data: WeaponData) -> void:
	var key := data.id if POSES.has(data.id) else String(FAMILY_POSE.get(data.model, "rifle"))
	var p: Dictionary = POSES[key]
	var is_pistol: bool = p["left"] == "pistol"
	_right_hand(root, p, is_pistol)
	if is_pistol:
		_left_pistol(root, p)
	else:
		var parent := root
		var center: Vector3 = p["lc"]
		if p.has("left_in") and root.has_node(String(p["left_in"])):
			parent = root.get_node(String(p["left_in"])) as Node3D
			center -= parent.position
		_left_forend(parent, center, float(p["lr"]))
		if parent.name == "Barrels" and parent.has_node("ShellL") and parent.has_node("ShellR"):
			_shell_loader(parent)


# --- Mano derecha: empuñadura y cola del disparador --------------------------

static func _right_hand(root: Node3D, p: Dictionary, pistol: bool) -> void:
	var top: Vector3 = p["top"]
	var bottom: Vector3 = p["bottom"]
	var a := (bottom - top).normalized()
	var u := Vector3.RIGHT
	var v := u.cross(a).normalized()  # hacia el frente de la empuñadura
	var r: float = p["r"]
	var trig: Vector3 = p["trigger"]
	var glove := MeshKit.new()
	var sleeve := MeshKit.new()
	var at := func(s: float, phi: float, rad: float) -> Vector3:
		return top + a * s + (u * cos(phi) + v * sin(phi)) * rad
	# Mayor, anular y meñique cerrados alrededor de la empuñadura (derecha → frente → izquierda)
	var heights := [0.024, 0.044, 0.062]
	for i in 3:
		_wrap_finger(glove, top, a, u, v, heights[i], r + 0.0085, deg_to_rad(38.0), 1.0, FINGER_LEN[i + 1], FINGER_R[i + 1])
	# Índice: por el costado derecho del armazón hasta la cola del disparador
	var k0: Vector3 = at.call(0.006, deg_to_rad(20.0), r + 0.009)
	var side := Vector3(0.0145, 0, 0)
	var k1 := Vector3(side.x + 0.002, lerpf(k0.y, trig.y, 0.5) + 0.004, trig.z + 0.032)
	var k2 := Vector3(side.x - 0.002, trig.y - 0.001, trig.z + 0.008)
	var k3 := Vector3(0.003, trig.y - 0.007, trig.z - 0.006)
	glove.capsule(k0, k1, FINGER_R[0][0], FINGER_R[0][1])
	glove.capsule(k1, k2, FINGER_R[0][1], FINGER_R[0][2])
	glove.capsule(k2, k3, FINGER_R[0][2], FINGER_R[0][2] * 0.92)
	# Palma (costado derecho) y talón de la mano (atrás)
	_palm(glove, at.call(0.036, deg_to_rad(-8.0), r + 0.007), a, u, v, deg_to_rad(-8.0), Vector3(0.021, 0.07, 0.046))
	_palm(glove, at.call(0.05, deg_to_rad(-70.0), r + 0.008), a, u, v, deg_to_rad(-70.0), Vector3(0.024, 0.06, 0.036))
	# Pulgar: por detrás de la empuñadura hacia el lado izquierdo, arriba
	var t0: Vector3 = at.call(0.03, deg_to_rad(-80.0), r + 0.013)
	var t1: Vector3 = at.call(-0.002, deg_to_rad(-120.0), r + 0.011)
	var t2: Vector3 = at.call(-0.012 if not pistol else -0.004, deg_to_rad(-165.0), r + 0.009)
	var t3: Vector3 = at.call(-0.016 if not pistol else -0.006, deg_to_rad(-205.0), r + 0.008)
	glove.capsule(t0, t1, THUMB_R[0] * 1.3, THUMB_R[0])
	glove.capsule(t1, t2, THUMB_R[0], THUMB_R[1])
	glove.capsule(t2, t3, THUMB_R[1], THUMB_R[2])
	# Muñeca, antebrazo, codo
	var wrist: Vector3 = at.call(0.075, deg_to_rad(-85.0), r + 0.016) + u * 0.006
	var dir := Vector3(0.15, -0.25, 0.95) if pistol else Vector3(0.38, -0.55, 0.74)
	var up := Vector3(0.0, 0.5, 0.85) if pistol else Vector3(-0.2, 0.9, 0.37)
	_forearm(glove, sleeve, wrist, wrist + dir.normalized() * FOREARM, up)
	_finish(root, "HandR", glove, sleeve).set_meta("palm", top + a * 0.04)


# --- Mano izquierda: guardamanos --------------------------------------------

## Escopetas: segunda pose de la mano izquierda, con los dos cartuchos en la mano.
## El controlador la muestra durante la recarga y la lleva hasta las recámaras.
static func _shell_loader(barrels: Node3D) -> void:
	var a := (barrels.get_node("ShellL") as Node3D).position
	var b := (barrels.get_node("ShellR") as Node3D).position
	var loader := Node3D.new()
	loader.name = "Loader"
	loader.position = (a + b) * 0.5
	loader.visible = false
	barrels.add_child(loader)
	# La mano agarra los culotes desde abajo; los cartuchos son los ShellL/ShellR
	# Se ve con los caños abiertos: el antebrazo se orienta para ese ángulo
	var comp := Basis(Vector3.RIGHT, deg_to_rad(WeaponController.BREAK_OPEN_DEG))
	_left_forend(loader, Vector3(0, -0.004, 0.024), 0.027, "HandLoad", comp, Vector3(-0.85, -0.5, -0.05), Vector3(-0.2, 0.35, 0.9), true)


static func _left_forend(parent: Node3D, c: Vector3, r: float, node_name := "HandL", comp := Basis.IDENTITY,
		arm_dir := Vector3(-0.58, -0.57, 0.57), upper_dir := Vector3(-0.17, 0.5, 0.85), wrist_at_palm := false) -> void:
	var a := Vector3.BACK  # +Z: hacia atrás (los dedos se escalonan a lo largo del caño)
	var u := Vector3.RIGHT
	var v := Vector3.UP
	var glove := MeshKit.new()
	var sleeve := MeshKit.new()
	var at := func(s: float, phi: float, rad: float) -> Vector3:
		return c + a * s + (u * cos(phi) + v * sin(phi)) * rad
	# Dedos: de abajo a la derecha subiendo por el costado derecho
	var heights := [-0.03, -0.009, 0.012, 0.031]
	for i in 4:
		_wrap_finger(glove, c, a, u, v, heights[i], r + 0.0085, deg_to_rad(-80.0), 1.0, FINGER_LEN[i], FINGER_R[i])
	# Palma abajo a la izquierda
	_palm(glove, at.call(0.0, deg_to_rad(-128.0), r + 0.007), a, u, v, deg_to_rad(-128.0), Vector3(0.022, 0.075, 0.056))
	_palm(glove, at.call(0.04, deg_to_rad(-150.0), r + 0.009), a, u, v, deg_to_rad(-150.0), Vector3(0.024, 0.04, 0.04))
	# Pulgar por el costado izquierdo, hacia adelante
	var t0: Vector3 = at.call(0.035, deg_to_rad(-165.0), r + 0.012)
	var t1: Vector3 = at.call(0.004, deg_to_rad(-178.0), r + 0.009)
	var t2: Vector3 = at.call(-0.026, deg_to_rad(172.0), r + 0.008)
	var t3: Vector3 = at.call(-0.05, deg_to_rad(165.0), r + 0.007)
	glove.capsule(t0, t1, THUMB_R[0] * 1.25, THUMB_R[0])
	glove.capsule(t1, t2, THUMB_R[0], THUMB_R[1])
	glove.capsule(t2, t3, THUMB_R[1], THUMB_R[2])
	var wrist: Vector3 = at.call(0.07, deg_to_rad(-138.0), r + 0.02)
	if wrist_at_palm:
		# Mano que se ve en otro ángulo: la muñeca sale de la palma hacia donde va el brazo
		wrist = at.call(0.01, deg_to_rad(-128.0), r + 0.014) + (comp * arm_dir).normalized() * 0.035
	# El codo queda abajo y afuera, fuera de la vista; el brazo sube hacia el hombro
	_forearm(glove, sleeve, wrist, wrist + (comp * arm_dir).normalized() * FOREARM, comp * upper_dir)
	_finish(parent, node_name, glove, sleeve).set_meta("palm", c)


# --- Mano izquierda de apoyo en la pistola ----------------------------------

static func _left_pistol(root: Node3D, p: Dictionary) -> void:
	var top: Vector3 = p["top"]
	var bottom: Vector3 = p["bottom"]
	var a := (bottom - top).normalized()
	var u := Vector3.RIGHT
	var v := u.cross(a).normalized()
	var r: float = float(p["r"]) + 0.019  # por encima de los dedos de la derecha
	var glove := MeshKit.new()
	var sleeve := MeshKit.new()
	var at := func(s: float, phi: float, rad: float) -> Vector3:
		return top + a * s + (u * cos(phi) + v * sin(phi)) * rad
	# Dedos sobre los de la derecha: de izquierda, por el frente, hacia la derecha
	var heights := [0.03, 0.05, 0.068, 0.084]
	for i in 4:
		_wrap_finger(glove, top, a, u, v, heights[i], r, deg_to_rad(195.0), -1.0, FINGER_LEN[i], FINGER_R[i])
	_palm(glove, at.call(0.056, deg_to_rad(185.0), r - 0.012), a, u, v, deg_to_rad(185.0), Vector3(0.022, 0.07, 0.052))
	# Pulgar adelante por el costado izquierdo del armazón
	var t0: Vector3 = at.call(0.03, deg_to_rad(165.0), r - 0.006)
	var t1 := t0 + Vector3(0.004, 0.008, -0.03)
	var t2 := t1 + Vector3(0.004, 0.004, -0.028)
	var t3 := t2 + Vector3(0.002, 0.001, -0.024)
	glove.capsule(t0, t1, THUMB_R[0] * 1.2, THUMB_R[0])
	glove.capsule(t1, t2, THUMB_R[0], THUMB_R[1])
	glove.capsule(t2, t3, THUMB_R[1], THUMB_R[2])
	var wrist: Vector3 = at.call(0.07, deg_to_rad(200.0), r + 0.008)
	_forearm(glove, sleeve, wrist, wrist + Vector3(-0.35, -0.25, 0.9).normalized() * FOREARM, Vector3(0.0, 0.5, 0.85))
	_finish(root, "HandL", glove, sleeve).set_meta("palm", at.call(0.056, deg_to_rad(185.0), r - 0.012))


# --- Piezas ------------------------------------------------------------------

## Dedo de tres falanges cerrado sobre un círculo de radio "rad" alrededor del eje.
static func _wrap_finger(k: MeshKit, base: Vector3, a: Vector3, u: Vector3, v: Vector3, s: float, rad: float,
		phi0: float, sense: float, lens: Array, radii: Array) -> void:
	var c := base + a * s
	var phi := phi0
	var prev := c + (u * cos(phi) + v * sin(phi)) * (rad + 0.004)
	k.ball(prev, radii[0], Vector3(1, 1, 1), 8)
	for j in 3:
		var l: float = lens[j]
		var rr := rad - j * 0.0015
		phi += sense * 2.0 * asin(clampf(l / (2.0 * rr), -1.0, 1.0))
		var nxt := c + (u * cos(phi) + v * sin(phi)) * rr
		var r1: float = radii[j + 1] if j < 2 else radii[2] * 0.9
		k.capsule(prev, nxt, radii[j], r1, 10)
		prev = nxt


## Palma: caja redondeada apoyada sobre el agarre, orientada según el ángulo.
static func _palm(k: MeshKit, center: Vector3, a: Vector3, u: Vector3, v: Vector3, phi: float, size: Vector3) -> void:
	var n := (u * cos(phi) + v * sin(phi)).normalized()
	var t := a.cross(n).normalized()
	k.box(Vector3.ZERO, size, 0.009, Transform3D(Basis(n, a, t), center))


## Muñeca con puño de guante, antebrazo con manga, codo y arranque del brazo.
static func _forearm(glove: MeshKit, sleeve: MeshKit, wrist: Vector3, elbow: Vector3, upper_dir: Vector3) -> void:
	var d := (elbow - wrist).normalized()
	glove.capsule(wrist - d * 0.012, wrist + d * 0.03, 0.026, 0.028, 14)
	# Puño del guante
	glove.capsule(wrist + d * 0.03, wrist + d * 0.045, 0.031, 0.031, 14)
	# Antebrazo con manga (más grueso hacia el codo)
	sleeve.capsule(wrist + d * 0.045, elbow, 0.033, 0.045, 14)
	sleeve.capsule(wrist + d * 0.05, wrist + d * 0.075, 0.037, 0.036, 14)  # puño de la manga
	sleeve.ball(elbow, 0.05, Vector3(1, 1, 1), 12)
	# Brazo: del codo hacia el hombro (sube y va hacia atrás)
	sleeve.capsule(elbow, elbow + upper_dir.normalized() * 0.28, 0.05, 0.058, 14)


static func _finish(parent: Node3D, n: String, glove: MeshKit, sleeve: MeshKit) -> Node3D:
	var g := Node3D.new()
	g.name = n
	parent.add_child(g)
	WeaponModelBuilder.put(g, "Glove", glove, WeaponModelBuilder.mat("glove"))
	WeaponModelBuilder.put(g, "Sleeve", sleeve, WeaponModelBuilder.mat("sleeve"))
	return g
