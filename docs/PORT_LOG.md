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
