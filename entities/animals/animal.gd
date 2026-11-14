class_name Animal
extends CharacterBody3D
## Animal salvaje: perro cimarrón, jabalí o carpincho. Andan en grupo (AnimalPack)
## por su zona.
##  - Perros: cobardes y de jauría. Te rodean corriendo en círculo y ladrando, de a uno
##    o dos se tiran a morder (o amagan) y se abren. Si les pegás o cae uno de cada
##    tres, se van.
##  - Jabalíes: grandes, rápidos y territoriales. Al que se mete en su lugar (o les
##    tira) lo embisten; la carga lo sigue hasta el final y recién en el último
##    momento se puede esquivar al costado.
##  - Carpinchos: tranquilos. Si hay peligro se meten abajo del agua (o se van); solo
##    muerden si los acorralás.
## Con un tiro a la cabeza o al pecho caen en el acto (ragdoll); si no, se arrastran un
## rato y caen. Muertos se pueden cuerear con el cuchillo.
##
## El cuerpo está hecho por código (cajas) con patas que se mueven: provisorio.

const HITBOX_LAYER := 6
const BODY_LAYER := 5
const RAGDOLL_LAYER := 12
## Probabilidad de sacar un cuero al cuerear.
const SKIN_CHANCE := 0.45
## Carpincho: a menos de esto de alguien (o trabado huyendo con alguien a CORNER_NEAR),
## se da vuelta y muerde.
const CORNER_DIST := 2.0
const CORNER_NEAR := 4.0
## Jabalí: a menos de esto deja de corregir el rumbo (ahí se lo esquiva).
const CHARGE_LOCK := 3.2
const CHARGE_TURN := 3.2

enum State { WANDER, ALERT, ATTACK, RETREAT, FLEE, DEAD, HIDE, DYING }

## Datos de cada especie. reach_up: cuánto más alto que él puede estar el blanco para
## alcanzarlo (subido a una caja, no). flee_frac: parte del grupo que tiene que caer
## para que se vayan. territory: radio de su lugar (0 = no defiende).
const SPECIES := {
	"dog": {
		"hp": 55.0, "walk": 1.4, "trot": 3.4, "run": 9.0, "size": Vector3(0.36, 0.42, 0.95),
		"leg": 0.42, "sight": 38.0, "smell": 14.0, "fov": 120.0, "mass": 25.0,
		"dmg": [7.0, 13.0], "reach": 1.35, "reach_up": 0.9, "hit_gap": 0.75, "hits": [1, 2], "push": 0.0,
		"retreat": [10.0, 20.0], "courage": 0.35, "flee_frac": 0.34, "territory": 0.0, "pack": [3, 5],
		"colors": [Color(0.36, 0.25, 0.16), Color(0.12, 0.11, 0.1), Color(0.62, 0.5, 0.33), Color(0.4, 0.4, 0.38)],
	},
	"boar": {
		"hp": 220.0, "walk": 1.1, "trot": 2.8, "run": 9.6, "size": Vector3(0.62, 0.8, 1.6),
		"leg": 0.38, "sight": 30.0, "smell": 12.0, "fov": 110.0, "mass": 95.0,
		"dmg": [20.0, 32.0], "reach": 1.55, "reach_up": 0.7, "hit_gap": 1.1, "hits": [1, 1], "push": 9.0,
		"retreat": [5.0, 10.0], "courage": 0.95, "flee_frac": 0.67, "territory": 26.0, "pack": [3, 4],
		"colors": [Color(0.2, 0.16, 0.13), Color(0.27, 0.21, 0.16), Color(0.16, 0.14, 0.13)],
	},
	"capy": {
		"hp": 75.0, "walk": 0.7, "trot": 2.0, "run": 6.2, "size": Vector3(0.5, 0.5, 1.05),
		"leg": 0.22, "sight": 20.0, "smell": 0.0, "fov": 150.0, "mass": 50.0,
		"dmg": [9.0, 16.0], "reach": 1.25, "reach_up": 0.6, "hit_gap": 0.9, "hits": [1, 2], "push": 0.0,
		"retreat": [8.0, 14.0], "courage": 0.0, "flee_frac": 0.01, "territory": 0.0, "pack": [3, 6],
		"colors": [Color(0.45, 0.31, 0.19), Color(0.5, 0.36, 0.22), Color(0.4, 0.29, 0.2)],
	},
}

@export var species: String = "dog"
var pack: AnimalPack = null
var state: State = State.WANDER
var hp: float = 55.0
## Muerto o muriéndose (no ataca ni cuenta como amenaza).
var dead: bool = false
var skinned: bool = false
var target: Node3D = null
var rng := RandomNumberGenerator.new()

var _d: Dictionary
var _move_to: Vector3 = Vector3.INF
var _speed: float = 0.0
var _t: float = 0.0
var _hits_left: int = 0
var _hit_cd: float = 0.0
var _charge_dir: Vector3 = Vector3.ZERO
var _charging: bool = false
var _charge_locked: bool = false
var _voice_t: float = 0.0
var _phase: float = 0.0
var _yaw: float = 0.0
var _stuck_t: float = 0.0
var _last_pos := Vector3.ZERO
var _dead_t: float = 0.0
var _flee_from := Vector3.ZERO
## Perro: "circle" (rodea), "dart" (se tira a morder), "feint" (amaga y se abre).
var _mode: String = ""
var _orbit_ang: float = 0.0
var _orbit_r: float = 7.0
var _orbit_dir: float = 1.0
var _unreach_t: float = 0.0
var _antic_t: float = 0.0
var _dying_t: float = 0.0
var _water_target := Vector3.INF
var _hide_t: float = 0.0
var _last_blood := Vector3.INF

var agent: NavigationAgent3D
var _model: Node3D
var _torso: MeshInstance3D
var _head_mesh: MeshInstance3D
var _legs: Array[Node3D] = []
var _head: Node3D
var _tail: Node3D
var _voice: AudioStreamPlayer3D
var _steps: AudioStreamPlayer3D
var _rag: Array[RigidBody3D] = []
var _rag_still: float = 0.0


