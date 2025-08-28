extends Node
class_name AttackManager

signal game_complete
signal phase_changed(new_phase: int) # For overall game phases

var game_duration:float = 0
@export var hud: HUD # Assuming HUD is a Node that needs updates
@export var attack_waves_container: Node # Assign a Node2D in your scene to hold the AttackWave instances

var game_timer: float = 0.0
var is_game_active: bool = false
var current_wave_index: int = -1 # -1 means no wave active yet
var active_wave: AttackWave = null

# Phase definitions (still useful for overall game progression/difficulty)
var phases = [
	{"start_time": 0.0, "end_time": 30.0, "name": "Introduction", "difficulty_multiplier": 1.0},
	{"start_time": 30.0, "end_time": 60.0, "name": "Escalation", "difficulty_multiplier": 1.5},
	{"start_time": 60.0, "end_time": 90.0, "name": "Intensity", "difficulty_multiplier": 2.0},
	{"start_time": 90.0, "end_time": 120.0, "name": "Final Challenge", "difficulty_multiplier": 2.5},
]
var current_phase_data: Dictionary = {}

func _ready():
	if not attack_waves_container:
		printerr("Attack Waves Container not assigned to AttackManager!")
		set_process(false)

	# Ensure all AttackWave children are initially inactive
	for child in attack_waves_container.get_children():
		if child is AttackWave:
			child.is_active = false
			child.set_process(false)
			
			game_duration += child.total_duration 

func start_game():
	is_game_active = true
	game_timer = 0.0
	current_wave_index = -1
	active_wave = null

	print("Game started! Survive for ", game_duration, " seconds!")
	_update_phase_info()
	_run_wave_sequence()

func _process(delta):
	if not is_game_active:
		return

	game_timer += delta
	hud.update_timer(int(game_timer), int(game_duration))
	_update_phase_info()

	if game_timer >= game_duration:
		complete_game()

func _update_phase_info():
	var new_phase_index = -1
	for i in range(phases.size()):
		var phase = phases[i]
		if game_timer >= phase.start_time and game_timer < phase.end_time:
			new_phase_index = i
			break

	if new_phase_index == -1:
		new_phase_index = phases.size() - 1

	if len(current_phase_data) == 0 or current_phase_data != phases[new_phase_index]:
		current_phase_data = phases[new_phase_index]
		print("Phase ", new_phase_index + 1, ": ", current_phase_data.name, " (Difficulty: ", current_phase_data.difficulty_multiplier, ")")
		phase_changed.emit(new_phase_index + 1)

func _run_wave_sequence() -> void:
	await get_tree().create_timer(0.5).timeout # Initial delay

	while is_game_active and current_wave_index < attack_waves_container.get_child_count() - 1:
		current_wave_index += 1
		var wave = attack_waves_container.get_child(current_wave_index)

		_apply_difficulty_to_wave(wave, current_phase_data.difficulty_multiplier)
		await get_tree().create_timer(wave.start_delay).timeout

		if is_instance_valid(wave):
			wave.wave_complete.connect(_on_wave_finished)
			wave.wave_started.connect(_on_wave_started)
			wave.start_wave()
			await wave.wave_complete 


func _on_wave_finished(wave:AttackWave):
	print("▶️ Wave completed: ", wave.name, " [%d/%d]s"%[game_timer, game_duration])
	active_wave = null

func _on_wave_started(wave:AttackWave):
	print("▶️ Wave started: ", wave.name, " [%d/%d]s"%[game_timer, game_duration])
	active_wave = wave
	hud.wave_label.text = active_wave.get_parent().name + "/" + active_wave.name


func _apply_difficulty_to_wave(wave_node: AttackWave, multiplier: float):
	for child_attack in wave_node.get_children():
		if child_attack is BulletStreamAttack:
			child_attack.speed *= multiplier
			child_attack.fire_rate /= multiplier
			child_attack.attack_duration *= (1.0 + (multiplier - 1.0) * 0.2)

func complete_game():
	is_game_active = false
	print("🎉 CONGRATULATIONS! 🎉")
	print("You survived all ", game_duration, " seconds!")
	print("Final Phase: ", current_phase_data.name, " completed!")
	game_complete.emit()

	for child in attack_waves_container.get_children():
		if child is AttackWave and is_instance_valid(child):
			child.stop_wave()

func get_remaining_time() -> float:
	return max(0.0, game_duration - game_timer)

func get_completion_percentage() -> float:
	return (game_timer / game_duration) * 100.0

func get_current_phase_info() -> Dictionary:
	return current_phase_data

func get_difficulty_multiplier() -> float:
	return current_phase_data.difficulty_multiplier

func skip_to_time(time_in_seconds: float):
	game_timer = clamp(time_in_seconds, 0.0, game_duration)
	current_wave_index = -1
	active_wave = null

	var accumulated_time = 0.0
	for i in range(attack_waves_container.get_child_count()):
		var wave = attack_waves_container.get_child(i) as AttackWave
		if not wave:
			continue

		var wave_start_time = accumulated_time + wave.start_delay
		var wave_end_time = wave_start_time + wave.wave_duration
		var next_wave_start_time = wave_end_time + wave.end_delay

		if game_timer >= wave_start_time and game_timer < next_wave_start_time:
			current_wave_index = i
			active_wave = wave
			wave.current_wave_timer = game_timer - wave_start_time
			wave.start_wave()
			print("⏩ Skipped to time: %.1f. Activated Wave %d." % [game_timer, i + 1])
			return

		accumulated_time = next_wave_start_time

	print("⏩ Skipped to time: %.1f. No active wave found." % game_timer)

func stop_game():
	is_game_active = false
	for child_wave in attack_waves_container.get_children():
		if is_instance_valid(child_wave) and child_wave is AttackWave:
			child_wave.stop_wave()
