## One attack: how long it takes, when it lands, and what it is worth.
##
## The point of having these at all is the gap between the two sides. The boatman knows two
## things - sweep the staff left, sweep it right - and that is his whole repertoire. A trained
## swordsman at the same level has four techniques with different timings, reaches and arcs, so
## even a level 1 ashigaru is harder to read than the player is.
class_name CombatMove
extends RefCounted

## Which pose curve drives it. See Samurai._pose() and Boatman.strike().
enum Shape {
	SWEEP,    ## flat, horizontal, both hands - the boatman's only idea
	KESA,     ## kesa-giri, the diagonal cut down from the shoulder
	DO,       ## do-giri, a horizontal swing at the waist
	KIRIAGE,  ## the rising cut, up from low on the other side
	TSUKI,    ## a straight thrust, for spears
}

var shape: Shape = Shape.SWEEP
var display_name: String = ""
var kanji: String = ""
## Whole move, start to recovered.
var duration: float = 0.6
## Fraction of the duration at which the blow lands. Everything before it is the telegraph.
var contact: float = 0.5
var damage_scale: float = 1.0
var reach_scale: float = 1.0
## -1 sweeps to the player's left, +1 to the right, 0 for anything centred.
var side: float = 0.0


static func make(
	shape_value: Shape, display_name: String, kanji: String,
	duration: float, contact: float, damage_scale: float, reach_scale: float = 1.0,
	side: float = 0.0
) -> CombatMove:
	var m := CombatMove.new()
	m.shape = shape_value
	m.display_name = display_name
	m.kanji = kanji
	m.duration = duration
	m.contact = contact
	m.damage_scale = damage_scale
	m.reach_scale = reach_scale
	m.side = side
	return m


## The boatman's two. Slow, flat, and telegraphed - he is swinging a punt pole.
static func sweep_left() -> CombatMove:
	return make(Shape.SWEEP, "Sweep left", "左払い", 0.62, 0.52, 1.0, 1.0, -1.0)


static func sweep_right() -> CombatMove:
	return make(Shape.SWEEP, "Sweep right", "右払い", 0.62, 0.52, 1.0, 1.0, 1.0)


## What a swordsman has. Faster, shorter tells, and they vary.
static func kesa() -> CombatMove:
	return make(Shape.KESA, "Kesa cut", "袈裟斬り", 0.72, 0.58, 1.25, 1.0)


static func do_giri() -> CombatMove:
	return make(Shape.DO, "Body swing", "胴斬り", 0.55, 0.46, 1.0, 1.12)


static func kiriage() -> CombatMove:
	return make(Shape.KIRIAGE, "Rising cut", "斬り上げ", 0.44, 0.40, 0.8, 0.95)


static func tsuki() -> CombatMove:
	return make(Shape.TSUKI, "Thrust", "突き", 0.5, 0.55, 1.1, 1.25)


## The repertoire that comes with a weapon.
static func for_weapon(weapon_name: String) -> Array[CombatMove]:
	match weapon_name:
		"Katana":
			return [kesa(), do_giri(), kiriage()]
		"Naginata":
			return [do_giri(), kesa(), tsuki()]
		"Yari":
			return [tsuki(), do_giri()]
		"Tetsubo":
			return [kesa(), do_giri()]
		_:
			return [sweep_left(), sweep_right()]
