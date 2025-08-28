# HomingMissile.gd
extends CharacterBody2D

@export var speed: float = 200.0
@export var turn_speed: float = 3.0
@export var acceleration: float = 50.0

# Prediction settings
@export var prediction_time: float = 1.5  # How far ahead to predict (seconds)
@export var prediction_accuracy: float = 0.8  # 0.0 = no prediction, 1.0 = perfect prediction

# Anti-clumping settings
@export var separation_radius: float = 60.0  # Distance to maintain from other missiles
@export var separation_strength: float = 100.0  # How strongly to avoid other missiles

# Advanced behavior
@export var evasion_detection_radius: float = 150.0  # How close to get before using evasion
@export var spiral_intensity: float = 0.3  # How much to spiral when close
@export var fuel_time: float = 800.0  # How long missile stays active

# Noise settings for unpredictability
@export var course_correction_noise: float = 0.4  # Random course adjustments
@export var speed_noise: float = 0.15  # Random speed variations
@export var turn_rate_noise: float = 0.3  # Random turning speed changes
@export var prediction_noise: float = 0.2  # Noise in target prediction
@export var noise_frequency: float = 2.0  # How often noise changes (Hz)

# Group tactics settings
@export var enable_group_tactics: bool = true
@export var formation_radius: float = 120.0  # How spread out formation positions are
@export var flanking_distance: float = 200.0  # How far to flank around target
@export var pincer_coordination: bool = true  # Whether to coordinate pincer attacks
@export var leader_following: bool = true  # Whether some missiles follow a leader

# Trail settings
@export var trail_length: int = 30
@export var trail_width: float = 8.0
@export var trail_color_start: Color = Color.ORANGE
@export var trail_color_end: Color = Color(1.0, 0.3, 0.0, 0.0)

var target: Node2D
var current_speed: float = 0.0
var trail_points: Array = []
var fuel_remaining: float
var spiral_offset: float = 0.0
var other_missiles: Array = []

# Noise variables
var noise_timer: float = 0.0
var current_course_noise: Vector2 = Vector2.ZERO
var current_speed_multiplier: float = 1.0
var current_turn_multiplier: float = 1.0
var prediction_error: Vector2 = Vector2.ZERO
var noise_seed: int

# Group behavior variables
var missile_id: int = 0  # Unique ID for this missile
var group_role: String = "hunter"  # "hunter", "flanker", "blocker", "leader"
var formation_position: Vector2 = Vector2.ZERO
var tactical_target: Vector2 = Vector2.ZERO
var coordination_timer: float = 0.0

@onready var trail := $Trail

func _ready():
	target = get_tree().get_first_node_in_group("player")
	fuel_remaining = fuel_time
	noise_seed = randi()  # Give each missile unique noise patterns
	missile_id = randi() % 10000  # Assign unique ID
	
	if not target:
		print("Warning: No player found in 'player' group")
	
	# Find other missiles for separation behavior
	update_missile_list()
	
	# Initialize noise values
	update_noise_values()
	
	# Assign tactical role based on existing missile count
	assign_tactical_role()

func _physics_process(delta):
	if not target or fuel_remaining <= 0:
		self_destruct()
		return
	
	fuel_remaining -= delta
	spiral_offset += delta * 3.0  # For spiral movement
	noise_timer += delta
	coordination_timer += delta
	
	# Update noise values periodically
	if noise_timer >= 1.0 / noise_frequency:
		update_noise_values()
		noise_timer = 0.0
	
	# Update group coordination periodically
	if coordination_timer >= 0.5:  # Update tactics twice per second
		update_group_coordination()
		coordination_timer = 0.0
	
	# Update our list of other missiles periodically
	if randf() < 0.1:  # 10% chance each frame to update list
		update_missile_list()
	
	# Get tactical target position (may be different from direct target)
	var target_position = get_tactical_target_position()
	
	# Calculate base direction to tactical target
	var direction_to_target = (target_position - global_position).normalized()
	
	# Add separation force from other missiles
	var separation_force = get_separation_force()
	
	# Add evasive spiral when close to target
	var evasion_force = get_evasion_force()
	
	# Add course correction noise
	var noise_force = current_course_noise
	
	# Add group coordination force
	var group_force = get_group_coordination_force()
	
	# Combine all forces
	var final_direction = (direction_to_target + separation_force + evasion_force + noise_force + group_force).normalized()
	
	# Apply turn rate noise to rotation speed
	var noisy_turn_speed = turn_speed * current_turn_multiplier
	
	# Smoothly rotate towards final direction
	var target_rotation = final_direction.angle()
	rotation = lerp_angle(rotation, target_rotation, noisy_turn_speed * delta)
	
	# Accelerate towards max speed (with fuel efficiency and speed noise)
	var fuel_efficiency = fuel_remaining / fuel_time
	var noisy_speed = speed * current_speed_multiplier
	
	# Apply role-based speed modifications
	var role_speed_modifier = get_role_speed_modifier()
	current_speed = min(current_speed + acceleration * delta * fuel_efficiency, noisy_speed * role_speed_modifier)
	
	# Move in the direction we're facing
	velocity = Vector2.RIGHT.rotated(rotation) * current_speed
	move_and_slide()
	
	update_trail()

