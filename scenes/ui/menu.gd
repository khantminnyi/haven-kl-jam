extends Control
# the layout lives in menu.tscn. this just connects buttons and moves the pictures.

var velocities: Array[Vector2] = []
var clock := 0.0

func _ready() -> void:
	# splash from text file
	var lines = FileAccess.get_file_as_string("res://scenes/ui/splash.txt").split("\n", false)
	if not lines.is_empty():
		$Heading/Splash.text = lines.pick_random()

	Engine.time_scale = 1.0
	Sfx.play_music("res://audio/music/main_menu_theme.mp3")
	$MainButtons/Play.pressed.connect(show_page.bind("Levels"))
	$MainButtons/Characters.pressed.connect(show_page.bind("Characters"))
	$MainButtons/Credits.pressed.connect(show_page.bind("Credits"))
	$MainButtons/Quit.pressed.connect(quit_or_mute)
	if OS.get_name() == "Web":
		$MainButtons/Quit.text = "le mute (M)"
	for page in ["Levels", "Characters", "Credits"]:
		get_node(page + "/Back").pressed.connect(show_page.bind("MainButtons"))
	for i in range(4):
		var button := get_node("Levels/Level" + str(i + 1)) as Button
		button.pressed.connect(Game.go_to_level.bind(i))
		button.disabled = i >= Game.unlocked
		if button.disabled:
			button.text = str(i + 1) + ". ???"
		elif Game.best_times.has(i):
			button.text += "   best %.1f s" % float(Game.best_times[i])
		if not button.disabled and Game.dev_time(i) > 0.0:
			button.text += "   dev %.1f s" % Game.dev_time(i)
	var unlocks := [1, 3, 4]
	for i in range(3):
		var card := get_node("Characters/Card" + str(i + 1))
		if Game.unlocked < unlocks[i]:
			card.get_node("Name").text = "???"
			card.get_node("Description").text = "reach level %d to meet them" % unlocks[i]
			card.get_node("Portrait").modulate = Color.BLACK
	for i in range($Bouncers.get_child_count()):
		velocities.append(Vector2.from_angle(0.7 + i * 1.9) * (120.0 + i * 22.0))
	show_page("MainButtons")

func show_page(page: String) -> void:
	for name in ["MainButtons", "Levels", "Characters", "Credits"]:
		get_node(name).visible = name == page
	$Heading.visible = page == "MainButtons" or page == "Levels"

func quit_or_mute() -> void:
	if OS.get_name() == "Web":
		Game.toggle_mute()
	else:
		get_tree().quit()

func _process(delta: float) -> void:
	clock += delta
	$Heading/Splash.scale = Vector2.ONE * (1.0 + sin(clock * 5.0) * 0.06)
	for i in range(velocities.size()):
		var picture := $Bouncers.get_child(i) as TextureRect
		picture.position += velocities[i] * delta
		for axis in range(2):
			var edge := maxf(size[axis] - picture.size[axis], 0.0)
			if picture.position[axis] < 0.0 or picture.position[axis] > edge:
				velocities[i][axis] *= -1.0
				picture.position[axis] = clampf(picture.position[axis], 0.0, edge)
