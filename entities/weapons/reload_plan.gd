class_name ReloadPlan
extends RefCounted
## Plan de una recarga con cargador o de un destrabado: claves de las manos, del
## cargador, de la manija (o corredera), de la mano de gancho y de los golpes del arma.
## Se arma al empezar, con el estrés de ese momento (más lento, intentos fallidos al
## brocal, olvidarse de montar), y el controlador solo lo evalúa cuadro a cuadro.
##
## Se construye en "unidades" (1 unidad ≈ una recarga normal sin manija) y al final
## todo se pasa a fracciones de la duración.
##
## Acciones:
##  - "reload": cambiar el cargador y, vacía, montar.
##  - "rack": montar (se olvidó de montar, o pistola con la corredera atrás).
##  - "misfire": golpe al cargador y montar; sale el cartucho que no disparó.
##  - "stovepipe": montar; sale la vaina trabada en la ventana.
##  - "double_feed": sacar el cargador, montar dos veces, meterlo y montar.

const Z := Vector3.ZERO

var action: String = "reload"
## Duración total (s).
var duration: float = 1.0
## Se olvidó de montar (recarga vacía bajo estrés): queda sin cartucho en la recámara.
var forgot_chamber: bool = false
## Intentos fallidos de meter el cargador.
var fumbles: int = 0
## Lado de la manija: +1 derecha (monta la mano derecha), −1 izquierda.
var side: float = -1.0
## Recorrido de la manija o la corredera (m).
var travel: float = 0.07
## La pieza que se tira: "Charging" o "Slide".
var pull_part: String = "Charging"

var hand_l: Array = []
var rot_l: Array = []
var hand_r: Array = []
var rot_r: Array = []
var mag: Array = []
var mag_hidden: Array = []
var hook: Array = []
var hook_on: Array = []
var pulls: Array = []
var bump_p: Array = []
var bump_r: Array = []
## Peso (en x) del giro del arma para mostrar el lado derecho al montar con la derecha.
var roll_w: Array = []
## [[t, nombre]]: "mag_out", "mag_in", "fumble", "rack_back", "rack_fwd", "eject_live",
## "eject_case", "slide_release", "tap".
var events: Array = []
## Pistolas: momento en que se suelta la corredera (−1 = no se suelta).
var slide_release: float = -1.0

var _l := Z
var _r := Z
var _rl := Z
var _rr := Z
var _slow := 1.0


## geo: "pl"/"pr" palmas de las manos; "mag_base" y "grab" (si hay cargador);
## "knob" (punto de la manija o corredera), "side", "hook_palm", "travel",
## "pull_part", "pistol", "rack" (si el arma tiene manija para montar).
static func make(act: String, geo: Dictionary, level: int, empty: bool, rng: RandomNumberGenerator,
		base_time: float, empty_time: float) -> ReloadPlan:
	var p := ReloadPlan.new()
	p.action = act
	p.side = geo.get("side", -1.0)
	p.travel = geo.get("travel", 0.07)
	p.pull_part = geo.get("pull_part", "Charging")
	p._slow = [1.0, 1.12, 1.27, 1.4][clampi(level, 0, 3)]
	var can_rack: bool = geo.get("rack", false)
	var pistol: bool = geo.get("pistol", false)
	var u := 0.0
	var uses_rack := false
	match act:
		"reload":
			if level == 1:
				p.fumbles = 1 if rng.randf() < 0.5 else 0
			elif level == 2:
				p.fumbles = 2
			elif level >= 3:
				p.fumbles = 3  # extremo: casi no le emboca
			var rack := empty and can_rack and not pistol
			if empty and can_rack and level > 0 and rng.randf() < [0.0, 0.15, 0.35, 0.5][clampi(level, 0, 3)]:
				rack = false
				p.forgot_chamber = true
			u = p._mag_out(geo, 0.0, true)
			u = p._mag_in(geo, u, p.fumbles, true)
			var seat := u
			if pistol and empty and not p.forgot_chamber:
				p.slide_release = seat + 0.07
				p._ev(seat + 0.07, "slide_release")
			if rack:
				uses_rack = true
				u = p._rack_after_seat(geo, seat, 1, ["", ""])
			else:
				u = p._left_home(geo, seat)
				p._kr(u, Z, Z)
		"rack", "stovepipe":
			uses_rack = true
			u = p._rack(geo, 0.02, 1, ["eject_case" if act == "stovepipe" else ""], Z)
		"misfire":
			uses_rack = true
			if geo.has("mag_base"):
				u = p._tap(geo, 0.0)
			if p.side > 0.0:
				p._left_home(geo, u)
				u = p._rack(geo, u + 0.08, 1, ["eject_live"], Z)
			else:
				u = p._rack(geo, u, 1, ["eject_live"], Z)
		"double_feed":
			uses_rack = true
			u = p._mag_out(geo, 0.0, true)
			var hold: Vector3 = p._l
			if p.side > 0.0:
				u = p._rack(geo, u + 0.02, 2, ["eject_live", ""], Z)
			else:
				u = p._rack(geo, u + 0.02, 2, ["eject_live", ""], hold)
			u = p._mag_in(geo, u - 0.12, 0, false)
			u = p._rack_after_seat(geo, u, 1, [""])
	var end := u + 0.04
	# Duración: el tiempo del arma escalado por lo que se agregó (intentos fallidos)
	# y más lento con estrés. Destrabar: tiempo por unidad igual al de recarga.
	if act == "reload":
		var nominal := end - p.fumbles * 0.17
		p.duration = (empty_time if uses_rack else base_time) * end / maxf(nominal, 0.01)
	else:
		p.duration = base_time * end * 0.95
	p.duration *= p._slow
	p._normalize(end)
	return p


