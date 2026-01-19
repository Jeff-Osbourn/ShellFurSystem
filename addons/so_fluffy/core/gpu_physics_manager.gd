## GPU Physics Manager for Shell Fur System
## Uses compute shaders to calculate physics on GPU for massive performance gains
class_name GPUFurPhysicsManager
extends RefCounted

## Rendering device for compute shader
var rd: RenderingDevice

## Compute shader and pipeline
var shader: RID
var pipeline: RID

## Buffer objects
var state_buffer: RID        # Physics state (persistent)
var transform_buffer: RID    # Instance transforms (updated each frame)
var config_uniform: RID      # Physics configuration
var results_buffer: RID      # Physics results per shell
var uniform_set: RID

## Configuration
var instance_count: int = 1
var shell_count: int = 8

## Physics parameters (matching PhysicsConfig struct in compute shader)
var gravity: Vector3 = Vector3.ZERO
var spring_constant: float = 80.0
var mass: float = 0.15
var damping: float = 3.0
var stretch: float = 1.0
var fur_length: float = 0.1
var stiffness: float = 1.0
var rotational_physics_scale: float = 1.0

## Wind parameters
var wind_enabled: bool = false
var wind_direction: Vector3 = Vector3(1.0, 0.0, 0.0)
var wind_strength: float = 0.0
var wind_turbulence: float = 0.3
var wind_speed: float = 1.0

## Physics state arrays (CPU-side cache)
var physics_states: Array[Dictionary] = []

## Status
var is_initialized: bool = false

func _init() -> void:
	rd = RenderingServer.get_rendering_device()
	if rd == null:
		push_error("GPUFurPhysicsManager: RenderingDevice not available! GPU physics disabled.")
		return

## Initialize GPU physics system
func initialize(p_instance_count: int, p_shell_count: int) -> bool:
	if rd == null:
		return false

	instance_count = max(1, p_instance_count)
	shell_count = max(1, p_shell_count)

	# Initialize physics state cache
	physics_states.clear()
	for i in range(instance_count):
		physics_states.append({
			"spring_offset": Vector3.ZERO,
			"spring_velocity": Vector3.ZERO,
			"spring_rotation": Vector3.ZERO,
			"spring_angular_velocity": Vector3.ZERO,
			"previous_position": Vector3.ZERO,
			"previous_rotation": Vector3.ZERO,
			"wind_time": 0.0
		})

	# Load compute shader
	if not _load_compute_shader():
		push_error("GPUFurPhysicsManager: Failed to load compute shader")
		return false

	# Create buffers
	if not _create_buffers():
		push_error("GPUFurPhysicsManager: Failed to create buffers")
		return false

	# Create uniform set
	if not _create_uniform_set():
		push_error("GPUFurPhysicsManager: Failed to create uniform set")
		return false

	is_initialized = true
	return true

## Load and compile compute shader
func _load_compute_shader() -> bool:
	var shader_file := RDShaderFile.new()
	var shader_path := "res://addons/so_fluffy/shaders/fur_physics_compute.glsl"

	if not FileAccess.file_exists(shader_path):
		push_error("GPUFurPhysicsManager: Compute shader not found at " + shader_path)
		return false

	var err := shader_file.parse_versions({})
	if err != OK:
		push_error("GPUFurPhysicsManager: Failed to parse shader versions")
		return false

	var shader_spirv := shader_file.get_spirv()
	shader = rd.shader_create_from_spirv(shader_spirv)

	if not shader.is_valid():
		push_error("GPUFurPhysicsManager: Failed to create compute shader")
		return false

	pipeline = rd.compute_pipeline_create(shader)

	if not pipeline.is_valid():
		push_error("GPUFurPhysicsManager: Failed to create compute pipeline")
		return false

	return true

