## Shared maths ported verbatim from reference/ukiyo-river.html.
##
## The hash functions are 32-bit in JavaScript (Math.imul, >>>) while GDScript ints are 64-bit
## signed, so every hash value is carried as an unsigned 32-bit number and masked back into range
## after each operation. Multiplication is allowed to overflow int64 on the way: the low 32 bits
## of the product survive the wrap, which is all Math.imul keeps either.
##
## Reference values for every function here live in docs/NOISE_CHECK.md and are asserted by
## scripts/tools/noise_check.gd.
class_name UkiyoMath
extends RefCounted

const U32: int = 0xFFFFFFFF
const U32_F: float = 4294967296.0

const RIVER_HALF: float = 17.0

## [amplitude, x frequency, z frequency, time frequency] - prototype WAVES
const WAVES: Array[Vector4] = [
	Vector4(0.06, 0.21, 0.13, 1.3),
	Vector4(0.05, -0.17, 0.29, 1.7),
	Vector4(0.035, 0.41, -0.23, 2.3),
	Vector4(0.025, -0.33, -0.47, 2.9),
]


## JavaScript `x | 0` followed by a reinterpretation as unsigned 32-bit.
static func to_u32(v: float) -> int:
	return int(v) & U32


## JavaScript `Math.imul(a, b)`, both operands and the result as unsigned 32-bit.
## Split into 16-bit halves so no intermediate product can overflow a signed 64-bit int.
static func imul(a: int, b: int) -> int:
	var lo: int = (a & 0xFFFF) * b
	var hi: int = ((a >> 16) * b) & 0xFFFF
	return (lo + (hi << 16)) & U32


## smooth(a, b, x) - smoothstep with the prototype's argument order.
static func smooth(a: float, b: float, x: float) -> float:
	var t: float = clampf((x - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


## hash2(x, y) - 32-bit integer hash returning [0, 1).
static func hash2(x: int, y: int) -> float:
	var h: int = (imul(x & U32, 374761393) ^ imul(y & U32, 668265263)) & U32
	h = imul(h ^ (h >> 13), 1274126177)
	h = (h ^ (h >> 16)) & U32
	return float(h) / U32_F


## vnoise(x, y) - value noise over hash2 with a smoothstep fade.
static func vnoise(x: float, y: float) -> float:
	var ix: int = int(floorf(x))
	var iy: int = int(floorf(y))
	var fx: float = x - float(ix)
	var fy: float = y - float(iy)
	var ux: float = fx * fx * (3.0 - 2.0 * fx)
	var uy: float = fy * fy * (3.0 - 2.0 * fy)
	var a: float = lerpf(hash2(ix, iy), hash2(ix + 1, iy), ux)
	var b: float = lerpf(hash2(ix, iy + 1), hash2(ix + 1, iy + 1), ux)
	return lerpf(a, b, uy)


## fbm(x, y, octaves) - normalised fractal sum of vnoise.
static func fbm(x: float, y: float, octaves: int) -> float:
	var s: float = 0.0
	var a: float = 0.5
	var f: float = 1.0
	var n: float = 0.0
	for i: int in octaves:
		s += a * vnoise(x * f + float(i) * 17.3, y * f - float(i) * 9.1)
		n += a
		a *= 0.5
		f *= 2.03
	return s / n


## angleLerp(a, b, t) - shortest-arc interpolation between two headings.
static func angle_lerp(a: float, b: float, t: float) -> float:
	var d: float = b - a
	while d > PI:
		d -= TAU
	while d < -PI:
		d += TAU
	return a + d * t


## riverX(z) - centre line of the river.
static func river_x(z: float) -> float:
	return 26.0 * sin(z * 0.0105) + 9.0 * sin(z * 0.027 + 1.3)


## riverSlope(z) - d(riverX)/dz.
static func river_slope(z: float) -> float:
	return 26.0 * 0.0105 * cos(z * 0.0105) + 9.0 * 0.027 * cos(z * 0.027 + 1.3)


## terrainH(x, z) - ground height: flat river bed, banks, then distant mountains.
static func terrain_h(x: float, z: float) -> float:
	var d: float = absf(x - river_x(z))
	var bank: float = smooth(RIVER_HALF - 1.0, RIVER_HALF + 11.0, d)
	var h: float = -3.2 + bank * (4.4 + fbm(x * 0.035, z * 0.035, 3) * 9.0)
	var far: float = smooth(50.0, 190.0, d)
	h += far * (maxf(0.0, fbm(x * 0.007 + 13.1, z * 0.007 - 4.2, 5) - 0.25) * 230.0 + 8.0)
	return h


## waveH(x, z, t, amp) - the CPU-side wave height the boat and lanterns ride on.
static func wave_h(x: float, z: float, t: float, amp: float) -> float:
	var h: float = 0.0
	for w: Vector4 in WAVES:
		h += w.x * sin(x * w.y + z * w.z + t * w.w)
	return h * amp
