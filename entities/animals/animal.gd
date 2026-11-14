class_name Animal
extends CharacterBody3D
## Animal salvaje: perro cimarrón, jabalí o carpincho. Andan en grupo (AnimalPack).
## Los datos de cada especie están en data/animals/<id>.tres (AnimalSpecies); el
## cuerpo y el ragdoll en AnimalBody; los sonidos en AnimalSounds. Acá: la conducta.
##
## Estilos de ataque (AnimalSpecies.attack_style):
##  - "pack" (perros): cobardes y de jauría. Te rodean en círculo ladrando, de a uno o
##    dos se tiran a morder (o amagan) y se abren.
##  - "charge" (jabalíes): territoriales. Embisten; la carga te sigue hasta el final y
##    recién en el último momento se puede esquivar al costado.
##  - "cornered" (carpinchos): se van (al agua si hay); muerden solo si los acorralan.
## Con un tiro a la cabeza o al pecho caen en el acto (ragdoll); si no, se arrastran un
## rato y caen. Muertos se pueden cuerear con el cuchillo.

const BODY_LAYER := 5
## Probabilidad de sacar un cuero al cuerear.
const SKIN_CHANCE := 0.45
## Carpincho: a menos de esto de alguien (o trabado huyendo con alguien a CORNER_NEAR),
## se da vuelta y muerde.
const CORNER_DIST := 2.0
const CORNER_NEAR := 4.0
## Jabalí: a menos de esto deja de corregir el rumbo (ahí se lo esquiva).
const CHARGE_LOCK := 3.2
const CHARGE_TURN := 3.2
## Daño por zona.
const ZONE_MULT := {"head": 2.4, "chest": 1.5, "torso": 0.9, "limb": 0.5}

enum State { WANDER, ALERT, ATTACK, RETREAT, FLEE, DEAD, HIDE, DYING }

@export var species: String = "dog"
var spec: AnimalSpecies
var body: AnimalBody
var pack: AnimalPack = null
var state: State = State.WANDER
var hp: float = 55.0
## Muerto o muriéndose (no ataca ni cuenta como amenaza).
var dead: bool = false
var skinned: bool = false
var target: Node3D = null
var rng := RandomNumberGenerator.new()

var _move_to: Vector3 = Vector3.INF
var _speed: float = 0.0
var _t: float = 0.0
var _hits_left: int = 0
var _hit_cd: float = 0.0
var _charge_dir: Vector3 = Vector3.ZERO
var _charging: bool = false
var _charge_locked: bool = false
var _voice_t: float = 0.0
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
var _voice: AudioStreamPlayer3D
var _steps: AudioStreamPlayer3D


func _ready() -> void:
	spec = AnimalSpecies.get_species(species)
	hp = spec.hp
	add_to_group("animals")
	collision_layer = 1 << (BODY_LAYER - 1)
	collision_mask = 1 | (1 << 9)
	floor_snap_length = 0.5
	floor_max_angle = deg_to_rad(50.0)
	var cs := CollisionShape3D.new()
	var sh := CapsuleShape3D.new()
	sh.radius = spec.size.x * 0.75
	sh.height = maxf(spec.size.y + spec.leg, sh.radius * 2.0 + 0.01)
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
	body = AnimalBody.new()
	body.name = "Body"
	add_child(body)
	body.setup(spec, self, rng)
	_yaw = rotation.y
	rotation = Vector3.ZERO
	_voice_t = rng.randf_range(2.0, 8.0)
	_orbit_dir = -1.0 if rng.randf() < 0.5 else 1.0
	EventBus.noise_emitted.connect(_on_noise)


func _style() -> String:
	return spec.attack_style


# --- Daño, agonía y muerte --------------------------------------------------------------

