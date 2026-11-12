extends TestCase
## F3: enemigos con IA (vista, oído, combate, dificultades), blindaje, granadas,
## cuchillo, muerte del jugador (cuerpo con el equipo y vuelta al campamento) y miras
## desmontables nuevas.

const PLAYER := preload("res://entities/player/player.tscn")
const LEVEL := preload("res://world/test_greybox/test_greybox.tscn")

var level: Node3D
var player: Player
var bot: BotInputProvider
var geo: Node3D


## Arena chica: piso, una pared y la malla de navegación.
func _arena(wall := false) -> void:
	level = Node3D.new()
	level.name = "Arena"
	add_child(level)
	geo = Node3D.new()
	geo.add_to_group(NavUtil.GROUP)
	level.add_child(geo)
	_box(Vector3(0, -0.5, 0), Vector3(160, 1, 160))
	if wall:
		_box(Vector3(0, 1.5, -8), Vector3(12, 3, 0.6))
	# Algunas coberturas bajas
	for x: float in [-6.0, 6.0]:
		_box(Vector3(x, 0.5, -20), Vector3(2, 1, 0.6))
	var sun := DirectionalLight3D.new()
	level.add_child(sun)
	NavUtil.bake(level, AABB(Vector3(-80, -2, -80), Vector3(160, 8, 160)), false, 0.3)
	player = PLAYER.instantiate() as Player
	level.add_child(player)
	bot = BotInputProvider.new()
	player.set_input_provider(bot)
	await physics_frames(5)
	CombatWorld.get_for(player).hitstop_enabled = false
	player.teleport(Vector3(0, 0.05, 0), 0.0)
	await physics_frames(10)


func _box(pos: Vector3, size: Vector3) -> void:
	var b := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	b.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	b.add_child(mi)
	b.position = pos
	geo.add_child(b)


func _npc(pos: Vector3, yaw: float, loadout := "bandit_rifle", diff := 1, weapon := "akm") -> HumanNpc:
	var n := HumanNpc.new()
	n.loadout_id = loadout
	n.difficulty_override = diff
	n.weapon_id = weapon
	n.seed_value = 1234
	n.position = pos
	n.rotation = Vector3(0, yaw, 0)
	level.add_child(n)
	return n


func before_each() -> void:
	DebugTools.god_mode = true


func after_each() -> void:
	DebugTools.god_mode = false
	GameState.difficulty = 1
	if level != null:
		level.queue_free()
		level = null
	await process_frames(2)


## Mira hacia +Z (hacia el jugador en el origen) desde −Z.
const FACE_SOUTH := PI


func test_npc_sees_player_in_the_open() -> void:
	await _arena()
	var n := _npc(Vector3(0, 0, -25), FACE_SOUTH)
	n.mag = 0
	n.spare_mags.clear()
	await physics_frames(60 * 3)
	assert_eq(n.brain.state, NpcBrain.State.COMBAT, "a 25 m de frente, a plena vista, lo ve")
	assert_true(n.brain.target_visible)


func test_npc_cannot_see_through_walls() -> void:
	await _arena(true)
	var n := _npc(Vector3(0, 0, -16), FACE_SOUTH)
	await physics_frames(60 * 3)
	assert_true(n.brain.state != NpcBrain.State.COMBAT, "con una pared en el medio no lo ve")
	assert_lt(n.brain.awareness, 0.3)


func test_crouched_far_player_is_harder_to_spot() -> void:
	await _arena()
	var n := _npc(Vector3(0, 0, -40), FACE_SOUTH, "bandit_rifle", 0)
	bot.crouch = true
	await physics_frames(60 * 2)
	assert_true(n.brain.state != NpcBrain.State.COMBAT, "un novato no ve a alguien agachado a 40 m")


