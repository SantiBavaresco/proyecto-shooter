class_name Animal
extends CharacterBody3D
## Animal salvaje (perro cimarrón, jabalí). Andan en grupo (AnimalPack) dando vueltas
## por su zona. Cuando te ven, te huelen o los asustás, atacan "de a golpes": se tiran
## encima, muerden o embisten, y se abren corriendo para cualquier lado para volver a
## entrar. Si el grupo pierde a la mitad o están muy heridos, se van.
##
## El cuerpo está hecho por código (cajas y cilindros) con patas que se mueven: es
## provisorio hasta tener modelos.

const HITBOX_LAYER := 6
const BODY_LAYER := 5

enum State { WANDER, ALERT, ATTACK, RETREAT, FLEE, DEAD }

## Datos de cada especie.
const SPECIES := {
	"dog": {
		"hp": 55.0, "walk": 1.4, "trot": 3.2, "run": 8.5, "size": Vector3(0.36, 0.42, 0.95),
		"leg": 0.42, "sight": 38.0, "smell": 14.0, "fov": 120.0,
		"dmg": [7.0, 13.0], "reach": 1.35, "hit_gap": 0.75, "hits": [1, 3], "push": 0.0,
		"retreat": [9.0, 18.0], "courage": 0.5, "pack": [3, 5],
		"colors": [Color(0.36, 0.25, 0.16), Color(0.12, 0.11, 0.1), Color(0.62, 0.5, 0.33), Color(0.4, 0.4, 0.38)],
	},
	"boar": {
		"hp": 150.0, "walk": 1.0, "trot": 2.4, "run": 7.4, "size": Vector3(0.5, 0.62, 1.25),
		"leg": 0.3, "sight": 24.0, "smell": 10.0, "fov": 100.0,
		"dmg": [16.0, 26.0], "reach": 1.3, "hit_gap": 1.4, "hits": [1, 1], "push": 7.0,
		"retreat": [7.0, 14.0], "courage": 0.65, "pack": [3, 4],
		"colors": [Color(0.2, 0.16, 0.13), Color(0.27, 0.21, 0.16), Color(0.16, 0.14, 0.13)],
	},
}

@export var species: String = "dog"
var pack: AnimalPack = null
var state: State = State.WANDER
var hp: float = 55.0
var dead: bool = false
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
var _voice_t: float = 0.0
var _phase: float = 0.0
var _yaw: float = 0.0
var _hurt_t: float = 99.0
var _stuck_t: float = 0.0
var _last_pos := Vector3.ZERO
var _dead_t: float = 0.0
var _flee_from := Vector3.ZERO

