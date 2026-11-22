class_name ActionCommand
extends RefCounted

enum Kind { ROLL, JUMP, ATTACK, INTERACT, FLASK }

var kind: Kind
var direction: Vector2


func _init(action: Kind, aim: Vector2 = Vector2.ZERO) -> void:
	kind = action
	direction = aim
