extends SceneTree
## Vistas laterales de la toma de las manos (calibración). Uso:
## godot --path . -s res://tests/screenshots/hands_probe.gd -- --out=<carpeta> --ids=akm,pistol
var out := "user://hands"
var ids: PackedStringArray = ["akm"]
var arms: SkinnedArms
var cam: Camera3D

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.trim_prefix("--out=")
		if a.begins_with("--ids="): ids = a.trim_prefix("--ids=").split(",")
	DirAccess.make_dir_recursive_absolute(out)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.6, 0.65)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.7)
	root.add_child(env)
	var l := DirectionalLight3D.new()
	l.rotation_degrees = Vector3(-40, 30, 0)
	root.add_child(l)
	cam = Camera3D.new()
	cam.near = 0.01
	cam.fov = 40
	root.add_child(cam)
	cam.current = true
	arms = SkinnedArms.new()
	root.add_child(arms)
	_run.call_deferred()

func _run() -> void:
	for id in ids:
		var d := load("res://data/weapons/%s.tres" % id) as WeaponData
		var m := WeaponModelBuilder.build(d)
		root.add_child(m)
		m.position = WeaponViewmodel.HIP_POSE.get(d.model, Vector3(0.13, -0.14, -0.26))
		SkinnedArms.hide_procedural(m)
		var hr := m.get_node_or_null("HandR") as Node3D
		var trig: Vector3 = m.to_global(hr.get_meta("grip_top") as Vector3)
		# Marca roja en la cola del disparador (de POSES)
		var key := d.id if ArmsBuilder.POSES.has(d.id) else String(ArmsBuilder.FAMILY_POSE.get(d.model, "rifle"))
		var tp: Vector3 = ArmsBuilder.POSES[key]["trigger"]
		var mk := MeshInstance3D.new()
		var sm := SphereMesh.new(); sm.radius = 0.004; sm.height = 0.008
		mk.mesh = sm
		var mat := StandardMaterial3D.new(); mat.albedo_color = Color.RED; mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; mat.no_depth_test = true
		mk.material_override = mat
		m.add_child(mk)
		mk.position = tp
		for f in 3:
			await process_frame
			arms.update(m, 0.016)
		var c := m.to_global(tp)
		for v in [["der", Vector3(0.35, 0.0, 0.0)], ["izq", Vector3(-0.35, 0.0, 0.0)], ["arriba", Vector3(0.0, 0.35, 0.001)], ["fp", Vector3.ZERO]]:
			if v[0] == "fp":
				cam.global_transform = Transform3D.IDENTITY
				cam.fov = 62
			else:
				cam.fov = 40
				cam.global_transform = Transform3D.IDENTITY.translated(c + v[1]).looking_at(c, Vector3.UP if v[0] != "arriba" else Vector3.FORWARD)
			for f in 2:
				arms.update(m, 0.016)
				await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(out.path_join("%s_%s.png" % [id, v[0]]))
		m.queue_free()
		await process_frame
	quit()
