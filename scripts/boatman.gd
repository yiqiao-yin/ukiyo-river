## The boatman: a jointed figure poling the boat.
##
## Prototype: reference/ukiyo-river.html lines 743-846. Built from lathes, cylinders and
## squashed spheres rather than a skinned mesh, exactly as the prototype builds it - so there is
## no skeleton here either. The torso, head, hat and pole are nodes that move; the arms are six
## loose pieces per side, repositioned every frame from a two-bone IK solve that plants both
## hands on the pole.
class_name Boatman
extends Node3D

## Prototype: the figure stands here on the boat, facing the bow.
const STAND: Vector3 = Vector3(0.0, -0.1, -3.0)

## Prototype ARM_A / ARM_B - upper and lower arm lengths, which the IK solves against.
const UPPER_ARM: float = 0.29
const LOWER_ARM: float = 0.27

## Prototype POLE_PIVOT - where the pole sits in the boatman's hands.
const POLE_PIVOT: Vector3 = Vector3(0.2, 1.12, 0.36)

## Prototype grips: where each hand takes hold along the pole.
const GRIP_LOW: float = -0.1
const GRIP_HIGH: float = 0.42

@export var upper: Node3D
@export var head: Node3D
@export var hat: Node3D
@export var pole: Node3D
@export var eye: Marker3D

var materials: Dictionary = {}

## Six loose pieces per side: upper arm, forearm, sleeve, elbow, shoulder, hand.
var _arms: Array[Dictionary] = []

## Where the hand ended up after _solve_arm clamped it to the arm's reach. A member rather than
## a second return value: this runs twice a frame and returning an Array would allocate.
var _solved_hand: Vector3 = Vector3.ZERO


func _ready() -> void:
	position = STAND
	materials = BoatMaterials.build()

	# Euler order matters for the torso and head: the prototype leaves three.js on XYZ while
	# Godot defaults to YXZ, and both take an x and a y rotation.
	upper.rotation_order = EULER_ORDER_XYZ
	head.rotation_order = EULER_ORDER_XYZ

	_build_legs()
	_build_torso()
	_build_head()
	_build_hat()
	_build_pole()
	_build_arms()
	animate(0.0, 1.0)


## animateBoatman(ph, act) - one poling cycle. `act` is how hard he is working.
func animate(phase: float, activity: float) -> void:
	var s: float = sin(phase)
	var c: float = cos(phase)
	var a: float = 0.3 + 0.32 * s * activity

	upper.rotation = Vector3(0.1 + 0.13 * s * activity, -0.12 - 0.06 * c * activity, 0.0)
	head.rotation = Vector3(-upper.rotation.x * 0.75 + 0.05, 0.1, 0.0)
	pole.position = POLE_PIVOT + Vector3(0.0, 0.04 * c * activity, 0.1 * s * activity)
	pole.rotation = Vector3(a, 0.0, -0.08)
	_solve_arms()


## Plants both hands on the pole wherever it currently is.
func _solve_arms() -> void:
	for arm: Dictionary in _arms:
		var side: float = arm["side"]
		# Shoulder rides the torso, hand rides the pole - both in the boatman's own space.
		var shoulder_point: Vector3 = upper.transform * Vector3(side * 0.2, 0.52, 0.0)
		var hand_point: Vector3 = pole.transform * Vector3(
			0.0, GRIP_HIGH if side > 0.0 else GRIP_LOW, 0.0
		)
		hand_point.x -= 0.035 * side

		var elbow_point: Vector3 = _solve_arm(
			shoulder_point, hand_point, Vector3(side * 0.8, -0.8, -0.4)
		)
		# _solve_arm pulls the hand in if the pole is out of reach; take the clamped one back.
		hand_point = _solved_hand

		_orient(arm["upper"], shoulder_point, elbow_point)
		_orient(arm["lower"], elbow_point, hand_point)
		var sleeve: Node3D = arm["sleeve"]
		sleeve.position = shoulder_point.lerp(elbow_point, 0.45)
		sleeve.basis = (arm["upper"] as Node3D).basis
		(arm["elbow"] as Node3D).position = elbow_point
		(arm["shoulder"] as Node3D).position = shoulder_point
		var hand: Node3D = arm["hand"]
		hand.position = hand_point
		hand.basis = (arm["lower"] as Node3D).basis


