## The overlay: title card, the mark, the control hint, and the top-right button bar.
##
## Prototype: reference/ukiyo-river.html lines 10-98 for the styling and 1344-1353 for the
## handlers. The CSS becomes a Theme built here rather than a .tres, so the colours and sizes
## sit next to the prototype's values they came from.
extends CanvasLayer

## Prototype CSS custom properties, dark scheme - the one that matches the scene.
const INK: String = "#efe7d6"
const MUTED: String = "#b3a994"
const BODY: String = "#cfc5b1"
const SMALL: String = "#a79d88"
const PANEL: Color = Color(0.051, 0.067, 0.086, 0.5)
const LINE: Color = Color(0.937, 0.906, 0.839, 0.16)
const LACQUER: String = "#b8372b"
const LAMP: String = "#f0b05a"
const CAST_INK: String = "#fff6e6"

## Prototype: #intro transitions opacity over .9s.
const FADE_SECONDS: float = 0.9

const MINCHO_BOLD: String = "res://assets/fonts/ShipporiMincho-Bold.ttf"
const MINCHO_MEDIUM: String = "res://assets/fonts/ShipporiMincho-Medium.ttf"

@export var environment_controller: EnvironmentController
@export var camera: Camera3D
@export var boat: Boat
@export var lightning: Lightning
@export var audio_director: AudioDirector

@export var weather_button: Button
@export var time_button: Button
@export var view_button: Button
@export var drift_button: Button
@export var sound_button: Button

@export var bar: Control
@export var mark: Control
@export var hint: Control
@export var title: Control
@export var cast_button: Button


func _ready() -> void:
	_build_theme()

	weather_button.pressed.connect(_on_weather)
	time_button.pressed.connect(_on_time)
	view_button.pressed.connect(_on_view)
	drift_button.pressed.connect(_on_drift)
	sound_button.pressed.connect(_on_sound)
	cast_button.pressed.connect(_on_cast_off)

	_refresh()


## Prototype: the scene is already running behind the veil; Cast off only lifts it, and starts
## the sound, which a browser will not play before a gesture anyway.
func _on_cast_off() -> void:
	if audio_director != null:
		audio_director.started = true
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tween: Tween = create_tween()
	tween.tween_property(title, "modulate:a", 0.0, FADE_SECONDS).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(title.hide)


func _on_weather() -> void:
	environment_controller.cycle_weather()
	# Prototype: switching back to Storm pulls the next bolt in so it is not a long wait.
	if environment_controller.weather_key == "storm" and lightning != null:
		lightning.schedule_soon()
	_refresh()


func _on_time() -> void:
	environment_controller.cycle_time()
	_refresh()


func _on_view() -> void:
	camera.cycle_mode()
	_refresh()


func _on_drift() -> void:
	boat.drift = not boat.drift
	_refresh()


func _on_sound() -> void:
	audio_director.enabled = not audio_director.enabled
	_refresh()


func _process(_delta: float) -> void:
	# Drift switches itself off the moment the player steers, so the button has to follow it.
	if boat != null and drift_button.button_pressed != boat.drift:
		drift_button.button_pressed = boat.drift


func _refresh() -> void:
	var weather: Dictionary = EnvironmentController.WEATHERS[environment_controller.weather_key]
	weather_button.text = "Weather: %s" % weather["label"]
	time_button.text = "Time: %s" % environment_controller.time_key.capitalize()
	view_button.text = "View: %s" % camera.mode_name()
	drift_button.button_pressed = boat.drift
	sound_button.button_pressed = audio_director.enabled


## The prototype's panels: translucent sumi with a hairline border and a soft radius.
func _build_theme() -> void:
	var theme := Theme.new()
	var mincho_bold: FontFile = load(MINCHO_BOLD)
	var mincho_medium: FontFile = load(MINCHO_MEDIUM)

	var button_style := _panel_style(PANEL, 999)
	var button_hover := _panel_style(Color(PANEL.r, PANEL.g, PANEL.b, 0.72), 999)
	var button_pressed := _panel_style(Color(PANEL.r, PANEL.g, PANEL.b, 0.86), 999)
	# Prototype: an engaged toggle is outlined in lamp light.
	button_pressed.border_color = Color(LAMP)
	button_pressed.set_border_width_all(1)

	theme.set_stylebox("normal", "Button", button_style)
	theme.set_stylebox("hover", "Button", button_hover)
	theme.set_stylebox("pressed", "Button", button_pressed)
	theme.set_stylebox("focus", "Button", button_hover)
	theme.set_color("font_color", "Button", Color(INK))
	theme.set_color("font_hover_color", "Button", Color(INK))
	theme.set_color("font_pressed_color", "Button", Color(INK))
	theme.set_font_size("font_size", "Button", 13)

	theme.set_stylebox("panel", "PanelContainer", _panel_style(PANEL, 10))
	theme.set_color("font_color", "Label", Color(INK))
	theme.set_font_size("font_size", "Label", 13)
	# A CanvasLayer has no theme of its own, so it goes on each root Control under it.
	for root: Control in [bar, mark, hint, title]:
		root.theme = theme

	# Top left mark: the kanji in Mincho, the reading beside it in the muted ink.
	_style_label(mark.get_node("Box/Kanji"), mincho_bold, 15, Color(INK))
	_style_label(mark.get_node("Box/Reading"), null, 13, Color(MUTED))
	_style_label(hint.get_node("Text"), null, 12, Color(MUTED))

	# Title card.
	for i: int in 3:
		var glyph: Label = title.get_node("Card/Kanji/Char%d" % i)
		_style_label(glyph, mincho_bold, 84, Color(INK))
		# Prototype: text-shadow 0 0 40px rgba(240,176,90,.25) - lamplight behind the mark.
		glyph.add_theme_color_override("font_shadow_color", Color(Color(LAMP), 0.25))
		glyph.add_theme_constant_override("shadow_outline_size", 22)
		glyph.add_theme_constant_override("shadow_offset_x", 0)
		glyph.add_theme_constant_override("shadow_offset_y", 0)
	_style_label(title.get_node("Card/Heading"), mincho_medium, 22, Color(INK))
	_style_label(title.get_node("Card/Blurb"), null, 15, Color(BODY))
	_style_label(title.get_node("Card/Footnote"), null, 12, Color(SMALL))

	var cast_style := _panel_style(Color(LACQUER), 12)
	cast_style.content_margin_left = 28
	cast_style.content_margin_right = 28
	cast_style.content_margin_top = 15
	cast_style.content_margin_bottom = 15
	cast_style.border_width_bottom = 0
	cast_button.add_theme_stylebox_override("normal", cast_style)
	cast_button.add_theme_stylebox_override("hover", _panel_style(Color(LACQUER).lightened(0.12), 12))
	cast_button.add_theme_stylebox_override("pressed", _panel_style(Color(LACQUER).darkened(0.12), 12))
	cast_button.add_theme_color_override("font_color", Color(CAST_INK))
	cast_button.add_theme_color_override("font_hover_color", Color(CAST_INK))
	cast_button.add_theme_font_size_override("font_size", 16)


func _style_label(node: Node, font: FontFile, size: int, color: Color) -> void:
	var label := node as Label
	if label == null:
		return
	if font != null:
		label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)


func _panel_style(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.set_border_width_all(1)
	style.border_color = LINE
	style.content_margin_left = 13
	style.content_margin_right = 13
	style.content_margin_top = 9
	style.content_margin_bottom = 9
	return style
