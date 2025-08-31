extends Node2D

signal score_updated(new_score)
signal letter_collected(letter, word_progress)
signal word_completed(word)

@export var collectible_scene: PackedScene
@export var spawn_margin: float = 50.0
@export var min_distance_from_player: float = 100.0
@export var game_duration: float = 100.0
@export var min_spawn_interval: float = 12  # Minimum seconds between spawns

var current_collectible: RigidBody2D = null
var player_reference: Node2D = null
var screen_size: Vector2
var total_score: int = 0

# Word spelling system
var target_word: String = "BISCUIT"
var collected_letters: Array[String] = []
var current_letter_index: int = 0
var total_words_completed: int = 0

# Timing control
var game_start_time: float
var last_spawn_time: float = 0.0
var can_spawn: bool = true
var spawn_timer: Timer

func _ready():
	screen_size = get_viewport().get_visible_rect().size
	game_start_time = Time.get_time_dict_from_system().hour * 3600 + Time.get_time_dict_from_system().minute * 60 + Time.get_time_dict_from_system().second
	
	# Create spawn timer
	spawn_timer = Timer.new()
	spawn_timer.wait_time = min_spawn_interval
	spawn_timer.one_shot = true
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(spawn_timer)
	
	# Find player reference
	player_reference = get_tree().get_first_node_in_group("player")
	if not player_reference:
		print("Warning: No player found in 'player' group")
	
	# Spawn first collectible immediately
	#spawn_collectible()

func _process(_delta):
	# Check if game time has exceeded duration
	var current_time = Time.get_time_dict_from_system().hour * 3600 + Time.get_time_dict_from_system().minute * 60 + Time.get_time_dict_from_system().second
	var elapsed_time = current_time - game_start_time
	
	if elapsed_time >= game_duration:
		can_spawn = false

func spawn_collectible():
	if not collectible_scene:
		print("Error: No collectible scene assigned to spawner")
		return
	
	# Don't spawn if one already exists
	if current_collectible and is_instance_valid(current_collectible):
		return
	
	# Don't spawn if game time is up or we've completed all possible words
	if not can_spawn:
		return
	
	# Check if we've collected all letters for all possible completions within game time
	var max_possible_completions = int(game_duration / (target_word.length() * min_spawn_interval))
	if total_words_completed >= max_possible_completions:
		print("Maximum words completed for game duration reached")
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
	current_collectible.collected.connect(on_collectible_collected)
	
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

func on_collectible_collected(letter: String, points: int):
	total_score += points
	collected_letters.append(letter)
	
	# Emit signals
	score_updated.emit(total_score)
	letter_collected.emit(letter, get_word_progress())
	
	# Check if we completed the word
	if collected_letters.size() == target_word.length():
		total_words_completed += 1
		word_completed.emit(target_word)
		reset_word_progress()
		print("Word completed! Total completions: ", total_words_completed)
	else:
		# Move to next letter
		current_letter_index += 1
	
	# Clear reference to collected item
	current_collectible = null
	
	# Start spawn timer to enforce minimum interval
	spawn_timer.start()

func _on_spawn_timer_timeout():
	# Only spawn if we're still within game time and haven't completed too many words
	if can_spawn:
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

func get_words_completed() -> int:
	return total_words_completed

func get_time_remaining() -> float:
	var current_time = Time.get_time_dict_from_system().hour * 3600 + Time.get_time_dict_from_system().minute * 60 + Time.get_time_dict_from_system().second
	var elapsed_time = current_time - game_start_time
	return max(0, game_duration - elapsed_time)

func force_spawn():
	# Utility function to manually spawn collectible (respects timing constraints)
	if current_collectible and is_instance_valid(current_collectible):
		current_collectible.queue_free()
	
	if can_spawn and not spawn_timer.time_left > 0:
		spawn_collectible()
