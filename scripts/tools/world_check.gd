## Verifies that the world was laid out from the same random sequence as the prototype.
##
## The floating lanterns are the sharp end of this. Their 120 numbers come off the shared stream
## only after every village house has drawn its five, so if a village consumed the wrong count,
## drew in the wrong order, or a landmark that should not touch the stream did, the lanterns all
## land somewhere else. Checking them checks the whole ordering with five numbers.
##
## Expected values came from running the prototype's own sequence under Node.
class_name WorldCheck
extends RefCounted

const TOLERANCE: float = 1e-6

## index -> [z along the river, offset across it, phase]
const EXPECTED_FLOATERS: Dictionary = {
	0: [-53.027691012, -10.984589631, 3.195344514],
	1: [-142.595516676, -0.760852401, 2.718767635],
	19: [-321.526272241, 13.249635983, 5.397128027],
	38: [-109.740166641, -11.297743696, 0.139312506],
	39: [-274.925933657, 1.628847100, 3.098699766],
}

const LABELS: PackedStringArray = ["z", "offset", "phase"]


static func run(lanterns: FloatingLanterns, architecture: Architecture) -> int:
	var failures: int = 0

	if lanterns == null or lanterns.floaters.size() != FloatingLanterns.COUNT:
		push_error("[world_check] the floating lanterns were not built")
		return 1

	for index: int in EXPECTED_FLOATERS:
		var want: Array = EXPECTED_FLOATERS[index]
		var got: Vector3 = lanterns.floaters[index]
		for i: int in 3:
			var value: float = got[i]
			var delta: float = absf(value - float(want[i]))
			if delta > TOLERANCE * maxf(1.0, absf(float(want[i]))):
				push_error("[world_check] floater %d %s = %.9f, expected %.9f" % [
					index, LABELS[i], value, want[i],
				])
				failures += 1

	if architecture != null:
		# Not random, but it does depend on every exclusion circle being registered: a landmark
		# that failed to claim its footprint would let extra lanterns through.
		# 4 flanking the two shrines, plus 19 roadside ones that clear the ground and footprint
		# tests. Counted by replaying the prototype's own placement loop.
		var spots: int = architecture.toro_spots.size()
		if spots != 23:
			push_error("[world_check] %d stone lanterns placed, expected 23" % spots)
			failures += 1

	if failures == 0:
		print("[world_check] world laid out from the prototype's random sequence")
	else:
		push_error("[world_check] %d layout mismatch(es)" % failures)
	return failures
