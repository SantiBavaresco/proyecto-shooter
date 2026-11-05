class_name ArenaConsole
extends StaticBody3D
## Consola de la zona de combate de la pista de pruebas: [F] cambia la dificultad
## de los enemigos o vuelve a poner el grupo de 5.

signal used(action: String)

## "difficulty" o "reset".
@export var action: String = "difficulty"

var _label: Label3D


func _ready() -> void:
	set_meta("surface", "metal")
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.8, 1.1, 0.5)
	cs.shape = bs
	cs.position = Vector3(0, 0.55, 0)
	add_child(cs)
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.8, 1.1, 0.5)
	body.mesh = bm
	body.position = Vector3(0, 0.55, 0)
	body.material_override = Structures.mat("metal")
	add_child(body)
	var screen := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.6, 0.35)
	screen.mesh = qm
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.05, 0.15, 0.1)
	sm.emission_enabled = true
	sm.emission = Color(0.1, 0.5, 0.25) if action == "difficulty" else Color(0.55, 0.3, 0.1)
	screen.material_override = sm
	screen.position = Vector3(0, 0.85, 0.26)
	add_child(screen)
	_label = Label3D.new()
	_label.font_size = 40
	_label.pixel_size = 0.004
	_label.outline_size = 8
	_label.position = Vector3(0, 1.5, 0)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(_label)
	refresh()


func refresh() -> void:
	if action == "difficulty":
		_label.text = tr("arena.difficulty") % tr(Difficulty.name_key(GameState.difficulty))
	else:
		_label.text = tr("arena.reset_label")


func get_interact_text() -> String:
	return tr("arena.change_difficulty") if action == "difficulty" else tr("arena.reset")


func interact(_player: Node) -> void:
	if action == "difficulty":
		GameState.difficulty = (GameState.difficulty + 1) % 3
		EventBus.toast.emit(tr("arena.difficulty") % tr(Difficulty.name_key(GameState.difficulty)))
	Foley.play(get_tree(), "equip", -8.0)
	refresh()
	used.emit(action)
