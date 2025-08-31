extends Node2D

@onready var anim:AnimatedSprite2D = $AnimatedSprite 
@onready var fx:CPUParticles2D = $CPUParticles2D

@export var playOnStart:bool = true 

func _ready():
	anim.animation_finished.connect(_on_AnimatedSprite_animation_finished)
	anim.visible = false
	fx.visible = false
	if playOnStart:
		play()
	
func play():
	anim.visible = true
	fx.visible = true
	self.rotation = randf_range(0, 2 * PI)
	anim.play("default")
	fx.emitting = true

func _on_AnimatedSprite_animation_finished():
	queue_free()
