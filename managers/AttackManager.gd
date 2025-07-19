# AttackManager.gd
extends Node
class_name AttackManager

signal game_complete

var game_timer: float = 0.0
var game_duration: float = 100.0
var current_attack_index: int = 0
var is_game_active: bool = false

# Pre-programmed attack timeline
var attack_timeline = [
	# Early game - simple attacks
	{"time": 3.0, "type": "bullet_stream", "params": {"start_pos": Vector2(-50, 200), "direction": Vector2(1, 0)}},
	{"time": 8.0, "type": "bullet_stream", "params": {"start_pos": Vector2(-50, 400), "direction": Vector2(1, 0)}},
	{"time": 12.0, "type": "bullet_stream", "params": {"start_pos": Vector2(600, -50), "direction": Vector2(0, 1)}},
	{"time": 18.0, "type": "bullet_stream", "params": {"start_pos": Vector2(-50, 300), "direction": Vector2(1, 0.5)}},
	{"time": 25.0, "type": "bullet_stream", "params": {"start_pos": Vector2(650, 200), "direction": Vector2(-1, 0)}},
	
	# Add more attacks as you implement them
	{"time": 30.0, "type": "bullet_stream", "params": {"start_pos": Vector2(300, -50), "direction": Vector2(0, 1)}},
	{"time": 35.0, "type": "bullet_stream", "params": {"start_pos": Vector2(-50, 500), "direction": Vector2(1, -0.3)}},
	{"time": 42.0, "type": "bullet_stream", "params": {"start_pos": Vector2(650, 100), "direction": Vector2(-1, 0.5)}},
	
	# Continue adding attacks up to 100 seconds...
]

# Attack scene references
var bullet_stream_scene = preload("res://scenes/attacks/BulletStreamAttack.tscn")

func _ready():
	start_game()

func start_game():
	is_game_active = true
	game_timer = 0.0
	current_attack_index = 0
	print("Game started! Survive for ", game_duration, " seconds!")

func _process(delta):
	if not is_game_active:
		return
	
	game_timer += delta
	
	# Check for attacks to spawn
	check_and_spawn_attacks()
	
	# Check for game completion
	if game_timer >= game_duration:
		complete_game()

func check_and_spawn_attacks():
	# Spawn any attacks that should happen at current time
	while current_attack_index < attack_timeline.size():
		var attack_data = attack_timeline[current_attack_index]
		
		if game_timer >= attack_data.time:
			spawn_attack(attack_data)
			current_attack_index += 1
		else:
			break  # No more attacks ready to spawn

func spawn_attack(attack_data: Dictionary):
	var attack_type = attack_data.type
	var params = attack_data.get("params", {})
	
	var attack_instance = null
	
	match attack_type:
		"bullet_stream":
			attack_instance = bullet_stream_scene.instantiate()
			
			# Set parameters
			if params.has("start_pos"):
				attack_instance.start_position = params.start_pos
			if params.has("direction"):
				attack_instance.direction = params.direction
			if params.has("speed"):
				attack_instance.bullet_speed = params.speed
			if params.has("spacing"):
				attack_instance.bullet_spacing = params.spacing
	
	if attack_instance:
		add_child(attack_instance)
		print("Spawned attack: ", attack_type, " at time: ", game_timer)

func complete_game():
	is_game_active = false
	print("Congratulations! You survived ", game_duration, " seconds!")
	game_complete.emit()

func get_remaining_time() -> float:
	return max(0.0, game_duration - game_timer)

func get_completion_percentage() -> float:
	return (game_timer / game_duration) * 100.0
