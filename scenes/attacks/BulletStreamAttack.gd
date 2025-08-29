extends BaseAttack
class_name BulletStreamAttack

var direction: Vector2
@export var stream_width: float = 20.0 
@export var speed: float = 300.0
@export var bullet_spacing: float = 50.0
@export var fire_rate: float = 0.1
@export var bullet_count: int = 10  

# Path movement variables
@export var path_follow: PathFollow2D
@export var path_speed: float = 100.0
@export var path_loop: bool = false
@export var rotate_with_path: bool = true
@export var smooth_rotation: bool = false
@export var rotation_speed: float = 5.0

const BULLET_SCENE = preload("res://scenes/projectiles/Bullet.tscn")

var _spawn_timer: float = 0.0
var _current_bullet_spacing_offset: float = 0.0
var _active_bullets: Array[Node] = []
var _bullets_spawned: int = 0  

# Path following variables
var _is_following_path: bool = false
var _initial_position: Vector2
var _initial_direction: Vector2
var _path: Path2D

func _ready():
	super._ready()
	_initial_direction = global_transform.x.normalized()
	direction = _initial_direction
	$warning_graphics/Line.width = stream_width
	_initial_position = global_position
	
	if path_follow:
		_setup_path_following()

func _process(delta):
	# Handle path movement
	if _is_following_path:
		_update_path_movement(delta)
	
	if _bullets_spawned >= bullet_count:
		if not _completed:		
			attack_completed.emit(self)
			_completed = true
		return  # Stop firing if limit reached

	_spawn_timer += delta
	if _spawn_timer >= fire_rate:
		spawn_bullet()
		_spawn_timer = 0.0

func execute_attack():
	super.execute_attack()
	_spawn_timer = 0.0
	_current_bullet_spacing_offset = 0.0
	_bullets_spawned = 0

func _setup_path_following():
	_is_following_path = true
	_path = path_follow.get_parent() as Path2D
	
	# Find the closest point on the path to our current position
	var closest_offset = _path.curve.get_closest_offset(_path.to_local(global_position))
	path_follow.progress = closest_offset
	path_follow.loop = path_loop

func _update_path_movement(delta):
	# Move along the path
	path_follow.progress += path_speed * delta
	
	# Update position
	global_position = path_follow.global_position
	
	# Handle rotation based on settings
	if rotate_with_path:
		# Get the path direction and combine it with the initial direction
		var path_direction = path_follow.transform.x.normalized()
		var initial_angle = _initial_direction.angle() + PI/2
		var path_angle = path_direction.angle()
		var target_angle = path_angle + initial_angle
		
		if smooth_rotation:
			# Smooth rotation interpolation
			var current_angle = direction.angle()
			var new_angle = lerp_angle(current_angle, target_angle, rotation_speed * delta)
			direction = Vector2.from_angle(new_angle)
			global_rotation = new_angle
		else:
			# Instant rotation
			direction = Vector2.from_angle(target_angle)
			global_rotation = target_angle
	
	# Stop following if we've reached the end and not looping
	if not path_loop and path_follow.progress_ratio >= 1.0:
		_is_following_path = false

func spawn_bullet():
	if not BULLET_SCENE or _bullets_spawned >= bullet_count:
		return

	SoundManager.play_sound_with_pitch(SHOOT_SFX, randf_range(0.5, 1.0))
	var bullet = BULLET_SCENE.instantiate()
	get_parent().add_child(bullet)

	var perp_direction = direction.orthogonal()
	var offset_from_center = fmod(_current_bullet_spacing_offset, stream_width) - (stream_width / 2.0)
	var spawn_pos_offset_from_origin = perp_direction * offset_from_center

	bullet.global_position = global_position + spawn_pos_offset_from_origin
	bullet.rotation = direction.angle()
	bullet.set_velocity(direction * speed)

	_active_bullets.append(bullet)
	_bullets_spawned += 1  
	_current_bullet_spacing_offset += bullet_spacing

	# Filter invalid bullets
	_active_bullets = _active_bullets.filter(func(b): return is_instance_valid(b))

func _immediate_cleanup():
	_cleanup_bullets(0)
	super._immediate_cleanup()

func cleanup():
	_cleanup_bullets(20)
	super.cleanup()

func _cleanup_bullets(cleanup_after: float = 20):
	await get_tree().create_timer(cleanup_after).timeout
	for bullet in _active_bullets:
		if is_instance_valid(bullet):
			bullet.queue_free()
	_active_bullets.clear()
