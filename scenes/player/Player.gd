# Player.gd
extends Node2D

# --- Configurable variables ---
@export var move_smoothing := 0.1
@export var dash_speed := 800.0
@export var dash_duration := 0.25
@export var dash_cooldown := 1.5
@export var max_hp := 3

# --- State ---
var current_hp := max_hp
var is_dashing := false
var dash_timer := 0.0
var dash_cooldown_timer := 0.0
var dash_direction := Vector2.ZERO
var target_position := Vector2.ZERO

# --- Nodes ---
@onready var sprite: Sprite2D = $Sprite2D
@onready var reticle: Sprite2D = $Reticle
@onready var dash_particles: GPUParticles2D = $DashParticles
@onready var collision_area: Area2D = $CollisionArea

# --- Signals to connect with HUD ---
signal hp_changed(current_hp: int)
signal dash_cooldown_updated(percent_ready: float)

func _ready():
	target_position = global_position
	reticle.visible = true
	reticle.modulate.a = 0.5
	collision_area.connect("area_entered", _on_area_entered)
	emit_signal("hp_changed", current_hp)

func _process(delta):
	# Update dash timers and movement
	if is_dashing:
		global_position += dash_direction * dash_speed * delta
		dash_timer -= delta
		if dash_timer <= 0:
			end_dash()
	else:
		_handle_mouse_input()
		_apply_smooth_movement(delta)
		dash_cooldown_timer = max(dash_cooldown_timer - delta, 0.0)

	# Update visuals
	_update_reticle(delta)
	emit_signal("dash_cooldown_updated", _get_dash_percent_ready())

func _input(event):
	if event.is_action_pressed("dash") and not is_dashing and dash_cooldown_timer <= 0.0:
		start_dash()

# --- Dash ---
func start_dash():
	is_dashing = true
	dash_timer = dash_duration
	dash_cooldown_timer = dash_cooldown
	dash_direction = (target_position - global_position).normalized()
	sprite.modulate = Color(1, 1, 1, 0.5)  # fade to show invulnerable
	dash_particles.emitting = true

func end_dash():
	is_dashing = false
	sprite.modulate = Color(1, 1, 1, 1)
	dash_particles.emitting = false

# --- Movement ---
func _handle_mouse_input():
	target_position = get_global_mouse_position()

func _apply_smooth_movement(delta):
	global_position = global_position.lerp(target_position, move_smoothing)

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
		return  # Invulnerable during dash
	take_damage(1)

func take_damage(amount: int):
	current_hp -= amount
	emit_signal("hp_changed", current_hp)
	print("Took damage! HP = ", current_hp)

	# Flash effect
	sprite.modulate = Color(1, 0.3, 0.3, 1.0)
	await get_tree().create_timer(0.1).timeout
	if not is_dashing:
		sprite.modulate = Color(1, 1, 1, 1.0)

	if current_hp <= 0:
		die()

func die():
	print("Player has died")
	queue_free()  # Or trigger a game over scene
