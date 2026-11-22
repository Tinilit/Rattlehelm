class_name PlayPreferences
extends RefCounted

const PATH := "user://play_preferences.cfg"
const BUSES: Array[StringName] = [&"Master", &"Music", &"SFX"]

var shake := true
var particles := true
var reduce_flashes := false
var health_numbers := true
var diagnostics := false
var stick_deadzone := 0.2
var volume: Dictionary[StringName, float] = {&"Master": 0.8, &"Music": 0.55, &"SFX": 0.78}


func load_from_disk() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) == OK:
		shake = bool(config.get_value("effects", "shake", shake))
		particles = bool(config.get_value("effects", "particles", particles))
		reduce_flashes = bool(config.get_value("effects", "reduce_flashes", reduce_flashes))
		health_numbers = bool(config.get_value("interface", "health_numbers", health_numbers))
		stick_deadzone = clampf(float(config.get_value("controls", "stick_deadzone", stick_deadzone)), 0.10, 0.45)
		for bus: StringName in BUSES:
			volume[bus] = clampf(float(config.get_value("volume", bus, volume[bus])), 0.0, 1.0)
	apply_audio()


func save_to_disk() -> void:
	var config := ConfigFile.new()
	config.set_value("effects", "shake", shake)
	config.set_value("effects", "particles", particles)
	config.set_value("effects", "reduce_flashes", reduce_flashes)
	config.set_value("interface", "health_numbers", health_numbers)
	config.set_value("controls", "stick_deadzone", stick_deadzone)
	for bus: StringName in BUSES:
		config.set_value("volume", bus, volume[bus])
	var error := config.save(PATH)
	if error != OK:
		push_warning("Could not save play preferences (%s)" % error_string(error))


func apply_audio() -> void:
	for bus: StringName in BUSES:
		var index := AudioServer.get_bus_index(bus)
		AudioServer.set_bus_mute(index, volume[bus] <= 0.001)
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(0.001, volume[bus])))
