class_name ContentCatalog
extends RefCounted

const FORTRESS := preload("res://content/packs/fortress.tres")
const WARDEN := preload("res://actors/hero/Warden.tscn")

var weapons: Dictionary[StringName, WeaponDef] = {}
var enemies: Dictionary[StringName, EnemyDef] = {}
var rooms: Dictionary[StringName, RoomDef] = {}
var errors := PackedStringArray()


func build(packs: Array[ContentPackDef]) -> bool:
	weapons.clear()
	enemies.clear()
	rooms.clear()
	errors.clear()

	var pack_ids: Dictionary[StringName, bool] = {}
	for pack: ContentPackDef in packs:
		if pack == null:
			errors.append("Enabled packs: empty pack reference")
			continue
		if _check_id(pack, pack.id, pack_ids):
			pack_ids[pack.id] = true
		for weapon: WeaponDef in pack.weapons:
			if weapon == null:
				_error(pack, "weapons", "empty reference")
			elif _check_id(weapon, weapon.id, weapons):
				weapons[weapon.id] = weapon
		for enemy: EnemyDef in pack.enemies:
			if enemy == null:
				_error(pack, "enemies", "empty reference")
			elif _check_id(enemy, enemy.id, enemies):
				enemies[enemy.id] = enemy
		for room: RoomDef in pack.rooms:
			if room == null:
				_error(pack, "rooms", "empty reference")
			elif _check_id(room, room.id, rooms):
				rooms[room.id] = room

	var attack_ids: Dictionary[StringName, AttackDef] = {}
	var warden_rig := WARDEN.instantiate()
	for weapon: WeaponDef in weapons.values():
		if _validate_weapon(weapon) and weapon.player_equippable:
			_validate_weapon_rig(weapon, warden_rig, attack_ids)
	warden_rig.free()

	for enemy: EnemyDef in enemies.values():
		if enemy.weapon == null or weapons.get(enemy.weapon.id) != enemy.weapon:
			_error(enemy, "weapon", "reference is outside the enabled packs")
		if enemy.actor_scene == null or enemy.health <= 0 or enemy.move_speed <= 0.0:
			_error(enemy, "actor_scene / health / move_speed", "valid actor scene and positive stats required")
			continue
		var actor := enemy.actor_scene.instantiate()
		if not actor is Combatant:
			_error(enemy, "actor_scene", "root must extend Combatant")
		elif enemy.weapon != null and enemy.weapon.opener != null:
			_validate_weapon_rig(enemy.weapon, actor, attack_ids)
		actor.free()
	for room: RoomDef in rooms.values():
		_validate_room(room)
	return errors.is_empty()


func _check_id(resource: Resource, id: StringName, index: Dictionary) -> bool:
	if id.is_empty():
		_error(resource, "id", "missing ID")
		return false
	if index.has(id):
		_error(resource, "id", "duplicate ID '%s'" % id)
		return false
	return true


func _validate_weapon(weapon: WeaponDef) -> bool:
	if weapon.label_key.is_empty() or weapon.icon == null or weapon.held_scene == null or weapon.opener == null:
		_error(weapon, "label_key / icon / held_scene / opener", "missing definition")
		return false
	var held := weapon.held_scene.instantiate()
	for marker: String in ["Grip", "Tip"]:
		if not held.get_node_or_null(NodePath(marker)) is Marker2D:
			_error(weapon, "held_scene", "missing Marker2D '%s'" % marker)
	held.free()
	return true


func _validate_weapon_rig(
	weapon: WeaponDef, actor: Node, attack_ids: Dictionary[StringName, AttackDef]
) -> void:
	var rig := actor.get_node_or_null(^"Rig")
	if rig == null:
		_error(weapon, "held_scene", "actor has no rig")
		return
	if not rig.get_node_or_null(FighterRig.SOCKET_PATH) is Marker2D:
		_error(weapon, "held_scene", "actor has no weapon socket")
	var player := rig.get_node_or_null(^"AnimationPlayer") as AnimationPlayer
	var tree := rig.get_node_or_null(^"AnimationTree") as AnimationTree
	if player == null or tree == null:
		_error(weapon, "opener.clip", "actor has no animation player or tree")
		return

	for first: AttackDef in [weapon.opener, weapon.kick, weapon.aerial]:
		var attack := first
		var chain: Array[AttackDef] = []
		while attack != null:
			if chain.has(attack):
				_error(attack, "follow_up", "combo loops back to itself")
				break
			chain.append(attack)
			if not attack_ids.has(attack.id) or attack_ids[attack.id] != attack:
				if _check_id(attack, attack.id, attack_ids):
					attack_ids[attack.id] = attack
			_validate_attack(attack, player, tree)
			attack = attack.follow_up


func _validate_attack(attack: AttackDef, player: AnimationPlayer, tree: AnimationTree) -> void:
	if (
		attack.startup < 1 or attack.active < 1 or attack.recovery < 1
		or attack.swing_tick < 0 or attack.swing_tick >= attack.startup + attack.active
		or attack.swing_audio == null
	):
		_error(attack, "startup / active / recovery / swing_tick / swing_audio", "invalid attack timing or cue")
	if attack.damage <= 0 or attack.reach < attack.front_start or attack.half_depth <= 0 or (
		attack.height_band.y <= attack.height_band.x
	):
		_error(attack, "damage / reach / half_depth / height_band", "invalid contact volume")
	if attack.follow_up != null and (
		attack.combo_input_tick < 0 or attack.chain_tick < attack.combo_input_tick
		or attack.chain_tick >= attack.duration()
	):
		_error(attack, "chain_tick", "combo transition is outside its action")
	var states := tree.tree_root as AnimationNodeStateMachine
	if states == null or not states.has_node(attack.clip) or not player.has_animation(attack.clip):
		_error(attack, "clip", "unknown animation '%s'" % attack.clip)
	elif absf(player.get_animation(attack.clip).length - attack.duration() * CombatSpace.STEP) > 0.001:
		_error(attack, "clip", "length must match the fixed-tick attack duration")


func _validate_room(room: RoomDef) -> void:
	if room.room_scene == null:
		_error(room, "room_scene", "missing room scene")
		return
	var node := room.room_scene.instantiate()
	if not node is RoomController:
		_error(room, "room_scene", "root must extend RoomController")
	elif (node as RoomController).player_scene == null:
		_error(room, "room_scene.player_scene", "missing player scene")
	elif node.get_node_or_null(^"Anchors/Entry") == null or node.get_node_or_null(^"Anchors/Exit") == null:
		_error(room, "room_scene", "entry and exit anchors are required")
	elif room.encounter != null:
		var spawns := node.get_node_or_null(^"Anchors/EnemySpawns")
		if room.encounter.id.is_empty() or room.encounter.roster.is_empty():
			_error(room.encounter, "id / roster", "an encounter needs an ID and at least one enemy")
		if spawns == null or spawns.get_child_count() < room.encounter.roster.size():
			_error(room, "encounter", "not enough enemy spawn markers")
		for enemy: EnemyDef in room.encounter.roster:
			if enemy == null or enemies.get(enemy.id) != enemy:
				_error(room.encounter, "roster", "enemy reference is outside the enabled packs")
	elif not (node as RoomController).training_yard:
		_error(room, "encounter", "an encounter is required outside the training yard")
	node.free()


func _error(resource: Resource, field: String, problem: String) -> void:
	var source := resource.resource_path
	if source.is_empty():
		source = resource.resource_name
	if source.is_empty():
		source = "<unsaved resource>"
	errors.append("%s.%s: %s" % [source, field, problem])
