# Ukiyo River — three.js → Godot port plan

Source: `reference/ukiyo-river.html` (1563 lines, three.js r128, single IIFE).
Target: Godot 4.7.2, Forward+, GDScript only, static typing.

The prototype is the specification. Every constant, formula and placement list below is copied
across unchanged unless a line in "Deviation" says otherwise.

---

## 1. Conventions and global decisions

| Topic | Prototype | Godot |
| --- | --- | --- |
| Handedness / units | right-handed, Y-up, metres | same — coordinates carry over 1:1 |
| Boat forward | **+Z** (`x += sin(h)*v`, `z += cos(h)*v`) | keep **+Z** internally. Godot meshes/cameras look down −Z, so any node that must face the boat heading gets `rotation.y = h + PI`, and `look_at` is avoided in favour of explicit basis construction. |
| Colour pipeline | three r128 legacy: hex written straight to the framebuffer | Godot converts linear→sRGB on output, so hex constants are fed through `Color.srgb_to_linear()` (or a `source_color` uniform hint, which does the same) to land on the same pixel value |
| Tonemapping | none | `Environment.tonemap_mode = LINEAR`, white = 1.0 |
| Time | `THREE.Clock`, `T` accumulates with `dt` clamped to 0.05 | one `float` accumulator on the main controller, same 0.05 clamp; shaders read it from a uniform rather than `TIME` wherever the prototype passes `uTime`, so pause/scrub stays possible |

---

## 2. Systems

### 2.1 Random and noise — **Phase 1**
Prototype: `mulberry32`, `hash2`, `vnoise`, `fbm`, `clamp`, `lerp`, `smooth`, `angleLerp`
(lines 110–119); global `rng = mulberry32(20260923)`.

Godot: `scripts/ukiyo_math.gd` — `class_name UkiyoMath`, all `static func`.
JavaScript `Math.imul` and `>>>` are 32-bit; GDScript ints are 64-bit, so every hash value is held
as an unsigned 32-bit int and masked with `& 0xFFFFFFFF` after each multiply/add, with `>>>`
implemented as a plain right shift on that unsigned representation. `mulberry32` becomes a small
`RefCounted` (`UkiyoRng`) because it carries state.

Verification: `scripts/tools/noise_check.gd` prints `hash2`, `vnoise`, `fbm`, `mulberry32`,
`riverX`, `riverSlope` and `terrainH` at fixed sample points and diffs them against reference
values captured from the JavaScript (recorded in `docs/NOISE_CHECK.md`). Tolerance 1e-9.

### 2.2 World shape — **Phase 1**
Prototype: `RIVER_HALF = 17`, `riverX`, `riverSlope`, `terrainH`, `WAVES`, `waveH` (lines 122–134).
Godot: same file as 2.1 (`UkiyoMath.river_x` … `UkiyoMath.wave_h`). `WAVES` is a
`const Array[Vector4]`. These four functions are consumed by terrain, water, boat, floating
lanterns, tree placement, landmark placement and the camera ground-clamp, so they live in one
place and nothing else re-derives them.

### 2.3 Terrain — **Phase 1**
Prototype: `TS = 900`, `TSEG = 230`, `PlaneGeometry` displaced by `terrainH`, per-vertex colours
blended from `#223020`, `#34422a`, `#2c2821`, `#4a4944`, `#2b3530` using `vnoise`, height and
normal.y (lines 223–242); `MeshLambertMaterial({vertexColors:true})`.

Godot: `scenes/terrain.tscn` + `scripts/terrain.gd` on a `MeshInstance3D`. Grid built with
`SurfaceTool`/`ArrayMesh` in `_ready()` (231×231 verts, 105 800 tris), `generate_normals()`,
COLOR array filled with the same blend. Material: `StandardMaterial3D`,
`vertex_color_use_as_albedo = true`, `roughness = 1`, `specular = 0` (Lambert has no specular
term). Built once at load; cached to `.res` later if load time becomes annoying.

### 2.4 Water — **Phase 2**
Prototype: `waterMat` `ShaderMaterial` (lines 245–342) over a 900 m plane with 110×110 segments —
vertex wave displacement, plus a fragment shader doing: flow-noise gradient, rain ripple rings
(`ripples()`, two octaves), boat bow wave, Fresnel mix between `uDeep` and a planar-reflection
texture, lantern specular + falloff, sun specular, stern foam, lightning flash, manual exp² fog,
and a `discard` of every fragment inside the hull footprint.

