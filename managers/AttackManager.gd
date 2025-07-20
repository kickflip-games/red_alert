# AttackManager.gd
extends Node
class_name AttackManager

signal game_complete
signal attack_spawned(attack_type: String, time: float)
signal phase_changed(new_phase: int)

var game_timer: float = 0.0
var game_duration: float = 100.0
var current_attack_index: int = 0
var is_game_active: bool = false
var current_phase: int = 1
var active_attacks: Array[Node] = []

@export var  hud: HUD

# Difficulty scaling parameters
var difficulty_multiplier: float = 1.0
var base_spawn_rate: float = 1.0

# Pre-programmed attack timeline - BULLET STREAM ONLY for now
var attack_timeline = [
	# PHASE 1: Introduction (0-30s) - Simple horizontal and vertical streams
	{"time": 2.0, "type": "bullet_stream", "params": {"start_pos": Vector2(-50, 200), "direction": Vector2(1, 0), "speed": 150}},
	{"time": 6.0, "type": "bullet_stream", "params": {"start_pos": Vector2(50, 400), "direction": Vector2(-1, 0), "speed": 150}},
	{"time": 10.0, "type": "bullet_stream", "params": {"start_pos": Vector2(600, -50), "direction": Vector2(0, 1), "speed": 160}},
	{"time": 14.0, "type": "bullet_stream", "params": {"start_pos": Vector2(650, 300), "direction": Vector2(-1, 0), "speed": 160}},
	{"time": 18.0, "type": "bullet_stream", "params": {"start_pos": Vector2(-50, 300), "direction": Vector2(1, 0.3), "speed": 170}},
	{"time": 22.0, "type": "bullet_stream", "params": {"start_pos": Vector2(400, -50), "direction": Vector2(0, 1), "speed": 170}},
	{"time": 26.0, "type": "bullet_stream", "params": {"start_pos": Vector2(650, 150), "direction": Vector2(-1, 0.2), "speed": 180}},
	
	# PHASE 2: Escalation (30-60s) - Diagonal and faster streams
	{"time": 30.0, "type": "bullet_stream", "params": {"start_pos": Vector2(-50, 100), "direction": Vector2(1, 0.5), "speed": 200}},
	{"time": 33.0, "type": "bullet_stream", "params": {"start_pos": Vector2(650, 200), "direction": Vector2(-1, 0), "speed": 220}},
	{"time": 36.0, "type": "bullet_stream", "params": {"start_pos": Vector2(200, -50), "direction": Vector2(0.3, 1), "speed": 210}},
	{"time": 39.0, "type": "bullet_stream", "params": {"start_pos": Vector2(-50, 500), "direction": Vector2(1, -0.4), "speed": 230}},
	{"time": 42.0, "type": "bullet_stream", "params": {"start_pos": Vector2(650, 450), "direction": Vector2(-1, -0.3), "speed": 240}},
	{"time": 45.0, "type": "bullet_stream", "params": {"start_pos": Vector2(500, -50), "direction": Vector2(-0.2, 1), "speed": 220}},
	{"time": 48.0, "type": "bullet_stream", "params": {"start_pos": Vector2(-50, 250), "direction": Vector2(1, 0.6), "speed": 250}},
	{"time": 51.0, "type": "bullet_stream", "params": {"start_pos": Vector2(650, 350), "direction": Vector2(-1, -0.5), "speed": 260}},
	{"time": 54.0, "type": "bullet_stream", "params": {"start_pos": Vector2(300, -50), "direction": Vector2(0, 1), "speed": 280}},
	{"time": 57.0, "type": "bullet_stream", "params": {"start_pos": Vector2(-50, 450), "direction": Vector2(1, -0.6), "speed": 270}},
	
	# PHASE 3: Intensity (60-90s) - Multiple overlapping streams
	{"time": 60.0, "type": "bullet_stream", "params": {"start_pos": Vector2(-50, 150), "direction": Vector2(1, 0.4), "speed": 300}},
	{"time": 61.5, "type": "bullet_stream", "params": {"start_pos": Vector2(650, 450), "direction": Vector2(-1, -0.4), "speed": 300}},
	{"time": 63.0, "type": "bullet_stream", "params": {"start_pos": Vector2(100, -50), "direction": Vector2(0.5, 1), "speed": 320}},
	{"time": 65.0, "type": "bullet_stream", "params": {"start_pos": Vector2(-50, 350), "direction": Vector2(1, -0.2), "speed": 310}},
	{"time": 66.5, "type": "bullet_stream", "params": {"start_pos": Vector2(650, 100), "direction": Vector2(-1, 0.7), "speed": 330}},
	{"time": 68.0, "type": "bullet_stream", "params": {"start_pos": Vector2(450, -50), "direction": Vector2(-0.3, 1), "speed": 340}},
	{"time": 70.0, "type": "bullet_stream", "params": {"start_pos": Vector2(-50, 200), "direction": Vector2(1, 0.8), "speed": 350}},
	{"time": 71.5, "type": "bullet_stream", "params": {"start_pos": Vector2(650, 400), "direction": Vector2(-1, -0.6), "speed": 360}},
	{"time": 73.0, "type": "bullet_stream", "params": {"start_pos": Vector2(250, -50), "direction": Vector2(0.2, 1), "speed": 340}},
	{"time": 75.0, "type": "bullet_stream", "params": {"start_pos": Vector2(-50, 100), "direction": Vector2(1, 0.9), "speed": 370}},
	{"time": 76.5, "type": "bullet_stream", "params": {"start_pos": Vector2(650, 300), "direction": Vector2(-1, 0), "speed": 380}},
	{"time": 78.0, "type": "bullet_stream", "params": {"start_pos": Vector2(350, -50), "direction": Vector2(-0.1, 1), "speed": 360}},
	{"time": 80.0, "type": "bullet_stream", "params": {"start_pos": Vector2(-50, 450), "direction": Vector2(1, -0.8), "speed": 390}},
	{"time": 81.5, "type": "bullet_stream", "params": {"start_pos": Vector2(650, 250), "direction": Vector2(-1, 0.3), "speed": 400}},
	{"time": 83.0, "type": "bullet_stream", "params": {"start_pos": Vector2(150, -50), "direction": Vector2(0.8, 1), "speed": 380}},
	{"time": 85.0, "type": "bullet_stream", "params": {"start_pos": Vector2(-50, 320), "direction": Vector2(1, -0.1), "speed": 410}},
	{"time": 87.0, "type": "bullet_stream", "params": {"start_pos": Vector2(650, 180), "direction": Vector2(-1, 0.6), "speed": 420}},
	
	# PHASE 4: Final Challenge (90-120s) - Rapid-fire chaos
	{"time": 90.0, "type": "bullet_stream", "params": {"start_pos": Vector2(-50, 200), "direction": Vector2(1, 0.5), "speed": 450}},
	{"time": 90.8, "type": "bullet_stream", "params": {"start_pos": Vector2(650, 400), "direction": Vector2(-1, -0.5), "speed": 450}},
	{"time": 91.6, "type": "bullet_stream", "params": {"start_pos": Vector2(300, -50), "direction": Vector2(0, 1), "speed": 480}},
	{"time": 92.4, "type": "bullet_stream", "params": {"start_pos": Vector2(-50, 150), "direction": Vector2(1, 0.8), "speed": 460}},
	{"time": 93.2, "type": "bullet_stream", "params": {"start_pos": Vector2(650, 350), "direction": Vector2(-1, -0.3), "speed": 470}},
	{"time": 94.0, "type": "bullet_stream", "params": {"start_pos": Vector2(200, -50), "direction": Vector2(0.4, 1), "speed": 490}},
	{"time": 95.0, "type": "bullet_stream", "params": {"start_pos": Vector2(-50, 100), "direction": Vector2(1, 1), "speed": 500}},
	{"time": 95.8, "type": "bullet_stream", "params": {"start_pos": Vector2(650, 500), "direction": Vector2(-1, -1), "speed": 500}},
	{"time": 96.6, "type": "bullet_stream", "params": {"start_pos": Vector2(400, -50), "direction": Vector2(-0.2, 1), "speed": 510}},
	{"time": 97.4, "type": "bullet_stream", "params": {"start_pos": Vector2(-50, 300), "direction": Vector2(1, 0.2), "speed": 520}},
	{"time": 98.2, "type": "bullet_stream", "params": {"start_pos": Vector2(650, 200), "direction": Vector2(-1, 0.8), "speed": 530}},
	{"time": 99.0, "type": "bullet_stream", "params": {"start_pos": Vector2(100, -50), "direction": Vector2(0.7, 1), "speed": 540}},
	{"time": 100.0, "type": "bullet_stream", "params": {"start_pos": Vector2(-50, 250), "direction": Vector2(1, 0.6), "speed": 550}},
	{"time": 100.8, "type": "bullet_stream", "params": {"start_pos": Vector2(650, 450), "direction": Vector2(-1, -0.7), "speed": 560}},
	{"time": 101.6, "type": "bullet_stream", "params": {"start_pos": Vector2(500, -50), "direction": Vector2(-0.5, 1), "speed": 570}},
	{"time": 102.4, "type": "bullet_stream", "params": {"start_pos": Vector2(-50, 400), "direction": Vector2(1, -0.4), "speed": 580}},
	{"time": 103.2, "type": "bullet_stream", "params": {"start_pos": Vector2(650, 150), "direction": Vector2(-1, 0.9), "speed": 590}},
	{"time": 104.0, "type": "bullet_stream", "params": {"start_pos": Vector2(250, -50), "direction": Vector2(0.1, 1), "speed": 600}},
	{"time": 105.0, "type": "bullet_stream", "params": {"start_pos": Vector2(-50, 350), "direction": Vector2(1, -0.2), "speed": 610}},
	{"time": 106.0, "type": "bullet_stream", "params": {"start_pos": Vector2(650, 100), "direction": Vector2(-1, 1.2), "speed": 620}},
	{"time": 107.0, "type": "bullet_stream", "params": {"start_pos": Vector2(350, -50), "direction": Vector2(-0.3, 1), "speed": 630}},
	{"time": 108.0, "type": "bullet_stream", "params": {"start_pos": Vector2(-50, 500), "direction": Vector2(1, -0.8), "speed": 640}},
	{"time": 109.0, "type": "bullet_stream", "params": {"start_pos": Vector2(650, 300), "direction": Vector2(-1, 0.1), "speed": 650}},
	{"time": 110.0, "type": "bullet_stream", "params": {"start_pos": Vector2(450, -50), "direction": Vector2(-0.6, 1), "speed": 660}},
	{"time": 111.0, "type": "bullet_stream", "params": {"start_pos": Vector2(-50, 180), "direction": Vector2(1, 0.7), "speed": 670}},
	{"time": 112.0, "type": "bullet_stream", "params": {"start_pos": Vector2(650, 420), "direction": Vector2(-1, -0.4), "speed": 680}},
	{"time": 113.0, "type": "bullet_stream", "params": {"start_pos": Vector2(150, -50), "direction": Vector2(0.9, 1), "speed": 690}},
	{"time": 114.0, "type": "bullet_stream", "params": {"start_pos": Vector2(-50, 280), "direction": Vector2(1, 0.3), "speed": 700}},
	{"time": 115.0, "type": "bullet_stream", "params": {"start_pos": Vector2(650, 380), "direction": Vector2(-1, -0.6), "speed": 720}},
	{"time": 116.0, "type": "bullet_stream", "params": {"start_pos": Vector2(300, -50), "direction": Vector2(0, 1), "speed": 750}},
	{"time": 117.0, "type": "bullet_stream", "params": {"start_pos": Vector2(-50, 220), "direction": Vector2(1, 0.9), "speed": 780}},
	{"time": 118.0, "type": "bullet_stream", "params": {"start_pos": Vector2(650, 320), "direction": Vector2(-1, -0.1), "speed": 800}},
]

