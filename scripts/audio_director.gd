## Ambient sound, synthesised the way the prototype synthesises it.
##
## Prototype: reference/ukiyo-river.html lines 1267-1303. Three looping noise beds - white noise
## band-limited for rain, brown noise rolled off for wind, brown noise through a narrow bandpass
## for water lapping at the hull - plus thunder as a swept lowpass over brown noise with a
## multi-stage envelope, and a highpassed crack for near strikes.
##
## Web Audio's graph becomes one AudioStreamGenerator here: the noise sources and biquads are
## evaluated per sample in GDScript and mixed into a single buffer. Everything is generated, so
## the project still ships without a single audio file.
class_name AudioDirector
extends Node

## Half of CD rate. The highest filter corner in the prototype is 6.5 kHz, so 11 kHz of
## bandwidth is plenty, and it halves the per-sample cost.
const MIX_RATE: float = 22050.0

## Prototype master gain.
const MASTER_GAIN: float = 0.9

@export var environment_controller: EnvironmentController
@export var boat: Boat
@export var player: AudioStreamPlayer

## Prototype `audio.on`, toggled by the Sound button.
var enabled: bool = true

## Set by the Cast off button. A browser cannot start audio before a user gesture either, so
## nothing is heard behind the title card.
var started: bool = false

## Set from Settings, 0 to 1.
var master_volume: float = 1.0

# Noise sources. Brown noise is the prototype's integrator: last = (last + 0.02*white)/1.02.
var _brown_wind: float = 0.0
var _brown_lap: float = 0.0
var _brown_thunder: float = 0.0

var _rain_highpass := Biquad.new()
var _rain_lowpass := Biquad.new()
var _wind_lowpass := Biquad.new()
var _lap_bandpass := Biquad.new()
var _thunder_lowpass := Biquad.new()
var _crack_highpass := Biquad.new()

# Smoothed gains, approached per sample the way setTargetAtTime does.
var _gain_rain: float = 0.0
var _gain_wind: float = 0.0
var _gain_lap: float = 0.0
var _gain_master: float = 0.0

var _target_rain: float = 0.0
var _target_wind: float = 0.0
var _target_lap: float = 0.0

## Seconds since the current thunder started, or negative when silent.
var _thunder_time: float = -1.0
var _thunder_nearness: float = 0.0
var _crack_time: float = -1.0


func _ready() -> void:
	# The menu pauses the tree; audio has to keep running or it stutters on every pause.
	process_mode = Node.PROCESS_MODE_ALWAYS
	configure()
	if player == null:
		return
	# Headless runs use the dummy audio driver and never hand back a playback; that is fine,
	# nothing else in the scene depends on audio existing.
	player.play()


## Releases the generator's playback. Godot frees the internal player at quit without clearing
## its stream reference, so the playback is never released and is reported as a leaked ObjectDB
## instance (godotengine/godot#95484, closed as not planned).
##
## Doing this from _exit_tree is too late: the audio server needs a frame to let go, and there
## are no more frames once teardown has started. main.gd calls this on the close request and
## then waits before quitting.
func shutdown() -> void:
	if player == null:
		return
	if player.playing:
		player.stop()
	player.stream = null


func _process(_delta: float) -> void:
	if environment_controller != null:
		# Prototype: 0.3*rain, 0.18*wind, 0.06 + 0.3*speedN.
		_target_rain = 0.3 * environment_controller.num("rain")
		_target_wind = 0.18 * environment_controller.num("wind")
		var speed_n: float = boat.speed_normalised() if boat != null else 0.0
		_target_lap = 0.06 + 0.3 * speed_n
	_fill()


## Sets up the filter bank. Split out of _ready so scripts/tools/audio_check.gd can drive the
## synthesis without an audio server behind it.
func configure() -> void:
	_rain_highpass.set_highpass(900.0, MIX_RATE)
	_rain_lowpass.set_lowpass(6500.0, MIX_RATE)
	_wind_lowpass.set_lowpass(380.0, MIX_RATE)
	_lap_bandpass.set_bandpass(520.0, 0.8, MIX_RATE)
	_crack_highpass.set_highpass(1200.0, MIX_RATE)


