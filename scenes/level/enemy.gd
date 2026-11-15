@tool
class_name Enemy
extends Target
# a target that shoots back, with deliberately bad aim.

@export var range := 1100.0  ## they only shoot when the character is this close
@export var inaccuracy := 0.7  ## radians of random aim error either way (about 40 degrees)
@export var fire_every := Vector2(2.0, 3.5)  ## random seconds between shots
@export var bullet_speed := 750.0

const LAST_WORDS: PackedStringArray = ["mommy?", "i have a family", "tell my wife i said hi", "not like this", "medic!"]

var _cooldown := 1.5
var _cough := 0.0
var _dead := false


func _init() -> void:
	style = Style.ENEMY_SOLDIER
	radius = 30.0
	collision_layer = 2  # layer 2 is for enemies, so the player's bullets can find them
	add_to_group("enemies")


func _ready() -> void:
	super()
	if not Engine.is_editor_hint():
		body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if _dead or Engine.is_editor_hint():
		return
	var shooter := get_tree().get_first_node_in_group("shooter") as Shooter
	if shooter == null or not shooter.alive or not shooter.launched_once:
		return
	var turn_left := shooter.global_position.x < global_position.x
	if turn_left != facing_left:
		facing_left = turn_left
		queue_redraw()
	_cough -= delta
	if _cough <= 0.0 and shooter.rig and shooter.rig.ability() == CharacterRig.Ability.JET and global_position.distance_to(shooter.global_position) < 380.0:
		_cough = 2.5
		_say("*cough*")
	_cooldown -= delta
	if _cooldown > 0.0 or global_position.distance_to(shooter.global_position) > range:
		return
	_cooldown = randf_range(fire_every.x, fire_every.y)
	var aim := (shooter.global_position - global_position).angle() + randf_range(-inaccuracy, inaccuracy)
	var shot := Bullet.new()
	shot.hostile = true
	shot.velocity = Vector2.from_angle(aim) * bullet_speed
	get_parent().add_child(shot)
	shot.global_position = global_position + Vector2.from_angle(aim) * 40.0
	Sfx.play("shot_01", -10.0, 0.8)


func _on_body_entered(body: Node2D) -> void:
	if body is Shooter and not _dead:
		die()


func die() -> void:
	if _dead:
		return
	_dead = true
	set_deferred("monitoring", false)
	explode()
	_say(LAST_WORDS[randi() % LAST_WORDS.size()])


func _say(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", Color("#f2ead3"))
	label.add_theme_color_override("font_outline_color", Color("#1b1b1b"))
	label.add_theme_constant_override("outline_size", 10)
	label.z_index = 50
	get_parent().add_child(label)
	label.global_position = global_position + Vector2(-60, -90)
	var tween := label.create_tween().set_ignore_time_scale(true).set_parallel()
	tween.tween_property(label, "position:y", label.position.y - 70.0, 1.6)
	tween.tween_property(label, "modulate:a", 0.0, 1.6).set_delay(0.8)
	tween.chain().tween_callback(label.queue_free)
