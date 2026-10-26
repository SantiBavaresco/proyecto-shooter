extends TestCase
## Balística y superficies en un mundo mínimo armado por el test.

var world: Node3D
var combat: CombatWorld
var rifle: WeaponData


func before_each() -> void:
	world = Node3D.new()
	add_child(world)
	combat = CombatWorld.new()
	combat.hitstop_enabled = false
	world.add_child(combat)
	combat.rng.seed = 12345
	rifle = load("res://data/weapons/rifle.tres")
	await physics_frames(2)


func after_each() -> void:
	world.queue_free()
	await process_frames(1)


func _wall(pos: Vector3, size: Vector3, surface: String, rot := Vector3.ZERO) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.set_meta("surface", surface)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	b.add_child(cs)
	b.position = pos
	b.rotation = rot
	world.add_child(b)
	return b


func test_grazing_angle() -> void:
	assert_near(Surface.grazing_angle(Vector3(0, 0, -1), Vector3(0, 0, 1)), 90.0, 0.01, "de frente")
	assert_near(Surface.grazing_angle(Vector3(1, 0, 0), Vector3(0, 1, 0)), 0.0, 0.01, "rasante")
	assert_near(Surface.grazing_angle(Vector3(1, -1, 0), Vector3(0, 1, 0)), 45.0, 0.01)


func test_ricochet_probability_rules() -> void:
	assert_eq(Surface.ricochet_probability("flesh", 1.0), 0.0, "la carne no rebota")
	assert_eq(Surface.ricochet_probability("metal", 80.0), 0.0, "de frente no rebota")
	assert_gt(Surface.ricochet_probability("metal", 5.0), Surface.ricochet_probability("dirt", 5.0),
		"el metal rebota más que la tierra")


func test_surface_from_meta() -> void:
	var b := _wall(Vector3(0, 0, -50), Vector3(1, 1, 1), "metal")
	assert_eq(Surface.of(b), "metal")
	var plain := StaticBody3D.new()
	world.add_child(plain)
	assert_eq(Surface.of(plain), Surface.DEFAULT)


func test_drop_at_100m_matches_physics() -> void:
	# Pared de papel a 100 m; tiro horizontal
	var t := _Target.new()
	t.set_meta("surface", "paper")
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(10, 10, 0.1)
	cs.shape = sh
	t.add_child(cs)
	t.position = Vector3(0, 0, -100)
	world.add_child(t)
	await physics_frames(2)
	combat.fire_projectile(Vector3.ZERO, Vector3.FORWARD, rifle)
	await physics_frames(30)
	assert_true(t.last != null, "la bala llegó a la diana")
	if t.last == null:
		return
	# t ≈ 0,125 s → caída ≈ ½·g·t² ≈ 7,7 cm (un poco más por la resistencia del aire)
	assert_gt(t.last.drop, 0.06, "cae algo")
	assert_lt(t.last.drop, 0.11, "no cae de más")
	assert_near(t.last.distance, 100.0, 0.5)
	assert_lt(t.last.damage, rifle.damage, "pierde energía con la distancia")
	assert_gt(t.last.damage, rifle.damage * 0.8)


func test_metal_ricochets_at_grazing_angle() -> void:
	# Piso de metal; disparos a 8° hacia abajo
	_wall(Vector3(0, -1, -20), Vector3(20, 0.2, 60), "metal")
	await physics_frames(2)
	var dir := Vector3(0, -sin(deg_to_rad(8)), -cos(deg_to_rad(8)))
	for i in 12:
		combat.fire_projectile(Vector3(0, 0.5, 0), dir, rifle)
	await physics_frames(20)
	assert_gt(float(combat.stats_ricochets), 3.0, "rebotes en metal rasante: %d de 12" % combat.stats_ricochets)


func test_dirt_does_not_ricochet_head_on() -> void:
	_wall(Vector3(0, -1, 0), Vector3(20, 0.2, 20), "dirt")
	await physics_frames(2)
	var dir := Vector3(0, -sin(deg_to_rad(70)), -cos(deg_to_rad(70)))
	for i in 12:
		combat.fire_projectile(Vector3(0, 1.0, 0), dir, rifle)
	await physics_frames(20)
	assert_eq(combat.stats_ricochets, 0)
	assert_eq(combat.stats_impacts, 12)