# Attack scene references - Currently only bullet_stream implemented
var attack_scenes = {
	"bullet_stream": preload("res://scenes/attacks/BulletStreamAttack.tscn"),
	# TODO: Add more attack types when implemented
	# "bullet_spiral": preload("res://scenes/attacks/BulletSpiralAttack.tscn"),
	# "bullet_wave": preload("res://scenes/attacks/BulletWaveAttack.tscn"),
	# "bullet_circle": preload("res://scenes/attacks/BulletCircleAttack.tscn"),
	# "bullet_cross": preload("res://scenes/attacks/BulletCrossAttack.tscn"),
}

# Phase definitions
var phases = [
	{"start_time": 0.0, "end_time": 30.0, "name": "Introduction", "difficulty": 1.0},
	{"start_time": 30.0, "end_time": 60.0, "name": "Escalation", "difficulty": 1.5},
	{"start_time": 60.0, "end_time": 90.0, "name": "Intensity", "difficulty": 2.0},
	{"start_time": 90.0, "end_time": 120.0, "name": "Final Challenge", "difficulty": 2.5},
]

func _ready():
	#start_game()
	# Connect to attack cleanup
	connect_attack_cleanup()

func start_game():
	is_game_active = true
	game_timer = 0.0
	current_attack_index = 0
	current_phase = 1
	difficulty_multiplier = 1.0
	active_attacks.clear()
	print("Game started! Survive for ", game_duration, " seconds!")
	print("Phase 1: Introduction - Simple attacks incoming...")

