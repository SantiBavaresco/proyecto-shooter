class_name CombatWorld
extends Node3D
## Simulación de proyectiles y efectos de impacto de un nivel.
##
## - Proyectiles reales (no hitscan): velocidad, gravedad, resistencia del aire.
## - Rebotes según el material y el ángulo de impacto (ver Surface).
## - Daño = daño base × (velocidad actual / velocidad de boca) × multiplicador de zona.
## - Efectos con pools (sin crear/destruir en caliente): marcas, partículas,
##   trazadoras, casquillos, destello de boca, sonidos.
##
## Hay uno por nivel; se obtiene con CombatWorld.get_for(nodo).

const DAMAGE_MODEL := preload("res://data/combat/damage_model.tres")
const MAX_PROJECTILES := 256
## Materiales que puede atravesar una bala.
const MAX_PENETRATIONS := 3
const MAX_LIFETIME := 3.0
const MAX_DECALS := 120
const MAX_PARTICLES := 24
const MAX_SHELLS := 30
const MAX_TRACERS := 32
## Segundos máximos de vuelo de un casquillo con física; al quedarse quieto (o al
## pasar este tiempo) pasa al piso como casquillo "dormido" (sin física, se dibuja
## junto con todos los demás en una sola llamada).
const SHELL_LIFETIME := 6.0
## Casquillos en el piso: cuánto duran, hasta qué distancia se dibujan y cuántos hay
## como máximo por tipo (los más viejos se reemplazan).
const REST_LIFETIME := 270.0
const REST_RANGE := 150.0
const MAX_REST := 600
const TRAJ_LIFETIME := 6.0
const TRAJ_MAX_SEGMENTS := 3000
## Capa de colisión de los casquillos (no chocan con el jugador ni con balas).
const SHELL_LAYER := 8
## Lo que tocan las balas: todo menos casquillos, cuerpos de movimiento de los
## enemigos (capa 5: las balas pegan en sus cuerpos de impacto), follaje (capa 9) y
## tejidos de alambrado (capa 10: solo frenan a la gente).
const BULLET_MASK := 0xFFFFFFFF & ~(1 << (SHELL_LAYER - 1)) & ~(1 << 4) & ~(1 << 8) & ~(1 << 9) & ~(1 << 11)

## Hit-stop (micro pausa) al confirmar una baja o un tiro a la cabeza.
var hitstop_enabled: bool = true
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Contadores para diagnóstico y tests.
var stats_impacts: int = 0
var stats_ricochets: int = 0
var stats_penetrations: int = 0
var _shell_shape: Shape3D
var _shell_shape_big: Shape3D

var _projectiles: Array[Projectile] = []
var _decals: Array[Decal] = []
var _decal_index: int = 0
var _particles: Array[CPUParticles3D] = []
var _particle_index: int = 0
var _tracers: Array[MeshInstance3D] = []
var _shells: Array[RigidBody3D] = []
var _shell_index: int = 0
var _shell_time: PackedFloat32Array = []
var _shell_big: Array[bool] = []
## Casquillos en el piso: [transform, segundos que le quedan] por tipo (latón / escopeta).
var _rest: Array = [[], []]
var _rest_mm: Array[MultiMeshInstance3D] = []
var _rest_dirty: bool = false
var _rest_cull_t: float = 0.0
var _audio: Array[AudioStreamPlayer3D] = []
var _audio_index: int = 0
var _muzzle_light: OmniLight3D
var _muzzle_light_time: float = 0.0
var _traj_mesh: ImmediateMesh
var _traj_instance: MeshInstance3D
var _traj_segments: Array = []  # [from, to, color, time]
var _decal_texture: ImageTexture
var _hitstop_active: bool = false


