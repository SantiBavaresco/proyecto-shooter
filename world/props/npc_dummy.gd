class_name NpcDummy
extends Node3D
## Personaje de prueba con modelo .glb (operadores, policía, PMC): recibe tiros por
## zonas (cabeza con núcleo letal, torso, extremidades) con cuerpos pegados a los
## huesos, muestra el daño y, al morir, se desploma tieso como una tabla hacia donde
## lo empujó el tiro. A los segundos se vuelve a parar.
##
## Al cargar se le sacan los visores nocturnos (mallas o huesos con "night_vision").

const MAX_HP := 100.0
## Segundos en el piso antes de pararse (si lo están revisando, espera).
const RESPAWN_TIME := 10.0
## Arma que lleva cada personaje (se saquea del cuerpo).
const WEAPON_BY_MODEL := {"fsb": "ak74", "swat": "mp5", "swat_remaster": "hk416", "swat_special": "g3"}
const BODY_LOOT := [["bandage", 1, 2, 0.6], ["medkit", 1, 1, 0.3], ["cash", 40, 250, 0.7], ["canned_meat", 1, 1, 0.3],
	["energy_drink", 1, 1, 0.2], ["water", 1, 1, 0.25]]
const HEIGHT := 1.8
## Zonas por nombre de hueso (en minúsculas) y radio del cuerpo de impacto.
const ZONES := [["head", "head", 0.11], ["neck", "head", 0.06], ["spine", "torso", 0.16], ["hips", "torso", 0.15],
	["pelvis", "torso", 0.15], ["upperarm", "limb", 0.055], ["forearm", "limb", 0.045], ["arm", "limb", 0.055],
	["thigh", "limb", 0.08], ["upleg", "limb", 0.08], ["calf", "limb", 0.06], ["leg", "limb", 0.06]]
const ZONE_COLORS: Dictionary = {
	"head_core": Color(1.0, 0.1, 0.1),
	"head": Color(1.0, 0.45, 0.3),
	"torso": Color(1.0, 0.9, 0.5),
	"limb": Color(0.8, 0.85, 0.9),
}

## Ruta del .glb del personaje.
@export var scene_path: String = ""
## Animación quieta a usar (vacío = la pose de reposo del modelo).
@export var idle_anim: String = ""
## Cuadro de la animación (segundos) que queda fijo.
@export var idle_at: float = 0.0
## Giro del modelo (grados) para que mire hacia adelante (+Z del nodo).
@export var yaw_deg: float = 0.0
## Sacar los visores nocturnos.
@export var remove_nvg: bool = true

var hp: float = MAX_HP
var down: bool = false
var hits_received: Array[HitInfo] = []
## Lo que lleva encima (se revisa con [F] cuando está en el piso).
var inventory: Inventory
var title_key: String = "loot.body"
var _looting: bool = false

var _body: Node3D
var _sk: Skeleton3D
var _head_bone: int = -1
var _labels: Array[Label3D] = []
var _label_index: int = 0
# Caída rígida: ángulo, velocidad angular, eje y pivote (en los pies)
var _ang: float = 0.0
var _ang_v: float = 0.0
var _fall_dir: Vector3 = Vector3.BACK
var _rising: bool = false


func _ready() -> void:
	inventory = Inventory.new(8, 6)
	inventory.title_key = title_key
	_make_loot()
	_build()


## Su arma con el cargador a medias, munición de ese calibre y algo de botín.
func _make_loot() -> void:
	inventory.clear()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var key := scene_path.get_file().get_basename()
	var wid: String = WEAPON_BY_MODEL.get(key, "")
	if wid != "" and ItemDB.has(ItemDB.weapon_item_id(wid)):
		var it := ItemDB.get_item(ItemDB.weapon_item_id(wid))
		var w := it.weapon()
		inventory.add(ItemStack.make(it.id, 1, {"mag": rng.randi_range(0, w.mag_size), "condition": rng.randf_range(0.45, 0.9)}))
		inventory.add_item(ItemDB.ammo_id(w.caliber), rng.randi_range(w.mag_size / 2, w.mag_size * 2))
	for e: Array in BODY_LOOT:
		if rng.randf() < float(e[3]):
			inventory.add_item(String(e[0]), rng.randi_range(int(e[1]), int(e[2])))


func get_interact_text() -> String:
	return tr("interact.search") % ["%s", tr(title_key)] if down else ""


func interact(_player: Node) -> void:
	if down:
		Foley.play(get_tree(), "pickup_item", -6.0)
		EventBus.loot_requested.emit(self)


func on_loot_opened() -> void:
	_looting = true