func apply_hit(info: HitInfo) -> bool:
	Blood.on_hit(self, info, state != State.DEAD)
	if state == State.DEAD:
		# Cuerpo: el tiro lo mueve (sin ruido)
		body.push_ragdoll(info.direction * clampf(info.damage * 0.12, 1.0, 8.0), info.position)
		return false
	var zone := info.zone
	var dmg := info.damage * float(ZONE_MULT.get(zone, 1.0))
	if state == State.DYING:
		# Arrastrándose: un tiro a la cabeza o al pecho (o uno fuerte) lo termina
		if zone in ["head", "chest"] or dmg > 35.0:
			_die(info)
		else:
			_dying_t *= 0.5
		return false
	hp -= dmg
	if hp <= 0.0:
		# Cabeza o corazón (o un tiro que lo deshace): cae en el acto. Si no, se arrastra.
		if zone in ["head", "chest"] or dmg > spec.hp * 1.6:
			_die(info)
		else:
			_start_dying(info)
		return true
	_say(AnimalSounds.kind_for("hurt", species), true)
	var src := info.source as Node3D
	if src != null and not is_instance_valid(src):
		src = null
	var from := src.global_position if src != null else info.position - info.direction * 10.0
	match _style():
		"cornered":
			# Si el que le pegó está encima, muerde; si no, se va (al agua si puede)
			if src != null and src.global_position.distance_to(global_position) < CORNER_NEAR and state != State.HIDE:
				_cornered(src)
			elif state != State.HIDE:
				_danger(from)
			if pack != null and src != null:
				pack.alarm(self, src)
		"pack":
			# Cobarde: herido se abre siempre, y muchas veces se va del todo
			if src != null:
				target = src
				if pack != null:
					pack.alarm(self, src)
			if hp < spec.hp * 0.5 or rng.randf() < 1.0 - spec.courage * 1.9 or (pack != null and pack.should_flee()):
				_flee(from)
			else:
				_retreat()
		"charge":
			# Herido se pone peor: va contra el que le tiró
			if src != null:
				target = src
				if pack != null:
					pack.alarm(self, src)
			if hp < spec.hp * 0.2 or (pack != null and pack.should_flee()):
				_flee(from)
			elif not _charging and target != null:
				_attack()
	return false


## Herido de muerte pero no en el acto: se arrastra un rato y cae.
func _start_dying(info: HitInfo) -> void:
	dead = true
	state = State.DYING
	_charging = false
	target = null
	_dying_t = rng.randf_range(6.0, 14.0)
	var away := global_position - (info.position - info.direction * 5.0)
	away.y = 0
	_go(_on_nav(global_position + away.normalized() * rng.randf_range(4.0, 9.0)), rng.randf_range(0.35, 0.7))
	_say(AnimalSounds.kind_for("dying", species), false)
	if pack != null:
		pack.member_died(self)


func _dying_update(delta: float) -> void:
	_dying_t -= delta
	# Arrastrándose: un rastro de sangre
	if global_position.distance_to(_last_blood) > 0.5:
		var dir := global_position - _last_blood if _last_blood != Vector3.INF else Vector3.FORWARD
		_last_blood = global_position
		Blood.smear(self, global_position, dir)
	if _dying_t <= 0.0:
		_die(null)
	elif _arrived():
		_move_to = Vector3.INF


## Cae muerto: ragdoll apoyado en el piso, charco de sangre, y ya no hace ruido.
func _die(info: HitInfo) -> void:
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
	var head_shot := info != null and info.zone == "head"
	if head_shot:
		Blood.headshot(self, info)
	var push := Vector3.ZERO
	var at := Vector3.ZERO
	if info != null:
		push = info.direction.normalized() * clampf(info.damage * 0.2, 2.0, 14.0)
		at = info.position
	var vel := velocity
	velocity = Vector3.ZERO
	body.make_ragdoll(vel, push, at, 1.0 if rng.randf() < 0.5 else -1.0)
	# Charco debajo (más rápido si fue a la cabeza)
	get_tree().create_timer(1.0, false).timeout.connect(func() -> void:
		if is_inside_tree():
			Blood.pool(self, body.head_position() if head_shot else body.center(), spec.size.z * (0.75 if head_shot else 0.85),
				4.0 if head_shot else 10.0))


## Centro del cuerpo (vivo o caído).
func center() -> Vector3:
	return body.center()


# --- Cuerear ----------------------------------------------------------------------------

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
	var cut := AnimalSounds.pick("knife", "cut", rng)
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
		body.ragdoll_update(delta)
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
		if d < best_d and d < spec.sight + 2.0 and _notices(h):
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
	if d < spec.smell * (0.6 if crouched else 1.0):
		return true
	if d > spec.sight:
		return false
	var fwd := Vector3(-sin(_yaw), 0, -cos(_yaw))
	if rad_to_deg(fwd.angle_to(Vector3(to.x, 0, to.z))) > spec.fov:
		return false
	# Agachado y quieto en el pasto, de lejos, pasa
	if crouched and Vector2(pv.x, pv.z).length() < 0.5 and d > spec.sight * 0.45:
		return false
	var eye := global_position + Vector3(0, spec.leg + 0.4, 0)
	var q := PhysicsRayQueryParameters3D.create(eye, p.global_position + Vector3(0, 1.0, 0), 1 | (1 << 8))
	q.exclude = [get_rid()]
	if p is CollisionObject3D:
		q.exclude.append((p as CollisionObject3D).get_rid())
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## Jabalí: ¿está en su lugar?
func _in_territory(p: Vector3) -> bool:
	var tr_r := spec.territory
	if tr_r <= 0.0 or pack == null:
		return false
	return Vector2(p.x - pack.home.x, p.z - pack.home.z).length() < tr_r


