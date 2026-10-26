extends Node3D
## Visor de modelos de armas: una imagen de costado (ortográfica) y otra en
## tres cuartos por arma, sobre fondo neutro.
## Uso: godot --path . --resolution 1400x700 res://tests/screenshots/model_viewer.tscn -- --out=<carpeta> [--ids=ak74,svd]

var out_dir := "user://model_viewer"
var ids: PackedStringArray = []
var with_arms := false
var _cam: Camera3D
var _holder: Node3D


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		if arg == "--arms":
			with_arms = true
		if arg.begins_with("--ids="):
			ids = arg.trim_prefix("--ids=").split(",", false)
	DirAccess.make_dir_recursive_absolute(out_dir)
	if ids.is_empty():
		ids = PackedStringArray(JSON.parse_string(FileAccess.get_file_as_string("res://data/weapons/catalog.json")))
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.62, 0.64, 0.66)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.7, 0.72)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 35, 0)
	sun.light_energy = 1.3
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-10, -140, 0)
	fill.light_energy = 0.45
	add_child(fill)
	_cam = Camera3D.new()
	add_child(_cam)
	_holder = Node3D.new()
	add_child(_holder)
	for id in ids:
		var d := load("res://data/weapons/%s.tres" % id) as WeaponData
		var m := WeaponModelBuilder.build(d)
		if not with_arms:
			for n in ["HandR", "HandL", "HookR", "HookL"]:
				var h := m.find_child(n, true, false)
				if h != null:
					h.free()
		_holder.add_child(m)
		var aabb := _aabb(m)
		var center := aabb.get_center()
		# De costado (lado derecho), ortográfica
		_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		_cam.size = maxf(aabb.size.z * 1.08, aabb.size.y * 2.2)
		_cam.global_transform = Transform3D(Basis.looking_at(Vector3(-1, 0, 0)), center + Vector3(2, 0, 0))
		await _frames(3)
		await _shot("%s_lado" % id)
		# Tres cuartos desde adelante-arriba-derecha, perspectiva
		_cam.projection = Camera3D.PROJECTION_PERSPECTIVE
		_cam.fov = 30
		var dir := Vector3(0.9, 0.45, -0.75).normalized()
		var dist := aabb.size.z * 1.75
		_cam.global_transform = Transform3D(Basis.looking_at(-dir), center + dir * dist)
		await _frames(3)
		await _shot("%s_34" % id)
		# Primeros planos de las manos
		if with_arms:
			for hn in ["HandR", "HandL", "HookR", "HookL"]:
				var hand := m.find_child(hn, true, false) as Node3D
				if hand == null:
					continue
				if hn.begins_with("Hook"):
					# Mano de montar: en la bola de la manija, del lado que corresponde
					var ch := m.get_node("Charging") as Node3D
					var kn: Vector3 = ch.get_meta("knob", Vector3.ZERO)
					if (kn.x + ch.position.x >= 0.0) != (hn == "HookR"):
						continue
					hand.position = ch.position + kn
					hand.visible = true
				var glove := hand.get_node("Glove") as MeshInstance3D
				var hb := glove.global_transform * glove.get_aabb()
				# La mano es la parte delantera del guante (el antebrazo va atrás)
				var hc := hb.get_center()
				hc.z = hb.position.z + 0.06
				hc.y = hb.end.y - 0.05
				for k in 2:
					var vd := Vector3(0.8, 0.35, -0.5).normalized() if k == 0 else Vector3(-0.8, 0.3, -0.5).normalized()
					_cam.projection = Camera3D.PROJECTION_PERSPECTIVE
					_cam.fov = 40
					_cam.global_transform = Transform3D(Basis.looking_at(-vd), hc + vd * 0.32)
					await _frames(3)
					await _shot("%s_%s_%s" % [id, hn, "der" if k == 0 else "izq"])
		# Desde atrás a la altura de la mira (lo que ve el tirador)
		var sight := m.get_node("Sight") as Node3D
		_cam.fov = 40
		_cam.global_transform = Transform3D(Basis.IDENTITY, sight.global_position + Vector3(0, 0.0, 0.33))
		await _frames(3)
		await _shot("%s_mira" % id)
		m.free()
	print("VISOR_OK -> ", ProjectSettings.globalize_path(out_dir))
	get_tree().quit()


func _aabb(n: Node) -> AABB:
	var box := AABB()
	var first := true
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		var b := mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


func _frames(k: int) -> void:
	for i in k:
		await get_tree().process_frame


func _shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg(out_dir.path_join(n + ".jpg"), 0.85)
