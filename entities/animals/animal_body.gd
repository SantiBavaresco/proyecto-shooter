class_name AnimalBody
extends Node3D
## Cuerpo de un animal hecho por código (provisorio hasta tener modelos): formas
## redondeadas (elipsoides, cápsulas, conos) según la especie, cajas de impacto, la
## animación de patas/cabeza/cola y el ragdoll al morir.
##
## Partes (cada una es un nodo con meta "size" = caja que la envuelve, para el ragdoll):
##   torso (tronco), head_center (cabeza), legs[i].get_child(0) (pata).
## Adelante = -Z.

const HITBOX_LAYER := 6
const RAGDOLL_LAYER := 12
## Capa visual de los personajes (la sangre del piso no se les pinta encima).
const VISUAL_LAYER := 2

var spec: AnimalSpecies
var torso: Node3D
var head: Node3D          ## pivote de la cabeza (gira)
var head_center: Node3D   ## centro de la cabeza (caja de impacto y ragdoll)
var tail: Node3D
var legs: Array[Node3D] = []
var rag: Array[RigidBody3D] = []

var _phase: float = 0.0
var _rag_still: float = 0.0
var _rag_t: float = 0.0
var _m: StandardMaterial3D
var _dark: StandardMaterial3D


func setup(s: AnimalSpecies, owner_node: Node3D, rng: RandomNumberGenerator) -> void:
	spec = s
	var col: Color = s.colors[rng.randi() % s.colors.size()] if not s.colors.is_empty() else Color(0.4, 0.3, 0.2)
	_m = _mat(col)
	_dark = _mat(col.darkened(0.35))
	match s.shape:
		"boar":
			_build_boar()
		"capy":
			_build_capy()
		_:
			_build_dog()
	set_meta("zone_owner", owner_node)
	for h in find_children("*", "StaticBody3D", true, false):
		h.set_meta("zone_owner", owner_node)


# --- Formas -----------------------------------------------------------------------------

func _build_dog() -> void:
	var sz := spec.size
	var lh := spec.leg
	torso = _part(self, Vector3(0, lh + sz.y * 0.5, 0), sz)
	_ellipsoid(torso, Vector3(0, 0.03, -sz.z * 0.2), Vector3(sz.x * 0.5, sz.y * 0.55, sz.z * 0.33), _m)
	_ellipsoid(torso, Vector3(0, -0.01, sz.z * 0.2), Vector3(sz.x * 0.44, sz.y * 0.45, sz.z * 0.32), _m)
	# Cuello
	_taper(torso, Vector3(0, sz.y * 0.32, -sz.z * 0.42), 0.075, 0.1, 0.3, _m, Vector3(-0.7, 0, 0))
	_torso_hitboxes(sz)
	head = _pivot(self, Vector3(0, lh + sz.y * 0.82, -sz.z * 0.55))
	var hs := Vector3(0.22, 0.2, 0.36)
	head_center = _part(head, Vector3(0, 0, -0.08), hs)
	_ellipsoid(head_center, Vector3(0, 0.02, 0.0), Vector3(0.11, 0.1, 0.13), _m)
	_cone_z(head_center, Vector3(0, -0.03, -0.17), 0.045, 0.068, 0.17, _m)
	_ellipsoid(head_center, Vector3(0, -0.015, -0.26), Vector3(0.028, 0.022, 0.02), _mat(Color(0.05, 0.04, 0.04)))
	for sx: float in [-1.0, 1.0]:
		_prism(head_center, Vector3(sx * 0.06, 0.12, 0.02), Vector3(0.07, 0.12, 0.03), _dark, Vector3(-0.2, 0, sx * 0.25))
		_ellipsoid(head_center, Vector3(sx * 0.055, 0.05, -0.1), Vector3(0.014, 0.014, 0.01), _mat(Color(0.05, 0.03, 0.02)))
	_hitbox(head_center, "head", hs)
	tail = _pivot(torso, Vector3(0, sz.y * 0.25, sz.z * 0.48))
	_taper(tail, Vector3(0, 0.0, 0.15), 0.014, 0.034, 0.32, _dark, Vector3(1.2, 0, 0))
	tail.rotation.x = 0.5
	_legs(sz, lh, 0.3, 0.36, 0.055, 0.035, false)


