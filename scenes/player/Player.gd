# Player.gd
extends Node2D

# --- Configurable variables ---
@export var acceleration := 800.0
@export var max_speed := 400.0
@export var drag := 0.95
@export var turn_rate := 8.0
@export var dash_speed := 1200.0   
@export var dash_duration := 0.15  
@export var dash_cooldown := 1.5
@export var dash_start_boost := 1.5
@export var max_hp := 3

# --- Circling behavior ---
@export var circle_radius := 80.0        # How close before circling starts
@export var circle_speed := 300.0        # Speed when circling
@export var circle_orbit_radius := 60.0  # Radius of circular orbit

# --- Turn effects ---
@export var sharp_turn_threshold := 2.0   # Radians/sec to trigger turn effects
@export var turn_fx_duration := 0.3      # How long turn effects last

# --- State ---
var velocity := Vector2.ZERO
var current_hp := max_hp
var is_dashing := false
var is_circling := false
var circle_angle := 0.0
var last_rotation := 0.0
var turn_fx_timer := 0.0
var dash_timer := 0.0
var dash_cooldown_timer := 0.0
var dash_direction := Vector2.ZERO
var target_position := Vector2.ZERO

# --- Trail system ---
var dash_trail_points: Array = []
var max_trail_points := 12

# --- Nodes ---
@onready var sprite: Sprite2D = $Sprite2D
@onready var reticle: Sprite2D = $Reticle
@onready var dash_particles: GPUParticles2D = $DashParticles
@onready var collision_area: Area2D = $CollisionArea
@onready var turn_fx_left: Line2D = $TurnFXLeft
@onready var turn_fx_right: Line2D = $TurnFXRight
@onready var dash_trail: Line2D = $DashTrail

# --- Signals to connect with HUD ---
signal hp_changed(current_hp: int)
signal dash_cooldown_updated(percent_ready: float)

func _ready():
	target_position = global_position
	reticle.visible = true
	reticle.modulate.a = 0.5
	collision_area.connect("area_entered", _on_area_entered)
	emit_signal("hp_changed", current_hp)
	last_rotation = sprite.rotation
	
	# Setup turn effects
	_setup_turn_fx()
	_setup_dash_trail()

func _setup_turn_fx():
	# Left wing trail
	turn_fx_left.width = 3.0
	turn_fx_left.default_color = Color(0.8, 0.9, 1.0, 0.0)
	turn_fx_left.visible = false
	
	# Right wing trail
	turn_fx_right.width = 3.0
	turn_fx_right.default_color = Color(0.8, 0.9, 1.0, 0.0)
	turn_fx_right.visible = false

func _setup_dash_trail():
	dash_trail.width = 4.0
	dash_trail.default_color = Color(1.0, 1.0, 1.0, 0.8)
	dash_trail.visible = false

func _process(delta):
	# Update dash timers and movement
	if is_dashing:
		_handle_dash_movement(delta)
		_update_dash_trail()
		dash_timer -= delta
		if dash_timer <= 0:
			end_dash()
	else:
		_handle_mouse_input()
		_apply_momentum_movement(delta)
		dash_cooldown_timer = max(dash_cooldown_timer - delta, 0.0)
		_fade_dash_trail(delta)

	# Update effects
	_update_turn_effects(delta)
	_update_reticle(delta)
	emit_signal("dash_cooldown_updated", _get_dash_percent_ready())

func _input(event):
	if event.is_action_pressed("dash") and can_dash():
		start_dash()

# --- Dash System ---
func can_dash() -> bool:
	return not is_dashing and dash_cooldown_timer <= 0.0 and current_hp > 0

func start_dash():
	is_dashing = true
	dash_timer = dash_duration
	dash_cooldown_timer = dash_cooldown
	dash_direction = (target_position - global_position).normalized()
	
	# Reset trail
	dash_trail_points.clear()
	dash_trail.visible = true
	
	# Visual impact effects
	sprite.modulate = Color(1.2, 1.2, 1.5, 0.7)
	sprite.scale = Vector2(1.2, 0.8)
	dash_particles.emitting = true

func _handle_dash_movement(delta):
	var dash_progress = 1.0 - (dash_timer / dash_duration)
	var current_speed = dash_speed
	
	if dash_progress < 0.3:
		current_speed *= dash_start_boost
	
	global_position += dash_direction * current_speed * delta
	sprite.rotation = dash_direction.angle()

func end_dash():
	is_dashing = false
	sprite.modulate = Color(1, 1, 1, 1)
	sprite.scale = Vector2.ONE
	dash_particles.emitting = false
	
	# Add some velocity in dash direction for smooth transition
	velocity += dash_direction * 200.0

# --- Momentum-Based Movement ---
func _handle_mouse_input():
	target_position = get_global_mouse_position()

func _apply_momentum_movement(delta):
	var distance_to_target = global_position.distance_to(target_position)
	
	# Check if we should enter circling mode
	if distance_to_target < circle_radius:
		_handle_circling_movement(delta)
	else:
		is_circling = false
		_handle_direct_movement(delta)
	
	# Apply drag and move
	velocity *= drag
	global_position += velocity * delta
	
	# Handle rotation with turn detection
	_handle_rotation_and_turns(delta)

