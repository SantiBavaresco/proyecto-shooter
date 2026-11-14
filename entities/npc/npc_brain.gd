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
## Ajustes generales de la IA (data/ai/ai_tuning.tres).
var T: AiTuning = AiTuning.get_default()

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
## Rol que le dio el comandante de la escuadra ("" = pelea por su cuenta).
var role: String = ""
var role_dest: Vector3 = Vector3.INF
var _role_t: float = 0.0
var _pending: Array = []
## Patrulla en formación: dónde ir y hacia dónde mirar (los pone la escuadra).
var follow_pos: Vector3 = Vector3.INF
var follow_yaw: float = 0.0
var _supp_point: Vector3 = Vector3.INF
var _melee_cd: float = 0.0
var _dodge_t: float = 0.0
## Lo ve "a través" de un arbusto: no lo ve de verdad, pero el fogonazo o el
## movimiento lo delatan; tira al cuerpo, con más error y nunca a la cabeza.
var concealed: bool = false
## Cuánto hace que lo vio por última vez metido en un arbusto (para "tirarle al arbusto").
var _bush_t: float = 99.0
var _bush_lost: bool = false


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


## Rol de la escuadra (con demora: los aliados no militares tardan en obedecer).
func set_role(r: String, dest := Vector3.INF, delay := 0.0) -> void:
	if delay > 0.0:
		_pending = [r, dest, delay]
		return
	_pending = []
	if r != role:
		_role_t = 0.0
	role = r
	role_dest = dest
	if r in ["advance", "flank", "retreat"] and dest != Vector3.INF:
		cover = dest
	_side_sign = 0.0 if r != "flank" else _side_sign


## Rol que le dieron y todavía no cumple (está "tardando en obedecer").
func pending_role() -> String:
	return String(_pending[0]) if not _pending.is_empty() else ""


func role_age() -> float:
	return _role_t


func _squad() -> Squad:
	return npc.squad_obj


func update(delta: float) -> void:
	state_t += delta
	_role_t += delta
	_dodge_t -= delta
	if not _pending.is_empty():
		_pending[2] = float(_pending[2]) - delta
		if float(_pending[2]) <= 0.0:
			var pr := _pending
			_pending = []
			set_role(String(pr[0]), pr[1])
	_burst_pause -= delta
	_melee_cd -= delta
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
	if _animals(dt):
		_track(delta)
		return
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
	if animal != null and is_instance_valid(animal) and not animal.dead:
		npc.aim_point = animal.global_position + Vector3(0, animal.spec.leg + 0.2, 0)
		return
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
	var veiled := 0
	_vis = [false, false, false]
	if dist < rng_eff and ang < fov * 0.5:
		var space := npc.get_world_3d().direct_space_state
		for i in pts.size():
			var rq := PhysicsRayQueryParameters3D.create(eye, pts[i], SIGHT_MASK)
			rq.exclude = [target.get_rid()] if target is CollisionObject3D else []
			var hit := space.intersect_ray(rq)
			if SmokeCloud.blocks(npc.get_tree(), eye, pts[i]):
				continue
			if hit.is_empty():
				seen += 1
				if i < 3:
					_vis[i] = true
			elif _is_foliage(hit) and (hit["position"] as Vector3).distance_to(pts[i]) < 2.5:
				veiled += 1  # lo tapa un arbusto que tiene encima
	# Metido en un arbusto: si tira (fogonazo) o se mueve, se delata
	concealed = false
	_bush_t += dt
	if veiled > 0:
		_bush_t = 0.0
	if seen == 0 and veiled > 0 and pl != null:
		var spd0 := Vector2(pl.velocity.x, pl.velocity.z).length()
		# De cerca un arbusto no esconde a nadie (alerta, a unos metros se nota el bulto)
		var close := T.bush_seen_alert if alert else T.bush_seen_calm
		if pl.fired_recently(2.5) or spd0 > 1.5 or dist < close:
			seen = 1
			concealed = true
			_vis = [false, true, false]
	_exposure = seen / float(pts.size()) * (0.6 if concealed else 1.0)
	if seen > 0:
		# De lejos cuesta bastante más darse cuenta (cae más rápido que la distancia)
		var rate := 1.0 / float(p["notice"]) * clampf(pow(20.0 / maxf(dist, 4.0), 1.5), 0.08, 3.0) * _exposure
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
		_say_contact()
	var was_visible := target_visible
	target_visible = seen > 0 and state == State.COMBAT
	if target_visible and not was_visible and unseen > 0.6:
		# Lo vuelve a ver (se asomó): necesita su tiempo para reaccionar, aunque ya
		# estuviera apuntando a esa esquina
		reaction_left = maxf(reaction_left, float(prof()["reaction"]) * _rng.randf_range(0.75, 1.1))
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