func test_projectiles_expire() -> void:
	combat.fire_projectile(Vector3.ZERO, Vector3.UP, rifle)
	assert_eq(combat.active_projectiles(), 1)
	await physics_frames(int(CombatWorld.MAX_LIFETIME * 60.0) + 5)
	assert_eq(combat.active_projectiles(), 0, "no quedan proyectiles colgados")


func test_weapon_data_coherent() -> void:
	for path: String in WeaponController.WEAPON_FILES.values():
		var w := load(path) as WeaponData
		assert_true(w != null, "carga %s" % path)
		assert_gt(w.rpm, 0.0)
		assert_gt(float(w.mag_size), 0.0)
		assert_gt(w.muzzle_velocity, 100.0)
		assert_lt(w.spread_ads, w.spread_hip, "%s: apuntar es más preciso" % w.id)
		assert_lt(w.reload_time, w.reload_time_empty + 0.001)
		assert_true(w.fire_modes.size() > 0)
		assert_true(TranslationServer.translate(w.name_key) != w.name_key, "%s tiene nombre traducido" % w.id)
	var r := load("res://data/weapons/rifle.tres") as WeaponData
	assert_true(r.has_mode("auto") and r.has_mode("semi"), "el fusil tiene tiro a tiro y automático")
	var s := load("res://data/weapons/shotgun.tres") as WeaponData
	assert_eq(s.mag_size, 2, "doble caño")
	assert_gt(float(s.pellets), 1.0)


class _Target extends StaticBody3D:
	var last: HitInfo

	func apply_hit(info: HitInfo) -> bool:
		last = info
		return false


# --- Penetración ---------------------------------------------------------------

func _paper(z: float) -> _Target:
	var t := _Target.new()
	t.set_meta("surface", "paper")
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(4, 4, 0.02)
	cs.shape = sh
	t.add_child(cs)
	t.position = Vector3(0, 0, z)
	world.add_child(t)
	return t


func test_rifle_goes_through_thin_wood_and_loses_energy() -> void:
	_wall(Vector3(0, 0, -10), Vector3(2, 2, 0.02), "wood")
	var t := _paper(-14.0)
	await physics_frames(2)
	combat.fire_projectile(Vector3.ZERO, Vector3.FORWARD, rifle)
	await physics_frames(10)
	assert_true(t.last != null, "atravesó la madera de 2 cm")
	if t.last != null:
		assert_lt(t.last.damage, rifle.damage * 0.9, "llega con menos energía")
	assert_eq(combat.stats_penetrations, 1)


func test_thick_wood_stops_rifle() -> void:
	_wall(Vector3(0, 0, -10), Vector3(2, 2, 0.25), "wood")
	var t := _paper(-14.0)
	await physics_frames(2)
	combat.fire_projectile(Vector3.ZERO, Vector3.FORWARD, rifle)
	await physics_frames(10)
	assert_true(t.last == null, "una viga de 25 cm frena la bala")
	assert_eq(combat.stats_penetrations, 0)


func test_sheet_metal_rifle_yes_pistol_no() -> void:
	var pistol := load("res://data/weapons/pistol.tres") as WeaponData
	assert_gt(Surface.penetrable_thickness("metal", rifle.penetration_power()), 0.003, "fusil: más de 3 mm de chapa")
	assert_lt(Surface.penetrable_thickness("metal", pistol.penetration_power()), 0.003, "pistola: menos de 3 mm")
	_wall(Vector3(0, 0, -10), Vector3(2, 2, 0.003), "metal")
	var t := _paper(-14.0)
	await physics_frames(2)
	combat.fire_projectile(Vector3.ZERO, Vector3.FORWARD, pistol)
	await physics_frames(10)
	assert_true(t.last == null, "la pistola no pasa 3 mm de chapa")
	combat.fire_projectile(Vector3.ZERO, Vector3.FORWARD, rifle)
	await physics_frames(10)
	assert_true(t.last != null, "el fusil sí")
