## Decides when samurai turn up, and of what sort.
##
## Nothing happens on the first stretch of the river: the ride is meant to be a ride before it
## is a fight. Past FIRST_ENCOUNTER_Z attackers start arriving, and both the size of a wave and
## the calibre of who is in it climb the further downstream you get - so the river reads as
## getting more dangerous rather than throwing everything at once.
class_name EncounterDirector
extends Node3D

## No enemies before here. The boat starts at z = -335, so this is a couple of minutes in.
const FIRST_ENCOUNTER_Z: float = -150.0
## Full danger by here.
const PEAK_Z: float = 360.0

## Seconds between waves, at the start of the river and at its most dangerous.
const CALM_GAP: float = 26.0
const BUSY_GAP: float = 11.0

## Never more than this many aboard at once.
const MAX_ACTIVE: int = 4

## Where on the deck attackers stand, in the boat's own space. Two abreast, fore and aft of
## the canopy, so they never stack up in one spot.
const DECK_SLOTS: Array[Vector3] = [
	Vector3(0.55, -0.05, -1.7), Vector3(-0.55, -0.05, -1.7),
	Vector3(0.55, -0.05, 1.9), Vector3(-0.55, -0.05, 1.9),
]

@export var boat: Boat
@export var player: PlayerCharacter
@export var environment_controller: EnvironmentController

## Every samurai alive right now, boarding or aboard.
var active: Array[Samurai] = []
var waves_sent: int = 0

var _next_wave: float = 6.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	if player != null:
		player.recovered.connect(_clear_attackers)


## Everyone aboard goes over the side, and the next wave is a while off.
func _clear_attackers() -> void:
	for enemy: Samurai in active:
		if is_instance_valid(enemy):
			enemy.queue_free()
	active.clear()
	_next_wave = CALM_GAP


func _process(delta: float) -> void:
	if boat == null or player == null:
		return
	if player.is_down():
		return
	active = active.filter(func(s: Samurai) -> bool: return is_instance_valid(s))
	player.enemies = active

	if boat.boat_z < FIRST_ENCOUNTER_Z:
		return

	_next_wave -= minf(delta, 0.05)
	if _next_wave <= 0.0:
		_send_wave()
		_next_wave = lerpf(CALM_GAP, BUSY_GAP, _danger())


## 0 where the first attackers appear, 1 at the far end of the river.
func _danger() -> float:
	return clampf(
		(boat.boat_z - FIRST_ENCOUNTER_Z) / (PEAK_Z - FIRST_ENCOUNTER_Z), 0.0, 1.0
	)


func _send_wave() -> void:
	var danger: float = _danger()
	var room: int = MAX_ACTIVE - active.size()
	if room <= 0:
		return
	# One attacker early, up to three once the river is dangerous.
	var count: int = mini(room, 1 + int(floor(danger * 2.0 + _rng.randf() * 0.7)))
	var taken: Array[Vector3] = []
	for s: Samurai in active:
		taken.append(s._deck_slot)

	for i: int in count:
		var slot: Vector3 = _free_slot(taken)
		taken.append(slot)
		var kind: SamuraiBuilder.Kind = _pick_kind(danger)
		var profile: Dictionary = Samurai.PROFILES[kind]
		var levels: Array = profile["level"]
		var level: int = _rng.randi_range(int(levels[0]), int(levels[1]))
		# Everyone gets a little tougher the further down the river you are.
		level += int(floor(danger * 2.0))

		var enemy: Samurai = Samurai.spawn(kind, level, boat, slot)
		enemy.defeated.connect(_on_defeated)
		enemy.skiff = _make_skiff()
		add_child(enemy.skiff)
		_place_skiff(enemy.skiff, slot)
		add_child(enemy)
		active.append(enemy)
	waves_sent += 1
	var roster: Array[String] = []
	for e: Samurai in active:
		roster.append("%s L%d hp%.0f chi%.0f %s" % [e.display_name(), e.stats.level, e.stats.max_health, e.stats.max_chi, e.stats.weapon().display_name])
	print("[wave %d] danger %.2f: %s" % [waves_sent, _danger(), ", ".join(roster)])


## Who turns up. Foot soldiers early, then ronin, then the real thing.
func _pick_kind(danger: float) -> SamuraiBuilder.Kind:
	var roll: float = _rng.randf()
	if danger < 0.25:
		return SamuraiBuilder.Kind.ASHIGARU if roll < 0.8 else SamuraiBuilder.Kind.RONIN
	if danger < 0.55:
		if roll < 0.4:
			return SamuraiBuilder.Kind.ASHIGARU
		return SamuraiBuilder.Kind.RONIN if roll < 0.85 else SamuraiBuilder.Kind.SAMURAI
	if roll < 0.2:
		return SamuraiBuilder.Kind.RONIN
	if roll < 0.65:
		return SamuraiBuilder.Kind.SAMURAI
	return SamuraiBuilder.Kind.SOHEI


func _free_slot(taken: Array[Vector3]) -> Vector3:
	for slot: Vector3 in DECK_SLOTS:
		if not taken.has(slot):
			return slot
	return DECK_SLOTS[_rng.randi() % DECK_SLOTS.size()]


## A bare hull, scaled down from the player's own - same lines, half the size.
func _make_skiff() -> Node3D:
	var skiff := Node3D.new()
	var meshes: Dictionary = BoatBuilder.build()
	var materials: Dictionary = BoatMaterials.build()
	for key: String in [BoatBuilder.MAT_HULL, BoatBuilder.MAT_DECK, BoatBuilder.MAT_DARK]:
		if not meshes.has(key):
			continue
		var instance := MeshInstance3D.new()
		instance.mesh = meshes[key]
		instance.material_override = materials[key]
		instance.scale = Vector3(0.5, 0.6, 0.42)
		skiff.add_child(instance)
	return skiff


## Comes up astern, off to the side the boarder will take. Separate from _make_skiff because
## global_position only means anything once the node is in the tree.
func _place_skiff(skiff: Node3D, slot: Vector3) -> void:
	skiff.global_position = boat.global_transform * Vector3(
		signf(slot.x) * 9.0, 0.0, -14.0 - _rng.randf() * 8.0
	)
	skiff.rotation.y = boat.heading


func _on_defeated(enemy: Samurai) -> void:
	player.gain(enemy.experience_value())
	player.notice.emit("%s defeated" % enemy.display_name())
	# His weapon is worth having.
	var dropped: Weapon = enemy.stats.weapon()
	if player.stats.pick_up(dropped):
		player.notice.emit("Took the %s %s" % [dropped.display_name, dropped.kanji])
	if enemy.skiff != null and is_instance_valid(enemy.skiff):
		enemy.skiff.queue_free()
