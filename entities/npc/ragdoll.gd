class_name Ragdoll
extends Node3D
## Muñeco físico ("ragdoll") de un personaje muerto: una cápsula rígida por parte
## del cuerpo (cadera, columna, pecho, cabeza, brazos, antebrazos, muslos y
## piernas), unidas con articulaciones con límites (las rodillas y los codos doblan
## solo para su lado; hombros, cadera y cuello como rótulas con tope). Arranca en la
## pose en que estaba el personaje, con su velocidad y el empujón del tiro; cada
## cuadro copia las cápsulas a los huesos del modelo. Cuando queda quieto se
## congela (no gasta nada) hasta que algo lo vuelva a empujar.
##
## Las cápsulas van en su propia capa: chocan con el mundo pero no con el jugador,
## los otros personajes ni entre ellas (no se traban); las balas no las tocan (los
## cuerpos de impacto siguen a los huesos).

## Capa 12: solo partes de cuerpos muertos (y armas caídas).
const LAYER := 12
## [hueso, hueso donde termina, radio (m), masa (kg), padre, tipo de articulación]
const PARTS := [
	["Hips", "Spine", 0.13, 12.0, "", ""],
	["Spine", "Spine2", 0.12, 9.0, "Hips", "spine"],
	["Spine2", "Neck", 0.14, 13.0, "Spine", "spine"],
	["Head", "HeadTop_End", 0.1, 5.0, "Spine2", "neck"],
	["LeftArm", "LeftForeArm", 0.05, 2.4, "Spine2", "shoulder"],
	["LeftForeArm", "LeftHand", 0.043, 1.8, "LeftArm", "elbow"],
	["RightArm", "RightForeArm", 0.05, 2.4, "Spine2", "shoulder"],
	["RightForeArm", "RightHand", 0.043, 1.8, "RightArm", "elbow"],
	["LeftUpLeg", "LeftLeg", 0.075, 8.0, "Hips", "hip"],
	["LeftLeg", "LeftFoot", 0.055, 4.5, "LeftUpLeg", "knee"],
	["RightUpLeg", "RightLeg", 0.075, 8.0, "Hips", "hip"],
	["RightLeg", "RightFoot", 0.055, 4.5, "RightUpLeg", "knee"],
]
## Cuánto tiene que estar quieto (s) para congelarse, y el máximo que simula.
const SETTLE_TIME := 1.2
const MAX_TIME := 12.0

var body: NpcBody
## hueso -> RigidBody3D
var parts: Dictionary = {}
## hueso -> transformación del hueso respecto de su cápsula
var _offset: Dictionary = {}
## Pose local de cada hueso al morir (los que no tienen cápsula la conservan).
var _local_at_death: Array[Transform3D] = []
var _t: float = 0.0
var _still: float = 0.0
var frozen: bool = false
## Bisagras (rodillas y codos): [padre, parte, eje en el espacio del padre] para medirlas.
var hinges: Array = []
## Agonía: segundos que le quedan revolcándose (0 = quieto/muerto del todo).
var agony_left: float = 0.0
var agony_total: float = 0.0
var _twitch_t: float = 0.0
var _blood_t: float = 0.0
var _last_blood := Vector3.INF
var _rng := RandomNumberGenerator.new()


## Herido de muerte (no en la cabeza): se retuerce cada vez menos hasta quedar quieto.
func start_agony(seconds: float) -> void:
	agony_total = seconds
	agony_left = seconds
	# Mientras se mueve, brazos y piernas frenados (que no se sacudan como trapos)
	for b: Variant in parts:
		var rb := parts[b] as RigidBody3D
		rb.angular_damp = 4.0
		rb.linear_damp = 0.6
	_twitch_t = _rng.randf_range(0.6, 1.2)
	if frozen:
		_unfreeze()


func end_agony() -> void:
	agony_left = 0.0


func is_agonizing() -> bool:
	return agony_left > 0.0


