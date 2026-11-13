class_name HumanNpc
extends CharacterBody3D
## Enemigo humano con IA. El cuerpo (NpcBody) pone el modelo, la pose y los cuerpos
## de impacto; el cerebro (NpcBrain) decide; acá están la vida, el blindaje, el arma
## (cargador, recarga, ráfagas, puntería) y el movimiento por la malla de navegación.
##
## Preparado para cooperativo: los objetivos son todos los nodos del grupo "player"
## (el cerebro elige), nada lee el Input y todo lo que pasa sale por señales.

signal died(npc: HumanNpc)

## Capa del cuerpo de movimiento (las balas no lo tocan: pegan en los cuerpos de impacto).
const BODY_LAYER := 5
## Capa del follaje: tapa la vista pero no frena balas ni gente.
const FOLIAGE_LAYER := 9
const WALK_SPEED := 1.5
const RUN_SPEED := 4.0
const CROUCH_SPEED := 1.0
const TURN_SPEED := 5.0
var _yaw_rate: float = 0.0
const SHOT_HEAR := 160.0
const SHOT_HEAR_SUPPRESSED := 35.0
const DAMAGE_MODEL := preload("res://data/combat/damage_model.tres")

@export var loadout_id: String = "bandit_rifle"
## Grupo con el que se avisa (los del mismo escuadrón se pasan dónde estás).
@export var squad: String = ""
## Recorrido de patrulla (vacío = se queda de guardia en su lugar).
@export var patrol: PackedVector3Array = PackedVector3Array()
## Dificultad propia (−1 = la del juego).
@export var difficulty_override: int = -1
## Arma fija (vacío = una al azar de su equipo).
@export var weapon_id: String = ""
## Semilla del equipo y del botín (0 = al azar).
@export var seed_value: int = 0
## Distancia máxima a su puesto (0 = sin límite): no persigue más allá.
@export var leash: float = 0.0
## Multiplica lo que oye (en lugares cerrados o para que no se enteren de todo).
@export var hearing_mult: float = 1.0
## Sin IA: queda quieto con las órdenes que se le den a mano (capturas, pruebas).
@export var ai_enabled: bool = true

var body: NpcBody
var brain: NpcBrain
var agent: NavigationAgent3D
var loadout: Dictionary
var hp: float = 100.0
var max_hp: float = 100.0
var dead: bool = false
var weapon: WeaponData
var sight_id: String = "__fabrica"
var muzzle_id: String = ""
var mag: int = 0
## Cargadores de repuesto (balas en cada uno) o munición suelta (escopetas).
var spare_mags: Array[int] = []
var loose_ammo: int = 0
var grenades: int = 0
var has_medkit: bool = false
var helmet: ItemStack
var vest: ItemStack
## Lo que se le saca al cuerpo.
var inventory: Inventory
var title_key: String = "loot.bandit"
var rng := RandomNumberGenerator.new()

## --- Órdenes del cerebro ---
var move_target: Vector3 = Vector3.INF
var move_speed: float = WALK_SPEED
var crouching: bool = false
## Punto al que apunta (INF = mira hacia donde camina).
var aim_point: Vector3 = Vector3.INF
## 0 = arma baja; 1 = al hombro.
var raised: bool = false
## Tiros que le quedan a la ráfaga pedida y error de puntería (grados) por tiro.
var burst_left: int = 0
var aim_error_deg: float = 2.0
## Mirar hacia este ángulo cuando no apunta a nada (guardia).
var look_yaw: float = NAN

var reloading: bool = false
var _reload_left: float = 0.0
var _cooldown: float = 0.0
var _burst_shot: int = 0
var _yaw: float = 0.0
var _torso_yaw: float = 0.0
var _pitch: float = 0.0
var _stuck_t: float = 0.0
var _last_pos: Vector3
var _audio: AudioStreamPlayer3D
var _exclude: Array[RID] = []
var _nav_target_set: Vector3 = Vector3.INF
var _looting: bool = false
var _heal_left: float = 0.0
var _step_dist: float = 0.0
var _steps: AudioStreamPlayer3D
## Táctica ("military" = se coordina en escuadra, habla y se hace señas).
var tactics: String = ""
## Voz (VoiceBank) de los que hablan; "" = mudo.
var voice_id: String = ""
var squad_obj: Squad = null
## Estrés (0..1): sube con tiros cerca, heridas y compañeros caídos; empeora la
## puntería y la recarga (más lenta, a veces se le traba la mano).
var stress: float = 0.0
## Estado del arma (0..1): las gastadas se traban en pleno combate.
var weapon_condition: float = 0.8
var smokes: int = 0
var _jam: bool = false
var _voice: AudioStreamPlayer3D


