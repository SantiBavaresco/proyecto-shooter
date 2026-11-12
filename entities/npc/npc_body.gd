class_name NpcBody
extends Node3D
## Cuerpo de un personaje con IA: el modelo .glb (esqueleto Mixamo), los cuerpos de
## impacto por hueso y una pose hecha por código mientras no haya animaciones reales
## (TODO-ASSET: animaciones Mixamo de caminar, correr, agacharse, disparar, recargar
## y morir; ver docs/ASSETS.md).
##
## Pose por código, sobre la pose de reposo del modelo:
##  - piernas con IK de dos huesos: los pies siguen un ciclo de pasos según la
##    velocidad y la dirección (puede caminar de costado o para atrás apuntando);
##  - agachado: baja la cadera y las rodillas se doblan solas por el IK;
##  - columna: se tuerce y se inclina hacia donde apunta (giro y altura);
##  - el arma va al hombro (apuntando) o baja (en guardia), y las manos la agarran
##    con IK (empuñadura y guardamanos del modelo del arma);
##  - al morir: se le aflojan las rodillas, se dobla y cae hacia donde lo empujó el
##    tiro; el arma cae al lado.
##
## Mira hacia −Z (como cualquier nodo de Godot).

const HEIGHT := 1.8
## Capa de los cuerpos de impacto (las balas y la interacción los tocan; nada choca con ellos).
const HITBOX_LAYER := 6
const ZONES := [["head", "head", 0.11], ["neck", "head", 0.06], ["spine", "torso", 0.16], ["hips", "torso", 0.15],
	["upperarm", "limb", 0.055], ["forearm", "limb", 0.045], ["arm", "limb", 0.055],
	["upleg", "limb", 0.08], ["leg", "limb", 0.06]]

@export var scene_path: String = ""

## --- Lo que pide la IA (se lee cada cuadro) ---
## Velocidad en coordenadas del personaje (m/s; −Z adelante).
var local_velocity: Vector3 = Vector3.ZERO
## 0 parado, 1 agachado.
var crouch: float = 0.0
## Giro de la parte de arriba respecto de las piernas (rad) y altura de la mira (rad).
var aim_yaw: float = 0.0
var aim_pitch: float = 0.0
## 1 = arma al hombro apuntando; 0 = baja, en guardia.
var raise: float = 0.0
## Recargando (baja un poco el arma y la mano izquierda va al cargador).
var reloading: bool = false
var is_pistol: bool = false

var skeleton: Skeleton3D
var weapon_node: Node3D
var hitboxes: Array[StaticBody3D] = []
var dead: bool = false

var _model: Node3D
var _rest_local: Array[Transform3D] = []
var _rest_global: Array[Transform3D] = []
var _order: PackedInt32Array = []
var _parent: PackedInt32Array = []
var _bones: Dictionary = {}
var _phase: float = 0.0
var _stride_amp: float = 0.0
var _hand_r := Transform3D.IDENTITY
var _hand_l := Transform3D.IDENTITY
var _stock_z: float = 0.25
## Muerte: tiempo, dirección de caída (en coordenadas del personaje) y giro final.
var _death_t: float = -1.0
var _fall_dir: Vector3 = Vector3.BACK
var _fall_node: Node3D
var _dropped_weapon: Node3D
## Muñeco físico al morir (null si murió "instantáneo", al cargar una partida).
var ragdoll: Ragdoll
## Fuerza del tiro que lo mata (N·s por cada 1 de dirección).
const DEATH_PUSH := 28.0
var _sk_scale: float = 1.0
var _crouch_s: float = 0.0
var _raise_s: float = 0.0
## Suavizados (lo que pide la IA cambia de golpe; el cuerpo lo sigue con inercia).
var _vel_s: Vector3 = Vector3.ZERO
var _accel_s: Vector3 = Vector3.ZERO
var _yaw_s: float = 0.0
var _pitch_s: float = 0.0
var _turn_s: float = 0.0
var _breath: float = 0.0
var _last_world_yaw: float = NAN


