## Fur Preset Resource
## Stores complete fur configuration for easy reuse and sharing
class_name FurPreset
extends Resource

## Preset metadata
@export var preset_name: String = "Custom"
@export_multiline var description: String = ""
@export var author: String = ""

## Rendering
@export_enum("Material Cascade:0", "GPU Instancing:1")
var rendering_mode: int = 0

## Shells and LOD
@export_range(8, 256, 1)
var number_of_shells: int = 64

@export var lod_enabled: bool = false
@export var lod_min_distance: float = 3.0
@export var lod_max_distance: float = 25.0
@export var lod_minimum_shells: int = 8

## Distribution
@export_enum("Linear:0", "Quadratic:1", "Exponential:2", "Custom:3")
var distribution_mode: int = 1
@export_range(1.0, 4.0, 0.1)
var distribution_bias: float = 2.0

## Performance
@export var use_texture_atlas: bool = true
@export var use_simplified_inner_shaders: bool = true
@export_range(0.0, 1.0, 0.05)
var detailed_shader_threshold: float = 0.6
@export var culling_enabled: bool = true
@export_enum("None:0", "Frustum:1", "Occlusion:2", "Aggressive:3")
var culling_mode: int = 1

## Shape and Growth
@export var length: float = 0.1
@export var density: float = 0.5
@export var scruffiness: float = 0.5
@export var thickness_scale: float = 1.5
@export var thickness_curve: CurveTexture

## Growth Direction
@export_range(0, 1, 0.005)
var normal_strength: float = 1.0
@export var static_direction_local: Vector3 = Vector3.ZERO
@export var static_direction_world: Vector3 = Vector3.ZERO

## Turbulence
@export var turbulence_texture: Texture2D
@export var turbulence_strength: float = 0.3
@export var jitter_texture: Texture2D
@export var jitter_strength: float = 0.0

## Curls
@export var curls_enabled: bool = false
@export var curls_twist: float = 48.0
@export var curls_fill: float = PI / 4.0

## Appearance
@export var albedo_color: Color = Color.WHITE
@export var albedo_texture: Texture2D
@export var height_gradient: GradientTexture2D
@export var scale_height_gradient: bool = false
@export var render_skin: bool = false

## Emission
@export var use_emission: bool = false
@export var emission_color: Color = Color.BLACK
@export var emission_energy_multiplier: float = 1.0
@export var emission_texture: Texture2D

## Ambient Occlusion
@export var ao_enabled: bool = false
@export var ao_strength: float = 0.7
@export var ao_density_influence: float = 0.5
@export var ao_depth_falloff: float = 2.0
@export var ao_color: Color = Color(0.3, 0.25, 0.2)
@export var ao_multi_sample: bool = false
@export var ao_samples: int = 4
@export var ao_sample_radius: float = 0.05
@export var self_shadow_enabled: bool = false
@export var self_shadow_strength: float = 0.5
@export var self_shadow_falloff: float = 3.0

## Physics
@export var physics_enabled: bool = true
@export var gravity: Vector3 = Vector3.ZERO
@export var spring_constant: float = 80.0
@export var mass: float = 0.15
@export var damping: float = 3.0
@export var stretch: float = 1.0
@export var stiffness: float = 1.0
@export var rotational_physics_scale: float = 1.0

## Multi-layer (if used)
@export var multilayer_enabled: bool = false
@export var fur_layers: Array[FurLayer] = []
@export_enum("Composite:0", "Replace:1", "Additive:2", "Max:3")
var layer_blend_mode: int = 0

