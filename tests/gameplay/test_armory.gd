extends TestCase
## Las 25 armas del catálogo: datos, modelos, apuntado alineado, cerrojo,
## recarga cartucho a cartucho, visor y armería.

const LEVEL := preload("res://world/test_greybox/test_greybox.tscn")

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
	player.teleport(Vector3(30, 0.05, 30), PI)
	await physics_frames(40)


func after_each() -> void:
	DebugTools.infinite_ammo = false
	level.queue_free()
	await process_frames(1)


func _catalog() -> Array:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/weapons/catalog.json"))


func _load(id: String) -> WeaponData:
	return load("res://data/weapons/%s.tres" % id) as WeaponData


func _equip(id: String) -> WeaponData:
	var d := _load(id)
	weapons.equip_weapon(d, 3 if d.slot == 3 else 1)
	bot.select_slot(3 if d.slot == 3 else 1)
	await physics_frames(60)
	return d


func test_catalog_has_26_valid_weapons() -> void:
	var cat := _catalog()
	assert_eq(cat.size(), 32)
	for id: String in cat:
		var d := _load(id)
		assert_true(d != null, "%s carga" % id)
		if d == null:
			continue
		assert_eq(d.id, id)
		assert_true(tr(d.name_key) != d.name_key, "%s tiene nombre" % id)
		assert_true(d.caliber != "", "%s tiene calibre" % id)
		assert_true(SynthSfx.CALIBER_FILES.has(d.caliber), "%s: hay disparo para su calibre" % id)
		var shot := SynthSfx.weapon_shot(d)
		assert_true(shot is AudioStreamRandomizer, "%s: usa el archivo del calibre" % id)
		if shot is AudioStreamRandomizer:
			var r := shot as AudioStreamRandomizer
			assert_eq(r.streams_count, 3, "%s: 3 variantes" % id)
			for i in r.streams_count:
				var st := r.get_stream(i)
				# (un archivo LFS sin bajar es un texto de 130 bytes: no carga como audio)
				assert_true(st != null and st.get_length() > 0.2, "%s: variante %d es audio de verdad" % [id, i])
		assert_lt(d.spread_ads, d.spread_hip, "%s: apuntar es más preciso" % id)
		assert_true(d.reload_type in ["magazine", "break", "rounds", "cylinder"], "%s: tipo de recarga válido" % id)
		if d.sight == "scope":
			assert_gt(d.scope_mag, 1.0, "%s: visor con aumento" % id)


func test_every_model_has_markers() -> void:
	for id: String in _catalog():
		var d := _load(id)
		var m := WeaponModelBuilder.build(d)
		if m.has_meta("imported"):
			# Importada: los marcadores salen del hueso del arma (necesita estar en el árbol)
			add_child(m)
			await process_frames(2)
			ImportedWeapon.sync_markers(m)
			remove_child(m)
		for marker in ["Sight", "Muzzle", "Ejection"]:
			assert_true(m.has_node(marker), "%s tiene %s" % [id, marker])
		if d.sight == "scope":
			assert_true(m.has_node("ScopeLens"), "%s tiene ocular" % id)
		if d.bolt_action:
			assert_true(m.has_node("Bolt"), "%s tiene cerrojo" % id)
		if d.reload_type == "break":
			assert_true(m.has_node("Barrels"), "%s se quiebra" % id)
		var muzzle := m.get_node("Muzzle") as Node3D
		assert_lt(muzzle.position.z, -0.1, "%s: la boca está adelante" % id)
		m.free()


func test_every_weapon_aims_through_its_sight() -> void:
	for id: String in _catalog():
		bot.aim = false
		await physics_frames(20)
		await _equip(id)
		bot.aim = true
		await physics_frames(int(weapons.current_data().ads_time * 60.0) + 15)
		await process_frames(25)
		var s := weapons.sight_node().global_position
		assert_near(s.x, 0.0, 0.004, "%s: mira centrada en X" % id)
		assert_near(s.y, 0.0, 0.004, "%s: mira centrada en Y" % id)
		assert_lt(s.z, -0.03, "%s: la mira está delante del ojo" % id)
	bot.aim = false


