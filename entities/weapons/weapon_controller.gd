class_name WeaponController
extends Node
## Armas del jugador: lógica (tick de física) y vista en primera persona (cada frame).
##
## Vista ("viewmodel"): las armas se dibujan en un SubViewport con mundo propio,
## cámara propia y FOV propio, superpuesto a la imagen del juego. Así el arma
## nunca atraviesa paredes y su FOV no depende del FOV del jugador.
## Apuntado real: al apuntar, el arma se coloca de forma que su marcador "Sight"
## quede exactamente en el eje de la cámara (centro de la pantalla).

enum State { READY, RELOADING, HOLSTER, DRAW, CYCLING }

const WEAPON_FILES: Dictionary = {
	1: "res://data/weapons/rifle.tres",
	2: "res://data/weapons/shotgun.tres",
	3: "res://data/weapons/pistol.tres",
}
## Posición de cadera por familia (espacio de la cámara del arma).
const HIP_POSE: Dictionary = {
	"pistol": Vector3(0.125, -0.13, -0.34),
	"smg": Vector3(0.13, -0.14, -0.26),
	"rifle_ar": Vector3(0.135, -0.15, -0.27),
	"rifle_ak": Vector3(0.135, -0.15, -0.27),
	"rifle_battle": Vector3(0.135, -0.15, -0.27),
	"bolt": Vector3(0.135, -0.15, -0.25),
	"shotgun_sxs": Vector3(0.13, -0.145, -0.24),
	"shotgun_ou": Vector3(0.13, -0.15, -0.24),
}
## Resolución de la imagen del visor (cuadrada).
const SCOPE_RES := 512
const VM_FOV_HIP := 62.0
const VM_FOV_ADS := 52.0
## Tiempo después de dejar de correr hasta poder disparar.
const SPRINT_RECOVERY := 0.18
const INTERACT_RANGE := 2.6
## Mínimo entre los dos caños de la escopeta.
const DOUBLE_BARREL_GAP := 0.15
## Apertura de los caños de las escopetas al recargar (grados).
const BREAK_OPEN_DEG := 62.0
## Cada muesca de la rueda multiplica el aumento por esto (visor variable).
const ZOOM_STEP := 1.26


## Estado de un arma del jugador.
class WeaponSlot:
	var data: WeaponData
	var mag: int = 0
	var reserve: int = 0
	var mode_index: int = 0
	var model: Node3D
	var shots: int = 0
	## Aumento actual del visor (los variables lo cambian con la rueda).
	var zoom: float = 1.0

	func mode() -> String:
		return data.fire_modes[mode_index] if data.fire_modes.size() > 0 else "semi"


var player: Player
var slots: Dictionary = {}
var current_slot: int = 1
var state: State = State.DRAW
var state_time: float = 0.0
var state_duration: float = 0.3
## 0 = cadera, 1 = apuntando.
var ads_amount: float = 0.0
var aiming: bool = false

var _pending_slot: int = -1
var _reload_empty: bool = false
var _reload_fx_done: bool = false
var _cooldown: float = 0.0
var _sprint_block: float = 0.0
var _sprint_pose: float = 0.0
var _hint_target: Node = null
var _rng := RandomNumberGenerator.new()

# Vista
var _vm_layer: CanvasLayer
var _vm_viewport: SubViewport
var _vm_camera: Camera3D
var _vm_light: DirectionalLight3D
var _rig: Node3D
var _flash: MeshInstance3D
var _flash_time: float = 0.0
var _kick_pos: Vector3 = Vector3.ZERO
var _kick_rot: Vector3 = Vector3.ZERO
var _sway: Vector3 = Vector3.ZERO
var _bob_t: float = 0.0
var _time: float = 0.0
var _slide_kick: float = 0.0
var _audio_shot: AudioStreamPlayer
var _audio_mech: AudioStreamPlayer
var _part_base: Dictionary = {}
var _cycle_fx_done: bool = false
# Visor: cámara en el mundo del juego que renderiza a una textura
var _scope_vp: SubViewport
var _scope_cam: Camera3D


func setup(p: Player) -> void:
	player = p
	_rng.randomize()
	_build_viewmodel()
	_build_scope_view()
	for slot: int in WEAPON_FILES:
		slots[slot] = _make_slot(load(WEAPON_FILES[slot]) as WeaponData)
	_equip(1)


