class_name WebPlaytestProbe
extends RefCounted
## Opt-in read-only surface for browser smoke tests. It exposes no controls or player data.

var _document_root: JavaScriptObject


func _init() -> void:
	if not OS.has_feature("web"):
		return
	var browser := JavaScriptBridge.get_interface("window")
	if "smoke=1" in String(browser.location.search).trim_prefix("?").split("&"):
		_document_root = JavaScriptBridge.get_interface("document").documentElement


func publish(
	screen: StringName, run: RunDirector, paused: bool, won: bool
) -> void:
	if _document_root == null:
		return
	var snapshot := {
		"screen": screen, "build": BuildVersion.SHA, "paused": paused, "won": won,
	}
	if run.room != null and run.state != null:
		var room := run.room
		var hero := room.hero
		snapshot.merge({
			"room": run.state.route[run.state.route_index],
			"tick": room.clock,
			"heroX": hero.position.x, "heroY": hero.position.y, "heroFacing": hero.facing,
			"heroHp": hero.health, "height": hero.height,
			"action": hero.last_action, "phase": hero.action.kind, "actionTick": hero.action.tick,
			"hits": room.players_hits, "enemyHits": room.enemy_hits, "enemyMisses": room.enemy_misses,
			"missDepth": room.last_enemy_miss_depth, "missFacing": room.last_enemy_miss_facing,
			"impactMaterial": room.last_material, "impactTick": room.last_impact_tick,
			"attackTick": room.last_attack_start_tick, "attackFacing": room.last_attack_facing,
			"missTick": room.last_enemy_miss_tick, "sfx": room.sound.cue_count,
			"cleared": room.cleared, "exitReady": room.can_exit(), "hitstop": room.hitstop,
			"healthNumbers": run.preferences.health_numbers, "shake": room.fx.shake_enabled,
			"particles": room.fx.particles_enabled,
		})
		var enemy := room.living_enemy()
		if enemy != null:
			snapshot.merge({
				"enemyX": enemy.position.x, "enemyY": enemy.position.y,
				"enemyHp": enemy.health, "enemyFacing": enemy.facing,
				"enemyAction": enemy.last_action, "enemyPhase": enemy.action.kind,
				"enemyActionTick": enemy.action.tick,
			})
	_document_root.setAttribute("data-rattlehelm", JSON.stringify(snapshot))