## A staff sweep, left or right. `t` runs 0 to 1 over the move.
##
## This costs almost nothing to animate because the arms already solve to the pole: swing the
## pole and twist the torso, and the hands follow on their own. Which is also why it looks like
## a boatman fighting rather than a swordsman - he is using the punt pole the only way he knows,
## flat and two-handed, with his whole body behind it.
func strike(t: float, direction: float) -> void:
	# Wind up against the swing, then carry through past the target.
	var swing: float = -cos(clampf(t, 0.0, 1.0) * PI) # -1 at the start, +1 at the end
	var yaw: float = direction * swing * 1.15
	var lean: float = sin(clampf(t, 0.0, 1.0) * PI)

	upper.rotation = Vector3(0.1 + lean * 0.18, -0.12 + yaw * 0.55, direction * lean * 0.12)
	head.rotation = Vector3(-upper.rotation.x * 0.6 + 0.05, yaw * 0.25, 0.0)
	pole.position = POLE_PIVOT + Vector3(-direction * lean * 0.12, 0.22 * lean, 0.18 * lean)
	# Held flat and level, so it sweeps across the deck rather than chopping.
	pole.rotation = Vector3(1.45, yaw * 1.5, -0.08 + direction * 0.25)
	_solve_arms()


## Guard: the pole brought up level and held across the chest with both hands.
##
## A boatman has no idea how to parry, but he does know how to hold a heavy pole steady, and
## with the arms already solving to its grips it is the most natural defensive shape the rig
## can make. `held` is how long the guard has been up, which lets a fresh raise snap into
## place and a held one settle.
func guard(held: float) -> void:
	var settle: float = clampf(held * 6.0, 0.0, 1.0)
	upper.rotation = Vector3(0.22, -0.34, 0.0)
	head.rotation = Vector3(-0.12, 0.28, 0.0)
	pole.position = POLE_PIVOT + Vector3(-0.16, 0.30 - settle * 0.03, 0.24)
	# Level and across, rather than the raked poling angle.
	pole.rotation = Vector3(1.52, 1.15, -0.05)
	_solve_arms()


## solveArm() - two-bone IK. Returns the elbow; the clamped hand lands in _solved_hand.
func _solve_arm(from: Vector3, to: Vector3, hint: Vector3) -> Vector3:
	var delta: Vector3 = to - from
	var d: float = delta.length()
	var reach: float = UPPER_ARM + LOWER_ARM - 0.005
	if d > reach:
		delta *= reach / d
		to = from + delta
		d = reach
	_solved_hand = to
	if d < 1e-5:
		return from
	var dir: Vector3 = delta / d
	# Distance along the shoulder-to-hand line where the elbow projects, and how far off it.
	var x: float = (UPPER_ARM * UPPER_ARM - LOWER_ARM * LOWER_ARM + d * d) / (2.0 * d)
	var h: float = sqrt(maxf(0.0, UPPER_ARM * UPPER_ARM - x * x))
	var bend: Vector3 = (hint - dir * hint.dot(dir)).normalized()
	return from + dir * x + bend * h


## orient(m, a, b) - centre the piece between two points with its own +Y running a to b.
func _orient(node: Node3D, from: Vector3, to: Vector3) -> void:
	var delta: Vector3 = to - from
	var length: float = delta.length()
	node.position = from + delta * 0.5
	if length > 1e-6:
		node.basis = Basis(Quaternion(Vector3.UP, delta / length))


