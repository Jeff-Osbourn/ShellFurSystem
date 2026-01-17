@tool
extends Node

## Modular Shell Fur System for Godot 4.5
## Improved with texture atlasing, adaptive shell distribution, simplified inner shaders, and shell culling

## ===== PREVIEW =====

## Show fur in editor. Fur rendering is relatively expensive, so it is recommended to disable this when not needed.
@export
var preview_in_editor: bool = true:
	set(v):
		preview_in_editor = v
		if Engine.is_editor_hint():
			_rebuild_fur()

## ===== TARGETING =====

@export_group("Targeting")

## Indices of surfaces to apply fur to. If empty, fur is applied to the entire mesh as a single overlay Material.
@export var target_surfaces: Array[int] = []:
	set(v):
		target_surfaces = v
		_rebuild_fur()

## ===== SHELLS AND LOD =====

@export_group("Shells and LOD")

## Number of shells to generate. Higher numbers look better, but incur larger performance penalties.
@export var number_of_shells: int = 64:
	set(v):
		number_of_shells = v
		if lod_manager:
			lod_manager.set_total_shells(number_of_shells)
		_rebuild_fur()

## Enable or disable dynamic LOD. If disabled, fur will always be rendered with the maximum number of shells.
@export var lod_enabled: bool = false:
	set(v):
		lod_enabled = v
		if lod_manager:
			lod_manager.lod_enabled = lod_enabled
		_update_lod()
		notify_property_list_changed()

## Minimum distance from the camera at which lower-detail LODs are used.
@export_range(0, 10, 0.01, "or_greater")
var lod_min_distance: float = 3.0:
	set(v):
		lod_min_distance = v
		if lod_manager:
			lod_manager.lod_min_distance = lod_min_distance

## Distance from the camera at which the lowest level LOD is used.
@export_range(0, 50, 0.01, "or_greater")
var lod_max_distance: float = 25.0:
	set(v):
		lod_max_distance = v
		if lod_manager:
			lod_manager.lod_max_distance = lod_max_distance

## Number of shells to use for the lowest-quality LOD.
@export_range(8, 256, 1, "or_greater")
var lod_minimum_shells: int = 8:
	set(v):
		lod_minimum_shells = v
		if lod_manager:
			lod_manager.lod_minimum_shells = lod_minimum_shells

## ===== ADAPTIVE SHELL DISTRIBUTION =====

@export_subgroup("Adaptive Distribution")

## Shell distribution mode: LINEAR (traditional), QUADRATIC (denser near surface), EXPONENTIAL (very dense near surface)
@export_enum("Linear:0", "Quadratic:1", "Exponential:2", "Custom:3")
var distribution_mode: int = 1:  # Default to QUADRATIC
	set(v):
		distribution_mode = v
		if lod_manager:
			lod_manager.set_distribution_mode(v, distribution_bias)
		_update_materials()

## Distribution bias - controls density falloff (1.0 = linear, >1 = denser near surface)
@export_range(1.0, 4.0, 0.1)
var distribution_bias: float = 2.0:
	set(v):
		distribution_bias = v
		if lod_manager:
			lod_manager.set_distribution_mode(distribution_mode, distribution_bias)
		_update_materials()

## ===== PERFORMANCE =====

@export_subgroup("Performance Optimizations")

## Enable texture atlas optimization (combines multiple textures into one)
@export var use_texture_atlas: bool = true:
	set(v):
		use_texture_atlas = v
		if material_manager:
			material_manager.use_texture_atlas = use_texture_atlas
		_update_materials()

## Enable simplified shaders for inner shells (major performance boost)
@export var use_simplified_inner_shaders: bool = true:
	set(v):
		use_simplified_inner_shaders = v
		_rebuild_fur()

## Threshold for detailed shader (shells above this height use full shader)
@export_range(0.0, 1.0, 0.05)
var detailed_shader_threshold: float = 0.6:
	set(v):
		detailed_shader_threshold = v
		if material_manager:
			material_manager.detailed_shell_threshold = detailed_shader_threshold
		_rebuild_fur()

## Enable shell culling system
@export var culling_enabled: bool = true:
	set(v):
		culling_enabled = v
		if culling_manager:
			culling_manager.culling_enabled = culling_enabled

## Culling mode: NONE, FRUSTUM (recommended), OCCLUSION, AGGRESSIVE
@export_enum("None:0", "Frustum:1", "Occlusion:2", "Aggressive:3")
var culling_mode: int = 1:  # Default to FRUSTUM
	set(v):
		culling_mode = v
		if culling_manager:
			culling_manager.culling_mode = v