func test_npc_hears_gunshot_but_not_suppressed_far() -> void:
	await _arena()
	# De espaldas, a 70 m
	var n := _npc(Vector3(0, 0, -70), 0.0)
	await physics_frames(20)
	EventBus.noise_emitted.emit(player.global_position, HumanNpc.SHOT_HEAR_SUPPRESSED, player)
	await physics_frames(20)
	assert_true(n.brain.state in [NpcBrain.State.IDLE, NpcBrain.State.PATROL], "el disparo con silenciador no se oye a 70 m")
	EventBus.noise_emitted.emit(player.global_position, HumanNpc.SHOT_HEAR, player)
	await physics_frames(20)
	assert_true(n.brain.state in [NpcBrain.State.COMBAT, NpcBrain.State.INVESTIGATE], "el disparo normal sí")


func test_npc_shoots_and_hurts_player() -> void:
	await _arena()
	var n := _npc(Vector3(0, 0, -20), FACE_SOUTH, "bandit_rifle", 2)
	DebugTools.god_mode = false
	var hits := [0]
	EventBus.player_hit_from.connect(func(_o: Vector3) -> void: hits[0] += 1)
	for i in 60 * 8:
		await physics_frames(1)
		if hits[0] > 0:
			break
	assert_gt(hits[0], 0, "un veterano a 20 m le pega")
	assert_lt(player.vitals.health, 100.0)
	assert_lt(n.mag, n._capacity(), "gastó balas")


func test_npc_dies_and_body_is_lootable() -> void:
	await _arena()
	var n := _npc(Vector3(0, 0, -6), FACE_SOUTH)
	await physics_frames(10)
	var info := HitInfo.new()
	info.damage = 500.0
	info.zone = "head_core"
	info.direction = Vector3(0, 0, -1)
	info.position = n.global_position + Vector3(0, 1.6, 0)
	info.source = player
	var killed := n.apply_hit(info)
	assert_true(killed)
	assert_true(n.dead)
	await physics_frames(60)
	assert_true(n.get_interact_text() != "", "se puede revisar")
	assert_eq(n.inventory.count_of("w_akm"), 1, "el arma queda en el cuerpo")
	assert_gt(n.inventory.count_of(ItemDB.standard_mag("akm")), 0, "y los cargadores")
	assert_false(n.is_in_group("ai_npc"))


func test_player_bullet_kills_npc_through_hitboxes() -> void:
	await _arena()
	var n := _npc(Vector3(0, 0, -8), 0.0)
	await physics_frames(30)
	var cw := CombatWorld.get_for(player)
	var w := load("res://data/weapons/g3.tres") as WeaponData
	var from := player.camera.global_position
	for i in 6:
		var to := n.body.chest_position()
		cw.fire_projectile(from, (to - from).normalized(), w, player, [player.get_rid()])
		await physics_frames(6)
		if n.dead:
			break
	assert_true(n.dead, "unos tiros de G3 al pecho lo matan")


func test_armor_classes() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	assert_lt(Armor.penetration_chance(0.3, 4, 1.0), 0.05, "un chaleco clase 4 frena una pistola")
	assert_gt(Armor.penetration_chance(1.66, 2, 1.0), 0.95, "un clase 2 no frena un 7,62×54R")
	assert_gt(Armor.penetration_chance(1.0, 4, 0.2), Armor.penetration_chance(1.0, 4, 1.0), "gastado frena menos")
	var stopped := 0
	var dmg := 0.0
	for i in 200:
		var r := Armor.resolve(40.0, 0.3, "torso", 4, 1.0, rng)
		if r.covered and not r.penetrated:
			stopped += 1
		dmg += r.damage
	assert_gt(stopped, 140, "casi siempre la frena (si la tapa)")
	assert_lt(dmg / 200.0, 15.0, "y pasa poco daño")