## Apply this preset to a Fur node
func apply_to_fur_node(fur_node: Node) -> void:
	if fur_node == null:
		return

	# Rendering
	fur_node.rendering_mode = rendering_mode

	# Shells and LOD
	fur_node.number_of_shells = number_of_shells
	fur_node.lod_enabled = lod_enabled
	fur_node.lod_min_distance = lod_min_distance
	fur_node.lod_max_distance = lod_max_distance
	fur_node.lod_minimum_shells = lod_minimum_shells

	# Distribution
	fur_node.distribution_mode = distribution_mode
	fur_node.distribution_bias = distribution_bias

	# Performance
	fur_node.use_texture_atlas = use_texture_atlas
	fur_node.use_simplified_inner_shaders = use_simplified_inner_shaders
	fur_node.detailed_shader_threshold = detailed_shader_threshold
	fur_node.culling_enabled = culling_enabled
	fur_node.culling_mode = culling_mode

	# Shape and Growth
	fur_node.length = length
	fur_node.density = density
	fur_node.scruffiness = scruffiness
	fur_node.thickness_scale = thickness_scale
	if thickness_curve:
		fur_node.thickness_curve = thickness_curve

	# Growth Direction
	fur_node.normal_strength = normal_strength
	fur_node.static_direction_local = static_direction_local
	fur_node.static_direction_world = static_direction_world

	# Turbulence
	if turbulence_texture:
		fur_node.turbulence_texture = turbulence_texture
	fur_node.turbulence_strength = turbulence_strength
	if jitter_texture:
		fur_node.jitter_texture = jitter_texture
	fur_node.jitter_strength = jitter_strength

	# Curls
	fur_node.curls_enabled = curls_enabled
	fur_node.curls_twist = curls_twist
	fur_node.curls_fill = curls_fill

	# Appearance
	fur_node.albedo_color = albedo_color
	if albedo_texture:
		fur_node.albedo_texture = albedo_texture
	if height_gradient:
		fur_node.height_gradient = height_gradient
	fur_node.scale_height_gradient = scale_height_gradient
	fur_node.render_skin = render_skin

	# Emission
	fur_node.use_emission = use_emission
	fur_node.emission_color = emission_color
	fur_node.emission_energy_multiplier = emission_energy_multiplier
	if emission_texture:
		fur_node.emission_texture = emission_texture

	# Ambient Occlusion
	fur_node.ao_enabled = ao_enabled
	fur_node.ao_strength = ao_strength
	fur_node.ao_density_influence = ao_density_influence
	fur_node.ao_depth_falloff = ao_depth_falloff
	fur_node.ao_color = ao_color
	fur_node.ao_multi_sample = ao_multi_sample
	fur_node.ao_samples = ao_samples
	fur_node.ao_sample_radius = ao_sample_radius
	fur_node.self_shadow_enabled = self_shadow_enabled
	fur_node.self_shadow_strength = self_shadow_strength
	fur_node.self_shadow_falloff = self_shadow_falloff

	# Physics
	fur_node.physics_enabled = physics_enabled
	fur_node.gravity = gravity
	fur_node.spring_constant = spring_constant
	fur_node.mass = mass
	fur_node.damping = damping
	fur_node.stretch = stretch
	fur_node.stiffness = stiffness
	fur_node.rotational_physics_scale = rotational_physics_scale

	# Multi-layer
	fur_node.multilayer_enabled = multilayer_enabled
	if multilayer_enabled and fur_layers.size() > 0:
		fur_node.fur_layers = fur_layers.duplicate()
	fur_node.layer_blend_mode = layer_blend_mode

## Create preset from existing Fur node
static func create_from_fur_node(fur_node: Node, name: String = "Custom") -> FurPreset:
	var preset = FurPreset.new()
	preset.preset_name = name

	# Copy all properties
	preset.rendering_mode = fur_node.rendering_mode
	preset.number_of_shells = fur_node.number_of_shells
	preset.lod_enabled = fur_node.lod_enabled
	preset.lod_min_distance = fur_node.lod_min_distance
	preset.lod_max_distance = fur_node.lod_max_distance
	preset.lod_minimum_shells = fur_node.lod_minimum_shells
	preset.distribution_mode = fur_node.distribution_mode
	preset.distribution_bias = fur_node.distribution_bias
	preset.use_texture_atlas = fur_node.use_texture_atlas
	preset.use_simplified_inner_shaders = fur_node.use_simplified_inner_shaders
	preset.detailed_shader_threshold = fur_node.detailed_shader_threshold
	preset.culling_enabled = fur_node.culling_enabled
	preset.culling_mode = fur_node.culling_mode
	preset.length = fur_node.length
	preset.density = fur_node.density
	preset.scruffiness = fur_node.scruffiness
	preset.thickness_scale = fur_node.thickness_scale
	preset.thickness_curve = fur_node.thickness_curve
	preset.normal_strength = fur_node.normal_strength
	preset.static_direction_local = fur_node.static_direction_local
	preset.static_direction_world = fur_node.static_direction_world
	preset.turbulence_texture = fur_node.turbulence_texture
	preset.turbulence_strength = fur_node.turbulence_strength
	preset.jitter_texture = fur_node.jitter_texture
	preset.jitter_strength = fur_node.jitter_strength
	preset.curls_enabled = fur_node.curls_enabled
	preset.curls_twist = fur_node.curls_twist
	preset.curls_fill = fur_node.curls_fill
	preset.albedo_color = fur_node.albedo_color
	preset.albedo_texture = fur_node.albedo_texture
	preset.height_gradient = fur_node.height_gradient
	preset.scale_height_gradient = fur_node.scale_height_gradient
	preset.render_skin = fur_node.render_skin
	preset.use_emission = fur_node.use_emission
	preset.emission_color = fur_node.emission_color
	preset.emission_energy_multiplier = fur_node.emission_energy_multiplier
	preset.emission_texture = fur_node.emission_texture
	preset.ao_enabled = fur_node.ao_enabled
	preset.ao_strength = fur_node.ao_strength
	preset.ao_density_influence = fur_node.ao_density_influence
	preset.ao_depth_falloff = fur_node.ao_depth_falloff
	preset.ao_color = fur_node.ao_color
	preset.ao_multi_sample = fur_node.ao_multi_sample
	preset.ao_samples = fur_node.ao_samples
	preset.ao_sample_radius = fur_node.ao_sample_radius
	preset.self_shadow_enabled = fur_node.self_shadow_enabled
	preset.self_shadow_strength = fur_node.self_shadow_strength
	preset.self_shadow_falloff = fur_node.self_shadow_falloff
	preset.physics_enabled = fur_node.physics_enabled
	preset.gravity = fur_node.gravity
	preset.spring_constant = fur_node.spring_constant
	preset.mass = fur_node.mass
	preset.damping = fur_node.damping
	preset.stretch = fur_node.stretch
	preset.stiffness = fur_node.stiffness
	preset.rotational_physics_scale = fur_node.rotational_physics_scale
	preset.multilayer_enabled = fur_node.multilayer_enabled
	preset.fur_layers = fur_node.fur_layers.duplicate() if fur_node.fur_layers else []
	preset.layer_blend_mode = fur_node.layer_blend_mode

	return preset