func _ready() -> void:
	_d = SPECIES.get(species, SPECIES["dog"])
	hp = float(_d["hp"])
	add_to_group("animals")
	collision_layer = 1 << (BODY_LAYER - 1)
	collision_mask = 1 | (1 << 9)
	floor_snap_length = 0.5
	floor_max_angle = deg_to_rad(50.0)
	var sz: Vector3 = _d["size"]
	var cs := CollisionShape3D.new()
	var sh := CapsuleShape3D.new()
	sh.radius = sz.x * 0.75
	sh.height = maxf(sz.y + float(_d["leg"]), sh.radius * 2.0 + 0.01)
	cs.shape = sh
	cs.position = Vector3(0, sh.height * 0.5, 0)
	add_child(cs)
	agent = NavigationAgent3D.new()
	agent.radius = 0.35
	agent.path_desired_distance = 0.8
	agent.target_desired_distance = 0.8
	add_child(agent)
	_voice = AudioStreamPlayer3D.new()
	_voice.bus = "SFX_World"
	_voice.unit_size = 6.0
	_voice.max_distance = 90.0
	add_child(_voice)
	_steps = AudioStreamPlayer3D.new()
	_steps.bus = "SFX_World"
	_steps.unit_size = 2.0
	_steps.max_distance = 30.0
	add_child(_steps)
	_build_model()
	_yaw = rotation.y
	rotation = Vector3.ZERO
	_voice_t = rng.randf_range(2.0, 8.0)
	_orbit_dir = -1.0 if rng.randf() < 0.5 else 1.0
	EventBus.noise_emitted.connect(_on_noise)


# --- Cuerpo ---------------------------------------------------------------------------

func _build_model() -> void:
	var sz: Vector3 = _d["size"]
	var leg_h: float = _d["leg"]
	var cols: Array = _d["colors"]
	var col: Color = cols[rng.randi() % cols.size()]
	var m := _mat(col)
	var dark := _mat(col.darkened(0.35))
	_model = Node3D.new()
	add_child(_model)
	if species == "capy":
		_build_capy(m, dark, sz, leg_h)
		return
	var boar := species == "boar"
	# Tronco (más alto adelante en el jabalí: la "joroba" de la cruz)
	_torso = _box(_model, Vector3(0, leg_h + sz.y * 0.5, 0), Vector3(sz.x, sz.y, sz.z), m)
	if boar:
		_box(_torso, Vector3(0, sz.y * 0.35, -sz.z * 0.22), Vector3(sz.x * 0.85, sz.y * 0.45, sz.z * 0.45), dark)
		# Cresta de cerdas por el lomo
		_box(_torso, Vector3(0, sz.y * 0.58, -sz.z * 0.1), Vector3(0.07, 0.12, sz.z * 0.7), dark)
	_torso_hitboxes(sz)
	# Cabeza (adelante = -Z)
	_head = Node3D.new()
	_head.position = Vector3(0, leg_h + sz.y * (0.75 if not boar else 0.55), -sz.z * 0.5)
	_model.add_child(_head)
	var hs := Vector3(sz.x * 0.8, sz.y * 0.62, sz.z * 0.3) if not boar else Vector3(sz.x * 0.8, sz.y * 0.7, sz.z * 0.32)
	_head_mesh = _box(_head, Vector3(0, 0, -hs.z * 0.5), hs, m)
	_hitbox(_head_mesh, "head", hs)
	# Hocico
	var sn := Vector3(hs.x * 0.55, hs.y * 0.5, hs.z * 0.9) if not boar else Vector3(hs.x * 0.6, hs.y * 0.55, hs.z * 1.3)
	_box(_head, Vector3(0, -hs.y * 0.2, -hs.z - sn.z * 0.5), sn, dark)
	if boar:
		# Disco del hocico y colmillos
		_box(_head, Vector3(0, -hs.y * 0.2, -hs.z - sn.z - 0.01), Vector3(sn.x * 0.9, sn.y * 0.9, 0.02), _mat(Color(0.35, 0.25, 0.25)))
		for sx: float in [-1.0, 1.0]:
			_box(_head, Vector3(sx * sn.x * 0.55, -hs.y * 0.15, -hs.z - sn.z * 0.7), Vector3(0.03, 0.12, 0.03), _mat(Color(0.9, 0.87, 0.78)), Vector3(0.4, 0, sx * 0.4))
	# Orejas
	for sx: float in [-1.0, 1.0]:
		if boar:
			_box(_head, Vector3(sx * hs.x * 0.4, hs.y * 0.55, -hs.z * 0.2), Vector3(0.1, 0.16, 0.05), dark, Vector3(0, 0, sx * 0.4))
		else:
			_box(_head, Vector3(sx * hs.x * 0.32, hs.y * 0.62, -hs.z * 0.3), Vector3(0.07, 0.15, 0.05), dark, Vector3(-0.15, 0, sx * 0.15))
	# Cola
	_tail = Node3D.new()
	_tail.position = Vector3(0, sz.y * 0.3, sz.z * 0.5)
	_torso.add_child(_tail)
	var tl := 0.32 if not boar else 0.2
	_box(_tail, Vector3(0, 0, tl * 0.5), Vector3(0.06, 0.06, tl), dark, Vector3(-0.5, 0, 0))
	_build_legs(sz, leg_h, dark, 0.32, 0.38, 0.09 if not boar else 0.13)


## Carpincho: barril con cabeza grande y cuadrada, hocico chato, orejas chiquitas y
## sin cola; patas cortas.
func _build_capy(m: Material, dark: Material, sz: Vector3, leg_h: float) -> void:
	_torso = _box(_model, Vector3(0, leg_h + sz.y * 0.5, 0.02), Vector3(sz.x, sz.y, sz.z), m)
	_box(_torso, Vector3(0, sz.y * 0.05, sz.z * 0.36), Vector3(sz.x * 1.04, sz.y * 1.04, sz.z * 0.32), m)
	_torso_hitboxes(sz)
	_head = Node3D.new()
	_head.position = Vector3(0, leg_h + sz.y * 0.72, -sz.z * 0.45)
	_model.add_child(_head)
	var hs := Vector3(sz.x * 0.62, sz.y * 0.62, sz.z * 0.42)
	_head_mesh = _box(_head, Vector3(0, -0.02, -hs.z * 0.5), hs, m)
	_hitbox(_head_mesh, "head", hs)
	# Hocico chato y alto, nariz oscura
	_box(_head, Vector3(0, -0.06, -hs.z - 0.05), Vector3(hs.x * 0.92, hs.y * 0.78, 0.12), m)
	_box(_head, Vector3(0, 0.02, -hs.z - 0.115), Vector3(hs.x * 0.55, 0.06, 0.01), dark)
	for sx: float in [-1.0, 1.0]:
		_box(_head, Vector3(sx * hs.x * 0.36, hs.y * 0.5, -hs.z * 0.15), Vector3(0.06, 0.06, 0.04), dark)
		# Ojos arriba (para mirar con el cuerpo bajo el agua)
		_box(_head, Vector3(sx * hs.x * 0.42, hs.y * 0.28, -hs.z * 0.55), Vector3(0.02, 0.035, 0.04), _mat(Color(0.05, 0.04, 0.03)))
	_tail = null
	_build_legs(sz, leg_h, dark, 0.3, 0.34, 0.1)


