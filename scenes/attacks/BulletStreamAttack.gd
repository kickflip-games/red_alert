# BulletStreamAttack.gd
extends BaseAttack
class_name BulletStreamAttack

@export var start_position: Vector2
@export var direction: Vector2 = Vector2.RIGHT
@export var stream_width: float = 20.0
@export var bullet_speed: float = 300.0
@export var bullet_spacing: float = 50.0
@export var bullet_scene: PackedScene

var warning_line: Line2D
var bullets: Array[RigidBody2D] = []

func _ready():
	# Set default values if not set
	if start_position == Vector2.ZERO:
		start_position = Vector2(-50, get_viewport().get_visible_rect().size.y / 2)
	
	direction = direction.normalized()
	
	# Load bullet scene if not assigned
	if not bullet_scene:
		bullet_scene = preload("res://scenes/Bullet.tscn")  # You'll need to create this
	
	super._ready()

func show_warning():
	# Create warning line
	warning_line = Line2D.new()
	add_child(warning_line)
	
	warning_line.width = stream_width
	warning_line.default_color = warning_color
	warning_line.default_color.a = 0.5  # Semi-transparent
	
	# Calculate line endpoints
	var screen_size = get_viewport().get_visible_rect().size
	var end_position = start_position + direction * (screen_size.x + screen_size.y)  # Long enough to cross screen
	
	warning_line.add_point(start_position)
	warning_line.add_point(end_position)
	
	# Animate the warning (pulsing effect)
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(warning_line, "default_color:a", 0.2, 0.3)
	tween.tween_property(warning_line, "default_color:a", 0.7, 0.3)

func hide_warning():
	if warning_line:
		warning_line.queue_free()

func execute_attack():
	spawn_bullets()

func spawn_bullets():
	var screen_size = get_viewport().get_visible_rect().size
	var total_distance = screen_size.x + screen_size.y
	var bullet_count = int(total_distance / bullet_spacing)
	
	for i in range(bullet_count):
		var bullet = bullet_scene.instantiate()
		get_parent().add_child(bullet)  # Add to parent so it's not deleted with attack
		
		# Position bullet
		bullet.global_position = start_position + direction * (i * bullet_spacing)
		
		# Set bullet velocity
		if bullet.has_method("set_velocity"):
			bullet.set_velocity(direction * bullet_speed)
		elif bullet is RigidBody2D:
			bullet.linear_velocity = direction * bullet_speed
		
		bullets.append(bullet)
		
		# Slight delay between bullet spawns for visual effect
		await get_tree().create_timer(0.05).timeout

func cleanup():
	# Clean up any remaining bullets after a delay
	get_tree().create_timer(5.0).timeout.connect(_cleanup_bullets)
	super.cleanup()

func _cleanup_bullets():
	for bullet in bullets:
		if is_instance_valid(bullet):
			bullet.queue_free()

# Helper functions for collision detection
func is_point_in_warning_area(point: Vector2) -> bool:
	if not is_warning_phase or not warning_line:
		return false
	
	# Check if point is within stream width of the line
	var closest_point = _get_closest_point_on_line(start_position, start_position + direction * 2000, point)
	return point.distance_to(closest_point) <= stream_width / 2

func is_point_in_attack_area(point: Vector2) -> bool:
	if not is_active:
		return false
	
	# Check if any bullet is near this point
	for bullet in bullets:
		if is_instance_valid(bullet) and bullet.global_position.distance_to(point) <= 20:  # Bullet radius
			return true
	return false

func _get_closest_point_on_line(line_start: Vector2, line_end: Vector2, point: Vector2) -> Vector2:
	var line_vec = line_end - line_start
	var point_vec = point - line_start
	var line_len = line_vec.length_squared()
	
	if line_len == 0:
		return line_start
	
	var t = point_vec.dot(line_vec) / line_len
	t = clamp(t, 0.0, 1.0)
	
	return line_start + t * line_vec
