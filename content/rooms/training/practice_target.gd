class_name PracticeTarget
extends Combatant

@export var surface_material: AttackDef.ContactMaterial = AttackDef.ContactMaterial.STRAW

@onready var _art: Sprite2D = $Artwork

var hits := 0
var _bend := 0.0
var _bend_tick := 0


func is_practice_target() -> bool:
	return true


func contact_material() -> AttackDef.ContactMaterial:
	return surface_material


func tick(_intent: CombatIntent, _room: RoomController, _clock: int) -> void:
	previous_floor = position


func take_contact(contact: CombatContact) -> void:
	hits += 1
	_bend = signf(contact.push.x) * (0.19 if surface_material == AttackDef.ContactMaterial.STRAW else 0.08)
	_bend_tick = 0


func present(_delta: float) -> void:
	if _bend_tick < 30:
		_bend_tick += 1
		_art.rotation = _bend * sin(_bend_tick * 0.47) * exp(-_bend_tick * 0.10)
	else:
		_art.rotation = 0.0
