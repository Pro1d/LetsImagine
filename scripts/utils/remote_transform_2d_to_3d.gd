class_name RemoteTransform2DTo3D
extends Node2D

signal position_updated(from_2d: Transform2D)

@export var _target_3d : Node3D
@export var y_offset := 0.0
@onready var _camera_3d := get_viewport().get_camera_3d()
var initialized := false
func _enter_tree() -> void:
	process_physics_priority = -100
	process_priority = 100
	visible = false

#func _ready() -> void:
	#var p3d := _target_3d.get_parent()
	#p3d.remove_child(_target_3d)
	#_target_3d.top_level = true
	#get_tree().root.add_child(_target_3d) # Config.root_3d.

func _physics_process(_delta: float) -> void:
	force_update()
func _process(_delta: float) -> void:
	if not initialized:
		force_update()
		visible = true
		initialized = true

func force_update() -> void:
	RemoteTransform2DTo3D.to_3d(self, y_offset, _target_3d, _camera_3d)
	
	position_updated.emit(global_transform)

static func to_3d(from: Node2D, _y_offset: float, to: Node3D, cam3d: Camera3D) -> void:
	to.global_position = cam3d.project_position(from.global_position, absf(cam3d.global_position.y) - _y_offset)
	to.global_position.y -= _y_offset
	to.global_rotation.y = -from.global_rotation