## Mira hacia ese punto (guardia que oyó algo lejos).
func _face(p: Vector3) -> void:
	var to := p - npc.global_position
	npc.look_yaw = atan2(-to.x, -to.z)


## Ruido: disparos, pasos, explosiones. Los aliados que disparan también alertan.
func on_noise(pos: Vector3, radius: float, source: Node) -> void:
	var d := pos.distance_to(npc.global_position)
	if d > radius * float(prof()["hearing"]) * npc.hearing_mult:
		return
	var ally := source is HumanNpc
	if ally:
		# Un compañero tirotea: los de cerca se meten; los de más lejos van a ver con
		# cuidado; los muy lejos solo se ponen alerta (no cruzan el mapa por un tiroteo
		# ajeno, ni se encadena la alarma de grupo en grupo)
		var other := source as HumanNpc
		if other.brain != null and other.brain.state == State.COMBAT and other.brain.last_known != Vector3.INF \
				and state != State.COMBAT:
			if d < T.ally_join:
				_enter_combat(other.brain.last_known + _jitter(4.0), false)
			elif d < T.ally_check and state in [State.IDLE, State.PATROL]:
				awareness = maxf(awareness, 0.6)
				_investigate_at(other.global_position.lerp(npc.global_position, 0.4) + _jitter(6.0), false)
			else:
				awareness = maxf(awareness, 0.5)
				_face(pos)
		return
	if source != null and not source.is_in_group("player") and not (source is Grenade):
		return
	# Granada: lo que se oye es la explosión, pero de dónde vino es la pista (la
	# tiraron desde por allá, no está parado donde explotó)
	if source is Grenade and (source as Grenade).thrower is Node3D and is_instance_valid((source as Grenade).thrower):
		var thr := (source as Grenade).thrower as Node3D
		if thr.is_in_group("player"):
			var away := thr.global_position - pos
			pos = thr.global_position + _jitter(clampf(away.length() * 0.35, 3.0, 9.0))
			d = pos.distance_to(npc.global_position)
	var err := _jitter(d * 0.12)
	if radius >= 40.0 and d > T.far_shot:
		# Muy lejos: se pone alerta y mira para ese lado, pero no deja su puesto
		awareness = maxf(awareness, 0.5)
		if state in [State.IDLE, State.PATROL]:
			_face(pos)
		return
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
	# Lo mordió un animal: se defiende de ese (no es "el jugador")
	if info.source is Animal:
		animal = info.source as Animal
		_animal_t = 0.0
		awareness = maxf(awareness, 0.8)
		return
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


# --- Animales ------------------------------------------------------------------------

## Animal al que le está tirando (o null).
var animal: Animal = null
var _animal_t: float = 0.0
var _animal_scan: float = 0.0


## Perros y jabalíes que se le vienen encima (o que lo atacaron) a menos de 15 m: les
## tira. Los carpinchos los deja en paz salvo que lo muerdan. Devuelve true si está
## ocupado con un animal (y no hace lo de siempre en este pensamiento).
func _animals(dt: float) -> bool:
	_animal_scan -= dt
	if _animal_scan <= 0.0:
		_animal_scan = 0.4
		var a := _spot_animal()
		if a != null and (animal == null or not is_instance_valid(animal) or animal.dead):
			animal = a
			_animal_t = 0.0
	if animal == null or not is_instance_valid(animal) or animal.dead or animal.is_hidden():
		animal = null
		return false
	var d := npc.global_position.distance_to(animal.global_position)
	_animal_t += dt
	if d > T.animal_sight * 1.6 or animal.state == Animal.State.FLEE and d > 8.0 or _animal_t > 25.0:
		animal = null
		return false
	# Si estás a la vista y el animal no está encima, sigue con vos
	if state == State.COMBAT and target_visible and d > 5.0:
		return false
	npc.stop()
	npc.raised = true
	npc.crouching = false
	npc.aim_point = animal.global_position + Vector3(0, animal.spec.leg + 0.2, 0)
	var p := prof()
	# Blanco chico y rápido: más error si corre
	var spd := Vector2(animal.velocity.x, animal.velocity.z).length()
	npc.aim_error_deg = _base_error(p, d) * (1.0 + spd * 0.12) * (1.0 + npc.stress * 0.5)
	if not npc.reloading and npc.burst_left <= 0 and _burst_pause <= 0.0 and _clear_line():
		var auto := npc.weapon.has_mode("auto")
		npc.burst_left = _rng.randi_range(2, 4) if auto else 1
		if npc.weapon.pellets > 1 or npc.weapon.bolt_action:
			npc.burst_left = 1
		_burst_pause = _rng.randf_range(0.25, 0.6) + (0.3 if not auto else 0.0)
	if npc.has_method("speak") and _animal_t < dt * 1.5:
		npc.call("speak", "contact", false)
	return true