# --- Tramos ------------------------------------------------------------------

func _kl(u: float, v: Vector3, rot := Vector3.INF) -> void:
	hand_l.append([u, v])
	_l = v
	if rot != Vector3.INF:
		rot_l.append([u, rot])
		_rl = rot


func _kr(u: float, v: Vector3, rot := Vector3.INF) -> void:
	hand_r.append([u, v])
	_r = v
	if rot != Vector3.INF:
		rot_r.append([u, rot])
		_rr = rot


func _ev(u: float, n: String) -> void:
	events.append([u, n])


func _bump(u: float, p: Vector3, r: Vector3, settle := 0.06) -> void:
	bump_p.append_array([[u - 0.02, Z], [u, p], [u + settle * 0.5, -p * 0.3], [u + settle, Z]])
	bump_r.append_array([[u - 0.02, Z], [u, r], [u + settle * 0.5, -r * 0.3], [u + settle, Z]])


func _grab(geo: Dictionary) -> Vector3:
	return (geo["mag_base"] as Vector3) + (geo["grab"] as Vector3) - (geo["pl"] as Vector3)


## La izquierda va al cargador, lo saca y lo baja fuera de la vista.
func _mag_out(geo: Dictionary, u: float, hide: bool) -> float:
	var g := _grab(geo)
	var drop := g + Vector3(-0.004, -0.075, 0.014)
	var out := g + Vector3(-0.14, -0.5, 0.18)
	_kl(u, _l, _rl)
	_kl(u + 0.1, g * 0.62 + Vector3(0.012, -0.028, 0.03), Vector3(6, 4, -8))
	_kl(u + 0.15, g, Vector3(8, 4, -12))
	_kl(u + 0.2, drop, Vector3(14, 6, -16))
	_kl(u + 0.33, out, Vector3(26, 10, -30))
	mag.append_array([[u + 0.15, Z], [u + 0.2, drop - g], [u + 0.33, out - g]])
	if hide:
		mag_hidden.append([u + 0.285, -1.0])
	_ev(u + 0.15, "mag_out")
	_bump(u + 0.2, Vector3(0, -0.012, 0.004), Vector3(-3, 0, 2), 0.14)
	_kr(u, _r, _rr)
	_kr(u + 0.15, Vector3(0.002, 0.004, 0.006), Vector3(2, 0, -2))
	_kr(u + 0.33, Vector3(0.003, 0.006, 0.01), Vector3(3, 1, -3))
	return u + 0.33