## Pecho (adelante, con el corazón: letal) y panza/ancas (atrás).
func _torso_hitboxes(sz: Vector3) -> void:
	var chest := Node3D.new()
	chest.position = Vector3(0, 0, -sz.z * 0.25)
	_torso.add_child(chest)
	_hitbox(chest, "chest", Vector3(sz.x, sz.y, sz.z * 0.5))
	var rear := Node3D.new()
	rear.position = Vector3(0, 0, sz.z * 0.25)
	_torso.add_child(rear)
	_hitbox(rear, "torso", Vector3(sz.x, sz.y, sz.z * 0.5))


func _build_legs(sz: Vector3, leg_h: float, dark: Material, kx: float, kz: float, w: float) -> void:
	for lz: float in [-1.0, 1.0]:
		for lx: float in [-1.0, 1.0]:
			var piv := Node3D.new()
			piv.position = Vector3(lx * sz.x * kx, leg_h, lz * sz.z * kz)
			_model.add_child(piv)
			var lm := _box(piv, Vector3(0, -leg_h * 0.5, 0), Vector3(w, leg_h, w * 1.1), dark)
			_hitbox(lm, "limb", Vector3(w + 0.03, leg_h, w + 0.03))
			_legs.append(piv)


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.95
	return m


func _box(parent: Node3D, pos: Vector3, size: Vector3, m: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	mi.layers = 2  # la sangre del piso no se les pinta encima
	parent.add_child(mi)
	return mi


func _hitbox(on: Node3D, zone: String, size: Vector3) -> void:
	var b := StaticBody3D.new()
	b.collision_layer = 1 << (HITBOX_LAYER - 1)
	b.collision_mask = 0
	b.set_meta("hit_zone", zone)
	b.set_meta("zone_owner", self)
	b.set_meta("surface", "flesh")
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	b.add_child(cs)
	on.add_child(b)


# --- Daño, agonía y ragdoll -----------------------------------------------------------

const ZONE_MULT := {"head": 2.4, "chest": 1.5, "torso": 0.9, "limb": 0.5}


func apply_hit(info: HitInfo) -> bool:
	if state == State.DEAD:
		# Cuerpo: el tiro lo mueve (sin ruido)
		_push_ragdoll(info.direction * clampf(info.damage * 0.12, 1.0, 8.0), info.position)
		return false
	var zone := info.zone
	var dmg := info.damage * float(ZONE_MULT.get(zone, 1.0))
	if state == State.DYING:
		# Arrastrándose: un tiro a la cabeza o al pecho (o uno fuerte) lo termina
		if zone in ["head", "chest"] or dmg > 35.0:
			_ragdoll(info)
		else:
			_dying_t *= 0.5
		return false
	hp -= dmg
	if hp <= 0.0:
		# Cabeza o corazón (o un tiro que lo deshace): cae en el acto. Si no, se arrastra.
		if zone in ["head", "chest"] or dmg > float(_d["hp"]) * 1.6:
			if zone == "head":
				Blood.spray(self, info.position, info.direction + Vector3.UP * 0.1, 35, 4.5)
			_ragdoll(info)
		else:
			_start_dying(info)
		return true
	_say({"dog": "yelp", "boar": "squeal", "capy": "squeal"}[species], true)
	var src := info.source as Node3D
	if src != null and not is_instance_valid(src):
		src = null
	var from := src.global_position if src != null else info.position - info.direction * 10.0
	match species:
		"capy":
			# Si el que le pegó está encima, muerde; si no, se va (al agua si puede)
			if src != null and src.global_position.distance_to(global_position) < CORNER_NEAR and state != State.HIDE:
				_cornered(src)
			elif state != State.HIDE:
				_danger(from)
			if pack != null and src != null:
				pack.alarm(self, src)
		"dog":
			# Cobarde: herido se abre siempre, y muchas veces se va del todo
			if src != null:
				target = src
				if pack != null:
					pack.alarm(self, src)
			if hp < float(_d["hp"]) * 0.5 or rng.randf() < 0.35 or (pack != null and pack.should_flee()):
				_flee(from)
			else:
				_retreat()
		"boar":
			# Herido se pone peor: va contra el que le tiró
			if src != null:
				target = src
				if pack != null:
					pack.alarm(self, src)
			if hp < float(_d["hp"]) * 0.2 or (pack != null and pack.should_flee()):
				_flee(from)
			elif not _charging and target != null:
				_attack()
	return false


## Herido de muerte pero no en el acto: se arrastra un rato con las patas de atrás
## muertas y cae.
func _start_dying(info: HitInfo) -> void:
	dead = true
	state = State.DYING
	_charging = false
	target = null
	_dying_t = rng.randf_range(6.0, 14.0)
	var away := global_position - (info.position - info.direction * 5.0)
	away.y = 0
	_go(_on_nav(global_position + away.normalized() * rng.randf_range(4.0, 9.0)), rng.randf_range(0.35, 0.7))
	_say({"dog": "whine", "boar": "grunt", "capy": "squeal"}[species], false)
	if pack != null:
		pack.member_died(self)


func _dying_update(delta: float) -> void:
	_dying_t -= delta
	# Arrastrándose: un rastro de sangre
	if global_position.distance_to(_last_blood) > 0.6:
		_last_blood = global_position
		Blood.stain(self, global_position + Vector3(rng.randf_range(-0.15, 0.15), 0, rng.randf_range(-0.15, 0.15)), rng.randf_range(0.18, 0.4))
	if _dying_t <= 0.0:
		_ragdoll(null)
	elif _arrived():
		_move_to = Vector3.INF


## Cae muerto: el cuerpo pasa a ser de física (tronco, cabeza y patas con bisagras),
## así queda apoyado sobre el piso como corresponde. Muerto no hace más ruido.
func _ragdoll(info: HitInfo) -> void:
	var was_dying := state == State.DYING
	dead = true
	state = State.DEAD
	_charging = false
	_voice.stop()
	remove_from_group("animals")
	add_to_group("animal_corpses")
	collision_layer = 0
	collision_mask = 0
	if not was_dying and pack != null:
		pack.member_died(self)
	var mass := float(_d["mass"])
	var vel := velocity
	velocity = Vector3.ZERO
	var tb := _rb(_torso, (_torso.mesh as BoxMesh).size, mass * 0.7)
	_model.reparent(tb, true)
	var hb := _rb(_head_mesh, (_head_mesh.mesh as BoxMesh).size, mass * 0.12)
	_head.reparent(hb, true)
	var neck := PinJoint3D.new()
	add_child(neck)
	neck.top_level = true
	neck.global_position = _head.global_position
	neck.node_a = neck.get_path_to(tb)
	neck.node_b = neck.get_path_to(hb)
	for piv in _legs:
		var lm := piv.get_child(0) as MeshInstance3D
		var lb := _rb(lm, (lm.mesh as BoxMesh).size, mass * 0.045)
		piv.reparent(lb, true)
		var hj := HingeJoint3D.new()
		add_child(hj)
		hj.top_level = true
		# Bisagra en la cadera, eje de costado del cuerpo
		hj.global_transform = Transform3D(Basis(tb.global_basis.z, tb.global_basis.y, tb.global_basis.x), piv.global_position)
		hj.set_flag(HingeJoint3D.FLAG_USE_LIMIT, true)
		hj.set_param(HingeJoint3D.PARAM_LIMIT_LOWER, deg_to_rad(-70.0))
		hj.set_param(HingeJoint3D.PARAM_LIMIT_UPPER, deg_to_rad(70.0))
		hj.node_a = hj.get_path_to(tb)
		hj.node_b = hj.get_path_to(lb)
	for b in _rag:
		b.linear_velocity = vel
	# Charco debajo (más rápido si fue a la cabeza)
	var head_shot := info != null and info.zone == "head"
	get_tree().create_timer(1.0, false).timeout.connect(func() -> void:
		if is_inside_tree() and not _rag.is_empty():
			var at := hb.global_position if head_shot else tb.global_position
			Blood.pool(self, at, float((_d["size"] as Vector3).z) * (0.7 if head_shot else 0.8), 4.0 if head_shot else 10.0))
	if info != null:
		var imp := info.direction.normalized() * clampf(info.damage * 0.2, 2.0, 14.0)
		_push_ragdoll(imp, info.position)
	else:
		# Se desploma de costado
		tb.apply_torque_impulse(tb.global_basis.z * (1.0 if rng.randf() < 0.5 else -1.0) * mass * 0.35)


func _rb(mesh: MeshInstance3D, size: Vector3, mass: float) -> RigidBody3D:
	var b := RigidBody3D.new()
	b.collision_layer = 1 << (RAGDOLL_LAYER - 1)
	b.collision_mask = 1
	b.mass = maxf(mass, 0.5)
	b.linear_damp = 0.4
	b.angular_damp = 1.5
	b.set_meta("zone_owner", self)
	b.set_meta("surface", "flesh")
	var pm := PhysicsMaterial.new()
	pm.friction = 0.9
	pm.bounce = 0.0
	b.physics_material_override = pm
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	b.add_child(cs)
	add_child(b)
	b.top_level = true
	b.global_transform = mesh.global_transform.orthonormalized()
	_rag.append(b)
	return b


func _push_ragdoll(impulse: Vector3, at: Vector3) -> void:
	if _rag.is_empty():
		return
	var tb := _rag[0]
	for b in _rag:
		b.freeze = false
	_rag_still = 0.0
	_dead_t = minf(_dead_t, 1.0)
	tb.apply_impulse(impulse, at - tb.global_position if at != Vector3.ZERO else Vector3.ZERO)


func _ragdoll_update(delta: float) -> void:
	if _rag.is_empty() or _rag[0].freeze:
		return
	var moving := false
	for b in _rag:
		if b.linear_velocity.length() > 0.12 or b.angular_velocity.length() > 0.4:
			moving = true
			break
	_rag_still = 0.0 if moving else _rag_still + delta
	# Quieto un rato (o mucho tiempo dando vueltas): se congela, no gasta física
	if (_rag_still > 0.8 and _dead_t > 1.0) or _dead_t > 10.0:
		for b in _rag:
			b.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
			b.freeze = true


## Centro del cuerpo (vivo o caído).
func center() -> Vector3:
	if not _rag.is_empty():
		return _rag[0].global_position
	return global_position + Vector3(0, float(_d["leg"]) + 0.2, 0)


# --- Cuerear --------------------------------------------------------------------------

func get_interact_text() -> String:
	if state != State.DEAD or skinned:
		return ""
	return "animal.skin_hint"


func interact(who: Node) -> void:
	var p := who as Player
	if p == null or state != State.DEAD or skinned:
		return
	if p.inventory == null or p.inventory.equipment.get("melee") == null:
		EventBus.toast.emit(tr("animal.need_knife"))
		return
	skinned = true
	var cut := Animal.sound("knife", "cut", rng)
	if cut != null:
		CombatWorld.get_for(self).play_sound_at(cut, center(), -4.0)
	if rng.randf() >= SKIN_CHANCE:
		EventBus.toast.emit(tr("animal.no_hide"))
		return
	var s := ItemStack.make("hide_" + species, 1)
	if p.inventory.receive(s) > 0:
		WorldItem.spawn(get_parent(), s, center() + Vector3(0, 0.3, 0))
		EventBus.toast.emit(tr("animal.got_hide_floor") % tr(s.item.name_key))
	else:
		EventBus.toast.emit(tr("animal.got_hide") % tr(s.item.name_key))


# --- IA -------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		_dead_t += delta
		_ragdoll_update(delta)
		if _dead_t > 600.0:
			queue_free()
		return
	_t -= delta
	_hit_cd -= delta
	_voice_t -= delta
	match state:
		State.WANDER:
			_wander(delta)
		State.ALERT:
			_alert(delta)
		State.ATTACK:
			_attack_update(delta)
		State.RETREAT:
			_retreat_update(delta)
		State.FLEE:
			_flee_update(delta)
		State.HIDE:
			_hide_update(delta)
		State.DYING:
			_dying_update(delta)
	if state == State.DEAD:
		return
	_move(delta)
	_animate(delta)


func _player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player


## Personas (vos y los enemigos) vivas.
func _humans() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for n in get_tree().get_nodes_in_group("player"):
		if not (n as Player).is_dead:
			out.append(n)
	for n in get_tree().get_nodes_in_group("ai_npc"):
		if not (n as HumanNpc).dead:
			out.append(n)
	return out


## La persona más cerca que ve o huele (o null).
func _noticed_human() -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for h in _humans():
		var d := h.global_position.distance_to(global_position)
		if d < best_d and d < float(_d["sight"]) + 2.0 and _notices(h):
			best_d = d
			best = h
	return best


func _nearest_human_dist() -> Array:
	var best: Node3D = null
	var best_d := INF
	for h in _humans():
		var d := h.global_position.distance_to(global_position)
		if d < best_d:
			best_d = d
			best = h
	return [best, best_d]


func _target_alive() -> bool:
	if target == null or not is_instance_valid(target):
		return false
	if target is Player:
		return not (target as Player).is_dead
	if target is HumanNpc:
		return not (target as HumanNpc).dead
	return true


## ¿Lo ve o lo huele?
func _notices(p: Node3D) -> bool:
	if p == null:
		return false
	var crouched := p is Player and (p as Player).stance == Player.Stance.CROUCHING
	var pv: Vector3 = (p as CharacterBody3D).velocity if p is CharacterBody3D else Vector3.ZERO
	var to := p.global_position - global_position
	var d := to.length()
	if d < float(_d["smell"]) * (0.6 if crouched else 1.0):
		return true
	if d > float(_d["sight"]):
		return false
	var fwd := Vector3(-sin(_yaw), 0, -cos(_yaw))
	if rad_to_deg(fwd.angle_to(Vector3(to.x, 0, to.z))) > float(_d["fov"]):
		return false
	# Agachado y quieto en el pasto, de lejos, pasa
	if crouched and Vector2(pv.x, pv.z).length() < 0.5 and d > float(_d["sight"]) * 0.45:
		return false
	var eye := global_position + Vector3(0, float(_d["leg"]) + 0.4, 0)
	var q := PhysicsRayQueryParameters3D.create(eye, p.global_position + Vector3(0, 1.0, 0), 1 | (1 << 8))
	q.exclude = [get_rid()]
	if p is CollisionObject3D:
		q.exclude.append((p as CollisionObject3D).get_rid())
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## Jabalí: ¿está en su lugar?
func _in_territory(p: Vector3) -> bool:
	var tr_r := float(_d["territory"])
	if tr_r <= 0.0 or pack == null:
		return false
	return Vector2(p.x - pack.home.x, p.z - pack.home.z).length() < tr_r


func _wander(delta: float) -> void:
	var p := _noticed_human()
	if p != null:
		target = p
		if species == "boar" and (_in_territory(p.global_position) or p.global_position.distance_to(global_position) < 14.0):
			# Se metió en su lugar (o se le vino encima): directo a embestir
			if pack != null:
				pack.alarm(self, p)
			_attack()
			return
		if pack != null:
			pack.alarm(self, p)
		else:
			_alert_on(p)
		return
	# Perros: a veces se corren entre ellos en círculos
	if _antic_t > 0.0:
		_antic_t -= delta
		_orbit_ang += _orbit_dir * float(_d["trot"]) * 1.2 / _orbit_r * delta
		var home := pack.home if pack != null else global_position
		_go(home + Vector3(sin(_orbit_ang), 0, cos(_orbit_ang)) * _orbit_r, float(_d["trot"]) * 1.2)
		if _antic_t <= 0.0:
			_t = 0.0
		return
	if _t <= 0.0:
		var r0 := rng.randf()
		if species == "dog" and r0 < 0.15:
			_antic_t = rng.randf_range(3.0, 6.0)
			_orbit_r = rng.randf_range(3.0, 6.0)
			_orbit_dir = -1.0 if rng.randf() < 0.5 else 1.0
			if rng.randf() < 0.5:
				_say("bark", false)
			return
		# Otro lugar cerca de la querencia (o se queda olfateando un rato)
		if r0 < 0.45:
			_move_to = Vector3.INF
			_t = rng.randf_range(2.0, 6.0)
		else:
			var home := pack.home if pack != null else global_position
			var r := pack.roam if pack != null else 15.0
			var off := Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized() * rng.randf_range(2.0, r)
			_go(home + off, float(_d["walk"]) if rng.randf() < 0.7 else float(_d["trot"]))
			_t = rng.randf_range(5.0, 12.0)
	if _voice_t <= 0.0:
		_voice_t = rng.randf_range(6.0, 16.0)
		if rng.randf() < 0.4:
			_say({"dog": "pant", "boar": "grunt", "capy": "click"}[species], false)


## Lo vio: lo mira, gruñe o ladra, y enseguida se larga (el carpincho, al agua).
func _alert_on(t: Node3D) -> void:
	target = t
	if species == "capy":
		_say("bark", true)
		_danger(t.global_position)
		return
	state = State.ALERT
	_move_to = Vector3.INF
	_antic_t = 0.0
	# El jabalí casi no duda
	_t = rng.randf_range(0.6, 2.2) if species == "dog" else rng.randf_range(0.2, 0.7)
	_say("growl" if species == "dog" and rng.randf() < 0.5 else ("bark" if species == "dog" else "snort"), true)


func _alert(_delta: float) -> void:
	if not _target_alive():
		_calm()
		return
	_face(target.global_position)
	if _voice_t <= 0.0:
		_voice_t = rng.randf_range(0.8, 1.6)
		_say("bark" if species == "dog" else "snort", true)
	if _t <= 0.0:
		var d := global_position.distance_to(target.global_position)
		if species == "boar" and d > 18.0 and not _in_territory(target.global_position) and rng.randf() > float(_d["courage"]):
			_flee(target.global_position)
		else:
			_attack()


func _attack() -> void:
	if not _target_alive():
		_calm()
		return
	state = State.ATTACK
	_antic_t = 0.0
	var hr: Array = _d["hits"]
	_hits_left = rng.randi_range(int(hr[0]), int(hr[1]))
	_charging = false
	if species == "boar":
		_start_charge()
	elif species == "dog":
		_circle()


## Perro: da vueltas alrededor ladrando antes de tirarse.
func _circle() -> void:
	_mode = "circle"
	var to := global_position - target.global_position
	_orbit_ang = atan2(to.x, to.z)
	_orbit_r = rng.randf_range(5.0, 9.0)
	_t = rng.randf_range(1.5, 4.5)
	if rng.randf() < 0.3:
		_orbit_dir = -_orbit_dir


func _start_charge() -> void:
	_charging = true
	_charge_locked = false
	var to := target.global_position - global_position
	to.y = 0
	_charge_dir = to.normalized() if to.length() > 0.1 else Vector3(-sin(_yaw), 0, -cos(_yaw))
	_t = 8.0
	_speed = float(_d["run"])
	_say("squeal" if rng.randf() < 0.3 else "snort", true)


## Puede alcanzar al blanco (no está subido a algo).
func _reachable(tp: Vector3) -> bool:
	var dy := tp.y - global_position.y
	return dy < float(_d["reach_up"]) and dy > -1.0


func _attack_update(delta: float) -> void:
	if not _target_alive():
		_calm()
		return
	var tp := target.global_position
	var d := Vector2(tp.x - global_position.x, tp.z - global_position.z).length()
	match species:
		"capy":
			# Acorralado: muerde y en cuanto puede se va
			_go(tp, float(_d["trot"]))
			_face(tp)
			if d < float(_d["reach"]) and _reachable(tp) and _hit_cd <= 0.0:
				_bite()
			if _hits_left <= 0 or _t <= 0.0:
				_danger(tp)
		"boar":
			_charge_update(delta, tp, d)
		_:
			_dog_attack(delta, tp, d)


## Embestida: lo sigue (con giro limitado) hasta CHARGE_LOCK; de ahí en más va derecho:
## si te corrés al costado en el último momento, pasa de largo.
func _charge_update(delta: float, tp: Vector3, d: float) -> void:
	if not _reachable(tp):
		# Subido a algo: da vueltas abajo bufando y al rato se cansa
		_unreach_t += delta
		_charging = false
		_go(tp, float(_d["trot"]))
		if _voice_t <= 0.0:
			_voice_t = rng.randf_range(1.0, 2.0)
			_say("snort", true)
		if _unreach_t > 12.0:
			_unreach_t = 0.0
			_retreat()
		return
	_unreach_t = 0.0
	if not _charging:
		_start_charge()
	if not _charge_locked:
		var want := Vector3(tp.x - global_position.x, 0, tp.z - global_position.z).normalized()
		var ang := _charge_dir.signed_angle_to(want, Vector3.UP)
		_charge_dir = _charge_dir.rotated(Vector3.UP, clampf(ang, -CHARGE_TURN * delta, CHARGE_TURN * delta))
		if d < CHARGE_LOCK:
			_charge_locked = true
	_speed = float(_d["run"])
	if d < float(_d["reach"]) and _hit_cd <= 0.0:
		_bite()
	# Pasó de largo (o se dio contra algo): frena, da la vuelta y vuelve
	var ahead := _charge_dir.dot(Vector3(tp.x - global_position.x, 0, tp.z - global_position.z).normalized())
	if _charge_locked and (d > CHARGE_LOCK + 5.0 or (ahead < -0.3 and d > 4.0)):
		_charging = false
		_retreat()
	elif is_on_wall() or _t <= 0.0:
		_charging = false
		_retreat()


func _dog_attack(delta: float, tp: Vector3, d: float) -> void:
	var reach_ok := _reachable(tp)
	if not reach_ok:
		_unreach_t += delta
		if _unreach_t > 15.0:
			# No llega: se cansa y se va a otra parte
			_unreach_t = 0.0
			_flee(tp)
			return
		if _mode != "circle":
			_circle()
	else:
		_unreach_t = maxf(0.0, _unreach_t - delta)
	if _voice_t <= 0.0:
		_voice_t = rng.randf_range(0.5, 1.3)
		_say("growl" if d < 4.0 else "bark", true)
	match _mode:
		"circle":
			_orbit_ang += _orbit_dir * float(_d["run"]) * 0.6 / _orbit_r * delta
			_go(tp + Vector3(sin(_orbit_ang), 0, cos(_orbit_ang)) * _orbit_r, float(_d["run"]) * 0.65)
			if _t <= 0.0 and reach_ok:
				if pack == null or pack.can_dart(self):
					_mode = "feint" if rng.randf() < 0.3 else "dart"
					_t = 4.0
				else:
					_t = rng.randf_range(0.8, 2.0)
		"dart", "feint":
			_go(tp, float(_d["run"]))
			if _mode == "feint" and d < 3.0:
				_retreat()
				return
			if d < float(_d["reach"]):
				_face(tp)
				if _hit_cd <= 0.0 and reach_ok:
					_bite()
			if _hits_left <= 0 or _t <= 0.0:
				_retreat()
		_:
			_circle()


## Muerde (perro, carpincho) o te lleva puesto (jabalí).
func _bite() -> void:
	_hit_cd = float(_d["hit_gap"])
	_hits_left -= 1
	var dr: Array = _d["dmg"]
	var info := HitInfo.new()
	info.damage = rng.randf_range(float(dr[0]), float(dr[1]))
	info.weapon_id = "melee"
	info.source = self
	var tp := target.global_position
	info.direction = (tp - global_position).normalized()
	# Perros y carpinchos van a las piernas y los brazos; el jabalí, piernas y cuerpo
	var limb := rng.randf() < (0.5 if species == "boar" else 0.75)
	info.zone = "limb" if limb else "torso"
	info.position = tp + Vector3(0, 0.5 if limb else 1.1, 0)
	info.distance = 1.0
	if target.has_method("apply_hit"):
		target.call("apply_hit", info)
	var push := float(_d["push"])
	if push > 0.0 and target is CharacterBody3D:
		var pd := info.direction
		pd.y = 0
		(target as CharacterBody3D).velocity += pd.normalized() * push + Vector3.UP * push * 0.35
	_say({"dog": "growl", "boar": "grunt", "capy": "bark"}[species], true)


## Se abre corriendo para un lado cualquiera (más o menos lejos de vos) y vuelve.
func _retreat() -> void:
	state = State.RETREAT
	_charging = false
	_mode = ""
	if pack != null:
		pack.dart_done(self)
	var away := global_position - (target.global_position if _target_alive() else global_position + Vector3.FORWARD)
	away.y = 0
	var base := atan2(away.x, away.z) if away.length() > 0.1 else rng.randf() * TAU
	var ang := base + rng.randf_range(-1.3, 1.3)
	var rr: Array = _d["retreat"]
	var dist := rng.randf_range(float(rr[0]), float(rr[1]))
	var dest := global_position + Vector3(sin(ang), 0, cos(ang)) * dist
	_go(_on_nav(dest), float(_d["run"]) * rng.randf_range(0.8, 1.0))
	_t = dist / float(_d["run"]) + (rng.randf_range(0.2, 1.0) if species == "boar" else rng.randf_range(0.5, 2.5))


func _retreat_update(_delta: float) -> void:
	if not _target_alive():
		_calm()
		return
	if _t <= 0.0 or _arrived():
		if pack != null and pack.should_flee():
			_flee(target.global_position)
		else:
			_face(target.global_position)
			_attack()


func _flee(from: Vector3) -> void:
	state = State.FLEE
	_charging = false
	_mode = ""
	if pack != null:
		pack.dart_done(self)
	_flee_from = from
	var away := global_position - from
	away.y = 0
	if away.length() < 0.1:
		away = Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1))
	var ang := atan2(away.x, away.z) + rng.randf_range(-0.6, 0.6)
	_go(_on_nav(global_position + Vector3(sin(ang), 0, cos(ang)) * rng.randf_range(45.0, 70.0)), float(_d["run"]))
	_t = rng.randf_range(10.0, 16.0)
	_say({"dog": "whine", "boar": "squeal", "capy": "squeal"}[species], true)


