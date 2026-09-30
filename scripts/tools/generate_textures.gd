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

	# Boat and boatman.
	_save(_planks(true, 8, Vector3(104, 74, 50), 11, 1024, 512), "hull.png")
	_save(_planks(false, 8, Vector3(104, 74, 50), 11, 1024, 512), "hull_bump.png")
	_save(_planks(true, 8, Vector3(128, 98, 70), 17, 1024, 512), "deck.png")
	_save(_planks(false, 8, Vector3(128, 98, 70), 17, 1024, 512), "deck_bump.png")
	_save(_weave(true), "weave.png")
	_save(_weave(false), "weave_bump.png")
	_save(_fiber(true), "fiber.png")
	_save(_fiber(false), "fiber_bump.png")
	_save(_strands(), "strands.png")
	_save(_fabric(Vector3(30, 40, 66), true, 21, 512), "kimono.png")
	_save(_fabric(Vector3(36, 36, 42), false, 23, 256), "pants.png")
	_save(_fabric(Vector3(150, 156, 164), false, 25, 256), "gaiter.png")
	_save(_fabric(Vector3(86, 58, 40), false, 27, 256), "obi.png")
	_save(_bamboo(), "bamboo.png")
	_save(_lantern(), "lantern.png")
	_save(_petal(), "petal.png")

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


## planksDraw(color, rows, base, seed) - sawn boards with grain, knots, nails and staining.
func _planks(coloured: bool, rows: int, base: Vector3, seed_value: int, w: int, h: int) -> Canvas2D:
	var r := UkiyoRng.new(seed_value)
	var c: Canvas2D = Canvas2D.create(w, h, Color(0, 0, 0, 1))
	var rh: float = float(h) / float(rows)

	for i: int in rows:
		var y0: float = float(i) * rh
		var sh: float = 0.78 + r.next() * 0.35
		c.fill_rect(0.0, y0, float(w), rh,
			Canvas2D.rgb(base.x * sh, base.y * sh, base.z * sh) if coloured
			else Canvas2D.rgb(160, 160, 160))

		# Grain: long wavy strokes running the length of the board.
		for _k: int in 30:
			var yy: float = y0 + r.next() * rh
			var amp: float = 0.5 + r.next() * 2.5
			var f: float = 0.004 + r.next() * 0.02
			var ph: float = r.next() * 6.28
			var a: float = 0.04 + r.next() * 0.16
			var lw: float = 0.4 + r.next() * 1.4
			var points := PackedVector2Array()
			var x: float = 0.0
			while x <= float(w):
				points.push_back(Vector2(x, yy + sin(x * f + ph) * amp))
				x += 8.0
			c.polyline(points, lw,
				Canvas2D.rgb(25, 14, 8, a) if coloured else Canvas2D.rgb(100, 100, 100, a * 1.6))

		var knot: bool = r.next() < 0.5
		var kx: float = r.next() * float(w)
		var ky: float = y0 + rh * (0.3 + r.next() * 0.4)
		var kr: float = 3.0 + r.next() * 6.0
		if knot:
			c.ellipse(Vector2(kx, ky), Vector2(kr * 2.2, kr), 0.0,
				Canvas2D.rgb(40, 24, 14, 0.7) if coloured else Canvas2D.rgb(90, 90, 90))

		# Board edge, one butt joint, and a row of nail heads.
		var seam: Color = Canvas2D.rgb(12, 8, 5, 0.9) if coloured else Canvas2D.rgb(15, 15, 15)
		c.fill_rect(0.0, y0, float(w), 3.0, seam)
		c.fill_rect(r.next() * float(w), y0, 3.0, rh, seam)
		for _p: int in 8:
			c.ellipse(Vector2(r.next() * float(w), y0 + 7.0), Vector2(2, 2), 0.0,
				Canvas2D.rgb(28, 18, 10, 0.85) if coloured else Canvas2D.rgb(50, 50, 50))

	# Weathering.
	for _i: int in 260:
		var x: float = r.next() * float(w)
		var y: float = r.next() * float(h)
		var s: float = 6.0 + r.next() * 40.0
		var a: float = r.next() * 0.07
		var light: bool = r.next() < 0.4
		var col: Color
		if coloured:
			col = Canvas2D.rgb(150, 140, 120, a) if light else Canvas2D.rgb(8, 6, 4, a)
		else:
			var v: float = 170.0 if light else 90.0
			col = Canvas2D.rgb(v, v, v, a)
		c.ellipse(Vector2(x, y), Vector2(s * 2.5, s * 0.4), 0.0, col)
	return c


