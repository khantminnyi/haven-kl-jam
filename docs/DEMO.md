# demo bits

**recoil** — aim right, fly left. drag length becomes launch speed; the first shot adds
upward lift. it replaces velocity rather than stacking it, so each shot is predictable.
`shooter.gd`: _pull, _launch_speed, _try_launch.

**slow-mo** — launch, then hold another drag in midair. Engine.time_scale ramps towards
0.12 while focus lasts, then back to 1 on release. physics gets slower delta, but focus
and UI divide by time_scale to keep real seconds. camera zoom, cold screen tint, lower
music pitch, reverb and a low-pass filter sell the effect together.
`shooter.gd`, `follow_cam.gd`, `sfx.gd`, `post.gdshader`.

**speed juice** — camera looks ahead along velocity and zooms out at speed. impact speed
controls shake, which fades out. trails are old positions drawn with less opacity;
the floppy character is visual spring motion, separate from the collision circle.
`follow_cam.gd`, `shooter.gd`, `character_rig.gd`.

**surfaces** — metal keeps more bounce, brick absorbs it, green goo stops + reloads,
glass breaks from shots, TNT sets off nearby TNT. floor hits reload; normal walls don't.
try a grenade at a brick barrier. `block.gd`, `grenade.gd`, shooter hit functions.

**woobly lines** — split a line into points and nudge them with a seeded offset.
change the seed every 170ms. the drawing wobbles, the collision doesn't.
`paint.gd`. one shared redraw tick, with offscreen drawing skipped.

**fast bullets** — raycast the whole next step, not just the endpoint, so a fast shot
can hit a thin wall. `bullet.gd` and `grenade.gd`.

**ghost** — recorded timestamps + positions, blended between samples. not an AI player.
it follows the old route even if the walls move. `ghost.gd`.

quick demo: shoot backwards -> aim midair -> bounce/stick -> grenade a wall -> show a
level edit in the Inspector and run it with F6. camera and slow-mo values are on Cam/Shooter.
