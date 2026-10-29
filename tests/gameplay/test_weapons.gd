extends TestCase
## Armas en el polígono de tiro, manejadas por el bot.

const LEVEL := preload("res://world/test_greybox/test_greybox.tscn")
const CX := 30.0
const LINE_Z := 30.0

var level: Node3D
var player: Player
var bot: BotInputProvider
var weapons: WeaponController


func before_each() -> void:
	DebugTools.infinite_ammo = false
	level = LEVEL.instantiate()
	add_child(level)
	player = level.get_node("Player")
	bot = BotInputProvider.new()
	player.set_input_provider(bot)
	weapons = player.weapons
	await physics_frames(5)
	CombatWorld.get_for(player).hitstop_enabled = false
	CombatWorld.get_for(player).rng.seed = 99
	# Estas pruebas usan el Fusil FMR (el slot 1 inicial ahora es la carabina importada)
	weapons.equip_weapon(load("res://data/weapons/rifle.tres") as WeaponData, 1)
	await physics_frames(40)


func after_each() -> void:
	DebugTools.infinite_ammo = false
	Engine.time_scale = 1.0
	level.queue_free()
	await process_frames(1)


func _ready_at(pos: Vector3) -> void:
	player.teleport(pos, PI)  # mirando hacia +Z (el polígono)
	player.pitch_angle = 0.0
	await physics_frames(40)  # que termine de sacar el arma


## Apunta la cámara a un punto del mundo.
func _look_at(target: Vector3) -> void:
	var eye := player.camera.global_position
	var d := target - eye
	player.yaw = atan2(-d.x, -d.z)
	player.pitch_angle = atan2(d.y, Vector2(d.x, d.z).length())
	await process_frames(2)


func _dummy(name: String) -> Mannequin:
	return level.get_node("Geometry/%s" % name) as Mannequin


func _shoot_once() -> void:
	bot.press_fire()
	await physics_frames(int(ceil(weapons.current_data().seconds_per_shot() * 60.0)) + 2)


func test_starts_with_rifle_ready() -> void:
	await _ready_at(Vector3(CX, 0.05, LINE_Z))
	assert_eq(weapons.current_slot, 1)
	assert_eq(weapons.state, WeaponController.State.READY)
	assert_eq(weapons.current().mag, 20)


func test_fire_consumes_ammo_and_spawns_projectile() -> void:
	await _ready_at(Vector3(CX, 0.05, LINE_Z))
	bot.press_fire()
	await physics_frames(1)
	assert_eq(weapons.current().mag, 19)
	assert_gt(float(CombatWorld.get_for(player).active_projectiles()), 0.0)


func test_torso_hit_damage() -> void:
	var d := _dummy("Dummy10m")
	d.reset()
	await _ready_at(Vector3(CX - 5.0, 0.05, LINE_Z + 2.0))
	bot.aim = true
	await physics_frames(30)
	await _look_at(d.global_position + Vector3(0, 1.18, 0))
	await _shoot_once()
	await physics_frames(5)
	assert_eq(d.hits_received.size(), 1, "un impacto")
	if d.hits_received.is_empty():
		return
	assert_eq(d.hits_received[0].zone, "torso")
	assert_near(d.hits_received[0].damage, 48.0, 2.0, "daño de torso ≈ daño base")


func test_headshot_kills() -> void:
	var d := _dummy("Dummy10m")
	d.reset()
	await _ready_at(Vector3(CX - 5.0, 0.05, LINE_Z + 2.0))
	bot.aim = true
	await physics_frames(30)
	await _look_at(d.global_position + Vector3(0, 1.68, 0))
	await _shoot_once()
	await physics_frames(5)
	assert_true(d.hits_received.size() > 0 and d.hits_received[0].zone == "head_core", "tiro al centro de la cabeza")
	assert_true(d.down, "un tiro de fusil en la cabeza derriba")


func test_ads_aligns_sight_with_screen_center() -> void:
	await _ready_at(Vector3(CX, 0.05, LINE_Z))
	for slot in [1, 2, 3]:
		bot.aim = false
		bot.select_slot(slot)
		await physics_frames(50)
		bot.aim = true
		await physics_frames(40)
		await process_frames(30)
		assert_eq(weapons.current_slot, slot)
		var sight := weapons.sight_node().global_position  # espacio de cámara del arma
		assert_near(sight.x, 0.0, 0.003, "slot %d: mira centrada en X" % slot)
		assert_near(sight.y, 0.0, 0.003, "slot %d: mira centrada en Y" % slot)
		assert_lt(sight.z, -0.05, "slot %d: mira delante del ojo" % slot)
	bot.aim = false