func _make_slot(data: WeaponData) -> WeaponSlot:
	var ws := WeaponSlot.new()
	ws.data = data
	ws.mag = data.mag_size
	ws.reserve = data.start_reserve
	ws.zoom = data.scope_mag
	ws.model = WeaponModelBuilder.build(data)
	ws.model.visible = false
	_rig.add_child(ws.model)
	_remember_parts(ws.model)
	if ws.model.has_node("ScopeLens"):
		var lens := ws.model.get_node("ScopeLens") as MeshInstance3D
		(lens.material_override as ShaderMaterial).set_shader_parameter("scope_tex", _scope_vp.get_texture())
	return ws


## Pone un arma en un slot (reemplaza la que había) y la saca.
func equip_weapon(data: WeaponData, slot: int) -> void:
	if slots.has(slot):
		var old := slots[slot] as WeaponSlot
		for n: Node in _part_base.keys():
			if not is_instance_valid(n) or old.model.is_ancestor_of(n):
				_part_base.erase(n)
		old.model.queue_free()
	slots[slot] = _make_slot(data)
	if slot == current_slot:
		_equip(slot)
	else:
		_start_holster(slot)


## Toma un arma (armería, saqueo): pistolas al slot 3; las largas al slot
## largo que tengas en la mano, o al 1.
func take_weapon(data: WeaponData) -> int:
	var slot := 3 if data.slot == 3 else (current_slot if current_slot in [1, 2] else 1)
	equip_weapon(data, slot)
	return slot


# --- Consultas (las usan el jugador, el HUD y los tests) -------------------------

func current() -> WeaponSlot:
	return slots.get(current_slot)


func current_data() -> WeaponData:
	var c := current()
	return c.data if c != null else null


func blocks_sprint() -> bool:
	return aiming or ads_amount > 0.3


func move_speed_mult() -> float:
	return lerpf(1.0, 0.6, ads_amount)


func fov_mult() -> float:
	var d := current_data()
	if d == null:
		return 1.0
	return lerpf(1.0, d.ads_fov_mult, _smooth(ads_amount))


## Multiplicador de sensibilidad del mouse (más fino mirando por un visor).
func look_mult() -> float:
	var c := current()
	if c == null or c.data.scope_mag <= 1.0:
		return 1.0
	return lerpf(1.0, 1.0 / sqrt(scope_mag(c)), _smooth(ads_amount))


## Aumento del visor en uso (variable o fijo).
func scope_mag(c: WeaponSlot) -> float:
	return clampf(c.zoom, c.data.scope_mag, c.data.scope_mag_max) if has_variable_zoom(c.data) else c.data.scope_mag


static func has_variable_zoom(d: WeaponData) -> bool:
	return d.scope_mag > 1.0 and d.scope_mag_max > d.scope_mag


func scope_camera() -> Camera3D:
	return _scope_cam


func eye_relief_for(c: WeaponSlot) -> float:
	if c.data.eye_relief > 0.0:
		return c.data.eye_relief
	var s := c.model.get_node("Sight")
	return s.get_meta("eye_relief", 0.2) if s.has_meta("eye_relief") else 0.2


func viewmodel_camera() -> Camera3D:
	return _vm_camera


func viewmodel_viewport() -> SubViewport:
	return _vm_viewport


func sight_node() -> Node3D:
	var c := current()
	return c.model.get_node("Sight") as Node3D if c != null else null


func get_state_dict() -> Dictionary:
	var c := current()
	if c == null:
		return {}
	return {
		"slot": current_slot,
		"name_key": c.data.name_key,
		"caliber": c.data.caliber,
		"cycling": state == State.CYCLING,
		"mag": c.mag,
		"mag_size": c.data.mag_size,
		"reserve": c.reserve,
		"mode": c.mode(),
		"has_modes": c.data.fire_modes.size() > 1,
		"reloading": state == State.RELOADING,
		"infinite": DebugTools.infinite_ammo,
		"zoom": scope_mag(c),
		"zoom_variable": has_variable_zoom(c.data),
	}


# --- Lógica (tick de física) ------------------------------------------------------