func _build_legs() -> void:
	var b: Dictionary = _buffers()
	# Hip, knee and ankle for each leg.
	var legs: Array = [
		[Vector3(-0.1, 0.86, 0.02), Vector3(-0.12, 0.47, 0.13), Vector3(-0.13, 0.09, 0.03)],
		[Vector3(0.1, 0.86, -0.02), Vector3(0.13, 0.48, -0.09), Vector3(0.15, 0.09, -0.22)],
	]
	for leg: Array in legs:
		var hip: Vector3 = leg[0]
		var knee: Vector3 = leg[1]
		var ankle: Vector3 = leg[2]
		MeshUtil.add_cone(b[BoatMaterials.PANTS], hip, knee, 0.085, 0.066, 16)
		MeshUtil.add_sphere(b[BoatMaterials.GAITER], knee, 0.064, 20, 14)
		MeshUtil.add_cone(b[BoatMaterials.GAITER], knee, ankle, 0.058, 0.044, 16)
		MeshUtil.add_sphere(b[BoatMaterials.SKIN], ankle, 0.045, 20, 14)
		MeshUtil.add_sphere(
			b[BoatMaterials.SKIN], Vector3(ankle.x, 0.04, ankle.z + 0.07), 0.05, 20, 14,
			Vector3(0.95, 0.6, 2.1)
		)
		# Straw sandal and its thong.
		MeshUtil.add_box(
			b[BoatMaterials.STRAW], Vector3(ankle.x, 0.012, ankle.z + 0.06),
			Vector3(0.12, 0.022, 0.27)
		)
		MeshUtil.add_cone(
			b[BoatMaterials.CORD],
			Vector3(ankle.x - 0.05, 0.02, ankle.z + 0.14),
			Vector3(ankle.x + 0.05, 0.07, ankle.z), 0.008, 0.008, 6
		)
	_commit(self, b, "Legs")


func _build_torso() -> void:
	var b: Dictionary = _buffers()
	_lathe_scaled(b[BoatMaterials.KIMONO], PackedVector2Array([
		Vector2(0.05, -0.2), Vector2(0.17, -0.12), Vector2(0.2, 0.0), Vector2(0.19, 0.14),
		Vector2(0.175, 0.26), Vector2(0.2, 0.4), Vector2(0.21, 0.5), Vector2(0.16, 0.57),
		Vector2(0.08, 0.61), Vector2(0.05, 0.63),
	]), 32, 0.0, TAU, 0.72)
	_lathe_scaled(b[BoatMaterials.KIMONO], PackedVector2Array([
		Vector2(0.26, -0.34), Vector2(0.235, -0.16), Vector2(0.205, 0.02),
	]), 32, 0.0, TAU, 0.8)

	# Sash and its knot at the back.
	var obi := MeshUtil.Buffer.new()
	MeshUtil.add_cone(obi, Vector3(0.0, 0.03, 0.0), Vector3(0.0, 0.13, 0.0), 0.207, 0.203, 32)
	MeshUtil.append_transformed(
		b[BoatMaterials.OBI], obi,
		Transform3D(Basis.IDENTITY.scaled(Vector3(1.0, 1.0, 0.73)), Vector3.ZERO)
	)
	MeshUtil.add_sphere(
		b[BoatMaterials.OBI], Vector3(0.0, 0.08, -0.155), 0.045, 20, 14,
		Vector3(1.4, 0.8, 0.7)
	)

	MeshUtil.add_torus(
		b[BoatMaterials.GAITER], Vector3(0.0, 0.585, 0.02), 0.09, 0.022, 8, 24, TAU,
		Basis(Vector3.RIGHT, PI * 0.5 + 0.35).scaled(Vector3(1.0, 1.25, 1.0))
	)

	# Three overlapping layers of straw cape, each left open at the front.
	_lathe_scaled(b[BoatMaterials.MINO], PackedVector2Array([
		Vector2(0.41, 0.1), Vector2(0.35, 0.28), Vector2(0.27, 0.45),
		Vector2(0.16, 0.57), Vector2(0.095, 0.63),
	]), 44, 0.55, TAU - 1.1, 0.8)
	_lathe_scaled(b[BoatMaterials.MINO], PackedVector2Array([
		Vector2(0.45, -0.2), Vector2(0.39, 0.0), Vector2(0.33, 0.2), Vector2(0.28, 0.36),
	]), 44, 0.6, TAU - 1.2, 0.8)
	_lathe_scaled(b[BoatMaterials.MINO], PackedVector2Array([
		Vector2(0.46, -0.46), Vector2(0.41, -0.3), Vector2(0.35, -0.1), Vector2(0.31, 0.02),
	]), 44, 0.65, TAU - 1.3, 0.8)

	MeshUtil.add_cone(
		b[BoatMaterials.SKIN], Vector3(0.0, 0.6, 0.0), Vector3(0.0, 0.72, 0.01), 0.05, 0.047, 16
	)
	_commit(upper, b, "Body")


