class_name CoverIndex
extends RefCounted
## Índice de las cosas detrás de las que uno se puede cubrir (troncos, arbustos, cajas,
## autos, bolsas de arena, tramos de muro). Se arma una vez por mundo a partir de las
## formas de colisión; la IA no necesita adivinar puntos al azar: va directo "detrás
## de ese tronco, del lado contrario a donde estás vos".
##
## Cada entrada: [centro (Vector3), radio horizontal (m), dura (true = para balas,
## false = solo tapa la vista, como un arbusto)].

const CELL := 8.0
const FOLIAGE_LAYER := 9
## Más alto que esto (agachado) para que sirva.
const MIN_HEIGHT := 0.7

static var _cache: Dictionary = {}


## Lo que hay para cubrirse a menos de `radius` de `at`.
static func near(n: Node3D, at: Vector3, radius: float) -> Array:
	var idx := _index(n)
	var out: Array = []
	var g: Dictionary = idx["grid"]
	var c0 := Vector2i(floori((at.x - radius) / CELL), floori((at.z - radius) / CELL))
	var c1 := Vector2i(floori((at.x + radius) / CELL), floori((at.z + radius) / CELL))
	for x in range(c0.x, c1.x + 1):
		for z in range(c0.y, c1.y + 1):
			for e: Array in g.get(Vector2i(x, z), []):
				var p: Vector3 = e[0]
				if Vector2(p.x - at.x, p.z - at.z).length() <= radius:
					out.append(e)
	return out


## Olvida el índice de ese mundo (si se construyó o se movió algo grande).
static func invalidate(n: Node3D) -> void:
	_cache.erase(n.get_world_3d().get_rid())


static func _index(n: Node3D) -> Dictionary:
	var rid := n.get_world_3d().get_rid()
	if _cache.has(rid):
		var c: Dictionary = _cache[rid]
		if is_instance_valid(c["root"]) and Time.get_ticks_msec() - int(c["t"]) < 30000:
			return c
	var root := n.get_tree().root
	var entries: Array = []
	for b in root.find_children("*", "StaticBody3D", true, false):
		var body := b as StaticBody3D
		if body == null or not body.is_inside_tree():
			continue
		var foliage := (body.collision_layer & (1 << (FOLIAGE_LAYER - 1))) != 0
		if not foliage and (body.collision_layer & 1) == 0:
			continue
		for cs in body.get_children():
			var shape_node := cs as CollisionShape3D
			if shape_node == null or shape_node.shape == null or shape_node.disabled:
				continue
			_add_shape(entries, shape_node, foliage)
	var grid := {}
	for e: Array in entries:
		var p: Vector3 = e[0]
		var k := Vector2i(floori(p.x / CELL), floori(p.z / CELL))
		if not grid.has(k):
			grid[k] = []
		grid[k].append(e)
	var c := {"root": root, "t": Time.get_ticks_msec(), "grid": grid}
	_cache[rid] = c
	return c


static func _add_shape(out: Array, cs: CollisionShape3D, foliage: bool) -> void:
	var xf := cs.global_transform
	var s := cs.shape
	var sc := xf.basis.get_scale()
	if s is BoxShape3D:
		var size := (s as BoxShape3D).size * sc
		if size.y < MIN_HEIGHT or foliage:
			return
		# Los muros largos se parten en tramos de ~1,5 m
		var ax := xf.basis.x.normalized()
		var az := xf.basis.z.normalized()
		var long_ax := ax if size.x >= size.z else az
		var long_len := maxf(size.x, size.z)
		var thick := minf(size.x, size.z)
		if long_len > 40.0 or thick > 12.0:
			return  # el piso, un galpón entero: no es "una cobertura"
		var bottom := xf.origin.y - size.y * 0.5
		var n := maxi(1, int(long_len / 1.5))
		for i in n:
			var f := (float(i) + 0.5) / n - 0.5
			var p := xf.origin + long_ax * f * long_len
			out.append([Vector3(p.x, bottom, p.z), thick * 0.5, true])
	elif s is CylinderShape3D:
		var cy := s as CylinderShape3D
		var h := cy.height * sc.y
		if h < MIN_HEIGHT or cy.radius * sc.x > 3.0:
			return
		out.append([Vector3(xf.origin.x, xf.origin.y - h * 0.5, xf.origin.z), cy.radius * sc.x, not foliage])
	elif s is SphereShape3D:
		var r := (s as SphereShape3D).radius * sc.x
		if not foliage or r < 0.5 or r > 3.0:
			return
		# Arbustos (copas bajas): tapan la vista; las copas de los árboles quedan altas
		var bottom := xf.origin.y - r
		var ground_y := _ground_under(cs, xf.origin)
		if bottom - ground_y > 0.5:
			return
		out.append([Vector3(xf.origin.x, ground_y, xf.origin.z), r * 0.8, false])
	elif s is CapsuleShape3D:
		var cp := s as CapsuleShape3D
		if cp.height * sc.y < MIN_HEIGHT or foliage:
			return
		out.append([Vector3(xf.origin.x, xf.origin.y - cp.height * sc.y * 0.5, xf.origin.z), cp.radius * sc.x, true])


static func _ground_under(n: Node3D, p: Vector3) -> float:
	var rq := PhysicsRayQueryParameters3D.create(p + Vector3(0, 0.5, 0), p - Vector3(0, 6, 0), 1)
	var hit := n.get_world_3d().direct_space_state.intersect_ray(rq)
	return (hit["position"] as Vector3).y if not hit.is_empty() else p.y - 1.0
