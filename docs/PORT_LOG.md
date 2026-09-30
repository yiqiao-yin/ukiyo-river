# Port log

One entry per phase: what got built, where it differs from
`reference/ukiyo-river.html` and why, and what to look for on F5.

---

## Phase 1: world foundation

### Built
- `scripts/ukiyo_math.gd` (`UkiyoMath`) — `hash2`, `vnoise`, `fbm`, `smooth`, `angleLerp`,
  `riverX`, `riverSlope`, `terrainH`, `waveH`, `WAVES`, `RIVER_HALF`. The 32-bit JavaScript
  hashing is emulated by carrying every hash value as an unsigned 32-bit int; `Math.imul` is
  split into 16-bit halves so no intermediate product can overflow a signed 64-bit int.
- `scripts/ukiyo_rng.gd` (`UkiyoRng`) — `mulberry32`, with the prototype's world seed 20260923.
- `scripts/tools/noise_check.gd` — 37 assertions against values captured from the prototype's own
  JavaScript under Node (listed in `docs/NOISE_CHECK.md`). **All 37 match**, including
  `terrainH`, `riverX`, `riverSlope` and the first eight draws of the world RNG. The maths port
  is exact, so terrain, landmark placement and tree scattering will land where the prototype puts
  them.
- `scripts/terrain.gd` — 900 m × 900 m, 230 × 230 segments, displaced by `terrainH`, per-vertex
  colours from the prototype's five base colours blended by `vnoise`, height and slope.
- `scripts/water.gd` — flat placeholder plane at y = 0 in `TIMES.night.deep`. Phase 2 replaces it.
- `shaders/sky.gdshader` — the prototype's sky fragment shader as a Godot `shader_type sky`.
- `scripts/environment_controller.gd` — the whole `TIMES` / `WEATHERS` table, `targetEnv()` and
  `stepEnv()`, driving the fog, ambient light, sun and sky uniforms every frame.
- `scripts/camera_rig.gd` — Phase 1 inspection camera.
- `scripts/tools/screenshot.gd` + `scenes/screenshot.tscn` — renders `main.tscn` offscreen and
  writes `shot.png`. Headless runs never create a rendering device, so they cannot catch a broken
  shader or a black screen; this can.

### Differences from the prototype
1. **Colour space.** three.js r128 in legacy mode writes hex colours straight to the framebuffer.
   Godot converts linear → sRGB on output, so every hex constant goes in through
   `Color.srgb_to_linear()`. Same pixel out, different number in.
2. **Sky uniforms are not `source_color`.** The controller already hands over linear colours; a
   `source_color` hint would convert a second time and sink the sky to black. (It did, at first.)
3. **Fog curve.** three's `FogExp2` is `exp(−(d·density)²)`; Godot's exponential fog is
   `exp(−d·density)`. The prototype's density number is used as-is, which makes the two curves
   agree at the `1/density` e-fold distance — closer in than that Godot fogs slightly more, further
   out slightly less.
4. **`fog_sky_affect = 0`.** Godot's fog tints the sky dome by default, which double-fogs it: the
   ported sky shader already does the prototype's own `mix(col, uFog, …)` horizon blend.
5. **No hemisphere light.** Godot 4 has no `HemisphereLight`. `TIMES.*.hemiSky` and `hemi` become
   `Environment.ambient_light_color` / `ambient_light_energy`; the `hemiGround` term is dropped.
6. **Light intensity is not numerically portable.** three.js and Godot use different light units.
   Under a pure-gamma model the faithful ambient energy would be `hemi^2.2` (0.135 rather than
   0.403) — the prototype's raw number is used instead, which reads slightly brighter and leaves
   more to look at. This is the main thing worth tuning in the editor.
7. **Shadows.** The prototype freezes its shadow map and uses a ±7 m ortho box around the boat.
   Godot has no "don't update shadows" switch, so shadows refresh every frame with
   `directional_shadow_max_distance = 20` standing in for the tight box.
8. **Triangle winding.** Godot's front faces wind clockwise, the reverse of three.js. Verified
   against `PlaneMesh`'s own index buffer rather than guessed; the terrain's two triangles per
   quad are flipped accordingly.
