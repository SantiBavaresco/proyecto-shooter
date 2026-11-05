class_name PlayerActions
extends Node
## Acciones rápidas que no son disparar: cuchillazo (V) y tirar una granada (G).
## El arma baja mientras tanto y en la vista aparece el cuchillo o la granada.
##
##  - Cuchillo: estocada corta al frente. Por la espalda a alguien que no te vio, es
##    letal; si no, hace bastante daño (un chaleco lo frena en el torso).
##  - Granada: la saca, tira del seguro y la lanza hacia donde mira (más fuerte
##    cuanto más arriba apunta). Usa la primera granada del inventario.

const MELEE_TIME := 0.55
const MELEE_HIT_AT := 0.17
const MELEE_RANGE := 1.8
const MELEE_DAMAGE := 65.0
const THROW_TIME := 0.95
const THROW_AT := 0.5
const THROW_SPEED := 15.0
const GRENADE_IDS := ["grenade_rg5", "grenade_f1"]

var player: Player
var action: String = ""
var t: float = 0.0
var _done: bool = false
var _prop: Node3D
var _grenade_id: String = ""


func tick(cmd: PlayerCommand, delta: float) -> void:
	if player.is_dead:
		_end()
		return
	if action == "":
		var free := not player.inventory.is_using() and not GameState.ui_open
		if cmd.melee and free and player.inventory.equipment.get("melee") != null:
			_start("melee")
		elif cmd.grenade and free:
			var gid := _grenade_in_inventory()
			if gid != "":
				_grenade_id = gid
				_start("throw")
			else:
				EventBus.toast.emit(tr("grenade.none"))
		return
	t += delta
	if action == "melee":
		if not _done and t >= MELEE_HIT_AT:
			_done = true
			_melee_hit()
		_anim_knife()
		if t >= MELEE_TIME:
			_end()
	elif action == "throw":
		if not _done and t >= THROW_AT:
			_done = true
			_throw()
		_anim_grenade()
		if t >= THROW_TIME:
			_end()


func busy() -> bool:
	return action != ""


func _grenade_in_inventory() -> String:
	for id: String in GRENADE_IDS:
		if player.inventory.count_of(id) > 0:
			return id
	return ""


func _start(a: String) -> void:
	action = a
	t = 0.0
	_done = false
	player.weapons.lowered = true
	player.input_provider.cancel_aim()
	_make_prop()
	if a == "melee":
		_play(SynthSfx.knife(false), -8.0)
	else:
		_play(SynthSfx.click("pin", 1.5, 0.05), -8.0)


func _end() -> void:
	if action != "":
		player.weapons.lowered = false
	action = ""
	if _prop != null:
		_prop.queue_free()
		_prop = null


func _play(s: AudioStream, vol: float) -> void:
	var a := AudioStreamPlayer.new()
	a.bus = "SFX_World"
	a.stream = s
	a.volume_db = vol
	add_child(a)
	a.play()
	a.finished.connect(a.queue_free)


# --- Cuchillo ---------------------------------------------------------------------------

func _melee_hit() -> void:
	var cam := player.camera
	var from := cam.global_position
	var to := from - cam.global_basis.z * MELEE_RANGE
	var q := PhysicsRayQueryParameters3D.create(from, to, 1 | (1 << (NpcBody.HITBOX_LAYER - 1)))
	q.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
	EventBus.noise_emitted.emit(player.global_position, 4.0, player)
	if hit.is_empty():
		return
	var col := hit["collider"] as Node
	var target: Node = null
	if col != null and col.has_meta("zone_owner"):
		target = col.get_meta("zone_owner") as Node
	elif col != null:
		var n := col
		for i in 4:
			if n == null:
				break
			if n.has_method("apply_hit"):
				target = n
				break
			n = n.get_parent()
	var zone := String(col.get_meta("hit_zone", "torso")) if col != null else "torso"
	var info := HitInfo.new()
	info.position = hit["position"]
	info.normal = hit["normal"]
	info.direction = -cam.global_basis.z
	info.weapon_id = "melee"
	info.source = player
	info.zone = zone
	info.surface = Surface.of(col)
	info.penetration = 0.2
	info.damage = MELEE_DAMAGE * (1.8 if zone.begins_with("head") else (0.6 if zone == "limb" else 1.0))
	if target is HumanNpc and backstab(target as HumanNpc):
		info.damage = 400.0
		info.penetration = 5.0
		info.zone = "torso"
	if target != null and target.has_method("apply_hit"):
		var killed: bool = target.call("apply_hit", info)
		EventBus.hit_confirmed.emit(info, killed)
		_play(SynthSfx.knife(true), -4.0)
	else:
		CombatWorld.get_for(player).play_sound_at(SynthSfx.impact(info.surface), info.position, -6.0)