func _wander(delta: float) -> void:
	var p := _noticed_human()
	if p != null:
		target = p
		if _style() == "charge" and (_in_territory(p.global_position) or p.global_position.distance_to(global_position) < 14.0):
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
		_orbit_ang += _orbit_dir * spec.trot * 1.2 / _orbit_r * delta
		var home := pack.home if pack != null else global_position
		_go(home + Vector3(sin(_orbit_ang), 0, cos(_orbit_ang)) * _orbit_r, spec.trot * 1.2)
		if _antic_t <= 0.0:
			_t = 0.0
		return
	if _t <= 0.0:
		var r0 := rng.randf()
		if _style() == "pack" and r0 < 0.15:
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
			_go(home + off, spec.walk if rng.randf() < 0.7 else spec.trot)
			_t = rng.randf_range(5.0, 12.0)
	if _voice_t <= 0.0:
		_voice_t = rng.randf_range(6.0, 16.0)
		if rng.randf() < 0.4:
			_say(AnimalSounds.kind_for("idle", species), false)


## Lo vio: lo mira, gruñe o ladra, y enseguida se larga (el carpincho, al agua).
func _alert_on(t: Node3D) -> void:
	target = t
	if _style() == "cornered":
		_say("bark", true)
		_danger(t.global_position)
		return
	state = State.ALERT
	_move_to = Vector3.INF
	_antic_t = 0.0
	# El jabalí casi no duda
	_t = rng.randf_range(0.6, 2.2) if _style() == "pack" else rng.randf_range(0.2, 0.7)
	_say("growl" if _style() == "pack" and rng.randf() < 0.5 else ("bark" if _style() == "pack" else "snort"), true)


func _alert(_delta: float) -> void:
	if not _target_alive():
		_calm()
		return
	_face(target.global_position)
	if _voice_t <= 0.0:
		_voice_t = rng.randf_range(0.8, 1.6)
		_say("bark" if _style() == "pack" else "snort", true)
	if _t <= 0.0:
		var d := global_position.distance_to(target.global_position)
		if _style() == "charge" and d > 18.0 and not _in_territory(target.global_position) and rng.randf() > spec.courage:
			_flee(target.global_position)
		else:
			_attack()


func _attack() -> void:
	if not _target_alive():
		_calm()
		return
	state = State.ATTACK
	_antic_t = 0.0
	_hits_left = rng.randi_range(spec.hits.x, spec.hits.y)
	_charging = false
	if _style() == "charge":
		_start_charge()
	elif _style() == "pack":
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
	_speed = spec.run
	_say("squeal" if rng.randf() < 0.3 else "snort", true)


## Puede alcanzar al blanco (no está subido a algo).
func _reachable(tp: Vector3) -> bool:
	var dy := tp.y - global_position.y
	return dy < spec.reach_up and dy > -1.0


func _attack_update(delta: float) -> void:
	if not _target_alive():
		_calm()
		return
	var tp := target.global_position
	var d := Vector2(tp.x - global_position.x, tp.z - global_position.z).length()
	match _style():
		"cornered":
			# Acorralado: muerde y en cuanto puede se va
			_go(tp, spec.trot)
			_face(tp)
			if d < spec.reach and _reachable(tp) and _hit_cd <= 0.0:
				_bite()
			if _hits_left <= 0 or _t <= 0.0:
				_danger(tp)
		"charge":
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
		_go(tp, spec.trot)
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
	_speed = spec.run
	if d < spec.reach and _hit_cd <= 0.0:
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
			_orbit_ang += _orbit_dir * spec.run * 0.6 / _orbit_r * delta
			_go(tp + Vector3(sin(_orbit_ang), 0, cos(_orbit_ang)) * _orbit_r, spec.run * 0.65)
			if _t <= 0.0 and reach_ok:
				if pack == null or pack.can_dart(self):
					_mode = "feint" if rng.randf() < 0.3 else "dart"
					_t = 4.0
				else:
					_t = rng.randf_range(0.8, 2.0)
		"dart", "feint":
			_go(tp, spec.run)
			if _mode == "feint" and d < 3.0:
				_retreat()
				return
			if d < spec.reach:
				_face(tp)
				if _hit_cd <= 0.0 and reach_ok:
					_bite()
			if _hits_left <= 0 or _t <= 0.0:
				_retreat()
		_:
			_circle()


