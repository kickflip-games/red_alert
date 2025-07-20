extends CanvasLayer
class_name HUD

@export var player: Node
@export var heart_full_texture: Texture2D
@export var heart_empty_texture: Texture2D

@onready var hp_label := $GameUi/HPLabel
@onready var dash_bar := $GameUi/DashCooldownBar
@onready var hearts := $GameUi/Hearts
@onready var timer_label:= $GameUi/TimerLabel
@onready var tween := create_tween()

func _ready():
	player.connect("hp_changed", _on_hp_changed)
	player.connect("dash_cooldown_updated", _on_dash_cooldown_updated)
	update_hearts(player.current_hp)  # initialize
	$GameUi.visible = false
	$EndScreen.visible = false
	

func _on_hp_changed(current_hp: int):
	hp_label.text = "HP: %d" % current_hp
	update_hearts(current_hp)

func _on_dash_cooldown_updated(percent_ready: float):
	dash_bar.value = percent_ready * 100.0


func update_hearts(current_hp: int):
	for i in range(hearts.get_child_count()):
		var heart = hearts.get_child(i)
		var target_texture = heart_full_texture if i < current_hp else heart_empty_texture

		if heart.texture != target_texture:
			var original_scale = heart.scale
			tween.kill()  # kill previous tween to avoid overlap
			tween = create_tween()
			heart.texture = target_texture
			heart.scale = Vector2(1.5, 1.5)
			tween.tween_property(heart, "scale", original_scale, 3).set_trans(Tween.TRANS_BOUNCE)
		else:
			heart.texture = target_texture


func update_timer(current_time:int, max_time:int):
	timer_label.text = "%02d/%d seconds" % [int(current_time), int(max_time)]
	
