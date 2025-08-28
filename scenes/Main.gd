extends Node2D

# Game states
enum GameState {
	START_SCREEN,
	PLAYING,
	GAME_OVER
}

var current_state = GameState.START_SCREEN
var game_timer: float = 0.0
var is_timer_running: bool = false

# UI references
@onready var start_screen = $HUD/StartScreen
@onready var end_screen = $HUD/EndScreen
@onready var game_ui = $HUD/GameUi
@onready var start_button = $HUD/StartScreen/StartButton
@onready var restart_button = $HUD/EndScreen/RestartButton
@onready var player = $Player
@onready var attack_manager = $AttackManager
#@onready var missile_spawner = $MissileSpawner
const GAME_MUSIC = preload("res://assets/audio/music/game_music.ogg")


func _ready():
	# Connect button signals
	start_button.pressed.connect(_on_start_button_pressed)
	restart_button.pressed.connect(_on_restart_button_pressed)
	player.player_died.connect(player_died)
	attack_manager.game_complete.connect(show_game_over)
	
	# Initialize screens
	show_start_screen()
	
	$AudioStreamPlayer.stream = GAME_MUSIC

func _process(delta):
	if current_state == GameState.PLAYING and is_timer_running:
		game_timer += delta
		# Update your game logic here

func show_start_screen():
	current_state = GameState.START_SCREEN
	start_screen.visible = true
	end_screen.visible = false
	game_ui.visible = false
	
	# Pause game elements
	get_tree().paused = false  # UI can still work
	# Stop any game processes

func start_game():
	current_state = GameState.PLAYING
	start_screen.visible = false
	end_screen.visible = false
	game_ui.visible = true
	
	# Reset game state
	game_timer = 0.0
	is_timer_running = true
	
	# Initialize/reset your game objects
	attack_manager.start_game()
	#missile_spawner.can_spawn = true
	# etc.
	$AudioStreamPlayer.play()

func show_game_over():
	#missile_spawner.can_spawn = false
	
	if current_state == GameState.GAME_OVER:
		return
	
	current_state = GameState.GAME_OVER
	is_timer_running = false
	
	# Fade to black effect
	var tween = create_tween()
	var fade_overlay = ColorRect.new()
	fade_overlay.color = Color.BLACK
	fade_overlay.color.a = 0.0
	fade_overlay.size = get_viewport().size
	add_child(fade_overlay)
	
	tween.tween_property(fade_overlay, "color:a", 1.0, 1.0)
	await tween.finished
	
	# Show end screen
	game_ui.visible = false
	end_screen.visible = true
	$AudioStreamPlayer.stop()
	
	
	if attack_manager.game_timer >= attack_manager.game_duration:
		$HUD/EndScreen/GameTxt.text = "You survived!"
	else:
		$HUD/EndScreen/GameTxt.text = "Died after %d seconds" % int(attack_manager.game_timer)
	
	# Remove fade overlay
	fade_overlay.queue_free()

func _on_start_button_pressed():
	print("START GAME")
	start_game()

func _on_restart_button_pressed():
	get_tree().reload_current_scene()

# Call this when player dies
func player_died():
	show_game_over()
