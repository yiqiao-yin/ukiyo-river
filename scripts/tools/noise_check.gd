## Verifies the GDScript maths port against values captured from the JavaScript prototype.
##
## Every expected number below came from running the prototype's own functions under Node; the
## full listing is in docs/NOISE_CHECK.md. Run at startup from main.gd so a regression in the
## 32-bit emulation shows up the moment it happens rather than as a subtly different valley.
class_name NoiseCheck
extends RefCounted

const TOLERANCE: float = 1e-9


## Returns the number of mismatches; 0 means the port is exact. Pass true to print every value.
static func run(verbose: bool = false) -> int:
	var failures: int = 0

	# hash2(x, y)
	failures += _check("hash2(0,0)", UkiyoMath.hash2(0, 0), 0.000000000, verbose)
	failures += _check("hash2(1,0)", UkiyoMath.hash2(1, 0), 0.508124461, verbose)
	failures += _check("hash2(0,1)", UkiyoMath.hash2(0, 1), 0.768274554, verbose)
	failures += _check("hash2(-1,-1)", UkiyoMath.hash2(-1, -1), 0.062055925, verbose)
	failures += _check("hash2(37,-91)", UkiyoMath.hash2(37, -91), 0.102077803, verbose)
	failures += _check("hash2(1234,5678)", UkiyoMath.hash2(1234, 5678), 0.916257587, verbose)

	# vnoise(x, y)
	failures += _check("vnoise(0.5,0.5)", UkiyoMath.vnoise(0.5, 0.5), 0.334613735, verbose)
	failures += _check("vnoise(3.25,-7.75)", UkiyoMath.vnoise(3.25, -7.75), 0.169485628, verbose)
	failures += _check("vnoise(-12.125,4.5)", UkiyoMath.vnoise(-12.125, 4.5), 0.874071849, verbose)
	failures += _check("vnoise(100.7,200.3)", UkiyoMath.vnoise(100.7, 200.3), 0.575413277, verbose)

	# fbm(x, y, octaves)
	failures += _check("fbm(0.5,0.5,3)", UkiyoMath.fbm(0.5, 0.5, 3), 0.302268198, verbose)
	failures += _check("fbm(1.7,-2.3,5)", UkiyoMath.fbm(1.7, -2.3, 5), 0.456199046, verbose)
	failures += _check("fbm(-8.25,13.5,3)", UkiyoMath.fbm(-8.25, 13.5, 3), 0.456711694, verbose)
	failures += _check("fbm(3.3,4.4,5)", UkiyoMath.fbm(3.3, 4.4, 5), 0.581323554, verbose)

	# mulberry32 sequences
	var expected_world: PackedFloat64Array = PackedFloat64Array([
		0.260265860, 0.044911657, 0.702738767, 0.785821498,
		0.935177126, 0.909754414, 0.863882763, 0.221007573,
	])
	var world_rng := UkiyoRng.new(UkiyoRng.WORLD_SEED)
	for i: int in expected_world.size():
		failures += _check("rng[%d]" % i, world_rng.next(), expected_world[i], verbose)

	var expected_11: PackedFloat64Array = PackedFloat64Array([
		0.511587049, 0.529946408, 0.608118564, 0.590157636,
	])
	var rng_11 := UkiyoRng.new(11)
	for i: int in expected_11.size():
		failures += _check("m11[%d]" % i, rng_11.next(), expected_11[i], verbose)

	# riverX / riverSlope
	failures += _check("riverX(-335)", UkiyoMath.river_x(-335.0), 0.598427051, verbose)
	failures += _check("riverX(-125)", UkiyoMath.river_x(-125.0), -33.017525666, verbose)
	failures += _check("riverX(0)", UkiyoMath.river_x(0.0), 8.672023669, verbose)
	failures += _check("riverX(322)", UkiyoMath.river_x(322.0), -11.016092138, verbose)
	failures += _check("riverSlope(-335)", UkiyoMath.river_slope(-335.0), -0.227507602, verbose)
	failures += _check("riverSlope(0)", UkiyoMath.river_slope(0.0), 0.338002215, verbose)
	failures += _check("riverSlope(322)", UkiyoMath.river_slope(322.0), -0.469897569, verbose)

	# terrainH(x, z)
	failures += _check("terrainH(0,0)", UkiyoMath.terrain_h(0.0, 0.0), -3.200000000, verbose)
	failures += _check("terrainH(20,0)", UkiyoMath.terrain_h(20.0, 0.0), -3.200000000, verbose)
	failures += _check("terrainH(40,-100)", UkiyoMath.terrain_h(40.0, -100.0), 7.979142717, verbose)
	failures += _check("terrainH(-60,250)", UkiyoMath.terrain_h(-60.0, 250.0), 16.282005133, verbose)
	failures += _check("terrainH(150,-300)", UkiyoMath.terrain_h(150.0, -300.0), 35.003358356, verbose)
	failures += _check("terrainH(300,300)", UkiyoMath.terrain_h(300.0, 300.0), 93.407329834, verbose)
	failures += _check("terrainH(-450,-450)", UkiyoMath.terrain_h(-450.0, -450.0), 86.066607277, verbose)
	failures += _check("terrainH(17.5,-335)", UkiyoMath.terrain_h(17.5, -335.0), -3.043401743, verbose)

	if failures == 0:
		print("[noise_check] all values match the JavaScript prototype")
	else:
		push_error("[noise_check] %d value(s) differ from the JavaScript prototype" % failures)
	return failures


static func _check(label: String, got: float, want: float, verbose: bool) -> int:
	# The reference values are printed to 9 decimal places, so compare at that precision.
	var delta: float = absf(got - want)
	if delta > TOLERANCE * maxf(1.0, absf(want) * 10.0):
		push_error("[noise_check] %s = %.9f, expected %.9f (delta %.3e)" % [label, got, want, delta])
		return 1
	if verbose:
		print("[noise_check] %s = %.9f" % [label, got])
	return 0
