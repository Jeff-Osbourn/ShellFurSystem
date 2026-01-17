## Fin Manager for Shell Fur System
## Generates and manages fin geometry to fill side-view gaps
## Fins are perpendicular cards that improve coverage when viewing fur from oblique angles
class_name FurFinManager
extends RefCounted

## Fin placement strategy
enum FinPlacement {
	DISABLED,      ## No fins
	RADIAL,        ## Fins arranged radially around the mesh (best for creatures)
	GRID,          ## Evenly distributed grid pattern
	EDGE_BASED,    ## Concentrated near silhouette edges (best quality, most expensive)
	SPARSE         ## Fewer fins for performance (good for background objects)
}

## Fin orientation mode
enum FinOrientation {
	CAMERA_FACING,     ## Billboard-style, always faces camera (best coverage)
	SHELL_PERPENDICULAR, ## Perpendicular to fur direction (more natural)
	FIXED_HORIZONTAL,  ## Fixed horizontal orientation
	FIXED_VERTICAL     ## Fixed vertical orientation
}

## Configuration
var enabled: bool = false
var placement: FinPlacement = FinPlacement.RADIAL
var orientation: FinOrientation = FinOrientation.CAMERA_FACING
var fin_count: int = 16  ## Number of fins to generate
var fin_density: float = 1.0  ## Density multiplier (0.5 = half density, 2.0 = double)
var fin_width: float = 0.1  ## Width of each fin in meters
var fin_alpha_boost: float = 1.2  ## Boost alpha to compensate for fewer samples

## Fin meshes and instances
var fin_meshes: Array[MeshInstance3D] = []
var camera: Camera3D = null

## Parent mesh reference
var parent_mesh: GeometryInstance3D = null

func _init() -> void:
	pass

## Initialize fin system
func initialize(mesh: GeometryInstance3D) -> void:
	parent_mesh = mesh
	cleanup()

## Generate fin geometry based on placement strategy
func generate_fins(fur_length: float, fur_direction: Vector3, shell_count: int) -> void:
	if not enabled or parent_mesh == null:
		return

	cleanup()

	# Calculate actual fin count based on density
	var actual_fin_count: int = max(1, int(fin_count * fin_density))

	match placement:
		FinPlacement.RADIAL:
			_generate_radial_fins(actual_fin_count, fur_length, fur_direction, shell_count)
		FinPlacement.GRID:
			_generate_grid_fins(actual_fin_count, fur_length, fur_direction, shell_count)
		FinPlacement.EDGE_BASED:
			_generate_edge_fins(actual_fin_count, fur_length, fur_direction, shell_count)
		FinPlacement.SPARSE:
			_generate_sparse_fins(actual_fin_count, fur_length, fur_direction, shell_count)

## Generate fins in a radial pattern around the mesh
func _generate_radial_fins(count: int, length: float, direction: Vector3, shells: int) -> void:
	var mesh_node: Node3D = parent_mesh as Node3D
	if mesh_node == null:
		return

	# Calculate mesh bounds to determine fin placement
	var aabb: AABB = _get_mesh_aabb()
	var center: Vector3 = aabb.get_center()
	var radius: float = aabb.size.length() * 0.5

	# Create fins in a circle around the mesh
	for i in range(count):
		var angle: float = (TAU / count) * i
		var fin_mesh: MeshInstance3D = _create_fin_mesh(length, direction, shells)

		# Position fin on circle
		var offset: Vector3 = Vector3(cos(angle), 0, sin(angle)) * radius
		fin_mesh.position = center + offset

		# Rotate to face outward
		fin_mesh.look_at(center, Vector3.UP)
		fin_mesh.rotate_object_local(Vector3.UP, PI / 2)

		mesh_node.add_child(fin_mesh)
		fin_meshes.append(fin_mesh)

## Generate fins in a grid pattern
func _generate_grid_fins(count: int, length: float, direction: Vector3, shells: int) -> void:
	var mesh_node: Node3D = parent_mesh as Node3D
	if mesh_node == null:
		return

	var aabb: AABB = _get_mesh_aabb()
	var grid_size: int = int(ceil(sqrt(count)))
	var step_x: float = aabb.size.x / grid_size
	var step_z: float = aabb.size.z / grid_size

	var created: int = 0
	for x in range(grid_size):
		for z in range(grid_size):
			if created >= count:
				break

			var fin_mesh: MeshInstance3D = _create_fin_mesh(length, direction, shells)
			fin_mesh.position = aabb.position + Vector3(
				step_x * x + step_x * 0.5,
				aabb.size.y * 0.5,
				step_z * z + step_z * 0.5
			)

			mesh_node.add_child(fin_mesh)
			fin_meshes.append(fin_mesh)
			created += 1