## Create GPU buffers
func _create_buffers() -> bool:
	# Physics state buffer (persistent, read/write)
	# Struct: 16 floats per instance (vec3 padded to vec4 x 7 + 1 float)
	var state_size := instance_count * 16 * 4  # 16 floats x 4 bytes
	var state_data := PackedFloat32Array()
	state_data.resize(instance_count * 16)
	state_data.fill(0.0)

	state_buffer = rd.storage_buffer_create(state_size, state_data.to_byte_array())
	if not state_buffer.is_valid():
		return false

	# Transform buffer (updated each frame)
	var transform_size := instance_count * 16 * 4  # mat4 = 16 floats
	var transform_data := PackedFloat32Array()
	transform_data.resize(instance_count * 16)
	# Initialize with identity matrices
	for i in range(instance_count):
		var base := i * 16
		transform_data[base + 0] = 1.0   # m[0][0]
		transform_data[base + 5] = 1.0   # m[1][1]
		transform_data[base + 10] = 1.0  # m[2][2]
		transform_data[base + 15] = 1.0  # m[3][3]

	transform_buffer = rd.storage_buffer_create(transform_size, transform_data.to_byte_array())
	if not transform_buffer.is_valid():
		return false

	# Config uniform buffer
	var config_size := 64  # 16 floats x 4 bytes (must be aligned to 16 bytes)
	var config_data := PackedFloat32Array()
	config_data.resize(16)
	_update_config_data(config_data)

	config_uniform = rd.uniform_buffer_create(config_size, config_data.to_byte_array())
	if not config_uniform.is_valid():
		return false

	# Results buffer (physics per shell, write-only from GPU)
	var total_shells := instance_count * shell_count
	var results_size := total_shells * 2 * 4 * 4  # 2 vec4s per shell (pos offset + rotation)
	var results_data := PackedFloat32Array()
	results_data.resize(total_shells * 8)
	results_data.fill(0.0)

	results_buffer = rd.storage_buffer_create(results_size, results_data.to_byte_array())
	if not results_buffer.is_valid():
		return false

	return true

## Update config data array
func _update_config_data(config_data: PackedFloat32Array) -> void:
	# PhysicsConfig struct layout (16 floats for alignment)
	config_data[0] = gravity.x
	config_data[1] = gravity.y
	config_data[2] = gravity.z
	config_data[3] = spring_constant

	config_data[4] = wind_direction.x
	config_data[5] = wind_direction.y
	config_data[6] = wind_direction.z
	config_data[7] = mass

	config_data[8] = damping
	config_data[9] = stretch
	config_data[10] = fur_length
	config_data[11] = stiffness

	config_data[12] = 1.0 if wind_enabled else 0.0
	config_data[13] = wind_strength
	config_data[14] = wind_turbulence
	config_data[15] = wind_speed

	# Note: Additional fields (rotational_physics_scale, delta_time, etc.)
	# would need expansion of this struct

## Create uniform set for bindings
func _create_uniform_set() -> bool:
	var uniforms: Array[RDUniform] = []

	# Binding 0: Physics state buffer (read/write)
	var state_uniform := RDUniform.new()
	state_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	state_uniform.binding = 0
	state_uniform.add_id(state_buffer)
	uniforms.append(state_uniform)

	# Binding 1: Transform buffer (read-only)
	var transform_uniform := RDUniform.new()
	transform_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	transform_uniform.binding = 1
	transform_uniform.add_id(transform_buffer)
	uniforms.append(transform_uniform)

	# Binding 2: Config uniform (read-only)
	var config_uniform_rd := RDUniform.new()
	config_uniform_rd.uniform_type = RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER
	config_uniform_rd.binding = 2
	config_uniform_rd.add_id(config_uniform)
	uniforms.append(config_uniform_rd)

	# Binding 3: Results buffer (write-only)
	var results_uniform := RDUniform.new()
	results_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	results_uniform.binding = 3
	results_uniform.add_id(results_buffer)
	uniforms.append(results_uniform)

	uniform_set = rd.uniform_set_create(uniforms, shader, 0)

	return uniform_set.is_valid()

