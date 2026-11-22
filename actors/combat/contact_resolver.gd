class_name ContactResolver
extends RefCounted


static func gather(actors: Array[Combatant], space: PhysicsDirectSpaceState2D) -> Array[CombatContact]:
	var contacts: Array[CombatContact] = []
	for source: Combatant in actors:
		if not source.action.active():
			continue
		for target: Combatant in actors:
			var contact := _contact_for(source, target, space)
			if contact != null:
				source.action.struck[target.spawn_id] = true
				contacts.append(contact)
	return contacts


static func _contact_for(
	source: Combatant, target: Combatant, space: PhysicsDirectSpaceState2D
) -> CombatContact:
	var action := source.action
	var attack := action.attack
	if target.is_dead() or target.team == source.team or action.struck.has(target.spawn_id):
		return null
	if target.protected_from(attack):
		return null

	var start := source.previous_floor if attack.advance_speed != 0.0 else source.position
	var origin := closest_point_on_sweep(start, source.position, target.position)
	var point: Vector2
	if attack.uses_blade_span:
		var blade_point: Variant = _blade_contact(source, target, attack)
		if blade_point == null:
			return null
		point = blade_point
	else:
		if not overlaps(origin, source.height, source.facing, attack, target):
			return null
		var target_edge := target.position - Vector2(float(source.facing) * target.hurt_width, 0)
		var height_low := maxf(source.height + attack.height_band.x, target.height + target.hurt_floor)
		var height_high := minf(source.height + attack.height_band.y, target.height + target.hurt_ceiling)
		point = CombatSpace.project(target_edge, lerpf(height_low, height_high, 0.77))

	if not clear_line(space, origin, target.position):
		return null
	var contact := CombatContact.new()
	contact.source = source
	contact.target = target
	contact.attack = attack
	contact.push = Vector2(float(source.facing), 0.0) * attack.knockback
	contact.floor_point = target.position
	contact.point = point
	return contact


static func _blade_contact(source: Combatant, target: Combatant, attack: AttackDef) -> Variant:
	var offset := target.position - source.position
	if absf(offset.y) > attack.half_depth + target.hurt_depth:
		return null
	if offset.x * source.facing + target.hurt_width < attack.front_start or source.rig == null:
		return null

	var edge := source.rig.weapon_edge()
	if edge.size() != 2:
		return null
	var floor_layer := source.get_parent() as Node2D
	var blade_root := floor_layer.to_local(edge[0])
	var blade_tip := floor_layer.to_local(edge[1])
	# Depth is checked separately. Compare blade height against the target on the same floor line.
	var top_left := Vector2(target.position.x - target.hurt_width,
		source.position.y - target.height - target.hurt_ceiling)
	var body_size := Vector2(target.hurt_width * 2.0, target.hurt_ceiling - target.hurt_floor)
	return _segment_contact(blade_root, blade_tip, Rect2(top_left, body_size).grow(2.0))


static func _segment_contact(start: Vector2, finish: Vector2, bounds: Rect2) -> Variant:
	if bounds.has_point(finish):
		return finish
	var corners: Array[Vector2] = [
		bounds.position, Vector2(bounds.end.x, bounds.position.y),
		bounds.end, Vector2(bounds.position.x, bounds.end.y),
	]
	var closest: Variant = start if bounds.has_point(start) else null
	for side: int in corners.size():
		var point: Variant = Geometry2D.segment_intersects_segment(
			start, finish, corners[side], corners[(side + 1) % corners.size()]
		)
		if point != null and (closest == null or finish.distance_squared_to(point) < finish.distance_squared_to(closest)):
			closest = point
	return closest


static func closest_point_on_sweep(start: Vector2, finish: Vector2, point: Vector2) -> Vector2:
	if start.is_equal_approx(finish):
		return finish
	return Geometry2D.get_closest_point_to_segment(point, start, finish)


static func overlaps(
	origin: Vector2, height: float, facing: int, attack: AttackDef, target: Combatant
) -> bool:
	var diff := target.position - origin
	var forward := diff.x * facing
	return (
		forward >= attack.front_start - target.hurt_width
		and forward <= attack.reach + target.hurt_width
		and absf(diff.y) <= attack.half_depth + target.hurt_depth
		and height + attack.height_band.y > target.height + target.hurt_floor
		and height + attack.height_band.x < target.height + target.hurt_ceiling
	)


static func clear_line(space: PhysicsDirectSpaceState2D, from: Vector2, to: Vector2) -> bool:
	if from.is_equal_approx(to):
		return true
	var ray := PhysicsRayQueryParameters2D.create(from, to, CombatSpace.WALL_LAYER)
	ray.hit_from_inside = true
	return space.intersect_ray(ray).is_empty()
