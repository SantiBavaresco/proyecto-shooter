class_name WeaponController
extends Node
## Armas del jugador: la lógica (tick de física): estados, disparo, recarga, fallas,
## munición e interacción. La vista en primera persona (modelo, manos, animaciones,
## visor) está en WeaponViewmodel, que solo lee este estado.

enum State { READY, RELOADING, HOLSTER, DRAW, CYCLING, CLEARING }

const WEAPON_FILES: Dictionary = {
	1: "res://data/weapons/rifle.tres",
	2: "res://data/weapons/shotgun.tres",
	3: "res://data/weapons/pistol.tres",
}
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
## Aguantar la respiración: segundos de aire, castigo al quedarse sin aire.
const BREATH_MAX := 5.0
const BREATH_PENALTY := 3.0
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
## Plan de la recarga o del destrabado en curso (armas con cargador o manija).
var _plan: ReloadPlan = null
var _plan_ev: int = 0
## Acción de destrabado en curso (para aplicar su efecto al terminar).
var _clear_action: String = ""
## Carga cartucho a cartucho: cuántos se van a meter, cuántos entraron y si se cortó
## (disparando) para cerrar el cerrojo con lo que ya hay.
var _rounds_planned: int = 0
var _rounds_done: int = 0
var _rounds_stop: bool = false
var _clip_load: bool = false
## Aguantar la respiración (Shift con visor): cuánto lo está haciendo (0..1), aire que
## le queda (s) y castigo por quedarse sin aire (s).
var breath_hold: float = 0.0
var breath_left: float = BREATH_MAX
var out_of_breath: float = 0.0
var _cooldown: float = 0.0
var _sprint_block: float = 0.0
var _hint_target: Node = null
var _rng := RandomNumberGenerator.new()
## Vista en primera persona (modelo, manos, animaciones, visor).
var view: WeaponViewmodel

var _audio_shot: AudioStreamPlayer
var _audio_mech: AudioStreamPlayer
var _cycle_fx_done: bool = false


func setup(p: Player) -> void:
	player = p
	_rng.randomize()
	_build_audio()
	view = WeaponViewmodel.new()
	view.name = "Viewmodel"
	view.wc = self
	add_child(view)
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
	view.add_model(ws.model)
	return ws


## Pone un arma en un slot (reemplaza la que había) y la saca.
func equip_weapon(data: WeaponData, slot: int) -> void:
	if slots.has(slot):
		var old := slots[slot] as WeaponSlot
		view.remove_model(old.model)
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
	return lerpf(1.0, d.ads_fov_mult, WeaponViewmodel.smooth(ads_amount))


## Multiplicador de sensibilidad del mouse (más fino mirando por un visor).
func look_mult() -> float:
	var c := current()
	if c == null or c.data.scope_mag <= 1.0:
		return 1.0
	return lerpf(1.0, 1.0 / sqrt(scope_mag(c)), WeaponViewmodel.smooth(ads_amount))


## Aumento del visor en uso (variable o fijo).
func scope_mag(c: WeaponSlot) -> float:
	return clampf(c.zoom, c.data.scope_mag, c.data.scope_mag_max) if has_variable_zoom(c.data) else c.data.scope_mag


static func has_variable_zoom(d: WeaponData) -> bool:
	return d.scope_mag > 1.0 and d.scope_mag_max > d.scope_mag


func scope_camera() -> Camera3D:
	return view.scope_cam


func eye_relief_for(c: WeaponSlot) -> float:
	if c.data.eye_relief > 0.0:
		return c.data.eye_relief
	var s := c.model.get_node("Sight")
	return s.get_meta("eye_relief", 0.2) if s.has_meta("eye_relief") else 0.2


func viewmodel_camera() -> Camera3D:
	return view.vm_camera


func viewmodel_viewport() -> SubViewport:
	return view.vm_viewport


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

	# Cartucho a cartucho: el gatillo corta la carga y se puede tirar con lo que entró
	if state == State.RELOADING and c.data.reload_type == "rounds" and cmd.fire_pressed and c.mag > 0 \
			and not _rounds_stop and state_time < state_duration * 0.9:
		_stop_loading_rounds()

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

	_update_breath(cmd, delta)
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
	if state == State.RELOADING and c.data.reload_type == "rounds":
		_load_rounds(c)
	if state == State.RELOADING:
		# Escopeta: expulsa las vainas al quebrarse
		if c.data.reload_type == "break" and not _reload_fx_done and state_time >= state_duration * 0.25:
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
		dur *= [1.0, 1.15, 1.45, 1.65][player.stress.level()]
	_plan_ev = 0
	_rounds_done = 0
	_rounds_stop = false
	_clip_load = c.data.reload_type == "rounds" and c.mag == 0 and c.data.clip_reload
	var needed := c.data.mag_size - c.mag
	_rounds_planned = needed if DebugTools.infinite_ammo else mini(needed, c.reserve)
	_set_state(State.RELOADING, dur)
	_play_mech(SynthSfx.click("reload_out", 0.6, 0.08), -6.0)
	_emit_state()


