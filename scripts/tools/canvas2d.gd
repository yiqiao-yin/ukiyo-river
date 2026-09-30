## A small software rasteriser over an Image.
##
## The prototype paints every texture with the browser's 2D canvas. Godot's Image has no drawing
## API at all, so the handful of canvas operations the prototype actually uses - filled rects,
## stroked lines and polylines, quadratic curves, rotated filled ellipses and gradients - are
## implemented here directly. Used only by scripts/tools/generate_textures.gd, which runs once
## and writes PNGs; nothing draws at runtime.
class_name Canvas2D
extends RefCounted

var image: Image
var width: int
var height: int


static func create(w: int, h: int, background: Color = Color(0, 0, 0, 0)) -> Canvas2D:
	var c := Canvas2D.new()
	c.width = w
	c.height = h
	c.image = Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	c.image.fill(background)
	return c


## Source-over alpha blend of one pixel, the canvas default.
func blend(x: int, y: int, color: Color) -> void:
	if x < 0 or y < 0 or x >= width or y >= height or color.a <= 0.0:
		return
	if color.a >= 1.0:
		image.set_pixel(x, y, color)
		return
	var dst: Color = image.get_pixel(x, y)
	var a: float = color.a + dst.a * (1.0 - color.a)
	if a <= 0.0:
		image.set_pixel(x, y, Color(0, 0, 0, 0))
		return
	image.set_pixel(x, y, Color(
		(color.r * color.a + dst.r * dst.a * (1.0 - color.a)) / a,
		(color.g * color.a + dst.g * dst.a * (1.0 - color.a)) / a,
		(color.b * color.a + dst.b * dst.a * (1.0 - color.a)) / a,
		a
	))


func fill_rect(x: float, y: float, w: float, h: float, color: Color) -> void:
	var x0: int = maxi(0, int(floor(x)))
	var y0: int = maxi(0, int(floor(y)))
	var x1: int = mini(width, int(ceil(x + w)))
	var y1: int = mini(height, int(ceil(y + h)))
	for py: int in range(y0, y1):
		for px: int in range(x0, x1):
			blend(px, py, color)


## A stroked segment of the given width, with a half-pixel soft edge so thin strokes do not
## disappear the way a hard coverage test makes them.
func line(a: Vector2, b: Vector2, line_width: float, color: Color) -> void:
	var radius: float = maxf(line_width, 0.6) * 0.5
	var min_x: int = maxi(0, int(floor(minf(a.x, b.x) - radius - 1.0)))
	var max_x: int = mini(width - 1, int(ceil(maxf(a.x, b.x) + radius + 1.0)))
	var min_y: int = maxi(0, int(floor(minf(a.y, b.y) - radius - 1.0)))
	var max_y: int = mini(height - 1, int(ceil(maxf(a.y, b.y) + radius + 1.0)))
	var ab: Vector2 = b - a
	var len_sq: float = ab.length_squared()
	for py: int in range(min_y, max_y + 1):
		for px: int in range(min_x, max_x + 1):
			var p := Vector2(float(px) + 0.5, float(py) + 0.5)
			var t: float = 0.0 if len_sq <= 0.0 else clampf((p - a).dot(ab) / len_sq, 0.0, 1.0)
			var distance: float = p.distance_to(a + ab * t)
			var coverage: float = clampf(radius + 0.5 - distance, 0.0, 1.0)
			if coverage > 0.0:
				blend(px, py, Color(color.r, color.g, color.b, color.a * coverage))


func polyline(points: PackedVector2Array, line_width: float, color: Color) -> void:
	for i: int in points.size() - 1:
		line(points[i], points[i + 1], line_width, color)


## A quadratic Bezier, sampled into a polyline - the canvas quadraticCurveTo.
func quadratic(a: Vector2, control: Vector2, b: Vector2, line_width: float, color: Color) -> void:
	var steps: int = maxi(4, int(a.distance_to(b) / 3.0))
	var points := PackedVector2Array()
	for i: int in steps + 1:
		var t: float = float(i) / float(steps)
		var inv: float = 1.0 - t
		points.push_back(a * (inv * inv) + control * (2.0 * inv * t) + b * (t * t))
	polyline(points, line_width, color)