## weaveDraw - the canopy matting: alternating cells of four woven strands.
func _weave(coloured: bool) -> Canvas2D:
	var r := UkiyoRng.new(5)
	var size: int = 512
	var cell: int = 32
	var c: Canvas2D = Canvas2D.create(size, size,
		Canvas2D.rgb(52, 45, 32) if coloured else Canvas2D.rgb(40, 40, 40))

	for cy: int in size / cell:
		for cx: int in size / cell:
			var horizontal: bool = (cx + cy) % 2 == 0
			for s: int in 4:
				var tone: float = 0.72 + r.next() * 0.4
				var o: float = float(s) * 8.0 + 1.0
				var base := Vector3(138.0 * tone, 122.0 * tone, 88.0 * tone)
				var stops: Array
				if coloured:
					stops = [
						[0.0, Canvas2D.rgb(base.x * 0.5, base.y * 0.5, base.z * 0.5)],
						[0.5, Canvas2D.rgb(base.x, base.y, base.z)],
						[1.0, Canvas2D.rgb(base.x * 0.45, base.y * 0.45, base.z * 0.45)],
					]
				else:
					stops = [
						[0.0, Canvas2D.rgb(70, 70, 70)],
						[0.5, Canvas2D.rgb(220, 220, 220)],
						[1.0, Canvas2D.rgb(70, 70, 70)],
					]
				if horizontal:
					c.gradient_rect(float(cx * cell), float(cy * cell) + o, float(cell), 6.0, true, stops)
				else:
					c.gradient_rect(float(cx * cell) + o, float(cy * cell), 6.0, float(cell), false, stops)

	for _i: int in 140:
		c.ellipse(
			Vector2(r.next() * float(size), r.next() * float(size)),
			Vector2(10.0 + r.next() * 50.0, 5.0 + r.next() * 30.0), r.next() * 3.0,
			Canvas2D.rgb(20, 22, 18, r.next() * 0.12) if coloured else Canvas2D.rgb(128, 128, 128, 0.0)
		)
	return c


## fiberDraw - straw matting for the hat and sandals: leaning fibres bound at intervals.
func _fiber(coloured: bool) -> Canvas2D:
	var r := UkiyoRng.new(9)
	var size: int = 512
	var c: Canvas2D = Canvas2D.create(size, size,
		Canvas2D.rgb(112, 92, 58) if coloured else Canvas2D.rgb(110, 110, 110))
	for _i: int in int(float(size) * 1.8):
		var x: float = r.next() * float(size)
		var t: float = 0.65 + r.next() * 0.55
		var lw: float = 0.6 + r.next() * 1.8
		var dx: float = (r.next() - 0.5) * 6.0
		c.line(Vector2(x, 0.0), Vector2(x + dx, float(size)), lw,
			Canvas2D.rgb(168.0 * t, 140.0 * t, 92.0 * t, 0.85) if coloured
			else Canvas2D.rgb(210.0 * t, 210.0 * t, 210.0 * t, 0.85))
	for k: int in range(1, 7):
		var y: float = float(size) * float(k) / 7.0
		c.fill_rect(0.0, y - 2.0, float(size), 4.0,
			Canvas2D.rgb(58, 42, 26, 0.9) if coloured else Canvas2D.rgb(30, 30, 30))
	return c


## strandsDraw - the straw cape, alpha cut so the individual strands read as separate.
func _strands() -> Canvas2D:
	var r := UkiyoRng.new(13)
	var size: int = 512
	var c: Canvas2D = Canvas2D.create(size, size)
	for _i: int in 1100:
		var x: float = r.next() * float(size)
		var length: float = float(size) * (0.62 + r.next() * 0.38)
		var t: float = 0.5 + r.next() * 0.55
		var lw: float = 1.0 + r.next() * 2.4
		var sway: float = (r.next() - 0.5) * 16.0
		c.quadratic(
			Vector2(x, 0.0), Vector2(x + sway * 0.4, length * 0.5), Vector2(x + sway, length),
			lw, Canvas2D.rgb(118.0 * t, 100.0 * t, 68.0 * t)
		)
	return c


## fabricDraw(base, marks, seed) - woven cloth. `marks` adds the kimono's stitched motifs.
func _fabric(base: Vector3, marks: bool, seed_value: int, size: int) -> Canvas2D:
	var r := UkiyoRng.new(seed_value)
	var c: Canvas2D = Canvas2D.create(size, size, Canvas2D.rgb(base.x, base.y, base.z))
	var y: float = 0.0
	while y < float(size):
		c.fill_rect(0.0, y, float(size), 1.0, Canvas2D.rgb(0, 0, 0, 0.05 + r.next() * 0.06))
		y += 2.0
	var x: float = 0.0
	while x < float(size):
		c.fill_rect(x, 0.0, 1.0, float(size), Canvas2D.rgb(255, 255, 255, 0.015 + r.next() * 0.03))
		x += 2.0
	if marks:
		for _i: int in 90:
			var mx: float = r.next() * float(size)
			var my: float = r.next() * float(size)
			var col: Color = Canvas2D.rgb(190, 198, 212, 0.5)
			for k: int in 3:
				c.fill_rect(mx + float(k) * 5.0 + r.next() * 2.0, my + (r.next() - 0.5) * 2.0, 3.0, 1.5, col)
			c.fill_rect(mx + 5.0, my - 6.0, 1.5, 3.0, col)
			c.fill_rect(mx + 5.0, my + 5.0, 1.5, 3.0, col)
	for _i: int in 70:
		c.ellipse(
			Vector2(r.next() * float(size), r.next() * float(size)),
			Vector2(3.0 + r.next() * 14.0, 30.0 + r.next() * 70.0), (r.next() - 0.5) * 0.3,
			Canvas2D.rgb(0, 0, 0, r.next() * 0.1)
		)
	return c