func _process(delta):
	if not is_game_active:
		return
	
	game_timer += delta
	
	# Update difficulty and phase
	update_game_phase()
	update_difficulty()
	
	# Check for attacks to spawn
	check_and_spawn_attacks()
	
	# Clean up finished attacks
	cleanup_finished_attacks()
	
	# Check for game completion
	if game_timer >= game_duration:
		complete_game()
		
	hud.update_timer(int(game_timer), int(game_duration))

func update_game_phase():
	var new_phase = get_current_phase()
	if new_phase != current_phase:
		current_phase = new_phase
		var phase_info = phases[current_phase - 1]
		print("Phase ", current_phase, ": ", phase_info.name)
		phase_changed.emit(current_phase)

func update_difficulty():
	# Gradually increase difficulty over time
	var phase_info = phases[get_current_phase() - 1]
	difficulty_multiplier = phase_info.difficulty + (game_timer / game_duration) * 0.5

func get_current_phase() -> int:
	for i in range(phases.size()):
		var phase = phases[i]
		if game_timer >= phase.start_time and game_timer < phase.end_time:
			return i + 1
	return phases.size()  # Final phase

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
	
	# Check if we have the scene for this attack type
	if not attack_scenes.has(attack_type):
		print("Warning: Attack type '", attack_type, "' not found in attack_scenes!")
		return
	
	var attack_instance = attack_scenes[attack_type].instantiate()
	
	# Apply difficulty scaling to parameters
	apply_difficulty_scaling(params)
	
	# Set common parameters that most attacks should support
	configure_attack_instance(attack_instance, params)
	
	if attack_instance:
		add_child(attack_instance)
		active_attacks.append(attack_instance)
		attack_spawned.emit(attack_type, game_timer)
		print("Spawned attack: ", attack_type, " at time: %.1f" % game_timer, " (Phase ", current_phase, ")")

