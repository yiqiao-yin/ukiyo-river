## Health and chi, for the player and for whoever is currently trying to kill him.
##
## Drawn rather than built out of Control nodes: the enemy bars have to follow heads that move
## every frame, so they are projected from world space with unproject_position, and the player's
## own panel is drawn in the same pass to keep one look.
class_name CombatHUD
extends Control

const HEALTH_COLOUR: Color = Color("#c2453a")
const HEALTH_BACK: Color = Color(0.08, 0.06, 0.06, 0.66)
const CHI_COLOUR: Color = Color("#5fc7c0")
const PANEL_BACK: Color = Color(0.051, 0.067, 0.086, 0.62)
const LINE: Color = Color(0.937, 0.906, 0.839, 0.18)
const INK: Color = Color("#efe7d6")
const MUTED: Color = Color("#b3a994")
## Enemy bars fade out past this far away.
const BAR_MAX_DISTANCE: float = 42.0

## Handed over by ui.gd. These live outside this scene, so a NodePath export in ui.tscn cannot
## reach them - it would resolve against the UI scene's own root and come back null.
var player: PlayerCharacter
var director: EncounterDirector
var camera: Camera3D

var _notice: String = ""
var _notice_time: float = 0.0
var _font: Font
var _kanji_font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_font = ThemeDB.fallback_font
	_kanji_font = load("res://assets/fonts/ShipporiMincho-Bold.ttf")


func setup(
	player_character: PlayerCharacter, encounters: EncounterDirector, view: Camera3D
) -> void:
	player = player_character
	director = encounters
	camera = view
	if player != null and not player.notice.is_connected(_on_notice):
		player.notice.connect(_on_notice)


func _on_notice(text: String) -> void:
	_notice = text
	_notice_time = 2.6


func _process(delta: float) -> void:
	_notice_time = maxf(0.0, _notice_time - delta)
	queue_redraw()


func _draw() -> void:
	if player == null or player.stats == null:
		return
	_draw_player_panel()
	_draw_enemy_bars()
	_draw_notice()


## Bottom left: level, the weapon in hand, and the two pools.
func _draw_player_panel() -> void:
	var stats: CharacterStats = player.stats
	var panel := Rect2(18.0, size.y - 126.0, 288.0, 108.0)
	draw_rect(panel, PANEL_BACK, true)
	draw_rect(panel, LINE, false, 1.0)

	var x: float = panel.position.x + 14.0
	var y: float = panel.position.y + 26.0
	draw_string(_font, Vector2(x, y), "Lv %d" % stats.level,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 17, INK)
	var weapon: Weapon = stats.weapon()
	draw_string(_font, Vector2(x + 58.0, y), weapon.display_name,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, MUTED)
	if _kanji_font != null:
		draw_string(_kanji_font, Vector2(panel.end.x - 46.0, y + 2.0), weapon.kanji,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 19, MUTED)

	_bar(Rect2(x, panel.position.y + 42.0, 260.0, 14.0),
		stats.health / maxf(stats.max_health, 1.0), HEALTH_COLOUR)
	draw_string(_font, Vector2(x + 4.0, panel.position.y + 53.0),
		"%d / %d" % [roundi(stats.health), roundi(stats.max_health)],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, INK)

	_bar(Rect2(x, panel.position.y + 64.0, 260.0, 12.0),
		stats.chi / maxf(stats.max_chi, 1.0), CHI_COLOUR)
	if _kanji_font != null:
		draw_string(_kanji_font, Vector2(x + 4.0, panel.position.y + 74.0), "気",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.05, 0.1, 0.1))
	draw_string(_font, Vector2(x + 22.0, panel.position.y + 74.0),
		"%d" % roundi(stats.chi), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.05, 0.1, 0.1))

	# Guard. The chi bar is the thing under pressure while it is up, so the tell sits on it.
	if player.guarding:
		draw_rect(Rect2(x - 2.0, panel.position.y + 62.0, 264.0, 16.0), Color("#c8a33c"), false, 2.0)
		if _kanji_font != null:
			draw_string(_kanji_font, Vector2(panel.end.x - 46.0, panel.position.y + 76.0),
				"受け", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#c8a33c"))

	# Experience toward the next level.
	var progress: float = float(stats.experience) / float(maxi(stats.next_level_at(), 1))
	_bar(Rect2(x, panel.position.y + 84.0, 260.0, 5.0), progress, Color("#c8a33c"))


## A small bar over every enemy still standing.
func _draw_enemy_bars() -> void:
	if director == null or camera == null:
		return
	for enemy: Samurai in director.active:
		if not is_instance_valid(enemy) or not enemy.stats.is_alive():
			continue
		var head: Vector3 = enemy.global_position + Vector3(0.0, 2.05, 0.0)
		if camera.is_position_behind(head):
			continue
		var distance: float = camera.global_position.distance_to(head)
		if distance > BAR_MAX_DISTANCE:
			continue
		var fade: float = clampf(1.0 - distance / BAR_MAX_DISTANCE, 0.15, 1.0)
		var at: Vector2 = camera.unproject_position(head)
		var width: float = clampf(96.0 * (12.0 / maxf(distance, 4.0)), 44.0, 110.0)
		var bar := Rect2(at.x - width * 0.5, at.y, width, 7.0)
		_bar(bar, enemy.stats.health / maxf(enemy.stats.max_health, 1.0),
			Color(HEALTH_COLOUR, fade))
		var label: String = "%s  Lv %d" % [enemy.display_name(), enemy.stats.level]
		draw_string(_font, Vector2(bar.position.x, bar.position.y - 5.0), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(INK, fade))


## Level ups, weapon pickups and kills, briefly, above the panel.
func _draw_notice() -> void:
	if _notice_time <= 0.0:
		return
	var alpha: float = clampf(_notice_time / 0.8, 0.0, 1.0)
	draw_string(_font, Vector2(20.0, size.y - 138.0), _notice,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(Color("#f0b05a"), alpha))


func _bar(rect: Rect2, fraction: float, colour: Color) -> void:
	draw_rect(rect, HEALTH_BACK, true)
	var filled := Rect2(rect.position, Vector2(rect.size.x * clampf(fraction, 0.0, 1.0), rect.size.y))
	if filled.size.x > 0.0:
		draw_rect(filled, colour, true)
	draw_rect(rect, LINE, false, 1.0)
