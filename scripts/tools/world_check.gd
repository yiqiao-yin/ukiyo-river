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


## Prototype tree scatter: how many of each species survive the rejection loop, and where the
## first of each lands. The loop consumes three numbers for a rejected attempt and six for an
## accepted one, so these only line up if that branch is exact.
const EXPECTED_TREE_COUNTS: Dictionary = {
	"cedar_near": 851, "cedar_far": 1142, "pine": 196, "cherry": 111,
}
## species -> [x, height, z, yaw draw, size draw]
const EXPECTED_FIRST_TREE: Dictionary = {
	"cedar_near": [-26.967705, 8.296433, -423.019126, 0.150385, 0.933384],
	"pine": [-10.133606, 6.945399, 267.354482, 0.130622, 0.436064],
	"cherry": [54.633985, 4.749505, 112.128975, 0.822546, 0.582020],
}


static func run(lanterns: FloatingLanterns, architecture: Architecture, trees: Trees) -> int:
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

	if trees != null and not trees.placements.is_empty():
		for species: String in EXPECTED_TREE_COUNTS:
			var count: int = (trees.placements[species] as Array).size()
			if count != int(EXPECTED_TREE_COUNTS[species]):
				push_error("[world_check] %d %s trees, expected %d" % [
					count, species, EXPECTED_TREE_COUNTS[species],
				])
				failures += 1
		for species: String in EXPECTED_FIRST_TREE:
			var list: Array = trees.placements[species]
			if list.is_empty():
				continue
			var want: Array = EXPECTED_FIRST_TREE[species]
			for i: int in 5:
				var delta: float = absf(float(list[0][i]) - float(want[i]))
				if delta > 1e-5 * maxf(1.0, absf(float(want[i]))):
					push_error("[world_check] first %s tree field %d = %.6f, expected %.6f" % [
						species, i, list[0][i], want[i],
					])
					failures += 1

	if failures == 0:
		print("[world_check] world laid out from the prototype's random sequence")
	else:
		push_error("[world_check] %d layout mismatch(es)" % failures)
	return failures