func test_player_vest_reduces_damage() -> void:
	await _arena()
	DebugTools.god_mode = false
	var avg := [0.0, 0.0]
	var min_cond := 1.0
	for k in 2:
		if k == 1:
			player.inventory._set_equipped("armor", ItemStack.make("vest_plate"))
		var total := 0.0
		for i in 30:
			if k == 1:
				(player.inventory.equipment["armor"] as ItemStack).state["condition"] = 1.0
			player.vitals.reset()
			player.is_dead = false
			var info := HitInfo.new()
			info.damage = 42.0
			info.penetration = 1.0
			info.zone = "torso"
			info.direction = Vector3(0, 0, 1)
			info.position = player.global_position + Vector3(0, 1.2, 0)
			player.apply_hit(info)
			total += 100.0 - player.vitals.health
			if k == 1:
				min_cond = minf(min_cond, float((player.inventory.equipment["armor"] as ItemStack).state["condition"]))
		avg[k] = total / 30.0
	assert_gt(avg[0], 35.0)
	assert_lt(avg[1], avg[0] * 0.6, "con placas, un tiro de AK hace mucho menos")
	# El chaleco cubre el 85 % del torso: algún tiro lo gasta, de a poco
	assert_lt(min_cond, 1.0, "y el chaleco se gasta")
	assert_gt(min_cond, 0.9, "de a poco")


func test_player_head_hit_zones() -> void:
	await _arena()
	var head := player.camera.global_position
	assert_eq(player.hit_zone(head + Vector3(0, 0, 0.3), Vector3(0, 0, -1)), "head_core")
	assert_eq(player.hit_zone(player.global_position + Vector3(0, 1.2, 0.3), Vector3(0, 0, -1)), "torso")
	assert_eq(player.hit_zone(player.global_position + Vector3(0.28, 1.2, 0.1), Vector3(0, 0, -1)), "limb", "brazo")
	assert_eq(player.hit_zone(player.global_position + Vector3(0, 0.4, 0.3), Vector3(0, 0, -1)), "limb")


func test_grenade_kills_nearby_npc_not_behind_wall() -> void:
	await _arena(true)
	var a := _npc(Vector3(2, 0, -4), 0.0)
	var b := _npc(Vector3(0, 0, -11), 0.0)  # detrás de la pared (z = −8)
	await physics_frames(10)
	var g := Grenade.make(player)
	level.add_child(g)
	g.global_position = Vector3(1.5, 0.2, -3.5)
	g.fuse = 0.1
	await physics_frames(30)
	assert_true(a.dead, "al lado de la granada muere")
	assert_false(b.dead, "detrás de la pared no")


func test_player_throws_grenade_with_g() -> void:
	await _arena()
	player.inventory.receive(ItemStack.make("grenade_rg5"))
	var before := player.inventory.count_of("grenade_rg5")
	bot.press_grenade()
	await physics_frames(70)
	assert_eq(player.inventory.count_of("grenade_rg5"), before - 1)
	assert_eq(get_tree().get_nodes_in_group("grenade").size(), 1, "la granada está volando")
	await physics_frames(60 * 4)
	assert_eq(get_tree().get_nodes_in_group("grenade").size(), 0, "y explotó")


func test_melee_backstab_kills() -> void:
	await _arena()
	# Mirando para el otro lado; el jugador detrás, pegado
	var n := _npc(Vector3(0, 0, -1.6), 0.0)
	await physics_frames(20)
	player.pitch_angle = -0.2
	bot.press_melee()
	await physics_frames(40)
	assert_true(n.dead, "una puñalada por la espalda es letal")


func test_squad_callout() -> void:
	await _arena()
	var a := _npc(Vector3(0, 0, -20), FACE_SOUTH, "bandit_rifle", 2)
	a.squad = "s"
	var b := _npc(Vector3(30, 0, -40), 0.0, "bandit_rifle", 2)  # de espaldas, lejos
	b.squad = "s"
	await physics_frames(60 * 3)
	assert_eq(a.brain.state, NpcBrain.State.COMBAT)
	assert_eq(b.brain.state, NpcBrain.State.COMBAT, "el compañero avisó")


