## Shortcuts for trying the game out, so testing combat does not mean drifting for two minutes
## first.
##
## Deliberately separate from everything else and attached to one node, so removing it before
## release is deleting this script and its node - nothing else refers to it.
##
##   F1  send a wave now
##   F2  jump 120 m downstream, to where the river gets dangerous
##   F3  heal to full
##   F4  hand over every weapon, to try them out
class_name DebugKeys
extends Node

@export var boat: Boat
@export var player: PlayerCharacter
@export var director: EncounterDirector

## Turn this off and the keys do nothing.
@export var enabled: bool = true


func _unhandled_input(event: InputEvent) -> void:
	if not enabled or not (event is InputEventKey) or not event.is_pressed() or event.is_echo():
		return
	match (event as InputEventKey).keycode:
		KEY_F1:
			_send_wave()
		KEY_F2:
			_jump_downstream()
		KEY_F3:
			_heal()
		KEY_F4:
			_give_weapons()


func _send_wave() -> void:
	if director == null:
		return
	director._send_wave()
	_say("wave sent")


## Encounters start at z = -150, so this is how you reach them without the wait.
func _jump_downstream() -> void:
	if boat == null:
		return
	boat.boat_z = minf(boat.boat_z + 120.0, Boat.Z_LIMIT - 10.0)
	boat.boat_x = UkiyoMath.river_x(boat.boat_z)
	_say("jumped to z = %.0f" % boat.boat_z)


func _heal() -> void:
	if player == null:
		return
	player.stats.health = player.stats.max_health
	player.stats.chi = player.stats.max_chi
	player.stats_changed.emit()
	_say("healed")


func _give_weapons() -> void:
	if player == null:
		return
	for weapon: Weapon in [Weapon.katana(), Weapon.naginata(), Weapon.yari(), Weapon.tetsubo()]:
		player.stats.pick_up(weapon)
	_say("all weapons - press Q to cycle")


func _say(text: String) -> void:
	print("[debug] ", text)
	if player != null:
		player.notice.emit("debug: " + text)
