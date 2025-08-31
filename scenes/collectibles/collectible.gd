class_name Collectible
extends RigidBody2D

signal collected(letter, points)

@export var points_value: int = 10
@export var initial_speed: float = 250.0
@export var bounce_damping: float = 0.8
@export var evasion_force: float = 400.0
@export var evasion_distance: float = 120.0
@export var min_speed: float = 50.0  # Minimum speed to maintain
@export var max_speed: float = 400.0  # Maximum speed limit

@onready var visuals: Node2D = $Visuals
@onready var sprite: Sprite2D = $Visuals/Sprite2D
@onready var label: Label = $Visuals/Label

var letter_char: String = ""
var screen_size: Vector2
var idle_tween: Tween
var spawn_tween: Tween
var player_reference: Node2D

func _ready():
	# Get screen boundaries and player reference
	screen_size = get_viewport().get_visible_rect().size
	player_reference = get_tree().get_first_node_in_group("player")
	
	# Set up physics for natural movement
	gravity_scale = 0
	linear_damp = 0.1  # Very low damping for natural coasting
	angular_damp = 3.0
	
	# Debug: Check if we have required collision shape
	var collision_shape = get_node("CollisionShape2D")
	if not collision_shape:
		print("WARNING: Collectible missing CollisionShape2D!")
	
	# Start invisible for spawn animation
	visuals.modulate = Color.TRANSPARENT
	visuals.scale = Vector2.ZERO
	
	# Start spawn animation
	play_spawn_animation()

func setup_letter(letter: String):
	letter_char = letter.to_upper()
	$Visuals/Label.text = letter_char

func play_spawn_animation():
	spawn_tween = create_tween()
	spawn_tween.set_parallel(true)
	
	# Scale in effect
	spawn_tween.tween_property(visuals, "scale", Vector2(1.2, 1.2), 0.3)
	spawn_tween.tween_property(visuals, "scale", Vector2(1.0, 1.0), 0.2).set_delay(0.3)
	
	# Fade in effect
	spawn_tween.tween_property(visuals, "modulate", Color.WHITE, 0.4)
	
	# Start physics movement and animations after spawn completes
	spawn_tween.tween_callback(start_physics_and_animations).set_delay(0.5)

func start_physics_and_animations():
	# Give initial random velocity kick
	var random_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	linear_velocity = random_direction * initial_speed
	print("Initial velocity kick: ", linear_velocity)
	
	# Start idle animation
	start_idle_animation()

func start_idle_animation():
	if idle_tween:
		idle_tween.kill()
	
	# Create separate continuous tweens for each animation
	create_rotation_animation()
	create_scale_animation()
	create_color_animation()

func create_rotation_animation():
	var rotation_tween = create_tween()
	rotation_tween.set_loops()
	rotation_tween.tween_property(visuals, "rotation", deg_to_rad(10), 0.8).set_trans(Tween.TRANS_SINE)
	rotation_tween.tween_property(visuals, "rotation", deg_to_rad(-10), 1.6).set_trans(Tween.TRANS_SINE)
	rotation_tween.tween_property(visuals, "rotation", deg_to_rad(10), 0.8).set_trans(Tween.TRANS_SINE)

func create_scale_animation():
	var scale_tween = create_tween()
	scale_tween.set_loops()
	scale_tween.tween_property(visuals, "scale", Vector2(1.1, 0.9), 1.2).set_trans(Tween.TRANS_SINE)
	scale_tween.tween_property(visuals, "scale", Vector2(0.9, 1.1), 1.2).set_trans(Tween.TRANS_SINE)
	scale_tween.tween_property(visuals, "scale", Vector2(1.1, 0.9), 1.2).set_trans(Tween.TRANS_SINE)

func create_color_animation():
	var color_tween = create_tween()
	color_tween.set_loops()
	color_tween.tween_property(visuals, "modulate", Color(1.2, 1.2, 1.2, 1.0), 1.5).set_trans(Tween.TRANS_SINE)
	color_tween.tween_property(visuals, "modulate", Color(0.9, 0.9, 0.9, 1.0), 1.5).set_trans(Tween.TRANS_SINE)
	color_tween.tween_property(visuals, "modulate", Color(1.2, 1.2, 1.2, 1.0), 1.5).set_trans(Tween.TRANS_SINE)

func _physics_process(delta):
	# Check for player proximity and apply evasion forces
	if player_reference:
		var distance_to_player = global_position.distance_to(player_reference.global_position)
		if distance_to_player < evasion_distance:
			evade_player()
	
	# Maintain minimum speed (gentle boost if moving too slowly)
	if linear_velocity.length() < min_speed:
		var current_direction = linear_velocity.normalized()
		if current_direction == Vector2.ZERO:
			# If completely stopped, pick random direction
			current_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		
		apply_central_impulse(current_direction * (min_speed * 2.0))
		print("Applying minimum speed boost")
	
	# Clamp velocity to maximum speed
	if linear_velocity.length() > max_speed:
		linear_velocity = linear_velocity.normalized() * max_speed

func evade_player():
	if not player_reference:
		return
	
	# Calculate direction away from player
	var evade_direction = (global_position - player_reference.global_position).normalized()
	
	# Apply evasion force (scaled by distance - closer = stronger force)
	var distance_to_player = global_position.distance_to(player_reference.global_position)
	var force_multiplier = 1.0 - (distance_to_player / evasion_distance)  # 1.0 when very close, 0.0 at max distance
	force_multiplier = clamp(force_multiplier, 0.0, 1.0)
	
	var actual_force = evasion_force * force_multiplier
	apply_central_impulse(evade_direction * actual_force)
	
	# Optional: Add slight randomness to make movement less predictable
	var random_offset = Vector2(randf_range(-0.3, 0.3), randf_range(-0.3, 0.3))
	apply_central_impulse(random_offset * actual_force * 0.5)

func _on_body_entered(body):
	# Handle wall bounces
	if body.is_in_group("walls"):
		# Apply bounce damping
		linear_velocity *= bounce_damping
		print("Bounced off wall, velocity after damping: ", linear_velocity)

func trigger_collection():
	# Stop all animations
	if idle_tween:
		idle_tween.kill()
	if spawn_tween:
		spawn_tween.kill()
	
	collected.emit(letter_char, points_value)
	create_collection_effect()

func create_collection_effect():
	# Create dramatic collection effect
	var collection_tween = create_tween()
	collection_tween.set_parallel(true)
	
	# Scale up and spin
	collection_tween.tween_property(visuals, "scale", Vector2(2.0, 2.0), 0.2)
	collection_tween.tween_property(visuals, "rotation", rotation + deg_to_rad(360), 0.2)
	
	# Bright flash then fade out
	collection_tween.tween_property(visuals, "modulate", Color(2.0, 2.0, 2.0, 1.0), 0.1)
	collection_tween.tween_property(visuals, "modulate", Color(2.0, 2.0, 2.0, 0.0), 0.1).set_delay(0.1)
	
	# Add some particles-like effect with label
	if label:
		var label_tween = create_tween()
		label_tween.set_parallel(true)
		label_tween.tween_property(label, "position", label.position + Vector2(0, -50), 0.3)
		label_tween.tween_property(label, "modulate", Color.TRANSPARENT, 0.3)
		label_tween.tween_property(label, "scale", Vector2(1.5, 1.5), 0.3)
	
	# Clean up after animation
	collection_tween.tween_callback(queue_free).set_delay(0.2)

func get_letter() -> String:
	return letter_char