func _ready() -> void:
	add_to_group("ai_npc")
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	collision_layer = 1 << (BODY_LAYER - 1)
	collision_mask = 1 | (1 << (BODY_LAYER - 1)) | (1 << 9)
	floor_max_angle = deg_to_rad(46.0)
	floor_snap_length = 0.45
	var cs := CollisionShape3D.new()
	cs.name = "Collision"
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.8
	cs.shape = cap
	cs.position = Vector3(0, 0.9, 0)
	add_child(cs)
	loadout = NpcLoadouts.get_loadout(loadout_id)
	tactics = String(loadout.get("tactics", ""))
	if tactics == "military":
		title_key = "loot.military"
	max_hp = float(loadout.get("hp", 100.0))
	hp = max_hp
	body = NpcBody.new()
	body.name = "Body"
	body.scene_path = NpcLoadouts.model_path(String(loadout.get("model", "fsb")))
	add_child(body)
	_equip()
	_exclude = body.hitbox_rids()
	_exclude.append(get_rid())
	agent = NavigationAgent3D.new()
	agent.name = "Agent"
	agent.path_desired_distance = 0.6
	agent.target_desired_distance = 0.7
	agent.radius = 0.4
	agent.height = 1.8
	agent.path_max_distance = 3.0
	add_child(agent)
	_audio = AudioStreamPlayer3D.new()
	_audio.bus = "SFX_World"
	_audio.max_distance = 450.0
	_audio.unit_size = 22.0
	_audio.attenuation_filter_cutoff_hz = 3500.0
	_audio.attenuation_filter_db = -18.0
	_audio.max_polyphony = 4
	add_child(_audio)
	_steps = AudioStreamPlayer3D.new()
	_steps.bus = "SFX_World"
	_steps.unit_size = 3.0
	_steps.max_distance = 40.0
	_steps.max_polyphony = 2
	add_child(_steps)
	WeaponController.ensure_suppressed_bus()
	_yaw = rotation.y
	rotation = Vector3.ZERO
	look_yaw = _yaw
	_last_pos = global_position
	brain = NpcBrain.new(self)
	EventBus.noise_emitted.connect(_on_noise)
	if bool(loadout.get("voice", false)):
		var vs := VoiceBank.voices()
		if not vs.is_empty():
			voice_id = String(vs[absi(hash(String(name))) % vs.size()])
	_voice = AudioStreamPlayer3D.new()
	_voice.bus = "SFX_World"
	_voice.max_polyphony = 1
	add_child(_voice)
	_join_squad.call_deferred()


func _join_squad() -> void:
	squad_obj = Squad.get_for(self)
	if squad_obj != null:
		squad_obj.add(self)


## Dice una frase: gritada (se oye de lejos) o hablada (solo de cerca).
func speak(key: String, shout: bool) -> void:
	if voice_id == "" or dead:
		return
	var st := VoiceBank.stream(voice_id, key, shout, rng)
	if st == null:
		return
	_voice.stream = st
	_voice.unit_size = 9.0 if shout else 2.2
	_voice.max_distance = 110.0 if shout else 22.0
	_voice.volume_db = 2.0 if shout else -6.0
	_voice.pitch_scale = rng.randf_range(0.96, 1.05) * (1.0 + stress * 0.06)
	_voice.position = Vector3(0, 1.6, 0)
	_voice.play()


func add_stress(v: float) -> void:
	var k := 0.6 if tactics == "military" else 1.0
	stress = clampf(stress + v * k, 0.0, 1.0)


## Dificultad con la que juega.
func profile() -> Dictionary:
	return Difficulty.profile(difficulty_override if difficulty_override >= 0 else GameState.difficulty)


