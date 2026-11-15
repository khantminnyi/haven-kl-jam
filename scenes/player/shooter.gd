class_name Shooter
extends CharacterBody2D
# player physics and input. shots go towards the mouse; recoil goes the other way.

signal launched(first: bool)
signal bounced(speed: float)
signal impact(at: Vector2, block: Block, speed: float)
signal exploded_off(at: Vector2)
signal died(reason: String)
signal health_changed(health: int)
signal grenade_thrown
signal slowmo_changed(active: bool)

const INK := Color("#1b1b1b")

@export_group("Body")
@export var radius := 16.0
@export var gravity := 1800.0

@export_group("Shooting")
@export var grab_radius := 40.0  ## how close a press must be to the body: small on purpose
@export var air_grab_radius := 90.0  ## bigger in the air, where aiming is harder
@export var min_pull := 30.0  ## shorter drags cancel
@export var max_pull := 220.0
@export var min_launch_speed := 400.0
@export var max_launch_speed := 1500.0
@export var recoil_min_speed := 900.0  ## the first shot always kicks at least this hard
@export var recoil_lift := 380.0  ## ...and pops you up a bit so you leave the ground
@export var air_shots_max := 1  ## shots allowed in the air. floors and sticky walls reload
@export var bullet_speed := 2600.0

@export_group("Bounce")
@export var bounce_min_speed := 450.0  ## floor hits slower than this stop bouncing and slide
@export var floor_friction := 0.86  ## per 60 fps frame while sliding
@export var fall_damage_speed := 0.0  ## landing faster than this is fatal. 0 = no fall damage
@export var spike_kill_speed := 380.0  ## hitting spikes faster than this is fatal
@export var bouncy_min_speed := 950.0  ## a bouncy block always throws you at least this fast
@export var explosion_speed := 1600.0
@export var max_speed := 2400.0

@export_group("Health")
@export var max_health := 3  ## characters can override this (see CharacterRig.LOOKS)
@export var bounce_hurt_speed := 1600.0  ## a bouncy block that throws you faster than this hurts
@export var hurt_invulnerable := 0.6  ## seconds of grace after a hit

@export_group("Tricks")
@export var grenade_speed := 950.0
@export var grenades_max := 2  ## floors refill them
@export var glide_fall_speed := 130.0  ## how slowly a gliding character sinks
@export var jet_thrust := 3400.0  ## push from a held fart (lactose guy)
@export var jet_fuel_max := 0.9  ## seconds of held fart; floors refill it

@export_group("Slow motion")
@export var slowmo_scale := 0.12
@export var slowmo_ramp_in := 0.12  ## real seconds to reach slow-mo
@export var slowmo_ramp_out := 0.06  ## real seconds to come back
@export var focus_max := 2.5  ## real seconds of slow-mo; refills when you reload

var focus := 0.0
var shots_left := 0
var dragging := false
var slowmo_active := false
var launched_once := false
var alive := true
var input_enabled := true
var stuck := false  # glued to a sticky wall
var gliding := false
var jetting := false
var jet_fuel := 0.0
var health := 3
var grenades := 0
var power := 0.0  # seconds of power-up left: unlimited shots (from lightning pickups)
var smashed := 0  # crates smashed this run
var no_sling_zones := 0  # how many noslingzones we are inside
var no_jet_zones := 0  # how many no-farting zones (jet off, slinging still allowed)

var _mouse_world := Vector2.ZERO
var _invuln := 0.0
var _grounded_timer := 0.0
var _owns_time := false
var _puff_timer := 0.0
var _trail: Array[Vector2] = []  # recent positions, newest first
var _trail_length := 14  # the lactose guy leaves a long green cloud

@onready var rig: CharacterRig = get_node_or_null("Rig")


