## One enemy, from the moment his skiff appears to the moment he goes over the side.
##
## He runs through four states: ROWING while his skiff closes on the player's boat, BOARDING
## while he steps across, FIGHTING once he is on deck, and DEFEATED on the way down. The skiff
## is his until he boards, then it is left behind to drift.
class_name Samurai
extends Node3D

enum State { ROWING, BOARDING, FIGHTING, DEFEATED }

## How close the skiff gets before he steps across.
const BOARD_RANGE: float = 3.2
## How long the step across takes.
const BOARD_SECONDS: float = 0.9
## He backs off to here between swings rather than standing inside the player.
const PREFERRED_GAP: float = 0.75
const MOVE_SPEED: float = 1.4
## Seconds between the end of one swing and the start of the next.
const RECOVERY: float = 1.1
## Each attacker waits a little before his first swing, and they are staggered, so a boarding
## party does not land three blows on the same frame.
const FIRST_SWING_DELAY: float = 1.3

## Per kind: level range, base health, base chi, weapon, and the experience he is worth.
const PROFILES: Dictionary = {
	SamuraiBuilder.Kind.ASHIGARU: {"level": [1, 2], "health": 42.0, "chi": 12.0, "xp": 30},
	SamuraiBuilder.Kind.RONIN: {"level": [2, 4], "health": 64.0, "chi": 22.0, "xp": 55},
	SamuraiBuilder.Kind.SAMURAI: {"level": [4, 6], "health": 96.0, "chi": 38.0, "xp": 95},
	SamuraiBuilder.Kind.SOHEI: {"level": [5, 7], "health": 84.0, "chi": 64.0, "xp": 120},
}

signal defeated(samurai: Samurai)

var kind: SamuraiBuilder.Kind = SamuraiBuilder.Kind.ASHIGARU
var stats: CharacterStats
var state: State = State.ROWING

## Set by the encounter director before the node enters the tree.
var boat: Boat
var skiff: Node3D

## The technique he is in the middle of. Picked fresh each time, so he does not repeat himself.
var _move: CombatMove
var _moves: Array[CombatMove] = []
var _last_move: int = -1

var _swing_timer: float = 0.0
var _recovery_timer: float = 0.0
var _board_timer: float = 0.0
var _board_from: Vector3 = Vector3.ZERO
var _death_timer: float = 0.0
var _arm: Node3D
var _weapon_pivot: Node3D
## Where on the player's deck he stands, in the boat's own space.
var _deck_slot: Vector3 = Vector3.ZERO
var _hit_flash: float = 0.0
var _materials: Dictionary = {}


static func spawn(
	enemy_kind: SamuraiBuilder.Kind, level: int, target: Boat, deck_slot: Vector3
) -> Samurai:
	var s := Samurai.new()
	s.kind = enemy_kind
	s.boat = target
	s._deck_slot = deck_slot
	var profile: Dictionary = PROFILES[enemy_kind]
	s.stats = CharacterStats.make(
		level, float(profile["health"]), float(profile["chi"]), [_weapon_for(enemy_kind)]
	)
	return s


static func _weapon_for(enemy_kind: SamuraiBuilder.Kind) -> Weapon:
	match enemy_kind:
		SamuraiBuilder.Kind.ASHIGARU:
			return Weapon.yari()
		SamuraiBuilder.Kind.SOHEI:
			return Weapon.naginata()
		SamuraiBuilder.Kind.SAMURAI:
			return Weapon.katana()
		_:
			return Weapon.katana()


func display_name() -> String:
	return SamuraiBuilder.KIND_NAMES[kind]


func experience_value() -> int:
	return int(PROFILES[kind]["xp"]) * stats.level


func _ready() -> void:
	_materials = SamuraiBuilder.materials(kind)
	var body: Dictionary = SamuraiBuilder.build(kind)
	for key: String in body:
		var instance := MeshInstance3D.new()
		instance.mesh = body[key]
		instance.material_override = _materials[key]
		add_child(instance)

	# The weapon arm is one piece that swings from the shoulder, with the weapon on the end.
	_arm = Node3D.new()
	_arm.position = Vector3(0.22, 1.33, 0.0)
	add_child(_arm)
	var upper := MeshInstance3D.new()
	var upper_buffer := MeshUtil.Buffer.new()
	MeshUtil.add_cone(upper_buffer, Vector3.ZERO, Vector3(0.0, -0.52, 0.0), 0.075, 0.05, 10)
	var upper_mesh := ArrayMesh.new()
	upper_buffer.commit(upper_mesh)
	upper.mesh = upper_mesh
	upper.material_override = _materials[SamuraiBuilder.CLOTH]
	_arm.add_child(upper)

	_weapon_pivot = Node3D.new()
	_weapon_pivot.position = Vector3(0.0, -0.54, 0.05)
	_arm.add_child(_weapon_pivot)
	var weapon_meshes: Dictionary = SamuraiBuilder.build_weapon(stats.weapon())
	for key: String in weapon_meshes:
		var instance := MeshInstance3D.new()
		instance.mesh = weapon_meshes[key]
		instance.material_override = _materials[key]
		_weapon_pivot.add_child(instance)

	# Off hand, fixed. Without it the figure reads as missing an arm.
	var off := MeshInstance3D.new()
	var off_buffer := MeshUtil.Buffer.new()
	MeshUtil.add_cone(
		off_buffer, Vector3(-0.22, 1.33, 0.0), Vector3(-0.30, 0.86, 0.12), 0.075, 0.05, 10
	)
	MeshUtil.add_sphere(off_buffer, Vector3(-0.30, 0.84, 0.13), 0.05, 10, 8)
	var off_mesh := ArrayMesh.new()
	off_buffer.commit(off_mesh)
	off.mesh = off_mesh
	off.material_override = _materials[SamuraiBuilder.CLOTH]
	add_child(off)

	_moves = CombatMove.for_weapon(stats.weapon().display_name)
	_move = _moves[0]

	stats.died.connect(_on_died)
	_rest_pose()