## Directly sets the bed gains, bypassing the per-frame read from the environment.
func set_targets(rain: float, wind: float, lap: float) -> void:
	_target_rain = rain
	_target_wind = wind
	_target_lap = lap


## Prototype thunder(n): n is 0 for a near strike and 1 for a distant one.
func thunder(nearness: float) -> void:
	_thunder_time = 0.0
	_thunder_nearness = clampf(nearness, 0.0, 1.0)
	_thunder_lowpass.set_lowpass(1200.0 - _thunder_nearness * 900.0, MIX_RATE)
	# Prototype: only close strikes get the sharp crack on top.
	_crack_time = 0.0 if _thunder_nearness < 0.25 else -1.0


## The playback is fetched per fill rather than cached: a cached reference into the audio
## server outlives shutdown and is reported as a leaked ObjectDB instance on exit.
func _fill() -> void:
	# Nothing to push once shutdown() has stopped the player, and asking a stopped player for
	# its playback is an error.
	if player == null or not player.playing:
		return
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return
	var frames: int = playback.get_frames_available()
	if frames <= 0:
		return
	playback.push_buffer(render(frames))


## The synthesis itself: mixes the beds, thunder and crack into `frames` stereo samples.
func render(frames: int) -> PackedVector2Array:
	var dt: float = 1.0 / MIX_RATE
	# setTargetAtTime time constants from the prototype.
	var k_rain: float = 1.0 - exp(-dt / 0.4)
	var k_wind: float = 1.0 - exp(-dt / 0.6)
	var k_lap: float = 1.0 - exp(-dt / 0.3)
	var k_master: float = 1.0 - exp(-dt / 0.1)
	var master_target: float = (MASTER_GAIN * master_volume) if (enabled and started) else 0.0

	# Deliberately a fresh array per call rather than a reused member: callers hold onto what
	# render() hands back, and a shared buffer would be overwritten under them by the next call.
	# The allocation happens a few times a second when the generator asks for data, not per frame.
	var buffer := PackedVector2Array()
	buffer.resize(frames)

	for i: int in frames:
		_gain_rain += (_target_rain - _gain_rain) * k_rain
		_gain_wind += (_target_wind - _gain_wind) * k_wind
		_gain_lap += (_target_lap - _gain_lap) * k_lap
		_gain_master += (master_target - _gain_master) * k_master

		var sample: float = 0.0

		if _gain_rain > 0.0001:
			var white: float = randf() * 2.0 - 1.0
			sample += _rain_lowpass.process(_rain_highpass.process(white)) * _gain_rain

		if _gain_wind > 0.0001:
			_brown_wind = (_brown_wind + 0.02 * (randf() * 2.0 - 1.0)) / 1.02
			sample += _wind_lowpass.process(_brown_wind * 3.5) * _gain_wind

		if _gain_lap > 0.0001:
			_brown_lap = (_brown_lap + 0.02 * (randf() * 2.0 - 1.0)) / 1.02
			sample += _lap_bandpass.process(_brown_lap * 3.5) * _gain_lap

		if _thunder_time >= 0.0:
			sample += _thunder_sample(dt)

		if _crack_time >= 0.0:
			var crack_env: float = _ramp(0.9, 0.0001, _crack_time / 0.35)
			var crack: float = _crack_highpass.process(randf() * 2.0 - 1.0)
			sample += crack * crack_env
			_crack_time += dt
			if _crack_time > 0.4:
				_crack_time = -1.0

		sample = clampf(sample * _gain_master, -1.0, 1.0)
		buffer[i] = Vector2(sample, sample)

	return buffer