## ===== BUILT-IN PRESETS =====

## Short cat fur - realistic domestic cat
static func cat_short() -> FurPreset:
	var preset = FurPreset.new()
	preset.preset_name = "Cat (Short)"
	preset.description = "Short domestic cat fur with soft undercoat"

	preset.number_of_shells = 48
	preset.length = 0.08
	preset.density = 1.2
	preset.scruffiness = 0.4
	preset.thickness_scale = 1.3
	preset.distribution_mode = 1  # Quadratic
	preset.distribution_bias = 2.5

	preset.albedo_color = Color(0.85, 0.75, 0.65)
	preset.ao_enabled = true
	preset.ao_strength = 0.6
	preset.ao_depth_falloff = 2.0

	preset.physics_enabled = true
	preset.spring_constant = 100.0
	preset.stiffness = 1.2

	return preset

## Long cat fur - fluffy persian/maine coon
static func cat_long() -> FurPreset:
	var preset = FurPreset.new()
	preset.preset_name = "Cat (Long/Fluffy)"
	preset.description = "Long fluffy cat fur (Persian, Maine Coon, etc.)"

	preset.multilayer_enabled = true
	var undercoat = FurLayer.new()
	undercoat.layer_name = "Undercoat"
	undercoat.shell_count = 32
	undercoat.length = 0.06
	undercoat.density = 2.0
	undercoat.thickness_scale = 0.7
	undercoat.albedo_color = Color(0.92, 0.88, 0.82)

	var guard = FurLayer.new()
	guard.layer_name = "Guard Hairs"
	guard.shell_count = 56
	guard.length = 0.18
	guard.density = 0.4
	guard.thickness_scale = 2.0
	guard.scruffiness = 0.9
	guard.albedo_color = Color(0.75, 0.68, 0.60)

	preset.fur_layers = [undercoat, guard]
	preset.distribution_mode = 1
	preset.distribution_bias = 2.8

	preset.ao_enabled = true
	preset.ao_strength = 0.75
	preset.ao_depth_falloff = 2.3
	preset.self_shadow_enabled = true
	preset.self_shadow_strength = 0.5

	return preset

## Dog fur - medium length
static func dog_medium() -> FurPreset:
	var preset = FurPreset.new()
	preset.preset_name = "Dog (Medium)"
	preset.description = "Medium length dog fur (Golden Retriever, etc.)"

	preset.number_of_shells = 56
	preset.length = 0.12
	preset.density = 0.8
	preset.scruffiness = 0.6
	preset.thickness_scale = 1.6
	preset.distribution_mode = 1
	preset.distribution_bias = 2.3

	preset.albedo_color = Color(0.78, 0.68, 0.52)
	preset.ao_enabled = true
	preset.ao_strength = 0.65

	preset.physics_enabled = true
	preset.spring_constant = 70.0
	preset.mass = 0.2
	preset.stiffness = 0.9

	return preset

## Grass - short ground cover
static func grass_short() -> FurPreset:
	var preset = FurPreset.new()
	preset.preset_name = "Grass (Short)"
	preset.description = "Short grass for lawns and fields"

	preset.number_of_shells = 32
	preset.length = 0.06
	preset.density = 2.5
	preset.scruffiness = 0.3
	preset.thickness_scale = 0.8
	preset.distribution_mode = 1
	preset.distribution_bias = 2.0

	preset.static_direction_world = Vector3.UP
	preset.normal_strength = 0.2

	preset.albedo_color = Color(0.3, 0.6, 0.25)
	preset.ao_enabled = true
	preset.ao_strength = 0.5
	preset.ao_color = Color(0.2, 0.3, 0.15)

	preset.physics_enabled = true
	preset.gravity = Vector3(0, -2, 0)
	preset.spring_constant = 120.0
	preset.stiffness = 0.4

	return preset

