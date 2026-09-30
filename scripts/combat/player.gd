## The player's own character: stats, swinging, and taking hits.
##
## The player is the boatman, so this node sits on him and its origin is where enemies measure
## distance to. Attacks are keyboard-driven: the boat is steered with the left hand on WASD and
## the mouse stays free for looking, so a swing is a key rather than a click.
class_name PlayerCharacter
extends Node3D

## Prototype boatman stands here; combat measures from his chest.
const CHEST: Vector3 = Vector3(0.0, 1.1, 0.0)

const START_HEALTH: float = 140.0
const START_CHI: float = 60.0

## Seconds of invulnerability after being struck, so a crowd cannot stunlock you.
const MERCY: float = 0.7

## Seconds spent down before the river carries you on.
const RECOVERY_SECONDS: float = 3.5

signal stats_changed
signal died
signal recovered
signal notice(text: String)

var stats: CharacterStats
@export var boat: Boat
@export var boatman: Boatman

var _swing_timer: float = 0.0
var _swing_heavy: bool = false
var _swing_landed: bool = false
var _mercy: float = 0.0
var _down_timer: float = 0.0
## Enemies currently aboard, kept by the encounter director.
var enemies: Array[Samurai] = []


func _ready() -> void:
	position = CHEST
	stats = CharacterStats.make(1, START_HEALTH, START_CHI, [Weapon.bo()])
	stats.chi_regen = 6.0
	stats.died.connect(_on_died)
	stats.levelled_up.connect(
		func(new_level: int) -> void: notice.emit("Level %d" % new_level)
	)


func is_down() -> bool:
	return _down_timer > 0.0


## Going down does not end the ride. You come round, the attackers have gone, and the river
## carries you on - so a bad fight costs progress and chi rather than the session.
func _on_died() -> void:
	_down_timer = RECOVERY_SECONDS
	_swing_timer = 0.0
	notice.emit("Struck down")
	died.emit()


func _process(delta: float) -> void:
	var dt: float = minf(delta, 0.05)

	if _down_timer > 0.0:
		_down_timer -= dt
		if _down_timer <= 0.0:
			stats.health = stats.max_health * 0.6
			stats.chi = stats.max_chi * 0.5
			notice.emit("The river carries you on")
			recovered.emit()
			stats_changed.emit()
		return

	stats.regenerate(dt)
	_mercy = maxf(0.0, _mercy - dt)

	if _swing_timer > 0.0:
		_advance_swing(dt)
	elif Input.is_action_just_pressed("ukiyo_attack"):
		_start_swing(false)
	elif Input.is_action_just_pressed("ukiyo_chi"):
		_start_swing(true)
	elif Input.is_action_just_pressed("ukiyo_swap"):
		var swapped: Weapon = stats.next_weapon()
		notice.emit("%s %s" % [swapped.display_name, swapped.kanji])
		stats_changed.emit()

	stats_changed.emit()


## A heavy strike costs chi and does over twice the damage; a light one is free.
func _start_swing(heavy: bool) -> void:
	if heavy and not stats.spend_chi(stats.weapon().chi_cost):
		notice.emit("Not enough 気")
		return
	_swing_timer = 0.0001
	_swing_heavy = heavy
	_swing_landed = false


func _advance_swing(dt: float) -> void:
	var weapon: Weapon = stats.weapon()
	_swing_timer += dt
	var t: float = clampf(_swing_timer / weapon.swing_time, 0.0, 1.0)
	# Drive the boatman's poling cycle hard through the swing so it reads as a strike.
	if boatman != null:
		boatman.animate(PI * 0.5 + t * PI, 1.0)

	if not _swing_landed and t >= weapon.contact_at:
		_swing_landed = true
		_strike(weapon)

	if t >= 1.0:
		_swing_timer = 0.0


## Everything aboard within reach and roughly in front takes the hit.
func _strike(weapon: Weapon) -> void:
	var damage: float = stats.attack_damage(_swing_heavy)
	var hits: int = 0
	for enemy: Samurai in enemies:
		if not is_instance_valid(enemy) or not enemy.stats.is_alive():
			continue
		if enemy.global_position.distance_to(global_position) <= weapon.reach:
			enemy.receive_hit(damage)
			hits += 1
	if hits == 0 and _swing_heavy:
		notice.emit("気 spent on air")


## True while a strike is playing, so the boat's poling animation stands aside for it.
func is_swinging() -> bool:
	return _swing_timer > 0.0


func receive_hit(amount: float, _from: Samurai) -> void:
	if _mercy > 0.0 or not stats.is_alive():
		return
	_mercy = MERCY
	stats.take_damage(amount)
	stats_changed.emit()


func gain(experience: int) -> void:
	stats.grant_experience(experience)
	stats_changed.emit()
