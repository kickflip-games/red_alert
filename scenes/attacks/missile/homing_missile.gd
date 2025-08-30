# HomingMissile.gd
extends CharacterBody2D

# Base stats with more randomness - much slower!
@export var base_speed: float = 160.0  # Much slower base speed
@export var base_turn_speed: float = 2.0  # Slower turning
@export var base_acceleration: float = 35.0  # Slower acceleration

# Randomization ranges (applied on spawn) - toned down
@export var speed_variation: float = 0.4  # ±20% speed variation
@export var turn_speed_variation: float = 0.5  # ±30% turn speed variation
@export var acceleration_variation: float = 0.5  # ±20% acceleration variation

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

# NEW: Advanced movement patterns
@export var circle_radius: float = 200.0  # Radius for circling behavior
@export var flank_distance: float = 300.0  # How far to flank around the player
@export var orbit_speed: float = 2.0  # Speed of orbital movement
@export var movement_pattern_change_chance: float = 0.02  # Per frame chance to switch patterns

# Collision settings
@export var missile_collision_enabled: bool = true  # Enable missile-missile collisions
@export var collision_detection_radius: float = 25.0  # How close before collision
@export var collision_avoidance_strength: float = 0.3  # How much they try to avoid each other

# NEW: Explosion force settings
@export var explosion_force_radius: float = 120.0  # How far explosion affects other missiles
@export var explosion_force_strength: float = 300.0  # How strong the explosion push is
@export var explosion_stun_duration: float = 0.5  # How long missiles are stunned by explosions

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

const EXPLOSION_SFX = preload("res://assets/audio/sfx/explosion-sound.ogg")
const THRUSTER_SFX = preload("res://assets/audio/sfx/missile-thruster-sound.ogg")
const EXPLOSION_FX = preload("res://scenes/attacks/missile/missile_explosion_fx.tscn")

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

# NEW: Movement pattern system
var movement_pattern: String = "direct"  # "direct", "circle", "flank_left", "flank_right", "spiral_in", "weave"
var pattern_timer: float = 0.0
var circle_center: Vector2
var circle_angle: float = 0.0
var flank_target_position: Vector2
var pattern_switch_timer: float = 0.0

# NEW: External forces and effects
var external_force: Vector2 = Vector2.ZERO
var external_force_decay: float = 5.0  # How fast external forces fade
var is_stunned: bool = false
var stun_timer: float = 0.0

# Other missiles for separation (cached for performance)
var other_missiles: Array = []
var missile_cache_timer: float = 0.0
const MISSILE_CACHE_INTERVAL: float = 0.1  # Update cache every 100ms

@onready var trail := $Trail

func _ready():
	target = get_tree().get_first_node_in_group("player")
	fuel_remaining = fuel_time
	unique_seed = randi()
	
	# Randomize stats on spawn
	randomize_stats()
	
	# Set initial intercept behavior
	setup_intercept_behavior()
	
	# NEW: Choose initial movement pattern
	choose_movement_pattern()
	
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

# NEW: Choose a movement pattern based on various factors
func choose_movement_pattern():
	var distance_to_target = global_position.distance_to(target.global_position) if target else 1000.0
	var pattern_weights = {}
	
	# Base weights for different patterns
	pattern_weights["direct"] = 30.0
	pattern_weights["circle"] = 20.0
	pattern_weights["flank_left"] = 15.0
	pattern_weights["flank_right"] = 15.0
	pattern_weights["spiral_in"] = 10.0
	pattern_weights["weave"] = 10.0
	
	# Modify weights based on distance and phase
	if distance_to_target > 400.0:
		# Far away - prefer circling and flanking
		pattern_weights["circle"] *= 2.0
		pattern_weights["flank_left"] *= 1.5
		pattern_weights["flank_right"] *= 1.5
		pattern_weights["direct"] *= 0.5
	elif distance_to_target < 150.0:
		# Close - prefer direct and spiral
		pattern_weights["direct"] *= 2.0
		pattern_weights["spiral_in"] *= 2.0
		pattern_weights["circle"] *= 0.3
	
	# Phase-based modifications
	match phase:
		"initial":
			pattern_weights["circle"] *= 1.5
			pattern_weights["weave"] *= 1.3
		"hunting":
			pattern_weights["flank_left"] *= 1.5
			pattern_weights["flank_right"] *= 1.5
		"aggressive":
			pattern_weights["direct"] *= 2.0
			pattern_weights["spiral_in"] *= 1.8
		"desperate":
			pattern_weights["direct"] *= 3.0
			pattern_weights["circle"] *= 0.2
	
	# Choose pattern based on weighted random selection
	var total_weight = 0.0
	for weight in pattern_weights.values():
		total_weight += weight
	
	var random_value = randf() * total_weight
	var current_weight = 0.0
	
	for pattern in pattern_weights:
		current_weight += pattern_weights[pattern]
		if random_value <= current_weight:
			movement_pattern = pattern
			break
	
	# Initialize pattern-specific data
	setup_pattern_data()