## Generate fins concentrated near edges (best quality)
func _generate_edge_fins(count: int, length: float, direction: Vector3, shells: int) -> void:
	# For now, use radial with higher density near edges
	# TODO: Implement proper edge detection using mesh normals
	_generate_radial_fins(count, length, direction, shells)

## Generate sparse fins for performance
func _generate_sparse_fins(count: int, length: float, direction: Vector3, shells: int) -> void:
	# Use radial pattern with reduced count
	_generate_radial_fins(max(4, count / 4), length, direction, shells)

## Create a single fin mesh (quad card)
func _create_fin_mesh(length: float, direction: Vector3, shells: int) -> MeshInstance3D:
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()

	# Create quad mesh for fin
	var quad_mesh: QuadMesh = QuadMesh.new()
	quad_mesh.size = Vector2(fin_width, length)
	quad_mesh.orientation = PlaneMesh.FACE_Z

	mesh_instance.mesh = quad_mesh
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Offset to align with fur base
	mesh_instance.position.y = length * 0.5

	return mesh_instance

## Apply materials to fins (should match shell materials)
func apply_materials(materials: Array[Material], shell_count: int) -> void:
	if fin_meshes.size() == 0 or materials.size() == 0:
		return

	# Use the middle shell's material for fins (good balance of detail and performance)
	var mid_shell_index: int = shell_count / 2
	if mid_shell_index < materials.size() and materials[mid_shell_index] != null:
		var fin_material: Material = materials[mid_shell_index].duplicate()

		# Boost alpha if needed
		if fin_material is ShaderMaterial and fin_alpha_boost != 1.0:
			fin_material.set_shader_parameter("alpha_boost", fin_alpha_boost)

		# Apply to all fins
		for fin in fin_meshes:
			if fin != null:
				fin.material_override = fin_material

## Update fin orientations (called per frame for camera-facing fins)
func update_orientation(camera_node: Camera3D) -> void:
	if not enabled or fin_meshes.size() == 0:
		return

	camera = camera_node

	match orientation:
		FinOrientation.CAMERA_FACING:
			_update_camera_facing()
		FinOrientation.SHELL_PERPENDICULAR:
			_update_shell_perpendicular()
		# FIXED orientations don't need per-frame updates

## Update fins to face camera (billboard effect)
func _update_camera_facing() -> void:
	if camera == null:
		return

	for fin in fin_meshes:
		if fin != null and is_instance_valid(fin):
			fin.look_at(camera.global_position, Vector3.UP)

## Update fins to be perpendicular to shell direction
func _update_shell_perpendicular() -> void:
	# Calculate perpendicular based on fur direction
	# This would need fur_direction parameter - keeping fins at current rotation for now
	pass

## Get mesh AABB (handles both MeshInstance3D and GeometryInstance3D)
func _get_mesh_aabb() -> AABB:
	if parent_mesh == null:
		return AABB()

	if parent_mesh is MeshInstance3D:
		var mesh: Mesh = (parent_mesh as MeshInstance3D).mesh
		if mesh != null:
			return mesh.get_aabb()

	# Fallback: construct AABB from transform
	return AABB(Vector3.ZERO, Vector3.ONE)

## Cleanup all fin meshes
func cleanup() -> void:
	for fin in fin_meshes:
		if fin != null and is_instance_valid(fin):
			fin.queue_free()

	fin_meshes.clear()

## Update LOD for fins (hide at distance)
func update_lod(distance: float, max_distance: float) -> void:
	if not enabled or fin_meshes.size() == 0:
		return

	var lod_ratio: float = clamp(distance / max_distance, 0.0, 1.0)

	# Hide fins beyond 50% max distance for performance
	var should_show: bool = lod_ratio < 0.5

	for fin in fin_meshes:
		if fin != null and is_instance_valid(fin):
			fin.visible = should_show
