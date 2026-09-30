## Holds the one random stream the world is laid out from.
##
## The prototype has a single `rng = mulberry32(20260923)` that the village houses, the floating
## lanterns and the tree scatter all draw from, in that order. The sequence is the world: draw
## one extra number anywhere and every village, lantern and tree downstream of it moves.
##
## In a node tree that order is decided by _ready order, which is tree order, so the consumers
## must stay in this sequence under Main:
##   Architecture  ->  FloatingLanterns  ->  Trees
class_name WorldRng
extends Node

var rng: UkiyoRng


func _init() -> void:
	# Built in _init rather than _ready so it exists before any consumer's _ready runs.
	rng = UkiyoRng.new(UkiyoRng.WORLD_SEED)
