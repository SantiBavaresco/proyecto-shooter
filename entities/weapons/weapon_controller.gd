class_name WeaponController
extends Node
## Armas del jugador: lógica (tick de física) y vista en primera persona (cada frame).
##
## Vista ("viewmodel"): las armas se dibujan en un SubViewport con mundo propio,
## cámara propia y FOV propio, superpuesto a la imagen del juego. Así el arma
## nunca atraviesa paredes y su FOV no depende del FOV del jugador.
## Apuntado real: al apuntar, el arma se coloca de forma que su marcador "Sight"
## quede exactamente en el eje de la cámara (centro de la pantalla).

enum State { READY, RELOADING, HOLSTER, DRAW, CYCLING, CLEARING }

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
## Desgaste por disparo según el mecanismo (fracción del estado).
const WEAR_PER_SHOT := {"magazine": 1.0 / 4000.0, "rounds": 1.0 / 5000.0, "break": 1.0 / 6000.0}
## Estado que simula la zona de armas gastadas.
const WORN_CONDITION := 0.18


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
	## Estado del arma (1 nueva, 0 destruida): baja con cada disparo.
	var condition: float = 1.0
	## Falla actual: "", "misfire", "stovepipe", "double_feed", "unchambered".
	var malfunction: String = ""
	## Vaina trabada en la ventana (se ve hasta que se monta).
	var case_stuck: bool = false

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
## Cartuchos disparados al empezar la recarga (escopetas: cuáles se extraen).
var _break_spent: int = 2
## Cargador fuera de la vista (se "cambia" por uno nuevo mientras no se ve).
var _mag_hidden: bool = false
## Plan de la recarga o del destrabado en curso (armas con cargador o manija).
var _plan: ReloadPlan = null
var _plan_ev: int = 0
## Acción de destrabado en curso (para aplicar su efecto al terminar).
var _clear_action: String = ""
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
## Giro del arma por la pose de recarga (rad): la mano del guardamanos lo compensa.
var _reload_roll: float = 0.0
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
		"clearing": state == State.CLEARING or (state == State.CYCLING and c.malfunction != ""),
		"fault": c.malfunction,
		"condition": effective_condition(c),
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

	if cmd.reload and state == State.READY and (c.malfunction != "" or _can_reload(c)):
		if c.malfunction != "":
			_start_clear(c)
		else:
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
		if wants and c.malfunction != "":
			# Trabada o sin bala en la recámara: el gatillo no hace nada
			if cmd.fire_pressed:
				_play_mech(SynthSfx.click("dry", 0.8, 0.05), -6.0)
				_cooldown = 0.2
		elif wants:
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
	if (state == State.RELOADING or state == State.CLEARING) and _plan != null:
		_run_plan_events(c)
	if state == State.CLEARING and state_time >= state_duration:
		_finish_clear(c)
		return
	if state == State.RELOADING:
		# Escopeta: expulsa las vainas al quebrarse
		if c.data.reload_type == "break" and not _reload_fx_done and state_time >= state_duration * 0.3:
			_reload_fx_done = true
			var spent := c.data.mag_size - c.mag
			for i in spent:
				_eject_shell(c, true, i, _break_shell_pos(c, i))
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
			if c.malfunction == "misfire":
				# Cerrojo: sale el cartucho que no disparó y entra otro
				c.malfunction = ""
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
	_break_spent = c.data.mag_size - c.mag
	_plan = null
	var dur := reload_duration(c)
	if c.data.reload_type == "magazine" and c.model.has_node("Mag"):
		_plan = ReloadPlan.make("reload", _plan_geo(c), player.stress.level(), _reload_empty, _rng,
			c.data.reload_time, c.data.reload_time_empty)
		dur = _plan.duration
	else:
		# Escopetas y cartucho a cartucho: solo más lento con estrés
		dur *= [1.0, 1.15, 1.45][player.stress.level()]
	_plan_ev = 0
	_set_state(State.RELOADING, dur)
	_play_mech(SynthSfx.click("reload_out", 0.6, 0.08), -6.0)
	_emit_state()