9. **Phase 1 camera is scaffolding, not the prototype's camera.** Drag sensitivity and the pitch
   clamps are the prototype's, but the zoom ceiling is opened from 40 m to 400 m and WASD walks
   the orbit target so the whole valley can be looked over. Phase 3 replaces all of it.

### What to look for when you press F5
The scene opens on the prototype's default **stormy night**, at the boat's starting position
(`riverX(-335), −335`), 40 m back from it.

- **It will be very dark.** That is the preset, not a bug: at night + storm the prototype's own
  terrain sits at roughly 2 % grey, and every bright thing in that scene — the bow lantern,
  water reflections, shore lanterns, lightning — arrives in Phases 2, 3 and 5. What you should be
  able to make out is a mountain silhouette against a faintly banded sky and the cloud deck
  drifting across it.
- **To actually judge the valley, switch the preset.** Select the `EnvironmentController` node
  and set `Time Key` to `day` and `Weather Key` to `clear` in the inspector. You should get: the
  river winding away between two banks, steep mountains closing in on both sides, distant ridges
  fading into fog, and a blue-grey sky gradient. The river channel should be a clean ~34 m-wide
  flat corridor with no terrain poking through the water plane.
- **Controls:** left-drag to orbit, mouse wheel to zoom (4.5 m to 400 m), WASD to walk the point
  you are orbiting along the valley. Fly up and down the river with WASD to check the banks over
  the full ±450 m.
- **Console:** `[noise_check] all values match the JavaScript prototype` on startup. If that line
  ever turns into errors, the world has silently shifted and nothing downstream can be trusted.

### Still open
- Whether the night ambient level wants raising for playability, or should stay faithful.
- The valley has no landmarks, trees, boat or real water yet — Phases 2 onward.

---

## Phase 2: water shader

### Built
- `shaders/water.gdshader` — the prototype's `waterMat` ported: the four-component wave sum
  (height in `.x`, gradient in `.yz`), the downstream flow-noise gradient, both octaves of rain
  ripple rings with the `exp(−camDist·0.035)` LOD, the boat bow wave, the Fresnel term, the
  lantern specular and light pool, sun/moon glitter, stern foam, the lightning term, and the
  hull cut-out `discard` using the prototype's `sec()` profile inline.
- `shaders/noise.gdshaderinc` — `h21`/`vn` lifted out of `sky.gdshader` so both shaders share
  one copy, as the prototype shares one `NOISE_GLSL` string, plus the wrapped variants below.
- `scripts/water.gd` — feeds the shader the eleven values the prototype recomputes per frame.
- Water mesh and material are sub-resources in `main.tscn`: a 900 m `PlaneMesh` at the
  prototype's 110×110 subdivision, so both stay tunable in the inspector.
- `scripts/tools/screenshot.gd` now also reports average frame time.

### Two things found by rendering it
1. **Hash precision — fixed.** The first render came out covered in flat, axis-aligned tiles.
   Not the mesh (4× tessellation changed nothing) and not SSR (disabling it changed nothing):
   `h21` multiplies its input by 456.21 and takes `fract`, and world-space lattice coordinates of
   several hundred push that product into the range where a 32-bit float only resolves to about
   0.008. Neighbouring cells quantise onto the same hash and the noise field collapses. The
   prototype has the identical weakness — it never showed there because its water sampled a
   blurred half-resolution reflection target, whereas a near-mirror Godot surface magnifies every
   normal artefact. `vn_wrapped` / `h21_wrapped` wrap the lattice onto a 512-cell torus before
   hashing, which keeps the hash argument small. The period is 320 m to 930 m of world space at
   the scales in use, so the repeat is never visible. Water only; the sky's inputs stay small
   enough not to need it.
2. **The ReflectionProbe was dropped, deliberately.** The handoff asked for SSR plus a
   ReflectionProbe fallback. Built and measured, the probe makes the water *worse*: a box probe
   over a 900 m river captures mostly dark bank, and that capture overrides the sky reflection,
   turning the near-field water black — most obvious at dusk, where without the probe the river
   carries the whole sunset and with it the foreground goes flat. It also cost ~10 % frame time
   and produced a leaked-texture warning at shutdown. Environment SSR plus sky reflection is both
   better looking and cheaper here. Worth revisiting in Phase 5, when lit windows and shore
   lanterns give a local probe something worth capturing.