func _equip() -> void:
	var weapons: Array = loadout.get("weapons", ["akm"])
	var wid := weapon_id if weapon_id != "" else String(weapons[rng.randi() % weapons.size()])
	weapon = load("res://data/weapons/%s.tres" % wid) as WeaponData
	if weapon == null:
		weapon = load("res://data/weapons/akm.tres") as WeaponData
	var wc: Array = loadout.get("weapon_condition", [0.3, 0.75])
	weapon_condition = rng.randf_range(float(wc[0]), float(wc[1]))
	# Mira (si su equipo trae y el arma la acepta)
	var sights: Array = loadout.get("sights", [])
	if not sights.is_empty():
		var sid := String(sights[rng.randi() % sights.size()])
		if sid != "" and ItemDB.has(sid) and ItemDB.fits_weapon(ItemDB.get_item(sid), weapon):
			sight_id = sid
	var sm: Array = loadout.get("smokes", [0, 0])
	smokes = rng.randi_range(int(sm[0]), int(sm[1]))
	# Alguno lleva silenciador (si el arma tiene rosca)
	var thread := ItemDB.thread_of(weapon)
	if thread != "" and rng.randf() < float(loadout.get("suppressor", 0.15)):
		muzzle_id = {"pistol": "supp_pistol", "545": "supp_545", "762": "supp_762"}.get(thread, "")
	body.set_weapon(weapon, sight_id, muzzle_id)
	mag = _capacity()
	var mm: Array = loadout.get("mags", [2, 3])
	if weapon.reload_type == "magazine" and ItemDB.standard_mag(weapon.id) != "":
		for i in rng.randi_range(int(mm[0]), int(mm[1])):
			spare_mags.append(_capacity())
	else:
		var am: Array = loadout.get("ammo", [weapon.mag_size, weapon.mag_size * 2])
		loose_ammo = rng.randi_range(int(am[0]), int(am[1]))
	var gm: Array = loadout.get("grenades", [0, 0])
	grenades = rng.randi_range(int(gm[0]), int(gm[1]))
	has_medkit = bool(loadout.get("medkit", false)) or rng.randf() < 0.3
	var h := String(loadout.get("helmet", ""))
	var v := String(loadout.get("vest", ""))
	if h != "" and ItemDB.has(h):
		helmet = ItemStack.make(h, 1, {"condition": rng.randf_range(0.55, 1.0)})
	if v != "" and ItemDB.has(v):
		vest = ItemStack.make(v, 1, {"condition": rng.randf_range(0.55, 1.0)})
	body.is_pistol = weapon.slot == 3
	# Botín que lleva encima (el arma, el blindaje y los cargadores se suman al morir)
	inventory = Inventory.new(10, 8)
	inventory.title_key = title_key
	for e: Array in loadout.get("loot", []):
		if rng.randf() < float(e[3]):
			inventory.add_item(String(e[0]), rng.randi_range(int(e[1]), int(e[2])))


func _capacity() -> int:
	var mid := ItemDB.standard_mag(weapon.id)
	if mid != "" and ItemDB.has(mid):
		return ItemDB.get_item(mid).capacity
	return weapon.mag_size


func ammo_left() -> int:
	var n := mag + loose_ammo
	for m in spare_mags:
		n += m
	return n


# --- Ciclo ------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if dead:
		return
	var p := profile()
	stress = maxf(0.0, stress - delta * (0.09 if tactics == "military" else 0.06))
	if ai_enabled:
		brain.update(delta)
	_update_heal(delta)
	_update_weapon(delta)
	_update_move(delta, p)
	_update_body(delta, p)


func _update_move(delta: float, _p: Dictionary) -> void:
	var hv := Vector3.ZERO
	var nav_ready := NavigationServer3D.map_get_iteration_id(get_world_3d().navigation_map) > 0
	if move_target != Vector3.INF and nav_ready and _heal_left <= 0.0:
		if _nav_target_set == Vector3.INF or _nav_target_set.distance_to(move_target) > 0.4:
			agent.target_position = move_target
			_nav_target_set = move_target
		if not agent.is_navigation_finished():
			var next := agent.get_next_path_position()
			var d := next - global_position
			d.y = 0.0
			if d.length() > 0.05:
				var spd := CROUCH_SPEED if crouching else move_speed
				hv = d.normalized() * spd
	var vy := velocity.y
	if not is_on_floor():
		vy -= 9.8 * delta
	else:
		vy = minf(vy, 0.0)
	velocity = velocity.lerp(Vector3(hv.x, vy, hv.z), 1.0 - exp(-7.0 * delta))
	velocity.y = vy
	move_and_slide()
	# Pasos (se oyen de cerca: corriendo bastante más)
	var hs := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and hs > 0.5:
		_step_dist += hs * delta
		var stride := 2.2 if hs > 3.0 else (1.25 if crouching else 1.7)
		if _step_dist >= stride:
			_step_dist = 0.0
			_play_step(hs)
	# Trabado: avisa al cerebro
	if hv.length() > 0.3 and global_position.distance_to(_last_pos) < 0.2 * delta * hv.length():
		_stuck_t += delta
	else:
		_stuck_t = maxf(0.0, _stuck_t - delta)
	_last_pos = global_position


