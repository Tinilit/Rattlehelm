class_name RoomController
extends Node2D

signal room_cleared
signal exit_requested
signal hero_defeated
signal frame_ready

@export var training_yard := false
@export var player_scene: PackedScene

@onready var actor_layer: Node2D = $Actors
@onready var marks: FloorMarks = $FloorMarks
@onready var fx: ArenaFX = $FX
@onready var sound: SoundStage = $Sound
@onready var _gate: Portcullis = $Portcullis
@onready var entry: Marker2D = $Anchors/Entry
@onready var exit: Marker2D = $Anchors/Exit
@onready var enemy_spawns: Node2D = $Anchors/EnemySpawns

var actor_list: Array[Combatant] = []
var hero: Combatant
var cleared := false
var clock := 0
var hitstop := 0
var players_hits := 0
var enemy_hits := 0
var enemy_misses := 0
var last_enemy_miss_depth := 0.0
var last_enemy_miss_facing := 0
var last_material := -1
var last_attack_facing := 0
var last_attack_start_tick := -1
var last_impact_tick := -1
var last_enemy_miss_tick := -1
var _brains: Dictionary[int, GatekeeperBrain] = {}
var _next_spawn_id := 1
var _living_enemies := 0
var _ending := false
var _defeat_ticks := 0
var _commands: PlayerCommandSource


func _ready() -> void:
	fx.camera = $Camera
	marks.exit_point = exit.position
	set_physics_process(false)


func begin(
	encounter: EncounterDef, loadout: WeaponDef, health: int, flasks: int,
	commands: PlayerCommandSource
) -> void:
	_commands = commands
	hero = spawn_actor(player_scene, loadout, entry.position, 0, 100)
	hero.health = health
	hero.flasks = flasks
	hero.action_started.connect(_on_hero_action)
	for child: Node in actor_layer.get_children():
		var target := child as PracticeTarget
		if target != null:
			target.spawn_id = _next_spawn_id
			_next_spawn_id += 1
			target.team = 1
			actor_list.append(target)
	if encounter != null:
		for index: int in encounter.roster.size():
			var definition := encounter.roster[index]
			var point := enemy_spawns.get_child(index) as Marker2D
			var actor := spawn_actor(definition.actor_scene, definition.weapon, point.position, 1, definition.health, -1)
			actor.speed = definition.move_speed
			_brains[actor.spawn_id] = GatekeeperBrain.new(definition, clock)
			actor.defeated.connect(_on_enemy_defeated)
			_living_enemies += 1
	cleared = _living_enemies == 0
	if cleared:
		_gate.open_immediately()
	marks.fighters = actor_list
	marks.gate_open = cleared
	set_physics_process(true)


func spawn_actor(
	scene: PackedScene, weapon: WeaponDef, floor_point: Vector2, team: int, hp: int, facing: int = 1
) -> Combatant:
	var actor := scene.instantiate() as Combatant
	actor.spawn_id = _next_spawn_id
	_next_spawn_id += 1
	actor.weapon = weapon
	actor.team = team
	actor.health = hp
	actor.max_health = hp
	actor.position = floor_point
	actor.facing = facing
	actor_layer.add_child(actor)
	actor.reset_physics_interpolation()
	actor.sound_requested.connect(sound.play)
	actor.air_landed.connect(_on_landing)
	actor_list.append(actor)
	return actor


func living_enemy() -> Combatant:
	for actor: Combatant in actor_list:
		if actor.team != 0 and not actor.is_practice_target() and not actor.is_dead():
			return actor
	return null


func has_kick_target(source: Combatant) -> bool:
	for target: Combatant in actor_list:
		var separation := target.position - source.position
		if (
			target.team != source.team and not target.is_dead() and target.height < 10.0
			and separation.x * source.facing > 0.0 and absf(separation.x) <= 25.0
			and absf(separation.y) <= 12.0
			and ContactResolver.clear_line(get_world_2d().direct_space_state, source.position, target.position)
		):
			return true
	return false


func can_exit() -> bool:
	return (
		cleared and not hero.is_dead() and _gate.is_open()
		and exit.position.distance_to(hero.position) < 63.0
	)


func flush_commands() -> void:
	_commands.clear()
	if hero != null:
		hero.clear_commands()


func _physics_process(delta: float) -> void:
	if _ending:
		return
	if hitstop > 0:
		hitstop -= 1
		frame_ready.emit()
		return
	clock += 1
	for actor: Combatant in actor_list:
		var intent: CombatIntent
		if actor == hero:
			intent = _commands.take_intent()
		elif _brains.has(actor.spawn_id):
			intent = _brains[actor.spawn_id].decide(actor, hero, clock)
		else:
			intent = CombatIntent.new()
		actor.tick(intent, self, clock)

	for actor: Combatant in actor_list:
		actor.sample_pose(delta)

	var contacts := ContactResolver.gather(actor_list, get_world_2d().direct_space_state)
	_note_whiffs()
	for contact: CombatContact in contacts:
		contact.target.take_contact(contact)
		hitstop = maxi(hitstop, contact.attack.hitstop)
		if contact.source == hero:
			players_hits += 1
			last_material = contact.target.contact_material()
			last_impact_tick = clock
		elif contact.target == hero:
			enemy_hits += 1

	for actor: Combatant in actor_list:
		actor.present(delta)
		fx.observe_weapon(actor)
		actor.action.tick += 1
	_present_contacts(contacts)

	if hero.is_dead():
		_defeat_ticks += 1
		if _defeat_ticks >= 37:
			_ending = true
			hero_defeated.emit()
	elif not cleared and _living_enemies == 0:
		cleared = true
		_gate.lift()
		sound.play(preload("res://content/audio/gate.wav"))
		room_cleared.emit()

	marks.gate_open = cleared and _gate.is_open()
	frame_ready.emit()
	if hero.interact_requested and can_exit():
		_ending = true
		exit_requested.emit()


func _present_contacts(contacts: Array[CombatContact]) -> void:
	var attacks_played: Dictionary[int, Dictionary] = {}
	for contact: CombatContact in contacts:
		var source := contact.source
		if (
			source.rig != null and source.action.attack == contact.attack
			and contact.attack.contact_on_weapon and not contact.attack.uses_blade_span
		):
			contact.point = source.rig.point_on_weapon(contact.point)
		var material := contact.target.contact_material()
		var sounds_played: Dictionary = attacks_played.get(source.spawn_id, {})
		if not sounds_played.has(material):
			sound.impact(material)
		fx.strike(contact, sounds_played.is_empty())
		sounds_played[material] = true
		attacks_played[source.spawn_id] = sounds_played


func _note_whiffs() -> void:
	for actor: Combatant in actor_list:
		var action := actor.action
		if actor.team == 0 or not action.active() or not action.struck.is_empty():
			continue
		if action.tick == action.attack.startup + action.attack.active - 1:
			enemy_misses += 1
			last_enemy_miss_tick = clock
			last_enemy_miss_depth = absf(hero.position.y - actor.position.y)
			last_enemy_miss_facing = actor.facing


func _on_landing(floor_point: Vector2) -> void:
	sound.play(preload("res://content/audio/boot.wav"), floor_point)
	fx.dust(floor_point)


func _on_enemy_defeated(_actor: Combatant) -> void:
	_living_enemies -= 1


func _on_hero_action(_clip: StringName) -> void:
	if hero.action.kind == ActionState.Kind.ATTACK:
		last_attack_facing = hero.facing
		last_attack_start_tick = clock