func _spot_animal() -> Animal:
	var best: Animal = null
	var best_d := T.animal_sight
	var eye := npc.body.eye_position()
	var fwd := npc.aim_forward()
	for n in npc.get_tree().get_nodes_in_group("animals"):
		var a := n as Animal
		if a == null or a.dead or a.is_hidden():
			continue
		var d := a.global_position.distance_to(npc.global_position)
		if d >= best_d:
			continue
		var hostile := a.spec.attack_style != "cornered" and (a.state in [Animal.State.ALERT, Animal.State.ATTACK, Animal.State.RETREAT] or d < 8.0)
		if a.target == npc and a.state == Animal.State.ATTACK:
			hostile = true
		if not hostile:
			continue
		# De espaldas solo los oye si están muy cerca
		var to := a.global_position - npc.global_position
		if d > 5.0 and rad_to_deg(Vector3(fwd.x, 0, fwd.z).angle_to(Vector3(to.x, 0, to.z))) > 80.0:
			continue
		var rq := PhysicsRayQueryParameters3D.create(eye, a.global_position + Vector3(0, 0.5, 0), 1 | (1 << 8))
		rq.exclude = npc._exclude
		if not npc.get_world_3d().direct_space_state.intersect_ray(rq).is_empty():
			continue
		best_d = d
		best = a
	return best


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


func _investigate_at(p: Vector3, share := true) -> void:
	var was := state
	investigate_pos = p
	_set_state(State.INVESTIGATE)
	_pause_t = _rng.randf_range(0.4, 1.0)
	# Militares: en silencio frena a los suyos con una seña (o les habla bajo) y van todos
	var sq := _squad()
	if share and sq != null and sq.commanded and npc.tactics == "military" and was != State.INVESTIGATE:
		sq.say(npc, "hold", true)
		for o in sq.alive():
			if o != npc and o.tactics == "military" and o.global_position.distance_to(npc.global_position) < 35.0 \
					and o.brain.state in [State.IDLE, State.PATROL]:
				o.brain._investigate_at(p + _jitter(4.0), false)


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
	if follow_pos != Vector3.INF:
		# Sigue al líder en formación
		if npc.global_position.distance_to(follow_pos) > 1.5:
			npc.go_to(follow_pos, HumanNpc.WALK_SPEED * 1.15)
		else:
			npc.stop()
			npc.look_yaw = follow_yaw
		return
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
	if _dodge_grenade():
		return
	if role != "" and _squad() != null:
		_squad_combat(dt, p)
	elif target_visible:
		_engage(dt, p)
	else:
		_lost(dt, p)


## Lo ve: dispara en ráfagas y maneja la posición (cubrirse, asomarse, avanzar).
func _engage(dt: float, p: Dictionary) -> void:
	_fire_visible(dt, p)
	var dist := npc.global_position.distance_to(target.global_position)
	_position(dt, p, dist)