func test_reload_moves_ammo_from_reserve() -> void:
	await _ready_at(Vector3(CX, 0.05, LINE_Z))
	for i in 3:
		await _shoot_once()
	assert_eq(weapons.current().mag, 17)
	bot.press_reload()
	await physics_frames(2)
	assert_eq(weapons.state, WeaponController.State.RELOADING)
	bot.press_fire()
	await physics_frames(2)
	assert_eq(weapons.current().mag, 17, "no dispara recargando")
	await physics_frames(int(weapons.current_data().reload_time * 60.0) + 5)
	assert_eq(weapons.current().mag, 20)
	assert_eq(weapons.current().reserve, 97)


func test_auto_mode() -> void:
	await _ready_at(Vector3(CX, 0.05, LINE_Z))
	bot.press_fire_mode()
	await physics_frames(2)
	assert_eq(weapons.current().mode(), "auto")
	bot.fire = true
	await physics_frames(30)  # 0,5 s a 650 disparos/min ≈ 5–6 disparos
	bot.fire = false
	var shots := 20 - weapons.current().mag
	assert_gt(float(shots), 3.0)
	assert_lt(float(shots), 8.0)


func test_semi_needs_separate_presses() -> void:
	await _ready_at(Vector3(CX, 0.05, LINE_Z))
	bot.fire = true
	await physics_frames(30)
	bot.fire = false
	assert_eq(weapons.current().mag, 19, "mantener el gatillo en tiro a tiro dispara una vez")


func test_shotgun_two_shots_and_pellets() -> void:
	await _ready_at(Vector3(CX, 0.05, LINE_Z))
	bot.select_slot(2)
	await physics_frames(50)
	assert_eq(weapons.current_slot, 2)
	var combat := CombatWorld.get_for(player)
	await physics_frames(200)  # que mueran los proyectiles anteriores
	bot.press_fire()
	await physics_frames(1)
	assert_eq(combat.active_projectiles(), 9, "9 perdigones")
	await physics_frames(12)
	bot.press_fire()
	await physics_frames(12)
	assert_eq(weapons.current().mag, 0)
	bot.press_fire()
	await physics_frames(12)
	assert_eq(weapons.current().mag, 0, "sin cartuchos no dispara")


func test_switch_weapons() -> void:
	await _ready_at(Vector3(CX, 0.05, LINE_Z))
	bot.select_slot(3)
	await physics_frames(3)
	assert_eq(weapons.state, WeaponController.State.HOLSTER)
	await physics_frames(50)
	assert_eq(weapons.current_slot, 3)
	assert_eq(weapons.state, WeaponController.State.READY)


func test_recoil_raises_and_recovers() -> void:
	await _ready_at(Vector3(CX, 0.05, LINE_Z))
	var p0 := player.pitch_angle
	bot.press_fire()
	await process_frames(8)
	var peak := player.pitch_angle
	assert_gt(peak - p0, deg_to_rad(0.6), "el retroceso sube la mira")
	await process_frames(90)
	assert_lt(player.pitch_angle, peak - deg_to_rad(0.3), "recupera una parte")
	assert_gt(player.pitch_angle, p0 - 0.001, "no baja más de donde estaba")


func test_cannot_fire_while_sprinting() -> void:
	await _ready_at(Vector3(CX, 0.05, LINE_Z))
	bot.move = Vector2(0, 1)
	bot.sprint = true
	await physics_frames(20)
	assert_true(player.is_sprinting)
	bot.press_fire()
	await physics_frames(3)
	assert_eq(weapons.current().mag, 20, "corriendo no dispara")
	bot.release_all()


func test_aim_blocks_sprint_and_slows() -> void:
	await _ready_at(Vector3(CX, 0.05, LINE_Z))
	bot.aim = true
	await physics_frames(30)
	assert_true(weapons.aiming)
	bot.move = Vector2(0, 1)
	await physics_frames(40)
	var hspeed := Vector2(player.velocity.x, player.velocity.z).length()
	assert_lt(hspeed, player.config.walk_speed * 0.7, "apuntando se camina más lento")
	bot.sprint = true
	await physics_frames(10)
	assert_false(weapons.aiming, "correr cancela el apuntado")
	bot.release_all()


func test_infinite_ammo_toggle() -> void:
	await _ready_at(Vector3(CX, 0.05, LINE_Z))
	DebugTools.infinite_ammo = true
	await _shoot_once()
	assert_eq(weapons.current().mag, 20)


