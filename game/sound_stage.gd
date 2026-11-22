class_name SoundStage
extends Node

const FLESH := preload("res://content/audio/flesh_contact.wav")
const STRAW := preload("res://content/audio/straw_contact.wav")
const IRON := preload("res://content/audio/iron_contact.wav")
const MUSIC := preload("res://content/audio/court_at_dusk.wav")

var cue_count := 0
var _score: AudioStreamPlayer


func play(stream: AudioStream, _floor_point: Vector2 = Vector2.ZERO) -> void:
	if stream == null:
		return
	cue_count += 1
	if DisplayServer.get_name() == "headless":
		return
	var speaker := AudioStreamPlayer.new()
	speaker.bus = &"SFX"
	speaker.stream = stream
	add_child(speaker)
	speaker.finished.connect(speaker.queue_free, CONNECT_ONE_SHOT)
	speaker.play()


func start_score() -> void:
	if is_instance_valid(_score):
		return
	_score = AudioStreamPlayer.new()
	_score.bus = &"Music"
	_score.stream = MUSIC
	add_child(_score)
	_score.play()


func impact(material: AttackDef.ContactMaterial) -> void:
	match material:
		AttackDef.ContactMaterial.IRON:
			play(IRON)
		AttackDef.ContactMaterial.STRAW:
			play(STRAW)
		_:
			play(FLESH)



func stop_all() -> void:
	for child: Node in get_children():
		if child is AudioStreamPlayer:
			child.stop()