func _ready() -> void:
	add_to_group("shooter")
	if rig:
		air_shots_max = rig.air_shots()  # some characters get more
		max_health = rig.max_health()
		if rig.ability() == CharacterRig.Ability.JET:
			_trail_length = 34
	health = max_health
	grenades = grenades_max
	focus = focus_max
	shots_left = air_shots_max
	var shape := CircleShape2D.new()
	shape.radius = radius
	var collider := CollisionShape2D.new()
	collider.shape = shape
	add_child(collider)
	_mouse_world = global_position


func _exit_tree() -> void:
	Engine.time_scale = 1.0
	Sfx.set_glide(false)


func _input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion:
		_mouse_world = _to_world(motion.position)
		return
	var button := event as InputEventMouseButton
	if button == null or button.button_index != MOUSE_BUTTON_LEFT:
		return
	_mouse_world = _to_world(button.position)
	if button.pressed:
		# bigger grab area midair because clicking a flying grandma is already hard enough.
		var reach := air_grab_radius
		if not launched_once or is_grounded():
			reach = grab_radius
		if input_enabled and alive and _can_shoot() and _mouse_world.distance_to(global_position) <= reach:
			dragging = true
	elif dragging:
		dragging = false
		_try_launch()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("primary"):
		_try_grenade()


func _physics_process(delta: float) -> void:
	# before the first shot we're standing still; glued to a sticky wall we hang still too.
	if not launched_once or stuck:
		Sfx.set_glide(false)
		return
	_grounded_timer = maxf(_grounded_timer - delta, 0.0)
	velocity.y += gravity * delta
	# character trick: hold space (or right mouse) and grandma glides on her wheelchair.
	gliding = alive and rig != null and rig.ability() == CharacterRig.Ability.GLIDE and _trick_held() and velocity.y > glide_fall_speed
	if gliding:
		velocity.y = glide_fall_speed
	Sfx.set_glide(gliding)
	# lactose guy: hold space to keep farting. it pushes you away from the mouse like a jetpack.
	jetting = alive and rig != null and rig.ability() == CharacterRig.Ability.JET and _trick_held() and (jet_fuel > 0.0 or power > 0.0) and no_sling_zones == 0 and no_jet_zones == 0
	if jetting:
		jet_fuel = maxf(jet_fuel - delta, 0.0)
		velocity -= aim_direction() * jet_thrust * delta
		_puff_timer -= delta
		if _puff_timer <= 0.0:
			_puff_timer = 0.08
			_spawn_shot(aim_direction())
	var hit := move_and_collide(velocity * delta)
	if hit:
		_on_hit(hit, delta)
	velocity = velocity.limit_length(max_speed)
	if alive and global_position.y > 6000.0:
		_die("fell out of the world")


func _process(delta: float) -> void:
	# slow-mo slows delta too. divide it back out or the focus timer lasts forever-ish.
	var real_delta := delta / maxf(Engine.time_scale, 0.001)
	power = maxf(power - real_delta, 0.0)
	_invuln = maxf(_invuln - delta, 0.0)
	# only aim in the air spends focus. holding on the floor should not eat your budget.
	var want_slowmo := dragging and alive and launched_once and not is_grounded() and focus > 0.0
	if want_slowmo:
		focus = maxf(focus - real_delta, 0.0)
		_owns_time = true
	if _owns_time:
		# we own the time scale until it gets back to 1; otherwise releasing would leave the game slow.
		var target := 1.0
		var ramp := slowmo_ramp_out
		if want_slowmo:
			target = slowmo_scale
			ramp = slowmo_ramp_in
		# ramp by real seconds, not frames. 0.12 takes us in, 0.06 gets us out at these defaults.
		var change_per_second := (1.0 - slowmo_scale) / ramp
		var change_this_frame := change_per_second * real_delta
		Engine.time_scale = move_toward(Engine.time_scale, target, change_this_frame)
		if not want_slowmo and is_equal_approx(Engine.time_scale, 1.0):
			_owns_time = false
	if want_slowmo != slowmo_active:
		slowmo_active = want_slowmo
		slowmo_changed.emit(slowmo_active)
	# remember where we've been for the speed trail.
	_trail.push_front(global_position)
	if _trail.size() > _trail_length:
		_trail.pop_back()
	queue_redraw()


