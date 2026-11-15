# le recoil

shoot one way, fly the other. made for haven KL's bounce back theme.
le ragdoll galore: zee, dan, khon. music by jerrick.

open project.godot in Godot 4.7. F5 runs the game, F6 runs the open scene.
drag to shoot. space/right click = grenade, glide or fart jet. R retries, Esc menu, M mute.

editing is mostly in the engine now:
- levels: scenes/level/levels/. move objects under Map; Shooter is the start, Target is the finish.
- blocks: change Size, Kind and Theme in the Inspector. Size updates collision too.
- menu: scenes/ui/menu.tscn. hidden pages have an eye toggle in the scene tree.
- hud: scenes/ui/hud.tscn. story/music/colours are on each level's root node.
- random menu lines: scenes/ui/splash.txt.

save with Ctrl+S before testing. new levels still need a Game.LEVELS entry and a menu button.
old ghosts need a new recording after route changes.

[demo notes](docs/DEMO.md) / [credits](CREDITS.md)
