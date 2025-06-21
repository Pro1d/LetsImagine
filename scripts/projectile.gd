class_name Projectile
extends CharacterBody2D

enum Shape { Circle = 0, Square, Triangle, Cross }
const ProjectileResource := preload("res://scenes/projectile.tscn")

@export var shape_type := Shape.Circle :
	set(s):
		if s != shape_type:
			shape_type = s
			_update_shape_type()
@export var radius := 15.0 :
	set(r):
		if radius != r:
			radius = r
			_update_shape_radius()
@export var color := Color.WHITE :
	set(c):
		if color != c:
			color = c
			_update_color()
@export var by_player := false :
	set(p):
		by_player = p
		_update_mask()
const base_velocity := 900.0
@export var current_velocity := Vector2.RIGHT * base_velocity

@onready var _shape := ($CollisionShape2D as CollisionShape2D).shape as CircleShape2D
@onready var _seek_area := $SeekArea2D as Area2D
@onready var _particles := %CPUParticles2D as CPUParticles2D
@onready var _explode_fx_root := %ExplodeCircle as Node2D
@onready var _explode_fx_animation := %ExplodeAnimationPlayer as AnimationPlayer

var exception_body : Array[PhysicsBody2D] = []
var bounce_left := 0 # 3
var piercing := false
var seeking := false
var explosive := false
var split_on_hit := false

var damage := 10.0 / Config.ATTACK_SPEED
var lifetime := 1.0 :
	set(l):
		lifetime = l
#const seek_radius := 150.0
#const explosion_radius := 120.0
const seek_accel := base_velocity * 5

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_update_shape_radius()
	_update_color()
	_update_mask()
	_update_shape_type()
	
	if not (seeking or explosive):
		_seek_area.monitoring = false
		_seek_area.remove_child(_seek_area.get_child(0))

func _physics_process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0:
		destroy_projectile(false)
	else:
		if seeking:
			var dmin := INF
			var bmin : PhysicsBody2D = null
			for b: PhysicsBody2D in _seek_area.get_overlapping_bodies():
				var d := global_position.distance_to(b.global_position)
				if d < dmin:
					dmin = d
					bmin = b
			if bmin != null:
				var seek_velocity := seek_accel * global_position.direction_to(bmin.global_position) * delta
				current_velocity = (current_velocity + seek_velocity).normalized() * current_velocity.length()
		_move_by(current_velocity * delta)
		rotation = current_velocity.angle()

func _move_by(motion: Vector2, reccursive: int = 3) -> void:
	if reccursive == 0:
		return
	
	var col := move_and_collide(motion, false, 0.08, true)

	if col != null:
		var N := col.get_normal()
		var body := col.get_collider() as PhysicsBody2D
		var rem := col.get_remainder()
		
		# SPLIT
		if split_on_hit:
			for i in range(2):
				var p := _clone_projectile()
				p.radius *= 0.7
				p.damage *= 0.6
				p.bounce_left = maxi(p.bounce_left - 2, 0)
				p.current_velocity = p.current_velocity.rotated((i * 2 - 1) * PI/2)
				#p.current_velocity = p.current_velocity.length() * N.rotated((i * 2 - 1) * PI/10)
				p.split_on_hit = false
		
		# BOUNCING
		if bounce_left > 0:
			if body.is_in_group("world_boundary"):
				current_velocity = current_velocity.bounce(N)
				_on_body_hit(body)
				for e in get_collision_exceptions():
					if e != null:
						remove_collision_exception_with(e)
			else:
				current_velocity = current_velocity.length() * N.rotated(
					(randf() * 2 * PI)
					if piercing else
					clampf(randfn(0, PI/6), -PI/2*.9, PI/2*.9)
				)
				if piercing:
					for e in get_collision_exceptions():
						if e != null:
							remove_collision_exception_with(e)
					add_collision_exception_with(body)
				_on_body_hit(body)
			bounce_left -= 1
			_move_by(rem.length() * current_velocity.normalized(), reccursive - 1)
		# PIERCING
		elif piercing:
			_on_body_hit(body)
			add_collision_exception_with(body)
			_move_by(rem, reccursive - 1)
		# EXPLOSIVE
		elif explosive:
			#_on_body_hit(body)
			destroy_projectile(true)
		# NORMAL
		else:
			_on_body_hit(body)
			destroy_projectile(true)

