class_name Blood
extends RefCounted
## Sangre: chorro de gotas (tiro), manchas irregulares en el piso (el que se arrastra o
## se revuelca) y charco que se va agrandando (alrededor de la cabeza o del cuerpo).
## Las manchas y charcos son Decals: se apoyan sobre lo que haya abajo (pasto, piso,
## pendiente). Hay un máximo: las más viejas se van.

const MAX_DECALS := 180
const COLOR := Color(0.33, 0.02, 0.02)
const VARIANTS := 6

static var _tex: Array[Texture2D] = []
static var _decals: Array[Decal] = []
static var _drop_mat: StandardMaterial3D


## Chorro de gotas desde `pos` hacia `dir` (para atrás de un tiro a la cabeza: la
## dirección de la bala). `amount`: cuántas gotas.
static func spray(at: Node, pos: Vector3, dir: Vector3, amount := 40, speed := 4.5) -> void:
	var root := _root(at)
	if root == null:
		return
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = amount
	p.lifetime = 0.9
	p.explosiveness = 0.92
	p.direction = dir.normalized() if dir.length() > 0.01 else Vector3.UP
	p.spread = 22.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -9.8, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.4
	var m := SphereMesh.new()
	m.radius = 0.012
	m.height = 0.024
	m.radial_segments = 4
	m.rings = 2
	m.material = _drop_material()
	p.mesh = m
	root.add_child(p)
	p.global_position = pos
	p.emitting = true
	p.finished.connect(p.queue_free)
	# Donde caen: unas manchas chicas adelante
	var flat := Vector3(dir.x, 0, dir.z)
	if flat.length() > 0.05:
		flat = flat.normalized()
		for i in 3:
			var d := randf_range(0.5, 1.8)
			stain(at, pos + flat * d + Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3)), randf_range(0.12, 0.3))


## Mancha irregular en el piso debajo de `pos` (tamaño en m).
static func stain(at: Node, pos: Vector3, size: float) -> Decal:
	var root := _root(at)
	if root == null:
		return null
	var ground := _ground(at, pos)
	if ground == Vector3.INF:
		return null
	var d := Decal.new()
	d.texture_albedo = _texture(randi() % VARIANTS)
	d.size = Vector3(size, 0.6, size)
	d.modulate = Color(1, 1, 1, randf_range(0.8, 1.0))
	d.albedo_mix = 1.0
	d.cull_mask = 1
	d.upper_fade = 0.2
	d.lower_fade = 0.2
	root.add_child(d)
	d.global_position = ground + Vector3(0, 0.1, 0)
	d.rotation = Vector3(0, randf() * TAU, 0)
	_track(d)
	return d


## Charco que crece hasta `size` en `seconds` debajo de `pos`.
static func pool(at: Node, pos: Vector3, size: float, seconds: float) -> void:
	var d := stain(at, pos, 0.08)
	if d == null:
		return
	d.modulate.a = 1.0
	var tw := d.create_tween()
	tw.tween_property(d, "size", Vector3(size, 0.6, size * randf_range(0.75, 1.0)), seconds) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


static func _track(d: Decal) -> void:
	_decals = _decals.filter(func(x: Decal) -> bool: return is_instance_valid(x))
	_decals.append(d)
	while _decals.size() > MAX_DECALS:
		var old: Decal = _decals.pop_front()
		if is_instance_valid(old):
			old.queue_free()


static func _root(at: Node) -> Node:
	if at == null or not at.is_inside_tree():
		return null
	var cw := CombatWorld.get_for(at as Node3D) if at is Node3D else null
	return cw if cw != null else at.get_tree().current_scene


static func _ground(at: Node, pos: Vector3) -> Vector3:
	var n := at as Node3D
	if n == null:
		return Vector3.INF
	var q := PhysicsRayQueryParameters3D.create(pos + Vector3(0, 0.6, 0), pos + Vector3(0, -2.5, 0), 1)
	var hit := n.get_world_3d().direct_space_state.intersect_ray(q)
	return hit["position"] if not hit.is_empty() else Vector3.INF


static func _drop_material() -> StandardMaterial3D:
	if _drop_mat == null:
		_drop_mat = StandardMaterial3D.new()
		_drop_mat.albedo_color = COLOR
		_drop_mat.roughness = 0.3
	return _drop_mat


## Mancha irregular (tools/fx/gen_blood.py): VARIANTS formas distintas.
static func _texture(i: int) -> Texture2D:
	if _tex.is_empty():
		for v in VARIANTS:
			var t := load("res://assets/textures/fx/blood_%d.png" % v) as Texture2D
			if t != null:
				_tex.append(t)
	return _tex[i % _tex.size()] if not _tex.is_empty() else null
