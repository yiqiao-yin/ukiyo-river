## Generates the prototype's painted textures once and writes them to assets/generated/.
##
## Prototype: reference/ukiyo-river.html paints these onto canvases at every page load. A game
## should not, so each draw function is ported against Canvas2D and the results are saved as
## PNGs that the project loads normally.
##
## Run from WSL with
##   godot --headless --path 'C:\Dev\ukiyo-river' --script res://scripts/tools/generate_textures.gd
##
## Each texture keeps the prototype's mulberry32 seed, so the grain and the scatter come out of
## the same random sequence. The rasteriser is not the browser's, so these are not pixel
## identical - the structure is.
extends SceneTree

const OUTPUT_DIR: String = "res://assets/generated"


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))

	_save(_bark("sugi", true), "bark_sugi.png")
	_save(_bark("sugi", false), "bark_sugi_bump.png")
	_save(_bark("pine", true), "bark_pine.png")
	_save(_bark("pine", false), "bark_pine_bump.png")
	_save(_bark("sakura", true), "bark_sakura.png")
	_save(_bark("sakura", false), "bark_sakura_bump.png")
	_save(_sugi_spray(), "foliage_cedar.png")
	_save(_pine_cluster(), "foliage_pine.png")
	_save(_blossom(), "foliage_blossom.png")

	print("[textures] done")
	quit()


func _save(canvas: Canvas2D, name: String) -> void:
	var path: String = OUTPUT_DIR.path_join(name)
	var error: Error = canvas.save(path)
	if error != OK:
		push_error("[textures] could not write %s (error %d)" % [path, error])
	else:
		print("[textures] wrote ", name)


## barkDraw(kind, color) - three very different barks, plus the greyscale bump variant.
func _bark(kind: String, coloured: bool) -> Canvas2D:
	var seed_value: int = 41 if kind == "sugi" else (43 if kind == "pine" else 47)
	var r := UkiyoRng.new(seed_value)
	var w: int = 256
	var h: int = 512
	var c: Canvas2D = Canvas2D.create(w, h, Color(0, 0, 0, 1))

	if kind == "sugi":
		# Long stringy fibres running the length of the trunk.
		c.image.fill(Canvas2D.rgb(86, 55, 40) if coloured else Canvas2D.rgb(120, 120, 120))
		for _i: int in 300:
			var x: float = r.next() * float(w)
			var lw: float = 1.0 + r.next() * 5.0
			var dark: bool = r.next() < 0.45
			var j1: float = r.next()
			var j2: float = r.next()
			var ph: float = r.next() * 6.0
			var col: Color
			if coloured:
				col = (
					Canvas2D.rgb(36, 22, 16, 0.8) if dark
					else Canvas2D.rgb(128.0 + j1 * 34.0, 86.0 + j2 * 22.0, 62, 0.55)
				)
			else:
				col = Canvas2D.rgb(35, 35, 35, 0.9) if dark else Canvas2D.rgb(205, 205, 205, 0.6)
			var points := PackedVector2Array()
			var y: float = 0.0
			while y <= float(h):
				points.push_back(Vector2(x + sin(y * 0.02 + ph) * 4.0, y))
				y += 24.0
			c.polyline(points, lw, col)
	elif kind == "pine":
		# Interlocking plates.
		c.image.fill(Canvas2D.rgb(30, 27, 25) if coloured else Canvas2D.rgb(15, 15, 15))
		var y: float = 0.0
		while y < float(h):
			var ph: float = 16.0 + r.next() * 28.0
			var x: float = -r.next() * 30.0
			while x < float(w):
				var pw: float = 14.0 + r.next() * 24.0
				var tone: float = 0.7 + r.next() * 0.5
				var a: float = r.next() * 3.0
				var b: float = r.next() * 3.0
				var cc: float = r.next() * 3.0
				var d: float = r.next() * 3.0
				var col: Color = (
					Canvas2D.rgb(84.0 * tone, 74.0 * tone, 64.0 * tone) if coloured
					else Canvas2D.rgb(170.0 * tone, 170.0 * tone, 170.0 * tone)
				)
				_quad(c, [
					Vector2(x + 2.0 + a, y + 2.0), Vector2(x + pw - 2.0, y + 1.0 + b),
					Vector2(x + pw - 1.0 - cc, y + ph - 2.0), Vector2(x + 1.0, y + ph - 1.0 - d),
				], col)
				x += pw
			y += ph
	else:
		# Cherry: horizontal lenticel bands over a smooth trunk.
		c.image.fill(Canvas2D.rgb(72, 54, 52) if coloured else Canvas2D.rgb(130, 130, 130))
		for _i: int in 60:
			var y: float = r.next() * float(h)
			var hh: float = 2.0 + r.next() * 6.0
			var a: float = 0.1 + r.next() * 0.25
			c.fill_rect(0.0, y, float(w), hh,
				Canvas2D.rgb(36, 26, 24, a) if coloured else Canvas2D.rgb(60, 60, 60, a))
		for _i: int in 520:
			var x: float = r.next() * float(w)
			var y2: float = r.next() * float(h)
			var l: float = 4.0 + r.next() * 10.0
			c.fill_rect(x, y2, l, 1.6,
				Canvas2D.rgb(150, 128, 116, 0.55) if coloured else Canvas2D.rgb(210, 210, 210, 0.8))

	# Moss, on every kind.
	for _i: int in 26:
		var x: float = r.next() * float(w)
		var y: float = r.next() * float(h)
		var s: float = 5.0 + r.next() * 18.0
		c.ellipse(Vector2(x, y), Vector2(s, s * 1.8), 0.0,
			Canvas2D.rgb(92, 104, 78, 0.28) if coloured else Canvas2D.rgb(150, 150, 150, 0.3))
	return c


