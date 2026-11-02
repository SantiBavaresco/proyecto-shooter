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
## Desvío del eje del arma por respiración y pulso (euler, rad): la bala sale por ahí
## apuntando (lo usa WeaponController al disparar) y la retícula del visor lo muestra.
var aim_rot: Vector3 = Vector3.ZERO

var _vm_layer: CanvasLayer
var _vm_light: DirectionalLight3D
var _flash: MeshInstance3D
## Fogonazo: variantes de la estrella frontal y la llama a lo largo del caño.
var _flash_mats: Array[StandardMaterial3D] = []
var _flame: MeshInstance3D
var _flame_mat: StandardMaterial3D
## Forma elegida para el disparo en curso: [variante, escala, largo de llama, ancho, giro, color].
var _flash_shot: Array = []
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
# Modelos importados: animación en curso, último estado y disparo pendiente
var _anim_key := ""
var _last_state: int = -1
var _shot_new: bool = false
## Brazos con esqueleto para las armas hechas por código (las importadas traen los suyos).
var arms: SkinnedArms


func _ready() -> void:
	_rng.randomize()
	_build_viewmodel()
	_build_scope_view()


## Agrega el modelo de un arma a la vista (oculto) y recuerda sus piezas.
func add_model(model: Node3D) -> void:
	rig.add_child(model)
	_remember_parts(model)
	if arms != null and arms.ok and not model.has_meta("imported"):
		SkinnedArms.hide_procedural(model)
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
	_shot_new = true


func flash() -> void:
	flash_time = 0.045
	# Cada disparo con otra forma: estrella, tamaño, llama hacia adelante y color
	var warm := _rng.randf()
	_flash_shot = [_rng.randi() % maxi(_flash_mats.size(), 1), _rng.randf_range(0.75, 1.3),
		_rng.randf_range(0.0, 1.0) if _rng.randf() > 0.2 else 0.0, _rng.randf_range(0.7, 1.3), _rng.randf() * TAU,
		Color(1.0, lerpf(0.62, 0.85, warm), lerpf(0.3, 0.55, warm))]


## Modelo importado: cadera (el ojo del modelo en la cámara) ↔ apuntado (la mira del
## hueso del arma alineada con la cámara), y la animación según el estado.
func _pose_imported(c: WeaponController.WeaponSlot, a: float) -> void:
	var inst := c.model.get_node("Inst") as Node3D
	var p := c.data.model_params
	var eye := ImportedWeapon._v(p.get("eye", [0.0, 1.6, 0.0]))
	var m_hip := Transform3D(Basis.IDENTITY, -eye)
	var s := ImportedWeapon.sight_in_inst(c.model)
	var m_ads := Transform3D(Basis.IDENTITY, Vector3(0, 0, -wc.eye_relief_for(c))) * s.affine_inverse()
	var q := m_hip.basis.get_rotation_quaternion().slerp(m_ads.basis.get_rotation_quaternion(), a)
	inst.transform = Transform3D(Basis(q), m_hip.origin.lerp(m_ads.origin, a))
	ImportedWeapon.sync_markers(c.model)
	_drive_anims(c)


