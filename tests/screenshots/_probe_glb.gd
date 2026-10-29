extends SceneTree
var done := false
func _process(_d):
	if done: return true
	done = true
	for a in OS.get_cmdline_user_args():
		_one(a)
	quit()
	return true

func _one(path: String) -> void:
	var inst := (load(path) as PackedScene).instantiate() as Node3D
	root.add_child(inst)
	print("=== ", path)
	var total := AABB()
	var first := true
	for mi: MeshInstance3D in inst.find_children("*", "MeshInstance3D", true, false):
		var xf := inst.global_transform.affine_inverse() * mi.global_transform
		var ab := xf * mi.get_aabb()
		if mi.skin != null:
			var sk := mi.get_node_or_null(mi.skeleton) as Skeleton3D
			ab = AABB()
			# aproximado: vértices en pose de reposo del esqueleto
			var arr := mi.mesh.surface_get_arrays(0)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var bones = arr[Mesh.ARRAY_BONES]
			var f := true
			for i in range(0, v.size(), 7):
				var b: int = bones[i * 4]
				var bi := mi.skin.get_bind_bone(b) if mi.skin.get_bind_bone(b) >= 0 else sk.find_bone(mi.skin.get_bind_name(b))
				var p := inst.global_transform.affine_inverse() * sk.global_transform * sk.get_bone_global_pose(bi) * mi.skin.get_bind_pose(b) * v[i]
				if f: ab = AABB(p, Vector3.ZERO); f = false
				else: ab = ab.expand(p)
		var chain := ""
		var n: Node = mi
		for k in 3:
			n = n.get_parent()
			if n == null or n == inst: break
			chain = String(n.name) + "/" + chain
		print("  %-60s skin=%s tris=%d  pos=%s size=%s" % [chain + String(mi.name), mi.skin != null, _tris(mi.mesh), (ab.position + ab.size * 0.5).snapped(Vector3.ONE * 0.001), ab.size.snapped(Vector3.ONE * 0.001)])
		if first: total = ab; first = false
		else: total = total.merge(ab)
	print("  TOTAL center=", (total.position + total.size * 0.5).snapped(Vector3.ONE * 0.001), " size=", total.size.snapped(Vector3.ONE * 0.001))
	inst.queue_free()

func _tris(m: Mesh) -> int:
	var t := 0
	for s in m.get_surface_count():
		var a := m.surface_get_arrays(s)
		t += (a[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3 if a[Mesh.ARRAY_INDEX] != null else (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return t
