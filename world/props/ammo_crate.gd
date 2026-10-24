class_name AmmoCrate
extends StaticBody3D
## Caja de munición del laboratorio: [F] repone la munición de todas las armas.


func _ready() -> void:
	set_meta("surface", "wood")
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.9, 0.5, 0.5)
	cs.shape = sh
	cs.position = Vector3(0, 0.25, 0)
	add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = sh.size
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.3, 0.33, 0.2)
	m.roughness = 0.8
	mi.material_override = m
	mi.position = cs.position
	add_child(mi)
	var stripe := MeshInstance3D.new()
	var sb := BoxMesh.new()
	sb.size = Vector3(0.92, 0.08, 0.52)
	stripe.mesh = sb
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.79, 0.64, 0.15)
	stripe.material_override = sm
	stripe.position = Vector3(0, 0.38, 0)
	add_child(stripe)


func get_interact_text() -> String:
	return "interact.ammo_crate"


func interact(player: Node) -> void:
	var p := player as Player
	if p != null and p.weapons != null:
		p.weapons.refill_all()
		EventBus.toast.emit(tr("interact.ammo_refilled"))