func _build_head() -> void:
	var b: Dictionary = _buffers()
	var skin: MeshUtil.Buffer = b[BoatMaterials.SKIN]
	var hair: MeshUtil.Buffer = b[BoatMaterials.HAIR]
	MeshUtil.add_sphere(skin, Vector3(0.0, 0.06, 0.012), 0.1, 20, 14, Vector3(0.9, 1.12, 1.02))
	MeshUtil.add_sphere(skin, Vector3(0.0, 0.0, 0.045), 0.06, 20, 14, Vector3(1.1, 0.8, 1.0))
	# Nose: a cone laid over on its side.
	var nose := MeshUtil.Buffer.new()
	MeshUtil.add_cone(nose, Vector3(0.0, -0.0225, 0.0), Vector3(0.0, 0.0225, 0.0), 0.017, 0.0, 10)
	MeshUtil.append_transformed(
		skin, nose,
		Transform3D(Basis(Vector3.RIGHT, PI * 0.5 - 0.3), Vector3(0.0, 0.05, 0.108))
	)
	for x: float in [-0.092, 0.092]:
		MeshUtil.add_sphere(skin, Vector3(x, 0.05, -0.005), 0.026, 12, 8, Vector3(0.45, 1.0, 0.8))
	for x: float in [-0.034, 0.034]:
		MeshUtil.add_sphere(hair, Vector3(x, 0.075, 0.098), 0.011, 10, 6, Vector3(1.4, 0.5, 0.6))
	MeshUtil.add_sphere(hair, Vector3(0.0, 0.085, -0.008), 0.104, 20, 14, Vector3(0.93, 1.02, 1.03))
	MeshUtil.add_sphere(hair, Vector3(0.0, 0.19, -0.05), 0.035, 14, 10, Vector3(0.8, 0.7, 1.4))
	MeshUtil.add_sphere(hair, Vector3(0.0, -0.02, 0.07), 0.03, 14, 10, Vector3(1.6, 0.8, 0.7))
	# Hat cords under the chin.
	for x: float in [-0.085, 0.085]:
		MeshUtil.add_cone(
			b[BoatMaterials.CORD], Vector3(x, 0.14, 0.0), Vector3(x * 0.25, -0.07, 0.07),
			0.005, 0.005, 6
		)
	_commit(head, b, "Head")


func _build_hat() -> void:
	var b: Dictionary = _buffers()
	var profile := PackedVector2Array([
		Vector2(0.47, -0.05), Vector2(0.455, -0.04), Vector2(0.37, 0.005), Vector2(0.25, 0.075),
		Vector2(0.13, 0.14), Vector2(0.05, 0.172), Vector2(0.001, 0.18),
	])
	MeshUtil.add_lathe(b[BoatMaterials.STRAW], profile, 64)
	var lining := PackedVector2Array()
	for p: Vector2 in profile:
		lining.push_back(Vector2(p.x * 0.97, p.y - 0.014))
	MeshUtil.add_lathe(b[BoatMaterials.STRAW_IN], lining, 64)
	MeshUtil.add_torus(
		b[BoatMaterials.CORD], Vector3(0.0, -0.046, 0.0), 0.463, 0.009, 8, 80, TAU,
		Basis(Vector3.RIGHT, PI * 0.5)
	)
	MeshUtil.add_cone(
		b[BoatMaterials.CORD], Vector3(0.0, 0.17, 0.0), Vector3(0.0, 0.22, 0.0), 0.03, 0.0, 12
	)
	_commit(hat, b, "Hat")


