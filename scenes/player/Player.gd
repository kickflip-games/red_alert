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
@export var max_hp := 5
@export var invincibility_duration: float = 1.2

# --- Circling behavior ---
@export var circle_radius := 80.0
@export var circle_speed := 300.0
@export var circle_orbit_radius := 60.0

# --- Juice FX ---
@export var hit_pause_duration := 0.095
@export var dash_bloom_intensity := 1.8
@export var idle_pulse_speed := 2.0
@export var dash_dial_radius := 40.0

# --- State ---
var velocity := Vector2.ZERO
var current_hp := max_hp
var is_dashing := false
var is_circling := false
var is_invincible := false
var is_hit_paused := false
var is_dead:= false
var circle_angle := 0.0
var last_rotation := 0.0
var dash_timer := 0.0
var dash_cooldown_timer := 0.0
var dash_direction := Vector2.ZERO
var target_position := Vector2.ZERO
var velocity_history: Array[Vector2] = []

# --- Trail reference ---
var current_trail: Trail

# --- Tween references ---
var sprite_tween: Tween

# --- Nodes ---
@onready var sprite: Sprite2D = $Sprite2D
@onready var reticle: Sprite2D = $Reticle
@onready var dash_particles: CPUParticles2D = $DashParticles
@onready var movement_particles: CPUParticles2D = $MovementParticles
@onready var damage_particles: CPUParticles2D = $DamageParticles
@onready var idle_pulse_particles: CPUParticles2D = $IdlePulseParticles
@onready var collision_area: Area2D = $CollisionArea
@onready var collectable_area: Area2D = $CollectableArea
@onready var dash_dial: Line2D = $DashDial
@onready var dash_dial_bg: Line2D = $DashDialBG

const HURT_SFX = preload("res://assets/audio/sfx/hurt-sound.ogg")
const DASH_SFX = preload("res://assets/audio/sfx/dash-sound.ogg")

# --- Signals ---
signal hp_changed(current_hp: int)
signal dash_cooldown_updated(percent_ready: float)
signal player_died
signal letter_pickedup(letter:String)

func _ready():
	target_position = global_position
	reticle.visible = true
	reticle.modulate.a = 0.5
	collision_area.body_entered.connect(_on_body_entered)
	collectable_area.body_entered.connect(_on_collectable_entered)
	
	emit_signal("hp_changed", current_hp)
	last_rotation = rotation
	
	_setup_dash_dial()
	_create_movement_trail()

func _create_movement_trail():
	current_trail = Trail.create()
	add_child(current_trail)
	
	# Style the movement trail
	current_trail.width = 25.0
	current_trail.default_color = Color(0.7, 0.9, 1.2, 0.2)

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
		
	_update_velocity_history()
	
	# Update dash timers and movement
	if is_dashing:
		_handle_dash_movement(delta)
		_apply_dash_bloom_effect()
		dash_timer -= delta
		if dash_timer <= 0:
			end_dash()
	else:
		_handle_mouse_input()
		_apply_momentum_movement(delta)
		dash_cooldown_timer = max(dash_cooldown_timer - delta, 0.0)
		_update_movement_particles()

	_update_reticle(delta)
	_update_dash_dial()
	emit_signal("dash_cooldown_updated", _get_dash_percent_ready())

func _input(event):
	if event.is_action_pressed("dash") and can_dash():
		start_dash()

# --- Utility Functions ---
func _update_velocity_history():
	velocity_history.append(velocity)
	if velocity_history.size() > 10:
		velocity_history.pop_front()

func _safe_kill_tween(tween_ref: Tween):
	if tween_ref and tween_ref.is_valid():
		tween_ref.kill()

func _create_safe_tween() -> Tween:
	return create_tween()

# --- Hit Pause System ---
func trigger_hit_pause():
	if is_hit_paused:
		return

	is_hit_paused = true
	Engine.time_scale = 0.1

	_safe_kill_tween(sprite_tween)

	await get_tree().create_timer(hit_pause_duration).timeout
	Engine.time_scale = 1.0
	is_hit_paused = false

# --- Enhanced Dash System ---
func can_dash() -> bool:
	return not is_dashing and dash_cooldown_timer <= 0.0 and current_hp > 0