func _ready() -> void:
	_fall_node = Node3D.new()
	_fall_node.name = "Fall"
	add_child(_fall_node)
	if scene_path == "" or not ResourceLoader.exists(scene_path):
		return
	var inst := GlbWeapon.scene(scene_path).instantiate() as Node3D
	inst.name = "Model"
	var facing := Node3D.new()
	facing.name = "Facing"
	# Los modelos miran hacia +Z: se dan vuelta para que miren hacia −Z
	facing.rotation = Vector3(0, PI, 0)
	_fall_node.add_child(facing)
	facing.add_child(inst)
	_model = inst
	var ap := inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap != null:
		ap.active = false
	skeleton = inst.find_child("Skeleton3D", true, false) as Skeleton3D
	for mi: MeshInstance3D in inst.find_children("*", "MeshInstance3D", true, false):
		var n := String(mi.name).to_lower() + "/" + String(mi.get_parent().name).to_lower()
		# Fuera: visores nocturnos y lo que no está pegado al esqueleto (el arma que
		# trae el modelo en las manos y cosas sueltas que no seguirían la pose)
		if n.contains("night_vision") or not (mi.get_parent() is Skeleton3D or mi.get_parent() is BoneAttachment3D):
			mi.visible = false
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if skeleton == null:
		return
	skeleton.reset_bone_poses()
	for b in skeleton.get_bone_count():
		if skeleton.get_bone_name(b).to_lower().contains("night_vision"):
			skeleton.set_bone_pose_scale(b, Vector3.ONE * 0.0001)
	_index_bones()
	_scale_model(inst)
	_add_hitboxes()


# --- Esqueleto ------------------------------------------------------------------

## Nombre corto de un hueso Mixamo: "mixamorig_LeftForeArm_24" → "LeftForeArm".
static func short_name(n: String) -> String:
	var s := n.trim_prefix("mixamorig_").trim_prefix("mixamorig:")
	var i := s.rfind("_")
	if i > 0 and s.substr(i + 1).is_valid_int():
		s = s.substr(0, i)
	return s


func bone(n: String) -> int:
	return int(_bones.get(n, -1))


## Huesos de padres a hijos.
func bone_order() -> PackedInt32Array:
	return _order


func _index_bones() -> void:
	var sk := skeleton
	var count := sk.get_bone_count()
	_rest_local.resize(count)
	_rest_global.resize(count)
	_parent.resize(count)
	for b in count:
		_rest_local[b] = sk.get_bone_rest(b)
		_parent[b] = sk.get_bone_parent(b)
		var sn := short_name(sk.get_bone_name(b))
		if not _bones.has(sn):
			_bones[sn] = b
	# Orden de padres a hijos
	var visited := {}
	for b in count:
		_visit(b, visited)
	for b in _order:
		var p := _parent[b]
		_rest_global[b] = _rest_local[b] if p < 0 else _rest_global[p] * _rest_local[b]
	# Columna: sin Spine2 en algunos modelos
	if bone("Spine2") < 0:
		_bones["Spine2"] = bone("Spine1")


func _visit(b: int, visited: Dictionary) -> void:
	if visited.has(b):
		return
	var p := _parent[b]
	if p >= 0:
		_visit(p, visited)
	visited[b] = true
	_order.append(b)


## Escala a la altura de una persona, parado sobre el origen.
func _scale_model(inst: Node3D) -> void:
	var lo := INF
	var hi := -INF
	var xf := _skel_to_model()
	for b in skeleton.get_bone_count():
		var y := (xf * _rest_global[b].origin).y
		lo = minf(lo, y)
		hi = maxf(hi, y)
	if hi - lo < 0.01:
		return
	var h := (hi - lo) * 1.06
	var k := HEIGHT / h
	inst.scale = Vector3.ONE * k
	var hips := xf * _rest_global[bone("Hips")].origin
	inst.position = Vector3(-hips.x * k, -(lo - (hi - lo) * 0.02) * k, -hips.z * k)
	_sk_scale = (skeleton.global_transform.basis.get_scale().x if skeleton.is_inside_tree() else 1.0)


## Transformación del esqueleto respecto del modelo (sin la escala del nodo "Model").
func _skel_to_model() -> Transform3D:
	var xf := Transform3D.IDENTITY
	var n: Node = skeleton
	while n != _model and n != null:
		xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf


## Del espacio de este nodo (el personaje) al del esqueleto, y al revés.
func _to_skel() -> Transform3D:
	return (global_transform.affine_inverse() * skeleton.global_transform).affine_inverse()


func _add_hitboxes() -> void:
	var sk := skeleton
	for b in sk.get_bone_count():
		var nm := short_name(sk.get_bone_name(b)).to_lower()
		if nm.contains("end") or nm.contains("finger") or nm.contains("hand") or nm.contains("toe") \
				or nm.contains("night") or nm.contains("eye") or nm.contains("foot") or nm.contains("shoulder") \
				or nm.contains("root"):
			continue
		var zone := ""
		var rad := 0.05
		for zd: Array in ZONES:
			if nm.contains(String(zd[0])):
				zone = zd[1]
				rad = zd[2]
				break
		if zone == "":
			continue
		var gp := _rest_global[b]
		var tip := gp.origin + gp.basis.y.normalized() * 0.2
		for ch in sk.get_bone_children(b):
			if not sk.get_bone_name(ch).to_lower().contains("night"):
				tip = _rest_global[ch].origin
				break
		var d_local := gp.affine_inverse() * tip
		var length := d_local.length()
		var world_scale := _world_scale()
		var len_m := length * world_scale
		if zone == "head":
			len_m = 0.2
		var att := BoneAttachment3D.new()
		att.bone_name = sk.get_bone_name(b)
		sk.add_child(att)
		var body := StaticBody3D.new()
		body.collision_layer = 1 << (HITBOX_LAYER - 1)
		body.collision_mask = 0
		body.set_meta("hit_zone", zone)
		body.set_meta("zone_owner", get_parent())
		body.set_meta("surface", "flesh")
		att.add_child(body)
		var cs := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = rad
		cap.height = maxf(len_m + rad * 0.5, rad * 2.0 + 0.01)
		cs.shape = cap
		var y := d_local.normalized() if length > 1e-5 else Vector3.UP
		var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
		var bas := Basis(x, y, x.cross(y)).scaled(Vector3.ONE / world_scale)
		var mid := d_local * 0.5
		if zone == "head":
			mid = y * (0.09 / world_scale)
		cs.transform = Transform3D(bas, mid)
		body.add_child(cs)
		hitboxes.append(body)


## Metros por unidad del esqueleto.
func _world_scale() -> float:
	var s := 1.0
	var n: Node = skeleton
	while n != null and n != self:
		if n is Node3D:
			s *= (n as Node3D).scale.x
		n = n.get_parent()
	return maxf(s, 1e-6)


func hitbox_rids() -> Array[RID]:
	var out: Array[RID] = []
	for h in hitboxes:
		out.append(h.get_rid())
	return out


## Posición del centro de la cabeza (mundo).
func head_position() -> Vector3:
	var b := bone("Head")
	if skeleton == null or b < 0:
		return global_position + Vector3(0, 1.62, 0)
	return skeleton.global_transform * (skeleton.get_bone_global_pose(b).origin) + Vector3(0, 0.08, 0)


func eye_position() -> Vector3:
	return head_position() + Vector3(0, 0.02, 0) - global_basis.z * 0.08


func chest_position() -> Vector3:
	var b := bone("Spine2")
	if skeleton == null or b < 0:
		return global_position + Vector3(0, 1.3, 0)
	return skeleton.global_transform * skeleton.get_bone_global_pose(b).origin


## Cabeza con núcleo letal (como el maniquí).
func refine_zone(zone: String, hit_pos: Vector3, dir: Vector3) -> String:
	if zone != "head":
		return zone
	var center := head_position()
	var to_c := center - hit_pos
	var closest := hit_pos + dir * clampf(to_c.dot(dir), 0.0, 0.35)
	return "head_core" if closest.distance_to(center) < 0.065 else "head"


# --- Arma ---------------------------------------------------------------------