func _flee_update(_delta: float) -> void:
	if species == "capy":
		var nh: Array = _nearest_human_dist()
		# Le cerraste el paso (o te le tiraste encima): muerde
		if nh[0] != null and (float(nh[1]) < CORNER_DIST or (_stuck_t > 0.5 and float(nh[1]) < CORNER_NEAR)):
			_cornered(nh[0])
			return
		if _water_target != Vector3.INF and _in_deep_water():
			_dive()
			return
	if _t <= 0.0 or _arrived():
		# Lejos y tranquilo: esa es su nueva querencia
		if pack != null:
			pack.home = global_position
		_calm()


func _calm() -> void:
	state = State.WANDER
	target = null
	_charging = false
	_mode = ""
	_unreach_t = 0.0
	_t = rng.randf_range(1.0, 3.0)
	_go(global_position, float(_d["walk"]))


# --- Carpincho: acorralado, peligro y agua ------------------------------------------

func _cornered(who: Node3D) -> void:
	target = who
	state = State.ATTACK
	_charging = false
	_hits_left = rng.randi_range(1, 2)
	_hit_cd = 0.2
	_t = 2.5
	_say("bark", true)


## Peligro: al agua honda más cercana (si hay) y abajo; si no, lejos.
func _danger(from: Vector3) -> void:
	var w := _find_water(from)
	if w == Vector3.INF:
		_water_target = Vector3.INF
		_flee(from)
		return
	state = State.FLEE
	_charging = false
	_flee_from = from
	_water_target = w
	_go(w, float(_d["run"]))
	_t = global_position.distance_to(w) / float(_d["run"]) + 6.0
	_say("bark", true)