## Grass - tall swaying
static func grass_tall() -> FurPreset:
	var preset = FurPreset.new()
	preset.preset_name = "Grass (Tall)"
	preset.description = "Tall swaying grass for fields and plains"

	preset.number_of_shells = 48
	preset.length = 0.20
	preset.density = 1.2
	preset.scruffiness = 0.8
	preset.thickness_scale = 1.1
	preset.distribution_mode = 2  # Exponential
	preset.distribution_bias = 2.5

	preset.static_direction_world = Vector3.UP
	preset.normal_strength = 0.15

	preset.albedo_color = Color(0.35, 0.65, 0.28)
	preset.ao_enabled = true
	preset.ao_strength = 0.6

	preset.physics_enabled = true
	preset.gravity = Vector3(0, -1.5, 0)
	preset.spring_constant = 40.0
	preset.mass = 0.08
	preset.damping = 2.0
	preset.stiffness = 0.3

	return preset

## Moss/Fuzz - very short dense
static func moss() -> FurPreset:
	var preset = FurPreset.new()
	preset.preset_name = "Moss/Fuzz"
	preset.description = "Very short dense moss or fuzzy surface"

	preset.number_of_shells = 24
	preset.length = 0.03
	preset.density = 3.0
	preset.scruffiness = 0.2
	preset.thickness_scale = 0.6
	preset.distribution_mode = 1
	preset.distribution_bias = 1.8

	preset.albedo_color = Color(0.25, 0.45, 0.25)
	preset.ao_enabled = true
	preset.ao_strength = 0.7
	preset.ao_depth_falloff = 1.5

	preset.physics_enabled = false

	return preset

## Fox - thick bushy
static func fox() -> FurPreset:
	var preset = FurPreset.new()
	preset.preset_name = "Fox"
	preset.description = "Thick bushy fox fur"

	preset.multilayer_enabled = true
	var undercoat = FurLayer.new()
	undercoat.layer_name = "Dense Undercoat"
	undercoat.shell_count = 40
	undercoat.length = 0.07
	undercoat.density = 1.8
	undercoat.thickness_scale = 0.8
	undercoat.albedo_color = Color(0.88, 0.82, 0.75)

	var guard = FurLayer.new()
	guard.layer_name = "Guard Hairs"
	guard.shell_count = 64
	guard.length = 0.16
	guard.density = 0.5
	guard.thickness_scale = 2.2
	guard.scruffiness = 0.7
	guard.albedo_color = Color(0.85, 0.45, 0.25)

	preset.fur_layers = [undercoat, guard]
	preset.distribution_mode = 1
	preset.distribution_bias = 3.0

	preset.ao_enabled = true
	preset.ao_strength = 0.72
	preset.self_shadow_enabled = true

	return preset

## Performance optimized - many creatures
static func performance_optimized() -> FurPreset:
	var preset = FurPreset.new()
	preset.preset_name = "Performance (Optimized)"
	preset.description = "Optimized for many furry creatures in scene"

	preset.rendering_mode = 1  # Instanced
	preset.number_of_shells = 48
	preset.length = 0.08
	preset.density = 0.6
	preset.distribution_mode = 1
	preset.distribution_bias = 2.5

	preset.use_texture_atlas = true
	preset.use_simplified_inner_shaders = true
	preset.culling_enabled = true
	preset.culling_mode = 2  # Occlusion

	preset.lod_enabled = true
	preset.lod_min_distance = 8.0
	preset.lod_max_distance = 40.0

	preset.ao_enabled = true
	preset.ao_strength = 0.5
	preset.ao_multi_sample = false

	return preset

## Maximum quality - hero character
static func maximum_quality() -> FurPreset:
	var preset = FurPreset.new()
	preset.preset_name = "Quality (Maximum)"
	preset.description = "Maximum quality for hero characters"

	preset.rendering_mode = 0  # Cascade for quality
	preset.number_of_shells = 128
	preset.distribution_mode = 1
	preset.distribution_bias = 2.8

	preset.use_simplified_inner_shaders = true
	preset.detailed_shader_threshold = 0.7

	preset.ao_enabled = true
	preset.ao_strength = 0.75
	preset.ao_multi_sample = true
	preset.ao_samples = 8
	preset.self_shadow_enabled = true
	preset.self_shadow_strength = 0.7

	preset.curls_enabled = false  # Enable if needed

	return preset
