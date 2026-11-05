extends Node
## Capturas de los enemigos: poses (guardia, apuntando, agachado, caminando,
## recargando, muerto) y de cerca. Uso:
## godot --path . --fixed-fps 60 --resolution 1600x900 res://tests/screenshots/npc_shots.tscn -- --out=<carpeta>

var out_dir := "user://screenshots_npc"
var level: Node3D
var geo: Node3D


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_tree().create_timer(600.0).timeout.connect(func() -> void: get_tree().quit())
	level = Node3D.new()
	add_child(level)
	geo = Node3D.new()
	level.add_child(geo)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.55, 0.6, 0.66)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.7, 0.7, 0.7)
	e.ambient_light_energy = 0.8
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.environment = e
	level.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	sun.shadow_enabled = true
	level.add_child(sun)
	var fl := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 60)
	fl.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.42, 0.4, 0.35)
	fl.material_override = fm
	level.add_child(fl)
	var col := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(60, 1, 60)
	cs.shape = bs
	cs.position = Vector3(0, -0.5, 0)
	col.add_child(cs)
	level.add_child(col)
	var poses := [["guardia", "bandit_rifle", "akm"], ["apuntando", "bandit_rifle", "ak74"], ["agachado", "bandit_smg", "mp5"],
		["caminando", "bandit_boss", "hk416"], ["recargando", "bandit_marksman", "svd"], ["pistola", "bandit_pistol", "bersa9"],
		["escopeta", "bandit_shotgun", "shotgun"], ["muerto", "bandit_rifle", "akm"]]
	var npcs: Array[HumanNpc] = []
	for i in poses.size():
		var n := HumanNpc.new()
		n.loadout_id = poses[i][1]
		n.weapon_id = poses[i][2]
		n.ai_enabled = false
		n.seed_value = 77 + i
		n.position = Vector3(-7.0 + i * 2.0, 0, 0)
		n.rotation = Vector3(0, 0, 0)
		level.add_child(n)
		npcs.append(n)
	await _frames(10)
	var aim := Vector3(0, 1.4, 12)
	for i in poses.size():
		var n := npcs[i]
		var nm: String = poses[i][0]
		n.look_yaw = PI
		match nm:
			"apuntando", "pistola", "escopeta":
				n.raised = true
				n.aim_point = n.global_position + aim
			"agachado":
				n.raised = true
				n.crouching = true
				n.aim_point = n.global_position + Vector3(0, 0.9, 12)
			"caminando":
				n.raised = true
				n.aim_point = n.global_position + aim
				n.velocity = Vector3(0, 0, 1.5)
			"recargando":
				n.raised = true
				n.aim_point = n.global_position + aim
				n.reloading = true
	await _frames(40)
	var dead := npcs[7]
	var hi := HitInfo.new()
	hi.damage = 999.0
	hi.zone = "torso"
	hi.direction = Vector3(0.3, 0, -1)
	hi.penetration = 5.0
	dead.apply_hit(hi)
	# Caminando: se le da velocidad al cuerpo directamente (sin malla de navegación)
	var walker := npcs[3]
	for f in 50:
		walker.body.local_velocity = Vector3(0, 0, -1.5)
		await get_tree().process_frame
	var cam := Camera3D.new()
	level.add_child(cam)
	cam.current = true
	cam.fov = 50
	cam.global_position = Vector3(0, 1.5, 7.5)
	cam.look_at(Vector3(0, 0.9, 0))
	walker.body.local_velocity = Vector3(0, 0, -1.5)
	await _frames(2)
	await _shot("N0_poses_frente")
	cam.global_position = Vector3(10, 1.5, 4)
	cam.look_at(Vector3(0, 0.9, 0))
	await _frames(2)
	await _shot("N1_poses_costado")
	for i in [0, 1, 2, 4, 5, 7]:
		var n := npcs[i]
		var front := n.global_position + Vector3(0.6, 1.4, 3.0)
		if i == 7:
			front = n.global_position + Vector3(0.5, 2.6, 3.2)
		cam.global_position = front
		cam.look_at(n.global_position + Vector3(0, 0.9 if i != 7 else 0.2, 0))
		await _frames(2)
		await _shot("N2_%s" % poses[i][0])
		cam.global_position = n.global_position + Vector3(2.8, 1.3, 0.2)
		cam.look_at(n.global_position + Vector3(0, 1.0 if i != 7 else 0.2, 0))
		await _frames(2)
		await _shot("N3_%s_lado" % poses[i][0])
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(n + ".png"))
