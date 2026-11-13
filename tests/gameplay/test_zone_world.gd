extends TestCase
## Isla Talavera: se arma, tiene malla de navegación, enemigos en las bases, alijo en
## el campamento y al morir se vuelve al campamento dejando el cuerpo.

const LEVEL := preload("res://world/zone_talavera/zone_talavera.tscn")

var level: Node3D
var player: Player


func before_each() -> void:
	DebugTools.god_mode = true
	level = LEVEL.instantiate()
	add_child(level)
	player = level.get_node("Player")
	player.set_input_provider(BotInputProvider.new())
	await physics_frames(30)


func after_each() -> void:
	DebugTools.god_mode = false
	level.queue_free()
	await process_frames(2)


func test_world_builds_with_enemies_and_navigation() -> void:
	var npcs := get_tree().get_nodes_in_group("ai_npc")
	assert_gt(npcs.size(), 14, "hay enemigos en las bases y el camino")
	var region := level.get_node("Navigation") as NavigationRegion3D
	for i in 300:
		if not region.is_baking():
			break
		await physics_frames(1)
	await physics_frames(10)
	assert_gt(region.navigation_mesh.get_polygon_count(), 500, "la malla de navegación se armó")
	var map := level.get_world_3d().navigation_map
	var b: Node = level
	var path := NavigationServer3D.map_get_path(map, b.call("ground", Vector3(-150, 0, 140)), b.call("ground", Vector3(35, 0, -25)), true)
	assert_gt(path.size(), 2, "se puede ir caminando del campamento al galpón")


func test_bases_are_above_water_and_flat() -> void:
	var b: Node = level
	for c: Vector3 in [Vector3(-150, 0, 150), Vector3(35, 0, -25), Vector3(128, 0, 112), Vector3(-105, 0, -115)]:
		var h: float = b.call("height", c.x, c.z)
		assert_gt(h, -1.6 + 1.0, "%s sobre el agua" % c)
		var h2: float = b.call("height", c.x + 6.0, c.z + 6.0)
		assert_near(h, h2, 0.05, "%s plano" % c)


func test_player_starts_at_camp_with_little_gear() -> void:
	assert_lt(player.global_position.distance_to(Vector3(-150, player.global_position.y, 150)), 12.0, "empieza en el campamento")
	assert_true(player.inventory.equipment["weapon1"] == null, "sin arma larga")
	assert_true(player.inventory.equipment["pistol"] != null, "con pistola")
	var stash := level.find_child("CampStash", true, false) as LootContainer
	assert_true(stash != null)
	assert_eq(stash.inventory.count_of("w_ak74"), 1, "en el alijo hay un AR-74")
	for s in stash.inventory.stacks:
		if s.item.kind == "mag":
			assert_eq(int(s.state["rounds"]), s.item.capacity, "con cargadores llenos")


func test_death_respawns_at_camp_and_leaves_body() -> void:
	DebugTools.god_mode = false
	var b: Node = level
	player.teleport((b.call("ground", Vector3(-100, 0, 100)) as Vector3) + Vector3(0, 0.1, 0))
	await physics_frames(5)
	var eye_y := player.camera.global_position.y
	player.take_damage(500.0)
	await physics_frames(90)
	assert_lt(player.camera.global_position.y, eye_y - 1.0, "la cámara cayó al piso")
	assert_false(player.weapons.view._vm_layer.visible, "sin arma en pantalla")
	await physics_frames(int(60 * (Player.RESTART_AFTER_DEATH + 0.5)) - 90)
	assert_false(player.is_dead)
	assert_true(player.weapons.view._vm_layer.visible, "al volver, el arma vuelve")
	assert_lt(player.camera.position.length(), 0.01, "y la cámara a su lugar")
	assert_lt(player.global_position.distance_to(Vector3(-150, player.global_position.y, 150)), 12.0, "volvió al campamento")
	var bodies := get_tree().get_nodes_in_group("player_corpse")
	assert_eq(bodies.size(), 1)
	if bodies.size() == 1:
		assert_eq((bodies[0] as PlayerCorpse).inventory.count_of("w_pistol"), 1, "lo que llevaba quedó en el cuerpo")
		assert_gt((bodies[0] as PlayerCorpse).inventory.count_of("cash"), 0, "con la plata")
		assert_true(player.inventory.equipment["pistol"] != null, "y reaparece con una pistola")
		assert_true((bodies[0] as PlayerCorpse).compass_label() != "", "la brújula marca el cuerpo")


func test_military_squads_in_zone() -> void:
	await physics_frames(10)
	var mil := 0
	for n in get_tree().get_nodes_in_group("ai_npc"):
		if (n as HumanNpc).tactics == "military":
			mil += 1
	assert_eq(mil, 10, "4 en el galpón, 2 de ronda y 4 en el monte")
	var galpon: Squad = null
	for s in get_tree().get_nodes_in_group("squad_coordinator"):
		if (s as Squad).id == "galpon":
			galpon = s
	assert_true(galpon != null and galpon.commanded, "el galpón tiene comandante militar")
	var bandits := 0
	for m in galpon.members:
		if m.tactics != "military":
			bandits += 1
	assert_eq(bandits, 5, "y 5 bandidos a sus órdenes")
	var b: Node = level
	var c := Vector3(92, 0, -118)
	var h: float = b.call("height", c.x, c.z)
	assert_gt(h, -1.6 + 1.0, "el campamento del monte, sobre el agua")


func test_npc_finds_cover_in_the_woods() -> void:
	await physics_frames(10)
	var found := 0
	var tried := 0
	for n in get_tree().get_nodes_in_group("ai_npc"):
		var h := n as HumanNpc
		if h.squad != "monte" and h.squad != "chacra":
			continue
		tried += 1
		var threat := h.global_position + Vector3(25, 0, 10)
		var c := h.brain._find_cover(threat, false)
		if c != Vector3.INF:
			found += 1
			assert_lt(c.distance_to(h.global_position), 15.0, "%s: cerca" % h.name)
	assert_gt(float(found), float(tried) * 0.6, "en el monte encuentran detrás de qué cubrirse (%d de %d)" % [found, tried])
	assert_gt(float(CoverIndex.near(player, Vector3(92, 0, -118), 20.0).size()), 5.0, "hay troncos y arbustos indexados")