## Proyectil en vuelo.
class Projectile:
	var pos: Vector3
	var vel: Vector3
	var v0: float
	var drag: float
	var damage: float
	var weapon_id: String
	var origin: Vector3
	var aim_dir: Vector3
	var traveled: float = 0.0
	var age: float = 0.0
	var ricochets: int = 0
	var max_ricochets: int = 2
	## Poder de penetración (WeaponData.penetration_power) y materiales atravesados.
	var power: float = 1.0
	var penetrations: int = 0
	var exclude: Array[RID] = []
	var source: Node
	var tracer: MeshInstance3D
	## Desplazamiento visual de la trazadora (de la cámara a la boca del arma) que se desvanece.
	var visual_offset: Vector3 = Vector3.ZERO
	var alive: bool = true
	## Ya avisó que pasó cerca de alguien.
	var near_done: bool = false


static func get_for(node: Node) -> CombatWorld:
	var existing := node.get_tree().get_first_node_in_group("combat_world") as CombatWorld
	if existing != null:
		return existing
	var cw := CombatWorld.new()
	cw.name = "CombatWorld"
	var root := node.get_tree().current_scene if node.get_tree().current_scene != null else node.get_tree().root
	# Si el nodo pertenece a otra escena (tests), colgarlo de la raíz de su nivel.
	var level := node.owner if node.owner != null else root
	level.add_child(cw)
	return cw


func _ready() -> void:
	add_to_group("combat_world")
	rng.randomize()
	_build_pools()


# --- API ----------------------------------------------------------------------

## Dispara un proyectil desde `origin` en dirección `dir`.
func fire_projectile(origin: Vector3, dir: Vector3, weapon: WeaponData, source: Node = null,
		exclude: Array[RID] = [], tracer: bool = false, muzzle_world: Vector3 = Vector3.INF) -> Projectile:
	if _projectiles.size() >= MAX_PROJECTILES:
		_projectiles.pop_front()
	var p := Projectile.new()
	p.pos = origin
	p.origin = origin
	p.aim_dir = dir.normalized()
	p.vel = p.aim_dir * weapon.muzzle_velocity
	p.v0 = weapon.muzzle_velocity
	p.drag = weapon.drag
	p.damage = weapon.damage
	p.weapon_id = weapon.id
	p.max_ricochets = weapon.max_ricochets
	p.power = weapon.penetration_power()
	p.exclude = exclude
	p.source = source
	if tracer:
		p.tracer = _take_tracer()
		if muzzle_world != Vector3.INF:
			p.visual_offset = muzzle_world - origin
	_projectiles.append(p)
	return p


func active_projectiles() -> int:
	return _projectiles.size()


## Casquillo expulsado (posición y velocidad en el mundo).
func spawn_shell(xform: Transform3D, velocity: Vector3, big: bool = false, ignore: PhysicsBody3D = null) -> void:
	var idx := _shell_index
	var s := _shells[idx]
	_shell_index = (_shell_index + 1) % _shells.size()
	if _shell_time[idx] > 0.0:
		_settle_shell(idx)  # el más viejo todavía volando: queda en el piso donde esté
	_shell_time[idx] = SHELL_LIFETIME
	_shell_big[idx] = big
	for e in s.get_collision_exceptions():
		s.remove_collision_exception_with(e)
	if ignore != null:
		s.add_collision_exception_with(ignore)
	s.freeze = false
	s.visible = true
	s.global_transform = xform
	# Vaina de fusil/pistola (latón) o de escopeta (tubo rojo con culote de latón)
	(s.get_child(0) as Node3D).visible = not big
	(s.get_child(1) as Node3D).visible = big
	(s.get_child(2) as CollisionShape3D).shape = _shell_shape_big if big else _shell_shape
	s.linear_velocity = velocity
	s.angular_velocity = Vector3(rng.randf_range(-20, 20), rng.randf_range(-20, 20), rng.randf_range(-20, 20))
	s.sleeping = false


## Destello de luz en la boca del arma (luz real del mundo).
func muzzle_flash_light(pos: Vector3) -> void:
	_muzzle_light.global_position = pos
	_muzzle_light.visible = true
	_muzzle_light.light_energy = rng.randf_range(2.5, 3.5)
	_muzzle_light_time = 0.05


