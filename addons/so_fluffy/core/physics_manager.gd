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

func _init():
	pass

## Initialize physics state
func initialize(mesh: GeometryInstance3D) -> void:
	if mesh == null:
		return

	spring_offset = Vector3.ZERO
	spring_velocity = Vector3.ZERO
	spring_rotation = Vector3.ZERO
	spring_angular_velocity = Vector3.ZERO

	previous_position = mesh.global_transform.origin
	previous_rotation = mesh.global_transform.basis.get_euler()

## Update linear spring physics
func update_linear_physics(delta: float, mesh: GeometryInstance3D) -> void:
	if not physics_enabled or mesh == null:
		return

	# Calculate compound linear forces
	var f = gravity

	# Calculate movement from previous position
	var dx = mesh.global_transform.origin - previous_position
	var v = dx / delta
	spring_offset += dx

	var st = 8.0  # "Exaggeration" factor for more fun spring movement

	# Spring force
	f += -spring_constant * spring_offset - damping * (v + spring_velocity)

	# Update velocity and position
	var a = f / mass
	spring_velocity += a * delta
	var s = spring_velocity * delta / 2.0

	spring_offset += s

	# Limit velocity and offset
	spring_velocity = spring_velocity.limit_length(200.0 * fur_length)
	spring_offset = spring_offset.limit_length(fur_length / st * stretch)

	previous_position = mesh.global_transform.origin

## Update rotational spring physics
func update_rotational_physics(delta: float, mesh: GeometryInstance3D) -> void:
	if not physics_enabled or mesh == null:
		return

	# Calculate compound rotational forces
	var f = Vector3.ZERO

	# Calculate rotation from previous position
	var dp = mesh.global_transform.basis.get_euler() - previous_rotation
	dp = Vector3(_short_angle(dp.x), _short_angle(dp.y), _short_angle(dp.z))

	var w = dp / delta
	spring_rotation += dp

	# Spring force
	f += -spring_rotation * spring_constant - damping * (w + spring_angular_velocity)

	# Update angular velocity and rotation
	var a = f / mass
	spring_angular_velocity += a * delta
	var p = spring_angular_velocity * delta / 2.0

	spring_rotation += p

	# Limit rotation
	spring_rotation = spring_rotation.limit_length(PI * fur_length / 2.0)

	previous_rotation = mesh.global_transform.basis.get_euler()

## Apply physics to materials
func apply_to_materials(materials: Array[Material], shell_count: int) -> void:
	if not physics_enabled or materials.size() == 0:
		return

	var st = 8.0  # Exaggeration factor
	var dh = 1.0 / float(shell_count - 1) if shell_count > 1 else 1.0
	var h = dh

	for i in range(shell_count):
		if i >= materials.size():
			break

		var mat = materials[i]
		if mat == null or not mat is ShaderMaterial:
			continue

		# Linear physics offset (scaled by height and stiffness)
		var offset_at_height = st * spring_offset * pow(h * i, stiffness)
		mat.set_shader_parameter("physics_pos_offset", -offset_at_height)

		# Rotational physics offset
		var rotation_at_height = rotational_physics_scale * spring_rotation * pow(h * i, stiffness)
		mat.set_shader_parameter("physics_rot_offset", Basis.from_euler(rotation_at_height))

## Reset physics state
func reset() -> void:
	spring_offset = Vector3.ZERO
	spring_velocity = Vector3.ZERO
	spring_rotation = Vector3.ZERO
	spring_angular_velocity = Vector3.ZERO

## Helper: Normalize angle to shortest path
func _short_angle(a: float) -> float:
	return fmod(2.0 * a, 2.0 * PI) - a

## Check if physics should run in editor
func should_run_in_editor(is_editor: bool, preview_enabled: bool) -> bool:
	return not is_editor or (physics_preview and preview_enabled)
