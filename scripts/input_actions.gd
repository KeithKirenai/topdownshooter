extends Node


func _ready() -> void:
	_ensure_action("move_left")
	_ensure_action("move_right")
	_ensure_action("move_up")
	_ensure_action("move_down")
	_ensure_action("shoot")
	_ensure_action("confirm")
	_ensure_action("shop")

	_add_key_event("move_left", KEY_A)
	_add_key_event("move_right", KEY_D)
	_add_key_event("move_up", KEY_W)
	_add_key_event("move_down", KEY_S)

	_add_mouse_event("shoot", MOUSE_BUTTON_LEFT)

	_add_joy_axis_event("move_left", JOY_AXIS_LEFT_X, -1.0)
	_add_joy_axis_event("move_right", JOY_AXIS_LEFT_X, 1.0)
	_add_joy_axis_event("move_up", JOY_AXIS_LEFT_Y, -1.0)
	_add_joy_axis_event("move_down", JOY_AXIS_LEFT_Y, 1.0)

	_add_joy_button_event("move_left", JOY_BUTTON_DPAD_LEFT)
	_add_joy_button_event("move_right", JOY_BUTTON_DPAD_RIGHT)
	_add_joy_button_event("move_up", JOY_BUTTON_DPAD_UP)
	_add_joy_button_event("move_down", JOY_BUTTON_DPAD_DOWN)

	_add_joy_axis_event("shoot", JOY_AXIS_TRIGGER_RIGHT, 0.5)
	_add_key_event("confirm", KEY_SPACE)
	_add_joy_button_event("confirm", JOY_BUTTON_A)
	_add_key_event("shop", KEY_TAB)
	_add_joy_button_event("shop", 6)

	_ensure_action("pause")
	_add_joy_button_event("pause", 7)

	_ensure_action("switch_weapon_prev")
	_add_key_event("switch_weapon_prev", KEY_Q)
	_add_joy_button_event("switch_weapon_prev", JOY_BUTTON_LEFT_SHOULDER)

	_ensure_action("switch_weapon_next")
	_add_key_event("switch_weapon_next", KEY_E)
	_add_joy_button_event("switch_weapon_next", JOY_BUTTON_RIGHT_SHOULDER)
	_add_joy_button_event("switch_weapon_next", JOY_BUTTON_Y)


func _ensure_action(action_name: String, deadzone: float = 0.5) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name, deadzone)


func _add_key_event(action_name: String, keycode: int) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode as Key
	InputMap.action_add_event(action_name, event)


func _add_mouse_event(action_name: String, button: int) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button as MouseButton
	InputMap.action_add_event(action_name, event)


func _add_joy_axis_event(action_name: String, axis: int, axis_value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = axis as JoyAxis
	event.axis_value = axis_value
	InputMap.action_add_event(action_name, event)


func _add_joy_button_event(action_name: String, button: int) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button as JoyButton
	InputMap.action_add_event(action_name, event)
