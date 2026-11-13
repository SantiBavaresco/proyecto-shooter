extends TestCase
## 3.1: escuadras militares (roles, fuego de cobertura, avance, flanqueo, voz y señas),
## humo, estrés de los enemigos, armas gastadas que se traban, presión de combate sobre
## el jugador y botín gastado.

const PLAYER := preload("res://entities/player/player.tscn")

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


func _squad(n: int, at: Vector3, sq := "mil_t", diff := 0) -> Array[HumanNpc]:
	var out: Array[HumanNpc] = []
	for i in n:
		var lo := "mil_leader" if i == 0 else "mil_rifle"
		var h := _npc(at + Vector3((i - n * 0.5) * 3.0, 0, float(i % 2) * 2.0), 0.0, lo, diff, "hk416")
		h.name = "Mil_%d" % i
		h.squad = sq
		out.append(h)
	return out


func test_squad_assigns_roles_and_suppresses() -> void:
	await _arena(true)
	# Pared entre el jugador y la escuadra: no lo ven, pero saben dónde está
	var team := _squad(4, Vector3(0, 0.05, -34))
	await physics_frames(30)
	var shots := [0]
	var cb := func(_pos: Vector3, r: float, src: Node) -> void:
		if src is HumanNpc and r >= 30.0 and not (src as HumanNpc).brain.target_visible:
			shots[0] += 1
	EventBus.noise_emitted.connect(cb)
	for m in team:
		m.brain.on_callout(player.global_position)
	var roles := {}
	for i in 60 * 10:
		await physics_frames(1)
		for m in team:
			if m.brain.role != "":
				roles[m.brain.role] = true
	EventBus.noise_emitted.disconnect(cb)
	var sq := team[0].squad_obj
	assert_true(sq != null and sq.commanded, "tienen comandante")
	assert_true(roles.has("suppress"), "alguien cubre (%s)" % [roles.keys()])
	assert_true(roles.has("advance") or roles.has("flank"), "alguien avanza o flanquea (%s)" % [roles.keys()])
	assert_gt(float(shots[0]), 3.0, "fuego de cobertura sin verlo")
	var closest := INF
	for m in team:
		closest = minf(closest, m.global_position.distance_to(player.global_position))
	assert_lt(closest, 30.0, "se fueron acercando")


func test_smoke_blocks_sight() -> void:
	await _arena()
	SmokeCloud.spawn(level, Vector3(0, 0, -10))
	for c in get_tree().get_nodes_in_group("smoke_cloud"):
		(c as SmokeCloud).t = SmokeCloud.GROW + 1.0
	var n := _npc(Vector3(0, 0.05, -20), PI, "bandit_rifle", 2)
	await physics_frames(60 * 3)
	assert_lt(n.brain.awareness, 0.2, "a través del humo no lo ve (%.2f)" % n.brain.awareness)
	for c in get_tree().get_nodes_in_group("smoke_cloud"):
		c.queue_free()
	await physics_frames(60 * 3)
	assert_gt(n.brain.awareness, 0.5, "sin humo sí")


func test_suppress_into_smoke_aims_last_known() -> void:
	await _arena()
	var team := _squad(2, Vector3(0, 0.05, -25))
	await physics_frames(20)
	for m in team:
		m.brain.on_callout(player.global_position)
	await physics_frames(60)
	SmokeCloud.spawn(level, Vector3(0, 0, -10))
	for c in get_tree().get_nodes_in_group("smoke_cloud"):
		(c as SmokeCloud).t = SmokeCloud.GROW + 1.0
	await physics_frames(30)
	var lk := team[0].brain.last_known
	# Se mueve detrás del humo: no lo pueden seguir
	player.teleport(Vector3(2, 0.05, 3), 0.0)
	await physics_frames(60 * 4)
	for m in team:
		assert_false(m.brain.target_visible, "no lo ve a través del humo")
		if m.brain.last_known != Vector3.INF:
			assert_lt(m.brain.last_known.distance_to(lk), 2.5, "tira adonde lo vio, no adonde está")


