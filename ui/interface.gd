class_name GameInterface
extends Control

signal chosen(choice: StringName)

const DISPLAY_FONT := preload("res://ui/fonts/DisplaySerif.ttf")
const UI_FONT := preload("res://ui/fonts/InterfaceSans.ttf")
const CREST := preload("res://ui/crest.svg")
const FLASK := preload("res://ui/flask.svg")
const FORTRESS := preload("res://content/rooms/watch_gate/fortress.svg")
const VEIL := preload("res://ui/title_veil.svg")
const PORTRAIT := preload("res://actors/hero/WardenRig.tscn")

const BRASS := Color("#ca9364")
const CREAM := Color("#ffeed1")
const MIST := Color("#b9b2b7")
const SHIELD := Color("#1b2835")

var preferences: PlayPreferences
var source: PlayerCommandSource
var _layout: Control
var _menu: Control
var _portrait: FighterRig
var _health_fill: ColorRect
var _health_text: Label
var _loadout: Label
var _weapon_icon: TextureRect
var _flask_count: Label
var _status: Label
var _hint: Label
var _controls: Label
var _diagnostics: Label
var _room_definition: RoomDef
var _practice := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS


func _physics_process(delta: float) -> void:
	if is_instance_valid(_portrait):
		_portrait.sample(&"idle", 0, -1, 0.0, delta)


func title(weapon: WeaponDef) -> void:
	_prepare_layout()
	_texture(_layout, FORTRESS, Rect2(0, 0, 1280, 720))
	_texture(_layout, VEIL, Rect2(0, 0, 1280, 720))
	# Scale the display parent so the rig can keep its own height transform.
	var display := Node2D.new()
	display.position = Vector2(985, 655)
	display.scale = Vector2(3.05, 3.05)
	_layout.add_child(display)
	_portrait = PORTRAIT.instantiate() as FighterRig
	display.add_child(_portrait)
	_portrait.equip(weapon)
	_portrait.sample(&"idle", 0, -1, 0.0, 0.0)

	_texture(_layout, CREST, Rect2(90, 87, 64, 64))
	_label(_layout, tr(&"TITLE_TAG"), Rect2(169, 105, 370, 36), 16, BRASS)
	_label(_layout, tr(&"TITLE"), Rect2(85, 149, 790, 122), 83, CREAM, true)
	_line(_layout, Rect2(93, 275, 476, 1), BRASS)
	_line(_layout, Rect2(93, 274, 76, 3), BRASS)
	_label(_layout, tr(&"TITLE_STORY"), Rect2(94, 299, 456, 78), 22, MIST)
	var play := _button(_layout, &"PLAY", &"play", Rect2(94, 398, 224, 60), true)
	_button(_layout, &"TRAINING", &"training", Rect2(332, 398, 224, 60))
	_button(_layout, &"SETTINGS", &"settings", Rect2(94, 471, 142, 44))
	_button(_layout, &"CREDITS", &"credits", Rect2(248, 471, 150, 44))
	if not OS.has_feature("web"):
		_button(_layout, &"QUIT", &"quit", Rect2(410, 471, 146, 44))
	_label(_layout, tr(&"BUILD_LABEL") % BuildVersion.SHA, Rect2(94, 644, 340, 24), 14, MIST)
	play.grab_focus()


func battle(definition: RoomDef, practice: bool) -> void:
	_prepare_layout()
	_room_definition = definition
	_practice = practice

	_panel(_layout, Rect2(26, 23, 367, 102))
	_texture(_layout, CREST, Rect2(38, 39, 58, 58))
	_label(_layout, tr(&"HEALTH").to_upper(), Rect2(108, 33, 110, 24), 12, MIST)
	_health_text = _label(_layout, "", Rect2(260, 32, 110, 25), 15, CREAM)
	_health_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_line(_layout, Rect2(108, 61, 262, 8), Color("#311e2c"))
	_health_fill = _line(_layout, Rect2(108, 61, 262, 8), Color("#be605c"))
	_weapon_icon = _texture(_layout, null, Rect2(107, 80, 42, 24))
	_loadout = _label(_layout, "", Rect2(153, 78, 178, 26), 15, CREAM)
	_texture(_layout, FLASK, Rect2(333, 79, 19, 24))
	_flask_count = _label(_layout, "", Rect2(355, 78, 26, 25), 15, CREAM)

	_panel(_layout, Rect2(994, 23, 260, 82))
	var room_name := _label(_layout, tr(definition.label_key), Rect2(1012, 34, 224, 34), 24, CREAM, true)
	room_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status = _label(_layout, "", Rect2(1011, 67, 224, 25), 15, BRASS)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	_panel(_layout, Rect2(26, 665, 1228, 40))
	_controls = _label(_layout, "", Rect2(42, 671, 600, 27), 14, CREAM)
	_hint = _label(_layout, "", Rect2(625, 671, 611, 27), 15, CREAM)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_diagnostics = _label(_layout, "", Rect2(30, 135, 744, 30), 15, Color.AQUAMARINE)


