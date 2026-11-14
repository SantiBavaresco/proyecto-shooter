extends Node3D
## Capturas de la 3.1.8: arma contra la pared, sangre (tiro a la cabeza, charco,
## manchas del que se revuelca), perros rodeando, animal caído (ragdoll) y enemigo
## agachado detrás de una cobertura baja.

const PLAYER := preload("res://entities/player/player.tscn")

var out := "user://demo318"
var player: Player
var geo: Node3D
var cam: Camera3D


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out)
	get_tree().create_timer(400.0).timeout.connect(func() -> void: get_tree().quit())
	DebugTools.god_mode = true
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.62, 0.66, 0.7)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.8, 0.8, 0.85)
	env.environment.ambient_light_energy = 0.7
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.6, 0)
	sun.shadow_enabled = true
	add_child(sun)
	geo = Node3D.new()
	geo.add_to_group(NavUtil.GROUP)
	add_child(geo)
	_box(Vector3(0, -0.5, 0), Vector3(120, 1, 120), Color(0.42, 0.45, 0.35))
	_box(Vector3(0, 1.5, -6), Vector3(8, 3, 0.4), Color(0.55, 0.5, 0.45))       # pared
	_box(Vector3(14, 0.5, -10), Vector3(2.4, 1.0, 0.6), Color(0.5, 0.5, 0.5))    # cobertura baja
	NavUtil.bake(self, AABB(Vector3(-60, -2, -60), Vector3(120, 8, 120)), false, 0.3)
	player = PLAYER.instantiate() as Player
	add_child(player)
	player.set_input_provider(BotInputProvider.new())
	await _f(30)
	CombatWorld.get_for(player).hitstop_enabled = false
	cam = Camera3D.new()
	add_child(cam)

	# 1) Pegado a la pared: el arma se levanta y se corre
	player.teleport(Vector3(0, 0.05, -5.35), 0.0)
	await _f(60)
	await _shot("1_arma_contra_la_pared")

	# 2) Tiro a la cabeza: chorro y charco alrededor de la cabeza
	player.teleport(Vector3(-20, 0.05, 10), 0.0)
	var n := _npc(Vector3(-20, 0.05, 4))
	await _f(20)
	n.helmet = null
	var hi := HitInfo.new()
	hi.damage = 300.0
	hi.zone = "head_core"
	hi.direction = Vector3(0, -0.1, -1).normalized()
	hi.position = n.body.head_position()
	hi.source = player
	n.apply_hit(hi)
	await _f(4)
	_look_first_person(n.body.head_position())
	await _shot("2_tiro_a_la_cabeza_chorro")
	await _f(60 * 5)
	_external(n.global_position + Vector3(2.2, 2.0, 2.2), n.global_position)
	await _shot("3_charco_alrededor_de_la_cabeza")

	# 3) Herido de muerte (no en la cabeza): se revuelca y deja manchas
	var m := _npc(Vector3(-32, 0.05, 4))
	await _f(20)
	var h2 := HitInfo.new()
	h2.damage = 220.0
	h2.zone = "torso"
	h2.direction = Vector3(0, 0, -1)
	h2.position = m.body.chest_position()
	h2.source = player
	m.vest = null
	m.apply_hit(h2)
	await _f(60 * 12)
	_external(m.global_position + Vector3(2.0, 2.4, 2.4), m.global_position)
	await _shot("4_agonia_manchas")

	# 4) Perros: te rodean en círculo
	_cam_player()
	player.teleport(Vector3(30, 0.05, 25), 0.0)
	var pk := AnimalPack.new()
	pk.species = "dog"
	pk.count = 5
	pk.seed_value = 3
	pk.position = Vector3(30, 0.1, 12)
	add_child(pk)
	await _f(60 * 4)
	_external(player.global_position + Vector3(0, 9, 9), player.global_position)
	await _shot("5_jauria_rodeando")

	# 5) Jabalí muerto de un tiro al pecho (ragdoll apoyado en el piso)
	var bp := AnimalPack.new()
	bp.species = "boar"
	bp.count = 1
	bp.seed_value = 4
	bp.position = Vector3(-30, 0.1, 30)
	add_child(bp)
	await _f(20)
	var b := bp.members[0]
	b.set_physics_process(true)
	var hb := HitInfo.new()
	hb.damage = 600.0
	hb.zone = "chest"
	hb.direction = Vector3(1, 0, 0)
	hb.position = b.global_position + Vector3(0, 0.8, 0)
	hb.source = player
	b.apply_hit(hb)
	await _f(60 * 5)
	_external(b.center() + Vector3(2.4, 1.6, 2.4), b.center())
	await _shot("6_jabali_caido")

	# 6) Enemigo agachado detrás de una cobertura baja
	_cam_player()
	player.teleport(Vector3(14, 0.05, -24), PI)
	var c := _npc(Vector3(14, 0.05, -9.2))
	await _f(20)
	c.brain._enter_combat(player.global_position, true)
	c.brain.cover = Vector3(14, 0.05, -9.2)
	c.brain._cover_t = 999.0
	for i in 60 * 6:
		await _f(1)
		if c.crouching and c.burst_left <= 0 and i > 120:
			break
	_external(Vector3(18.5, 1.6, -11.5), Vector3(14, 0.7, -9.6))
	await _shot("7_agachado_en_cobertura_baja")
	get_tree().quit()


func _npc(at: Vector3) -> HumanNpc:
	var n := HumanNpc.new()
	n.loadout_id = "mil_rifle"
	n.weapon_id = "hk416"
	n.seed_value = 5
	n.position = at
	add_child(n)
	return n


func _box(pos: Vector3, size: Vector3, col: Color) -> void:
	var b := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	b.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	bm.material = m
	mi.mesh = bm
	b.add_child(mi)
	b.position = pos
	geo.add_child(b)


func _look_first_person(t: Vector3) -> void:
	_cam_player()
	var d := t - player.camera.global_position
	player.yaw = atan2(-d.x, -d.z)
	player.pitch_angle = atan2(d.y, Vector2(d.x, d.z).length())


func _cam_player() -> void:
	player.camera.current = true
	for cl in find_children("*", "CanvasLayer", true, false):
		(cl as CanvasLayer).visible = true


func _external(from: Vector3, to: Vector3) -> void:
	cam.global_position = from
	cam.look_at(to)
	cam.current = true
	for cl in find_children("*", "CanvasLayer", true, false):
		(cl as CanvasLayer).visible = false


func _shot(name: String) -> void:
	await _f(3)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))


func _f(n: int) -> void:
	for i in n:
		await get_tree().process_frame
