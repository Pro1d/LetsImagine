class_name Game2D
extends Node2D

signal game_finished

const WeaponPackedScene := preload("res://scenes/weapon.tscn")
const basic_weapon_spec := preload("res://resources/weapons/basic.tres")

enum State {
	IDLE,
	PLAYING,
	WEAPON_SELECTION,
	ENDING
}
enum Difficulty { Easy=0, Medium, Hard, Boss, Hardest }
const waves_seq : Array[Difficulty] = [
	Difficulty.Easy, Difficulty.Easy,
	Difficulty.Medium, Difficulty.Medium,
	Difficulty.Hard, Difficulty.Hard,
	Difficulty.Boss,
	Difficulty.Hardest, Difficulty.Hardest, Difficulty.Hardest,
	Difficulty.Boss,
]

@export var overlay : Overlay = null
@export var weapon_overlay : WeaponOverlay = null
@export var score_overlay : ScoreOverlay = null
@export var waves_collection : AttackWaveCollection
@export var weapon_specs : Array[WeaponSpec] = []
@export var current_wave_index := 0
var current_wave : AttackWave
var _state := State.IDLE
var completed_waves := 0
var _prev_wave_index := -1 # avoid randomly picking the same wave in a row
var _prev_wave_difficulty := Difficulty.Easy
var fighting_boss := false
var enemy_kill_count := 0
var boss_kill_count := 0

@onready var player_plane := %PlayerPlane as PlayerPlane


# Called when the node enters the scene tree for the first time.
func _enter_tree() -> void:
	Config.root_2d = self

func _ready() -> void:
	player_plane.destroyed.connect(_on_player_destroyed)
	player_plane.set_firing(false)
	overlay.func_player_hp = func() -> int: return player_plane.hitpoint
	overlay.func_player_max_hp = func() -> int: return player_plane.max_hitpoint
	overlay.hide_enemy_life()
	overlay.hide()

func _process(_delta: float) -> void:
	match _state:
		State.PLAYING:
			if fighting_boss and current_wave != null:
				overlay.show_enemy_life(current_wave.compute_total_hitpoints(), current_wave.total_max_hitpoints)

func clear_world() -> void:
	_clear_nodes(self)

func start_game() -> void:
	clear_world()
	player_plane.reset()
	for i in [0, 2] as Array[int]:
		var w := WeaponPackedScene.instantiate() as Weapon
		w.index = i
		w.weapon_spec = basic_weapon_spec
		add_child(w)
		player_plane.add_weapon(w)
	player_plane.set_firing(true)
	completed_waves = 0
	enemy_kill_count = 0
	boss_kill_count = 0
	_prev_wave_index = -1
	_prev_wave_difficulty = waves_seq[0] as Difficulty
	overlay.show()
	VoiceManagerSingleton.play(VoiceManager.Type.StartGame)
	load_next_wave(Difficulty.Easy)
	_state = State.PLAYING

func _on_wave_cleared() -> void:
	if _state != State.PLAYING:
		return
	
	if fighting_boss:
		boss_kill_count += current_wave.killed_enemies
	else:
		enemy_kill_count += current_wave.killed_enemies
	
	stop_and_clear_wave()
	
	completed_waves += 1
	if completed_waves < waves_seq.size():
		# Offer a weapon at start of a new difficulty
		var difficulty := waves_seq[completed_waves]
		if difficulty != _prev_wave_difficulty:
			_prev_wave_index = -1
			clear_world()
			_state = State.WEAPON_SELECTION
			await drop_and_pick_weapon()
			_state = State.PLAYING
		load_next_wave(difficulty)
		_prev_wave_difficulty = difficulty
	else:
		await get_tree().create_timer(1.0).timeout
		if _state == State.PLAYING:
			finish_game(true)

func  load_next_wave(difficulty: Difficulty) -> void:
	var col : Array[PackedScene]
	var forced_index := -1
	var stronger_enemies := false
	match difficulty:
		Difficulty.Easy:
			col = waves_collection.easy_waves
		Difficulty.Medium:
			col = waves_collection.medium_waves
		Difficulty.Hard:
			col = waves_collection.hard_waves
		Difficulty.Hardest:
			col = waves_collection.hardest_waves
			stronger_enemies = true
		Difficulty.Boss, _:
			col = waves_collection.boss_waves
			if boss_kill_count < col.size():
				forced_index = boss_kill_count 
	# avoid picking the same wave twice in a row
	var pick_index := (
		(_prev_wave_index + 1 + randi_range(0, col.size() - 2)) % col.size()
		if _prev_wave_index >= 0 else
		randi_range(0, col.size() - 1)
	)
	if forced_index >= 0:
		pick_index = forced_index
	load_wave(col[pick_index] as PackedScene, difficulty == Difficulty.Boss, stronger_enemies)
	_prev_wave_index = pick_index

