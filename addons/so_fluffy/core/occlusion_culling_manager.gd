## Occlusion Culling Manager for Shell Fur System
## Handles LOD and visibility optimization to reduce overdraw
class_name FurOcclusionCullingManager
extends RefCounted

## LOD configuration
@export_group("Level of Detail")
## Enable distance-based LOD
var lod_enabled: bool = true

## Distance ranges for LOD levels (in world units)
## At each distance threshold, shell count is reduced
var lod_distances: Array[float] = [5.0, 10.0, 20.0, 40.0]

## Shell count at each LOD level (as fraction of max shells)
## 1.0 = full shells, 0.5 = half shells, 0.25 = quarter shells
var lod_shell_fractions: Array[float] = [1.0, 0.75, 0.5, 0.25, 0.1]

## Minimum shell count (never go below this)
var min_shell_count: int = 2

## View-dependent culling
@export_group("View Culling")
## Enable culling of back-facing shells
var backface_culling_enabled: bool = true

## Angle threshold for backface culling (in radians)
## Shells facing away from camera by more than this angle are culled
var backface_threshold: float = deg_to_rad(100.0)

## Occlusion culling
@export_group("Occlusion")
## Enable occlusion culling (skip completely hidden shells)
var occlusion_enabled: bool = true

## Start culling from this shell index (inner shells)
## Shells closer to base are more likely occluded
var occlusion_start_shell: int = 0

## Cull every N shells (skip pattern)
## 1 = check every shell, 2 = check every other shell
var occlusion_check_interval: int = 1

## Internal state
var current_shell_count: int = 8
var max_shell_count: int = 8
var camera_position: Vector3 = Vector3.ZERO
var camera_forward: Vector3 = Vector3(0, 0, -1)

func _init() -> void:
	pass

## Initialize with max shell count
func initialize(p_max_shell_count: int) -> void:
	max_shell_count = p_max_shell_count
	current_shell_count = max_shell_count

## Update camera info for culling calculations
func update_camera(cam_position: Vector3, cam_forward: Vector3) -> void:
	camera_position = cam_position
	camera_forward = cam_forward.normalized()

## Calculate LOD level based on distance
func calculate_lod_level(object_position: Vector3) -> int:
	if not lod_enabled:
		return 0

	var distance := camera_position.distance_to(object_position)

	# Find which LOD distance range we're in
	for i in range(lod_distances.size()):
		if distance < lod_distances[i]:
			return i

	# Beyond all thresholds - use lowest LOD
	return lod_distances.size()

## Get shell count for current LOD level
func get_shell_count_for_lod(lod_level: int) -> int:
	if lod_level < 0 or lod_level >= lod_shell_fractions.size():
		lod_level = lod_shell_fractions.size() - 1

	var fraction: float = lod_shell_fractions[lod_level]
	var shell_count: int = max(min_shell_count, int(float(max_shell_count) * fraction))

	return shell_count

## Update shell count based on distance LOD
func update_lod(object_position: Vector3) -> int:
	var lod_level := calculate_lod_level(object_position)
	current_shell_count = get_shell_count_for_lod(lod_level)
	return current_shell_count

## Check if a shell should be rendered based on view angle
func should_render_shell_view(shell_index: int, object_position: Vector3, object_normal: Vector3) -> bool:
	if not backface_culling_enabled:
		return true

	# Direction from camera to object
	var view_dir := (object_position - camera_position).normalized()

	# Dot product: positive = facing camera, negative = facing away
	var facing_dot := object_normal.dot(-view_dir)

	# For shells, we can be more aggressive with back-facing culling on inner shells
	# Inner shells (lower index) can be culled more aggressively
	var shell_factor := 1.0 - (float(shell_index) / float(max_shell_count))
	var adjusted_threshold := cos(backface_threshold) * (1.0 - shell_factor * 0.3)

	return facing_dot > adjusted_threshold

## Check if shell should be rendered based on occlusion
func should_render_shell_occlusion(shell_index: int) -> bool:
	if not occlusion_enabled:
		return true

	# Don't cull outer shells
	if shell_index >= current_shell_count - 2:
		return true

	# Only check shells within the interval
	if occlusion_check_interval > 1 and shell_index % occlusion_check_interval != 0:
		return true

	# Start culling from occlusion_start_shell
	if shell_index < occlusion_start_shell:
		return true

	# Could be extended with actual depth testing, but for now
	# we assume inner shells have a chance of being occluded
	# This is a heuristic - actual occlusion would require depth buffer checks

	return true

## Get visibility mask for all shells
## Returns array of bools indicating which shells should render
func get_shell_visibility(object_position: Vector3, object_normal: Vector3) -> Array[bool]:
	var visibility: Array[bool] = []
	visibility.resize(current_shell_count)
	visibility.fill(true)

	for i in range(current_shell_count):
		var visible := true

		# Check view-dependent culling
		if backface_culling_enabled:
			visible = visible and should_render_shell_view(i, object_position, object_normal)

		# Check occlusion culling
		if occlusion_enabled:
			visible = visible and should_render_shell_occlusion(i)

		visibility[i] = visible

	return visibility

## Get optimized shell indices (only shells that should render)
## This can be used to skip shell creation entirely for invisible shells
func get_active_shell_indices(object_position: Vector3, object_normal: Vector3) -> Array[int]:
	var visibility := get_shell_visibility(object_position, object_normal)
	var active_indices: Array[int] = []

	for i in range(visibility.size()):
		if visibility[i]:
			active_indices.append(i)

	return active_indices

## Calculate performance metrics
func get_culling_stats() -> Dictionary:
	var stats := {}
	stats["max_shell_count"] = max_shell_count
	stats["current_shell_count"] = current_shell_count
	stats["shell_reduction_percent"] = (1.0 - float(current_shell_count) / float(max_shell_count)) * 100.0
	stats["lod_enabled"] = lod_enabled
	stats["backface_culling_enabled"] = backface_culling_enabled
	stats["occlusion_enabled"] = occlusion_enabled

	return stats

## Preset configurations

## Preset: Maximum Quality (no culling)
func preset_max_quality() -> void:
	lod_enabled = false
	backface_culling_enabled = false
	occlusion_enabled = false
	current_shell_count = max_shell_count

## Preset: Balanced (moderate culling)
func preset_balanced() -> void:
	lod_enabled = true
	lod_distances = [10.0, 20.0, 40.0, 80.0]
	lod_shell_fractions = [1.0, 0.75, 0.5, 0.25, 0.1]
	backface_culling_enabled = true
	backface_threshold = deg_to_rad(100.0)
	occlusion_enabled = true
	occlusion_start_shell = 0
	occlusion_check_interval = 2

## Preset: Maximum Performance (aggressive culling)
func preset_max_performance() -> void:
	lod_enabled = true
	lod_distances = [5.0, 10.0, 20.0, 40.0]
	lod_shell_fractions = [0.75, 0.5, 0.25, 0.15, 0.05]
	backface_culling_enabled = true
	backface_threshold = deg_to_rad(90.0)
	occlusion_enabled = true
	occlusion_start_shell = 0
	occlusion_check_interval = 1
	min_shell_count = 2

## Preset: VR Optimized (extreme performance focus)
func preset_vr_optimized() -> void:
	lod_enabled = true
	lod_distances = [3.0, 6.0, 12.0, 24.0]
	lod_shell_fractions = [0.6, 0.4, 0.2, 0.1, 0.05]
	backface_culling_enabled = true
	backface_threshold = deg_to_rad(85.0)
	occlusion_enabled = true
	occlusion_start_shell = 0
	occlusion_check_interval = 1
	min_shell_count = 1