## sugiSprayDraw - one cedar frond: a stem with needle pairs fanning off it.
func _sugi_spray() -> Canvas2D:
	var r := UkiyoRng.new(51)
	var w: int = 256
	var h: int = 256
	var c: Canvas2D = Canvas2D.create(w, h)

	var stem := func(t: float) -> Vector2:
		return Vector2(
			6.0 + t * (float(w) - 14.0),
			float(h) * 0.5 + sin(t * 2.2) * float(h) * 0.05 + t * t * float(h) * 0.07
		)

	var spine := PackedVector2Array()
	var t: float = 0.0
	while t <= 1.0:
		spine.push_back(stem.call(t))
		t += 0.05
	c.polyline(spine, 3.0, Canvas2D.rgb(70, 50, 34))

	for i: int in 40:
		var ti: float = 0.04 + float(i) / 40.0 * 0.92
		var s: Vector2 = stem.call(ti)
		var env: float = sin(PI * minf(1.0, ti * 1.1)) * (1.0 - ti * 0.3)
		var length: float = float(h) * 0.46 * env * (0.75 + r.next() * 0.4)
		var side: float = 1.0 if i % 2 == 1 else -1.0
		var a: float = side * (0.8 + r.next() * 0.4)
		var dx: float = cos(a)
		var dy: float = sin(a)
		var steps: int = maxi(3, int(length / 2.4))
		for k: int in steps:
			var f: float = float(k) / float(steps)
			var p := Vector2(s.x + dx * length * f * 0.6, s.y + dy * length * f)
			for sd: float in [-1.0, 1.0]:
				var na: float = atan2(dy, dx * 0.6) + sd * 0.9
				var nl: float = 5.0 + r.next() * 5.0 * (1.0 - f * 0.5)
				var tone: float = 0.7 + r.next() * 0.5
				var col: Color = (
					Canvas2D.rgb(78.0 * tone, 108.0 * tone, 64.0 * tone) if f > 0.8
					else Canvas2D.rgb(30.0 * tone, 58.0 * tone, 36.0 * tone)
				)
				c.line(p, p + Vector2(cos(na), sin(na)) * nl, 2.2, col)
	return c