func load_wave(scene: PackedScene, boss: bool, stronger_enemies: bool = false) -> void:
	if boss:
		current_wave = scene.instantiate() as AttackWave
		overlay.show_enemy_life(current_wave.total_max_hitpoints, current_wave.total_max_hitpoints)
		VoiceManagerSingleton.play(VoiceManager.Type.BossStarting)
		MusicManager.switch_to_boss_music()
	else:
		current_wave = scene.instantiate() as AttackWave
		current_wave.make_stronger_enemies = stronger_enemies # must be set before add_child
		overlay.hide_enemy_life()
	fighting_boss = boss
	Config.root_2d.add_child(current_wave)
	current_wave.cleared.connect(_on_wave_cleared)

func stop_and_clear_wave() -> void:
	if current_wave != null:
		current_wave.queue_free()
		current_wave = null
	MusicManager.switch_to_main_music()

func drop_and_pick_weapon() -> void:
	# Weapon 1
	var w1 := WeaponPackedScene.instantiate() as Weapon
	var w1_index := randi_range(0, weapon_specs.size() - 1) % weapon_specs.size()
	w1.weapon_spec = weapon_specs[w1_index]
	add_child(w1)
	var w1_3d := w1.take_root_3d()
	Config.root_3d.add_child(w1_3d)
	RemoteTransform2DTo3D.to_3d((%Weapon1Marker2D as Node2D), 0.0, w1_3d, get_viewport().get_camera_3d())
	w1_3d.rotate_y((randf() * 2 - 1) * deg_to_rad(20.0))
	w1_3d.rotate_x(deg_to_rad(-20.0))
	w1_3d.global_position.y += 0.02
	# Weapon 2
	var w2 := WeaponPackedScene.instantiate() as Weapon
	var w2_index := (randi_range(0, weapon_specs.size() - 2) + w1_index + 1) % weapon_specs.size()
	w2.weapon_spec = weapon_specs[w2_index]
	add_child(w2)
	var w2_3d := w2.take_root_3d()
	Config.root_3d.add_child(w2_3d)
	RemoteTransform2DTo3D.to_3d((%Weapon2Marker2D as Node2D), 0.0, w2_3d, get_viewport().get_camera_3d())
	w2_3d.rotate_y((randf() * 2 - 1) * deg_to_rad(20.0))
	w2_3d.rotate_x(deg_to_rad(-20.0))
	w2_3d.global_position.y += 0.02
	#await get_tree().process_frame #create_timer(2.0).timeout
	
	var game_world := get_parent() as GameWorld3D
	var occupied_slots : Array[String] = [
		"" if player_plane.equipped_weapons[0] == null else player_plane.equipped_weapons[0].weapon_spec.display_name(),
		"" if player_plane.equipped_weapons[1] == null else player_plane.equipped_weapons[1].weapon_spec.display_name(),
		"" if player_plane.equipped_weapons[2] == null else player_plane.equipped_weapons[2].weapon_spec.display_name()
	]
	var _selected_w := await game_world.player_pick_weapon(
		w1, w2, occupied_slots, true # player_plane.hitpoint < player_plane.max_hitpoint
	)
	# ALREADY DONE IN game_world.player_pick_weapon
	#if w1 != selected_w:
		#w1.return_root_3d()
		#w1.queue_free()
	#if w2 != selected_w:
		#w2.return_root_3d()
		#w2.queue_free()
	#if selected_w == null:
		#player_plane.hitpoint = mini(player_plane.hitpoint + REPAIR_HEALTH, player_plane.max_hitpoint)

func finish_game(victory: bool) -> void:
	_state = State.ENDING
	player_plane.invunerability = true
	player_plane.set_firing(victory)
	overlay.hide()
	
	if victory:
		VoiceManagerSingleton.play(VoiceManagerSingleton.Type.Victory, 0.0, true, 0.7)
	else:
		await get_tree().create_timer(2.5).timeout
		VoiceManagerSingleton.play(VoiceManagerSingleton.Type.Defeat, 0.0, true, 0.7)
	
	stop_and_clear_wave()
	
	SoundFxManagerSingleton.play(SoundFxManager.Type.Pop)
	score_overlay.set_victory(victory)
	score_overlay.commit_xp_gain(
		completed_waves * Config.XP_PER_WAVE + enemy_kill_count * Config.XP_PER_ENEMY,
		boss_kill_count * Config.XP_PER_BOSS
	)
	score_overlay.show()
	await score_overlay.continue_clicked
	score_overlay.hide()
	
	_state = State.IDLE
	player_plane.set_firing(false)
	player_plane.reset()
	clear_world()
	game_finished.emit()

func _clear_nodes(n: Node) -> void:
	for c in n.get_children():
		if c.is_in_group("unique_to_game"):
			c.queue_free()
		else:
			_clear_nodes(c)

func _on_player_destroyed() -> void:
	match _state:
		State.PLAYING:
			finish_game(false)
