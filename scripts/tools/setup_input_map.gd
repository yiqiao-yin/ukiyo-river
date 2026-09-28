## One-off: writes the boat's input actions into project.godot.
##
## Run from WSL with
##   godot --headless --path 'C:\Dev\ukiyo-river' --script res://scripts/tools/setup_input_map.gd
## Committed so the mapping is reproducible rather than a hand-edited block in project.godot.
## After running, the actions show up under Project Settings > Input Map and can be remapped
## there without touching this file.
extends SceneTree

const ACTIONS: Dictionary = {
	"ukiyo_forward": [KEY_W, KEY_UP],
	"ukiyo_back": [KEY_S, KEY_DOWN],
	"ukiyo_left": [KEY_A, KEY_LEFT],
	"ukiyo_right": [KEY_D, KEY_RIGHT],
}


func _init() -> void:
	for action: String in ACTIONS:
		var events: Array[InputEventKey] = []
		for keycode: int in ACTIONS[action]:
			var event := InputEventKey.new()
			# -1 is what the editor writes: match the key on any device.
			event.device = -1
			event.physical_keycode = keycode
			events.push_back(event)
		ProjectSettings.set_setting("input/" + action, {
			"deadzone": 0.2,
			"events": events,
		})
		print("[input] %s -> %s" % [action, ACTIONS[action]])

	var error: Error = ProjectSettings.save()
	if error != OK:
		push_error("[input] could not save project.godot (error %d)" % error)
	else:
		print("[input] project.godot updated")
	quit()