### Other differences from the prototype
3. **Reflections.** The prototype rendered the scene a second time through a mirrored camera into
   a half-resolution target and blended with `mix(deep, refl, fres + 0.3)`. Here the shader hands
   the engine a normal and a low roughness and lets SSR and the sky do it. The `+ 0.3` floor —
   30 % reflection even looking straight down — is not physical and has no direct equivalent;
   `u_refl_boost` on the material stands in for it and is the knob to turn if the water reads too
   dark from above.
4. **Fog.** The shader's hand-rolled `exp(−density²·dist²)` term is gone; `Environment` fog covers
   it, with the curve caveat from Phase 1.
5. **Highlights are EMISSION.** The prototype sums its speculars, foam and flash straight into
   `gl_FragColor`; in Godot they go through `EMISSION` so the engine's own lighting still applies.
6. **`u_deep` is the body colour only.** Because the engine now supplies reflections, `ALBEDO`
   carries `uDeep * (0.35 + 0.65·amb)` and the mix against a reflection texture is gone.

### What to look for when you press F5
Still the stormy night, still no boat — the boat couplings (`u_boat`, `u_boat_dir`, `u_speed_n`,
`u_lamp_pos`) are wired but parked far off the plane, so no wake, no foam, no hull cut-out yet.

- **Rain ripple rings.** The clearest thing in the scene: overlapping circles expanding and fading
  across the water, densest near the camera and thinning with distance. This is the one place the
  stormy night is genuinely legible.
- **Wave motion.** Drifting swell with finer noise detail riding on it, moving downstream.
- **Set Time to `dusk` or `day` with Weather `clear`** to judge the reflections — the river should
  carry the sky colour, with a bright specular streak where the sun is. Check there is no tiling:
  the surface should read as continuous noise everywhere, right out to the far bank.
- **Frame time** is printed by the screenshot tool: currently 2.86 ms (349 fps) at 1280×720.

### Still open
- `u_refl_boost` and `u_roughness` are the two water knobs; both are on the material in the
  inspector.
- Whether to bring a ReflectionProbe back in Phase 5.

---

## Phase 3: boat and controls

### Built
- `scripts/mesh_util.gd` — shared geometry helpers. Builders pass corners in the prototype's
  counter-clockwise-from-outside order and `Buffer` emits them reversed for Godot, so no call
  site has to think about winding. Also cones, lathes, boxes, ring skinning and caps.
  `terrain.gd` now uses its normal routine instead of its own copy.
- `scripts/boat_builder.gd` — the prototype's boat: `sec()`, `profilePt()` and the lofted hull
  (65 stations × 42 section points, outer shell, inner shell 6 cm inboard, both end caps), the
  four gunwale tubes, the deck strip with its thwarts and transom, the stem post, the sagging
  half-cylinder canopy with four bamboo hoops and a ridge pole, and the mast, arm, cord, lathed
  paper lantern and its caps.
- `scripts/boat.gd` — `updateBoat()` in full: thrust and steer, the Drift autopilot, the speed
  and turn integrators, bank and z clamps, wave-sampled pitch and roll, the poling phase, and
  the lantern flicker driving light, paper and glow.
- `scripts/camera_rig.gd` — Follow, Boatman and Orbit, with the prototype's sensitivities,
  clamps, smoothing and ground clearance.
- `scripts/tools/setup_input_map.gd` — writes `ukiyo_forward` / `back` / `left` / `right`
  (WASD + arrows) into `project.godot` via ProjectSettings rather than by hand-editing, so the
  mapping is reproducible and still remappable in Project Settings > Input Map.
- `scripts/tools/boat_check.gd` — **the physics is verified, not just ported.** The Drift
  autopilot is deterministic, so the prototype's trajectory can be captured and replayed: 200
  simulated seconds at a fixed 1/60 s, from the start at z = -335 down to the far limit, through
  the turnaround and part of the way back. All seven tracked values match at every checkpoint,
  which covers the autopilot steering, the `atan2` heading error and its wrap, the bank clamp,
  the z clamp and both integrators.