func _build_boar() -> void:
	var sz := spec.size
	var lh := spec.leg
	torso = _part(self, Vector3(0, lh + sz.y * 0.5, 0), sz)
	_ellipsoid(torso, Vector3.ZERO, Vector3(sz.x * 0.5, sz.y * 0.48, sz.z * 0.5), _m)
	# Joroba de la cruz y cresta de cerdas por el lomo
	_ellipsoid(torso, Vector3(0, sz.y * 0.16, -sz.z * 0.2), Vector3(sz.x * 0.46, sz.y * 0.42, sz.z * 0.3), _dark)
	_capsule_z(torso, Vector3(0, sz.y * 0.5, -sz.z * 0.06), 0.045, sz.z * 0.72, _dark)
	_torso_hitboxes(sz)
	head = _pivot(self, Vector3(0, lh + sz.y * 0.5, -sz.z * 0.46))
	var hs := Vector3(0.42, 0.44, 0.62)
	head_center = _part(head, Vector3(0, -0.06, -0.22), hs)
	# Cabeza en cuña: ancha atrás, angosta adelante
	_cone_z(head_center, Vector3(0, 0, 0.0), 0.1, 0.23, 0.6, _m)
	_cone_z(head_center, Vector3(0, -0.04, -0.33), 0.09, 0.1, 0.06, _mat(Color(0.33, 0.24, 0.24)))
	for sx: float in [-1.0, 1.0]:
		# Colmillos para arriba y orejas paradas
		_taper(head_center, Vector3(sx * 0.08, -0.02, -0.24), 0.008, 0.02, 0.13, _mat(Color(0.9, 0.87, 0.78)), Vector3(-0.5, 0, -sx * 0.35))
		_prism(head_center, Vector3(sx * 0.12, 0.2, 0.2), Vector3(0.11, 0.17, 0.05), _dark, Vector3(-0.3, 0, sx * 0.4))
		_ellipsoid(head_center, Vector3(sx * 0.11, 0.09, -0.02), Vector3(0.016, 0.016, 0.012), _mat(Color(0.04, 0.03, 0.02)))
	_hitbox(head_center, "head", hs)
	tail = _pivot(torso, Vector3(0, sz.y * 0.2, sz.z * 0.5))
	_taper(tail, Vector3(0, 0, 0.1), 0.01, 0.025, 0.2, _dark, Vector3(1.4, 0, 0))
	_legs(sz, lh, 0.3, 0.36, 0.1, 0.055, true)


func _build_capy() -> void:
	var sz := spec.size
	var lh := spec.leg
	torso = _part(self, Vector3(0, lh + sz.y * 0.5, 0), sz)
	# Barril con el anca un poco más alta
	_ellipsoid(torso, Vector3(0, 0, -0.03), Vector3(sz.x * 0.52, sz.y * 0.5, sz.z * 0.48), _m)
	_ellipsoid(torso, Vector3(0, sz.y * 0.06, sz.z * 0.26), Vector3(sz.x * 0.5, sz.y * 0.5, sz.z * 0.3), _m)
	_torso_hitboxes(sz)
	head = _pivot(self, Vector3(0, lh + sz.y * 0.74, -sz.z * 0.42))
	var hs := Vector3(0.27, 0.3, 0.44)
	head_center = _part(head, Vector3(0, -0.02, -0.12), hs)
	_ellipsoid(head_center, Vector3(0, 0.02, 0.02), Vector3(0.13, 0.15, 0.17), _m)
	# Hocico chato y alto
	_ellipsoid(head_center, Vector3(0, -0.02, -0.15), Vector3(0.11, 0.12, 0.1), _m)
	_ellipsoid(head_center, Vector3(0, 0.0, -0.245), Vector3(0.06, 0.03, 0.01), _mat(Color(0.12, 0.08, 0.06)))
	for sx: float in [-1.0, 1.0]:
		_ellipsoid(head_center, Vector3(sx * 0.07, 0.15, 0.08), Vector3(0.03, 0.03, 0.02), _dark)
		_ellipsoid(head_center, Vector3(sx * 0.09, 0.09, -0.04), Vector3(0.015, 0.018, 0.012), _mat(Color(0.04, 0.03, 0.02)))
	_hitbox(head_center, "head", hs)
	tail = null
	_legs(sz, lh, 0.3, 0.33, 0.065, 0.05, true)


## Pecho (adelante, con el corazón: letal) y panza/ancas (atrás).
func _torso_hitboxes(sz: Vector3) -> void:
	var chest := _pivot(torso, Vector3(0, 0, -sz.z * 0.25))
	_hitbox(chest, "chest", Vector3(sz.x, sz.y, sz.z * 0.5))
	var rear := _pivot(torso, Vector3(0, 0, sz.z * 0.25))
	_hitbox(rear, "torso", Vector3(sz.x, sz.y, sz.z * 0.5))