## bambooDraw - a culm with its node band, tiled up the pole.
func _bamboo() -> Canvas2D:
	var r := UkiyoRng.new(31)
	var w: int = 64
	var h: int = 256
	var c: Canvas2D = Canvas2D.create(w, h, Canvas2D.rgb(128, 116, 66))
	for _i: int in 70:
		c.fill_rect(r.next() * float(w), 0.0, 1.0 + r.next() * 2.0, float(h),
			Canvas2D.rgb(60, 52, 28, 0.08 + r.next() * 0.18))
	for _i: int in 20:
		c.fill_rect(0.0, r.next() * float(h), float(w), 2.0 + r.next() * 20.0,
			Canvas2D.rgb(40, 34, 20, r.next() * 0.15))
	c.fill_rect(0.0, float(h) * 0.5 - 4.0, float(w), 8.0, Canvas2D.rgb(52, 44, 22, 0.95))
	c.fill_rect(0.0, float(h) * 0.5 + 4.0, float(w), 3.0, Canvas2D.rgb(190, 178, 118, 0.55))
	return c


## lanternDraw - the paper shade: warm paper, red ends, bamboo ribs and two 川 characters.
func _lantern() -> Canvas2D:
	var w: int = 512
	var h: int = 256
	var c: Canvas2D = Canvas2D.create(w, h, Canvas2D.rgb(255, 216, 152))
	c.vertical_gradient([
		[0.0, Canvas2D.rgb(190, 70, 30, 0.75)],
		[0.16, Canvas2D.rgb(190, 70, 30, 0.0)],
		[0.84, Canvas2D.rgb(190, 70, 30, 0.0)],
		[1.0, Canvas2D.rgb(190, 70, 30, 0.75)],
	])
	for i: int in range(1, 16):
		c.fill_rect(0.0, float(h) * float(i) / 16.0 - 1.0, float(w), 2.0,
			Canvas2D.rgb(150, 86, 40, 0.35))
	for cx: float in [float(w) * 0.25, float(w) * 0.75]:
		_kawa(c, cx, float(h) * 0.53, float(h) * 0.46)
	return c


## The character 川 - three strokes, drawn rather than set, so no font has to ship. The left
## stroke hooks away at the foot, the middle one is short, the right one runs the full height.
func _kawa(c: Canvas2D, cx: float, cy: float, size: float) -> void:
	var ink: Color = Canvas2D.rgb(40, 18, 10, 0.92)
	var half: float = size * 0.5
	var stroke: float = size * 0.1
	c.quadratic(
		Vector2(cx - size * 0.34, cy - half * 0.86),
		Vector2(cx - size * 0.36, cy + half * 0.2),
		Vector2(cx - size * 0.46, cy + half * 0.82),
		stroke, ink
	)
	c.line(
		Vector2(cx, cy - half * 0.62), Vector2(cx, cy + half * 0.28), stroke, ink
	)
	c.line(
		Vector2(cx + size * 0.34, cy - half * 0.92), Vector2(cx + size * 0.34, cy + half * 0.9),
		stroke, ink
	)


## A single cherry petal, alpha cut out of the quad.
##
## Not from the prototype: its petals are untextured THREE.Points, which render as hard squares.
## Faithful, but they read as placeholder confetti against the sky, so they get a shape here.
## Rounded at the tip with the notch a cherry petal has, and paler toward the edge.
func _petal() -> Canvas2D:
	var size: int = 64
	var c: Canvas2D = Canvas2D.create(size, size)
	var half: float = float(size) * 0.5
	for py: int in size:
		for px: int in size:
			# Normalised to [-1, 1], slightly taller than wide.
			var u: float = (float(px) + 0.5 - half) / (half * 0.78)
			var v: float = (float(py) + 0.5 - half) / half
			var r: float = sqrt(u * u + v * v)
			# The notch: a bite taken out of the wide end.
			var notch: float = sqrt(u * u / 0.36 + (v - 1.15) * (v - 1.15) / 0.16)
			var alpha: float = smoothstep(1.0, 0.82, r) * smoothstep(0.85, 1.05, notch)
			if alpha <= 0.002:
				continue
			# Deeper pink at the base, almost white at the tip.
			var tone: float = clampf((v + 1.0) * 0.5, 0.0, 1.0)
			var colour: Color = Canvas2D.rgb(252, 232, 238).lerp(Canvas2D.rgb(232, 150, 172), tone)
			colour.a = alpha
			c.blend(px, py, colour)
	return c