func is_grounded() -> bool:
	return _grounded_timer > 0.0 or stuck


func aim_direction() -> Vector2:
	var to_mouse := _mouse_world - global_position
	if to_mouse.length() > 1.0:
		return to_mouse.normalized()
	else:
		return Vector2.RIGHT


func _trick_held() -> bool:
	return Input.is_action_pressed("primary") or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)


func _can_shoot() -> bool:
	if no_sling_zones > 0:
		return false
	return not launched_once or is_grounded() or shots_left > 0 or power > 0.0


func _to_world(screen_pos: Vector2) -> Vector2:
	# undo camera pan + zoom first. screen pixels are not world positions.
	return get_canvas_transform().affine_inverse() * screen_pos


func _pull() -> Vector2:
	return (global_position - _mouse_world).limit_length(max_pull)


func _launch_speed(pull: Vector2) -> float:
	# inverse_lerp turns 30..220px into 0..1; lerpf turns that into 400..1500px/s. defaults only.
	var pull_distance := pull.length()
	var power_fraction := inverse_lerp(min_pull, max_pull, pull_distance)
	var launch_speed := lerpf(min_launch_speed, max_launch_speed, power_fraction)
	return launch_speed


func _try_launch() -> void:
	var pull := _pull()
	if pull.length() < min_pull or not alive:
		return
	var first := not launched_once
	if launched_once and not is_grounded() and power <= 0.0:
		shots_left -= 1
	launched_once = true
	stuck = false
	_grounded_timer = 0.0
	# replace the old velocity here, do not add it. each sling gets a predictable new direction.
	var recoil_direction := pull.normalized()
	var launch_speed := _launch_speed(pull)
	velocity = recoil_direction * launch_speed
	if first:
		# the first kick is violent no matter how gently you aimed, and lifts you off your feet.
		velocity = velocity.normalized() * maxf(velocity.length(), recoil_min_speed)
		velocity.y = minf(velocity.y, 0.0) - recoil_lift
	# bullet goes towards mouse. we go backwards. congrats, the gun is now public transport.
	var shot_direction := -pull.normalized()
	_spawn_shot(shot_direction)
	if rig:
		rig.kick(velocity.length())
		rig.fire(shot_direction)
		if first:
			rig.say("aaaaa")
	launched.emit(first)
	_log("launch first=%s pos=%s v=%s" % [first, global_position.round(), velocity.round()])


func _try_grenade() -> void:
	if not (alive and launched_once and input_enabled and grenades > 0):
		return
	if rig == null or rig.ability() != CharacterRig.Ability.GRENADE:
		return
	grenades -= 1
	# spawned in code, not a grenade node you need to place in every level.
	var nade := Grenade.new()
	nade.velocity = aim_direction() * grenade_speed + velocity * 0.3
	nade.ignore = get_rid()
	get_parent().add_child(nade)
	nade.global_position = global_position + aim_direction() * (radius + 8.0)
	grenade_thrown.emit()
	rig.say("fire in the hole")


func _spawn_shot(direction: Vector2) -> void:
	var shot := Bullet.new()
	if rig:
		shot.style = rig.shot_style()
	else:
		shot.style = Bullet.Style.BULLET
	shot.velocity = direction * bullet_speed
	shot.ignore = get_rid()
	get_parent().add_child(shot)
	shot.global_position = global_position + direction * (radius + 6.0)
	Sfx.shot(shot.style)