func setup_pattern_data():
	match movement_pattern:
		"circle":
			circle_center = target.global_position if target else global_position
			circle_angle = (global_position - circle_center).angle()
		"flank_left", "flank_right":
			setup_flank_target()
		"spiral_in":
			circle_center = target.global_position if target else global_position
			circle_angle = (global_position - circle_center).angle()
		"weave":
			pattern_timer = randf() * TAU  # Random starting phase for weave

func setup_flank_target():
	if not target:
		return
	
	var to_target = target.global_position - global_position
	var target_velocity = get_target_velocity()
	
	# Predict where target will be
	var predicted_target_pos = target.global_position + target_velocity * 2.0
	
	# Choose flanking side
	var flank_direction = to_target.orthogonal().normalized()
	if movement_pattern == "flank_right":
		flank_direction = -flank_direction
	
	# Set flanking position
	flank_target_position = predicted_target_pos + flank_direction * flank_distance

func update_phase():
	var distance_to_target = global_position.distance_to(target.global_position)
	
	match phase:
		"initial":
			if spawn_time > initial_boost_time:
				phase = "hunting"
		"hunting":
			if distance_to_target < close_range_threshold:
				phase = "aggressive"
			elif fuel_remaining < fuel_time * 0.4:  # Less than 40% fuel
				phase = "desperate"
		"aggressive":
			if distance_to_target > close_range_threshold * 2.0:  # Easier to escape aggressive mode
				phase = "hunting"
			elif fuel_remaining < fuel_time * 0.3:  # Less than 30% fuel
				phase = "desperate"
		"desperate":
			# Stay desperate until death
			pass

func _physics_process(delta):
	if not target or fuel_remaining <= 0:
		self_destruct()
		return
	
	spawn_time += delta
	fuel_remaining -= delta
	noise_timer += delta
	missile_cache_timer += delta
	pattern_timer += delta
	pattern_switch_timer += delta
	
	# Handle external forces and stun effects
	handle_external_effects(delta)
	
	# Skip normal AI if stunned
	if is_stunned:
		apply_external_forces_only(delta)
		update_trail()
		return
	
	# Occasionally consider switching movement patterns
	if pattern_switch_timer > 2.0 and randf() < movement_pattern_change_chance:
		choose_movement_pattern()
		pattern_switch_timer = 0.0
	
	# Check for missile collisions
	if missile_collision_enabled:
		check_missile_collisions()
	
	# Update phase based on conditions
	update_phase()
	
	# Update noise periodically
	if noise_timer >= 1.0 / noise_frequency:
		update_noise_values()
		noise_timer = 0.0
	
	# Update missile list occasionally for better performance
	if missile_cache_timer >= MISSILE_CACHE_INTERVAL:
		update_missile_list()
		missile_cache_timer = 0.0
	
	# Get target position based on current phase AND movement pattern
	var target_position = get_movement_pattern_target_position()
	
	# Calculate movement forces
	var direction_to_target = (target_position - global_position).normalized()
	var separation_force = get_separation_force()
	var collision_avoidance_force = get_collision_avoidance_force()
	var phase_modifier = get_phase_behavior_modifier()
	
	# Combine forces
	var ai_direction = (direction_to_target + separation_force + collision_avoidance_force + phase_modifier).normalized()
	
	# Apply phase-specific turn speed
	var current_turn_speed = turn_speed * turn_multiplier * get_phase_turn_multiplier()
	
	# Rotate towards target (reduced by external forces)
	var target_rotation = ai_direction.angle()
	var external_force_influence = external_force.length() / explosion_force_strength
	var effective_turn_speed = current_turn_speed * (1.0 - external_force_influence * 0.5)
	rotation = lerp_angle(rotation, target_rotation, effective_turn_speed * delta)
	
	# Apply phase-specific speed and acceleration
	var target_speed = speed * speed_multiplier * get_phase_speed_multiplier()
	var current_acceleration = acceleration * get_phase_acceleration_multiplier()
	
	current_speed = move_toward(current_speed, target_speed, current_acceleration * delta)
	
	# Combine AI velocity with external forces
	var ai_velocity = Vector2.RIGHT.rotated(rotation) * current_speed
	velocity = ai_velocity + external_force
	move_and_slide()
	
	update_trail()

