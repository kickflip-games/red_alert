# HomingMissile.gd
extends CharacterBody2D

# Base stats with more randomness - much slower!
@export var base_speed: float = 120.0  # Much slower base speed
@export var base_turn_speed: float = 1.8  # Slower turning
@export var base_acceleration: float = 30.0  # Slower acceleration

# Randomization ranges (applied on spawn) - toned down
@export var speed_variation: float = 0.2  # ±20% speed variation
@export var turn_speed_variation: float = 0.3  # ±30% turn speed variation
@export var acceleration_variation: float = 0.2  # ±20% acceleration variation

# Actual stats (randomized on spawn)
var speed: float
var turn_speed: float
var acceleration: float

# Behavioral settings
@export var prediction_time: float = 0.8  # Even less prediction
@export var prediction_accuracy: float = 0.4  # Poor prediction accuracy
@export var separation_radius: float = 80.0  # Larger separation (more spacing)
@export var separation_strength: float = 150.0  # Stronger separation force
@export var fuel_time: float = 12.0  # Shorter lifespan

# Aggression phases - much gentler
@export var initial_boost_time: float = 1.0  # Shorter boost
@export var initial_boost_multiplier: float = 1.1  # Barely faster
@export var close_range_threshold: float = 100.0  # Very close before aggressive
@export var aggressive_speed_multiplier: float = 1.05  # Tiny speed boost
@export var aggressive_turn_multiplier: float = 1.2  # Moderate turn boost

# Advanced behavior
@export var evasion_detection_radius: float = 80.0  # Smaller evasion range
@export var spiral_intensity: float = 0.3  # Much gentler spirals
@export var intercept_ahead_distance: float = 100.0  # Less aggressive intercept

# Collision settings
@export var missile_collision_enabled: bool = true  # Enable missile-missile collisions
@export var collision_detection_radius: float = 25.0  # How close before collision
@export var collision_avoidance_strength: float = 0.3  # How much they try to avoid each other (0.0 = no avoidance, 1.0 = strong avoidance)

# Dynamic noise settings
@export var base_course_noise: float = 0.2
@export var base_speed_noise: float = 0.1
@export var base_turn_noise: float = 0.2
@export var noise_frequency: float = 3.0

# Trail settings
@export var trail_length: int = 20
@export var trail_width: float = 6.0
@export var trail_color_start: Color = Color.ORANGE
@export var trail_color_end: Color = Color(1.0, 0.3, 0.0, 0.0)

var target: Node2D
var current_speed: float = 0.0
var trail_points: Array = []
var fuel_remaining: float
var spawn_time: float = 0.0
var phase: String = "initial"  # "initial", "hunting", "aggressive", "desperate"

# Enhanced noise variables
var noise_timer: float = 0.0
var course_noise: Vector2 = Vector2.ZERO
var speed_multiplier: float = 1.0
var turn_multiplier: float = 1.0
var unique_seed: int

# Intercept behavior
var intercept_angle: float = 0.0
var intercept_side: int = 1  # 1 or -1 for left/right intercept

# Other missiles for separation
var other_missiles: Array = []

@onready var trail := $Trail

func _ready():
	target = get_tree().get_first_node_in_group("player")
	fuel_remaining = fuel_time
	unique_seed = randi()
	
	# Randomize stats on spawn
	randomize_stats()
	
	# Set initial intercept behavior
	setup_intercept_behavior()
	
	if not target:
		push_error("Warning: No player found in 'player' group")
		queue_free()
		return
	
	# Start with initial boost phase
	phase = "initial"
	update_missile_list()

func randomize_stats():
	# Apply random variations to base stats
	speed = base_speed * randf_range(1.0 - speed_variation, 1.0 + speed_variation)
	turn_speed = base_turn_speed * randf_range(1.0 - turn_speed_variation, 1.0 + turn_speed_variation)
	acceleration = base_acceleration * randf_range(1.0 - acceleration_variation, 1.0 + acceleration_variation)
	
	# Randomize noise levels too
	var noise_variation = randf_range(0.5, 1.5)
	base_course_noise *= noise_variation
	base_speed_noise *= noise_variation
	base_turn_noise *= noise_variation

