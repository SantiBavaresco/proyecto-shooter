class_name Mannequin
extends Node3D
## Maniquí de tiro con zonas de impacto (cabeza, torso, extremidades).
## Muestra el daño de cada impacto, cae al llegar a 0 y se levanta solo.

const MAX_HP := 100.0
const RESPAWN_TIME := 3.0
const ZONE_COLORS: Dictionary = {
	"head": Color(1.0, 0.35, 0.25),
	"torso": Color(1.0, 0.9, 0.5),
	"limb": Color(0.8, 0.85, 0.9),
}

var hp: float = MAX_HP
var down: bool = false
var hits_received: Array[HitInfo] = []

var _pivot: Node3D
var _parts: Dictionary = {}
var _flash: Dictionary = {}
var _labels: Array[Label3D] = []
var _label_index: int = 0
var _fall: float = 0.0


func _ready() -> void:
	_build()


## Recibe un impacto. Devuelve true si este impacto lo derribó.
func apply_hit(info: HitInfo) -> bool:
	hits_received.append(info)
	if down:
		return false
	hp -= info.damage
	_show_number(info)
	if _parts.has(info.zone):
		_flash[info.zone] = 0.12
	if hp <= 0.0:
		down = true
		get_tree().create_timer(RESPAWN_TIME, false).timeout.connect(_respawn)
		return true
	return false


func reset() -> void:
	hp = MAX_HP
	down = false
	_fall = 0.0
	hits_received.clear()


func _respawn() -> void:
	hp = MAX_HP
	down = false


func _process(delta: float) -> void:
	_fall = move_toward(_fall, 1.0 if down else 0.0, delta / (0.35 if down else 0.6))
	var f := _fall * _fall * (3.0 - 2.0 * _fall)
	_pivot.rotation = Vector3(deg_to_rad(-80.0) * f, 0, 0)
	for zone: String in _flash.keys():
		_flash[zone] -= delta
		var on: bool = _flash[zone] > 0.0
		for mi: MeshInstance3D in _parts[zone]:
			(mi.material_override as StandardMaterial3D).emission_enabled = on
	for l in _labels:
		if l.visible:
			l.position.y += delta * 0.6
			l.modulate.a -= delta * 0.9
			if l.modulate.a <= 0.0:
				l.visible = false


func _show_number(info: HitInfo) -> void:
	var l := _labels[_label_index]
	_label_index = (_label_index + 1) % _labels.size()
	l.text = "%d" % roundi(info.damage)
	l.modulate = ZONE_COLORS.get(info.zone, Color.WHITE)
	l.global_position = info.position + Vector3(0, 0.15, 0)
	l.visible = true


func _build() -> void:
	# Base fija + cuerpo que pivota en los pies al caer
	var base := StaticBody3D.new()
	base.set_meta("surface", "metal")
	add_child(base)
	_add_part(base, "", Vector3(0.5, 0.06, 0.5), Vector3(0, 0.03, 0), Color(0.25, 0.25, 0.24), false)

	_pivot = Node3D.new()
	_pivot.position = Vector3(0, 0.06, 0)
	add_child(_pivot)
	var body := StaticBody3D.new()
	body.set_meta("surface", "flesh")
	_pivot.add_child(body)

	var skin := Color(0.78, 0.7, 0.58)
	var cloth := Color(0.35, 0.37, 0.3)
	# Piernas
	for x: float in [-0.11, 0.11]:
		_add_part(body, "limb", Vector3(0.14, 0.82, 0.16), Vector3(x, 0.41, 0), cloth)
	# Torso y cadera
	_add_part(body, "torso", Vector3(0.42, 0.6, 0.24), Vector3(0, 1.12, 0), cloth)
	_add_part(body, "torso", Vector3(0.36, 0.14, 0.22), Vector3(0, 0.88, 0), cloth)
	# Brazos
	for x: float in [-0.29, 0.29]:
		_add_part(body, "limb", Vector3(0.12, 0.6, 0.13), Vector3(x, 1.1, 0), cloth)
	# Cuello y cabeza
	_add_part(body, "head", Vector3(0.1, 0.08, 0.1), Vector3(0, 1.46, 0), skin)
	_add_part(body, "head", Vector3(0.22, 0.26, 0.24), Vector3(0, 1.62, 0), skin)

	for i in 8:
		var l := Label3D.new()
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.font_size = 64
		l.pixel_size = 0.004
		l.outline_size = 12
		l.no_depth_test = true
		l.visible = false
		add_child(l)
		_labels.append(l)


func _add_part(body: StaticBody3D, zone: String, size: Vector3, pos: Vector3, color: Color, register := true) -> void:
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	cs.position = pos
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.8
	m.emission = Color(1.0, 0.3, 0.2)
	m.emission_energy_multiplier = 1.5
	mi.material_override = m
	mi.position = pos
	body.add_child(mi)
	if register and zone != "":
		# Cada zona es un cuerpo propio para que el impacto sepa qué parte tocó
		var zb := StaticBody3D.new()
		zb.set_meta("hit_zone", zone)
		zb.set_meta("surface", "flesh")
		body.remove_child(cs)
		zb.add_child(cs)
		body.add_child(zb)
		if not _parts.has(zone):
			_parts[zone] = []
		_parts[zone].append(mi)