func handle_external_effects(delta: float):
	# Handle stun timer
	if is_stunned:
		stun_timer -= delta
		if stun_timer <= 0.0:
			is_stunned = false
	
	# Decay external forces
	external_force = external_force.move_toward(Vector2.ZERO, external_force_decay * 100.0 * delta)

func apply_external_forces_only(delta: float):
	# When stunned, only external forces affect movement
	velocity = external_force
	move_and_slide()

# NEW: Apply explosion force from another missile
func apply_explosion_force(explosion_position: Vector2, force_strength: float = -1.0):
	if force_strength < 0:
		force_strength = explosion_force_strength
	
	var distance = global_position.distance_to(explosion_position)
	if distance > explosion_force_radius:
		return  # Too far away
	
	var direction_away = (global_position - explosion_position).normalized()
	var force_falloff = 1.0 - (distance / explosion_force_radius)  # Linear falloff
	force_falloff = force_falloff * force_falloff  # Square for more dramatic falloff
	
	var applied_force = direction_away * force_strength * force_falloff
	external_force += applied_force
	
	# Add some stun effect if the explosion is close enough
	if distance < explosion_force_radius * 0.6:
		is_stunned = true
		stun_timer = explosion_stun_duration * force_falloff

# NEW: Get target position based on movement pattern
func get_movement_pattern_target_position() -> Vector2:
	if not target:
		return global_position
	
	var base_target = get_phase_target_position()
	
	match movement_pattern:
		"direct":
			return base_target
		"circle":
			return get_circle_target_position()
		"flank_left", "flank_right":
			return get_flank_target_position()
		"spiral_in":
			return get_spiral_in_target_position()
		"weave":
			return get_weave_target_position()
		_:
			return base_target

func get_circle_target_position() -> Vector2:
	# Update circle center to follow target (slowly)
	if target:
		circle_center = circle_center.lerp(target.global_position, 0.02)
	
	# Determine orbit direction based on phase
	var orbit_direction = 1.0
	if phase == "desperate":
		orbit_direction = -1.0  # Reverse direction when desperate
	
	# Update circle angle
	circle_angle += orbit_speed * orbit_direction * get_process_delta_time()
	
	# Calculate target position on circle
	var circle_offset = Vector2.from_angle(circle_angle) * circle_radius
	var circle_target = circle_center + circle_offset
	
	# In aggressive/desperate phases, gradually spiral inward
	if phase == "aggressive":
		var spiral_factor = 0.99
		circle_radius *= spiral_factor
		circle_radius = max(circle_radius, 50.0)  # Don't spiral too close
	elif phase == "desperate":
		var spiral_factor = 0.98
		circle_radius *= spiral_factor
		circle_radius = max(circle_radius, 30.0)
	
	return circle_target