func setup_intercept_behavior():
	# Randomly choose which side to approach from and intercept angle
	intercept_side = 1 if randf() > 0.5 else -1
	intercept_angle = randf_range(PI * 0.3, PI * 0.7)  # 30-70 degree intercept angles

func _physics_process(delta):
	if not target or fuel_remaining <= 0:
		self_destruct()
		return
	
	spawn_time += delta
	fuel_remaining -= delta
	noise_timer += delta
	
	# Check for missile collisions
	if missile_collision_enabled:
		check_missile_collisions()
	
	# Update phase based on conditions
	update_phase()
	
	# Update noise periodically
	if noise_timer >= 1.0 / noise_frequency:
		update_noise_values()
		noise_timer = 0.0
	
	# Update missile list occasionally
	if randf() < 0.05:  # 5% chance per frame
		update_missile_list()
	
	# Get target position based on current phase
	var target_position = get_phase_target_position()
	
	# Calculate movement
	var direction_to_target = (target_position - global_position).normalized()
	var separation_force = get_separation_force()
	var collision_avoidance_force = get_collision_avoidance_force()
	var phase_modifier = get_phase_behavior_modifier()
	
	# Combine forces
	var final_direction = (direction_to_target + separation_force + collision_avoidance_force + phase_modifier).normalized()
	
	# Apply phase-specific turn speed
	var current_turn_speed = turn_speed * turn_multiplier * get_phase_turn_multiplier()
	
	# Rotate towards target
	var target_rotation = final_direction.angle()
	rotation = lerp_angle(rotation, target_rotation, current_turn_speed * delta)
	
	# Apply phase-specific speed and acceleration
	var target_speed = speed * speed_multiplier * get_phase_speed_multiplier()
	var current_acceleration = acceleration * get_phase_acceleration_multiplier()
	
	current_speed = move_toward(current_speed, target_speed, current_acceleration * delta)
	
	# Move
	velocity = Vector2.RIGHT.rotated(rotation) * current_speed
	move_and_slide()
	
	update_trail()

func update_phase():
	var distance_to_target = global_position.distance_to(target.global_position)
	
	match phase:
		"initial":
			if spawn_time > initial_boost_time:
				phase = "hunting"
		"hunting":
			if distance_to_target < close_range_threshold:
				phase = "aggressive"
			elif fuel_remaining < fuel_time * 0.4:  # Less than 40% fuel (more time before desperate)
				phase = "desperate"
		"aggressive":
			if distance_to_target > close_range_threshold * 2.0:  # Easier to escape aggressive mode
				phase = "hunting"
			elif fuel_remaining < fuel_time * 0.3:  # Less than 30% fuel
				phase = "desperate"
		"desperate":
			# Stay desperate until death
			pass

func get_phase_target_position() -> Vector2:
	if not target:
		return global_position
	
	match phase:
		"initial":
			return get_intercept_position()
		"hunting":
			return get_predicted_target_position()
		"aggressive":
			return get_aggressive_target_position()
		"desperate":
			return get_desperate_target_position()
		_:
			return target.global_position

func get_intercept_position() -> Vector2:
	# Much less aggressive intercept - mostly just head toward player
	var player_velocity = get_target_velocity()
	var to_player = target.global_position - global_position
	
	if player_velocity.length() < 20.0:  # Player is mostly stationary
		# Just go toward player with slight offset
		var small_offset = to_player.orthogonal().normalized() * intercept_side * 50.0
		return target.global_position + small_offset
	else:
		# Very mild intercept - mostly chase behavior
		var mild_prediction = target.global_position + player_velocity * 0.3
		return mild_prediction