func _drive_anims(c: WeaponController.WeaponSlot) -> void:
	var ap := c.model.get_meta("ap") as AnimationPlayer
	if ap == null:
		return
	var d := c.data
	var idle := ImportedWeapon.anim_name(d, "idle")
	var shoot := ImportedWeapon.anim_name(d, "shoot")
	var idle_from := float((d.model_params.get("anims", {}) as Dictionary).get("idle_from", 0.0))
	var want := idle
	var speed := 1.0
	var from := -1.0
	var st := int(wc.state)
	var entered := st != _last_state
	_last_state = st
	var restart := false
	var manual := -1.0
	match wc.state:
		WeaponController.State.DRAW:
			want = ImportedWeapon.anim_name(d, "draw")
			speed = ImportedWeapon.anim_length(c.model, d, "draw") / maxf(wc.state_duration, 0.05)
			restart = entered
		WeaponController.State.HOLSTER:
			want = ImportedWeapon.anim_name(d, "holster")
			speed = ImportedWeapon.anim_length(c.model, d, "holster") / maxf(wc.state_duration, 0.05)
			restart = entered
		WeaponController.State.RELOADING:
			# Se maneja a mano (seek): con estrés el tiempo vuelve atrás en el brocal
			want = ImportedWeapon.anim_name(d, wc.imported_anim_key)
			manual = wc.imported_reload_time(c).x
			restart = entered
		WeaponController.State.CLEARING:
			want = ImportedWeapon.anim_name(d, "reload_empty")
			from = float(d.model_params.get("rack_from", 0.0))
			speed = ImportedWeapon.rack_time(c.model, d) / maxf(wc.state_duration, 0.05)
			restart = entered
		_:
			if _shot_new:
				want = shoot
				restart = true
			elif ap.current_animation == shoot and ap.is_playing():
				want = shoot
	_shot_new = false
	var key_now := "%s@%d" % [want, c.model.get_instance_id()]
	if key_now != _anim_key or restart:
		ap.play(want, 0.02 if want == shoot else 0.12)
		ap.seek(from if from >= 0.0 else (idle_from if want == idle else 0.0), true)
		_anim_key = key_now
	ap.speed_scale = speed
	if manual >= 0.0:
		ap.speed_scale = 0.0
		ap.seek(manual, true)
	# La animación quieta no está en bucle: vuelve al principio útil
	if want == idle and ap.current_animation == idle and ap.current_animation_position >= ap.current_animation_length - 0.05:
		ap.seek(idle_from, true)


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
	var imported := c.model.has_meta("imported")
	var pos := Vector3.ZERO
	if imported:
		# Modelo importado: su animación manda; la pose de cadera/apuntado va en el
		# modelo y acá solo se suman balanceo, retroceso y estrés
		_pose_imported(c, a)
	else:
		var sight := (c.model.get_node("Sight") as Node3D).position
		var hip: Vector3 = HIP_POSE.get(w.model, Vector3(0.13, -0.14, -0.26))
		if w.model_params.has("hip"):
			hip = GlbWeapon._v(w.model_params["hip"])  # armas .glb muy chicas o grandes
		var ads := Vector3(-sight.x, -sight.y, -wc.eye_relief_for(c) - sight.z)
		pos = hip.lerp(ads, a)
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

	# Arma baja (usando un consumible)
	var lt := smooth(wc.lower_amount)
	if lt > 0.0:
		pos.y -= 0.3 * lt
		rot.x -= deg_to_rad(42) * lt
	# Animaciones de estado
	_reload_roll = 0.0
	var vis_state: int = -1 if imported else int(wc.state)
	match vis_state:
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
				"cylinder":
					# Revólver: arriba y girado, para ver el tambor afuera a la izquierda
					rp = Vector3(-0.07, 0.1, 0.06)
					rr = Vector3(22.0, 6.0, -34.0)
					if wc.state == WeaponController.State.RELOADING:
						# Al expulsar las vainas, la boca apunta arriba
						var tb := wc.break_time(t).x
						var up := smooth(clampf((tb - 0.17) / 0.06, 0.0, 1.0)) * (1.0 - smooth(clampf((tb - 0.31) / 0.06, 0.0, 1.0)))
						rr += Vector3(38.0, 0.0, 10.0) * up
						rp += Vector3(0.0, 0.03, 0.0) * up
				_:
					if w.model == "pistol" and wc.state == WeaponController.State.CLEARING:
						# Montar la pistola: más lejos y de costado, para ver la corredera
						rp = Vector3(-0.05, 0.07, -0.03)
						rr = Vector3(12.0, -18.0, -22.0)
					elif w.model == "pistol":
						rp = Vector3(-0.1, 0.12, 0.1)
						rr = Vector3(24.0, -8.0, -30.0)
			var side_mag := c.model.get_node_or_null("Mag")
			if w.reload_type == "magazine" and side_mag != null and float(side_mag.get_meta("roll", 0.0)) < -45.0:
				# Cargador al costado izquierdo: el arma no se gira (si no, el cargador sale para arriba)
				rp = Vector3(-0.03, 0.06, 0.03)
				rr = Vector3(12.0, -8.0, 6.0)
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
				var per := 0.7 / maxf(float(1 if wc._clip_load else wc._rounds_planned), 1.0)
				var k := fmod(t, maxf(per, 0.01)) / maxf(per, 0.01)
				pos.y -= sin(k * PI) * 0.006 * inn
		WeaponController.State.CYCLING:
			# Accionar el cerrojo: el arma baja apenas y gira hacia la mano
			var t := clampf(wc.state_time / wc.state_duration, 0.0, 1.0)
			var b := sin(t * PI)
			# Casi nada si se acciona sin dejar de mirar por el visor
			rot.z += deg_to_rad(lerpf(8.0, 1.2, a)) * b
			pos.y -= 0.01 * b * (1.0 - a * 0.85)

	# Estrés: temblor de las manos (más fuerte manipulando el arma). Apuntando con visor,
	# aguantar la respiración lo calma (no en estrés extremo)
	var hold := wc.breath_sway_factor() if w.sight == "scope" else 1.0
	var tremor_rot := Vector3.ZERO
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
		var steady := lerpf(1.0, hold, a)
		pos += dp.limit_length(0.007 if busy_now else 0.014) * steady
		tremor_rot = dr.limit_length(deg_to_rad(1.6 if busy_now else 3.2)) * steady
		rot += tremor_rot
	# Respiración con visor: el rifle se mece lento (y la retícula con él)
	var breath := Vector3.ZERO
	if w.sight == "scope" and a > 0.01:
		var b_amp := deg_to_rad(0.085) * hold * (0.6 if wc.player.stance == Player.Stance.CROUCHING else 1.0)
		b_amp *= 1.0 + st * 1.2 + wc.player.stress.extreme * 1.5
		b_amp *= 1.0 + clampf(Vector2(wc.player.velocity.x, wc.player.velocity.z).length() / 3.0, 0.0, 1.5)
		breath = Vector3(sin(_time * 1.38) + sin(_time * 2.9 + 0.7) * 0.25,
			sin(_time * 0.69 + 0.5) * 0.6 + sin(_time * 2.3) * 0.2, 0.0) * b_amp * a
		rot += breath
	aim_rot = breath + tremor_rot * a
	rig.position = pos
	rig.rotation = rot
	if not imported:
		_animate_parts(c, delta)
	if arms != null:
		arms.visible = arms.ok and not imported
		if arms.visible:
			arms.update(c.model, delta)

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
			var bt := wc.break_time(t)
			var tb := bt.x
			var p := path(tb, [[0.0, z], [0.08, z], [0.13, Vector3(0, -0.014, 0.004)], [0.19, Vector3(0, 0.004, 0)], [0.24, z],
				[0.56, z], [0.6, Vector3(0, 0.002, -0.006)], [0.66, z], [0.8, z], [0.86, Vector3(0, 0.012, 0)],
				[0.91, Vector3(0, -0.004, 0)], [1.0, z]])
			var r := path(tb, [[0.0, z], [0.08, z], [0.13, Vector3(-6, 0, 1)], [0.19, Vector3(1, 0, 0)], [0.24, z], [0.56, z],
				[0.6, Vector3(-2, 0, 0)], [0.66, z], [0.8, z], [0.86, Vector3(7, 0, -1)], [0.91, Vector3(-2, 0, 0)], [1.0, z]])
			if bt.y >= 0.0:
				# Los cartuchos pegan en el borde de la recámara: pequeño golpe
				var k := fmod(bt.y, 1.0)
				var hit := exp(-pow((k - 0.4) / 0.08, 2.0))
				p += Vector3(0, -0.003, 0.002) * hit
				r += Vector3(-1.2, 0, 0.6) * hit
			return [p, r]
		"magazine":
			if wc._plan != null:
				return [path(t, wc._plan.bump_p), path(t, wc._plan.bump_r)]
		"cylinder":
			if wc.state != WeaponController.State.RELOADING:
				return [z, z]
			# Golpe seco al abrir y al cerrar el tambor
			var tb2 := wc.break_time(t).x
			var p2 := path(tb2, [[0.0, z], [0.1, z], [0.13, Vector3(-0.004, 0.0, 0.0)], [0.17, z], [0.64, z],
				[0.69, Vector3(0.006, 0.004, 0.0)], [0.74, z], [1.0, z]])
			var r2 := path(tb2, [[0.0, z], [0.1, z], [0.13, Vector3(0, 0, 3)], [0.17, z], [0.64, z],
				[0.69, Vector3(-2, 0, -5)], [0.74, z], [1.0, z]])
			return [p2, r2]
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
			var per := 0.7 / maxf(float(1 if wc._clip_load else wc._rounds_planned), 1.0)
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
	if m.has_node("Crane"):
		_animate_cylinder(m, t if wc.state == WeaponController.State.RELOADING else -1.0)


