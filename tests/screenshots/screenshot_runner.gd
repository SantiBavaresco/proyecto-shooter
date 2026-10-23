extends Node
## Saca capturas de las pantallas principales para revisar a ojo.
## Necesita pantalla (no --headless). Uso:
##   godot --path . --fixed-fps 60 --resolution 1600x900 res://tests/screenshots/screenshot_runner.tscn -- --out=<carpeta>

const TitleScreen := preload("res://ui/title/title_screen.tscn")
const Level := preload("res://world/test_greybox/test_greybox.tscn")
const OptionsMenu := preload("res://ui/options/options_menu.gd")

var out_dir: String = "user://screenshots"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	await _frames(3)

	# 1. Título
	var title := TitleScreen.instantiate()
	add_child(title)
	await _frames(4)
	await _shot("01_titulo")
	title.queue_free()
	await _frames(2)

	# Nivel con bot
	var level := Level.instantiate()
	add_child(level)
	var player: Player = level.get_node("Player")
	var bot := BotInputProvider.new()
	player.set_input_provider(bot)
	GameState.state = GameState.State.PLAYING
	await _frames(10)

	# 2. Vista general desde el spawn
	await _place(player, Vector3(0, 0.05, 6), 0.35, -0.12)
	await _shot("02_pista_general")

	# 3. Saltos y rampas
	await _place(player, Vector3(6, 0.05, 2), -0.55, -0.05)
	await _shot("03_saltos_y_rampas")

	# 4. Dentro del túnel, agachado
	bot.crouch = true
	await _place(player, Vector3(-10, 0.05, -2.5), 0.0, -0.05)
	bot.move = Vector2(0, 1)
	await _frames(70)
	bot.move = Vector2.ZERO
	await _frames(20)
	await _shot("04_tunel_agachado")
	bot.crouch = false

	# 5. Esquina: inclinado a la derecha mirando los postes
	await _place(player, Vector3(2.7, 0.05, -43.4), -0.25, 0.0)
	bot.lean = 1.0
	await _frames(40)
	await _shot("05_inclinacion_esquina")
	bot.lean = 0.0
	await _frames(30)

	# 6. Contenedores
	await _place(player, Vector3(-12, 0.05, -30), 0.75, 0.05)
	await _shot("06_contenedores")

	# 7. Datos de rendimiento (F1)
	await _place(player, Vector3(0, 0.05, 6), 0.35, -0.12)
	DebugTools.toggle_overlay()
	await _frames(20)
	await _shot("07_debug_f1")
	DebugTools.toggle_overlay()

	# 8. Pausa
	GameState.set_paused(true)
	await _frames(6)
	await _shot("08_pausa")
	GameState.set_paused(false)
	await _frames(4)

	# 9. Opciones → Controles
	var opts := Control.new()
	opts.set_script(OptionsMenu)
	var layer := CanvasLayer.new()
	layer.layer = 60
	add_child(layer)
	layer.add_child(opts)
	await _frames(4)
	(opts.find_children("*", "TabContainer", true, false)[0] as TabContainer).current_tab = 1
	await _frames(4)
	await _shot("09_opciones_controles")

	print("CAPTURAS_OK -> ", ProjectSettings.globalize_path(out_dir))
	get_tree().quit()


func _place(player: Player, pos: Vector3, yaw: float, pitch: float) -> void:
	player.teleport(pos, yaw)
	player.pitch_angle = pitch
	await _frames(40)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := out_dir.path_join(shot_name + ".png")
	img.save_png(path)
	print("captura: ", path)
