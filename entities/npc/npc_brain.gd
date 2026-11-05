class_name NpcBrain
extends RefCounted
## Cerebro de un enemigo: percepción (vista y oído) y decisiones. Piensa ~10 veces
## por segundo; entre medio el cuerpo sigue la última orden.
##
## Estados:
##  - IDLE: de guardia, mira alrededor de vez en cuando.
##  - PATROL: recorre sus puntos con pausas.
##  - INVESTIGATE: vio algo raro o escuchó ruido: va a mirar con el arma arriba.
##  - COMBAT: sabe dónde estás. Te tira en ráfagas, se cubre, avanza o flanquea
##    según la dificultad; si te pierde, va a buscarte o tira una granada.
##  - SEARCH: te perdió hace rato: revisa la zona y después vuelve a lo suyo.
##  - RETREAT: herido: se aleja a cubierto y se cura (si tiene botiquín).
##
## Vista: un "medidor de alerta" que sube más rápido cuanto más cerca, más expuesto
## y más de frente estés (agachado y quieto cuesta más verte). Oído: disparos (con
## silenciador se oyen mucho menos), pasos y explosiones. Los del mismo escuadrón
## se avisan dónde estás.

enum State { IDLE, PATROL, INVESTIGATE, COMBAT, SEARCH, RETREAT }

const THINK := 0.1
## Capas que tapan la vista: mundo y follaje.
const SIGHT_MASK := 1 | (1 << 8)

var npc: HumanNpc
var state: State = State.IDLE
var state_t: float = 0.0
var awareness: float = 0.0
var target: Node3D = null
var target_visible: bool = false
var last_known: Vector3 = Vector3.INF
## Segundos desde que lo vio por última vez (en combate).
var unseen: float = 999.0
## Segundos que lo viene siguiendo con la vista (asienta la puntería).
var track_time: float = 0.0
var reaction_left: float = 0.0
var cover: Vector3 = Vector3.INF
var investigate_pos: Vector3 = Vector3.INF
var home: Vector3
var home_yaw: float = 0.0

var _think_t: float = 0.0
var _rng := RandomNumberGenerator.new()
var _patrol_i: int = 0
var _pause_t: float = 0.0
var _cover_t: float = 0.0
var _burst_pause: float = 0.0
var _flank_tried: bool = false
var _grenade_t: float = 0.0
var _callout_t: float = -1.0
var _under_fire: float = 0.0
var _peek_t: float = 0.0
var _search_pts: Array[Vector3] = []
var _exposure: float = 0.0
## Qué partes del blanco se ven (cabeza, pecho, cadera).
var _vis: Array[bool] = [false, false, false]
## Esta ráfaga va a la cabeza.
var _aim_head: bool = false
var _advance_t: float = 0.0


func _init(n: HumanNpc) -> void:
	npc = n
	_rng.randomize()
	_think_t = _rng.randf() * THINK
	home = n.global_position
	home_yaw = n._yaw
	state = State.PATROL if n.patrol.size() > 1 else State.IDLE


func prof() -> Dictionary:
	return npc.profile()


func _set_state(s: State) -> void:
	if s == state:
		return
	state = s
	state_t = 0.0
	_flank_tried = false


func update(delta: float) -> void:
	state_t += delta
	_burst_pause -= delta
	_grenade_t -= delta
	_under_fire = maxf(0.0, _under_fire - delta)
	_think_t -= delta
	if _callout_t > 0.0:
		_callout_t -= delta
		if _callout_t <= 0.0:
			_callout()
	if _think_t > 0.0:
		_track(delta)
		return
	var dt := THINK - _think_t
	_think_t = THINK
	_perceive(dt)
	match state:
		State.IDLE:
			_idle(dt)
		State.PATROL:
			_patrol(dt)
		State.INVESTIGATE:
			_investigate(dt)
		State.COMBAT:
			_combat(dt)
		State.SEARCH:
			_search(dt)
		State.RETREAT:
			_retreat(dt)
	_track(delta)


## Entre pensamientos: la mira sigue al blanco si lo ve.
func _track(_delta: float) -> void:
	if state == State.COMBAT and target_visible and target != null and is_instance_valid(target):
		npc.aim_point = _aim_spot()


# --- Percepción ---------------------------------------------------------------------

func _pick_target() -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for n in npc.get_tree().get_nodes_in_group("player"):
		var p := n as Player
		if p == null or p.is_dead:
			continue
		var d := p.global_position.distance_to(npc.global_position)
		if d < best_d:
			best_d = d
			best = p
	return best