### Three bugs the renders caught
1. **Three surfaces were wound inside-out** — canopy, deck and hoops. Their normals pointed
   inward, so the awning lit like a flat slab and the deck's front face aimed at the riverbed.
   Fixed by reordering the quads; the reasoning is in comments at each site.
2. **One hull end cap faced into the boat.** The prototype emits both caps with identical
   winding, which is harmless with `THREE.DoubleSide`, but leaves one cap lit from the wrong
   side here. `Buffer.cap_fan()` now sums the fan's face normals and flips the whole cap if it
   disagrees with the direction it should face, so neither end can be wrong.
3. **The boat had no transform until its first tick**, so the camera started at the origin and
   spent its first seconds crawling 335 m up the river to catch up. `_ready()` now places it.

### Differences from the prototype
4. **The hull cut-out runs to the transom.** The prototype discards water from 3 % along the
   hull, leaving a 25 cm band standing inside the transom. Invisible against its blurred
   reflection target; against a near-mirror surface it catches the lantern and blows out to
   white. The cut-out now starts at the transom itself. The bow margin is unchanged.
5. **The boat runs on `_process`, not `_physics_process`.** The prototype drives everything from
   one loop with one clock; this keeps the boat on the same `elapsed` as the waves and the
   environment, and stops the camera reading a 60 Hz transform on a 300 fps frame.
6. **Rails sample `sec()` directly.** The prototype fits a Catmull-Rom spline through 33
   stations; evaluating the section function at every tube segment is the same curve without the
   spline approximation.
7. **The lantern's falloff is exact.** three.js r128 in legacy mode uses
   `pow(1 - d/range, decay)` — the same formula Godot's `omni_attenuation` uses — so range 26 and
   attenuation 2 carry over unchanged. Only the energy scale is engine-specific; it is on the
   `LanternLight` node if the pool of light wants tuning.
8. **The boat is untextured.** The prototype paints planks, weave, bamboo and lantern paper onto
   canvases at load. Those become generated PNGs in Phase 7, where the boatman's straw, cape and
   fabric textures are needed too; for now each material carries its texture's base tone. The
   lantern paper's 川 characters come with that pass.
9. **No boatman yet** (Phase 7). The Boatman camera sits on an `Eye` marker at the prototype's
   computed eye position, which Phase 7 reparents to the actual head.
10. **Drift cannot be switched back on** once player input turns it off — the prototype only
    re-enables it from the Drift button, which arrives with the UI in Phase 4.

### What to look for when you press F5
The boat is there, lit, and moving on its own down the river in the dark.

- **Drift is on**, so the boat poles itself downstream, steering to follow the channel. Left it
  alone for a few minutes and it will run the length of the river, hit the limit at z = 390 and
  turn around.
- **Take the helm** with W/S (forward and back) and A/D or the arrows (steer). Any input switches
  Drift off — and there is no way back until Phase 4, so restart to get it again.
- **Camera:** left-drag to look around, wheel to zoom 4.5–40 m. The View button is Phase 4, so
  Follow is all you get on F5; the other two modes are checked and working.
- **Look for:** the lantern swinging at the bow with its light pooling on the water and a flicker
  in it; rain rings breaking around the hull; the water correctly cut away inside the boat, with
  no bright patch at the stern; the boat pitching as it rides the swell and heeling into turns.
- **Switch to `day` / `clear`** on the EnvironmentController to actually see the boat: lofted
  hull with an upswept bow, gunwale rails, the arched canopy with its bamboo hoops, the deck and
  thwarts, the mast and hanging lantern.
- **Console:** both `[noise_check]` and `[boat_check]` should report a match.
- **Frame time:** 2.83 ms (354 fps) at 1280×720.

### Still open
- The lantern's light energy is the one number that cannot port exactly; worth an eye at night.

---

## Phase 4: weather and time

### Built
- `scripts/lightning.gd` — `strike()`, `jag()`, `ribbon()` and `flashAt()` ported. A bolt picks a
  bearing and a distance (22 % chance of a close one), subdivides cloud base to ground seven
  times, expands into a camera-facing ribbon with three forks, and runs the five-pulse flash
  envelope. The flash drives the sky shader, the sun's colour and energy, the ambient level, the
  water and the rain tint; while it is bright the directional light swings onto the bolt's
  bearing, as in the prototype.
