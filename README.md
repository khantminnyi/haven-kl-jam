# le recoil

shoot one way, get launched the other way. a very questionable means of transport.
made for haven KL, theme was bounce back. le ragdoll galore: zee, dan, khon. music by jerrick.

Godot 4.7, standard version. project.godot -> F5. F6 runs the open scene, F8 stops.
drag from the character towards the shot, release for recoil. space / right mouse =
grenade, glide or fart jet. R retries, Esc menu, M mute, hold F for extra flop.

levels: scenes/level/levels/. tutorial, soldier_1, grandpa_1 (actually grandma), lactose_1.
Shooter = start position, Target = finish. 

2D workspace, Local scene tree. select a node, F to frame it, W to move, Ctrl+D to copy.
position is under Inspector -> Transform. block Size changes both drawing and collision;
Scale stays at (1, 1). Kind changes material, Theme changes colours, Soft makes pillows safe.
blocks are merged rectangles, so a whole floor may be one node. smaller platforms = duplicate
one, change Size, move it. Map's Level Size sets the camera boundary, not the floor size.
Ctrl+S before F6. runtime Remote edits disappear when the game stops.

root node: story, music, win text, lighting colours. Sign: Text. Enemy: range/fire interval.
Pickup: Kind + Icon. Lamp: colour/strength/reach. NoSlingZone: Size + Bans Shots.
Shooter: launch speed, gravity, focus duration, slow-mo scale. Cam: zoom and follow strength.
character-specific overrides live in CharacterRig.LOOKS, so some Shooter values get replaced.
new level: duplicate a scene; menu order still needs its path in game.gd's LEVELS.
changed routes need fresh ghost recordings; old ghosts don't know about moved walls.

code trail, from a shot to the aftermath:
- shooter.gd: input, pull distance, shot + opposite velocity, gravity, collision, abilities.
- bullet.gd / grenade.gd: moving shots, hit checks, blast radius.
- block.gd: surface response, collision rectangle, explosions and drawing.
- level.gd: story -> camera pan -> aiming -> flying -> dead/win. wires player signals to UI.
- follow_cam.gd: follows ahead of velocity, zooms out with speed, adds decaying shake.
- character_rig.gd: springy body, sprites and speech. visual motion, not the physics collider.
- paint.gd: woobly lines. seed changes every 170ms. ms paint goes brrr.
- sfx.gd / post.gdshader: sounds, slowed music/reverb, screen tint.
- game.gd: level order, progress, mute, scene changes. save is user://save.cfg.
- level_map.gd: old text generator plus conversion to saved nodes. bypassed for manual layouts.
- target/enemy/pickup/no_sling_zone: finish, enemies, bonuses, restricted areas.
- lamp/doodle/sign/story_dog/pixel_backdrop: lights, props, notes, story animation, background.
- ghost.gd: playback of recorded runs. dev/dev_tools.gd: debug input/capture helpers.
- ui/: menu, characters screen, dialogue panels, death radio, win card, milk splash.

slow-mo = Engine.time_scale. focus and UI use delta / time_scale to keep real seconds.
shot direction points along the drag; recoil points backwards. pull length chooses speed.
first shot gets extra lift. floors/sticky walls reload; ordinary walls don't.
juice comes from several small things together: camera lead + speed zoom, impact shake,
body stretch/flail, trails, particles, sound. physics still belongs to Shooter.

exports use the matching Godot templates and export_presets.cfg. web upload needs every
file in build/web, index.html at the zip root. test through a server/itch, not file://.
keep export/convert_text_resources_to_binary=false (story text loading needs it).
source art, import settings, uid files and ghosts stay in git. .godot/ and build/ don't.

[credits](CREDITS.md), [commit-time build scraps](docs/BUILD_LOG.md).

menu layout now lives in scenes/ui/menu.tscn: real buttons, labels and texture rects.
Levels, Characters and Credits are hidden pages; toggle their eye icon to edit them.
hud labels live in scenes/ui/hud.tscn. runtime code fills their text.
doodles: select Map/Doodle, then Theme + Pick. movement uses Transform/Position.
the individual doodle strokes, wobbly block outlines and animated effects still use code.
