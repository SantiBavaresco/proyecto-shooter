class_name AnimalPack
extends Node3D
## Grupo de animales (jauría de perros, piara de jabalíes): los crea alrededor de su
## querencia y coordina que cuando uno se alarma se alarmen todos, y que si caen la
## mitad, los demás se vayan.

@export var species: String = "dog"
@export var count: int = 0  ## 0 = al azar según la especie
@export var roam: float = 22.0
@export var seed_value: int = 1

var home: Vector3
var members: Array[Animal] = []
var _start := 0
var _dead := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = seed_value
	home = global_position
	var sp := AnimalSpecies.get_species(species)
	var n := count if count > 0 else _rng.randi_range(sp.pack.x, sp.pack.y)
	for i in n:
		var a := Animal.new()
		a.species = species
		a.pack = self
		a.name = "%s%d" % [species.capitalize(), i]
		a.rng.seed = seed_value * 31 + i
		var off := Vector3(_rng.randf_range(-3, 3), 0, _rng.randf_range(-3, 3))
		a.rotation.y = _rng.randf() * TAU
		add_child(a)
		a.global_position = _ground(home + off)
		members.append(a)
	_start = n


## Uno vio, olió u oyó algo: le avisa a todo el grupo (cada uno reacciona a su tiempo).
func alarm(_who: Animal, target: Node3D) -> void:
	for m in members:
		if m.dead or m.state in [Animal.State.ATTACK, Animal.State.RETREAT, Animal.State.FLEE]:
			continue
		if m.state == Animal.State.WANDER:
			m._alert_on(target)
			m._t += _rng.randf_range(0.0, 1.2)
		elif m.spec.attack_style == "cornered" and m.state == Animal.State.ALERT:
			m._danger(target.global_position)


func member_died(_a: Animal) -> void:
	_dead += 1
	if should_flee():
		for m in members:
			if not m.dead and m.state not in [Animal.State.FLEE, Animal.State.HIDE, Animal.State.DYING]:
				if m.spec.attack_style == "cornered":
					m._danger(_a.global_position)
				else:
					m._flee(_a.global_position)


## Perdieron a una parte (perros: 1 de cada 3; jabalíes: 2 de cada 3): se van.
func should_flee() -> bool:
	var frac := AnimalSpecies.get_species(species).flee_frac
	return _start > 0 and float(_dead) >= ceilf(float(_start) * frac)


## Perros: de a dos como mucho se tiran a morder a la vez; el resto da vueltas.
var _darting: Array[Animal] = []


func can_dart(a: Animal) -> bool:
	_darting = _darting.filter(func(x: Animal) -> bool: return is_instance_valid(x) and not x.dead and x.state == Animal.State.ATTACK)
	if a in _darting:
		return true
	if _darting.size() >= 2:
		return false
	_darting.append(a)
	return true


func dart_done(a: Animal) -> void:
	_darting.erase(a)


func calm() -> void:
	pass


func alive() -> int:
	var n := 0
	for m in members:
		if not m.dead:
			n += 1
	return n


func _ground(p: Vector3) -> Vector3:
	var lvl := get_parent()
	while lvl != null and not lvl.has_method("height"):
		lvl = lvl.get_parent()
	if lvl != null:
		return Vector3(p.x, float(lvl.call("height", p.x, p.z)) + 0.1, p.z)
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 30.0, p + Vector3.DOWN * 30.0, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return (hit["position"] as Vector3) + Vector3(0, 0.1, 0) if not hit.is_empty() else p
