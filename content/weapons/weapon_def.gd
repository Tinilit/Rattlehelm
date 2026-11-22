class_name WeaponDef
extends Resource

@export var id: StringName
@export var label_key: StringName
@export var player_equippable := true
@export var icon: Texture2D
@export var held_scene: PackedScene
@export var opener: AttackDef
@export var kick: AttackDef
@export var aerial: AttackDef