func test_difficulty_changes_accuracy() -> void:
	var hits := []
	for diff in [0, 2]:
		await _arena()
		var count := [0]
		var cb := func(_o: Vector3) -> void: count[0] += 1
		EventBus.player_hit_from.connect(cb)
		for i in 3:
			_npc(Vector3(-6 + i * 6, 0, -30), FACE_SOUTH, "bandit_rifle", diff)
		await physics_frames(60 * 10)
		EventBus.player_hit_from.disconnect(cb)
		hits.append(count[0])
		level.queue_free()
		level = null
		await process_frames(2)
	assert_gt(hits[1], hits[0], "el veterano le pega más que el novato (%s)" % [hits])


func test_player_death_leaves_body_and_respawns() -> void:
	DebugTools.god_mode = false
	level = LEVEL.instantiate()
	add_child(level)
	player = level.get_node("Player")
	bot = BotInputProvider.new()
	player.set_input_provider(bot)
	await physics_frames(10)
	player.teleport(Vector3(5, 0.05, -5), 0.0)
	await physics_frames(5)
	var had := player.inventory.count_of("medkit")
	assert_gt(had, 0)
	player.take_damage(500.0)
	assert_true(player.is_dead)
	await physics_frames(int(60 * (Player.RESTART_AFTER_DEATH + 0.5)))
	assert_false(player.is_dead, "volvió a aparecer")
	var corpses := get_tree().get_nodes_in_group("player_corpse")
	assert_eq(corpses.size(), 1, "quedó su cuerpo")
	if corpses.size() == 1:
		var c := corpses[0] as PlayerCorpse
		assert_eq(c.inventory.count_of("w_ak74u"), 1, "con su arma")
		assert_true(c.inventory.count_of("backpack_medium") == 1, "y la mochila con lo de adentro")
		assert_gt(c.global_position.distance_to(player.global_position), 3.0, "lejos de donde reapareció")


func test_factory_sights_now_removable() -> void:
	for id: String in ["hk416", "scarl", "svd"]:
		var w := load("res://data/weapons/%s.tres" % id) as WeaponData
		var def := WeaponAttach.sight_of(w, {})
		assert_true(def != "", "%s trae mira de fábrica" % id)
		var with := WeaponModelBuilder.build(WeaponAttach.model_data(w, def))
		WeaponAttach.apply_model(with, w, def, "")
		var bare := WeaponModelBuilder.build(WeaponAttach.model_data(w, ""))
		WeaponAttach.apply_model(bare, w, "", "")
		var has_glass := with.get_node_or_null("Lens") != null or with.get_node_or_null("ScopeLens") != null
		var bare_glass := bare.get_node_or_null("Lens") != null or bare.get_node_or_null("ScopeLens") != null
		assert_true(has_glass, "%s con mira" % id)
		assert_false(bare_glass, "%s sin mira queda con alza y guion" % id)
		assert_eq(WeaponAttach.apply_data(w, def).sight, "scope" if id == "svd" else "red_dot")
		with.free()
		bare.free()
	var pso := ItemDB.get_item("optic_pso")
	assert_true(ItemDB.fits_weapon(pso, load("res://data/weapons/svd.tres")))
	assert_false(ItemDB.fits_weapon(pso, load("res://data/weapons/akm.tres")), "el PSO solo va en el DR-1")