## One sample of thunder: brown noise through a lowpass that sweeps down to 90 Hz, shaped by
## the prototype's four-stage gain envelope.
func _thunder_sample(dt: float) -> float:
	var n: float = _thunder_nearness
	var t: float = _thunder_time
	var total: float = 6.0 + n * 2.0
	if t > total:
		_thunder_time = -1.0
		return 0.0

	# Prototype: frequency ramps 1200 - 900n down to 90 Hz across five seconds.
	var start_hz: float = 1200.0 - n * 900.0
	var hz: float = _ramp(start_hz, 90.0, clampf(t / 5.0, 0.0, 1.0))
	_thunder_lowpass.set_lowpass(hz, MIX_RATE)

	var peak: float = 1.7 * (1.0 - n * 0.55)
	var attack: float = 0.05 + n * 0.5
	var envelope: float
	if t < attack:
		envelope = _ramp(0.0001, peak, t / attack)
	elif t < 1.2 + n:
		envelope = _ramp(peak, peak * 0.35, (t - attack) / maxf(1.2 + n - attack, 0.001))
	elif t < 1.6 + n:
		envelope = _ramp(peak * 0.35, peak * 0.6, (t - (1.2 + n)) / 0.4)
	else:
		envelope = _ramp(peak * 0.6, 0.0001, (t - (1.6 + n)) / maxf(total - (1.6 + n), 0.001))

	_brown_thunder = (_brown_thunder + 0.02 * (randf() * 2.0 - 1.0)) / 1.02
	var value: float = _thunder_lowpass.process(_brown_thunder * 3.5) * envelope
	_thunder_time += dt
	return value


## Web Audio's exponentialRampToValueAtTime, evaluated at normalised progress `t`.
static func _ramp(from: float, to: float, t: float) -> float:
	var clamped: float = clampf(t, 0.0, 1.0)
	var a: float = maxf(absf(from), 0.0001)
	var b: float = maxf(absf(to), 0.0001)
	return a * pow(b / a, clamped)


## A direct form 1 biquad, matching the Web Audio BiquadFilterNode shapes the prototype uses.
class Biquad:
	extends RefCounted

	var _b0: float = 1.0
	var _b1: float = 0.0
	var _b2: float = 0.0
	var _a1: float = 0.0
	var _a2: float = 0.0
	var _x1: float = 0.0
	var _x2: float = 0.0
	var _y1: float = 0.0
	var _y2: float = 0.0

	## Butterworth Q. The prototype leaves Q at the Web Audio default for its lowpass and
	## highpass stages; 1/sqrt(2) is the flat, non-resonant response that implies.
	const DEFAULT_Q: float = 0.70710678

	func set_lowpass(hz: float, rate: float) -> void:
		var w: float = TAU * clampf(hz, 10.0, rate * 0.49) / rate
		var alpha: float = sin(w) / (2.0 * DEFAULT_Q)
		var cw: float = cos(w)
		_normalise((1.0 - cw) * 0.5, 1.0 - cw, (1.0 - cw) * 0.5, 1.0 + alpha, -2.0 * cw, 1.0 - alpha)

	func set_highpass(hz: float, rate: float) -> void:
		var w: float = TAU * clampf(hz, 10.0, rate * 0.49) / rate
		var alpha: float = sin(w) / (2.0 * DEFAULT_Q)
		var cw: float = cos(w)
		_normalise((1.0 + cw) * 0.5, -(1.0 + cw), (1.0 + cw) * 0.5, 1.0 + alpha, -2.0 * cw, 1.0 - alpha)

	func set_bandpass(hz: float, q: float, rate: float) -> void:
		var w: float = TAU * clampf(hz, 10.0, rate * 0.49) / rate
		var alpha: float = sin(w) / (2.0 * q)
		var cw: float = cos(w)
		_normalise(alpha, 0.0, -alpha, 1.0 + alpha, -2.0 * cw, 1.0 - alpha)

	func process(x: float) -> float:
		var y: float = _b0 * x + _b1 * _x1 + _b2 * _x2 - _a1 * _y1 - _a2 * _y2
		_x2 = _x1
		_x1 = x
		_y2 = _y1
		_y1 = y
		return y

	func _normalise(b0: float, b1: float, b2: float, a0: float, a1: float, a2: float) -> void:
		_b0 = b0 / a0
		_b1 = b1 / a0
		_b2 = b2 / a0
		_a1 = a1 / a0
		_a2 = a2 / a0
