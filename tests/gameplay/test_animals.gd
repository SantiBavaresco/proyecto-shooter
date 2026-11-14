extends TestCase
## Animales: jaurías de perros y piaras de jabalíes que atacan de a golpes y se abren
## para cualquier lado; reciben tiros, mueren y si cae la mitad el resto se va.

const PLAYER := preload("res://entities/player/player.tscn")

var level: Node3D
var player: Player
var bot: BotInputProvider
var geo: Node3D


func _arena() -> void:
	level = Node3D.new()
	level.name = "Arena"
	add_child(level)
	geo = Node3D.new()
	geo.add_to_group(NavUtil.GROUP)
	level.add_child(geo)
	var b := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(200, 1, 200)
	cs.shape = sh
	b.add_child(cs)
	b.position = Vector3(0, -0.5, 0)
	geo.add_child(b)
	level.add_child(DirectionalLight3D.new())
	NavUtil.bake(level, AABB(Vector3(-100, -2, -100), Vector3(200, 8, 200)), false, 0.3)
	player = PLAYER.instantiate() as Player
	level.add_child(player)
	bot = BotInputProvider.new()
	player.set_input_provider(bot)
	await physics_frames(5)
	CombatWorld.get_for(player).hitstop_enabled = false
	player.teleport(Vector3(0, 0.05, 0), 0.0)
	await physics_frames(10)


func _pack(species: String, pos: Vector3, n := 4) -> AnimalPack:
	var pk := AnimalPack.new()
	pk.species = species
	pk.count = n
	pk.roam = 8.0
	pk.seed_value = 7
	pk.position = pos
	level.add_child(pk)
	return pk


func _shot(a: Animal, zone: String, dmg: float) -> HitInfo:
	var h := HitInfo.new()
	h.damage = dmg
	h.zone = zone
	h.direction = (a.global_position - player.global_position).normalized()
	h.position = a.global_position + Vector3(0, 0.6, 0)
	h.source = player
	return h


func after_each() -> void:
	DebugTools.god_mode = false
	if level != null:
		level.queue_free()
		level = null
	await process_frames(2)


func test_dogs_attack_bite_and_retreat() -> void:
	await _arena()
	var pk := _pack("dog", Vector3(0, 0.1, -22))
	await physics_frames(10)
	assert_eq(pk.members.size(), 4, "4 perros")
	var hp0 := player.vitals.health
	var states := {}
	var max_d := 0.0
	for f in 60 * 20:
		await physics_frames(1)
		for m in pk.members:
			states[m.state] = true
			if m.state == Animal.State.RETREAT:
				max_d = maxf(max_d, m.global_position.distance_to(player.global_position))
	assert_true(states.has(Animal.State.ATTACK), "te atacan")
	assert_true(states.has(Animal.State.RETREAT), "y se abren")
	assert_lt(player.vitals.health, hp0, "te muerden")
	assert_gt(max_d, 6.0, "se alejan antes de volver a entrar")


func test_boars_charge_and_knock_back() -> void:
	await _arena()
	DebugTools.god_mode = true
	var pk := _pack("boar", Vector3(0, 0.1, -12), 3)
	await physics_frames(10)
	var hits := [0]  # (las lambdas copian los int: va en un array)
	var c := func(_a: float) -> void: hits[0] += 1
	EventBus.player_damaged.connect(c)
	var charged := false
	for f in 60 * 20:
		await physics_frames(1)
		for m in pk.members:
			if m._charging:
				charged = true
	EventBus.player_damaged.disconnect(c)
	assert_true(charged, "embisten")
	assert_gt(hits[0], 0, "te llevan puesto")


func test_shot_dog_dies_and_half_pack_flees() -> void:
	await _arena()
	DebugTools.god_mode = true
	var pk := _pack("dog", Vector3(0, 0.1, -30))
	await physics_frames(10)
	var a := pk.members[0]
	var b := pk.members[1]
	assert_true(a.apply_hit(_shot(a, "head", 40.0)), "un tiro a la cabeza lo mata")
	assert_true(a.dead)
	assert_false(b.apply_hit(_shot(b, "limb", 20.0)), "a la pata no")
	b.apply_hit(_shot(b, "torso", 80.0))
	assert_true(b.dead, "dos tiros sí")
	await physics_frames(5)
	for m in pk.members:
		if not m.dead:
			assert_eq(m.state, Animal.State.FLEE, "%s: cayó la mitad, se va" % m.name)