## Revólver: el tambor sale a la izquierda con la grúa, la varilla expulsa las vainas,
## la mano trae los cartuchos nuevos todos juntos (como un cargador rápido) y lo
## cierra. Con estrés los cartuchos pegan en el borde de las recámaras y reintenta.
## Tiempo del quiebre normal: abre 0.10-0.18, expulsa 0.20-0.30, cartuchos 0.42-0.56,
## cierra 0.64-0.70.
func _animate_cylinder(m: Node3D, t_real: float) -> void:
	var crane := m.get_node("Crane") as Node3D
	var rounds := m.get_node_or_null("Rounds") as Node3D
	var r := t_real >= 0.0
	var bt := wc.break_time(t_real) if r else Vector2(-1.0, -1.0)
	var t := bt.x
	var open := 0.0
	var dz := 0.0
	var show := true
	if r:
		open = smooth(clampf((t - 0.1) / 0.08, 0.0, 1.0)) * (1.0 - smooth(clampf((t - 0.64) / 0.06, 0.0, 1.0)))
		if t < 0.3:
			dz = 0.075 * smooth(clampf((t - 0.2) / 0.08, 0.0, 1.0))
		elif t < 0.42:
			show = false
		elif t < 0.56:
			dz = 0.09 * (1.0 - smooth(clampf((t - 0.42) / 0.12, 0.0, 1.0)))
			if bt.y >= 0.0:
				# Intento fallido: pegan en el borde, se traban y vuelven
				var k := fmod(bt.y, 1.0)
				dz = 0.012 + 0.02 * sin(k * PI)
	# La grúa gira sobre su eje (paralelo al caño) hacia la izquierda
	var basis := Basis(Vector3.BACK, deg_to_rad(82.0) * open)
	crane.transform = Transform3D(basis, part_base[crane])
	if rounds != null:
		rounds.transform = Transform3D(basis, part_base[rounds]) * Transform3D(Basis.IDENTITY, Vector3(0, 0, dz))
		rounds.visible = show
	# La mano izquierda va a los cartuchos (trae los nuevos y los empuja)
	var hl := m.get_node_or_null("HandL") as Node3D
	if hl != null and part_base.has(hl) and r:
		var palm: Vector3 = hl.get_meta("palm", Vector3.ZERO)
		# Cara trasera del tambor, en el espacio de la grúa (su eje queda abajo a la izquierda)
		var rear_local := Vector3(0.012, 0.021, 0.06 + dz + 0.02)
		var at := Transform3D(basis, part_base[crane]) * rear_local + Vector3(-0.015, -0.035, 0.02)
		var w := smooth(clampf((t - 0.32) / 0.1, 0.0, 1.0)) * (1.0 - smooth(clampf((t - 0.6) / 0.1, 0.0, 1.0)))
		var away := Vector3(-0.06, -0.25, 0.08) * (smooth(clampf((t - 0.28) / 0.06, 0.0, 1.0)) * (1.0 - smooth(clampf((t - 0.4) / 0.04, 0.0, 1.0))))
		hl.position = part_base[hl] + (at - palm) * w + away


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
func _animate_break(br: Node3D, t_real: float) -> void:
	var r := t_real >= 0.0
	# Con estrés, la recarga se estira en los intentos fallidos: "t" es el tiempo del
	# quiebre normal y "fumble" la fase del intento (−1 si no hay)
	var bt := wc.break_time(t_real) if r else Vector2(-1.0, -1.0)
	var t := bt.x
	var fumble := bt.y
	var open := 0.0
	if r:
		# Quiebre rápido (seco) y cierre de golpe
		open = smooth(clampf((t - 0.08) / 0.1, 0.0, 1.0)) * (1.0 - smooth(clampf((t - 0.82) / 0.07, 0.0, 1.0)))
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
		if r and fumble >= 0.0:
			# Intento fallido: los cartuchos pegan en el borde, se traban y vuelven atrás
			var k := fmod(fumble, 1.0)
			var miss := br.basis * Vector3(0.006 if int(fumble) % 2 == 0 else -0.005, -0.004, -0.012)
			o = behind + path(k, [[0.0, z], [0.4, miss], [0.55, miss + br.basis * Vector3(0.002, 0.0, 0.003)],
				[0.85, br.basis * Vector3(-0.004, 0.006, 0.02)], [1.0, z]])
		# Estrés: el pulso de la mano que carga
		var st := wc.player.stress.value
		if r and st > 0.001:
			var tr3 := wc.player.stress.tremor_base()
			o += Vector3(tr3.x, tr3.y, tr3.z * 0.5) * 0.004 * st
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
			var ex := 0.03 * smooth(clampf((t - 0.09) / 0.06, 0.0, 1.0))
			var k := clampf((t - 0.16) / 0.06, 0.0, 1.0)
			var fly := inv * (Vector3((i * 2.0 - 1.0) * 0.015, 0.2, 0.025) * k)
			sh.visible = t > 0.08 and t < 0.22
			sh.position = base + seat + Vector3(0, 0, ex) + fly
			sh.rotation = Vector3(-deg_to_rad(90.0) * k, 0, 0)
		elif not spent:
			# Cartucho sin disparar: queda en la recámara (se ve con los caños abiertos)
			sh.visible = t > 0.08 and t < 0.9
			sh.position = base + seat
		else:
			sh.visible = t >= 0.34 and t < 0.9
			# Los cartuchos viajan en la mano hasta que entran; después quedan en la recámara
			sh.position = base + (load_off if (t < 0.6 and loader != null) else seat)