## Pone el arma en las manos (modelo por código, sin brazos).
func set_weapon(data: WeaponData, sight := "__fabrica", muzzle := "") -> void:
	if weapon_node != null:
		weapon_node.queue_free()
		weapon_node = null
	if data == null:
		return
	is_pistol = data.slot == 3
	var m := ItemModels.display_weapon(data, sight, muzzle) if String(data.model_params.get("shape", "")) == "imported" \
		else _weapon_model(data, sight, muzzle)
	weapon_node = m
	add_child(m)
	var box := ItemModels.local_aabb(m)
	_stock_z = box.end.z
	# Manos: empuñadura cerca del origen (convención de los modelos) y la otra sobre el
	# guardamanos, a un poco menos de la mitad hacia la boca
	if is_pistol:
		_hand_r = Transform3D(Basis(), Vector3(0, -0.06, 0.035))
		_hand_l = Transform3D(Basis(), Vector3(-0.012, -0.075, 0.025))
	else:
		_hand_r = Transform3D(Basis(), Vector3(0, -0.075, 0.05))
		_hand_l = Transform3D(Basis(), Vector3(0, -0.03, maxf(box.position.z * 0.34, -0.3)))
	for mi: MeshInstance3D in m.find_children("*", "MeshInstance3D", true, false):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


func _weapon_model(data: WeaponData, sight: String, muzzle: String) -> Node3D:
	var sg := WeaponAttach.sight_of(data, {}) if sight == "__fabrica" else sight
	var m := WeaponModelBuilder.build(WeaponAttach.model_data(data, sg))
	WeaponAttach.apply_model(m, data, sg, muzzle)
	for n in ["HandR", "HandL", "HookR", "HookL", "HookP", "Arms", "SkinnedArms"]:
		var h := m.find_child(n, true, false)
		if h != null:
			h.get_parent().remove_child(h)
			h.free()
	var lens := m.get_node_or_null("ScopeLens") as MeshInstance3D
	if lens != null and lens.material_override is ShaderMaterial:
		var mat := (lens.material_override as ShaderMaterial).duplicate() as ShaderMaterial
		mat.set_shader_parameter("active", 0.0)
		lens.material_override = mat
	return m


func muzzle_position() -> Vector3:
	if weapon_node != null:
		var mz := weapon_node.get_node_or_null("Muzzle") as Node3D
		if mz != null:
			return mz.global_position
	return eye_position() - global_basis.z * 0.6


# --- Pose -----------------------------------------------------------------------

## Pose por distancia a la cámara: cerca, cada cuadro; lejos, cada tanto (se nota
## poco y ahorra mucho con muchos enemigos).
var _lod_t: float = 0.0


func _process(delta: float) -> void:
	if skeleton == null:
		return
	if dead:
		if ragdoll != null:
			if not ragdoll.frozen:
				ragdoll.apply_pose()
		else:
			_update_death(delta)
		return
	_lod_t += delta
	var cam := get_viewport().get_camera_3d()
	var interval := 0.0
	if cam != null:
		var d := cam.global_position.distance_to(global_position)
		interval = 0.0 if d < 60.0 else (0.033 if d < 120.0 else (0.1 if d < 200.0 else 0.3))
	if _lod_t >= interval:
		_update_pose(_lod_t)
		_lod_t = 0.0


func _update_pose(delta: float) -> void:
	delta = minf(delta, 0.1)
	var k := func(rate: float) -> float: return 1.0 - exp(-rate * delta)
	# Agacharse y subir el arma con curva (arranca y frena suave)
	_crouch_s = lerpf(_crouch_s, crouch, k.call(5.0))
	_raise_s = lerpf(_raise_s, 0.35 if reloading else raise, k.call(7.0))
	var prev_v := _vel_s
	_vel_s = _vel_s.lerp(local_velocity, k.call(7.0))
	if delta > 0.0:
		_accel_s = _accel_s.lerp((_vel_s - prev_v) / delta, k.call(4.0))
	_yaw_s = lerp_angle(_yaw_s, aim_yaw, k.call(10.0))
	_pitch_s = lerpf(_pitch_s, aim_pitch, k.call(10.0))
	# Giro del cuerpo entero (para inclinarse en las curvas)
	var wy := global_rotation.y
	if not is_nan(_last_world_yaw) and delta > 0.0:
		_turn_s = lerpf(_turn_s, wrapf(wy - _last_world_yaw, -PI, PI) / delta, k.call(5.0))
	_last_world_yaw = wy
	_breath = fmod(_breath + delta * (1.5 + clampf(_vel_s.length() / 3.0, 0.0, 1.0) * 1.5), TAU)
	var speed := Vector2(_vel_s.x, _vel_s.z).length()
	# Pasos: una zancada (dos pasos) cada ~1,4 m caminando
	var stride := lerpf(0.55, 0.36, _crouch_s) * clampf(speed / 1.5, 0.0, 1.6)
	_stride_amp = move_toward(_stride_amp, stride if speed > 0.15 else 0.0, delta * 2.5)
	_phase = fmod(_phase + delta * speed / maxf(lerpf(1.4, 1.0, _crouch_s), 0.1) * PI, TAU)
	_solve(_stride_amp, _phase, Vector2(_vel_s.x, _vel_s.z) / maxf(speed, 0.001), 0.0)