Godot: `shaders/water.gdshader` (`shader_type spatial`) on `scenes/water.tscn`.
- Reflection: the manual mirror camera + render target is **dropped**. `Environment` SSR
  (`ssr_enabled`) plus a `ReflectionProbe` over the river supply reflections; the shader keeps its
  Fresnel term and feeds `ROUGHNESS`/`NORMAL` so the engine's reflection does the work.
- Everything else (waves, `noiseGrad`, `ripples`, wake, foam, lantern/sun speculars, hull
  `discard`) ports line-for-line, writing `ALBEDO`/`ROUGHNESS`/`EMISSION`/`NORMAL` instead of
  `gl_FragColor`, and letting `Environment` fog replace the hand-rolled `ff` term.
- `cameraPosition` → `CAMERA_POSITION_WORLD`; `modelMatrix` → `MODEL_MATRIX`.

### 2.5 Sky — **Phase 1**
Prototype: `skyMat` `ShaderMaterial` on a back-side 1500 m sphere pinned to the camera, with
`NOISE_GLSL` (`h21`, `vn`), a 5-octave `fbm`, gradient `uHor`→`uTop`, star field, sun/moon discs
(`pow(s,700)`, `pow(s,40)`, `pow(s,6)`), scrolling clouds, lightning flash and a fog blend
(lines 184–220).

Godot: `shaders/sky.gdshader`, `shader_type sky`, on a `Sky`/`ShaderMaterial` inside
`WorldEnvironment`. `vDir` → `EYEDIR`, `gl_FragColor` → `COLOR`. No sphere mesh, no
`renderOrder`, no camera pinning. Uniforms keep prototype names (`u_top`, `u_hor`, `u_fog`,
`u_sun_col`, `u_sun_dir`, `u_time`, `u_cloud`, `u_flash`, `u_stars`, `u_haze`), colours tagged
`source_color`.

### 2.6 Fog and lighting — **Phase 1** (values re-driven in Phase 4)
Prototype: `FogExp2(0x121822, 0.01)` with colour/density animated from the preset;
`HemisphereLight(0x5d6f93, 0x08090b, 0.4)`; `DirectionalLight(0x9fb4d8, 0.4)` repositioned each
frame 100 m along `env.sunDir` from the boat, 2048² PCF soft shadows with a tight ortho box
(±7, near 60, far 150), `shadowMap.autoUpdate = false`.

Godot: `WorldEnvironment` in `main.tscn` driven by `scripts/environment_controller.gd`.
- Fog: `Environment.fog_enabled`, `fog_light_color`, `fog_density`. **Deviation:** three's
  `FogExp2` is `exp(−(d·density)²)`; Godot's exponential fog is `exp(−d·density)`. The density is
  re-fitted so the two agree at mid range, and volumetric fog is switched on during storms as the
  handoff asks. Recorded in PORT_LOG.
- Hemisphere light: no such node in Godot 4 → `Environment.ambient_light_source = COLOR` with the
  sky colour, plus `Environment.ambient_light_energy`; the ground term folds into the sky
  contribution. Recorded in PORT_LOG.
- Sun: `DirectionalLight3D`, `shadow_enabled`, `directional_shadow_mode = ORTHOGONAL`,
  matching ortho extents. Godot has no `autoUpdate=false` equivalent; shadows update every frame.

### 2.7 Camera and controls — **Phase 1** (orbit) / **Phase 3** (full)
Prototype: `cam = {yawOff, pitch 0.24, dist 12, mode, orbit, head, fpPitch −0.05}`;
modes `Follow / Boatman / Orbit`; drag → yaw/pitch (0.006, 0.004 rad/px; pitch clamps
0.04–1.25, first-person pitch −0.7–0.6); wheel → `dist *= exp(deltaY*0.001)` clamped 4.5–40;
follow position lerped at `1−exp(−dt*6)` and lifted above `terrainH + 1.4` and 0.7;
heading smoothed with `angleLerp` at `1−exp(−dt*2.2)`; orbit mode advances `0.1 rad/s`.

Godot: `scripts/camera_rig.gd` on a `Camera3D` (fov 60, near 0.1, far 2200).
Phase 1 ships orbit-around-origin-ish drag/zoom only, so the valley can be inspected before the
boat exists; Phase 3 replaces the target with the boat and adds the three modes. Mouse handled in
`_unhandled_input`; W/S/A/D and arrows go through the InputMap in Phase 3
(`ukiyo_forward`, `ukiyo_back`, `ukiyo_left`, `ukiyo_right`). Touch joystick is **dropped** —
this is a desktop build.