func _on_hit(hit: KinematicCollision2D, delta: float) -> void:
	var normal := hit.get_normal()
	# dot product isolates speed INTO the wall. scraping sideways should not count as a huge slam.
	var into := -velocity.dot(normal)  # how hard we hit, straight into the surface
	var is_floor := normal.y < -0.7
	var block := hit.get_collider() as Block
	var kind := Block.Kind.STONE
	if block:
		kind = block.kind
	if not alive:
		velocity = velocity.bounce(normal) * 0.35
		return
	if kind == Block.Kind.LAVA:
		_hit_lava(normal)
	elif block and block.is_spiky_side(normal) and into > spike_kill_speed:
		_hit_spikes()
	elif kind == Block.Kind.EXPLOSIVE:
		_hit_explosive(block)
	elif kind == Block.Kind.STICKY:
		_hit_sticky(block, hit.get_position(), normal, into)
	elif fall_damage_speed > 0.0 and is_floor and into > fall_damage_speed and kind != Block.Kind.BOUNCY:
		velocity = velocity.bounce(normal) * 0.3
		_die("splat")
	else:
		_bounce_off(block, kind, hit.get_position(), normal, into, is_floor, delta)


func _hit_lava(normal: Vector2) -> void:
	velocity = velocity.bounce(normal) * 0.2
	_die("cooked")


func _hit_spikes() -> void:
	velocity = Vector2.ZERO
	_die("skewered")


func _hit_explosive(block: Block) -> void:
	block.explode()
	var away := (global_position - block.global_position).normalized()
	velocity = (away + Vector2(0, -0.35)).normalized() * explosion_speed
	shots_left = air_shots_max
	exploded_off.emit(block.global_position)
	if rig:
		rig.kick(2000.0)
		rig.say("boom")


func _hit_sticky(block: Block, point: Vector2, normal: Vector2, into: float) -> void:
	velocity = Vector2.ZERO
	stuck = true
	_reload()
	block.impact_fx(point, normal, maxf(into, 300.0))
	if rig:
		rig.kick(into)
		rig.say(["squelch", "eww", "sticky"].pick_random())


func _bounce_off(block: Block, kind: Block.Kind, point: Vector2, normal: Vector2, into: float, is_floor: bool, delta: float) -> void:
	var keep := 0.62
	if block:
		keep = block.bounciness()
	if block:
		block.impact_fx(point, normal, into)
	impact.emit(point, block, into)
	if into > bounce_min_speed or not is_floor or kind == Block.Kind.BOUNCY:
		velocity = velocity.bounce(normal) * keep
		if kind == Block.Kind.BOUNCY:
			# make sure a bouncy block always gives a proper "boing" outwards.
			var outwards := velocity.dot(normal)
			if outwards < bouncy_min_speed:
				velocity += normal * (bouncy_min_speed - outwards)
		bounced.emit(into)
		var pillow := block != null and block.soft
		if rig and into > rig.hurt_speed() and not pillow:
			hurt(1, "too frail")  # grandma: one hard knock costs a heart (but pillows are soft)
		elif kind == Block.Kind.BOUNCY and not pillow and velocity.length() > bounce_hurt_speed:
			hurt(1, "bounced too hard")
		if rig and into > 200.0:
			rig.kick(into)
			rig.say(_ouch(kind))
	else:
		velocity = velocity.slide(normal)
		# 0.86 is tuned per 60fps frame. the exponent keeps friction similar at other tick rates.
		velocity.x *= pow(floor_friction, delta * 60.0)
	# floor = free reload. walls do not count, otherwise you can cheese the whole climb.
	if is_floor:
		_grounded_timer = 0.08
		_reload()


func _ouch(kind: Block.Kind) -> String:
	match kind:
		Block.Kind.BOUNCY:
			return ["boing", "wheee", "boioing"].pick_random()
		Block.Kind.SPIKES:
			return ["ow ow ow", "pointy", "oww"].pick_random()
		Block.Kind.METAL:
			return ["clang", "ding", "bonk"].pick_random()
	return ["oww", "ow", "oof", "ack", "my spine", "ugh", "why"].pick_random()


func hurt(amount: int, reason: String) -> void:
	if not alive or _invuln > 0.0:
		return
	health = maxi(health - amount, 0)
	_invuln = hurt_invulnerable
	health_changed.emit(health)
	if rig:
		rig.kick(1400.0)
		rig.say("ow")
	if health <= 0:
		_die(reason)