## A filled ellipse, optionally rotated. `inner` and `outer` give the radial gradient the
## prototype uses for cherry petals; pass the same colour twice for a flat fill.
func ellipse(
	centre: Vector2, radii: Vector2, rotation: float, inner: Color, outer: Color = Color(0, 0, 0, -1)
) -> void:
	var flat: bool = outer.a < 0.0
	var extent: float = maxf(radii.x, radii.y) + 1.0
	var min_x: int = maxi(0, int(floor(centre.x - extent)))
	var max_x: int = mini(width - 1, int(ceil(centre.x + extent)))
	var min_y: int = maxi(0, int(floor(centre.y - extent)))
	var max_y: int = mini(height - 1, int(ceil(centre.y + extent)))
	var cs: float = cos(-rotation)
	var sn: float = sin(-rotation)
	var rx: float = maxf(radii.x, 0.001)
	var ry: float = maxf(radii.y, 0.001)
	for py: int in range(min_y, max_y + 1):
		for px: int in range(min_x, max_x + 1):
			var d := Vector2(float(px) + 0.5 - centre.x, float(py) + 0.5 - centre.y)
			var lx: float = (d.x * cs - d.y * sn) / rx
			var ly: float = (d.x * sn + d.y * cs) / ry
			var r: float = sqrt(lx * lx + ly * ly)
			if r > 1.05:
				continue
			var coverage: float = clampf((1.05 - r) / 0.1, 0.0, 1.0)
			var color: Color = inner if flat else inner.lerp(outer, clampf(r, 0.0, 1.0))
			blend(px, py, Color(color.r, color.g, color.b, color.a * coverage))


## A gradient-filled rect, along y when `vertical` and along x otherwise - canvas
## createLinearGradient followed by fillRect.
func gradient_rect(
	x: float, y: float, w: float, h: float, vertical: bool, stops: Array
) -> void:
	var x0: int = maxi(0, int(floor(x)))
	var y0: int = maxi(0, int(floor(y)))
	var x1: int = mini(width, int(ceil(x + w)))
	var y1: int = mini(height, int(ceil(y + h)))
	for py: int in range(y0, y1):
		for px: int in range(x0, x1):
			var t: float = (
				(float(py) + 0.5 - y) / maxf(h, 0.001) if vertical
				else (float(px) + 0.5 - x) / maxf(w, 0.001)
			)
			blend(px, py, _sample_stops(stops, clampf(t, 0.0, 1.0)))


## A vertical gradient across the whole canvas, from a list of (offset, colour) stops.
func vertical_gradient(stops: Array) -> void:
	for py: int in height:
		var t: float = float(py) / float(maxi(height - 1, 1))
		blend_row(py, _sample_stops(stops, t))


func blend_row(y: int, color: Color) -> void:
	for px: int in width:
		blend(px, y, color)


static func _sample_stops(stops: Array, t: float) -> Color:
	if stops.is_empty():
		return Color(0, 0, 0, 0)
	var previous: Array = stops[0]
	for stop: Array in stops:
		if t <= float(stop[0]):
			var span: float = float(stop[0]) - float(previous[0])
			if span <= 0.0:
				return stop[1]
			var k: float = (t - float(previous[0])) / span
			return (previous[1] as Color).lerp(stop[1] as Color, k)
		previous = stop
	return stops[stops.size() - 1][1]


## Saves as PNG. Colours are authored in sRGB, which is how albedo textures are read back.
func save(path: String) -> Error:
	return image.save_png(path)


## rgba(r, g, b, a) with the prototype's 0-255 components.
static func rgb(r: float, g: float, b: float, a: float = 1.0) -> Color:
	return Color(r / 255.0, g / 255.0, b / 255.0, a)