func _process(delta: float) -> void:
	if boat == null:
		return
	var dt: float = minf(delta, 0.05)
	stats.regenerate(dt)
	_update_hit_flash(dt)

	match state:
		State.ROWING:
			_row(dt)
		State.BOARDING:
			_board(dt)
		State.FIGHTING:
			_fight(dt)
		State.DEFEATED:
			_sink(dt)


## The skiff closes on the player's boat from behind and to one side.
func _row(dt: float) -> void:
	if skiff == null:
		_begin_boarding()
		return
	var target: Vector3 = boat.global_transform * Vector3(
		signf(_deck_slot.x) * 2.6, 0.0, _deck_slot.z - 0.5
	)
	var to_target: Vector3 = target - skiff.global_position
	to_target.y = 0.0
	var distance: float = to_target.length()
	# Chase a little faster than the player can run, or he could never be caught.
	var speed: float = 8.6
	if distance > 0.05:
		skiff.global_position += to_target / distance * minf(speed * dt, distance)
	skiff.rotation.y = lerp_angle(skiff.rotation.y, boat.heading, 1.0 - exp(-dt * 2.0))
	skiff.position.y = UkiyoMath.wave_h(
		skiff.position.x, skiff.position.z, _now(), _wind()
	)
	global_position = skiff.global_position + Vector3(0.0, 0.12, 0.0)
	rotation.y = skiff.rotation.y

	if distance < BOARD_RANGE:
		_begin_boarding()


func _begin_boarding() -> void:
	state = State.BOARDING
	_board_timer = 0.0
	_board_from = global_position


## A short arc from the skiff onto the deck, after which he belongs to the boat.
func _board(dt: float) -> void:
	_board_timer += dt
	var t: float = clampf(_board_timer / BOARD_SECONDS, 0.0, 1.0)
	var landing: Vector3 = boat.global_transform * _deck_slot
	var position_now: Vector3 = _board_from.lerp(landing, t)
	# Lift through the middle of the step so he clears the gunwale.
	position_now.y += sin(t * PI) * 0.55
	global_position = position_now
	rotation.y = boat.heading + PI
	if t >= 1.0:
		state = State.FIGHTING
		# Reparent onto the boat so he rides with it from here on.
		var keep: Transform3D = global_transform
		get_parent().remove_child(self)
		boat.add_child(self)
		global_transform = keep
		if skiff != null:
			skiff.set_meta("abandoned", true)


## On deck: close to striking distance, then swing on a cycle.
func _fight(dt: float) -> void:
	var to_player: Vector3 = _player_position() - global_position
	to_player.y = 0.0
	var distance: float = to_player.length()
	var reach: float = stats.weapon().reach

	# Face the player.
	if distance > 0.01:
		var wanted: float = atan2(to_player.x, to_player.z)
		rotation.y = lerp_angle(rotation.y, wanted, 1.0 - exp(-dt * 6.0))

	if _swing_timer > 0.0:
		_advance_swing(dt)
		return

	if _recovery_timer > 0.0:
		_recovery_timer -= dt
		_rest_pose()
		return

	if distance > reach - PREFERRED_GAP:
		# Step in, staying on the deck.
		var step: Vector3 = to_player / maxf(distance, 0.001) * MOVE_SPEED * dt
		position += boat.global_transform.basis.inverse() * step
		_rest_pose()
	else:
		_start_swing()


## Picks a technique, avoiding the one he just used so the pattern stays unreadable.
func _start_swing() -> void:
	var choice: int = randi() % _moves.size()
	if _moves.size() > 1 and choice == _last_move:
		choice = (choice + 1 + randi() % (_moves.size() - 1)) % _moves.size()
	_last_move = choice
	_move = _moves[choice]

	_swing_timer = 0.0001
	# He spends chi when he has plenty, which is what makes the monk dangerous.
	var heavy: bool = stats.chi > stats.max_chi * 0.6 and stats.spend_chi(stats.weapon().chi_cost)
	set_meta("heavy", heavy)
	set_meta("landed", false)


