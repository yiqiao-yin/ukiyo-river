# Ukiyo River

A rainy night boat ride through old Japan, built in Godot. This is a port of an existing three.js prototype.

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
- Run git from WSL only

## Layout
- scenes/, scripts/, shaders/, assets/ (models, textures, audio)
- Scripts are named after their scene (boat.tscn uses boat.gd). snake_case file names, PascalCase class_name

## Working rules
- Keep .tscn edits minimal and structural. I do visual layout, camera framing, and tuning in the editor
- Prefer building geometry and effects in scripts and shaders over large hand-edited scene files
- Never edit anything in .godot/ (editor cache)
- After each change, tell me exactly what I should see when I press F5
