extends Node
## Video de la respiración con visor (R-700 a 200 m): libre, aguantando (Shift) y sin aire.
## Uso: godot --path . --fixed-fps 30 --resolution 1280x720 --write-movie out.avi res://tests/screenshots/breath_video.tscn

const Level := preload("res://world/test_greybox/test_greybox.tscn")

var level: Node3D
var player: Player
var bot: BotInputProvider
var caption: Label


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
	caption.add_theme_font_size_override("font_size", 30)
	caption.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	caption.add_theme_constant_override("shadow_offset_y", 2)
	caption.position = Vector2(40, 30)
	cl.add_child(caption)
	await _f(10)
	var d := load("res://data/weapons/rem700.tres") as WeaponData
	player.weapons.equip_weapon(d, 1)
	bot.select_slot(1)
	player.teleport(Vector3(30, 0.05, 31.0), PI)
	await _f(40)
	var target := (level.get_node("Geometry/Target200m") as Node3D).global_position + Vector3(0, 1.5, 0)
	bot.aim = true
	await _f(30)
	_look(target)
	bot.press_zoom(6)
	await _f(10)
	_look(target)
	caption.text = "RESPIRANDO"
	await _f(150)
	caption.text = "SHIFT: AGUANTANDO LA RESPIRACIÓN"
	bot.sprint = true
	await _f(100)
	bot.press_fire()
	await _f(80)
	caption.text = "SE QUEDA SIN AIRE"
	await _f(130)
	bot.sprint = false
	caption.text = "RECUPERANDO"
	await _f(90)
	get_tree().quit()


func _look(target: Vector3) -> void:
	var dv := target - player.camera.global_position
	player.yaw = atan2(-dv.x, -dv.z)
	player.pitch_angle = atan2(dv.y, Vector2(dv.x, dv.z).length())


func _f(n: int) -> void:
	for i in n:
		await get_tree().process_frame
