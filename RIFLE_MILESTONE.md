# Playable rifle milestone

Run Scenes/TestArena.tscn (configured main scene) in Godot 4.

Controls: WASD move, mouse look, Space jump, Shift slide, LMB automatic fire,
RMB hold sights, R reload, F6 respawn, Esc opens settings/resumes. The Resume button also resumes;
release LMB before firing again after resume or respawn.

The reusable Weapons/Assault_Rifle_01/AssaultRifle.tscn exposes RPM (600),
magazine (30), initial reserve (120), damage (25), range (100 m), reload time
(2.1 s), and optional fire/empty AudioStreams. Rifle geometry and markers come
from the original GLB. Grip anchors the model, muzzle anchors the flash and
obstruction checks. The imported Cube is hidden only on the runtime instance.
Weapon motion is procedural Godot animation: kick/recovery, magazine removal
and reinsertion, sway, bob, sight transition, and slide lowering.

Damage receivers implement take_damage(amount, hit_position, source) -> bool.
Return true only when damage is accepted. Four targets have 100 health and
reset three seconds after destruction. Camera aiming uses world collision
layer 1, excludes the player, then checks camera-to-muzzle and muzzle-to-aim
segments to prevent firing through cover. The rifle retracts near walls and
hides at very close contact; world geometry also naturally occludes it.

Reload commits ammo only when complete. Respawn cancels the animation and
preserves both ammo pools. Manual F6 reset preserves ammunition. Automatic respawn after elimination
now restores a fresh 30/120 supply. Sliding allows automatic hip fire and raises the rifle while firing; sights stay
disabled during a slide. Reloading and sliding may overlap; reloading blocks fire. Pause freezes player, weapon, targets,
and impact tweens. Resume clicks cannot become shots.

Validation: Tests/rifle_test.gd exercises initial values, movement, jump,
wall collision, fall respawn, damage, single and sustained fire, 600 RPM,
empty magazine, recoil recovery, invalid/partial reloads, reload interruption,
ADS, shooting while sliding, pause/rearm, both cover paths, target reset.
Run with:
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/ebenoelofse/Desktop/Vexora --script res://Tests/rifle_test.gd

Tests/rifle_visual.gd runs with a renderer and saves hip, ADS and reload PNGs
under Tests/. Metal/Forward+ visual captures were inspected. Headless startup
prints a macOS system certificate-store diagnostic; no game script/runtime
errors occurred in the passing tests or graphical run.

Limitations: No suitable sound assets exist in the project, so firing and
empty-magazine audio remain unassigned and silent. No first-person arms were
added. Muzzle flashes and impact effects are simple geometry. Weapon animation
is procedural, with no imported animation clips or changes to the source rig.

Changed/added implementation files:
- project.godot
- Scenes/FPSPlayer.tscn, Scenes/TestArena.tscn, Scenes/PracticeTarget.tscn
- Scripts/fps_player.gd, Scripts/test_arena.gd
- Scripts/assault_rifle.gd, Scripts/practice_target.gd
- Weapons/Assault_Rifle_01/AssaultRifle.tscn
- Tests/rifle_test.gd, Tests/rifle_visual.gd and visual captures
- RIFLE_MILESTONE.md (this file); Godot-generated UID/import sidecars

Future task, separate from this milestone: export/import the repaired Land
clip from Player_01.blend and connect landing transitions in fps_player.gd.
Land has not been exported or connected here. No GLB, Blender asset, character
scale, source rig, or existing character animation was edited in this work.
The pre-existing modified Player_01.blend and other uncommitted work were kept.

Update: Shift now triggers a slide with boost, lowered camera/capsule and cooldown.
See DEVELOPMENT.md for tuning and Tests/slide_test.gd for validation.

View settings: Esc opens sensitivity and vertical FOV sliders with local saving.
Airborne steering and shooting are supported; see DEVELOPMENT.md.

Health update: 150 HP, damage HUD, 2-second automatic respawn and 1-second
spawn protection. Red damage pad right of spawn allows testing before bots.
