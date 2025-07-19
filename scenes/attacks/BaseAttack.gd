# BaseAttack.gd
extends Node2D
class_name BaseAttack

signal attack_finished

@export var warning_duration: float = 1.0
@export var attack_duration: float = 1.0
@export var warning_color: Color = Color.YELLOW
@export var attack_color: Color = Color.RED

var is_warning_phase: bool = true
var is_active: bool = false

func _ready():
	start_attack()

func start_attack():
	show_warning()
	is_warning_phase = true
	
	# Wait for warning duration
	await get_tree().create_timer(warning_duration).timeout
	
	# Switch to attack phase
	is_warning_phase = false
	is_active = true
	hide_warning()
	execute_attack()
	
	# Wait for attack duration
	await get_tree().create_timer(attack_duration).timeout
	
	# Cleanup
	is_active = false
	cleanup()

# Override these in subclasses
func show_warning():
	pass

func hide_warning():
	pass

func execute_attack():
	pass

func cleanup():
	attack_finished.emit()
	queue_free()
