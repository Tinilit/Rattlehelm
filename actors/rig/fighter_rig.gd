class_name FighterRig
extends Node2D

const SOCKET_PATH := ^"Facing/Skeleton/Hip/Spine/Chest/NearShoulder/NearElbow/NearHand/WeaponSocket"

@export var painted_guard_weapon: PackedScene

@onready var _facing_node: Node2D = $Facing
@onready var _skeleton: Skeleton2D = $Facing/Skeleton
@onready var _hip: Bone2D = $Facing/Skeleton/Hip
@onready var _mixer: AnimationTree = $AnimationTree
@onready var _playback: AnimationNodeStateMachinePlayback = _mixer.get("parameters/playback")
@onready var _socket: Marker2D = get_node(SOCKET_PATH)
@onready var _waist_layer := get_node_or_null(^"%WaistLayer") as Node2D
@onready var _painted_guard := get_node_or_null(^"Facing/PaintedGuard") as Sprite2D
@onready var _gear_slots := _skeleton.find_children("*Gear", "Marker2D", true, true)

@onready var _bottle: Sprite2D = get_node_or_null(
	^"Facing/Skeleton/Hip/Spine/Chest/FarShoulder/FarElbow/FarHand/Bottle"
) as Sprite2D

var _held: Node2D
var _tip: Marker2D
var _blade_root: Marker2D
var _clip: StringName
var _revision := -1
var _facing := 1
var _guard_weapon_equipped := false


func equip(weapon: WeaponDef) -> void:
	if is_instance_valid(_held):
		_socket.remove_child(_held)
		_held.queue_free()
	_held = weapon.held_scene.instantiate() as Node2D
	_socket.add_child(_held)
	var grip: Marker2D = _held.get_node(^"Grip")
	_held.position = -grip.position
	_tip = _held.get_node(^"Tip")
	_blade_root = _held.get_node_or_null(^"BladeRoot") as Marker2D
	_guard_weapon_equipped = weapon.held_scene == painted_guard_weapon
	_show_painted_guard(false)


func equip_wearable(slot: StringName, wearable: PackedScene) -> bool:
	var mount := get_node_or_null(NodePath("%" + String(slot))) as Marker2D
	# Gear anchors reserve their child for a single visual item.
	if mount == null or mount == _socket:
		return false
	var item: Node2D
	if wearable != null:
		var node := wearable.instantiate()
		item = node as Node2D
		if item == null:
			node.free()
			return false
	for previous: Node in mount.get_children():
		mount.remove_child(previous)
		previous.queue_free()
	if item != null:
		mount.add_child(item)
	_show_painted_guard(false)
	return true


func weapon_edge() -> PackedVector2Array:
	if not is_instance_valid(_blade_root) or not is_instance_valid(_tip):
		return PackedVector2Array()
	return PackedVector2Array([_blade_root.global_position, _tip.global_position])


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
	var painted_idle := clip == &"idle" and _can_show_painted_guard()
	_mixer.advance(0.0 if painted_idle and _painted_guard.visible else delta)
	var show_guard := painted_idle and _playback.get_current_node() == &"idle"
	show_guard = show_guard and _playback.get_fading_from_node() == &""
	if show_guard and not _painted_guard.visible:
		# Begin at the reference key so the first step can blend from the painted pose.
		_playback.start(&"idle", true)
		_mixer.advance(0.0)
	_show_painted_guard(show_guard)
	if _waist_layer != null:
		# The waist shares the torso's pivot and keeps the hip orientation in its draw slot.
		_waist_layer.global_transform = _hip.global_transform
	if _bottle != null:
		var time := _playback.get_current_play_position()
		_bottle.visible = clip == &"flask" and time >= 4.0 * CombatSpace.STEP and time < 24.0 * CombatSpace.STEP


func _can_show_painted_guard() -> bool:
	if _painted_guard == null or not _guard_weapon_equipped:
		return false
	for slot: Node in _gear_slots:
		if slot.get_child_count() != 0:
			return false
	return true


func _show_painted_guard(show: bool) -> void:
	if _painted_guard != null:
		_painted_guard.visible = show
		_skeleton.visible = not show


func weapon_tip() -> Vector2:
	return _tip.global_position if is_instance_valid(_tip) else global_position


func point_on_weapon(world_point: Vector2) -> Vector2:
	if not is_instance_valid(_tip):
		return world_point
	return Geometry2D.get_closest_point_to_segment(world_point, _socket.global_position, _tip.global_position)


func playback_position() -> float:
	return _playback.get_current_play_position()
