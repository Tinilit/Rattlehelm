class_name Combatant
extends CharacterBody2D

signal defeated(actor: Combatant)
signal air_landed(floor_point: Vector2)
signal recovered_health(floor_point: Vector2)
signal action_started(clip: StringName)
signal sound_requested(stream: AudioStream, floor_point: Vector2)
signal acted(command: ActionCommand.Kind)

const BUFFER_TICKS := 7
const ROLL_TICKS := 24
const TAKEOFF_TICKS := 3
const LAND_TICKS := 7
const FLASK_TICKS := 27
const FLASK_EFFECT_TICK := 16
const JUMP_SPEED := 515.0
const FLASK_HEAL := 30

@export var hurt_width := 10.0
@export var hurt_depth := 4.0
@export var hurt_floor := 5.0
@export var hurt_ceiling := 125.0

@onready var rig: FighterRig = get_node_or_null(^"Rig") as FighterRig
@onready var _shadow: Sprite2D = $Shadow

var spawn_id: int
var team: int
var max_health := 100
var health := 100
var flasks := 0
var weapon: WeaponDef
var speed := CombatSpace.SPEED.x
var action := ActionState.new()
var facing := 1
var height := 0.0
var vertical_speed := 0.0
var previous_floor := Vector2.ZERO
var invulnerable_ticks := 0
var last_action: StringName
var interact_requested := false
var reduce_flashes := false

var _floor_velocity := Vector2.ZERO
var _knockback := Vector2.ZERO
var _roll_direction := Vector2.ZERO
var _pending: ActionCommand
var _pending_until := 0
var _stagger_ticks := 0
var _air_attack_spent := false
var _allows_actor_collision := true


func _ready() -> void:
	previous_floor = position
	if rig != null:
		if weapon != null:
			rig.equip(weapon)
		present(0.0)


func is_dead() -> bool:
	return action.kind == ActionState.Kind.DEAD


func is_practice_target() -> bool:
	return false


func contact_material() -> AttackDef.ContactMaterial:
	return AttackDef.ContactMaterial.FLESH


func protected_from(definition: AttackDef) -> bool:
	if invulnerable_ticks > 0:
		return true
	return (
		action.kind == ActionState.Kind.ROLL
		and action.tick >= 3 and action.tick <= 11
		and definition.reach_height != AttackDef.ReachHeight.LOW
	)


func tick(intent: CombatIntent, room: RoomController, clock: int) -> void:
	interact_requested = false
	previous_floor = position
	if invulnerable_ticks > 0:
		invulnerable_ticks -= 1
	_end_expired_action()
	_use_commands(intent.commands, room, clock)
	_update_action_cues()
	_move_on_floor(intent.move)
	_update_height()


func _end_expired_action() -> void:
	match action.kind:
		ActionState.Kind.ATTACK:
			if action.tick >= action.attack.duration():
				action.start(ActionState.Kind.FREE)
		ActionState.Kind.ROLL:
			if action.tick >= ROLL_TICKS:
				action.start(ActionState.Kind.FREE)
		ActionState.Kind.TAKEOFF:
			if action.tick >= TAKEOFF_TICKS:
				vertical_speed = JUMP_SPEED
				_air_attack_spent = false
				action.start(ActionState.Kind.FREE)
		ActionState.Kind.LAND:
			if action.tick >= LAND_TICKS:
				action.start(ActionState.Kind.FREE)
		ActionState.Kind.STAGGER:
			if action.tick >= _stagger_ticks:
				action.start(ActionState.Kind.FREE)
		ActionState.Kind.FLASK:
			if action.tick >= FLASK_TICKS:
				action.start(ActionState.Kind.FREE)


