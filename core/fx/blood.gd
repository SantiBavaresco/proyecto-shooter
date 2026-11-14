class_name Blood
extends RefCounted
## Sangre. Lo que la dispara (personas y animales) llama a estas funciones; los números
## están en BloodSettings (data/fx/blood.tres) y las texturas en assets/textures/fx
## (tools/fx/gen_blood.py).
##
##  on_hit(victim, info, alive)   cada tiro al cuerpo: gotas + salpicadura en la pared o
##                                el piso de atrás (y, si ya está en el piso, debajo)
##  headshot(victim, info)        chorro grande para atrás y salpicaduras en abanico
##  pool(victim, at, size, secs)  charco que crece, irregular; en pendiente corre ("río")
##  smear(victim, at, dir)        arrastre (el que se arrastra o se revuelca)
##  stain(victim, at, size)       gotas sueltas
##
## Todas las manchas son Decals: se apoyan sobre lo que haya (piso, pared, pendiente) y
## no se pintan sobre los personajes (que están en otra capa visual).

enum Kind { POOL, SPLAT, SMEAR, DROP }
const VARIANTS := {Kind.POOL: 6, Kind.SPLAT: 6, Kind.SMEAR: 4, Kind.DROP: 4}
const NAMES := {Kind.POOL: "pool", Kind.SPLAT: "splat", Kind.SMEAR: "smear", Kind.DROP: "drop"}
## Capas donde se proyectan (el mundo); los personajes van en la 2.
const DECAL_CULL := 1
const WORLD_MASK := 1

static var _tex: Dictionary = {}
static var _decals: Array[Decal] = []
static var _drop_mat: StandardMaterial3D


static func cfg() -> BloodSettings:
	return BloodSettings.get_default()


# --- Eventos ----------------------------------------------------------------------------

## Un tiro le pegó a `victim` (vivo o ya caído).
static func on_hit(victim: Node3D, info: HitInfo, alive: bool) -> void:
	if victim == null or info == null or info.damage <= 0.0 or not victim.is_inside_tree():
		return
	var s := cfg()
	var dir := info.direction.normalized() if info.direction.length() > 0.01 else Vector3.FORWARD
	var head := info.zone.begins_with("head")
	spray(victim, info.position, dir + Vector3.UP * 0.1, s.hit_drops * (2 if head else 1), s.hit_speed)
	# Sale por detrás: mancha en la pared o el piso que haya atrás
	var hit := _ray(victim, info.position + dir * 0.25, info.position + dir * s.splatter_range)
	if not hit.is_empty():
		var sz := randf_range(s.splatter_size.x, s.splatter_size.y)
		_decal(victim, Kind.SPLAT, hit["position"], hit["normal"], dir, sz, sz * randf_range(1.0, 1.4))
	# En el piso: además, debajo
	if not alive:
		var g := _ray(victim, info.position + Vector3.UP * 0.3, info.position + Vector3.DOWN * 1.5)
		if not g.is_empty():
			var sz2 := randf_range(s.corpse_splat_size.x, s.corpse_splat_size.y)
			_decal(victim, Kind.SPLAT, g["position"], g["normal"], dir, sz2, sz2)


## Tiro a la cabeza: chorro grande para atrás y salpicaduras en abanico.
static func headshot(victim: Node3D, info: HitInfo) -> void:
	if victim == null or info == null or not victim.is_inside_tree():
		return
	var s := cfg()
	var dir := info.direction.normalized() if info.direction.length() > 0.01 else Vector3.FORWARD
	spray(victim, info.position, dir + Vector3.UP * 0.2, s.head_drops, s.head_speed, 28.0)
	var right := dir.cross(Vector3.UP).normalized()
	if right.length() < 0.1:
		right = Vector3.RIGHT
	for i in s.head_splatters:
		var d := dir.rotated(Vector3.UP, deg_to_rad(randf_range(-s.head_cone_deg, s.head_cone_deg)))
		d = d.rotated(right, deg_to_rad(randf_range(-s.head_cone_deg, s.head_cone_deg * 0.5)) - 0.15)
		var hit := _ray(victim, info.position + d * 0.2, info.position + d * s.splatter_range * 1.4)
		if not hit.is_empty():
			var sz := randf_range(s.splatter_size.x, s.splatter_size.y) * randf_range(0.7, 1.3)
			_decal(victim, Kind.SPLAT, hit["position"], hit["normal"], d, sz, sz * randf_range(1.1, 1.6))