func _build_pole() -> void:
	var b: Dictionary = _buffers()
	MeshUtil.add_cone(
		b[BoatMaterials.BAMBOO], Vector3(0.0, -4.3, 0.0), Vector3(0.0, 2.1, 0.0), 0.036, 0.03, 14
	)
	_commit(pole, b, "Pole")


func _build_arms() -> void:
	for i: int in 2:
		var side: float = 1.0 if i == 1 else -1.0
		var arm: Dictionary = {"side": side}
		arm["upper"] = _piece(_cone_mesh(UPPER_ARM, 0.07, 0.058, 16), BoatMaterials.KIMONO)
		arm["lower"] = _piece(_cone_mesh(LOWER_ARM, 0.046, 0.036, 16), BoatMaterials.SKIN)
		arm["sleeve"] = _piece(_cone_mesh(0.16, 0.062, 0.075, 16), BoatMaterials.KIMONO)
		arm["elbow"] = _piece(_sphere_mesh(0.05, Vector3.ONE), BoatMaterials.SKIN)
		arm["shoulder"] = _piece(_sphere_mesh(0.075, Vector3.ONE), BoatMaterials.KIMONO)
		arm["hand"] = _piece(
			_sphere_mesh(0.045, Vector3(0.85, 1.05, 1.35)), BoatMaterials.SKIN
		)
		_arms.push_back(arm)


func _piece(mesh: ArrayMesh, material_key: String) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = materials[material_key]
	add_child(instance)
	return instance


## A cone centred on the origin with its axis along Y, ready to be reoriented each frame.
func _cone_mesh(length: float, bottom: float, top: float, segments: int) -> ArrayMesh:
	var buffer := MeshUtil.Buffer.new()
	MeshUtil.add_cone(
		buffer, Vector3(0.0, -length * 0.5, 0.0), Vector3(0.0, length * 0.5, 0.0),
		bottom, top, segments
	)
	var mesh := ArrayMesh.new()
	buffer.commit(mesh)
	return mesh


func _sphere_mesh(radius: float, scale: Vector3) -> ArrayMesh:
	var buffer := MeshUtil.Buffer.new()
	MeshUtil.add_sphere(buffer, Vector3.ZERO, radius, 20, 14, scale)
	var mesh := ArrayMesh.new()
	buffer.commit(mesh)
	return mesh


## A lathe squashed along z, which is how the prototype narrows the torso and the cape.
func _lathe_scaled(
	target: MeshUtil.Buffer, profile: PackedVector2Array, segments: int,
	phi_start: float, phi_length: float, z_scale: float
) -> void:
	var temp := MeshUtil.Buffer.new()
	MeshUtil.add_lathe(temp, profile, segments, phi_start, phi_length)
	MeshUtil.append_transformed(
		target, temp,
		Transform3D(Basis.IDENTITY.scaled(Vector3(1.0, 1.0, z_scale)), Vector3.ZERO)
	)


func _buffers() -> Dictionary:
	var out: Dictionary = {}
	for key: String in materials:
		out[key] = MeshUtil.Buffer.new()
	return out


## One MeshInstance3D per material that actually got used.
func _commit(parent: Node3D, buffers: Dictionary, group: String) -> void:
	for key: String in buffers:
		var buffer: MeshUtil.Buffer = buffers[key]
		if buffer.is_empty():
			continue
		var mesh := ArrayMesh.new()
		buffer.commit(mesh)
		var instance := MeshInstance3D.new()
		instance.name = "%s%s" % [group, key.capitalize()]
		instance.mesh = mesh
		instance.material_override = materials[key]
		parent.add_child(instance)