## Puntos del blanco que se pueden ver (cabeza, pecho, cadera).
func _target_points(t: Node3D) -> Array[Vector3]:
	var p := t as Player
	if p != null:
		var base := p.global_position
		return [p.camera.global_position, base + Vector3(0, p.eye_height * 0.72, 0), base + Vector3(0, p.eye_height * 0.4, 0)]
	return [t.global_position + Vector3(0, 1.5, 0)]


func _perceive(dt: float) -> void:
	var t := _pick_target()
	if t != target:
		target = t
		track_time = 0.0
	if target == null:
		target_visible = false
		if state == State.COMBAT:
			_set_state(State.SEARCH)
		return
	var p := prof()
	var eye := npc.body.eye_position()
	var pts := _target_points(target)
	var dist := eye.distance_to(pts[1])
	var alert := state in [State.COMBAT, State.INVESTIGATE, State.SEARCH, State.RETREAT]
	var rng_eff := float(p["sight_range"]) * (1.3 if alert else 1.0)
	var pl := target as Player
	if pl != null:
		if pl.stance == Player.Stance.CROUCHING:
			rng_eff *= 0.6
		if pl.is_sprinting:
			rng_eff *= 1.2
	var fov := deg_to_rad(float(p["fov"])) * (1.6 if state == State.COMBAT else 1.0)
	var fwd := npc.aim_forward()
	fwd.y = 0.0
	var to := pts[1] - eye
	var flat := Vector3(to.x, 0, to.z)
	var ang := fwd.normalized().angle_to(flat.normalized()) if flat.length() > 0.01 else 0.0
	var seen := 0
	_vis = [false, false, false]
	if dist < rng_eff and ang < fov * 0.5:
		var space := npc.get_world_3d().direct_space_state
		for i in pts.size():
			var rq := PhysicsRayQueryParameters3D.create(eye, pts[i], SIGHT_MASK)
			rq.exclude = [target.get_rid()] if target is CollisionObject3D else []
			if space.intersect_ray(rq).is_empty():
				seen += 1
				if i < 3:
					_vis[i] = true
	_exposure = seen / float(pts.size())
	if seen > 0:
		var rate := 1.0 / float(p["notice"]) * clampf(20.0 / maxf(dist, 4.0), 0.2, 3.0) * _exposure
		if ang > fov * 0.25:
			rate *= 0.5
		if alert:
			rate *= 2.5
		if pl != null:
			var spd := Vector2(pl.velocity.x, pl.velocity.z).length()
			rate *= 1.3 if spd > 4.0 else (0.6 if spd < 0.3 and pl.stance == Player.Stance.CROUCHING else 1.0)
		awareness = minf(1.5, awareness + rate * dt)
	elif state != State.COMBAT:
		awareness = maxf(0.0, awareness - dt * 0.06)
	if awareness >= 1.0 and seen > 0 and state != State.COMBAT:
		_enter_combat(target.global_position, true)
	target_visible = seen > 0 and state == State.COMBAT
	if target_visible:
		last_known = target.global_position
		unseen = 0.0
		track_time += dt
	else:
		unseen += dt
		track_time = maxf(0.0, track_time - dt * 2.0)
		# Lo vio a medias: va a mirar
		if seen > 0 and awareness >= 0.35 and state in [State.IDLE, State.PATROL, State.SEARCH]:
			_investigate_at(target.global_position)


## Ruido: disparos, pasos, explosiones. Los aliados que disparan también alertan.
func on_noise(pos: Vector3, radius: float, source: Node) -> void:
	var d := pos.distance_to(npc.global_position)
	if d > radius * float(prof()["hearing"]) * npc.hearing_mult:
		return
	var ally := source is HumanNpc
	if ally:
		var other := source as HumanNpc
		if other.brain != null and other.brain.state == State.COMBAT and other.brain.last_known != Vector3.INF:
			if state != State.COMBAT:
				_enter_combat(other.brain.last_known + _jitter(4.0), false)
		return
	if source != null and not source.is_in_group("player") and not (source is Grenade):
		return
	var err := _jitter(d * 0.12)
	if radius >= 40.0:
		# Un disparo o una explosión: sabe más o menos de dónde vino
		awareness = maxf(awareness, 0.95 if d < radius * 0.35 else 0.7)
		if state == State.COMBAT:
			if unseen > 2.0:
				last_known = pos + err
		elif d < radius * 0.35:
			_enter_combat(pos + err, false)
		else:
			_investigate_at(pos + err)
	else:
		# Pasos
		awareness = minf(1.0, awareness + 0.3)
		if state in [State.IDLE, State.PATROL, State.SEARCH]:
			_investigate_at(pos + err)


