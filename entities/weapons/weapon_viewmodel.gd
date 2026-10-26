class_name WeaponViewmodel
extends Node
## Vista en primera persona del arma (cada frame): modelo, manos, pose de cadera y
## apuntado, balanceo, retroceso visual, estrés, recargas y destrabados animados,
## fogonazo y visor. Solo lee el estado de WeaponController ("wc"); no decide nada.
##
## El arma se dibuja en un SubViewport con mundo propio, cámara propia y FOV propio,
## superpuesto a la imagen del juego: nunca atraviesa paredes y su FOV no depende del
## del jugador. Apuntado real: el marcador "Sight" queda en el eje de la cámara.

## Posición de cadera por familia (espacio de la cámara del arma).
const HIP_POSE: Dictionary = {
	"pistol": Vector3(0.125, -0.13, -0.34),
	"smg": Vector3(0.13, -0.14, -0.26),
	"rifle_ar": Vector3(0.135, -0.15, -0.27),
	"rifle_ak": Vector3(0.135, -0.15, -0.27),
	"rifle_battle": Vector3(0.135, -0.15, -0.27),
	"bolt": Vector3(0.135, -0.15, -0.25),
	"shotgun_sxs": Vector3(0.13, -0.145, -0.24),
	"shotgun_ou": Vector3(0.13, -0.15, -0.24),
}
## Resolución de la imagen del visor (cuadrada).
const SCOPE_RES := 512
const VM_FOV_HIP := 62.0
const VM_FOV_ADS := 52.0

var wc: WeaponController
var rig: Node3D
var vm_viewport: SubViewport
var vm_camera: Camera3D
var scope_cam: Camera3D
## Posiciones de reposo de las piezas animadas (cargador, manija, manos...).
var part_base: Dictionary = {}
## Retroceso visual (lo suma el disparo; se recupera solo).
var kick_pos: Vector3 = Vector3.ZERO
var kick_rot: Vector3 = Vector3.ZERO
var slide_kick: float = 0.0
var flash_time: float = 0.0

var _vm_layer: CanvasLayer
var _vm_light: DirectionalLight3D
var _flash: MeshInstance3D
var _scope_vp: SubViewport
var _sway: Vector3 = Vector3.ZERO
var _bob_t: float = 0.0
var _time: float = 0.0
var _sprint_pose: float = 0.0
## Giro del arma por la pose de recarga (rad): la mano del guardamanos lo compensa.
var _reload_roll: float = 0.0
## Cargador fuera de la vista (se "cambia" por uno nuevo mientras no se ve).
var _mag_hidden: bool = false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_build_viewmodel()
	_build_scope_view()


## Agrega el modelo de un arma a la vista (oculto) y recuerda sus piezas.
func add_model(model: Node3D) -> void:
	rig.add_child(model)
	_remember_parts(model)
	if model.has_node("ScopeLens"):
		var lens := model.get_node("ScopeLens") as MeshInstance3D
		(lens.material_override as ShaderMaterial).set_shader_parameter("scope_tex", _scope_vp.get_texture())


func remove_model(model: Node3D) -> void:
	for n: Node in part_base.keys():
		if not is_instance_valid(n) or model.is_ancestor_of(n):
			part_base.erase(n)
	model.queue_free()


## Patada visual de un disparo.
func kick(w: WeaponData, ads: float, roll_deg: float) -> void:
	kick_pos.z += w.kick_back * lerpf(1.0, 0.6, ads)
	kick_rot.x += deg_to_rad(w.kick_rot) * lerpf(1.0, 0.45, ads)
	kick_rot.z += deg_to_rad(roll_deg)
	slide_kick = 1.0


func flash() -> void:
	flash_time = 0.045