## ===== SHAPE AND GROWTH =====

@export_group("Shape and Growth")

## Strand length
@export_range(0, 2, 0.01, "or_greater")
var length: float = 0.1:
	set(v):
		length = v
		if culling_manager:
			culling_manager.set_fur_length(length)
		if physics_manager:
			physics_manager.fur_length = length
		_update_materials()

## Scaling of the fur density - strands per area.
@export_range(0.010, 3, 0.001, "or_greater")
var density: float = 0.5:
	set(v):
		density = v
		_update_materials()

## Seed for fur noise random generator
@export var seed: int = RandomNumberGenerator.new().randi_range(0, 65535):
	set(v):
		seed = v
		_update_materials()

## Variation of the height distribution of strands.
@export_range(0.0, 4, 0.001, "or_greater")
var scruffiness: float = 0.5:
	set(v):
		scruffiness = v
		_update_materials()

## Fur heightmap texture. Values scale hair length by [1..0]. Black pixels are not rendered.
@export var heightmap_texture: Texture2D:
	set(v):
		heightmap_texture = v
		_rebuild_texture_atlas()
		_update_materials()

@export_subgroup("Strand Thickness")

## Thickness profile of a single strand.
@export var thickness_curve: CurveTexture:
	set(v):
		thickness_curve = v
		_update_materials()

## Uniformly scales the thickness of all strands.
@export_range(0.01, 4.0, 0.01, "or_greater")
var thickness_scale: float = 1.5:
	set(v):
		thickness_scale = v
		_update_materials()

@export_subgroup("Curls")

## Turn curls rendering on or off. Curls are quite expensive to render.
@export var curls_enabled: bool = false:
	set(v):
		curls_enabled = v
		_update_materials()
		notify_property_list_changed()

@export_range(0, 128, 0.01, "or_greater")
var curls_twist: float = 48.0:
	set(v):
		curls_twist = v
		_update_materials()

@export_range(0, 2 * PI, 0.01, "or_greater")
var curls_fill: float = PI / 4.0:
	set(v):
		curls_fill = v
		_update_materials()

@export_subgroup("Turbulence and Jitter")

## Noise texture to overlay displacement turbulence on the fur.
@export var turbulence_texture: Texture2D = preload("res://addons/so_fluffy/turbulence_default.tres"):
	set(v):
		turbulence_texture = v
		_rebuild_texture_atlas()
		_update_materials()

## Strength of the turbulence effect.
@export_range(0, 1, 0.001, "or_greater")
var turbulence_strength: float = 0.3:
	set(v):
		turbulence_strength = v
		_update_materials()

## Noise texture to add high-frequency jitter on the fur.
@export var jitter_texture: Texture2D = preload("res://addons/so_fluffy/turbulence_default.tres"):
	set(v):
		jitter_texture = v
		_rebuild_texture_atlas()
		_update_materials()

## Strength of the jitter effect.
@export_range(0, 1, 0.001, "or_greater")
var jitter_strength: float = 0.0:
	set(v):
		jitter_strength = v
		_update_materials()

@export_subgroup("Growth Direction")

## Blends the fur growth direction between the surface normal and the static directions.
@export_range(0, 1, 0.005)
var normal_strength: float = 1.0:
	set(v):
		normal_strength = v
		_update_materials()

## Static direction of fur growth in object space.
@export var static_direction_local: Vector3 = Vector3.ZERO:
	set(v):
		static_direction_local = v
		_update_materials()

## Static direction of fur growth in world space.
@export var static_direction_world: Vector3 = Vector3.ZERO:
	set(v):
		static_direction_world = v
		_update_materials()

## ===== APPEARANCE =====

@export_group("Appearance")

## Albedo color is multiplied by this gradient, sampled by relative height.
@export var height_gradient: GradientTexture2D:
	set(v):
		height_gradient = v
		_update_materials()

## Should the height gradient be scaled with the length of individual strands?
@export var scale_height_gradient: bool = false:
	set(v):
		scale_height_gradient = v
		_update_materials()

## If enabled, all pixels on shell 0 are rendered.
@export var render_skin: bool = false:
	set(v):
		render_skin = v
		_update_materials()

@export_subgroup("Albedo")

## Plain hair color
@export_color_no_alpha
var albedo_color: Color = Color.LIGHT_BLUE:
	set(v):
		albedo_color = v
		_update_materials()

