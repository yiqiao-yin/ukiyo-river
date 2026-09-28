## River surface.
##
## Phase 1 placeholder: a flat 900 m plane at y = 0 in the prototype's deep-water colour, so the
## valley reads as a valley while the terrain and sky are reviewed. Phase 2 replaces the material
## with the ported water shader (waves, flow noise, rain ripples, reflections, wake, foam) and
## subdivides the plane to the prototype's 110x110 grid.
extends MeshInstance3D

## Prototype TS - the water plane is the same size as the terrain.
const SIZE: float = 900.0


func _ready() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(SIZE, SIZE)
	# Phase 2 needs 110x110 for vertex wave displacement; flat does not, so keep it cheap.
	plane.subdivide_width = 1
	plane.subdivide_depth = 1
	mesh = plane

	var mat := StandardMaterial3D.new()
	# TIMES.night.deep
	mat.albedo_color = Color("#0f1b22").srgb_to_linear()
	mat.roughness = 0.15
	mat.metallic = 0.0
	material_override = mat