func on_near_miss(origin: Vector3, _source: Node) -> void:
	_under_fire = 2.5
	awareness = maxf(awareness, 1.0)
	if state != State.COMBAT:
		_enter_combat(origin + _jitter(origin.distance_to(npc.global_position) * 0.08), false)
	elif not target_visible:
		last_known = origin + _jitter(3.0)


func on_damaged(info: HitInfo) -> void:
	_under_fire = 3.0
	awareness = 1.2
	var from := info.source as Node3D
	var pos := from.global_position if from != null and is_instance_valid(from) else info.position - info.direction * 20.0
	if state != State.COMBAT and state != State.RETREAT:
		_enter_combat(pos, false)
		reaction_left *= 0.6
	elif not target_visible:
		last_known = pos + _jitter(2.0)
	# Herido: cubrirse ya
	_cover_t = 0.0


## Un compañero avisó dónde estás.
func on_callout(pos: Vector3) -> void:
	if state == State.COMBAT or state == State.RETREAT:
		return
	awareness = maxf(awareness, 1.0)
	_enter_combat(pos + _jitter(3.0), false)


func _enter_combat(pos: Vector3, seen: bool) -> void:
	var was := state
	_set_state(State.COMBAT)
	last_known = pos
	unseen = 0.0 if seen else 3.0
	awareness = maxf(awareness, 1.0)
	reaction_left = float(prof()["reaction"]) * (1.0 if seen else 0.5) * _rng.randf_range(0.8, 1.25)
	_cover_t = _rng.randf_range(0.0, 0.6)
	npc.raised = true
	var co := float(prof()["callout"])
	if co >= 0.0 and was != State.COMBAT:
		_callout_t = maxf(co, 0.05)


func _callout() -> void:
	if npc.dead or last_known == Vector3.INF:
		return
	for n in npc.get_tree().get_nodes_in_group("ai_npc"):
		var o := n as HumanNpc
		if o == null or o == npc or o.dead:
			continue
		if npc.squad != "" and o.squad != npc.squad:
			continue
		if o.global_position.distance_to(npc.global_position) < 70.0:
			o.brain.on_callout(last_known)


func _investigate_at(p: Vector3) -> void:
	investigate_pos = p
	_set_state(State.INVESTIGATE)
	_pause_t = _rng.randf_range(0.4, 1.0)


# --- Estados tranquilos ---------------------------------------------------------------

func _idle(_dt: float) -> void:
	npc.raised = false
	npc.crouching = false
	npc.aim_point = Vector3.INF
	npc.burst_left = 0
	if npc.global_position.distance_to(home) > 1.5:
		npc.go_to(home)
		return
	npc.stop()
	# Mira alrededor de su puesto
	_pause_t -= THINK
	if _pause_t <= 0.0:
		_pause_t = _rng.randf_range(3.0, 7.0)
		npc.look_yaw = home_yaw + _rng.randf_range(-1.1, 1.1)


func _patrol(_dt: float) -> void:
	npc.raised = false
	npc.crouching = false
	npc.aim_point = Vector3.INF
	npc.burst_left = 0
	if npc.patrol.size() < 2:
		_set_state(State.IDLE)
		return
	var p := npc.patrol[_patrol_i % npc.patrol.size()]
	if _pause_t > 0.0:
		_pause_t -= THINK
		npc.stop()
		return
	npc.go_to(p, HumanNpc.WALK_SPEED)
	if npc.arrived() or npc.is_stuck():
		_patrol_i = (_patrol_i + 1) % npc.patrol.size()
		_pause_t = _rng.randf_range(1.5, 4.0)
		npc.look_yaw = npc.rotation.y + _rng.randf_range(-0.8, 0.8)


func _investigate(_dt: float) -> void:
	npc.raised = true
	npc.aim_point = Vector3.INF
	npc.burst_left = 0
	if _pause_t > 0.0:
		# Primero se da vuelta a mirar
		_pause_t -= THINK
		npc.stop()
		var d := investigate_pos - npc.global_position
		npc.look_yaw = atan2(-d.x, -d.z)
		return
	npc.go_to(investigate_pos, HumanNpc.WALK_SPEED)
	if npc.arrived() or npc.is_stuck() or state_t > 25.0:
		npc.stop()
		npc.look_yaw = npc.rotation.y + _rng.randf_range(-1.5, 1.5)
		if state_t > 30.0 or npc.arrived():
			awareness = minf(awareness, 0.3)
			_set_state(State.PATROL if npc.patrol.size() > 1 else State.IDLE)