## Destrabar (R con una falla): cerrojo → accionarlo; con manija o corredera → el
## plan de la falla (golpe al cargador, montar, sacar el cargador...).
func _start_clear(c: WeaponSlot) -> void:
	_clear_action = c.malfunction
	_reload_empty = false
	if c.data.bolt_action:
		_cycle_fx_done = false
		_set_state(State.CYCLING, c.data.cycle_time * [1.0, 1.15, 1.4][player.stress.level()])
		_emit_state()
		return
	var act := c.malfunction
	if act == "unchambered":
		act = "rack"
	_plan = ReloadPlan.make(act, _plan_geo(c), player.stress.level(), false, _rng, c.data.reload_time, c.data.reload_time_empty)
	_plan_ev = 0
	_set_state(State.CLEARING, _plan.duration)
	_play_mech(SynthSfx.click("reload_out", 1.1, 0.05), -9.0)
	_emit_state()


func _finish_clear(c: WeaponSlot) -> void:
	if _clear_action == "double_feed" and c.mag > 0 and not DebugTools.infinite_ammo:
		c.mag -= 1  # el cartucho que se trabó se pierde
	c.malfunction = ""
	c.case_stuck = false
	_clear_action = ""
	_set_state(State.READY, 0.0)
	_emit_state()


## Datos del arma que necesita el plan: palmas, cargador, manija o corredera.
func _plan_geo(c: WeaponSlot) -> Dictionary:
	var m := c.model
	var z := Vector3.ZERO
	var g := {"pistol": c.data.model == "pistol"}
	var hl := m.get_node_or_null("HandL") as Node3D
	var hr := m.get_node_or_null("HandR") as Node3D
	g["pl"] = hl.get_meta("palm", z) if hl != null else z
	g["pr"] = hr.get_meta("palm", z) if hr != null else z
	if m.has_node("Mag"):
		var mag := m.get_node("Mag") as Node3D
		g["mag_base"] = _part_base[mag]
		g["grab"] = mag.get_meta("grab", Vector3(0, -0.05, 0.0))
	if m.has_node("Charging") and not g["pistol"]:
		var ch := m.get_node("Charging") as Node3D
		var kn: Vector3 = _part_base[ch] + (ch.get_meta("knob", z) as Vector3)
		var sd := 1.0 if kn.x > 0.0 else -1.0
		var hook := m.get_node_or_null("HookR" if sd > 0.0 else "HookL") as Node3D
		g["rack"] = true
		g["knob"] = kn
		g["side"] = sd
		g["hook_palm"] = hook.get_meta("palm", z) if hook != null else z
		g["travel"] = 0.05 if absf(kn.x) < 0.016 else 0.075
		g["pull_part"] = "Charging"
	elif m.has_node("Slide") and m.has_node("HookP"):
		var hp := m.get_node("HookP") as Node3D
		g["rack"] = true
		g["knob"] = hp.get_meta("knob", Vector3(0, 0.022, 0.02))
		g["side"] = -1.0
		g["hook_palm"] = hp.get_meta("palm", z)
		g["travel"] = 0.032
		g["pull_part"] = "Slide"
	return g


## Sonidos y efectos del plan (vainas, cartuchos) a medida que pasa el tiempo.
func _run_plan_events(c: WeaponSlot) -> void:
	var t := clampf(state_time / maxf(state_duration, 0.001), 0.0, 1.0)
	while _plan_ev < _plan.events.size() and float(_plan.events[_plan_ev][0]) <= t:
		var n: String = _plan.events[_plan_ev][1]
		_plan_ev += 1
		match n:
			"mag_out":
				_play_mech(SynthSfx.click("mag_out", 0.7, 0.06), -7.0)
			"mag_in":
				_play_mech(SynthSfx.click("mag_in", 0.95, 0.05), -5.0)
			"fumble":
				_play_mech(SynthSfx.click("fumble", 1.25, 0.03), -8.0)
			"tap":
				_play_mech(SynthSfx.click("tap", 0.55, 0.04), -8.0)
			"rack_back":
				_play_mech(SynthSfx.click("rack_back", 0.8, 0.06), -6.0)
			"rack_fwd":
				_play_mech(SynthSfx.click("rack_fwd", 1.05, 0.05), -5.0)
			"slide_release":
				_play_mech(SynthSfx.click("slide_rel", 1.0, 0.05), -6.0)
			"eject_live", "eject_case":
				c.case_stuck = false
				var ej := c.model.get_node_or_null("Ejection") as Node3D
				_eject_shell(c, false, 0, ej.global_position if ej != null else Vector3.INF)


