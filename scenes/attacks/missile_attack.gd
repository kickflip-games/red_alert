extends BaseAttack
class_name MissileAttack

@export var missile_scene: PackedScene # Assign your missile scene in the inspector
@export var spawn_delay: float = 2.0
@export var spawn_radius: float = 600.0
@export var max_num_active: int = 4
@export var missile_count: int = 8 # Total missiles to spawn during attack
@export var fire_rate: float = 0.5 # Time between missile spawns
@export var show_spawn_radius: bool = true # Show spawn radius in editor

var active_missiles: Array[Node] = []
var player: Node2D
var _spawn_timer: float = 0.0
var _missiles_spawned: int = 0

func _ready():
	super._ready()
	
	# Find the player
	player = get_tree().get_first_node_in_group("player")
	if not player:
		push_error("No player found in 'player' group for MissileAttack")

func _process(delta):
	if not is_processing():
		return
	
	# Clean up destroyed missiles from our tracking array
	active_missiles = active_missiles.filter(func(missile): return is_instance_valid(missile))
	
	# Check if we've completed the attack
	if _missiles_spawned >= missile_count:
		if not _completed:
			attack_completed.emit(self)
			_completed = true
		return
	
	# Spawn missiles based on fire rate and active limit
	_spawn_timer += delta
	if _spawn_timer >= fire_rate and len(active_missiles) < max_num_active:
		spawn_missile()
		_spawn_timer = 0.0

func execute_attack():
	super.execute_attack()
	_spawn_timer = 0.0
	_missiles_spawned = 0

func spawn_missile():
	if not missile_scene or not player or _missiles_spawned >= missile_count:
		return
	
	# Don't spawn if we've hit the active limit
	if len(active_missiles) >= max_num_active:
		return
	
	var missile = missile_scene.instantiate()
	
	# Spawn missile around the player, just off-screen
	var angle = randf() * TAU
	var spawn_position = player.global_position + Vector2.RIGHT.rotated(angle) * spawn_radius
	
	missile.global_position = spawn_position
	
	# Add to scene and track it
	get_tree().current_scene.add_child.call_deferred(missile)
	active_missiles.append(missile)
	_missiles_spawned += 1
	
	# Play shooting sound effect
	SoundManager.play_sound_with_pitch(SHOOT_SFX, randf_range(0.8, 1.2))
	
	#print("Spawned missile at: ", spawn_position, " (", _missiles_spawned, "/", missile_count, ")")

func _immediate_cleanup():
	_cleanup_missiles(0)
	super._immediate_cleanup()

func cleanup():
	_cleanup_missiles(20)
	super.cleanup()

func _cleanup_missiles(cleanup_after: float = 20):
	await get_tree().create_timer(cleanup_after).timeout
	for missile in active_missiles:
		if is_instance_valid(missile):
			missile.queue_free()
	active_missiles.clear()

# Editor visualization
func _draw():
	if not Engine.is_editor_hint() or not show_spawn_radius:
		return
	
	# Draw spawn radius circle around player position (if player exists)
	if player:
		var local_player_pos = to_local(player.global_position)
		draw_arc(local_player_pos, spawn_radius, 0, TAU, 64, Color.CYAN, 2.0)
		draw_circle(local_player_pos, 5, Color.CYAN) # Mark player position
	else:
		# Fallback: draw around attack position if no player
		draw_arc(Vector2.ZERO, spawn_radius, 0, TAU, 64, Color.RED, 2.0)

# Update editor display when properties change
func _validate_property(property):
	if property.name in ["spawn_radius", "show_spawn_radius"] and Engine.is_editor_hint():
		queue_redraw()