- `scripts/audio_director.gd` — the Web Audio graph rebuilt on one `AudioStreamGenerator`. Three
  noise beds (band-limited white for rain, brown rolled off at 380 Hz for wind, brown through a
  520 Hz bandpass at Q 0.8 for lapping) plus thunder as a lowpass sweeping 1200 Hz down to 90 Hz
  over five seconds under a four-stage envelope, and a highpassed crack for near strikes. Biquads
  and noise are evaluated per sample in GDScript at 22 050 Hz. **No audio files.**
- `scripts/weather.gd` + `scenes/weather.tscn` — rain and petals as `GPUParticles3D` following
  the camera, with `amount_ratio` thinning the drops the way the prototype's `setDrawRange` did.
- `scripts/ui.gd` + `scenes/ui.tscn` — the five buttons, cycling in the prototype's order.
- Explicit `process_priority` ordering across the scene: lightning writes the flash, the
  environment applies it, the boat moves, water and weather read both, the camera follows last.
  The prototype gets this free from its single loop; in a node tree it has to be stated.
- `scripts/tools/audio_check.gd` — **the audio is verified.** Headless runs use a dummy driver
  and never make a sound, so silence, a NaN, a dead filter or a bed wired to the wrong noise
  source would all ship unnoticed. Each bed is rendered alone and checked for level and for
  zero-crossing rate, which stands in for brightness without an FFT. Rain comes out at 0.375
  crossings per sample (near-white), wind at 0.011 (a deep rumble), and lapping at 0.050 —
  which is 2 × 520 / 22050, so the bandpass is sitting exactly where the prototype put it.
  Thunder rises to full scale and decays to silence.

### Two things the renders caught
1. **Drops were spawning on the lens.** The emission box was centred on the camera, so a few
   drops appeared a few centimetres away and smeared a quarter of the screen. The prototype only
   ever recycles a drop to somewhere overhead, so both emitters now sit above the camera in their
   own local transforms — rain 27.5 m up, petals 7 m up, matching the heights the prototype
   recycles to.
2. **Petals were being fed sRGB values as linear**, which made them brighter than the
   prototype's pink. Converted, like every other colour in the project.

### Differences from the prototype
3. **Rain drops do not accelerate.** The prototype gives each drop a constant velocity, so the
   wind goes into the emission direction rather than into particle gravity. Because the fall
   speed varies 22–32 m/s while the wind drift is fixed, a single emission direction is a close
   approximation rather than an exact one.
4. **Audio runs at 22 050 Hz.** The prototype's highest filter corner is 6.5 kHz, so 11 kHz of
   bandwidth loses nothing audible and halves the per-sample cost of running the filters in
   GDScript.
5. **Lowpass and highpass use a Butterworth Q.** The prototype leaves Q at the Web Audio default
   for those stages; 1/√2 is the flat, non-resonant response that implies. The bandpass keeps the
   prototype's explicit Q of 0.8.
6. **The buttons are unstyled.** The prototype's bar is a rounded translucent panel in Shippori
   Mincho. Fonts and styling are Phase 8, along with the title screen and the 浮世川 mark.

### Known warning, not a project bug
`1 ObjectDB instance was leaked at exit` appears on every run that plays audio. It is Godot's
audio server still holding the generator's playback at shutdown: the project keeps no reference
to it (the playback is fetched per fill, and the player is stopped in `_exit_tree`), and deleting
the `AudioStreamPlayer` node makes the warning disappear. Nothing in project code can release it.

### What to look for when you press F5
The scene is now the prototype's, minus the landmarks and trees.

- **Rain** falling at an angle across the whole view, ringing the water where it lands.
- **Lightning** every 4–13 seconds: the sky and the whole valley flash, the bolt itself is drawn
  for 0.6 s somewhere on a random bearing, and the thunder follows a moment later — the delay is
  the sound travelling, so distant strikes rumble late and near ones crack.
- **Sound.** Rain hiss, a wind bed under it, water lapping that rises with speed. Sound is on by
  default; the button mutes it.
