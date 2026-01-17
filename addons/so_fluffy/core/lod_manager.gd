## LOD Manager for Shell Fur System
## Handles LOD calculations, shell selection, and adaptive shell distribution
class_name FurLODManager
extends RefCounted

## Shell distribution modes
enum DistributionMode {
	LINEAR,        # Traditional linear spacing
	QUADRATIC,     # Denser near surface, sparser at tips
	EXPONENTIAL,   # Even denser near surface
	CUSTOM         # User-defined curve
}

## LOD configuration
var lod_enabled: bool = false
var lod_min_distance: float = 3.0
var lod_max_distance: float = 25.0
var lod_minimum_shells: int = 8

## Adaptive shell distribution
var distribution_mode: DistributionMode = DistributionMode.QUADRATIC
var distribution_curve: Curve = null  # For CUSTOM mode
var distribution_bias: float = 2.0     # Controls density falloff (1.0 = linear, >1 = denser near surface)

## Current LOD state
var current_lod: int = 0
var current_shell_count: int = 0

## Shell configuration
var total_shells: int = 64
var active_shell_indices: Array[int] = []
var shell_heights: Array[float] = []  # Normalized heights (0..1) for each shell

func _init(shell_count: int = 64):
	total_shells = shell_count
	current_shell_count = shell_count
	_recalculate_shell_distribution()

## Calculate shell heights based on distribution mode
func _recalculate_shell_distribution() -> void:
	shell_heights.clear()
	shell_heights.resize(total_shells)

	for i in range(total_shells):
		var linear_h = float(i) / float(total_shells - 1) if total_shells > 1 else 0.0
		var h = _apply_distribution_curve(linear_h)
		shell_heights[i] = h

## Apply distribution curve to get actual shell height
func _apply_distribution_curve(linear_h: float) -> float:
	match distribution_mode:
		DistributionMode.LINEAR:
			return linear_h

		DistributionMode.QUADRATIC:
			# Quadratic: h = t^bias (denser near surface when bias > 1)
			return pow(linear_h, distribution_bias)

		DistributionMode.EXPONENTIAL:
			# Exponential falloff: more aggressive density near surface
			var exp_factor = distribution_bias
			return (exp(linear_h * exp_factor) - 1.0) / (exp(exp_factor) - 1.0)

		DistributionMode.CUSTOM:
			if distribution_curve != null:
				return distribution_curve.sample(linear_h)
			return linear_h

		_:
			return linear_h

## Get shell height for a specific shell index
func get_shell_height(index: int) -> float:
	if index >= 0 and index < shell_heights.size():
		return shell_heights[index]
	return 0.0

## Calculate LOD based on camera distance
func calculate_lod(mesh: GeometryInstance3D, camera: Camera3D) -> int:
	if not lod_enabled or camera == null or mesh == null:
		return 0

	# Use closest point on AABB for distance calculation
	var aabb: AABB = mesh.get_aabb()
	var closest = _closest_point_on_aabb(mesh, aabb, camera.global_transform.origin)

	# LOD distance in the range [0, 1]
	var distance = camera.global_transform.origin.distance_to(closest)
	var rel_dist: float = clampf((distance - lod_min_distance) / (lod_max_distance - lod_min_distance), 0.0, 1.0)

	# Linearly scale LOD level
	return clampi(floori(rel_dist * total_shells), 0, total_shells - 1)

## Apply LOD by selecting which shells to render
func apply_lod(lod_level: int) -> Array[int]:
	current_lod = lod_level

	# Calculate number of shells for this LOD level
	current_shell_count = lod_minimum_shells + int((1.0 - float(lod_level) / float(total_shells - 1)) * (total_shells - lod_minimum_shells))
	current_shell_count = clampi(current_shell_count, lod_minimum_shells, total_shells)

	# Select shells with adaptive distribution
	active_shell_indices.clear()

	if current_shell_count >= total_shells:
		# Use all shells
		for i in range(total_shells):
			active_shell_indices.append(i)
	else:
		# Select subset of shells maintaining distribution
		var step = float(total_shells - 1) / float(current_shell_count - 1)

		for i in range(current_shell_count):
			var index = int(step * i)
			active_shell_indices.append(index)

	return active_shell_indices

## Get thickness compensation for current LOD
## Lower shell counts need thicker strands to maintain visual density
func get_lod_thickness_multiplier() -> float:
	if not lod_enabled:
		return 1.0

	# Empirical formula from original implementation
	return 4.5987 * pow(current_shell_count, -0.2807)

## Set distribution mode
func set_distribution_mode(mode: DistributionMode, bias: float = 2.0) -> void:
	distribution_mode = mode
	distribution_bias = bias
	_recalculate_shell_distribution()

## Set custom distribution curve
func set_custom_distribution_curve(curve: Curve) -> void:
	distribution_curve = curve
	distribution_mode = DistributionMode.CUSTOM
	_recalculate_shell_distribution()

## Update total shell count
func set_total_shells(count: int) -> void:
	total_shells = count
	current_shell_count = count
	_recalculate_shell_distribution()

## Helper: Find closest point on AABB to a world position
func _closest_point_on_aabb(mesh: GeometryInstance3D, aabb: AABB, world_pos: Vector3) -> Vector3:
	var pos = mesh.to_global(aabb.position)
	var end = mesh.to_global(aabb.end)

	var closest = Vector3(
		clampf(world_pos.x, pos.x, end.x),
		clampf(world_pos.y, pos.y, end.y),
		clampf(world_pos.z, pos.z, end.z)
	)

	return closest
