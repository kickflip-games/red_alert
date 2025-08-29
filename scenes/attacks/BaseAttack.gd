extends Node2D
class_name BaseAttack

@export var warning_duration: float = 1.0
@export var attack_duration: float = 1.0

var warning_node: Node2D
var warning_tween: Tween
var _completed: bool = false
const ALERT_SFX = preload("res://assets/audio/sfx/alarm-sound-OGG.ogg")
const SHOOT_SFX = preload("res://assets/audio/sfx/bullet-sound-OGG.ogg")

signal attack_completed(attack: BaseAttack)

func _ready():
	warning_node = $warning_graphics
	if not warning_node:
		push_error("Warning graphics are not set in this attack")
		return
	
	$warning_graphics/Sprite2D.rotation = -global_rotation
	warning_node.visible = false
	set_process(false)

func start_attack():
	visible = true
	show_warning()
	await get_tree().create_timer(warning_duration).timeout
	
	# Switch to attack phase
	hide_warning()
	execute_attack()
	
	# Wait for attack duration
	await get_tree().create_timer(attack_duration).timeout
	cleanup()

func stop_attack():
	set_process(false)
	hide_warning()
	_immediate_cleanup()

# --- Overridable methods for subclasses ---
func show_warning():
	if not is_instance_valid(warning_node):
		push_warning("Warning node is invalid, cannot show warning.")
		return
	
	warning_node.visible = true
	SoundManager.play_sound_with_pitch(ALERT_SFX, randf_range(0.5, 1.0))
	
	# Use safe tween management
	_safe_kill_tween(warning_tween)
	warning_tween = _create_safe_tween()
	
	warning_tween.set_loops() \
				 .set_trans(Tween.TRANS_SINE) \
				 .set_ease(Tween.EASE_IN_OUT)
	
	var start_alpha := warning_node.modulate.a
	var target_alpha := start_alpha * 0.2
	
	warning_tween.tween_property(warning_node, "modulate:a", target_alpha, warning_duration / 4)
	warning_tween.tween_property(warning_node, "modulate:a", start_alpha, warning_duration / 4)

func hide_warning():
	if not is_instance_valid(warning_node):
		return
	
	_safe_kill_tween(warning_tween)
	warning_node.visible = false
	# Reset alpha for next use
	warning_node.modulate.a = 1.0

func execute_attack():
	# Subclasses implement their attack logic here
	set_process(true)

func _immediate_cleanup():
	"""
	Subclasses should override this to perform cleanup if attack is stopped prematurely
	E.g., stopping active timers, freeing unmanaged nodes
	"""
	_safe_kill_tween(warning_tween)
	set_process(false)

func cleanup():
	"""
	Normal cleanup after attack completion
	Subclasses can override this for additional cleanup
	"""
	_safe_kill_tween(warning_tween)
	_completed = true
	attack_completed.emit(self)

# --- Utility functions ---
func _safe_kill_tween(tween_ref: Tween):
	if tween_ref and tween_ref.is_valid():
		tween_ref.kill()

func _create_safe_tween() -> Tween:
	return create_tween()

func is_completed() -> bool:
	return _completed
