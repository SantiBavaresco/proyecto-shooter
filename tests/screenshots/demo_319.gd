extends Node3D
## Capturas de la 3.1.9: animales con cuerpos redondeados (perro, jabalí, carpincho),
## jabalí al lado de una persona (escala), sangre (salpicadura en pared, charco que
## corre en pendiente, arrastre).

const PLAYER := preload("res://entities/player/player.tscn")

var out := "user://demo319"
var player: Player
var geo: Node3D
var cam: Camera3D


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out)
	get_tree().create_timer(300.0).timeout.connect(func() -> void: get_tree().quit())
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
	add_child(geo)
	_box(Vector3(0, -0.5, 0), Vector3(120, 1, 120), Color(0.42, 0.45, 0.35), Vector3.ZERO)
	_box(Vector3(20, 1.5, -6), Vector3(8, 3, 0.4), Color(0.6, 0.57, 0.52), Vector3.ZERO)       # pared
	_box(Vector3(-20, 0.0, 0), Vector3(10, 1, 10), Color(0.42, 0.45, 0.35), Vector3(0.0, 0, 0.18))  # rampa
	player = PLAYER.instantiate() as Player
	add_child(player)
	player.set_input_provider(BotInputProvider.new())
	player.teleport(Vector3(0, 0.05, 30), 0.0)
	await _f(20)
	CombatWorld.get_for(player).hitstop_enabled = false
	cam = Camera3D.new()
	add_child(cam)
	for cl in find_children("*", "CanvasLayer", true, false):
		(cl as CanvasLayer).visible = false

	# 1) Los tres animales y una persona de referencia
	var i := 0
	for sp in ["dog", "boar", "capy"]:
		var pk := AnimalPack.new()
		pk.species = sp
		pk.count = 1
		pk.seed_value = 2 + i
		pk.position = Vector3([-4.2, -1.0, 2.4][i], 0.1, 0)
		add_child(pk)
		i += 1
	var n := HumanNpc.new()
	n.loadout_id = "bandit_rifle"
	n.ai_enabled = false
	n.position = Vector3(4.6, 0.05, 0)
	add_child(n)
	await _f(30)
	for a in find_children("*", "Animal", true, false):
		(a as Animal).set_physics_process(false)
		(a as Animal).body.rotation.y = PI * 0.5
	cam.global_position = Vector3(0.2, 1.3, 5.6)
	cam.look_at(Vector3(0.2, 0.6, 0))
	cam.current = true
	await _shot("1_animales_redondeados")

	# 2) Salpicadura en la pared de atrás (tiros al cuerpo)
	var b := find_children("*", "Animal", true, false)[1] as Animal
	b.global_position = Vector3(20, 0.05, -4)
	await _f(2)
	for k in 3:
		var hi := HitInfo.new()
		hi.damage = 15.0
		hi.zone = "torso"
		hi.direction = Vector3(randf_range(-0.15, 0.15), randf_range(-0.05, 0.1), -1).normalized()
		hi.position = b.body.center()
		hi.source = player
		b.apply_hit(hi)
	await _f(30)
	b.global_position = Vector3(40, 0.05, 40)
	await _f(2)
	cam.global_position = Vector3(20, 1.5, -1.0)
	cam.look_at(Vector3(20, 1.0, -6))
	await _shot("2_salpicadura_en_pared")

	# 3) Charco en pendiente: corre para abajo
	Blood.pool(player, Vector3(-20, 1.0, 0), 1.0, 2.0)
	await _f(60 * 5)
	cam.global_position = Vector3(-20, 3.5, 3.5)
	cam.look_at(Vector3(-20, 0.3, 0))
	await _shot("3_charco_que_corre")

	# 4) Arrastre (rastro)
	var p0 := Vector3(5, 0, 12)
	for k in 8:
		Blood.smear(player, p0 + Vector3(k * 0.45, 0, sin(k * 0.6) * 0.3), Vector3(1, 0, 0.2))
	cam.global_position = Vector3(6.5, 3.0, 15.0)
	cam.look_at(Vector3(6.5, 0, 12))
	await _shot("4_arrastre")
	get_tree().quit()


func _box(pos: Vector3, size: Vector3, col: Color, rot: Vector3) -> void:
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
	b.rotation = rot
	geo.add_child(b)


func _shot(name: String) -> void:
	await _f(3)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))


func _f(n: int) -> void:
	for i in n:
		await get_tree().process_frame