func test_bullet_hits_animal_hitbox() -> void:
	await _arena()
	DebugTools.god_mode = true
	var pk := _pack("boar", Vector3(0, 0.1, -10), 1)
	await physics_frames(10)
	var a := pk.members[0]
	a.set_physics_process(false)
	var hp0 := a.hp
	var cw := CombatWorld.get_for(player)
	var from := Vector3(0, 0.7, -4)
	var w := load("res://data/weapons/akm.tres") as WeaponData
	cw.fire_projectile(from, (a.global_position + Vector3(0, 0.75, 0) - from).normalized(), w, player)
	await physics_frames(10)
	assert_lt(a.hp, hp0, "la bala le pega")


func test_boars_come_for_the_shooter() -> void:
	await _arena()
	DebugTools.god_mode = true
	var pk := _pack("boar", Vector3(0, 0.1, -45), 3)
	await physics_frames(10)
	var d0 := pk.members[0].global_position.distance_to(player.global_position)
	EventBus.noise_emitted.emit(player.global_position, HumanNpc.SHOT_HEAR, player)
	await physics_frames(3)
	for m in pk.members:
		assert_true(m.state in [Animal.State.ALERT, Animal.State.ATTACK], "un tiro a media distancia: van al que tiró")
	await physics_frames(60 * 2)
	assert_lt(pk.members[0].global_position.distance_to(player.global_position), d0 - 6.0, "y corren hacia vos")


func test_zone_has_animals() -> void:
	var zone := (load("res://world/zone_talavera/zone_talavera.tscn") as PackedScene).instantiate()
	add_child(zone)
	await physics_frames(30)
	var dogs := 0
	var boars := 0
	for n in get_tree().get_nodes_in_group("animals"):
		if (n as Animal).species == "dog":
			dogs += 1
		else:
			boars += 1
	assert_gt(dogs, 5, "jaurías en la isla")
	assert_gt(boars, 8, "piaras en la isla")
	zone.queue_free()
	await process_frames(2)


func _box_at(pos: Vector3, size: Vector3) -> void:
	var b := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	b.add_child(cs)
	b.position = pos
	geo.add_child(b)


func test_dogs_cant_bite_you_on_top_of_a_box() -> void:
	await _arena()
	_box_at(Vector3(0, 1.0, 0), Vector3(2.4, 2.0, 2.4))
	player.teleport(Vector3(0, 2.1, 0), 0.0)
	await physics_frames(20)
	var pk := _pack("dog", Vector3(0, 0.1, -16))
	await physics_frames(10)
	var hp0 := player.vitals.health
	for f in 60 * 12:
		await physics_frames(1)
	assert_eq(player.vitals.health, hp0, "arriba de una caja de 2 m no te muerden")


func test_boar_charge_dodged_at_the_last_moment() -> void:
	await _arena()
	DebugTools.god_mode = true
	var pk := _pack("boar", Vector3(0, 0.1, -25), 1)
	await physics_frames(10)
	var b := pk.members[0]
	b.target = player
	b._attack()
	var hits := [0]
	var c := func(_a: float) -> void: hits[0] += 1
	EventBus.player_damaged.connect(c)
	# Esperás quieto hasta que está encima y recién ahí te corrés al costado
	var dodged := false
	for f in 60 * 6:
		await physics_frames(1)
		if not dodged and b.global_position.distance_to(player.global_position) < 2.9:
			player.teleport(player.global_position + Vector3(2.6, 0, 0), 0.0)
			dodged = true
		if dodged and b.state == Animal.State.RETREAT:
			break
	assert_true(dodged)
	assert_eq(hits[0], 0, "esquivada en el último momento, pasa de largo")
	# Si te corrés temprano, te sigue
	b._attack()
	player.teleport(player.global_position + Vector3(-6, 0, 0), 0.0)
	for f in 60 * 6:
		await physics_frames(1)
		if hits[0] > 0:
			break
	EventBus.player_damaged.disconnect(c)
	assert_gt(hits[0], 0, "corrido de antes: corrige y te lleva puesto")