func test_bad_weapon_jams() -> void:
	await _arena()
	var n := _npc(Vector3(0, 0.05, -20), 0.0)
	n.ai_enabled = false
	await physics_frames(10)
	n.weapon_condition = 0.05
	var jams := 0
	for i in 400:
		n.mag = 30
		n.reloading = false
		n._jam = false
		n.burst_left = 1
		n._fire(Vector3.FORWARD)
		if n._jam:
			jams += 1
	assert_gt(float(jams), 4.0, "un arma muy gastada se traba seguido (%d en 400)" % jams)
	n.weapon_condition = 0.9
	jams = 0
	for i in 400:
		n.mag = 30
		n._jam = false
		n.burst_left = 1
		n._fire(Vector3.FORWARD)
		if n._jam:
			jams += 1
	assert_eq(jams, 0, "una buena no")


func test_npc_stress_rises_and_slows_reload() -> void:
	await _arena()
	var n := _npc(Vector3(0, 0.05, -20), 0.0)
	n.ai_enabled = false
	await physics_frames(10)
	for i in 4:
		n.on_near_miss(player.global_position, player)
	assert_gt(n.stress, 0.5, "tiros cerca lo ponen nervioso")
	var calm := 0.0
	var nervous := 0.0
	for i in 30:
		n.stress = 0.0
		n.mag = 0
		n.reloading = false
		n.spare_mags = [30]
		n.start_reload()
		calm += n._reload_left
		n.stress = 1.0
		n.reloading = false
		n.spare_mags = [30]
		n.start_reload()
		nervous += n._reload_left
	assert_gt(nervous, calm * 1.4, "con estrés recarga más lento (y a veces se traba)")
	await physics_frames(60 * 5)
	assert_lt(n.stress, 0.8, "se le va pasando")


func test_voice_shout_talk_or_signal() -> void:
	await _arena()
	var team := _squad(2, Vector3(0, 0.05, -25))
	await physics_frames(20)
	var sq := team[0].squad_obj
	team[1].global_position = team[0].global_position + Vector3(4, 0, 0)
	await physics_frames(2)
	assert_eq(sq.say(team[0], "moving"), "signal", "se ven, tranquilos: seña")
	sq._voice_t = 0.0
	assert_eq(sq.say(team[0], "contact"), "talk", "cerca: hablado")
	sq._voice_t = 0.0
	sq._key_t.clear()
	sq.note_shot()
	assert_eq(sq.say(team[0], "moving"), "shout", "en pleno tiroteo: grito")
	sq._voice_t = 0.0
	sq._key_t.clear()
	sq.last_shot_t = -99.0
	team[1].global_position = team[0].global_position + Vector3(30, 0, 0)
	await physics_frames(2)
	assert_eq(sq.say(team[0], "contact"), "shout", "lejos: grito")
	sq._voice_t = 0.0
	assert_eq(sq.say(team[0], "contact"), "", "no repite la misma frase enseguida")
	assert_eq(sq.say(team[0], "search", true), "", "en sigilo y lejos: se lo guarda")
	assert_true(VoiceBank.stream(team[0].voice_id, "contact", true, RandomNumberGenerator.new()) != null, "hay audio")


func test_player_combat_pressure() -> void:
	await _arena()
	var team := _squad(2, Vector3(0, 0.05, -12))
	await physics_frames(20)
	for m in team:
		m.ai_enabled = false
		m.brain.state = NpcBrain.State.COMBAT
		m.brain.target = player
	await physics_frames(90)
	var outdoor := player.pressure
	assert_gt(outdoor, 0.25, "2 encima: al menos estrés leve (%.2f)" % outdoor)
	assert_gt(float(player.stress.level()), 0.5)
	_box(Vector3(0, 3.2, 0), Vector3(8, 0.3, 8))
	await physics_frames(30)
	assert_gt(player.pressure, outdoor * 1.5, "bajo techo, más (%.2f → %.2f)" % [outdoor, player.pressure])
	for m in team:
		m.brain.state = NpcBrain.State.IDLE
	team[0].brain.state = NpcBrain.State.COMBAT
	team[0].global_position = Vector3(0, 0.05, -55)
	await physics_frames(30)
	assert_lt(player.pressure, 0.1, "uno lejos casi nada")