## Un movimiento de dolor: encoge una pierna, se agarra (brazo al pecho), se gira a
## medias o levanta la cabeza. Cada vez más débil.
func _twitch(k: float) -> void:
	var hips := parts.get(body.bone("Hips")) as RigidBody3D
	var chest := parts.get(body.bone("Spine2")) as RigidBody3D
	if hips == null or chest == null:
		return
	var up := Vector3.UP
	var along := (chest.global_position - hips.global_position).normalized()
	# Movimientos chicos y que respetan el cuerpo (nada de llevar brazos abajo del
	# tronco ni girarlo entero): con bisagras y conos, poco empuje alcanza
	match _rng.randi() % 4:
		0, 1:
			# Dobla una rodilla (el pie se arrastra hacia la cadera) y la vuelve a estirar
			var side := "Left" if _rng.randf() < 0.5 else "Right"
			var leg := parts.get(body.bone(side + "Leg")) as RigidBody3D
			var thigh := parts.get(body.bone(side + "UpLeg")) as RigidBody3D
			if leg != null and thigh != null:
				var to_hip := (hips.global_position - leg.global_position)
				to_hip.y = 0.0
				leg.apply_central_impulse((to_hip.normalized() * 1.6 + up * 0.8) * k)
				thigh.apply_central_impulse(up * 1.2 * k)
		2:
			# Mueve un brazo: levanta un poco la mano y la deja caer
			var side2 := "Left" if _rng.randf() < 0.5 else "Right"
			var fa := parts.get(body.bone(side2 + "ForeArm")) as RigidBody3D
			if fa != null:
				fa.apply_central_impulse(up * 1.1 * k)
		3:
			# Levanta apenas la cabeza y los hombros, o se ladea un poco
			var head := parts.get(body.bone("Head")) as RigidBody3D
			if head != null:
				head.apply_central_impulse(up * 1.0 * k)
			if _rng.randf() < 0.5:
				chest.apply_central_impulse(up * 2.5 * k)
			else:
				chest.apply_torque_impulse(along * _rng.randf_range(-1.0, 1.0) * 2.0 * k)
	_still = 0.0


## Arma el muñeco con la pose actual del esqueleto. vel: velocidad que traía;
## hit_pos/push: dónde y hacia dónde lo empujó el tiro (impulso en N·s).
static func create(b: NpcBody, vel: Vector3, hit_pos: Vector3, push: Vector3) -> Ragdoll:
	var r := Ragdoll.new()
	r.name = "Ragdoll"
	r.body = b
	# En coordenadas del mundo: las articulaciones y cápsulas no heredan el giro del personaje
	r.top_level = true
	b.add_child(r)
	r.global_transform = Transform3D.IDENTITY
	r._build(vel)
	r.push(hit_pos, push)
	return r


func _build(vel: Vector3) -> void:
	var sk := body.skeleton
	var skx := sk.global_transform
	_local_at_death.resize(sk.get_bone_count())
	for i in sk.get_bone_count():
		_local_at_death[i] = sk.get_bone_pose(i)
	var right := body.global_basis.x.normalized()
	for pd: Array in PARTS:
		var bn := String(pd[0])
		var b := body.bone(bn)
		if b < 0 or parts.has(b):
			continue
		var bw := _ortho(skx * sk.get_bone_global_pose(b))
		var p0 := bw.origin
		var e := body.bone(String(pd[1]))
		var p1: Vector3
		if e >= 0 and e != b:
			p1 = (skx * sk.get_bone_global_pose(e)).origin
		else:
			# Sin hueso de punta (cabeza): para arriba lo que mide una cabeza
			p1 = p0 + bw.basis.y * 0.2
		var axis := p1 - p0
		var length := axis.length()
		if length < 0.02:
			continue
		var y := axis / length
		var x := y.cross(right)
		if x.length() < 0.1:
			x = y.cross(body.global_basis.z)
		x = x.normalized()
		var xf := Transform3D(Basis(x, y, x.cross(y)).orthonormalized(), (p0 + p1) * 0.5)
		var rb := RigidBody3D.new()
		rb.name = "Part_" + bn
		rb.top_level = true
		rb.collision_layer = 1 << (LAYER - 1)
		rb.collision_mask = 1
		rb.mass = float(pd[3])
		rb.linear_damp = 0.1
		rb.angular_damp = 1.2
		rb.continuous_cd = true
		rb.can_sleep = true
		rb.set_meta("surface", "flesh")
		rb.set_meta("zone_owner", body.get_parent())
		var mat := PhysicsMaterial.new()
		mat.friction = 0.9
		mat.bounce = 0.0
		rb.physics_material_override = mat
		var cs := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		var rad := float(pd[2])
		cap.radius = rad
		cap.height = maxf(length + rad * (0.6 if bn == "Head" else 0.2), rad * 2.0 + 0.01)
		cs.shape = cap
		rb.add_child(cs)
		add_child(rb)
		rb.global_transform = xf
		rb.reset_physics_interpolation()
		rb.linear_velocity = vel
		parts[b] = rb
		_offset[b] = xf.affine_inverse() * bw
	for pd: Array in PARTS:
		var b := body.bone(String(pd[0]))
		var pb := body.bone(String(pd[4]))
		if not parts.has(b) or not parts.has(pb) or b == pb:
			continue
		_joint(parts[pb], parts[b], String(pd[5]), (skx * sk.get_bone_global_pose(b)).origin, right)