func _handle_direct_movement(delta):
	var direction_to_target = (target_position - global_position).normalized()
	velocity += direction_to_target * acceleration * delta
	
	if velocity.length() > max_speed:
		velocity = velocity.normalized() * max_speed

func _handle_circling_movement(delta):
	if not is_circling:
		is_circling = true
		# Set initial circle angle based on current position relative to target
		var to_target = target_position - global_position
		circle_angle = to_target.angle() + PI/2  # Start perpendicular
	
	# Orbit around the target position
	circle_angle += (circle_speed / circle_orbit_radius) * delta
	var orbit_position = target_position + Vector2(cos(circle_angle), sin(circle_angle)) * circle_orbit_radius
	
	# Move toward orbit position
	var direction_to_orbit = (orbit_position - global_position).normalized()
	velocity += direction_to_orbit * acceleration * delta
	
	if velocity.length() > circle_speed:
		velocity = velocity.normalized() * circle_speed

func _handle_rotation_and_turns(delta):
	if velocity.length() > 10.0:
		var target_rotation = velocity.angle()
		var old_rotation = sprite.rotation
		sprite.rotation = lerp_angle(sprite.rotation, target_rotation, turn_rate * delta)
		
		# Calculate turn rate for effects
		var rotation_change = abs(angle_difference(sprite.rotation, last_rotation))
		var turn_speed = rotation_change / delta
		
		if turn_speed > sharp_turn_threshold:
			_trigger_turn_effects(turn_speed)
		
		last_rotation = sprite.rotation

# --- Turn Effects ---
func _trigger_turn_effects(turn_intensity: float):
	turn_fx_timer = turn_fx_duration
	
	# Create wing trails
	var wing_offset = 25.0  # Distance from center to wingtips
	var wing_direction = Vector2(cos(sprite.rotation + PI/2), sin(sprite.rotation + PI/2))
	
	# Left wing trail
	var left_wing_pos = global_position - wing_direction * wing_offset
	_create_wing_trail(turn_fx_left, left_wing_pos, turn_intensity)
	
	# Right wing trail  
	var right_wing_pos = global_position + wing_direction * wing_offset
	_create_wing_trail(turn_fx_right, right_wing_pos, turn_intensity)

func _create_wing_trail(trail: Line2D, wing_pos: Vector2, intensity: float):
	trail.visible = true
	trail.clear_points()
	
	var trail_length = min(intensity * 20.0, 80.0)
	var trail_direction = -velocity.normalized()
	
	trail.add_point(to_local(wing_pos))
	trail.add_point(to_local(wing_pos + trail_direction * trail_length))

func _update_turn_effects(delta):
	if turn_fx_timer > 0:
		turn_fx_timer -= delta
		var alpha = turn_fx_timer / turn_fx_duration
		
		turn_fx_left.default_color.a = alpha * 0.7
		turn_fx_right.default_color.a = alpha * 0.7
	else:
		turn_fx_left.visible = false
		turn_fx_right.visible = false

# --- Dash Trail Effects ---
func _update_dash_trail():
	dash_trail_points.append(global_position)
	if dash_trail_points.size() > max_trail_points:
		dash_trail_points.pop_front()
	
	dash_trail.clear_points()
	for i in range(dash_trail_points.size()):
		var alpha = float(i) / float(dash_trail_points.size())
		dash_trail.add_point(to_local(dash_trail_points[i]))

func _fade_dash_trail(delta):
	if dash_trail_points.size() > 0:
		# Remove oldest trail points gradually
		if randf() < 3.0 * delta:  # Remove points over time
			dash_trail_points.pop_front()
		
		if dash_trail_points.size() > 0:
			dash_trail.clear_points()
			for point in dash_trail_points:
				dash_trail.add_point(to_local(point))
		else:
			dash_trail.visible = false

func _update_reticle(delta):
	reticle.global_position = target_position
	var pulse = (sin(Time.get_ticks_msec() / 200.0) + 1.5) * 0.5
	reticle.scale = Vector2.ONE * (1.0 + 0.2 * pulse)
	reticle.modulate.a = 0.5 + 0.3 * pulse

func _get_dash_percent_ready() -> float:
	return clamp(1.0 - dash_cooldown_timer / dash_cooldown, 0.0, 1.0)

# --- Collision & Damage ---
func _on_area_entered(area: Area2D):
	if is_dashing:
		return
	take_damage(1)

func take_damage(amount: int):
	current_hp -= amount
	emit_signal("hp_changed", current_hp)
	print("Took damage! HP = ", current_hp)

	sprite.modulate = Color(1, 0.3, 0.3, 1.0)
	await get_tree().create_timer(0.1).timeout
	if not is_dashing:
		sprite.modulate = Color(1, 1, 1, 1.0)

	if current_hp <= 0:
		die()

func die():
	print("Player has died")
	queue_free()
