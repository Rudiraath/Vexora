@tool
extends Node3D
## Apply reusable world-scale materials only to this map instance.
## Imported meshes, UVs and source GLB materials remain untouched.
const CONCRETE = preload("res://Materials/Arena/concrete_panels.tres")
const FLOOR = preload("res://Materials/Arena/concrete_floor.tres")
const CONSTRUCTION = preload("res://Materials/Arena/construction_orange.tres")
const METAL = preload("res://Materials/Arena/structural_metal.tres")

func _ready() -> void:
	apply_materials()

func apply_materials() -> void:
	for child in find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		var part := String(mesh.name)
		if part == "Cube":
			mesh.hide()
		elif part == "Map_Floor":
			mesh.material_override = FLOOR
		elif part.begins_with("Crate_") or "Ramp" in part:
			mesh.material_override = CONSTRUCTION
		elif part.begins_with("Barrier_") or "Stairs" in part:
			mesh.material_override = METAL
		else:
			mesh.material_override = CONCRETE