## Articulación entre el padre (a) y la parte (b) en el punto "at".
func _joint(a: RigidBody3D, b: RigidBody3D, kind: String, at: Vector3, right: Vector3) -> void:
	var dir := (b.global_position - at).normalized()
	var j: Joint3D
	if kind == "knee" or kind == "elbow":
		# Bisagra: gira alrededor del eje que dobla la articulación desde la pose actual
		var up_dir := (at - a.global_position).normalized()
		var hinge := up_dir.cross(dir)
		var bend := up_dir.angle_to(dir)
		if bend < 0.15:
			# Casi derecha: la rodilla dobla hacia atrás; el codo hacia adelante (o hacia
			# arriba si el brazo ya apunta adelante)
			if kind == "knee":
				hinge = -right
			else:
				var fwd := -body.global_basis.z.normalized()
				hinge = up_dir.cross(fwd)
				if hinge.length() < 0.3:
					hinge = up_dir.cross(Vector3.UP)
			bend = 0.05
		hinge = hinge.normalized()
		var h := HingeJoint3D.new()
		# Base de mano derecha (x × y = z): Z es el eje de la bisagra
		var hx := dir.cross(hinge).normalized()
		hinge = hx.cross(dir).normalized()
		h.transform = Transform3D(Basis(hx, dir, hinge), at)
		h.set_flag(HingeJoint3D.FLAG_USE_LIMIT, true)
		var max_bend := 2.5 if kind == "knee" else 2.6
		# Ángulo 0 = la pose de ahora: puede estirarse hasta derecha y doblarse hasta el
		# tope. Ojo: el ángulo del límite es el de A respecto de B (medido: girar B en
		# +Z cuenta negativo), así que el rango va invertido.
		h.set_param(HingeJoint3D.PARAM_LIMIT_LOWER, -maxf(max_bend - bend, 0.05))
		h.set_param(HingeJoint3D.PARAM_LIMIT_UPPER, bend)
		hinges.append([a, b, a.global_basis.inverse() * hinge, kind])
		j = h
	else:
		var c := ConeTwistJoint3D.new()
		var tx := dir
		var ty := tx.cross(right)
		if ty.length() < 0.1:
			ty = tx.cross(Vector3.FORWARD)
		ty = ty.normalized()
		c.transform = Transform3D(Basis(tx, ty, tx.cross(ty)).orthonormalized(), at)
		# Conos chicos: el cuerpo caído mantiene una forma de cuerpo (brazos al costado
		# y no cruzados abajo, piernas que no se cruzan del todo)
		var spans := {"spine": [0.25, 0.18], "neck": [0.5, 0.45], "shoulder": [0.95, 0.45], "hip": [0.7, 0.2]}
		var sp: Array = spans.get(kind, [0.5, 0.3])
		c.set_param(ConeTwistJoint3D.PARAM_SWING_SPAN, float(sp[0]))
		c.set_param(ConeTwistJoint3D.PARAM_TWIST_SPAN, float(sp[1]))
		j = c
	j.exclude_nodes_from_collision = true
	add_child(j)
	j.node_a = j.get_path_to(a)
	j.node_b = j.get_path_to(b)


static func _ortho(t: Transform3D) -> Transform3D:
	return Transform3D(t.basis.orthonormalized(), t.origin)


