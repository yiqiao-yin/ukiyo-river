## Places the landmarks along the river and merges them into one mesh per material.
##
## Prototype: reference/ukiyo-river.html lines 455-511, plus the shore-lantern lights at 1171
## and 1519-1525.
##
## The world RNG order matters. The prototype draws from one mulberry32 stream seeded 20260923,
## and the village houses consume it before the floating lanterns, which consume it before the
## trees. Anything that changes that order moves every village, lantern and tree in the world,
## so the draws happen here in the prototype's sequence and the shared stream is handed on.
class_name Architecture
extends Node3D

## Prototype LANDMARKS: [kind, z, side]. Bridges have no side.
const LANDMARKS: Array = [
	["torii", -262.0, 1.0], ["shrine", -262.0, 1.0], ["village", -200.0, -1.0],
	["stilt", -172.0, -1.0], ["bridge", -125.0, 0.0],
	["pagoda", -52.0, 1.0], ["village", 12.0, 1.0], ["torii", 92.0, -1.0],
	["shrine", 92.0, -1.0], ["bridge", 175.0, 0.0],
	["village", 232.0, -1.0], ["stilt", 262.0, 1.0], ["pagoda", 322.0, -1.0],
	["village", -320.0, 1.0],
]

## Prototype: roadside lanterns every 30 m, alternating banks, skipped where the ground is
## wrong or a landmark is in the way.
const TORO_SPACING: float = 30.0
const TORO_START: float = -410.0
const TORO_END: float = 410.0
const TORO_OFFSET: float = UkiyoMath.RIVER_HALF + 5.5

## Prototype: the two shore lights are reassigned to the nearest lanterns twice a second.
const LIGHT_REFRESH: float = 0.5

@export var environment_controller: EnvironmentController
@export var boat: Boat
@export var world_rng: WorldRng
@export var shore_light_a: OmniLight3D
@export var shore_light_b: OmniLight3D

## Circles the trees must avoid, as (x, z, radius). Read by trees.gd in Phase 6.
var exclusions: Array[Vector3] = []

## Where a shore light can sit, at the flame height of each stone lantern.
var toro_spots: PackedVector3Array = PackedVector3Array()

var _lamp_material: StandardMaterial3D
var _window_material: StandardMaterial3D
var _light_timer: float = 0.0


func _ready() -> void:
	var buffers: Dictionary = ArchitectureBuilder.new_buffers()
	_place_landmarks(buffers)
	_place_roadside_lanterns(buffers)

	var materials: Dictionary = ArchitectureBuilder.materials()
	_lamp_material = materials[ArchitectureBuilder.MAT_LAMP]
	_window_material = materials[ArchitectureBuilder.MAT_WINDOW]

	for key: String in buffers:
		var buffer: MeshUtil.Buffer = buffers[key]
		if buffer.is_empty():
			continue
		var mesh := ArrayMesh.new()
		buffer.commit(mesh)
		var instance := MeshInstance3D.new()
		instance.name = key.capitalize()
		instance.mesh = mesh
		instance.material_override = materials[key]
		add_child(instance)


func _process(delta: float) -> void:
	if environment_controller == null:
		return
	var night: float = environment_controller.num("night")
	var t: float = environment_controller.elapsed
	var flicker: float = 1.0 + 0.05 * sin(t * 13.0) + 0.04 * sin(t * 23.7)

	# Prototype: the lantern paper brightens with the dark, the windows almost go out by day.
	if _lamp_material != null:
		var glow: float = 0.4 + 0.8 * night
		_lamp_material.albedo_color = (
			Color(ArchitectureBuilder.LAMP_BASE).srgb_to_linear() * (glow * flicker * 1.1)
		)
	if _window_material != null:
		_window_material.albedo_color = (
			Color(ArchitectureBuilder.WINDOW_BASE).srgb_to_linear() * (0.25 + 0.95 * night)
		)

	_update_shore_lights(delta, night, flicker)


## Prototype: rather than light every stone lantern, two point lights chase the nearest two.
func _update_shore_lights(delta: float, night: float, flicker: float) -> void:
	if shore_light_a == null or shore_light_b == null or toro_spots.is_empty():
		return
	_light_timer -= delta
	if _light_timer <= 0.0 and boat != null:
		_light_timer = LIGHT_REFRESH
		var best: Vector3 = toro_spots[0]
		var second: Vector3 = toro_spots[0]
		var best_d: float = INF
		var second_d: float = INF
		for spot: Vector3 in toro_spots:
			var d: float = spot.distance_squared_to(boat.global_position)
			if d < best_d:
				second = best
				second_d = best_d
				best = spot
				best_d = d
			elif d < second_d:
				second = spot
				second_d = d
		shore_light_a.global_position = best
		shore_light_b.global_position = second
	var energy: float = 1.3 * night * flicker
	shore_light_a.light_energy = energy
	shore_light_b.light_energy = energy


func blocked(x: float, z: float) -> bool:
	for e: Vector3 in exclusions:
		var dx: float = x - e.x
		var dz: float = z - e.y
		if dx * dx + dz * dz < e.z * e.z:
			return true
	return false