func get_flank_target_position() -> Vector2:
	# Update flank target occasionally
	if int(pattern_timer * 2.0) != int((pattern_timer - get_process_delta_time()) * 2.0):
		setup_flank_target()
	
	var distance_to_flank = global_position.distance_to(flank_target_position)
	
	# If we've reached the flanking position, switch to attack mode
	if distance_to_flank < 80.0:
		# Now attack from the flanking position
		return target.global_position
	else:
		# Still moving to flanking position
		return flank_target_position

func get_spiral_in_target_position() -> Vector2:
	# Similar to circle, but constantly spiraling inward
	if target:
		circle_center = circle_center.lerp(target.global_position, 0.03)
	
	circle_angle += orbit_speed * 1.5 * get_process_delta_time()
	
	# Constantly spiral inward
	var target_radius = 40.0  # Final spiral radius
	var spiral_speed = 30.0  # How fast to spiral in
	circle_radius = move_toward(circle_radius, target_radius, spiral_speed * get_process_delta_time())
	
	var spiral_offset = Vector2.from_angle(circle_angle) * circle_radius
	return circle_center + spiral_offset

func get_weave_target_position() -> Vector2:
	var base_target = get_phase_target_position()
	
	# Create weaving motion perpendicular to the direction toward target
	var to_target = (base_target - global_position).normalized()
	var perpendicular = to_target.orthogonal()
	
	# Weave pattern using sine waves
	var weave_intensity = 60.0
	var weave_frequency = 3.0
	var weave_offset = perpendicular * sin(pattern_timer * weave_frequency) * weave_intensity
	
	# Add some forward/backward weaving too
	var forward_weave = to_target * sin(pattern_timer * weave_frequency * 0.7) * 30.0
	
	return base_target + weave_offset + forward_weave

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
	var player_velocity = get_target_velocity()
	var to_player = target.global_position - global_position
	
	if player_velocity.length() < 20.0:
		var small_offset = to_player.orthogonal().normalized() * intercept_side * 50.0
		return target.global_position + small_offset
	else:
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
	var base_target = get_predicted_target_position()
	var spiral_offset = Vector2.UP.rotated(rotation + PI/2) * sin(spawn_time * 4.0) * spiral_intensity * 30.0
	return base_target + spiral_offset

func get_desperate_target_position() -> Vector2:
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
	var base_multiplier: float
	match phase:
		"initial": 
			base_multiplier = initial_boost_multiplier
		"hunting": 
			base_multiplier = 0.9
		"aggressive": 
			base_multiplier = aggressive_speed_multiplier
		"desperate": 
			base_multiplier = 1.1
		_: 
			base_multiplier = 0.9
	
	# Modify speed based on movement pattern
	match movement_pattern:
		"circle":
			return base_multiplier * 0.85  # Slower when circling
		"flank_left", "flank_right":
			return base_multiplier * 1.1   # Faster when flanking
		"spiral_in":
			return base_multiplier * 0.9   # Moderate speed for spiral
		"weave":
			return base_multiplier * 0.95  # Slightly slower for weaving
		_:
			return base_multiplier

func get_phase_turn_multiplier() -> float:
	var base_multiplier: float
	match phase:
		"initial": 
			base_multiplier = 1.0
		"hunting": 
			base_multiplier = 0.8
		"aggressive": 
			base_multiplier = aggressive_turn_multiplier
		"desperate": 
			base_multiplier = 1.3
		_: 
			base_multiplier = 0.8
	
	# Modify turn speed based on movement pattern
	match movement_pattern:
		"circle", "spiral_in":
			return base_multiplier * 1.3  # Need better turning for circular motion
		"weave":
			return base_multiplier * 1.5  # Much better turning for weaving
		"flank_left", "flank_right":
			return base_multiplier * 1.1  # Slightly better turning for flanking
		_:
			return base_multiplier

func get_phase_acceleration_multiplier() -> float:
	match phase:
		"initial": return 1.1
		"hunting": return 0.8
		"aggressive": return 1.0
		"desperate": return 1.2
		_: return 0.8