## Texture defining hair color.
@export var albedo_texture: Texture2D:
	set(v):
		albedo_texture = v
		_update_materials()

@export_subgroup("Emission")

## Enable emission
@export var use_emission: bool = false:
	set(v):
		use_emission = v
		_update_materials()
		notify_property_list_changed()

## Uniform emission color
@export_color_no_alpha
var emission_color: Color:
	set(v):
		emission_color = v
		_update_materials()

## Emission energy multiplier.
@export_range(0, 16, 0.01)
var emission_energy_multiplier: float = 1.0:
	set(v):
		emission_energy_multiplier = v
		_update_materials()

## Texture defining emission color.
@export var emission_texture: Texture2D:
	set(v):
		emission_texture = v
		_update_materials()

## ===== PHYSICS =====

@export_group("Physics")

## Disable physics processing altogether.
@export var physics_enabled: bool = true:
	set(v):
		physics_enabled = v
		if physics_manager:
			physics_manager.physics_enabled = physics_enabled
			if not physics_enabled:
				physics_manager.reset()
		notify_property_list_changed()

## Simulate physics in the editor.
@export var physics_preview: bool = true:
	set(v):
		physics_preview = v
		if physics_manager:
			physics_manager.physics_preview = physics_preview

## Adjust the magnitude of rotational physics effects
@export var rotational_physics_scale: float = 1.0:
	set(v):
		rotational_physics_scale = v
		if physics_manager:
			physics_manager.rotational_physics_scale = rotational_physics_scale

## Gravity constant
@export var gravity: Vector3 = Vector3(0, 0, 0):
	set(v):
		gravity = v
		if physics_manager:
			physics_manager.gravity = gravity

## Strand spring constant
@export var spring_constant: float = 80:
	set(v):
		spring_constant = v
		if physics_manager:
			physics_manager.spring_constant = spring_constant

## Strand mass
@export var mass: float = 0.15:
	set(v):
		mass = v
		if physics_manager:
			physics_manager.mass = mass

## Spring damping
@export var damping: float = 3:
	set(v):
		damping = v
		if physics_manager:
			physics_manager.damping = damping

## Allow strand to stretch beyond its length.
@export_range(1, 2, 0.01, "or_greater")
var stretch: float = 1.0:
	set(v):
		stretch = v
		if physics_manager:
			physics_manager.stretch = stretch

## Controls how stiff the strands are over their length.
@export_range(0, 4, 0.01, "or_greater")
var stiffness: float = 1.0:
	set(v):
		stiffness = v
		if physics_manager:
			physics_manager.stiffness = stiffness

## ===== INTERNAL STATE =====

# Managers
var lod_manager: FurLODManager
var material_manager: FurMaterialManager
var physics_manager: FurPhysicsManager
var culling_manager: FurCullingManager

# The geometry we're growing fur on
var mesh: GeometryInstance3D

func _validate_property(property: Dictionary):
	# Hide/show emission section details
	if property.name in ["emission_color", "emission_energy_multiplier", "emission_texture"] and not use_emission:
		property.usage = PROPERTY_USAGE_NO_EDITOR
	# Hide/show curls section details
	if property.name in ["curls_twist", "curls_fill"] and not curls_enabled:
		property.usage = PROPERTY_USAGE_NO_EDITOR
	# Hide/show physics section details
	if property.name in ["physics_preview", "gravity", "spring_constant", "mass", "damping", "stretch", "stiffness", "rotational_physics_scale"] and not physics_enabled:
		property.usage = PROPERTY_USAGE_NO_EDITOR
	# Hide/show LOD section details
	if property.name in ["lod_min_distance", "lod_max_distance", "lod_minimum_shells"] and not lod_enabled:
		property.usage = PROPERTY_USAGE_NO_EDITOR

func _ready():
	mesh = get_parent()
	_initialize_managers()
	_rebuild_fur()
	notify_property_list_changed()

func _enter_tree():
	pass

func _exit_tree() -> void:
	if material_manager and mesh:
		material_manager.clear_materials(mesh)

