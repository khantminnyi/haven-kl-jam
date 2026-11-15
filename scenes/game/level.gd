class_name Level
extends Node2D
# one level: story, pan, aim, fly, then win or die. connects the other bits.

enum State { STORY, PAN, AIM, REVEAL, FLY, DEAD, WIN }

const INK := Color("#1b1b1b")
const PAPER := Color("#f2ead3")

# after a retry the story is skipped, so restarting is instant.
static var skip_intro := false

@export_group("Story")
@export var level_name := "level"
@export var speaker := "SOLDIER"  ## name on the comic panel
@export var story: PackedStringArray = []  ## panels shown before the level starts
@export var pan_story: PackedStringArray = []  ## panels shown while the camera pans to the target
@export_file("*.mp3") var music := ""  ## this level's theme song (looped)
@export var death_radio: PackedStringArray = []  ## short radio chatter on the death card
@export var win_big := "got em"  ## what slams onto the screen when you win
@export var win_small := ""  ## a line under it, above your time
@export var win_colour := Color("#33d6a6")
# a famous banner instead of the big word (see WinCard). a sprite sheet plays as an animation.
@export_file("*.png") var win_image := ""
@export var win_frames := Vector2i(1, 1)  ## columns and rows of the sheet
@export var win_frame_count := 1
@export var win_width := 760.0
@export var milk_finale := false  ## on the last click, squirt milk over the whole screen before leaving
@export var aim_hint := "drag on the character to aim. let go to fire"
@export var pan_to_target := true
# the tutorial pretends to be a normal aim-and-shoot game until the first shot.
@export var tutorial := false
@export var reveal: PackedStringArray = []  ## tutorial: panels shown after the first shot
@export var battle_flashes := false  ## distant artillery: flashes, rumbles and far-off shots

@export_group("Mood")
@export var ambient := Color(0.82, 0.8, 0.86)  ## overall tint of the world (white = full daylight)
@export var player_light := Color(1.0, 0.86, 0.62)  ## the glow that follows the character
@export var background_tint := Color(0.75, 0.78, 0.95)
@export var grade := Color(1.0, 0.97, 0.92)  ## colour grade applied to the whole screen
@export var dust := Color(1.0, 0.9, 0.7, 0.5)  ## floating specks in the air

var state := State.STORY
var run_time := 0.0  # seconds since the first shot (the score)
var _clock := 0.0
var _rec_times := PackedFloat32Array()  # the run, recorded every physics frame (for the dev ghost)
var _rec_points := PackedVector2Array()
var _ghost: Ghost
var _boil_frame := -1
var _pan_hold := false  # camera stays on the target while pan_story plays
var _slowmo_amount := 0.0
var _reveal_in := -1.0
var _cine_scale := 1.0
var _cine_left := 0.0
var _next_flash := 3.0
var _big: Label
var _small: Label
var _hint: Label
var _timer: Label
var _panel: ComicPanel
var _win_card: WinCard
var _milk: MilkSplash
var _finale_started := false
var _dog: StoryDog
var _fridge: StoryFridge
var _story_focus := 0.0  # 0 = camera on the character, 1 = on the target (when the cow talks)
var _story_focus_goal := 0.0
var _death_card: DeathRadio
var _post: ShaderMaterial
var _ambient_node: CanvasModulate

@onready var shooter: Shooter = $Shooter
@onready var target: Target = $Target
@onready var cam: FollowCam = $Cam
func _ready() -> void:
	if music == "":
		Sfx.stop_music()
	else:
		Sfx.play_music(music)
	_build_mood()
	_build_hud()
	var ghost_data := Game.ghost_data(Game.current_level_index())
	if not ghost_data.is_empty():
		_ghost = Ghost.new()
		_ghost.setup(ghost_data)
		add_child(_ghost)
	cam.shooter = shooter
	# keep the camera inside the map so you never see the void past the walls.
	var map := get_node_or_null("Map") as LevelMap
	if map:
		var area := Rect2(map.position + map.bounds.position, map.bounds.size)
		cam.limit_left = int(area.position.x)
		cam.limit_top = int(area.position.y)
		cam.limit_right = int(area.end.x)
		cam.limit_bottom = int(area.end.y)
	shooter.launched.connect(_on_launched)
	shooter.died.connect(_on_died)
	shooter.exploded_off.connect(_on_explosion)
	# impact speed drives shake, capped at 12 so tiny taps stay quiet and big hits feel chunky.
	shooter.bounced.connect(_on_bounce)
	target.body_entered.connect(_on_target_hit)
	if skip_intro:
		cam.snap_to(shooter.global_position, cam.base_zoom)
		_start_aim()
		return
	# story: close-up on the character while they talk.
	shooter.input_enabled = false
	cam.override_active = true
	cam.override_point = shooter.global_position
	cam.override_zoom = 1.5
	cam.snap_to(shooter.global_position, 1.5)
	_hint.text = level_name
	_panel.play(speaker, story, _after_story)


