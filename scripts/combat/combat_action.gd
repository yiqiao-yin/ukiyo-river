## One thing a character can do in a fight.
##
## Actions are data, and a character carries the list of the ones it knows. That is the whole
## point of the type: the boatman starts with two sweeps and a block, a trained swordsman has
## four techniques and a guard, and new actions - a weave, a feint, a disarm - are added by
## writing a constructor here and granting it, not by touching the combat loop.
##
## The gap between what the player knows and what is coming at him *is* the early game.
class_name CombatAction
extends RefCounted

enum Kind {
	ATTACK,  ## costs time, deals damage on contact
	GUARD,   ## held; soaks damage while up, and negates it outright if raised in time
	EVADE,   ## a single fast step out of the way. Reserved - see weave() below.
}

## Which pose curve drives it. See Samurai._pose() and Boatman.strike()/guard().
enum Shape {
	SWEEP,    ## flat, horizontal, both hands - the boatman's only idea
	KESA,     ## kesa-giri, the diagonal cut down from the shoulder
	DO,       ## do-giri, a horizontal swing at the waist
	KIRIAGE,  ## the rising cut, up from low on the other side
	TSUKI,    ## a straight thrust, for spears
	GUARD,    ## weapon up and across
	STEP,     ## a hard push off to one side
}

var kind: Kind = Kind.ATTACK
var shape: Shape = Shape.SWEEP
var display_name: String = ""
var kanji: String = ""
## Whole action, start to recovered.
var duration: float = 0.6
## Fraction of the duration at which an attack lands. Everything before it is the telegraph.
var contact: float = 0.5
var damage_scale: float = 1.0
var reach_scale: float = 1.0
## -1 to the character's left, +1 to the right, 0 for anything centred.
var side: float = 0.0
var chi_cost: float = 0.0


static func make(
	kind_value: Kind, shape_value: Shape, display_name: String, kanji: String,
	duration: float, contact: float, damage_scale: float, reach_scale: float = 1.0,
	side: float = 0.0
) -> CombatAction:
	var a := CombatAction.new()
	a.kind = kind_value
	a.shape = shape_value
	a.display_name = display_name
	a.kanji = kanji
	a.duration = duration
	a.contact = contact
	a.damage_scale = damage_scale
	a.reach_scale = reach_scale
	a.side = side
	return a


# ---------------------------------------------------------------- attacks

## The boatman's two. Slow, flat, and telegraphed - he is swinging a punt pole.
static func sweep_left() -> CombatAction:
	return make(Kind.ATTACK, Shape.SWEEP, "Sweep left", "左払い", 0.62, 0.52, 1.0, 1.0, -1.0)


static func sweep_right() -> CombatAction:
	return make(Kind.ATTACK, Shape.SWEEP, "Sweep right", "右払い", 0.62, 0.52, 1.0, 1.0, 1.0)


## What a swordsman has. Faster, shorter tells, and they vary.
static func kesa() -> CombatAction:
	return make(Kind.ATTACK, Shape.KESA, "Kesa cut", "袈裟斬り", 0.72, 0.58, 1.25)


static func do_giri() -> CombatAction:
	return make(Kind.ATTACK, Shape.DO, "Body swing", "胴斬り", 0.55, 0.46, 1.0, 1.12)


static func kiriage() -> CombatAction:
	return make(Kind.ATTACK, Shape.KIRIAGE, "Rising cut", "斬り上げ", 0.44, 0.40, 0.8, 0.95)


static func tsuki() -> CombatAction:
	return make(Kind.ATTACK, Shape.TSUKI, "Thrust", "突き", 0.5, 0.55, 1.1, 1.25)


# ---------------------------------------------------------------- defence

## Guard. Held rather than triggered, so it has no duration of its own.
##
## Everyone can in principle hold a weapon up, which is why this is the one action granted by
## default. Whether it is any good depends on the character: soaking a blow costs chi, and a
## guard held by someone with none left breaks.
static func block() -> CombatAction:
	return make(Kind.GUARD, Shape.GUARD, "Guard", "受け", 0.0, 0.0, 0.0)


## A weave: one hard step out of the line of the blow.
##
## Defined but granted to nobody yet. This is the next action to hand out, and the plan is for
## it to arrive when the player first gets ashore - on its own key, so guarding and evading are
## separate decisions rather than the same button.
static func weave(side_value: float) -> CombatAction:
	return make(
		Kind.EVADE, Shape.STEP,
		"Weave left" if side_value < 0.0 else "Weave right", "捌き",
		0.34, 0.0, 0.0, 1.0, side_value
	)


# ---------------------------------------------------------------- loadouts

## The attacks that come with a weapon.
static func attacks_for_weapon(weapon_name: String) -> Array[CombatAction]:
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
