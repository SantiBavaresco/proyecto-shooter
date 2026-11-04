extends TestCase
## Estrés de combate y fallas del arma: zonas de prueba, recarga bajo estrés,
## olvidarse de montar, fallas por desgaste y destrabado con R.

const LEVEL := preload("res://world/test_greybox/test_greybox.tscn")
const LINE_Z := 30.0

var level: Node3D
var player: Player
var bot: BotInputProvider
var weapons: WeaponController


func before_each() -> void:
	DebugTools.infinite_ammo = false
	level = LEVEL.instantiate()
	add_child(level)
	player = level.get_node("Player")
	bot = BotInputProvider.new()
	player.set_input_provider(bot)
	weapons = player.weapons
	await physics_frames(5)
	CombatWorld.get_for(player).hitstop_enabled = false


func after_each() -> void:
	DebugTools.infinite_ammo = false
	level.queue_free()
	await process_frames(1)


func _equip(id: String) -> WeaponData:
	var d := load("res://data/weapons/%s.tres" % id) as WeaponData
	weapons.equip_weapon(d, 3 if d.slot == 3 else 1)
	bot.select_slot(3 if d.slot == 3 else 1)
	await physics_frames(60)
	return d


func _zone_pos(kind: String) -> Vector3:
	var z := level.find_child("Zone_" + kind, true, false) as Node3D
	return z.global_position + Vector3(0, 0.05, 0)


# --- Modelo de estrés (sin escena) ---------------------------------------------

func test_stress_rises_fast_and_falls_slow() -> void:
	var s := Stress.new()
	s.target = 1.0
	for i in 60:
		s.tick(1.0 / 60.0)
	assert_gt(s.value, 0.5, "en 1 s sube más de la mitad")
	for i in 60:
		s.tick(1.0 / 60.0)
	assert_eq(s.level(), 2)
	s.target = 0.0
	for i in 60:
		s.tick(1.0 / 60.0)
	assert_gt(s.value, 0.7, "baja despacio")
	assert_lt(Stress.new().aim_drift(1.0).length(), 0.000001, "sin estrés no hay deriva")


func test_fault_risk_grows_with_wear() -> void:
	var good := WeaponController.fault_risk(1.0)
	var worn := WeaponController.fault_risk(WeaponController.WORN_CONDITION)
	var sum_good: float = good["misfire"] + good["stovepipe"] + good["double_feed"]
	var sum_worn: float = worn["misfire"] + worn["stovepipe"] + worn["double_feed"]
	assert_lt(sum_good, 0.001, "un arma sana casi no falla")
	assert_gt(sum_worn, 0.025, "un arma gastada falla seguido")
	assert_lt(sum_worn, 0.06, "pero no cada dos tiros")
	var ak := WeaponController.fault_risk(WeaponController.WORN_CONDITION, WeaponController.reliability(load("res://data/weapons/pp19.tres")))
	assert_lt(float(ak["misfire"]) + float(ak["stovepipe"]) + float(ak["double_feed"]), sum_worn * 0.7, "tipo AK: más confiable")


# --- Planes de recarga ----------------------------------------------------------

func _geo_for(id: String) -> Dictionary:
	var d := await _equip(id)
	assert_true(d != null)
	return weapons._plan_geo(weapons.current())


func test_stress_fumbles_are_random_with_a_cap() -> void:
	var geo: Dictionary = await _geo_for("akm")
	var d := weapons.current_data()
	var rng := RandomNumberGenerator.new()
	var seen := {}
	for seed in 40:
		rng.seed = seed
		var calm := ReloadPlan.make("reload", geo, 0, false, rng, d.reload_time, d.reload_time_empty)
		var high := ReloadPlan.make("reload", geo, 2, false, rng, d.reload_time, d.reload_time_empty)
		var extreme := ReloadPlan.make("reload", geo, 3, false, rng, d.reload_time, d.reload_time_empty)
		assert_near(calm.duration, d.reload_time, 0.01, "sin estrés dura lo normal")
		assert_eq(calm.fumbles, 0)
		assert_lt(float(high.fumbles), 3.0, "alto: hasta 3 intentos")
		assert_lt(float(extreme.fumbles), 4.0, "extremo: hasta 4 intentos")
		var r := high.duration / calm.duration
		assert_gt(r, 1.2, "alto: más lenta (%.2f)" % r)
		assert_lt(r, 1.9, "alto: no eterna (%.2f)" % r)
		seen[high.fumbles] = true
	assert_gt(float(seen.size()), 1.0, "no siempre la misma cantidad de intentos")
	# Pistola: hasta 3 intentos aunque sea extremo
	var pg: Dictionary = await _geo_for("pistol")
	var pd := weapons.current_data()
	for seed in 30:
		rng.seed = seed
		var pp := ReloadPlan.make("reload", pg, 3, false, rng, pd.reload_time, pd.reload_time_empty)
		assert_lt(float(pp.fumbles), 3.0, "pistola: hasta 3 intentos")


