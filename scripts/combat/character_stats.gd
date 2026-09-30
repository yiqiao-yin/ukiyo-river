## Level, health, chi and carried weapons - shared by the player and every enemy.
##
## Chi (気) is the force pool. It refills on its own and is spent on heavy strikes, so a fight
## is a choice between chipping away safely and spending chi for a blow that ends it sooner.
class_name CharacterStats
extends RefCounted

## What one level is worth.
const HEALTH_PER_LEVEL: float = 11.0
const CHI_PER_LEVEL: float = 8.0
## Damage dealt is scaled by this much per level above the first.
const DAMAGE_PER_LEVEL: float = 0.09

var level: int = 1
var experience: int = 0

var max_health: float = 100.0
var health: float = 100.0
var max_chi: float = 50.0
var chi: float = 50.0
## Chi regained per second.
var chi_regen: float = 5.0

var inventory: Array[Weapon] = []
var equipped_index: int = 0

signal died
signal levelled_up(new_level: int)
signal damaged(amount: float)


static func make(level_value: int, base_health: float, base_chi: float, weapons: Array[Weapon]) -> CharacterStats:
	var s := CharacterStats.new()
	s.level = maxi(1, level_value)
	s.max_health = base_health + float(s.level - 1) * HEALTH_PER_LEVEL
	s.health = s.max_health
	s.max_chi = base_chi + float(s.level - 1) * CHI_PER_LEVEL
	s.chi = s.max_chi
	s.inventory = weapons
	return s


func weapon() -> Weapon:
	if inventory.is_empty():
		return Weapon.bo()
	return inventory[clampi(equipped_index, 0, inventory.size() - 1)]


func is_alive() -> bool:
	return health > 0.0


## Cycles to the next weapon carried, and returns it.
func next_weapon() -> Weapon:
	if inventory.size() > 1:
		equipped_index = (equipped_index + 1) % inventory.size()
	return weapon()


func pick_up(new_weapon: Weapon) -> bool:
	for held: Weapon in inventory:
		if held.display_name == new_weapon.display_name:
			return false
	inventory.append(new_weapon)
	return true


## Damage this character deals with a swing, before the target's level is considered.
func attack_damage(heavy: bool) -> float:
	var base: float = weapon().damage * (1.0 + float(level - 1) * DAMAGE_PER_LEVEL)
	return base * (weapon().heavy_multiplier if heavy else 1.0)


## True if there was enough chi and it was spent.
func spend_chi(amount: float) -> bool:
	if chi < amount:
		return false
	chi -= amount
	return true


func take_damage(amount: float) -> void:
	if not is_alive():
		return
	health = maxf(0.0, health - amount)
	damaged.emit(amount)
	if health <= 0.0:
		died.emit()


func heal(amount: float) -> void:
	health = minf(max_health, health + amount)


func regenerate(delta: float) -> void:
	chi = minf(max_chi, chi + chi_regen * delta)


## Experience needed to reach the next level.
func next_level_at() -> int:
	return level * 100


func grant_experience(amount: int) -> void:
	experience += amount
	while experience >= next_level_at():
		experience -= next_level_at()
		level += 1
		max_health += HEALTH_PER_LEVEL
		health = max_health
		max_chi += CHI_PER_LEVEL
		chi = max_chi
		levelled_up.emit(level)
