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
@export var invincibility_duration: float = 1.2

# --- Circling behavior ---
@export var circle_radius := 80.0
@export var circle_speed := 300.0
@export var circle_orbit_radius := 60.0

# --- Turn effects ---
@export var sharp_turn_threshold := 2.0
@export var turn_fx_duration := 0.3
@export var curved_trail_segments := 8  # Number of segments for curved trails

# --- Juice FX ---
@export var hit_pause_duration := 0.08  # Hit pause duration
@export var dash_bloom_intensity := 1.8
@export var dash_trail_fade_duration := 0.2
@export var idle_pulse_speed := 2.0
@export var dash_dial_radius := 40.0  # Distance from player center

# --- State ---
var velocity := Vector2.ZERO
var current_hp := max_hp
var is_dashing := false
var is_circling := false
var is_invincible := false
var is_hit_paused := false
var circle_angle := 0.0
var last_rotation := 0.0
var turn_fx_timer := 0.0
var dash_timer := 0.0
var dash_cooldown_timer := 0.0
var dash_direction := Vector2.ZERO
var target_position := Vector2.ZERO
var velocity_history: Array[Vector2] = []  # For curved trails

# --- Trail system ---
var dash_trail_points: Array = []
var max_trail_points := 15
var movement_trail_points: Array = []
var max_movement_trail_points := 20
var dash_trail_tween: Tween
var dash_trail_active = false
var turn_trail_points_left = []
var turn_trail_points_right = []
var max_turn_trail_points = 20  # Adjust as needed
var is_sharp_turning = false
var turn_trail_fade_speed = 1.0  # Adjust fade speed


# --- Nodes ---
@onready var sprite: Sprite2D = $Sprite2D
@onready var reticle: Sprite2D = $Reticle
@onready var dash_particles: GPUParticles2D = $DashParticles
@onready var movement_particles: GPUParticles2D = $MovementParticles
@onready var idle_pulse_particles: GPUParticles2D = $IdlePulseParticles
@onready var collision_area: Area2D = $CollisionArea
@onready var turn_fx_left: Line2D = $TurnFXLeft
@onready var turn_fx_right: Line2D = $TurnFXRight
@onready var dash_trail: Line2D = $DashTrail
@onready var movement_trail: Line2D = $MovementTrail
@onready var dash_dial: Line2D = $DashDial
@onready var dash_dial_bg: Line2D = $DashDialBG

# --- Signals ---
signal hp_changed(current_hp: int)
signal dash_cooldown_updated(percent_ready: float)
signal player_died

func _ready():
	target_position = global_position
	reticle.visible = true
	reticle.modulate.a = 0.5
	collision_area.connect("body_entered", _on_body_entered)
	emit_signal("hp_changed", current_hp)
	last_rotation = rotation
	
	#_setup_movement_trail()
	_setup_dash_dial()
	




func _setup_movement_trail():
	movement_trail.width = 2.0
	movement_trail.default_color = Color(1.0, 1.0, 1.0, 0.7)
	movement_trail.visible = true

func _setup_dash_dial():
	# Background circle (full circle)
	dash_dial_bg.width = 3.0
	dash_dial_bg.default_color = Color(0.3, 0.3, 0.3, 0.5)
	_create_circle_points(dash_dial_bg, dash_dial_radius, 32)
	
	# Progress arc
	dash_dial.width = 4.0
	dash_dial.default_color = Color(0.2, 0.8, 1.0, 0.8)



func _process(delta):
	if is_hit_paused:
		return
		
	# Track velocity for curved trails
	velocity_history.append(velocity)
	if velocity_history.size() > 10:
		velocity_history.pop_front()
	
	# Update dash timers and movement
	if is_dashing:
		_handle_dash_movement(delta)
		_update_dash_trail()
		_apply_dash_bloom_effect()
		dash_timer -= delta
		if dash_timer <= 0:
			end_dash()
	else:
		_handle_mouse_input()
		_apply_momentum_movement(delta)
		dash_cooldown_timer = max(dash_cooldown_timer - delta, 0.0)
		
		_update_movement_trail()
		_update_movement_particles()

	# Update all visual effects
	#_update_turn_effects(delta)
	_update_reticle(delta)
	_update_dash_dial()
	#_update_idle_pulse(delta)
	emit_signal("dash_cooldown_updated", _get_dash_percent_ready())

