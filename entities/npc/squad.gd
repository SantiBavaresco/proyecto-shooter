class_name Squad
extends Node
## Comandante de una escuadra con táctica militar. Cada medio segundo mira la pelea
## (cuántos quedan, quién te ve, quién recarga, a qué distancia estás) y reparte roles:
##
##  - suppress: tira de cobertura a donde te vio por última vez, aunque no te vea,
##    para que no te asomes (nunca te sigue a través del humo: tira a donde estabas).
##  - advance: corre a una cobertura más cerca tuyo mientras otros lo cubren.
##  - flank: te rodea por un costado.
##  - hold: espera a cubierto apuntando a donde estás (un ángulo).
##  - reload: recarga a cubierto (otro lo cubre).
##
## No es por turnos fijos: según la situación, uno o dos cubren y el resto avanza, o
## unos mantienen y otros flanquean. Siempre que alguien avanza, alguien tira.
## Avisan con la voz (gritan si están lejos o en pleno tiroteo, hablan si están cerca)
## o con señas si se ven y la cosa está tranquila. Los aliados que no son militares
## (bandidos del mismo "trabajo") también reciben órdenes, pero tardan en obedecer.

const EVAL := 0.5
## Frases que se pueden reemplazar por una seña con la mano.
const SIGNALS := {"moving": "advance", "flank": "flank", "hold": "hold", "search": "advance", "cover_me": "advance"}

var id: String = ""
var members: Array[HumanNpc] = []
var leader: HumanNpc = null
## La escuadra tiene un militar que manda (si no, cada uno pelea por su cuenta).
var commanded: bool = false
## Modo actual: "" (sin pelea), "push", "hold", "flank", "fall_back".
var mode: String = ""
var last_known: Vector3 = Vector3.INF
var _t: float = 0.0
var _flank_t: float = 0.0
var _smoke_t: float = 0.0
var _voice_t: float = 0.0
## Último disparo de alguien de la escuadra (para saber si la cosa está "caliente").
var last_shot_t: float = -99.0
var _clock: float = 0.0
var _initial: int = 0
var _rng := RandomNumberGenerator.new()
var _said_lost: bool = false
## Segundos en el modo actual (si la pelea se estanca, cambian de táctica).
var _mode_t: float = 0.0
## Cuándo se dijo cada frase por última vez (no repetir lo mismo a cada rato).
var _key_t: Dictionary = {}
const KEY_GAP := {"flank": 8.0, "reloading": 4.0, "moving": 4.0, "cover_me": 4.0, "covering": 4.0,
	"order_cover": 8.0, "order_flank": 8.0, "lost": 10.0, "contact": 6.0, "left": 6.0, "right": 6.0, "jam": 3.0}


## La escuadra de este personaje (la crea si no existe). null si no tiene escuadra.
static func get_for(n: HumanNpc) -> Squad:
	if n.squad == "" or not n.is_inside_tree():
		return null
	for s in n.get_tree().get_nodes_in_group("squad_coordinator"):
		var sq := s as Squad
		if sq.id == n.squad:
			return sq
	var sq := Squad.new()
	sq.id = n.squad
	sq.name = "Squad_" + n.squad
	n.get_parent().add_child(sq)
	return sq


func _ready() -> void:
	add_to_group("squad_coordinator")
	_rng.randomize()
	EventBus.npc_killed.connect(_on_killed)


func add(n: HumanNpc) -> void:
	if members.has(n):
		return
	members.append(n)
	_initial = members.size()
	if n.tactics == "military":
		commanded = true
		if leader == null or bool(n.loadout.get("leader", false)):
			leader = n


func alive() -> Array[HumanNpc]:
	var out: Array[HumanNpc] = []
	for m in members:
		if is_instance_valid(m) and not m.dead:
			out.append(m)
	return out


func is_hot() -> bool:
	return _clock - last_shot_t < 2.5


func note_shot() -> void:
	last_shot_t = _clock


func _physics_process(delta: float) -> void:
	_clock += delta
	_flank_t -= delta
	_smoke_t -= delta
	_voice_t -= delta
	_update_formation()
	_t -= delta
	if _t > 0.0:
		return
	_t = EVAL
	if commanded:
		_evaluate()


# --- Pelea --------------------------------------------------------------------------