func physics_tick(cmd: PlayerCommand, delta: float) -> void:
	_cooldown -= delta
	_advance_state(delta)

	if player.is_sprinting:
		_sprint_block = SPRINT_RECOVERY
		if aiming or cmd.aim:
			player.input_provider.cancel_aim()
			cmd.aim = false
	else:
		_sprint_block -= delta

	if cmd.weapon_slot > 0 and slots.has(cmd.weapon_slot) and cmd.weapon_slot != current_slot \
			and state != State.HOLSTER:
		_start_holster(cmd.weapon_slot)

	var c := current()
	if cmd.fire_mode and c.data.fire_modes.size() > 1 and state == State.READY:
		c.mode_index = (c.mode_index + 1) % c.data.fire_modes.size()
		_play_mech(SynthSfx.click("mode", 1.3, 0.04), -8.0)
		_emit_state()

	if cmd.reload and state == State.READY and _can_reload(c):
		_start_reload()
		player.input_provider.cancel_aim()
		cmd.aim = false

	# Cerrojo: si se mantiene el gatillo, se acciona sin sacar el ojo del visor
	var keep_aim := state == State.CYCLING and aiming and cmd.fire
	var want_aim := cmd.aim and (state == State.READY or state == State.DRAW or keep_aim) and not player.is_sprinting
	if want_aim != aiming:
		aiming = want_aim
		EventBus.aim_changed.emit(aiming)
	ads_amount = move_toward(ads_amount, 1.0 if aiming else 0.0, delta / maxf(c.data.ads_time, 0.01))

	# Visor variable: la rueda regula el aumento mientras se apunta
	if cmd.zoom != 0 and aiming and has_variable_zoom(c.data):
		var z := clampf(scope_mag(c) * pow(ZOOM_STEP, cmd.zoom), c.data.scope_mag, c.data.scope_mag_max)
		if not is_equal_approx(z, c.zoom):
			c.zoom = z
			_play_mech(SynthSfx.click("zoom", 1.8, 0.025), -14.0)
			_emit_state()

	if state == State.READY and _cooldown <= 0.0 and _sprint_block <= 0.0:
		var wants := cmd.fire_pressed if c.mode() == "semi" else cmd.fire
		if wants:
			if c.mag > 0:
				_fire(c)
			elif cmd.fire_pressed:
				_play_mech(SynthSfx.click("dry", 0.8, 0.05), -6.0)
				_cooldown = 0.2
				if c.reserve <= 0:
					EventBus.toast.emit(tr("weapon.empty"))

	_update_interaction(cmd)


func _advance_state(delta: float) -> void:
	if state == State.READY:
		return
	state_time += delta
	var c := current()
	if state == State.RELOADING:
		# Escopeta: expulsa las vainas al quebrarse
		if c.data.reload_type == "break" and not _reload_fx_done and state_time >= state_duration * 0.3:
			_reload_fx_done = true
			var spent := c.data.mag_size - c.mag
			for i in spent:
				_eject_shell(c, true, i)
		if state_time >= state_duration:
			_finish_reload(c)
	elif state == State.HOLSTER and state_time >= state_duration:
		_equip(_pending_slot)
	elif state == State.DRAW and state_time >= state_duration:
		_set_state(State.READY, 0.0)
	elif state == State.CYCLING:
		# Cerrojo: la vaina sale cuando el cerrojo va hacia atrás
		if not _cycle_fx_done and state_time >= state_duration * 0.45:
			_cycle_fx_done = true
			_eject_shell(c, false, 0)
			_play_mech(SynthSfx.click("bolt_back", 0.75, 0.07), -7.0)
		if state_time >= state_duration:
			_play_mech(SynthSfx.click("bolt_fwd", 1.0, 0.05), -8.0)
			_set_state(State.READY, 0.0)
			_emit_state()


func _set_state(s: State, duration: float) -> void:
	state = s
	state_time = 0.0
	state_duration = duration


func _equip(slot: int) -> void:
	for k: int in slots:
		(slots[k] as WeaponSlot).model.visible = (k == slot)
	current_slot = slot
	_pending_slot = -1
	_set_state(State.DRAW, current().data.draw_time)
	_play_mech(SynthSfx.click("draw", 0.7, 0.07), -10.0)
	_emit_state()


func _start_holster(slot: int) -> void:
	_pending_slot = slot
	if aiming:
		player.input_provider.cancel_aim()
	_set_state(State.HOLSTER, current().data.holster_time)
	_emit_state()


func _can_reload(c: WeaponSlot) -> bool:
	return c.mag < c.data.mag_size and (c.reserve > 0 or DebugTools.infinite_ammo)


func _start_reload() -> void:
	var c := current()
	_reload_empty = c.mag == 0
	_reload_fx_done = false
	_set_state(State.RELOADING, reload_duration(c))
	_play_mech(SynthSfx.click("reload_out", 0.6, 0.08), -6.0)
	_emit_state()


## Duración de la recarga según el tipo de arma y cuántos cartuchos faltan.
func reload_duration(c: WeaponSlot) -> float:
	var w := c.data
	if w.reload_type == "rounds":
		if c.mag == 0 and w.clip_reload:
			return w.reload_time_empty
		var needed := w.mag_size - c.mag
		if not DebugTools.infinite_ammo:
			needed = mini(needed, c.reserve)
		return w.reload_time + w.round_time * needed
	return w.reload_time_empty if c.mag == 0 else w.reload_time