func start_dash():
	is_dashing = true
	SoundManager.play_sound_with_pitch(DASH_SFX, randf_range(0.85, 1))
	dash_timer = dash_duration
	dash_cooldown_timer = dash_cooldown
	dash_direction = (target_position - global_position).normalized()
	
	# Enhanced visual impact
	sprite.modulate = Color(dash_bloom_intensity, dash_bloom_intensity, dash_bloom_intensity + 0.3, 0.9)
	
	# Make trail more prominent during dash
	if current_trail:
		current_trail.width = 30.0
		current_trail.default_color = Color(1.0, 1.3, 1.8, 0.5)
	
	# Particle effects
	dash_particles.emitting = true
	if movement_particles:
		movement_particles.emitting = false

func _apply_dash_bloom_effect():
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

	if not is_instance_valid(sprite):
		return

	_safe_kill_tween(sprite_tween)
	sprite_tween = _create_safe_tween()
	
	sprite_tween.parallel().tween_property(sprite, "modulate", Color.WHITE, 0.2) \
			 .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	dash_particles.emitting = false

	if movement_particles and is_instance_valid(movement_particles):
		movement_particles.emitting = true

	velocity += dash_direction * 200.0
	
	# Return trail to normal appearance
	if current_trail:
		current_trail.width = 25.0
		current_trail.default_color = Color(0.7, 0.9, 1.2, 0.2)

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
		last_rotation = rotation

# --- Movement Particles ---
func _update_movement_particles():
	if movement_particles:
		if velocity.length() > 30.0:
			movement_particles.emitting = true
		else:
			movement_particles.emitting = false

# --- Dash Dial System ---
func _update_dash_dial():
	var dash_percent = _get_dash_percent_ready()
	dash_dial.clear_points()
	
	if dash_percent < 1.0:
		var arc_angle = dash_percent * TAU
		_create_arc_points(dash_dial, dash_dial_radius, arc_angle, 24)
		dash_dial.visible = true
		dash_dial_bg.visible = true
		
		# Color based on readiness
		dash_dial.default_color = Color(0.2, 1.0, 0.3, 0.9) if dash_percent > 0.8 else Color(1.0, 0.5, 0.2, 0.7)
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
		var angle = (float(i) / float(segments)) * end_angle - PI/2
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
	if is_dashing or is_invincible or is_dead:
		return
	
	take_damage(1)
	body.queue_free()

func _on_collectable_entered(body: Node2D):
	if body is Collectible:
		body.trigger_collection()
		letter_pickedup.emit(body.letter_char)

func take_damage(amount: int):
	damage_particles.emitting = true
	current_hp -= amount
	trigger_hit_pause()
	SoundManager.play_sound_with_pitch(HURT_SFX, randf_range(0.75, 1.0))
	emit_signal("hp_changed", current_hp)
	print("Took damage! HP = ", current_hp)

	if current_hp <= 0:
		die()
	else:
		become_invincible()

func become_invincible():
	if not is_instance_valid(sprite):
		return

	is_invincible = true

	_safe_kill_tween(sprite_tween)
	sprite_tween = _create_safe_tween()
	sprite_tween.set_loops(int(invincibility_duration * 6))
	sprite_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	sprite_tween.tween_property(sprite, "modulate", Color(1.5, 0.5, 0.5, 0.4), invincibility_duration / 12)
	sprite_tween.tween_property(sprite, "modulate", Color.WHITE, invincibility_duration / 12)

	await get_tree().create_timer(invincibility_duration).timeout
	is_invincible = false
	print("Player is no longer invincible.")

func die():
	if not is_instance_valid(sprite):
		return
	is_dead = true
	print("Player has died")
	player_died.emit()

	_safe_kill_tween(sprite_tween)
	sprite_tween = _create_safe_tween()
	
	sprite_tween.parallel().tween_property(sprite, "scale", Vector2.ZERO, 0.5) \
					  .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	sprite_tween.parallel().tween_property(sprite, "modulate", Color.TRANSPARENT, 0.5) \
					  .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	await sprite_tween.finished

	if is_instance_valid(self):
		queue_free()