func _on_body_hit(body: PhysicsBody2D, damage_factor: float = 1.0) -> void:
	var enemy := Enemy.find_parent_enemy(body)
	if enemy != null:
		enemy.take_damage(damage * damage_factor)
	var player := body as PlayerPlane
	if player != null:
		player.take_damage()
	_particles.emitting = true
	SoundFxManagerSingleton.play(SoundFxManager.Type.ProjectileHit)

func destroy_projectile(_hit: bool = false) -> void:
	queue_free()
	
	if explosive:
		for b: PhysicsBody2D in _seek_area.get_overlapping_bodies():
			#var d := global_position.distance_to(b.global_position)
			#var e := Enemy.find_parent_enemy(b)
			#if e != null:
				#d -= e.radius
			#if d < explosion_radius:
			_on_body_hit(b, 2.0)
		# Explode fx
		_explode_fx_root.show()
		_explode_fx_animation.play("explode")
		SoundFxManagerSingleton.play(SoundFxManager.Type.ProjectileExplode)
		_keep_fx_until_death(_explode_fx_root, _explode_fx_animation.animation_finished)
	else:
		# Hit fx
		_particles.emitting = true
		_keep_fx_until_death(_particles, _particles.finished)

func _keep_fx_until_death(node: Node2D, s: Signal) -> void:
	var gpos := node.global_transform
	node.modulate = modulate
	remove_child(node)
	get_parent().add_child(node)
	node.global_transform = gpos
	await s
	node.queue_free()

func _clone_projectile() -> Projectile:
	var p := ProjectileResource.instantiate() as Projectile
	p.global_position = global_position
	
	p.radius = radius
	p.color = color
	p.shape_type = shape_type
	p.by_player = by_player
	p.current_velocity = current_velocity
	p.bounce_left = bounce_left
	p.piercing = piercing
	p.seeking = seeking
	p.explosive = explosive
	p.split_on_hit = split_on_hit
	p.damage = damage
	p.lifetime = lifetime
	
	get_parent().add_child(p)
	return p

func _update_shape_type() -> void:
	var i := 0
	for c: Node2D in $Shape.get_children():
		c.visible = (shape_type == i)
		if c.visible:
			(c as Line2D).width_curve = Config.curve_width_resources.pick_random()
			if i == Shape.Circle or i == Shape.Cross:
				c.rotation = randf() * 2 * PI
		i += 1

func _update_shape_radius() -> void:
	if _shape != null:
		var s := radius / 20.0
		_shape.radius = radius
		($Shape as Node2D).scale = Vector2.ONE * s
		for c: Line2D in $Shape.get_children():
			c.width = 6 * (1 / s)

func _update_color() -> void:
	modulate = color

func _update_mask() -> void:
	if by_player:
		collision_layer |= Config.LAYER_PLAYER_PROJECTILE
		collision_layer &= ~Config.LAYER_ENEMY_PROJECTILE
		collision_mask &= ~Config.LAYER_PLAYER
		collision_mask &= ~Config.LAYER_PLAYER_SHIELD
		collision_mask |= Config.LAYER_ENEMY
	else:
		collision_layer &= ~Config.LAYER_PLAYER_PROJECTILE
		collision_layer |= Config.LAYER_ENEMY_PROJECTILE
		collision_mask |= Config.LAYER_PLAYER
		collision_mask |= Config.LAYER_PLAYER_SHIELD
		collision_mask &= ~Config.LAYER_ENEMY