## Duración de la recarga según el tipo de arma y cuántos cartuchos faltan
## (durante una recarga o un destrabado, la duración real, con estrés).
func reload_duration(c: WeaponSlot) -> float:
	if c == current() and (state == State.RELOADING or state == State.CLEARING):
		return state_duration
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
	if _plan != null and _plan.forgot_chamber:
		# Con el apuro se olvidó de montar: la primera vez el gatillo hace "clic"
		c.malfunction = "unchambered"
	_play_mech(SynthSfx.click("reload_in", 0.9, 0.06), -6.0)
	_set_state(State.READY, 0.0)
	_emit_state()


func _fire(c: WeaponSlot) -> void:
	var w := c.data
	var cond := effective_condition(c)
	c.condition = maxf(0.0, c.condition - float(WEAR_PER_SHOT.get(w.reload_type, 1.0 / 4000.0)))
	var risk := fault_risk(cond)
	if _rng.randf() < risk["misfire"]:
		# No disparó: el cartucho queda en la recámara (con cargador o cerrojo hay que
		# destrabar; en la escopeta se pasa al otro caño y se saca al recargar)
		if not DebugTools.infinite_ammo:
			c.mag -= 1
		_play_mech(SynthSfx.click("dry", 0.75, 0.05), -4.0)
		_cooldown = 0.25
		if w.reload_type != "break":
			c.malfunction = "misfire"
		_kick_rot.x += deg_to_rad(0.6)
		_emit_state()
		return
	if not DebugTools.infinite_ammo:
		c.mag -= 1
	c.shots += 1
	_cooldown = maxf(w.seconds_per_shot(), DOUBLE_BARREL_GAP if w.reload_type == "break" else 0.0)

	var cam := player.camera
	var origin := cam.global_position
	var basis := cam.global_basis
	var fwd := -basis.z
	var spread := lerpf(w.spread_hip * player.stress.hip_spread_mult(), w.spread_ads, _smooth(ads_amount)) * _spread_factor(w)
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
		# Semiautomáticas: la vaina puede quedar trabada en la ventana o entrar dos
		# cartuchos a la vez (solo si quedaba otro para alimentar)
		var roll := _rng.randf()
		if c.mag > 0 and roll < risk["stovepipe"]:
			c.malfunction = "stovepipe"
			c.case_stuck = true
			_cooldown = 0.3
		elif c.mag > 0 and w.reload_type == "magazine" and roll < risk["stovepipe"] + risk["double_feed"]:
			c.malfunction = "double_feed"
			_cooldown = 0.3
			_eject_shell(c, false, 0)
		else:
			_eject_shell(c, false, 0)
	EventBus.weapon_fired.emit(w.id)
	_emit_state()


## Estado con el que se comporta el arma (la zona de armas gastadas lo baja).
func effective_condition(c: WeaponSlot) -> float:
	if player != null and player.zone_kinds.has("worn"):
		return minf(c.condition, WORN_CONDITION)
	return c.condition


## Probabilidad de cada falla por disparo según el estado: casi nada en un arma
## sana; sube rápido por debajo del 70 %.
static func fault_risk(condition: float) -> Dictionary:
	var k := pow(clampf((0.7 - condition) / 0.7, 0.0, 1.0), 2.0)
	return {"misfire": 0.0004 + 0.055 * k, "stovepipe": 0.0003 + 0.06 * k, "double_feed": 0.0001 + 0.018 * k}


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