func test_zz_sim() -> void:
	if not OS.get_cmdline_user_args().has("--sim"):
		return
	for dist: float in [20.0, 40.0, 70.0]:
		for diff in [0, 1, 2]:
			await _arena()
			var count := [0]
			var first := [-1.0]
			var t0 := Time.get_ticks_msec()
			var frames := [0]
			var cb := func(_o: Vector3) -> void:
				count[0] += 1
				if first[0] < 0.0:
					first[0] = frames[0] / 60.0
			EventBus.player_hit_from.connect(cb)
			var shots := 0
			var npcs: Array[HumanNpc] = []
			for i in 3:
				npcs.append(_npc(Vector3(-6 + i * 6, 0, -dist), FACE_SOUTH, "bandit_rifle", diff, "ak74"))
			for f in 60 * 12:
				frames[0] = f
				await physics_frames(1)
			for n in npcs:
				shots += n._capacity() * (1 + 3) - n.ammo_left()
			EventBus.player_hit_from.disconnect(cb)
			print("SIM dist=%d diff=%d hits=%d shots=%d first=%.1f" % [dist, diff, count[0], shots, first[0]])
			level.queue_free()
			level = null
			await process_frames(2)


func test_npc_ragdoll_falls_and_settles() -> void:
	await _arena()
	var n := _npc(Vector3(0, 0, -6), FACE_SOUTH)
	await physics_frames(20)
	var info := HitInfo.new()
	info.damage = 500.0
	info.zone = "torso"
	info.direction = Vector3(0, 0, -1)
	info.position = n.body.chest_position()
	info.source = player
	n.apply_hit(info)
	var rd := n.body.ragdoll
	assert_true(rd != null, "cae como muñeco físico")
	assert_gt(float(rd.parts.size()), 9.0, "con cadera, columna, cabeza, brazos y piernas")
	await physics_frames(60 * 4)
	var hips := rd.center()
	assert_lt(hips.y, 0.45, "quedó en el piso (cadera a %.2f m)" % hips.y)
	assert_lt(hips.z, -6.0, "cayó hacia donde lo empujó el tiro")
	var head := n.body.head_position()
	assert_lt(head.y, 0.6, "la cabeza también (%.2f m)" % head.y)
	for i in rd.hinges.size():
		var bend := rd.hinge_bend(i)
		assert_true(bend > -0.25 and bend < 2.8, "%s %d no se dobla al revés (%.2f rad)" % [rd.hinges[i][3], i, bend])
	# Las rodillas no se doblan al revés aunque las empujen fuerte
	for i in rd.hinges.size():
		var child := rd.hinges[i][1] as RigidBody3D
		var parent := rd.hinges[i][0] as RigidBody3D
		var axis := (parent.global_basis * (rd.hinges[i][2] as Vector3)).normalized()
		# Empuje que la endereza y la pasa de largo (gira al revés del doblez)
		var tangent := axis.cross(child.global_basis.y).normalized()
		rd.push(child.global_position + child.global_basis.y * 0.2, -tangent * child.mass * 2.5)
	await physics_frames(60 * 2)
	for i in rd.hinges.size():
		var bend := rd.hinge_bend(i)
		assert_gt(bend, -0.3, "%s %d sigue sin doblarse al revés tras empujarla (%.2f rad)" % [rd.hinges[i][3], i, bend])
	await physics_frames(60 * 6)
	assert_true(rd.frozen, "quieto, se congela (no gasta)")
	# Un tiro al cuerpo lo vuelve a mover
	var hi := HitInfo.new()
	hi.damage = 40.0
	hi.direction = Vector3(1, 0, 0)
	hi.position = rd.center()
	n.apply_hit(hi)
	assert_false(rd.frozen, "un tiro lo mueve")
	assert_true(n.get_interact_text() != "", "se puede revisar")



func test_npc_hears_real_player_shot() -> void:
	await _arena()
	var n := _npc(Vector3(0, 0, -70), 0.0)
	await physics_frames(20)
	for i in 200:
		if player.weapons.state == WeaponController.State.READY:
			break
		await physics_frames(1)
	# Disparo de verdad hacia un costado (la bala no le pasa cerca)
	player.yaw = PI * 0.5
	bot.press_fire()
	await physics_frames(20)
	assert_true(n.brain.state in [NpcBrain.State.COMBAT, NpcBrain.State.INVESTIGATE], "oye el tiro del jugador a 70 m")
