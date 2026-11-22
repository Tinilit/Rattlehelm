extends SceneTree

const WATCH_GATE := preload("res://content/rooms/watch_gate/WatchGate.tscn")
const GATE_ROSTER := preload("res://content/rooms/watch_gate/gate_watch.tres")
const YARD := preload("res://content/rooms/training/TrainingYard.tscn")
const GUARD := preload("res://content/enemies/gatekeeper/Gatekeeper.tscn")
const SWORD := preload("res://content/weapons/sword/sword.tres")
const CLUB := preload("res://content/enemies/gatekeeper/club.tres")
const HELMET := preload("res://content/enemies/gatekeeper/SentryHelmet.tscn")

var _room: RoomController
var _input_source: PlayerCommandSource
var _failures := 0
var _checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	Input.use_accumulated_input = false
	_input_source = PlayerCommandSource.new()
	root.add_child(_input_source)
	_input_source.enabled = true
	_catalog_and_rigs()
	_painted_guard_pose()
	_far_arm_layers_and_pose()
	await _idle_and_tap()
	await _targets_and_combo()
	await _blade_reach(1)
	await _blade_reach(-1)
	await _kick()
	await _wall_and_roll()
	await _jump_and_action_priority()
	await _same_tick_trade()
	await _depth_dodge_counter(1)
	await _depth_dodge_counter(-1)
	await _pause_and_heal()
	_drop_room()
	_input_source.queue_free()
	print("Rattlehelm: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _catalog_and_rigs() -> void:
	var catalog := ContentCatalog.new()
	_check(catalog.build([ContentCatalog.FORTRESS]), "Base catalog", [], catalog.errors)
	_check(catalog.weapons.has(&"sword") and catalog.rooms.has(&"watch_gate"),
		"Catalog path", "sword and watch_gate", catalog.rooms.keys())
	var pack := ContentCatalog.FORTRESS.duplicate() as ContentPackDef
	pack.weapons.append(SWORD)
	var accepted := catalog.build([pack])
	_check(not accepted and "duplicate ID 'sword'" in " ".join(catalog.errors),
		"Duplicate weapon fixture", "reported sword.id", catalog.errors)
	for scene: PackedScene in [ContentCatalog.WARDEN, GUARD]:
		var actor := scene.instantiate() as Combatant
		var rig := actor.get_node(^"Rig") as FighterRig
		var animation_player := rig.get_node(^"AnimationPlayer") as AnimationPlayer
		var skeleton := rig.get_node(^"Facing/Skeleton") as Skeleton2D
		var bones := skeleton.find_children("*", "Bone2D", true, true)
		_check(bones.size() == 18, "%s cutout bones" % actor.name, 18, bones.size())
		_check(rig.has_node(FighterRig.SOCKET_PATH), "%s hand socket" % actor.name, true, rig.has_node(FighterRig.SOCKET_PATH))
		var broken_paths := PackedStringArray()
		for clip_id: StringName in animation_player.get_animation_list():
			var clip := animation_player.get_animation(clip_id)
			for track: int in clip.get_track_count():
				var node_path := NodePath(clip.track_get_path(track).get_concatenated_names())
				if not rig.has_node(node_path):
					broken_paths.append("%s:%s" % [clip_id, node_path])
		_check(broken_paths.is_empty(), "%s animation track targets" % actor.name, [], broken_paths)
		var slot := rig.get_node(^"%HeadGear") as Marker2D
		var initial_items := 0 if scene == ContentCatalog.WARDEN else 1
		_check(slot.get_child_count() == initial_items, "%s headgear at spawn" % actor.name,
			initial_items, slot.get_child_count())
		var outfit_ok := rig.equip_wearable(&"HeadGear", HELMET) and slot.get_child_count() == 1
		_check(outfit_ok and rig.equip_wearable(&"HeadGear", null) and slot.get_child_count() == 0,
			"%s removable helmet follows the head" % actor.name, true, outfit_ok)
		actor.free()


func _painted_guard_pose() -> void:
	var hero := ContentCatalog.WARDEN.instantiate() as Combatant
	hero.weapon = SWORD
	root.add_child(hero)
	var rig := hero.rig
	var art := rig.get_node(^"Facing/PaintedGuard") as Sprite2D
	var skeleton := rig.get_node(^"Facing/Skeleton") as Skeleton2D
	var starting_tip := rig.weapon_tip()
	for tick in 55:
		rig.sample(&"idle", 0, 1, 0.0, CombatSpace.STEP)
	var painted := art.visible and not skeleton.visible
	var tip_held := rig.weapon_tip().is_equal_approx(starting_tip)
	_check(painted and tip_held, "Default guard holds the fitted illustration and sword pose",
		[true, true], [painted, tip_held])

	rig.sample(&"idle", 0, -1, 0.0, CombatSpace.STEP)
	_check(art.visible and art.global_transform.determinant() < 0.0,
		"Painted guard mirrors with the fighter", true, art.global_transform.determinant())
	rig.sample(&"stride", 1, -1, 0.0, CombatSpace.STEP)
	var stride_visible := skeleton.visible and not art.visible
	for tick in 10:
		rig.sample(&"idle", 2, -1, 0.0, CombatSpace.STEP)
	var settled := art.visible and not skeleton.visible
	rig.sample(&"slash_1", 3, -1, 0.0, CombatSpace.STEP)
	var slash_visible := skeleton.visible and not art.visible
	_check(stride_visible and settled and slash_visible, "Guard and cutout switch across locomotion and attacks",
		[true, true, true], [stride_visible, settled, slash_visible])

	rig.sample(&"idle", 4, -1, 0.0, CombatSpace.STEP)
	rig.equip_wearable(&"HeadGear", HELMET)
	rig.sample(&"idle", 4, -1, 0.0, CombatSpace.STEP)
	var helmet_visible := skeleton.visible and not art.visible
	rig.equip_wearable(&"HeadGear", null)
	rig.equip(CLUB)
	rig.sample(&"idle", 4, -1, 0.0, CombatSpace.STEP)
	var club_visible := skeleton.visible and not art.visible
	rig.equip(SWORD)
	rig.sample(&"idle", 4, -1, 0.0, CombatSpace.STEP)
	_check(helmet_visible and club_visible and art.visible, "Painted guard follows the default outfit",
		[true, true, true], [helmet_visible, club_visible, art.visible])
	hero.free()


func _far_arm_layers_and_pose() -> void:
	for scene: PackedScene in [ContentCatalog.WARDEN, GUARD]:
		var actor := scene.instantiate() as Combatant
		root.add_child(actor)
		var rig := actor.rig
		if scene == ContentCatalog.WARDEN:
			rig.equip(SWORD)
			_watchman_leg_layers(rig)
			_watchman_grip(rig)
		var offhand := rig.get_node(^"%OffHandGear") as Marker2D
		var wrist := offhand.get_parent() as Bone2D
		var elbow := wrist.get_parent() as Bone2D
		var shoulder := elbow.get_parent() as Bone2D
		var chest := shoulder.get_parent() as Bone2D
		var chest_center := rig.get_node(^"%TorsoGear") as Marker2D
		var near := chest.get_node(^"NearShoulder")
		var torso := chest.get_node(^"Art")
		var layers_ok := shoulder.show_behind_parent and shoulder.get_index() < torso.get_index()
		layers_ok = layers_ok and torso.get_index() < near.get_index()
		var joints_ok := is_equal_approx(shoulder.length, elbow.position.length())
		joints_ok = joints_ok and is_equal_approx(elbow.length, wrist.position.length())
		_check(layers_ok and joints_ok, "%s offhand hierarchy and layer order" % actor.name,
			[true, true], [layers_ok, joints_ok])
		if scene == ContentCatalog.WARDEN:
			var palm_art := wrist.get_node(^"Art") as Sprite2D
			var cuff := elbow.get_node(^"Art") as Sprite2D
			var palm_in_front := not wrist.show_behind_parent and cuff.get_index() < wrist.get_index()
			var joined := palm_in_front and _painted_joint_overlaps(wrist.global_position, palm_art, cuff)
			_check(joined, "Watchman palm overlaps the front of the wrist wrap", true, joined)
			var waist := rig.get_node(^"%WaistLayer") as Node2D
			var waist_art := waist.get_node(^"Art") as Sprite2D
			var hip := rig.get_node(^"Facing/Skeleton/Hip") as Bone2D
			var behind_torso := waist.get_index() + 1 == torso.get_index()
			var waist_fitted := _painted_joint_overlaps(hip.global_position, waist_art, torso as Sprite2D)
			_check(behind_torso and waist_fitted,
				"Watchman waist meets the torso one layer below it", [true, true], [behind_torso, waist_fitted])
			var foreground := torso.get_index() < near.get_index() and chest.get_node(^"Neck").get_index() < near.get_index()
			_check(foreground, "Watchman near arm is in front of the torso and head", true, foreground)
		for facing: int in [1, -1]:
			rig.sample(&"idle", 1, facing, 0.0, 0.0)
			for tick: int in 5:
				rig.sample(&"idle", 1, facing, 0.0, CombatSpace.STEP)
			var offset := wrist.global_position - chest_center.global_position
			_check(offset.x * facing > 28.0 and offset.y > 18.0 and offset.y < 39.0,
				"%s far fist rests outside the lower chest facing %d" % [actor.name, facing],
				"forward x > 28, vertical offset between 18 and 39", offset)
			var edge := rig.weapon_edge()
			if edge.size() == 2:
				var palm := offhand.global_position
				var closest := Geometry2D.get_closest_point_to_segment(palm, edge[0], edge[1])
				var clearance := palm.y - closest.y
				_check(clearance > 4.0, "Watchman free hand clears the blade facing %d" % facing,
					"more than 4 px below the blade", clearance)
			var lowest := 0.0
			rig.sample(&"stride", 2, facing, 0.0, 0.0)
			for tick: int in 32:
				rig.sample(&"stride", 2, facing, 0.0, CombatSpace.STEP)
				lowest = maxf(lowest, wrist.global_position.y - chest_center.global_position.y)
			_check(lowest < 39.0, "%s far arm stays clear of the hip through the stride facing %d" % [actor.name, facing],
				"maximum wrist drop < 39", lowest)
		if scene == ContentCatalog.WARDEN:
			_watchman_pelvis_pivot(rig, chest)
		actor.free()


func _watchman_pelvis_pivot(rig: FighterRig, chest: Bone2D) -> void:
	var hip := rig.get_node(^"Facing/Skeleton/Hip") as Bone2D
	var waist := rig.get_node(^"%WaistLayer") as Node2D
	var torso := chest.get_node(^"Art") as Sprite2D
	var waist_art := waist.get_node(^"Art") as Sprite2D
	var animations := rig.get_node(^"AnimationPlayer") as AnimationPlayer
	var label := "Watchman torso stays on the pelvic pivot through swings and rolls"
	for facing: int in [1, -1]:
		for clip: StringName in [&"slash_3", &"roll"]:
			rig.sample(clip, 1, facing, 0.0, 0.0)
			var ticks := roundi(animations.get_animation(clip).length / CombatSpace.STEP)
			for tick: int in ticks:
				var pivot := hip.global_position
				var seated := chest.global_position.distance_to(pivot) < 0.001
				seated = seated and waist.global_position.distance_to(pivot) < 0.001
				seated = seated and _painted_joint_overlaps(pivot, waist_art, torso)
				if not seated:
					_check(false, label, "painted joint at the hip", "%s facing %d at tick %d" % [clip, facing, tick])
					return
				rig.sample(clip, 1, facing, 0.0, CombatSpace.STEP)
	_check(true, label, true, true)


func _watchman_grip(rig: FighterRig) -> void:
	var socket := rig.get_node(FighterRig.SOCKET_PATH) as Marker2D
	var fist := socket.get_node(^"../Art") as Sprite2D
	var sword := socket.get_child(0) as Node2D
	var grip := sword.get_node(^"Grip") as Marker2D
	var blade_art := sword.get_node(^"Artwork") as Sprite2D
	var palm := socket.global_position
	var attached := not socket.position.is_zero_approx() and grip.global_position.is_equal_approx(palm)
	var covered := socket.get_index() < fist.get_index() and fist.is_pixel_opaque(fist.to_local(palm))
	covered = covered and blade_art.is_pixel_opaque(blade_art.to_local(palm))
	_check(attached and covered, "Watchman fist covers the fitted sword handle at the palm", true, attached and covered)


func _watchman_leg_layers(rig: FighterRig) -> void:
	var slots := ["NearLegGear", "NearShinGear", "NearFootGear", "FarLegGear", "FarShinGear", "FarFootGear"]
	var hip := rig.get_node(^"Facing/Skeleton/Hip") as Bone2D
	var spine := hip.get_node(^"Spine")
	var waist := rig.get_node(^"%WaistLayer/Art") as Sprite2D
	var joints: Array[Bone2D] = []
	var layers_ok := true
	for slot: String in slots:
		var joint := rig.get_node(NodePath("%" + slot)).get_parent() as Bone2D
		joints.append(joint)
		var thigh_under_waist := joint.get_parent() == hip and joint.get_index() < spine.get_index()
		layers_ok = layers_ok and (thigh_under_waist or joint.show_behind_parent)
	_check(layers_ok, "Watchman thighs, shins and feet tuck behind their painted seams", true, layers_ok)

	var first_gap := ""
	rig.sample(&"stride", 1, 1, 0.0, 0.0)
	for tick: int in 32:
		for joint: Bone2D in joints:
			var lower := joint.get_node(^"Art") as Sprite2D
			var parent := joint.get_parent()
			var upper := waist if parent == hip else parent.get_node(^"Art") as Sprite2D
			if not _painted_joint_overlaps(joint.global_position, lower, upper):
				first_gap = "%s at tick %d" % [joint.name, tick]
				break
		if not first_gap.is_empty():
			break
		rig.sample(&"stride", 1, 1, 0.0, CombatSpace.STEP)
	_check(first_gap.is_empty(), "Watchman hip, knee and ankle seams overlap across the stride", "", first_gap)


func _painted_joint_overlaps(center: Vector2, lower: Sprite2D, upper: Sprite2D) -> bool:
	for x in range(-4, 5, 2):
		for y in range(-4, 5, 2):
			var point := center + Vector2(x, y)
			if lower.is_pixel_opaque(lower.to_local(point)) and upper.is_pixel_opaque(upper.to_local(point)):
				return true
	return false


func _idle_and_tap() -> void:
	_load_room(YARD)
	var hero := _room.hero
	var before := hero.position
	await _until(func() -> bool: return _room.clock >= 600, 610)
	_check(hero.position.is_equal_approx(before) and hero.last_action == &"",
		"600-tick idle", [before, &""], [hero.position, hero.last_action])
	var response := PlayerCommandSource.radial_response(Vector2(0.25, 0.0), 0.2)
	_check(absf(response.length() - 0.0625) < 0.001,
		"Small analog deflection", 0.0625, response.length())
	_check(PlayerCommandSource.radial_response(Vector2(0.09, 0.09), 0.2) == Vector2.ZERO,
		"Radial drift below threshold", Vector2.ZERO, Vector2(0.09, 0.09))
	var normalized := CombatSpace.velocity_for(Vector2(1, 1), 270.0) / CombatSpace.SPEED
	_check(is_equal_approx(normalized.length(), 1.0), "Diagonal magnitude", 1.0, normalized.length())
	_tap(KEY_J)
	await _until(func() -> bool: return hero.action.kind == ActionState.Kind.ATTACK, 4)
	_check(hero.last_action == &"slash_1", "Press/release between ticks", &"slash_1", hero.last_action)
	await _until(func() -> bool: return hero.action.kind == ActionState.Kind.FREE, 24)
	_check(_room.players_hits == 0 and _room.sound.cue_count == 1, "Empty swing cue without impact", [0, 1],
		[_room.players_hits, _room.sound.cue_count])


func _targets_and_combo() -> void:
	_load_room(WATCH_GATE)
	var hero := _room.hero
	hero.position = Vector2(550, 546)
	var left := _room.spawn_actor(GUARD, CLUB, Vector2(603, 528), 1, 44, -1)
	var right := _room.spawn_actor(GUARD, CLUB, Vector2(605, 564), 1, 44, -1)
	var far := _room.spawn_actor(GUARD, CLUB, Vector2(603, 597), 1, 44, -1)
	_tap(KEY_J)
	await _until(func() -> bool: return _room.players_hits >= 2, 13)
	_check([left.health, right.health, far.health] == [32, 32, 44], "One arc, two targets, depth miss",
		[32, 32, 44], [left.health, right.health, far.health])
	_check(_room.last_impact_tick - _room.last_attack_start_tick == 5, "First active tick", 5,
		_room.last_impact_tick - _room.last_attack_start_tick)
	_check(_room.hitstop == 3, "One shared hitstop", 3, _room.hitstop)
	var animation_time := hero.rig.playback_position()
	var tip := hero.rig.weapon_tip() - hero.position
	_check(absf(animation_time - 5 * CombatSpace.STEP) < 0.001 and tip.x >= 65.0,
		"Blade is out on the first resolved active tick", "forward tip at tick 5", [tip, animation_time])
	var clock := _room.clock
	await physics_frame
	_check(_room.clock == clock and is_equal_approx(animation_time, hero.rig.playback_position()),
		"Pose holds during hitstop", [clock, animation_time], [_room.clock, hero.rig.playback_position()])
	var freeze_left := _room.hitstop
	paused = true
	_room.flush_commands()
	await _physics_frames(10)
	_check(_room.hitstop == freeze_left and _room.clock == clock,
		"Pause holds the remaining hitstop", [freeze_left, clock], [_room.hitstop, _room.clock])
	paused = false
	_tap(KEY_J)
	await _until(func() -> bool: return _room.players_hits == 4, 22)
	_check([left.health, right.health, far.health] == [18, 18, 44], "Buffered chain renews contact list",
		[18, 18, 44], [left.health, right.health, far.health])
	_check(hero.last_action == &"slash_2" and hero.action.impact_index == 1,
		"Combo action index", [&"slash_2", 1], [hero.last_action, hero.action.impact_index])
	await _until(func() -> bool: return hero.action.tick >= 10, 12)
	_tap(KEY_J)
	await _until(func() -> bool: return _room.players_hits == 6, 26)
	_check([left.health, right.health, far.health] == [0, 0, 44],
		"Third swing finishes both in-lane targets", [0, 0, 44], [left.health, right.health, far.health])
	_check(hero.last_action == &"slash_3" and hero.action.impact_index == 2,
		"Finisher action index", [&"slash_3", 2], [hero.last_action, hero.action.impact_index])


func _blade_reach(facing: int) -> void:
	_load_room(WATCH_GATE)
	var hero := _room.hero
	hero.position = Vector2(640, 550)
	hero.facing = facing
	var at_tip := _room.spawn_actor(GUARD, CLUB, Vector2(640 + 112 * facing, 550), 1, 44, -facing)
	var too_far := _room.spawn_actor(GUARD, CLUB, Vector2(640 + 156 * facing, 550), 1, 44, -facing)
	var other_lane := _room.spawn_actor(GUARD, CLUB, Vector2(640 + 112 * facing, 590), 1, 44, -facing)
	_tap(KEY_J)
	await _until(func() -> bool: return hero.action.kind == ActionState.Kind.ATTACK, 4)
	await _until(func() -> bool: return hero.action.kind == ActionState.Kind.FREE, 30)
	_check([at_tip.health, too_far.health, other_lane.health] == [32, 44, 44],
		"Visible sword edge reaches across a gap facing %d" % facing,
		[32, 44, 44], [at_tip.health, too_far.health, other_lane.health])


func _kick() -> void:
	_load_room(WATCH_GATE)
	var hero := _room.hero
	hero.position = Vector2(567, 548)
	var guard := _room.spawn_actor(GUARD, CLUB, Vector2(591, 548), 1, 44, -1)
	_tap(KEY_J)
	await _until(func() -> bool: return _room.players_hits == 1, 10)
	_check(hero.last_action == &"kick" and guard.health == 39,
		"Neutral point-blank action is a kick", [&"kick", 39], [hero.last_action, guard.health])
	await _until(func() -> bool: return guard.position.x >= 617.0, 15)
	_check(guard.position.x >= 617.0, "Kick moves the opponent toward sword range", ">= 617", guard.position.x)


func _wall_and_roll() -> void:
	_load_room(WATCH_GATE)
	var hero := _room.hero
	hero.position = Vector2(549, 549)
	var target := _room.spawn_actor(GUARD, CLUB, Vector2(611, 549), 1, 44, -1)
	var wall := StaticBody2D.new()
	var wall_shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(10, 78)
	wall_shape.shape = rectangle
	wall.add_child(wall_shape)
	wall.position = Vector2(583, 549)
	_room.add_child(wall)
	await physics_frame
	_tap(KEY_J)
	await _until(func() -> bool: return hero.action.tick >= 10, 14)
	_check(target.health == 44, "Strike cannot cross stone", 44, target.health)
	await _until(func() -> bool: return hero.action.kind == ActionState.Kind.FREE, 26)
	hero.position = Vector2(1157, 546)
	_tap(KEY_K)
	await _until(func() -> bool: return hero.action.kind == ActionState.Kind.ROLL, 4)
	await _until(func() -> bool: return hero.action.tick >= 4, 10)
	_check(hero.protected_from(SWORD.opener), "Roll t3–11 protects against ordinary contact",
		true, hero.protected_from(SWORD.opener))
	var low := AttackDef.new()
	low.reach_height = AttackDef.ReachHeight.LOW
	_check(not hero.protected_from(low), "Roll does not protect against a low wave", false, hero.protected_from(low))
	await _until(func() -> bool: return hero.action.tick >= 13, 14)
	_check(not hero.protected_from(SWORD.opener), "Roll recovery is vulnerable", false, hero.protected_from(SWORD.opener))
	await _until(func() -> bool: return hero.action.kind == ActionState.Kind.FREE, 26)
	_check(hero.position.x <= 1175.2, "Wall holds during a roll", "<= 1175.2", hero.position.x)


func _jump_and_action_priority() -> void:
	_load_room(WATCH_GATE)
	var hero := _room.hero
	_tap(KEY_SPACE)
	await _until(func() -> bool: return hero.height > 25.0, 15)
	_tap(KEY_K)
	_tap(KEY_J)
	await _until(func() -> bool: return hero.action.kind == ActionState.Kind.ATTACK, 5)
	_check(hero.last_action == &"air_slash", "Invalid air roll leaves a valid attack", &"air_slash", hero.last_action)
	await _until(func() -> bool: return hero.height >= 82.0, 24)
	var low := AttackDef.new()
	low.height_band = Vector2(0, 20)
	var overlaps := ContactResolver.overlaps(hero.position + Vector2.LEFT * 33.0, 0.0, 1, low, hero)
	_check(not overlaps and hero.height <= 95.0, "Jump is above low contact band", "82–95 px; no contact", [hero.height, overlaps])
	await _until(func() -> bool: return hero.action.kind == ActionState.Kind.LAND, 50)
	_check(hero.height == 0.0, "Lands on floor", 0, hero.height)


func _same_tick_trade() -> void:
	_load_room(WATCH_GATE)
	var hero := _room.hero
	hero.position = Vector2(560, 545)
	var target := _room.spawn_actor(GUARD, SWORD, Vector2(619, 545), 1, 44, -1)
	for actor: Combatant in [hero, target]:
		actor.action.start(ActionState.Kind.ATTACK, SWORD.opener)
	await _until(func() -> bool: return _room.clock >= SWORD.opener.startup + 1, 10)
	_check([hero.health, target.health] == [88, 32], "Both contacts survive attack interruption in the same tick",
		[88, 32], [hero.health, target.health])


func _depth_dodge_counter(direction: int) -> void:
	_load_room(WATCH_GATE, GATE_ROSTER)
	var hero := _room.hero
	var enemy := _room.living_enemy()
	var approach := KEY_D if direction > 0 else KEY_A
	var counter := KEY_A if direction > 0 else KEY_D
	hero.position = Vector2(640 - 58 * direction, 550)
	hero.facing = direction
	enemy.position = Vector2(640, 550)
	enemy.facing = -direction
	await _until(func() -> bool: return enemy.action.kind == ActionState.Kind.ATTACK, 50)
	var was_left := enemy.facing == -1
	_key(KEY_W, true)
	await _until(func() -> bool: return hero.position.y <= 513.0, 24)
	_key(KEY_W, false)
	await _until(func() -> bool: return _room.enemy_misses == 1, 42)
	_check(hero.health == 100 and _room.last_enemy_miss_depth > 23.0 and was_left == (direction > 0),
		"Depth dodge direction %d" % direction, "100 HP, correct facing and depth > 23",
		[hero.health, _room.last_enemy_miss_facing, _room.last_enemy_miss_depth])
	_key(approach, true)
	_tap(KEY_K)
	_key(approach, false)
	await _until(func() -> bool: return hero.action.kind == ActionState.Kind.ROLL, 5)
	await _until(func() -> bool: return hero.action.kind == ActionState.Kind.FREE, 30)
	_check((hero.position.x - enemy.position.x) * direction > 10.0,
		"Roll crosses the sentry direction %d" % direction, "opposite side", [hero.position.x, enemy.position.x])
	_key(KEY_S, true)
	_key(counter, true)
	await _until(func() -> bool:
		var difference := hero.position - enemy.position
		return absf(difference.y) <= 14.0 and absf(difference.x) <= 64.0, 28)
	_tap(KEY_J)
	_key(KEY_S, false)
	_key(counter, false)
	await _until(func() -> bool: return _room.players_hits > 0, 20)
	_check(_room.players_hits == 1 and _room.last_attack_facing == -direction and enemy.health == 32,
		"Counter after dodge and roll direction %d" % direction, [1, -direction, 32],
		[_room.players_hits, _room.last_attack_facing, enemy.health])


func _pause_and_heal() -> void:
	_load_room(WATCH_GATE)
	var hero := _room.hero
	hero.health = 65
	_tap(KEY_U)
	await _until(func() -> bool: return hero.action.kind == ActionState.Kind.FLASK, 4)
	var clock := _room.clock
	paused = true
	_room.flush_commands()
	_input_source.enabled = false
	await _physics_frames(24)
	_check(_room.clock == clock and hero.flasks == 1 and hero.health == 65,
		"Pause holds the flask before its effect tick", [clock, 1, 65], [_room.clock, hero.flasks, hero.health])
	paused = false
	_input_source.enabled = true
	await _until(func() -> bool: return hero.flasks == 0, 25)
	_check(hero.health == 95 and hero.flasks == 0, "Flask commits effect and charge together", [95, 0],
		[hero.health, hero.flasks])


func _load_room(scene: PackedScene, encounter: EncounterDef = null) -> void:
	_drop_room()
	_room = scene.instantiate() as RoomController
	_room.process_mode = Node.PROCESS_MODE_PAUSABLE
	root.add_child(_room)
	_room.begin(encounter, SWORD, 100, 1, _input_source)
	_input_source.clear()


func _drop_room() -> void:
	if _room != null:
		root.remove_child(_room)
		_room.queue_free()
		_room = null


func _until(condition: Callable, limit: int) -> void:
	for frame: int in limit:
		if condition.call():
			return
		await physics_frame


func _physics_frames(count: int) -> void:
	for frame: int in count:
		await physics_frame


func _tap(code: Key) -> void:
	_key(code, true)
	_key(code, false)


func _key(code: Key, held: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = held
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _check(condition: bool, claim: String, expected: Variant, actual: Variant) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	var tick := _room.clock if _room != null else 0
	var context := _room.name if _room != null else &"catalog"
	printerr("FAIL %s tick %d: %s. Expected %s, got %s." % [context, tick, claim, expected, actual])
