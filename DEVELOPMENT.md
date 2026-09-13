# Vexora development

## Current milestone
Existing Godot arena: basic bot combat milestone complete. Scenes/TestArena.tscn remains
the playable main scene. Continue in Godot; the browser FPS brief provides the
long-term gameplay direction, not authorization to replace the engine or assets.

## Completed
- Three configurable practice opponents spawn by default. Set TestArena.bot_count
  to 0 for target-only practice, up to 8 for testing. No multiplayer added.
- Bots reuse the original player model/scale/rig and Idle/Run/Fall animations.
  Runtime armour tint distinguishes enemies; existing rifle grip follows the
  animated right hand. No GLB or Blender assets changed.
- Bots patrol baked routes, chase last-seen player positions, wait 0.65 seconds
  before firing, use line-of-sight and muzzle-cover checks, and reload.
- Defaults: 150 HP, 3.6 m/s, 12 damage, 0.3 s between shots, 3-degree spread,
  26 m detection range, 20-round magazine, 1.8 s reload, 3 s respawn.
  Tune these on Scenes/PracticeBot.tscn / Scripts/practice_bot.gd exports.
- Bot damage uses the existing rifle receiver contract and hit marker. Kills
  show an elimination notification and a practice elimination count.
- Bot respawns score existing spawn points by separation and cover. Player
  automatic respawns also choose distant points when bots are enabled.
- Bots freeze during pause, ignore dead/protected players, and have 0.8 s
  protection after respawn. Muzzle flashes and brief tracers show enemy shots.
- Navigation/test_arena_nav.tres is baked from the existing static map collision.
  Regenerate after map geometry changes with Tests/bake_bot_navigation.gd.
- Player has configurable 150 HP, reusable take_damage(amount, point, source)
  damage contract, health_changed/eliminated/respawned signals, invalid-damage
  rejection, damage flash and low-health HUD feedback. No passive regeneration.
- Lethal damage disables input/collision, hides the weapon/body, cancels reload
  and slide, and shows a two-second respawn countdown. Pause freezes the timer.
- Automatic respawn returns to the existing spawn, restores health and 30/120
  ammo, and grants one second of protection. Held fire must be released first.
- F6 remains a manual practice reset while alive: restores HP and preserves ammo.
  Falling below the arena now eliminates and uses the same two-second respawn.
- Red DAMAGE TEST pad at (-12, 0, 17), right of spawn, deals 25 HP each 0.5 s.
  Step off to stop damage. This is a temporary test fixture for the pre-bot stage.
- New files: Scenes/DamageZone.tscn, Scripts/damage_zone.gd,
  Scripts/health_hud.gd, Tests/health_test.gd and health screenshot captures.
- Existing player movement, jumping, map collisions and respawn.
- Ground movement now uses whole-vector acceleration with separate starting,
  stopping, turning, reversing and excess-speed recovery rates. Normal speed
  remains 4.5 m/s. Defaults: acceleration 14, release braking 12, turning 18,
  reversing 20 and slide momentum recovery 6 m/s²; exported on Player.
- From rest, full normal speed takes about 0.32 seconds. Releasing at normal
  speed stops in about 0.38 seconds with roughly 0.84 metres of coasting.
- Diagonal acceleration matches straight acceleration; no instant velocity
  snapping on turns. Slide exit excess speed eases toward normal speed.
- Air control now preserves takeoff/slide-jump momentum with light drag and
  moderate directional steering. Air acceleration 7 m/s², drag 0.25 m/s²,
  excess momentum decay 0.6 m/s²; steering cannot stack unlimited speed.
- Esc opens a pause/settings panel: mouse sensitivity 0.2–3×, vertical FOV
  70–110° (default 90°), reset defaults, Resume. Preferences apply live and
  save on resume/window close to user://settings.cfg. No click-anywhere resume.
- ADS preserves a consistent zoom ratio relative to the chosen FOV. Shooting
  stays available on the ground, in the air and while sliding; reload still
  blocks shots. Settings clicks cannot trigger shots on resume.
- Camera-mounted rifle, automatic fire, recoil, ADS, reload, ammo HUD and targets.
- Shift now slides instead of sprinting; shooting stays available during slides.
- Slide: 8.8 m/s initial boost, 0.7 s duration, no cooldown after ending,
  3.2 m/s minimum entry speed, 4 m/s² slide friction. Values are exported on Player.
- Feet-anchored 1.05 m capsule with smooth eye-height transition to 0.9 m.
  Low ceilings prevent standing until clear. Space exits slide into a jump.
- Tap Shift again to chain slides immediately after they end. Holding Shift does not auto-repeat; pause/resume and respawn clear pending input.
- Original concrete panels, orange construction panels and slate metal textures.
- Four reusable StandardMaterial3D resources in Materials/Arena.
- Scripts/arena_materials.gd applies materials to the map instance in editor and
  runtime using world-space triplanar mapping. No UV unwrap is required.
