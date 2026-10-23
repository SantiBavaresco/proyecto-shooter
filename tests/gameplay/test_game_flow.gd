extends TestCase
## Flujo de estados y menús (sin cambiar de escena, para no matar al runner).

const TitleScreen := preload("res://ui/title/title_screen.tscn")
const OptionsMenu := preload("res://ui/options/options_menu.gd")


func after_each() -> void:
	GameState.set_paused(false)
	GameState.state = GameState.State.BOOT
	get_tree().paused = false


func test_level_loads_in_background() -> void:
	var path := GameState.LEVEL_TEST_GREYBOX
	assert_eq(ResourceLoader.load_threaded_request(path), OK)
	var status := ResourceLoader.THREAD_LOAD_IN_PROGRESS
	for i in 600:
		status = ResourceLoader.load_threaded_get_status(path)
		if status != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			break
		await process_frames(1)
	assert_eq(status, ResourceLoader.THREAD_LOAD_LOADED)
	assert_true(ResourceLoader.load_threaded_get(path) is PackedScene)


func test_pause_and_resume() -> void:
	GameState.state = GameState.State.PLAYING
	GameState.set_paused(true)
	assert_eq(GameState.state, GameState.State.PAUSED)
	assert_true(get_tree().paused)
	assert_true(AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")), "pausa silencia la música")
	assert_true(AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX_World")), "pausa silencia el mundo")
	assert_false(AudioServer.is_bus_mute(AudioServer.get_bus_index("UI")), "la UI sigue sonando")
	await process_frames(2)
	GameState.set_paused(false)
	assert_eq(GameState.state, GameState.State.PLAYING)
	assert_false(get_tree().paused)
	assert_false(AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")), "al volver se restaura")


func test_title_screen_builds_in_both_languages() -> void:
	for code in Loc.available_languages():
		Loc.set_language(code)
		var t := TitleScreen.instantiate()
		add_child(t)
		await process_frames(2)
		var buttons := t.find_children("*", "Button", true, false)
		assert_eq(buttons.size(), 5, "5 botones en el título (%s)" % code)
		t.queue_free()
		await process_frames(1)
	Loc.set_language("es")


func test_options_menu_builds() -> void:
	var o := Control.new()
	o.set_script(OptionsMenu)
	add_child(o)
	await process_frames(2)
	var tabs := o.find_children("*", "TabContainer", true, false)
	assert_eq(tabs.size(), 1)
	assert_eq((tabs[0] as TabContainer).get_tab_count(), 4)
	o.queue_free()


func test_bug_report_written() -> void:
	var p := DebugTools.save_bug_report()
	assert_true(p != "" and FileAccess.file_exists(p), "se guarda el reporte")
	var txt := FileAccess.get_file_as_string(p)
	assert_true(txt.contains("REPORTE DE BUG"))
	DirAccess.remove_absolute(p)
