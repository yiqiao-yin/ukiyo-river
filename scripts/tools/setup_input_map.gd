## One-off: writes the boat's input actions into project.godot.
##
## Run from WSL with
##   godot --headless --path 'C:\Dev\ukiyo-river' --script res://scripts/tools/setup_input_map.gd
## Committed so the mapping is reproducible rather than a hand-edited block in project.godot.
## After running, the actions show up under Project Settings > Input Map and can be remapped
## there without touching this file.
extends SceneTree

## Mouse buttons are listed separately from keys.
const MOUSE_ACTIONS: Dictionary = {
	"ukiyo_attack": [MOUSE_BUTTON_LEFT],
	"ukiyo_block": [MOUSE_BUTTON_RIGHT],
}

const ACTIONS: Dictionary = {
	"ukiyo_forward": [KEY_W, KEY_UP],
	"ukiyo_back": [KEY_S, KEY_DOWN],
	"ukiyo_left": [KEY_A, KEY_LEFT],
	"ukiyo_right": [KEY_D, KEY_RIGHT],
	# Combat. The mouse stays on the camera, so swinging is a key.
	# Left click is the strike; space is kept as a keyboard alternative.
	"ukiyo_attack": [KEY_SPACE],
	"ukiyo_chi": [KEY_SHIFT],
	"ukiyo_swap": [KEY_Q],
	# Guard is held. Right click is the natural pair to a left-click strike, so looking around
	# moved to a middle-mouse drag.
	"ukiyo_block": [KEY_F],
	# Reserved. Nobody knows the weave yet - it is the action the player picks up ashore.
	"ukiyo_evade_left": [KEY_Z],
	"ukiyo_evade_right": [KEY_C],
}


func _init() -> void:
	for action: String in ACTIONS:
		var events: Array[InputEvent] = []
		for keycode: int in ACTIONS[action]:
			var event := InputEventKey.new()
			# -1 is what the editor writes: match the key on any device.
			event.device = -1
			event.physical_keycode = keycode
			events.push_back(event)
		for button: int in MOUSE_ACTIONS.get(action, []):
			var click := InputEventMouseButton.new()
			click.device = -1
			click.button_index = button
			events.push_back(click)
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
