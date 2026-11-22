extends Node

@onready var _run: RunDirector = $Run
@onready var _sound: SoundStage = $Sound
@onready var _commands: PlayerCommandSource = $Commands
@onready var _interface: GameInterface = $HUD/Interface

var _catalog := ContentCatalog.new()
var _preferences := PlayPreferences.new()
var _probe := WebPlaytestProbe.new()
var _screen: StringName = &"title"
var _won := false
var _option_origin: StringName
var _quitting := false


func _ready() -> void:
	get_tree().auto_accept_quit = false
	TranslationServer.add_translation(preload("res://ui/locale/interface.en.tres"))
	if not _catalog.build([ContentCatalog.FORTRESS]):
		for message: String in _catalog.errors:
			push_error(message)
		get_tree().quit(1)
		return
	_preferences.load_from_disk()
	_commands.stick_deadzone = _preferences.stick_deadzone
	_run.preferences = _preferences
	_interface.preferences = _preferences
	_interface.source = _commands
	_run.entered_room.connect(_on_room_entered)
	_run.completed.connect(_on_run_completed)
	_run.frame_ready.connect(_refresh)
	_interface.chosen.connect(_on_choice)
	_commands.active_device_lost.connect(_pause_if_battling)
	_commands.device_changed.connect(_refresh)
	_show_title()


func _input(event: InputEvent) -> void:
	if event.is_echo() or not event.is_pressed():
		return
	if event.is_action_pressed(&"pause_game") and _screen == &"battle":
		_pause_if_battling()
	elif _screen == &"pause" and (event.is_action_pressed(&"pause_game") or event.is_action_pressed(&"ui_cancel")):
		_resume()
	elif _screen in [&"settings", &"credits"] and event.is_action_pressed(&"ui_cancel"):
		_leave_overlay()
	elif _screen == &"battle" and event.is_action_pressed(&"show_diagnostics"):
		_preferences.diagnostics = not _preferences.diagnostics
		_run.apply_preferences()
	else:
		return
	get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_pause_if_battling()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		_quit.call_deferred()


func _quit() -> void:
	if _quitting:
		return
	_quitting = true
	_commands.enabled = false
	_sound.stop_all()
	_run.dispose()
	await get_tree().create_timer(0.12).timeout
	get_tree().quit()


func _on_choice(choice: StringName) -> void:
	match choice:
		&"play":
			_start(false)
		&"training":
			_start(true)
		&"settings":
			_option_origin = _screen
			_screen = &"settings"
			_interface.options()
		&"credits":
			_option_origin = _screen
			_screen = &"credits"
			_interface.credits()
		&"back":
			_leave_overlay()
		&"resume":
			_resume()
		&"title":
			_show_title()
		&"quit":
			_quit()
	_refresh()


func _show_title() -> void:
	_commands.enabled = false
	_commands.clear()
	get_tree().paused = false
	_run.dispose()
	_screen = &"title"
	_interface.title(_catalog.weapons[&"sword"])
	_refresh()


func _start(practice: bool) -> void:
	_sound.start_score()
	get_tree().paused = false
	_screen = &"battle"
	_commands.enabled = true
	_won = false
	_run.start(_catalog, _commands, practice)


func _on_room_entered(definition: RoomDef) -> void:
	_interface.battle(definition, _run.state.practice)
	_sound.play(preload("res://content/audio/draw.wav"))
	_refresh()


func _pause_if_battling() -> void:
	if _screen != &"battle" or _run == null or _run.room == null:
		return
	_screen = &"pause"
	_run.room.flush_commands()
	_commands.enabled = false
	get_tree().paused = true
	_interface.pause_menu()
	_refresh()


func _resume() -> void:
	_run.room.flush_commands()
	_interface.close_menu()
	_screen = &"battle"
	_commands.enabled = true
	get_tree().paused = false
	_refresh()


func _leave_overlay() -> void:
	if _screen == &"settings":
		_preferences.save_to_disk()
		_commands.stick_deadzone = _preferences.stick_deadzone
		_run.apply_preferences()
	if _option_origin == &"pause":
		_screen = &"pause"
		_interface.pause_menu()
	else:
		_show_title()
	_refresh()


func _on_run_completed(won: bool) -> void:
	if _run.state.practice:
		_show_title()
		return
	_won = won
	_screen = &"summary"
	_commands.enabled = false
	_commands.clear()
	_interface.summary(won)
	_refresh()


func _refresh() -> void:
	if _run.room != null:
		_interface.update_battle(_run.room)
	_probe.publish(_screen, _run, get_tree().paused, _won)
