class_name StoryFridge
extends Node2D
# the fridge the lactose guy shuffles towards while his back is to us in the intro.

const PICTURE := "res://art/sprites/fridge.png"
const HEIGHT := 150.0

var _texture: Texture2D
var _age := 0.0


func _ready() -> void:
	_texture = load(PICTURE)


func _process(delta: float) -> void:
	_age += delta / maxf(Engine.time_scale, 0.001)
	modulate.a = clampf(_age * 5.0, 0.0, 1.0)  # quick fade-in so it doesn't just blink on


func _draw() -> void:
	if _texture == null:
		return
	# origin is the floor under the fridge's centre.
	var wide := HEIGHT * _texture.get_width() / _texture.get_height()
	draw_texture_rect(_texture, Rect2(-wide / 2.0, -HEIGHT, wide, HEIGHT), false)