func _physics_process(_delta: float) -> void:
	if state == State.FLY and shooter.alive:
		_rec_times.append(run_time)
		_rec_points.append(shooter.global_position)


func _process(delta: float) -> void:
	var real_delta := delta / maxf(Engine.time_scale, 0.001)
	# the hand-drawn wobble: tell every block, doodle and pickup to redraw ~6 times a second.
	# (one check here instead of hundreds of per-frame _process calls.)
	if Paint.frame() != _boil_frame:
		_boil_frame = Paint.frame()
		# one shared tick tells scenery to wobble; each object still checks if it is on screen.
		get_tree().call_group("boil", "_boil")
	_clock += real_delta
	_update_cinematic(real_delta)
	_update_battle(real_delta)
	match state:
		State.STORY:
			# when the cow speaks, the camera visits it, then comes back.
			_story_focus = move_toward(_story_focus, _story_focus_goal, real_delta * 1.2)
			var look := smoothstep(0.0, 1.0, _story_focus)
			cam.override_point = shooter.global_position.lerp(target.global_position, look)
			cam.override_zoom = lerpf(1.5, cam.base_zoom, look)
		State.PAN:
			# over to the target, hold a moment (or until the panels are done), and back.
			var to_target := smoothstep(0.0, 1.0, _clock) - smoothstep(1.8, 2.6, _clock)
			if _pan_hold:
				to_target = smoothstep(0.0, 1.0, _clock)
			cam.override_point = shooter.global_position.lerp(target.global_position, to_target)
			cam.override_zoom = lerpf(1.5, cam.base_zoom, smoothstep(0.0, 0.8, _clock))
			if _clock > 2.7 and not _pan_hold:
				_start_aim()
		State.AIM:
			if tutorial and shooter.dragging:
				# fake "serious aiming game" read-out. it means nothing. that's the joke.
				var aim := shooter.aim_direction()
				var power := shooter._pull().length() / shooter.max_pull * 100.0
				_hint.text = "angle %d    power %d%%    wind 0.3" % [int(rad_to_deg(-aim.angle())), int(power)]
		State.FLY:
			# the score uses wall-clock-ish time, so aiming in slow-mo still costs time.
			run_time += real_delta
			if _ghost:
				_ghost.time = run_time
			_timer.text = ("%.1f" % run_time) + ("   smashed %d" % shooter.smashed if shooter.smashed > 0 else "")
	if _reveal_in > 0.0:
		_reveal_in -= real_delta
		if _reveal_in <= 0.0 and shooter.alive:
			state = State.REVEAL
			shooter.input_enabled = false
			_panel.play(speaker, reveal, _after_reveal, "reveal")
	# slow-mo makes the screen go cool (see post.gdshader).
	var want := 1.0 if shooter.slowmo_active else 0.0
	_slowmo_amount = move_toward(_slowmo_amount, want, real_delta * 6.0)
	_post.set_shader_parameter("slowmo", _slowmo_amount)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		_restart()
		return
	if event.is_action_pressed("pause"):
		Game.go_to_menu()
		return
	var click := event as InputEventMouseButton
	if click == null or not click.pressed:
		return
	if state == State.PAN and not _pan_hold:
		_start_aim()
	elif state == State.DEAD and _clock > 0.6:
		_restart()
	elif state == State.WIN and _clock > 0.6:
		if milk_finale:
			if not _finale_started:
				_finale_started = true
				Engine.time_scale = 1.0
				_milk.start(shooter.get_global_transform_with_canvas().origin, Game.level_won)
		else:
			Game.level_won()


func _on_line_started(who: String) -> void:
	_story_focus_goal = 1.0 if state == State.STORY and who.to_lower() == "cow" else 0.0