### 2.8 Boat — **Phase 3**
Prototype: `HL = 8.2`, `sec(t)`, `profilePt()`, `buildHull()` (64×20 lofted surface with an inner
shell and two end caps), rail tubes via `CatmullRomCurve3` + `TubeGeometry`, deck `ShapeGeometry`,
thwarts, canopy (half cylinder with a sag term, four bamboo hoops, ridge), bow lantern
(`LatheGeometry` + painted `T_LANTERN` + additive sprite glow + `PointLight(0xffb45a, 2, 26, 2)`
at `LANTERN_POS = (0, 2.32, 3.55)`).
Physics (lines 1361–1399): `FLOW = 0.45`, `speed += (thrust*3.2 − speed*0.45)*dt`,
`turnRate = steer*(0.35 + min(|speed|,5)*0.1)`, `turn` smoothed at `1−exp(−dt*3)`,
`h −= turn*dt`, bank clamp at `RIVER_HALF − 1.8` with `speed *= 0.96`, `|z|` clamp at 390 with
`speed *= 0.9`, pitch/roll sampled from `waveH` three metres ahead and one metre abeam.
Autopilot ("Drift") on by default, looks 28 m downstream, `steer = clamp(−d*2.2, −1, 1)`,
turns itself off on any player input.

Godot: `scenes/boat.tscn` + `scripts/boat.gd` on a `Node3D` (kinematic — the prototype has no
rigid body and Jolt would change the feel). Hull/rails/deck/canopy built in
`scripts/boat_builder.gd` with `SurfaceTool`. Rails: `CatmullRomCurve3`+`TubeGeometry` →
`Curve3D` sampled + swept ring. Sprite glow → `Sprite3D` with additive billboard material.
`PointLight` → `OmniLight3D` (`omni_range = 26`, distance falloff exponent 2 → `attenuation = 2`).

### 2.9 Boatman — **Phase 7**
Prototype: jointed figure built from lathes/cylinders/spheres (lines 743–846), two-bone IK
(`solveArm`, `ARM_A = 0.29`, `ARM_B = 0.27`), poling cycle `animateBoatman(ph, act)` around
`POLE_PIVOT = (0.2, 1.12, 0.36)`, straw `mino` cape in three lathe layers with alpha-tested
strand texture, conical hat, hidden in Boatman camera mode.

Godot: `scenes/boatman.tscn` + `scripts/boatman.gd`. Same hand-built hierarchy of
`MeshInstance3D`s (no skeleton — the prototype has none); IK ported verbatim; alpha-test
materials via `ALPHA_SCISSOR_THRESHOLD = 0.45` (mino) / `0.42` (foliage).

### 2.10 Rain splashes and drips — **Phase 7**
Prototype: 220-point CPU pool (`emit`, `updateParticles`), 140 splashes/s and 30 drips/s scaled by
`env.rain`, spawned on the canopy arc and the hat rim, gravity −9.8, life 0.16 s / 0.8 s.
Godot: two `GPUParticles3D` (splash burst + drip) parented to the boat with matching emission
shapes, rates, lifetimes and gravity.

### 2.11 Rain and petals — **Phase 4**
Prototype: `RAIN_MAX = 8000` line segments recycled in a 70×70×35 box around the camera, wind
drift `cos/sin(0.6)*wind*5`, streak length `0.035 s` of travel; 220 petal points, fall 0.5–1.0 m/s
with sine sway, recycled in a 50 m box.
Godot: `scenes/weather.tscn` — two `GPUParticles3D` following the camera
(`transform_align = Z_BILLBOARD_Y_TO_VELOCITY` for the streaks, `ParticleProcessMaterial` with
gravity + turbulence for petals). Emission amount scales with `env.rain`.

### 2.12 Lightning and thunder — **Phase 4**
Prototype: `strike()` picks a bearing and a distance (22 % chance of a "close" 60–110 m strike,
otherwise 130–330 m), builds a jagged polyline (`jag`, depth 7, displacement 45) from y=190 down
to `terrainH`, expands it into a camera-facing ribbon (`ribbon`) plus three forks, and plays a
5-pulse flash envelope (`flashAt`, `exp(−t*18)`); thunder fires after `dist/140` seconds;
`bolt.next = 4 + rand*9` between strikes while `env.storm > 0.6`.
Godot: `scripts/lightning.gd` rebuilding the ribbon into an `ImmediateMesh` each strike with an
unshaded additive material; the flash value drives the sky uniform, the sun light energy/colour,
ambient energy, the water shader and the rain colour, exactly as in the frame loop.
`setTimeout` → `SceneTreeTimer`.

