extends Node
## Estado global del juego y navegación entre pantallas.
##
## Boot → Title → Loading → Playing ⇄ Paused
## (Inventory, PDA, Dialogue, Trade y GameOver se suman en fases siguientes.)

enum State { BOOT, TITLE, LOADING, PLAYING, PAUSED }

const SCENE_TITLE := "res://ui/title/title_screen.tscn"
const SCENE_LOADING := "res://ui/loading/loading_screen.tscn"
const LEVEL_TEST_GREYBOX := "res://world/test_greybox/test_greybox.tscn"

const PauseMenuScript := preload("res://ui/pause/pause_menu.gd")
const UiTheme := preload("res://ui/theme/ui_theme.gd")

var state: State = State.BOOT
## Hay una pantalla abierta sobre el juego (inventario): el jugador no recibe input.
var ui_open: bool = false
## Nivel que la pantalla de carga tiene que cargar.
var pending_level: String = ""

var _pause_menu: CanvasLayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.theme = UiTheme.build()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if state == State.PLAYING and not ui_open:
			set_paused(true)
			get_viewport().set_input_as_handled()
		elif state == State.PAUSED and _pause_menu != null and _pause_menu.call("is_at_root"):
			set_paused(false)
			get_viewport().set_input_as_handled()


func goto_title() -> void:
	_clear_pause()
	ui_open = false
	_set_state(State.TITLE)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(SCENE_TITLE)


## Arranca un nivel pasando por la pantalla de carga.
func start_level(level_path: String) -> void:
	_clear_pause()
	ui_open = false
	pending_level = level_path
	_set_state(State.LOADING)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(SCENE_LOADING)


## Lo llama la pantalla de carga cuando terminó.
func on_level_loaded(packed: PackedScene) -> void:
	get_tree().change_scene_to_packed(packed)
	_set_state(State.PLAYING)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func set_paused(paused: bool) -> void:
	if paused == (state == State.PAUSED):
		return
	get_tree().paused = paused
	AudioManager.set_world_paused(paused)
	if paused:
		_set_state(State.PAUSED)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_pause_menu = CanvasLayer.new()
		_pause_menu.set_script(PauseMenuScript)
		add_child(_pause_menu)
	else:
		_clear_pause()
		_set_state(State.PLAYING)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if ui_open else Input.MOUSE_MODE_CAPTURED


func quit_game() -> void:
	get_tree().quit()


func state_name() -> String:
	return State.keys()[state]


## Inventario y pantallas parecidas: muestran el mouse y cortan el input del jugador
## (el mundo sigue andando).
func set_ui_open(open: bool) -> void:
	ui_open = open
	if state == State.PLAYING:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if open else Input.MOUSE_MODE_CAPTURED


func _clear_pause() -> void:
	get_tree().paused = false
	AudioManager.set_world_paused(false)
	if _pause_menu != null:
		_pause_menu.queue_free()
		_pause_menu = null


func _set_state(new_state: State) -> void:
	if new_state == state:
		return
	var prev := state
	state = new_state
	EventBus.game_state_changed.emit(prev, new_state)
