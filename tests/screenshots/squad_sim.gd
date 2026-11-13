extends Node
## Simulación: los 8 militares de la zona de combate contra el jugador (invulnerable,
## quieto a cubierto en la entrada). Registra roles, distancias, tiros, voces, señas y
## humo; saca capturas desde arriba cada tanto.

const Level := preload("res://world/test_greybox/test_greybox.tscn")

var out_dir := "user://squad_sim"
var said := {}
var shots := 0
var shots_blind := 0
## Capturas (lento sin placa de video): --shots
var shots_enabled := false
var secs := 45


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		if arg == "--shots":
			shots_enabled = true
		if arg.begins_with("--secs="):
			secs = int(arg.trim_prefix("--secs="))
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_tree().create_timer(600.0).timeout.connect(func() -> void: get_tree().quit())
	DebugTools.god_mode = true
	ArenaConsole.faction = "military"
	var level := Level.instantiate()
	add_child(level)
	var player: Player = level.get_node("Player")
	player.set_input_provider(BotInputProvider.new())
	GameState.state = GameState.State.PLAYING
	await _frames(90)
	# El jugador entra a la zona y se queda detrás del muro bajo de la entrada
	player.teleport(Vector3(-49, 0.05, -60.2), PI)
	var npcs: Array = level.get("_arena_npcs")
	print("SIM militares: ", npcs.size())
	EventBus.noise_emitted.connect(func(_p: Vector3, r: float, src: Node) -> void:
		if src is HumanNpc and r >= 30.0:
			shots += 1
			if not (src as HumanNpc).brain.target_visible:
				shots_blind += 1)
	# Contar frases: envolvemos speak/play_signal mirando los nodos cada cuadro
	var cam := Camera3D.new()
	level.add_child(cam)
	cam.global_position = Vector3(-60, 16, -56)
	cam.look_at(Vector3(-50, 0, -76))
	cam.fov = 70
	cam.current = true
	for c in level.find_children("*", "CanvasLayer", true, false):
		(c as CanvasLayer).visible = false
	# Lo descubren (como si lo hubieran oído entrar)
	(npcs[0] as HumanNpc).brain.on_callout(player.global_position)
	var t := 0.0
	var shot_i := 0
	var last_voice := {}
	var signals := 0
	for f in 60 * secs:
		await get_tree().physics_frame
		t += 1.0 / 60.0
		for n in npcs:
			var h := n as HumanNpc
			if not is_instance_valid(h) or h.dead:
				continue
			if h._voice.playing and last_voice.get(h, null) != h._voice.stream:
				last_voice[h] = h._voice.stream
				var k := String(h._voice.stream.resource_path.get_file().get_basename())
				k = k.substr(0, k.rfind("_", k.rfind("_") - 1)) + ("(grito)" if h._voice.unit_size > 5.0 else "(hablado)")
				said[k] = int(said.get(k, 0)) + 1
			elif not h._voice.playing:
				last_voice[h] = null
			if h.body.signal_kind() != "" and h.body._sig_t < 1.0 / 60.0 + 0.0001:
				signals += 1
		if f % 180 == 0:
			var roles := {}
			var dsum := 0.0
			var alive := 0
			for n in npcs:
				var h := n as HumanNpc
				if h.dead:
					continue
				alive += 1
				var r: String = h.brain.role if h.brain.role != "" else ("st:" + NpcBrain.State.keys()[h.brain.state])
				roles[r] = int(roles.get(r, 0)) + 1
				dsum += h.global_position.distance_to(player.global_position)
			var sq: Squad = (npcs[0] as HumanNpc).squad_obj
			print("SIM t=%2ds modo=%-6s dist_media=%5.1f tiros=%3d (sin verlo %3d) humo=%d roles=%s" % [int(t), sq.mode if sq else "-",
				dsum / maxf(alive, 1), shots, shots_blind, get_tree().get_nodes_in_group("smoke_cloud").size(), roles])
		if shots_enabled and f in [60 * 3, 60 * 7, 60 * 12]:
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(out_dir.path_join("S%d_t%02d.png" % [shot_i, int(t)]))
			shot_i += 1
	print("SIM frases: ", said)
	print("SIM señas: ", signals)
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
