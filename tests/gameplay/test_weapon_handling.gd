extends TestCase
## Manejo del arma: retroceso desde la cadera según el calibre y el arma que choca con
## la pared (se levanta, no se apunta ni se tira).

const PLAYER := preload("res://entities/player/player.tscn")

var level: Node3D
var player: Player
var bot: BotInputProvider
var geo: Node3D


func _arena() -> void:
	level = Node3D.new()
	add_child(level)
	geo = Node3D.new()
	level.add_child(geo)
	_box(Vector3(0, -0.5, 0), Vector3(60, 1, 60))
	_box(Vector3(0, 1.5, -10), Vector3(8, 3, 0.4))
	level.add_child(DirectionalLight3D.new())
	player = PLAYER.instantiate() as Player
	level.add_child(player)
	bot = BotInputProvider.new()
	player.set_input_provider(bot)
	await physics_frames(5)
	CombatWorld.get_for(player).hitstop_enabled = false
	DebugTools.infinite_ammo = true


func _box(pos: Vector3, size: Vector3) -> void:
	var b := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	b.add_child(cs)
	b.position = pos
	geo.add_child(b)


func after_each() -> void:
	DebugTools.infinite_ammo = false
	if level != null:
		level.queue_free()
		level = null
	await process_frames(2)


func _climb(w: String, slot: int, aim: bool) -> float:
	player.weapons.equip_weapon(load("res://data/weapons/%s.tres" % w), slot)
	bot.select_slot(slot)
	player.teleport(Vector3(10, 0.05, 10), 0.0)
	player.pitch_angle = 0.0
	await physics_frames(50)
	bot.aim = aim
	await physics_frames(30)
	var p0 := player.pitch_angle
	bot.press_fire()
	await physics_frames(3)
	var climb := player.pitch_angle - p0
	bot.aim = false
	await physics_frames(40)
	return climb


func test_hip_fire_kicks_more_than_pistols() -> void:
	await _arena()
	var rifle_hip := await _climb("akm", 1, false)
	var rifle_ads := await _climb("akm", 1, true)
	var pistol_hip := await _climb("pistol", 3, false)
	var pistol_ads := await _climb("pistol", 3, true)
	assert_gt(rifle_hip, rifle_ads * 2.0, "fusil desde la cadera: salta mucho más que apuntando (%.4f / %.4f)" % [rifle_hip, rifle_ads])
	assert_lt(pistol_hip, pistol_ads * 1.8, "pistola: parecido (%.4f / %.4f)" % [pistol_hip, pistol_ads])


func test_weapon_blocked_against_wall() -> void:
	await _arena()
	var ws := player.weapons
	player.teleport(Vector3(0, 0.05, -9.45), 0.0)  # pegado a la pared, mirando hacia ella
	player.pitch_angle = 0.0
	await physics_frames(50)
	assert_gt(ws.wall_amount, WeaponController.WALL_BLOCK, "el arma choca con la pared")
	bot.aim = true
	await physics_frames(30)
	assert_false(ws.aiming, "no se puede apuntar")
	var mag0 := ws.current().mag
	bot.press_fire()
	await physics_frames(10)
	assert_eq(ws.current().mag, mag0, "ni tirar")
	bot.aim = false
	# Un paso atrás: libre
	player.teleport(Vector3(0, 0.05, -7.5), 0.0)
	await physics_frames(30)
	assert_lt(ws.wall_amount, 0.05, "lejos de la pared, libre")