func test_bolt_action_needs_cycling() -> void:
	var d := await _equip("rem700")
	bot.press_fire()
	await physics_frames(2)
	assert_eq(weapons.current().mag, d.mag_size - 1)
	assert_eq(weapons.state, WeaponController.State.CYCLING, "después del tiro se acciona el cerrojo")
	bot.press_fire()
	await physics_frames(2)
	assert_eq(weapons.current().mag, d.mag_size - 1, "no dispara con el cerrojo abierto")
	await physics_frames(int(d.cycle_time * 60.0) + 3)
	assert_eq(weapons.state, WeaponController.State.READY)
	bot.press_fire()
	await physics_frames(2)
	assert_eq(weapons.current().mag, d.mag_size - 2)


func test_round_by_round_and_clip_reload() -> void:
	var d := await _equip("mauser1909")
	# Dos tiros y recarga parcial: cartucho a cartucho
	for i in 2:
		bot.press_fire()
		await physics_frames(int(d.cycle_time * 60.0) + 5)
	var c := weapons.current()
	assert_eq(c.mag, 3)
	assert_near(weapons.reload_duration(c), d.reload_time + 2.0 * d.round_time, 0.001)
	# Vacía: peine completo
	c.mag = 0
	assert_near(weapons.reload_duration(c), d.reload_time_empty, 0.001)
	bot.press_reload()
	await physics_frames(int(d.reload_time_empty * 60.0) + 5)
	assert_eq(c.mag, 5)


func test_sks_always_loads_a_clip() -> void:
	var d := await _equip("sks")
	var c := weapons.current()
	c.mag = 6
	assert_near(weapons.reload_duration(c), d.reload_time_empty, 0.001, "SK-45: peine aunque no esté vacía")
	bot.press_reload()
	await physics_frames(int(d.reload_time_empty * 60.0) + 10)
	assert_eq(c.mag, d.mag_size)


func test_bolt_misfire_and_stuck_case_clear_with_the_bolt() -> void:
	await _equip("rem700")
	var c := weapons.current()
	c.mag = 4
	c.malfunction = "misfire"
	bot.press_reload()
	await physics_frames(int(c.data.cycle_time * 1.7 * 60.0) + 5)
	assert_eq(c.malfunction, "")
	assert_eq(c.mag, 3, "el cartucho que no disparó sale y se descuenta")
	c.malfunction = "stovepipe"
	bot.press_fire()
	await physics_frames(3)
	assert_eq(c.mag, 3, "vaina trabada: no dispara")
	bot.press_reload()
	await physics_frames(int(c.data.cycle_time * 1.7 * 60.0) + 5)
	assert_eq(c.malfunction, "", "forzar el cerrojo la saca")


func test_bolt_rounds_count_up_and_fire_interrupts() -> void:
	var d := await _equip("rem700")
	var c := weapons.current()
	c.mag = 0
	c.reserve = 20
	bot.press_reload()
	await physics_frames(2)
	var dur := weapons.state_duration
	var seen: Array[int] = []
	for i in int(dur * 60.0 * 0.6):
		await physics_frames(1)
		if seen.is_empty() or seen[seen.size() - 1] != c.mag:
			seen.append(c.mag)
	assert_gt(float(seen.size()), 2.0, "el contador sube de a uno (%s)" % str(seen))
	var loaded := c.mag
	assert_gt(float(loaded), 0.0)
	assert_lt(float(loaded), float(d.mag_size), "todavía no terminó")
	# Gatillo: corta la recarga, cierra el cerrojo y queda listo con lo que entró
	bot.press_fire()
	await physics_frames(int(dur * 60.0 * 0.12) + 10)
	assert_eq(weapons.state, WeaponController.State.READY, "cortó la recarga")
	assert_eq(c.mag, loaded, "con los cartuchos que ya había metido")
	assert_eq(c.reserve, 20 - loaded)
	bot.press_fire()
	await physics_frames(3)
	assert_eq(c.mag, loaded - 1, "y dispara")


func test_scope_magnifies() -> void:
	var d := await _equip("svd")
	bot.aim = true
	await physics_frames(40)
	await process_frames(10)
	var main_fov := player.camera.fov
	var scope_fov := weapons.scope_camera().fov
	assert_lt(scope_fov, 20.0, "el visor muestra un campo chico")
	assert_eq(weapons.viewmodel_viewport() != null, true)
	assert_lt(weapons.look_mult(), 0.7, "la sensibilidad baja con el visor")
	assert_near(player.camera.fov, Settings.get_value("video", "fov"), 1.0, "visor: la vista de afuera no hace zoom")
	assert_gt(main_fov, scope_fov * 3.0)
	bot.aim = false
	assert_true(d != null)


