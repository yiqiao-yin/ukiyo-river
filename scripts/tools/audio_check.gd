## Sanity-checks the synthesised audio.
##
## The beds are generated noise, so there is nothing to diff against the prototype sample for
## sample - but silence, NaNs, a dead filter or a bed wired to the wrong noise source are all
## easy to ship blind, because the headless runs use a dummy audio driver and never make a
## sound. This renders each bed on its own and asserts it is audible, finite, and in roughly the
## right part of the spectrum: rain is band-limited white and should cross zero constantly,
## wind is brown noise rolled off at 380 Hz and should crawl.
class_name AudioCheck
extends RefCounted

## Long enough for the slowest gain ramp (0.6 s) to settle before anything is measured.
const SETTLE_SECONDS: float = 3.0
const MEASURE_SECONDS: float = 1.0


static func run() -> int:
	var failures: int = 0
	failures += _check_bed("rain", 0.3, 0.0, 0.0, 0.02, 0.15, 1.0)
	failures += _check_bed("wind", 0.0, 0.18, 0.0, 0.002, 0.0, 0.08)
	failures += _check_bed("lap", 0.0, 0.0, 0.3, 0.002, 0.01, 0.2)
	failures += _check_thunder()

	if failures == 0:
		print("[audio_check] all beds audible, finite and in band")
	else:
		push_error("[audio_check] %d problem(s) in the synthesised audio" % failures)
	return failures


## Renders one bed alone and checks its level and its zero-crossing rate, which stands in for
## brightness without needing an FFT.
static func _check_bed(
	label: String, rain: float, wind: float, lap: float,
	min_rms: float, min_zcr: float, max_zcr: float
) -> int:
	var director := AudioDirector.new()
	director.configure()
	# Nothing is audible before Cast off; the check is driving the synthesis directly.
	director.started = true
	director.set_targets(rain, wind, lap)
	director.render(int(AudioDirector.MIX_RATE * SETTLE_SECONDS))
	var buffer: PackedVector2Array = director.render(int(AudioDirector.MIX_RATE * MEASURE_SECONDS))
	director.free()

	var failures: int = 0
	var sum_squares: float = 0.0
	var crossings: int = 0
	var previous: float = 0.0
	for i: int in buffer.size():
		var v: float = buffer[i].x
		if not is_finite(v):
			push_error("[audio_check] %s produced a non-finite sample at %d" % [label, i])
			return 1
		sum_squares += v * v
		if (v >= 0.0) != (previous >= 0.0):
			crossings += 1
		previous = v

	var rms: float = sqrt(sum_squares / float(buffer.size()))
	var zcr: float = float(crossings) / float(buffer.size())
	print("[audio_check] %s: rms %.4f, zero crossings %.3f per sample" % [label, rms, zcr])

	if rms < min_rms:
		push_error("[audio_check] %s is too quiet: rms %.5f below %.5f" % [label, rms, min_rms])
		failures += 1
	if zcr < min_zcr or zcr > max_zcr:
		push_error("[audio_check] %s sits outside its band: %.3f crossings, wanted %.3f-%.3f" % [
			label, zcr, min_zcr, max_zcr,
		])
		failures += 1
	return failures


## Thunder has to rise from silence to a real peak and then decay away again.
static func _check_thunder() -> int:
	var director := AudioDirector.new()
	director.configure()
	director.started = true
	director.set_targets(0.0, 0.0, 0.0)
	# Let the master gain come up first, so the peak measured is the thunder's own.
	director.render(int(AudioDirector.MIX_RATE * 1.0))
	director.thunder(0.1)
	var burst: PackedVector2Array = director.render(int(AudioDirector.MIX_RATE * 3.0))
	var tail: PackedVector2Array = director.render(int(AudioDirector.MIX_RATE * 8.0))
	director.free()

	var peak: float = 0.0
	for i: int in burst.size():
		peak = maxf(peak, absf(burst[i].x))
	var tail_peak: float = 0.0
	for i: int in range(tail.size() - int(AudioDirector.MIX_RATE), tail.size()):
		tail_peak = maxf(tail_peak, absf(tail[i].x))
	print("[audio_check] thunder: peak %.3f, tail %.5f" % [peak, tail_peak])

	var failures: int = 0
	if peak < 0.1:
		push_error("[audio_check] thunder never got loud: peak %.4f" % peak)
		failures += 1
	if tail_peak > 0.01:
		push_error("[audio_check] thunder never decayed: tail %.4f" % tail_peak)
		failures += 1
	return failures