func _eject_shell(_c: WeaponSlot, shotgun_shell: bool, index: int, from := Vector3.INF) -> void:
	var cam := player.camera.global_transform
	# Fuera del centro de la vista: a la derecha y adelante (fusil/pistola). Las vainas
	# de la escopeta salen de donde las dejó el extractor, hacia arriba y atrás.
	var local := Vector3(0.28, -0.12, -0.45) if not shotgun_shell else Vector3(-0.04 + index * 0.08, -0.32, -0.35)
	if from != Vector3.INF:
		local = from
	var pos := cam * local
	var vel := cam.basis * (Vector3(1.6, 1.4, 0.4) if not shotgun_shell else Vector3(-0.6 + index * 1.2, 2.0, 0.45))
	vel += player.velocity
	CombatWorld.get_for(player).spawn_shell(Transform3D(cam.basis, pos), vel, shotgun_shell)


## Dónde está (en el espacio de la cámara) la vaina "i" de la escopeta al saltar.
func _break_shell_pos(c: WeaponSlot, i: int) -> Vector3:
	var sh := c.model.get_node_or_null("Barrels/Shell" + ("L" if i == 0 else "R")) as Node3D
	return sh.global_position if sh != null else Vector3.INF


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
	_reload_roll = 0.0
	match state:
		State.HOLSTER:
			var t := _smooth(clampf(state_time / state_duration, 0.0, 1.0))
			pos.y -= 0.28 * t
			rot.x -= deg_to_rad(40) * t
		State.DRAW:
			var t := _smooth(1.0 - clampf(state_time / state_duration, 0.0, 1.0))
			pos.y -= 0.28 * t
			rot.x -= deg_to_rad(40) * t
		State.RELOADING, State.CLEARING:
			var t := clampf(state_time / state_duration, 0.0, 1.0)
			var edge := minf(0.15, 0.35 / maxf(state_duration, 0.1))
			var inn := _smooth(clampf(t / edge, 0.0, 1.0)) * (1.0 - _smooth(clampf((t - (1.0 - edge)) / edge, 0.0, 1.0)))
			# Pose de recarga: el arma se sube, se acerca y se gira para que se vea
			# lo que hacen las manos (brocal, ventana o recámaras)
			var rp := Vector3(-0.07, 0.07, 0.04)
			var rr := Vector3(18.0, -10.0, -38.0)
			match w.reload_type:
				"break":
					rp = Vector3(-0.03, 0.06, 0.03)
					rr = Vector3(12.0, 0.0, 14.0)
				"rounds":
					rp = Vector3(-0.04, 0.05, 0.03)
					rr = Vector3(12.0, 0.0, 22.0)
				_:
					if w.model == "pistol" and state == State.CLEARING:
						# Montar la pistola: más lejos y de costado, para ver la corredera
						rp = Vector3(-0.05, 0.07, -0.03)
						rr = Vector3(12.0, -18.0, -22.0)
					elif w.model == "pistol":
						rp = Vector3(-0.1, 0.12, 0.1)
						rr = Vector3(24.0, -8.0, -30.0)
			if _plan != null and _plan.side > 0.0:
				# Manija a la derecha: el arma gira para mostrar ese lado mientras monta
				var k := _smooth(_path(t, _plan.roll_w).x)
				rr = rr.lerp(Vector3(10.0, -16.0, 16.0), k)
				rp = rp.lerp(Vector3(-0.08, 0.05, 0.0), k)
			pos += rp * inn
			rot += rr * (PI / 180.0) * inn
			_reload_roll = deg_to_rad(rr.z) * inn
			# Golpes: sacar y calzar el cargador, abrir y cerrar los caños, la manija
			var bump := _reload_bumps(w, t)
			pos += bump[0]
			rot += bump[1] * (PI / 180.0)
			if w.reload_type == "rounds" and state == State.RELOADING:
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

	# Estrés: temblor de las manos (más fuerte manipulando el arma)
	var st := player.stress.value
	if st > 0.001:
		var busy := 1.6 if state == State.RELOADING or state == State.CLEARING else 1.0
		var tr3 := player.stress.tremor()
		pos += tr3 * 0.0026 * st * busy * (1.0 - a * 0.5)
		rot += Vector3(tr3.y, tr3.x, tr3.z) * deg_to_rad(0.9) * st * busy * (1.0 - a * 0.5)
	_rig.position = pos
	_rig.rotation = rot
	_animate_parts(c, delta)

	_vm_camera.fov = lerpf(VM_FOV_HIP, VM_FOV_ADS, a)
	_update_scope(c, a)
	_update_flash(c, delta)
	_sync_light()