func _level() -> Node:
	var n: Node = get_parent()
	while n != null and not n.has_method("water_level"):
		n = n.get_parent()
	return n


func _in_deep_water() -> bool:
	var lvl := _level()
	if lvl == null:
		return false
	var wl := float(lvl.call("water_level"))
	return global_position.y < wl - float(_d["leg"]) - float((_d["size"] as Vector3).y) - 0.1


## Agua honda (que lo tape) más cercana, sin ir para el lado del peligro.
func _find_water(from: Vector3) -> Vector3:
	var lvl := _level()
	if lvl == null:
		return Vector3.INF
	var wl := float(lvl.call("water_level"))
	var deep := wl - float(_d["leg"]) - float((_d["size"] as Vector3).y) - 0.35
	var best := Vector3.INF
	var best_score := INF
	for ring in range(1, 11):
		var r := ring * 7.0
		for i in 16:
			var a := TAU * i / 16.0
			var p := global_position + Vector3(sin(a), 0, cos(a)) * r
			var h := float(lvl.call("height", p.x, p.z))
			if h > deep:
				continue
			if lvl.has_method("swimmable") and not bool(lvl.call("swimmable", p.x, p.z)):
				continue
			var toward := (p - global_position).normalized().dot((from - global_position).normalized())
			var score := r * (1.0 + maxf(0.0, toward) * 1.5)
			if score < best_score:
				best_score = score
				best = Vector3(p.x, h, p.z)
		if best != Vector3.INF and ring >= 2:
			break
	return best