## Initialize all manager instances
func _initialize_managers() -> void:
	# LOD Manager
	lod_manager = FurLODManager.new(number_of_shells)
	lod_manager.lod_enabled = lod_enabled
	lod_manager.lod_min_distance = lod_min_distance
	lod_manager.lod_max_distance = lod_max_distance
	lod_manager.lod_minimum_shells = lod_minimum_shells
	lod_manager.set_distribution_mode(distribution_mode, distribution_bias)

	# Material Manager
	material_manager = FurMaterialManager.new()
	material_manager.use_texture_atlas = use_texture_atlas
	material_manager.detailed_shell_threshold = detailed_shader_threshold if use_simplified_inner_shaders else 0.0

	# Physics Manager
	physics_manager = FurPhysicsManager.new()
	physics_manager.physics_enabled = physics_enabled
	physics_manager.physics_preview = physics_preview
	physics_manager.gravity = gravity
	physics_manager.spring_constant = spring_constant
	physics_manager.mass = mass
	physics_manager.damping = damping
	physics_manager.stretch = stretch
	physics_manager.stiffness = stiffness
	physics_manager.rotational_physics_scale = rotational_physics_scale
	physics_manager.fur_length = length

	# Culling Manager
	culling_manager = FurCullingManager.new()
	culling_manager.culling_enabled = culling_enabled
	culling_manager.culling_mode = culling_mode
	culling_manager.set_fur_length(length)
	culling_manager.initialize(number_of_shells)

	# Initialize physics
	if mesh:
		physics_manager.initialize(mesh)

## Rebuild entire fur system
func _rebuild_fur() -> void:
	if not mesh or not Engine.is_editor_hint() and not is_inside_tree():
		return

	if Engine.is_editor_hint() and not preview_in_editor:
		if material_manager:
			material_manager.clear_materials(mesh)
		return

	# Clear old materials
	if material_manager:
		material_manager.clear_materials(mesh)

	# Rebuild texture atlas
	_rebuild_texture_atlas()

	# Create new materials
	if material_manager:
		material_manager.create_materials(mesh, number_of_shells, target_surfaces)

	# Apply LOD
	_update_lod()

	# Update materials
	_update_materials()

## Rebuild texture atlas from current textures
func _rebuild_texture_atlas() -> void:
	if not material_manager or not use_texture_atlas:
		return

	material_manager.build_texture_atlas(heightmap_texture, turbulence_texture, jitter_texture)

## Update all material parameters
func _update_materials() -> void:
	if not material_manager or not lod_manager:
		return

	var params = {
		"length": length,
		"density": density,
		"seed": seed,
		"scruffiness": scruffiness,
		"normal_strength": normal_strength,
		"static_direction_local": static_direction_local,
		"static_direction_world": static_direction_world,
		"thickness_curve": thickness_curve,
		"thickness_scale": thickness_scale,
		"render_skin": render_skin,
		"heightmap_texture": heightmap_texture,
		"turbulence_texture": turbulence_texture,
		"jitter_texture": jitter_texture,
		"turbulence_strength": turbulence_strength,
		"jitter_strength": jitter_strength,
		"curls_enabled": curls_enabled,
		"curls_twist": curls_twist,
		"curls_fill": curls_fill,
		"albedo_color": albedo_color,
		"height_gradient": height_gradient,
		"scale_height_gradient": scale_height_gradient,
		"albedo_texture": albedo_texture,
		"use_emission": use_emission,
		"emission_color": emission_color,
		"emission_energy_multiplier": emission_energy_multiplier,
		"emission_texture": emission_texture,
	}

	var lod_thickness = lod_manager.get_lod_thickness_multiplier()
	material_manager.configure_materials(params, lod_manager.shell_heights, lod_thickness)

## Update LOD level and shell selection
func _update_lod() -> void:
	if not lod_manager:
		return

	var active_indices = lod_manager.apply_lod(lod_manager.current_lod)

	if material_manager:
		material_manager.update_lod_chain(active_indices)

	_update_materials()

func _process(_delta):
	# LOD
	if lod_enabled and mesh and lod_manager:
		var camera: Camera3D = get_viewport().get_camera_3d()
		if camera:
			var new_lod = lod_manager.calculate_lod(mesh, camera)
			if new_lod != lod_manager.current_lod:
				lod_manager.current_lod = new_lod
				_update_lod()

	# Shell culling (future enhancement - would need to modify material visibility)
	# Currently culling_manager calculates visibility but doesn't apply it
	# This would require render layer manipulation or shader parameters

func _physics_process(delta):
	if not physics_manager or not mesh:
		return

	if not physics_manager.should_run_in_editor(Engine.is_editor_hint(), preview_in_editor):
		return

	# Update physics simulation
	physics_manager.update_linear_physics(delta, mesh)
	physics_manager.update_rotational_physics(delta, mesh)

	# Apply to materials
	if material_manager:
		physics_manager.apply_to_materials(material_manager.shells, number_of_shells)
