class_name SmokeCloud
extends Node3D
## Nube de una granada de humo: crece unos segundos, se mantiene y se disipa. Tapa la
## vista de la IA (nadie ve a través: a lo sumo tiran de cobertura adonde te vieron
## por última vez) y la del jugador (es humo de verdad en pantalla).

## Viento (por ahora uno solo para todo el mapa): el humo se estira para ese lado.
static var wind: Vector3 = Vector3(1.0, 0.0, 0.35).normalized()
## Ancho (radio horizontal) y alto (radio vertical) de la nube: es baja y ancha.
const MAX_RADIUS := 4.2
const HEIGHT_RADIUS := 2.0
## Largo que alcanza la nube a favor del viento.
const MAX_LENGTH := 16.0
const GROW := 5.0
const HOLD := 49.0
const FADE := 6.0

var t: float = 0.0
var _puffs: CPUParticles3D


static func spawn(parent: Node, at: Vector3) -> SmokeCloud:
	var c := SmokeCloud.new()
	c.name = "SmokeCloud"
	parent.add_child(c)
	c.global_position = at
	return c


## Radio (horizontal) que tapa ahora (0 si ya no tapa). Dura 60 s en total.
func radius() -> float:
	if t < GROW:
		return MAX_RADIUS * smoothstep(0.0, GROW, t) * 0.95
	if t < GROW + HOLD:
		return MAX_RADIUS
	return MAX_RADIUS * clampf(1.0 - (t - GROW - HOLD) / FADE, 0.0, 1.0) * 1.1


## Largo de la nube a favor del viento (va creciendo).
func length() -> float:
	return MAX_LENGTH * smoothstep(0.0, GROW * 3.0, t)


## Eje de la nube: de la lata hacia donde sopla el viento, a media altura.
func axis() -> Array:
	var y := Vector3(0, HEIGHT_RADIUS * 0.75, 0)
	var a := global_position + y
	return [a, a + wind * length()]


## ¿El segmento a→b pasa por adentro de alguna nube? Se mide en un espacio donde la
## nube (baja y larga) es redonda; un poco de humo en el borde no tapa.
static func blocks(tree: SceneTree, a: Vector3, b: Vector3) -> bool:
	for n in tree.get_nodes_in_group("smoke_cloud"):
		var c := n as SmokeCloud
		if c == null:
			continue
		var r := c.radius() * 0.85
		if r < 0.5:
			continue
		var ax: Array = c.axis()
		var k := Vector3(1.0, MAX_RADIUS / HEIGHT_RADIUS, 1.0)
		var p0 := (ax[0] as Vector3) * k
		var p1 := (ax[1] as Vector3) * k
		var sa := a * k
		var sb := b * k
		var steps := clampi(int(sa.distance_to(sb) / (r * 0.5)) + 2, 3, 48)
		for i in steps + 1:
			var q := sa.lerp(sb, float(i) / steps)
			if _dist_to_segment(q, p0, p1) < r:
				return true
	return false


static func _dist_to_segment(q: Vector3, p0: Vector3, p1: Vector3) -> float:
	var d := p1 - p0
	var l2 := d.length_squared()
	if l2 < 0.0001:
		return q.distance_to(p0)
	var u := clampf((q - p0).dot(d) / l2, 0.0, 1.0)
	return q.distance_to(p0 + d * u)


func _ready() -> void:
	add_to_group("smoke_cloud")
	_puffs = CPUParticles3D.new()
	_puffs.amount = 120
	_puffs.lifetime = 16.0
	_puffs.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_puffs.emission_sphere_radius = 0.8
	# Sale a ras del piso hacia donde sopla el viento, abriéndose a los costados
	_puffs.direction = (wind + Vector3(0, 0.12, 0)).normalized()
	_puffs.spread = 40.0
	_puffs.initial_velocity_min = 0.8
	_puffs.initial_velocity_max = 2.2
	_puffs.gravity = wind * 0.32 + Vector3(0, 0.03, 0)
	_puffs.damping_min = 0.25
	_puffs.damping_max = 0.45
	_puffs.scale_amount_min = 3.0
	_puffs.scale_amount_max = 4.8
	var curve := Curve.new()
	curve.max_value = 1.5
	curve.add_point(Vector2(0, 0.35))
	curve.add_point(Vector2(0.25, 1.0))
	curve.add_point(Vector2(1, 1.35))
	_puffs.scale_amount_curve = curve
	var m := SphereMesh.new()
	m.radius = 0.5
	m.height = 0.62
	m.radial_segments = 10
	m.rings = 5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.78, 0.78, 0.76, 0.62)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.vertex_color_use_as_albedo = true
	m.material = mat
	_puffs.mesh = m
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 0.0))
	grad.add_point(0.12, Color(1, 1, 1, 0.95))
	grad.add_point(0.75, Color(1, 1, 1, 0.85))
	grad.set_color(grad.get_point_count() - 1, Color(1, 1, 1, 0.0))
	_puffs.color_ramp = grad
	add_child(_puffs)
	_puffs.emitting = true
	var snd := AudioStreamPlayer3D.new()
	snd.stream = SynthSfx.hiss()
	snd.bus = "SFX_World"
	snd.unit_size = 6.0
	snd.max_distance = 60.0
	snd.volume_db = -4.0
	add_child(snd)
	snd.play()


func _process(delta: float) -> void:
	t += delta
	if t > GROW + HOLD - 10.0 and _puffs.emitting:
		_puffs.emitting = false
	if t > GROW + HOLD + FADE + 2.0:
		queue_free()
