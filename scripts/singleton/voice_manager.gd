class_name VoiceManager
extends Node

enum Type {
	Intro = 0,
	StartGame,
	EquipWeapon,
	Repair,
	PlayerDamage,
	BossStarting,
	Defeat,
	Victory,
}
const audio_resources_by_type := {
	Type.Intro: preload("res://resources/audio/voices/child-mom-dialog.tres"),
	Type.StartGame: preload("res://resources/audio/voices/start.tres"),
	Type.EquipWeapon: preload("res://resources/audio/voices/choice.tres"),
	Type.Repair: preload("res://resources/audio/voices/yeah.tres"),
	Type.PlayerDamage: preload("res://resources/audio/voices/damage.tres"),
	Type.BossStarting: preload("res://resources/audio/voices/boss.tres"),
	Type.Defeat: preload("res://resources/audio/voices/defeat.tres"),
	Type.Victory: preload("res://resources/audio/voices/victory.tres"),
}

@onready var _audio_player := %AudioStreamPlayer as AudioStreamPlayer

func play(type: Type, proba_quiet: float = 0.0, queue: bool = false, delay: float = 0.0) -> void:
	if randf() < proba_quiet:
		return
	
	if delay > 1e-4:
		await get_tree().create_timer(delay).timeout
	
	if _audio_player.playing:
		if queue:
			await _audio_player.finished
			await play(type, 0.0, false) # recc call to avoid race condition + avoid infinite queue
		return
	
	var res := audio_resources_by_type.get(type, null) as AudioStream
	if res == null:
		return
		
	await play_stream(res)

func play_stream(stream: AudioStream) -> void:
	_audio_player.stream = stream
	_audio_player.play()
	await _audio_player.finished

func finished() -> void:
	if _audio_player.playing:
		await _audio_player.finished