func _use_commands(commands: Array[ActionCommand], room: RoomController, clock: int) -> void:
	if is_dead():
		_pending = null
		return
	if clock > _pending_until:
		_pending = null
	var next_pending := _pending
	for kind: int in ActionCommand.Kind.size():
		var candidate: ActionCommand
		for fresh: ActionCommand in commands:
			if fresh.kind == kind:
				candidate = fresh
				break
		var is_fresh := candidate != null
		if candidate == null and _pending != null and _pending.kind == kind:
			candidate = _pending
		if candidate == null:
			continue
		if _apply_command(candidate, room):
			_pending = null
			acted.emit(candidate.kind)
			return
		if is_fresh and kind <= ActionCommand.Kind.ATTACK and (
			next_pending == null or next_pending == _pending
		):
			next_pending = candidate
	if next_pending != _pending:
		_pending = next_pending
		_pending_until = clock + BUFFER_TICKS


func clear_commands() -> void:
	_pending = null


func _apply_command(command: ActionCommand, room: RoomController) -> bool:
	if command.kind == ActionCommand.Kind.ATTACK:
		return _try_attack(command.direction, room)
	if action.kind != ActionState.Kind.FREE or height > 0.0 or vertical_speed > 0.0:
		return false
	match command.kind:
		ActionCommand.Kind.ROLL:
			_roll_direction = command.direction.normalized()
			if _roll_direction == Vector2.ZERO:
				_roll_direction = Vector2(facing, 0.0)
			_aim(_roll_direction)
			_begin(ActionState.Kind.ROLL, &"roll")
		ActionCommand.Kind.JUMP:
			_aim(command.direction)
			_begin(ActionState.Kind.TAKEOFF, &"takeoff")
		ActionCommand.Kind.INTERACT:
			interact_requested = true
		ActionCommand.Kind.FLASK:
			if flasks == 0 or health == max_health:
				return false
			_begin(ActionState.Kind.FLASK, &"flask")
	return true


func _try_attack(direction: Vector2, room: RoomController) -> bool:
	if weapon == null:
		return false
	if action.kind == ActionState.Kind.ATTACK:
		var definition := action.attack
		if definition.follow_up != null and action.tick >= definition.combo_input_tick and (
			action.tick >= definition.chain_tick
		):
			_aim(direction)
			_begin_attack(definition.follow_up, action.impact_index + 1)
			return true
		return false
	if action.kind != ActionState.Kind.FREE:
		return false
	if height > 0.0 or vertical_speed > 0.0:
		if weapon.aerial == null or _air_attack_spent:
			return false
		_air_attack_spent = true
		_aim(direction)
		_begin_attack(weapon.aerial)
		return true
	_aim(direction)
	if weapon.kick != null and direction.length_squared() < 0.04 and room.has_kick_target(self):
		_begin_attack(weapon.kick)
	else:
		_begin_attack(weapon.opener)
	return true


func _begin_attack(definition: AttackDef, index: int = 0) -> void:
	action.start(ActionState.Kind.ATTACK, definition, index)
	last_action = definition.id
	action_started.emit(definition.clip)


func _begin(next: ActionState.Kind, clip: StringName) -> void:
	action.start(next)
	last_action = clip
	action_started.emit(clip)


func _aim(direction: Vector2) -> void:
	if absf(direction.x) > 0.08:
		facing = 1 if direction.x > 0.0 else -1


func _update_action_cues() -> void:
	match action.kind:
		ActionState.Kind.ATTACK:
			if action.tick == action.attack.swing_tick:
				sound_requested.emit(action.attack.swing_audio, position)
		ActionState.Kind.ROLL:
			if action.tick == 1:
				sound_requested.emit(preload("res://content/audio/roll.wav"), position)
		ActionState.Kind.FLASK:
			if action.tick == FLASK_EFFECT_TICK:
				flasks -= 1
				health = mini(max_health, health + FLASK_HEAL)
				sound_requested.emit(preload("res://content/audio/flask.wav"), position)
				recovered_health.emit(position)