func _play_step(speed: float) -> void:
	var surf := "dirt"
	for i in get_slide_collision_count():
		var c := get_slide_collision(i).get_collider() as Node
		if c != null and c.has_meta("surface") and get_slide_collision(i).get_normal().y > 0.6:
			surf = Foley.step_surface(String(c.get_meta("surface")))
			break
	var st := Foley.step(surf)
	if st == null:
		return
	_steps.stream = st
	_steps.volume_db = -6.0 if speed > 3.0 else (-16.0 if crouching else -11.0)
	_steps.play()


func arrived() -> bool:
	if move_target == Vector3.INF:
		return true
	var d := global_position - move_target
	d.y = 0.0
	return d.length() < 0.9 or (agent.is_navigation_finished() and d.length() < 2.0)


func is_stuck() -> bool:
	return _stuck_t > 1.2


func go_to(p: Vector3, speed := WALK_SPEED) -> void:
	if leash > 0.0 and brain != null:
		var off := p - brain.home
		off.y = 0.0
		if off.length() > leash:
			p = brain.home + off.normalized() * leash
	move_target = p
	move_speed = speed
	_stuck_t = 0.0


func stop() -> void:
	move_target = Vector3.INF


func is_moving() -> bool:
	return Vector2(velocity.x, velocity.z).length() > 0.3


## Giro del cuerpo hacia el blanco (o hacia donde camina) y pose.
func _update_body(delta: float, p: Dictionary) -> void:
	var hv := Vector3(velocity.x, 0, velocity.z)
	var want_yaw := _yaw
	var aim_dir := Vector3.ZERO
	if aim_point != Vector3.INF:
		aim_dir = aim_point - body.eye_position()
		want_yaw = atan2(-aim_dir.x, -aim_dir.z)
	elif hv.length() > 0.4:
		want_yaw = atan2(-hv.x, -hv.z)
	elif not is_nan(look_yaw):
		want_yaw = look_yaw
	# Las piernas giran más lento que el torso; el torso cubre la diferencia
	var turn := TURN_SPEED * (1.4 if float(p.get("reaction", 0.6)) < 0.4 else 1.0)
	var diff := wrapf(want_yaw - _yaw, -PI, PI)
	var leg_diff := diff
	if hv.length() > 0.4 and aim_point != Vector3.INF:
		# Caminando y apuntando: las piernas siguen a donde camina si no es muy de costado
		var move_yaw := atan2(-hv.x, -hv.z)
		var md := wrapf(move_yaw - _yaw, -PI, PI)
		if absf(wrapf(want_yaw - move_yaw, -PI, PI)) < 1.0:
			leg_diff = md
	# Giro con inercia: acelera y frena (no gira a velocidad fija de golpe)
	var want_rate := clampf(leg_diff * 7.0, -turn, turn)
	_yaw_rate = lerpf(_yaw_rate, want_rate, 1.0 - exp(-12.0 * delta))
	_yaw = wrapf(_yaw + _yaw_rate * delta, -PI, PI)
	rotation = Vector3(0, _yaw, 0)
	var torso_target := clampf(wrapf(want_yaw - _yaw, -PI, PI), -0.9, 0.9)
	var td := torso_target - _torso_yaw
	_torso_yaw += clampf(td * (1.0 - exp(-14.0 * delta)), -turn * 1.6 * delta, turn * 1.6 * delta)
	if aim_dir != Vector3.ZERO:
		var pt := atan2(aim_dir.y, Vector2(aim_dir.x, aim_dir.z).length())
		_pitch = move_toward(_pitch, clampf(pt, -1.1, 1.1), 3.0 * delta)
	else:
		_pitch = move_toward(_pitch, 0.0, 2.0 * delta)
	body.local_velocity = global_basis.inverse() * hv
	body.crouch = 1.0 if crouching else 0.0
	body.aim_yaw = _torso_yaw
	body.aim_pitch = _pitch
	body.raise = 1.0 if raised else 0.0
	body.reloading = reloading or _heal_left > 0.0


