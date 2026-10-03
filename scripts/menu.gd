## The front screen, and the pause screen - they are the same thing.
##
## Three panels behind one title card: Home, Profile and Settings. Escape brings it back during
## play and pauses the game while it is up.
##
## Nothing here is saved. There is no database yet, so a profile is whatever you set this run
## and settings apply live and reset when the exe is closed. That is deliberate for now, and
## the one place to change when persistence arrives is _collect()/_apply() below.
class_name Menu
extends ColorRect

enum Screen { HOME, PROFILE, SETTINGS }

const FADE_SECONDS: float = 0.5

signal begin_pressed

@export var environment_controller: EnvironmentController
@export var audio_director: AudioDirector
@export var camera: Camera3D
@export var boat: Boat

@export var home_panel: Control
@export var profile_panel: Control
@export var settings_panel: Control
@export var begin_button: Button
@export var profile_button: Button
@export var settings_button: Button
@export var quit_button: Button

## Set on the fly, lost on exit.
var player_name: String = "Boatman"

var _panel: Menu.Screen = Menu.Screen.HOME
var _started: bool = false
var _profile_lines: Label
var _name_field: LineEdit


func _ready() -> void:
	# The menu has to keep running while it has the game paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	begin_button.pressed.connect(_on_begin)
	profile_button.pressed.connect(func() -> void: _show(Menu.Screen.PROFILE))
	settings_button.pressed.connect(func() -> void: _show(Menu.Screen.SETTINGS))
	quit_button.pressed.connect(_on_quit)
	_build_profile()
	_build_settings()
	_show(Menu.Screen.HOME)
	get_tree().paused = true


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.is_pressed() or event.is_echo():
		return
	if (event as InputEventKey).keycode != KEY_ESCAPE:
		return
	get_viewport().set_input_as_handled()
	if visible:
		# Escape backs out of a sub-panel first, then closes the menu.
		if _panel != Menu.Screen.HOME:
			_show(Menu.Screen.HOME)
		elif _started:
			_close()
	else:
		_open()


func _process(_delta: float) -> void:
	if visible and _panel == Menu.Screen.PROFILE:
		_refresh_profile()


func _on_begin() -> void:
	_started = true
	begin_pressed.emit()
	_close()


func _on_quit() -> void:
	var main: Node = get_tree().current_scene
	if main != null and main.has_method("shutdown_and_quit"):
		main.shutdown_and_quit()
	else:
		get_tree().quit()


func _open() -> void:
	get_tree().paused = true
	modulate.a = 1.0
	show()
	_show(Menu.Screen.HOME)


func _close() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tween: Tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(self, "modulate:a", 0.0, FADE_SECONDS).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func() -> void:
		hide()
		get_tree().paused = false
	)


func _show(screen: Menu.Screen) -> void:
	_panel = screen
	mouse_filter = Control.MOUSE_FILTER_STOP
	home_panel.visible = screen == Menu.Screen.HOME
	profile_panel.visible = screen == Menu.Screen.PROFILE
	settings_panel.visible = screen == Menu.Screen.SETTINGS
	begin_button.text = "Resume" if _started else "Cast off"
	if screen == Menu.Screen.PROFILE:
		_refresh_profile()


# ------------------------------------------------------------------ profile

func _build_profile() -> void:
	_name_field = LineEdit.new()
	_name_field.text = player_name
	_name_field.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_field.custom_minimum_size = Vector2(260, 0)
	_name_field.text_changed.connect(func(text: String) -> void: player_name = text)
	profile_panel.add_child(_name_field)

	_profile_lines = Label.new()
	_profile_lines.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	profile_panel.add_child(_profile_lines)

	profile_panel.add_child(_back_button())


## Read live off the character, so the profile is the truth rather than a copy of it.
func _refresh_profile() -> void:
	var player: PlayerCharacter = boat.player if boat != null else null
	if player == null or player.stats == null:
		_profile_lines.text = "no character yet"
		return
	var stats: CharacterStats = player.stats
	var weapons: PackedStringArray = []
	for weapon: Weapon in stats.inventory:
		weapons.append("%s %s" % [weapon.display_name, weapon.kanji])
	var known: PackedStringArray = []
	for action: CombatAction in stats.actions:
		known.append(action.display_name)
	_profile_lines.text = "\n".join([
		"Level %d      %d / %d experience" % [stats.level, stats.experience, stats.next_level_at()],
		"Health %d / %d" % [roundi(stats.health), roundi(stats.max_health)],
		"気 %d / %d" % [roundi(stats.chi), roundi(stats.max_chi)],
		"",
		"Carrying: %s" % (", ".join(weapons) if weapons.size() > 0 else "nothing"),
		"Knows: %s" % ", ".join(known),
		"",
		"Nothing here is saved. Closing the game starts you fresh.",
	])


# ----------------------------------------------------------------- settings

func _build_settings() -> void:
	settings_panel.add_child(_slider_row("Volume", 0.0, 1.0, 0.9, func(v: float) -> void:
		if audio_director != null:
			audio_director.master_volume = v
	))
	settings_panel.add_child(_slider_row("Look sensitivity", 0.3, 2.5, 1.0, func(v: float) -> void:
		if camera != null:
			camera.look_sensitivity = v
	))
	settings_panel.add_child(_check_row("Sound", true, func(on: bool) -> void:
		if audio_director != null:
			audio_director.enabled = on
	))
	settings_panel.add_child(_check_row("Fullscreen", false, func(on: bool) -> void:
		DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED
		)
	))
	settings_panel.add_child(_options_row(
		"Weather", EnvironmentController.WEATHER_ORDER, 0, func(index: int) -> void:
			if environment_controller != null:
				environment_controller.weather_key = EnvironmentController.WEATHER_ORDER[index]
	))
	settings_panel.add_child(_options_row(
		"Time", EnvironmentController.TIME_ORDER, 0, func(index: int) -> void:
			if environment_controller != null:
				environment_controller.time_key = EnvironmentController.TIME_ORDER[index]
	))
	settings_panel.add_child(_back_button())


func _slider_row(label: String, low: float, high: float, value: float, on_change: Callable) -> Control:
	var row := HBoxContainer.new()
	row.add_child(_row_label(label))
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = 0.05
	slider.value = value
	slider.custom_minimum_size = Vector2(180, 0)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.value_changed.connect(on_change)
	row.add_child(slider)
	return row


func _check_row(label: String, value: bool, on_change: Callable) -> Control:
	var row := HBoxContainer.new()
	row.add_child(_row_label(label))
	var check := CheckButton.new()
	check.button_pressed = value
	check.toggled.connect(on_change)
	row.add_child(check)
	return row


func _options_row(
	label: String, choices: PackedStringArray, selected: int, on_change: Callable
) -> Control:
	var row := HBoxContainer.new()
	row.add_child(_row_label(label))
	var options := OptionButton.new()
	for choice: String in choices:
		options.add_item(choice.capitalize())
	options.selected = selected
	options.custom_minimum_size = Vector2(180, 0)
	options.item_selected.connect(on_change)
	row.add_child(options)
	return row


func _row_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(190, 0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _back_button() -> Button:
	var back := Button.new()
	back.text = "Back"
	back.pressed.connect(func() -> void: _show(Menu.Screen.HOME))
	return back