func _evaluate() -> void:
	var live := alive()
	if live.is_empty():
		return
	if leader == null or leader.dead:
		leader = null
		for m in live:
			if m.tactics == "military":
				leader = m
				break
	var fighters: Array[HumanNpc] = []
	for m in live:
		if m.brain.state == NpcBrain.State.COMBAT:
			fighters.append(m)
	if fighters.is_empty():
		if mode != "":
			mode = ""
			for m in live:
				m.brain.set_role("")
		return
	# Lo que sabe uno lo saben todos (por radio o a los gritos)
	var best: HumanNpc = null
	for m in fighters:
		if m.brain.last_known != Vector3.INF and (best == null or m.brain.unseen < best.brain.unseen):
			best = m
	if best == null:
		return
	last_known = best.brain.last_known
	var min_unseen := best.brain.unseen
	for m in fighters:
		if m.brain.unseen > min_unseen + 1.0:
			m.brain.last_known = last_known
	# Los que todavía no pelean pero son de la escuadra se suman
	for m in live:
		if m.brain.state in [NpcBrain.State.IDLE, NpcBrain.State.PATROL, NpcBrain.State.INVESTIGATE, NpcBrain.State.SEARCH]:
			m.brain.on_callout(last_known)
	var n := fighters.size()
	if n == 1:
		fighters[0].brain.set_role("")
		mode = "solo"
		_lost_voice(min_unseen)
		return
	var avg_d := 0.0
	for m in fighters:
		avg_d += m.global_position.distance_to(last_known)
	avg_d /= n
	var losses := _initial - live.size()
	var prev_mode := mode
	# Modo de la escuadra
	if losses * 2 >= _initial and n <= 2 and _initial >= 3:
		mode = "fall_back"
	elif n >= 2 and _flank_t <= 0.0 and (min_unseen > 4.0 or (mode == "hold" and _mode_t > 6.0)):
		# Te perdieron, o la pelea se estancó: uno o dos te rodean y te entran
		mode = "flank"
		_flank_t = 16.0
	elif mode == "flank" and (_flank_t > 4.0 or _someone_with_role("assault", null) != null or _someone_with_role("flank", null) != null):
		pass  # dejan que los que rodean lleguen y entren
	elif avg_d > 24.0:
		mode = "push"
	else:
		mode = "hold" if min_unseen < 8.0 else "push"
	_mode_t = _mode_t + EVAL if mode == prev_mode else 0.0
	_assign(fighters, n, avg_d, min_unseen)
	_lost_voice(min_unseen)


func _assign(fighters: Array[HumanNpc], n: int, avg_d: float, unseen: float) -> void:
	var free: Array[HumanNpc] = []
	var suppressors: Array[HumanNpc] = []
	for m in fighters:
		if m.reloading or m.is_healing():
			if m.brain.role != "reload":
				m.brain.set_role("reload")
				if m.voice_id != "" and _rng.randf() < 0.7:
					say(m, "reloading")
		else:
			free.append(m)
	if free.is_empty():
		return
	# ¿Quién cubre? El que te ve, el que está a cubierto, el tirador; el que recién se
	# movió también (ya llegó y le toca tirar).
	var score := {}
	for m in free:
		score[m] = _sup_score(m)
	free.sort_custom(func(a: HumanNpc, b: HumanNpc) -> bool: return float(score[a]) > float(score[b]))
	var sup_n := clampi(roundi(n * 0.35), 1, mini(2, maxi(1, free.size() - 1)))
	if mode == "hold":
		sup_n = clampi(roundi(n * 0.5), 1, mini(2, free.size()))
	for i in sup_n:
		suppressors.append(free[i])
	var rest: Array[HumanNpc] = free.slice(sup_n)
	for m in suppressors:
		_give(m, "suppress", Vector3.INF)
	if rest.is_empty():
		return
	match mode:
		"fall_back":
			for m in rest:
				var away := m.brain._find_cover(last_known, false, 10.0, 24.0)
				_give(m, "retreat", away)
			if rest.size() > 0 and leader != null:
				say(leader, "fall_back")
		"flank":
			# Uno o dos rodean (por lados opuestos) y después entran; el resto mantiene
			var flankers := mini(2 if rest.size() >= 3 else 1, rest.size())
			var busy := 0
			for m in rest:
				if m.brain.role in ["flank", "assault"]:
					busy += 1
			for i in rest.size():
				var m := rest[i]
				if m.brain.role in ["flank", "assault"]:
					continue  # ya está en camino: que siga
				if busy < flankers:
					busy += 1
					var f := m.brain._flank_point()
					if f != Vector3.INF:
						_give(m, "flank", f)
						continue
				_give(m, "hold", Vector3.INF)
		"push":
			# Avanzan de a pocos, de cobertura en cobertura, mientras otros tiran
			var movers := clampi(ceili(n / 3.0), 1, rest.size())
			var moved := 0
			for m in rest:
				if m.brain.role in ["advance", "flank", "assault"] and not m.arrived():
					moved += 1
					continue
				if moved < movers and m.brain.role_age() > 2.0:
					var c := m.brain._find_cover(last_known, true, 4.0, 14.0)
					if c == Vector3.INF and avg_d > 30.0:
						c = m.global_position + (last_known - m.global_position).normalized() * 8.0
						_maybe_smoke(m)
					if c != Vector3.INF:
						_give(m, "advance", c)
						moved += 1
						continue
				_give(m, "hold", Vector3.INF)
		_:
			# Cerca (o en interiores): mantienen los ángulos; de vez en cuando uno se
			# acerca de a uno si hace rato que no te ven
			for i in rest.size():
				var m := rest[i]
				if i == 0 and unseen > 6.0 and m.brain.role_age() > 4.0:
					var c := m.brain._find_cover(last_known, true, 3.0, 9.0)
					if c != Vector3.INF:
						_give(m, "advance", c)
						continue
				_give(m, "hold", Vector3.INF)