## Cuatro patas: muslo/brazo que se afina, caña fina y pata/pezuña.
func _legs(sz: Vector3, lh: float, kx: float, kz: float, r_top: float, r_low: float, hoof: bool) -> void:
	for lz: float in [-1.0, 1.0]:
		for lx: float in [-1.0, 1.0]:
			var piv := _pivot(self, Vector3(lx * sz.x * kx, lh, lz * sz.z * kz))
			var seg := _part(piv, Vector3(0, -lh * 0.5, 0), Vector3(r_top * 2.0, lh, r_top * 2.0))
			_taper(seg, Vector3(0, lh * 0.2, 0), r_top * 0.75, r_top, lh * 0.6, _m)
			_taper(seg, Vector3(0, -lh * 0.25, 0), r_low * 0.8, r_low, lh * 0.5, _dark)
			if hoof:
				_taper(seg, Vector3(0, -lh * 0.47, -0.01), r_low * 0.9, r_low * 1.05, 0.06, _mat(Color(0.08, 0.07, 0.06)))
			else:
				_ellipsoid(seg, Vector3(0, -lh * 0.47, -0.02), Vector3(r_low * 1.2, r_low * 0.8, r_low * 1.7), _dark)
			_hitbox(seg, "limb", Vector3(r_top * 2.2, lh, r_top * 2.2))
			legs.append(piv)


# --- Piezas -----------------------------------------------------------------------------

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.95
	return m


func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n


## Parte del cuerpo: un nodo con la caja que la envuelve (para el ragdoll).
func _part(parent: Node3D, pos: Vector3, size: Vector3) -> Node3D:
	var n := _pivot(parent, pos)
	n.set_meta("size", size)
	return n


func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, m: Material, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	mi.layers = VISUAL_LAYER
	parent.add_child(mi)
	return mi


func _ellipsoid(parent: Node3D, pos: Vector3, radii: Vector3, m: Material) -> MeshInstance3D:
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 14
	sm.rings = 8
	return _mesh(parent, sm, pos, m, Vector3.ZERO, radii)


func _capsule_z(parent: Node3D, pos: Vector3, radius: float, length: float, m: Material) -> MeshInstance3D:
	var cm := CapsuleMesh.new()
	cm.radius = radius
	cm.height = maxf(length, radius * 2.0 + 0.01)
	cm.radial_segments = 10
	cm.rings = 4
	return _mesh(parent, cm, pos, m, Vector3(PI * 0.5, 0, 0))