## Lo ve: apunta y tira ráfagas (error según la dificultad, el estrés y si se mueve).
func _fire_visible(dt: float, p: Dictionary) -> void:
	npc.aim_point = _aim_spot()
	# Encima tuyo: culatazo
	if _melee_check():
		return
	reaction_left -= dt
	var floor_k := float(p["settle_floor"])
	var settle := clampf(track_time / float(p["settle_time"]), 0.0, 1.0)
	var d0 := npc.global_position.distance_to(target.global_position)
	npc.aim_error_deg = _base_error(p, d0) * lerpf(1.0, floor_k, settle)
	var tp := target as Player
	if tp != null and Vector2(tp.velocity.x, tp.velocity.z).length() > 2.0:
		npc.aim_error_deg *= 1.4
	if _under_fire > 0.0:
		npc.aim_error_deg *= 1.25
	npc.aim_error_deg *= 1.0 + npc.stress * 0.8
	if concealed:
		npc.aim_error_deg *= 1.6
	# Con el último cargador: tira menos pero cuida cada tiro
	if npc.low_ammo():
		npc.aim_error_deg *= 0.7
	var dist := npc.global_position.distance_to(target.global_position)
	var moving := npc.move_target != Vector3.INF and not npc.arrived()
	if moving:
		npc.aim_error_deg *= 1.5  # caminando tira peor
	var can_shoot := reaction_left <= 0.0 and not npc.reloading and (not moving or bool(p["move_shoot"]) or _strafing) \
		and not npc.sprinting
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
		if npc.low_ammo():
			npc.burst_left = mini(npc.burst_left, _rng.randi_range(1, 2))
			_burst_pause = _burst_pause * 1.8 + 0.4
		_aim_head = _rng.randf() < float(p["head_aim"])


## Si lo tiene encima (y lo ve), le pega un culatazo. true si lo hizo (o lo está por hacer).
func _melee_check() -> bool:
	if target == null or not is_instance_valid(target) or not target_visible:
		return false
	var d := Vector2(target.global_position.x - npc.global_position.x, target.global_position.z - npc.global_position.z).length()
	if d > T.melee_range or absf(target.global_position.y - npc.global_position.y) > 1.0:
		return false
	if _melee_cd > 0.0:
		return _melee_cd > 0.8  # recién pegó: se recompone antes de tirar
	_melee_cd = _rng.randf_range(1.6, 2.4)
	npc.burst_left = 0
	npc.melee(target, _rng.randf() < T.melee_knockdown)
	return true


## Error de puntería (grados) a esa distancia: dispersión en metros que crece con la
## raíz de la distancia (ver Difficulty, "spread").
func _base_error(p: Dictionary, dist: float) -> float:
	var d := maxf(dist, 1.0)
	return rad_to_deg(atan(float(p.get("spread", 0.6)) * sqrt(d) / d))


## Dónde pararse peleando solo: cubrirse, asomarse, acercarse si no llega.
func _position(dt: float, p: Dictionary, dist: float) -> void:
	_strafing = false
	npc.body.peek_lean = 0.0
	_cover_t -= dt
	var range_ok := dist < _weapon_range()
	if npc.reloading and cover == Vector3.INF and _rng.randf() < float(p["cover"]) * dt * 3.0:
		cover = _find_cover(target.global_position, false)
	if _cover_t <= 0.0:
		_cover_t = _rng.randf_range(4.0, 8.0)
		var want_cover := _under_fire > 0.0 or _exposure > 0.3 or target_visible
		if not range_ok:
			cover = _find_cover(target.global_position, true)
		elif want_cover and _rng.randf() < float(p["cover"]):
			cover = _find_cover(target.global_position, false)
	if cover != Vector3.INF:
		_strafing = false
		npc.go_to(cover, HumanNpc.RUN_SPEED if _under_fire > 0.0 else HumanNpc.WALK_SPEED * 1.6)
		if npc.arrived():
			npc.stop()
			_peek(dt, p)
		else:
			npc.crouching = false
	else:
		# Sin cobertura: no se queda parado al descubierto; se va moviendo de costado
		# mientras tira (peor puntería) y sigue buscando dónde cubrirse
		_strafe(dt)


## A cubierto: agachado cuando no tira, se asoma (se para) para la ráfaga.
var _strafing: bool = false
var _strafe_t: float = 0.0
var _strafe_side: float = 1.0


## Al descubierto: camina de costado (cambiando de lado cada tanto), un poco hacia
## adelante o atrás, y mira de nuevo si hay una cobertura cerca.
func _strafe(dt: float) -> void:
	_strafing = true
	npc.crouching = false
	_strafe_t -= dt
	if target == null or not is_instance_valid(target):
		return
	if _strafe_t <= 0.0 or npc.arrived() or npc.is_stuck():
		_strafe_t = _rng.randf_range(1.4, 3.0)
		if _rng.randf() < 0.6:
			_strafe_side = -_strafe_side
		var to := target.global_position - npc.global_position
		to.y = 0.0
		var side := to.normalized().cross(Vector3.UP) * _strafe_side
		var p := npc.global_position + side * _rng.randf_range(2.5, 4.5) + to.normalized() * _rng.randf_range(-1.5, 1.0)
		var map := npc.get_world_3d().navigation_map
		if NavigationServer3D.map_get_iteration_id(map) > 0:
			p = NavigationServer3D.map_get_closest_point(map, p)
		npc.go_to(p, HumanNpc.WALK_SPEED * 1.1)
		# Cobertura cerca: la próxima vez va para ahí
		_cover_t = minf(_cover_t, 1.0)