func get_predicted_target_position() -> Vector2:
	if not target:
		return Vector2.ZERO
	
	var target_velocity = get_target_velocity()
	var distance_to_target = global_position.distance_to(target.global_position)
	var time_to_intercept = distance_to_target / max(current_speed, 1.0)
	
	var prediction_distance = min(time_to_intercept, prediction_time)
	var predicted_position = target.global_position + (target_velocity * prediction_distance * prediction_accuracy)
	
	return predicted_position

func get_aggressive_target_position() -> Vector2:
	# In aggressive mode, aim slightly ahead and add spiral movement
	var base_target = get_predicted_target_position()
	var spiral_offset = Vector2.UP.rotated(rotation + PI/2) * sin(spawn_time * 4.0) * spiral_intensity * 30.0
	return base_target + spiral_offset

func get_desperate_target_position() -> Vector2:
	# Desperate mode: go directly for the player with maximum aggression
	return target.global_position

func get_target_velocity() -> Vector2:
	if not target:
		return Vector2.ZERO
	
	if "velocity" in target:
		return target.velocity
	elif target.has_method("get_velocity"):
		return target.get_velocity()
	return Vector2.ZERO

func get_phase_speed_multiplier() -> float:
	match phase:
		"initial": return initial_boost_multiplier
		"hunting": return 0.9  # Actually slower during hunting
		"aggressive": return aggressive_speed_multiplier
		"desperate": return 1.1  # Only slight speed boost when desperate
		_: return 0.9

func get_phase_turn_multiplier() -> float:
	match phase:
		"initial": return 1.0  # Normal turning
		"hunting": return 0.8  # Slower turning during hunt
		"aggressive": return aggressive_turn_multiplier
		"desperate": return 1.3  # Decent turning when desperate
		_: return 0.8

func get_phase_acceleration_multiplier() -> float:
	match phase:
		"initial": return 1.1  # Slight acceleration boost
		"hunting": return 0.8  # Slower acceleration
		"aggressive": return 1.0  # Normal acceleration
		"desperate": return 1.2  # Moderate acceleration
		_: return 0.8

func get_phase_behavior_modifier() -> Vector2:
	match phase:
		"initial":
			# Less randomness to initial approach
			return Vector2.from_angle(randf() * TAU) * 0.05
		"hunting":
			# Standard hunting with mild course correction
			return course_noise * 0.3
		"aggressive":
			# Gentler spiral and weave behavior
			var spiral = Vector2.UP.rotated(rotation + PI/2) * sin(spawn_time * 3.0) * spiral_intensity * 0.5
			return spiral + course_noise * 0.7
		"desperate":
			# Less erratic movement
			var erratic = Vector2.from_angle(randf() * TAU) * 0.15
			return erratic + course_noise * 1.2
		_:
			return Vector2.ZERO

func get_separation_force() -> Vector2:
	var separation = Vector2.ZERO
	var nearby_count = 0
	
	for missile in other_missiles:
		if not is_instance_valid(missile) or missile == self:
			continue
			
		var distance = global_position.distance_to(missile.global_position)
		if distance < separation_radius and distance > 0:
			var away_direction = (global_position - missile.global_position).normalized()
			var strength = (separation_radius - distance) / separation_radius
			separation += away_direction * strength
			nearby_count += 1
	
	if nearby_count > 0:
		separation = separation.normalized() * (separation_strength / 100.0)
		# Reduce separation in desperate phase (more willing to clump)
		if phase == "desperate":
			separation *= 0.5
	
	return separation

func update_missile_list():
	other_missiles.clear()
	var missiles = get_tree().get_nodes_in_group("missiles")
	for missile in missiles:
		if missile != self and is_instance_valid(missile):
			other_missiles.append(missile)

