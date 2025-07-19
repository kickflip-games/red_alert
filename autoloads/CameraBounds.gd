# CameraBounds.gd
extends Node

var camera: Camera2D
var rect: Rect2
var viewport_size: Vector2


@export var spawn_padding := 50.0

func _process(_delta):
	if camera:
		_update_bounds()

func _update_bounds():
	viewport_size = get_viewport().get_visible_rect().size
	var half_size = viewport_size * 0.5 * camera.zoom
	var camera_pos = camera.global_position
	rect = Rect2(camera_pos - half_size, viewport_size * camera.zoom)

func get_spawn_position(outside_direction: Vector2) -> Vector2:
	if not camera:
		return Vector2.ZERO
	var center = rect.position + rect.size * 0.5
	var offset = rect.size * 0.5 + Vector2(spawn_padding, spawn_padding)
	return center + outside_direction.normalized() * offset