var agent: NavigationAgent3D
var _model: Node3D
var _legs: Array[Node3D] = []
var _head: Node3D
var _tail: Node3D
var _voice: AudioStreamPlayer3D
var _steps: AudioStreamPlayer3D


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
	var boar := species == "boar"
	# Tronco (más alto adelante en el jabalí: la "joroba" de la cruz)
	var torso := _box(_model, Vector3(0, leg_h + sz.y * 0.5, 0), Vector3(sz.x, sz.y, sz.z), m)
	if boar:
		_box(_model, Vector3(0, leg_h + sz.y * 0.85, -sz.z * 0.22), Vector3(sz.x * 0.85, sz.y * 0.45, sz.z * 0.45), dark)
		# Cresta de cerdas por el lomo
		_box(_model, Vector3(0, leg_h + sz.y * 1.08, -sz.z * 0.1), Vector3(0.06, 0.1, sz.z * 0.7), dark)
	_hitbox(torso, "torso", Vector3(sz.x, sz.y, sz.z))
	# Cabeza (adelante = -Z)
	_head = Node3D.new()
	_head.position = Vector3(0, leg_h + sz.y * (0.75 if not boar else 0.55), -sz.z * 0.5)
	_model.add_child(_head)
	var hs := Vector3(sz.x * 0.8, sz.y * 0.62, sz.z * 0.3) if not boar else Vector3(sz.x * 0.8, sz.y * 0.7, sz.z * 0.32)
	var hb := _box(_head, Vector3(0, 0, -hs.z * 0.5), hs, m)
	_hitbox(hb, "head", hs)
	# Hocico
	var sn := Vector3(hs.x * 0.55, hs.y * 0.5, hs.z * 0.9) if not boar else Vector3(hs.x * 0.6, hs.y * 0.55, hs.z * 1.3)
	_box(_head, Vector3(0, -hs.y * 0.2, -hs.z - sn.z * 0.5), sn, dark)
	if boar:
		# Disco del hocico y colmillos
		_box(_head, Vector3(0, -hs.y * 0.2, -hs.z - sn.z - 0.01), Vector3(sn.x * 0.9, sn.y * 0.9, 0.02), _mat(Color(0.35, 0.25, 0.25)))
		for sx: float in [-1.0, 1.0]:
			_box(_head, Vector3(sx * sn.x * 0.55, -hs.y * 0.15, -hs.z - sn.z * 0.7), Vector3(0.025, 0.09, 0.025), _mat(Color(0.9, 0.87, 0.78)), Vector3(0.4, 0, sx * 0.4))
	# Orejas
	for sx: float in [-1.0, 1.0]:
		if boar:
			_box(_head, Vector3(sx * hs.x * 0.4, hs.y * 0.55, -hs.z * 0.2), Vector3(0.08, 0.13, 0.04), dark, Vector3(0, 0, sx * 0.4))
		else:
			_box(_head, Vector3(sx * hs.x * 0.32, hs.y * 0.62, -hs.z * 0.3), Vector3(0.07, 0.15, 0.05), dark, Vector3(-0.15, 0, sx * 0.15))
	# Cola
	_tail = Node3D.new()
	_tail.position = Vector3(0, leg_h + sz.y * 0.8, sz.z * 0.5)
	_model.add_child(_tail)
	var tl := 0.32 if not boar else 0.18
	_box(_tail, Vector3(0, 0, tl * 0.5), Vector3(0.06, 0.06, tl), dark, Vector3(-0.5, 0, 0))
	# Patas: un pivote en la cadera/hombro cada una
	for lz: float in [-1.0, 1.0]:
		for lx: float in [-1.0, 1.0]:
			var piv := Node3D.new()
			piv.position = Vector3(lx * sz.x * 0.32, leg_h, lz * sz.z * 0.38)
			_model.add_child(piv)
			_box(piv, Vector3(0, -leg_h * 0.5, 0), Vector3(0.09 if not boar else 0.11, leg_h, 0.1), dark)
			_hitbox(piv.get_child(0), "limb", Vector3(0.12, leg_h, 0.12))
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


# --- Daño -----------------------------------------------------------------------------

func apply_hit(info: HitInfo) -> bool:
	if dead:
		return false
	var mult := {"head": 2.2, "torso": 1.0, "limb": 0.55}.get(info.zone, 1.0) as float
	var dmg := info.damage * mult
	hp -= dmg
	_hurt_t = 0.0
	if hp <= 0.0:
		_die(info)
		return true
	_say("yelp" if species == "dog" else "squeal", true)
	# Te pegué: si viene de vos te tienen ubicado
	var src := info.source as Node3D
	if src != null and is_instance_valid(src):
		target = src
		if pack != null:
			pack.alarm(self, src)
	# Herido: se abre (y si está muy mal, se va)
	if hp < float(_d["hp"]) * 0.3 or (pack != null and pack.should_flee()):
		_flee(src.global_position if src != null else global_position + Vector3.FORWARD)
	elif state == State.ATTACK and species == "dog":
		_retreat()
	elif state != State.ATTACK and state != State.FLEE:
		_attack()
	return false


func _die(info: HitInfo) -> void:
	dead = true
	state = State.DEAD
	remove_from_group("animals")
	add_to_group("animal_corpses")
	collision_layer = 0
	velocity = Vector3.ZERO
	_say("whine" if species == "dog" else "squeal", true)
	# Cae de costado
	var side := -1.0 if rng.randf() < 0.5 else 1.0
	var tw := create_tween()
	tw.tween_property(_model, "rotation:z", side * PI * 0.5, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_model, "position:x", side * (float(_d["leg"]) + float((_d["size"] as Vector3).y) * 0.5) * 0.9, 0.45)
	tw.parallel().tween_property(_model, "position:y", -float((_d["size"] as Vector3).x) * 0.3, 0.45)
	if info != null:
		var push := info.direction
		push.y = 0
		tw.parallel().tween_property(self, "global_position", global_position + push.normalized() * 0.3, 0.3)
	if pack != null:
		pack.member_died(self)


# --- IA -------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if dead:
		_dead_t += delta
		if _dead_t > 600.0:
			queue_free()
		return
	_t -= delta
	_hit_cd -= delta
	_hurt_t += delta
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
	_move(delta)
	_animate(delta)


func _player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player


func _target_alive() -> bool:
	if target == null or not is_instance_valid(target):
		return false
	if target is Player:
		return not (target as Player).is_dead
	if target is HumanNpc:
		return not (target as HumanNpc).dead
	return true


