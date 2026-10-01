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

## What a raised guard leaves you taking.
const BLOCK_SOAK: float = 0.25
## Chi burned per point of damage stopped. Hold against enough and the guard breaks.
const BLOCK_CHI_PER_DAMAGE: float = 0.55
## Raise the guard within this long before a blow lands and it is turned aside completely.
const PARRY_WINDOW: float = 0.28
## How long a broken guard leaves you open.
const GUARD_BREAK: float = 1.1

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
## The boatman knows one thing and does it alternately: sweep left, sweep right, left again.
## Which is why two attackers on opposite sides is genuinely awkward for him.
var _move: CombatAction = CombatAction.sweep_right()
var _next_side: float = 1.0
var _mercy: float = 0.0
var _down_timer: float = 0.0
## Guard state. `guarding` is the held input; the timer is how long it has been up, which is
## what makes a late raise a parry rather than a block.
var guarding: bool = false
var _guard_held: float = 0.0
var _guard_break: float = 0.0
## Enemies currently aboard, kept by the encounter director.
var enemies: Array[Samurai] = []


func _ready() -> void:
	position = CHEST
	stats = CharacterStats.make(1, START_HEALTH, START_CHI, [Weapon.bo()])
	stats.chi_regen = 6.0
	# He starts knowing two sweeps and how to get the pole in the way. That is all.
	stats.actions = [CombatAction.sweep_left(), CombatAction.sweep_right(), CombatAction.block()]
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
	_guard_break = maxf(0.0, _guard_break - dt)
	_update_guard(dt)

	if _swing_timer > 0.0:
		_advance_swing(dt)
	elif guarding:
		# Guarding and striking are separate decisions; you cannot do both.
		if boatman != null:
			boatman.guard(_guard_held)
	elif Input.is_action_just_pressed("ukiyo_attack"):
		_start_swing(false)
	elif Input.is_action_just_pressed("ukiyo_chi"):
		_start_swing(true)
	elif Input.is_action_just_pressed("ukiyo_swap"):
		var swapped: Weapon = stats.next_weapon()
		notice.emit("%s %s" % [swapped.display_name, swapped.kanji])
		stats_changed.emit()

	stats_changed.emit()


## A heavy strike costs chi and does over twice the damage. It is not a better technique - it
## is the same sweep with his weight behind it, which is all he has.
func _start_swing(heavy: bool) -> void:
	if heavy and not stats.spend_chi(stats.weapon().chi_cost):
		notice.emit("Not enough 気")
		return
	_move = CombatAction.sweep_right() if _next_side > 0.0 else CombatAction.sweep_left()
	_next_side = -_next_side
	_swing_timer = 0.0001
	_swing_heavy = heavy
	_swing_landed = false


func _advance_swing(dt: float) -> void:
	_swing_timer += dt
	var t: float = clampf(_swing_timer / _move.duration, 0.0, 1.0)
	if boatman != null:
		boatman.strike(t, _move.side)

	if not _swing_landed and t >= _move.contact:
		_swing_landed = true
		_strike(stats.weapon())

	if t >= 1.0:
		_swing_timer = 0.0


## A sweep only catches what is on the side it is travelling toward, plus whatever is straight
## ahead. Two boarders on opposite sides therefore have to be dealt with in turn, which is the
## whole tactical content of fighting with a punt pole.
func _strike(weapon: Weapon) -> void:
	var damage: float = stats.attack_damage(_swing_heavy) * _move.damage_scale
	var reach: float = weapon.reach * _move.reach_scale
	var hits: int = 0
	for enemy: Samurai in enemies:
		if not is_instance_valid(enemy) or not enemy.stats.is_alive():
			continue
		var to_enemy: Vector3 = enemy.global_position - global_position
		if to_enemy.length() > reach:
			continue
		# Which side of him the target is on, in his own frame.
		var lateral: float = global_transform.basis.x.dot(to_enemy.normalized())
		if _move.side != 0.0 and lateral * _move.side < -0.3:
			continue
		enemy.receive_hit(damage)
		hits += 1
	if hits == 0 and _swing_heavy:
		notice.emit("気 spent on air")


## True while a strike or a guard is playing, so the boat's poling animation stands aside.
func is_swinging() -> bool:
	return _swing_timer > 0.0 or guarding


## Guard is held, not triggered. A broken one cannot be raised again until it recovers.
func _update_guard(delta: float) -> void:
	var wanted: bool = (
		Input.is_action_pressed("ukiyo_block")
		and _guard_break <= 0.0
		and stats.can(CombatAction.Kind.GUARD)
		and _swing_timer <= 0.0
	)
	if wanted and not guarding:
		_guard_held = 0.0
	guarding = wanted
	if guarding:
		_guard_held += delta


## What a raised guard does to an incoming blow.
##
## Raising it late - inside PARRY_WINDOW of the blow landing - turns the strike aside for
## nothing, which is the reward for reading the telegraph. Holding it up from well before costs
## chi proportional to what it stopped, and runs out.
func _resolve_guard(amount: float) -> float:
	if not guarding:
		return amount
	if _guard_held <= PARRY_WINDOW:
		stats.chi = minf(stats.max_chi, stats.chi + amount * 0.25)
		notice.emit("Turned aside")
		return 0.0
	if not stats.spend_chi(amount * BLOCK_CHI_PER_DAMAGE):
		stats.chi = 0.0
		guarding = false
		_guard_break = GUARD_BREAK
		notice.emit("Guard broken")
		return amount
	return amount * BLOCK_SOAK


func receive_hit(amount: float, _from: Samurai, _action: CombatAction = null) -> void:
	if _mercy > 0.0 or not stats.is_alive():
		return
	var taken: float = _resolve_guard(amount)
	# A blow turned aside completely does not start the mercy window, so a good guard can be
	# held through a flurry rather than buying a free second.
	if taken <= 0.0:
		stats_changed.emit()
		return
	_mercy = MERCY
	stats.take_damage(taken)
	stats_changed.emit()


func gain(experience: int) -> void:
	stats.grant_experience(experience)
	stats_changed.emit()
