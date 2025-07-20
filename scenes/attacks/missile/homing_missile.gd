# HomingMissile.gd
# Attach this script to a CharacterBody2D node

extends CharacterBody2D

@export var speed: float = 200.0
@export var turn_speed: float = 3.0
@export var acceleration: float = 50.0

# Trail settings
@export var trail_length: int = 30
@export var trail_width: float = 8.0
@export var trail_color_start: Color = Color.ORANGE
@export var trail_color_end: Color = Color(1.0, 0.3, 0.0, 0.0)  # Transparent orange

var target: Node2D
var current_speed: float = 0.0
var trail_points: Array = []
@onready var trail := $Trail

func _ready():
	# Find the player node
	target = get_tree().get_first_node_in_group("player")
	if not target:
		print("Warning: No player found in 'player' group")
	

func _physics_process(delta):
	if not target:
		return
	
	# Calculate direction to target
	var direction_to_target = (target.global_position - global_position).normalized()
	
	# Smoothly rotate towards target
	var target_rotation = direction_to_target.angle()
	rotation = lerp_angle(rotation, target_rotation, turn_speed * delta)
	
	# Accelerate towards max speed
	current_speed = min(current_speed + acceleration * delta, speed)
	
	# Move in the direction we're facing
	velocity = Vector2.RIGHT.rotated(rotation) * current_speed
	move_and_slide()
	
	# Update trail
	update_trail()

func update_trail():
	# Add current global position to trail points array
	trail_points.append(global_position)
	
	# Limit trail length
	if trail_points.size() > trail_length:
		trail_points.pop_front()
	
	# Clear and rebuild the trail
	trail.visible = true
	trail.clear_points()
	
	# Add all points, converting global positions to local coordinates
	for point in trail_points:
		trail.add_point(to_local(point))

func destroy():
	queue_free()

func _on_area_2d_body_entered(body):
	# If this hits the player or other objects, destroy the missile
	if body.is_in_group("player"):
		# Handle player damage here
		print("Player hit by missile!")
		destroy()