func get_predicted_target_position() -> Vector2:
	if not target:
		return Vector2.ZERO
	
	# Get target's current velocity
	var target_velocity = Vector2.ZERO
	if "velocity" in target:
		target_velocity = target.velocity
	elif target.has_method("get_velocity"):
		target_velocity = target.get_velocity()
	
	# Calculate distance and time to intercept
	var distance_to_target = global_position.distance_to(target.global_position)
	var time_to_intercept = distance_to_target / max(current_speed, 1.0)
	
	# Predict where target will be
	var prediction_distance = min(time_to_intercept, prediction_time)
	var predicted_position = target.global_position + (target_velocity * prediction_distance)
	
	# Add prediction noise/error
	predicted_position += prediction_error
	
	# Blend between current position and predicted position based on accuracy
	return target.global_position.lerp(predicted_position, prediction_accuracy)

func get_tactical_target_position() -> Vector2:
	if not enable_group_tactics:
		return get_predicted_target_position()
	
	match group_role:
		"hunter":
			return get_predicted_target_position()
		"flanker":
			return get_flanking_position()
		"blocker":
			return get_blocking_position()
		"leader":
			return get_predicted_target_position()
		_:
			return get_predicted_target_position()

func assign_tactical_role():
	if not enable_group_tactics:
		group_role = "hunter"
		return
	
	var missile_count = other_missiles.size() + 1  # +1 for self
	
	# Assign roles based on missile count and ID
	if missile_count == 1:
		group_role = "hunter"
	elif missile_count == 2:
		if missile_id % 2 == 0:
			group_role = "hunter"
		else:
			group_role = "flanker"
	elif missile_count >= 3:
		var role_index = missile_id % 4
		match role_index:
			0: group_role = "leader"
			1: group_role = "flanker"
			2: group_role = "blocker"
			3: group_role = "hunter"

func update_group_coordination():
	if not enable_group_tactics or not target:
		return
	
	var missile_count = other_missiles.size() + 1
	
	# Update formation based on group size and roles
	if missile_count >= 2:
		calculate_formation_position()
	
	# Coordinate timing for pincer attacks
	if pincer_coordination and missile_count >= 2:
		coordinate_pincer_attack()

func calculate_formation_position():
	var missile_count = other_missiles.size() + 1
	var my_index = get_my_formation_index()
	
	# Create circular formation around target
	var angle_step = TAU / missile_count
	var my_angle = angle_step * my_index
	
	formation_position = target.global_position + Vector2.from_angle(my_angle) * formation_radius

func get_my_formation_index() -> int:
	var sorted_missiles = []
	
	# Only add valid missiles to the sorted list
	for missile in other_missiles:
		if is_instance_valid(missile):
			sorted_missiles.append(missile)
	
	# Add self
	sorted_missiles.append(self)
	
	# Sort by missile ID
	sorted_missiles.sort_custom(func(a, b): return a.missile_id < b.missile_id)
	
	for i in range(sorted_missiles.size()):
		if sorted_missiles[i] == self:
			return i
	return 0

func get_flanking_position() -> Vector2:
	if not target:
		return global_position
	
	# Get target's velocity to predict escape direction
	var target_velocity = Vector2.ZERO
	if "velocity" in target:
		target_velocity = target.velocity
	
	# Flank from the side the target is moving away from
	var escape_direction = target_velocity.normalized()
	if escape_direction.length() < 0.1:
		escape_direction = (target.global_position - global_position).normalized()
	
	# Position perpendicular to escape direction
	var flank_direction = Vector2(-escape_direction.y, escape_direction.x)
	if missile_id % 2 == 0:
		flank_direction = -flank_direction  # Some missiles flank from other side
	
	return target.global_position + flank_direction * flanking_distance

func get_blocking_position() -> Vector2:
	if not target:
		return global_position
	
	# Get target's predicted escape route
	var predicted_pos = get_predicted_target_position()
	var escape_direction = (predicted_pos - target.global_position).normalized()
	
	# Position ahead of target to block escape
	return predicted_pos + escape_direction * flanking_distance * 0.7

func coordinate_pincer_attack() -> void:
	# Simple coordination: wait for other missiles to get into position
	var missiles_in_position = 0
	var total_missiles = other_missiles.size() + 1
	
	for missile in other_missiles:
		if not is_instance_valid(missile):
			continue
		var distance_to_formation = missile.global_position.distance_to(missile.formation_position)
		if distance_to_formation < 80.0:  # Close enough to formation position
			missiles_in_position += 1
	
	# Check if we're in position too
	var my_distance_to_formation = global_position.distance_to(formation_position)
	if my_distance_to_formation < 80.0:
		missiles_in_position += 1
	
	# If most missiles are in position, signal to attack
	var coordination_threshold = max(2, total_missiles * 0.6)
	if missiles_in_position >= coordination_threshold:
		# Switch to aggressive hunter mode
		if group_role != "leader":
			group_role = "hunter"

