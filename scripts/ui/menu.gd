class_name Menu
extends Control

signal play_clicked

var plane_index := 0

@onready var display_xp := Config.xp
var tween_xp : Tween

func _ready() -> void:
	_display_level_progression(display_xp)
	_display_plane()
	
	(%PrevPlaneButton as Button).pressed.connect(_on_change_plane_pressed.bind(-1))
	(%NextPlaneButton as Button).pressed.connect(_on_change_plane_pressed.bind(+1))
	(%PlayButton as Button).pressed.connect(play_clicked.emit)
	WhalepassSingleton.progress_updated.connect(_on_progress_updated)
	WhalepassSingleton.inventory_updated.connect(_on_inventory_updated)
	
	visibility_changed.connect(func() -> void:
		if visible: WhalepassSingleton.trigger_update()
	)
	WhalepassSingleton.trigger_update()

func _on_progress_updated() -> void:
	if tween_xp != null:
		tween_xp.kill()
	tween_xp = create_tween()
	tween_xp.tween_method(_display_level_progression, display_xp, Config.xp, 2.0) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

func _on_inventory_updated() -> void:
	_display_plane()

func _display_level_progression(xp: int) -> void:
	display_xp = xp
	var e := Config.get_level_from_xp(display_xp)
	(%PlayerLevelLabel as Label).text = "Level %d" % [e.level] + (" (max)" if e.level == Config.Exp.max_level else "")
	(%XpLabel as Label).text = "Next Level: %d/%d exp" % [e.xp, e.xp_next_level]
	(%XpProgressBar as ProgressBar).value = e.xp
	(%XpProgressBar as ProgressBar).max_value = e.xp_next_level

func _on_change_plane_pressed(i: int) -> void:
	var planes_count := Config.available_planes.size()
	plane_index = (plane_index + i + planes_count) % planes_count
	_display_plane()

func _display_plane() -> void:
	var type := plane_index as PlayerPlane.Type
	if Config.available_planes[plane_index]:
		(%PlaneLabel as Label).text = PlayerPlane.display_description(type)
	else:
		(%PlaneLabel as Label).text = (
			PlayerPlane.display_description(type).split("\n")[0] +
			"\nUnlocked at level %d" % [Config.unlock_level_planes[type]]
		)
	Config.player_node.type = type
	(%PlayButton as Button).disabled = not Config.available_planes[plane_index]
