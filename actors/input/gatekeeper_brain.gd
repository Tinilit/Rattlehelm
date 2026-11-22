class_name GatekeeperBrain
extends RefCounted
## Reads positions, height, and visible actor state. It never sees player commands.

var definition: EnemyDef
var ready_at: int


func _init(enemy: EnemyDef, clock: int) -> void:
	definition = enemy
	ready_at = clock + enemy.engagement_delay


func decide(actor: Combatant, player: Combatant, clock: int) -> CombatIntent:
	var intent := CombatIntent.new()
	if actor.action.kind != ActionState.Kind.FREE or player.is_dead():
		return intent
	var separation := player.position - actor.position
	var aim := Vector2(1.0 if separation.x >= 0.0 else -1.0, 0.0)
	if absf(separation.x) <= definition.preferred_reach and absf(separation.y) <= 11.0:
		if clock >= ready_at:
			intent.commands.append(ActionCommand.new(ActionCommand.Kind.ATTACK, aim))
			ready_at = clock + definition.weapon.opener.duration() + definition.engagement_delay
		return intent
	var horizontal := separation.x
	if absf(separation.y) > 12.0 and absf(separation.x) < 45.0:
		horizontal = 0.0
	intent.move = Vector2(horizontal * 0.68, separation.y * 1.5).limit_length(1.0)
	return intent
