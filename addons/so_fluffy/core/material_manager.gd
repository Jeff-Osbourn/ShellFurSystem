## Material Manager for Shell Fur System
## Handles material creation, configuration, and texture atlas optimization
class_name FurMaterialManager
extends RefCounted

## Shader tier system for performance optimization
enum ShaderTier {
	DETAILED,    # Full-featured shader for outer shells (emission, detailed normals, etc.)
	SIMPLIFIED,  # Optimized shader for inner shells (basic shading only)
}

## Material configuration
var base_shell_material: Material = null
var outer_shader: Shader = null
var inner_shader: Shader = null

## Shell materials
var shells: Array[Material] = []

## Texture atlas (combines multiple textures into one)
var atlas_texture: ImageTexture = null
var use_texture_atlas: bool = true

## Shader tier thresholds
var detailed_shell_threshold: float = 0.6  # Shells above this height use detailed shader

## Target mesh configuration
var target_surfaces: Array[int] = []

func _init():
	# Load shaders
	_load_shaders()

## Load shader resources
func _load_shaders() -> void:
	# Load outer (detailed) shader
	if ResourceLoader.exists("res://addons/so_fluffy/shaders/so_fluffy_outer.gdshader"):
		outer_shader = load("res://addons/so_fluffy/shaders/so_fluffy_outer.gdshader")
	else:
		# Fallback to original shader
		outer_shader = load("res://addons/so_fluffy/so_fluffy.gdshader")

	# Load inner (simplified) shader
	if ResourceLoader.exists("res://addons/so_fluffy/shaders/so_fluffy_inner.gdshader"):
		inner_shader = load("res://addons/so_fluffy/shaders/so_fluffy_inner.gdshader")
	else:
		# Fallback to outer shader if inner doesn't exist yet
		inner_shader = outer_shader

	# Load base material
	if ResourceLoader.exists("res://addons/so_fluffy/shell_material.tres"):
		base_shell_material = load("res://addons/so_fluffy/shell_material.tres")

## Create material cascade for shells
func create_materials(mesh: GeometryInstance3D, shell_count: int, target_surfs: Array[int]) -> Array[Material]:
	if mesh == null:
		return []

	target_surfaces = target_surfs
	shells.clear()

	# Create first material
	var mat = _create_shell_material(0, shell_count)
	mat.set_meta("is_fur", true)

	# Assign to mesh
	if target_surfaces.size() == 0:
		if not _assign_fur_material(mesh.material_overlay, mat):
			mesh.material_overlay = mat
	else:
		for i in target_surfaces:
			if not _assign_fur_material(mesh.get_surface_override_material(i), mat):
				mesh.set_surface_override_material(i, mat)

	shells.append(mat)

	# Create remaining shells
	for i in range(1, shell_count):
		var new_mat = _create_shell_material(i, shell_count)
		new_mat.set_meta("is_fur", true)
		mat.next_pass = new_mat
		mat = new_mat
		shells.append(mat)

	return shells

## Create a single shell material with appropriate shader tier
func _create_shell_material(shell_index: int, total_shells: int) -> ShaderMaterial:
	var mat = ShaderMaterial.new()

	# Determine shader tier based on shell height
	var h = float(shell_index) / float(total_shells - 1) if total_shells > 1 else 0.0
	var shader_tier = ShaderTier.DETAILED if h >= detailed_shell_threshold else ShaderTier.SIMPLIFIED

	# Assign shader
	match shader_tier:
		ShaderTier.DETAILED:
			mat.shader = outer_shader
		ShaderTier.SIMPLIFIED:
			mat.shader = inner_shader

	return mat

## Configure all materials with current parameters
func configure_materials(params: Dictionary, shell_heights: Array[float], lod_thickness: float) -> void:
	for i in range(shells.size()):
		_configure_material(shells[i], i, params, shell_heights, lod_thickness)

