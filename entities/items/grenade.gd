class_name Grenade
extends RigidBody3D
## Granada de fragmentación tirada (por el jugador o por un enemigo). Rebota, rueda y
## explota cuando se termina la espoleta: daño con caída por distancia a todo lo que
## esté a la vista de la explosión (detrás de una pared no llega), estruendo que la IA
## oye de lejos, fogonazo, humo y sacudón de cámara si estás cerca.

const RADIUS := 9.0
const MAX_DAMAGE := 160.0
## Poder de penetración de las esquirlas (un chaleco clase 2 frena casi todas).
const FRAG_PEN := 0.36

var fuse: float = 3.6
var thrower: Node = null
var item_id: String = "grenade_rg5"
var _exploded: bool = false
var _bounce_t: float = 0.0


static func make(by: Node, id := "grenade_rg5") -> Grenade:
	var g := Grenade.new()
	g.thrower = by
	g.item_id = id
	g.fuse = 3.4 if id == "grenade_rg5" else 3.8
	return g


## Velocidad para que una granada tirada desde `from` caiga en `to` saliendo con el
## ángulo `angle` (tiro parabólico).
static func launch_velocity(from: Vector3, to: Vector3, angle: float) -> Vector3:
	var g := 9.8
	var d := to - from
	var flat := Vector3(d.x, 0, d.z)
	var dx := maxf(flat.length(), 0.5)
	var dy := d.y
	var a := angle
	for i in 4:
		var den := 2.0 * pow(cos(a), 2) * (dx * tan(a) - dy)
		if den > 0.01:
			var v := sqrt(g * dx * dx / den)
			v = minf(v, 22.0)
			return flat.normalized() * v * cos(a) + Vector3.UP * v * sin(a)
		a += 0.15
	return flat.normalized() * 10.0 + Vector3.UP * 6.0


func _ready() -> void:
	add_to_group("grenade")
	mass = 0.4
	continuous_cd = true
	collision_layer = 0
	collision_mask = 1
	contact_monitor = true
	max_contacts_reported = 2
	var pm := PhysicsMaterial.new()
	pm.bounce = 0.25
	pm.friction = 0.9
	pm.rough = true
	physics_material_override = pm
	angular_damp = 1.5
	linear_damp = 0.1
	var cs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 0.04
	cs.shape = sp
	add_child(cs)
	var it := ItemDB.get_item(item_id) if ItemDB.has(item_id) else null
	var m := ItemModels.build(it) if it != null else Node3D.new()
	add_child(m)
	m.position = Vector3(0, -0.04, 0)
	angular_velocity = Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8))
	body_entered.connect(_on_body)


func _on_body(_b: Node) -> void:
	if _bounce_t <= 0.0 and linear_velocity.length() > 1.5:
		_bounce_t = 0.15
		CombatWorld.get_for(self).play_sound_at(SynthSfx.click("grenade_clink", 1.6, 0.04), global_position, -6.0)


func _physics_process(delta: float) -> void:
	_bounce_t -= delta
	fuse -= delta
	if fuse <= 0.0 and not _exploded:
		explode()