## Empujón (un tiro, una explosión): a la parte más cercana a "at".
func push(at: Vector3, impulse: Vector3) -> void:
	if impulse.length() < 0.001 or parts.is_empty():
		return
	var best: RigidBody3D = null
	var bd := INF
	for b: int in parts:
		var rb := parts[b] as RigidBody3D
		var d := rb.global_position.distance_squared_to(at) if at != Vector3.INF else 0.0
		if d < bd:
			bd = d
			best = rb
	if frozen:
		_unfreeze()
	best.apply_impulse(impulse, (at - best.global_position) if at != Vector3.INF else Vector3.ZERO)
	_still = 0.0


func _unfreeze() -> void:
	frozen = false
	_t = MAX_TIME - 4.0
	for b: int in parts:
		(parts[b] as RigidBody3D).freeze = false


func _physics_process(delta: float) -> void:
	if frozen or parts.is_empty():
		return
	_t += delta
	if agony_left > 0.0:
		agony_left -= delta
		# Se revuelca: va dejando manchas irregulares donde se mueve
		_blood_t -= delta
		var hips := parts.get(body.bone("Hips")) as RigidBody3D
		if _blood_t <= 0.0 and hips != null:
			_blood_t = _rng.randf_range(0.5, 1.1)
			if hips.global_position.distance_to(_last_blood) > 0.15:
				_last_blood = hips.global_position
				Blood.stain(body, hips.global_position + Vector3(_rng.randf_range(-0.25, 0.25), 0, _rng.randf_range(-0.25, 0.25)), _rng.randf_range(0.25, 0.6))
		_t = minf(_t, MAX_TIME - 3.0)  # no se congela mientras se mueve
		_twitch_t -= delta
		var k := clampf(agony_left / maxf(agony_total, 0.1), 0.0, 1.0)
		if _twitch_t <= 0.0:
			# Al principio seguido y fuerte; al final, de vez en cuando y apenas
			_twitch_t = lerpf(3.2, 0.7, k) * _rng.randf_range(0.6, 1.4)
			_twitch(0.35 + k * 0.65)
		return
	var moving := false
	for b: int in parts:
		var rb := parts[b] as RigidBody3D
		if rb.linear_velocity.length() > 0.12 or rb.angular_velocity.length() > 0.5:
			moving = true
			break
	_still = 0.0 if moving else _still + delta
	if (_still > SETTLE_TIME and _t > 1.5) or _t > MAX_TIME:
		frozen = true
		for b: int in parts:
			var rb := parts[b] as RigidBody3D
			rb.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
			rb.freeze = true
		apply_pose()


## Copia las cápsulas a los huesos (los huesos sin cápsula conservan su pose local).
func apply_pose() -> void:
	var sk := body.skeleton
	if sk == null:
		return
	var inv := sk.global_transform.affine_inverse()
	var order := body.bone_order()
	var g: Array[Transform3D] = []
	g.resize(sk.get_bone_count())
	for b in order:
		var p := sk.get_bone_parent(b)
		if parts.has(b):
			var rb := parts[b] as RigidBody3D
			var w := rb.get_global_transform_interpolated() * (_offset[b] as Transform3D)
			var t := inv * w
			g[b] = Transform3D(t.basis.orthonormalized(), t.origin)
		elif p < 0:
			g[b] = _local_at_death[b]
		else:
			g[b] = g[p] * _local_at_death[b]
	var hips := body.bone("Hips")
	for b in order:
		var p := sk.get_bone_parent(b)
		var local := g[b] if p < 0 else g[p].affine_inverse() * g[b]
		sk.set_bone_pose_rotation(b, local.basis.get_rotation_quaternion())
		if b == hips or p < 0:
			sk.set_bone_pose_position(b, local.origin)


## Dónde quedó el cuerpo (la cadera), para la brújula y el saqueo.
func center() -> Vector3:
	var h := body.bone("Hips")
	if parts.has(h):
		return (parts[h] as RigidBody3D).global_position
	return body.global_position


## Cuánto está doblada una bisagra (rad, con signo): 0 derecha, positivo doblada para
## su lado, negativo doblada al revés.
func hinge_bend(i: int) -> float:
	var a := hinges[i][0] as RigidBody3D
	var b := hinges[i][1] as RigidBody3D
	var axis := (a.global_basis * (hinges[i][2] as Vector3)).normalized()
	var up_dir := a.global_basis.y
	var dir := b.global_basis.y
	return up_dir.signed_angle_to(dir, axis)