func test_plan_keys_are_ordered_and_bounded() -> void:
	var geo: Dictionary = await _geo_for("g3")
	var d := weapons.current_data()
	var rng := RandomNumberGenerator.new()
	for act: String in ["reload", "rack", "misfire", "stovepipe", "double_feed"]:
		var p := ReloadPlan.make(act, geo, 2, true, rng, d.reload_time, d.reload_time_empty)
		for arr: Array in [p.hand_l, p.hand_r, p.mag, p.hook]:
			var prev := -1.0
			for k: Array in arr:
				assert_true(float(k[0]) >= prev - 0.0001 and float(k[0]) <= 1.0001, "%s: claves en orden" % act)
				prev = float(k[0])
		if act != "reload":
			assert_false(p.hook_on.is_empty(), "%s: monta con la mano de gancho" % act)


# --- En el juego ------------------------------------------------------------------

func test_zones_set_stress_and_wear() -> void:
	await _equip("akm")
	player.teleport(_zone_pos("stress_high"), PI)
	await physics_frames(150)
	assert_true(player.zone_kinds.has("stress_high"))
	assert_eq(player.stress.level(), 2, "zona de estrés alto")
	player.teleport(_zone_pos("stress_medium"), PI)
	await physics_frames(300)
	assert_eq(player.stress.level(), 1, "zona de estrés medio")
	player.teleport(_zone_pos("stress_extreme"), PI)
	await physics_frames(150)
	assert_eq(player.stress.level(), 3, "zona de estrés extremo")
	assert_gt(player.stress.blur_extra(), 0.9, "extremo: desenfoque máximo")
	player.teleport(_zone_pos("worn"), PI)
	await physics_frames(5)
	assert_lt(weapons.effective_condition(weapons.current()), 0.4, "zona de armas gastadas")


func test_forgot_to_chamber_needs_rack() -> void:
	await _equip("akm")
	var c := weapons.current()
	c.mag = 0
	player.teleport(_zone_pos("stress_high"), PI)
	await physics_frames(150)
	# Forzar el olvido: se reintenta hasta que el plan lo elige (35 % en alto)
	var forgot := false
	for i in 30:
		weapons._rng.seed = i
		bot.press_reload()
		await physics_frames(2)
		if weapons._plan != null and weapons._plan.forgot_chamber:
			forgot = true
			break
		# Cancelar: volver a vaciar y esperar que termine
		await physics_frames(int(weapons.state_duration * 60.0) + 5)
		c.mag = 0
		c.malfunction = ""
	assert_true(forgot, "en estrés alto a veces se olvida de montar")
	await physics_frames(int(weapons.state_duration * 60.0) + 5)
	assert_eq(c.malfunction, "unchambered")
	var before := c.mag
	bot.press_fire()
	await physics_frames(3)
	assert_eq(c.mag, before, "el gatillo hace clic, no dispara")
	bot.press_reload()
	await physics_frames(2)
	assert_eq(weapons.state, WeaponController.State.CLEARING, "R monta")
	await physics_frames(int(weapons.state_duration * 60.0) + 5)
	assert_eq(c.malfunction, "")
	bot.press_fire()
	await physics_frames(3)
	assert_eq(c.mag, before - 1, "ahora dispara")


func test_worn_weapon_jams_and_r_clears_it() -> void:
	DebugTools.infinite_ammo = false
	await _equip("g3")
	player.teleport(_zone_pos("worn") + Vector3(0, 0, 1.0), 0.0)
	await physics_frames(10)
	var c := weapons.current()
	var fault := ""
	for i in 300:
		c.mag = 20
		bot.press_fire()
		await physics_frames(8)
		if c.malfunction != "":
			fault = c.malfunction
			break
	assert_true(fault != "", "un arma muy gastada termina fallando")
	var mag := c.mag
	bot.press_fire()
	await physics_frames(3)
	assert_eq(c.mag, mag, "trabada no dispara")
	bot.press_reload()
	await physics_frames(2)
	assert_eq(weapons.state, WeaponController.State.CLEARING, "R destraba")
	await physics_frames(int(weapons.state_duration * 60.0) + 5)
	assert_eq(c.malfunction, "", "destrabada")
	assert_eq(weapons.state, WeaponController.State.READY)
	if fault == "double_feed":
		assert_eq(c.mag, mag - 1, "doble alimentación: se pierde un cartucho")


func test_bolt_misfire_clears_with_the_bolt() -> void:
	await _equip("rem700")
	var c := weapons.current()
	c.malfunction = "misfire"
	bot.press_reload()
	await physics_frames(2)
	assert_eq(weapons.state, WeaponController.State.CYCLING, "cerrojo: se acciona")
	await physics_frames(int(c.data.cycle_time * 60.0) + 5)
	assert_eq(c.malfunction, "")


# --- Respiración con visor ------------------------------------------------------

## Cuánto se mueve el eje del arma (retícula) en un rato apuntando.
func _sway_range(frames: int) -> float:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for i in frames:
		await process_frames(1)
		var r := weapons.view.aim_rot
		lo = Vector2(minf(lo.x, r.x), minf(lo.y, r.y))
		hi = Vector2(maxf(hi.x, r.x), maxf(hi.y, r.y))
	return (hi - lo).length()