func _on_stage(cue: String) -> void:
	if shooter.rig:
		shooter.rig.back_view = cue.contains("back view")
		shooter.rig.stained = cue.contains("stain")
	# while his back is turned he is walking up to the fridge.
	if cue.contains("back view"):
		if _fridge == null:
			_fridge = StoryFridge.new()
			_fridge.z_index = -1
			add_child(_fridge)
			_fridge.global_position = shooter.global_position + Vector2(46, 40)
	elif _fridge:
		_fridge.queue_free()
		_fridge = null
	if cue.contains("steal") and _dog == null:
		_dog = StoryDog.new()
		add_child(_dog)
		_dog.start(shooter.global_position + Vector2(0, 18))
		_panel.actor_node = _dog


func _after_story() -> void:
	if _dog:
		_dog.queue_free()  # the real dog is waiting at the target
		_dog = null
		_panel.actor_node = null
	if _fridge:
		_fridge.queue_free()
		_fridge = null
	_story_focus_goal = 0.0
	if pan_to_target:
		state = State.PAN
		_clock = _story_focus  # carry on from where the camera is, so it doesn't jump back first
		if not pan_story.is_empty():
			_pan_hold = true
			_panel.play(speaker, pan_story, _after_pan_story, "pan")
	else:
		_start_aim()


func _after_pan_story() -> void:
	_pan_hold = false
	_clock = 1.8  # jump to the "head back to the character" part of the pan


func _start_aim() -> void:
	state = State.AIM
	cam.override_active = false
	shooter.input_enabled = true
	_hint.text = aim_hint
	if OS.is_debug_build():
		# handy for scripted playtests: where the character is on screen once the camera settles.
		get_tree().create_timer(0.6).timeout.connect(func() -> void:
			print("[Level] shooter on screen at ", shooter.get_global_transform_with_canvas().origin.round()))


func _after_reveal() -> void:
	state = State.FLY
	shooter.input_enabled = true
	_hint.text = ""


func _on_launched(first: bool) -> void:
	if not first:
		return
	state = State.FLY
	run_time = 0.0
	_hint.text = ""
	# the kick: slow motion for a moment while you fly backwards screaming.
	_cinematic(0.22, 1.0)
	cam.shake(10.0)
	if tutorial and not skip_intro and not reveal.is_empty():
		_reveal_in = 1.5


func _on_died(reason: String) -> void:
	if state == State.WIN:
		return
	state = State.DEAD
	_clock = 0.0
	_reveal_in = -1.0
	cam.shake(18.0)
	Sfx.play("slam_03", -2.0, 0.8)
	# watch the limbs fly in slow motion before the verdict.
	_cinematic(0.2, 1.3)
	_death_card.show_after(1.0, death_radio)
	_pop("oops", "%s. click or press r to go again" % reason, Color("#ec3750"))


func _on_target_hit(body: Node2D) -> void:
	if body != shooter or state != State.FLY or not shooter.alive:
		return
	state = State.WIN
	_clock = 0.0
	shooter.input_enabled = false
	target.explode()
	cam.shake(34.0)
	_cinematic(0.25, 0.8)
	Sfx.play("bell_01")
	Sfx.pick(["hit_01", "hit_02"], 2.0)
	var best := Game.report_time(run_time)
	Game.save_ghost(Game.current_level_index(), run_time, _rec_times, _rec_points)
	var dev := Game.dev_time(Game.current_level_index())
	var dev_text := ""
	if dev > 0.0:
		dev_text = "    dev %.1f s" % dev
	if win_image != "":
		_win_card.show_card(win_image, win_frames, win_frame_count, win_width, get_viewport_rect().size.y * 0.3)
		_small.anchor_top = 0.66
		_small.anchor_bottom = 0.66
	var title := win_big
	if win_image != "":
		title = ""
	var subtitle := ""
	if win_small != "":
		subtitle = win_small + "\n"
	var best_text := ""
	if best:
		best_text = "  (new best)"
	subtitle += "%.1f s%s%s    smashed %d\nclick to keep going" % [run_time, best_text, dev_text, shooter.smashed]
	_pop(title, subtitle, win_colour)


func _restart() -> void:
	skip_intro = true
	get_tree().reload_current_scene()


func _cinematic(scale: float, seconds: float) -> void:
	_cine_scale = scale
	_cine_left = seconds