# --- Combate -----------------------------------------------------------------------

func _combat(dt: float) -> void:
	var p := prof()
	npc.raised = true
	unseen = 0.0 if target_visible else unseen
	# Herido: retirarse a curarse
	if npc.hp <= float(p["retreat_hp"]) and npc.has_medkit and not npc.is_healing():
		_set_state(State.RETREAT)
		cover = _find_cover(last_known, false, 10.0, 22.0)
		return
	if target_visible:
		_engage(dt, p)
	else:
		_lost(dt, p)


## Lo ve: dispara en ráfagas y maneja la posición (cubrirse, asomarse, avanzar).
func _engage(dt: float, p: Dictionary) -> void:
	npc.aim_point = _aim_spot()
	reaction_left -= dt
	var floor_k := float(p["settle_floor"])
	var settle := clampf(track_time / float(p["settle_time"]), 0.0, 1.0)
	npc.aim_error_deg = float(p["aim_error"]) * lerpf(1.0, floor_k, settle)
	var tp := target as Player
	if tp != null and Vector2(tp.velocity.x, tp.velocity.z).length() > 2.0:
		npc.aim_error_deg *= 1.4
	if _under_fire > 0.0:
		npc.aim_error_deg *= 1.25
	var dist := npc.global_position.distance_to(target.global_position)
	var moving := npc.move_target != Vector3.INF and not npc.arrived()
	var can_shoot := reaction_left <= 0.0 and not npc.reloading and (not moving or bool(p["move_shoot"]))
	if can_shoot and npc.burst_left <= 0 and _burst_pause <= 0.0 and _clear_line():
		var b: Array = p["burst"]
		var auto := npc.weapon.has_mode("auto")
		npc.burst_left = _rng.randi_range(int(b[0]), int(b[1])) if auto else _rng.randi_range(1, 3)
		# De lejos, ráfagas cortas
		if auto and dist > 40.0:
			npc.burst_left = mini(npc.burst_left, _rng.randi_range(1, 3))
		if npc.weapon.pellets > 1 or npc.weapon.bolt_action:
			npc.burst_left = 1
		_burst_pause = float(p["burst_pause"]) * _rng.randf_range(0.7, 1.4) + (0.4 if not auto else 0.0)
		_aim_head = _rng.randf() < float(p["head_aim"])
	# Posición
	_cover_t -= dt
	var range_ok := dist < _weapon_range()
	if npc.reloading and cover == Vector3.INF and _rng.randf() < float(p["cover"]) * dt * 3.0:
		cover = _find_cover(target.global_position, false)
	if _cover_t <= 0.0:
		_cover_t = _rng.randf_range(4.0, 8.0)
		var want_cover := _under_fire > 0.0 or _exposure > 0.6
		if not range_ok:
			cover = _find_cover(target.global_position, true)
		elif want_cover and _rng.randf() < float(p["cover"]):
			cover = _find_cover(target.global_position, false)
	if cover != Vector3.INF:
		npc.go_to(cover, HumanNpc.RUN_SPEED if _under_fire > 0.0 else HumanNpc.WALK_SPEED * 1.6)
		if npc.arrived():
			npc.stop()
			_peek(dt, p)
		else:
			npc.crouching = false
	else:
		npc.stop()
		# Sin cobertura: agacharse a veces para achicar el blanco
		npc.crouching = _under_fire > 0.0 and float(p["cover"]) > 0.5 and dist > 12.0


## A cubierto: agachado cuando no tira, se asoma (se para) para la ráfaga.
func _peek(dt: float, p: Dictionary) -> void:
	_peek_t -= dt
	if npc.reloading or npc.is_healing():
		npc.crouching = true
		return
	if npc.burst_left > 0:
		npc.crouching = _crouched_sees()
		return
	if _peek_t <= 0.0:
		_peek_t = float(p["burst_pause"]) + _rng.randf_range(0.3, 1.2)
		npc.crouching = _under_fire > 0.0 or _rng.randf() < 0.5
		if not _crouched_sees() and npc.crouching and _burst_pause <= 0.1:
			npc.crouching = false


