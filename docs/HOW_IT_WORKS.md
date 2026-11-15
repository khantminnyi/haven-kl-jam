# how le recoil works

techi techi breakdownn

## recoil

Dragging gives a direction and a distance. The distance becomes launch speed, and
the player gets pushed the opposite way. The first shot also adds upward lift.
Each shot replaces velocity, so aiming again gives a fairly predictable result.
The character's floppy limbs are just visuals; the actual collision is a circle.

Look in `scenes/player/shooter.gd`: `_pull`, `_launch_speed`, `_try_launch`.

## slow-mo

After launching, dragging in midair spends focus and moves `Engine.time_scale`
towards 0.12. That's about 12% of normal game speed. Releasing the drag or running
out of focus brings it back to 1. It ramps between them instead of snapping.

Godot slows `delta` too. Focus uses `delta / Engine.time_scale` so a second of
focus still costs a real second. The run timer and dialogue typing use the same
idea. Reloading refills focus, and aiming on the ground doesn't spend it.

slower movement, camera zoom, a cooler screen tint, lower music pitch, reverb and muffled high frequencies.


Start with `shooter.gd`'s `_process`, then `scenes/game/sfx.gd` and `follow_cam.gd`.


## the ghost

It's a recordig. During a run, the level records the time and player
position every physics frame. Winning an editor playtest saves it if it's faster
than the existing dev run.

`ghosts/level_0.json` is the tutorial, then 1 is soldier, 2 grandma and 3 lactose.
Each file has the finish time, an array of timestamps (`t`), and positions (`p`)
stored as x, y, x, y. Playback finds the two samples around the current run time
and blends between them. That keeps it smooth even between recorded frames.
There is no collision or replayed input. If a wall moves, the ghost still follows
its old route, so record a new run after changing a level layout.

These four JSON files are tracked by Git and explicitly included in both export
presets. Commit any changed ghost files, then export again to ship the new runs.
For itch.io, zip the Web export with `index.html` at the zip root, including its
`.pck`, `.wasm` and other generated files. The ghosts travel inside the pack.

Exported games replay those bundled runs without replacing them. Player best
times and unlocks live separately in `user://save.cfg`; they aren't Git files or
new ghost recordings. Browser saves aren't shared between people's devices.

See `scenes/game/game.gd` (`save_ghost`, `ghost_data`) and `scenes/player/ghost.gd`.

## dialogue and little story scenes


Lines use `speaker|text`. `sarge` gets the radio style, a name containing
`narrator` gets cinematic bars, and other speakers get speech bubbles. Clicking
finishes the typing, then another click advances. Player aiming is disabled
while the dialogue is active; this isn't a whole-tree pause.

A third part can trigger an action: `game narrator|some text|steals` spawns the
dog. Parenthesized directions advance after 2.8 seconds and can also trigger
cues, like the lactose guy turning around. `comic_panel.gd` emits the cue and
`level.gd`'s `_on_stage` handles what happens in the world.

## sound behind the scenes

`Sfx` handles the shared sound players. Radio lines start with a click, and
speech gets quiet ticks as letters appear. Narrator lines look for a
recording under `audio/voice/`.

Hits can pick different sounds with slightly different pitches so repeats feel
less identical. Slow-mo affects effects and music, while gliding adds a wind
loop. Camera shake, impact sounds and the short launch slowdown do a lot of the
work in making a simple shot feel heavy.

p.s. check out our splash.txt for an easter egg :0
