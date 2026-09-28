## Verifies the boat physics port against a trajectory captured from the JavaScript prototype.
##
## The Drift autopilot is fully deterministic - no input, no randomness, constant storm wind - so
## the prototype's updateBoat() and this port must trace the same path step for step. The run
## below is 200 simulated seconds at a fixed 1/60 s, which carries the boat from its start at
## z = -335 down to the far limit, through the turnaround, and part of the way back: enough to
## exercise the autopilot's steering, the heading wrap, the bank clamp and the z clamp.
##
## Expected values came from running the prototype's own function under Node.
class_name BoatCheck
extends RefCounted

const DT: float = 1.0 / 60.0

## Storm wind, which is what the default preset holds steady.
const WIND: float = 1.6

## step index -> [x, z, heading, speed, turn, push, wave height]
const EXPECTED: Dictionary = {
	60: [0.456895834, -333.859012479, -0.186820803, 1.292274986, -0.044183695, 0.855181682, 0.006809690],
	300: [-1.006286921, -322.116810877, -0.131602259, 3.183967197, -0.008424084, 5.866179472, 0.067527427],
	1200: [-5.308543377, -263.039508874, -0.080425282, 3.555131399, 0.007808229, 27.919415687, 0.032920401],
	3600: [-29.680141432, -105.762323294, 0.129984847, 3.555555556, -0.033865415, 87.208098765, 0.162527058],
	12000: [-10.357373649, 324.344325319, -3.553404670, 3.554287276, 0.000782858, 293.266195644, -0.104896942],
}

const LABELS: PackedStringArray = ["x", "z", "heading", "speed", "turn", "push", "waveY"]

## Loose enough to absorb 200 s of accumulated floating point, tight enough that a wrong sign,
## a swapped atan2 argument or a missing wrap shows up immediately.
const TOLERANCE: float = 1e-4


static func run() -> int:
	var boat := Boat.new()
	boat.boat_x = UkiyoMath.river_x(Boat.START_Z)
	boat.boat_z = Boat.START_Z
	boat.heading = atan(UkiyoMath.river_slope(Boat.START_Z))

	var failures: int = 0
	var t: float = 0.0
	var last_step: int = 12000
	for step: int in range(1, last_step + 1):
		boat.step_physics(DT, t, WIND)
		t += DT
		if not EXPECTED.has(step):
			continue
		var want: Array = EXPECTED[step]
		var got: Array = [
			boat.boat_x, boat.boat_z, boat.heading, boat.speed, boat.turn, boat.push,
			UkiyoMath.wave_h(boat.boat_x, boat.boat_z, t, WIND),
		]
		for i: int in LABELS.size():
			var delta: float = absf(float(got[i]) - float(want[i]))
			if delta > TOLERANCE * maxf(1.0, absf(float(want[i]))):
				push_error("[boat_check] step %d %s = %.9f, expected %.9f (delta %.3e)" % [
					step, LABELS[i], got[i], want[i], delta,
				])
				failures += 1

	boat.free()
	if failures == 0:
		print("[boat_check] trajectory matches the JavaScript prototype over 200 s")
	else:
		push_error("[boat_check] %d value(s) differ from the JavaScript prototype" % failures)
	return failures