## Por la espalda y sin que te haya visto: letal.
func backstab(npc: HumanNpc) -> bool:
	if npc.brain == null or npc.brain.state == NpcBrain.State.COMBAT:
		return false
	var to_me := player.global_position - npc.global_position
	to_me.y = 0.0
	var fwd := -npc.global_basis.z
	return fwd.dot(to_me.normalized()) < -0.3


# --- Granada ----------------------------------------------------------------------------

func _throw() -> void:
	if player.inventory.take(_grenade_id, 1) <= 0:
		return
	var cam := player.camera
	var fwd := -cam.global_basis.z
	var g := Grenade.make(player, _grenade_id)
	var lvl := player.get_parent()
	lvl.add_child(g)
	g.global_position = cam.global_position + fwd * 0.4 + cam.global_basis.x * 0.15 - cam.global_basis.y * 0.05
	# Más arriba apunta, más lejos (y un empujoncito hacia arriba siempre)
	g.linear_velocity = fwd * THROW_SPEED + Vector3.UP * 2.5 + Vector3(player.velocity.x, 0, player.velocity.z)
	g.add_collision_exception_with(player)
	_play(SynthSfx.knife(false), -12.0)


# --- Vista ------------------------------------------------------------------------------

func _make_prop() -> void:
	var vp := player.weapons.viewmodel_viewport() if player.weapons != null else null
	if vp == null:
		return
	var id := "knife" if action == "melee" else _grenade_id
	if not ItemDB.has(id):
		return
	_prop = Node3D.new()
	var m := ItemModels.build(ItemDB.get_item(id))
	_prop.add_child(m)
	if action == "melee":
		# El modelo está acostado con la punta hacia +X: la punta hacia adelante (−Z)
		m.rotation = Vector3(0, PI * 0.5, PI * 0.5)
	vp.add_child(_prop)
	_prop.visible = false


func _anim_knife() -> void:
	if _prop == null:
		return
	var cam := player.weapons.viewmodel_camera()
	_prop.visible = true
	var k := sin(clampf(t / MELEE_TIME, 0.0, 1.0) * PI)
	var thrust := pow(k, 0.6)
	var local := Vector3(lerpf(0.22, 0.06, thrust), lerpf(-0.26, -0.1, thrust), lerpf(-0.3, -0.62, thrust))
	var rot := Basis.from_euler(Vector3(deg_to_rad(lerpf(-25, 5, thrust)), deg_to_rad(lerpf(20, 4, thrust)), 0))
	_prop.global_transform = cam.global_transform * Transform3D(rot, local)


func _anim_grenade() -> void:
	if _prop == null:
		return
	var cam := player.weapons.viewmodel_camera()
	_prop.visible = t < THROW_AT + 0.02
	var up := smoothstep(0.0, THROW_AT * 0.7, t)
	var back := smoothstep(THROW_AT * 0.6, THROW_AT, t)
	var local := Vector3(0.18, lerpf(-0.35, -0.12, up) + back * 0.08, lerpf(-0.3, -0.32, up) + back * 0.12)
	_prop.global_transform = cam.global_transform * Transform3D(Basis.from_euler(Vector3(0.3, 0.2, 0)), local)
