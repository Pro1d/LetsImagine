class_name Menu
extends Control

signal play_clicked

var plane_index := 0

@onready var display_xp := Config.xp
var tween_xp : Tween

@onready var _player_level_label := %PlayerLevelLabel as Label
@onready var _xp_label := %XpLabel as Label
@onready var _xp_progress_bar := %XpProgressBar as ProgressBar
@onready var _play_button := %PlayButton as Button
@onready var _plane_label := %PlaneLabel as Label

func _ready() -> void:
	_display_level_progression(display_xp)
	_display_plane()
	
	(%PrevPlaneButton as Button).pressed.connect(_on_change_plane_pressed.bind(-1))
	(%NextPlaneButton as Button).pressed.connect(_on_change_plane_pressed.bind(+1))
	_play_button.pressed.connect(play_clicked.emit)
	
	visibility_changed.connect(func() -> void:
		if visible: _update()
	)
	_update()

func _update() -> void:
	if tween_xp != null:
		tween_xp.kill()
	tween_xp = create_tween()
	tween_xp.tween_method(_display_level_progression, display_xp, Config.xp, 2.0) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		
	_display_plane()

func _display_level_progression(xp: int) -> void:
	display_xp = xp
	var e := Config.get_level_from_xp(display_xp)
	_player_level_label.text = "Level %d" % [e.level] + (" (max)" if e.level == Config.Exp.max_level else "")
	_xp_label.text = "Next Level: %d/%d exp" % [e.xp, e.xp_next_level]
	_xp_progress_bar.value = e.xp
	_xp_progress_bar.max_value = e.xp_next_level

func _on_change_plane_pressed(i: int) -> void:
	var planes_count := Config.available_planes.size()
	plane_index = (plane_index + i + planes_count) % planes_count
	_display_plane()

func _display_plane() -> void:
	var type := plane_index as PlayerPlane.Type
	if Config.available_planes[plane_index]:
		_plane_label.text = PlayerPlane.display_description(type)
	else:
		_plane_label.text = (
			PlayerPlane.display_description(type).split("\n")[0] +
			"\nUnlocked at level %d" % [Config.unlock_level_planes[type]]
		)
	Config.player_node.type = type
	_play_button.disabled = not Config.available_planes[plane_index]