## Hacia dónde apunta el arma ahora (mundo).
func aim_forward() -> Vector3:
	var yaw := _yaw + _torso_yaw
	return Vector3(-sin(yaw) * cos(_pitch), sin(_pitch), -cos(yaw) * cos(_pitch)).normalized()


# --- Arma -------------------------------------------------------------------------

func _update_weapon(delta: float) -> void:
	_cooldown -= delta
	if reloading:
		_reload_left -= delta
		if _reload_left <= 0.0:
			_finish_reload()
		return
	if mag <= 0:
		if ammo_left() > 0:
			start_reload()
		else:
			burst_left = 0
		return
	if burst_left <= 0 or _cooldown > 0.0 or aim_point == Vector3.INF or not raised:
		if burst_left <= 0:
			_burst_shot = 0
		return
	# Solo dispara si el arma ya apunta más o menos hacia ahí
	var want := (aim_point - body.muzzle_position()).normalized()
	if aim_forward().angle_to(want) > deg_to_rad(9.0):
		return
	# Un compañero se cruzó en la línea de tiro: espera (sin fuego amigo)
	if _ally_in_line():
		return
	_fire(want)


func _ally_in_line() -> bool:
	var from := body.muzzle_position()
	var rq := PhysicsRayQueryParameters3D.create(from, from + (aim_point - from).limit_length(60.0),
		1 << (NpcBody.HITBOX_LAYER - 1))
	rq.exclude = _exclude
	var hit := get_world_3d().direct_space_state.intersect_ray(rq)
	if hit.is_empty():
		return false
	var c := hit["collider"] as Node
	if c == null or not c.has_meta("zone_owner"):
		return false
	var o: Variant = c.get_meta("zone_owner")
	return o is HumanNpc and o != self and not (o as HumanNpc).dead


func _fire(want: Vector3) -> void:
	var w := weapon
	mag -= 1
	burst_left -= 1
	_burst_shot += 1
	var auto := w.has_mode("auto")
	_cooldown = w.seconds_per_shot() if auto and burst_left > 0 else maxf(w.seconds_per_shot(), rng.randf_range(0.28, 0.55))
	if w.bolt_action:
		_cooldown = maxf(_cooldown, w.cycle_time + 0.3)
	# El error crece con la ráfaga (el retroceso) y con el arma en movimiento
	var err := aim_error_deg * (1.0 + 0.15 * (_burst_shot - 1)) + w.spread_ads
	if is_moving():
		err *= 1.5
	var origin := body.muzzle_position()
	var combat := CombatWorld.get_for(self)
	for i in maxi(w.pellets, 1):
		var cone := err + (w.pellet_spread if w.pellets > 1 else 0.0)
		var dir := _cone(want, cone)
		var tracer := i == 0 and w.tracer_every > 0 and rng.randi() % 5 == 0
		combat.fire_projectile(origin, dir, w, self, _exclude, tracer)
	var sup := muzzle_id != ""
	if not sup:
		combat.muzzle_flash_light(origin)
	_audio.stream = SynthSfx.weapon_shot(w)
	_audio.bus = WeaponController.SUPPRESSED_BUS if sup else "SFX_World"
	_audio.volume_db = w.sfx_volume_db + (-6.0 if sup else 3.0)
	_audio.unit_size = 6.0 if sup else 22.0
	_audio.global_position = origin
	_audio.play()
	EventBus.noise_emitted.emit(origin, SHOT_HEAR_SUPPRESSED if sup else SHOT_HEAR, self)
	if squad_obj != null:
		squad_obj.note_shot()
	if burst_left <= 0:
		_burst_shot = 0
	# Arma gastada: se traba (más con los nervios)
	if weapon_condition < 0.6 and mag > 0:
		var risk := (0.6 - weapon_condition) * 0.05 * (1.0 + stress * 0.5)
		if rng.randf() < risk:
			_start_jam()


