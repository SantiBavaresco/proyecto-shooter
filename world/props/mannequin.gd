class_name Mannequin
extends Node3D
## Maniquí de tiro con zonas de impacto (cabeza, torso, extremidades).
## Muestra el daño de cada impacto, cae al llegar a 0 y se levanta solo.
## La cabeza tiene un núcleo (cerebro y centro de la cara) que es letal: un tiro
## que lo atraviesa se marca "head_core"; el resto de la cabeza es "head".

const MAX_HP := 100.0
const RESPAWN_TIME := 3.0
## Núcleo letal en el espacio de la caja de la cabeza (centro y tamaño).
const HEAD_CENTER := Vector3(0, 1.62, 0)
const CORE_CENTER := Vector3(0, 0.02, 0.0)
const CORE_SIZE := Vector3(0.12, 0.13, 0.15)
const ZONE_COLORS: Dictionary = {
	"head_core": Color(1.0, 0.1, 0.1),
	"head": Color(1.0, 0.45, 0.3),
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
	var flash_zone := "head" if DamageModel.is_head(info.zone) else info.zone
	if _parts.has(flash_zone):
		_flash[flash_zone] = 0.12
	if hp <= 0.0:
		down = true
		get_tree().create_timer(RESPAWN_TIME, false).timeout.connect(_respawn)
		return true
	return false


## Afina la zona: si el tiro que entró por la cabeza atraviesa el núcleo, es letal.
func refine_zone(zone: String, hit_pos: Vector3, dir: Vector3) -> String:
	if zone != "head":
		return zone
	var head_xf := _pivot.global_transform * Transform3D(Basis.IDENTITY, HEAD_CENTER + CORE_CENTER)
	var inv := head_xf.affine_inverse()
	var o := inv * hit_pos
	var d := (inv.basis * dir).normalized()
	return "head_core" if _segment_hits_box(o, d, 0.35, CORE_SIZE * 0.5) else "head"


## Intersección del segmento o + d·t (0 ≤ t ≤ length) con la caja centrada de semiejes h.
static func _segment_hits_box(o: Vector3, d: Vector3, length: float, h: Vector3) -> bool:
	var t0 := 0.0
	var t1 := length
	for i in 3:
		if absf(d[i]) < 1e-6:
			if absf(o[i]) > h[i]:
				return false
			continue
		var a := (-h[i] - o[i]) / d[i]
		var b := (h[i] - o[i]) / d[i]
		t0 = maxf(t0, minf(a, b))
		t1 = minf(t1, maxf(a, b))
		if t0 > t1:
			return false
	return true


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
	l.text = tr("hit.lethal") if info.zone == "head_core" else "%d" % roundi(info.damage)
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
	_add_part(body, "head", Vector3(0.22, 0.26, 0.24), HEAD_CENTER, skin)

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
		zb.set_meta("zone_owner", self)
		zb.set_meta("surface", "flesh")
		body.remove_child(cs)
		zb.add_child(cs)
		body.add_child(zb)
		if not _parts.has(zone):
			_parts[zone] = []
		_parts[zone].append(mi)