func test_ammo_crate_refills() -> void:
	await _ready_at(Vector3(CX, 0.05, LINE_Z))
	for i in 2:
		await _shoot_once()
	var crate := level.get_node("Geometry/AmmoCrate") as Node3D
	player.teleport(crate.global_position + Vector3(0, 0.05, 1.6), 0.0)
	await physics_frames(5)
	await _look_at(crate.global_position + Vector3(0, 0.25, 0))
	await physics_frames(3)
	bot.press_interact()
	await physics_frames(3)
	assert_eq(weapons.current().mag, 20)
	assert_eq(weapons.current().reserve, 100)


func test_paper_target_reports_drop_at_100m() -> void:
	var t := level.get_node("Geometry/Target100m") as PaperTarget
	await _ready_at(Vector3(t.global_position.x, 0.05, LINE_Z))
	bot.aim = true
	await physics_frames(30)
	await _look_at(t.global_position + Vector3(0, 1.2 + 0.6, 0))
	await _shoot_once()
	await physics_frames(20)
	assert_true(t.last_hit != null, "le pega a la diana de 100 m")
	if t.last_hit != null:
		assert_near(t.last_hit.distance, 100.0, 3.0)
		assert_gt(t.last_hit.drop, 0.04)


func test_head_core_is_lethal_and_cheek_is_not() -> void:
	var d := _dummy("Dummy10m")
	d.reset()
	var head := d.global_position + Vector3(0, 0.06 + Mannequin.HEAD_CENTER.y, 0)
	# Centro de la cara, de frente: núcleo. Pómulo y mandíbula: periferia. De perfil por la sien: núcleo.
	assert_eq(d.refine_zone("head", head + Vector3(0, 0.02, -0.12), Vector3(0, 0, 1)), "head_core", "centro de la cara")
	assert_eq(d.refine_zone("head", head + Vector3(0.09, 0.0, -0.12), Vector3(0, 0, 1)), "head", "pómulo")
	assert_eq(d.refine_zone("head", head + Vector3(0, -0.1, -0.12), Vector3(0, 0, 1)), "head", "mandíbula")
	assert_eq(d.refine_zone("head", head + Vector3(-0.11, 0.02, 0.0), Vector3(1, 0, 0)), "head_core", "sien, de perfil")
	assert_eq(d.refine_zone("torso", head, Vector3(0, 0, 1)), "torso")
	# Con la pistola .22: al centro de la cabeza mata de un tiro, al pómulo no
	weapons.equip_weapon(load("res://data/weapons/p22.tres"), 3)
	bot.select_slot(3)
	await _ready_at(Vector3(CX - 5.0, 0.05, LINE_Z + 2.0))
	bot.aim = true
	await physics_frames(30)
	await _look_at(head + Vector3(0.088, -0.01, 0))
	await _shoot_once()
	await physics_frames(5)
	assert_eq(d.hits_received.size(), 1)
	if d.hits_received.size() == 1:
		assert_eq(d.hits_received[0].zone, "head", "tiro al pómulo")
		assert_near(d.hits_received[0].damage, 14.0 * 3.0, 4.0, "periferia: ×3")
	assert_false(d.down, "un .22 en el pómulo no mata")
	d.reset()
	await physics_frames(20)
	await _look_at(head + Vector3(0, 0.02, 0))
	await _shoot_once()
	await physics_frames(5)
	assert_eq(d.hits_received.size(), 1)
	if d.hits_received.size() == 1:
		assert_eq(d.hits_received[0].zone, "head_core")
	assert_true(d.down, "un .22 al centro de la cabeza mata de un tiro")
	bot.aim = false


func test_npc_takes_hits_by_zone() -> void:
	var npc := level.get_node("Geometry/Npc_swat") as NpcDummy
	npc.reset()
	await _ready_at(Vector3(npc.global_position.x, 0.05, LINE_Z + 6.0))
	bot.aim = true
	await physics_frames(30)
	await _look_at(npc.global_position + Vector3(0, 1.25, 0))
	await _shoot_once()
	await physics_frames(10)
	assert_eq(npc.hits_received.size(), 1, "un impacto en el personaje")
	if npc.hits_received.is_empty():
		return
	assert_eq(npc.hits_received[0].zone, "torso")
	await _look_at(npc.global_position + Vector3(0, 1.68, 0))
	await _shoot_once()
	await physics_frames(10)
	assert_eq(npc.hits_received.size(), 2)
	if npc.hits_received.size() > 1:
		assert_true(DamageModel.is_head(npc.hits_received[1].zone), "tiro a la cabeza: %s" % npc.hits_received[1].zone)