func _crouched_sees() -> bool:
	if target == null:
		return false
	var from := npc.global_position + Vector3(0, 1.0, 0)
	var rq := PhysicsRayQueryParameters3D.create(from, _target_points(target)[1], SIGHT_MASK)
	rq.exclude = [target.get_rid()] if target is CollisionObject3D else []
	return npc.get_world_3d().direct_space_state.intersect_ray(rq).is_empty()


## Lo perdió de vista: espera, flanquea, avanza o tira una granada.
func _lost(dt: float, p: Dictionary) -> void:
	npc.burst_left = 0
	npc.crouching = false
	if last_known == Vector3.INF:
		_set_state(State.SEARCH)
		return
	npc.aim_point = last_known + Vector3(0, 1.2, 0)
	var d := npc.global_position.distance_to(last_known)
	if unseen > 2.0 and grenade_ready(p) and d > 8.0 and d < 32.0:
		_grenade_t = 6.0
		npc.throw_grenade(last_known, lerpf(4.0, 1.5, float(p["grenade"]) / 0.3))
		return
	if unseen > 4.0 and not _flank_tried:
		_flank_tried = true
		if _rng.randf() < float(p["flank"]):
			var f := _flank_point()
			if f != Vector3.INF:
				cover = f
				npc.go_to(f, HumanNpc.RUN_SPEED)
				return
	_advance_t -= dt
	if unseen > 6.0 and _advance_t <= 0.0 and float(p["cover"]) > 0.4:
		# Avanza a una cobertura más cerca de donde estabas
		_advance_t = _rng.randf_range(5.0, 9.0)
		var c := _find_cover(last_known, true)
		cover = c if c != Vector3.INF else last_known
	if cover != Vector3.INF:
		npc.go_to(cover, HumanNpc.WALK_SPEED * 1.4)
		if npc.arrived():
			npc.stop()
	if unseen > 20.0 + float(p["reaction"]) * 10.0:
		_start_search()


func grenade_ready(p: Dictionary) -> bool:
	return npc.grenades > 0 and _grenade_t <= 0.0 and _rng.randf() < float(p["grenade"])


func _start_search() -> void:
	_set_state(State.SEARCH)
	_search_pts.clear()
	if last_known != Vector3.INF:
		_search_pts.append(last_known)
		for i in 3:
			_search_pts.append(last_known + _jitter(8.0))
	cover = Vector3.INF


func _search(_dt: float) -> void:
	npc.raised = true
	npc.aim_point = Vector3.INF
	npc.burst_left = 0
	npc.crouching = false
	if _search_pts.is_empty() or state_t > 45.0:
		awareness = 0.3
		_set_state(State.PATROL if npc.patrol.size() > 1 else State.IDLE)
		return
	npc.go_to(_search_pts[0], HumanNpc.WALK_SPEED)
	if npc.arrived() or npc.is_stuck():
		_search_pts.pop_front()
		npc.look_yaw = npc.rotation.y + _rng.randf_range(-2.0, 2.0)


func _retreat(_dt: float) -> void:
	npc.burst_left = 0
	npc.aim_point = last_known + Vector3(0, 1.2, 0) if last_known != Vector3.INF else Vector3.INF
	if cover != Vector3.INF and not npc.arrived():
		npc.go_to(cover, HumanNpc.RUN_SPEED)
		return
	npc.stop()
	npc.crouching = true
	if not npc.is_healing():
		if npc.has_medkit:
			npc.start_heal()
		else:
			_set_state(State.COMBAT)
			cover = Vector3.INF
	if state_t > 12.0 or (not npc.is_healing() and npc.hp > float(prof()["retreat_hp"])):
		_set_state(State.COMBAT)
		cover = Vector3.INF


# --- Utilidades ----------------------------------------------------------------------

## Dónde apunta: al pecho (o a la cabeza, a veces), con un poco de adelanto si corre.
func _aim_spot() -> Vector3:
	var pts := _target_points(target)
	var spot := pts[1]
	if pts.size() >= 3:
		# A lo que se ve: el pecho; si está tapado, la cabeza o la cadera
		if not _vis[1]:
			spot = pts[0] if _vis[0] else (pts[2] if _vis[2] else pts[1])
		elif _aim_head and _vis[0]:
			spot = pts[0]
	var tp := target as Player
	if tp != null:
		var dist := npc.global_position.distance_to(tp.global_position)
		spot += Vector3(tp.velocity.x, 0, tp.velocity.z) * (dist / maxf(npc.weapon.muzzle_velocity, 100.0)) * 0.6
	return spot


