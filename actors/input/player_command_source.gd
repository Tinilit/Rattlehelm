class_name PlayerCommandSource
extends Node

signal device_changed
signal active_device_lost

const ACTIONS: Array[StringName] = [
	&"roll", &"jump", &"attack", &"interact", &"flask"
]
const MOVE_ACTIONS: Array[StringName] = [
	&"move_left", &"move_right", &"move_back", &"move_front"
]
const PAD_POSITIONS := {
	JOY_BUTTON_A: "SOUTH", JOY_BUTTON_B: "EAST", JOY_BUTTON_X: "WEST",
	JOY_BUTTON_Y: "NORTH", JOY_BUTTON_LEFT_SHOULDER: "LB",
	JOY_BUTTON_START: "MENU",
}

var enabled := false
var stick_deadzone := 0.2

var _queue: Array[ActionCommand] = []
var _pad := -1
var _stick_engaged := false


func _ready() -> void:
	Input.joy_connection_changed.connect(_on_joy_connection_changed)


func _input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event is InputEventJoypadMotion and event.axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
		var magnitude := _raw_stick(event.device).length()
		if magnitude > maxf(stick_deadzone, 0.32) and (not _stick_engaged or _pad != event.device):
			_set_device(event.device)
		if event.device == _pad:
			_stick_engaged = magnitude > maxf(stick_deadzone, 0.32)
	if event is InputEventKey or event is InputEventJoypadButton:
		for action: StringName in MOVE_ACTIONS + ACTIONS:
			if event.is_action_pressed(action):
				_set_device(event.device if event is InputEventJoypadButton else -1)
				break
	if not enabled:
		return
	for kind: int in ACTIONS.size():
		if event.is_action_pressed(ACTIONS[kind]):
			_enqueue(kind as ActionCommand.Kind, movement())
			break


func _enqueue(kind: ActionCommand.Kind, direction: Vector2) -> void:
	for command: ActionCommand in _queue:
		if command.kind == kind:
			return
	_queue.append(ActionCommand.new(kind, direction))


func movement() -> Vector2:
	var digital := Input.get_vector(
		&"move_left", &"move_right", &"move_back", &"move_front", 0.0
	)
	var analog := Vector2.ZERO
	if _pad >= 0:
		analog = radial_response(_raw_stick(_pad), stick_deadzone)
	else:
		for device: int in Input.get_connected_joypads():
			var candidate := radial_response(_raw_stick(device), stick_deadzone)
			if candidate.length_squared() > analog.length_squared():
				analog = candidate
	return digital if digital.length_squared() > analog.length_squared() else analog


func take_intent() -> CombatIntent:
	var intent := CombatIntent.new()
	intent.move = movement()
	intent.commands.assign(_queue)
	_queue.clear()
	return intent


func clear() -> void:
	_queue.clear()


func action_label(action: StringName) -> String:
	for binding: InputEvent in InputMap.action_get_events(action):
		if _pad >= 0 and binding is InputEventJoypadButton:
			var pad_name := Input.get_joy_name(_pad).to_lower()
			var index: int = binding.button_index
			if "playstation" in pad_name or "dualsense" in pad_name or "dualshock" in pad_name:
				var playstation := {0: "×", 1: "○", 2: "□", 3: "△", 9: "L1", 6: "OPTIONS"}
				return String(playstation.get(index, tr(&"BUTTON_NUMBER") % index))
			if "xbox" in pad_name or "xinput" in pad_name:
				var xbox := {0: "A", 1: "B", 2: "X", 3: "Y", 9: "LB", 6: "MENU"}
				return String(xbox.get(index, tr(&"BUTTON_NUMBER") % index))
			if PAD_POSITIONS.has(index):
				return tr(StringName(PAD_POSITIONS[index]))
			return tr(&"BUTTON_NUMBER") % index
		if _pad < 0 and binding is InputEventKey:
			return OS.get_keycode_string(binding.physical_keycode)
	return ""


func movement_label() -> String:
	return tr(&"MOVE_PAD") if _pad >= 0 else tr(&"MOVE_KEYS")


static func radial_response(raw: Vector2, deadzone: float) -> Vector2:
	var magnitude := raw.length()
	if magnitude <= deadzone:
		return Vector2.ZERO
	return raw / magnitude * inverse_lerp(deadzone, 1.0, minf(magnitude, 1.0))


func _raw_stick(device: int) -> Vector2:
	return Vector2(
		Input.get_joy_axis(device, JOY_AXIS_LEFT_X),
		Input.get_joy_axis(device, JOY_AXIS_LEFT_Y)
	)


func _set_device(device: int) -> void:
	if _pad != device:
		_pad = device
		_stick_engaged = false
		device_changed.emit()


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if not connected and device == _pad:
		clear()
		_set_device(-1)
		active_device_lost.emit()