## ¿Lo ve o lo huele?
func _notices(p: Player) -> bool:
	if p == null or p.is_dead:
		return false
	var to := p.global_position - global_position
	var d := to.length()
	if d < float(_d["smell"]) * (0.6 if (p.stance == Player.Stance.CROUCHING) else 1.0):
		return true
	if d > float(_d["sight"]):
		return false
	var fwd := Vector3(-sin(_yaw), 0, -cos(_yaw))
	if rad_to_deg(fwd.angle_to(Vector3(to.x, 0, to.z))) > float(_d["fov"]):
		return false
	# Agachado y quieto en el pasto, de lejos, pasa
	if (p.stance == Player.Stance.CROUCHING) and Vector2(p.velocity.x, p.velocity.z).length() < 0.5 and d > float(_d["sight"]) * 0.45:
		return false
	var eye := global_position + Vector3(0, float(_d["leg"]) + 0.4, 0)
	var q := PhysicsRayQueryParameters3D.create(eye, p.global_position + Vector3(0, 1.0, 0), 1 | (1 << 8))
	q.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _wander(_delta: float) -> void:
	var p := _player()
	if _notices(p):
		target = p
		if pack != null:
			pack.alarm(self, p)
		else:
			_alert_on(p)
		return
	if _t <= 0.0:
		# Elige otro lugar cerca de la querencia (o se queda olfateando un rato)
		if rng.randf() < 0.35:
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
			_say("pant" if species == "dog" else "grunt", false)


## Lo vio: lo mira, gruñe o ladra, y enseguida se larga.
func _alert_on(t: Node3D) -> void:
	target = t
	state = State.ALERT
	_move_to = Vector3.INF
	_t = rng.randf_range(0.6, 2.2)
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
		# Los jabalíes, si estás lejos, a veces prefieren irse
		var d := global_position.distance_to(target.global_position)
		if species == "boar" and d > 16.0 and rng.randf() > float(_d["courage"]):
			_flee(target.global_position)
		else:
			_attack()


func _attack() -> void:
	if not _target_alive():
		_calm()
		return
	state = State.ATTACK
	var hr: Array = _d["hits"]
	_hits_left = rng.randi_range(int(hr[0]), int(hr[1]))
	_t = rng.randf_range(4.0, 7.0)  # no se queda pegado para siempre
	_charging = false
	if species == "boar":
		_start_charge()
	else:
		_say("bark", true)


func _start_charge() -> void:
	# Embiste en línea recta hacia donde estás (con algo de adelanto) y sigue de largo
	var to := target.global_position - global_position
	var lead := Vector3.ZERO
	if target is CharacterBody3D:
		lead = (target as CharacterBody3D).velocity * clampf(to.length() / float(_d["run"]), 0.0, 1.0) * 0.6
	to += lead
	to.y = 0
	_charge_dir = to.normalized()
	_charging = true
	_t = to.length() / float(_d["run"]) + rng.randf_range(0.8, 1.4)
	_say("squeal" if rng.randf() < 0.3 else "snort", true)


func _attack_update(_delta: float) -> void:
	if not _target_alive():
		_calm()
		return
	var tp := target.global_position
	var d := Vector2(tp.x - global_position.x, tp.z - global_position.z).length()
	if species == "boar":
		# Embestida: no corrige el rumbo (por eso se la puede esquivar)
		_move_to = global_position + _charge_dir * 4.0
		_speed = float(_d["run"])
		if d < float(_d["reach"]) and _hit_cd <= 0.0:
			_bite()
		if _t <= 0.0 or is_on_wall():
			_retreat()
		return
	_go(tp, float(_d["run"]))
	if d < float(_d["reach"]):
		_face(tp)
		if _hit_cd <= 0.0:
			_bite()
	if _hits_left <= 0 or _t <= 0.0:
		_retreat()
	if _voice_t <= 0.0:
		_voice_t = rng.randf_range(0.6, 1.4)
		_say("growl" if d < 4.0 else "bark", true)


## Muerde (perro) o te lleva puesto (jabalí).
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
	# Los perros van a las piernas y los brazos; el jabalí, piernas y cuerpo
	var limb := rng.randf() < (0.75 if species == "dog" else 0.5)
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
	_say("growl" if species == "dog" else "grunt", true)
	if species == "boar":
		_retreat()