### 2.13 Audio — **Phase 4**
Prototype: Web Audio. Three looping beds — white noise → highpass 900 → lowpass 6500 (rain),
brown noise → lowpass 380 (wind), brown noise at rate 1.3 → bandpass 520 Q 0.8 (lapping) — with
gains `0.3*rain`, `0.18*wind`, `0.06 + 0.3*speedN`. Thunder: brown noise through a lowpass swept
`1200−900n` → 90 Hz over 5 s with a multi-stage gain envelope, plus a highpassed white-noise crack for near
strikes.
Godot: `scripts/audio_director.gd` with four `AudioStreamPlayer`s fed by `AudioStreamGenerator`;
white/brown noise generated in GDScript, biquad coefficients hand-written (Godot's
`AudioEffectFilter` lives on buses, so each bed gets its own bus with the matching filter effect —
whichever proves cleaner is recorded in PORT_LOG). No audio files ship.

### 2.14 Weather and time presets — **Phase 4**
Prototype: `TIMES` (night/dusk/day) and `WEATHERS` (clear/rain/storm) tables verbatim at lines
1190–1199; `targetEnv()` desaturates top/hor/fog toward luminance by `cloud*0.6`, scales
`hemi`, `sun` and `stars` by cloud, and `stepEnv(dt)` lerps every colour and number at
`1−exp(−dt*1.1)`.
Godot: `scripts/environment_controller.gd` holds the same two dictionaries as typed
`Dictionary[String, Dictionary]` constants and the same interpolation, then pushes values into
`Environment`, `DirectionalLight3D`, the sky shader, the water shader, the emissive materials and
the audio director each frame.

### 2.15 Architecture and landmarks — **Phase 5**
Prototype builders: `torii(s)`, `house(opts)`, `pagoda()`, `toro()`, `bridge(z0)`, `stilt(z0,side)`,
`placeOnBank()`, the 14-entry `LANDMARKS` table, the `exclusions` list, the 30 m-spaced roadside
`toro` loop from z −410→410, and `bakeStatic()` which merges everything by material.
Godot: `scripts/architecture.gd` + `scripts/builders/*.gd`. `bakeStatic` → `SurfaceTool` merge per
material, one `MeshInstance3D` per material. `roofGeo` (a 4-sided cone rotated 45°) → a hand-built
pyramid mesh. Window/lamp `MeshBasicMaterial` → unshaded `StandardMaterial3D`
(`shading_mode = UNSHADED`) whose colour is scaled by `env.night` each frame.
Two shore `PointLight`s reassigned every 0.5 s to the nearest two `toroSpots` →
two `OmniLight3D`s with the same nearest-two sort.

### 2.16 Floating lanterns — **Phase 5**
Prototype: 40 instanced paper boxes + bases drifting at `FLOW*1.3`, wrapped ±160 m around the
boat, pushed aside within 2.6 m, riding `waveH`.
Godot: two `MultiMeshInstance3D`s (paper, base), same update loop writing `set_instance_transform`.

### 2.17 Trees — **Phase 6**
Prototype: `GB` geometry builder (`tube`, `card`), `buildSugi/buildMatsu/buildSakura` with seeds
101/202/303, 404/505, 11/22/33, 7/8/9; up to 2300 placements sampled with `rng`, rejected by
`terrainH < 0.6` or `blocked()`, split by distance into sakura (<48 m), pine (<42 m), near cedar
(<70 m) and far cedar; `InstancedMesh` per variant; wind sway injected into the vertex shader
(`uH`, `uFl`, phase from the instance position); far cedars hidden in the reflection pass.
Godot: `scripts/trees.gd` + `scripts/builders/tree_builder.gd`, one `MultiMeshInstance3D` per
(species, variant, trunk/foliage). Sway moves into `shaders/foliage.gdshader` and
`shaders/trunk.gdshader` using `MODEL_MATRIX[3].xz` for the per-instance phase. Per-instance tint
via `MultiMesh.use_colors`.

### 2.18 Canvas textures — **Phase 3 onwards, generated once**
Prototype: 20-odd procedural canvas textures (`planksDraw`, `weaveDraw`, `fiberDraw`,
`strandsDraw`, `fabricDraw`, `bambooDraw`, `lanternDraw`, `barkDraw`, `sugiSprayDraw`, `pineDraw`,
`blossomDraw`, radial `glowTex`) redrawn at every page load.
Godot: `scripts/tools/generate_textures.gd`, an `EditorScript` run once from the editor. Each
draw function is reimplemented against an `Image` (with small line/ellipse/gradient helpers in
`scripts/tools/canvas2d.gd`, seeded by the same `mulberry32` seeds) and saved as PNG to
`assets/generated/`. Runtime only loads the PNGs. The bump-map variants (`*_B`) become normal maps
generated from the same greyscale source.