- **The five buttons, top right.** Weather cycles Storm → Rain → Clear, Time cycles Night → Dusk
  → Day, View cycles Follow → Boatman → Orbit, and Drift and Sound toggle. Switching back to
  Storm pulls the next bolt in to 1.5 s so you are not left waiting. Every transition eases over
  about a second rather than snapping.
- **Drift is now recoverable** — the button turns it back on after you have steered.
- Try **Clear / Dusk**: the rain stops, the storm clouds clear off, and the sunset lays a long
  reflection down the river.
- **Frame time:** 2.76 ms (362 fps) at 1280×720 with rain at full.

---

## Phase 5: architecture and lanterns

### Built
- `scripts/architecture_builder.gd` — `torii()`, `house()`, `pagoda()`, `toro()`, `bridge()` and
  `stilt()`, each in its own local space with the prototype's dimensions.
- `scripts/architecture.gd` — the 14-entry landmark table placed along the river, the exclusion
  circles, the roadside stone lanterns every 30 m on alternating banks, and the two shore lights
  that chase the nearest two lanterns twice a second. Everything sharing a material is merged
  into one mesh, which is what the prototype's `bakeStatic()` does: 11 surfaces for the whole
  world's architecture.
- `scripts/floating_lanterns.gd` — 40 paper lanterns on two `MultiMeshInstance3D`s, drifting
  faster than the current, wrapping around the boat, nudged aside by the hull.
- `scripts/world_rng.gd` — holds the single `mulberry32(20260923)` stream the world is laid out
  from, and documents the consumption order that has to be preserved.
- `scripts/tools/world_check.gd` — **the world layout is verified.** The prototype draws from one
  stream in a fixed order: village houses, then floating lanterns, then trees. The lanterns are
  the sharp end of it — their 120 numbers come off the stream only after every village house has
  drawn its five, so if a village consumed the wrong count or drew in the wrong order, they all
  land somewhere else. Five of them are checked against the JavaScript, plus the stone lantern
  count, which depends on every exclusion circle being registered.

### Primitives rewritten
1. **Boxes were shading like rounded blobs.** `add_box` shared eight corners, so every corner
   averaged three face normals. `BoxGeometry` has per-face normals and nearly every building
   here is a box, so boxes now emit four vertices per face. Cylinder end caps got the same
   treatment — they had been blending into the wall and rounding off a hard rim.
2. **New primitives** to match the prototype's vocabulary: `add_pyramid` for `roofGeo`,
   `add_sphere`, `add_bent_bar` for `bendBox`, and `append_transformed` for the merge.
   The pyramid is worth a note: the prototype's roof is a 4-sided cone of radius 1 turned 45°,
   so after scaling the base corners sit at 0.707 × scale and the base is 1.414 × scale across.
   The roof is *wider* than the scale factor, and that overhang is what gives the eaves.

### One thing that turned out not to be a bug
Seen from far off through fog, the village houses looked like they were floating above the bank.
Before changing anything I measured it: the analytic `terrainH` the houses are placed at differs
from the tessellated mesh surface by at most 0.5 m at those positions, and a fixed camera over
the village shows them sitting correctly on the ground. It was a misread of a hazy distant view.
Recorded because the check is the useful part, not the outcome.

### Differences from the prototype
3. **The builders live in one file, not six.** `docs/PORT_PLAN.md` proposed
   `scripts/builders/*.gd` per structure; each is fifteen to thirty lines, so they read better
   together, matching the `boat.gd` / `boat_builder.gd` split already in use.
4. **Merged at build time rather than after.** The prototype assembles scene graphs and then
   flattens them with `bakeStatic()`. Here each structure is built into per-material buffers and
   appended under its transform, which reaches the same place without the intermediate nodes.
5. **Stone lantern light falloff** carries over exactly, as the bow lantern's did: three.js
   legacy `pow(1 - d/range, decay)` is Godot's `omni_attenuation` formula, so range 16 and
   attenuation 2 are unchanged. Only energy is engine-specific.

### What to look for when you press F5
The river has landmarks now. Drift carries you past them, or hold W to get there faster.