func test_military_loot_is_worn() -> void:
	await _arena()
	var n := _npc(Vector3(0, 0.05, -10), 0.0, "mil_rifle", 1, "hk416")
	await physics_frames(10)
	var hi := HitInfo.new()
	hi.damage = 500.0
	hi.zone = "head_core"
	hi.penetration = 9.0
	hi.direction = Vector3(0, 0, -1)
	hi.position = n.body.head_position()
	n.apply_hit(hi)
	var w: ItemStack = null
	var v: ItemStack = null
	for st in n.inventory.stacks:
		if st.item.kind == "weapon":
			w = st
		elif st.item.kind == "armor":
			v = st
	assert_true(w != null and v != null)
	assert_lt(float(w.state["condition"]), 0.5, "el arma está gastada")
	assert_lt(float(v.state["condition"]), 0.55, "el chaleco también")
	assert_eq(String(w.state.get("sight", "")), n.sight_id if n.sight_id != "__fabrica" else String(w.state.get("sight", "")), "con su mira")


func test_patrol_formation() -> void:
	await _arena()
	player.teleport(Vector3(70, 0.05, 70), 0.0)
	var team := _squad(4, Vector3(0, 0.05, -20))
	team[0].patrol = PackedVector3Array([Vector3(0, 0, -20), Vector3(0, 0, -50)])
	team[0].brain.state = NpcBrain.State.PATROL
	for m in team.slice(1):
		m.brain.state = NpcBrain.State.PATROL
	await physics_frames(60 * 6)
	for m in team.slice(1):
		assert_true(m.brain.follow_pos != Vector3.INF, "%s sigue al líder" % m.name)
		var d: float = m.global_position.distance_to(team[0].global_position)
		assert_gt(d, 2.5, "abiertos, no amontonados (%.1f m)" % d)
		assert_lt(d, 16.0, "pero cerca del líder (%.1f m)" % d)


func test_bandit_allies_take_orders() -> void:
	await _arena(true)
	var team := _squad(2, Vector3(0, 0.05, -34))
	var b1 := _npc(Vector3(-6, 0.05, -36), 0.0, "bandit_rifle", 0)
	var b2 := _npc(Vector3(6, 0.05, -36), 0.0, "bandit_rifle", 0)
	b1.squad = "mil_t"
	b2.squad = "mil_t"
	await physics_frames(30)
	team[0].brain.on_callout(player.global_position)
	var got := false
	for i in 60 * 6:
		await physics_frames(1)
		if b1.brain.role != "" or b2.brain.role != "":
			got = true
			break
	assert_true(got, "los bandidos del mismo trabajo reciben órdenes")
	assert_true(team[0].squad_obj.members.has(b1))


func test_smoke_spreads_with_wind_and_lasts_60s() -> void:
	await _arena()
	var c := SmokeCloud.spawn(level, Vector3(0, 0, -10))
	c.t = 20.0
	var w := SmokeCloud.wind
	var side := w.cross(Vector3.UP).normalized()
	var o := Vector3(0, 1.5, -10)
	# A favor del viento tapa lejos; de costado y por arriba, poco
	assert_true(SmokeCloud.blocks(get_tree(), o + w * 12.0 + side * 6.0, o + w * 12.0 - side * 6.0), "tapa 12 m a favor del viento")
	assert_false(SmokeCloud.blocks(get_tree(), o - w * 9.0 + side * 6.0, o - w * 9.0 - side * 6.0), "contra el viento casi no")
	assert_false(SmokeCloud.blocks(get_tree(), o + Vector3(0, 4.5, 0) + side * 6.0, o + Vector3(0, 4.5, 0) - side * 6.0), "es baja")
	c.t = 55.0
	assert_gt(c.radius(), 0.5, "a los 55 s todavía tapa")
	c.t = 61.0
	assert_lt(c.radius(), 0.5, "a los 60 s se fue")
	c.queue_free()
