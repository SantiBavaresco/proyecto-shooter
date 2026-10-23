extends TestCase


func after_each() -> void:
	InputActions.register_defaults()


func test_all_actions_registered() -> void:
	for action: String in InputActions.DEFAULTS:
		assert_true(InputMap.has_action(action), "falta la acción %s" % action)


func test_rebindable_actions_exist_and_have_key() -> void:
	for action: String in InputActions.REBINDABLE:
		assert_true(InputActions.DEFAULTS.has(action), "%s no está en DEFAULTS" % action)
		assert_true(InputActions.get_kbm_event(action) != null, "%s no tiene tecla por defecto" % action)


func test_no_duplicate_default_keys() -> void:
	var seen: Dictionary = {}
	for action: String in InputActions.REBINDABLE:
		var d := InputActions.event_to_dict(InputActions.get_kbm_event(action))
		var k := str(d)
		assert_false(seen.has(k), "%s y %s usan la misma tecla" % [action, seen.get(k, "")])
		seen[k] = action


func test_serialization_roundtrip() -> void:
	var e := InputActions.event_from_dict({"key": KEY_K})
	var d := InputActions.event_to_dict(e)
	assert_eq(d, {"key": KEY_K})
	var m := InputActions.event_from_dict({"mouse": MOUSE_BUTTON_XBUTTON1})
	assert_eq(InputActions.event_to_dict(m), {"mouse": MOUSE_BUTTON_XBUTTON1})


func test_set_kbm_event_keeps_joypad() -> void:
	InputActions.set_kbm_event("jump", InputActions.event_from_dict({"key": KEY_K}))
	var has_joy := false
	for e in InputMap.action_get_events("jump"):
		if e is InputEventJoypadButton:
			has_joy = true
	assert_true(has_joy, "el remapeo no debe borrar el botón de joystick")
	assert_eq(InputActions.event_to_dict(InputActions.get_kbm_event("jump")), {"key": KEY_K})


func test_find_conflict() -> void:
	var w := InputActions.event_from_dict({"key": KEY_W})
	assert_eq(InputActions.find_conflict("jump", w), "move_forward")
	assert_eq(InputActions.find_conflict("move_forward", w), "")