func get_phase_behavior_modifier() -> Vector2:
	match phase:
		"initial":
			return Vector2.from_angle(randf() * TAU) * 0.05
		"hunting":
			return course_noise * 0.3
		"aggressive":
			var spiral = Vector2.UP.rotated(rotation + PI/2) * sin(spawn_time * 3.0) * spiral_intensity * 0.5
			return spiral + course_noise * 0.7
		"desperate":
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
	var noise_intensity = get_phase_noise_intensity()
	
	var time_factor = spawn_time * noise_frequency
	var seeded_random = sin(unique_seed + time_factor)
	
	var course_angle = seeded_random * TAU
	var course_magnitude = abs(sin(unique_seed * 2 + time_factor * 1.3))
	course_noise = Vector2.from_angle(course_angle) * course_magnitude * base_course_noise * noise_intensity
	
	speed_multiplier = 1.0 + sin(unique_seed * 3 + time_factor * 0.8) * base_speed_noise * noise_intensity
	speed_multiplier = clamp(speed_multiplier, 0.6, 1.6)
	
	turn_multiplier = 1.0 + sin(unique_seed * 5 + time_factor * 1.1) * base_turn_noise * noise_intensity
	turn_multiplier = clamp(turn_multiplier, 0.5, 2.0)

func get_phase_noise_intensity() -> float:
	match phase:
		"initial": return 0.6
		"hunting": return 0.8
		"aggressive": return 1.0
		"desperate": return 1.3
		_: return 0.8

func check_missile_collisions():
	for missile in other_missiles:
		if not is_instance_valid(missile):
			continue
			
		var distance = global_position.distance_to(missile.global_position)
		if distance < collision_detection_radius:
			#print("Missile collision! Both missiles destroyed")
			missile.destroy_from_collision()
			destroy_from_collision()
			return

func get_collision_avoidance_force() -> Vector2:
	if not missile_collision_enabled or collision_avoidance_strength <= 0.0:
		return Vector2.ZERO
	
	var avoidance = Vector2.ZERO
	var collision_threats = 0
	
	for missile in other_missiles:
		if not is_instance_valid(missile):
			continue
			
		var distance = global_position.distance_to(missile.global_position)
		var collision_buffer = collision_detection_radius * 2.0
		
		if distance < collision_buffer and distance > 0:
			var to_missile = missile.global_position - global_position
			var our_velocity_normalized = velocity.normalized()
			var their_velocity_normalized = Vector2.ZERO
			
			if "velocity" in missile:
				their_velocity_normalized = missile.velocity.normalized()
			
			var heading_towards = our_velocity_normalized.dot(to_missile.normalized()) > 0.3
			var they_heading_towards = their_velocity_normalized.dot(-to_missile.normalized()) > 0.3
			
			if heading_towards and they_heading_towards:
				var away_direction = (global_position - missile.global_position).normalized()
				var avoidance_strength = (collision_buffer - distance) / collision_buffer
				avoidance += away_direction * avoidance_strength
				collision_threats += 1
	
	if collision_threats > 0:
		avoidance = avoidance.normalized() * collision_avoidance_strength
		if phase == "desperate":
			avoidance *= 0.3
	
	return avoidance

func destroy_from_collision():
	#print("Missile destroyed by collision with another missile!")
	destroy()

func destroy():
	# NEW: Apply explosion forces to nearby missiles before destroying
	apply_explosion_forces_to_nearby_missiles()
	spawn_explosion()
	queue_free()

# NEW: Apply explosion forces to all nearby missiles
func apply_explosion_forces_to_nearby_missiles():
	var nearby_missiles = get_tree().get_nodes_in_group("missiles")
	for missile in nearby_missiles:
		if missile != self and is_instance_valid(missile) and missile.has_method("apply_explosion_force"):
			missile.apply_explosion_force(global_position)

func spawn_explosion():
	#print("explosion spawned")
	var explosion_instance = EXPLOSION_FX.instantiate()
	explosion_instance.global_position = global_position
	get_tree().get_root().add_child(explosion_instance)

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
	#print("Missile fuel depleted - self destructing")
	destroy()

func _on_area_2d_body_entered(body):
	if body.is_in_group("player"):
		#print("Player hit by missile!")
		destroy()

func _enter_tree():
	add_to_group("missiles")

func _exit_tree():
	remove_from_group("missiles")
