extends Node
## Video del estrés (calma → medio → alto) con Movie Maker de Godot.
## Uso: godot --path . --fixed-fps 30 --resolution 1280x720 --write-movie out.avi res://tests/screenshots/stress_video.tscn

const Level := preload("res://world/test_greybox/test_greybox.tscn")

var level: Node3D
var player: Player
var bot: BotInputProvider
var caption: Label
var dummy: Vector3


func _ready() -> void:
	level = Level.instantiate()
	add_child(level)
	player = level.get_node("Player")
	bot = BotInputProvider.new()
	player.set_input_provider(bot)
	GameState.state = GameState.State.PLAYING
	var cl := CanvasLayer.new()
	cl.layer = 20
	add_child(cl)
	caption = Label.new()
	caption.add_theme_font_size_override("font_size", 34)
	caption.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	caption.add_theme_constant_override("shadow_offset_y", 2)
	caption.position = Vector2(40, 30)
	cl.add_child(caption)
	await _f(10)
	CombatWorld.get_for(player).hitstop_enabled = false
	dummy = (level.get_node("Geometry/Dummy15m") as Node3D).global_position + Vector3(0, 1.3, 0)
	var d := load("res://data/weapons/akm.tres") as WeaponData
	player.weapons.equip_weapon(d, 1)
	bot.select_slot(1)
	await _f(30)
	await _stage("CALMA", Vector3(30, 0.05, 28.0), Color(0.9, 0.9, 0.9))
	await _stage("ESTRÉS MEDIO", _zone("stress_medium"), Color(0.95, 0.75, 0.2))
	await _stage("ESTRÉS ALTO", _zone("stress_high"), Color(0.95, 0.35, 0.25))
	get_tree().quit()


func _stage(title: String, pos: Vector3, col: Color) -> void:
	caption.text = title
	caption.add_theme_color_override("font_color", col)
	player.teleport(pos, PI)
	await _f(2)
	# Llega al nivel de la zona de golpe (para el video)
	player.stress.value = player.stress.target
	_look(dummy)
	await _f(45)
	# Cadera: 5 tiros
	for i in 5:
		bot.press_fire()
		await _f(9)
	await _f(25)
	# Apuntando: la mira se mueve
	bot.aim = true
	await _f(25)
	_look(dummy)
	await _f(75)
	for i in 3:
		bot.press_fire()
		await _f(12)
	bot.aim = false
	await _f(20)
	# Recarga con el cargador vacío
	player.weapons.current().mag = 0
	player.weapons.current().malfunction = ""
	bot.press_reload()
	await _f(2)
	await _f(int(player.weapons.state_duration * 30.0) + 10)
	if player.weapons.current().malfunction == "unchambered":
		caption.text = title + " — se olvidó de montar: R"
		bot.press_fire()
		await _f(20)
		bot.press_reload()
		await _f(2)
		await _f(int(player.weapons.state_duration * 30.0) + 10)
	await _f(20)


func _zone(kind: String) -> Vector3:
	return (level.find_child("Zone_" + kind, true, false) as Node3D).global_position + Vector3(0, 0.05, 0.6)


func _look(target: Vector3) -> void:
	var d := target - player.camera.global_position
	player.yaw = atan2(-d.x, -d.z)
	player.pitch_angle = atan2(d.y, Vector2(d.x, d.z).length())


func _f(n: int) -> void:
	for i in n:
		await get_tree().process_frame
