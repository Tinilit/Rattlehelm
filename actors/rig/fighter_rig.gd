class_name FighterRig
extends Node2D

const SOCKET_PATH := ^"Facing/Skeleton/Hip/Spine/Chest/NearShoulder/NearElbow/NearHand/WeaponSocket"

@onready var _facing_node: Node2D = $Facing
@onready var _mixer: AnimationTree = $AnimationTree
@onready var _playback: AnimationNodeStateMachinePlayback = _mixer.get("parameters/playback")
@onready var _socket: Marker2D = get_node(SOCKET_PATH)

@onready var _bottle: Sprite2D = get_node_or_null(
	^"Facing/Skeleton/Hip/Spine/Chest/FarShoulder/FarElbow/FarHand/Bottle"
) as Sprite2D

var _held: Node2D
var _tip: Marker2D
var _clip: StringName
var _revision := -1
var _facing := 1


func equip(weapon: WeaponDef) -> void:
	if is_instance_valid(_held):
		_socket.remove_child(_held)
		_held.queue_free()
	_held = weapon.held_scene.instantiate() as Node2D
	_socket.add_child(_held)
	var grip: Marker2D = _held.get_node(^"Grip")
	_held.position = -grip.position
	_tip = _held.get_node(^"Tip")


func sample(clip: StringName, revision: int, facing: int, height: float, delta: float) -> void:
	if facing != _facing:
		_facing = facing
		_facing_node.transform = Transform2D(Vector2(facing, 0.0), Vector2.DOWN, Vector2.ZERO)
		_facing_node.reset_physics_interpolation()
	position = CombatSpace.project(Vector2.ZERO, height)
	if clip != _clip or revision != _revision:
		var locomotion_blend := _clip in [&"idle", &"stride"] and clip in [&"idle", &"stride"]
		if locomotion_blend:
			_playback.travel(clip)
		else:
			_playback.start(clip, true)
		_clip = clip
		_revision = revision
	_mixer.advance(delta)
	if _bottle != null:
		var time := _playback.get_current_play_position()
		_bottle.visible = clip == &"flask" and time >= 4.0 * CombatSpace.STEP and time < 24.0 * CombatSpace.STEP


func weapon_tip() -> Vector2:
	return _tip.global_position if is_instance_valid(_tip) else global_position


func point_on_weapon(world_point: Vector2) -> Vector2:
	if not is_instance_valid(_tip):
		return world_point
	return Geometry2D.get_closest_point_to_segment(world_point, _socket.global_position, _tip.global_position)


func playback_position() -> float:
	return _playback.get_current_play_position()