func _move_on_floor(direction: Vector2) -> void:
	var desired := Vector2.ZERO
	var pass_through := action.kind == ActionState.Kind.ROLL or is_dead()
	if pass_through == _allows_actor_collision:
		_allows_actor_collision = not pass_through
		set_collision_mask_value(2, _allows_actor_collision)
		set_collision_layer_value(2, _allows_actor_collision)
	match action.kind:
		ActionState.Kind.FREE, ActionState.Kind.TAKEOFF:
			if action.kind == ActionState.Kind.FREE:
				_aim(direction)
			var control := 0.76 if height > 0.0 else 1.0
			desired = CombatSpace.velocity_for(direction, speed * control)
		ActionState.Kind.ROLL:
			var roll_speed := 468.0 if action.tick < 13 else 254.0
			desired = CombatSpace.velocity_for(_roll_direction, roll_speed)
		ActionState.Kind.ATTACK:
			if action.tick >= action.attack.advance_tick and action.tick < action.attack.startup + action.attack.active:
				desired.x = action.attack.advance_speed * facing
			if height > 0.0:
				desired = CombatSpace.velocity_for(direction, speed * 0.42)
	_floor_velocity = _floor_velocity.move_toward(desired, 67.5 if height == 0.0 else 41.0)
	if action.kind == ActionState.Kind.ROLL:
		_floor_velocity = desired
	velocity = _floor_velocity + _knockback
	move_and_slide()
	if get_slide_collision_count() > 0:
		var surface := get_last_slide_collision().get_normal()
		_knockback = _knockback.slide(surface)
		_floor_velocity = _floor_velocity.slide(surface)
	_knockback = _knockback.move_toward(Vector2.ZERO, 11.5)


func _update_height() -> void:
	if height <= 0.0 and vertical_speed <= 0.0:
		return
	height += vertical_speed * CombatSpace.STEP
	vertical_speed -= CombatSpace.GRAVITY * CombatSpace.STEP
	if height > 0.0:
		return
	height = 0.0
	vertical_speed = 0.0
	air_landed.emit(position)
	if action.kind in [ActionState.Kind.FREE, ActionState.Kind.ATTACK]:
		action.start(ActionState.Kind.LAND)


func take_contact(contact: CombatContact) -> void:
	if is_dead():
		return
	health = maxi(0, health - contact.attack.damage)
	_knockback = contact.push
	if health == 0:
		_begin(ActionState.Kind.DEAD, &"fall")
		defeated.emit(self)
		return
	if team == 0:
		invulnerable_ticks = 39
	_stagger_ticks = contact.attack.stun_ticks
	_begin(ActionState.Kind.STAGGER, &"stagger")


func present(delta: float) -> void:
	if rig == null:
		return
	_shadow.scale = Vector2.ONE * lerpf(0.75, 0.56, clampf(height / 95.0, 0.0, 1.0))
	_shadow.modulate.a = lerpf(1.0, 0.66, clampf(height / 95.0, 0.0, 1.0))
	rig.modulate = Color(1.22, 0.89, 0.78) if (
		invulnerable_ticks > 0 and invulnerable_ticks % 6 < 3 and not reduce_flashes
	) else Color.WHITE
	rig.sample(_current_clip(), action.revision, facing, height, delta)
	if action.kind == ActionState.Kind.FREE and height == 0.0 and action.tick % 16 == 8:
		if position.distance_squared_to(previous_floor) > 2.0:
			sound_requested.emit(preload("res://content/audio/boot.wav"), position)


func _current_clip() -> StringName:
	match action.kind:
		ActionState.Kind.ATTACK:
			return action.attack.clip
		ActionState.Kind.ROLL:
			return &"roll"
		ActionState.Kind.TAKEOFF:
			return &"takeoff"
		ActionState.Kind.LAND:
			return &"land"
		ActionState.Kind.STAGGER:
			return &"stagger"
		ActionState.Kind.DEAD:
			return &"fall"
		ActionState.Kind.FLASK:
			return &"flask"
	if height > 0.0:
		return &"airborne"
	return &"stride" if _floor_velocity.length_squared() > 220.0 else &"idle"