## A cubierto. Cobertura baja: agachado atrás y se para solo para tirar. Cobertura alta:
## parado atrás, y para tirar da un paso al costado inclinándose y vuelve.
func _peek(dt: float, p: Dictionary) -> void:
	_peek_t -= dt
	if _cover_kind_at != cover:
		_cover_kind_at = cover
		_classify_cover()
	if npc.reloading or npc.is_healing():
		npc.crouching = _cover_kind != "tall"
		npc.body.peek_lean = 0.0
		_go_back_to_cover()
		return
	var firing := npc.burst_left > 0 or (_burst_pause <= 0.2 and target_visible)
	match _cover_kind:
		"tall":
			npc.crouching = false
			if firing and _peek_side != 0.0:
				var out := cover + _peek_dir * 0.75
				if npc.global_position.distance_to(out) > 0.25:
					npc.go_to(out, HumanNpc.WALK_SPEED)
				npc.body.peek_lean = _peek_side
			else:
				npc.body.peek_lean = 0.0
				_go_back_to_cover()
		_:
			npc.body.peek_lean = 0.0
			# Baja (o ninguna): agachado; se para para tirar si agachado no ve
			if firing:
				npc.crouching = _crouched_sees()
			else:
				npc.crouching = true


var _cover_kind: String = ""
var _cover_kind_at: Vector3 = Vector3.INF
var _peek_side: float = 0.0
var _peek_dir: Vector3 = Vector3.ZERO


func _go_back_to_cover() -> void:
	if cover != Vector3.INF and npc.global_position.distance_to(cover) > 0.35:
		npc.go_to(cover, HumanNpc.WALK_SPEED)
	else:
		npc.stop()


## ¿Qué tan alta es la cobertura (respecto de donde estás)? Y para qué lado asomarse.
func _classify_cover() -> void:
	_cover_kind = "low"
	_peek_side = 0.0
	var threat := last_known if last_known != Vector3.INF else (target.global_position if target != null and is_instance_valid(target) else Vector3.INF)
	if threat == Vector3.INF or cover == Vector3.INF:
		return
	var space := npc.get_world_3d().direct_space_state
	var to := threat - cover
	to.y = 0.0
	if to.length() < 0.5:
		return
	var f := to.normalized()
	var stand := cover + Vector3(0, 1.55, 0)
	var q := PhysicsRayQueryParameters3D.create(stand, stand + f * 2.0, 1)
	q.exclude = npc._exclude
	if space.intersect_ray(q).is_empty():
		return  # parado ve por arriba: es baja
	_cover_kind = "tall"
	# Asomarse por el lado que está libre
	var right := f.cross(Vector3.UP).normalized()
	for side: float in ([1.0, -1.0] if _rng.randf() < 0.5 else [-1.0, 1.0]):
		var from := stand + right * side * 0.8
		var q2 := PhysicsRayQueryParameters3D.create(from, from + f * 2.0, 1)
		q2.exclude = npc._exclude
		var q3 := PhysicsRayQueryParameters3D.create(stand, from, 1)
		q3.exclude = npc._exclude
		if space.intersect_ray(q2).is_empty() and space.intersect_ray(q3).is_empty():
			_peek_side = side
			_peek_dir = right * side
			return


func _is_foliage(hit: Dictionary) -> bool:
	var c := hit.get("collider") as CollisionObject3D
	return c != null and (c.collision_layer & (1 << 8)) != 0


func _crouched_sees() -> bool:
	if target == null:
		return false
	var from := npc.global_position + Vector3(0, 1.0, 0)
	var rq := PhysicsRayQueryParameters3D.create(from, _target_points(target)[1], SIGHT_MASK)
	rq.exclude = [target.get_rid()] if target is CollisionObject3D else []
	return npc.get_world_3d().direct_space_state.intersect_ray(rq).is_empty()


