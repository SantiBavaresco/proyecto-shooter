extends TestCase
## Verifica que todos los idiomas tengan exactamente las mismas claves
## y que el código no use claves inexistentes.


func test_all_languages_have_same_keys() -> void:
	var base := Loc.read_language_file(Loc.LANGUAGES[Loc.FALLBACK])
	assert_false(base.is_empty(), "el idioma base no cargó")
	for code: String in Loc.LANGUAGES:
		var other := Loc.read_language_file(Loc.LANGUAGES[code])
		for key: String in base:
			assert_true(other.has(key), "falta '%s' en %s" % [key, code])
		for key: String in other:
			assert_true(base.has(key), "'%s' sobra en %s (no existe en %s)" % [key, code, Loc.FALLBACK])


func test_every_rebindable_action_has_name() -> void:
	var base := Loc.read_language_file(Loc.LANGUAGES[Loc.FALLBACK])
	for action: String in InputActions.REBINDABLE:
		assert_true(base.has("action." + action), "falta el nombre de la acción %s" % action)


func test_code_uses_only_existing_keys() -> void:
	var base := Loc.read_language_file(Loc.LANGUAGES[Loc.FALLBACK])
	var re := RegEx.create_from_string("tr\\(\"([a-z_]+\\.[a-z0-9_]+)\"\\)")
	for path in _gd_files("res://"):
		var src := FileAccess.get_file_as_string(path)
		for m in re.search_all(src):
			var key := m.get_string(1)
			assert_true(base.has(key), "%s usa la clave inexistente '%s'" % [path, key])


func test_switching_language_translates() -> void:
	var prev := Loc.current_language()
	Loc.set_language("en")
	assert_eq(tr("menu.options"), "Options")
	Loc.set_language("es")
	assert_eq(tr("menu.options"), "Opciones")
	Loc.set_language(prev)


func _gd_files(dir: String) -> PackedStringArray:
	var out: PackedStringArray = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		if d.begins_with(".") or d == "addons":
			continue
		out.append_array(_gd_files(dir.path_join(d)))
	return out
