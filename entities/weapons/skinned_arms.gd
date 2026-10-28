class_name SkinnedArms
extends Node3D
## Brazos con esqueleto para las armas hechas por código: los mismos brazos y manos
## del AR-74K importado (modelo con huesos, CC-BY, ver docs/ASSETS.md).
##
## Las armas por código siguen armando sus manos procedurales (HandR, HandL, HookR,
## HookL, HookP, HandLoad) y la vista las sigue moviendo igual que antes en cada
## recarga y destrabado; acá esas mallas se ocultan y quedan como "objetivos": cada
## cuadro la mano del esqueleto va a donde está la mano procedural visible y el codo
## y el hombro se acomodan solos (IK de dos huesos). Los dedos quedan con la pose de
## agarre del modelo (cuadro de la animación quieta).
##
## Calibración: en el modelo del AR-74K se mide dónde queda cada mano respecto de la
## empuñadura y del guardamanos; en cada arma se usa la misma relación sobre su propia
## empuñadura y guardamanos (con su ángulo y su grosor).

const SCENE := "res://assets/models/ak74u/ak74u.glb"
## Ojo del modelo (la cámara): el esqueleto se pone de modo que quede en el origen.
const EYE := Vector3(0.0, 1.62, 0.02)
## Hombros un poco más abajo y atrás que en el modelo: con las manos altas (cartuchos,
## manija) el brazo entra desde abajo y no cruza la pantalla.
const SHOULDER_SHIFT := Vector3(0.0, -0.05, 0.05)
const GUN_BONE := "Bone_043"
## Mallas de los brazos (el resto es el arma y los cargadores del modelo).
const ARM_MESHES := ["Object_57", "Object_59"]
const IDLE_ANIM := "IDLE"
const IDLE_AT := 1.0
## Empuñadura y guardamanos del AR-74K (marco del arma: adelante −Z, arriba +Y).
const AK_GRIP_TOP := Vector3(0.0, -0.045, 0.012)
const AK_GRIP_AXIS := Vector3(0.0, -0.058, 0.015)
const AK_GRIP_R := 0.012
const AK_FOREND := Vector3(0.0, 0.012, -0.245)
const AK_FOREND_R := 0.022
## Índice derecho: cuánto se cierra hacia la pose del mayor para apoyarse en la cola
## del disparador (en el modelo está estirado, fuera del guardamanos del gatillo).
const INDEX_CURL := 0.45
## Ajuste de la toma derecha sobre la empuñadura (a lo largo de ella y en el arma).
const GRIP_DROP := 0.03
## Inclinación máxima de la mano respecto de la vertical (grados).
const GRIP_MAX_TILT := 38.0
const GRIP_SHIFT := Vector3(0.0, 0.0, 0.0)
## Dónde apoya la yema respecto de la cola del disparador (marco del arma).
const TRIGGER_PAD := Vector3(0.0, -0.002, 0.004)
## Hacia dónde cae cada codo (espacio de la cámara): abajo y afuera.
const POLE := {1: Vector3(0.7, -1.0, 0.1), -1: Vector3(-0.7, -1.0, 0.05)}
## Segundos para pasar de una toma a otra (empuñadura → manija, etc.).
const SWITCH_TIME := 0.09

var sk: Skeleton3D
var ok: bool = false
var _chain := {}  # lado → [brazo, antebrazo, mano]
var _idle := {}  # hueso → pose local de la animación quieta
var _rel_grip: Transform3D
var _rel_forend: Transform3D
## Yema del índice derecho en el espacio del hueso de la mano.
var _tip_local: Vector3
## Yema del índice en el espacio de su primera falange.
var _tip_i1: Vector3
var _index1: int = -1
## Base del índice en el espacio del hueso de la mano.
var _i1_local: Vector3
## Cola del disparador del arma actual (espacio de este nodo), o null.
var _trigger_at: Variant = null
var _len := {}  # lado → [brazo, antebrazo]
var _idle_g := {}  # lado → [hombro, codo, muñeca, base brazo, base antebrazo]
var _src := {}
var _from := {}
var _blend_t := {}
var _last := {}