## Arma la pose completa en el espacio del esqueleto y la aplica.
## stride: largo del paso (m); move_dir: dirección del movimiento (x, z locales);
## fold: 0–1 al morir (rodillas que se aflojan y el torso que se dobla).
func _solve(stride: float, phase: float, move_dir: Vector2, fold: float) -> void:
	var sk := skeleton
	var to_sk := _to_skel()
	var from_sk := to_sk.affine_inverse()
	var up := (to_sk.basis * Vector3.UP).normalized()
	var fwd := (to_sk.basis * Vector3.FORWARD).normalized()
	var right := (to_sk.basis * Vector3.RIGHT).normalized()
	var unit := 1.0 / _world_scale()  # unidades del esqueleto por metro
	var g: Array[Transform3D] = []
	g.resize(sk.get_bone_count())
	var hips := bone("Hips")
	var walk := clampf(stride / 0.5, 0.0, 1.0) * (1.0 - fold)
	var bob := absf(sin(phase)) * 0.025 * walk
	var drop := (_crouch_s * 0.42 + fold * 0.5 - bob) * unit
	# Se inclina hacia adelante al acelerar o correr, atrás al frenar
	var acc_lean := clampf(-_accel_s.z * 0.04, -0.12, 0.18) * (1.0 - fold)
	var lean := _crouch_s * 0.35 + fold * 0.6 + clampf(stride - 0.6, 0.0, 0.5) * 0.4 + acc_lean
	# Balanceo de cadera al caminar, inclinación en las curvas y respiración
	var sway := sin(phase) * 0.022 * walk
	var bank := clampf(-_turn_s * Vector2(_vel_s.x, _vel_s.z).length() * 0.035, -0.16, 0.16) * (1.0 - fold)
	var breath := sin(_breath) * 0.012 * (1.0 - fold)
	var spine_names := ["Spine", "Spine1", "Spine2"]
	var n_spine := 0
	for nm: String in spine_names:
		if _bones.has(nm) and (nm != "Spine2" or bone("Spine2") != bone("Spine1")):
			n_spine += 1
	var w := 1.0 / maxf(n_spine, 1)
	# De perfil al apuntar un arma larga (el hombro izquierdo adelante): el torso gira
	# a la derecha y la cabeza compensa
	var blade := -0.5 * _raise_s * (0.0 if is_pistol else 1.0) * (1.0 - fold)
	for b in _order:
		var p := _parent[b]
		var t := _rest_local[b] if p < 0 else g[p] * _rest_local[b]
		if p < 0:
			t = _rest_global[b]
		if b == hips:
			t.origin -= up * drop
			t.origin += right * sway * unit
			t.basis = Basis(fwd, bank + sway * 2.0) * Basis(right, -lean * 0.4) * t.basis
		var sn := short_name(sk.get_bone_name(b))
		var si := spine_names.find(sn)
		if si >= 0:
			var rot := Basis(up, (_yaw_s + blade) * w) * Basis(right, (_pitch_s * w) - lean * 0.2 * (1.0 if si == 0 else 0.5) - breath) \
				* Basis(fwd, -(sway * 2.0 + bank) * w * 0.8)
			t.basis = rot * t.basis
		elif sn == "Neck":
			# La cabeza compensa el balanceo (mirada estable)
			t.basis = Basis(up, -blade * 0.9) * Basis(right, breath * 0.6) * t.basis
		g[b] = t
	# Arma en el espacio del esqueleto
	var wxf := _weapon_transform(g, up, fwd, right, unit, fold)
	if weapon_node != null and not dead:
		weapon_node.transform = global_transform.affine_inverse() * skeleton.global_transform * wxf
	# Piernas: pies en el piso siguiendo el ciclo de pasos
	for side: float in [1.0, -1.0]:
		var sname := "Left" if side > 0.0 else "Right"
		var up_leg := bone(sname + "UpLeg")
		var leg := bone(sname + "Leg")
		var foot := bone(sname + "Foot")
		if up_leg < 0 or leg < 0 or foot < 0:
			continue
		var ph := phase + (0.0 if side > 0.0 else PI)
		var hip_m := from_sk * g[up_leg].origin
		var rest_foot_m := from_sk * (_rest_global[foot].origin)
		var md := Vector3(move_dir.x, 0, move_dir.y)
		var target_m := Vector3(rest_foot_m.x, rest_foot_m.y, rest_foot_m.z)
		target_m.x = lerpf(target_m.x, hip_m.x, 0.2) + side * _crouch_s * 0.05
		target_m += md * (sin(ph) * stride * 0.5)
		target_m.y += maxf(0.0, cos(ph)) * 0.09 * clampf(stride / 0.4, 0.0, 1.0)
		# Agachado: una rodilla adelante, la otra casi en el piso
		if _crouch_s > 0.01 and side < 0.0:
			target_m += Vector3(0, 0, 0.18) * _crouch_s
		elif _crouch_s > 0.01:
			target_m += Vector3(0, 0, -0.12) * _crouch_s
		var pole := (to_sk.basis * (Vector3.FORWARD + Vector3(side * 0.1, 0, 0))).normalized()
		_two_bone(g, up_leg, leg, foot, to_sk * target_m, pole)
		# Pie plano (como en reposo)
		g[foot].basis = _rest_global[foot].basis
		_refresh_children(g, foot)
	# Brazos: las manos al arma
	if weapon_node != null and not dead:
		var hr := wxf * _hand_r
		var hl := wxf * (_hand_l if not reloading else Transform3D(Basis(), Vector3(0, -0.12, -0.12)))
		_arm_ik(g, "Right", hr.origin, up, fwd, right, -1.0)
		_arm_ik(g, "Left", hl.origin, up, fwd, right, 1.0)
	elif fold > 0.0:
		for sname: String in ["Left", "Right"]:
			var arm := bone(sname + "Arm")
			if arm >= 0:
				g[arm].basis = Basis(right, -fold * 0.8) * g[arm].basis
				_refresh_children(g, arm)
	_apply(g)