## Se queda abajo del agua quieto un rato.
func _dive() -> void:
	state = State.HIDE
	_move_to = Vector3.INF
	_charging = false
	_hide_t = rng.randf_range(20.0, 40.0)
	velocity = Vector3.ZERO


func _hide_update(delta: float) -> void:
	_hide_t -= delta
	if _hide_t > 0.0:
		return
	# Sale si no hay nadie cerca; si no, aguanta un poco más
	var nh: Array = _nearest_human_dist()
	if nh[0] != null and float(nh[1]) < 18.0:
		_hide_t = rng.randf_range(6.0, 12.0)
		return
	_water_target = Vector3.INF
	state = State.WANDER
	target = null
	if pack != null:
		_go(pack.home, float(_d["walk"]) * 1.5)
	_t = rng.randf_range(15.0, 25.0)


func is_hidden() -> bool:
	return state == State.HIDE


func _on_noise(pos: Vector3, radius: float, source: Node) -> void:
	if dead or state in [State.ATTACK, State.RETREAT, State.FLEE, State.HIDE]:
		return
	if source == self or source is Animal:
		return
	var d := global_position.distance_to(pos)
	if d > radius * 0.8:
		return
	var shooter := source as Node3D
	var human := shooter is Player or shooter is HumanNpc
	match species:
		"capy":
			if radius >= 20.0 and d < 70.0:
				_danger(pos)
		"boar":
			# Un tiro a media distancia: van para donde está el que tiró (y si lo ven,
			# lo embisten). Solo de muy lejos, a veces se van.
			if radius >= 40.0:
				if human and d < 75.0:
					if pack != null:
						pack.alarm(self, shooter)
					else:
						_alert_on(shooter)
				elif rng.randf() > 0.5:
					_flee(pos)
		_:
			if radius >= 40.0 and (not human or d > 50.0 or rng.randf() > float(_d["courage"]) + 0.3):
				_flee(pos)
			elif human:
				if pack != null:
					pack.alarm(self, shooter)
				else:
					_alert_on(shooter)