func _update_flash(c: WeaponController.WeaponSlot, delta: float) -> void:
	if flash_time > 0.0:
		flash_time -= delta
		var muzzle := c.model.get_node("Muzzle") as Node3D
		if _flash_shot.is_empty():
			flash()
		var big := 1.6 if c.data.reload_type == "break" else (0.75 if c.data.model == "pistol" else 1.0)
		var life := clampf(flash_time / 0.045, 0.0, 1.0)  # se achica en los 2-3 cuadros que dura
		var mat := _flash_mats[int(_flash_shot[0])]
		mat.albedo_color = _flash_shot[5]
		_flash.material_override = mat
		_flash.visible = true
		var fwd0 := -muzzle.global_basis.z.normalized()
		# Un poco por delante de la boca, para que el arma no lo tape
		_flash.global_position = muzzle.global_position + fwd0 * 0.025
		var sc := float(_flash_shot[1]) * big * lerpf(0.7, 1.0, life) * _rng.randf_range(0.92, 1.08)
		_flash.scale = Vector3(sc, sc, sc)
		# Llama hacia adelante (dos planos cruzados a lo largo del caño), de largo variable
		var ln := float(_flash_shot[2])
		_flame.visible = ln > 0.05
		if _flame.visible:
			_flame_mat.albedo_color = _flash_shot[5]
			var fwd := -muzzle.global_basis.z.normalized()
			var b := Basis.looking_at(fwd, Vector3.UP if absf(fwd.y) < 0.95 else Vector3.BACK)
			b = b * Basis(Vector3.BACK, float(_flash_shot[4]))
			var wdt := 0.075 * float(_flash_shot[3]) * big
			_flame.global_transform = Transform3D(b.scaled_local(Vector3(wdt, wdt, lerpf(0.1, 0.3, ln) * big * lerpf(0.75, 1.0, life))),
				muzzle.global_position)
	else:
		_flash.visible = false
		if _flame != null:
			_flame.visible = false
		_flash_shot = []