## Trae el cargador (nuevo o el mismo) y lo calza; con estrés pega en el borde del
## brocal, lo baja y vuelve a intentar.
func _mag_in(geo: Dictionary, u: float, n_fumbles: int, _fresh: bool) -> float:
	var g := _grab(geo)
	var out := g + Vector3(-0.14, -0.5, 0.18)
	var drop2 := g + Vector3(-0.014, -0.105, 0.024)
	var x := u + 0.12  # agarra uno nuevo (fuera de cuadro)
	_kl(x, out, Vector3(26, 10, -30))
	if not mag_hidden.is_empty() and float(mag_hidden[mag_hidden.size() - 1][1]) < 0.0:
		mag_hidden[mag_hidden.size() - 1][1] = x + 0.04
	mag.append([x, out - g])
	x += 0.11
	_kl(x, drop2, Vector3(14, 6, -14))
	mag.append([x, drop2 - g])
	for i in n_fumbles:
		# Le pega al borde del brocal (adelante o atrás), se traba, lo baja y reintenta
		var sx := 0.012 if i % 2 == 0 else -0.01
		var miss := g + Vector3(sx, -0.016, 0.014 if i % 2 == 0 else -0.012)
		_kl(x + 0.05, miss, Vector3(10, 2, -18 if i % 2 == 0 else -4))
		mag.append([x + 0.05, miss - g])
		_ev(x + 0.05, "fumble")
		_bump(x + 0.05, Vector3(0, -0.005, 0.002), Vector3(-1.5, 0.5, 1.2), 0.05)
		_kl(x + 0.09, miss + Vector3(0.002, -0.004, 0.002), Vector3(12, 3, -15))
		mag.append([x + 0.09, miss + Vector3(0.002, -0.004, 0.002) - g])
		_kl(x + 0.15, drop2 + Vector3(0.004 * (i % 2), -0.01, 0.004), Vector3(16, 6, -14))
		mag.append([x + 0.15, drop2 + Vector3(0.004 * (i % 2), -0.01, 0.004) - g])
		x += 0.17
	_kl(x + 0.06, g + Vector3(0, -0.014, 0.003), Vector3(9, 4, -11))
	mag.append([x + 0.06, Vector3(0, -0.014, 0.003)])
	_kl(x + 0.11, g, Vector3(6, 3, -9))
	mag.append([x + 0.11, Z])
	_ev(x + 0.11, "mag_in")
	_bump(x + 0.12, Vector3(0, 0.014, -0.004), Vector3(5, 0, -2), 0.08)
	_kr(x + 0.06, Vector3(0, -0.004, 0.002), Vector3(-2, 0, 1))
	_kr(x + 0.17, Vector3(0.002, 0.004, 0.008), Z)
	return x + 0.11


## La izquierda vuelve del brocal al guardamanos.
func _left_home(_geo: Dictionary, u: float) -> float:
	var from := _l
	_kl(u + 0.04, from + Vector3(0.01, 0.018, 0.016), Vector3(3, 1, -4))
	_kl(u + 0.13, from * 0.32 + Vector3(0.01, -0.012, 0.025), Vector3(2, 1, -3))
	_kl(u + 0.19, Z, Z)
	return u + 0.19


## Golpe de la palma abajo del cargador (tap-rack).
func _tap(geo: Dictionary, u: float) -> float:
	var g := _grab(geo) if geo.has("mag_base") else Vector3(0, -0.1, 0.0)
	var under := g + Vector3(0, -0.035, 0.012)
	_kl(u, _l, _rl)
	_kl(u + 0.09, under, Vector3(10, 4, -10))
	_kl(u + 0.12, under + Vector3(0, 0.03, -0.004), Vector3(8, 4, -10))
	_ev(u + 0.12, "tap")
	_bump(u + 0.12, Vector3(0, 0.01, 0), Vector3(3, 0, 0), 0.06)
	_kl(u + 0.16, under + Vector3(0, -0.01, 0.006), Vector3(10, 4, -10))
	return u + 0.16


## Después de calzar: con la manija a la derecha la izquierda vuelve primero.
func _rack_after_seat(geo: Dictionary, seat: float, n: int, ejects: Array) -> float:
	if side > 0.0:
		_left_home(geo, seat)
		return _rack(geo, seat + 0.1, n, ejects, Z)
	return _rack(geo, seat + 0.05, n, ejects, Z)


