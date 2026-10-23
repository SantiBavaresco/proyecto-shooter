extends Node
## Localización. Carga los textos desde res://localization/<idioma>.json
## y los registra en el TranslationServer, así funciona tr("clave").
##
## Para agregar un idioma: crear el JSON con las mismas claves que es.json
## y sumarlo a LANGUAGES. Un test verifica que no falten claves.

## Código → archivo. El orden es el del selector de Opciones.
const LANGUAGES: Dictionary = {
	"es": "res://localization/es.json",
	"en": "res://localization/en.json",
}
const FALLBACK := "es"

var _names: Dictionary = {}


func _ready() -> void:
	for code: String in LANGUAGES:
		_load_language(code, LANGUAGES[code])
	set_language(Settings.get_value("game", "language"))


func available_languages() -> Array[String]:
	var out: Array[String] = []
	for code: String in LANGUAGES:
		out.append(code)
	return out


## Nombre del idioma en su propio idioma (ej. "Español", "English").
func language_name(code: String) -> String:
	return _names.get(code, code)


func current_language() -> String:
	return TranslationServer.get_locale()


func set_language(code: String) -> void:
	if not LANGUAGES.has(code):
		push_warning("Loc: idioma desconocido '%s', uso %s" % [code, FALLBACK])
		code = FALLBACK
	if TranslationServer.get_locale() == code:
		return
	TranslationServer.set_locale(code)
	EventBus.language_changed.emit(code)


## Lee un JSON de idioma. Devuelve {} si falla. Público para los tests.
static func read_language_file(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		push_error("Loc: no existe %s" % file_path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(file_path))
	if parsed is Dictionary:
		return parsed
	push_error("Loc: JSON inválido en %s" % file_path)
	return {}


func _load_language(code: String, file_path: String) -> void:
	var data := read_language_file(file_path)
	if data.is_empty():
		return
	var t := Translation.new()
	t.locale = code
	for key: String in data:
		if key == "_meta":
			_names[code] = data["_meta"].get("name", code)
			continue
		t.add_message(key, str(data[key]))
	TranslationServer.add_translation(t)