func apply_difficulty_scaling(params: Dictionary):
	# Scale speed parameters based on difficulty
	if params.has("speed"):
		params.speed *= difficulty_multiplier
	
	# Increase bullet count for circle attacks
	if params.has("bullets"):
		params.bullets = int(params.bullets * difficulty_multiplier)
	
	# Increase wave frequency and amplitude
	if params.has("frequency"):
		params.frequency *= difficulty_multiplier
	if params.has("amplitude"):
		params.amplitude *= (1.0 + (difficulty_multiplier - 1.0) * 0.5)

func configure_attack_instance(attack_instance: Node, params: Dictionary):
	# Set parameters that are commonly supported by attack instances
	for param_name in params:
		var param_value = params[param_name]
		
		# Use set() to set properties dynamically if they exist
		if attack_instance.has_method("set_" + param_name):
			attack_instance.call("set_" + param_name, param_value)
		elif param_name in attack_instance:
			attack_instance.set(param_name, param_value)

func connect_attack_cleanup():
	# Connect to attack completion signals if your attacks emit them
	# This helps with memory management
	pass

func cleanup_finished_attacks():
	# Remove attacks that have finished or are no longer valid
	active_attacks = active_attacks.filter(func(attack): return is_instance_valid(attack) and attack.get_parent() != null)

func complete_game():
	is_game_active = false
	print("🎉 CONGRATULATIONS! 🎉")
	print("You survived all ", game_duration, " seconds!")
	print("Final Phase: ", phases[current_phase - 1].name, " completed!")
	print("Total attacks survived: ", current_attack_index)
	game_complete.emit()

# Utility functions for external systems
func get_remaining_time() -> float:
	return max(0.0, game_duration - game_timer)

func get_completion_percentage() -> float:
	return (game_timer / game_duration) * 100.0

func get_current_phase_info() -> Dictionary:
	return phases[get_current_phase() - 1]

func get_active_attack_count() -> int:
	return active_attacks.size()

func get_difficulty_multiplier() -> float:
	return difficulty_multiplier

# Debug functions
func skip_to_phase(phase_number: int):
	if phase_number > 0 and phase_number <= phases.size():
		game_timer = phases[phase_number - 1].start_time
		print("Skipped to Phase ", phase_number)

func add_time(seconds: float):
	game_timer += seconds

# Emergency stop for testing
func stop_game():
	is_game_active = false
	# Clean up all active attacks
	for attack in active_attacks:
		if is_instance_valid(attack):
			attack.queue_free()
	active_attacks.clear()
