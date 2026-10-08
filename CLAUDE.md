# Ukiyo River

A role-playing game that starts with a night boat ride down a river in old Japan. The world and
the boat are a faithful port of a three.js prototype (reference/ukiyo-river.html); the combat on
top of it is new work. The long-term direction is to bring the player ashore to fight.

What exists today: the river, terrain, weather and time-of-day system, procedural audio, the boat
and its boatman, and samurai who row out, board the boat and attack. See docs/ below.

## Engine
- Godot 4.7.2, GDScript only, Forward+ renderer
- Use Godot 4 syntax and APIs only. Never Godot 3 syntax (no `yield`, no bare `export` or `onready`, no `KinematicBody`)
- Static typing everywhere: typed variables and typed function signatures

## Environment
- The project lives on Windows at C:\Dev\ukiyo-river. Claude Code runs in WSL at /mnt/c/Dev/ukiyo-river
- Godot console binary: /mnt/c/Users/eagle/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe
  (nothing is installed at C:\Tools\Godot yet — if you move Godot there, update this path)
- After every change, run the main scene headless briefly and fix any errors it prints before reporting done:
  "/mnt/c/Users/eagle/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe" --headless --path 'C:\Dev\ukiyo-river' --script res://scripts/tools/run_check.gd
  This runs the main scene for 120 frames and then closes it the way a window close does, so the
  game's own shutdown is exercised. It replaces `--quit-after 120`, which force-quits between
  frames, skips shutdown entirely, and reported a leak warning nothing in the project could fix.
- Headless has no rendering device, so it cannot catch a broken shader or a black screen. For
  anything visual, render a frame offscreen as well:
  "/mnt/c/Users/eagle/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe" --path 'C:\Dev\ukiyo-river' --resolution 1280x720 res://scenes/screenshot.tscn
  It writes shot.png and prints the average frame time.
- After adding, renaming or moving a script with a `class_name`, rebuild the class cache or the
  name will not resolve: add `--headless --import` before anything else runs.
- Build a standalone Windows .exe with:
  "/mnt/c/Users/eagle/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe" --headless --path 'C:\Dev\ukiyo-river' --export-release "Windows Desktop" 'C:\Dev\ukiyo-river\build\UkiyoRiver.exe'
  The preset is in export_presets.cfg; build/ is gitignored because the binary is ~120 MB.
  Export templates live in %APPDATA%/Godot/export_templates/4.7.2.stable and are already installed.
- Run git from WSL only

## Layout
- scenes/, scripts/, shaders/, assets/, docs/
- scripts/combat/ is the combat system. scripts/tools/ is development-only (checks, texture
  generation, screenshots) and ships nothing to the player. The *_builder.gd scripts at the top of
  scripts/ build geometry and hold no state
- Scripts are named after their scene (boat.tscn uses boat.gd). snake_case file names, PascalCase class_name
- Textures in assets/generated/ are produced by scripts/tools/generate_textures.gd, not painted by
  hand. Regenerate rather than edit. There are no audio files at all — every sound is synthesised
  at runtime by audio_director.gd

## Docs
- docs/PORT_PLAN.md — the 20 systems mapped prototype → Godot, and the deviations taken
- docs/PORT_LOG.md — per-phase log, plus every known difference from the prototype and why
- docs/COMBAT.md — actions, characters, weapons, the player/enemy asymmetry, guarding
- docs/TESTING.md — how to run it, controls, debug keys, what to look for
- docs/NOISE_CHECK.md — the noise values the port is held against

## Verification
Five checks run at startup and print to the console: noise, boat trajectory, audio, world layout,
and tree counts. They compare against values taken from the JavaScript prototype and are the
regression net for the port — if a change makes one of them disagree, that is a real bug, not a
stale expectation to update. Keep them passing.

Verify against the prototype rather than assuming. Measure rather than guess: several things that
looked like obvious causes turned out not to be (see PORT_LOG.md).

## Things that will bite you
- Godot front faces wind clockwise; three.js winds counter-clockwise. Geometry ported straight
  from the prototype comes out inside-out. MeshUtil takes corners in three.js order and reverses
  them for you — use it
- The prototype is three.js r128, which writes hex colours straight to the framebuffer. Godot
  converts linear → sRGB on output, so every hex from the prototype needs `Color.srgb_to_linear()`.
  Do not also tag such a uniform `source_color` — that converts it twice
- The world is laid out by replaying the prototype's random sequence in order. Adding or removing
  a draw from that sequence moves every tree and building after it. world_check.gd catches this
- NodePath exports in a .tscn need `node_paths=PackedStringArray("prop")` on the node line, or
  they silently resolve to null
- PackedArrays are returned by reference. Do not reuse a member array as a return buffer

## Working rules
- Keep .tscn edits minimal and structural. I do visual layout, camera framing, and tuning in the editor
- Prefer building geometry and effects in scripts and shaders over large hand-edited scene files
- Never edit anything in .godot/ (editor cache)
- After each change, tell me exactly what I should see when I press F5
