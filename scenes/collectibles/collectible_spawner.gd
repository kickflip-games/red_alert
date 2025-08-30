extends Node2D

signal score_updated(new_score)
signal letter_collected(letter, word_progress)
signal word_completed(word)

@export var collectible_scene: PackedScene
@export var spawn_margin: float = 50.0
@export var min_distance_from_player: float = 100.0

var current_collectible: RigidBody2D = null
var player_reference: Node2D = null
var screen_size: Vector2
var total_score: int = 0

# Word spelling system
var target_word: String = "BISCUIT"
var collected_letters: Array[String] = []
var current_letter_index: int = 0

func _ready():
	screen_size = get_viewport().get_visible_rect().size
	
	# Find player reference
	player_reference = get_tree().get_first_node_in_group("player")
	if not player_reference:
		print("Warning: No player found in 'player' group")
	
	# Spawn first collectible
	spawn_collectible()

func spawn_collectible():
	if not collectible_scene:
		print("Error: No collectible scene assigned to spawner")
		return
	
	# Don't spawn if one already exists
	if current_collectible and is_instance_valid(current_collectible):
		return
	
	# Create new collectible
	current_collectible = collectible_scene.instantiate()
	
	# Set up the current letter
	var current_letter = target_word[current_letter_index]
	print("CURRENT LETTER ", current_letter)
	current_collectible.setup_letter(current_letter)
	
	# Find safe spawn position
	var spawn_position = get_safe_spawn_position()
	current_collectible.global_position = spawn_position
	
	# Connect collection signal
	current_collectible.collected.connect(_on_collectible_collected)
	
	# Add to scene
	add_child(current_collectible)

func get_safe_spawn_position() -> Vector2:
	var attempts = 0
	var max_attempts = 20
	
	while attempts < max_attempts:
		var x = randf_range(spawn_margin, screen_size.x - spawn_margin)
		var y = randf_range(spawn_margin, screen_size.y - spawn_margin)
		var potential_position = Vector2(x, y)
		
		# Check distance from player
		if player_reference:
			var distance_to_player = potential_position.distance_to(player_reference.global_position)
			if distance_to_player >= min_distance_from_player:
				return potential_position
		else:
			return potential_position
		
		attempts += 1
	
	# Fallback: spawn at center if all attempts failed
	return screen_size * 0.5

func _on_collectible_collected(letter: String, points: int):
	total_score += points
	collected_letters.append(letter)
	
	# Emit signals
	score_updated.emit(total_score)
	letter_collected.emit(letter, get_word_progress())
	
	# Check if we completed the word
	if collected_letters.size() == target_word.length():
		word_completed.emit(target_word)
		reset_word_progress()
	else:
		# Move to next letter
		current_letter_index += 1
	
	# Clear reference to collected item
	current_collectible = null
	
	# Spawn next collectible after short delay
	await get_tree().create_timer(0.5).timeout
	spawn_collectible()

func get_word_progress() -> String:
	"""Returns the current progress like 'BIS___' """
	var progress = ""
	for i in range(target_word.length()):
		if i < collected_letters.size():
			progress += collected_letters[i]
		else:
			progress += "_"
	return progress

func reset_word_progress():
	"""Reset to start collecting the word again"""
	collected_letters.clear()
	current_letter_index = 0

func get_current_score() -> int:
	return total_score

func get_target_word() -> String:
	return target_word

func get_next_letter() -> String:
	if current_letter_index < target_word.length():
		return target_word[current_letter_index]
	return ""

func force_spawn():
	# Utility function to manually spawn collectible
	if current_collectible and is_instance_valid(current_collectible):
		current_collectible.queue_free()
	
	spawn_collectible()
