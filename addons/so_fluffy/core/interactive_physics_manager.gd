## Interactive Physics Manager for Shell Fur System
## Handles Area3D-based collision physics for realistic fur interaction
class_name FurInteractivePhysicsManager
extends RefCounted

## Configuration
var enabled: bool = false
var global_strength: float = 1.0  ## Overall displacement strength
var smoothing: float = 0.15  ## Interpolation speed (lower = smoother)
var max_displacement: float = 0.3  ## Maximum displacement in meters
var compression_strength: float = 0.5  ## How much fur compresses when pressed

## Collision zones (array of FurCollisionZone resources)
var zones: Array[FurCollisionZone] = []

## Parent mesh reference
var parent_mesh: GeometryInstance3D = null

## Current displacement state (smoothed)
var current_displacement: Vector3 = Vector3.ZERO
var target_displacement: Vector3 = Vector3.ZERO

## Collision data passed to shaders
var collision_positions: Array[Vector3] = []  ## Up to 8 collision points
var collision_directions: Array[Vector3] = []  ## Direction to push fur
var collision_strengths: Array[float] = []  ## Falloff strength per collision

const MAX_COLLISIONS: int = 8  ## Maximum collision points tracked

func _init() -> void:
	pass

## Initialize with parent mesh
func initialize(mesh: GeometryInstance3D) -> void:
	parent_mesh = mesh
	cleanup()

## Add a collision zone
func add_zone(zone: FurCollisionZone) -> void:
	if zone in zones:
		return

	zones.append(zone)

	# Create Area3D if parent exists
	if parent_mesh != null:
		zone.create_area(parent_mesh)

## Remove a collision zone
func remove_zone(zone: FurCollisionZone) -> void:
	if zone in zones:
		zone.cleanup()
		zones.erase(zone)

## Clear all zones
func clear_zones() -> void:
	for zone in zones:
		zone.cleanup()

	zones.clear()

## Create default body zones for a humanoid/creature
func create_default_zones() -> void:
	clear_zones()

	# Main body zone (largest)
	var body_zone := FurCollisionZone.new()
	body_zone.zone_name = "Body"
	body_zone.shape_type = FurCollisionZone.ShapeType.CAPSULE
	body_zone.radius = 0.3
	body_zone.height = 0.8
	body_zone.position_offset = Vector3(0, 0, 0)
	body_zone.influence_radius = 0.25
	body_zone.displacement_strength = 1.0
	add_zone(body_zone)

	# Head zone
	var head_zone := FurCollisionZone.new()
	head_zone.zone_name = "Head"
	head_zone.shape_type = FurCollisionZone.ShapeType.SPHERE
	head_zone.radius = 0.2
	head_zone.position_offset = Vector3(0, 0.5, 0)
	head_zone.influence_radius = 0.15
	head_zone.displacement_strength = 1.2  # More sensitive
	add_zone(head_zone)

## Create simple single-zone for entire body
func create_simple_zone() -> void:
	clear_zones()

	var simple_zone := FurCollisionZone.new()
	simple_zone.zone_name = "Whole Body"
	simple_zone.shape_type = FurCollisionZone.ShapeType.SPHERE
	simple_zone.radius = 0.5
	simple_zone.position_offset = Vector3.ZERO
	simple_zone.influence_radius = 0.3
	simple_zone.displacement_strength = 1.0
	add_zone(simple_zone)

## Update collision detection (call per physics frame)
func update(delta: float) -> void:
	if not enabled or parent_mesh == null:
		# Smoothly return to rest
		current_displacement = current_displacement.lerp(Vector3.ZERO, smoothing)
		return

	var mesh_global_pos: Vector3 = parent_mesh.global_position

	# Update all zones
	for zone in zones:
		zone.update_collision_data(mesh_global_pos)

	# Calculate target displacement from all active collisions
	target_displacement = Vector3.ZERO
	collision_positions.clear()
	collision_directions.clear()
	collision_strengths.clear()

	var collision_count: int = 0

	for zone in zones:
		if not zone.enabled or zone.collision_points.size() == 0:
			continue

		for i in range(zone.collision_points.size()):
			if collision_count >= MAX_COLLISIONS:
				break

			var collision_pos: Vector3 = zone.collision_points[i]
			var collision_dir: Vector3 = zone.collision_normals[i]

			# Transform to local space
			var local_pos: Vector3 = parent_mesh.global_transform.affine_inverse() * collision_pos

			collision_positions.append(local_pos)
			collision_directions.append(collision_dir)
			collision_strengths.append(zone.displacement_strength * global_strength)

			# Add to overall displacement
			target_displacement += collision_dir * zone.displacement_strength * global_strength

			collision_count += 1

	# Limit maximum displacement
	if target_displacement.length() > max_displacement:
		target_displacement = target_displacement.normalized() * max_displacement

	# Smooth interpolation
	current_displacement = current_displacement.lerp(target_displacement, smoothing)

## Apply collision data to materials
func apply_to_materials(materials: Array[Material]) -> void:
	if not enabled or materials.size() == 0:
		return

	# Prepare collision data for shader (up to 8 collision points)
	var positions_array: PackedVector3Array = PackedVector3Array()
	var directions_array: PackedVector3Array = PackedVector3Array()
	var strengths_array: PackedFloat32Array = PackedFloat32Array()

	# Fill with actual collision data
	for i in range(MAX_COLLISIONS):
		if i < collision_positions.size():
			positions_array.append(collision_positions[i])
			directions_array.append(collision_directions[i])
			strengths_array.append(collision_strengths[i])
		else:
			# Fill remaining slots with zeros
			positions_array.append(Vector3.ZERO)
			directions_array.append(Vector3.ZERO)
			strengths_array.append(0.0)

	# Apply to all materials
	for mat in materials:
		if mat == null or not mat is ShaderMaterial:
			continue

		var shader_mat: ShaderMaterial = mat

		# Check if shader supports interactive physics
		if shader_mat.get_shader() == null:
			continue

		# Set collision data
		shader_mat.set_shader_parameter("interactive_physics_enabled", enabled)
		shader_mat.set_shader_parameter("collision_count", collision_positions.size())

		# Note: Godot doesn't support array uniforms well, so we'll pass the overall displacement
		# For per-collision displacement, we'd need to modify the shader approach
		shader_mat.set_shader_parameter("interactive_displacement", current_displacement)
		shader_mat.set_shader_parameter("interactive_compression", compression_strength)

## Get current displacement (for other systems)
func get_displacement() -> Vector3:
	return current_displacement

## Get collision count
func get_collision_count() -> int:
	return collision_positions.size()

## Cleanup all zones
func cleanup() -> void:
	clear_zones()
	current_displacement = Vector3.ZERO
	target_displacement = Vector3.ZERO
	collision_positions.clear()
	collision_directions.clear()
	collision_strengths.clear()

## Debug visualization (optional)
func is_colliding() -> bool:
	return collision_positions.size() > 0
