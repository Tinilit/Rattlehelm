class_name ActionState
extends RefCounted
## Runtime state of a single fighter. Definitions remain shared and read-only.

enum Kind { FREE, ATTACK, TAKEOFF, LAND, ROLL, STAGGER, FLASK, DEAD }

var kind := Kind.FREE
var tick := 0
var attack: AttackDef
var revision := 0
var sequence := 0
var impact_index := 0
var struck: Dictionary[int, bool] = {}


func start(next: Kind, definition: AttackDef = null, index: int = 0) -> void:
	revision += 1
	kind = next
	tick = 0
	attack = definition
	impact_index = index
	if next == Kind.ATTACK:
		sequence += 1
	struck.clear()


func active() -> bool:
	return kind == Kind.ATTACK and attack.is_active(tick)