func play_sound_at(stream: AudioStream, pos: Vector3, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var a := _audio[_audio_index]
	_audio_index = (_audio_index + 1) % _audio.size()
	a.stream = stream
	a.global_position = pos
	a.volume_db = volume_db
	a.pitch_scale = pitch
	a.play()


# --- Simulación -----------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if _projectiles.is_empty():
		return
	var space := get_world_3d().direct_space_state
	var g := ProjectSettings.get_setting("physics/3d/default_gravity", 9.8) as float
	var i := 0
	while i < _projectiles.size():
		var p := _projectiles[i]
		_step(p, space, g, delta)
		if not p.alive:
			if p.tracer != null:
				p.tracer.visible = false
				p.tracer = null
			_projectiles.remove_at(i)
		else:
			i += 1


## Avanza un proyectil un tick. Público para los tests.
func _step(p: Projectile, space: PhysicsDirectSpaceState3D, g: float, delta: float) -> void:
	p.age += delta
	if p.age > MAX_LIFETIME:
		p.alive = false
		return
	# Integración: gravedad + resistencia cuadrática
	var speed := p.vel.length()
	p.vel += Vector3.DOWN * g * delta
	p.vel -= p.vel.normalized() * p.drag * speed * speed * delta
	var from := p.pos
	var to := p.pos + p.vel * delta
	_check_near_miss(p, from, to)
	var remaining := 1.0
	# Hasta 4 sub-tramos por tick para resolver rebotes y penetraciones en el mismo frame.
	for _sub in 4:
		var q := PhysicsRayQueryParameters3D.create(from, to)
		q.exclude = p.exclude
		q.collide_with_areas = false
		q.collision_mask = BULLET_MASK
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			_record_segment(p, from, to)
			p.traveled += from.distance_to(to)
			p.pos = to
			break
		var hp: Vector3 = hit["position"]
		var hn: Vector3 = hit["normal"]
		_record_segment(p, from, hp)
		p.traveled += from.distance_to(hp)
		var seg_len := from.distance_to(to)
		remaining *= 1.0 - (from.distance_to(hp) / seg_len if seg_len > 0.0 else 1.0)
		var collider: Object = hit["collider"]
		var next := _handle_impact(p, hp, hn, collider, space)
		if next == Vector3.INF:
			p.alive = false
			p.pos = hp
			return
		# Rebote o penetración: sigue desde ahí con el tiempo que quedaba del tick
		from = next
		to = from + p.vel * delta * remaining
	p.pos = to
	_update_tracer(p, from)


## Balas que pasan cerca: al jugador le suena el chasquido y le sube el estrés; los
## enemigos se dan cuenta de que les están tirando (y de dónde).
func _check_near_miss(p: Projectile, from: Vector3, to: Vector3) -> void:
	if p.near_done or p.traveled < 4.0:
		return
	var from_player := p.source != null and is_instance_valid(p.source) and p.source.is_in_group("player")
	if not from_player:
		var pl := get_tree().get_first_node_in_group("player") as Player
		if pl != null and not pl.is_dead:
			var head := pl.camera.global_position
			var c := Geometry3D.get_closest_point_to_segment(head, from, to)
			var d := c.distance_to(head)
			if d < 1.6 and d > 0.05:
				p.near_done = true
				play_sound_at(SynthSfx.crack(), c, -2.0 - d * 4.0, rng.randf_range(0.92, 1.08))
				pl.near_miss(1.6 - d)
		return
	for n in get_tree().get_nodes_in_group("ai_npc"):
		var npc := n as Node3D
		if npc == null or not npc.has_method("on_near_miss"):
			continue
		var chest := npc.global_position + Vector3(0, 1.3, 0)
		if Geometry3D.get_closest_point_to_segment(chest, from, to).distance_to(chest) < 2.5:
			npc.call("on_near_miss", p.origin, p.source)
			p.near_done = true


## Impacto: daño, efectos y qué sigue. Devuelve desde dónde continúa el proyectil
## (rebote o salida del material atravesado) o Vector3.INF si se detuvo.
func _handle_impact(p: Projectile, pos: Vector3, normal: Vector3, collider: Object,
		space: PhysicsDirectSpaceState3D = null) -> Vector3:
	stats_impacts += 1
	var surface := Surface.of(collider)
	var dir := p.vel.normalized()
	var info := HitInfo.new()
	info.position = pos
	info.normal = normal
	info.direction = dir
	info.surface = surface
	info.weapon_id = p.weapon_id
	info.distance = p.traveled
	info.ricochets = p.ricochets
	info.source = p.source if is_instance_valid(p.source) else null
	info.zone = _zone_of(collider, pos, dir)
	info.drop = _drop_from_aim(p, pos)
	var vel_factor := clampf(p.vel.length() / maxf(p.v0, 1.0), 0.0, 1.0)
	info.penetration = p.power * vel_factor
	info.damage = p.damage * vel_factor * DAMAGE_MODEL.multiplier(info.zone)
	if DAMAGE_MODEL.is_lethal(info.zone):
		info.damage = maxf(info.damage, DAMAGE_MODEL.lethal_damage)

	var target := _find_hittable(collider)
	var killed := false
	if target != null:
		var result: Variant = target.call("apply_hit", info)
		killed = result is bool and result
		if p.source != null and p.source.is_in_group("player"):
			EventBus.hit_confirmed.emit(info, killed)
			if hitstop_enabled and (killed or DamageModel.is_head(info.zone)):
				_hitstop()

	# ¿Rebota?
	var ang := Surface.grazing_angle(dir, normal)
	var prob := Surface.ricochet_probability(surface, ang)
	var bounce := p.ricochets < p.max_ricochets and target == null and rng.randf() < prob
	_spawn_impact_fx(pos, normal, surface, collider, bounce)
	if bounce:
		var s := Surface.data(surface)
		var reflected := p.vel.bounce(normal)
		# Un poco de desvío aleatorio
		reflected = reflected.rotated(Vector3.UP, rng.randf_range(-0.08, 0.08))
		p.vel = reflected * float(s["ricochet_energy"])
		p.ricochets += 1
		stats_ricochets += 1
		p.damage *= 0.7
		# (sin zumbido de rebote; se consume el mismo azar que antes para no cambiar la
		# secuencia de rebotes)
		rng.randf()
		return pos + normal * 0.01
	# ¿Lo atraviesa? (chapa, madera: según el espesor que encuentra en su recorrido)
	if target == null and space != null and p.penetrations < MAX_PENETRATIONS:
		var exit := _try_penetrate(p, pos, dir, surface, collider, space)
		if exit != Vector3.INF:
			return exit
	return Vector3.INF


## Penetración: mide el espesor a lo largo del recorrido (un rayo desde atrás hacia
## la entrada que golpea la cara de salida) y, si alcanza, la bala sale del otro lado
## más lenta y apenas desviada, dejando agujero de salida.
func _try_penetrate(p: Projectile, pos: Vector3, dir: Vector3, surface: String, collider: Object,
		space: PhysicsDirectSpaceState3D) -> Vector3:
	var vel_factor := clampf(p.vel.length() / maxf(p.v0, 1.0), 0.0, 1.0)
	var cap := Surface.penetrable_thickness(surface, p.power * vel_factor * vel_factor)
	if cap <= 0.0005:
		return Vector3.INF
	var far := pos + dir * (cap + 0.002)
	var q := PhysicsRayQueryParameters3D.create(far, pos + dir * 0.0002)
	q.collide_with_areas = false
	q.collision_mask = BULLET_MASK
	var back := space.intersect_ray(q)
	if back.is_empty() or back["collider"] != collider:
		return Vector3.INF  # más grueso de lo que puede atravesar (o pegado a otra cosa)
	var exit: Vector3 = back["position"]
	var thick := pos.distance_to(exit)
	var used := clampf(thick / cap, 0.0, 1.0)
	# Pierde velocidad según cuánto de su capacidad gastó, y se desvía un poco
	var keep := sqrt(1.0 - used) * 0.92
	var new_dir := dir.rotated(Vector3.UP, rng.randf_range(-1.0, 1.0) * deg_to_rad(4.0) * used)
	new_dir = new_dir.rotated(new_dir.cross(Vector3.UP).normalized(), rng.randf_range(-1.0, 1.0) * deg_to_rad(3.0) * used)
	p.vel = new_dir * p.vel.length() * keep
	p.penetrations += 1
	stats_penetrations += 1
	_spawn_impact_fx(exit, back["normal"], surface, collider, false)
	return exit + new_dir * 0.002


## Zona golpeada. Si el cuerpo tiene un "zone_owner" con refine_zone(), este puede
## afinarla (ej.: el núcleo de la cabeza, que está adentro de la caja de la cabeza).
func _zone_of(collider: Object, pos: Vector3, dir: Vector3) -> String:
	var n := collider as Node
	if n == null or not n.has_meta("hit_zone"):
		return ""
	var zone: String = n.get_meta("hit_zone")
	var owner_node: Object = n.get_meta("zone_owner", null)
	if owner_node != null and is_instance_valid(owner_node) and owner_node.has_method("refine_zone"):
		zone = owner_node.call("refine_zone", zone, pos, dir)
	return zone


func _find_hittable(collider: Object) -> Node:
	var n := collider as Node
	if n != null and n.has_meta("zone_owner"):
		# Cuerpos pegados a huesos (personajes): el dueño está muchos niveles arriba
		var owner_node: Object = n.get_meta("zone_owner")
		if owner_node is Node and is_instance_valid(owner_node) and (owner_node as Node).has_method("apply_hit"):
			return owner_node as Node
	for i in 5:
		if n == null:
			return null
		if n.has_method("apply_hit"):
			return n
		n = n.get_parent()
	return null


## Distancia entre el punto de impacto y la línea de mira original (caída + desvío).
func _drop_from_aim(p: Projectile, pos: Vector3) -> float:
	var rel := pos - p.origin
	var along := rel.dot(p.aim_dir)
	var closest := p.origin + p.aim_dir * along
	return maxf(0.0, closest.y - pos.y)


# --- Efectos ----------------------------------------------------------------

func _spawn_impact_fx(pos: Vector3, normal: Vector3, surface: String, collider: Object, ricochet: bool) -> void:
	var s := Surface.data(surface)
	if s["decals"] and collider is StaticBody3D:
		var d := _decals[_decal_index]
		_decal_index = (_decal_index + 1) % _decals.size()
		var up := normal.normalized()
		var side := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
		var fwd := side.cross(up).normalized()
		d.global_transform = Transform3D(Basis(side, up, fwd).rotated(up, rng.randf() * TAU), pos)
		d.modulate = s["decal"]
		var sz := rng.randf_range(0.06, 0.09)
		d.size = Vector3(sz, 0.12, sz)
		d.visible = true
	var part := _particles[_particle_index]
	_particle_index = (_particle_index + 1) % _particles.size()
	# Las partículas salen por el −Z local: se orienta el emisor mirando hacia la normal.
	var up_ref := Vector3.UP if absf(normal.y) < 0.95 else Vector3.FORWARD
	part.global_transform = Transform3D(Basis.looking_at(normal, up_ref), pos + normal * 0.02)
	part.direction = Vector3(0, 0, -1)
	part.color = s["particle"]
	var mat := part.mesh.surface_get_material(0) as StandardMaterial3D
	if mat != null:
		mat.emission_enabled = s["sparks"] or ricochet
		mat.emission = Color(1.0, 0.6, 0.2)
		mat.emission_energy_multiplier = 3.0
	part.amount = 14 if (s["sparks"] or ricochet) else 10
	part.restart()
	part.emitting = true
	play_sound_at(SynthSfx.impact(surface), pos, -4.0, rng.randf_range(0.9, 1.1))


func _update_tracer(p: Projectile, seg_start: Vector3) -> void:
	if p.tracer == null:
		return
	var fade := clampf(1.0 - p.traveled / 25.0, 0.0, 1.0)
	var off := p.visual_offset * fade
	var tail := p.pos - p.vel.normalized() * minf(p.vel.length() * 0.016, 7.0)
	if tail.distance_to(p.origin) > p.pos.distance_to(p.origin):
		tail = p.origin
	var a := tail + off
	var b := p.pos + off
	var length := a.distance_to(b)
	if length < 0.01:
		return
	p.tracer.visible = true
	var up := Vector3.UP if absf((b - a).normalized().dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
	p.tracer.global_transform = Transform3D(Basis.looking_at(b - a, up), (a + b) * 0.5)
	p.tracer.scale = Vector3(1.0, 1.0, length)
	p.tracer.reset_physics_interpolation()


func _record_segment(p: Projectile, a: Vector3, b: Vector3) -> void:
	if not DebugTools.show_trajectories:
		return
	if _traj_segments.size() >= TRAJ_MAX_SEGMENTS:
		_traj_segments.pop_front()
	var c := Color(1.0, 0.85, 0.2) if p.ricochets == 0 else Color(1.0, 0.25, 0.2)
	_traj_segments.append([a, b, c, TRAJ_LIFETIME])


func _process(delta: float) -> void:
	if _muzzle_light_time > 0.0:
		_muzzle_light_time -= delta
		if _muzzle_light_time <= 0.0:
			_muzzle_light.visible = false
	for i in _shells.size():
		if _shell_time[i] > 0.0:
			_shell_time[i] -= delta
			var b := _shells[i]
			var still := SHELL_LIFETIME - _shell_time[i] > 0.5 and (b.sleeping
				or (b.linear_velocity.length() < 0.04 and b.angular_velocity.length() < 0.5))
			if still or _shell_time[i] <= 0.0:
				_settle_shell(i)
	_update_rest(delta)
	_draw_trajectories(delta)


## Casquillo quieto: deja de ser un cuerpo físico y pasa a la lista del piso.
func _settle_shell(i: int) -> void:
	var b := _shells[i]
	_shell_time[i] = 0.0
	if b.global_position.y > -20.0:
		var list: Array = _rest[1 if _shell_big[i] else 0]
		if list.size() >= MAX_REST:
			list.pop_front()
		list.append([b.global_transform, REST_LIFETIME])
		_rest_dirty = true
	b.visible = false
	b.freeze = true


## Casquillos en el piso: vencen a los REST_LIFETIME segundos y solo se dibujan
## cerca del jugador (se revisa dos veces por segundo).
func _update_rest(delta: float) -> void:
	_rest_cull_t -= delta
	for list: Array in _rest:
		var k := 0
		while k < list.size() and float(list[k][1]) - delta <= 0.0:
			k += 1
		if k > 0:
			for j in k:
				list.pop_front()
			_rest_dirty = true
		for e: Array in list:
			e[1] = float(e[1]) - delta
	if not _rest_dirty and _rest_cull_t > 0.0:
		return
	_rest_cull_t = 0.5
	_rest_dirty = false
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var eye := cam.global_position if cam != null else Vector3.ZERO
	for t in 2:
		var list: Array = _rest[t]
		var mm := _rest_mm[t].multimesh
		var shown: Array[Transform3D] = []
		for e: Array in list:
			var xf: Transform3D = e[0]
			if cam == null or xf.origin.distance_squared_to(eye) < REST_RANGE * REST_RANGE:
				shown.append(xf)
		mm.instance_count = shown.size()
		for j in shown.size():
			mm.set_instance_transform(j, shown[j])


## Casquillos en el piso (para los tests).
func resting_shells() -> int:
	return (_rest[0] as Array).size() + (_rest[1] as Array).size()


func _draw_trajectories(delta: float) -> void:
	_traj_mesh.clear_surfaces()
	if _traj_segments.is_empty():
		return
	var i := 0
	while i < _traj_segments.size():
		_traj_segments[i][3] -= delta
		if _traj_segments[i][3] <= 0.0:
			_traj_segments.remove_at(i)
		else:
			i += 1
	if _traj_segments.is_empty() or not DebugTools.show_trajectories:
		if not DebugTools.show_trajectories:
			_traj_segments.clear()
		return
	_traj_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for seg in _traj_segments:
		_traj_mesh.surface_set_color(seg[2])
		_traj_mesh.surface_add_vertex(seg[0])
		_traj_mesh.surface_set_color(seg[2])
		_traj_mesh.surface_add_vertex(seg[1])
	_traj_mesh.surface_end()


func _hitstop() -> void:
	if _hitstop_active:
		return
	_hitstop_active = true
	Engine.time_scale = 0.15
	await get_tree().create_timer(0.05, true, false, true).timeout
	Engine.time_scale = 1.0
	_hitstop_active = false


# --- Pools --------------------------------------------------------------------

func _build_pools() -> void:
	_decal_texture = _make_hole_texture()
	for i in MAX_DECALS:
		var d := Decal.new()
		d.texture_albedo = _decal_texture
		d.visible = false
		d.upper_fade = 0.2
		d.lower_fade = 0.2
		d.cull_mask = 1
		add_child(d)
		_decals.append(d)

	for i in MAX_PARTICLES:
		var p := CPUParticles3D.new()
		p.one_shot = true
		p.emitting = false
		p.explosiveness = 1.0
		p.lifetime = 0.55
		p.amount = 10
		p.spread = 35.0
		p.initial_velocity_min = 1.5
		p.initial_velocity_max = 5.0
		p.gravity = Vector3(0, -9.8, 0)
		p.scale_amount_min = 0.5
		p.scale_amount_max = 1.2
		p.local_coords = false
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.025, 0.025, 0.025)
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mesh.material = m
		p.mesh = mesh
		add_child(p)
		_particles.append(p)

	var tracer_mesh := BoxMesh.new()
	tracer_mesh.size = Vector3(0.018, 0.018, 1.0)
	var tm := StandardMaterial3D.new()
	tm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tm.albedo_color = Color(1.0, 0.75, 0.4)
	tm.emission_enabled = true
	tm.emission = Color(1.0, 0.55, 0.2)
	tm.emission_energy_multiplier = 6.0
	tracer_mesh.material = tm
	for i in MAX_TRACERS:
		var t := MeshInstance3D.new()
		t.mesh = tracer_mesh
		t.visible = false
		t.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		t.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		add_child(t)
		_tracers.append(t)

	var shell_mesh := CylinderMesh.new()
	shell_mesh.top_radius = 0.0045
	shell_mesh.bottom_radius = 0.0055
	shell_mesh.height = 0.04
	shell_mesh.radial_segments = 8
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.85, 0.65, 0.25)
	sm.metallic = 0.9
	sm.roughness = 0.35
	shell_mesh.material = sm
	var shell_shape := CylinderShape3D.new()
	shell_shape.radius = 0.006
	shell_shape.height = 0.04
	_shell_shape = shell_shape
	_shell_shape_big = CylinderShape3D.new()
	_shell_shape_big.radius = 0.011
	_shell_shape_big.height = 0.065
	# Vaina de escopeta: tubo rojo + culote de latón
	var hull := CylinderMesh.new()
	hull.top_radius = 0.0105
	hull.bottom_radius = 0.0105
	hull.height = 0.05
	hull.radial_segments = 10
	var hm := StandardMaterial3D.new()
	hm.albedo_color = Color(0.62, 0.08, 0.06)
	hm.roughness = 0.6
	hull.material = hm
	var base := CylinderMesh.new()
	base.top_radius = 0.0112
	base.bottom_radius = 0.0116
	base.height = 0.015
	base.radial_segments = 10
	base.material = sm
	_shell_time.resize(MAX_SHELLS)
	_shell_big.resize(MAX_SHELLS)
	# Rebotan poco y casi no ruedan (salvo en pendiente)
	var shell_phys := PhysicsMaterial.new()
	shell_phys.friction = 0.95
	shell_phys.bounce = 0.15
	for i in MAX_SHELLS:
		var b := RigidBody3D.new()
		b.collision_layer = 1 << (SHELL_LAYER - 1)
		b.collision_mask = 1
		b.mass = 0.012
		b.freeze = true
		b.visible = false
		b.continuous_cd = true
		b.physics_material_override = shell_phys
		b.angular_damp = 4.0
		b.linear_damp = 0.35
		var mi := MeshInstance3D.new()
		mi.mesh = shell_mesh
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		b.add_child(mi)
		var big := Node3D.new()
		var hi := MeshInstance3D.new()
		hi.mesh = hull
		hi.position.y = 0.008
		hi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		big.add_child(hi)
		var bi := MeshInstance3D.new()
		bi.mesh = base
		bi.position.y = -0.024
		bi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		big.add_child(bi)
		big.visible = false
		b.add_child(big)
		var cs := CollisionShape3D.new()
		cs.shape = shell_shape
		b.add_child(cs)
		add_child(b)
		_shells.append(b)
		_shell_time[i] = 0.0
		_shell_big[i] = false
	# Casquillos en el piso: un MultiMesh por tipo
	var big_mesh := ArrayMesh.new()
	for part: Array in [[hull, Vector3(0, 0.008, 0)], [base, Vector3(0, -0.024, 0)]]:
		var st := SurfaceTool.new()
		st.append_from(part[0] as Mesh, 0, Transform3D(Basis.IDENTITY, part[1]))
		st.commit(big_mesh)
		big_mesh.surface_set_material(big_mesh.get_surface_count() - 1, (part[0] as PrimitiveMesh).material)
	for m: Mesh in [shell_mesh, big_mesh]:
		var mmi := MultiMeshInstance3D.new()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = m
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		add_child(mmi)
		_rest_mm.append(mmi)

	for i in 12:
		var a := AudioStreamPlayer3D.new()
		a.bus = "SFX_World"
		a.max_distance = 120.0
		a.unit_size = 6.0
		add_child(a)
		_audio.append(a)

	_muzzle_light = OmniLight3D.new()
	_muzzle_light.light_color = Color(1.0, 0.7, 0.35)
	_muzzle_light.omni_range = 5.0
	_muzzle_light.visible = false
	_muzzle_light.shadow_enabled = false
	add_child(_muzzle_light)

	_traj_mesh = ImmediateMesh.new()
	_traj_instance = MeshInstance3D.new()
	_traj_instance.mesh = _traj_mesh
	var lm := StandardMaterial3D.new()
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.vertex_color_use_as_albedo = true
	lm.no_depth_test = true
	_traj_instance.material_override = lm
	_traj_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_traj_instance)


func _take_tracer() -> MeshInstance3D:
	for t in _tracers:
		if not t.visible and not _tracer_in_use(t):
			return t
	return null


func _tracer_in_use(t: MeshInstance3D) -> bool:
	for p in _projectiles:
		if p.tracer == t:
			return true
	return false


## Textura de agujero de bala generada por código. TODO-ASSET: decal_bullet_holes
func _make_hole_texture() -> ImageTexture:
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var r := RandomNumberGenerator.new()
	r.seed = 7
	var c := Vector2(size, size) * 0.5
	for y in size:
		for x in size:
			var d := Vector2(x, y).distance_to(c) / (size * 0.5)
			var jitter := r.randf_range(-0.08, 0.08)
			var a := 0.0
			var lum := 1.0
			if d < 0.22 + jitter * 0.3:
				a = 1.0
				lum = 0.05
			elif d < 0.75 + jitter:
				var t := (d - 0.22) / 0.53
				a = (1.0 - t) * 0.85
				lum = lerpf(0.35, 1.0, t)
			img.set_pixel(x, y, Color(lum, lum, lum, a))
	return ImageTexture.create_from_image(img)
