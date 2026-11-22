class_name Portcullis
extends Node2D

const LIFT_TICKS := 35

var _raised_ticks := 0
var _lifting := false


func open_immediately() -> void:
	_raised_ticks = LIFT_TICKS
	queue_redraw()


func lift() -> void:
	_lifting = true


func is_open() -> bool:
	return _raised_ticks == LIFT_TICKS


func _physics_process(_delta: float) -> void:
	if _lifting and not is_open():
		_raised_ticks += 1
		queue_redraw()


func _draw() -> void:
	var travel := 236.0 * smoothstep(0.0, 1.0, float(_raised_ticks) / LIFT_TICKS)
	for x: float in [-90.0, -70.0, -50.0, -30.0, -10.0, 10.0, 30.0, 50.0, 70.0, 90.0]:
		var arch := -246.0 + absf(x) * 1.04
		var point := -21.0 - travel
		if point < arch:
			continue
		draw_line(Vector2(x, arch), Vector2(x, point - 10.0), Color("#141a26"), 10.0)
		draw_line(Vector2(x + 1.0, arch), Vector2(x + 1.0, point - 10.0), Color("#5a4b4c"), 5.0)
		draw_line(Vector2(x - 0.5, arch), Vector2(x - 0.5, point - 10.0), Color("#8a6959"), 1.0)
		draw_colored_polygon(PackedVector2Array([
			Vector2(x - 3.0, point - 10.0), Vector2(x + 5.0, point - 10.0), Vector2(x, point)
		]), Color("#4a3f46"))
	for bar: float in [-118.0, -68.0]:
		var y := bar - travel
		var span := minf(104.0, (y + 246.0) / 1.04)
		if span > 0.0:
			draw_line(Vector2(-span, y), Vector2(span, y), Color("#221e28"), 11.0)
			draw_line(Vector2(-span, y - 1.0), Vector2(span, y - 1.0), Color("#806256"), 6.0)
