extends Node

#const CursorArrowIcon := preload("res://assets/images/ui/cursor_arrow2.atlastex")
#const CursorIBeamIcon := preload("res://assets/images/ui/cursor_ibeam.atlastex")
#const CursorAimIcon := preload("res://assets/images/ui/cursor_aim1.atlastex")

const SAVE_PATH := "user://save.cfg"
var save_file := ConfigFile.new()

const ATTACK_SPEED := 1.7
const REPAIR_HEALTH := 2
const XP_PER_BOSS := 75
const XP_PER_ENEMY := 1
const XP_PER_WAVE := 5

var LAYER_PLAYER := 1 << 1
var LAYER_ENEMY := 1 << 2
var LAYER_PLAYER_PROJECTILE := 1 << 3 #(ProjectSettings.get_setting("layer_names/2d_physics/player_projectile") as String)
var LAYER_ENEMY_PROJECTILE := 1 << 4 #(ProjectSettings.get_setting("layer_names/2d_physics/enemy_projectile") as String)
var LAYER_PLAYER_SHIELD := 1 << 8

const curve_width_resources : Array[Resource] = [
	preload("res://resources/materials/curve_width_1.tres"),
	preload("res://resources/materials/curve_width_2.tres"),
	preload("res://resources/materials/curve_width_3.tres"),
	preload("res://resources/materials/curve_width_4.tres"),
]
const plane_model_resources : Array[ArrayMesh] = [
	preload("res://assets/models/all/Plane.res"),
	preload("res://assets/models/all/PlaneRed.res"),
	preload("res://assets/models/all/PlaneBlackWhite.res"),
	preload("res://assets/models/all/PlaneGreen.res"),
	preload("res://assets/models/all/PlaneSky.res")
]
const plane_type_by_reward_name := {
	"wood": PlayerPlane.Type.Wood,
	"red": PlayerPlane.Type.FireRed,
	"green": PlayerPlane.Type.EmeraldGreen,
	"white": PlayerPlane.Type.BlackAndWhite,
	"sky": PlayerPlane.Type.AboveSky
}
var available_planes : Array[bool] = [true, false, false, false, false]
const unlock_level_planes: Array[int] = [0, 1, 2, 4, 7]
var xp : int:
	set(x):save_config("game", "xp", x)
	get: return read_config("game", "xp", 0)

var player_node : PlayerPlane
var root_2d : Node2D
var root_3d : Node3D
var camera_3d : Camera3D

func _enter_tree() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	camera_3d = get_viewport().get_camera_3d()
#	Input.set_custom_mouse_cursor(
#		CursorArrowIcon, Input.CURSOR_ARROW, Vector2(2, 2)
#	)
#	Input.set_custom_mouse_cursor(
#		CursorIBeamIcon, Input.CURSOR_IBEAM, Vector2(16, 16)
#	)
#	Input.set_custom_mouse_cursor(
#		CursorAimIcon, Input.CURSOR_CROSS, Vector2(16, 16)
#	)
	save_file.load(SAVE_PATH)
	for i in range(available_planes.size()):
		available_planes[i] = read_config("game", "available_planes_" + str(i), available_planes[i])

func save_available_planes() -> void:
	for i in range(available_planes.size()):
		save_config("game", "available_planes_" + str(i), available_planes[i])

func read_config(section: String, key: String, default: Variant) -> Variant:
	if save_file.has_section_key(section, key):
		return save_file.get_value(section, key)
	else:
		return default
	
func save_config(section: String, key: String, value: Variant) -> void:
	save_file.set_value(section, key, value)
	save_file.save(SAVE_PATH)

class Exp:
	const max_level := 10
	var level := 0
	var xp := 0
	var xp_next_level := 100

func get_level_from_xp(_xp: int = -1) -> Exp:
	var e := Exp.new()
	e.xp = xp if _xp == -1 else _xp
	
	while e.xp > e.xp_next_level:
		e.level += 1
		if e.level >= Exp.max_level:
			e.level = Exp.max_level
			e.xp = e.xp_next_level
			break
		else:
			e.xp -= e.xp_next_level
			e.xp_next_level += 50
	
	return e

func give_xp(_xp: int) -> void:
	xp += _xp
	update_inventory()

func update_inventory() -> void:
	var e := get_level_from_xp()
	for p in range(available_planes.size()):
		available_planes[p] = (e.level >= unlock_level_planes[p])
	save_available_planes()