func _finish_reload(c: WeaponSlot) -> void:
	var needed := c.data.mag_size - c.mag
	var take := needed if DebugTools.infinite_ammo else mini(needed, c.reserve)
	c.mag += take
	if not DebugTools.infinite_ammo:
		c.reserve -= take
	_play_mech(SynthSfx.click("reload_in", 0.9, 0.06), -6.0)
	_set_state(State.READY, 0.0)
	_emit_state()


func _fire(c: WeaponSlot) -> void:
	var w := c.data
	if not DebugTools.infinite_ammo:
		c.mag -= 1
	c.shots += 1
	_cooldown = maxf(w.seconds_per_shot(), DOUBLE_BARREL_GAP if w.reload_type == "break" else 0.0)

	var cam := player.camera
	var origin := cam.global_position
	var basis := cam.global_basis
	var fwd := -basis.z
	var spread := lerpf(w.spread_hip, w.spread_ads, _smooth(ads_amount)) * _spread_factor(w)
	var combat := CombatWorld.get_for(player)
	var muzzle_world := _vm_to_world(c.model.get_node("Muzzle").global_position)
	for i in maxi(w.pellets, 1):
		var cone := spread + (w.pellet_spread if w.pellets > 1 else 0.0)
		var dir := _random_cone(fwd, basis, cone)
		var tracer := i == 0 and w.tracer_every > 0 and c.shots % w.tracer_every == 0
		combat.fire_projectile(origin, dir, w, player, [player.get_rid()], tracer, muzzle_world)

	# Retroceso de cámara (subida + desvío lateral) y patada visual del arma
	var mult := lerpf(1.0, w.recoil_ads_mult, ads_amount)
	if player.stance == Player.Stance.CROUCHING:
		mult *= 0.85
	player.apply_recoil(deg_to_rad(w.recoil_pitch * mult),
		deg_to_rad(_rng.randf_range(-w.recoil_yaw, w.recoil_yaw) * mult), w.recoil_recovery)
	_kick_pos.z += w.kick_back * lerpf(1.0, 0.6, ads_amount)
	_kick_rot.x += deg_to_rad(w.kick_rot) * lerpf(1.0, 0.45, ads_amount)
	_kick_rot.z += deg_to_rad(_rng.randf_range(-1.5, 1.5))
	_slide_kick = 1.0

	_flash_time = 0.045
	combat.muzzle_flash_light(muzzle_world)
	_audio_shot.stream = SynthSfx.gunshot(w.id, w.sfx_body_hz, w.sfx_tail)
	_audio_shot.volume_db = w.sfx_volume_db
	_audio_shot.pitch_scale = _rng.randf_range(0.96, 1.04)
	_audio_shot.play()
	if w.bolt_action:
		_cycle_fx_done = false
		_set_state(State.CYCLING, w.cycle_time)
	elif w.reload_type != "break":
		_eject_shell(c, false, 0)
	EventBus.weapon_fired.emit(w.id)
	_emit_state()


## Multiplicador de dispersión por movimiento, aire y postura.
func _spread_factor(w: WeaponData) -> float:
	var f := 1.0
	var hspeed := Vector2(player.velocity.x, player.velocity.z).length()
	f *= lerpf(1.0, w.spread_move_mult, clampf(hspeed / player.config.walk_speed, 0.0, 1.0))
	if not player.is_on_floor():
		f *= w.spread_air_mult
	if player.stance == Player.Stance.CROUCHING:
		f *= w.spread_crouch_mult
	return f


## Dirección aleatoria dentro de un cono (diámetro en grados).
func _random_cone(fwd: Vector3, basis: Basis, cone_deg: float) -> Vector3:
	if cone_deg <= 0.0:
		return fwd
	var half := deg_to_rad(cone_deg * 0.5)
	var r := tan(half) * sqrt(_rng.randf())
	var th := _rng.randf() * TAU
	return (fwd + basis.x * r * cos(th) + basis.y * r * sin(th)).normalized()


func _eject_shell(_c: WeaponSlot, shotgun_shell: bool, index: int) -> void:
	var cam := player.camera.global_transform
	# Fuera del centro de la vista: a la derecha y adelante (fusil/pistola) o
	# abajo y adelante (vainas de la escopeta al quebrarla). Así no tapan la mira.
	var local := Vector3(0.28, -0.12, -0.45) if not shotgun_shell else Vector3(-0.04 + index * 0.08, -0.32, -0.35)
	var pos := cam * local
	var vel := cam.basis * (Vector3(1.6, 1.4, 0.4) if not shotgun_shell else Vector3(-0.3 + index * 0.6, 0.8, 2.0))
	vel += player.velocity
	CombatWorld.get_for(player).spawn_shell(Transform3D(cam.basis, pos), vel, shotgun_shell)


