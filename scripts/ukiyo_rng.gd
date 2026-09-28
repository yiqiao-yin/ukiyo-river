## mulberry32, ported verbatim from reference/ukiyo-river.html.
##
## A stateful counterpart to UkiyoMath: the prototype's `rng = mulberry32(20260923)` drives
## village jitter, floating lantern placement and tree scattering, so the sequence has to match
## call for call or the world lays out differently.
class_name UkiyoRng
extends RefCounted

## The prototype's global seed: `const rng = mulberry32(20260923)`.
const WORLD_SEED: int = 20260923

var _a: int = 0


func _init(seed_value: int) -> void:
	_a = seed_value & UkiyoMath.U32


## One draw in [0, 1).
func next() -> float:
	_a = (_a + 0x6D2B79F5) & UkiyoMath.U32
	var t: int = UkiyoMath.imul(_a ^ (_a >> 15), 1 | _a)
	t = ((t + UkiyoMath.imul(t ^ (t >> 7), 61 | t)) & UkiyoMath.U32) ^ t
	return float((t ^ (t >> 14)) & UkiyoMath.U32) / UkiyoMath.U32_F


## Convenience for the many `a + rng()*b` expressions in the prototype.
func range_f(from: float, to: float) -> float:
	return from + (to - from) * next()