## Se le trabó el arma: tarda en destrabarla (y pierde el cartucho trabado).
func _start_jam() -> void:
	_jam = true
	reloading = true
	burst_left = 0
	_reload_left = rng.randf_range(1.6, 3.2) * (1.0 + stress * 0.6)
	_play_at(SynthSfx.click("dry", 0.9, 0.04), -6.0)
	if squad_obj != null:
		squad_obj.say(self, "jam")


func _cone(fwd: Vector3, deg: float) -> Vector3:
	var a := rng.randf() * TAU
	# Uniforme en el disco del error
	var r := deg_to_rad(deg) * sqrt(rng.randf())
	var side := fwd.cross(Vector3.UP).normalized()
	if side.length() < 0.1:
		side = Vector3.RIGHT
	var upv := side.cross(fwd).normalized()
	return (fwd + (side * cos(a) + upv * sin(a)) * tan(r)).normalized()


func start_reload() -> void:
	if reloading or ammo_left() - mag <= 0:
		return
	reloading = true
	burst_left = 0
	_reload_left = weapon.reload_time_empty * 1.1 if weapon.reload_type == "magazine" else weapon.round_time * 4.0 + 0.6
	# Con estrés recarga más lento y a veces se le traba la mano (el cargador no entra)
	_reload_left *= 1.0 + stress * 0.5
	var fumble := stress * (0.15 if tactics == "military" else 0.3)
	if rng.randf() < fumble:
		_reload_left += rng.randf_range(0.8, 2.0)
		get_tree().create_timer(_reload_left * 0.5, false).timeout.connect(func() -> void:
			if is_inside_tree() and not dead:
				_play_at(SynthSfx.click("mag_in", 1.3, 0.03), -8.0))
	_play_at(SynthSfx.click("mag_out", 0.8, 0.06), -4.0)


func _finish_reload() -> void:
	reloading = false
	if _jam:
		_jam = false
		mag = maxi(0, mag - 1)
		_play_at(SynthSfx.click("charge", 1.0, 0.05), -4.0)
		return
	if weapon.reload_type == "magazine" and not spare_mags.is_empty():
		# Cambia por el cargador más lleno; el vacío queda (va al botín)
		spare_mags.sort()
		var best: int = spare_mags.pop_back()
		if mag > 0:
			spare_mags.append(mag)
		mag = best
	elif loose_ammo > 0:
		var cap := _capacity()
		var n := mini(cap - mag, loose_ammo if weapon.reload_type != "break" else cap)
		n = mini(n, loose_ammo)
		mag += n
		loose_ammo -= n
	_play_at(SynthSfx.click("mag_in", 1.0, 0.05), -4.0)


func _play_at(s: AudioStream, vol: float) -> void:
	var cw := CombatWorld.get_for(self)
	cw.play_sound_at(s, global_position + Vector3(0, 1.2, 0), vol)


## Tira una granada hacia `target` (tiro parabólico con algo de error).
func throw_grenade(target: Vector3, error_m: float, id := "grenade_rg5") -> void:
	if id == "grenade_smoke":
		if smokes <= 0:
			return
		smokes -= 1
	else:
		if grenades <= 0:
			return
		grenades -= 1
	var from := body.chest_position() + Vector3(0, 0.45, 0) - global_basis.z * 0.3
	var aim := target + Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)) * error_m
	var g := Grenade.make(self, id)
	get_parent().add_child(g)
	g.global_position = from
	g.linear_velocity = Grenade.launch_velocity(from, aim, deg_to_rad(38.0))
	g.add_collision_exception_with(self)


# --- Curarse -------------------------------------------------------------------------

func start_heal() -> bool:
	if not has_medkit or _heal_left > 0.0:
		return false
	has_medkit = false
	_heal_left = 3.2
	burst_left = 0
	return true


func is_healing() -> bool:
	return _heal_left > 0.0


func _update_heal(delta: float) -> void:
	if _heal_left > 0.0:
		_heal_left -= delta
		if _heal_left <= 0.0:
			hp = minf(max_hp, hp + 45.0)


# --- Daño -----------------------------------------------------------------------------

func refine_zone(zone: String, hit_pos: Vector3, dir: Vector3) -> String:
	return body.refine_zone(zone, hit_pos, dir)


