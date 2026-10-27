class_name ImportedWeapon
extends RefCounted
## Armas importadas (.glb con brazos, esqueleto y animaciones propias).
##
## El modelo trae su animación (sacar, quieta, disparo, recargas, guardar); el juego
## sigue poniendo por código todo lo demás: balanceo, retroceso, estrés, respiración y
## fallas. No trae animación de apuntar: la mira se calcula sobre el hueso del arma y
## cada cuadro se alinea con la cámara.
##
## model_params:
##  - scene: ruta del .glb. gun_bone: hueso del arma (su +Y apunta adelante, −Z arriba).
##  - sight / muzzle / ejection: puntos en el espacio de ese hueso.
##  - eye: dónde estaría el ojo en el modelo, para la pose de cadera.
##  - anims: nombres de las animaciones {draw, idle, shoot, reload, reload_empty, holster}
##    y rack_from: segundo de reload_empty desde el que monta (para destrabar).

## Base de los marcadores sobre el hueso: −Z = adelante (+Y del hueso), +Y = arriba.
const MARKER_BASIS := Basis(Vector3(-1, 0, 0), Vector3(0, 0, -1), Vector3(0, -1, 0))


static func build(data: WeaponData) -> Node3D:
	var p := data.model_params
	var root := Node3D.new()
	root.name = data.id
	root.set_meta("imported", true)
	var inst := (load(String(p["scene"])) as PackedScene).instantiate() as Node3D
	inst.name = "Inst"
	root.add_child(inst)
	# Sombras y luces del viewmodel: el modelo no proyecta sombra propia
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var sk := inst.find_child("Skeleton3D", true, false) as Skeleton3D
	var mount := BoneAttachment3D.new()
	mount.name = "GunMount"
	mount.bone_name = String(p.get("gun_bone", "Bone_043")).replace(":", "_")
	sk.add_child(mount)
	for n: String in ["sight", "muzzle", "ejection"]:
		var mk := Marker3D.new()
		mk.name = "Gun_" + n
		mk.transform = Transform3D(MARKER_BASIS, _v(p.get(n, [0, 0, 0])))
		mount.add_child(mk)
		# Copia en la raíz (la vista la actualiza cada cuadro): el resto del juego
		# sigue leyendo "Sight", "Muzzle" y "Ejection" como en los modelos por código
		var top := Marker3D.new()
		top.name = n.capitalize()
		root.add_child(top)
	(root.get_node("Sight") as Node3D).set_meta("eye_relief", float(p.get("eye_relief", 0.32)))
	var ap := inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	root.set_meta("ap", ap)
	root.set_meta("mount", mount)
	return root


static func _v(a: Variant) -> Vector3:
	if a is Vector3:
		return a
	var arr: Array = a
	return Vector3(float(arr[0]), float(arr[1]), float(arr[2]))


static func anim_name(data: WeaponData, key: String) -> String:
	var anims: Dictionary = data.model_params.get("anims", {})
	return String(anims.get(key, key.to_upper()))


static func anim_length(model: Node3D, data: WeaponData, key: String) -> float:
	var ap := model.get_meta("ap") as AnimationPlayer
	var n := anim_name(data, key)
	return ap.get_animation(n).length if ap != null and ap.has_animation(n) else 1.0


## Segundos que dura montar (el tramo final de la recarga vacía).
static func rack_time(model: Node3D, data: WeaponData) -> float:
	return anim_length(model, data, "reload_empty") - float(data.model_params.get("rack_from", 0.0))


## Intentos fallidos al brocal (estrés): cuánto tiempo de animación agrega cada uno.
## En cada intento el cargador llega al brocal, pega, vuelve atrás y reintenta.
const FUMBLE_HOLD := 0.12


static func fumble_span(data: WeaponData, key: String) -> float:
	var seat: Array = (data.model_params.get("seat", {}) as Dictionary).get(key, [])
	if seat.size() < 2:
		return 0.0
	return (float(seat[1]) - float(seat[0])) * 2.0 + FUMBLE_HOLD


## Tiempo de la animación de recarga para "u" segundos de animación extendida con
## "n" intentos fallidos. Devuelve [tiempo, fase del intento (−1 si no hay)].
static func reload_anim_time(data: WeaponData, key: String, u: float, n: int) -> Vector2:
	var seat: Array = (data.model_params.get("seat", {}) as Dictionary).get(key, [])
	if n <= 0 or seat.size() < 2:
		return Vector2(u, -1.0)
	var t_back := float(seat[0])
	var t_miss := float(seat[1])
	var span := fumble_span(data, key)
	if u < t_miss:
		return Vector2(u, -1.0)
	if u >= t_miss + span * n:
		return Vector2(u - span * n, -1.0)
	var k := fmod(u - t_miss, span)
	var phase := floorf((u - t_miss) / span)
	var back := t_miss - t_back
	if k < FUMBLE_HOLD:
		return Vector2(t_miss, phase)  # pega en el borde del brocal
	k -= FUMBLE_HOLD
	if k < back:
		return Vector2(t_miss - k, phase + 0.3)  # lo saca un poco
	return Vector2(t_back + (k - back), phase + 0.6)  # y vuelve a intentar


## Mira sobre el hueso del arma, en el espacio del modelo instanciado (sin la pose
## de cadera/apuntado que la vista le aplica encima).
static func sight_in_inst(model: Node3D) -> Transform3D:
	var inst := model.get_node("Inst") as Node3D
	var mk := (model.get_meta("mount") as Node3D).get_node("Gun_sight") as Node3D
	return inst.global_transform.affine_inverse() * mk.global_transform


## Copia los marcadores del hueso a la raíz del arma.
static func sync_markers(model: Node3D) -> void:
	var mount := model.get_meta("mount") as Node3D
	var inv := model.global_transform.affine_inverse()
	for n: String in ["sight", "muzzle", "ejection"]:
		(model.get_node(n.capitalize()) as Node3D).transform = inv * (mount.get_node("Gun_" + n) as Node3D).global_transform
