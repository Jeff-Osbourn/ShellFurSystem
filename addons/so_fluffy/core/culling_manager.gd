## Culling Manager for Shell Fur System
## Handles frustum culling and visibility optimization for individual shells
class_name FurCullingManager
extends RefCounted

## Culling modes
enum CullingMode {
	NONE,              # No culling (render all shells)
	FRUSTUM,           # Frustum culling only
	OCCLUSION,         # Frustum + simple occlusion
	AGGRESSIVE         # All optimizations enabled
}

## Configuration
var culling_mode: CullingMode = CullingMode.FRUSTUM
var culling_enabled: bool = true

## Shell visibility tracking
var shell_visible: Array[bool] = []
var culled_shell_count: int = 0

## Frustum culling configuration
var fur_length: float = 0.1
var shell_expansion_factor: float = 1.1  # How much larger each shell AABB is

## Occlusion culling (simple backface-based)
var use_backface_culling: bool = true
var backface_cull_threshold: float = 0.0  # Dot product threshold for backface culling

func _init():
	pass

## Initialize culling for a set of shells
func initialize(shell_count: int) -> void:
	shell_visible.clear()
	shell_visible.resize(shell_count)
	shell_visible.fill(true)
	culled_shell_count = 0

## Update shell visibility based on camera
func update_visibility(
	mesh: GeometryInstance3D,
	camera: Camera3D,
	shell_heights: Array[float],
	active_shell_indices: Array[int]
) -> Array[bool]:

	if not culling_enabled or camera == null or mesh == null:
		# All shells visible
		shell_visible.fill(true)
		culled_shell_count = 0
		return shell_visible

	culled_shell_count = 0

	match culling_mode:
		CullingMode.NONE:
			shell_visible.fill(true)

		CullingMode.FRUSTUM:
			_frustum_cull(mesh, camera, shell_heights, active_shell_indices)

		CullingMode.OCCLUSION:
			_frustum_cull(mesh, camera, shell_heights, active_shell_indices)
			_occlusion_cull(mesh, camera, active_shell_indices)

		CullingMode.AGGRESSIVE:
			_frustum_cull(mesh, camera, shell_heights, active_shell_indices)
			_occlusion_cull(mesh, camera, active_shell_indices)
			_backface_cull(mesh, camera, active_shell_indices)

	return shell_visible

## Frustum culling - check if shell AABB is in camera frustum
func _frustum_cull(
	mesh: GeometryInstance3D,
	camera: Camera3D,
	shell_heights: Array[float],
	active_indices: Array[int]
) -> void:

	var frustum_planes = _get_frustum_planes(camera)
	var base_aabb = mesh.get_aabb()

	for idx in active_indices:
		if idx >= shell_heights.size():
			continue

		var h = shell_heights[idx]
		var shell_aabb = _get_shell_aabb(mesh, base_aabb, h)

		# Check against all frustum planes
		var visible = true
		for plane in frustum_planes:
			if not _aabb_intersects_plane(shell_aabb, plane):
				visible = false
				culled_shell_count += 1
				break

		shell_visible[idx] = visible

## Simple occlusion culling - cull inner shells when outer shells are opaque
func _occlusion_cull(mesh: GeometryInstance3D, camera: Camera3D, active_indices: Array[int]) -> void:
	# Simple heuristic: if viewing from far away, cull some inner shells
	# This is a simplified occlusion test - proper occlusion would require depth buffers

	var distance = camera.global_transform.origin.distance_to(mesh.global_transform.origin)
	var occlusion_distance_threshold = fur_length * 10.0

	if distance < occlusion_distance_threshold:
		return  # Too close for occlusion culling

	# Cull inner 25% of shells if far away
	var cull_threshold = 0.25
	for idx in active_indices:
		if shell_visible[idx] and idx < int(active_indices.size() * cull_threshold):
			shell_visible[idx] = false
			culled_shell_count += 1

## Backface culling - cull shells on backfacing surfaces
func _backface_cull(mesh: GeometryInstance3D, camera: Camera3D, active_indices: Array[int]) -> void:
	if not use_backface_culling:
		return

	# Get camera direction
	var cam_pos = camera.global_transform.origin
	var mesh_pos = mesh.global_transform.origin
	var to_camera = (cam_pos - mesh_pos).normalized()

	# Get mesh forward direction (approximate - this is simplified)
	var mesh_forward = mesh.global_transform.basis.z

	# If mesh is facing away from camera, cull more aggressively
	var facing_dot = mesh_forward.dot(to_camera)
	if facing_dot < backface_cull_threshold:
		# Facing away - cull more inner shells
		for idx in active_indices:
			if shell_visible[idx] and idx < active_indices.size() / 2:
				shell_visible[idx] = false
				culled_shell_count += 1

## Get camera frustum planes
func _get_frustum_planes(camera: Camera3D) -> Array[Plane]:
	var frustum: Array[Plane] = []

	# Get camera frustum from projection matrix
	var projection = camera.get_camera_projection()
	var cam_transform = camera.global_transform

	# Extract frustum planes (simplified - Godot 4 provides these directly)
	# Near, Far, Left, Right, Top, Bottom
	var fov = camera.fov
	var aspect = camera.get_viewport().get_visible_rect().size.aspect()
	var near = camera.near
	var far = camera.far

	# Calculate frustum planes in world space
	var forward = -cam_transform.basis.z
	var right = cam_transform.basis.x
	var up = cam_transform.basis.y
	var pos = cam_transform.origin

	# Near and far planes
	frustum.append(Plane(forward, pos + forward * near))
	frustum.append(Plane(-forward, pos + forward * far))

	# Side planes (simplified calculation)
	var half_fov_rad = deg_to_rad(fov / 2.0)
	var near_height = tan(half_fov_rad) * near
	var near_width = near_height * aspect

	# Left, Right, Top, Bottom planes
	frustum.append(Plane(right, pos))
	frustum.append(Plane(-right, pos))
	frustum.append(Plane(up, pos))
	frustum.append(Plane(-up, pos))

	return frustum

## Get AABB for a specific shell height
func _get_shell_aabb(mesh: GeometryInstance3D, base_aabb: AABB, shell_height: float) -> AABB:
	# Expand AABB based on shell height
	var expansion = fur_length * shell_height * shell_expansion_factor

	var expanded_aabb = base_aabb.grow(expansion)

	# Transform to world space
	var world_aabb = mesh.global_transform * expanded_aabb

	return world_aabb

## Check if AABB intersects with plane (on positive side)
func _aabb_intersects_plane(aabb: AABB, plane: Plane) -> bool:
	# Get AABB center and extents
	var center = aabb.get_center()
	var extents = aabb.size / 2.0

	# Calculate AABB "radius" along plane normal
	var radius = abs(extents.x * plane.normal.x) + \
				 abs(extents.y * plane.normal.y) + \
				 abs(extents.z * plane.normal.z)

	# Distance from plane to center
	var distance = plane.distance_to(center)

	# AABB intersects if center distance is less than radius
	return distance > -radius

## Get culling statistics
func get_culling_stats() -> Dictionary:
	var visible_count = 0
	for v in shell_visible:
		if v:
			visible_count += 1

	return {
		"total_shells": shell_visible.size(),
		"visible_shells": visible_count,
		"culled_shells": culled_shell_count,
		"cull_percentage": (float(culled_shell_count) / float(shell_visible.size())) * 100.0 if shell_visible.size() > 0 else 0.0
	}

## Set fur length for culling calculations
func set_fur_length(length: float) -> void:
	fur_length = length