## Cilindro que se afina (r_top arriba, r_bottom abajo), con giro.
func _taper(parent: Node3D, pos: Vector3, r_top: float, r_bottom: float, h: float, m: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bottom
	cm.height = h
	cm.radial_segments = 10
	cm.rings = 1
	return _mesh(parent, cm, pos, m, rot)


## Cono a lo largo de Z: r_front adelante (-Z), r_back atrás.
func _cone_z(parent: Node3D, pos: Vector3, r_front: float, r_back: float, length: float, m: Material) -> MeshInstance3D:
	# El cilindro va en +Y; girado +90° en X, su "arriba" queda atrás (+Z)
	return _taper(parent, pos, r_back, r_front, length, m, Vector3(PI * 0.5, 0, 0))


func _prism(parent: Node3D, pos: Vector3, size: Vector3, m: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var pm := PrismMesh.new()
	pm.size = size
	return _mesh(parent, pm, pos, m, rot)


func _hitbox(on: Node3D, zone: String, size: Vector3) -> void:
	var b := StaticBody3D.new()
	b.collision_layer = 1 << (HITBOX_LAYER - 1)
	b.collision_mask = 0
	b.set_meta("hit_zone", zone)
	b.set_meta("surface", "flesh")
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	b.add_child(cs)
	on.add_child(b)


# --- Animación --------------------------------------------------------------------------

## Pose del cuerpo según la velocidad. Devuelve true en el cuadro en que apoya una pata
## (para el ruido de pasos). wander: anda tranquilo (cola, cabeza baja olfateando).
func animate(delta: float, speed: float, wander: bool, alert: bool) -> bool:
	var stride := spec.leg * 2.6
	var dphase := speed / stride * TAU * delta
	_phase += dphase
	var amp := clampf(speed / spec.trot, 0.0, 1.0) * (0.55 if speed < spec.trot * 1.3 else 0.8)
	var gallop := speed > spec.trot * 1.3
	for i in legs.size():
		# Paso/trote: diagonales juntas; galope: delanteras y traseras juntas
		var off := (0.0 if i < 2 else PI * 0.8) if gallop else (0.0 if i in [0, 3] else PI)
		legs[i].rotation.x = sin(_phase + off) * amp
	position.y = sin(_phase) * 0.06 if gallop else absf(sin(_phase)) * 0.03 * amp
	rotation.x = sin(_phase) * 0.06 * amp if gallop else 0.0
	rotation.z = 0.0
	if tail != null:
		tail.rotation.y = sin(Time.get_ticks_msec() * 0.012) * (0.5 if wander and spec.shape == "dog" else 0.1)
	if head != null:
		var low := wander and speed < 0.6 and not alert
		head.rotation.x = lerpf(head.rotation.x, -0.45 if low else 0.0, 1.0 - exp(-3.0 * delta))
	return speed > 2.5 and int(_phase / PI) != int((_phase - dphase) / PI)


## Herido de muerte arrastrándose: patas de atrás muertas, cuerpo caído de costado.
func animate_dying(delta: float, speed: float) -> void:
	_phase += speed / (spec.leg * 2.6) * TAU * delta
	var k := 1.0 - exp(-2.0 * delta)
	for i in legs.size():
		legs[i].rotation.x = sin(_phase * 1.6) * 0.7 if i < 2 else 1.3
	rotation.z = lerpf(rotation.z, 0.25, k)
	rotation.x = lerpf(rotation.x, 0.12, k)
	position.y = lerpf(position.y, -spec.leg * 0.45, k)
	if head != null:
		head.rotation.x = lerpf(head.rotation.x, -0.5, k)


# --- Ragdoll ----------------------------------------------------------------------------

## Pasa a cuerpo de física (tronco, cabeza y patas con bisagras) para que quede apoyado
## sobre el piso como corresponde. vel: la que traía; push/at: el empujón del tiro.
func make_ragdoll(vel: Vector3, push: Vector3, at: Vector3, roll_dir: float) -> void:
	var host := get_parent() as Node3D
	var tb := _rb(host, torso, spec.mass * 0.7)
	reparent(tb, true)
	var hb := _rb(host, head_center, spec.mass * 0.12)
	head.reparent(hb, true)
	var neck := PinJoint3D.new()
	host.add_child(neck)
	neck.top_level = true
	neck.global_position = head.global_position
	neck.node_a = neck.get_path_to(tb)
	neck.node_b = neck.get_path_to(hb)
	for piv in legs:
		var seg := piv.get_child(0) as Node3D
		var lb := _rb(host, seg, spec.mass * 0.045)
		piv.reparent(lb, true)
		var hj := HingeJoint3D.new()
		host.add_child(hj)
		hj.top_level = true
		hj.global_transform = Transform3D(Basis(tb.global_basis.z, tb.global_basis.y, tb.global_basis.x), piv.global_position)
		hj.set_flag(HingeJoint3D.FLAG_USE_LIMIT, true)
		hj.set_param(HingeJoint3D.PARAM_LIMIT_LOWER, deg_to_rad(-70.0))
		hj.set_param(HingeJoint3D.PARAM_LIMIT_UPPER, deg_to_rad(70.0))
		hj.node_a = hj.get_path_to(tb)
		hj.node_b = hj.get_path_to(lb)
	for b in rag:
		b.linear_velocity = vel
	if push != Vector3.ZERO:
		push_ragdoll(push, at)
	else:
		# Se desploma de costado
		tb.apply_torque_impulse(tb.global_basis.z * roll_dir * spec.mass * 0.35)


func _rb(host: Node3D, part: Node3D, mass: float) -> RigidBody3D:
	var b := RigidBody3D.new()
	b.collision_layer = 1 << (RAGDOLL_LAYER - 1)
	b.collision_mask = 1
	b.mass = maxf(mass, 0.5)
	b.linear_damp = 0.4
	b.angular_damp = 1.5
	b.set_meta("zone_owner", host)
	b.set_meta("surface", "flesh")
	var pm := PhysicsMaterial.new()
	pm.friction = 0.9
	pm.bounce = 0.0
	b.physics_material_override = pm
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = part.get_meta("size", Vector3(0.2, 0.2, 0.2))
	cs.shape = bs
	b.add_child(cs)
	host.add_child(b)
	b.top_level = true
	b.global_transform = Transform3D(part.global_basis.orthonormalized(), part.global_position)
	rag.append(b)
	return b


func push_ragdoll(impulse: Vector3, at: Vector3) -> void:
	if rag.is_empty():
		return
	for b in rag:
		b.freeze = false
	_rag_still = 0.0
	_rag_t = minf(_rag_t, 1.0)
	var tb := rag[0]
	tb.apply_impulse(impulse, at - tb.global_position if at != Vector3.ZERO else Vector3.ZERO)


## Se congela cuando queda quieto (o después de un rato): no gasta física.
func ragdoll_update(delta: float) -> void:
	if rag.is_empty() or rag[0].freeze:
		return
	_rag_t += delta
	var moving := false
	for b in rag:
		if b.linear_velocity.length() > 0.12 or b.angular_velocity.length() > 0.4:
			moving = true
			break
	_rag_still = 0.0 if moving else _rag_still + delta
	if (_rag_still > 0.8 and _rag_t > 1.0) or _rag_t > 10.0:
		for b in rag:
			b.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
			b.freeze = true


func is_frozen() -> bool:
	return not rag.is_empty() and rag[0].freeze


## Centro del tronco (vivo o caído).
func center() -> Vector3:
	return rag[0].global_position if not rag.is_empty() else torso.global_position


func head_position() -> Vector3:
	return head_center.global_position