func _input(event):
	if event.is_action_pressed("dash") and can_dash():
		start_dash()

# --- Hit Pause System ---
func trigger_hit_pause():
	if is_hit_paused:
		return
		
	is_hit_paused = true
	Engine.time_scale = 0.1  # Slow down time dramatically
	
	# Visual impact effect
	var impact_tween = create_tween()
	impact_tween.tween_property(sprite, "scale", Vector2(1.3, 0.7), hit_pause_duration * 0.3)
	impact_tween.tween_property(sprite, "scale", Vector2.ONE, hit_pause_duration * 0.7)
	
	# Resume normal time after pause
	await get_tree().create_timer(hit_pause_duration * Engine.time_scale).timeout
	Engine.time_scale = 1.0
	is_hit_paused = false

# --- Enhanced Dash System ---
func can_dash() -> bool:
	return not is_dashing and dash_cooldown_timer <= 0.0 and current_hp > 0

func start_dash():
	is_dashing = true
	dash_timer = dash_duration
	dash_cooldown_timer = dash_cooldown
	dash_direction = (target_position - global_position).normalized()
	
	# Reset and show trail
	dash_trail_points.clear()
	dash_trail.visible = true
	
	# Enhanced visual impact
	sprite.modulate = Color(dash_bloom_intensity, dash_bloom_intensity, dash_bloom_intensity + 0.3, 0.9)
	sprite.scale = Vector2(1.3, 0.7)
	
	# Particle burst
	dash_particles.emitting = true
	if movement_particles:
		movement_particles.emitting = false  # Stop movement particles during dash

func _apply_dash_bloom_effect():
	# Pulsing bloom effect during dash
	var pulse = sin(Time.get_ticks_msec() * 0.02) * 0.2 + 1.0
	sprite.modulate = Color(dash_bloom_intensity * pulse, dash_bloom_intensity * pulse, 
						   (dash_bloom_intensity + 0.3) * pulse, 0.9)

func _handle_dash_movement(delta):
	var dash_progress = 1.0 - (dash_timer / dash_duration)
	var current_speed = dash_speed
	
	if dash_progress < 0.3:
		current_speed *= dash_start_boost
	
	global_position += dash_direction * current_speed * delta
	rotation = dash_direction.angle()

func end_dash():
	is_dashing = false
	
	# Smooth return to normal
	var end_tween = create_tween()
	end_tween.parallel().tween_property(sprite, "modulate", Color.WHITE, 0.2)
	end_tween.parallel().tween_property(sprite, "scale", Vector2.ONE, 0.2)
	
	dash_particles.emitting = false
	
	# Resume movement particles
	if movement_particles:
		movement_particles.emitting = true
	
	# Add velocity for smooth transition
	velocity += dash_direction * 200.0

	start_dash_trail_fade()

# --- Enhanced Movement System ---
func _handle_mouse_input():
	target_position = get_global_mouse_position()

func _apply_momentum_movement(delta):
	var distance_to_target = global_position.distance_to(target_position)
	
	if distance_to_target < circle_radius:
		_handle_circling_movement(delta)
	else:
		is_circling = false
		_handle_direct_movement(delta)
	
	velocity *= drag
	global_position += velocity * delta
	_handle_rotation_and_turns(delta)

func _handle_direct_movement(delta):
	var direction_to_target = (target_position - global_position).normalized()
	velocity += direction_to_target * acceleration * delta
	
	if velocity.length() > max_speed:
		velocity = velocity.normalized() * max_speed