# --- Movimiento -----------------------------------------------------------------------

func _go(p: Vector3, speed: float) -> void:
	_move_to = p
	_speed = speed


func _arrived() -> bool:
	if _move_to == Vector3.INF:
		return true
	var d := _move_to - global_position
	d.y = 0
	return d.length() < 1.2 or (agent.is_navigation_finished() and d.length() < 3.0)


func _on_nav(p: Vector3) -> Vector3:
	var map := get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(map) == 0:
		return p
	return NavigationServer3D.map_get_closest_point(map, p)


func _face(p: Vector3) -> void:
	var to := p - global_position
	if Vector2(to.x, to.z).length() > 0.05:
		_yaw = lerp_angle(_yaw, atan2(-to.x, -to.z), 0.25)


func _move(delta: float) -> void:
	var hv := Vector3.ZERO
	if _charging:
		hv = _charge_dir * _speed
	elif _move_to != Vector3.INF and state != State.HIDE:
		var nav_ok := NavigationServer3D.map_get_iteration_id(get_world_3d().navigation_map) > 0
		var next := _move_to
		if nav_ok:
			if agent.target_position.distance_to(_move_to) > 0.5:
				agent.target_position = _move_to
			if not agent.is_navigation_finished():
				next = agent.get_next_path_position()
		var dd := next - global_position
		dd.y = 0
		if dd.length() > 0.3 and not _arrived():
			hv = dd.normalized() * _speed
	var vy := velocity.y
	vy = vy - 9.8 * delta if not is_on_floor() else minf(vy, 0.0)
	var acc := 9.0 if species == "dog" else (5.5 if species == "boar" else 6.0)
	velocity = velocity.lerp(Vector3(hv.x, vy, hv.z), 1.0 - exp(-acc * delta))
	velocity.y = vy
	move_and_slide()
	var hs := Vector2(velocity.x, velocity.z)
	if hs.length() > 0.4 and state != State.ALERT:
		_yaw = lerp_angle(_yaw, atan2(-hs.x, -hs.y), 1.0 - exp(-10.0 * delta))
	_model.rotation.y = _yaw
	# Trabado (contra algo): corta y elige otra cosa
	if hv.length() > 0.5 and global_position.distance_to(_last_pos) < hv.length() * delta * 0.15:
		_stuck_t += delta
		if _stuck_t > 1.0 and species != "capy":
			_stuck_t = 0.0
			_charging = false
			if state == State.ATTACK:
				_retreat()
			elif state == State.RETREAT:
				_attack()
			elif state == State.WANDER:
				_t = 0.0
				_antic_t = 0.0
	else:
		_stuck_t = maxf(0.0, _stuck_t - delta)
	_last_pos = global_position