- Textures/Arena contains the PNG sources, import settings and full generation
  prompts in GENERATION.md. Created using the built-in image_gen tool.
- Texture imports capped at 256 pixels with mipmaps; material filtering uses
  nearest sampling with mipmaps and anisotropy for crisp, stable surfaces.

## Material assignment
- Floor: lightly tinted concrete, approximately one-metre panel spacing.
- Walls, screens and platforms: concrete panels.
- Ramps and crates: orange construction panels.
- Barriers and stairs: slate structural metal.
Tune tint, roughness and UV1 scale in Materials/Arena/*.tres. Change assignment
rules in Scripts/arena_materials.gd. Imported GLB resources remain unchanged.

## Validation
- Graphical Godot Metal/Forward+ run completed without game errors.
- Inspected spawn, ramp/platform and crate views captured by
  Tests/arena_visual.gd as Tests/arena_textures_{spawn,ramp,crates}.png.
- Existing Tests/rifle_test.gd passed: movement, jump, map walls, damage,
  fire timing, sustained fire while sliding, reload, pause, targets, respawn.
- Headless Godot emits its existing macOS certificate-store diagnostic.
- Tests/slide_test.gd passes boost, camera, capsule, immediate slide chaining, held-key, shooting,
  pause, jump, air rejection, roof clearance, respawn, ramp and wall checks.
- Tests/slide_visual.gd rendered slide/shoot and recovered views without errors.
- Tests/momentum_test.gd passes acceleration, diagonal parity, stopping,
  turning, reversing, slide-speed recovery, 30/120 Hz consistency, real-player
  coasting, pause and respawn checks, both headless and with Metal rendering.
- Rifle and slide regression suites passed after the movement changes.
- Tests/air_settings_test.gd passed air momentum, steering, speed limit,
  diagonal parity, airborne shooting, settings application, persistence,
  invalid values, defaults, ADS FOV, respawn and resume-trigger checks.
- Graphical Metal run also verified captured mouse sensitivity and rendered
  Tests/settings_view.png. Headless tests skip captured mouse input because
  the headless display cannot capture a pointer.
- Tests/health_test.gd passed in headless and graphical Metal runs: damage,
  invalid/repeated hits, death, movement/fire/reload/slide restrictions, pause,
  exactly-once auto-respawn, ammo reset, trigger rearm, spawn protection,
  damage-zone entry/exit, full death/respawn cycles and falling.
- Inspected Tests/health_damage.png, health_eliminated.png, health_respawn.png.
  Existing movement, slide, rifle and view settings suites all passed.
- Tests/bot_test.gd passes patrol movement, cover routing, detection, shooting,
  reload, player rifle hits, elimination counting, respawn, protection, reaction
  delay, pause and ignoring dead players; also passed a graphical Metal run.
- Tests/bot_soak.gd simulated 60 seconds: all three bots navigated and fired;
  a new player life spawned over 38 m from the closest bot in that scenario.
- Existing movement, slide, rifle, health and view-settings regressions pass.
  These isolate their fixtures with bot_count=0; bot tests run real opponents.
- Inspected Tests/bot_combat.png from the graphical combat test.
- Navigation implementation reference: https://docs.godotengine.org/en/stable/classes/class_navigationmesh.html
- Browser performance and Compatibility rendering have not been validated.

## Known limitations
- Bots currently fight the player, not each other. This is a practice skirmish,
  not a timed free-for-all match. No advanced tactics, jumping or slide AI.
- Bots navigate ground routes and ramps. Dedicated stair traversal and more
  sophisticated crowd avoidance remain future improvements.
- Existing locomotion animations are reused; a bespoke two-hand rifle aiming
  pose, reload animation and death animation for bots remain future polish.
- Bot gunshots remain silent because firing audio assets are still missing.
  Player damage audio is also missing. Tracers are simple temporary geometry.
- This is the existing test layout with a new material pass, not the future
  vertical construction arena. No new geometry or jump pads in this milestone.
- Firing and empty-click sound assets are still missing. No first-person arms.
- Triplanar mapping projects patterns onto sloped surfaces; authored UVs may be
  useful later for directional details or bespoke props.

## Future work (not started)
- Review texture look, then choose the next gameplay or map milestone.
- Next planned milestone: improved vertical arena. Later: improved vertical arena,
  jump pads, match HUD and loop, authoritative multiplayer and browser testing.
- Separately export/import the repaired Land animation and connect it to the
  controller. No Blender or game-build export was performed in this work.

## Asset preservation
Character scale, rig, original animations, weapon GLB and map GLB were preserved.
The pre-existing modified Player_01.blend was not changed by this texture pass.
