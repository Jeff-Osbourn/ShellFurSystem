## Fur Layer Resource
## Defines properties for a single fur layer in a multi-layer fur system
## Allows creating undercoat + guard hairs, or different fur zones
class_name FurLayer
extends Resource

## Layer identification
@export var layer_name: String = "Default"
@export var enabled: bool = true

## Layer blending
@export_range(0.0, 1.0, 0.01)
var blend_strength: float = 1.0  ## How strongly this layer affects the final result

## Layer mask (which parts of the mesh get this layer)
@export var layer_mask: Texture2D  ## Black = no layer, White = full layer
@export var use_vertex_colors: bool = false  ## Use vertex color R channel as mask
@export_enum("R:0", "G:1", "B:2", "A:3")
var vertex_color_channel: int = 0  ## Which vertex color channel to use

## Shell configuration for this layer
@export_range(8, 256, 1)
var shell_count: int = 64

@export_range(0, 2, 0.01, "or_greater")
var length: float = 0.1

@export_range(0.010, 3, 0.001, "or_greater")
var density: float = 0.5

@export_range(0.0, 4, 0.001, "or_greater")
var scruffiness: float = 0.5

## Thickness
@export var thickness_curve: CurveTexture
@export_range(0.01, 4.0, 0.01, "or_greater")
var thickness_scale: float = 1.5

## Appearance
@export_color_no_alpha
var albedo_color: Color = Color.WHITE

@export var albedo_texture: Texture2D

## Growth direction
@export_range(0, 1, 0.005)
var normal_strength: float = 1.0

@export var static_direction_local: Vector3 = Vector3.ZERO
@export var static_direction_world: Vector3 = Vector3.ZERO

## Curls
@export var curls_enabled: bool = false
@export_range(0, 128, 0.01, "or_greater")
var curls_twist: float = 48.0
@export_range(0, 2 * PI, 0.01, "or_greater")
var curls_fill: float = PI / 4.0

## Height gradient
@export var height_gradient: GradientTexture2D
@export var scale_height_gradient: bool = false

## Physics override (if null, uses parent settings)
@export var override_physics: bool = false
@export var physics_scale: float = 1.0  ## Multiplier for physics effects

## Shader tier override
@export var force_detailed_shader: bool = false  ## Force all shells to use detailed shader

func _init():
	layer_name = "Default"
	enabled = true

## Get all parameters as a dictionary for material configuration
func get_parameters() -> Dictionary:
	return {
		"length": length,
		"density": density,
		"scruffiness": scruffiness,
		"thickness_curve": thickness_curve,
		"thickness_scale": thickness_scale,
		"albedo_color": albedo_color,
		"albedo_texture": albedo_texture,
		"normal_strength": normal_strength,
		"static_direction_local": static_direction_local,
		"static_direction_world": static_direction_world,
		"curls_enabled": curls_enabled,
		"curls_twist": curls_twist,
		"curls_fill": curls_fill,
		"height_gradient": height_gradient,
		"scale_height_gradient": scale_height_gradient,
	}

## Create a default undercoat layer
static func create_undercoat() -> FurLayer:
	var layer = FurLayer.new()
	layer.layer_name = "Undercoat"
	layer.shell_count = 32
	layer.length = 0.05
	layer.density = 1.5
	layer.thickness_scale = 0.8
	layer.scruffiness = 0.3
	layer.albedo_color = Color(0.9, 0.9, 0.85)  # Slightly off-white
	return layer

## Create a default guard hair layer
static func create_guard_hairs() -> FurLayer:
	var layer = FurLayer.new()
	layer.layer_name = "Guard Hairs"
	layer.shell_count = 48
	layer.length = 0.15
	layer.density = 0.3
	layer.thickness_scale = 2.0
	layer.scruffiness = 0.8
	layer.albedo_color = Color(0.6, 0.5, 0.4)  # Darker
	return layer

## Create a short fur layer
static func create_short_fur() -> FurLayer:
	var layer = FurLayer.new()
	layer.layer_name = "Short Fur"
	layer.shell_count = 32
	layer.length = 0.08
	layer.density = 0.8
	layer.thickness_scale = 1.2
	layer.scruffiness = 0.4
	return layer
