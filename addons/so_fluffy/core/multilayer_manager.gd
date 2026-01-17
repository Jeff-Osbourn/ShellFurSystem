## Multi-Layer Fur Manager
## Handles rendering multiple fur layers with different properties
## Examples: undercoat + guard hairs, different zones on creature
class_name FurMultiLayerManager
extends RefCounted

## Layer blending modes
enum BlendMode {
	COMPOSITE,  # Layers render on top of each other
	REPLACE,    # Each layer replaces previous based on mask
	ADDITIVE,   # Layers add together
	MAX         # Take maximum of all layers
}

## Multi-layer configuration
var enabled: bool = false
var layers: Array[FurLayer] = []
var blend_mode: BlendMode = BlendMode.COMPOSITE

## Material managers for each layer
var layer_material_managers: Array[FurMaterialManager] = []
var layer_shell_offsets: Array[int] = []  # Starting shell index for each layer

func _init():
	pass

## Add a fur layer
func add_layer(layer: FurLayer) -> void:
	if layer == null:
		return

	layers.append(layer)

	# Create material manager for this layer
	var mat_manager = FurMaterialManager.new()
	layer_material_managers.append(mat_manager)

## Remove a layer by index
func remove_layer(index: int) -> void:
	if index >= 0 and index < layers.size():
		layers.remove_at(index)
		layer_material_managers.remove_at(index)

## Clear all layers
func clear_layers() -> void:
	layers.clear()
	layer_material_managers.clear()
	layer_shell_offsets.clear()

## Get total shell count across all layers
func get_total_shell_count() -> int:
	var total = 0
	for layer in layers:
		if layer.enabled:
			total += layer.shell_count
	return total

## Calculate shell offsets for each layer
func calculate_shell_offsets() -> void:
	layer_shell_offsets.clear()

	var offset = 0
	for layer in layers:
		if layer.enabled:
			layer_shell_offsets.append(offset)
			offset += layer.shell_count
		else:
			layer_shell_offsets.append(-1)  # Disabled layer

## Create materials for all layers
func create_layer_materials(
	mesh: GeometryInstance3D,
	target_surfaces: Array[int],
	use_atlas: bool,
	use_simplified_inner: bool,
	detailed_threshold: float
) -> Array[Material]:

	if not enabled or layers.size() == 0:
		return []

	calculate_shell_offsets()

	var all_shells: Array[Material] = []
	var first_mat: Material = null
	var prev_mat: Material = null

	# Create materials for each layer
	for i in range(layers.size()):
		var layer = layers[i]
		if not layer.enabled:
			continue

		var mat_manager = layer_material_managers[i]
		mat_manager.use_texture_atlas = use_atlas
		mat_manager.detailed_shell_threshold = detailed_threshold if use_simplified_inner and not layer.force_detailed_shader else 0.0

		# Create shells for this layer
		var layer_shells = mat_manager.create_materials(mesh, layer.shell_count, target_surfaces)

		# Link to previous layer's last shell
		if prev_mat != null and layer_shells.size() > 0:
			prev_mat.next_pass = layer_shells[0]

		if first_mat == null and layer_shells.size() > 0:
			first_mat = layer_shells[0]

		if layer_shells.size() > 0:
			prev_mat = layer_shells[layer_shells.size() - 1]

		all_shells.append_array(layer_shells)

	# Assign first material to mesh
	if first_mat != null:
		if target_surfaces.size() == 0:
			mesh.material_overlay = first_mat
		else:
			for surf in target_surfaces:
				mesh.set_surface_override_material(surf, first_mat)

	return all_shells