func _sup_score(m: HumanNpc) -> float:
	var s := 0.0
	if m.brain.target_visible:
		s += 3.0
	if m.brain.cover != Vector3.INF and m.arrived():
		s += 1.0
	if m.brain.role == "advance" and m.arrived():
		s += 2.0  # llegó: ahora le toca cubrir
	if m.brain.role == "suppress":
		s += 1.5  # que no cambien todo el tiempo
	if m.weapon != null and (m.weapon.bolt_action or m.weapon.slot == 3):
		s -= 1.0
	if String(m.loadout_id).ends_with("marksman"):
		s += 1.0
	return s + _rng.randf() * 0.3


## Le da un rol (con su voz o seña, y la demora de los que no son militares).
func _give(m: HumanNpc, role: String, dest: Vector3) -> void:
	if m.brain.role == role and (dest == Vector3.INF or m.brain.role_dest.distance_to(dest) < 2.0):
		return
	if m.brain.pending_role() == role:
		return  # ya se lo dijeron; está por obedecer
	var delay := 0.0 if m.tactics == "military" else _rng.randf_range(0.8, 1.6)
	m.brain.set_role(role, dest, delay)
	# Lo que se dice
	match role:
		"advance":
			if m.voice_id != "":
				say(m, "cover_me" if _rng.randf() < 0.6 else "moving")
				var cov := _someone_with_role("suppress", m)
				if cov != null and cov.voice_id != "":
					get_tree().create_timer(0.7, false).timeout.connect(func() -> void:
						if is_instance_valid(cov) and not cov.dead:
							say(cov, "covering"))
			elif leader != null and leader != m and leader.voice_id != "":
				say(leader, "order_flank" if _rng.randf() < 0.3 else "moving")
		"flank":
			if m.voice_id != "":
				say(m, "flank")
			elif leader != null and leader.voice_id != "":
				say(leader, "order_flank")
		"suppress":
			if m.voice_id == "" and leader != null and leader != m and leader.voice_id != "":
				say(leader, "order_cover")


## Fuego de cobertura: como mucho dos tirando a ciegas a la vez.
var _supp_at: Dictionary = {}


func may_suppress(m: HumanNpc) -> bool:
	var now := Time.get_ticks_msec()
	var busy := 0
	for k: Variant in _supp_at.keys():
		if not is_instance_valid(k) or (k as HumanNpc).dead:
			_supp_at.erase(k)
			continue
		if k != m and now - int(_supp_at[k]) < 2500:
			busy += 1
	return busy < 2


func note_suppress(m: HumanNpc) -> void:
	_supp_at[m] = Time.get_ticks_msec()


func _someone_with_role(role: String, not_m: HumanNpc) -> HumanNpc:
	for o in alive():
		if o != not_m and o.brain.role == role:
			return o
	return null


