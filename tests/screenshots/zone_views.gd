extends Node
## Capturas de la Isla Talavera en perspectiva: a la altura de los ojos desde varios
## lugares y un par de vistas altas, para ver árboles y relieve.

const Zone := preload("res://world/zone_talavera/zone_talavera.tscn")

var out_dir := "user://zone_views"
## [nombre, desde (x, alto sobre el piso, z), hacia (x, alto, z), fov]
const VIEWS := [
	["V1_puesto_hacia_el_reten", Vector3(-138, 1.7, 136), Vector3(-62, 2.5, 60), 70.0],
	["V2_camino_al_reten", Vector3(-95, 1.7, 86), Vector3(-62, 1.5, 60), 65.0],
	["V3_galpon_desde_la_loma", Vector3(-8, 2.2, 22), Vector3(35, 3.0, -25), 60.0],
	["V4_adentro_del_galpon", Vector3(16, 1.7, 4), Vector3(40, 2.5, -20), 72.0],
	["V5_estacion_de_bombeo", Vector3(100, 1.7, 140), Vector3(128, 2.0, 112), 65.0],
	["V6_orilla_del_rio", Vector3(150, 1.7, 30), Vector3(205, -0.5, 10), 70.0],
	["V7_chacra", Vector3(-82, 1.7, -92), Vector3(-105, 2.0, -115), 65.0],
	["V8_monte", Vector3(60, 1.7, 60), Vector3(80, 1.5, 20), 72.0],
	["V9_vista_alta_desde_el_puesto", Vector3(-205, 70, 205), Vector3(10, 0, -10), 55.0],
	["V10_vista_alta_desde_el_rio", Vector3(230, 55, -60), Vector3(20, 0, 20), 55.0],
]


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_tree().create_timer(500.0).timeout.connect(func() -> void: get_tree().quit())
	DebugTools.god_mode = true
	var zone := Zone.instantiate()
	add_child(zone)
	await _frames(120)
	for n in zone.find_children("*", "HumanNpc", true, false):
		(n as HumanNpc).ai_enabled = false
	var player := get_tree().get_first_node_in_group("player") as Player
	if player != null:
		player.teleport(Vector3(-150, 30, 150), 0.0)
		player.set_physics_process(false)
	for c in zone.find_children("*", "CanvasLayer", true, false):
		(c as CanvasLayer).visible = false
	var cam := Camera3D.new()
	zone.add_child(cam)
	cam.far = 1200.0
	cam.current = true
	for v: Array in VIEWS:
		var from: Vector3 = v[1]
		var to: Vector3 = v[2]
		var gf: float = zone.call("height", from.x, from.z)
		var gt: float = zone.call("height", to.x, to.z)
		cam.global_position = Vector3(from.x, gf + from.y, from.z)
		cam.fov = float(v[3])
		cam.look_at(Vector3(to.x, gt + to.y, to.z))
		await _frames(40)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out_dir.path_join(String(v[0]) + ".png"))
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
