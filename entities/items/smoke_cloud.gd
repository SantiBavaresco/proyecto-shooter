class_name SmokeCloud
extends Node3D
## Nube de una granada de humo: crece unos segundos, se mantiene y se disipa. Tapa la
## vista de la IA (nadie ve a través: a lo sumo tiran de cobertura adonde te vieron
## por última vez) y la del jugador (es humo de verdad en pantalla).

const MAX_RADIUS := 5.5
const GROW := 4.0
const HOLD := 22.0
const FADE := 6.0

var t: float = 0.0
var _puffs: CPUParticles3D


static func spawn(parent: Node, at: Vector3) -> SmokeCloud:
	var c := SmokeCloud.new()
	c.name = "SmokeCloud"
	parent.add_child(c)
	c.global_position = at
	return c


## Radio que tapa ahora (0 si ya no tapa).
func radius() -> float:
	if t < GROW:
		return MAX_RADIUS * smoothstep(0.0, GROW, t) * 0.95
	if t < GROW + HOLD:
		return MAX_RADIUS
	return MAX_RADIUS * clampf(1.0 - (t - GROW - HOLD) / FADE, 0.0, 1.0) * 1.1


## ¿El segmento a→b pasa por adentro de alguna nube? (lo bastante adentro: un poco de
## humo en el borde no tapa)
static func blocks(tree: SceneTree, a: Vector3, b: Vector3) -> bool:
	for n in tree.get_nodes_in_group("smoke_cloud"):
		var c := n as SmokeCloud
		if c == null:
			continue
		var r := c.radius() * 0.8
		if r < 0.5:
			continue
		var center := c.global_position + Vector3(0, r * 0.45, 0)
		var ab := b - a
		var k := clampf((center - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		if (a + ab * k).distance_to(center) < r:
			return true
	return false


func _ready() -> void:
	add_to_group("smoke_cloud")
	_puffs = CPUParticles3D.new()
	_puffs.amount = 70
	_puffs.lifetime = 9.0
	_puffs.preprocess = 0.0
	_puffs.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_puffs.emission_sphere_radius = 0.6
	_puffs.direction = Vector3.UP
	_puffs.spread = 180.0
	_puffs.initial_velocity_min = 0.6
	_puffs.initial_velocity_max = 2.2
	_puffs.gravity = Vector3(0.15, 0.12, 0.05)
	_puffs.damping_min = 0.35
	_puffs.damping_max = 0.6
	_puffs.scale_amount_min = 2.6
	_puffs.scale_amount_max = 4.2
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.35))
	curve.add_point(Vector2(0.3, 1.0))
	curve.add_point(Vector2(1, 1.25))
	_puffs.scale_amount_curve = curve
	var m := SphereMesh.new()
	m.radius = 0.5
	m.height = 1.0
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
	if t > GROW + HOLD - 2.0 and _puffs.emitting:
		_puffs.emitting = false
	if t > GROW + HOLD + FADE + 4.0:
		queue_free()