func _advance_swing(dt: float) -> void:
	var weapon: Weapon = stats.weapon()
	_swing_timer += dt
	var t: float = clampf(_swing_timer / _move.duration, 0.0, 1.0)
	_pose(t)

	if not bool(get_meta("landed", false)) and t >= _move.contact:
		set_meta("landed", true)
		var distance: float = _player_position().distance_to(global_position)
		if distance <= weapon.reach * _move.reach_scale and boat != null and boat.player != null:
			var damage: float = (
				stats.attack_damage(bool(get_meta("heavy", false))) * _move.damage_scale
			)
			boat.player.receive_hit(damage, self)

	if t >= 1.0:
		_swing_timer = 0.0
		_recovery_timer = RECOVERY
		_rest_pose()


## The arm and weapon curves for each technique. The first part of every one is the telegraph:
## the blade goes somewhere visible before it comes back, which is what makes them readable and
## therefore fair.
func _pose(t: float) -> void:
	# Windup runs to contact, follow-through after it.
	var wind: float = clampf(t / maxf(_move.contact, 0.01), 0.0, 1.0)
	var follow: float = clampf((t - _move.contact) / maxf(1.0 - _move.contact, 0.01), 0.0, 1.0)

	match _move.shape:
		CombatMove.Shape.KESA:
			# Up over the shoulder, then down across the body.
			_arm.rotation = Vector3(0.35 - wind * 2.5 + follow * 3.1, -wind * 0.5, -0.25 + follow * 0.9)
			_weapon_pivot.rotation = Vector3(-0.5 - wind * 0.9 + follow * 2.6, 0.0, 0.0)
		CombatMove.Shape.DO:
			# Drawn back to the side, then swung flat through the waist.
			_arm.rotation = Vector3(-0.5, -wind * 1.5 + follow * 2.8, -0.9)
			_weapon_pivot.rotation = Vector3(-1.2, 0.0, -wind * 0.6 + follow * 1.1)
		CombatMove.Shape.KIRIAGE:
			# Dropped low, then whipped up from the opposite hip.
			_arm.rotation = Vector3(0.35 + wind * 1.0 - follow * 2.6, wind * 0.4, -0.25 - follow * 0.5)
			_weapon_pivot.rotation = Vector3(0.9 - follow * 2.4, 0.0, 0.0)
		CombatMove.Shape.TSUKI:
			# Cocked back beside the hip, then driven straight out.
			var reach_out: float = -wind * 0.35 + follow * 1.0
			_arm.rotation = Vector3(-1.1 - wind * 0.3 + follow * 0.5, 0.0, -0.2)
			_arm.position = Vector3(0.22, 1.33, 0.0) + Vector3(0.0, 0.0, reach_out * 0.35)
			_weapon_pivot.rotation = Vector3(-1.45, 0.0, 0.0)
		_:
			_arm.rotation = Vector3(0.35, -wind * 1.2 + follow * 2.2, -0.25)
			_weapon_pivot.rotation = Vector3(-0.9, 0.0, 0.0)


## Guard: weapon up and across, not hanging at his side.
func _rest_pose() -> void:
	if _arm == null:
		return
	_arm.rotation = Vector3(-0.35, -0.25, -0.5)
	_arm.position = Vector3(0.22, 1.33, 0.0)
	_weapon_pivot.rotation = Vector3(-0.9, 0.0, 0.0)


## Called by the player's swing.
func receive_hit(amount: float) -> void:
	if state == State.DEFEATED:
		return
	stats.take_damage(amount)
	_hit_flash = 1.0


func _on_died() -> void:
	state = State.DEFEATED
	_death_timer = 0.0
	defeated.emit(self)


## Over the side and under.
func _sink(dt: float) -> void:
	_death_timer += dt
	rotation.x = -minf(_death_timer * 2.4, PI * 0.5)
	position.y -= dt * 0.9
	if _death_timer > 3.0:
		queue_free()


## A short red flash on every plate when he is struck, so hits register.
func _update_hit_flash(dt: float) -> void:
	if _hit_flash <= 0.0:
		return
	_hit_flash = maxf(0.0, _hit_flash - dt * 6.0)
	var tint: Color = Color(1.0, 0.25, 0.2).srgb_to_linear() * _hit_flash * 0.45
	for key: String in [SamuraiBuilder.LACQUER, SamuraiBuilder.CLOTH, SamuraiBuilder.STEEL]:
		(_materials[key] as StandardMaterial3D).emission_enabled = _hit_flash > 0.0
		(_materials[key] as StandardMaterial3D).emission = tint


func _player_position() -> Vector3:
	if boat == null or boat.player == null:
		return global_position
	return boat.player.global_position


func _now() -> float:
	return boat.environment_controller.elapsed if boat.environment_controller != null else 0.0


func _wind() -> float:
	return boat.environment_controller.num("wind") if boat.environment_controller != null else 1.0