static func smooth(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


# --- Cada frame ------------------------------------------------------------

func _process(delta: float) -> void:
	if wc == null or wc.player == null or wc.current() == null:
		return
	_time += delta
	var c := wc.current()
	var w := c.data
	var a := smooth(wc.ads_amount)

	# Pose base: cadera ↔ mira alineada con el centro de la pantalla
	var sight := (c.model.get_node("Sight") as Node3D).position
	var hip: Vector3 = HIP_POSE.get(w.model, Vector3(0.13, -0.14, -0.26))
	var ads := Vector3(-sight.x, -sight.y, -wc.eye_relief_for(c) - sight.z)
	var pos := hip.lerp(ads, a)
	var rot := Vector3.ZERO

	# Correr: arma baja y girada
	_sprint_pose = move_toward(_sprint_pose, 1.0 if wc.player.is_sprinting else 0.0, delta / 0.18)
	var s := smooth(_sprint_pose)
	pos += Vector3(0.03, -0.07, 0.07) * s
	rot += Vector3(deg_to_rad(-14), deg_to_rad(38), deg_to_rad(10)) * s

	# Balanceo al caminar
	var hspeed := Vector2(wc.player.velocity.x, wc.player.velocity.z).length()
	if wc.player.is_on_floor():
		_bob_t += delta * hspeed * 1.7
	var amp := 0.011 * clampf(hspeed / 4.0, 0.0, 1.6) * (1.0 - a * 0.85)
	pos += Vector3(sin(_bob_t) * amp, -absf(cos(_bob_t)) * amp * 0.8, 0.0)
	rot.z += sin(_bob_t) * amp * 1.2
	# Respiración
	pos.y += sin(_time * 1.7) * 0.0012 * (1.0 - a * 0.6)

	# Inercia al mirar (el arma "se atrasa" respecto de la cámara)
	var look := wc.player.last_look
	var sway_target := Vector3(-look.x, look.y, 0.0) * 0.5 * (1.0 - a * 0.75)
	sway_target = sway_target.limit_length(0.035)
	_sway = _sway.lerp(sway_target, 1.0 - exp(-10.0 * delta))
	pos += _sway
	rot += Vector3(_sway.y * 1.2, _sway.x * 2.0, _sway.x * 1.5)

	# Retroceso visual
	kick_pos = kick_pos.lerp(Vector3.ZERO, 1.0 - exp(-16.0 * delta))
	kick_rot = kick_rot.lerp(Vector3.ZERO, 1.0 - exp(-12.0 * delta))
	pos += kick_pos
	rot += kick_rot

	# Animaciones de estado
	_reload_roll = 0.0
	match wc.state:
		WeaponController.State.HOLSTER:
			var t := smooth(clampf(wc.state_time / wc.state_duration, 0.0, 1.0))
			pos.y -= 0.28 * t
			rot.x -= deg_to_rad(40) * t
		WeaponController.State.DRAW:
			var t := smooth(1.0 - clampf(wc.state_time / wc.state_duration, 0.0, 1.0))
			pos.y -= 0.28 * t
			rot.x -= deg_to_rad(40) * t
		WeaponController.State.RELOADING, WeaponController.State.CLEARING:
			var t := clampf(wc.state_time / wc.state_duration, 0.0, 1.0)
			var edge := minf(0.15, 0.35 / maxf(wc.state_duration, 0.1))
			var inn := smooth(clampf(t / edge, 0.0, 1.0)) * (1.0 - smooth(clampf((t - (1.0 - edge)) / edge, 0.0, 1.0)))
			# Pose de recarga: el arma se sube, se acerca y se gira para que se vea
			# lo que hacen las manos (brocal, ventana o recámaras)
			var rp := Vector3(-0.07, 0.07, 0.04)
			var rr := Vector3(18.0, -10.0, -38.0)
			match w.reload_type:
				"break":
					rp = Vector3(-0.03, 0.06, 0.03)
					rr = Vector3(12.0, 0.0, 14.0)
				"rounds":
					rp = Vector3(-0.04, 0.05, 0.03)
					rr = Vector3(12.0, 0.0, 22.0)
				_:
					if w.model == "pistol" and wc.state == WeaponController.State.CLEARING:
						# Montar la pistola: más lejos y de costado, para ver la corredera
						rp = Vector3(-0.05, 0.07, -0.03)
						rr = Vector3(12.0, -18.0, -22.0)
					elif w.model == "pistol":
						rp = Vector3(-0.1, 0.12, 0.1)
						rr = Vector3(24.0, -8.0, -30.0)
			if wc._plan != null and wc._plan.side > 0.0:
				# Manija a la derecha: el arma gira para mostrar ese lado mientras monta
				var k := smooth(path(t, wc._plan.roll_w).x)
				rr = rr.lerp(Vector3(10.0, -16.0, 16.0), k)
				rp = rp.lerp(Vector3(-0.08, 0.05, 0.0), k)
			pos += rp * inn
			rot += rr * (PI / 180.0) * inn
			_reload_roll = deg_to_rad(rr.z) * inn
			# Golpes: sacar y calzar el cargador, abrir y cerrar los caños, la manija
			var bump := _reload_bumps(w, t)
			pos += bump[0]
			rot += bump[1] * (PI / 180.0)
			if w.reload_type == "rounds" and wc.state == WeaponController.State.RELOADING:
				# Empuja cada cartucho: pequeño golpe por ronda
				var per := 0.7 / maxf(float(wc._rounds_planned), 1.0)
				var k := fmod(t, maxf(per, 0.01)) / maxf(per, 0.01)
				pos.y -= sin(k * PI) * 0.006 * inn
		WeaponController.State.CYCLING:
			# Accionar el cerrojo: el arma baja apenas y gira hacia la mano
			var t := clampf(wc.state_time / wc.state_duration, 0.0, 1.0)
			var b := sin(t * PI)
			# Casi nada si se acciona sin dejar de mirar por el visor
			rot.z += deg_to_rad(lerpf(8.0, 1.2, a)) * b
			pos.y -= 0.01 * b * (1.0 - a * 0.85)

	# Estrés: temblor de las manos (más fuerte manipulando el arma)
	var st := wc.player.stress.value
	if st > 0.001:
		var busy := 1.6 if wc.state == WeaponController.State.RELOADING or wc.state == WeaponController.State.CLEARING else 1.0
		var tr3 := wc.player.stress.tremor()
		# Más amplio en alto (value³ casi no suma en medio)
		var big := 1.0 + pow(st, 3.0) * 0.6
		var dp := tr3 * 0.0026 * st * big * busy * (1.0 - a * 0.5)
		var dr := Vector3(tr3.y, tr3.x, tr3.z) * deg_to_rad(0.9) * st * big * busy * (1.0 - a * 0.5)
		# Tope: el arma (y los brazos con ella) se mueve, pero los hombros no viajan;
		# manipulando, menos todavía (si no, el brazo cruza la pantalla)
		var busy_now := busy > 1.0
		pos += dp.limit_length(0.007 if busy_now else 0.014)
		rot += dr.limit_length(deg_to_rad(1.6 if busy_now else 3.2))
	rig.position = pos
	rig.rotation = rot
	_animate_parts(c, delta)

	vm_camera.fov = lerpf(VM_FOV_HIP, VM_FOV_ADS, a)
	_update_scope(c, a)
	_update_flash(c, delta)
	_sync_light()


## Recorrido suave por claves [[t, Vector3], ...] (Catmull-Rom): las manos y las
## piezas pasan por las posiciones clave sin frenar de golpe en cada una.
static func path(t: float, keys: Array) -> Vector3:
	var n := keys.size()
	if t <= float(keys[0][0]):
		return keys[0][1]
	if t >= float(keys[n - 1][0]):
		return keys[n - 1][1]
	var i := 0
	while i < n - 2 and t > float(keys[i + 1][0]):
		i += 1
	var t0: float = keys[i][0]
	var t1: float = keys[i + 1][0]
	var u := clampf((t - t0) / maxf(t1 - t0, 1e-5), 0.0, 1.0)
	var p0: Vector3 = keys[maxi(i - 1, 0)][1]
	var p1: Vector3 = keys[i][1]
	var p2: Vector3 = keys[i + 1][1]
	var p3: Vector3 = keys[mini(i + 2, n - 1)][1]
	return 0.5 * ((2.0 * p1) + (p2 - p0) * u + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * u * u
		+ (3.0 * p1 - p0 - 3.0 * p2 + p3) * u * u * u)


## Golpes del arma durante la recarga: [desplazamiento, giro en grados].
func _reload_bumps(w: WeaponData, t: float) -> Array:
	var z := Vector3.ZERO
	if wc.state == WeaponController.State.CLEARING and wc._plan != null:
		return [path(t, wc._plan.bump_p), path(t, wc._plan.bump_r)]
	match w.reload_type:
		"break":
			return [path(t, [[0.0, z], [0.1, z], [0.16, Vector3(0, -0.012, 0.004)], [0.24, Vector3(0, 0.004, 0)], [0.3, z],
				[0.56, z], [0.6, Vector3(0, 0.002, -0.006)], [0.66, z], [0.8, z], [0.86, Vector3(0, 0.012, 0)],
				[0.92, Vector3(0, -0.004, 0)], [1.0, z]]),
				path(t, [[0.0, z], [0.1, z], [0.16, Vector3(-5, 0, 1)], [0.24, Vector3(1, 0, 0)], [0.3, z], [0.56, z],
				[0.6, Vector3(-2, 0, 0)], [0.66, z], [0.8, z], [0.86, Vector3(7, 0, -1)], [0.92, Vector3(-2, 0, 0)], [1.0, z]])]
		"magazine":
			if wc._plan != null:
				return [path(t, wc._plan.bump_p), path(t, wc._plan.bump_r)]
	return [z, z]


## Manos durante la recarga y el cerrojo. Mano derecha (izquierda en pistolas):
## baja al cargador, se lo lleva, trae otro, lo calza y, vacía, tira de la manija.
## Cartucho a cartucho: la mano va a la ventana y empuja cada uno.
## Cerrojo: la mano derecha va a la bola del cerrojo y la acompaña.
func _animate_hands(c: WeaponController.WeaponSlot, t: float) -> Vector3:
	var m := c.model
	var w := c.data
	var hr := m.get_node_or_null("HandR") as Node3D
	var hl := m.get_node_or_null("HandL") as Node3D
	var z := Vector3.ZERO
	var off_r := z
	var off_l := z
	var mag_follow := z
	var pistol := w.model == "pistol"
	var rot_l := z  # giro de la muñeca izquierda (grados) alrededor de la palma
	var rot_r := z
	_mag_hidden = false
	for hn: String in ["HookR", "HookL", "HookP"]:
		if m.has_node(hn):
			(m.get_node(hn) as Node3D).visible = false
	if hr != null:
		hr.visible = true
	if hl != null:
		hl.visible = true
	if t >= 0.0 and wc._plan != null and (wc.state == WeaponController.State.RELOADING or wc.state == WeaponController.State.CLEARING):
		# Recarga o destrabado según el plan: manos, cargador y mano de gancho
		off_l = path(t, wc._plan.hand_l)
		rot_l = path(t, wc._plan.rot_l)
		off_r = path(t, wc._plan.hand_r)
		rot_r = path(t, wc._plan.rot_r)
		mag_follow = path(t, wc._plan.mag)
		_mag_hidden = ReloadPlan.in_window(t, wc._plan.mag_hidden)
		if ReloadPlan.in_window(t, wc._plan.hook_on):
			var hook_name := "HookP" if wc._plan.pull_part == "Slide" else ("HookR" if wc._plan.side > 0.0 else "HookL")
			var hook := m.get_node_or_null(hook_name) as Node3D
			var rack_hand := hr if wc._plan.side > 0.0 else hl
			if hook != null:
				var g := wc._plan_geo(c)
				var ho := path(t, wc._plan.hook)
				# Mientras tira, la mano va pegada a la pieza
				var pb := wc._plan.pull_back(t)
				if pb > 0.0:
					ho = Vector3(ho.x, ho.y, pb)
				# Compensa el giro del arma: el brazo cuelga hacia abajo
				var hb := Basis(Vector3.BACK, -_reload_roll * 0.85)
				hook.transform = Transform3D(hb, (g["knob"] as Vector3) + ho)
				hook.visible = true
				if rack_hand != null:
					rack_hand.visible = false
		# Estrés: las manos tiemblan al manipular
		var st := wc.player.stress.value
		if st > 0.001:
			var tr3 := wc.player.stress.tremor_base()
			off_l += Vector3(tr3.z, tr3.x, tr3.y) * 0.0045 * st
			off_r += tr3 * 0.002 * st
			rot_l += Vector3(tr3.y, tr3.z, tr3.x) * 1.5 * st  # poco giro: el brazo entero gira con la mano
			if mag_follow.length() > 0.001:
				mag_follow += Vector3(tr3.z, tr3.x, tr3.y) * 0.0045 * st
	elif t >= 0.0 and w.reload_type == "rounds" and hr != null and m.has_node("Ejection"):
		var palm: Vector3 = hr.get_meta("palm", z)
		var port: Vector3 = (m.get_node("Ejection") as Node3D).position + Vector3(0.03, -0.04, 0.025) - palm
		var o := path(t, [[0.0, z], [0.1, port + Vector3(0.03, -0.04, 0.03)], [0.16, port], [0.86, port],
			[0.94, port * 0.4 + Vector3(0.02, -0.02, 0.02)], [1.0, z]])
		if t > 0.16 and t < 0.86:
			# Empuja cada cartucho hacia abajo
			var per := 0.7 / maxf(float(wc._rounds_planned), 1.0)
			var k := fmod(t - 0.16, maxf(per, 0.01)) / maxf(per, 0.01)
			o += Vector3(0, -0.012 * sin(k * PI), 0.004 * sin(k * TAU))
		off_r = o
	elif wc.state == WeaponController.State.CYCLING and hr != null and m.has_node("Bolt"):
		var bolt := m.get_node("Bolt") as Node3D
		if bolt.has_meta("knob"):
			var ct := clampf(wc.state_time / maxf(wc.state_duration, 0.001), 0.0, 1.0)
			var knob: Vector3 = bolt.position + bolt.basis * (bolt.get_meta("knob") as Vector3)
			var tgt := knob + Vector3(0.02, -0.012, 0.006) - (hr.get_meta("palm", z) as Vector3)
			var blend := smooth(clampf(ct / 0.16, 0.0, 1.0)) * (1.0 - smooth(clampf((ct - 0.84) / 0.16, 0.0, 1.0)))
			off_r = tgt * blend
	if hr != null and part_base.has(hr):
		# Con el ojo muy cerca de la mano (escopetas, garganta de culata), al apuntar
		# la mano baja un poco para no tapar la vista
		var eye_z := (m.get_node("Sight") as Node3D).position.z + wc.eye_relief_for(c)
		var near := clampf(0.2 - (eye_z - (hr.get_meta("palm", z) as Vector3).z), 0.0, 0.15)
		off_r += Vector3(0.006, -0.45, 0.12) * near * smooth(wc.ads_amount)
		var pr: Vector3 = hr.get_meta("palm", z)
		var br := Basis.from_euler(rot_r * (PI / 180.0))
		hr.transform = Transform3D(br, part_base[hr] + pr - br * pr + off_r)
	if hl != null and part_base.has(hl):
		var bw := Basis.from_euler(rot_l * (PI / 180.0))
		if pistol:
			var pp: Vector3 = hl.get_meta("palm", z)
			hl.transform = Transform3D(bw, part_base[hl] + pp - bw * pp + off_l)
		else:
			# Gira sobre el eje del guardamanos al revés que el arma: los dedos siguen
			# agarrando y el brazo cuelga hacia abajo en vez de cruzar la pantalla
			var c0: Vector3 = hl.get_meta("palm", z)
			# Sobre el guardamanos compensa el giro; cuanto más lejos va, menos
			var on_hg := 1.0 - smooth(clampf(off_l.length() / 0.06, 0.0, 1.0))
			if t >= 0.0 and wc._plan != null and wc._plan.side < 0.0 and not wc._plan.hook_on.is_empty():
				# Yendo a la manija de la izquierda: el brazo sigue colgando hacia abajo
				var w0: Array = wc._plan.hook_on[0]
				var w1: Array = wc._plan.hook_on[wc._plan.hook_on.size() - 1]
				# (al destrabar, desde el principio: la mano va directo a la manija)
				var lead := 1.0 if wc.state == WeaponController.State.CLEARING else 0.14
				on_hg = maxf(on_hg, smooth(clampf((t - float(w0[0]) + lead) / 0.08, 0.0, 1.0))
					* (1.0 - smooth(clampf((t - float(w1[1]) - 0.02) / 0.08, 0.0, 1.0))))
			var b := Basis(Vector3.BACK, -_reload_roll * 0.85 * on_hg) * bw
			hl.transform = Transform3D(b, part_base[hl] + c0 - b * c0 + off_l)
	return mag_follow


func _animate_parts(c: WeaponController.WeaponSlot, delta: float) -> void:
	var w := c.data
	var busy := wc.state == WeaponController.State.RELOADING or wc.state == WeaponController.State.CLEARING
	var t := clampf(wc.state_time / maxf(wc.state_duration, 0.001), 0.0, 1.0) if busy else -1.0
	var m := c.model
	var mag_follow := _animate_hands(c, t)
	_update_stuck_case(c)
	if m.has_node("Mag"):
		var mag := m.get_node("Mag") as Node3D
		mag.position = part_base[mag] + mag_follow
		mag.visible = not _mag_hidden
	if m.has_node("Charging"):
		var ch := m.get_node("Charging") as Node3D
		var back := 0.0
		if t >= 0.0 and wc._plan != null and wc._plan.pull_part == "Charging":
			back = wc._plan.pull_back(t)
		elif t >= 0.0 and w.reload_type == "rounds":
			back = 0.07 * smooth(clampf(t / 0.08, 0.0, 1.0)) * (1.0 - smooth(clampf((t - 0.92) / 0.08, 0.0, 1.0)))
		elif c.malfunction == "double_feed":
			back = 0.012  # el cerrojo no cerró: la manija queda un poco atrás
		ch.position = part_base[ch] + Vector3(0, 0, back)
	if m.has_node("Slide"):
		var sl := m.get_node("Slide") as Node3D
		slide_kick = move_toward(slide_kick, 0.0, delta / 0.07)
		var back := sin(slide_kick * PI) * 0.032 if slide_kick > 0.0 else 0.0
		# Corredera atrás: vacía (hasta que entra el cargador y se suelta), o sin montar
		var released := t >= 0.0 and wc._plan != null and wc._plan.slide_release >= 0.0 and t > wc._plan.slide_release
		var locked := (c.mag == 0 and not released) or (c.malfunction == "unchambered" and wc.state != WeaponController.State.CLEARING)
		if locked and slide_kick <= 0.5 and wc.state != WeaponController.State.CLEARING:
			back = 0.032
		if wc.state == WeaponController.State.CLEARING and wc._plan != null and wc._plan.pull_part == "Slide":
			back = wc._plan.pull_back(t)
			# Sin montar, la corredera estaba atrás: sigue atrás hasta que la suelta
			if c.malfunction == "unchambered" and not wc._plan.pulls.is_empty() and t < float(wc._plan.pulls[0][2]):
				back = 0.032
		elif c.malfunction == "double_feed" or c.malfunction == "stovepipe":
			back = maxf(back, 0.01)
		sl.position = part_base[sl] + Vector3(0, 0, back)
	if m.has_node("Bolt"):
		var bolt := m.get_node("Bolt") as Node3D
		var lift := 0.0
		var back := 0.0
		var ct := -1.0
		if wc.state == WeaponController.State.CYCLING:
			ct = clampf(wc.state_time / maxf(wc.state_duration, 0.001), 0.0, 1.0)
		elif t >= 0.0:
			# Recargando: cerrojo abierto mientras entran los cartuchos
			if t <= 0.08:
				ct = t / 0.08 * 0.35
			elif t < 0.92:
				ct = 0.35
			else:
				ct = 0.35 + (t - 0.92) / 0.08 * 0.65
		if ct >= 0.0:
			lift = smooth(clampf(ct / 0.2, 0.0, 1.0)) * (1.0 - smooth(clampf((ct - 0.8) / 0.2, 0.0, 1.0)))
			back = smooth(clampf((ct - 0.2) / 0.25, 0.0, 1.0)) * (1.0 - smooth(clampf((ct - 0.5) / 0.25, 0.0, 1.0)))
		bolt.position = part_base[bolt] + Vector3(0, 0, back * 0.075)
		bolt.rotation = Vector3(0, 0, deg_to_rad(65) * lift)
	if m.has_node("Barrels"):
		var br := m.get_node("Barrels") as Node3D
		_animate_break(br, t)


## Vaina trabada en la ventana ("encasquillada"): se crea la primera vez y se ve
## mientras dure la falla, de pie, apretada por el cerrojo.
func _update_stuck_case(c: WeaponController.WeaponSlot) -> void:
	var m := c.model
	var sc := m.get_node_or_null("StuckCase") as Node3D
	if sc == null:
		if not c.case_stuck or not m.has_node("Ejection"):
			return
		var pistol := c.data.model == "pistol"
		sc = Node3D.new()
		sc.name = "StuckCase"
		m.add_child(sc)
		var r := 0.0045 if pistol else 0.0055
		var l := 0.022 if pistol else 0.042
		WeaponModelBuilder.cyl(sc, "Case", r, l, Vector3.ZERO, WeaponModelBuilder.mat("brass"), 12, Vector3(PI * 0.5, 0, 0), 0.0008)
		sc.position = (m.get_node("Ejection") as Node3D).position + Vector3(0.004, l * 0.42, 0.0)
		sc.rotation = Vector3(0.0, 0.0, deg_to_rad(-48.0))
	sc.visible = c.case_stuck


## Escopeta de quiebre: la mano izquierda suelta el guardamanos, los caños caen
## a fondo, la mano trae dos cartuchos, los mete en las recámaras, se cierra y la
## mano vuelve al guardamanos.
##   0.02–0.12 la mano se va · 0.10–0.26 abre (salen las vainas a 0.3)
##   0.34–0.48 trae los cartuchos · 0.48–0.60 los mete · 0.62–0.74 la mano se va
##   0.80–0.92 cierra · 0.88–0.98 la mano vuelve al guardamanos
func _animate_break(br: Node3D, t: float) -> void:
	var r := t >= 0.0
	var open := 0.0
	if r:
		open = smooth(clampf((t - 0.1) / 0.16, 0.0, 1.0)) * (1.0 - smooth(clampf((t - 0.8) / 0.12, 0.0, 1.0)))
	br.rotation = Vector3(deg_to_rad(-WeaponController.BREAK_OPEN_DEG) * open, 0, 0)
	var inv := br.basis.inverse()
	var z := Vector3.ZERO
	# Recorridos en el espacio del arma (se pasan al de los caños, que están girados)
	var away := Vector3(-0.07, -0.26, 0.04)
	var hand := br.get_node_or_null("HandL") as Node3D
	if hand != null:
		var o := z
		if r:
			o = path(t, [[0.0, z], [0.03, Vector3(-0.004, -0.01, 0.01)], [0.07, Vector3(-0.03, -0.09, 0.03)], [0.13, away],
				[0.85, away], [0.9, Vector3(-0.035, -0.1, 0.03)], [0.95, Vector3(-0.004, -0.012, 0.01)], [1.0, z]])
		hand.position = part_base[hand] + inv * o
		hand.visible = not (r and t > 0.13 and t < 0.85)
	var loader := br.get_node_or_null("Loader") as Node3D
	var load_off := z
	if loader != null:
		var behind := br.basis * Vector3(0, 0.004, 0.045)  # alineados detrás de las recámaras
		var seated := br.basis * Vector3(0, 0, -0.024)  # culote al ras de la recámara
		var o := away
		if r and t >= 0.34 and t < 0.78:
			o = path(t, [[0.34, away], [0.41, Vector3(-0.07, -0.12, 0.05)], [0.47, behind + Vector3(-0.01, 0.004, 0.01)],
				[0.5, behind], [0.6, seated], [0.63, seated], [0.69, Vector3(-0.05, -0.1, 0.06)], [0.78, away]])
		load_off = inv * o
		loader.visible = r and t >= 0.34 and t < 0.78
		loader.position = part_base[loader] + load_off
	var seat := Vector3(0, 0, -0.024)
	for i in 2:
		var sh := br.get_node("Shell" + ("L" if i == 0 else "R")) as Node3D
		var base: Vector3 = part_base[sh]
		var spent := i < wc._break_spent
		sh.rotation = Vector3.ZERO
		if not r:
			sh.visible = false
			sh.position = base + seat
		elif t < 0.34 and spent:
			# Vaina vieja: el extractor la saca un poco al abrir y el expulsor la tira
			# hacia arriba, rápido y casi vertical (a 0.25 sigue como vaina física)
			var ex := 0.03 * smooth(clampf((t - 0.11) / 0.08, 0.0, 1.0))
			var k := clampf((t - 0.19) / 0.06, 0.0, 1.0)
			var fly := inv * (Vector3((i * 2.0 - 1.0) * 0.015, 0.2, 0.025) * k)
			sh.visible = t > 0.1 and t < 0.25
			sh.position = base + seat + Vector3(0, 0, ex) + fly
			sh.rotation = Vector3(-deg_to_rad(90.0) * k, 0, 0)
		elif not spent:
			# Cartucho sin disparar: queda en la recámara (se ve con los caños abiertos)
			sh.visible = t > 0.1 and t < 0.92
			sh.position = base + seat
		else:
			sh.visible = t >= 0.34 and t < 0.92
			# Los cartuchos viajan en la mano hasta que entran; después quedan en la recámara
			sh.position = base + (load_off if (t < 0.6 and loader != null) else seat)


func _update_flash(c: WeaponController.WeaponSlot, delta: float) -> void:
	if flash_time > 0.0:
		flash_time -= delta
		var muzzle := c.model.get_node("Muzzle") as Node3D
		_flash.visible = true
		_flash.global_position = muzzle.global_position
		_flash.rotation = Vector3(0, 0, _rng.randf() * TAU)
		var sc := _rng.randf_range(0.8, 1.25) * (1.6 if c.data.reload_type == "break" else 1.0)
		_flash.scale = Vector3(sc, sc, sc)
	else:
		_flash.visible = false


## Copia la dirección del sol del mundo a la luz del arma (en espacio de cámara).
func _sync_light() -> void:
	var sun := get_tree().get_first_node_in_group("sun") as DirectionalLight3D
	if sun == null:
		return
	_vm_light.basis = wc.player.camera.global_basis.inverse() * sun.global_basis
	_vm_light.light_color = sun.light_color
	_vm_light.light_energy = sun.light_energy * 0.9











func _remember_parts(model: Node3D) -> void:
	for path: String in ["Mag", "Charging", "Slide", "Bolt", "Barrels/ShellL", "Barrels/ShellR", "Barrels/HandL", "Barrels/Loader",
			"HandR", "HandL", "HookR", "HookL"]:
		if model.has_node(path):
			var n := model.get_node(path) as Node3D
			part_base[n] = n.position


## Visor con aumento: la cámara del visor mira por el eje del arma y su FOV
## se calcula para que el aumento sea real respecto de la vista sin visor.
func _update_scope(c: WeaponController.WeaponSlot, a: float) -> void:
	var lens := c.model.get_node_or_null("ScopeLens") as MeshInstance3D
	var on := lens != null and a > 0.02 and c.data.scope_mag > 1.0
	_scope_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	if lens == null:
		return
	(lens.material_override as ShaderMaterial).set_shader_parameter("active", a if on else 0.0)
	if not on:
		return
	var main := wc.player.camera
	# Tamaño angular del ocular en pantalla, convertido a ángulo de la cámara del mundo
	var dist := maxf(-lens.global_position.z, 0.01)
	var d: float = lens.get_meta("lens_d", 0.034)
	var a_vm := 2.0 * atan((d * 0.5) / dist)
	var frac := tan(a_vm * 0.5) / tan(deg_to_rad(vm_camera.fov) * 0.5)
	var a_main := 2.0 * atan(frac * tan(deg_to_rad(main.fov) * 0.5))
	scope_cam.fov = clampf(rad_to_deg(a_main) / wc.scope_mag(c), 0.3, 60.0)
	# Mira por el eje del arma (incluye retroceso y balanceo)
	scope_cam.global_transform = Transform3D(main.global_basis * rig.basis, main.global_position)


func _build_scope_view() -> void:
	_scope_vp = SubViewport.new()
	_scope_vp.name = "ScopeView"
	_scope_vp.size = Vector2i(SCOPE_RES, SCOPE_RES)
	_scope_vp.own_world_3d = false
	_scope_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_scope_vp.audio_listener_enable_3d = false
	_scope_vp.msaa_3d = Viewport.MSAA_2X
	add_child(_scope_vp)
	scope_cam = Camera3D.new()
	scope_cam.near = 0.05
	scope_cam.far = 2000.0
	scope_cam.current = true
	_scope_vp.add_child(scope_cam)


func _build_viewmodel() -> void:
	_vm_layer = CanvasLayer.new()
	_vm_layer.name = "ViewmodelLayer"
	_vm_layer.layer = 1
	add_child(_vm_layer)
	var container := SubViewportContainer.new()
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vm_layer.add_child(container)
	vm_viewport = SubViewport.new()
	vm_viewport.transparent_bg = true
	vm_viewport.own_world_3d = true
	vm_viewport.handle_input_locally = false
	vm_viewport.audio_listener_enable_3d = false
	vm_viewport.msaa_3d = Viewport.MSAA_2X
	container.add_child(vm_viewport)

	vm_camera = Camera3D.new()
	vm_camera.fov = VM_FOV_HIP
	vm_camera.near = 0.01
	vm_camera.far = 10.0
	vm_camera.current = true
	vm_viewport.add_child(vm_camera)

	_vm_light = DirectionalLight3D.new()
	_vm_light.shadow_enabled = false
	vm_viewport.add_child(_vm_light)
	var fill := DirectionalLight3D.new()
	fill.light_energy = 0.25
	fill.rotation_degrees = Vector3(-20, 160, 0)
	fill.shadow_enabled = false
	vm_viewport.add_child(fill)

	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.6, 0.56)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	var we := WorldEnvironment.new()
	we.environment = env
	vm_viewport.add_child(we)

	rig = Node3D.new()
	rig.name = "Rig"
	vm_viewport.add_child(rig)

	_flash = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.14, 0.14)
	_flash.mesh = q
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fm.albedo_texture = _make_flash_texture()
	fm.albedo_color = Color(1.0, 0.75, 0.45)
	_flash.material_override = fm
	_flash.visible = false
	vm_viewport.add_child(_flash)



## Estrella de destello generada por código. TODO-ASSET: vfx_muzzle_flash
static func _make_flash_texture() -> ImageTexture:
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := Vector2(n, n) * 0.5
	for y in n:
		for x in n:
			var v := Vector2(x, y) - c
			var d := v.length() / (n * 0.5)
			var ang := atan2(v.y, v.x)
			var rays := pow(absf(cos(ang * 3.0)), 8.0) * (1.0 - d)
			var core := clampf(1.0 - d * 2.2, 0.0, 1.0)
			var a := clampf(core + rays * 1.2, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)