## Cartucho a cartucho: cada uno entra cuando la mano lo empuja (el contador sube de a
## uno). Con peine (vacía), entran todos juntos a mitad de la recarga.
func _load_rounds(c: WeaponSlot) -> void:
	if _rounds_stop or _rounds_done >= _rounds_planned:
		return
	var t := state_time / maxf(state_duration, 0.001)
	var due := _rounds_planned if (_clip_load and t >= 0.55) else 0
	if not _clip_load:
		while due < _rounds_planned and t >= 0.16 + 0.7 * (float(due) + 0.5) / float(_rounds_planned):
			due += 1
	while _rounds_done < due:
		_rounds_done += 1
		c.mag += 1
		if not DebugTools.infinite_ammo:
			c.reserve -= 1
		_play_mech(SynthSfx.click("round_in", 1.15, 0.03), -9.0)
		_emit_state()


## Cortar la carga cartucho a cartucho (gatillo): cierra el cerrojo con lo que ya entró.
func _stop_loading_rounds() -> void:
	_rounds_stop = true
	state_time = maxf(state_time, state_duration * 0.9)


## Destrabar (R con una falla): cerrojo → accionarlo; con manija o corredera → el
## plan de la falla (golpe al cargador, montar, sacar el cargador...).
func _start_clear(c: WeaponSlot) -> void:
	_clear_action = c.malfunction
	_reload_empty = false
	if c.data.bolt_action:
		_cycle_fx_done = false
		_set_state(State.CYCLING, c.data.cycle_time * [1.0, 1.15, 1.4, 1.6][player.stress.level()])
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
		g["mag_base"] = view.part_base[mag]
		g["grab"] = mag.get_meta("grab", Vector3(0, -0.05, 0.0))
	if m.has_node("Charging") and not g["pistol"]:
		var ch := m.get_node("Charging") as Node3D
		var kn: Vector3 = view.part_base[ch] + (ch.get_meta("knob", z) as Vector3)
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
	if c.data.reload_type == "rounds":
		_load_rounds(c)  # los que faltaban por tiempo (los cartuchos ya entraron de a uno)
	else:
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
		view.kick_rot.x += deg_to_rad(0.6)
		_emit_state()
		return
	if not DebugTools.infinite_ammo:
		c.mag -= 1
	c.shots += 1
	_cooldown = maxf(w.seconds_per_shot(), DOUBLE_BARREL_GAP if w.reload_type == "break" else 0.0)

	var cam := player.camera
	var origin := cam.global_position
	# Apuntando, la bala sale por el eje del arma (respiración y pulso incluidos):
	# donde está la retícula, no el centro fijo de la pantalla
	var basis := cam.global_basis * Basis.from_euler(view.aim_rot)
	var fwd := -basis.z
	var spread := lerpf(w.spread_hip * player.stress.hip_spread_mult(), w.spread_ads, WeaponViewmodel.smooth(ads_amount)) * _spread_factor(w)
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
	view.kick(w, ads_amount, _rng.randf_range(-1.5, 1.5))

	view.flash()
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


## Aguantar la respiración (Shift) mirando por un visor. Dura unos segundos (menos con
## estrés alto); si se agota, el pulso empeora un rato. En estrés extremo no se puede.
func _update_breath(cmd: PlayerCommand, delta: float) -> void:
	var c := current()
	var scoped := aiming and c != null and c.data.sight == "scope"
	var lvl := player.stress.level()
	var max_air := BREATH_MAX * (0.6 if lvl == 2 else 1.0)
	var want := cmd.sprint and scoped and lvl < 3 and out_of_breath <= 0.0 and breath_left > 0.0
	if want:
		breath_left -= delta
		if breath_left <= 0.0:
			breath_left = 0.0
			out_of_breath = BREATH_PENALTY
			want = false
	else:
		out_of_breath = maxf(0.0, out_of_breath - delta)
		if not cmd.sprint or not scoped:
			breath_left = minf(max_air, breath_left + delta * 1.2)
	breath_left = minf(breath_left, max_air)
	breath_hold = move_toward(breath_hold, 1.0 if want else 0.0, delta / 0.35)


## Multiplicador del balanceo con visor: aguantando, casi quieto (en estrés alto la mitad);
## sin aire, peor.
func breath_sway_factor() -> float:
	var calm := 0.12 if player.stress.level() < 2 else 0.5
	var f := lerpf(1.0, calm, breath_hold)
	return f * (1.0 + 1.2 * clampf(out_of_breath / BREATH_PENALTY, 0.0, 1.0))


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
	var vel := cam.basis * (Vector3(1.6, 1.4, 0.4) if not shotgun_shell else Vector3(-0.25 + index * 0.5, 3.6, 0.35))
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


# --- Sonido y utilidades ---------------------------------------------------------

## Convierte un punto del mundo del arma (espacio de cámara) al mundo del juego.
func _vm_to_world(p: Vector3) -> Vector3:
	return player.camera.global_transform * p


func _play_mech(stream: AudioStream, volume_db: float) -> void:
	_audio_mech.stream = stream
	_audio_mech.volume_db = volume_db
	_audio_mech.play()


func _build_audio() -> void:
	_audio_shot = AudioStreamPlayer.new()
	_audio_shot.bus = "SFX_World"
	_audio_shot.max_polyphony = 6
	add_child(_audio_shot)
	_audio_mech = AudioStreamPlayer.new()
	_audio_mech.bus = "SFX_World"
	_audio_mech.max_polyphony = 3
	add_child(_audio_mech)
