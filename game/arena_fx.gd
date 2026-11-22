class_name ArenaFX
extends Node2D

class Impact:
	var location: Vector2
	var tint: Color
	var heavy: bool
	var age := 0
	var spokes: PackedVector2Array

class Trail:
	var sequence: int
	var points: Array[Vector2] = []
	var age := 0
	var tint: Color

var camera: Camera2D
var shake_enabled := true
var particles_enabled := true
var _intensity := 0.0
var _impacts: Array[Impact] = []
var _trails: Dictionary[int, Trail] = {}
var _rng := RandomNumberGenerator.new()


func strike(contact: CombatContact, accent: bool) -> void:
	var impact := Impact.new()
	impact.location = contact.point
	impact.heavy = contact.attack.hitstop >= 4
	match contact.target.contact_material():
		AttackDef.ContactMaterial.IRON:
			impact.tint = Color("#fff1bc")
		AttackDef.ContactMaterial.STRAW:
			impact.tint = Color("#f4b966")
		_:
			impact.tint = Color("#ffc982")
	var spokes := PackedVector2Array()
	for index: int in 10:
		var direction := Vector2.from_angle(_rng.randf_range(0.0, TAU))
		spokes.append(direction * _rng.randf_range(10.0, 31.0))
	impact.spokes = spokes
	_impacts.append(impact)
	if accent and shake_enabled:
		_intensity = maxf(_intensity, 3.3 if impact.heavy else 1.9)


func dust(floor_point: Vector2) -> void:
	var impact := Impact.new()
	impact.location = floor_point
	impact.tint = Color("#c99c88")
	impact.spokes = PackedVector2Array([Vector2.LEFT * 24.0, Vector2.RIGHT * 24.0])
	_impacts.append(impact)


func observe_weapon(actor: Combatant) -> void:
	if actor.rig == null or actor.action.kind != ActionState.Kind.ATTACK:
		return
	var action := actor.action
	if not action.attack.contact_on_weapon:
		return
	if action.tick < action.attack.swing_tick or action.tick >= action.attack.startup + action.attack.active:
		return
	var trail: Trail = _trails.get(actor.spawn_id)
	if trail == null or trail.sequence != action.sequence:
		trail = Trail.new()
		trail.sequence = action.sequence
		trail.tint = Color("#ffc486") if actor.team != 0 else Color("#d3ede6")
		_trails[actor.spawn_id] = trail
	trail.points.append(actor.rig.weapon_tip())
	trail.age = 0
	if trail.points.size() > 9:
		trail.points.pop_front()


func _physics_process(_delta: float) -> void:
	for impact: Impact in _impacts:
		impact.age += 1
	_impacts = _impacts.filter(func(impact: Impact) -> bool: return impact.age < 20)
	for id: int in _trails.keys():
		_trails[id].age += 1
		if _trails[id].age > 10:
			_trails.erase(id)
	if camera != null:
		camera.offset = Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-0.65, 0.65)) * _intensity
		_intensity = move_toward(_intensity, 0.0, 0.36)
	queue_redraw()


func _draw() -> void:
	for trail: Trail in _trails.values():
		var opacity := (1.0 - float(trail.age) / 11.0)
		for index: int in range(1, trail.points.size()):
			var weight := float(index) / trail.points.size()
			var tint := Color(trail.tint, opacity * weight * 0.66)
			draw_line(trail.points[index - 1], trail.points[index], tint, 2.0 + 5.0 * weight, true)
			draw_line(trail.points[index - 1], trail.points[index], Color(tint, tint.a * 0.25), 13.0, true)
	for impact: Impact in _impacts:
		var life := float(impact.age) / 20.0
		if impact.spokes.size() == 2:
			if particles_enabled:
				for vector: Vector2 in impact.spokes:
					draw_circle(impact.location + vector * life + Vector2.UP * life * 6.0,
						2.0 + life * 7.0, Color(impact.tint, (1.0-life) * 0.50), true)
			continue
		var radius := (11.0 if impact.heavy else 7.0) + life * 27.0
		draw_arc(impact.location, radius, 0.0, TAU, 22, Color(impact.tint, (1.0-life) * 0.69), 1.65, true)
		draw_circle(impact.location, 5.0 * maxf(0.0, 1.0 - life * 4.0), Color("#fff3da"), true)
		if particles_enabled:
			for vector: Vector2 in impact.spokes:
				var point := impact.location + vector * life * 1.85 + Vector2.DOWN * life * life * 11.0
				draw_line(point, point + vector.normalized() * (5.5-life*4.0),
					Color(impact.tint, (1.0-life) * 0.90), 2.1, true)