## pineDraw - ten tufts of needles radiating from a point.
func _pine_cluster() -> Canvas2D:
	var r := UkiyoRng.new(53)
	var w: int = 256
	var h: int = 256
	var c: Canvas2D = Canvas2D.create(w, h)
	for _t: int in 10:
		var cx: float = float(w) * (0.2 + r.next() * 0.6)
		var cy: float = float(h) * (0.22 + r.next() * 0.56)
		var radius: float = float(w) * (0.15 + r.next() * 0.12)
		for _k: int in 170:
			var a: float = r.next() * TAU
			var l: float = radius * (0.45 + r.next() * 0.55)
			var tone: float = 0.65 + r.next() * 0.55
			c.line(
				Vector2(cx, cy), Vector2(cx + cos(a) * l, cy + sin(a) * l * 0.85),
				1.5 + r.next() * 0.9,
				Canvas2D.rgb(36.0 * tone, 68.0 * tone, 42.0 * tone, 0.95)
			)
		c.ellipse(Vector2(cx, cy), Vector2(3, 3), 0.0, Canvas2D.rgb(40, 32, 22))
	return c


## blossomDraw - a cherry spray: twigs, leaves, and 95 five-petalled flowers.
func _blossom() -> Canvas2D:
	var r := UkiyoRng.new(57)
	var w: int = 256
	var h: int = 256
	var c: Canvas2D = Canvas2D.create(w, h)

	for _k: int in 5:
		c.line(
			Vector2(float(w) * 0.5, float(h) * 0.5),
			Vector2(float(w) * (0.1 + r.next() * 0.8), float(h) * (0.1 + r.next() * 0.8)),
			2.0, Canvas2D.rgb(58, 40, 36)
		)
	for _i: int in 14:
		var x: float = float(w) * (0.2 + r.next() * 0.6)
		var y: float = float(h) * (0.2 + r.next() * 0.6)
		var s: float = 7.0 + r.next() * 5.0
		c.ellipse(Vector2(x, y), Vector2(s, s * 0.45), r.next() * TAU, Canvas2D.rgb(110, 92, 50))

	for _i: int in 95:
		var a: float = r.next() * TAU
		var d: float = sqrt(r.next()) * float(w) * 0.42
		var x: float = float(w) * 0.5 + cos(a) * d
		var y: float = float(h) * 0.5 + sin(a) * d * 0.9
		var s: float = 6.0 + r.next() * 5.0
		var rot: float = r.next() * TAU
		var tone: float = 0.88 + r.next() * 0.12
		for p: int in 5:
			var pa: float = rot + float(p) * 1.2566
			c.ellipse(
				Vector2(x + cos(pa) * s * 0.55, y + sin(pa) * s * 0.55),
				Vector2(s * 0.6, s * 0.42), pa,
				Canvas2D.rgb(228.0 * tone, 146.0 * tone, 168.0 * tone),
				Canvas2D.rgb(252.0 * tone, 228.0 * tone, 234.0 * tone)
			)
		c.ellipse(Vector2(x, y), Vector2(s * 0.22, s * 0.22), 0.0, Canvas2D.rgb(186, 66, 92))
		for _q: int in 5:
			var qa: float = r.next() * TAU
			c.fill_rect(
				x + cos(qa) * s * 0.3, y + sin(qa) * s * 0.3, 1.6, 1.6,
				Canvas2D.rgb(245, 214, 120)
			)
	return c


## Fills a convex quad by scanning its bounding box - the prototype's plate polygons.
func _quad(c: Canvas2D, points: Array, color: Color) -> void:
	var min_x: float = INF
	var max_x: float = -INF
	var min_y: float = INF
	var max_y: float = -INF
	for p: Vector2 in points:
		min_x = minf(min_x, p.x)
		max_x = maxf(max_x, p.x)
		min_y = minf(min_y, p.y)
		max_y = maxf(max_y, p.y)
	for py: int in range(maxi(0, int(min_y)), mini(c.height, int(max_y) + 1)):
		for px: int in range(maxi(0, int(min_x)), mini(c.width, int(max_x) + 1)):
			var p := Vector2(float(px) + 0.5, float(py) + 0.5)
			var inside: bool = true
			for i: int in points.size():
				var a: Vector2 = points[i]
				var b: Vector2 = points[(i + 1) % points.size()]
				if (b - a).cross(p - a) < 0.0:
					inside = false
					break
			if inside:
				c.blend(px, py, color)