func on_loot_closed() -> void:
	_looting = false


func _build() -> void:
	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)
	if scene_path == "" or not ResourceLoader.exists(scene_path):
		return
	var inst := GlbWeapon.scene(scene_path).instantiate() as Node3D
	inst.name = "Model"
	var holder := Node3D.new()
	holder.name = "Facing"
	holder.rotation = Vector3(0, deg_to_rad(yaw_deg), 0)
	_body.add_child(holder)
	holder.add_child(inst)
	var ap := inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap != null:
		if idle_anim != "" and ap.has_animation(idle_anim):
			ap.play(idle_anim)
			ap.seek(idle_at, true)
			ap.advance(0.0)
		ap.active = false
	_sk = inst.find_child("Skeleton3D", true, false) as Skeleton3D
	# Sin visores nocturnos
	for mi: MeshInstance3D in inst.find_children("*", "MeshInstance3D", true, false):
		var n := String(mi.name).to_lower() + "/" + String(mi.get_parent().name).to_lower()
		if n.contains("night_vision"):
			mi.visible = false
	if _sk != null and remove_nvg:
		for b in _sk.get_bone_count():
			if _sk.get_bone_name(b).to_lower().contains("night_vision"):
				_sk.set_bone_pose_scale(b, Vector3.ONE * 0.0001)
		_sk.force_update_all_bone_transforms()
	# Escala a la altura de una persona, parado sobre el origen
	var ab := _aabb(inst)
	if ab.size.y > 0.01:
		var k := HEIGHT / ab.size.y
		inst.scale = Vector3.ONE * k
		inst.position = Vector3(-ab.get_center().x * k, -ab.position.y * k, -ab.get_center().z * k)
	for mi: MeshInstance3D in inst.find_children("*", "MeshInstance3D", true, false):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_add_hitboxes(inst)
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


## Caja que envuelve las mallas (con la pose del esqueleto si tiene).
func _aabb(inst: Node3D) -> AABB:
	var ab := AABB()
	var first := true
	var inv := inst.global_transform.affine_inverse() if inst.is_inside_tree() else Transform3D.IDENTITY
	for mi: MeshInstance3D in inst.find_children("*", "MeshInstance3D", true, false):
		if not mi.visible:
			continue
		var b := (inv * mi.global_transform) * mi.get_aabb() if mi.is_inside_tree() else mi.get_aabb()
		if first:
			ab = b
			first = false
		else:
			ab = ab.merge(b)
	if _sk != null:
		# Las mallas con esqueleto pueden traer una caja vieja: se usan los huesos
		var bb := AABB()
		var f2 := true
		for b in _sk.get_bone_count():
			var p := inv * _sk.global_transform * _sk.get_bone_global_pose(b).origin
			if f2:
				bb = AABB(p, Vector3.ZERO)
				f2 = false
			else:
				bb = bb.expand(p)
		if not f2 and bb.size.y > 0.2:
			# Los huesos no llegan a la coronilla ni a la suela: se agrega un margen
			bb = bb.grow(0.04 * bb.size.y)
			return bb
	return ab


## Un cuerpo de impacto por hueso (cápsula hacia el hueso hijo), con su zona.
func _add_hitboxes(_inst: Node3D) -> void:
	if _sk == null:
		return
	for b in _sk.get_bone_count():
		var nm := _sk.get_bone_name(b).to_lower()
		if nm.contains("end") or nm.contains("nub") or nm.contains("finger") or nm.contains("hand") or nm.contains("toe") \
				or nm.contains("night") or nm.contains("eye"):
			continue
		var zone := ""
		var rad := 0.05
		for zd: Array in ZONES:
			if nm.contains(String(zd[0])):
				zone = zd[1]
				rad = zd[2]
				break
		if zone == "":
			continue
		if nm.contains("head") and _head_bone < 0:
			_head_bone = b
		# Largo y dirección: hacia el hijo (sin contar los visores), en el espacio del hueso
		var gp := _sk.get_bone_global_pose(b)
		var tip := gp.origin + gp.basis.y.normalized() * 0.2
		for ch in _sk.get_bone_children(b):
			if not _sk.get_bone_name(ch).to_lower().contains("night"):
				tip = _sk.get_bone_global_pose(ch).origin
				break
		var d_local := gp.affine_inverse() * tip
		var length := d_local.length()
		# Escala del modelo hasta este nodo (para pasar los radios a metros)
		var world_scale := 1.0
		var n: Node = _sk
		while n != null and n != self:
			if n is Node3D:
				world_scale *= (n as Node3D).scale.x
			n = n.get_parent()
		world_scale = maxf(world_scale, 1e-6)
		var len_m := length * world_scale
		if zone == "head":
			len_m = 0.2
		var att := BoneAttachment3D.new()
		att.bone_name = _sk.get_bone_name(b)
		_sk.add_child(att)
		var body := StaticBody3D.new()
		body.set_meta("hit_zone", zone)
		body.set_meta("zone_owner", self)
		body.set_meta("surface", "flesh")
		att.add_child(body)
		var cs := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = rad
		cap.height = maxf(len_m + rad * 0.5, rad * 2.0 + 0.01)
		cs.shape = cap
		# Cápsula a lo largo del hueso; se compensa la escala del modelo (radio en metros)
		var y := d_local.normalized() if length > 1e-5 else Vector3.UP
		var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
		var bas := Basis(x, y, x.cross(y)).scaled(Vector3.ONE / world_scale)
		var mid := d_local * 0.5
		if zone == "head":
			mid = y * (0.09 / world_scale)
		cs.transform = Transform3D(bas, mid)
		body.add_child(cs)


