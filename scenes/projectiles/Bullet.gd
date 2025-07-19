# Bullet.gd
extends RigidBody2D
class_name Bullet

@export var damage: int = 1
@export var lifetime: float = 10.0

var velocity: Vector2

func _ready():
	# Set up the bullet
	gravity_scale = 0  # No gravity for top-down
	lock_rotation = true  # Keep bullet upright
	
	# Connect collision signal
	body_entered.connect(_on_body_entered)
	
	# Auto-destroy after lifetime
	get_tree().create_timer(lifetime).timeout.connect(_destroy_bullet)
	
	# Make sure the bullet moves
	if velocity != Vector2.ZERO:
		linear_velocity = velocity

func _integrate_forces(state):
	# Keep constant velocity (ignore friction/dampening)
	if velocity != Vector2.ZERO:
		state.linear_velocity = velocity

func set_velocity(new_velocity: Vector2):
	velocity = new_velocity
	linear_velocity = velocity

func _on_body_entered(body):
	# Check if we hit the player
	if body.has_method("take_damage"):
		body.take_damage(damage)
		_destroy_bullet()

func _destroy_bullet():
	# Add destruction effect here if desired
	queue_free()

# Clean up when leaving screen bounds
func _on_visible_on_screen_notifier_2d_screen_exited():
	_destroy_bullet()