func _weapon_range() -> float:
	var w := npc.weapon
	if w.pellets > 1:
		return 22.0
	if w.slot == 3:
		return 30.0
	if w.caliber in ["9×19", "9×18", ".45 ACP", ".22 LR"]:
		return 45.0
	return 110.0


## No dispara si hay un compañero en la línea de tiro.
func _clear_line() -> bool:
	var from := npc.body.muzzle_position()
	var rq := PhysicsRayQueryParameters3D.create(from, npc.aim_point, 1 | (1 << (NpcBody.HITBOX_LAYER - 1)))
	rq.exclude = npc._exclude
	var hit := npc.get_world_3d().direct_space_state.intersect_ray(rq)
	if hit.is_empty():
		return true
	var c := hit["collider"] as Node
	if c != null and c.has_meta("zone_owner"):
		var o: Variant = c.get_meta("zone_owner")
		if o is HumanNpc and o != npc and not (o as HumanNpc).dead:
			# Se corre un poco para tener línea
			npc.go_to(npc.global_position + npc.global_basis.x * _rng.randf_range(-2.5, 2.5))
			return false
	return true


## Busca una cobertura: un punto de la malla de navegación desde donde, agachado, no
## se lo ve desde `threat`. advance = que quede más cerca del enemigo.
func _find_cover(threat: Vector3, advance: bool, rmin := 3.0, rmax := 14.0) -> Vector3:
	var map := npc.get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(map) == 0:
		return Vector3.INF
	var space := npc.get_world_3d().direct_space_state
	var eye_t := threat + Vector3(0, 1.5, 0)
	var me := npc.global_position
	var best := Vector3.INF
	var best_s := INF
	var d_now := me.distance_to(threat)
	var claimed := _claimed_covers()
	for i in 16:
		var a := TAU * i / 16.0 + _rng.randf_range(-0.15, 0.15)
		var r := _rng.randf_range(rmin, rmax)
		var c := NavigationServer3D.map_get_closest_point(map, me + Vector3(cos(a), 0, sin(a)) * r)
		if c.distance_to(me + Vector3(cos(a), 0, sin(a)) * r) > 2.5:
			continue
		var dt := c.distance_to(threat)
		if dt < 6.0:
			continue
		if advance and dt > d_now - 3.0:
			continue
		var crowd := false
		for o: Vector3 in claimed:
			if o.distance_to(c) < 2.0:
				crowd = true
				break
		if crowd:
			continue
		var rq := PhysicsRayQueryParameters3D.create(c + Vector3(0, 0.9, 0), eye_t, SIGHT_MASK)
		if target is CollisionObject3D:
			rq.exclude = [target.get_rid()]
		if space.intersect_ray(rq).is_empty():
			continue  # agachado se lo ve: no es cobertura
		var rq2 := PhysicsRayQueryParameters3D.create(c + Vector3(0, 1.55, 0), eye_t, SIGHT_MASK)
		rq2.exclude = rq.exclude
		var peek := space.intersect_ray(rq2).is_empty()
		var s := c.distance_to(me) * 0.6 - (3.0 if peek else 0.0) + absf(dt - 22.0) * 0.08
		if advance:
			s += dt * 0.3
		if s < best_s:
			best_s = s
			best = c
	return best


func _claimed_covers() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for n in npc.get_tree().get_nodes_in_group("ai_npc"):
		var o := n as HumanNpc
		if o != null and o != npc and o.brain != null and o.brain.cover != Vector3.INF:
			out.append(o.brain.cover)
	return out


## Un punto a un costado de donde lo vio por última vez, para entrarle de flanco.
func _flank_point() -> Vector3:
	var map := npc.get_world_3d().navigation_map
	var to := last_known - npc.global_position
	to.y = 0.0
	if to.length() < 1.0:
		return Vector3.INF
	var side := to.normalized().cross(Vector3.UP) * (1.0 if _rng.randf() < 0.5 else -1.0)
	var p := last_known - to.normalized() * 10.0 + side * _rng.randf_range(12.0, 18.0)
	var c := NavigationServer3D.map_get_closest_point(map, p)
	return c if c.distance_to(p) < 6.0 else Vector3.INF


func _jitter(r: float) -> Vector3:
	return Vector3(_rng.randf_range(-r, r), 0, _rng.randf_range(-r, r))
