class_name ShadowBody
extends Node3D
## Cuerpo del jugador que solo proyecta sombra (la cámara no lo ve): cabeza, torso,
## brazos con el arma y piernas que caminan. Reemplaza al cilindro: la sombra se ve
## como una persona que camina, se agacha, se inclina y apunta.
## Son cápsulas simples: casi no cuesta nada y no hace falta un modelo con animaciones.

const THIGH := 0.44
const SHIN := 0.44
const UPPER_ARM := 0.29
const FOREARM := 0.27

var player: Player
var _hips: Node3D
var _torso: Node3D
var _legs: Array[Array] = []  # [cadera, rodilla] por pierna
var _arms: Array[Array] = []  # [hombro, codo] por brazo
var _gun: MeshInstance3D
var _phase: float = 0.0
var _crouch: float = 0.0
var _move: float = 0.0


func _ready() -> void:
	_hips = Node3D.new()
	add_child(_hips)
	_torso = Node3D.new()
	_hips.add_child(_torso)
	_capsule(_torso, 0.15, 0.56, Vector3(0, 0.28, 0), Vector3(1.0, 1.0, 0.65))  # torso
	_capsule(_torso, 0.13, 0.26, Vector3(0, 0.0, 0), Vector3(1.0, 1.0, 0.8))  # cadera
	var head := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.11
	sm.height = 0.24
	head.mesh = sm
	head.position = Vector3(0, 0.7, 0.02)
	_shadow_only(head)
	_torso.add_child(head)
	for side: float in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(side * 0.1, 0, 0)
		_hips.add_child(hip)
		_capsule(hip, 0.075, THIGH, Vector3(0, -THIGH * 0.5, 0))
		var knee := Node3D.new()
		knee.position = Vector3(0, -THIGH, 0)
		hip.add_child(knee)
		_capsule(knee, 0.06, SHIN, Vector3(0, -SHIN * 0.5, 0))
		_capsule(knee, 0.05, 0.22, Vector3(0, -SHIN, -0.06), Vector3.ONE, Vector3(-PI * 0.5, 0, 0))  # pie
		_legs.append([hip, knee])
		var sh := Node3D.new()
		sh.position = Vector3(side * 0.2, 0.52, 0)
		_torso.add_child(sh)
		_capsule(sh, 0.055, UPPER_ARM, Vector3(0, -UPPER_ARM * 0.5, 0))
		var elbow := Node3D.new()
		elbow.position = Vector3(0, -UPPER_ARM, 0)
		sh.add_child(elbow)
		_capsule(elbow, 0.045, FOREARM, Vector3(0, -FOREARM * 0.5, 0))
		_arms.append([sh, elbow])
	# El arma en las manos (una caja larga)
	_gun = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.05, 0.12, 0.75)
	_gun.mesh = bm
	_shadow_only(_gun)
	_torso.add_child(_gun)


func _capsule(parent: Node3D, r: float, length: float, pos: Vector3, scale_xyz := Vector3.ONE,
		rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = r
	cm.height = maxf(length, r * 2.0)
	cm.radial_segments = 10
	cm.rings = 3
	mi.mesh = cm
	mi.position = pos
	mi.rotation = rot
	mi.scale = scale_xyz
	_shadow_only(mi)
	parent.add_child(mi)
	return mi


func _shadow_only(mi: MeshInstance3D) -> void:
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY


func _process(delta: float) -> void:
	if player == null:
		return
	rotation = Vector3(0, player.yaw, 0)
	var hv := Vector3(player.velocity.x, 0, player.velocity.z)
	var hs := hv.length()
	var on_floor := player.is_on_floor()
	_move = move_toward(_move, clampf(hs / 4.0, 0.0, 1.3) if on_floor else 0.3, delta * 4.0)
	var crouching := player.stance != Player.Stance.STANDING
	_crouch = move_toward(_crouch, 1.0 if crouching else 0.0, delta * 5.0)
	# Fase de la caminata: una vuelta cada dos pasos
	var stride := 2.35 if player.is_sprinting else (1.25 if crouching else 1.85)
	if on_floor:
		_phase = fmod(_phase + hs * delta / stride * PI, TAU)
	# Caderas: bajan al agacharse; el cuerpo se inclina un poco al correr y al ir de costado
	var hip_h := lerpf(0.9, 0.52, _crouch)
	_hips.position = Vector3(0, hip_h + absf(sin(_phase)) * 0.03 * _move, 0)
	var local_v := Basis(Vector3.UP, -player.yaw) * hv
	var fwd_lean := clampf(-local_v.z / 6.0, -0.2, 0.3) * 0.5 + (0.25 if player.is_sprinting else 0.0)
	_torso.rotation = Vector3(-fwd_lean - _crouch * 0.25, 0, -player.lean_amount * 0.35)
	# Piernas: balanceo opuesto; al agacharse, rodillas dobladas
	var swing := 0.5 * minf(_move, 1.0) + (0.15 if player.is_sprinting else 0.0)
	for i in 2:
		var s := sin(_phase + PI * i)
		var hip := _legs[i][0] as Node3D
		var knee := _legs[i][1] as Node3D
		var bend := lerpf(0.0, 1.9, _crouch)
		# (girar +X lleva hacia adelante un miembro que cuelga)
		hip.rotation = Vector3(s * swing + lerpf(0.0, 1.1, _crouch), 0, 0)
		knee.rotation = Vector3(-(maxf(0.0, -s) * swing * 1.4 + bend), 0, 0)
	# Brazos: sostienen el arma apuntando a donde mira (o colgando sin arma)
	var armed := player.weapons != null and player.weapons.current() != null and not player.weapons.lowered
	var aim := player.pitch_angle + fwd_lean + _crouch * 0.25
	for i in 2:
		var sh := _arms[i][0] as Node3D
		var el := _arms[i][1] as Node3D
		if armed:
			var side := -1.0 if i == 0 else 1.0
			sh.rotation = Vector3(PI * 0.5 + aim - (0.15 if i == 0 else 0.35), side * 0.35, 0)
			el.rotation = Vector3(0.5 if i == 0 else 0.9, 0, 0)
		else:
			var s2 := sin(_phase + PI * (1 - i))
			sh.rotation = Vector3(s2 * swing * 0.7, 0, (0.08 if i == 1 else -0.08))
			el.rotation = Vector3(0.2 + absf(s2) * 0.2 * _move, 0, 0)
	_gun.visible = armed
	if armed:
		_gun.position = Vector3(0.05, 0.42, -0.35)
		_gun.rotation = Vector3(aim - player.pitch_angle * 0.0, 0, 0)
