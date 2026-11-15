class_name Grenade
extends Node2D
# gravity, raycast, bounce, fuse, boom.

const INK := Color("#1b1b1b")
const GRAVITY := 1800.0
const FUSE := 1.3
const REACH := 190.0  ## blast radius in pixels
const PUSH := 1100.0  ## how hard the blast shoves the shooter (at point blank)

var velocity := Vector2.ZERO
var ignore: RID  # the thrower's body, so it doesn't hit itself on the way out

var _age := 0.0


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= FUSE:
		_detonate()
		return
	velocity.y += GRAVITY * delta
	# check the whole next step with a ray. checking just the end lets fast stuff phase through walls.
	var next := global_position + velocity * delta
	var query := PhysicsRayQueryParameters2D.create(global_position, next, 1)
	query.exclude = [ignore]
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		global_position = next
	else:
		global_position = hit["position"] + hit["normal"] * 3.0
		velocity = velocity.bounce(hit["normal"]) * 0.45
	queue_redraw()


func _detonate() -> void:
	Sfx.play("explosion", 0.0, 1.2)
	Block.burst(get_parent(), global_position, Color("#ff9a3c"), 40, 650.0)
	Block.blast(get_tree(), global_position, REACH)
	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		if enemy is Enemy and enemy.global_position.distance_to(global_position) < REACH + 30.0:
			enemy.die()
	var shooter := get_tree().get_first_node_in_group("shooter") as Shooter
	if shooter:
		shooter.blast_push(global_position, REACH + 40.0, PUSH)
	var cam := get_tree().get_first_node_in_group("cam") as FollowCam
	if cam:
		cam.shake(16.0)
	queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 9.0, INK)
	draw_circle(Vector2.ZERO, 7.0, Color("#6f8f45"))
	# the fuse blinks faster as it burns down.
	if int(_age * (4.0 + _age * 6.0)) % 2 == 0:
		draw_circle(Vector2(0, -10), 4.0, Color("#ec3750"))