func _handle_circling_movement(delta):
	if not is_circling:
		is_circling = true
		var to_target = target_position - global_position
		circle_angle = to_target.angle() + PI/2
	
	circle_angle += (circle_speed / circle_orbit_radius) * delta
	var orbit_position = target_position + Vector2(cos(circle_angle), sin(circle_angle)) * circle_orbit_radius
	
	var direction_to_orbit = (orbit_position - global_position).normalized()
	velocity += direction_to_orbit * acceleration * delta
	
	if velocity.length() > circle_speed:
		velocity = velocity.normalized() * circle_speed


func _handle_rotation_and_turns(delta):
	if velocity.length() > 2.0:
		var target_rotation = velocity.angle()
		rotation = lerp_angle(rotation, target_rotation, turn_rate * delta)
		
		var rotation_change = abs(angle_difference(rotation, last_rotation))
		var turn_speed = rotation_change / delta
		
		if turn_speed > sharp_turn_threshold:
			if !is_sharp_turning:
				# Just started sharp turning - reset trails
				is_sharp_turning = true
				turn_trail_points_left.clear()
				turn_trail_points_right.clear()
			
			
			update_turn_trail_right()
			update_turn_trail_left()
				
		else:
			if is_sharp_turning:
				# Just stopped sharp turning - start fade
				is_sharp_turning = false
				start_turn_trails_fade()
		
		last_rotation = rotation


# --- Movement Trail System ---



func _update_movement_particles():
	if movement_particles:
		if velocity.length() > 30.0:
			movement_particles.emitting = true
			# Adjust particle direction based on movement
			movement_particles.process_material.direction = Vector3(-velocity.normalized().x, -velocity.normalized().y, 0)
		else:
			movement_particles.emitting = false

# --- Dash Dial System ---
func _update_dash_dial():
	var dash_percent = _get_dash_percent_ready()
	dash_dial.clear_points()
	
	if dash_percent < 1.0:
		# Create arc based on cooldown progress
		var arc_angle = dash_percent * TAU
		_create_arc_points(dash_dial, dash_dial_radius, arc_angle, 24)
		dash_dial.visible = true
		dash_dial_bg.visible = true
		
		# Color based on readiness
		if dash_percent > 0.8:
			dash_dial.default_color = Color(0.2, 1.0, 0.3, 0.9)  # Green when ready
		else:
			dash_dial.default_color = Color(1.0, 0.5, 0.2, 0.7)  # Orange when charging
	else:
		dash_dial.visible = false
		dash_dial_bg.visible = false

func _create_circle_points(line: Line2D, radius: float, segments: int):
	line.clear_points()
	for i in range(segments + 1):
		var angle = (float(i) / float(segments)) * TAU
		var point = Vector2(cos(angle), sin(angle)) * radius
		line.add_point(point)

func _create_arc_points(line: Line2D, radius: float, end_angle: float, segments: int):
	line.clear_points()
	var actual_segments = int(segments * (end_angle / TAU))
	
	for i in range(actual_segments + 1):
		var angle = (float(i) / float(segments)) * end_angle - PI/2  # Start from top
		var point = Vector2(cos(angle), sin(angle)) * radius
		line.add_point(point)



func _update_reticle(delta):
	reticle.global_position = target_position
	var pulse = (sin(Time.get_ticks_msec() / 200.0) + 1.5) * 0.5
	reticle.scale = Vector2.ONE * (1.0 + 0.2 * pulse)
	reticle.modulate.a = 0.5 + 0.3 * pulse

func _get_dash_percent_ready() -> float:
	return clamp(1.0 - dash_cooldown_timer / dash_cooldown, 0.0, 1.0)

# --- Enhanced Collision & Damage ---
func _on_body_entered(body: Node2D):
	print("Body entered: ", body.name)
	if is_dashing or is_invincible:
		return
	
	# Trigger hit pause for impact
	trigger_hit_pause()
	
	take_damage(1)
	body.queue_free()

