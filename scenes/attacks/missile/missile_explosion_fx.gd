extends Node2D

@onready var anim = $AnimatedSprite 

func _ready():
	self.rotation = randf_range(0, 2 * PI)
	anim.play("default")
	anim.animation_finished.connect(_on_AnimatedSprite_animation_finished)
	$GPUParticles2D.emitting = true

func _on_AnimatedSprite_animation_finished():
	queue_free()