func _ready() -> void:
	if not ResourceLoader.exists(SCENE):
		return
	var inst := (load(SCENE) as PackedScene).instantiate() as Node3D
	inst.name = "Arms"
	inst.position = -EYE + SHOULDER_SHIFT
	add_child(inst)
	for mi: Node in inst.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		m.visible = ARM_MESHES.has(String(m.name))
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sk = inst.find_child("Skeleton3D", true, false) as Skeleton3D
	var ap := inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if sk == null or ap == null or not ap.has_animation(IDLE_ANIM):
		return
	# Pose de agarre: un cuadro de la animación quieta; después la animación se apaga
	ap.play(IDLE_ANIM)
	ap.seek(IDLE_AT, true)
	ap.advance(0.0)
	ap.active = false
	sk.force_update_all_bone_transforms()
	_curl_index()
	for b in sk.get_bone_count():
		_idle[b] = sk.get_bone_pose(b)
	for side: int in [1, -1]:
		var n := "Right" if side > 0 else "Left"
		var ids: Array[int] = [_bone(n + "Arm_"), _bone(n + "ForeArm_"), _bone(n + "Hand_")]
		if ids.has(-1):
			return
		_chain[side] = ids
		var s := _g(ids[0])
		var e := _g(ids[1])
		var h := _g(ids[2])
		_len[side] = [s.origin.distance_to(e.origin), e.origin.distance_to(h.origin)]
		_idle_g[side] = [s, e, h]
	# Calibración sobre el arma del modelo
	var gb := sk.find_bone(GUN_BONE)
	if gb < 0:
		return
	var gun := global_transform.affine_inverse() * sk.global_transform * sk.get_bone_global_pose(gb) \
		* Transform3D(ImportedWeapon.MARKER_BASIS, Vector3.ZERO)
	var gi := gun.affine_inverse()
	_rel_grip = _grip_frame(AK_GRIP_TOP, AK_GRIP_AXIS.normalized(), 0.0).affine_inverse() * gi * _g(_chain[1][2])
	_rel_forend = Transform3D(Basis.IDENTITY, AK_FOREND).affine_inverse() * gi * _g(_chain[-1][2])
	var i2 := _bone("RightHandIndex2_")
	var i3 := _bone("RightHandIndex3_")
	if i2 >= 0 and i3 >= 0:
		# Yema: a mitad de la última falange (el modelo no trae hueso de la punta)
		var g3 := _g(i3)
		var l3 := _g(i2).origin.distance_to(g3.origin) * 0.8
		var tip := g3.origin + g3.basis.y.normalized() * l3 * 0.55
		_tip_local = _g(_chain[1][2]).affine_inverse() * tip
		_index1 = _bone("RightHandIndex1_")
		_tip_i1 = _g(_index1).affine_inverse() * tip
		_i1_local = _g(_chain[1][2]).affine_inverse() * _g(_index1).origin
	ok = true


## Cierra el índice derecho hacia la pose del mayor (sin tocar el resto de la mano).
func _curl_index() -> void:
	for j in 3:
		var bi := _bone("RightHandIndex%d_" % (j + 1))
		var bm := _bone("RightHandMiddle%d_" % (j + 1))
		if bi < 0 or bm < 0:
			continue
		var qi := sk.get_bone_pose_rotation(bi)
		var qm := sk.get_bone_pose_rotation(bm)
		sk.set_bone_pose_rotation(bi, qi.slerp(qm, INDEX_CURL if j > 0 else INDEX_CURL * 0.6))
	sk.force_update_all_bone_transforms()


func _bone(part: String) -> int:
	for b in sk.get_bone_count():
		if sk.get_bone_name(b).contains(part) and not sk.get_bone_name(b).contains("."):
			return b
	return -1


## Pose global de un hueso, en el espacio de este nodo.
func _g(b: int) -> Transform3D:
	return global_transform.affine_inverse() * sk.global_transform * sk.get_bone_global_pose(b)


## Marco de una empuñadura: origen en la palma, Y hacia arriba de la empuñadura.
static func _grip_frame(top: Vector3, a: Vector3, dx: float) -> Transform3D:
	var y := -a
	var x := Vector3.RIGHT
	var z := x.cross(y).normalized()
	return Transform3D(Basis(x, y, z), top + a * 0.04 + Vector3(dx, 0, 0))


## Base de una mano: dedos hacia "fingers", palma mirando a "palm" (en el esqueleto
## de Mixamo la Y del hueso va hacia los dedos y la Z sale de la palma).
static func _hand_basis(fingers: Vector3, palm: Vector3) -> Basis:
	var y := fingers.normalized()
	var z := (palm - y * palm.dot(y)).normalized()
	return Basis(y.cross(z), y, z)


## Oculta las mallas de las manos procedurales de un arma (quedan como objetivos).
static func hide_procedural(model: Node3D) -> void:
	for n: Node in model.find_children("*", "Node3D", true, false):
		if n.has_meta("kind"):
			for part: String in ["Glove", "Sleeve"]:
				if n.has_node(part):
					(n.get_node(part) as Node3D).visible = false