# --- Interacción ------------------------------------------------------------

func _update_interaction(cmd: PlayerCommand) -> void:
	var cam := player.camera
	var from := cam.global_position
	var to := from - cam.global_basis.z * INTERACT_RANGE
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = [player.get_rid()]
	q.collide_with_areas = true
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
	var target: Node = null
	if not hit.is_empty():
		var n := hit["collider"] as Node
		for i in 4:
			if n == null:
				break
			if n.has_method("interact"):
				target = n
				break
			n = n.get_parent()
	if target != _hint_target:
		_hint_target = target
		var text := ""
		if target != null:
			var key_label := InputActions.event_label(InputActions.get_kbm_event("interact"))
			text = tr(target.call("get_interact_text")) % key_label
		EventBus.interact_hint_changed.emit(text)
	if cmd.interact and target != null:
		target.call("interact", player)


## Repone la munición de todas las armas (caja de munición del laboratorio).
func refill_all() -> void:
	for k: int in slots:
		var ws := slots[k] as WeaponSlot
		ws.reserve = ws.data.start_reserve
		ws.mag = ws.data.mag_size
	_emit_state()


func _emit_state() -> void:
	EventBus.weapon_state_changed.emit(get_state_dict())


# --- Vista (cada frame) -----------------------------------------------------

func _process(delta: float) -> void:
	if player == null:
		return
	_time += delta
	var c := current()
	var w := c.data
	var a := _smooth(ads_amount)

	# Pose base: cadera ↔ mira alineada con el centro de la pantalla
	var sight := (c.model.get_node("Sight") as Node3D).position
	var hip: Vector3 = HIP_POSE.get(w.model, Vector3(0.13, -0.14, -0.26))
	var ads := Vector3(-sight.x, -sight.y, -eye_relief_for(c) - sight.z)
	var pos := hip.lerp(ads, a)
	var rot := Vector3.ZERO

	# Correr: arma baja y girada
	_sprint_pose = move_toward(_sprint_pose, 1.0 if player.is_sprinting else 0.0, delta / 0.18)
	var s := _smooth(_sprint_pose)
	pos += Vector3(0.03, -0.07, 0.07) * s
	rot += Vector3(deg_to_rad(-14), deg_to_rad(38), deg_to_rad(10)) * s

	# Balanceo al caminar
	var hspeed := Vector2(player.velocity.x, player.velocity.z).length()
	if player.is_on_floor():
		_bob_t += delta * hspeed * 1.7
	var amp := 0.011 * clampf(hspeed / 4.0, 0.0, 1.6) * (1.0 - a * 0.85)
	pos += Vector3(sin(_bob_t) * amp, -absf(cos(_bob_t)) * amp * 0.8, 0.0)
	rot.z += sin(_bob_t) * amp * 1.2
	# Respiración
	pos.y += sin(_time * 1.7) * 0.0012 * (1.0 - a * 0.6)

	# Inercia al mirar (el arma "se atrasa" respecto de la cámara)
	var look := player.last_look
	var sway_target := Vector3(-look.x, look.y, 0.0) * 0.5 * (1.0 - a * 0.75)
	sway_target = sway_target.limit_length(0.035)
	_sway = _sway.lerp(sway_target, 1.0 - exp(-10.0 * delta))
	pos += _sway
	rot += Vector3(_sway.y * 1.2, _sway.x * 2.0, _sway.x * 1.5)

	# Retroceso visual
	_kick_pos = _kick_pos.lerp(Vector3.ZERO, 1.0 - exp(-16.0 * delta))
	_kick_rot = _kick_rot.lerp(Vector3.ZERO, 1.0 - exp(-12.0 * delta))
	pos += _kick_pos
	rot += _kick_rot

	# Animaciones de estado
	match state:
		State.HOLSTER:
			var t := _smooth(clampf(state_time / state_duration, 0.0, 1.0))
			pos.y -= 0.28 * t
			rot.x -= deg_to_rad(40) * t
		State.DRAW:
			var t := _smooth(1.0 - clampf(state_time / state_duration, 0.0, 1.0))
			pos.y -= 0.28 * t
			rot.x -= deg_to_rad(40) * t
		State.RELOADING:
			var t := clampf(state_time / state_duration, 0.0, 1.0)
			var edge := minf(0.15, 0.35 / maxf(state_duration, 0.1))
			var inn := _smooth(clampf(t / edge, 0.0, 1.0)) * (1.0 - _smooth(clampf((t - (1.0 - edge)) / edge, 0.0, 1.0)))
			var brk := w.reload_type == "break"
			rot.z += deg_to_rad(14.0 if brk else 30.0) * inn
			rot.x += deg_to_rad(12.0 if brk else 10.0) * inn
			# Escopeta: se sube y se acerca para ver las recámaras abiertas
			pos += (Vector3(-0.03, 0.06, 0.03) if brk else Vector3(-0.035, -0.035, 0.05)) * inn
			if w.reload_type == "rounds":
				# Empuja cada cartucho: pequeño golpe por ronda
				var per := w.round_time / maxf(state_duration, 0.01)
				var k := fmod(t, maxf(per, 0.01)) / maxf(per, 0.01)
				pos.y -= sin(k * PI) * 0.006 * inn
		State.CYCLING:
			# Accionar el cerrojo: el arma baja apenas y gira hacia la mano
			var t := clampf(state_time / state_duration, 0.0, 1.0)
			var b := sin(t * PI)
			# Casi nada si se acciona sin dejar de mirar por el visor
			rot.z += deg_to_rad(lerpf(8.0, 1.2, a)) * b
			pos.y -= 0.01 * b * (1.0 - a * 0.85)

	_rig.position = pos
	_rig.rotation = rot
	_animate_parts(c, delta)

	_vm_camera.fov = lerpf(VM_FOV_HIP, VM_FOV_ADS, a)
	_update_scope(c, a)
	_update_flash(c, delta)
	_sync_light()


