class_name CombatSpace
extends RefCounted
## Floor coordinates are screen pixels before applying height. Feet and shadows share the floor.

const TICK_RATE := 60
const STEP := 1.0 / float(TICK_RATE)
const WALL_LAYER := 1
const BODY_LAYER := 2
const SPEED := Vector2(270.0, 155.0)
const GRAVITY := 1540.0


static func project(floor_point: Vector2, height: float) -> Vector2:
	return floor_point - Vector2(0.0, height)


static func velocity_for(direction: Vector2, speed: float) -> Vector2:
	return direction.limit_length() * SPEED * speed / SPEED.x
