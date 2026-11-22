class_name AttackDef
extends Resource

enum ContactMaterial { FLESH, STRAW, IRON }
enum ReachHeight { BODY, LOW, AIR }

@export var id: StringName
@export_category("Fixed ticks")
@export_range(1, 120) var startup := 5
@export_range(1, 120) var active := 4
@export_range(1, 120) var recovery := 11
@export_range(0, 10) var hitstop := 3
@export var follow_up: AttackDef
@export var combo_input_tick := 0
@export var chain_tick := 0
@export_category("Contact")
@export var damage := 12
@export var front_start := 4.0
@export var reach := 62.0
@export var half_depth := 17.0
@export var height_band := Vector2(22.0, 104.0)
@export var reach_height: ReachHeight = ReachHeight.BODY
@export var knockback := 135.0
@export var stun_ticks := 14
@export var advance_speed := 0.0
@export_range(0, 120) var advance_tick := 0
@export_category("Presentation")
@export var clip: StringName
@export var contact_on_weapon := true
@export var swing_audio: AudioStream
@export var swing_tick := 2


func duration() -> int:
	return startup + active + recovery


func is_active(tick: int) -> bool:
	return tick >= startup and tick < startup + active