func explode() -> void:
	_exploded = true
	var center := global_position + Vector3(0, 0.15, 0)
	var space := get_world_3d().direct_space_state
	var hit_targets := {}
	for n in get_tree().get_nodes_in_group("player") + get_tree().get_nodes_in_group("ai_npc") \
			+ get_tree().get_nodes_in_group("blast_target"):
		var t := n as Node3D
		if t == null or hit_targets.has(t) or not t.has_method("apply_hit"):
			continue
		var aim := t.global_position + Vector3(0, 1.0, 0)
		var d := center.distance_to(aim)
		if d > RADIUS:
			continue
		# Detrás de algo sólido no llega
		var rq := PhysicsRayQueryParameters3D.create(center, aim, 1)
		var ex: Array[RID] = []
		if t is CollisionObject3D:
			ex.append((t as CollisionObject3D).get_rid())
		rq.exclude = ex
		var hit := space.intersect_ray(rq)
		var k := 1.0 if hit.is_empty() else 0.12
		var dmg := MAX_DAMAGE * pow(1.0 - d / RADIUS, 1.6) * k
		if dmg < 2.0:
			continue
		hit_targets[t] = true
		var info := HitInfo.new()
		info.damage = dmg
		info.zone = "torso"
		info.position = aim
		info.direction = (aim - center).normalized()
		info.distance = d
		info.weapon_id = "grenade"
		info.penetration = FRAG_PEN * (1.3 - d / RADIUS)
		info.source = thrower if is_instance_valid(thrower) else null
		var killed: bool = t.call("apply_hit", info)
		if thrower != null and is_instance_valid(thrower) and thrower.is_in_group("player") and t != thrower:
			EventBus.hit_confirmed.emit(info, killed)
	# Sacudón y estrés al jugador que está cerca
	for n in get_tree().get_nodes_in_group("player"):
		var pl := n as Player
		if pl == null or pl.is_dead:
			continue
		var d := pl.global_position.distance_to(center)
		if d < 30.0:
			var s := clampf(1.0 - d / 30.0, 0.0, 1.0)
			pl.near_miss(s * 4.0)
			pl.apply_recoil(deg_to_rad(randf_range(1.0, 3.5) * s), deg_to_rad(randf_range(-3.0, 3.0) * s), 0.9)
	EventBus.noise_emitted.emit(center, 220.0, self)
	_fx(center)
	queue_free()


func _fx(center: Vector3) -> void:
	var parent := get_parent()
	var root := Node3D.new()
	root.name = "Explosion"
	parent.add_child(root)
	root.global_position = center
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.7, 0.4)
	light.light_energy = 9.0
	light.omni_range = 14.0
	root.add_child(light)
	var snd := AudioStreamPlayer3D.new()
	snd.stream = SynthSfx.explosion()
	snd.bus = "SFX_World"
	snd.unit_size = 30.0
	snd.max_distance = 600.0
	snd.volume_db = 4.0
	snd.attenuation_filter_cutoff_hz = 2500.0
	root.add_child(snd)
	snd.play()
	# Fogonazo (chispas) y humo
	var sparks := CPUParticles3D.new()
	sparks.one_shot = true
	sparks.amount = 40
	sparks.lifetime = 0.5
	sparks.explosiveness = 1.0
	sparks.direction = Vector3.UP
	sparks.spread = 180.0
	sparks.initial_velocity_min = 6.0
	sparks.initial_velocity_max = 16.0
	sparks.gravity = Vector3(0, -9.8, 0)
	var sm := SphereMesh.new()
	sm.radius = 0.03
	sm.height = 0.06
	var smat := StandardMaterial3D.new()
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.albedo_color = Color(1.0, 0.75, 0.35)
	sm.material = smat
	sparks.mesh = sm
	root.add_child(sparks)
	sparks.emitting = true
	var smoke := CPUParticles3D.new()
	smoke.one_shot = true
	smoke.amount = 22
	smoke.lifetime = 3.5
	smoke.explosiveness = 0.9
	smoke.direction = Vector3.UP
	smoke.spread = 70.0
	smoke.initial_velocity_min = 1.0
	smoke.initial_velocity_max = 3.5
	smoke.gravity = Vector3(0, 0.4, 0)
	smoke.damping_min = 1.0
	smoke.damping_max = 2.0
	smoke.scale_amount_min = 1.2
	smoke.scale_amount_max = 2.4
	var qm := SphereMesh.new()
	qm.radius = 0.5
	qm.height = 1.0
	qm.radial_segments = 8
	qm.rings = 4
	var mm := StandardMaterial3D.new()
	mm.albedo_color = Color(0.25, 0.23, 0.21, 0.55)
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.material = mm
	smoke.mesh = qm
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 0.9))
	grad.set_color(1, Color(1, 1, 1, 0.0))
	smoke.color_ramp = grad
	root.add_child(smoke)
	smoke.emitting = true
	var tw := root.create_tween()
	tw.tween_property(light, "light_energy", 0.0, 0.25)
	tw.tween_interval(4.0)
	tw.tween_callback(root.queue_free)