## Montar: la mano del lado de la manija llega por afuera del arma, cambia a la pose
## de gancho, tira "n" veces (soltando cada vez) y vuelve a "home".
func _rack(geo: Dictionary, u: float, n: int, ejects: Array, home: Vector3) -> float:
	var right := side > 0.0
	var rpalm: Vector3 = geo["pr"] if right else geo["pl"]
	var knob: Vector3 = geo["knob"]
	var hp: Vector3 = geo.get("hook_palm", Z)
	var ap := knob + hp + Vector3(side * 0.012, 0.012, 0.02) - rpalm
	var start := _r if right else _l
	var mid := start.lerp(ap, 0.5) + Vector3(side * 0.07, 0.01, 0.04)
	var appr := Vector3(side * 0.012, 0.012, 0.02)
	var ar := u + 0.075
	# Giro de la muñeca en el camino; a la izquierda, además, el brazo baja (sin esto,
	# con el arma girada el antebrazo cruza la pantalla en horizontal)
	var turn := Vector3(-10, 8, 14) if right else Vector3(-6, 0, 38)
	if right:
		_kr(u, start, _rr)
		_kr(u + 0.0375, mid, turn)
		_kr(ar, ap, turn * 0.5)
		roll_w.append_array([[u - 0.06, Z], [u + 0.02, Vector3(1, 0, 0)]])
	else:
		_kl(u, start, _rl)
		_kl(u + 0.0375, mid, turn)
		_kl(ar, ap, Vector3(0, 0, 30))
	hook.append([ar, appr])
	var p0 := ar + 0.04
	hook.append([p0, Z])
	var rel := p0
	for i in n:
		var p1 := p0 + 0.065
		rel = p1 + 0.03
		hook.append_array([[p1, Vector3(0, 0, travel)], [rel, Vector3(0, 0, travel)]])
		pulls.append([p0, p1, rel])
		_ev(p1, "rack_back")
		_ev(rel, "rack_fwd")
		var ej: String = ejects[i] if i < ejects.size() else ""
		if ej != "":
			_ev(p1 - 0.01, ej)
		bump_p.append_array([[p0, Z], [p1, Vector3(side * 0.004, 0, 0.01)], [rel, Vector3(side * 0.004, 0, 0.01)],
			[rel + 0.025, Vector3(0, 0.006, -0.006)], [rel + 0.07, Z]])
		bump_r.append_array([[p0, Z], [p1, Vector3(1.5, side * 3.0, -side * 2.0)], [rel, Vector3(1.5, side * 3.0, -side * 2.0)],
			[rel + 0.025, Vector3(-3, 0, side * 1.5)], [rel + 0.08, Z]])
		if i < n - 1:
			# Vuelve a tomar la manija adelante para el próximo tirón
			hook.append_array([[rel + 0.03, appr * 0.5 + Vector3(0, 0, travel * 0.5)], [rel + 0.07, Z]])
			p0 = rel + 0.08
	var off := rel + 0.03
	hook.append([off, Vector3(0, 0, travel) + appr])
	hook_on.append([ar, off])
	var mid2 := ap.lerp(home, 0.5) + Vector3(side * 0.05, -0.04, 0.03)
	var back := off + 0.12
	if right:
		_kr(off, ap, turn * 0.5)
		_kr(off + 0.05, mid2, Vector3(-6, 3, 6))
		_kr(back, home, Z)
		roll_w.append_array([[off + 0.02, Vector3(1, 0, 0)], [back + 0.04, Z]])
	else:
		_kl(off, ap, Vector3(0, 0, 30))
		_kl(off + 0.055, mid2, Vector3(-4, 0, 34))
		_kl(back, home, Z)
	return back


# --- Evaluación ----------------------------------------------------------------

func _normalize(total: float) -> void:
	var k := 1.0 / maxf(total, 0.001)
	for arr: Array in [hand_l, rot_l, hand_r, rot_r, mag, hook, bump_p, bump_r, roll_w, events]:
		arr.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
		for e: Array in arr:
			e[0] = float(e[0]) * k
	for arr: Array in [mag_hidden, hook_on]:
		for e: Array in arr:
			e[0] = float(e[0]) * k
			e[1] = float(e[1]) * k if float(e[1]) >= 0.0 else 2.0
	for e: Array in pulls:
		for i in 3:
			e[i] = float(e[i]) * k
	if slide_release >= 0.0:
		slide_release *= k
	# Extremos: todo empieza y termina en reposo
	for arr: Array in [hand_l, rot_l, hand_r, rot_r, mag, bump_p, bump_r, roll_w]:
		arr.push_front([0.0, Z])
		arr.append([1.0, Z])


static func in_window(t: float, windows: Array) -> bool:
	for w: Array in windows:
		if t >= float(w[0]) and t < float(w[1]):
			return true
	return false


## Recorrido de la manija: atrás con la mano, se sostiene y vuelve de golpe al soltarla.
func pull_back(t: float) -> float:
	for e: Array in pulls:
		var p0: float = e[0]
		var p1: float = e[1]
		var rl: float = e[2]
		if t < p0:
			continue
		if t < p1:
			return travel * WeaponViewmodel.smooth((t - p0) / maxf(p1 - p0, 0.001))
		if t < rl:
			return travel
		var k := clampf((t - rl) / 0.02, 0.0, 1.0)
		if k < 1.0:
			return travel * (1.0 - k) * (1.0 - k)
	return 0.0