## Recorrido suave por claves [[t, Vector3], ...] (Catmull-Rom): las manos y las
## piezas pasan por las posiciones clave sin frenar de golpe en cada una.
static func _path(t: float, keys: Array) -> Vector3:
	var n := keys.size()
	if t <= float(keys[0][0]):
		return keys[0][1]
	if t >= float(keys[n - 1][0]):
		return keys[n - 1][1]
	var i := 0
	while i < n - 2 and t > float(keys[i + 1][0]):
		i += 1
	var t0: float = keys[i][0]
	var t1: float = keys[i + 1][0]
	var u := clampf((t - t0) / maxf(t1 - t0, 1e-5), 0.0, 1.0)
	var p0: Vector3 = keys[maxi(i - 1, 0)][1]
	var p1: Vector3 = keys[i][1]
	var p2: Vector3 = keys[i + 1][1]
	var p3: Vector3 = keys[mini(i + 2, n - 1)][1]
	return 0.5 * ((2.0 * p1) + (p2 - p0) * u + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * u * u
		+ (3.0 * p1 - p0 - 3.0 * p2 + p3) * u * u * u)


## Golpes del arma durante la recarga: [desplazamiento, giro en grados].
func _reload_bumps(w: WeaponData, t: float) -> Array:
	var z := Vector3.ZERO
	if state == State.CLEARING and _plan != null:
		return [_path(t, _plan.bump_p), _path(t, _plan.bump_r)]
	match w.reload_type:
		"break":
			return [_path(t, [[0.0, z], [0.1, z], [0.16, Vector3(0, -0.012, 0.004)], [0.24, Vector3(0, 0.004, 0)], [0.3, z],
				[0.56, z], [0.6, Vector3(0, 0.002, -0.006)], [0.66, z], [0.8, z], [0.86, Vector3(0, 0.012, 0)],
				[0.92, Vector3(0, -0.004, 0)], [1.0, z]]),
				_path(t, [[0.0, z], [0.1, z], [0.16, Vector3(-5, 0, 1)], [0.24, Vector3(1, 0, 0)], [0.3, z], [0.56, z],
				[0.6, Vector3(-2, 0, 0)], [0.66, z], [0.8, z], [0.86, Vector3(7, 0, -1)], [0.92, Vector3(-2, 0, 0)], [1.0, z]])]
		"magazine":
			if _plan != null:
				return [_path(t, _plan.bump_p), _path(t, _plan.bump_r)]
	return [z, z]