## Recibe un impacto. Devuelve true si este impacto lo mató.
func apply_hit(info: HitInfo) -> bool:
	hits_received.append(info)
	if down:
		return false
	hp -= info.damage
	_show_number(info)
	if hp <= 0.0:
		down = true
		_rising = false
		var d := info.direction
		d.y = 0.0
		_fall_dir = d.normalized() if d.length() > 0.01 else -global_basis.z
		# Empujón inicial según el daño (más fuerte, cae más rápido)
		_ang = 0.0
		_ang_v = clampf(info.damage / 60.0, 0.4, 2.2)
		get_tree().create_timer(RESPAWN_TIME, false).timeout.connect(_respawn)
		return true
	return false


## Cabeza: si el tiro pasa cerca del centro, es letal.
func refine_zone(zone: String, hit_pos: Vector3, dir: Vector3) -> String:
	if zone != "head" or _sk == null or _head_bone < 0:
		return zone
	var hp_xf := _sk.global_transform * _sk.get_bone_global_pose(_head_bone)
	var center := hp_xf.origin + Vector3(0, 0.08, 0)
	var to_c := center - hit_pos
	var along := to_c.dot(dir)
	var closest := hit_pos + dir * clampf(along, 0.0, 0.35)
	return "head_core" if closest.distance_to(center) < 0.065 else "head"


func reset() -> void:
	hp = MAX_HP
	down = false
	_rising = false
	_ang = 0.0
	_ang_v = 0.0
	hits_received.clear()
	if _body != null:
		_body.transform = Transform3D.IDENTITY


func _respawn() -> void:
	if _looting:
		# Lo están revisando: se para cuando cierren la ventana
		get_tree().create_timer(1.0, false).timeout.connect(_respawn)
		return
	_make_loot()
	hp = MAX_HP
	down = false
	_rising = true


func _process(delta: float) -> void:
	if _body != null:
		if down:
			# Tabla que cae: aceleración angular por la gravedad (pivote en los pies)
			if _ang < PI * 0.5:
				_ang_v += 1.5 * 9.8 / HEIGHT * sin(maxf(_ang, 0.05)) * delta
				_ang += _ang_v * delta
				if _ang >= PI * 0.5:
					# Golpe contra el piso: rebota apenas y queda
					_ang = PI * 0.5
					_ang_v = -_ang_v * 0.18
			else:
				_ang_v += 1.5 * 9.8 / HEIGHT * delta
				_ang = minf(_ang + _ang_v * delta, PI * 0.5)
		elif _rising:
			_ang = move_toward(_ang, 0.0, delta * 2.2)
			if _ang <= 0.0:
				_rising = false
		var axis := Vector3.UP.cross(_fall_dir).normalized()
		var local_axis := (global_basis.inverse() * axis).normalized() if axis.length() > 0.5 else Vector3.RIGHT
		_body.transform = Transform3D(Basis(local_axis, _ang), Vector3.ZERO)
	for l in _labels:
		if l.visible:
			l.position.y += delta * 0.6
			l.modulate.a -= delta * 0.9
			if l.modulate.a <= 0.0:
				l.visible = false


func _show_number(info: HitInfo) -> void:
	if _labels.is_empty():
		return
	var l := _labels[_label_index]
	_label_index = (_label_index + 1) % _labels.size()
	l.text = tr("hit.lethal") if info.zone == "head_core" else "%d" % roundi(info.damage)
	l.modulate = ZONE_COLORS.get(info.zone, Color.WHITE)
	l.global_position = info.position + Vector3(0, 0.15, 0)
	l.visible = true