func update_battle(room: RoomController) -> void:
	if not is_instance_valid(_health_fill):
		return
	var hero := room.hero
	_health_fill.size.x = 262.0 * float(hero.health) / hero.max_health
	_health_text.visible = preferences.health_numbers
	_health_text.text = "%d / %d" % [hero.health, hero.max_health]
	_weapon_icon.texture = hero.weapon.icon
	_loadout.text = tr(hero.weapon.label_key)
	_flask_count.text = str(hero.flasks)
	var enemy := room.living_enemy()
	if _room_definition.encounter == null:
		_status.text = tr(&"YARD_TARGETS")
	elif enemy != null:
		var label := _room_definition.encounter.roster[0].label_key
		_status.text = tr(label)
		if preferences.health_numbers:
			_status.text += "  %d / %d" % [enemy.health, enemy.max_health]
	else:
		_status.text = tr(&"GATE_OPEN" if room.marks.gate_open else &"GATE_LOCKED")
	_controls.text = "%s %s   /   %s %s   /   %s %s   /   %s %s   /   %s %s" % [
		source.movement_label(), tr(&"MOVE"),
		source.action_label(&"attack"), tr(&"ATTACK"),
		source.action_label(&"roll"), tr(&"ROLL"),
		source.action_label(&"jump"), tr(&"JUMP"),
		source.action_label(&"flask"), tr(&"FLASK_NAME")
	]
	if room.can_exit():
		_hint.text = tr(&"EXIT_TRAINING" if _practice else &"EXIT_HINT") % source.action_label(&"interact")
	else:
		_hint.text = tr(&"YARD_HINT" if _room_definition.encounter == null else &"GATE_HINT")
	_diagnostics.visible = preferences.diagnostics
	if preferences.diagnostics:
		var phase := ActionState.Kind.keys()[hero.action.kind] as String
		_diagnostics.text = "t%04d  %s:%02d  %s  (%.1f, %.1f)  h %.1f  freeze %d" % [
			room.clock, phase, maxi(0, hero.action.tick - 1), hero.last_action,
			hero.position.x, hero.position.y, hero.height, room.hitstop
		]


func pause_menu() -> void:
	_overlay(Rect2(403, 164, 474, 388))
	_label(_menu, tr(&"PAUSE"), Rect2(431, 186, 418, 73), 53, CREAM, true)
	var resume := _button(_menu, &"RESUME", &"resume", Rect2(433, 278, 414, 53), true)
	_button(_menu, &"SETTINGS", &"settings", Rect2(433, 343, 414, 53))
	_button(_menu, &"RETURN_TITLE", &"title", Rect2(433, 408, 414, 53))
	_label(_menu, tr(&"BUILD_LABEL") % BuildVersion.SHA, Rect2(434, 498, 390, 28), 14, MIST)
	resume.grab_focus()


func options() -> void:
	_overlay(Rect2(333, 80, 614, 584))
	_label(_menu, tr(&"SETTINGS"), Rect2(362, 98, 552, 70), 49, CREAM, true)
	_slider(&"MASTER_VOLUME", 184.0, 0.0, 1.0, preferences.volume[&"Master"],
		func(value: float) -> void: _volume(&"Master", value))
	_slider(&"MUSIC_VOLUME", 231.0, 0.0, 1.0, preferences.volume[&"Music"],
		func(value: float) -> void: _volume(&"Music", value))
	_slider(&"SFX_VOLUME", 278.0, 0.0, 1.0, preferences.volume[&"SFX"],
		func(value: float) -> void: _volume(&"SFX", value))
	_slider(&"STICK_DEADZONE", 325.0, 0.1, 0.45, preferences.stick_deadzone,
		func(value: float) -> void: preferences.stick_deadzone = value)
	_toggle(&"SHAKE", 373.0, preferences.shake,
		func(value: bool) -> void: preferences.shake = value)
	_toggle(&"PARTICLES", 421.0, preferences.particles,
		func(value: bool) -> void: preferences.particles = value)
	_toggle(&"REDUCE_FLASHES", 469.0, preferences.reduce_flashes,
		func(value: bool) -> void: preferences.reduce_flashes = value)
	_toggle(&"HEALTH_NUMBERS", 517.0, preferences.health_numbers,
		func(value: bool) -> void: preferences.health_numbers = value)
	var back := _button(_menu, &"BACK", &"back", Rect2(362, 580, 216, 53), true)
	back.grab_focus()


func credits() -> void:
	_overlay(Rect2(349, 183, 582, 356))
	_label(_menu, tr(&"CREDITS"), Rect2(380, 206, 510, 76), 47, CREAM, true)
	_label(_menu, tr(&"CREDITS_DETAIL"), Rect2(382, 300, 491, 94), 22, MIST)
	var back := _button(_menu, &"BACK", &"back", Rect2(382, 440, 220, 54), true)
	back.grab_focus()