## Configure a single material
func _configure_material(mat: Material, index: int, params: Dictionary, shell_heights: Array[float], lod_thickness: float) -> void:
	if mat == null or not mat is ShaderMaterial:
		return

	var shader_mat = mat as ShaderMaterial

	# Get shell height (adaptive or linear)
	var h = shell_heights[index] if index < shell_heights.size() else float(index) / float(shells.size() - 1)

	# Core parameters
	shader_mat.set_shader_parameter("h", h)
	shader_mat.set_shader_parameter("height", params.get("length", 0.1))
	shader_mat.set_shader_parameter("density", params.get("density", 0.5))
	shader_mat.set_shader_parameter("seed", params.get("seed", 0))
	shader_mat.set_shader_parameter("scruffiness", params.get("scruffiness", 0.5))

	# Growth direction
	shader_mat.set_shader_parameter("normal_strength", params.get("normal_strength", 1.0))
	shader_mat.set_shader_parameter("static_direction_local", params.get("static_direction_local", Vector3.ZERO))
	shader_mat.set_shader_parameter("static_direction_world", params.get("static_direction_world", Vector3.ZERO))

	# Thickness
	shader_mat.set_shader_parameter("thickness_scale", params.get("thickness_scale", 1.5) * lod_thickness)
	shader_mat.set_shader_parameter("thickness_curve", params.get("thickness_curve", null))
	shader_mat.set_shader_parameter("use_thickness_curve", params.get("thickness_curve", null) != null)

	# Render options
	shader_mat.set_shader_parameter("render_skin", params.get("render_skin", false))

	# Texture atlas or individual textures
	if use_texture_atlas and atlas_texture != null:
		shader_mat.set_shader_parameter("texture_atlas", atlas_texture)
		shader_mat.set_shader_parameter("use_texture_atlas", true)
	else:
		# Individual textures (backward compatibility)
		shader_mat.set_shader_parameter("use_texture_atlas", false)
		shader_mat.set_shader_parameter("heightmap_texture", params.get("heightmap_texture", null))
		shader_mat.set_shader_parameter("use_heightmap_texture", params.get("heightmap_texture", null) != null)
		shader_mat.set_shader_parameter("turbulence_texture", params.get("turbulence_texture", null))
		shader_mat.set_shader_parameter("jitter_texture", params.get("jitter_texture", null))

	shader_mat.set_shader_parameter("turbulence_strength", params.get("turbulence_strength", 0.3))
	shader_mat.set_shader_parameter("jitter_strength", params.get("jitter_strength", 0.0))

	# Curls
	shader_mat.set_shader_parameter("curls_enabled", params.get("curls_enabled", false))
	shader_mat.set_shader_parameter("curls_twist", params.get("curls_twist", 48.0))
	shader_mat.set_shader_parameter("curls_fill", params.get("curls_fill", PI / 4.0))

	# Appearance
	shader_mat.set_shader_parameter("color", params.get("albedo_color", Color.WHITE))
	shader_mat.set_shader_parameter("height_gradient", params.get("height_gradient", null))
	shader_mat.set_shader_parameter("use_height_gradient", params.get("height_gradient", null) != null)
	shader_mat.set_shader_parameter("scale_height_gradient", params.get("scale_height_gradient", false))
	shader_mat.set_shader_parameter("albedo_texture", params.get("albedo_texture", null))
	shader_mat.set_shader_parameter("use_albedo_texture", params.get("albedo_texture", null) != null)

	# Emission (only for detailed shader)
	if shader_mat.shader == outer_shader:
		shader_mat.set_shader_parameter("use_emission", params.get("use_emission", false))
		shader_mat.set_shader_parameter("emission_color", params.get("emission_color", Color.BLACK))
		shader_mat.set_shader_parameter("emission_energy_multiplier", params.get("emission_energy_multiplier", 1.0))
		shader_mat.set_shader_parameter("emission_texture", params.get("emission_texture", null))
		shader_mat.set_shader_parameter("use_emission_texture", params.get("emission_texture", null) != null)

## Build texture atlas from individual textures
## Combines: R=heightmap, G=turbulence, B=jitter, A=unused
func build_texture_atlas(heightmap: Texture2D, turbulence: Texture2D, jitter: Texture2D) -> void:
	if not use_texture_atlas:
		return

	# Determine atlas size (use largest texture dimension)
	var size = Vector2i(256, 256)  # Default size

	if heightmap != null and heightmap is Texture2D:
		var img_size = heightmap.get_size()
		size.x = max(size.x, int(img_size.x))
		size.y = max(size.y, int(img_size.y))

	# Create atlas image
	var atlas_img = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)

	# Get source images
	var heightmap_img = _get_texture_image(heightmap, size)
	var turbulence_img = _get_texture_image(turbulence, size)
	var jitter_img = _get_texture_image(jitter, size)

	# Combine into atlas
	for y in range(size.y):
		for x in range(size.x):
			var r = heightmap_img.get_pixel(x, y).r if heightmap_img != null else 1.0
			var g = turbulence_img.get_pixel(x, y).r if turbulence_img != null else 0.5
			var b = jitter_img.get_pixel(x, y).r if jitter_img != null else 0.5
			var a = 1.0

			atlas_img.set_pixel(x, y, Color(r, g, b, a))

	# Create texture from atlas
	atlas_texture = ImageTexture.create_from_image(atlas_img)

## Helper: Get image from texture, resized to match atlas
func _get_texture_image(texture: Texture2D, target_size: Vector2i) -> Image:
	if texture == null:
		return null

	var img = texture.get_image()
	if img == null:
		return null

	if img.get_size() != target_size:
		img.resize(target_size.x, target_size.y, Image.INTERPOLATE_BILINEAR)

	return img

## Clear all materials
func clear_materials(mesh: GeometryInstance3D) -> void:
	if mesh == null:
		return

	if target_surfaces.size() == 0:
		if not _remove_fur_material(mesh.material_overlay):
			mesh.material_overlay = null
	else:
		for i in target_surfaces:
			if not _remove_fur_material(mesh.get_surface_override_material(i)):
				mesh.set_surface_override_material(i, null)

	for shell in shells:
		shell.next_pass = null

	shells.clear()

## Remove fur material from chain
func _remove_fur_material(mat: Material) -> bool:
	if mat == null:
		return false
	if mat.has_meta("is_fur"):
		return false

	while mat.next_pass != null:
		if mat.next_pass.has_meta("is_fur"):
			mat.next_pass = null
			return true
		mat = mat.next_pass

	return true

## Assign fur material to chain
func _assign_fur_material(mat: Material, fur: Material) -> bool:
	if mat == null:
		return false

	while mat.next_pass != null:
		mat = mat.next_pass

	mat.next_pass = fur
	return true

## Update LOD shell chain
func update_lod_chain(active_indices: Array[int]) -> void:
	if active_indices.size() == 0:
		return

	# Relink shell chain to skip inactive shells
	for i in range(active_indices.size() - 1):
		var current_idx = active_indices[i]
		var next_idx = active_indices[i + 1]

		if current_idx < shells.size() and next_idx < shells.size():
			shells[current_idx].next_pass = shells[next_idx]

	# Ensure last active shell has no next_pass
	var last_idx = active_indices[active_indices.size() - 1]
	if last_idx < shells.size():
		shells[last_idx].next_pass = null
