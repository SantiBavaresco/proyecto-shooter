extends Node
## Capturas del ragdoll: 4 enemigos de la zona de combate muertos desde distintos
## lados (uno contra un muro bajo), a mitad de la caída y ya en el piso.

const Level := preload("res://world/test_greybox/test_greybox.tscn")

var out_dir := "user://screenshots_ragdoll"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_tree().create_timer(400.0).timeout.connect(func() -> void: get_tree().quit())
	DebugTools.god_mode = true
	var level := Level.instantiate()
	add_child(level)
	var player: Player = level.get_node("Player")
	player.set_input_provider(BotInputProvider.new())
	GameState.state = GameState.State.PLAYING
	await _frames(90)
	var npcs: Array = level.get("_arena_npcs")
	# Lugar despejado de la zona, con un muro bajo (jersey en -49,-62) de un lado
	var spots := [
		[Vector3(-49, 0.05, -60.6), 0.0, Vector3(0, 0, -1), 1.35],  # de frente, cae contra el muro bajo
		[Vector3(-45, 0.05, -58), PI * 0.5, Vector3(1, 0, 0.2), 1.45],  # de costado
		[Vector3(-53, 0.05, -57), PI, Vector3(0, 0, -1), 1.6],  # por la espalda, a la cabeza
		[Vector3(-41, 0.05, -61), -0.6, Vector3(-0.5, 0, 0.8), 0.9],  # a las piernas
	]
	for i in mini(npcs.size(), spots.size()):
		var n := npcs[i] as HumanNpc
		n.ai_enabled = false
		n.global_position = spots[i][0]
		n.rotation = Vector3(0, spots[i][1], 0)
		n._yaw = spots[i][1]
		n.raised = i % 2 == 0
	for i in range(spots.size(), npcs.size()):
		(npcs[i] as Node3D).global_position = Vector3(-60, 0.05, -90)
	player.teleport(Vector3(-47, 0.05, -50), 0.0)
	var cam := Camera3D.new()
	level.add_child(cam)
	cam.global_position = Vector3(-38.5, 3.4, -52.5)
	cam.look_at(Vector3(-47.5, 0.6, -60))
	cam.fov = 58
	cam.current = true
	for c in level.find_children("*", "CanvasLayer", true, false):
		(c as CanvasLayer).visible = false
	await _frames(60)
	await _shot("R0_antes")
	for i in mini(npcs.size(), spots.size()):
		var n := npcs[i] as HumanNpc
		var hi := HitInfo.new()
		hi.damage = 500.0
		hi.zone = "torso"
		hi.penetration = 6.0
		hi.direction = (spots[i][2] as Vector3).normalized()
		hi.position = n.global_position + Vector3(0, float(spots[i][3]), 0)
		n.apply_hit(hi)
	await _phys(14)
	await _shot("R1_cayendo")
	await _phys(30)
	await _shot("R2_cayendo")
	await _phys(60 * 4)
	await _shot("R3_en_el_piso")
	var c1 := (npcs[1] as HumanNpc).body.ragdoll.center()
	cam.global_position = c1 + Vector3(-1.4, 1.5, 1.6)
	cam.look_at(c1 + Vector3(0, 0.05, 0))
	await _frames(10)
	await _shot("R4_cerca")
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _phys(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(n + ".png"))
