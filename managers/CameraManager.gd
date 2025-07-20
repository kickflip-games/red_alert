extends Camera2D


@export var debug_draw_bounds := true

func _ready():
	CameraBounds.camera = self


func _draw():
	if debug_draw_bounds:
		debug_draw(self)

func _process(_delta):
	queue_redraw()
	
	
func debug_draw(draw_target: Node2D):
	if debug_draw_bounds:
		var top_left_local = draw_target.to_local(CameraBounds.rect.position)
		draw_target.draw_rect(Rect2(top_left_local, CameraBounds.rect.size), Color.BLACK, false, 2)
		