func test_sawed_off_break_reload() -> void:
	var d := await _equip("sawedoff")
	for i in 2:
		bot.press_fire()
		await physics_frames(14)
	assert_eq(weapons.current().mag, 0)
	bot.press_reload()
	await physics_frames(int(d.reload_time_empty * 60.0) + 5)
	assert_eq(weapons.current().mag, 2)


func test_armory_table_equips_weapon() -> void:
	var table := level.get_node("Geometry/Table_ak74") as Node3D
	player.teleport(table.global_position + Vector3(0, 0.05, 1.3), 0.0)
	await physics_frames(5)
	var eye := player.camera.global_position
	var target := table.global_position + Vector3(0, 0.9, 0)
	var dv := target - eye
	player.yaw = atan2(-dv.x, -dv.z)
	player.pitch_angle = atan2(dv.y, Vector2(dv.x, dv.z).length())
	await physics_frames(3)
	bot.press_interact()
	await physics_frames(60)
	assert_eq(weapons.current().data.id, "ak74", "la AR-74 quedó en la mano")
	assert_eq(weapons.current_slot, 1)


func test_bolt_keeps_scope_while_fire_held() -> void:
	var d := await _equip("rem700")
	bot.aim = true
	await physics_frames(int(d.ads_time * 60.0) + 10)
	assert_true(weapons.aiming)
	bot.fire = true
	await physics_frames(3)
	assert_eq(weapons.state, WeaponController.State.CYCLING)
	await physics_frames(int(d.cycle_time * 30.0))
	assert_true(weapons.aiming, "con el gatillo apretado acciona el cerrojo sin dejar el visor")
	assert_gt(weapons.ads_amount, 0.95)
	await physics_frames(int(d.cycle_time * 30.0) + 6)
	assert_eq(weapons.state, WeaponController.State.READY)
	assert_true(weapons.aiming)
	assert_eq(weapons.current().mag, d.mag_size - 1, "mantener el gatillo no vuelve a disparar")
	bot.fire = false
	await physics_frames(2)
	bot.press_fire()
	await physics_frames(2)
	assert_eq(weapons.current().mag, d.mag_size - 2, "soltar y apretar dispara el siguiente")
	bot.aim = false


func test_bolt_leaves_scope_when_fire_released() -> void:
	var d := await _equip("rem700")
	bot.aim = true
	await physics_frames(int(d.ads_time * 60.0) + 10)
	bot.press_fire()
	await physics_frames(6)
	assert_eq(weapons.state, WeaponController.State.CYCLING)
	assert_false(weapons.aiming, "gatillo suelto: saca el ojo del visor para accionar")
	await physics_frames(int((d.cycle_time + d.ads_time) * 60.0) + 10)
	assert_true(weapons.aiming, "y vuelve a apuntar al terminar")
	bot.aim = false


func test_variable_scope_zoom_with_wheel() -> void:
	var d := await _equip("rem700")
	var c := weapons.current()
	assert_true(WeaponController.has_variable_zoom(d))
	assert_near(weapons.scope_mag(c), 5.0, 0.01)
	bot.press_zoom(2)
	await physics_frames(3)
	assert_near(weapons.scope_mag(c), 5.0, 0.01, "sin apuntar la rueda no cambia el aumento")
	bot.aim = true
	await physics_frames(int(d.ads_time * 60.0) + 15)
	await process_frames(5)
	var fov_low := weapons.scope_camera().fov
	var look_low := weapons.look_mult()
	bot.press_zoom(3)
	await physics_frames(3)
	assert_near(weapons.scope_mag(c), 5.0 * pow(WeaponController.ZOOM_STEP, 3), 0.05)
	bot.press_zoom(30)
	await physics_frames(3)
	assert_near(weapons.scope_mag(c), 25.0, 0.01, "tope de 25×")
	await process_frames(5)
	assert_lt(weapons.scope_camera().fov, fov_low / 4.5, "a 25× el campo es 5 veces más chico que a 5×")
	assert_lt(weapons.look_mult(), look_low, "más aumento, mouse más fino")
	assert_eq(weapons.get_state_dict()["zoom"], 25.0)
	bot.press_zoom(-50)
	await physics_frames(3)
	assert_near(weapons.scope_mag(c), 5.0, 0.01, "mínimo de 5×")
	bot.aim = false
	# Los visores fijos no cambian
	var s := await _equip("svd")
	bot.aim = true
	await physics_frames(int(s.ads_time * 60.0) + 10)
	bot.press_zoom(3)
	await physics_frames(3)
	assert_near(weapons.scope_mag(weapons.current()), 4.0, 0.01)
	bot.aim = false


