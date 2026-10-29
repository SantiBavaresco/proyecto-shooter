extends SceneTree
## Calibración de modelos: vista lateral (+X) y superior ortográficas del arma armada,
## y un JSON con la cámara y los marcadores para dibujar la grilla encima.
var out := "user://calib"
var ids: PackedStringArray = []

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.trim_prefix("--out=")
		if a.begins_with("--ids="): ids = a.trim_prefix("--ids=").split(",")
	DirAccess.make_dir_recursive_absolute(out)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.85, 0.87, 0.9)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.9, 0.9, 0.9)
	root.add_child(env)
	var l := DirectionalLight3D.new(); l.rotation_degrees = Vector3(-35, 60, 0); root.add_child(l)
	_run.call_deferred()

func _run() -> void:
	get_root().get_tree().create_timer(240.0).timeout.connect(quit)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	root.add_child(cam); cam.current = true
	for id in ids:
		var d := load("res://data/weapons/%s.tres" % id) as WeaponData
		var m := WeaponModelBuilder.build(d)
		root.add_child(m)
		for n: Node in m.find_children("*", "Node3D", true, false):
			if n.has_meta("kind"):
				(n as Node3D).visible = false
		await process_frame
		var info := {"id": id, "markers": {}}
		for mk in ["Sight", "Muzzle", "Ejection"]:
			info["markers"][mk] = _a((m.get_node(mk) as Node3D).position)
		for part in ["Mag", "Charging", "Bolt", "Slide", "Cylinder", "Barrels"]:
			var n := m.get_node_or_null(part) as Node3D
			if n:
				info["markers"][part] = _a(n.position)
				if n.has_meta("knob"):
					info["markers"][part + "_knob"] = _a(n.position + n.basis * (n.get_meta("knob") as Vector3))
		var hr := m.get_node_or_null("HandR") as Node3D
		if hr:
			info["markers"]["grip_top"] = _a(hr.get_meta("grip_top"))
			info["markers"]["trigger"] = _a(hr.get_meta("trigger"))
		var hl := m.get_node_or_null("HandL") as Node3D
		if hl == null: hl = m.get_node_or_null("Barrels/HandL") as Node3D
		if hl:
			info["markers"]["forend"] = _a(hl.get_meta("palm"))
		var ab := AABB(); var f := true
		for mi: MeshInstance3D in m.find_children("*", "MeshInstance3D", true, false):
			if not mi.is_visible_in_tree(): continue
			var b := mi.global_transform * mi.get_aabb()
			if f: ab = b; f = false
			else: ab = ab.merge(b)
		info["aabb"] = [_a(ab.position), _a(ab.size)]
		var c := ab.get_center()
		var span := maxf(ab.size.z, ab.size.y * 1.6) * 1.08
		cam.size = span / 1.6  # vertical (viewport 1600x1000)
		info["cam_size"] = cam.size
		info["center"] = _a(c)
		cam.global_transform = Transform3D.IDENTITY.translated(c + Vector3(2, 0, 0)).looking_at(c, Vector3.UP)
		cam.near = 0.01; cam.far = 10
		for k in 3: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out.path_join("%s_side.png" % id))
		cam.global_transform = Transform3D.IDENTITY.translated(c + Vector3(0, 2, 0)).looking_at(c, Vector3.LEFT)
		for k in 3: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out.path_join("%s_top.png" % id))
		var fa := FileAccess.open(out.path_join("%s.json" % id), FileAccess.WRITE)
		fa.store_string(JSON.stringify(info))
		fa.close()
		m.queue_free()
		await process_frame
	quit()

func _a(v: Vector3) -> Array:
	return [snappedf(v.x, 0.0001), snappedf(v.y, 0.0001), snappedf(v.z, 0.0001)]