## Manos durante la recarga y el cerrojo. Mano derecha (izquierda en pistolas):
## baja al cargador, se lo lleva, trae otro, lo calza y, vacía, tira de la manija.
## Cartucho a cartucho: la mano va a la ventana y empuja cada uno.
## Cerrojo: la mano derecha va a la bola del cerrojo y la acompaña.
func _animate_hands(c: WeaponSlot, t: float) -> Vector3:
	var m := c.model
	var w := c.data
	var hr := m.get_node_or_null("HandR") as Node3D
	var hl := m.get_node_or_null("HandL") as Node3D
	var z := Vector3.ZERO
	var off_r := z
	var off_l := z
	var mag_follow := z
	var pistol := w.model == "pistol"
	var rot_l := z  # giro de la muñeca izquierda (grados) alrededor de la palma
	var rot_r := z
	_mag_hidden = false
	for hn: String in ["HookR", "HookL", "HookP"]:
		if m.has_node(hn):
			(m.get_node(hn) as Node3D).visible = false
	if hr != null:
		hr.visible = true
	if hl != null:
		hl.visible = true
	if t >= 0.0 and _plan != null and (state == State.RELOADING or state == State.CLEARING):
		# Recarga o destrabado según el plan: manos, cargador y mano de gancho
		off_l = _path(t, _plan.hand_l)
		rot_l = _path(t, _plan.rot_l)
		off_r = _path(t, _plan.hand_r)
		rot_r = _path(t, _plan.rot_r)
		mag_follow = _path(t, _plan.mag)
		_mag_hidden = ReloadPlan.in_window(t, _plan.mag_hidden)
		if ReloadPlan.in_window(t, _plan.hook_on):
			var hook_name := "HookP" if _plan.pull_part == "Slide" else ("HookR" if _plan.side > 0.0 else "HookL")
			var hook := m.get_node_or_null(hook_name) as Node3D
			var rack_hand := hr if _plan.side > 0.0 else hl
			if hook != null:
				var g := _plan_geo(c)
				var ho := _path(t, _plan.hook)
				# Mientras tira, la mano va pegada a la pieza
				var pb := _plan.pull_back(t)
				if pb > 0.0:
					ho = Vector3(ho.x, ho.y, pb)
				# Compensa el giro del arma: el brazo cuelga hacia abajo
				var hb := Basis(Vector3.BACK, -_reload_roll * 0.85)
				hook.transform = Transform3D(hb, (g["knob"] as Vector3) + ho)
				hook.visible = true
				if rack_hand != null:
					rack_hand.visible = false
		# Estrés: las manos tiemblan al manipular
		var st := player.stress.value
		if st > 0.001:
			var tr3 := player.stress.tremor()
			off_l += Vector3(tr3.z, tr3.x, tr3.y) * 0.0045 * st
			off_r += tr3 * 0.002 * st
			rot_l += Vector3(tr3.y, tr3.z, tr3.x) * 3.5 * st
			if mag_follow.length() > 0.001:
				mag_follow += Vector3(tr3.z, tr3.x, tr3.y) * 0.0045 * st
	elif t >= 0.0 and w.reload_type == "rounds" and hr != null and m.has_node("Ejection"):
		var palm: Vector3 = hr.get_meta("palm", z)
		var port: Vector3 = (m.get_node("Ejection") as Node3D).position + Vector3(0.03, -0.04, 0.025) - palm
		var o := _path(t, [[0.0, z], [0.1, port + Vector3(0.03, -0.04, 0.03)], [0.16, port], [0.86, port],
			[0.94, port * 0.4 + Vector3(0.02, -0.02, 0.02)], [1.0, z]])
		if t > 0.16 and t < 0.86:
			# Empuja cada cartucho hacia abajo
			var per := w.round_time / maxf(state_duration, 0.01)
			var k := fmod(t - 0.16, maxf(per, 0.01)) / maxf(per, 0.01)
			o += Vector3(0, -0.012 * sin(k * PI), 0.004 * sin(k * TAU))
		off_r = o
	elif state == State.CYCLING and hr != null and m.has_node("Bolt"):
		var bolt := m.get_node("Bolt") as Node3D
		if bolt.has_meta("knob"):
			var ct := clampf(state_time / maxf(state_duration, 0.001), 0.0, 1.0)
			var knob: Vector3 = bolt.position + bolt.basis * (bolt.get_meta("knob") as Vector3)
			var tgt := knob + Vector3(0.02, -0.012, 0.006) - (hr.get_meta("palm", z) as Vector3)
			var blend := _smooth(clampf(ct / 0.16, 0.0, 1.0)) * (1.0 - _smooth(clampf((ct - 0.84) / 0.16, 0.0, 1.0)))
			off_r = tgt * blend
	if hr != null and _part_base.has(hr):
		# Con el ojo muy cerca de la mano (escopetas, garganta de culata), al apuntar
		# la mano baja un poco para no tapar la vista
		var eye_z := (m.get_node("Sight") as Node3D).position.z + eye_relief_for(c)
		var near := clampf(0.2 - (eye_z - (hr.get_meta("palm", z) as Vector3).z), 0.0, 0.15)
		off_r += Vector3(0.006, -0.45, 0.12) * near * _smooth(ads_amount)
		var pr: Vector3 = hr.get_meta("palm", z)
		var br := Basis.from_euler(rot_r * (PI / 180.0))
		hr.transform = Transform3D(br, _part_base[hr] + pr - br * pr + off_r)
	if hl != null and _part_base.has(hl):
		var bw := Basis.from_euler(rot_l * (PI / 180.0))
		if pistol:
			var pp: Vector3 = hl.get_meta("palm", z)
			hl.transform = Transform3D(bw, _part_base[hl] + pp - bw * pp + off_l)
		else:
			# Gira sobre el eje del guardamanos al revés que el arma: los dedos siguen
			# agarrando y el brazo cuelga hacia abajo en vez de cruzar la pantalla
			var c0: Vector3 = hl.get_meta("palm", z)
			# Sobre el guardamanos compensa el giro; cuanto más lejos va, menos
			var on_hg := 1.0 - _smooth(clampf(off_l.length() / 0.06, 0.0, 1.0))
			if t >= 0.0 and _plan != null and _plan.side < 0.0 and not _plan.hook_on.is_empty():
				# Yendo a la manija de la izquierda: el brazo sigue colgando hacia abajo
				var w0: Array = _plan.hook_on[0]
				var w1: Array = _plan.hook_on[_plan.hook_on.size() - 1]
				# (al destrabar, desde el principio: la mano va directo a la manija)
				var lead := 1.0 if state == State.CLEARING else 0.14
				on_hg = maxf(on_hg, _smooth(clampf((t - float(w0[0]) + lead) / 0.08, 0.0, 1.0))
					* (1.0 - _smooth(clampf((t - float(w1[1]) - 0.02) / 0.08, 0.0, 1.0))))
			var b := Basis(Vector3.BACK, -_reload_roll * 0.85 * on_hg) * bw
			hl.transform = Transform3D(b, _part_base[hl] + c0 - b * c0 + off_l)
	return mag_follow