func _animate_parts(c: WeaponSlot, delta: float) -> void:
	var w := c.data
	var t := clampf(state_time / maxf(state_duration, 0.001), 0.0, 1.0) if state == State.RELOADING else -1.0
	var m := c.model
	if m.has_node("Mag"):
		var mag := m.get_node("Mag") as Node3D
		var off := 0.0
		if t >= 0.0:
			if t < 0.15:
				off = 0.0
			elif t < 0.35:
				off = _smooth((t - 0.15) / 0.2) * 0.32
			elif t < 0.5:
				off = 0.32
			elif t < 0.64:
				off = (1.0 - _smooth((t - 0.5) / 0.14)) * 0.32
		mag.position = _part_base[mag] + Vector3(0, -off, off * 0.15)
		mag.visible = off < 0.3
	if m.has_node("Charging"):
		var ch := m.get_node("Charging") as Node3D
		var back := 0.0
		if t >= 0.0 and w.reload_type == "rounds":
			back = 0.07 * _smooth(clampf(t / 0.08, 0.0, 1.0)) * (1.0 - _smooth(clampf((t - 0.92) / 0.08, 0.0, 1.0)))
		elif t >= 0.0 and _reload_empty and t > 0.68 and t < 0.84:
			back = sin((t - 0.68) / 0.16 * PI) * 0.07
		ch.position = _part_base[ch] + Vector3(0, 0, back)
	if m.has_node("Slide"):
		var sl := m.get_node("Slide") as Node3D
		_slide_kick = move_toward(_slide_kick, 0.0, delta / 0.07)
		var back := sin(_slide_kick * PI) * 0.032 if _slide_kick > 0.0 else 0.0
		var locked := c.mag == 0 and not (t >= 0.0 and t > 0.72)
		if locked and (state == State.READY or state == State.RELOADING) and _slide_kick <= 0.5:
			back = 0.032
		sl.position = _part_base[sl] + Vector3(0, 0, back)
	if m.has_node("Bolt"):
		var bolt := m.get_node("Bolt") as Node3D
		var lift := 0.0
		var back := 0.0
		var ct := -1.0
		if state == State.CYCLING:
			ct = clampf(state_time / maxf(state_duration, 0.001), 0.0, 1.0)
		elif t >= 0.0:
			# Recargando: cerrojo abierto mientras entran los cartuchos
			if t <= 0.08:
				ct = t / 0.08 * 0.35
			elif t < 0.92:
				ct = 0.35
			else:
				ct = 0.35 + (t - 0.92) / 0.08 * 0.65
		if ct >= 0.0:
			lift = _smooth(clampf(ct / 0.2, 0.0, 1.0)) * (1.0 - _smooth(clampf((ct - 0.8) / 0.2, 0.0, 1.0)))
			back = _smooth(clampf((ct - 0.2) / 0.25, 0.0, 1.0)) * (1.0 - _smooth(clampf((ct - 0.5) / 0.25, 0.0, 1.0)))
		bolt.position = _part_base[bolt] + Vector3(0, 0, back * 0.075)
		bolt.rotation = Vector3(0, 0, deg_to_rad(65) * lift)
	if m.has_node("Barrels"):
		var br := m.get_node("Barrels") as Node3D
		_animate_break(br, t)