## Se abre corriendo para un lado cualquiera (más o menos lejos de vos) y vuelve.
func _retreat() -> void:
	state = State.RETREAT
	_charging = false
	var away := global_position - (target.global_position if _target_alive() else global_position + Vector3.FORWARD)
	away.y = 0
	var base := atan2(away.x, away.z) if away.length() > 0.1 else rng.randf() * TAU
	var ang := base + rng.randf_range(-1.3, 1.3)
	var rr: Array = _d["retreat"]
	var dist := rng.randf_range(float(rr[0]), float(rr[1]))
	var dest := global_position + Vector3(sin(ang), 0, cos(ang)) * dist
	_go(_on_nav(dest), float(_d["run"]) * rng.randf_range(0.8, 1.0))
	_t = dist / float(_d["run"]) + rng.randf_range(0.5, 2.5)


func _retreat_update(_delta: float) -> void:
	if not _target_alive():
		_calm()
		return
	if _t <= 0.0 or _arrived():
		if pack != null and pack.should_flee():
			_flee(target.global_position)
		else:
			# Da la vuelta, mira y vuelve a entrar
			_face(target.global_position)
			_attack()


func _flee(from: Vector3) -> void:
	state = State.FLEE
	_charging = false
	_flee_from = from
	var away := global_position - from
	away.y = 0
	if away.length() < 0.1:
		away = Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1))
	var ang := atan2(away.x, away.z) + rng.randf_range(-0.6, 0.6)
	_go(_on_nav(global_position + Vector3(sin(ang), 0, cos(ang)) * rng.randf_range(45.0, 70.0)), float(_d["run"]))
	_t = rng.randf_range(10.0, 16.0)
	_say("whine" if species == "dog" else "squeal", true)


func _flee_update(_delta: float) -> void:
	if _t <= 0.0 or _arrived():
		# Lejos y tranquilo: esa es su nueva querencia
		if pack != null:
			pack.home = global_position
			pack.calm()
		_calm()


func _calm() -> void:
	state = State.WANDER
	target = null
	_charging = false
	_t = rng.randf_range(1.0, 3.0)
	_go(global_position, float(_d["walk"]))


func _on_noise(pos: Vector3, radius: float, source: Node) -> void:
	if dead or state in [State.ATTACK, State.RETREAT, State.FLEE]:
		return
	if source == self or source is Animal:
		return
	var d := global_position.distance_to(pos)
	if d > radius * 0.8:
		return
	# Un tiro: los jabalíes casi siempre se van; los perros van a ver si es cerca
	var shooter := source as Node3D
	if species == "boar" or d > 50.0 or not (shooter is Player):
		if radius >= 40.0:
			_flee(pos)
		return
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
	elif _move_to != Vector3.INF:
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
	var acc := 9.0 if species == "dog" else 4.5
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
		if _stuck_t > 1.0:
			_stuck_t = 0.0
			_charging = false
			if state == State.ATTACK or state == State.RETREAT:
				_retreat() if state == State.ATTACK else _attack()
			else:
				_t = 0.0
	else:
		_stuck_t = maxf(0.0, _stuck_t - delta)
	_last_pos = global_position


func _animate(delta: float) -> void:
	var hs := Vector2(velocity.x, velocity.z).length()
	var stride := float(_d["leg"]) * 2.6
	_phase += hs / stride * TAU * delta
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
	_model.position.y = absf(sin(_phase)) * 0.03 * amp if not gallop else sin(_phase * 1.0) * 0.06
	_model.rotation.x = sin(_phase) * 0.06 * amp if gallop else 0.0
	if _tail != null:
		var wag := 0.5 if state == State.WANDER and species == "dog" else 0.1
		_tail.rotation.y = sin(Time.get_ticks_msec() * 0.012) * wag
	if _head != null:
		# Olfatea con la cabeza baja cuando anda tranquilo
		var low := state == State.WANDER and hs < 0.6
		_head.rotation.x = lerpf(_head.rotation.x, -0.45 if low else 0.0, 1.0 - exp(-3.0 * delta))
	# Pasos (patas: suaves, más fuerte al galope)
	if is_on_floor() and hs > 2.5 and int(_phase / PI) != int((_phase - hs / stride * TAU * delta) / PI):
		var st := Foley.step("dirt")
		if st != null:
			_steps.stream = st
			_steps.pitch_scale = 1.5 if species == "dog" else 1.1
			_steps.volume_db = -14.0 if species == "dog" else -9.0
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
	var s := Animal.sound(species, kind, rng)
	if s == null:
		return
	_voice.stream = s
	_voice.volume_db = 0.0 if loud else -8.0
	_voice.pitch_scale = rng.randf_range(0.92, 1.08) * (1.0 if species == "boar" else 1.0)
	_voice.position = Vector3(0, float(_d["leg"]) + 0.3, -float((_d["size"] as Vector3).z) * 0.5)
	_voice.play()
	_voice_t = maxf(_voice_t, 0.5)