## Muerde (perro, carpincho) o te lleva puesto (jabalí).
func _bite() -> void:
	_hit_cd = spec.hit_gap
	_hits_left -= 1
	var info := HitInfo.new()
	info.damage = rng.randf_range(spec.damage.x, spec.damage.y)
	info.weapon_id = "melee"
	info.source = self
	var tp := target.global_position
	info.direction = (tp - global_position).normalized()
	# Perros y carpinchos van a las piernas y los brazos; el jabalí, piernas y cuerpo
	var limb := rng.randf() < (0.5 if _style() == "charge" else 0.75)
	info.zone = "limb" if limb else "torso"
	info.position = tp + Vector3(0, 0.5 if limb else 1.1, 0)
	info.distance = 1.0
	if target.has_method("apply_hit"):
		target.call("apply_hit", info)
	var push := spec.push
	if push > 0.0 and target is CharacterBody3D:
		var pd := info.direction
		pd.y = 0
		(target as CharacterBody3D).velocity += pd.normalized() * push + Vector3.UP * push * 0.35
	_say(AnimalSounds.kind_for("bite", species), true)


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
	var dist := rng.randf_range(spec.retreat.x, spec.retreat.y)
	var dest := global_position + Vector3(sin(ang), 0, cos(ang)) * dist
	_go(_on_nav(dest), spec.run * rng.randf_range(0.8, 1.0))
	_t = dist / spec.run + (rng.randf_range(0.2, 1.0) if _style() == "charge" else rng.randf_range(0.5, 2.5))


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
	_go(_on_nav(global_position + Vector3(sin(ang), 0, cos(ang)) * rng.randf_range(45.0, 70.0)), spec.run)
	_t = rng.randf_range(10.0, 16.0)
	_say(AnimalSounds.kind_for("flee", species), true)


func _flee_update(_delta: float) -> void:
	if _style() == "cornered":
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
	_go(global_position, spec.walk)


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
	_go(w, spec.run)
	_t = global_position.distance_to(w) / spec.run + 6.0
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
	return global_position.y < wl - spec.leg - float(spec.size.y) - 0.1


## Agua honda (que lo tape) más cercana, sin ir para el lado del peligro.
func _find_water(from: Vector3) -> Vector3:
	var lvl := _level()
	if lvl == null:
		return Vector3.INF
	var wl := float(lvl.call("water_level"))
	var deep := wl - spec.leg - float(spec.size.y) - 0.35
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
		_go(pack.home, spec.walk * 1.5)
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
	match _style():
		"cornered":
			if radius >= 20.0 and d < 70.0:
				_danger(pos)
		"charge":
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
			if radius >= 40.0 and (not human or d > 50.0 or rng.randf() > spec.courage + 0.3):
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
	var acc := spec.accel
	velocity = velocity.lerp(Vector3(hv.x, vy, hv.z), 1.0 - exp(-acc * delta))
	velocity.y = vy
	move_and_slide()
	var hs := Vector2(velocity.x, velocity.z)
	if hs.length() > 0.4 and state != State.ALERT:
		_yaw = lerp_angle(_yaw, atan2(-hs.x, -hs.y), 1.0 - exp(-10.0 * delta))
	body.rotation.y = _yaw
	# Trabado (contra algo): corta y elige otra cosa
	if hv.length() > 0.5 and global_position.distance_to(_last_pos) < hv.length() * delta * 0.15:
		_stuck_t += delta
		if _stuck_t > 1.0 and _style() != "cornered":
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
	if state == State.DYING:
		body.animate_dying(delta, hs)
		return
	if state == State.HIDE:
		return
	# Pasos (patas: suaves, más fuerte al galope)
	if body.animate(delta, hs, state == State.WANDER, state == State.ALERT) and is_on_floor():
		var st := Foley.step("dirt")
		if st != null:
			_steps.stream = st
			_steps.pitch_scale = 1.5 if spec.mass < 40.0 else 1.1
			_steps.volume_db = -14.0 if spec.mass < 40.0 else -8.0
			_steps.play()


# --- Sonido -----------------------------------------------------------------------------

func _say(kind: String, loud: bool) -> void:
	if state == State.DEAD:
		return
	var s := AnimalSounds.pick(species, kind, rng)
	if s == null:
		return
	_voice.stream = s
	_voice.volume_db = (0.0 if loud else -8.0) + (-10.0 if state == State.DYING else 0.0)
	_voice.pitch_scale = rng.randf_range(0.92, 1.08) * (0.85 if spec.mass > 80.0 else 1.0)
	_voice.position = Vector3(0, spec.leg + 0.3, -spec.size.z * 0.5)
	_voice.play()
	_voice_t = maxf(_voice_t, 0.5)