## Charco debajo de `at` que crece hasta `size` en `seconds`: irregular (manchas extra
## alrededor) y, si el piso está en pendiente, corre para abajo.
static func pool(victim: Node3D, at: Vector3, size: float, seconds: float) -> void:
	if victim == null or not victim.is_inside_tree():
		return
	var s := cfg()
	var g := _ray(victim, at + Vector3.UP * 0.6, at + Vector3.DOWN * 2.5)
	if g.is_empty():
		return
	var p: Vector3 = g["position"]
	var n: Vector3 = g["normal"]
	var final := size * s.pool_size_mult
	var main := _decal(victim, Kind.POOL, p, n, Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU), 0.08, 0.08)
	_grow(main, final, final * randf_range(0.75, 1.0), seconds)
	for i in randi_range(s.pool_satellites.x, s.pool_satellites.y):
		var off := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * final * randf_range(0.25, 0.45)
		var sat := _decal(victim, Kind.POOL, p + off, n, Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU), 0.05, 0.05)
		var k := randf_range(0.35, 0.6)
		_grow(sat, final * k, final * k * randf_range(0.7, 1.0), seconds * randf_range(0.8, 1.3))
	# Pendiente: un hilo que baja ("río"), se va estirando de a tramos
	var down := Vector3(n.x, 0, n.z)
	if 1.0 - n.y >= s.flow_min_slope and down.length() > 0.001:
		down = down.normalized()
		var length := randf_range(s.flow_length.x, s.flow_length.y) * clampf((1.0 - n.y) * 60.0, 0.6, 1.6)
		var step := length / maxi(s.flow_steps, 1)
		var cur := p
		for i in s.flow_steps:
			cur += down.rotated(Vector3.UP, randf_range(-0.35, 0.35)) * step
			var gi := _ray(victim, cur + Vector3.UP * 0.8, cur + Vector3.DOWN * 2.0)
			if gi.is_empty():
				break
			cur = gi["position"]
			var w := final * lerpf(0.3, 0.12, float(i) / s.flow_steps)
			var d := _decal(victim, Kind.SMEAR, cur, gi["normal"], down, 0.02, 0.02)
			var delay := seconds * (0.4 + 0.12 * i)
			d.get_tree().create_timer(delay, false).timeout.connect(func() -> void:
				if is_instance_valid(d):
					_grow(d, w, step * 1.6, seconds * 0.6))


## Arrastre: trazo alargado en la dirección en que se mueve (o se revuelca).
static func smear(victim: Node3D, at: Vector3, dir: Vector3) -> void:
	if victim == null or not victim.is_inside_tree():
		return
	var s := cfg()
	var g := _ray(victim, at + Vector3.UP * 0.6, at + Vector3.DOWN * 2.5)
	if g.is_empty():
		return
	var flat := Vector3(dir.x, 0, dir.z)
	if flat.length() < 0.01:
		flat = Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU)
	_decal(victim, Kind.SMEAR, g["position"], g["normal"], flat.normalized(),
		randf_range(s.smear_width.x, s.smear_width.y), randf_range(s.smear_length.x, s.smear_length.y))


