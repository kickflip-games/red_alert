class_name Collectible
extends RigidBody2D

signal collected(letter, points)

@export var points_value: int = 10
@export var initial_speed: float = 200.0
@export var bounce_damping: float = 0.8

@onready var sprite: Sprite2D = $Sprite2D
@onready var label: Label = $Label

var letter_char: String = ""
var screen_size: Vector2

func _ready():
	# Get screen boundaries
	screen_size = get_viewport().get_visible_rect().size
	
	# Set up physics for bouncing
	gravity_scale = 0
	linear_damp = 0.2
	
	# Give initial random velocity
	var random_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	linear_velocity = random_direction * initial_speed


func setup_letter(letter: String):
	letter_char = letter.to_upper()
	$Label.text = letter_char
	

func _physics_process(delta):
	# Add slight rotation for visual appeal
	rotation += delta * 1.0
	
	# Optional: Add slight damping over time to prevent infinite bouncing
	if linear_velocity.length() < 50.0:
		var boost_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		apply_impulse(boost_direction * 100.0)

		
func trigger_collection():
	collected.emit(letter_char, points_value)
	create_collection_effect()
	queue_free()

func create_collection_effect():
	# Simple scale-up effect before disappearing
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.1)
	tween.tween_property(self, "modulate:a", 0.0, 0.1)

func get_letter() -> String:
	return letter_char