## Copia la dirección del sol del mundo a la luz del arma (en espacio de cámara).
func _sync_light() -> void:
	var sun := get_tree().get_first_node_in_group("sun") as DirectionalLight3D
	if sun == null:
		return
	_vm_light.basis = wc.player.camera.global_basis.inverse() * sun.global_basis
	_vm_light.light_color = sun.light_color
	_vm_light.light_energy = sun.light_energy * 0.9











func _remember_parts(model: Node3D) -> void:
	for path: String in ["Mag", "Charging", "Slide", "Bolt", "Crane", "Rounds", "Barrels/ShellL", "Barrels/ShellR", "Barrels/HandL", "Barrels/Loader",
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
	arms = SkinnedArms.new()
	arms.name = "SkinnedArms"
	vm_viewport.add_child(arms)

	_flash = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.2, 0.2)
	_flash.mesh = q
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fm.billboard_keep_scale = true
	fm.albedo_color = Color(1.0, 0.75, 0.45)
	for i in 6:
		var m := fm.duplicate() as StandardMaterial3D
		m.albedo_texture = _make_flash_texture(i)
		_flash_mats.append(m)
	_flash.material_override = _flash_mats[0]
	_flash.visible = false
	vm_viewport.add_child(_flash)
	# Llama: dos planos cruzados a lo largo del eje (−Z), de la boca hacia adelante
	_flame = MeshInstance3D.new()
	_flame.mesh = _make_flame_mesh()
	_flame_mat = StandardMaterial3D.new()
	_flame_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flame_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flame_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_flame_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_flame_mat.albedo_texture = _make_flame_texture()
	_flame.material_override = _flame_mat
	_flame.visible = false
	vm_viewport.add_child(_flame)