func _animate_parts(c: WeaponSlot, delta: float) -> void:
	var w := c.data
	var busy := state == State.RELOADING or state == State.CLEARING
	var t := clampf(state_time / maxf(state_duration, 0.001), 0.0, 1.0) if busy else -1.0
	var m := c.model
	var mag_follow := _animate_hands(c, t)
	_update_stuck_case(c)
	if m.has_node("Mag"):
		var mag := m.get_node("Mag") as Node3D
		mag.position = _part_base[mag] + mag_follow
		mag.visible = not _mag_hidden
	if m.has_node("Charging"):
		var ch := m.get_node("Charging") as Node3D
		var back := 0.0
		if t >= 0.0 and _plan != null and _plan.pull_part == "Charging":
			back = _plan.pull_back(t)
		elif t >= 0.0 and w.reload_type == "rounds":
			back = 0.07 * _smooth(clampf(t / 0.08, 0.0, 1.0)) * (1.0 - _smooth(clampf((t - 0.92) / 0.08, 0.0, 1.0)))
		elif c.malfunction == "double_feed":
			back = 0.012  # el cerrojo no cerró: la manija queda un poco atrás
		ch.position = _part_base[ch] + Vector3(0, 0, back)
	if m.has_node("Slide"):
		var sl := m.get_node("Slide") as Node3D
		_slide_kick = move_toward(_slide_kick, 0.0, delta / 0.07)
		var back := sin(_slide_kick * PI) * 0.032 if _slide_kick > 0.0 else 0.0
		# Corredera atrás: vacía (hasta que entra el cargador y se suelta), o sin montar
		var released := t >= 0.0 and _plan != null and _plan.slide_release >= 0.0 and t > _plan.slide_release
		var locked := (c.mag == 0 and not released) or (c.malfunction == "unchambered" and state != State.CLEARING)
		if locked and _slide_kick <= 0.5 and state != State.CLEARING:
			back = 0.032
		if state == State.CLEARING and _plan != null and _plan.pull_part == "Slide":
			back = _plan.pull_back(t)
			# Sin montar, la corredera estaba atrás: sigue atrás hasta que la suelta
			if c.malfunction == "unchambered" and not _plan.pulls.is_empty() and t < float(_plan.pulls[0][2]):
				back = 0.032
		elif c.malfunction == "double_feed" or c.malfunction == "stovepipe":
			back = maxf(back, 0.01)
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