func blast_push(from: Vector2, reach: float, force: float) -> void:
	var offset := global_position - from
	if offset.length() > reach or not alive:
		return
	launched_once = true
	stuck = false
	velocity += offset.normalized() * force * (1.0 - offset.length() / reach)


func _reload() -> void:
	grenades = grenades_max
	focus = focus_max
	shots_left = air_shots_max
	jet_fuel = jet_fuel_max


func start_power(seconds: float) -> void:
	power = seconds
	_reload()
	if rig:
		rig.say("lets goo")


func _die(reason: String) -> void:
	if not alive:
		return
	alive = false
	dragging = false
	stuck = false
	if rig:
		rig.explode(velocity)
	died.emit(reason)
	_log("died: %s at %s" % [reason, global_position.round()])


func _draw() -> void:
	if not alive:
		return
	# speed trail: fading blobs along the path, only when moving fast.
	var gassy := rig != null and rig.ability() == CharacterRig.Ability.JET
	if velocity.length() > (250.0 if gassy else 600.0):
		for i in range(_trail.size()):
			# newest dot is brightest; old dots shrink/fade. cheap speed juice, no extra physics.
			var fade := 1.0 - float(i) / _trail.size()
			if gassy:
				draw_circle(to_local(_trail[i]), radius * (0.9 + (1.0 - fade) * 1.2), Color(0.55, 0.75, 0.2, 0.3 * fade))
			else:
				draw_circle(to_local(_trail[i]), radius * 0.8 * fade, Color(1.0, 0.95, 0.7, 0.28 * fade))
	var pull := _pull()
	# power-up: a crackling yellow ring.
	if power > 0.0:
		draw_arc(Vector2.ZERO, radius + 14.0 + sin(Time.get_ticks_msec() / 60.0) * 3.0, 0.0, TAU, 20, Color("#f1c40f"), 4.0)
	# first shot only: an arrow out of the weapon, like any normal shooting game. after that
	# there's no aim line; the character stretches instead (see CharacterRig).
	if dragging and not launched_once:
		_draw_first_aim(pull, pull.length() >= min_pull)
	if not launched_once:
		return
	# shots left in the air (dots) and slow-mo budget (bar), above the head.
	for i in range(air_shots_max):
		var dot := Vector2(-6.0 * (air_shots_max - 1) + i * 12.0, -radius - 34.0)
		draw_circle(dot, 5.0, INK)
		draw_circle(dot, 3.5, Color("#f1c40f") if i < shots_left or is_grounded() else Color("#55504a"))
	if max_health > 1:
		for i in range(max_health):
			var heart := Vector2(-10.0 * (max_health - 1) + i * 20.0, -radius - 50.0)
			draw_circle(heart, 7.0, INK)
			draw_circle(heart, 5.0, Color("#ec3750") if i < health else Color("#55504a"))
	if dragging or focus < focus_max:
		var bar := Rect2(-20.0, -radius - 26.0, 40.0, 5.0)
		draw_rect(bar, Color(INK, 0.35))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * focus / focus_max, bar.size.y)), Color("#338eda"))


func _draw_first_aim(pull: Vector2, aiming: bool) -> void:
	var direction := -pull.normalized() if pull.length() > 1.0 else Vector2.RIGHT
	var muzzle := direction * 40.0
	var tip := muzzle + direction * (60.0 + pull.length())
	var colour := Color("#ec3750") if aiming else Color(INK, 0.4)
	draw_line(muzzle, tip, Color(colour, 0.35), 14.0)
	draw_line(muzzle, tip, colour, 5.0)
	var side := direction.orthogonal() * 16.0
	draw_colored_polygon(PackedVector2Array([tip + direction * 26.0, tip + side, tip - side]), colour)


func _log(message: String) -> void:
	if OS.is_debug_build():
		print("[Shooter] ", message)