## Update transforms for all instances
func update_transforms(transforms: Array[Transform3D]) -> void:
	if not is_initialized or rd == null:
		return

	var transform_data := PackedFloat32Array()
	transform_data.resize(instance_count * 16)

	for i in range(min(transforms.size(), instance_count)):
		var t: Transform3D = transforms[i]
		var base := i * 16

		# Column 0
		transform_data[base + 0] = t.basis.x.x
		transform_data[base + 1] = t.basis.x.y
		transform_data[base + 2] = t.basis.x.z
		transform_data[base + 3] = 0.0

		# Column 1
		transform_data[base + 4] = t.basis.y.x
		transform_data[base + 5] = t.basis.y.y
		transform_data[base + 6] = t.basis.y.z
		transform_data[base + 7] = 0.0

		# Column 2
		transform_data[base + 8] = t.basis.z.x
		transform_data[base + 9] = t.basis.z.y
		transform_data[base + 10] = t.basis.z.z
		transform_data[base + 11] = 0.0

		# Column 3 (position)
		transform_data[base + 12] = t.origin.x
		transform_data[base + 13] = t.origin.y
		transform_data[base + 14] = t.origin.z
		transform_data[base + 15] = 1.0

	# Update buffer
	rd.buffer_update(transform_buffer, 0, transform_data.size() * 4, transform_data.to_byte_array())

## Dispatch compute shader to calculate physics
func compute_physics(delta: float) -> void:
	if not is_initialized or rd == null:
		return

	# Update config with delta time
	var config_data := PackedFloat32Array()
	config_data.resize(20)  # Expanded for additional fields
	_update_config_data(config_data)
	config_data[16] = rotational_physics_scale
	config_data[17] = delta
	config_data[18] = 8.0  # exaggeration_factor
	config_data[19] = 0.0  # padding

	rd.buffer_update(config_uniform, 0, config_data.size() * 4, config_data.to_byte_array())

	# Create compute list
	var compute_list := rd.compute_list_begin()

	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)

	# Set push constants
	var push_constant := PackedInt32Array()
	push_constant.resize(4)
	push_constant[0] = instance_count
	push_constant[1] = shell_count
	push_constant[2] = instance_count * shell_count
	push_constant[3] = 0  # padding

	rd.compute_list_set_push_constant(compute_list, push_constant.to_byte_array(), push_constant.size() * 4)

	# Dispatch (workgroup size is 64, so dispatch ceil(instance_count / 64) groups)
	var workgroups := ceili(float(instance_count) / 64.0)
	rd.compute_list_dispatch(compute_list, workgroups, 1, 1)

	rd.compute_list_end()

	# Submit and sync (for now - can be async)
	rd.submit()
	rd.sync()

## Get physics results (for reading back to CPU if needed)
func get_physics_results() -> PackedFloat32Array:
	if not is_initialized or rd == null:
		return PackedFloat32Array()

	var total_shells := instance_count * shell_count
	var results_byte_array := rd.buffer_get_data(results_buffer)

	return results_byte_array.to_float32_array()

## Get results buffer RID for sharing with other shaders
func get_results_buffer_rid() -> RID:
	return results_buffer

## Cleanup
func cleanup() -> void:
	if rd == null:
		return

	if uniform_set.is_valid():
		rd.free_rid(uniform_set)
	if results_buffer.is_valid():
		rd.free_rid(results_buffer)
	if config_uniform.is_valid():
		rd.free_rid(config_uniform)
	if transform_buffer.is_valid():
		rd.free_rid(transform_buffer)
	if state_buffer.is_valid():
		rd.free_rid(state_buffer)
	if pipeline.is_valid():
		rd.free_rid(pipeline)
	if shader.is_valid():
		rd.free_rid(shader)

	is_initialized = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		cleanup()
