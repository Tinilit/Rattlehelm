class_name FloorMarks
extends Node2D

var fighters: Array[Combatant]
var exit_point := Vector2.ZERO
var gate_open := false
var diagnostics := false
var _time := 0.0


func _physics_process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var tint := Color("#e4b17c") if gate_open else Color("#985c51")
	var rad := 1.0 + sin(_time * 3.5) * 0.08
	var p := exit_point
	draw_polyline(PackedVector2Array([
		p+Vector2(-33,0)*rad, p+Vector2(0,-13)*rad, p+Vector2(33,0)*rad,
		p+Vector2(0,13)*rad, p+Vector2(-33,0)*rad,
	]), Color(tint, 0.64), 1.5, true)
	if gate_open:
		draw_colored_polygon(PackedVector2Array([
			p+Vector2(-9,1), p+Vector2(0,-5), p+Vector2(9,1),
			p+Vector2(9,5), p+Vector2(0,0), p+Vector2(-9,5),
		]), Color(tint, 0.92))
	for actor: Combatant in fighters:
		if actor.team != 0 and actor.action.kind == ActionState.Kind.ATTACK:
			var definition := actor.action.attack
			var tick := maxi(0, actor.action.tick - 1)
			if tick < definition.startup + definition.active:
				_draw_threat(actor, definition, tick)
		if diagnostics:
			draw_line(actor.position + Vector2.LEFT * 6.0, actor.position + Vector2.RIGHT * 6.0, Color.AQUAMARINE, 1.0)
			draw_line(actor.position + Vector2.UP * 6.0, actor.position + Vector2.DOWN * 6.0, Color.AQUAMARINE, 1.0)
			if actor.action.kind == ActionState.Kind.ATTACK and actor.action.attack.is_active(maxi(0, actor.action.tick - 1)):
				if actor.rig != null and actor.action.attack.uses_blade_span:
					var blade := actor.rig.weapon_edge()
					if blade.size() == 2:
						draw_line(to_local(blade[0]), to_local(blade[1]), Color.AQUAMARINE, 2.0, true)
				else:
					draw_rect(_zone(actor, actor.action.attack), Color.AQUAMARINE, false, 1.5)


func _draw_threat(actor: Combatant, definition: AttackDef, tick: int) -> void:
	var zone := _zone(actor, definition)
	var hot := definition.is_active(tick)
	var progress := clampf(float(tick) / definition.startup, 0.0, 1.0)
	var tint := Color("#ffe0a4") if hot else Color("#e78a62")
	draw_rect(zone, Color(tint, 0.10 + 0.24 * progress))
	draw_rect(zone, Color(tint, 0.70), false, 1.3)
	var origin := actor.position + Vector2(actor.facing * (definition.reach - 8.0), 0.0)
	for rung: float in [0.0, 9.0, 18.0]:
		var ear := origin - Vector2(actor.facing * rung, 0.0)
		draw_polyline(PackedVector2Array([
			ear + Vector2(-actor.facing * 6.0, -5.0), ear, ear + Vector2(-actor.facing * 6.0, 5.0)
		]), Color(tint, 0.82), 1.25, true)


func _zone(actor: Combatant, definition: AttackDef) -> Rect2:
	var a := actor.position.x + actor.facing * definition.front_start
	var b := actor.position.x + actor.facing * definition.reach
	return Rect2(minf(a, b), actor.position.y - definition.half_depth, absf(a-b), definition.half_depth * 2.0)