## Vaina trabada en la ventana ("encasquillada"): se crea la primera vez y se ve
## mientras dure la falla, de pie, apretada por el cerrojo.
func _update_stuck_case(c: WeaponSlot) -> void:
	var m := c.model
	var sc := m.get_node_or_null("StuckCase") as Node3D
	if sc == null:
		if not c.case_stuck or not m.has_node("Ejection"):
			return
		var pistol := c.data.model == "pistol"
		sc = Node3D.new()
		sc.name = "StuckCase"
		m.add_child(sc)
		var r := 0.0045 if pistol else 0.0055
		var l := 0.022 if pistol else 0.042
		WeaponModelBuilder.cyl(sc, "Case", r, l, Vector3.ZERO, WeaponModelBuilder.mat("brass"), 12, Vector3(PI * 0.5, 0, 0), 0.0008)
		sc.position = (m.get_node("Ejection") as Node3D).position + Vector3(0.004, l * 0.42, 0.0)
		sc.rotation = Vector3(0.0, 0.0, deg_to_rad(-48.0))
	sc.visible = c.case_stuck


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
	var inv := br.basis.inverse()
	var z := Vector3.ZERO
	# Recorridos en el espacio del arma (se pasan al de los caños, que están girados)
	var away := Vector3(-0.07, -0.26, 0.04)
	var hand := br.get_node_or_null("HandL") as Node3D
	if hand != null:
		var o := z
		if r:
			o = _path(t, [[0.0, z], [0.03, Vector3(-0.004, -0.01, 0.01)], [0.07, Vector3(-0.03, -0.09, 0.03)], [0.13, away],
				[0.85, away], [0.9, Vector3(-0.035, -0.1, 0.03)], [0.95, Vector3(-0.004, -0.012, 0.01)], [1.0, z]])
		hand.position = _part_base[hand] + inv * o
		hand.visible = not (r and t > 0.13 and t < 0.85)
	var loader := br.get_node_or_null("Loader") as Node3D
	var load_off := z
	if loader != null:
		var behind := br.basis * Vector3(0, 0.004, 0.045)  # alineados detrás de las recámaras
		var seated := br.basis * Vector3(0, 0, -0.024)  # culote al ras de la recámara
		var o := away
		if r and t >= 0.34 and t < 0.78:
			o = _path(t, [[0.34, away], [0.41, Vector3(-0.07, -0.12, 0.05)], [0.47, behind + Vector3(-0.01, 0.004, 0.01)],
				[0.5, behind], [0.6, seated], [0.63, seated], [0.69, Vector3(-0.05, -0.1, 0.06)], [0.78, away]])
		load_off = inv * o
		loader.visible = r and t >= 0.34 and t < 0.78
		loader.position = _part_base[loader] + load_off
	var seat := Vector3(0, 0, -0.024)
	for i in 2:
		var sh := br.get_node("Shell" + ("L" if i == 0 else "R")) as Node3D
		var base: Vector3 = _part_base[sh]
		var spent := i < _break_spent
		sh.rotation = Vector3.ZERO
		if not r:
			sh.visible = false
			sh.position = base + seat
		elif t < 0.34 and spent:
			# Vaina vieja: el extractor la saca un poco al abrir y el expulsor la tira
			# hacia arriba y atrás (a 0.3 sigue como vaina física)
			var ex := 0.03 * _smooth(clampf((t - 0.12) / 0.1, 0.0, 1.0))
			var k := clampf((t - 0.22) / 0.08, 0.0, 1.0)
			var fly := inv * (Vector3((i * 2.0 - 1.0) * 0.035, 0.13, 0.07) * k + Vector3(0, -0.05, 0) * k * k)
			sh.visible = t > 0.1 and t < 0.3
			sh.position = base + seat + Vector3(0, 0, ex) + fly
			sh.rotation = Vector3(-deg_to_rad(220.0) * k, 0, 0)
		elif not spent:
			# Cartucho sin disparar: queda en la recámara (se ve con los caños abiertos)
			sh.visible = t > 0.1 and t < 0.92
			sh.position = base + seat
		else:
			sh.visible = t >= 0.34 and t < 0.92
			# Los cartuchos viajan en la mano hasta que entran; después quedan en la recámara
			sh.position = base + (load_off if (t < 0.6 and loader != null) else seat)


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
	for path: String in ["Mag", "Charging", "Slide", "Bolt", "Barrels/ShellL", "Barrels/ShellR", "Barrels/HandL", "Barrels/Loader",
			"HandR", "HandL", "HookR", "HookL"]:
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
