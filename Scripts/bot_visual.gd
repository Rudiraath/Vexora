extends Node3D
## Runtime presentation only. Imported character scale, rig and clips are preserved.
var animation_player: AnimationPlayer
var animation_names: Dictionary = {}
var hit_material: StandardMaterial3D
var tint: StandardMaterial3D
var hand: Node3D
var grip: Node3D
var muzzle: Node3D
var flash: MeshInstance3D
var flash_left := 0.0
var meshes: Array[MeshInstance3D] = []
@onready var rifle: Node3D = $Rifle
func _ready() -> void:
	tint = StandardMaterial3D.new()
	tint.albedo_color = Color("d75c57")
	tint.roughness = 0.9
	hit_material = StandardMaterial3D.new()
	hit_material.albedo_color = Color(1, 0.75, 0.35)
	hit_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for node in $Character.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.name == "Cube":
			mesh.hide()
			continue
		meshes.append(mesh)
		if "Armor" in String(mesh.name) or "Accent" in String(mesh.name):
			mesh.material_override = tint
	hand = $Character.find_child("Player_Hand_R", true, false)
	grip = rifle.find_child("Grip_Point", true, false)
	muzzle = rifle.find_child("Muzzle_Point", true, false)
	for mesh in rifle.find_children("Cube", "MeshInstance3D", true, false):
		mesh.hide()
	var players := $Character.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		animation_player = players[0]
		for library_name in animation_player.get_animation_library_list():
			var library := animation_player.get_animation_library(library_name).duplicate(true) as AnimationLibrary
			animation_player.remove_animation_library(library_name)
			animation_player.add_animation_library(library_name, library)
		for full_name in animation_player.get_animation_list():
			var short_name := String(full_name).get_slice("/", String(full_name).get_slice_count("/") - 1)
			animation_names[short_name] = full_name
			if short_name in ["Idle", "Run", "Fall"]:
				animation_player.get_animation(full_name).loop_mode = Animation.LOOP_LINEAR
	flash = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.06
	sphere.height = 0.12
	flash.mesh = sphere
	flash.material_override = hit_material
	muzzle.add_child(flash)
	flash.hide()
func update_pose(delta: float, moving: bool, airborne: bool, hit: bool) -> void:
	flash_left = maxf(0, flash_left - delta)
	flash.visible = flash_left > 0
	for mesh in meshes:
		mesh.material_overlay = hit_material if hit else null
	if animation_player:
		var clip := "Fall" if airborne else ("Run" if moving else "Idle")
		if animation_names.has(clip) and (animation_player.current_animation != animation_names[clip] or not animation_player.is_playing()):
			animation_player.play(animation_names[clip], 0.12)
	# Put the grip in the animated right hand, keeping the barrel forward.
	rifle.global_basis = global_basis * Basis(Vector3.UP, PI / 2.0)
	if hand:
		rifle.global_position = hand.global_position - rifle.global_basis * grip.position
func shot() -> void:
	flash_left = 0.065
func stop() -> void:
	flash_left = 0
	flash.hide()
	if animation_player:
		animation_player.pause()
