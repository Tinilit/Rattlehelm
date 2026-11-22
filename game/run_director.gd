class_name RunDirector
extends Node2D

signal entered_room(definition: RoomDef)
signal frame_ready
signal completed(won: bool)

var room: RoomController
var state: RunState
var preferences: PlayPreferences
var _catalog: ContentCatalog
var _commands: PlayerCommandSource


func start(catalog: ContentCatalog, commands: PlayerCommandSource, practice: bool) -> void:
	_catalog = catalog
	_commands = commands
	state = RunState.new()
	state.practice = practice
	state.route.append(&"training_yard")
	if not practice:
		state.route.append(&"watch_gate")
	_load_room()


func dispose() -> void:
	if is_instance_valid(room):
		room.set_physics_process(false)
		remove_child(room)
		room.queue_free()
	room = null
	state = null


func _load_room() -> void:
	if is_instance_valid(room):
		room.set_physics_process(false)
		remove_child(room)
		room.queue_free()
	var definition := _catalog.rooms[state.route[state.route_index]]
	room = definition.room_scene.instantiate() as RoomController
	add_child(room)
	room.begin(definition.encounter, _catalog.weapons[state.weapon_id], state.health, state.flasks, _commands)
	apply_preferences()
	room.exit_requested.connect(_on_exit)
	room.hero_defeated.connect(_conclude.bind(false))
	room.frame_ready.connect(frame_ready.emit)
	_commands.clear()
	entered_room.emit(definition)


func apply_preferences() -> void:
	if room == null:
		return
	room.hero.reduce_flashes = preferences.reduce_flashes
	room.fx.shake_enabled = preferences.shake
	room.fx.particles_enabled = preferences.particles
	room.marks.diagnostics = preferences.diagnostics


func _on_exit() -> void:
	state.health = room.hero.health
	state.flasks = room.hero.flasks
	if state.route_index + 1 == state.route.size():
		_conclude(true)
		return
	state.route_index += 1
	_load_room.call_deferred()


func _conclude(won: bool) -> void:
	completed.emit.call_deferred(won)