## Escopeta de quiebre: la mano izquierda suelta el guardamanos, los caños caen
## a fondo, la mano trae dos cartuchos, los mete en las recámaras, se cierra y la
## mano vuelve al guardamanos.
##   0.02–0.12 la mano se va · 0.10–0.26 abre (salen las vainas a 0.3)
##   0.34–0.48 trae los cartuchos · 0.48–0.60 los mete · 0.62–0.74 la mano se va
##   0.80–0.92 cierra · 0.88–0.98 la mano vuelve al guardamanos
func _animate_break(br: Node3D, t: float) -> void:
	var r := t >= 0.0
	var open := 0.0
	if r:
		open = _smooth(clampf((t - 0.1) / 0.16, 0.0, 1.0)) * (1.0 - _smooth(clampf((t - 0.8) / 0.12, 0.0, 1.0)))
	br.rotation = Vector3(deg_to_rad(-BREAK_OPEN_DEG) * open, 0, 0)
	# Fuera de la vista: abajo y a la izquierda (en el espacio del arma, pasado a los caños)
	var away := br.basis.inverse() * Vector3(-0.07, -0.26, 0.04)
	var hand := br.get_node_or_null("HandL") as Node3D
	if hand != null:
		var off := 0.0
		if r:
			off = _smooth(clampf((t - 0.02) / 0.1, 0.0, 1.0)) * (1.0 - _smooth(clampf((t - 0.88) / 0.1, 0.0, 1.0)))
		hand.position = _part_base[hand] + away * off
		hand.visible = off < 0.98
	var loader := br.get_node_or_null("Loader") as Node3D
	var load_off := away
	if loader != null:
		var behind := Vector3(0, 0.004, 0.045)  # alineados detrás de las recámaras
		var seated := Vector3(0, 0, -0.024)  # culote al ras de la recámara
		if r and t >= 0.34 and t < 0.48:
			load_off = away.lerp(behind, _smooth((t - 0.34) / 0.14))
		elif r and t >= 0.48 and t < 0.62:
			load_off = behind.lerp(seated, _smooth(clampf((t - 0.48) / 0.12, 0.0, 1.0)))
		elif r and t >= 0.6 and t < 0.62:
			load_off = seated
		elif r and t >= 0.62 and t < 0.74:
			load_off = seated.lerp(away, _smooth((t - 0.62) / 0.12))
		loader.visible = r and t >= 0.34 and t < 0.74
		loader.position = _part_base[loader] + load_off
	for n: String in ["ShellL", "ShellR"]:
		var sh := br.get_node(n) as Node3D
		var base: Vector3 = _part_base[sh]
		sh.visible = r and t >= 0.34 and t < 0.92
		# Los cartuchos viajan en la mano hasta que entran; después quedan en la recámara
		sh.position = base + (load_off if (r and t < 0.6 and loader != null) else Vector3(0, 0, -0.024))


func _update_flash(c: WeaponSlot, delta: float) -> void:
	if _flash_time > 0.0:
		_flash_time -= delta
		var muzzle := c.model.get_node("Muzzle") as Node3D
		_flash.visible = true
		_flash.global_position = muzzle.global_position
		_flash.rotation = Vector3(0, 0, _rng.randf() * TAU)
		var sc := _rng.randf_range(0.8, 1.25) * (1.6 if c.data.reload_type == "break" else 1.0)
		_flash.scale = Vector3(sc, sc, sc)
	else:
		_flash.visible = false


## Copia la dirección del sol del mundo a la luz del arma (en espacio de cámara).
func _sync_light() -> void:
	var sun := get_tree().get_first_node_in_group("sun") as DirectionalLight3D
	if sun == null:
		return
	_vm_light.basis = player.camera.global_basis.inverse() * sun.global_basis
	_vm_light.light_color = sun.light_color
	_vm_light.light_energy = sun.light_energy * 0.9


## Convierte un punto del mundo del arma (espacio de cámara) al mundo del juego.
func _vm_to_world(p: Vector3) -> Vector3:
	return player.camera.global_transform * p


func _play_mech(stream: AudioStream, volume_db: float) -> void:
	_audio_mech.stream = stream
	_audio_mech.volume_db = volume_db
	_audio_mech.play()


