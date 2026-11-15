class_name Bullet
extends Node2D
# raycast the next step, deal with the hit, then disappear. fart clouds fade instead.

enum Style {
	BULLET,  ## soldier: fast yellow streak
	ROCKET,  ## grandma: fat rocket with a flash on impact
	FART,  ## lactose man: a slowing green cloud; can set off tnt.
}

const INK := Color("#1b1b1b")

var style := Style.BULLET
var velocity := Vector2.ZERO
var ignore: RID  # the shooter's body, so we don't hit ourselves
var hostile := false  # an enemy's bullet: hurts the character instead of breaking things

var _age := 0.0


func _physics_process(delta: float) -> void:
	_age += delta
	queue_redraw()
	if style == Style.FART:
		# the cloud slows down quickly and fades away. gas and sparks don't mix: it sets off tnt.
		velocity *= pow(0.02, delta)
		var step := velocity * delta * 0.25
		var gas_query := PhysicsRayQueryParameters2D.create(global_position, global_position + step, 1)
		gas_query.exclude = [ignore]
		var gas_hit := get_world_2d().direct_space_state.intersect_ray(gas_query)
		var tnt := gas_hit.get("collider") as Block
		if tnt and tnt.kind == Block.Kind.EXPLOSIVE:
			tnt.explode()
			queue_free()
			return
		position += step
		if _age > 1.2:
			queue_free()
		return
	if _age > 1.5:
		queue_free()
		return
	# check the path we're about to travel so a fast bullet can't skip through a thin wall.
	var next := global_position + velocity * delta
	if not hostile:
		# enemies are areas on collision layer 2, so they get their own ray.
		var enemy_query := PhysicsRayQueryParameters2D.create(global_position, next, 2)
		enemy_query.collide_with_areas = true
		enemy_query.collide_with_bodies = false
		var enemy := get_world_2d().direct_space_state.intersect_ray(enemy_query).get("collider") as Enemy
		if enemy:
			enemy.die()
			queue_free()
			return
	var query := PhysicsRayQueryParameters2D.create(global_position, next, 1)
	if ignore.is_valid():
		# ignore the shooter that spawned this shot or it can bonk itself immediately.
		query.exclude = [ignore]
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		global_position = next
		return
	if hostile:
		var victim := hit["collider"] as Shooter
		if victim:
			victim.hurt(1, "shot")
		queue_free()
		return
	var block := hit["collider"] as Block
	if block:
		match block.kind:
			Block.Kind.GLASS:
				block.shatter()
			Block.Kind.EXPLOSIVE:
				block.explode()
			_:
				block.impact_fx(hit["position"], hit["normal"], 1400.0 if style == Style.ROCKET else 700.0)
		if style == Style.ROCKET:
			block.flash(hit["position"], Color("#ffb347"), 2.5, 4.0, 0.3)
	queue_free()


func _draw() -> void:
	var back := -velocity.normalized()
	match style:
		Style.BULLET:
			if hostile:
				draw_line(Vector2.ZERO, back * 20.0, INK, 7.0)
				draw_line(Vector2.ZERO, back * 18.0, Color("#ec3750"), 4.0)
				return
			draw_line(Vector2.ZERO, back * 26.0, Color("#f1c40f", 0.5), 6.0)
			draw_line(Vector2.ZERO, back * 12.0, INK, 7.0)
			draw_line(Vector2.ZERO, back * 10.0, Color("#f1c40f"), 4.0)
		Style.ROCKET:
			draw_line(back * 14.0, back * 40.0, Color("#ff9a3c", 0.7), 9.0)
			draw_line(Vector2.ZERO, back * 20.0, INK, 13.0)
			draw_line(Vector2.ZERO, back * 18.0, Color("#6f8f45"), 9.0)
			draw_circle(Vector2.ZERO, 5.0, Color("#ec3750"))
		Style.FART:
			var fade := clampf(1.0 - _age / 1.2, 0.0, 1.0)
			for puff: Vector2 in [Vector2.ZERO, Vector2(14, -8), Vector2(-10, 10), Vector2(8, 14)]:
				draw_circle(puff * (1.0 + _age), 14.0 + _age * 26.0, Color(0.55, 0.75, 0.2, 0.45 * fade))