func _update_cinematic(real_delta: float) -> void:
	# let dragging have priority here. two scripts fighting over time_scale would flicker.
	if _cine_left <= 0.0 or shooter.dragging:
		return
	_cine_left -= real_delta
	if _cine_left > 0.25:
		Engine.time_scale = _cine_scale
	else:
		Engine.time_scale = lerpf(1.0, _cine_scale, maxf(_cine_left, 0.0) / 0.25)


func _update_battle(real_delta: float) -> void:
	if not battle_flashes:
		return
	_next_flash -= real_delta
	if _next_flash > 0.0:
		return
	_next_flash = randf_range(1.5, 4.5)
	if randf() < 0.5:
		Sfx.pick(["shot_01", "shot_02"], -24.0, 0.7)
		return
	cam.shake(5.0)
	Sfx.play("explosion", -20.0, 0.6)
	_ambient_node.color = Color(ambient.r * 1.3, ambient.g * 1.2, ambient.b * 1.05)
	var tween := create_tween().set_ignore_time_scale(true)
	tween.tween_property(_ambient_node, "color", ambient, 0.4)


func _pop(big: String, small: String, colour: Color) -> void:
	_big.text = big
	_small.text = small
	_big.add_theme_color_override("font_color", colour)
	_big.pivot_offset = _big.size / 2.0
	_big.scale = Vector2(3.0, 3.0)
	_big.rotation = -0.1
	var tween := create_tween().set_ignore_time_scale(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_big, "scale", Vector2.ONE, 0.35)


# mood stuff: light, background, dust, screen tint

func _build_mood() -> void:
	# tint the whole world a little; lights then add warm pools on top.
	_ambient_node = CanvasModulate.new()
	_ambient_node.color = ambient
	add_child(_ambient_node)
	# pixel-art sky and hills drawn in code, in three parallax layers.
	PixelBackdrop.build(self, background_tint, battle_flashes)
	# soft glows so the character and the target always stand out.
	for spot: Array in [[shooter, player_light, 0.18, 3.0], [target, Color(1, 0.95, 0.8), 0.22, 3.5]]:
		var glow := PointLight2D.new()
		glow.texture = Block.glow_texture()
		glow.texture_scale = spot[3]
		glow.energy = spot[2]
		glow.color = spot[1]
		spot[0].add_child(glow)
	# floating dust/embers that drift around the camera.
	var specks := CPUParticles2D.new()
	specks.amount = 36
	specks.lifetime = 7.0
	specks.preprocess = 7.0
	specks.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	specks.emission_rect_extents = Vector2(900, 550)
	specks.direction = Vector2(1, -0.3)
	specks.spread = 40.0
	specks.gravity = Vector2(0, -8)
	specks.initial_velocity_min = 8.0
	specks.initial_velocity_max = 30.0
	specks.scale_amount_min = 2.0
	specks.scale_amount_max = 5.0
	specks.color = dust
	specks.local_coords = false
	$Cam.add_child(specks)
	# screen shader: the ms Paint look plus colour grade.
	var layer := CanvasLayer.new()
	layer.layer = 50
	# this overlay is made here at runtime. you will not find it in the saved scene tree.
	var screen := ColorRect.new()
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_post = ShaderMaterial.new()
	_post.shader = load("res://scenes/game/post.gdshader")
	_post.set_shader_parameter("grade", grade)
	screen.material = _post
	layer.add_child(screen)
	add_child(layer)


func _build_hud() -> void:
	# saved UI scene: positions and fonts are editable without touching this script.
	var hud := preload("res://scenes/ui/hud.tscn").instantiate()
	add_child(hud)
	_big = hud.get_node("Big")
	_small = hud.get_node("Small")
	_hint = hud.get_node("Hint")
	_timer = hud.get_node("Timer")
	for label in [_big, _small, _hint, _timer]:
		label.text = ""
	_death_card = hud.get_node("DeathRadio")
	_panel = hud.get_node("Dialogue")
	_panel.shooter_node = shooter
	_panel.target_node = target
	_panel.voice_id = scene_file_path.get_file().get_basename()
	_panel.stage.connect(_on_stage)
	_panel.line_started.connect(_on_line_started)
	_win_card = hud.get_node("WinCard")
	_milk = hud.get_node("MilkSplash")


func _on_explosion(_at: Vector2) -> void:
	cam.shake(28.0)


func _on_bounce(speed: float) -> void:
	# harder hit = more shake. the cap keeps it readable.
	var shake_amount := speed / 120.0
	shake_amount = clampf(shake_amount, 0.0, 12.0)
	cam.shake(shake_amount)