- **Heading downstream from the start** (z = -335): a village on the right bank, then a torii
  standing at the water's edge with a shrine, a second gate and flanking stone lanterns behind
  it, a stilt house out over the water on its piles, an arched vermillion bridge, the five
  storey pagoda, and more villages and gates beyond.
- **Stone lanterns** every 30 m or so along the banks, alternating sides, skipping anywhere the
  ground is wrong or a landmark is in the way. Only the nearest two actually cast light — watch
  them hand off as you pass.
- **Floating paper lanterns** drifting down the river around you, glowing, reflecting on the
  water, and nudging out of the way if you run into them.
- **Windows** lit at night and nearly out by day — try the Time button.
- **Frame time:** 2.63 ms (380 fps) at 1280×720, unchanged, because the whole world's
  architecture is 11 draw calls.

---

## Phase 6: trees

### Built
- `scripts/tools/canvas2d.gd` — a small software rasteriser. Godot's `Image` has no drawing API
  at all, so the canvas operations the prototype actually uses (filled rects, stroked lines and
  polylines, quadratic curves, rotated filled ellipses with an optional radial gradient, vertical
  gradients) are implemented directly.
- `scripts/tools/generate_textures.gd` — writes the painted textures to `assets/generated/` once.
  Three barks with their bump variants, the cedar frond, the pine tuft and the cherry spray.
  Each keeps the prototype's mulberry32 seed, so the grain and the scatter come out of the same
  sequence. Takes about two seconds.
- `scripts/tree_builder.gd` — `GB.tube()` and `GB.card()`, then `buildSugi`, `buildMatsu` and
  `buildSakura` including the recursive cherry branching. The cards carry authored normals
  pointing out of the crown rather than out of the quad, plus an ambient occlusion term in the
  vertex colour; that is what stops a flat quad reading as a flat quad.
- `scripts/trees.gd` — the rejection sampler, the four species lists, and one
  `MultiMeshInstance3D` pair per species variant with per-instance tint.
- `shaders/tree_sway.gdshaderinc`, `trunk.gdshader`, `foliage.gdshader` — the sway injected into
  `MeshPhongMaterial` by the prototype's `onBeforeCompile`, now a shared include. The per-instance
  phase offset comes from `MODEL_MATRIX[3]`, which is where a MultiMesh keeps what the prototype
  reads out of `instanceMatrix[3]`.

### The forest is verified tree for tree
The scatter loop is the most fragile thing in the port: a rejected attempt consumes three random
numbers and stops, an accepted one consumes six, and it runs at the tail of the shared stream
after every village and floating lantern. Get the branch wrong anywhere and the whole forest
moves. `world_check` now asserts the four species counts and the first placement of each against
the JavaScript:

```
851 cedar near, 1142 cedar far, 196 pine, 111 cherry
```

All four match exactly, as do the positions, which means the entire chain — villages, lanterns,
then 9000 scatter attempts with their rejections — is drawing the prototype's numbers in the
prototype's order.

### Differences from the prototype
1. **Trunks are wound outward.** The prototype's `GB.tube()` emits triangles whose front faces
   point *into* the tube, while its trunk material is single sided — so its trunks are drawn
   from the inside of the far wall. At trunk scale that still reads as a trunk, which is
   presumably why it went unnoticed. Winding them outward is the only defensible reading.
2. **A headless script, not an EditorScript.** `docs/PORT_PLAN.md` proposed an EditorScript for
   the textures; a `--script` tool does the same job once and can be run from WSL without
   opening the editor, which is how everything else in this project is driven.
3. **Not pixel-identical textures.** Same draw calls, same seeds, same structure, but the
   rasteriser is not the browser's — line joins and antialiasing differ.
4. **Far cedars are no longer hidden from reflections.** The prototype keeps a `treeFarMeshes`
   list and hides it while rendering its mirror pass. That pass is gone (Phase 2), so there is
   nothing to hide them from; screen-space reflections simply reflect what is on screen.
5. **Bump maps become normal maps.** three.js `bumpMap` perturbs the normal from a height
   gradient; Godot wants a normal map, so the greyscale bark variants are fed through
   `NORMAL_MAP` with a modest depth. Close, not identical.

### What to look for when you press F5
The banks are forested now.

- **Cedar** everywhere, near ones with crossed sprays and far ones cheaper and slightly paler,
  thinning out as the ground rises.