func summary(won: bool) -> void:
	_overlay(Rect2(335, 188, 610, 352))
	_label(_menu, tr(&"CLEARED" if won else &"STOPPED"), Rect2(363, 213, 554, 79), 45, CREAM, true)
	_label(_menu, tr(&"VICTORY_DETAIL" if won else &"DEFEAT_DETAIL"),
		Rect2(366, 305, 530, 58), 21, MIST)
	var replay := _button(_menu, &"RESTART", &"play", Rect2(365, 417, 249, 56), true)
	_button(_menu, &"RETURN_TITLE", &"title", Rect2(628, 417, 286, 56))
	replay.grab_focus()


func close_menu() -> void:
	if is_instance_valid(_menu):
		remove_child(_menu)
		_menu.queue_free()
	_menu = null
	_set_background_focus(true)


func _set_background_focus(active: bool) -> void:
	if is_instance_valid(_layout):
		for control: Node in _layout.get_children():
			if control is Button:
				control.focus_mode = Control.FOCUS_ALL if active else Control.FOCUS_NONE


func _prepare_layout() -> void:
	close_menu()
	if is_instance_valid(_layout):
		remove_child(_layout)
		_layout.queue_free()
	_layout = Control.new()
	_layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_layout)
	_portrait = null
	_health_fill = null


func _overlay(panel: Rect2) -> void:
	close_menu()
	_set_background_focus(false)
	_menu = Control.new()
	add_child(_menu)
	_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_line(_menu, Rect2(0, 0, 1280, 720), Color(0.035, 0.057, 0.089, 0.73))
	_panel(_menu, panel, Color("#14202d"))
	_line(_menu, Rect2(panel.position + Vector2(1, 1), Vector2(panel.size.x-2, 2)), BRASS)


func _volume(bus: StringName, value: float) -> void:
	preferences.volume[bus] = value
	preferences.apply_audio()


func _slider(key: StringName, y: float, low: float, high: float, value: float, callback: Callable) -> void:
	_label(_menu, tr(key), Rect2(364, y, 284, 29), 18, CREAM)
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = 0.01
	slider.value = value
	_menu.add_child(slider)
	slider.position = Vector2(653, y+6)
	slider.size = Vector2(251, 24)
	slider.add_theme_stylebox_override("slider", _style(Color("#25374a"), Color("#705a51"), 1))
	slider.add_theme_stylebox_override("grabber_area", _style(Color("#7a554b"), BRASS, 1))
	slider.add_theme_stylebox_override("focus", _style(Color.TRANSPARENT, CREAM, 1))
	slider.value_changed.connect(callback)


func _toggle(key: StringName, y: float, pressed: bool, callback: Callable) -> void:
	var toggle := CheckButton.new()
	toggle.text = tr(key)
	toggle.button_pressed = pressed
	_menu.add_child(toggle)
	toggle.position = Vector2(364, y)
	toggle.size = Vector2(541, 40)
	_button_theme(toggle, false, 18)
	toggle.toggled.connect(callback)


func _button(parent: Control, key: StringName, choice: StringName, area: Rect2, primary := false) -> Button:
	var button := Button.new()
	button.text = tr(key)
	parent.add_child(button)
	button.position = area.position
	button.size = area.size
	_button_theme(button, primary, 21 if area.size.y > 48 else 17)
	button.pressed.connect(chosen.emit.bind(choice))
	return button


func _button_theme(button: Button, primary: bool, font_size: int) -> void:
	button.add_theme_font_override("font", UI_FONT)
	button.add_theme_font_size_override("font_size", font_size)
	var normal := Color("#603d3a") if primary else SHIELD
	button.add_theme_stylebox_override("normal", _style(normal, Color("#9d6d55"), 1))
	button.add_theme_stylebox_override("hover", _style(normal.lightened(0.14), BRASS, 1))
	button.add_theme_stylebox_override("pressed", _style(normal.lightened(0.21), CREAM, 1))
	button.add_theme_stylebox_override("focus", _style(Color.TRANSPARENT, Color("#f7cc8e"), 2))
	for state: String in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		button.add_theme_color_override(state, CREAM)


func _panel(parent: Control, area: Rect2, fill := Color(0.06, 0.095, 0.144, 0.91)) -> Panel:
	var result := Panel.new()
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(result)
	result.position = area.position
	result.size = area.size
	result.add_theme_stylebox_override("panel", _style(fill, Color("#916a57"), 1))
	return result


func _style(fill: Color, line_color: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = line_color
	style.set_border_width_all(width)
	return style


func _label(
	parent: Control, value: String, area: Rect2, points: int, color: Color, display_font := false
) -> Label:
	var result := Label.new()
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	parent.add_child(result)
	result.add_theme_font_override("font", DISPLAY_FONT if display_font else UI_FONT)
	result.add_theme_font_size_override("font_size", points)
	result.add_theme_color_override("font_color", color)
	result.position = area.position
	result.size = area.size
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.text = value
	return result


func _line(parent: Control, area: Rect2, color: Color) -> ColorRect:
	var result := ColorRect.new()
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.color = color
	parent.add_child(result)
	result.position = area.position
	result.size = area.size
	return result


func _texture(parent: Control, image: Texture2D, area: Rect2) -> TextureRect:
	var result := TextureRect.new()
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.texture = image
	result.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	result.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	parent.add_child(result)
	result.position = area.position
	result.size = area.size
	return result
