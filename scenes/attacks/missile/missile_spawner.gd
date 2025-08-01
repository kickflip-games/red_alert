extends Node2D

@export var missile_scene: PackedScene # Assign your missile scene in the inspector
@export var spawn_delay: float = 2.0
@export var spawn_radius: float = 600.0

var active_missiles: Array[Node] = []
var player: Node2D
var can_spawn:bool = true

func _ready():
	# Find the player
	player = get_tree().get_first_node_in_group("player")
	
	can_spawn = false

func _process(delta):
	# Clean up destroyed missiles from our tracking array
	active_missiles = active_missiles.filter(func(missile): return is_instance_valid(missile))
	
	# Always ensure at least one missile exists
	if active_missiles.is_empty() and can_spawn:
		spawn_missile()
	

func spawn_missile():
	if not missile_scene or not player:
		print("Missing missile scene or player reference")
		return
	
	var missile = missile_scene.instantiate()
	
	# Spawn missile at a random position around the player, outside the screen
	var angle = randf() * TAU
	var spawn_position = global_position + Vector2.RIGHT.rotated(angle) * spawn_radius
	
	missile.global_position = spawn_position
	
	# Add to scene and track it
	get_tree().current_scene.add_child.call_deferred(missile)
	active_missiles.append(missile)
	
	print("Spawned missile at: ", spawn_position)