## Lo perdió de vista: espera, flanquea, avanza o tira una granada.
func _lost(dt: float, p: Dictionary) -> void:
	if last_known == Vector3.INF:
		_set_state(State.SEARCH)
		return
	var d := npc.global_position.distance_to(last_known)
	# Se metió en un arbusto: le tira al arbusto (reconocimiento por fuego) desde donde
	# está, en vez de ir a meterse adentro hasta chocarlo
	if _bush_t < 1.5 or (unseen < T.bush_fire_time and _bush_lost):
		_bush_lost = true
		if unseen < T.bush_fire_time and d > 3.0 and d < 45.0 and npc.ammo_left() > 0:
			npc.stop()
			_suppress_fire(dt, p)
			return
	_bush_lost = false
	npc.burst_left = 0
	npc.crouching = false
	npc.aim_point = last_known + Vector3(0, 1.2, 0)
	if unseen > 2.0 and grenade_ready(p) and d > 8.0 and d < 32.0:
		_grenade_t = 6.0
		npc.throw_grenade(last_known, lerpf(4.0, 1.5, float(p["grenade"]) / 0.3))
		if _squad() != null:
			_squad().say(npc, "grenade_out")
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
		# Sin cobertura: se arrima, pero no hasta encima de donde te perdió
		cover = c if c != Vector3.INF else last_known + (npc.global_position - last_known).normalized() * minf(d, 7.0)
	# Esperando a que reaparezcas: no parado en el medio de la nada
	_cover_t -= dt
	if cover == Vector3.INF and _cover_t <= 0.0:
		_cover_t = _rng.randf_range(2.5, 4.5)
		cover = _find_cover(last_known, false, 1.5, 10.0)
	if cover != Vector3.INF:
		npc.go_to(cover, HumanNpc.WALK_SPEED * 1.4)
		if npc.arrived():
			npc.stop()
			npc.crouching = true
	else:
		npc.crouching = true
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
	if concealed:
		# Tira al bulto dentro del arbusto: al cuerpo, sin cabeza, a donde vio el fogonazo
		var j := _jitter(0.35)
		j.y = -absf(j.y)  # nunca para arriba (hacia la cabeza)
		return pts[1].lerp(pts[2], _rng.randf_range(0.25, 1.0)) + j
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
	# Candidatos: detrás de cada cosa que tapa (tronco, arbusto, caja, muro), del lado
	# contrario a la amenaza; y además unos puntos al azar por si hay pozos o lomas
	var cands: Array = []
	for e: Array in CoverIndex.near(npc, me, rmax + 1.0):
		var oc: Vector3 = e[0]
		var away := Vector3(oc.x - threat.x, 0, oc.z - threat.z)
		if away.length() < 0.1:
			continue
		var want := oc + away.normalized() * (float(e[1]) + 0.55)
		var dm := Vector2(want.x - me.x, want.z - me.z).length()
		if dm < 0.6 or dm > rmax + 1.0:
			continue
		cands.append([want, bool(e[2])])
	cands.sort_custom(func(x: Array, y: Array) -> bool:
		return (x[0] as Vector3).distance_squared_to(me) < (y[0] as Vector3).distance_squared_to(me))
	cands = cands.slice(0, 28)
	for i in 10:
		var a := TAU * i / 10.0 + _rng.randf_range(-0.2, 0.2)
		cands.append([me + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(rmin, rmax), true])
	for cd: Array in cands:
		var want_p: Vector3 = cd[0]
		var c := NavigationServer3D.map_get_closest_point(map, want_p)
		if Vector2(c.x - want_p.x, c.z - want_p.z).length() > 1.2:
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
		# Más cerca es mejor; poder asomarse parado, también; lo que para balas, mejor
		# que un arbusto que solo tapa la vista
		var s := c.distance_to(me) * 0.6 - (3.0 if peek else 0.0) + absf(dt - 22.0) * 0.08 - (2.0 if bool(cd[1]) else 0.0)
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


var _side_sign: float = 0.0