## Mancha suelta (gotas) debajo de `at`.
static func stain(victim: Node3D, at: Vector3, size: float) -> void:
	if victim == null or not victim.is_inside_tree():
		return
	var g := _ray(victim, at + Vector3.UP * 0.6, at + Vector3.DOWN * 2.5)
	if not g.is_empty():
		_decal(victim, Kind.DROP, g["position"], g["normal"], Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU), size, size)


## Gotas que vuelan (partículas): desde `pos` hacia `dir`.
static func spray(at: Node3D, pos: Vector3, dir: Vector3, amount: int, speed: float, spread := 20.0) -> void:
	var root := _root(at)
	if root == null or amount <= 0:
		return
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = amount
	p.lifetime = 1.0
	p.explosiveness = 0.9
	p.direction = dir.normalized()
	p.spread = spread
	p.initial_velocity_min = speed * 0.35
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -9.8, 0)
	p.damping_min = 0.5
	p.damping_max = 1.5
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.6
	var m := SphereMesh.new()
	m.radius = 0.011
	m.height = 0.022
	m.radial_segments = 4
	m.rings = 2
	m.material = _drop_material()
	p.mesh = m
	root.add_child(p)
	p.global_position = pos
	p.emitting = true
	p.finished.connect(p.queue_free)


# --- Piezas -----------------------------------------------------------------------------

## Mancha proyectada sobre la superficie de normal `n`, alargada en `along` (ancho w,
## largo l en metros).
static func _decal(at: Node3D, kind: Kind, pos: Vector3, n: Vector3, along: Vector3, w: float, l: float) -> Decal:
	var root := _root(at)
	if root == null:
		return null
	var d := Decal.new()
	d.texture_albedo = _texture(kind, randi() % int(VARIANTS[kind]))
	d.cull_mask = DECAL_CULL
	d.modulate = Color(1, 1, 1, cfg().opacity * randf_range(0.85, 1.0))
	d.upper_fade = 0.0
	d.lower_fade = 0.0
	d.normal_fade = 0.15
	d.size = Vector3(w, 0.6, l)
	root.add_child(d)
	# El decal proyecta por su -Y: Y = normal, Z = hacia dónde se alarga
	var y := n.normalized()
	var z := (along - y * along.dot(y))
	if z.length() < 0.01:
		z = y.cross(Vector3.RIGHT if absf(y.x) < 0.9 else Vector3.FORWARD)
	z = z.normalized()
	var x := y.cross(z).normalized()
	d.global_transform = Transform3D(Basis(x, y, z), pos + y * 0.08)
	_track(d)
	return d


static func _grow(d: Decal, w: float, l: float, seconds: float) -> void:
	if d == null or not is_instance_valid(d):
		return
	var tw := d.create_tween()
	tw.tween_property(d, "size", Vector3(w, 0.6, l), seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


static func _track(d: Decal) -> void:
	_decals = _decals.filter(func(x: Decal) -> bool: return is_instance_valid(x))
	_decals.append(d)
	while _decals.size() > cfg().max_decals:
		var old: Decal = _decals.pop_front()
		if is_instance_valid(old):
			old.queue_free()


static func _root(at: Node) -> Node:
	if at == null or not at.is_inside_tree():
		return null
	return CombatWorld.get_for(at as Node3D) if at is Node3D else at.get_tree().current_scene


static func _ray(at: Node3D, from: Vector3, to: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to, WORLD_MASK)
	return at.get_world_3d().direct_space_state.intersect_ray(q)


static func _drop_material() -> StandardMaterial3D:
	if _drop_mat == null:
		_drop_mat = StandardMaterial3D.new()
		_drop_mat.albedo_color = Color(0.32, 0.02, 0.02)
		_drop_mat.roughness = 0.25
	return _drop_mat


static func _texture(kind: Kind, i: int) -> Texture2D:
	var key := "%d_%d" % [kind, i]
	if not _tex.has(key):
		_tex[key] = load("res://assets/textures/fx/blood_%s_%d.png" % [NAMES[kind], i])
	return _tex[key]
