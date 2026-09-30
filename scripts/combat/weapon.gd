## A weapon a character can carry.
##
## Reach is the distance in metres at which a swing connects, measured between character
## origins, so a spear outranges a sword without either needing a hitbox. A heavy strike costs
## chi and is the only way to spend it.
class_name Weapon
extends RefCounted

var display_name: String = ""
## Japanese name, shown beside the English one.
var kanji: String = ""
var damage: float = 8.0
var reach: float = 2.0
## Seconds from the start of a swing until it can connect again.
var swing_time: float = 0.55
## Fraction of swing_time at which the blow actually lands.
var contact_at: float = 0.45
var chi_cost: float = 0.0
var heavy_multiplier: float = 2.2


static func make(
	display_name: String, kanji: String, damage: float, reach: float,
	swing_time: float, chi_cost: float
) -> Weapon:
	var w := Weapon.new()
	w.display_name = display_name
	w.kanji = kanji
	w.damage = damage
	w.reach = reach
	w.swing_time = swing_time
	w.chi_cost = chi_cost
	return w


## The pole the boatman already carries. Long, light, and what the player starts with.
static func bo() -> Weapon:
	return make("Bo staff", "棒", 11.0, 2.8, 0.55, 12.0)


static func katana() -> Weapon:
	return make("Katana", "刀", 15.0, 2.1, 0.45, 16.0)


static func naginata() -> Weapon:
	return make("Naginata", "薙刀", 19.0, 2.9, 0.7, 20.0)


static func yari() -> Weapon:
	return make("Yari", "槍", 12.0, 3.1, 0.6, 14.0)


static func tetsubo() -> Weapon:
	return make("Tetsubo", "鉄棒", 26.0, 2.2, 0.95, 24.0)