## Mueve los brazos a las manos procedurales del arma (después de animarlas).
func update(model: Node3D, delta: float) -> void:
	if not ok:
		return
	for side: int in [1, -1]:
		var src := _source(model, side)
		if src == null:
			continue
		var tgt := global_transform.affine_inverse() * src.global_transform * _grip_of(src)
		if side > 0:
			_trigger_at = null
			if src.has_meta("trigger") and String(src.get_meta("kind", "")) == "grip":
				_trigger_at = global_transform.affine_inverse() * src.global_transform \
					* ((src.get_meta("trigger") as Vector3) + TRIGGER_PAD)
		if _src.get(side) != src:
			if _src.has(side) and _last.has(side):
				_from[side] = _last[side]
				_blend_t[side] = 0.0
			_src[side] = src
		if _blend_t.has(side):
			_blend_t[side] = float(_blend_t[side]) + delta / SWITCH_TIME
			var k := WeaponViewmodel.smooth(clampf(float(_blend_t[side]), 0.0, 1.0))
			tgt = (_from[side] as Transform3D).interpolate_with(tgt, k)
			if float(_blend_t[side]) >= 1.0:
				_blend_t.erase(side)
		_last[side] = tgt
		_solve(side, tgt)
		if side > 0:
			_aim_index()


## Mano procedural que manda en cada lado (la visible; si no hay, la de reposo, que
## igual se mueve fuera de la vista, ej. la izquierda mientras busca cartuchos).
func _source(model: Node3D, side: int) -> Node3D:
	var names: Array = ["HookR", "HandR"] if side > 0 else ["HookL", "HookP", "Barrels/Loader/LoadPose/HandLoad", "Barrels/HandL", "HandL"]
	var fallback: Node3D = null
	for n: String in names:
		var node := model.get_node_or_null(n) as Node3D
		if node == null:
			continue
		if node.is_visible_in_tree():
			return node
		if fallback == null and (n == "HandR" or n.ends_with("HandL")):
			fallback = node
	return fallback


## Dónde va el hueso de la mano respecto del nodo de la mano procedural.
func _grip_of(src: Node3D) -> Transform3D:
	var z := Vector3.ZERO
	match String(src.get_meta("kind", "")):
		"grip":
			var a: Vector3 = src.get_meta("grip_axis")
			# Culatas de garganta (SKS, Mauser, escopetas): la empuñadura casi acostada;
			# la mano no se acuesta tanto
			var tilt := a.angle_to(Vector3.DOWN)
			# (cuánto más acostada que el tope: la mano sube para abrazar la garganta)
			var flat := clampf((tilt - deg_to_rad(GRIP_MAX_TILT)) / deg_to_rad(30.0), 0.0, 1.0)
			if tilt > deg_to_rad(GRIP_MAX_TILT):
				a = Vector3.DOWN.slerp(a, deg_to_rad(GRIP_MAX_TILT) / tilt).normalized()
			var dx := (float(src.get_meta("grip_r")) - AK_GRIP_R) * 1.5
			var g := _grip_frame(src.get_meta("grip_top"), a, dx) * _rel_grip
			# La mano abraza la empuñadura (más abajo que en la medición del modelo)
			g.origin += a * GRIP_DROP * (1.0 - flat * 0.6) + GRIP_SHIFT + Vector3(0, 0.016 * flat, 0)
			if src.has_meta("trigger") and _index1 >= 0:
				# Si el índice no llega a la cola del disparador, la mano se acerca
				var tr: Vector3 = (src.get_meta("trigger") as Vector3) + TRIGGER_PAD
				var i1 := g * _i1_local
				var reach := _tip_i1.length() * 0.8
				var dv := tr - i1
				if dv.length() > reach:
					g.origin += dv.normalized() * (dv.length() - reach)
			return g
		"forend":
			var c: Vector3 = src.get_meta("palm", z)
			var r := _rel_forend
			var k := (float(src.get_meta("lr", AK_FOREND_R)) + 0.012) / (AK_FOREND_R + 0.012)
			r.origin = Vector3(r.origin.x * k, r.origin.y * k, r.origin.z)
			return Transform3D(Basis.IDENTITY, c) * r
		"hook":
			# Por arriba de la bola, palma abajo, dedos adelante enganchando la manija
			var s := float(src.get_meta("side", 1.0))
			return Transform3D(_hand_basis(Vector3(-s * 0.1, -0.25, -1.0), Vector3(-s * 0.15, -1.0, 0.0)),
				Vector3(s * 0.03, 0.03, 0.095))
		"slide":
			# Palma sobre la corredera, dedos hacia la derecha y abajo
			var kn: Vector3 = src.get_meta("knob", z)
			return Transform3D(_hand_basis(Vector3(1.0, -0.35, -0.35), Vector3(0.35, -1.0, 0.0)),
				kn + Vector3(-0.07, 0.035, 0.045))
		"support":
			# Mano de apoyo de la pistola: palma contra el costado izquierdo, dedos por delante
			var p: Vector3 = src.get_meta("palm", z)
			return Transform3D(_hand_basis(Vector3(0.35, -0.35, -1.0), Vector3(1.0, 0.1, 0.0)),
				p + Vector3(-0.03, -0.01, 0.05))
		"loader":
			# Palma abajo detrás de las recámaras, dedos hacia adentro de los caños con los
			# cartuchos entre los dedos (el culote contra la palma)
			var d: Vector3 = src.get_meta("d", Vector3.BACK)
			var far: Vector3 = src.get_meta("far", Vector3.FORWARD)
			var near := -far
			return Transform3D(_hand_basis(-d + far * 0.5, near), d * 0.075 + far * 0.02 + Vector3(-0.012, 0, 0))
	return Transform3D.IDENTITY