# --- Modelos .glb (F1.23) --------------------------------------------------------

func test_glb_models_have_parts_and_hands() -> void:
	for id: String in _catalog():
		var d := _load(id)
		if String(d.model_params.get("shape", "")) != "glb":
			continue
		var m := WeaponModelBuilder.build(d)
		for n in ["Sight", "Muzzle", "Ejection", "HandR"]:
			assert_true(m.has_node(n), "%s: tiene %s" % [id, n])
		assert_true((m.get_node("HandR") as Node3D).has_meta("trigger"), "%s: mano con gatillo" % id)
		if d.reload_type == "magazine":
			assert_true(m.has_node("Mag"), "%s: cargador aparte" % id)
			assert_gt(float((m.get_node("Mag") as Node3D).get_child_count()), 0.0, "%s: el cargador tiene malla" % id)
		if d.sight == "scope":
			assert_true(m.has_node("ScopeLens"), "%s: ocular del visor" % id)
		var meshes := m.find_children("*", "MeshInstance3D", true, false)
		assert_gt(float(meshes.size()), 1.0, "%s: tiene mallas" % id)
		m.free()


func test_vk19_is_procedural_with_holo() -> void:
	var d := _load("vityaz")
	assert_eq(String(d.model_params.get("shape", "")), "vityaz")
	var m := WeaponModelBuilder.build(d)
	assert_true(m.has_node("Lens"), "vidrio de la holográfica")
	var lm := (m.get_node("Lens") as MeshInstance3D).material_override as ShaderMaterial
	assert_true(bool(lm.get_shader_parameter("holo")), "retícula holográfica")
	var sight := (m.get_node("Sight") as Node3D).position
	var muzzle := (m.get_node("Muzzle") as Node3D).position
	assert_true(absf(sight.x) < 0.001 and absf(muzzle.x) < 0.001, "mira y boca sobre el eje")
	assert_gt(sight.y, 0.06, "la ventana queda por encima del alza y del guion")
	assert_true(m.has_node("Mag") and m.has_node("Charging"), "cargador y manija animables")
	m.free()


func test_revolver_reloads_all_at_once() -> void:
	var d := await _equip("revolver45")
	var c := weapons.current()
	c.mag = 1
	c.reserve = 20
	bot.press_reload()
	await physics_frames(2)
	assert_eq(int(weapons.state), int(WeaponController.State.RELOADING))
	var dur := weapons.state_duration
	await physics_frames(int(dur * 60.0 * 0.5))
	assert_eq(c.mag, 1, "a mitad de la recarga todavía no entraron")
	await physics_frames(int(dur * 60.0 * 0.5) + 10)
	assert_eq(c.mag, d.mag_size, "entran todos juntos")
	assert_eq(c.reserve, 15)


func test_npc_falls_stiff_and_gets_up() -> void:
	var npc := level.find_child("Npc_fsb", true, false) as NpcDummy
	assert_true(npc != null, "hay personajes de prueba")
	var info := HitInfo.new()
	info.damage = 150.0
	info.zone = "torso"
	info.direction = Vector3(0, 0, 1)
	info.position = npc.global_position + Vector3(0, 1.3, 0)
	assert_true(npc.apply_hit(info), "muere")
	await process_frames(90)
	assert_gt(npc._ang, 1.4, "queda en el piso (como una tabla)")
	await get_tree().create_timer(NpcDummy.RESPAWN_TIME + 1.5).timeout
	assert_lt(npc._ang, 0.05, "se vuelve a parar")
	assert_false(npc.down)
