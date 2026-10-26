class_name PaperTarget
extends Node3D
## Diana de papel sobre un bastidor. Muestra la distancia y la caída de la
## bala en el último impacto (útil para ver la balística a 100 y 200 m).

@export var face_size: float = 1.0
## Escala del texto con la distancia y la caída (más chico en dianas cercanas).
@export var label_scale: float = 1.0

var last_hit: HitInfo
var _label: Label3D


func _ready() -> void:
	_build()


func apply_hit(info: HitInfo) -> bool:
	last_hit = info
	_label.text = tr("target.hit") % [roundi(info.distance), roundi(info.drop * 100.0)]
	return false


func _build() -> void:
	var body := StaticBody3D.new()
	body.set_meta("surface", "paper")
	add_child(body)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(face_size, face_size, 0.02)
	cs.shape = sh
	cs.position = Vector3(0, 1.2 + face_size * 0.5, 0)
	body.add_child(cs)
	var face := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(face_size, face_size, 0.02)
	face.mesh = bm
	face.position = cs.position
	var m := StandardMaterial3D.new()
	m.albedo_texture = _rings_texture()
	m.roughness = 0.9
	face.material_override = m
	add_child(face)
	# Patas de madera (no reciben impactos de diana: son "wood")
	var legs := StaticBody3D.new()
	legs.set_meta("surface", "wood")
	add_child(legs)
	for x: float in [-face_size * 0.45, face_size * 0.45]:
		var lcs := CollisionShape3D.new()
		var ls := BoxShape3D.new()
		ls.size = Vector3(0.06, 1.25, 0.06)
		lcs.shape = ls
		lcs.position = Vector3(x, 0.62, 0.03)
		legs.add_child(lcs)
		var lm := MeshInstance3D.new()
		var lb := BoxMesh.new()
		lb.size = ls.size
		lm.mesh = lb
		var wm := StandardMaterial3D.new()
		wm.albedo_color = Color(0.42, 0.3, 0.18)
		lm.material_override = wm
		lm.position = lcs.position
		legs.add_child(lm)
	_label = Label3D.new()
	_label.position = Vector3(0, 1.2 + face_size + 0.25, 0)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 64
	_label.pixel_size = 0.004 * maxf(face_size, 1.0) * 2.0 * label_scale
	_label.outline_size = 12
	_label.text = "—"
	add_child(_label)


## Anillos concéntricos generados por código. TODO-ASSET: target_paper
static func _rings_texture() -> ImageTexture:
	var n := 256
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	var c := Vector2(n, n) * 0.5
	for y in n:
		for x in n:
			var d := Vector2(x, y).distance_to(c) / (n * 0.5)
			var ring := int(d * 10.0)
			var col := Color(0.92, 0.9, 0.84)
			if d < 0.1:
				col = Color(0.7, 0.12, 0.1)
			elif ring < 6 and fmod(d * 10.0, 1.0) < 0.06:
				col = Color(0.1, 0.1, 0.1)
			elif d < 0.4:
				col = Color(0.15, 0.15, 0.15) if ring % 2 == 0 else Color(0.92, 0.9, 0.84)
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)
