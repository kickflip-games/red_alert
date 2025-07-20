extends BaseAttack
class_name BulletStreamAttack

@export var start_position: Vector2
@export var direction: Vector2 = Vector2.RIGHT
@export var stream_width: float = 20.0
@export var bullet_speed: float = 300.0
@export var bullet_spacing: float = 50.0
@export var warning_icon_texture: Texture2D  # Optional custom warning icon
@export var debug_draw := true

const bullet_scene = preload("res://scenes/projectiles/Bullet.tscn")

var warning_line: Line2D
var warning_icon: Sprite2D
var bullets: Array[RigidBody2D] = []
var end_position: Vector2

func _ready():
	var bounds = CameraBounds.rect

	# Compute start and end positions based on direction
	if start_position == Vector2.ZERO:
		start_position = get_edge_spawn_point(bounds, direction, 50.0)

	end_position = get_edge_spawn_point(bounds, -direction, 50.0)
	direction = (end_position - start_position).normalized()

	super._ready()

func get_edge_spawn_point(bounds: Rect2, dir: Vector2, padding: float = 50.0) -> Vector2:
	var center = bounds.position + bounds.size * 0.5
	var half = bounds.size * 0.5
	var offset = dir.normalized() * (half + Vector2(padding, padding))
	return center + offset

func show_warning():
	# Create warning line
	warning_line = Line2D.new()
	warning_line.width = stream_width
	warning_line.default_color = Color(1, 0, 0, 0.2)
	add_child(warning_line)

	warning_line.add_point(start_position)
	warning_line.add_point(end_position)

	# Animate warning line (pulsing)
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(warning_line, "default_color:a", 0.05, 0.3)
	tween.tween_property(warning_line, "default_color:a", 0.2, 0.3)

	# Optional warning icon
	if warning_icon_texture:
		warning_icon = Sprite2D.new()
		warning_icon.scale = Vector2(5,5)
		warning_icon.texture = warning_icon_texture
		warning_icon.position = start_position + (direction * 70.0)  # pull it into screen
		add_child(warning_icon)

		# Animate icon
		var icon_tween = create_tween()
		icon_tween.set_loops()

		#icon_tween.tween_property(warning_icon, "modulate:a", 0.5, 0.4)
		#icon_tween.tween_property(warning_icon, "modulate:a", 0.9, 0.4)

		icon_tween.parallel().tween_property(warning_icon, "scale", Vector2(6.2, 6.2), 0.3)
		icon_tween.parallel().tween_property(warning_icon, "scale", Vector2(4.8, 4.8), 0.3)

func hide_warning():
	if warning_line:
		warning_line.queue_free()
	if warning_icon:
		warning_icon.queue_free()

func execute_attack():
	spawn_bullets()

func spawn_bullets():
	var total_distance = (end_position - start_position).length()
	var bullet_count = int(total_distance / bullet_spacing)

	for i in range(bullet_count):
		var bullet = bullet_scene.instantiate()
		get_parent().add_child(bullet)

		var pos = start_position + direction * (-i * bullet_spacing)
		bullet.global_position = pos
		bullet.rotation = direction.angle()
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

func _draw():
	if not debug_draw:
		return

	draw_circle(to_local(start_position), 6, Color.YELLOW)
	draw_circle(to_local(end_position), 6, Color.CYAN)

	var arrow_tip = to_local(start_position + direction * 30.0)
	draw_line(to_local(start_position), arrow_tip, Color.ORANGE, 2)