func test_scope_sways_and_holding_breath_steadies_it() -> void:
	await _equip("rem700")
	player.teleport(Vector3(30, 0.05, 31.5), PI)
	bot.aim = true
	await physics_frames(60)
	var free := await _sway_range(150)
	assert_gt(free, deg_to_rad(0.05), "con visor la retícula se mece (%.3f°)" % rad_to_deg(free))
	bot.sprint = true
	await physics_frames(30)
	assert_gt(weapons.breath_hold, 0.9, "Shift con visor: aguanta la respiración")
	assert_false(player.is_sprinting, "no corre")
	var held := await _sway_range(150)
	assert_lt(held, free * 0.35, "aguantando, casi quieta (%.3f° vs %.3f°)" % [rad_to_deg(held), rad_to_deg(free)])
	# Se le acaba el aire
	await physics_frames(int(WeaponController.BREATH_MAX * 60.0))
	assert_gt(weapons.out_of_breath, 0.0, "a los segundos se queda sin aire")
	assert_lt(weapons.breath_hold, 0.5)
	bot.sprint = false
	bot.aim = false


func test_breath_hold_by_stress_level() -> void:
	await _equip("rem700")
	player.teleport(_zone_pos("stress_high"), PI)
	await physics_frames(150)
	bot.aim = true
	bot.sprint = true
	await physics_frames(40)
	assert_gt(weapons.breath_sway_factor(), 0.4, "estrés alto: aguantar ayuda pero no del todo")
	assert_lt(weapons.breath_sway_factor(), 0.6)
	player.teleport(_zone_pos("stress_extreme"), PI)
	bot.sprint = false
	await physics_frames(150)
	bot.sprint = true
	await physics_frames(40)
	assert_lt(weapons.breath_hold, 0.01, "estrés extremo: no se puede aguantar")
	bot.sprint = false
	bot.aim = false


func test_shotgun_reload_feels_stress() -> void:
	var d := await _equip("shotgun")
	var c := weapons.current()
	c.mag = 0
	bot.press_reload()
	await physics_frames(2)
	var calm_dur := weapons.state_duration
	assert_eq(weapons.break_fumbles, 0, "sin estrés no le erra")
	await physics_frames(int(calm_dur * 60.0) + 10)
	assert_eq(c.mag, 2)
	player.teleport(_zone_pos("stress_extreme"), PI)
	await physics_frames(200)
	var seen := {}
	for i in 12:
		c.mag = 0
		c.reserve = 20
		weapons._rng.seed = i
		bot.press_reload()
		await physics_frames(2)
		assert_gt(weapons.state_duration, calm_dur * 1.3, "extremo: más lenta")
		assert_lt(float(weapons.break_fumbles), 4.0, "hasta 4 intentos")
		seen[weapons.break_fumbles] = true
		await physics_frames(int(weapons.state_duration * 60.0) + 10)
		assert_eq(c.mag, 2, "igual termina cargando")
	assert_gt(float(seen.size()), 1.0, "los intentos varían")
	assert_true(d != null)


func test_imported_reload_fumbles_with_stress() -> void:
	var d := await _equip("ak74u")
	var c := weapons.current()
	c.mag = 5
	bot.press_reload()
	await physics_frames(2)
	assert_eq(weapons.imported_fumbles, 0, "sin estrés no le erra al brocal")
	var calm_dur := weapons.state_duration
	await physics_frames(int(calm_dur * 60.0) + 10)
	assert_eq(c.mag, d.mag_size + 1, "carga completa (+1 en la recámara)")
	player.teleport(_zone_pos("stress_extreme"), PI)
	await physics_frames(200)
	var seen := {}
	for i in 10:
		c.mag = 5
		c.reserve = 200
		weapons._rng.seed = i
		bot.press_reload()
		await physics_frames(2)
		var n := weapons.imported_fumbles
		seen[n] = true
		assert_lt(float(n), 4.0, "hasta 3 intentos fallidos")
		if n > 0:
			assert_gt(weapons.state_duration, calm_dur * 1.5, "cada intento alarga la recarga")
			# En la mitad de un intento la animación está detrás del punto donde calza
			var span := ImportedWeapon.fumble_span(d, "reload")
			var seat: Array = (d.model_params["seat"] as Dictionary)["reload"]
			var total := ImportedWeapon.anim_length(c.model, d, "reload") + span * n
			var u := float(seat[1]) + span * 0.5
			var at := ImportedWeapon.reload_anim_time(d, "reload", u, n)
			assert_lt(at.x, float(seat[1]), "vuelve a intentar")
			assert_gt(at.y, -0.5, "fase de intento")
			assert_true(total > 0.0)
		await physics_frames(int(weapons.state_duration * 60.0) + 10)
		assert_eq(c.mag, d.mag_size + 1, "igual termina cargando")
	assert_gt(float(seen.size()), 1.0, "los intentos varían")
