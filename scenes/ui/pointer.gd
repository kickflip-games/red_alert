class_name Pointer
extends Node2D

@export var player: Node2D
@export var target: Node2D
@onready var arrow: Sprite2D = $Sprite2D
@onready var label: RichTextLabel = $RichTextLabel

# Animation params
var init_scale: Vector2
var pulse_speed: float = 3.0     # how fast it pulses
var pulse_strength: float = 0.05 # how much it scales up/down
var alpha_pulse_strength: float = 0.4 # how much transparency change (0-1)

func set_refs(p: Node2D, t: Node2D) -> void:
	player = p
	target = t

func _ready() -> void:
	init_scale = arrow.scale

func _process(delta: float) -> void:
	if not player or not target:
		return

	# Midpoint between player and target
	global_position = (player.global_position + target.global_position) * 0.5

	# Direction vector
	var direction: Vector2 = target.global_position - player.global_position
	arrow.rotation = direction.angle()

	# Animate sprite scale (relative to original scale)
	var pulse = 1.0 + pulse_strength * sin(Time.get_ticks_msec() / 1000.0 * pulse_speed)
	arrow.scale = init_scale * pulse

	# Fade alpha up and down (white base color)
	var alpha = 1.0 - alpha_pulse_strength * (0.5 * (1.0 + sin(Time.get_ticks_msec() / 1000.0 * pulse_speed)))
	arrow.modulate = Color(1, 1, 1, alpha)

	# Place label just "behind" arrow, along the line
	var label_offset = -direction.normalized() * (arrow.texture.get_height() * arrow.scale.y * 0.6)
	label.position = label_offset