static func _smooth(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


func _remember_parts(model: Node3D) -> void:
	for path: String in ["Mag", "Charging", "Slide", "Bolt", "Barrels/ShellL", "Barrels/ShellR", "Barrels/HandL", "Barrels/Loader"]:
		if model.has_node(path):
			var n := model.get_node(path) as Node3D
			_part_base[n] = n.position


## Visor con aumento: la cámara del visor mira por el eje del arma y su FOV
## se calcula para que el aumento sea real respecto de la vista sin visor.
func _update_scope(c: WeaponSlot, a: float) -> void:
	var lens := c.model.get_node_or_null("ScopeLens") as MeshInstance3D
	var on := lens != null and a > 0.02 and c.data.scope_mag > 1.0
	_scope_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	if lens == null:
		return
	(lens.material_override as ShaderMaterial).set_shader_parameter("active", a if on else 0.0)
	if not on:
		return
	var main := player.camera
	# Tamaño angular del ocular en pantalla, convertido a ángulo de la cámara del mundo
	var dist := maxf(-lens.global_position.z, 0.01)
	var d: float = lens.get_meta("lens_d", 0.034)
	var a_vm := 2.0 * atan((d * 0.5) / dist)
	var frac := tan(a_vm * 0.5) / tan(deg_to_rad(_vm_camera.fov) * 0.5)
	var a_main := 2.0 * atan(frac * tan(deg_to_rad(main.fov) * 0.5))
	_scope_cam.fov = clampf(rad_to_deg(a_main) / scope_mag(c), 0.3, 60.0)
	# Mira por el eje del arma (incluye retroceso y balanceo)
	_scope_cam.global_transform = Transform3D(main.global_basis * _rig.basis, main.global_position)


func _build_scope_view() -> void:
	_scope_vp = SubViewport.new()
	_scope_vp.name = "ScopeView"
	_scope_vp.size = Vector2i(SCOPE_RES, SCOPE_RES)
	_scope_vp.own_world_3d = false
	_scope_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_scope_vp.audio_listener_enable_3d = false
	_scope_vp.msaa_3d = Viewport.MSAA_2X
	add_child(_scope_vp)
	_scope_cam = Camera3D.new()
	_scope_cam.near = 0.05
	_scope_cam.far = 2000.0
	_scope_cam.current = true
	_scope_vp.add_child(_scope_cam)


func _build_viewmodel() -> void:
	_vm_layer = CanvasLayer.new()
	_vm_layer.name = "ViewmodelLayer"
	_vm_layer.layer = 1
	add_child(_vm_layer)
	var container := SubViewportContainer.new()
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vm_layer.add_child(container)
	_vm_viewport = SubViewport.new()
	_vm_viewport.transparent_bg = true
	_vm_viewport.own_world_3d = true
	_vm_viewport.handle_input_locally = false
	_vm_viewport.audio_listener_enable_3d = false
	_vm_viewport.msaa_3d = Viewport.MSAA_2X
	container.add_child(_vm_viewport)

	_vm_camera = Camera3D.new()
	_vm_camera.fov = VM_FOV_HIP
	_vm_camera.near = 0.01
	_vm_camera.far = 10.0
	_vm_camera.current = true
	_vm_viewport.add_child(_vm_camera)

	_vm_light = DirectionalLight3D.new()
	_vm_light.shadow_enabled = false
	_vm_viewport.add_child(_vm_light)
	var fill := DirectionalLight3D.new()
	fill.light_energy = 0.25
	fill.rotation_degrees = Vector3(-20, 160, 0)
	fill.shadow_enabled = false
	_vm_viewport.add_child(fill)

	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.6, 0.56)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	var we := WorldEnvironment.new()
	we.environment = env
	_vm_viewport.add_child(we)

	_rig = Node3D.new()
	_rig.name = "Rig"
	_vm_viewport.add_child(_rig)

	_flash = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.14, 0.14)
	_flash.mesh = q
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fm.albedo_texture = _make_flash_texture()
	fm.albedo_color = Color(1.0, 0.75, 0.45)
	_flash.material_override = fm
	_flash.visible = false
	_vm_viewport.add_child(_flash)

	_audio_shot = AudioStreamPlayer.new()
	_audio_shot.bus = "SFX_World"
	_audio_shot.max_polyphony = 6
	add_child(_audio_shot)
	_audio_mech = AudioStreamPlayer.new()
	_audio_mech.bus = "SFX_World"
	_audio_mech.max_polyphony = 3
	add_child(_audio_mech)


## Estrella de destello generada por código. TODO-ASSET: vfx_muzzle_flash
static func _make_flash_texture() -> ImageTexture:
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := Vector2(n, n) * 0.5
	for y in n:
		for x in n:
			var v := Vector2(x, y) - c
			var d := v.length() / (n * 0.5)
			var ang := atan2(v.y, v.x)
			var rays := pow(absf(cos(ang * 3.0)), 8.0) * (1.0 - d)
			var core := clampf(1.0 - d * 2.2, 0.0, 1.0)
			var a := clampf(core + rays * 1.2, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)