func take_damage(amount: int):
	current_hp -= amount
	emit_signal("hp_changed", current_hp)
	print("Took damage! HP = ", current_hp)

	if current_hp <= 0:
		die()
	else:
		become_invincible()

func become_invincible():
	is_invincible = true
	
	# Enhanced flashing with color shift
	var tween = create_tween().set_loops(int(invincibility_duration * 6))
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(sprite, "modulate", Color(1.5, 0.5, 0.5, 0.4), invincibility_duration / 12)
	tween.tween_property(sprite, "modulate", Color.WHITE, invincibility_duration / 12)

	await get_tree().create_timer(invincibility_duration).timeout
	is_invincible = false
	print("Player is no longer invincible.")

func die():
	print("Player has died")
	# Death effect before destruction
	player_died.emit()
	
	var death_tween = create_tween()
	death_tween.parallel().tween_property(sprite, "scale", Vector2.ZERO, 0.5)
	death_tween.parallel().tween_property(sprite, "modulate", Color.TRANSPARENT, 0.5)
	await death_tween.finished
	
	queue_free()




##### TRAILS
## PLEASE CLEAN UP -- lots of shitty duplicated code... 


func update_turn_trail_left():
	turn_trail_points_left.append(global_position)
	if turn_trail_points_left.size() > max_turn_trail_points:
		turn_trail_points_left.pop_front()
	
	turn_fx_left.clear_points()
	turn_fx_left.visible = true
	
	# Add all points
	for point in turn_trail_points_left:
		turn_fx_left.add_point(to_local(point))


func update_turn_trail_right():
	turn_trail_points_right.append(global_position)
	if turn_trail_points_right.size() > max_turn_trail_points:
		turn_trail_points_right.pop_front()
	
	turn_fx_right.clear_points()
	turn_fx_right.visible = true
	
	# Add all points
	for point in turn_trail_points_right:
		turn_fx_right.add_point(to_local(point))


func start_turn_trails_fade():
	# Fade both trails
	var left_tween = create_tween()
	var right_tween = create_tween()
	
	left_tween.tween_property(turn_fx_left, "modulate:a", 0.0, turn_trail_fade_speed)
	right_tween.tween_property(turn_fx_right, "modulate:a", 0.0, turn_trail_fade_speed)
	
	left_tween.finished.connect(_on_turn_trail_fade_complete.bind("left"))
	right_tween.finished.connect(_on_turn_trail_fade_complete.bind("right"))

func _on_turn_trail_fade_complete(side: String):
	if side == "left":
		turn_fx_left.visible = false
		turn_fx_left.modulate.a = 1.0
		turn_trail_points_left.clear()
	else:
		turn_fx_right.visible = false
		turn_fx_right.modulate.a = 1.0
		turn_trail_points_right.clear()




func _update_dash_trail():
	dash_trail_points.append(global_position)
	if dash_trail_points.size() > max_trail_points:
		dash_trail_points.pop_front()
	
	dash_trail.clear_points()
	
	# Add all points first
	for point in dash_trail_points:
		dash_trail.add_point(to_local(point))
	
	
	
func start_dash_trail_fade():
	if dash_trail_active:
		return
	
	dash_trail_tween = create_tween()
	dash_trail_tween.finished.connect(_on_dash_trail_fade_complete)
	
	dash_trail_active = true
	# Tween the entire trail's modulate alpha from 1.0 to 0.0
	dash_trail_tween.tween_property(dash_trail, "modulate:a", 0.0, dash_trail_fade_duration)

func _on_dash_trail_fade_complete():
	dash_trail.visible = false
	dash_trail.modulate.a = 1.0  # Reset for next time
	dash_trail_points.clear()
	dash_trail_active = false
	
func _update_movement_trail():
	movement_trail_points.append(global_position)
	if movement_trail_points.size() > max_movement_trail_points:
		movement_trail_points.pop_front()
	
	movement_trail.visible = true
	movement_trail.clear_points()
	
	# Add all points first
	for point in movement_trail_points:
		movement_trail.add_point(to_local(point))