## Recibe un tiro (o esquirla). Devuelve true si lo mató.
func apply_hit(info: HitInfo) -> bool:
	if dead:
		# Ya muerto: el tiro mueve el cuerpo
		body.push(info.position, info.direction.normalized() * clampf(info.damage * 0.25, 3.0, 15.0))
		return false
	var dmg := info.damage
	var piece := helmet if info.zone.begins_with("head") else (vest if info.zone == "torso" else null)
	if piece != null:
		var cond := float(piece.state.get("condition", 1.0))
		var res := Armor.resolve(dmg, info.penetration, info.zone, piece.item.armor_class, cond, rng)
		if res.covered:
			piece.state["condition"] = maxf(0.0, cond - res.wear)
			dmg = res.damage
			if not res.penetrated and info.zone == "head_core":
				dmg = maxf(minf(dmg, 30.0), 15.0)
	hp -= dmg
	add_stress(0.35)
	brain.on_damaged(info)
	if hp <= 0.0:
		_die(info)
		return true
	return false


func on_near_miss(origin: Vector3, source: Node) -> void:
	if not dead:
		add_stress(0.18)
		brain.on_near_miss(origin, source)


func _on_noise(pos: Vector3, radius: float, source: Node) -> void:
	if not dead and source != self:
		brain.on_noise(pos, radius, source)


func _die(info: HitInfo) -> void:
	dead = true
	hp = 0.0
	burst_left = 0
	remove_from_group("ai_npc")
	add_to_group("npc_corpse")
	($Collision as CollisionShape3D).set_deferred("disabled", true)
	var vel := velocity
	velocity = Vector3.ZERO
	body.die(info.direction if info != null else -global_basis.z, false,
		info.position if info != null else Vector3.INF, vel)
	# Golpe del cuerpo y del arma contra el piso
	get_tree().create_timer(0.75, false).timeout.connect(func() -> void:
		if is_inside_tree():
			_play_at(SynthSfx.impact("flesh"), -2.0)
			_play_at(SynthSfx.impact("metal"), -10.0))
	_fill_corpse()
	died.emit(self)
	EventBus.npc_killed.emit(self, info.source if info != null else null)


## Al morir, todo lo que tenía pasa al botín: el arma (con lo que le quedaba en el
## cargador), los cargadores de repuesto, la munición, el blindaje y las granadas.
func _fill_corpse() -> void:
	# Lo que se saquea está gastado (los militares usan su equipo hasta romperlo)
	var lc: Array = loadout.get("loot_condition", [weapon_condition - 0.1, weapon_condition + 0.05])
	var wst := ItemStack.make(ItemDB.weapon_item_id(weapon.id), 1,
		{"mag": mag, "condition": clampf(rng.randf_range(float(lc[0]), float(lc[1])), 0.05, 1.0)})
	if sight_id != "__fabrica" and sight_id != "":
		wst.state["sight"] = sight_id
	if muzzle_id != "":
		wst.state["muzzle"] = muzzle_id
	inventory.add(wst)
	var mid := ItemDB.standard_mag(weapon.id)
	for r in spare_mags:
		if mid != "":
			inventory.add(ItemStack.make(mid, 1, {"rounds": r}))
	if loose_ammo > 0:
		inventory.add_item(ItemDB.ammo_id(weapon.caliber), loose_ammo)
	var ac: Array = loadout.get("armor_loot_condition", [])
	for st: ItemStack in [helmet, vest]:
		if st != null:
			if not ac.is_empty():
				st.state["condition"] = minf(float(st.state.get("condition", 1.0)), rng.randf_range(float(ac[0]), float(ac[1])))
			inventory.add(st)
	if smokes > 0:
		inventory.add_item("grenade_smoke", smokes)
	if grenades > 0:
		inventory.add_item("grenade_rg5", grenades)
	if has_medkit:
		inventory.add_item("medkit", 1)


func get_interact_text() -> String:
	return tr("interact.search") % ["%s", tr(title_key)] if dead else ""


func interact(_player: Node) -> void:
	if dead:
		Foley.play(get_tree(), "pickup_item", -6.0)
		EventBus.loot_requested.emit(self)


func on_loot_opened() -> void:
	_looting = true


func on_loot_closed() -> void:
	_looting = false


func get_debug_info() -> Dictionary:
	return {"estado": NpcBrain.State.keys()[brain.state], "alerta": "%.2f" % brain.awareness, "vida": "%.0f" % hp,
		"cargador": mag, "ve": brain.target_visible}
