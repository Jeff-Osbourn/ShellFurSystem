## Physics Manager for Shell Fur System
## Handles spring-based physics simulation for fur movement
class_name FurPhysicsManager
extends RefCounted

## Physics configuration
var physics_enabled: bool = true
var physics_preview: bool = true  # For editor

## Linear spring physics
var gravity: Vector3 = Vector3.ZERO
var spring_constant: float = 80.0
var mass: float = 0.15
var damping: float = 3.0
var stretch: float = 1.0  # Max stretch allowed (1.0 = no stretch)

## Wind simulation
var wind_enabled: bool = false
var wind_direction: Vector3 = Vector3(1.0, 0.0, 0.0)
var wind_strength: float = 0.0
var wind_turbulence: float = 0.3  # Random variation in wind
var wind_speed: float = 1.0  # Speed of wind gusts

## Rotational physics
var rotational_physics_scale: float = 1.0

## Stiffness (how bendy strands are)
var stiffness: float = 1.0

## Physics state
var previous_position: Vector3 = Vector3.ZERO
var previous_rotation: Vector3 = Vector3.ZERO
var spring_offset: Vector3 = Vector3.ZERO
var spring_velocity: Vector3 = Vector3.ZERO
var spring_rotation: Vector3 = Vector3.ZERO
var spring_angular_velocity: Vector3 = Vector3.ZERO

## Fur properties (for physics calculations)
var fur_length: float = 0.1

## Internal time for wind simulation
var wind_time: float = 0.0

func _init() -> void:
	pass

## Initialize physics state
func initialize(mesh: GeometryInstance3D) -> void:
	if mesh == null:
		return

	spring_offset = Vector3.ZERO
	spring_velocity = Vector3.ZERO
	spring_rotation = Vector3.ZERO
	spring_angular_velocity = Vector3.ZERO
	wind_time = 0.0

	previous_position = mesh.global_transform.origin
	previous_rotation = mesh.global_transform.basis.get_euler()

## Update linear spring physics
func update_linear_physics(delta: float, mesh: GeometryInstance3D) -> void:
	if not physics_enabled or mesh == null:
		return

	# Update wind time for turbulence
	wind_time += delta * wind_speed

	# Calculate compound linear forces
	var f: Vector3 = gravity

	# Add wind force
	if wind_enabled and wind_strength > 0.0:
		var wind_noise: float = sin(wind_time) * cos(wind_time * 0.7) * wind_turbulence
		var wind_force: Vector3 = wind_direction.normalized() * wind_strength * (1.0 + wind_noise)
		f += wind_force

	# Calculate movement from previous position
	var dx: Vector3 = mesh.global_transform.origin - previous_position
	var v: Vector3 = dx / delta if delta > 0.0 else Vector3.ZERO
	spring_offset += dx

	var st: float = 8.0  # "Exaggeration" factor for more visible spring movement

	# Spring force (Hooke's law) with velocity damping
	# F = -kx - cv
	f += -spring_constant * spring_offset - damping * spring_velocity

	# Update velocity and position (Euler integration)
	var a: Vector3 = f / mass
	spring_velocity += a * delta
	spring_offset += spring_velocity * delta

	# Limit velocity and offset to prevent extreme values
	spring_velocity = spring_velocity.limit_length(200.0 * fur_length)
	spring_offset = spring_offset.limit_length(fur_length / st * stretch)

	previous_position = mesh.global_transform.origin

## Update rotational spring physics
func update_rotational_physics(delta: float, mesh: GeometryInstance3D) -> void:
	if not physics_enabled or mesh == null:
		return

	# Calculate compound rotational forces
	var f: Vector3 = Vector3.ZERO

	# Calculate rotation from previous position
	var dp: Vector3 = mesh.global_transform.basis.get_euler() - previous_rotation
	dp = Vector3(_short_angle(dp.x), _short_angle(dp.y), _short_angle(dp.z))

	var w: Vector3 = dp / delta if delta > 0.0 else Vector3.ZERO
	spring_rotation += dp

	# Spring force with angular damping
	f += -spring_rotation * spring_constant - damping * spring_angular_velocity

	# Update angular velocity and rotation
	var a: Vector3 = f / mass
	spring_angular_velocity += a * delta
	spring_rotation += spring_angular_velocity * delta

	# Limit angular velocity and rotation
	spring_angular_velocity = spring_angular_velocity.limit_length(50.0)  # Prevent spinning too fast
	spring_rotation = spring_rotation.limit_length(PI * fur_length / 2.0)

	previous_rotation = mesh.global_transform.basis.get_euler()

## Apply physics to materials
func apply_to_materials(materials: Array[Material], shell_count: int) -> void:
	if materials.size() == 0 or shell_count <= 0:
		return

	var st: float = 8.0  # Exaggeration factor

	# Calculate default values (identity/zero)
	var default_offset: Vector3 = Vector3.ZERO
	var default_rotation: Basis = Basis.IDENTITY

	for i in range(shell_count):
		if i >= materials.size():
			break

		var mat: Material = materials[i]
		if mat == null or not mat is ShaderMaterial:
			continue

		var shader_mat: ShaderMaterial = mat as ShaderMaterial

		# Calculate normalized height (0.0 to 1.0) for this shell
		var h: float = float(i) / float(shell_count - 1) if shell_count > 1 else 1.0

		if physics_enabled:
			# Linear physics offset (scaled by height^stiffness for natural bend)
			var offset_at_height: Vector3 = st * spring_offset * pow(h, stiffness)
			shader_mat.set_shader_parameter("physics_pos_offset", -offset_at_height)

			# Rotational physics offset (scaled by height^stiffness)
			var rotation_at_height: Vector3 = rotational_physics_scale * spring_rotation * pow(h, stiffness)
			shader_mat.set_shader_parameter("physics_rot_offset", Basis.from_euler(rotation_at_height))
		else:
			# Always initialize to default values even when physics disabled
			shader_mat.set_shader_parameter("physics_pos_offset", default_offset)
			shader_mat.set_shader_parameter("physics_rot_offset", default_rotation)

## Reset physics state
func reset() -> void:
	spring_offset = Vector3.ZERO
	spring_velocity = Vector3.ZERO
	spring_rotation = Vector3.ZERO
	spring_angular_velocity = Vector3.ZERO
	wind_time = 0.0

## Helper: Normalize angle to shortest path (-PI to PI)
func _short_angle(a: float) -> float:
	return fmod(a + PI, TAU) - PI

## Check if physics should run in editor
func should_run_in_editor(is_editor: bool, preview_enabled: bool) -> bool:
	return not is_editor or (physics_preview and preview_enabled)