- **Black pine**, low and leaning, close to the water.
- **Cherry** in blossom, only within 48 m of the river — look for the pink among the green.
- **Wind.** Switch Weather between Clear and Storm and watch the whole forest lean harder and
  the foliage flutter: the sway scales with the same wind value that drives the waves and rain.
- **Frame time:** 2.77 ms (361 fps) at 1280×720 with 2300 trees — unchanged, because each
  species variant is a single multimesh draw.

### Still open
- Falling petals read as hard pink squares up close. The prototype's are the same size and
  equally square (`THREE.Points`, size 0.13), so this is faithful rather than broken, but it is
  the one thing on screen that looks more like a placeholder than a choice. Easy to soften with
  a texture if you would rather.

---

## Phase 7: boatman and boat details

### Built
- The remaining painted textures: hull and deck planks with their bump variants, the canopy
  weave, straw fibre, the cape strands, four fabrics (kimono, pants, gaiters, obi), bamboo and
  the lantern paper. Fifteen more images out of the same generator, about thirty seconds.
- `scripts/boat_materials.gd` — the prototype's whole `BM` table in one place, shared by the
  boat and the boatman, with the per-frame wetness that makes every surface glossier in rain.
  The boat's flat stand-in colours from Phase 3 are gone.
- `scripts/boatman.gd` + `scenes/boatman.tscn` — the figure: legs, sandals and thongs, the
  lathed torso, sash and knot, collar, three layers of straw cape, neck, head with jaw, nose,
  ears, brows, hair and topknot, the conical hat with its lining, rim and finial, the bamboo
  pole, and twelve loose arm pieces. Two-bone IK (`solveArm`) plants both hands on the pole
  every frame, and the poling cycle drives the torso, head and pole together.
- `scripts/rain_splashes.gd` — four `GPUParticles3D`: splashes off the canopy and the hat,
  drips off the gunwales and the hat brim. Each emitter is a point cloud sampled from the same
  surface the prototype spawns on, and each system's `amount` is the prototype's rate times its
  lifetime, so the same number of drops is in the air.
- The Boatman camera now sits on a marker parented to his head, and he is hidden in that mode.

### The 川 on the lantern is drawn, not typeset
The prototype sets the character with a Google font. Shipping a font for two glyphs is silly and
loading one at runtime is worse, so 川 is drawn directly: three strokes, the left one hooking
away at the foot, the middle short, the right running the full height. No font in the project.

### Differences from the prototype
1. **Bump maps become normal maps.** three.js `bumpMap` perturbs the normal from a height
   gradient; Godot has no equivalent, so the greyscale variants are fed through `NORMAL_MAP` at
   modest depth. Close, not identical.
2. **Splashes are emitted from sampled point clouds** rather than recomputed per drop. The
   prototype picks a fresh random point on the canopy arc for every splash; here 240 points are
   sampled from that same arc once and the emitter picks among them. At 140 drops a second the
   difference is not visible.
3. **Splash counts are steady-state, not per-event.** The prototype accumulates fractional
   spawns; GPUParticles3D works from `amount` over `lifetime`, which gives the same rate.
4. **The sampling uses its own random stream** (seed 8081) rather than the world one — drawing
   from the shared stream here would move every village, lantern and tree.

### What to look for when you press F5
There is a man in the boat now.

- **He poles.** Watch the cycle: the torso leans and twists, the head counter-rotates, the pole
  swings, and both hands stay planted on it because the arms are solved to reach rather than
  animated. Under way he works hard; coasting he barely moves.
- **His kit**: conical straw hat with a corded rim, three overlapping layers of straw cape,
  indigo kimono, sash, white gaiters and straw sandals.
- **Rain coming off him and the boat.** In Storm, drops kick up off the hat and the canopy and
  run off the brim and the gunwales.
- **The boat is textured.** Sawn planks with grain, knots and nail heads on hull and deck; woven
  matting on the canopy; bamboo poles; and the paper lantern with its red ends, ribs and two 川.
  Everything gets glossier as the rain comes on.
- **View: Boatman** puts you behind his eyes and hides him.
- **Frame time:** 2.74 ms (365 fps) at 1280×720.