## Dónde va el arma: al hombro derecho apuntando, o baja en guardia.
func _weapon_transform(g: Array[Transform3D], up: Vector3, fwd: Vector3, right: Vector3, unit: float, fold: float) -> Transform3D:
	var sh := bone("RightArm")
	var sp := bone("Spine2")
	var shoulder := g[sh].origin if sh >= 0 else Vector3.ZERO
	var chest := g[sp].origin if sp >= 0 else shoulder
	var r := _raise_s * (1.0 - fold)
	var yaw_b := Basis(up, _yaw_s)
	var aim_fwd := yaw_b * fwd
	var aim_right := yaw_b * right
	var pitch := lerpf(-0.75, _pitch_s, r)
	var dir := Basis(aim_right, pitch) * aim_fwd
	var w_up := dir.cross(aim_right).normalized() * -1.0
	if w_up.dot(up) < 0.0:
		w_up = -w_up
	var basis := Basis(aim_right, w_up, -dir).orthonormalized()
	var pos: Vector3
	if is_pistol:
		var eye := chest + up * (0.3 * unit)
		pos = eye + dir * (lerpf(0.3, 0.48, r) * unit) - up * (lerpf(0.35, 0.08, r) * unit) - aim_right * (0.02 * unit)
	else:
		# La culata contra el hombro (un poco hacia adentro); en guardia, baja y hacia el centro
		var pocket := shoulder + aim_right * (-0.02 * unit) - aim_right * ((1.0 - r) * 0.08 * unit) + up * ((r * 0.05 - (1.0 - r) * 0.06) * unit) + aim_fwd * (0.04 * unit)
		pos = pocket - basis * Vector3(0, 0, _stock_z * unit * 0.9)
	# El arma acompaña el paso (menos apuntando) y la respiración
	var walk := clampf(_stride_amp / 0.5, 0.0, 1.0) * (1.0 - fold)
	pos += up * ((sin(_phase * 2.0) * 0.012 * walk * (1.0 - r * 0.6) + sin(_breath) * 0.004) * unit)
	pos += aim_right * (sin(_phase) * 0.01 * walk * (1.0 - r * 0.7) * unit)
	return Transform3D(basis.scaled(Vector3.ONE * unit), pos)