## Para cruzar campo abierto: humo entre ellos y vos.
func _maybe_smoke(m: HumanNpc) -> void:
	if _smoke_t > 0.0:
		return
	var thrower: HumanNpc = null
	for o in alive():
		if o.smokes > 0 and o.tactics == "military":
			thrower = o
			break
	if thrower == null:
		return
	_smoke_t = 30.0
	var mid := thrower.global_position.lerp(last_known, 0.45)
	thrower.throw_grenade(mid, 2.0, "grenade_smoke")
	say(thrower, "smoke")


func _lost_voice(unseen: float) -> void:
	if unseen > 7.0 and not _said_lost:
		_said_lost = true
		for m in alive():
			if m.voice_id != "":
				say(m, "lost")
				break
	elif unseen < 1.0:
		_said_lost = false


func _on_killed(n: Node, _by: Node) -> void:
	var h := n as HumanNpc
	if h == null or not members.has(h):
		return
	for m in alive():
		if m.global_position.distance_to(h.global_position) < 40.0:
			m.add_stress(0.25 if m.tactics != "military" else 0.15)
	if commanded:
		for m in alive():
			if m.voice_id != "" and m.global_position.distance_to(h.global_position) < 40.0:
				say(m, "man_down")
				break


# --- Voz y señas ---------------------------------------------------------------------

## `m` dice algo a la escuadra. Si el compañero más cercano lo ve y no hay tiroteo,
## se lo hace con una seña; si está cerca, se lo dice hablando; si no, lo grita.
## quiet: en sigilo (sin tiroteo) nunca grita: seña o habla bajo, o se lo guarda.
func say(m: HumanNpc, key: String, quiet := false) -> String:
	if m == null or m.dead or m.voice_id == "":
		return ""
	if _voice_t > 0.0 and key not in ["grenade_incoming", "man_down", "reloading"]:
		return ""
	if _clock - float(_key_t.get(key, -99.0)) < float(KEY_GAP.get(key, 2.0)):
		return ""
	var near: HumanNpc = null
	var nd := INF
	for o in alive():
		if o == m:
			continue
		var d := o.global_position.distance_to(m.global_position)
		if d < nd:
			nd = d
			near = o
	var hot := is_hot()
	var sees := near != null and nd < 25.0 and _los(m, near)
	var how := ""
	if SIGNALS.has(key) and sees and not hot:
		how = "signal"
	elif nd < 10.0 and not hot:
		how = "talk"
	elif quiet:
		how = "talk" if nd < 15.0 else ""
	else:
		how = "shout"
	if how == "":
		return ""
	_voice_t = 0.8
	_key_t[key] = _clock
	if how == "signal":
		m.body.play_signal(String(SIGNALS[key]))
	else:
		m.speak(key, how == "shout")
	return how


func _los(a: HumanNpc, b: HumanNpc) -> bool:
	var rq := PhysicsRayQueryParameters3D.create(a.body.eye_position(), b.body.eye_position(), 1)
	return a.get_world_3d().direct_space_state.intersect_ray(rq).is_empty()


# --- Patrulla en formación -----------------------------------------------------------------

## Patrullando: el líder recorre su ruta y los demás lo siguen abiertos en cuña
## (separados, no amontonados); el último mira para atrás.
func _update_formation() -> void:
	if not commanded or leader == null or leader.dead:
		return
	if leader.brain.state != NpcBrain.State.PATROL:
		for m in members:
			if is_instance_valid(m) and not m.dead and m.brain.follow_pos != Vector3.INF:
				# Se queda donde está (no vuelve corriendo a donde apareció)
				m.brain.follow_pos = Vector3.INF
				m.brain.home = m.global_position
				m.brain.home_yaw = m._yaw
		return
	var basis := Basis(Vector3.UP, leader._yaw)
	var slot := 0
	var live := alive()
	for m in live:
		if m == leader or m.tactics != "military":
			continue
		if m.brain.state == NpcBrain.State.IDLE:
			m.brain._set_state(NpcBrain.State.PATROL)
		elif m.brain.state != NpcBrain.State.PATROL:
			continue
		slot += 1
		var side := -1.0 if slot % 2 == 1 else 1.0
		var row := ceili(slot / 2.0)
		m.brain.follow_pos = leader.global_position + basis * Vector3(side * 4.0 * row, 0, 5.0 * row)
		m.brain.follow_yaw = leader._yaw + (PI if slot == live.size() - 1 and slot >= 3 else side * 0.5)