## Configure all layer materials
func configure_layer_materials(
	base_params: Dictionary,
	shell_heights: Array[float],
	lod_thickness: float,
	atlas_texture: ImageTexture
) -> void:

	for i in range(layers.size()):
		var layer = layers[i]
		if not layer.enabled:
			continue

		# Merge base params with layer-specific params
		var layer_params = base_params.duplicate()
		var layer_overrides = layer.get_parameters()

		for key in layer_overrides:
			layer_params[key] = layer_overrides[key]

		# Add layer mask
		if layer.layer_mask != null:
			layer_params["layer_mask"] = layer.layer_mask
			layer_params["use_layer_mask"] = true
		else:
			layer_params["use_layer_mask"] = false

		# Vertex color masking
		layer_params["use_vertex_color_mask"] = layer.use_vertex_colors
		layer_params["vertex_color_channel"] = layer.vertex_color_channel

		# Configure materials for this layer
		var mat_manager = layer_material_managers[i]
		mat_manager.atlas_texture = atlas_texture
		mat_manager.configure_materials(layer_params, shell_heights, lod_thickness)

## Get layer index for a global shell index
func get_layer_for_shell(shell_index: int) -> int:
	for i in range(layers.size()):
		if not layers[i].enabled:
			continue

		var offset = layer_shell_offsets[i]
		var count = layers[i].shell_count

		if shell_index >= offset and shell_index < offset + count:
			return i

	return -1

## Get local shell index within a layer
func get_local_shell_index(shell_index: int, layer_index: int) -> int:
	if layer_index < 0 or layer_index >= layers.size():
		return -1

	var offset = layer_shell_offsets[layer_index]
	return shell_index - offset

## Apply physics to all layers
func apply_physics_to_layers(physics_manager: FurPhysicsManager) -> void:
	for i in range(layers.size()):
		var layer = layers[i]
		if not layer.enabled:
			continue

		var mat_manager = layer_material_managers[i]
		var physics_scale = layer.physics_scale if layer.override_physics else 1.0

		# Temporarily scale physics
		var original_offset = physics_manager.spring_offset
		var original_rotation = physics_manager.spring_rotation

		physics_manager.spring_offset *= physics_scale
		physics_manager.spring_rotation *= physics_scale

		physics_manager.apply_to_materials(mat_manager.shells, layer.shell_count)

		# Restore original
		physics_manager.spring_offset = original_offset
		physics_manager.spring_rotation = original_rotation

## Create preset: Realistic mammal fur (undercoat + guard hairs)
static func create_mammal_preset() -> Array[FurLayer]:
	var undercoat = FurLayer.create_undercoat()
	var guard = FurLayer.create_guard_hairs()
	return [undercoat, guard]

## Create preset: Bird-like feathers (soft down + longer feathers)
static func create_feather_preset() -> Array[FurLayer]:
	var down = FurLayer.new()
	down.layer_name = "Down"
	down.shell_count = 24
	down.length = 0.04
	down.density = 2.0
	down.thickness_scale = 0.6
	down.scruffiness = 0.2
	down.albedo_color = Color(0.95, 0.95, 0.9)

	var feathers = FurLayer.new()
	feathers.layer_name = "Feathers"
	feathers.shell_count = 48
	feathers.length = 0.12
	feathers.density = 0.4
	feathers.thickness_scale = 2.5
	feathers.scruffiness = 1.2
	feathers.curls_enabled = true
	feathers.curls_twist = 16.0

	return [down, feathers]

## Create preset: Grass layers (short + tall)
static func create_grass_preset() -> Array[FurLayer]:
	var short = FurLayer.new()
	short.layer_name = "Short Grass"
	short.shell_count = 24
	short.length = 0.05
	short.density = 1.5
	short.thickness_scale = 1.0
	short.static_direction_world = Vector3.UP
	short.normal_strength = 0.3

	var tall = FurLayer.new()
	tall.layer_name = "Tall Grass"
	tall.shell_count = 48
	tall.length = 0.15
	tall.density = 0.6
	tall.thickness_scale = 1.2
	tall.scruffiness = 0.8
	tall.static_direction_world = Vector3.UP
	tall.normal_strength = 0.2

	return [short, tall]