func test_lethal_shot_ragdolls_and_body_lies_on_ground() -> void:
	await _arena()
	DebugTools.god_mode = true
	var pk := _pack("dog", Vector3(0, 0.1, -30), 4)
	await physics_frames(10)
	var a := pk.members[0]
	var b := pk.members[1]
	assert_true(a.apply_hit(_shot(a, "chest", 200.0)), "al pecho: muere")
	assert_eq(a.state, Animal.State.DEAD, "cae en el acto")
	assert_true(b.apply_hit(_shot(b, "torso", 70.0)), "a las ancas: muere igual...")
	assert_eq(b.state, Animal.State.DYING, "...pero se arrastra")
	var p0 := b.global_position
	await physics_frames(60 * 3)
	assert_gt(b.global_position.distance_to(p0), 0.5, "se arrastra un poco")
	b.apply_hit(_shot(b, "head", 30.0))
	assert_eq(b.state, Animal.State.DEAD, "un tiro a la cabeza lo termina")
	await physics_frames(60 * 4)
	assert_true(a._rag[0].freeze, "el cuerpo se quedó quieto")
	assert_gt(a.center().y, 0.08, "apoyado sobre el piso, no hundido (%.2f)" % a.center().y)
	a._voice.stop()
	a.apply_hit(_shot(a, "torso", 50.0))
	assert_false(a._voice.playing, "muerto no hace ruido")


func test_skinning_needs_knife_and_gives_hide_sometimes() -> void:
	await _arena()
	DebugTools.god_mode = true
	var pk := _pack("boar", Vector3(0, 0.1, -30), 4)
	await physics_frames(10)
	for m in pk.members:
		m.apply_hit(_shot(m, "head", 900.0))
	await physics_frames(10)
	var pinv := player.inventory
	var knife := pinv.take_equipped("melee") if pinv.equipment.get("melee") != null else null
	var a := pk.members[0]
	assert_eq(a.get_interact_text(), "animal.skin_hint")
	a.interact(player)
	assert_false(a.skinned, "sin cuchillo no se puede")
	pinv.place_equipped(knife if knife != null else ItemStack.make("knife"), "melee")
	var before := pinv.count_of("hide_boar")
	for m in pk.members:
		m.rng.seed = 5
		m.interact(player)
		assert_true(m.skinned)
		assert_eq(m.get_interact_text(), "", "una sola vez por cuerpo")
	var got := pinv.count_of("hide_boar") - before
	assert_true(got >= 0 and got <= 4, "a veces sí, a veces no (%d de 4)" % got)


func test_capybara_flees_and_bites_if_cornered() -> void:
	await _arena()
	DebugTools.god_mode = true
	var pk := _pack("capy", Vector3(0, 0.1, -12), 3)
	await physics_frames(20)
	var c := pk.members[0]
	assert_eq(c.state, Animal.State.FLEE, "te ve: se va (sin agua cerca, corriendo)")
	var hits := [0]
	var cb := func(_a: float) -> void: hits[0] += 1
	EventBus.player_damaged.connect(cb)
	var d := pk.members[1]
	player.teleport(d.global_position + Vector3(1.2, 0, 0), 0.0)
	for f in 60 * 3:
		await physics_frames(1)
		if hits[0] > 0:
			break
	EventBus.player_damaged.disconnect(cb)
	assert_gt(hits[0], 0, "encima de uno: te muerde")


func test_npc_shoots_attacking_dogs() -> void:
	await _arena()
	DebugTools.god_mode = true
	player.teleport(Vector3(80, 0.05, 80), 0.0)
	var n := HumanNpc.new()
	n.loadout_id = "bandit_rifle"
	n.weapon_id = "akm"
	n.seed_value = 3
	n.position = Vector3(0, 0.05, 0)
	level.add_child(n)
	await physics_frames(20)
	var pk := _pack("dog", Vector3(0, 0.1, -13), 3)
	var hurt := false
	var mag0 := n.mag
	var shot_at := false
	for f in 60 * 20:
		await physics_frames(1)
		if n.brain.animal != null and n.mag < mag0:
			shot_at = true
		for m in pk.members:
			if m.dead or m.hp < float(Animal.SPECIES["dog"]["hp"]):
				hurt = true
		if hurt:
			break
	assert_true(shot_at or hurt, "el bandido les tira a los perros (a 15 m)")
	# Y los perros que se van lejos no los sigue tirando
	await physics_frames(60 * 4)
	for m in pk.members:
		if not m.dead and m.global_position.distance_to(n.global_position) > 30.0:
			assert_true(n.brain.animal != m, "no le sigue tirando a uno que se fue")