func update_noise_values():
	# Enhanced noise with phase-specific intensity
	var noise_intensity = get_phase_noise_intensity()
	
	var time_factor = spawn_time * noise_frequency
	var seeded_random = sin(unique_seed + time_factor)
	
	# Course noise
	var course_angle = seeded_random * TAU
	var course_magnitude = abs(sin(unique_seed * 2 + time_factor * 1.3))
	course_noise = Vector2.from_angle(course_angle) * course_magnitude * base_course_noise * noise_intensity
	
	# Speed noise
	speed_multiplier = 1.0 + sin(unique_seed * 3 + time_factor * 0.8) * base_speed_noise * noise_intensity
	speed_multiplier = clamp(speed_multiplier, 0.6, 1.6)
	
	# Turn rate noise
	turn_multiplier = 1.0 + sin(unique_seed * 5 + time_factor * 1.1) * base_turn_noise * noise_intensity
	turn_multiplier = clamp(turn_multiplier, 0.5, 2.0)

func get_phase_noise_intensity() -> float:
	match phase:
		"initial": return 0.6  # Less noise
		"hunting": return 0.8   # Reduced noise
		"aggressive": return 1.0  # Normal noise
		"desperate": return 1.3   # Less erratic
		_: return 0.8

func check_missile_collisions():
	for missile in other_missiles:
		if not is_instance_valid(missile):
			continue
			
		var distance = global_position.distance_to(missile.global_position)
		if distance < collision_detection_radius:
			# BOOM! Both missiles explode
			print("Missile collision! Both missiles destroyed")
			missile.destroy_from_collision()
			destroy_from_collision()
			return  # Exit early since we're about to be destroyed

func get_collision_avoidance_force() -> Vector2:
	if not missile_collision_enabled or collision_avoidance_strength <= 0.0:
		return Vector2.ZERO
	
	var avoidance = Vector2.ZERO
	var collision_threats = 0
	
	# Check for imminent collisions and try to avoid them (but not too hard!)
	for missile in other_missiles:
		if not is_instance_valid(missile):
			continue
			
		var distance = global_position.distance_to(missile.global_position)
		var collision_buffer = collision_detection_radius * 2.0  # Start avoiding at 2x collision distance
		
		if distance < collision_buffer and distance > 0:
			# Calculate if we're on a collision course
			var to_missile = missile.global_position - global_position
			var our_velocity_normalized = velocity.normalized()
			var their_velocity_normalized = Vector2.ZERO
			
			if "velocity" in missile:
				their_velocity_normalized = missile.velocity.normalized()
			
			# Check if we're heading towards each other
			var heading_towards = our_velocity_normalized.dot(to_missile.normalized()) > 0.3
			var they_heading_towards = their_velocity_normalized.dot(-to_missile.normalized()) > 0.3
			
			if heading_towards and they_heading_towards:
				# We're on a collision course, try to avoid
				var away_direction = (global_position - missile.global_position).normalized()
				var avoidance_strength = (collision_buffer - distance) / collision_buffer
				avoidance += away_direction * avoidance_strength
				collision_threats += 1
	
	if collision_threats > 0:
		avoidance = avoidance.normalized() * collision_avoidance_strength
		# Reduce avoidance in desperate phase (more willing to crash)
		if phase == "desperate":
			avoidance *= 0.3
	
	return avoidance

func destroy_from_collision():
	print("Missile destroyed by collision with another missile!")
	# Add explosion effect here if desired
	destroy()

func destroy():
	queue_free()

func update_trail():
	trail_points.append(global_position)
	
	if trail_points.size() > trail_length:
		trail_points.pop_front()
	
	if trail:
		trail.visible = true
		trail.clear_points()
		
		for point in trail_points:
			trail.add_point(to_local(point))

func self_destruct():
	print("Missile fuel depleted - self destructing")
	destroy()

func _on_area_2d_body_entered(body):
	if body.is_in_group("player"):
		print("Player hit by missile!")
		# Add explosion/damage logic here
		destroy()

func _enter_tree():
	add_to_group("missiles")

func _exit_tree():
	remove_from_group("missiles")
