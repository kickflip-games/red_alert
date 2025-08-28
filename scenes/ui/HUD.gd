extends CanvasLayer
class_name HUD

@export var player: Node
@export var heart_full_texture: Texture2D
@export var heart_empty_texture: Texture2D

@onready var hp_label := $GameUi/HPLabel
@onready var dash_bar := $GameUi/DashCooldownBar
@onready var hearts := $GameUi/Hearts
@onready var timer_label := $GameUi/TimerLabel
@onready var wave_label := $GameUi/WaveDebugLabel

# Tween management for hearts
var heart_tweens: Array[Tween] = []

func _ready():
	if not player:
		push_error("Player node not assigned to HUD")
		return
	
	player.connect("hp_changed", _on_hp_changed)
	player.connect("dash_cooldown_updated", _on_dash_cooldown_updated)
	
	update_hearts(player.current_hp)
	$GameUi.visible = false
	$EndScreen.visible = false

func _on_hp_changed(current_hp: int):
	hp_label.text = "HP: %d" % current_hp
	update_hearts(current_hp)

func _on_dash_cooldown_updated(percent_ready: float):
	dash_bar.value = percent_ready * 100.0

func update_hearts(current_hp: int):
	# Ensure we have enough tween slots
	_resize_tween_array()
	
	for i in range(hearts.get_child_count()):
		var heart = hearts.get_child(i)
		if not is_instance_valid(heart):
			continue
		
		var target_texture = heart_full_texture if i < current_hp else heart_empty_texture
		
		if heart.texture != target_texture:
			_animate_heart_change(heart, target_texture, i)
		else:
			heart.texture = target_texture

func _animate_heart_change(heart: Node, target_texture: Texture2D, heart_index: int):
	var original_scale: Vector2 = heart.scale
	
	# Apply the texture and overscale immediately
	heart.texture = target_texture
	heart.scale = Vector2(1.5, 1.5)
	
	# Kill any existing tween for this heart
	_safe_kill_heart_tween(heart_index)
	
	# Create new tween
	heart_tweens[heart_index] = _create_safe_tween()
	heart_tweens[heart_index].tween_property(heart, "scale", original_scale, 0.3) \
							 .set_trans(Tween.TRANS_BOUNCE) \
							 .set_ease(Tween.EASE_OUT)

func update_timer(current_time: int, max_time: int):
	timer_label.text = "%02d/%d seconds" % [int(current_time), int(max_time)]

# --- Tween Management ---
func _resize_tween_array():
	var needed_size = hearts.get_child_count()
	heart_tweens.resize(needed_size)

func _safe_kill_heart_tween(index: int):
	if index < heart_tweens.size() and heart_tweens[index] and heart_tweens[index].is_valid():
		heart_tweens[index].kill()
		heart_tweens[index] = null

func _create_safe_tween() -> Tween:
	return create_tween()

func cleanup_tweens():
	"""Call this when the HUD is being destroyed or reset"""
	for i in range(heart_tweens.size()):
		_safe_kill_heart_tween(i)
	heart_tweens.clear()
