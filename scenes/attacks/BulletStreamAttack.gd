extends BaseAttack
class_name BulletStreamAttack

@export var start_position: Vector2
@export var direction: Vector2 = Vector2.RIGHT
@export var stream_width: float = 20.0
@export var bullet_speed: float = 300.0
@export var bullet_spacing: float = 50.0
@export var warning_icon_texture: Texture2D  # Optional custom warning icon

const bullet_scene = preload("res://scenes/projectiles/Bullet.tscn")

var warning_line: Line2D
var warning_icon: Sprite2D
var bullets: Array[RigidBody2D] = []

func _ready():
	direction = direction.normalized()
	
	# Set default start position if not specified
	if start_position == Vector2.ZERO:
		var bounds = get_camera_bounds()
		start_position = Vector2(bounds.position.x - 50, bounds.position.y + bounds.size.y / 2)
	
	super._ready()

func get_camera_bounds() -> Rect2:
	var camera = get_viewport().get_camera_2d()

	var viewport_size = get_viewport().get_visible_rect().size
	var zoom = camera.zoom
	
	# Calculate the actual visible area in world coordinates
	var visible_size = viewport_size / zoom
	var top_left = camera.global_position - visible_size * 0.5
	
	return Rect2(top_left, visible_size)
	
	

func show_warning():
	# Create warning line
	warning_line = Line2D.new()
	warning_line.width = stream_width
	warning_line.default_color = Color(1, 0, 0, 0.5)
	add_child(warning_line)

	var bounds = get_camera_bounds()
	# Calculate end position that extends beyond the visible area
	var travel_distance = bounds.size.length() + 100  # Add some buffer
	var end_position = start_position + direction * travel_distance

	warning_line.add_point(start_position)
	warning_line.add_point(end_position)

	# Animate warning line (pulsing)
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(warning_line, "default_color:a", 0.2, 0.3)
	tween.tween_property(warning_line, "default_color:a", 0.7, 0.3)

	# Create warning icon
	if warning_icon_texture:
		warning_icon = Sprite2D.new()
		warning_icon.texture = warning_icon_texture
		warning_icon.position = start_position
		add_child(warning_icon)

		# Animate icon (pulse alpha + scale)
		var icon_tween = create_tween()
		icon_tween.set_loops()

		# Pulse alpha
		icon_tween.tween_property(warning_icon, "modulate:a", 0.2, 0.4)
		icon_tween.tween_property(warning_icon, "modulate:a", 0.9, 0.4)

		# Pulse scale
		icon_tween.parallel().tween_property(warning_icon, "scale", Vector2(2.2, 2.2), 0.4)
		icon_tween.parallel().tween_property(warning_icon, "scale", Vector2(1.8, 1.8), 0.4)

func hide_warning():
	if warning_line:
		warning_line.queue_free()
	if warning_icon:
		warning_icon.queue_free()

func execute_attack():
	spawn_bullets()

func spawn_bullets():
	var bounds = get_camera_bounds()
	# Use diagonal length of camera bounds plus buffer for total travel distance
	var travel_distance = bounds.size.length() + 200
	var bullet_count = int(travel_distance / bullet_spacing)

	# Start bullets off-screen, heading toward start_position
	var spawn_origin = start_position - direction * travel_distance * 0.5

	for i in range(bullet_count):
		var bullet = bullet_scene.instantiate()
		get_parent().add_child(bullet)

		bullet.global_position = spawn_origin + direction * (i * bullet_spacing)
		bullet.rotation = direction.angle()
		bullet.set_velocity(direction * bullet_speed)
		bullet.linear_velocity = direction * bullet_speed
		bullets.append(bullet)

		await get_tree().create_timer(0.05).timeout

func cleanup():
	get_tree().create_timer(5.0).timeout.connect(_cleanup_bullets)
	super.cleanup()

func _cleanup_bullets():
	for bullet in bullets:
		if is_instance_valid(bullet):
			bullet.queue_free()