func _animate(delta: float) -> void:
	var hs := Vector2(velocity.x, velocity.z).length()
	var stride := float(_d["leg"]) * 2.6
	var dphase := hs / stride * TAU * delta
	_phase += dphase
	if state == State.DYING:
		# Se arrastra: patas de atrás muertas, adelante tirando, cuerpo caído de costado
		for i in _legs.size():
			_legs[i].rotation.x = (sin(_phase * 1.6) * 0.7 if i < 2 else 1.3)
		_model.rotation.z = lerpf(_model.rotation.z, 0.25, 1.0 - exp(-2.0 * delta))
		_model.rotation.x = lerpf(_model.rotation.x, 0.12, 1.0 - exp(-2.0 * delta))
		_model.position.y = lerpf(_model.position.y, -float(_d["leg"]) * 0.45, 1.0 - exp(-2.0 * delta))
		if _head != null:
			_head.rotation.x = lerpf(_head.rotation.x, -0.5, 1.0 - exp(-2.0 * delta))
		return
	if state == State.HIDE:
		return
	var amp := clampf(hs / float(_d["trot"]), 0.0, 1.0) * (0.55 if hs < float(_d["trot"]) * 1.3 else 0.8)
	var gallop := hs > float(_d["trot"]) * 1.3
	for i in _legs.size():
		# Al paso/trote: diagonales juntas; al galope: delanteras y traseras juntas
		var off := 0.0
		if gallop:
			off = 0.0 if i < 2 else PI * 0.8
		else:
			off = 0.0 if i in [0, 3] else PI
		_legs[i].rotation.x = sin(_phase + off) * amp
	_model.position.y = absf(sin(_phase)) * 0.03 * amp if not gallop else sin(_phase) * 0.06
	_model.rotation.x = sin(_phase) * 0.06 * amp if gallop else 0.0
	if _tail != null:
		var wag := 0.5 if state == State.WANDER and species == "dog" else 0.1
		_tail.rotation.y = sin(Time.get_ticks_msec() * 0.012) * wag
	if _head != null:
		# Olfatea con la cabeza baja cuando anda tranquilo
		var low := state == State.WANDER and hs < 0.6
		_head.rotation.x = lerpf(_head.rotation.x, -0.45 if low else 0.0, 1.0 - exp(-3.0 * delta))
	# Pasos (patas: suaves, más fuerte al galope)
	if is_on_floor() and hs > 2.5 and int(_phase / PI) != int((_phase - dphase) / PI):
		var st := Foley.step("dirt")
		if st != null:
			_steps.stream = st
			_steps.pitch_scale = 1.5 if species == "dog" else 1.1
			_steps.volume_db = -14.0 if species == "dog" else -8.0
			_steps.play()


# --- Sonido ---------------------------------------------------------------------------

static var _sounds: Dictionary = {}


static func sound(species_id: String, kind: String, r: RandomNumberGenerator) -> AudioStream:
	var key := species_id + "_" + kind
	if not _sounds.has(key):
		var list: Array = []
		for i in 8:
			var path := "res://assets/audio/animals/%s_%d.wav" % [key, i]
			if ResourceLoader.exists(path):
				list.append(load(path))
		_sounds[key] = list
	var l: Array = _sounds[key]
	return null if l.is_empty() else l[r.randi() % l.size()]


func _say(kind: String, loud: bool) -> void:
	if state == State.DEAD:
		return
	var s := Animal.sound(species, kind, rng)
	if s == null:
		return
	_voice.stream = s
	_voice.volume_db = (0.0 if loud else -8.0) + (-10.0 if state == State.DYING else 0.0)
	_voice.pitch_scale = rng.randf_range(0.92, 1.08) * (0.85 if species == "boar" else 1.0)
	_voice.position = Vector3(0, float(_d["leg"]) + 0.3, -float((_d["size"] as Vector3).z) * 0.5)
	_voice.play()
	_voice_t = maxf(_voice_t, 0.5)