## Un punto a un costado de donde lo vio por última vez (a 8–12 m de ese lugar, de
## costado), para entrarle de flanco. Prefiere una cobertura ahí.
func _flank_point() -> Vector3:
	var map := npc.get_world_3d().navigation_map
	var to := last_known - npc.global_position
	to.y = 0.0
	if to.length() < 1.0:
		return Vector3.INF
	# El lado: el que le queda más a mano (o al azar), y no el mismo que otro flanqueador
	if _side_sign == 0.0:
		_side_sign = 1.0 if _rng.randf() < 0.5 else -1.0
		var sq := _squad()
		if sq != null:
			for m in sq.alive():
				if m != npc and m.brain.role in ["flank", "assault"] and m.brain._side_sign != 0.0:
					_side_sign = -m.brain._side_sign
	var side := to.normalized().cross(Vector3.UP) * _side_sign
	for k in 3:
		var p := last_known + side * _rng.randf_range(8.0, 12.0) - to.normalized() * _rng.randf_range(0.0, 4.0)
		var c := NavigationServer3D.map_get_closest_point(map, p)
		if c.distance_to(p) < 5.0:
			var cv := _find_cover_near(c, last_known)
			return cv if cv != Vector3.INF else c
		side = side.rotated(Vector3.UP, 0.35 * _side_sign)
	return Vector3.INF


## Cobertura a 4 m de `at` que tape de `threat` (o INF).
func _find_cover_near(at: Vector3, threat: Vector3) -> Vector3:
	for e: Array in CoverIndex.near(npc, at, 4.0):
		var p: Vector3 = e[0]
		var away := (p - threat)
		away.y = 0
		if away.length() < 1.0:
			continue
		return p + away.normalized() * (float(e[1]) + 0.6)
	return Vector3.INF


func _jitter(r: float) -> Vector3:
	return Vector3(_rng.randf_range(-r, r), 0, _rng.randf_range(-r, r))



# --- Escuadra --------------------------------------------------------------------------

## Pelea con el rol que le dio el comandante.
func _squad_combat(dt: float, p: Dictionary) -> void:
	var lk := last_known + Vector3(0, 1.2, 0) if last_known != Vector3.INF else Vector3.INF
	match role:
		"reload":
			npc.burst_left = 0
			if cover == Vector3.INF:
				cover = _find_cover(last_known, false, 2.0, 9.0)
			if cover != Vector3.INF and not npc.arrived():
				npc.go_to(cover, HumanNpc.RUN_SPEED)
			else:
				npc.stop()
				npc.crouching = true
			npc.aim_point = lk
		"advance", "flank", "retreat":
			if role_dest != Vector3.INF and npc.global_position.distance_to(role_dest) > 1.3:
				npc.go_to(role_dest, HumanNpc.RUN_SPEED)
				npc.crouching = false
				if target_visible and bool(p["move_shoot"]):
					_fire_visible(dt, p)
				else:
					npc.burst_left = 0
					npc.aim_point = lk
			elif role == "flank" and not target_visible and unseen > 1.5 and last_known != Vector3.INF:
				# Llegó al costado y no te ve: entra (de a uno, rápido, tirando si te ve)
				set_role("assault", last_known)
				if npc.voice_id != "" and _squad() != null:
					_squad().say(npc, "moving")
			else:
				cover = role_dest
				_hold(dt, p)
		"assault":
			# Entra hasta donde te vio por última vez; si llega y no estás, te busca
			var dest := last_known if last_known != Vector3.INF else role_dest
			var dd := npc.global_position.distance_to(dest)
			if target_visible:
				if dd < 8.0:
					npc.stop()
				else:
					npc.go_to(dest, HumanNpc.WALK_SPEED * 1.6)
				_fire_visible(dt, p)
				if role_age() > 6.0:
					set_role("hold")
			elif dd > 2.5:
				npc.go_to(dest, HumanNpc.RUN_SPEED if dd > 10.0 else HumanNpc.WALK_SPEED * 1.6)
				npc.crouching = false
				npc.burst_left = 0
				npc.aim_point = lk
			else:
				set_role("")
				last_known = dest
				_start_search()
		"suppress":
			_hold(dt, p)
			if not target_visible:
				_suppress_fire(dt, p)
		_:
			_hold(dt, p)


## A cubierto donde está (o en una cobertura cerca): se asoma y tira si lo ve.
func _hold(dt: float, p: Dictionary) -> void:
	_strafing = false
	npc.body.peek_lean = 0.0
	_cover_t -= dt
	if cover == Vector3.INF and _cover_t <= 0.0 and last_known != Vector3.INF:
		_cover_t = _rng.randf_range(3.0, 6.0)
		cover = _find_cover(last_known, false, 1.5, 7.0)
	if cover != Vector3.INF and not npc.arrived() and npc.global_position.distance_to(cover) > 1.0:
		npc.go_to(cover, HumanNpc.RUN_SPEED if _under_fire > 0.0 else HumanNpc.WALK_SPEED * 1.6)
		npc.crouching = false
	elif cover == Vector3.INF:
		# Sin dónde cubrirse: si lo ve, se mueve de costado tirando; si no, agachado
		if target_visible:
			_strafe(dt)
		else:
			_strafing = false
			npc.stop()
			npc.crouching = _crouched_sees() or npc.burst_left <= 0
	else:
		npc.stop()
		_peek(dt, p)
	if target_visible:
		_fire_visible(dt, p)
	elif role != "suppress":
		npc.burst_left = 0
		if last_known != Vector3.INF:
			npc.aim_point = last_known + Vector3(0, 1.2, 0)