func _place_landmarks(buffers: Dictionary) -> void:
	var rng: UkiyoRng = world_rng.rng
	for entry: Array in LANDMARKS:
		var kind: String = entry[0]
		var z: float = entry[1]
		var side: float = entry[2]
		match kind:
			"torii":
				# Prototype places this one at a fixed height on the bank edge, not on the ground.
				var x: float = UkiyoMath.river_x(z) + side * (UkiyoMath.RIVER_HALF + 2.5)
				ArchitectureBuilder.merge(
					buffers, ArchitectureBuilder.torii(1.25),
					_placed(Vector3(x, -1.5, z), atan(UkiyoMath.river_slope(z)))
				)
			"shrine":
				_place_shrine(buffers, z, side)
			"village":
				_place_village(buffers, rng, z, side)
			"stilt":
				_place_stilt(buffers, z, side)
			"bridge":
				ArchitectureBuilder.merge(
					buffers, ArchitectureBuilder.bridge(),
					_placed(
						Vector3(UkiyoMath.river_x(z), 0.0, z), atan(UkiyoMath.river_slope(z))
					)
				)
				exclusions.push_back(Vector3(UkiyoMath.river_x(z), z, 30.0))
			"pagoda":
				var d: float = UkiyoMath.RIVER_HALF + 30.0
				ArchitectureBuilder.merge(
					buffers, ArchitectureBuilder.pagoda(), _on_bank(z, side, d, true)
				)
				exclusions.push_back(
					Vector3(UkiyoMath.river_x(z) + side * d, z, 10.0)
				)


func _place_shrine(buffers: Dictionary, z: float, side: float) -> void:
	ArchitectureBuilder.merge(
		buffers,
		ArchitectureBuilder.house(
			8.0, 6.0, 3.0, 2.8, ArchitectureBuilder.MAT_ROOF,
			ArchitectureBuilder.MAT_WOOD, ArchitectureBuilder.MAT_VERM, true
		),
		_on_bank(z, side, UkiyoMath.RIVER_HALF + 16.0, true)
	)
	# Prototype turns the approach gate a further quarter turn so it faces the shrine.
	var gate: Transform3D = _on_bank(z, side, UkiyoMath.RIVER_HALF + 9.5, true)
	gate.basis = gate.basis.rotated(Vector3.UP, PI * 0.5)
	ArchitectureBuilder.merge(buffers, ArchitectureBuilder.torii(0.8), gate)

	for dz: float in [-3.5, 3.5]:
		var spot: Transform3D = _on_bank(z + dz, side, UkiyoMath.RIVER_HALF + 12.0, false)
		ArchitectureBuilder.merge(buffers, ArchitectureBuilder.toro(), spot)
		toro_spots.push_back(spot.origin + Vector3(0.0, 1.7, 0.0))

	exclusions.push_back(
		Vector3(UkiyoMath.river_x(z) + side * (UkiyoMath.RIVER_HALF + 13.0), z, 12.0)
	)


## Five houses scattered along the bank. The five RNG draws per house, in this order, are what
## keep the village laid out the way the prototype lays it out.
func _place_village(buffers: Dictionary, rng: UkiyoRng, z: float, side: float) -> void:
	for i: int in 5:
		var zz: float = z + float(i - 2) * 10.0 + (rng.next() - 0.5) * 3.0
		var d: float = UkiyoMath.RIVER_HALF + 9.0 + rng.next() * 9.0
		var w: float = 5.0 + rng.next() * 2.5
		var depth: float = 4.0 + rng.next() * 1.5
		var roof_key: String = (
			ArchitectureBuilder.MAT_THATCH if rng.next() < 0.45 else ArchitectureBuilder.MAT_ROOF
		)
		ArchitectureBuilder.merge(
			buffers,
			ArchitectureBuilder.house(
				w, depth, 2.6, 1.9, roof_key,
				ArchitectureBuilder.MAT_PLASTER, ArchitectureBuilder.MAT_DARKWOOD, true
			),
			_on_bank(zz, side, d, true)
		)
	exclusions.push_back(
		Vector3(UkiyoMath.river_x(z) + side * (UkiyoMath.RIVER_HALF + 13.0), z, 30.0)
	)


func _place_stilt(buffers: Dictionary, z: float, side: float) -> void:
	var x: float = UkiyoMath.river_x(z) + side * (UkiyoMath.RIVER_HALF + 5.5)
	ArchitectureBuilder.merge(
		buffers, ArchitectureBuilder.stilt(),
		_placed(Vector3(x, 0.0, z), -side * PI * 0.5)
	)
	exclusions.push_back(Vector3(x, z, 9.0))


func _place_roadside_lanterns(buffers: Dictionary) -> void:
	var z: float = TORO_START
	var k: int = 0
	while z < TORO_END:
		var side: float = 1.0 if k % 2 == 1 else -1.0
		var x: float = UkiyoMath.river_x(z) + side * TORO_OFFSET
		var h: float = UkiyoMath.terrain_h(x, z)
		# Prototype: skip anything in the water, up a slope, or inside a landmark's footprint.
		if h >= 0.15 and h <= 5.0 and not blocked(x, z):
			ArchitectureBuilder.merge(
				buffers, ArchitectureBuilder.toro(), _placed(Vector3(x, h, z), 0.0)
			)
			toro_spots.push_back(Vector3(x, h + 1.7, z))
		z += TORO_SPACING
		k += 1


## placeOnBank(obj, z, side, d, faceRiver).
func _on_bank(z: float, side: float, d: float, face_river: bool) -> Transform3D:
	var x: float = UkiyoMath.river_x(z) + side * d
	var yaw: float = 0.0
	if face_river:
		yaw = -side * PI * 0.5 + atan(UkiyoMath.river_slope(z))
	return _placed(Vector3(x, UkiyoMath.terrain_h(x, z), z), yaw)


func _placed(origin: Vector3, yaw: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw), origin)
