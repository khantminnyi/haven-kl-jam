@tool
class_name Lamp
extends Node2D
# lantern drawing plus a light. the ceiling ray decides the chain length.

const INK := Color("#1b1b1b")

@export var colour := Color(1.0, 0.65, 0.3)
@export var strength := 0.3
@export var reach := 2.4  ## how far the light spreads

var _light: PointLight2D
var _chain := 0.0  # distance up to the ceiling
var _time := randf() * 10.0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_light = PointLight2D.new()
	_light.texture = Block.glow_texture()
	_light.color = colour
	_light.texture_scale = reach
	add_child(_light)
	# wait for the level's blocks to exist, then look straight up for something to hang from.
	await get_tree().physics_frame
	await get_tree().physics_frame
	var query := PhysicsRayQueryParameters2D.create(global_position, global_position + Vector2(0, -900))
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		_chain = global_position.y - float(hit["position"].y)
		queue_redraw()


func _process(delta: float) -> void:
	if _light == null:
		return
	# lights are the costly part of a frame: switch off the ones nobody can see.
	var seen := Paint.on_screen(self, 380.0)
	_light.visible = seen
	if not seen:
		return
	# two wobbling sine waves make a cheap but convincing flicker.
	_time += delta
	_light.energy = strength * (0.85 + 0.1 * sin(_time * 11.0) + 0.05 * sin(_time * 23.0))


func _draw() -> void:
	if _chain > 0.0:
		Paint.line(self, Vector2(0, -14), Vector2(0, -_chain), INK, 3.0, 1, 1.5)
	draw_rect(Rect2(-11, -14, 22, 28), INK)
	draw_rect(Rect2(-8, -11, 16, 22), colour.lightened(0.4))
	draw_circle(Vector2.ZERO, 5.0, Color.WHITE)