## Estrella de destello generada por código, con otra forma por variante (cantidad,
## largo y ancho de las puntas, núcleo irregular). TODO-ASSET: vfx_muzzle_flash
static func _make_flash_texture(seed_i: int = 0) -> ImageTexture:
	var n := 96
	var r := RandomNumberGenerator.new()
	r.seed = 7919 * (seed_i + 1)
	var rays := r.randi_range(4, 7)
	var off := r.randf() * TAU
	var lens: Array[float] = []
	var widths: Array[float] = []
	for k in rays:
		lens.append(r.randf_range(0.55, 1.0))
		widths.append(r.randf_range(0.12, 0.3))
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := Vector2(n, n) * 0.5
	for y in n:
		for x in n:
			var v := Vector2(x, y) - c
			var d := v.length() / (n * 0.5)
			var ang := atan2(v.y, v.x)
			var a := 0.0
			for k in rays:
				var ra := off + TAU * float(k) / rays + sin(float(k) * 2.3) * 0.25
				var da := absf(wrapf(ang - ra, -PI, PI))
				var wk := widths[k] * (1.0 - d / lens[k])
				if wk > 0.0 and da < wk:
					a = maxf(a, (1.0 - da / wk) * (1.0 - d / lens[k]) * 1.3)
			# Núcleo con borde irregular
			var core_r := 0.32 + 0.06 * sin(ang * 5.0 + off) + 0.04 * sin(ang * 9.0 - off)
			a = maxf(a, clampf((core_r - d) / core_r * 1.8, 0.0, 1.0))
			img.set_pixel(x, y, Color(1, 1, 1, clampf(a, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)


## Textura de la llama: base ancha y brillante en la boca, se afina y se apaga hacia la
## punta, con lenguas irregulares.
static func _make_flame_texture() -> ImageTexture:
	var w := 32
	var h := 96
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var u := float(y) / (h - 1)  # 0 en la boca, 1 en la punta
		var half := (1.0 - u) * (0.55 + 0.15 * sin(u * 17.0)) + 0.05
		for x in w:
			var vx := absf(float(x) / (w - 1) * 2.0 - 1.0)
			var a := clampf((half - vx) / maxf(half, 0.01), 0.0, 1.0) * pow(1.0 - u, 1.3)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)


## Dos planos cruzados de 1×1 a lo largo de −Z (de 0 a −1), centrados en el eje.
static func _make_flame_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for plane in 2:
		var side := Vector3(0.5, 0, 0) if plane == 0 else Vector3(0, 0.5, 0)
		var p0 := -side
		var p1 := side
		var p2 := side + Vector3(0, 0, -1)
		var p3 := -side + Vector3(0, 0, -1)
		for tri: Array in [[p0, p1, p2, Vector2(0, 0), Vector2(1, 0), Vector2(1, 1)], [p0, p2, p3, Vector2(0, 0), Vector2(1, 1), Vector2(0, 1)]]:
			for k in 3:
				st.set_uv(tri[3 + k])
				st.add_vertex(tri[k])
	return st.commit()