### 2.19 UI — **Phase 4** (buttons) / **Phase 8** (title screen)
Prototype: fixed top bar with `Weather / Time / View / Drift / Sound`, a hint line, and the
`#intro` overlay with 浮世川, a blurb and a "Cast off" button.
Godot: `scenes/ui.tscn` + `scripts/ui.gd` — `CanvasLayer` with a `HBoxContainer` of `Button`s
(same cycle order and labels) and a full-screen title `Control` that fades out over 0.9 s.
Fonts: the prototype loads Shippori Mincho and Zen Kaku Gothic New from Google Fonts. Nothing is
downloaded at runtime in a shipped game, so Phase 8 either vendors the fonts into `assets/fonts/`
(SIL OFL, redistributable) or falls back to the default theme — decision recorded in PORT_LOG.

### 2.20 Environment cube map for wet surfaces — **Phase 2**
Prototype: a 128² `CubeCamera` over a duplicate sky sphere, refreshed every 2 s, assigned as
`envMap` to every boat material.
Godot: dropped — the `WorldEnvironment` sky is the ambient/reflection source automatically.
Recorded in PORT_LOG.

---

## 3. Phase checklist

| Phase | Contents | Gate |
| --- | --- | --- |
| 1 | 2.1 2.2 2.3 2.5 2.6, placeholder water, orbit camera | **stop and ask for editor review** |
| 2 | 2.4, 2.20 | headless + commit + log |
| 3 | 2.8, camera modes, InputMap, Drift | headless + commit + log |
| 4 | 2.14 2.11 2.12 2.13 2.19a | headless + commit + log |
| 5 | 2.15 2.16 | headless + commit + log |
| 6 | 2.17 | headless + commit + log |
| 7 | 2.9 2.10, falling petals on the boat | headless + commit + log |
| 8 | 2.19b, performance pass, final difference list | headless + commit + log |

After every phase: run the headless check from `CLAUDE.md`, fix every error and warning, commit as
`Phase N: <name>`, append to `docs/PORT_LOG.md` (what was built, what differs and why, what to
look for on F5).

## 4. Files

```
assets/generated/         PNGs from the EditorScript
docs/PORT_PLAN.md         this file
docs/PORT_LOG.md          per-phase log
docs/NOISE_CHECK.md       JavaScript reference values for the maths port
reference/ukiyo-river.html the prototype
scenes/    main.tscn terrain.tscn water.tscn boat.tscn boatman.tscn
           weather.tscn architecture.tscn trees.tscn ui.tscn
scripts/   ukiyo_math.gd terrain.gd water.gd environment_controller.gd camera_rig.gd
           boat.gd boat_builder.gd boatman.gd weather.gd lightning.gd audio_director.gd
           architecture.gd trees.gd ui.gd
scripts/builders/  torii.gd house.gd pagoda.gd toro.gd bridge.gd stilt.gd tree_builder.gd
scripts/tools/     noise_check.gd generate_textures.gd canvas2d.gd
shaders/   sky.gdshader water.gdshader foliage.gdshader trunk.gdshader lightning.gdshader
```

---

## 5. As built

Audited against the tree after Phase 8. The plan held, with three departures, all deliberate:

- **The six structure builders are one file.** `scripts/architecture_builder.gd` rather than
  `scripts/builders/torii.gd`, `house.gd`, `pagoda.gd`, `toro.gd`, `bridge.gd`, `stilt.gd`. Each
  is fifteen to thirty lines and they read better together, matching the
  `boat.gd` / `boat_builder.gd` split already in use.
- **No `lightning.gdshader`.** The bolt is an unshaded additive `StandardMaterial3D` over an
  `ImmediateMesh`; it needs no shader code.
- **Extra files the plan did not anticipate:** `scripts/boat_materials.gd` (the shared `BM`
  table), `scripts/world_rng.gd` (the one random stream the world is laid out from),
  `shaders/tree_sway.gdshaderinc`, `scripts/rain_splashes.gd`, and four verification tools -
  `noise_check`, `boat_check`, `audio_check`, `world_check` - plus `screenshot.gd`, which is
  how every phase was actually checked.

Three functions in the prototype are dead code and were correctly not ported: `cylBetween`,
and the `iron` and `indigo` materials, each defined once and never used.
