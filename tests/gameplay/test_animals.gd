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


func test_boars_flee_from_far_shots() -> void:
	await _arena()
	var pk := _pack("boar", Vector3(0, 0.1, -60), 3)
	await physics_frames(10)
	EventBus.noise_emitted.emit(Vector3(0, 0, 0), HumanNpc.SHOT_HEAR, player)
	await physics_frames(3)
	for m in pk.members:
		assert_eq(m.state, Animal.State.FLEE, "un tiro lejos: se van")


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