func _arm_ik(g: Array[Transform3D], sname: String, target: Vector3, up: Vector3, fwd: Vector3, right: Vector3, side: float) -> void:
	var arm := bone(sname + "Arm")
	var fore := bone(sname + "ForeArm")
	var hand := bone(sname + "Hand")
	if arm < 0 or fore < 0 or hand < 0:
		return
	# Codos abajo y hacia afuera
	var pole := (-up * 1.0 + right * (-side) * 0.6 - fwd * 0.2).normalized()
	_two_bone(g, arm, fore, hand, target, pole)


## IK analítico de dos huesos (a → b → c) hacia `target`, doblando hacia `pole`.
func _two_bone(g: Array[Transform3D], a: int, b: int, c: int, target: Vector3, pole: Vector3) -> void:
	var pa := g[a].origin
	var pb := g[b].origin
	var pc := g[c].origin
	var l1 := pa.distance_to(pb)
	var l2 := pb.distance_to(pc)
	var to_t := target - pa
	var d := clampf(to_t.length(), absf(l1 - l2) + 0.001, (l1 + l2) * 0.999)
	var dir := to_t.normalized() if to_t.length() > 1e-6 else (pc - pa).normalized()
	var ca := clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0)
	var bend := (pole - dir * pole.dot(dir))
	if bend.length() < 1e-5:
		bend = (pb - pa) - dir * (pb - pa).dot(dir)
	bend = bend.normalized()
	var pb2 := pa + (dir * ca + bend * sqrt(1.0 - ca * ca)) * l1
	_rotate_toward(g, a, pb - pa, pb2 - pa)
	_refresh_children(g, a)
	var pc_now := g[c].origin
	_rotate_toward(g, b, pc_now - g[b].origin, (pa + dir * d) - g[b].origin)
	_refresh_children(g, b)


func _rotate_toward(g: Array[Transform3D], b: int, from: Vector3, to: Vector3) -> void:
	if from.length() < 1e-6 or to.length() < 1e-6:
		return
	var q := Quaternion(from.normalized(), to.normalized())
	g[b].basis = Basis(q) * g[b].basis


## Recalcula los hijos de un hueso después de cambiarlo.
func _refresh_children(g: Array[Transform3D], b: int) -> void:
	for ch in skeleton.get_bone_children(b):
		g[ch] = g[b] * _rest_local[ch]
		_refresh_children(g, ch)


func _apply(g: Array[Transform3D]) -> void:
	var sk := skeleton
	for b in _order:
		var p := _parent[b]
		var local := g[b] if p < 0 else g[p].affine_inverse() * g[b]
		sk.set_bone_pose_rotation(b, local.basis.get_rotation_quaternion())
		if b == bone("Hips"):
			sk.set_bone_pose_position(b, local.origin)


# --- Muerte -----------------------------------------------------------------------