func get_group_coordination_force() -> Vector2:
	if not enable_group_tactics:
		return Vector2.ZERO
	
	var coordination_force = Vector2.ZERO
	
	# Formation keeping for non-hunter roles
	if group_role != "hunter" and formation_position != Vector2.ZERO:
		var to_formation = (formation_position - global_position)
		var formation_distance = to_formation.length()
		
		if formation_distance > 50.0:  # Only apply if we're far from formation
			coordination_force += to_formation.normalized() * 0.3
	
	# Leader following behavior
	if leader_following and group_role != "leader":
		var leader = find_leader_missile()
		if leader:
			var leader_direction = (leader.global_position - global_position).normalized()
			var distance_to_leader = global_position.distance_to(leader.global_position)
			
			# Follow leader but maintain some distance
			if distance_to_leader > 150.0:
				coordination_force += leader_direction * 0.2
			elif distance_to_leader < 80.0:
				coordination_force -= leader_direction * 0.2
	
	return coordination_force

func find_leader_missile():
	for missile in other_missiles:
		if is_instance_valid(missile) and missile.group_role == "leader":
			return missile
	return null

func get_role_speed_modifier() -> float:
	match group_role:
		"hunter": return 1.0      # Normal speed
		"flanker": return 1.1     # Slightly faster to get into position
		"blocker": return 1.2     # Fastest to cut off escape routes  
		"leader": return 0.9      # Slightly slower, more methodical
		_: return 1.0

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
		separation = separation.normalized() * separation_strength / 100.0
	
	return separation

func get_evasion_force() -> Vector2:
	var distance_to_target = global_position.distance_to(target.global_position)
	
	# Only use evasion when close to target
	if distance_to_target > evasion_detection_radius:
		return Vector2.ZERO
	
	# Create a spiral pattern to make the missile harder to predict
	var spiral_strength = (evasion_detection_radius - distance_to_target) / evasion_detection_radius
	var perpendicular = Vector2.UP.rotated(rotation + PI/2)
	var spiral_force = perpendicular * sin(spiral_offset) * spiral_intensity * spiral_strength
	
	return spiral_force

func update_missile_list():
	other_missiles.clear()
	# Find all nodes in the "missiles" group (you'll need to add missiles to this group)
	var missiles = get_tree().get_nodes_in_group("missiles")
	for missile in missiles:
		if missile != self:
			other_missiles.append(missile)

func update_noise_values():
	# Use a seed-based approach so each missile has consistent but unique noise
	var time_factor = Time.get_time_dict_from_system().minute * 60 + Time.get_time_dict_from_system().second
	var seeded_random = (noise_seed + int(time_factor * noise_frequency)) % 1000
	
	# Generate different types of noise using different offsets
	var course_angle = (float(seeded_random) * 0.1) * TAU
	var course_magnitude = float((seeded_random * 3) % 100) / 100.0
	current_course_noise = Vector2.from_angle(course_angle) * course_magnitude * course_correction_noise
	
	# Speed noise (0.85 to 1.15 range by default)
	var speed_random = float((seeded_random * 7) % 100) / 100.0
	current_speed_multiplier = 1.0 + (speed_random - 0.5) * 2.0 * speed_noise
	current_speed_multiplier = clamp(current_speed_multiplier, 0.5, 1.5)
	
	# Turn rate noise (0.7 to 1.3 range by default)
	var turn_random = float((seeded_random * 11) % 100) / 100.0
	current_turn_multiplier = 1.0 + (turn_random - 0.5) * 2.0 * turn_rate_noise
	current_turn_multiplier = clamp(current_turn_multiplier, 0.3, 2.0)
	
	# Prediction error noise
	var pred_angle = (float(seeded_random) * 0.13) * TAU
	var pred_magnitude = float((seeded_random * 17) % 100) / 100.0
	var max_error = 50.0  # Maximum prediction error in pixels
	prediction_error = Vector2.from_angle(pred_angle) * pred_magnitude * prediction_noise * max_error

func update_trail():
	trail_points.append(global_position)
	
	if trail_points.size() > trail_length:
		trail_points.pop_front()
	
	trail.visible = true
	trail.clear_points()
	
	for point in trail_points:
		trail.add_point(to_local(point))

func self_destruct():
	# Add explosion effect here if desired
	print("Missile self-destructed")
	destroy()

func destroy():
	queue_free()

func _on_area_2d_body_entered(body):
	if body.is_in_group("player"):
		print("Player hit by missile!")
		# Add explosion/damage logic here
		destroy()

# Call this when spawning the missile to add it to the missiles group
func _enter_tree():
	add_to_group("missiles")

func _exit_tree():
	remove_from_group("missiles")