## IK de dos huesos: hombro fijo (se adelanta si la mano no llega), codo hacia el polo.
func _solve(side: int, tgt: Transform3D) -> void:
	var ids: Array[int] = _chain[side]
	for b in ids:
		sk.set_bone_pose(b, _idle[b])
	var lens: Array = _len[side]
	var l1: float = lens[0]
	var l2: float = lens[1]
	var ig: Array = _idle_g[side]
	var s := _g(ids[0]).origin
	var t := tgt.origin
	var dv := t - s
	var d := dv.length()
	var reach := (l1 + l2) * 0.985
	if d > reach:
		# El hombro acompaña (brazo estirado): no se despega la mano del arma
		s += dv / d * (d - reach)
		d = reach
	d = maxf(d, absf(l1 - l2) + 0.01)
	var dir := (t - s).normalized()
	var a := (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
	var h := sqrt(maxf(l1 * l1 - a * a, 0.0))
	var pole: Vector3 = POLE[side]
	var perp := (pole - dir * pole.dot(dir)).normalized()
	var e := s + dir * a + perp * h
	var s0: Vector3 = (ig[0] as Transform3D).origin
	var e0: Vector3 = (ig[1] as Transform3D).origin
	var h0: Vector3 = (ig[2] as Transform3D).origin
	var n0 := (e0 - s0).cross(h0 - e0).normalized()
	var n1 := (e - s).cross(t - e).normalized()
	var b_arm := _frame(e - s, n1) * _frame(e0 - s0, n0).inverse() * (ig[0] as Transform3D).basis
	var b_fore := _frame(t - e, n1) * _frame(h0 - e0, n0).inverse() * (ig[1] as Transform3D).basis
	var to_skel := sk.global_transform.affine_inverse() * global_transform
	sk.set_bone_global_pose(ids[0], to_skel * Transform3D(b_arm, s))
	sk.set_bone_global_pose(ids[1], to_skel * Transform3D(b_fore, e))
	sk.set_bone_global_pose(ids[2], to_skel * Transform3D(tgt.basis, t))


static func _frame(v: Vector3, n: Vector3) -> Basis:
	var y := v.normalized()
	var x := (n - y * n.dot(y)).normalized()
	return Basis(x, y, x.cross(y))


## Índice derecho: gira la primera falange para que la yema caiga en la cola del
## disparador (con la mano en otra toma, queda como está).
func _aim_index() -> void:
	if _index1 < 0:
		return
	sk.set_bone_pose(_index1, _idle[_index1])
	if _trigger_at == null:
		return
	var g1 := _g(_index1)
	var tip := g1 * _tip_i1
	var from := (tip - g1.origin).normalized()
	var to := ((_trigger_at as Vector3) - g1.origin).normalized()
	if from.dot(to) < cos(deg_to_rad(60.0)):
		return
	var axis := from.cross(to)
	if axis.length() < 1e-5:
		return
	var rot := Basis(axis.normalized(), from.angle_to(to))
	var to_skel := sk.global_transform.affine_inverse() * global_transform
	sk.set_bone_global_pose(_index1, to_skel * Transform3D(rot * g1.basis, g1.origin))