## Cae muerto. dir: hacia dónde lo empujó el último tiro (mundo); hit_pos: dónde le
## pegó; vel: la velocidad que traía. Cae como un muñeco físico (ragdoll); "instant"
## (al cargar) lo deja acostado sin simular.
func die(dir: Vector3, instant := false, hit_pos := Vector3.INF, vel := Vector3.ZERO) -> void:
	if dead:
		return
	dead = true
	var d := global_basis.inverse() * dir
	d.y = 0.0
	_fall_dir = d.normalized() if d.length() > 0.05 else Vector3.BACK
	_death_t = 1.6 if instant else 0.0
	for h in hitboxes:
		h.set_meta("dead", true)
	var use_ragdoll := not instant and skeleton != null and bone("Hips") >= 0
	# El arma se suelta y cae
	if weapon_node != null:
		_dropped_weapon = weapon_node
		weapon_node = null
		if use_ragdoll:
			_drop_weapon_physics(dir, vel)
		else:
			var xf := _dropped_weapon.global_transform
			var side := global_basis * Vector3(randf_range(-0.6, 0.6), 0, randf_range(-0.2, 0.6))
			var flat := Basis(Vector3(0, 1, 0), randf() * TAU) * Basis(Vector3(0, 0, 1), PI * 0.5)
			var tw := create_tween()
			_dropped_weapon.global_transform = xf
			var ground := global_position + side + Vector3(0, 0.04, 0)
			tw.tween_property(_dropped_weapon, "global_transform", Transform3D(flat, ground), 0.0 if instant else 0.5) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if use_ragdoll:
		var push := dir.normalized() * DEATH_PUSH if dir.length() > 0.01 else Vector3.ZERO
		var at := hit_pos if hit_pos != Vector3.INF else chest_position()
		ragdoll = Ragdoll.create(self, vel, at, push)
		return
	if instant:
		_update_death(0.0)


## Un tiro o una explosión a un cuerpo ya muerto: lo mueve.
func push(at: Vector3, impulse: Vector3) -> void:
	if ragdoll != null:
		ragdoll.push(at, impulse)


## El arma se suelta de las manos y cae como un objeto físico.
func _drop_weapon_physics(dir: Vector3, vel: Vector3) -> void:
	var w := _dropped_weapon
	var xf := w.global_transform
	var rb := RigidBody3D.new()
	rb.name = "DroppedWeapon"
	rb.top_level = true
	rb.collision_layer = 1 << (Ragdoll.LAYER - 1)
	rb.collision_mask = 1
	rb.mass = 3.5
	rb.angular_damp = 1.0
	rb.continuous_cd = true
	add_child(rb)
	rb.global_transform = Transform3D(xf.basis.orthonormalized(), xf.origin)
	var keep_scale := xf.basis.get_scale()
	w.get_parent().remove_child(w)
	rb.add_child(w)
	w.transform = Transform3D(Basis.from_scale(keep_scale), Vector3.ZERO)
	var box := ItemModels.local_aabb(w)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(maxf(box.size.x * keep_scale.x, 0.04), maxf(box.size.y * keep_scale.y, 0.04),
		maxf(box.size.z * keep_scale.z, 0.1))
	cs.shape = sh
	cs.position = box.get_center() * keep_scale
	rb.add_child(cs)
	rb.reset_physics_interpolation()
	rb.linear_velocity = vel + dir.normalized() * 0.8 + global_basis * Vector3(randf_range(-0.8, 0.8), 0.6, -0.4)
	rb.angular_velocity = Vector3(randf_range(-3, 3), randf_range(-2, 2), randf_range(-3, 3))
	_dropped_weapon = rb


func _update_death(delta: float) -> void:
	if _death_t > 2.0:
		return
	_death_t += delta
	# 0–0,35 s: se le aflojan las rodillas; después cae como un peso muerto
	var fold := smoothstep(0.0, 0.45, _death_t)
	var fall := clampf((_death_t - 0.2) / 0.55, 0.0, 1.0)
	fall = fall * fall
	var axis := Vector3.UP.cross(_fall_dir).normalized()
	if axis.length() < 0.5:
		axis = Vector3.RIGHT
	# Pivote en los pies; acostado queda apoyado sobre la espalda o el pecho (se sube
	# lo que mide de grueso el cuerpo para que no se entierre)
	var ang := fall * PI * 0.5
	_fall_node.transform = Transform3D(Basis(axis, ang), Vector3(0, fall * 0.13, 0) + _fall_dir * (fall * 0.2))
	_crouch_s = 0.0
	_raise_s = 0.0
	_solve(0.0, 0.0, Vector2.ZERO, fold * (1.0 - fall))
