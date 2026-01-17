## Compute Shader Preprocessor for Fur System
## Pre-generates noise patterns on GPU for massive performance improvement
## Instead of calculating noise per-fragment per-shell, we calculate once and reuse
class_name FurComputePreprocessor
extends RefCounted

## Rendering device
var rd: RenderingDevice

## Compute shader and pipeline
var shader: RID
var pipeline: RID

## Output texture
var output_texture: Texture2D
var output_image: RID

## Configuration
var enabled: bool = false
var texture_size: int = 1024
var noise_type: int = 0  # 0=gold, 1=perlin, 2=simplex

## Parameters for compute shader
var seed: int = 0
var density: float = 1.0
var scruffiness: float = 0.5
var turbulence_scale: float = 2.0
var jitter_scale: float = 1.0

func _init():
	# Check if compute shaders are supported
	rd = RenderingServer.get_rendering_device()
	if rd == null:
		push_warning("FurComputePreprocessor: RenderingDevice not available (possibly Forward Mobile renderer)")
		enabled = false
		return

	enabled = true

## Initialize compute shader
func initialize() -> bool:
	if not enabled or rd == null:
		return false

	# Load and compile compute shader
	var shader_file = load("res://addons/so_fluffy/shaders/noise_compute.glsl")
	if shader_file == null:
		push_error("FurComputePreprocessor: Could not load compute shader")
		return false

	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
	if shader_spirv == null:
		push_error("FurComputePreprocessor: Failed to get SPIR-V from shader")
		return false

	shader = rd.shader_create_from_spirv(shader_spirv)
	if not shader.is_valid():
		push_error("FurComputePreprocessor: Failed to create shader")
		return false

	pipeline = rd.compute_pipeline_create(shader)
	if not pipeline.is_valid():
		push_error("FurComputePreprocessor: Failed to create compute pipeline")
		return false

	return true

## Generate noise texture using compute shader
func generate_noise_texture(
	p_seed: int,
	p_density: float,
	p_scruffiness: float,
	size: int = 1024
) -> Texture2D:

	if not enabled or rd == null:
		push_warning("FurComputePreprocessor: Not enabled, returning null")
		return null

	# Store parameters
	seed = p_seed
	density = p_density
	scruffiness = p_scruffiness
	texture_size = size

	# Create output texture format
	var fmt := RDTextureFormat.new()
	fmt.width = texture_size
	fmt.height = texture_size
	fmt.format = RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT
	fmt.usage_bits = RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | \
					  RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT | \
					  RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT

	# Create texture
	output_image = rd.texture_create(fmt, RDTextureView.new())
	if not output_image.is_valid():
		push_error("FurComputePreprocessor: Failed to create output texture")
		return null

	# Create uniform set for compute shader
	var uniform_set = _create_uniform_set()
	if uniform_set == null or not uniform_set.is_valid():
		push_error("FurComputePreprocessor: Failed to create uniform set")
		return null

	# Run compute shader
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)

	# Dispatch compute shader (workgroups of 8x8)
	var workgroup_count_x = int(ceil(float(texture_size) / 8.0))
	var workgroup_count_y = int(ceil(float(texture_size) / 8.0))
	rd.compute_list_dispatch(compute_list, workgroup_count_x, workgroup_count_y, 1)

	rd.compute_list_end()

	# Submit and wait for completion
	rd.submit()
	rd.sync()

	# Read back texture data
	var byte_data: PackedByteArray = rd.texture_get_data(output_image, 0)

	# Create Godot texture from data
	var img := Image.create_from_data(
		texture_size,
		texture_size,
		false,
		Image.FORMAT_RGBAH,
		byte_data
	)

	output_texture = ImageTexture.create_from_image(img)

	# Cleanup
	rd.free_rid(uniform_set)

	return output_texture

## Create uniform set for compute shader
func _create_uniform_set() -> RID:
	# Uniform 0: Output texture
	var output_uniform := RDUniform.new()
	output_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	output_uniform.binding = 0
	output_uniform.add_id(output_image)

	# Uniform 1: Parameters buffer
	var params_buffer = _create_params_buffer()
	var params_uniform := RDUniform.new()
	params_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER
	params_uniform.binding = 1
	params_uniform.add_id(params_buffer)

	var uniforms := [output_uniform, params_uniform]
	return rd.uniform_set_create(uniforms, shader, 0)

## Create parameters buffer for compute shader
func _create_params_buffer() -> RID:
	# Pack parameters into byte array
	# Layout matches shader uniform block (32-byte aligned)
	var params := PackedByteArray()

	# int seed
	params.append_array(_pack_int(seed))

	# float density
	params.append_array(_pack_float(density))

	# float scruffiness
	params.append_array(_pack_float(scruffiness))

	# int texture_size
	params.append_array(_pack_int(texture_size))

	# float turbulence_scale
	params.append_array(_pack_float(turbulence_scale))

	# float jitter_scale
	params.append_array(_pack_float(jitter_scale))

	# int noise_type
	params.append_array(_pack_int(noise_type))

	# float padding (for alignment)
	params.append_array(_pack_float(0.0))

	# Create uniform buffer
	return rd.uniform_buffer_create(params.size(), params)

## Pack int32 to bytes (little endian)
func _pack_int(value: int) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(4)
	bytes.encode_s32(0, value)
	return bytes

## Pack float32 to bytes (little endian)
func _pack_float(value: float) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(4)
	bytes.encode_float(0, value)
	return bytes

## Cleanup resources
func cleanup() -> void:
	if rd == null:
		return

	if output_image.is_valid():
		rd.free_rid(output_image)

	if pipeline.is_valid():
		rd.free_rid(pipeline)

	if shader.is_valid():
		rd.free_rid(shader)

## Check if compute preprocessing is available
static func is_supported() -> bool:
	var device = RenderingServer.get_rendering_device()
	return device != null

## Get estimated performance benefit
static func get_performance_benefit(shell_count: int) -> Dictionary:
	# Traditional: noise calculated per fragment per shell
	# Compute: noise calculated once, sampled per shell

	# Assume 1M fragments per shell (typical for medium detail mesh)
	var fragments_per_shell = 1_000_000
	var traditional_noise_calls = fragments_per_shell * shell_count

	# With compute: just texture samples (much cheaper)
	var compute_noise_calls = fragments_per_shell  # Generated once
	var compute_texture_samples = fragments_per_shell * shell_count  # Just sampling

	# Noise calculation is ~20x more expensive than texture sample
	var noise_cost_multiplier = 20.0

	var traditional_cost = traditional_noise_calls * noise_cost_multiplier
	var compute_cost = compute_noise_calls * noise_cost_multiplier + compute_texture_samples

	var speedup = traditional_cost / compute_cost

	return {
		"traditional_noise_calculations": traditional_noise_calls,
		"compute_noise_calculations": compute_noise_calls,
		"theoretical_speedup": speedup,
		"estimated_fps_gain": (speedup - 1.0) * 100.0,
		"memory_cost_mb": (1024 * 1024 * 8) / (1024.0 * 1024.0)  # RGBA16F texture
	}

## Test compute shader with simple parameters
static func test() -> bool:
	var preprocessor = FurComputePreprocessor.new()

	if not preprocessor.enabled:
		print("Compute shaders not supported")
		return false

	if not preprocessor.initialize():
		print("Failed to initialize compute shader")
		return false

	var texture = preprocessor.generate_noise_texture(12345, 1.0, 0.5, 512)

	if texture == null:
		print("Failed to generate texture")
		return false

	print("Success! Generated ", texture.get_width(), "x", texture.get_height(), " texture")
	preprocessor.cleanup()
	return true
