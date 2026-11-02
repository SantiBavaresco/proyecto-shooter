class_name WeaponTable
extends StaticBody3D
## Mesa de la armería del laboratorio: muestra un arma con su nombre y calibre.
## Mirarla + [F] la equipa en su slot (pistolas al 3; largas al slot largo en uso).
## Reemplazo provisorio del inventario hasta la F2.

const TABLE_SIZE := Vector3(1.3, 0.05, 0.6)
const TABLE_HEIGHT := 0.85

@export var weapon_path: String = ""

var data: WeaponData
var _model: Node3D


func _ready() -> void:
	set_meta("surface", "wood")
	data = load(weapon_path) as WeaponData
	_build()


func get_interact_text() -> String:
	# Ya traducido; el controlador reemplaza %s por la tecla
	return tr("interact.take_weapon") % ["%s", tr(data.name_key)]


func interact(player: Node) -> void:
	var p := player as Player
	if p == null or p.weapons == null:
		return
	var slot := p.weapons.take_weapon(data)
	EventBus.toast.emit(tr("interact.weapon_taken") % [tr(data.name_key), slot])


func _build() -> void:
	# Tablero y patas
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(TABLE_SIZE.x, TABLE_HEIGHT + 0.25, TABLE_SIZE.z)
	cs.shape = sh
	cs.position = Vector3(0, (TABLE_HEIGHT + 0.25) * 0.5, 0)
	add_child(cs)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.36, 0.27, 0.17)
	wood.roughness = 0.8
	_mesh(Vector3(TABLE_SIZE.x, TABLE_SIZE.y, TABLE_SIZE.z), Vector3(0, TABLE_HEIGHT, 0), wood)
	for x: float in [-0.58, 0.58]:
		for z: float in [-0.24, 0.24]:
			_mesh(Vector3(0.05, TABLE_HEIGHT, 0.05), Vector3(x, TABLE_HEIGHT * 0.5, z), wood)
	# Arma acostada sobre la mesa, de costado, con el caño hacia +X
	_model = ItemModels.display_weapon(data)
	for n in ["HandR", "HandL", "HookR", "HookL", "HookP"]:
		var h := _model.find_child(n, true, false)
		if h != null:
			h.get_parent().remove_child(h)
			h.free()
	# Acostada sobre su lado izquierdo: caño (−Z local) → +X, lado derecho (+X local) → arriba.
	# Se centra sobre la mesa y se apoya según su tamaño real.
	_model.basis = Basis(Vector3(0, 1, 0), Vector3(0, 0, -1), Vector3(-1, 0, 0))
	var box := _local_aabb(_model)
	_model.position = Vector3(box.get_center().z, TABLE_HEIGHT + TABLE_SIZE.y * 0.5 - box.position.x + 0.001,
		box.get_center().y)
	add_child(_model)
	_disable_lens()
	# Cartel con nombre y calibre
	var l := Label3D.new()
	l.text = "%s\n%s" % [tr(data.name_key), data.caliber]
	l.position = Vector3(0, TABLE_HEIGHT + 0.55, 0)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = 48
	l.pixel_size = 0.0035
	l.outline_size = 10
	l.modulate = Color(0.95, 0.92, 0.82)
	add_child(l)


## Caja que envuelve todas las mallas del modelo, en sus coordenadas locales.
static func _local_aabb(model: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for c in model.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		var xf := Transform3D.IDENTITY
		var n: Node = mi
		while n != model:
			xf = (n as Node3D).transform * xf
			n = n.get_parent()
		var b := xf * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


## En la mesa el visor muestra vidrio oscuro (no hay cámara de visor).
func _disable_lens() -> void:
	var lens := _model.get_node_or_null("ScopeLens") as MeshInstance3D
	if lens != null:
		var m := (lens.material_override as ShaderMaterial).duplicate() as ShaderMaterial
		m.set_shader_parameter("active", 0.0)
		lens.material_override = m


func _mesh(size: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