## Fuego de cobertura: ráfagas a donde te vio por última vez (aunque no te vea, y
## aunque haya humo: no te sigue, tira a donde estabas) para que no te asomes.
func _suppress_fire(dt: float, p: Dictionary) -> void:
	if last_known == Vector3.INF:
		return
	# A ciegas no se tira para siempre, ni todos a la vez: de a uno o dos por escuadra
	var sq := _squad()
	if unseen > T.suppress_max_time or (sq != null and npc.burst_left <= 0 and not sq.may_suppress(npc)):
		npc.burst_left = 0
		npc.aim_point = last_known + Vector3(0, 1.2, 0)
		return
	reaction_left -= dt
	if reaction_left > 0.0 or npc.reloading:
		return
	if npc.burst_left <= 0:
		_supp_point = last_known + Vector3(0, _rng.randf_range(0.5, 1.5), 0) + _jitter(1.3)
	npc.aim_point = _supp_point
	npc.aim_error_deg = _base_error(p, npc.global_position.distance_to(_supp_point)) * 1.3 * (1.0 + npc.stress * 0.8)
	# Para tirar se para (agachado detrás de la cobertura le pegaría a la cobertura)
	if npc.burst_left > 0:
		npc.crouching = false
	if npc.burst_left <= 0 and _burst_pause <= 0.0 and _clear_line():
		var auto := npc.weapon.has_mode("auto")
		# Tiros sueltos o ráfagas cortas (no vaciar el cargador contra la pared)
		npc.burst_left = _rng.randi_range(1, 3) if auto else 1
		if npc.weapon.pellets > 1 or npc.weapon.bolt_action:
			npc.burst_left = 1
		if sq != null:
			sq.note_suppress(npc)
		var pause := float(p["burst_pause"]) * _rng.randf_range(1.4, 2.6) + (0.6 if not auto else 0.3)
		# Si le queda poca munición, cubre con menos
		if npc.ammo_left() < npc.weapon.mag_size * 2:
			pause *= 2.0
		_burst_pause = pause


## Una granada (del enemigo) cayó cerca: grita y se aleja corriendo.
func _dodge_grenade() -> bool:
	if _dodge_t > 0.0:
		return npc.move_target != Vector3.INF and not npc.arrived()
	for n in npc.get_tree().get_nodes_in_group("grenade"):
		var g := n as Grenade
		if g == null or g.item_id == "grenade_smoke" or g.thrower == npc:
			continue
		if g.thrower is HumanNpc and (g.thrower as HumanNpc).squad == npc.squad and npc.squad != "":
			continue
		var d := g.global_position.distance_to(npc.global_position)
		if d < 7.0 and g.linear_velocity.length() < 6.0:
			_dodge_t = 3.0
			var away := (npc.global_position - g.global_position)
			away.y = 0.0
			var to := npc.global_position + away.normalized() * 9.0
			var map := npc.get_world_3d().navigation_map
			if NavigationServer3D.map_get_iteration_id(map) != 0:
				to = NavigationServer3D.map_get_closest_point(map, to)
			npc.go_to(to, HumanNpc.RUN_SPEED)
			npc.crouching = false
			npc.burst_left = 0
			if _squad() != null:
				_squad().say(npc, "grenade_incoming")
			return true
	return false


## Avisa el contacto (a veces dice para qué lado estás).
func _say_contact() -> void:
	var sq := _squad()
	if sq == null or npc.voice_id == "" or target == null:
		return
	var to := target.global_position - npc.global_position
	var side := (-npc.global_basis.z.rotated(Vector3.UP, npc._yaw)).cross(to.normalized()).y
	var key := "contact"
	if absf(side) > 0.5 and _rng.randf() < 0.5:
		key = "left" if side > 0.0 else "right"
	sq.say(npc, key)
